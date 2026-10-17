import UIKit
import Observation

/// The scan of the photo library, started from onboarding or "Find in photos". It is owned by the app, not by a screen.
/// It finishes only when everything is done: every photo read, then every stadium visit checked against the real
/// league schedule. Visits with a game on the schedule are games; the rest (a concert, a tour, a tailgate) are "other".
@Observable
@MainActor
final class ScanModel {
    enum State: Equatable { case idle, scanning, matching, done, empty, denied }

    private(set) var state: State = .idle
    private(set) var progress = PhotoMatcher.ScanProgress()
    /// Stadium visits with a game on the real schedule that day, newest first.
    private(set) var games: [PhotoCluster] = []
    /// Visits at or near a stadium with no game on the schedule, newest first.
    private(set) var others: [PhotoCluster] = []
    /// The schedule match for each game, by visit id.
    private(set) var matches: [String: FoundGame] = [:]
    /// Ticket screenshots that pinned a game, by visit id. A ticket makes its visit a game even without a schedule match.
    private(set) var tickets: [String: TicketDraft] = [:]
    /// Visits checked against the schedule so far, and how many there are in all.
    private(set) var checkedVisits = 0
    private(set) var totalVisits = 0
    /// Set once the review screen has taken the results, so the Timeline banner goes away.
    private(set) var reviewed = false
    /// Set once the scan screen has walked the person through every step, so the results appear after it, not mid-count.
    private(set) var shown = false

    @ObservationIgnored private var task: Task<Void, Never>?

    var matchedCount: Int { matches.count }
    var inProgress: Bool { state == .scanning || state == .matching }
    /// The newest game's schedule entry, for the first-result card.
    var newest: FoundGame? { games.first.flatMap { matches[$0.id] } }

    /// Asks for photo access if needed, then scans and matches. Safe to call again after access is granted in Settings.
    func start(library: Library) {
        guard !inProgress else { return }
        task = Task { await run(library: library) }
    }

    func markReviewed() { reviewed = true }
    func markShown() { shown = true }

    func reset() {
        task?.cancel()
        state = .idle
        progress = .init()
        games = []
        others = []
        matches = [:]
        tickets = [:]
        checkedVisits = 0
        totalVisits = 0
        reviewed = false
        shown = false
    }

    private func run(library: Library) async {
        guard await PhotoMatcher.requestAccess() else { state = .denied; return }
        progress = .init()
        games = []; others = []; matches = [:]; tickets = [:]
        checkedVisits = 0; totalVisits = 0
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

        // Ticket screenshots pin games on their own, even when none of the night's photos have GPS. Read them here, so
        // the review that follows has nothing left to wait for.
        var visits = found
        var ticketed: [String: TicketDraft] = [:]
        let have = Set(library.games.compactMap { g in library.venue(g.venueId).map { VisitGrouping.key(venueId: $0.id, date: g.date, tz: $0.tz) } })
        let anchors = await TicketAnchors.find(in: TicketAnchors.screenshots(limit: 200), teams: library.allTeams, venues: venues)
        for anchor in anchors {
            let key = VisitGrouping.key(venueId: anchor.venue.id, date: anchor.date, tz: anchor.venue.tz)
            guard !have.contains(key) else { continue }
            ticketed[key] = anchor.draft
            if visits.contains(where: { $0.id == key }) { continue }
            let ids = await PhotoMatcher.photos(at: anchor.venue, around: anchor.date) + [anchor.id]
            let cluster = PhotoCluster(id: key, venue: anchor.venue, start: anchor.date, end: anchor.date,
                                       assetIds: ids, times: ids.map { _ in anchor.date })
            visits.append(cluster)
            if let game = await Self.match(cluster, venues: venues) { matched[key] = game }
        }
        matches = matched
        tickets = ticketed
        let isGame: (PhotoCluster) -> Bool = { matched[$0.id] != nil || ticketed[$0.id] != nil }
        let ordered = visits.sorted { $0.start > $1.start }
        games = ordered.filter(isGame)
        others = ordered.filter { !isGame($0) }
        state = games.isEmpty && others.isEmpty ? .empty : .done
    }

    /// The game on the schedule at this visit's stadium (or the arena next door) around the photos' times.
    nonisolated static func match(_ cluster: PhotoCluster, venues: [Venue]) async -> FoundGame? {
        for venue in [cluster.venue] + PhotoMatcher.neighbors(of: cluster.venue, in: venues) {
            if let game = await GameLookup.games(at: venue, from: cluster.start, to: cluster.end).first { return game }
        }
        return nil
    }
}
