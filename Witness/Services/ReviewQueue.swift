import Foundation
import CoreLocation

/// What the fan turned down when a scan asked: the photos of every skipped visit and their days. Added visits live in the
/// library, so between the two no pass (onboarding, the background search, Find in photos) asks about a visit twice.
/// Kept on disk, so a skip still holds after the app is closed.
struct ReviewLedger: Codable, Equatable {
    /// Photos of every visit or possible game the fan skipped.
    private(set) var dismissedAssets: Set<String> = []
    /// Days written by ledgers before skips were kept per outing. They no longer hide anything: a skipped visit used to hide every
    /// later possible game on its phone-day (a morning tour hid the evening game). Still read and written, so an older file loads.
    private(set) var dismissedDays: Set<String> = []
    /// Photos of the games on the schedule the fan skipped. Only these keep a game away: skipping a stadium visit with no game
    /// (or a day the search was unsure of) says nothing about a game the schedule finds for those photos later.
    private(set) var dismissedGames: Set<String> = []

    /// The time the photos of one skip span. A possible game found from other photos taken within `skipWindowHours` of it is the
    /// same outing and stays away; one hours later the same day is a different outing.
    struct Outing: Codable, Hashable {
        var from: TimeInterval
        var to: TimeInterval
    }
    private(set) var dismissedOutings: [Outing] = []

    init() {}

    /// - span: first to last photo time of what was skipped (nil: nothing is kept away beyond the photos themselves).
    mutating func dismiss(_ assetIds: [String], span: ClosedRange<Date>? = nil, game: Bool = false) {
        dismissedAssets.formUnion(assetIds)
        if let span {
            let outing = Outing(from: span.lowerBound.timeIntervalSince1970, to: span.upperBound.timeIntervalSince1970)
            if !dismissedOutings.contains(outing) { dismissedOutings.append(outing) }
        }
        if game { dismissedGames.formUnion(assetIds) }
    }

    /// Whether a skip covers this moment: within `skipWindowHours` of a skipped outing's photos.
    func skipped(at date: Date, settings: ScanSettings = .current) -> Bool {
        let t = date.timeIntervalSince1970, slack = settings.skipWindowHours * 3600
        return dismissedOutings.contains { t >= $0.from - slack && t <= $0.to + slack }
    }

    private enum CodingKeys: String, CodingKey { case dismissedAssets, dismissedDays, dismissedGames, dismissedOutings }

    /// Ledgers written before game skips were kept apart have no `dismissedGames`; before per-outing skips, no `dismissedOutings`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dismissedAssets = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedAssets) ?? []
        dismissedDays = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedDays) ?? []
        dismissedGames = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedGames) ?? []
        dismissedOutings = try c.decodeIfPresent([Outing].self, forKey: .dismissedOutings) ?? []
    }

    static func load(from url: URL) -> ReviewLedger {
        guard let data = try? Data(contentsOf: url) else { return .init() }
        return (try? JSONDecoder().decode(ReviewLedger.self, from: data)) ?? .init()
    }

    func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// One review across every pass: nothing already in the library, nothing the fan turned down, and nothing twice.
/// A visit is known by its photos: two passes that offer the same photos offer the same visit.
enum ReviewQueue {
    /// Photo library ids already on a saved game or visit.
    static func photos(in games: [GameEntry]) -> Set<String> {
        var out = Set<String>()
        for g in games {
            for ref in g.photos { if case .library(let id) = ref { out.insert(id) } }
        }
        return out
    }

    /// Photos that keep a game on the schedule out of the review: those of saved games, and of games the fan skipped. A saved
    /// stadium visit's photos don't: the game found for them is that visit's game, and confirming it turns the visit into it.
    static func gamePhotos(in games: [GameEntry], ledger: ReviewLedger) -> Set<String> {
        photos(in: games.filter { !$0.awaitsGame }).union(ledger.dismissedGames)
    }

    /// The days (in each ground's time zone) the library already has something at a ground, with the ground.
    private static func outings(_ games: [GameEntry], venues: [Venue]) -> [(venue: Venue, day: String)] {
        var keyer = DayKeyer()
        return games.compactMap { g in
            guard let v = venues.first(where: { $0.id == g.venueId }) else { return nil }
            return (v, keyer.day(g.date, tz: v.tz))
        }
    }

    /// The same outing: the same day at one ground or the one next door (`neighborMeters`: a stadium and its neighbour share a car park).
    private static func sameOuting(_ a: Venue, _ aDay: String, _ b: Venue, _ bDay: String, settings: ScanSettings) -> Bool {
        aDay == bDay && (a.id == b.id || a.location.distance(from: b.location) <= settings.neighborMeters)
    }

    /// The first pass, games then stadium visits. A visit at a game's ground (or the one next door) on the game's day is
    /// that game, the walk in past the ballpark: its photos join the game, which keeps its id (and its schedule match),
    /// instead of the day being asked about twice. Anything the library has or the fan turned down is left out, and so is a
    /// stadium visit on a day the library already has something at that ground or next door. (A game on such a day stays:
    /// two games next door to each other on one day are rare but real, and the scan already skips the library's ground-days.)
    /// A game whose photos are on a saved stadium visit stays too: the visit was saved before its game was found.
    static func firstPass(games: [PhotoCluster], others: [PhotoCluster], library: [GameEntry], venues: [Venue],
                          ledger: ReviewLedger, settings: ScanSettings = .current) -> (games: [PhotoCluster], others: [PhotoCluster]) {
        let taken = photos(in: library).union(ledger.dismissedAssets)
        let gameTaken = gamePhotos(in: library, ledger: ledger)
        let saved = outings(library, venues: venues)
        var keyer = DayKeyer()
        // What places a game or visit is the photos at the ground; the day's other photos ride along and say nothing about it
        // (BiH v Canada at BMO Field carried the Rogers Centre photos of a saved ballgame that evening).
        func placing(_ c: PhotoCluster) -> [String] { c.anchors.isEmpty ? c.assetIds : c.anchors }
        var kept = games.filter { !placing($0).contains(where: gameTaken.contains) }
        var visits: [PhotoCluster] = []
        for visit in others where !placing(visit).contains(where: taken.contains) {
            let day = keyer.day(visit.start, tz: visit.venue.tz)
            let ids = Set(visit.assetIds)
            if let at = kept.firstIndex(where: {
                $0.assetIds.contains(where: ids.contains)
                    || sameOuting($0.venue, keyer.day($0.start, tz: $0.venue.tz), visit.venue, day, settings: settings)
            }) {
                let merged = kept[at].combined(with: visit)
                kept[at] = PhotoCluster(id: kept[at].id, venue: kept[at].venue, start: merged.start, end: merged.end,
                                        assetIds: merged.assetIds, times: merged.times, insideIds: merged.insideIds)
            } else if saved.contains(where: { sameOuting($0.venue, $0.day, visit.venue, day, settings: settings) }) {
                continue
            } else if !visits.contains(where: { $0.assetIds.contains(where: ids.contains) }) {
                visits.append(visit)
            }
        }
        return (kept.sorted { $0.start > $1.start }, visits.sorted { $0.start > $1.start })
    }

    /// Possible games from any pass, newest first: none that share photos with a visit already up for review, one offered
    /// earlier in `days` (so the pass that found it first keeps it), the library, or a skip, and none from the same outing as
    /// something the fan turned down (within `skipWindowHours` of its photos, not the whole day).
    static func possible(_ days: [PossibleDay], alongside shown: [PhotoCluster], library: [GameEntry],
                         ledger: ReviewLedger, settings: ScanSettings = .current) -> [PossibleDay] {
        var taken = photos(in: library).union(ledger.dismissedAssets)
        for c in shown { taken.formUnion(c.assetIds) }
        var out: [PossibleDay] = []
        for day in days {
            guard !day.assetIds.contains(where: taken.contains), !ledger.skipped(at: day.day, settings: settings) else { continue }
            taken.formUnion(day.assetIds)
            out.append(day)
        }
        return out.sorted { $0.day > $1.day }
    }
}
