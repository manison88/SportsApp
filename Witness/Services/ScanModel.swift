import UIKit
import Observation
import CoreLocation

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
    @ObservationIgnored private(set) var pendingVisits: [PhotoCluster] {
        didSet { Self.savePending(pendingVisits, to: pendingURL) }
    }

    nonisolated static var pendingURL: URL { URL.applicationSupportDirectory.appending(path: "pending-visits.json") }
    nonisolated static var ledgerURL: URL { URL.applicationSupportDirectory.appending(path: "review-ledger.json") }

    /// What the fan skipped in any review, so no later pass offers it again. Added visits are in the library.
    @ObservationIgnored private(set) var ledger: ReviewLedger
    @ObservationIgnored private let ledgerURL: URL
    @ObservationIgnored private let pendingURL: URL
    @ObservationIgnored private let photos: Photos

    /// Where a scan reads the photos and what it sees in them: the photo library on the phone, or photos a test hands in.
    struct Photos {
        var access: () async -> Bool
        var discover: (_ venues: [Venue], _ existing: [GameEntry], _ progress: @escaping @Sendable (PhotoMatcher.ScanProgress) -> Void) async -> PhotoMatcher.Found
        var look: (_ refs: [PhotoRef], _ max: Int) async -> SceneCheck.DayLook
        /// The album and trip step of the background search.
        var suggest: (_ venues: [Venue], _ teams: [Team], _ home: CLLocation, _ hasHome: Bool, _ claimed: Set<String>,
                      _ progress: @escaping @MainActor (GameSuggester.Step, Int, Int) -> Void) async -> [PossibleDay]
        /// Albums whose title names a game ("BiH v Qatar"): the schedule is asked for a game between the two teams while the
        /// photos were taken, so the stadium comes from the schedule and no photo needs a location.
        var matchups: (_ venues: [Venue], _ teams: [Team], _ existing: [GameEntry]) async -> [PossibleDay] = { _, _, _ in [] }

        static let library = Photos(
            access: { await PhotoMatcher.requestAccess() },
            discover: { venues, existing, progress in await PhotoMatcher.discover(venues: venues, existing: existing, progress: progress) },
            look: { refs, max in await SceneCheck.look(at: refs, max: max) },
            suggest: { venues, teams, home, hasHome, claimed, progress in
                await GameSuggester.find(venues: venues, teams: teams, home: home, hasHome: hasHome, claimed: claimed, progress: progress)
            },
            matchups: { venues, teams, existing in await MatchupAlbums.inLibrary(teams: teams, venues: venues, existing: existing) })
    }

    init(ledgerURL: URL = ScanModel.ledgerURL, pendingURL: URL = ScanModel.pendingURL, photos: Photos = .library) {
        self.ledgerURL = ledgerURL
        self.pendingURL = pendingURL
        self.photos = photos
        ledger = ReviewLedger.load(from: ledgerURL)
        pendingVisits = Self.loadPending(from: pendingURL)
    }

    private static func loadPending(from url: URL) -> [PhotoCluster] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PhotoCluster].self, from: data)) ?? []
    }

    private static func savePending(_ visits: [PhotoCluster], to url: URL) {
        if visits.isEmpty { try? FileManager.default.removeItem(at: url); return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(visits).write(to: url, options: .atomic)
    }

    /// Waits for the first pass (and the background search, when one is running) to finish. For tests and the scan check.
    func finished() async {
        await task?.value
        await deepTask?.value
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

    /// The first pass's results, minus what the library has or the fan turned down, each visit in one place.
    func settleFirstPass(games: [PhotoCluster], others: [PhotoCluster], library: Library) {
        let settled = ReviewQueue.firstPass(games: games, others: others, library: library.games, venues: library.venues, ledger: ledger)
        self.games = settled.games
        self.others = settled.others
    }

    /// Adds the background search's finds to what is waiting, minus anything already added, turned down or offered.
    func settleDeep(_ found: [PossibleDay], library: Library) {
        possible = ReviewQueue.possible(possible + found, alongside: games + others, library: library.games, ledger: ledger)
    }

    struct Review { var games: [PhotoCluster]; var others: [PhotoCluster]; var possible: [PossibleDay] }

    /// Hands everything waiting to the review screen, once: the lists empty as they are taken, so a later search's review
    /// shows only that search's finds. Checked against the library and the skips again, since both change while results wait.
    func takeForReview(library: Library) -> Review {
        settleFirstPass(games: games, others: others, library: library)
        settleDeep([], library: library)
        let out = Review(games: games, others: others, possible: possible)
        games = []; others = []; possible = []
        markReviewed()
        return out
    }

    /// The fan skipped this visit or day: it is not offered again, by this pass or any later one, after a relaunch too.
    /// `asGame` when it was offered as a game on the schedule; a skipped stadium visit still lets a game found later for its photos through.
    func dismiss(_ assetIds: [String], on day: Date, asGame: Bool = false) {
        var keyer = DayKeyer()
        ledger.dismiss(assetIds, day: keyer.day(day, tz: .current), game: asGame)
        ledger.save(to: ledgerURL)
        let ids = Set(assetIds)
        games.removeAll { $0.assetIds.contains(where: ids.contains) }
        others.removeAll { $0.assetIds.contains(where: ids.contains) }
        possible.removeAll { $0.assetIds.contains(where: ids.contains) }
        pendingVisits.removeAll { $0.assetIds.contains(where: ids.contains) }
    }

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
        // Stadium visits already up for review, and days the fan turned down, are not looked for again in the albums.
        for c in others { claimed.insert(keyer.day(c.start, tz: .current)) }
        claimed.formUnion(ledger.dismissedDays)
        let venues = library.venues, teams = library.allTeams
        let home = library.profile.homeLocation, hasHome = library.hasHome
        Analytics.shared.track(.onboardingStep, ["step": "deep_scan_started"])
        let pending = pendingVisits.filter { !$0.assetIds.contains(where: ledger.dismissedAssets.contains) }
        let claimedBefore = claimed
        let photos = photos
        deepTask = Task { [weak self] in
            var claimed = claimedBefore
            var keyer = DayKeyer()
            // First the stadium visits with no game on the schedule: a possible game when the photos look like one
            // (a league the schedules do not cover), and the fan confirms the stadium.
            var atStadiums: [PossibleDay] = []
            for (n, cluster) in pending.enumerated() {
                if Task.isCancelled { return }
                self?.deepStep = .visits; self?.deepDone = n; self?.deepTotal = pending.count
                if let day = await Self.waitingDay(cluster, venues: venues, look: { await photos.look($0.map { PhotoRef.library($0) }, 24) }) {
                    atStadiums.append(day)
                }
            }
            for day in atStadiums { claimed.insert(keyer.day(day.day, tz: .current)) }
            let found = await photos.suggest(venues, teams, home, hasHome, claimed) { step, done, total in
                self?.deepStep = step
                self?.deepTotal = total
                self?.deepDone = done
            }
            guard let self, !Task.isCancelled else { return }
            settleDeep(atStadiums + found, library: library)
            pendingVisits = []
            deepReviewed = false
            deepState = .done
            Analytics.shared.track(.scanFinished, ["deep": true, "possible": found.count])
        }
    }

    /// Adds visits to the library in one go, without asking about each: games with their schedule match (or ticket seat), or
    /// every visit as a stadium visit. Plays and win probability arrive afterwards. Added visits leave the lists, so the review
    /// screen only shows what is left. Returns how many new cards the library gained (photos for a game it already has
    /// join that game, and are not counted).
    @discardableResult
    func commit(_ clusters: [PhotoCluster], asVisits: Bool = false, tickets extraTickets: [String: TicketDraft] = [:],
                matches extraMatches: [String: FoundGame] = [:], into library: Library) -> Int {
        let before = library.games.count
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
        return library.games.count - before
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
        guard await photos.access() else {
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

        let scanned = await photos.discover(library.venues, library.games) { p in
            Task { @MainActor [weak self] in
                guard let self, self.state == .scanning else { return }
                self.progress = p
            }
        }
        let found = scanned.visits
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
        // around the ground) when the photos inside its fence show the ground itself, from the ground, three times over
        // (`DayLook.showsTheGround`); the rest wait for the background search.
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
        // A saved stadium visit is scanned again only to find its game: still without one, it stays as it was and is not asked about again.
        let savedVisits = PhotoMatcher.savedVisitKeys(library.games, venues: venues)
        let unmatched = visits.filter { matched[$0.id] == nil && !savedVisits.contains($0.id) }
        state = .verifying
        verifiedVisits = 0
        verifyTotal = unmatched.count
        var tours: [PhotoCluster] = []
        var pending: [PhotoCluster] = []
        for cluster in unmatched {
            if Task.isCancelled { break }
            let look = await photos.look(cluster.anchors.map { PhotoRef.library($0) }, SceneCheck.tourSample)
            if look.showsTheGround() { tours.append(cluster) } else { pending.append(cluster) }
            verifiedVisits += 1
        }
        pendingVisits = pending.filter { !$0.assetIds.contains(where: ledger.dismissedAssets.contains) }
        matches = matched
        skippedVisits = pending.count
        possible = []
        settleFirstPass(games: confirmed, others: tours, library: library)
        // Days spent just outside a stadium's fence, offered as possible games when the schedule had one there then.
        var aroundGrounds: [PossibleDay] = []
        for cluster in scanned.nearby {
            if Task.isCancelled { break }
            if let day = await Self.nearbyDay(cluster, venues: venues) { aroundGrounds.append(day) }
        }
        // Albums titled for a game: cheap (a title read per album; only a matchup title asks the schedules), and a game between
        // the two named teams on the photos' dates is strong enough to ask about without a single located photo.
        let titled = Task.isCancelled ? [] : await photos.matchups(venues, library.allTeams, library.games)
        // Photos with no location on a day the located ones place in one city: a possible game only when that city's schedule
        // had one while they were taken and the sampled photos look like a stadium. At most `CityDays.maxDays` days, and a
        // scene check only for a day a game fits.
        var inCity: [PossibleDay] = []
        let see = photos.look
        for day in scanned.cityDays {
            if Task.isCancelled { break }
            if let offer = await CityDays.evaluate(day, look: { await see($0, CityDays.sample) }).offer { inCity.append(offer) }
        }
        settleDeep(aroundGrounds + titled + inCity, library: library)
        state = games.isEmpty && others.isEmpty && possible.isEmpty ? .empty : .done
        Analytics.shared.track(.scanFinished, ["games": games.count, "visits": others.count, "photos": progress.scanned,
                                               "seconds": Int(Date().timeIntervalSince(began))])
    }

    /// What the background search offers for a stadium visit the first pass left without a game. `see` looks at photos by id:
    /// it is handed the ones inside the fence.
    nonisolated static func waitingDay(_ cluster: PhotoCluster, venues: [Venue],
                                       look see: ([String]) async -> SceneCheck.DayLook) async -> PossibleDay? {
        let middle = cluster.times.sorted().dropFirst(cluster.times.count / 2).first ?? cluster.start
        // The schedule first, the ground next door too: the visit may be waiting from a scan that never looked there, or whose
        // lookup failed. A game on it is offered whatever the photos look like, with the ground it was played at first.
        if let game = await match(cluster, venues: venues) {
            let at = GameLookup.venue(of: game, in: venues) ?? cluster.venue
            return PossibleDay(id: "possible-" + cluster.id, day: middle, assetIds: cluster.assetIds, times: cluster.times,
                               reason: "Photos at \(cluster.venue.name) \u{00B7} \(GameSuggester.describe(game, at: at))",
                               suggestions: [at] + [cluster.venue].filter { $0.id != at.id })
        }
        // At a stadium already, but the photos inside its fence must show the ground itself from the ground, three times over
        // and never from the air: a landing over the ground or a bar across the street is not a visit. A day with no game is
        // offered too: a stadium tour is a visit worth keeping, and the review saves it as one when no game turns up for the date.
        let look = await see(cluster.anchors)
        guard look.showsTheGround() else { return nil }
        let game = look.isGame(minVenue: 1, minShare: 0.2) && PhotoMatcher.looksLikeAGame(cluster.times)
        return PossibleDay(id: "possible-" + cluster.id, day: middle, assetIds: cluster.assetIds, times: cluster.times,
                           reason: game ? "Photos at \(cluster.venue.name) that look like a game, but none is on the schedule"
                                        : "Photos inside \(cluster.venue.name) with no game that day \u{00B7} a stadium visit?",
                           suggestions: [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: venues).prefix(2))
    }

    /// A possible game for a day of photos just outside a stadium's fence: only when the schedule had a game there (or next door)
    /// while the photos were taken, from two hours before kickoff to three after.
    nonisolated static func nearbyDay(_ cluster: PhotoCluster, venues: [Venue]) async -> PossibleDay? {
        guard let game = await match(cluster, venues: venues),
              cluster.times.contains(where: { $0 >= game.start.addingTimeInterval(-2 * 3600) && $0 <= game.start.addingTimeInterval(3 * 3600) })
        else { return nil }
        let at = GameLookup.venue(of: game, in: venues) ?? cluster.venue
        let middle = cluster.times.sorted().dropFirst(cluster.times.count / 2).first ?? cluster.start
        return PossibleDay(id: "possible-near-" + cluster.id, day: middle, assetIds: cluster.assetIds, times: cluster.times,
                           reason: "Photos around \(cluster.venue.name) \u{00B7} \(GameSuggester.describe(game, at: at))",
                           suggestions: [at] + [cluster.venue].filter { $0.id != at.id })
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
