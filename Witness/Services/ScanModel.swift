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

    @ObservationIgnored private var task: Task<Void, Never>?

    var matchedCount: Int { matches.count }
    var inProgress: Bool { state == .scanning || state == .matching || state == .verifying }
    /// The newest game's schedule entry, for the first-result card.
    var newest: FoundGame? { games.first.flatMap { matches[$0.id] } }

    /// Asks for photo access if needed, then scans and matches. Safe to call again after access is granted in Settings.
    func start(library: Library) {
        guard !inProgress else { return }
        task = Task { await run(library: library) }
    }

    func markReviewed() { reviewed = true }

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

        // The stadium and the date decide. Tickets are digital and are not read here; a scene check is only a second opinion.
        let visits = Self.mergeRaceWeekends(found, matched: &matched)
        matches = matched
        tickets = [:]

        state = .verifying
        let candidates = visits.filter { matched[$0.id] != nil }
        let unmatched = visits.filter { matched[$0.id] == nil }
        verifyTotal = candidates.count + unmatched.count
        var confirmed: [PhotoCluster] = []
        var maybe: [PossibleDay] = []
        var skipped = 0
        func makePossible(_ cluster: PhotoCluster, _ reason: String) -> PossibleDay {
            let middle = cluster.times.sorted().dropFirst(cluster.times.count / 2).first ?? cluster.start
            return PossibleDay(id: "possible-" + cluster.id, day: middle, assetIds: cluster.assetIds, times: cluster.times,
                               reason: reason, suggestions: [cluster.venue])
        }
        for cluster in candidates {
            let look = await SceneCheck.verdict(for: cluster.assetIds.map { PhotoRef.library($0) }, sample: 8)
            // A game on the schedule at the stadium that day stands, unless the photos clearly show somewhere else and the
            // setting (indoors for an arena, outdoors for a ballpark) does not fit the stadium either.
            if let look, look.clearlyElsewhere, !look.fits(cluster.venue) {
                maybe.append(makePossible(cluster, "Photos near \(cluster.venue.name) on a game day, but they don't look like a game"))
            } else {
                confirmed.append(cluster)
            }
            verifiedVisits += 1
        }
        // A visit with no game on the schedule is not shown, unless the photos themselves look like a game (a league the
        // schedules do not cover): then it is a possible game, and the fan confirms the stadium.
        for cluster in unmatched {
            let look = await SceneCheck.verdict(for: cluster.assetIds.map { PhotoRef.library($0) }, sample: 8)
            if let look, look.looksLikeGame, PhotoMatcher.looksLikeAGame(cluster.times) {
                maybe.append(makePossible(cluster, "Photos at \(cluster.venue.name) that look like a game, but none is on the schedule"))
            } else {
                skipped += 1
            }
            verifiedVisits += 1
        }

        // Albums, trips and days with no location: a scoreboard names the game; anything else is a day to ask about.
        var claimed = Set<String>()
        var keyer = DayKeyer()
        for g in library.games { claimed.insert(keyer.day(g.date, tz: .current)) }
        for c in confirmed { claimed.insert(keyer.day(c.start, tz: .current)) }
        for m in maybe { claimed.insert(keyer.day(m.day, tz: .current)) }
        let base = verifiedVisits, baseTotal = verifyTotal
        let extra = await GameSuggester.find(venues: library.venues, teams: library.allTeams, home: library.profile.homeLocation,
                                             hasHome: library.hasHome, claimed: claimed) { [weak self] done, total in
            self?.verifyTotal = baseTotal + total
            self?.verifiedVisits = base + done
        }
        for (cluster, game) in extra.games where !confirmed.contains(where: { $0.id == cluster.id }) {
            confirmed.append(cluster)
            matched[cluster.id] = game
        }
        matches = matched
        maybe += extra.possible

        skippedVisits = skipped
        games = confirmed.sorted { $0.start > $1.start }
        others = []
        possible = maybe.sorted { $0.day > $1.day }
        state = games.isEmpty && possible.isEmpty ? .empty : .done
        Analytics.shared.track(.scanFinished, ["games": games.count, "possible": possible.count, "photos": progress.scanned,
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
