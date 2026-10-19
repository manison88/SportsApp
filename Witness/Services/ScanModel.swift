import UIKit
import Observation

/// The scan of the photo library, started from onboarding or "Find in photos". It is owned by the app, not by a screen.
/// It finishes only when everything is done: every photo read, then every stadium visit checked against the real
/// league schedule. Visits with a game on the schedule are games; the rest (a concert, a tour, a tailgate) are "other".
@Observable
@MainActor
final class ScanModel {
    enum State: Equatable { case idle, scanning, matching, verifying, done, empty, denied }

    private(set) var state: State = .idle
    private(set) var progress = PhotoMatcher.ScanProgress()
    /// Stadium visits with a game on the real schedule that day, newest first.
    private(set) var games: [PhotoCluster] = []
    /// Visits at or near a stadium with no game on the schedule, newest first.
    private(set) var others: [PhotoCluster] = []
    /// Days that might be games where the stadium is not known: the fan picks it and the photos' date finds the game. Never added in bulk.
    private(set) var possible: [PossibleDay] = []
    /// The schedule match for each game, by visit id.
    private(set) var matches: [String: FoundGame] = [:]
    /// Ticket screenshots that pinned a game, by visit id. A ticket makes its visit a game even without a schedule match.
    private(set) var tickets: [String: TicketDraft] = [:]
    /// Visits checked against the schedule so far, and how many there are in all.
    private(set) var checkedVisits = 0
    private(set) var totalVisits = 0
    /// Visits looked at so far in the last check (do the photos look like a game or an event?), and how many there are.
    private(set) var verifiedVisits = 0
    private(set) var verifyTotal = 0
    /// Why a visit that matched a game was moved to "other", by visit id.
    private(set) var notes: [String: String] = [:]
    /// Visits near a stadium whose photos looked like neither a game nor an event (a home, a street), left out.
    private(set) var skippedVisits = 0
    /// Set once the review screen has taken the results, so the Timeline banner goes away.
    private(set) var reviewed = false
    /// Set once the scan screen has walked the person through every step, so the results appear after it, not mid-count.
    private(set) var shown = false

    /// The optional second pass over albums, trips and photos with no location. Only ever started by the fan, and runs in the background.
    enum DeepState: Equatable { case idle, running, done }
    private(set) var deepState: DeepState = .idle
    private(set) var deepDone = 0
    private(set) var deepTotal = 0
    private(set) var deepStep: GameSuggester.Step = .reading
    /// The whole search as 0...1, each step a quarter: stadium visits, reading albums, sorting them, the days.
    var deepFraction: Double {
        let part = deepTotal > 0 ? Double(deepDone) / Double(deepTotal) : 0
        return min(1, (Double(deepStep.rawValue) + part) / 4)
    }
    /// Set once the fan has seen the second pass's results.
    private(set) var deepReviewed = true
    /// The fan said no to the second pass; it is not offered again.
    var deepDeclined: Bool {
        get { UserDefaults.standard.bool(forKey: "deepScanDeclined") }
        set { UserDefaults.standard.set(newValue, forKey: "deepScanDeclined") }
    }

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var deepTask: Task<Void, Never>?
    /// Stadium visits from the first pass with no game on the schedule, looked at only in the background search.
    /// Kept on disk, so the search still covers them after the app is closed; cleared once it has run.
    @ObservationIgnored private var pendingVisits: [PhotoCluster] = ScanModel.loadPending() {
        didSet { Self.savePending(pendingVisits) }
    }

    private static var pendingURL: URL { URL.applicationSupportDirectory.appending(path: "pending-visits.json") }

    private static func loadPending() -> [PhotoCluster] {
        guard let data = try? Data(contentsOf: pendingURL) else { return [] }
        return (try? JSONDecoder().decode([PhotoCluster].self, from: data)) ?? []
    }

    private static func savePending(_ visits: [PhotoCluster]) {
        if visits.isEmpty { try? FileManager.default.removeItem(at: pendingURL); return }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(visits).write(to: pendingURL, options: .atomic)
    }

    var matchedCount: Int { matches.count }
    var inProgress: Bool { state == .scanning || state == .matching || state == .verifying }
    /// The newest game's schedule entry, for the first-result card.
    var newest: FoundGame? { games.first.flatMap { matches[$0.id] } }

    /// Asks for photo access if needed, then scans and matches. Safe to call again after access is granted in Settings.
    func start(library: Library) {
        guard !inProgress else { return }
        task = Task { await run(library: library) }
    }

    func markReviewed() { reviewed = true; deepReviewed = true }

    /// Looks through albums, trips and days with no location for more games, in the background. Everything it finds is a
    /// possible game: the fan picks the stadium, and nothing is added on its own.
    func startDeepScan(library: Library) {
        guard deepState != .running else { return }
        deepState = .running
        deepDone = 0; deepTotal = 0; deepStep = .visits
        var claimed = Set<String>()
        var keyer = DayKeyer()
        for g in library.games { claimed.insert(keyer.day(g.date, tz: .current)) }
        for c in games { claimed.insert(keyer.day(c.start, tz: .current)) }
        for m in possible { claimed.insert(keyer.day(m.day, tz: .current)) }
        let venues = library.venues, teams = library.allTeams
        let home = library.profile.homeLocation, hasHome = library.hasHome
        Analytics.shared.track(.onboardingStep, ["step": "deep_scan_started"])
        let pending = pendingVisits
        let claimedBefore = claimed
        deepTask = Task { [weak self] in
            var claimed = claimedBefore
            var keyer = DayKeyer()
            // First the stadium visits with no game on the schedule: a possible game when the photos look like one
            // (a league the schedules do not cover), and the fan confirms the stadium.
            var atStadiums: [PossibleDay] = []
            for (n, cluster) in pending.enumerated() {
                if Task.isCancelled { return }
                self?.deepStep = .visits; self?.deepDone = n; self?.deepTotal = pending.count
                // At a stadium already, so one clear photo of the ground or a game will do, as long as the day was not mostly
                // somewhere else (a bar across the street). A day with no game is offered too: a stadium tour is a visit worth
                // keeping, and the review saves it as one when no game turns up for the date.
                let look = await SceneCheck.look(at: cluster.assetIds.map { PhotoRef.library($0) })
                guard look.venue >= 1, !look.mostlyElsewhere else { continue }
                let game = look.isGame(minVenue: 1, minShare: 0.2) && PhotoMatcher.looksLikeAGame(cluster.times)
                let middle = cluster.times.sorted().dropFirst(cluster.times.count / 2).first ?? cluster.start
                atStadiums.append(PossibleDay(id: "possible-" + cluster.id, day: middle, assetIds: cluster.assetIds, times: cluster.times,
                                              reason: game ? "Photos at \(cluster.venue.name) that look like a game, but none is on the schedule"
                                                           : "Photos inside \(cluster.venue.name) with no game that day \u{00B7} a stadium visit?",
                                              suggestions: [cluster.venue]))
            }
            for day in atStadiums { claimed.insert(keyer.day(day.day, tz: .current)) }
            let found = await GameSuggester.find(venues: venues, teams: teams, home: home, hasHome: hasHome, claimed: claimed) { step, done, total in
                self?.deepStep = step
                self?.deepTotal = total
                self?.deepDone = done
            }
            guard let self, !Task.isCancelled else { return }
            possible = (possible + atStadiums + found).sorted { $0.day > $1.day }
            pendingVisits = []
            deepReviewed = false
            deepState = .done
            Analytics.shared.track(.scanFinished, ["deep": true, "possible": found.count])
        }
    }

    /// Adds visits to the library in one go, without asking about each: games with their schedule match (or ticket seat), or
    /// every visit as a stadium visit. Plays and win probability arrive afterwards. Added visits leave the lists, so the review
    /// screen only shows what is left. Returns how many were added.
    @discardableResult
    func commit(_ clusters: [PhotoCluster], asVisits: Bool = false, tickets extraTickets: [String: TicketDraft] = [:],
                matches extraMatches: [String: FoundGame] = [:], into library: Library) -> Int {
        var details: [(String, FoundGame)] = []
        let tickets = self.tickets.merging(extraTickets) { _, new in new }
        let matches = self.matches.merging(extraMatches) { _, new in new }
        for cluster in clusters {
            let venue = cluster.venue
            var entry = GameEntry(sport: venue.sports.first ?? .baseball, date: cluster.start, venueId: venue.id,
                                  photos: cluster.assetIds.map { PhotoRef.library($0) }, origin: .photos)
            if let draft = tickets[cluster.id] {
                entry.seat = draft.seatLine
                entry.origin = .ticket
            }
            if asVisits {
                entry.kind = .visit
                entry.competition = "Stadium visit"
            } else if let game = matches[cluster.id] {
                entry.date = game.start
                if let at = GameLookup.venue(of: game, in: library.venues) { entry.venueId = at.id }
                GameLookup.apply(game, detail: nil, to: &entry, library: library)
                details.append((entry.id, game))
            } else if tickets[cluster.id] == nil && !GameLookup.leagues(for: venue).isEmpty {
                entry.kind = .visit
                entry.competition = "Stadium visit"
            }
            library.add(entry)
        }
        let ids = Set(clusters.map(\.id))
        games.removeAll { ids.contains($0.id) }
        others.removeAll { ids.contains($0.id) }
        Analytics.shared.track(.gameAdded, ["source": asVisits ? "scan_add_all_visits" : "scan_add_all", "count": clusters.count])
        Task {
            for (id, game) in details {
                guard let detail = await GameLookup.detail(game), var saved = library.game(id) else { continue }
                GameLookup.apply(game, detail: detail, to: &saved, library: library)
                library.update(saved)
            }
        }
        return clusters.count
    }
    func markShown() { shown = true }

    func reset() {
        task?.cancel()
        deepTask?.cancel()
        deepState = .idle
        deepDone = 0; deepTotal = 0
        deepReviewed = true
        state = .idle
        progress = .init()
        games = []
        others = []
        possible = []
        matches = [:]
        tickets = [:]
        notes = [:]
        checkedVisits = 0
        totalVisits = 0
        verifiedVisits = 0
        verifyTotal = 0
        skippedVisits = 0
        reviewed = false
        shown = false
    }

    private func run(library: Library) async {
        let began = Date()
        guard await PhotoMatcher.requestAccess() else {
            state = .denied
            Analytics.shared.track(.onboardingStep, ["step": "photo_access", "granted": false])
            return
        }
        Analytics.shared.track(.onboardingStep, ["step": "photo_access", "granted": true])
        progress = .init()
        games = []; others = []; possible = []; matches = [:]; tickets = [:]; notes = [:]
        checkedVisits = 0; totalVisits = 0; verifiedVisits = 0; verifyTotal = 0; skippedVisits = 0
        reviewed = false
        shown = false
        state = .scanning
        // The scan can take minutes: keep the screen awake so it isn't interrupted.
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        let found = await PhotoMatcher.discover(venues: library.venues, existing: library.games) { p in
            Task { @MainActor [weak self] in
                guard let self, self.state == .scanning else { return }
                self.progress = p
            }
        }
        progress.scanned = progress.total

        state = .matching
        totalVisits = found.count
        let venues = library.venues
        var matched: [String: FoundGame] = [:]
        // Schedule lookups are network calls, so a few run at once.
        for start in stride(from: 0, to: found.count, by: 4) {
            let chunk = Array(found[start..<min(start + 4, found.count)])
            let results = await withTaskGroup(of: (String, FoundGame?).self, returning: [(String, FoundGame?)].self) { group in
                for cluster in chunk {
                    group.addTask { (cluster.id, await Self.match(cluster, venues: venues)) }
                }
                var out: [(String, FoundGame?)] = []
                for await r in group { out.append(r) }
                return out
            }
            for (id, game) in results { if let game { matched[id] = game } }
            matches = matched
            checkedVisits = min(start + chunk.count, found.count)
        }

        // A second, slower pass over the visits left without a game: a lookup that failed under load gets another chance,
        // one visit at a time, before a real game is filed as "no game on the schedule".
        for cluster in found where matched[cluster.id] == nil {
            if Task.isCancelled { break }
            if let game = await Self.match(cluster, venues: venues) { matched[cluster.id] = game; matches = matched }
        }

        // The stadium and the date decide. Tickets are digital and are not read here; a scene check is only a second opinion.
        let visits = Self.mergeRaceWeekends(found, matched: &matched)
        matches = matched
        tickets = [:]

        // Games: a game on the schedule at the stadium that day. A visit with no game is a stadium visit (a tour, a walk
        // around the ground) when a few of its photos clearly show the stadium; the rest wait for the background search.
        // One game, one card: photos split between two neighbouring grounds (the walk in by the ballpark, the match next
        // door) that found the same game become one visit.
        var confirmed: [PhotoCluster] = []
        var byGame: [String: Int] = [:]
        for cluster in visits {
            guard let game = matched[cluster.id] else { continue }
            if let at = byGame[game.id] {
                let merged = confirmed[at].combined(with: cluster)
                matched[merged.id] = game
                confirmed[at] = merged
            } else {
                byGame[game.id] = confirmed.count
                confirmed.append(cluster)
            }
        }
        let unmatched = visits.filter { matched[$0.id] == nil }
        state = .verifying
        verifiedVisits = 0
        verifyTotal = unmatched.count
        var tours: [PhotoCluster] = []
        var pending: [PhotoCluster] = []
        for cluster in unmatched {
            if Task.isCancelled { break }
            let look = await SceneCheck.look(at: cluster.assetIds.map { PhotoRef.library($0) }, max: 6)
            if look.venue >= 1, !look.mostlyElsewhere { tours.append(cluster) } else { pending.append(cluster) }
            verifiedVisits += 1
        }
        pendingVisits = pending
        matches = matched
        skippedVisits = pending.count
        games = confirmed.sorted { $0.start > $1.start }
        others = tours.sorted { $0.start > $1.start }
        possible = []
        state = games.isEmpty && others.isEmpty ? .empty : .done
        Analytics.shared.track(.scanFinished, ["games": games.count, "visits": others.count, "photos": progress.scanned,
                                               "seconds": Int(Date().timeIntervalSince(began))])
    }

    /// A race weekend is one event over several days at the circuit: Friday, Saturday and Sunday photos become one visit.
    nonisolated static func mergeRaceWeekends(_ clusters: [PhotoCluster], matched: inout [String: FoundGame]) -> [PhotoCluster] {
        var out: [PhotoCluster] = []
        var byRace: [String: Int] = [:]
        for cluster in clusters {
            guard let game = matched[cluster.id], let race = game.race else { out.append(cluster); continue }
            if let at = byRace[race.id] {
                let merged = out[at].combined(with: cluster)
                matched[merged.id] = game
                if merged.id != out[at].id { matched[out[at].id] = nil }
                if merged.id != cluster.id { matched[cluster.id] = nil }
                out[at] = merged
            } else {
                byRace[race.id] = out.count
                out.append(cluster)
            }
        }
        return out
    }

    /// The game on the schedule at this visit's stadium (or the arena next door) around the photos' times.
    nonisolated static func match(_ cluster: PhotoCluster, venues: [Venue]) async -> FoundGame? {
        for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: venues) {
            if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first { return game }
        }
        return nil
    }
}
