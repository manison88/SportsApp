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
    func markShown() { shown = true }

    func reset() {
        task?.cancel()
        state = .idle
        progress = .init()
        games = []
        others = []
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
        guard await PhotoMatcher.requestAccess() else { state = .denied; return }
        progress = .init()
        games = []; others = []; matches = [:]; tickets = [:]; notes = [:]
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

        // Ticket screenshots pin games on their own, even when none of the night's photos have GPS. Read them here, so
        // the review that follows has nothing left to wait for.
        var visits = Self.mergeRaceWeekends(found, matched: &matched)
        matches = matched
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

        // Location and a game on that date are not enough: a home near the stadium puts photos there on game day too.
        // A game needs photos that look like one. A ticket is proof on its own.
        state = .verifying
        let ticketBacked = visits.filter { ticketed[$0.id] != nil }
        let candidates = visits.filter { matched[$0.id] != nil && ticketed[$0.id] == nil }
        let unmatched = visits.filter { matched[$0.id] == nil && ticketed[$0.id] == nil }
        verifyTotal = candidates.count + unmatched.count
        var confirmed = ticketBacked
        var inOther: [PhotoCluster] = []
        var skipped = 0
        for cluster in candidates {
            let look = await SceneCheck.verdict(for: cluster.assetIds.map { PhotoRef.library($0) }, sample: 8)
            // Only a clear sign of somewhere else (a bedroom, a restaurant) overrides the schedule match. Without the
            // classifier, or when it is unsure, the match stands.
            if look == nil || !look!.clearlyElsewhere {
                confirmed.append(cluster)
            } else {
                inOther.append(cluster)
                if let game = matched[cluster.id] {
                    notes[cluster.id] = game.race.map { "There was a race here (\($0.title)), but these photos don't look like it." }
                        ?? "There was a game here that day (\(game.away.abbreviation) at \(game.home.abbreviation)), but these photos don't look like it."
                }
            }
            verifiedVisits += 1
        }
        for cluster in unmatched {
            let look = await SceneCheck.verdict(for: cluster.assetIds.map { PhotoRef.library($0) }, sample: 8)
            if look == nil || !look!.clearlyElsewhere { inOther.append(cluster) } else { skipped += 1 }
            verifiedVisits += 1
        }
        skippedVisits = skipped
        games = confirmed.sorted { $0.start > $1.start }
        others = inOther.sorted { $0.start > $1.start }
        state = games.isEmpty && others.isEmpty ? .empty : .done
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
