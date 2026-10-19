import Foundation
import CoreLocation

/// A stretch of photos with no location on a day the fan's other photos place them in one city with big stadiums: Federal
/// Way in the morning, Pike Place Market at night, and 118 photos with no location in between, the match at Lumen Field
/// among them. Nothing in those photos says where they were taken, so this is only ever a possible game, and only when the
/// schedule had a game in that city while they were taken and the photos themselves look like a stadium.
struct CityDay: Hashable, Sendable {
    /// The photos with no location, oldest first (no gap of more than an hour).
    let ids: [String]
    let times: [Date]
    /// The located photos that say where the fan was: just before, during and just after.
    let anchors: [PhotoPoint]
    /// The city's big stadiums whose schedules are asked, biggest first.
    let venues: [Venue]
    var start: Date { times.first ?? .distantPast }
    var end: Date { times.last ?? .distantPast }
    /// The biggest stadium's city ("Seattle").
    var city: String { venues.first?.city ?? "" }
}

enum CityDays {
    /// A stretch with no location: photos no more than an hour apart, at least five of them over at least half an hour.
    static let maxGap: TimeInterval = 3600
    static let minPhotos = 5
    static let minSpan: TimeInterval = 30 * 60
    /// The located photos before and after must be this close in time: the evening before or the next morning.
    static let anchorReach: TimeInterval = 12 * 3600
    /// One city: every located photo within this of every other, and of each stadium asked.
    static let metro: CLLocationDistance = 40_000
    /// Grounds with a crowd worth photographing; a high-school field with a schedule entry is not asked.
    static let minCapacity = 10_000
    static let maxVenues = 6
    /// Days looked up per scan, newest first: each asks a city's schedules, and a game in the window costs a scene check.
    static let maxDays = 12
    /// A game's window: from an hour before kickoff to three and a half hours after.
    static let before: TimeInterval = 3600
    static let after: TimeInterval = 3.5 * 3600
    /// Photos looked at per day, from the game's window.
    static let sample = 16

    /// Pure: the stretches worth asking about. `taken` holds the photos a visit or a day around a stadium already has; a stretch
    /// near anything the library has saved (a game, a visit) is left alone, since that day is accounted for.
    static func candidates(_ points: [PhotoPoint], venues: [Venue], taken: Set<String>, existing: [GameEntry]) -> [CityDay] {
        let located = located(points)
        let big = bigGrounds(venues)
        var out: [CityDay] = []
        for run in runs(points, taken: taken).reversed() {
            guard out.count < maxDays, case .day(let day) = judge(run, located: located, grounds: big, existing: existing) else { continue }
            out.append(day)
        }
        return out
    }

    static func located(_ points: [PhotoPoint]) -> [PhotoPoint] {
        points.filter { $0.date != nil && $0.latitude != nil && $0.longitude != nil }.sorted { $0.date! < $1.date! }
    }

    static func bigGrounds(_ venues: [Venue]) -> [Venue] {
        venues.filter { ($0.capacity ?? 0) >= minCapacity && $0.closed == nil && !GameLookup.leagues(for: $0).isEmpty }
    }

    /// Pure: the photos with no location (screenshots and photos a visit has left out), in stretches with no gap over an hour.
    static func runs(_ points: [PhotoPoint], taken: Set<String>) -> [[PhotoPoint]] {
        let loose = points.filter { $0.date != nil && $0.latitude == nil && !$0.screenshot && !taken.contains($0.id) }
            .sorted { $0.date! < $1.date! }
        var runs: [[PhotoPoint]] = []
        for p in loose {
            if let last = runs.last?.last?.date, p.date!.timeIntervalSince(last) <= maxGap { runs[runs.count - 1].append(p) } else { runs.append([p]) }
        }
        return runs
    }

    /// What one stretch is: a day to ask the city's schedules about, or why not (for the scan check).
    enum Verdict: Equatable {
        case day(CityDay)
        case tooFew, saved, noAnchors, spread, noGrounds([PhotoPoint])

        var why: String {
            switch self {
            case .day: "asked"
            case .tooFew: "fewer than \(CityDays.minPhotos) photos or under \(Int(CityDays.minSpan / 60)) min"
            case .saved: "something is saved then"
            case .noAnchors: "no located photo during it, nor one within 12 h both before and after"
            case .spread: "the located photos around it are more than \(Int(CityDays.metro / 1000)) km apart"
            case .noGrounds: "no stadium of \(CityDays.minCapacity / 1000)k+ within \(Int(CityDays.metro / 1000)) km of every located photo"
            }
        }
    }

    static func judge(_ run: [PhotoPoint], located: [PhotoPoint], grounds big: [Venue], existing: [GameEntry]) -> Verdict {
        guard run.count >= minPhotos, let start = run.first?.date, let end = run.last?.date,
              end.timeIntervalSince(start) >= minSpan else { return .tooFew }
        if existing.contains(where: { $0.date >= start.addingTimeInterval(-4 * 3600) && $0.date <= end.addingTimeInterval(2 * 3600) }) {
            return .saved
        }
        guard let anchors = anchors(for: start...end, in: located) else {
            return nearby(start...end, in: located).isEmpty ? .noAnchors : .spread
        }
        let spots = anchors.map { CLLocation(latitude: $0.latitude!, longitude: $0.longitude!) }
        let grounds = big.filter { v in spots.allSatisfy { $0.distance(from: v.location) <= metro } }
            .sorted { ($0.capacity ?? 0) > ($1.capacity ?? 0) }
        guard !grounds.isEmpty else { return .noGrounds(anchors) }
        return .day(CityDay(ids: run.map(\.id), times: run.compactMap(\.date), anchors: anchors, venues: Array(grounds.prefix(maxVenues))))
    }

    /// The located photos that would anchor a span, before the one-city check.
    private static func nearby(_ span: ClosedRange<Date>, in located: [PhotoPoint]) -> [PhotoPoint] {
        let during = located.filter { span.contains($0.date!) }
        let before = located.last { $0.date! < span.lowerBound && span.lowerBound.timeIntervalSince($0.date!) <= anchorReach }
        let after = located.first { $0.date! > span.upperBound && $0.date!.timeIntervalSince(span.upperBound) <= anchorReach }
        return !during.isEmpty || (before != nil && after != nil) ? [before].compactMap { $0 } + during + [after].compactMap { $0 } : []
    }

    /// Pure: where the fan was during `span`, from located photos: those taken during it, else the last one before and the first
    /// one after (both needed, each within twelve hours). Nil when there are none, or they are not all in one city.
    static func anchors(for span: ClosedRange<Date>, in located: [PhotoPoint]) -> [PhotoPoint]? {
        let anchors = nearby(span, in: located)
        guard !anchors.isEmpty else { return nil }
        let spots = anchors.map { CLLocation(latitude: $0.latitude!, longitude: $0.longitude!) }
        for a in spots { for b in spots where a.distance(from: b) > metro { return nil } }
        return anchors
    }

    /// Pure: the photos of the stretch in a game's window, when they make a real stay (five or more, over half an hour).
    static func inWindow(_ day: CityDay, kickoff: Date) -> [Int]? {
        let at = day.times.indices.filter { day.times[$0] >= kickoff.addingTimeInterval(-before) && day.times[$0] <= kickoff.addingTimeInterval(after) }
        guard at.count >= minPhotos, let first = at.first, let last = at.last,
              day.times[last].timeIntervalSince(day.times[first]) >= minSpan else { return nil }
        return at
    }

    /// Pure: the photos look like a stadium. Stricter than a stadium visit's check, since nothing else places these photos:
    /// three or more of the sample show a stadium, arena, scoreboard or sport, at least 30% of those classified; two show the
    /// ground itself (a stadium, a scoreboard, the stands), not just a ball or a pitch; and under a quarter look like a bar,
    /// a meal or a home (a match on a pub's TV).
    static func looksLikeTheGround(_ look: SceneCheck.DayLook) -> Bool {
        look.venue >= 3 && look.venueShare >= 0.3 && look.structure >= 2 && look.elsewhereShare < 0.25
    }

    struct Fit: Hashable {
        let game: FoundGame
        let venue: Venue
        let photos: [Int]
    }

    struct Evaluation {
        let day: CityDay
        /// Every game at the city's stadiums around the stretch, with the photos in its window (empty when they make no stay).
        var games: [Fit] = []
        /// The games that fit best (the most photos in the window), up to three.
        var best: [Fit] = []
        var look: SceneCheck.DayLook?
        var offer: PossibleDay?
    }

    /// Asks the city's schedules, then looks at the photos only if a game fits.
    static func evaluate(_ day: CityDay, look see: ([PhotoRef]) async -> SceneCheck.DayLook) async -> Evaluation {
        var eval = Evaluation(day: day)
        var seen = Set<String>()
        for venue in day.venues {
            if Task.isCancelled { return eval }
            // Kickoffs from five hours before the first photo to an hour after the last: every window the photos can be in.
            for game in await GameLookup.games(at: venue, from: day.start, to: day.end) where seen.insert(game.id).inserted {
                // The ground the schedule names (a World Cup game matches every soccer ground in the city by its city).
                let at = GameLookup.venue(of: game, in: day.venues) ?? venue
                eval.games.append(Fit(game: game, venue: at, photos: inWindow(day, kickoff: game.start) ?? []))
            }
        }
        let fitting = eval.games.filter { !$0.photos.isEmpty }.sorted { $0.photos.count > $1.photos.count }
        guard let top = fitting.first else { return eval }
        // Two games in the city at once (a ballgame and a match): the ones whose window holds nearly as many photos are offered too.
        eval.best = Array(fitting.filter { Double($0.photos.count) >= Double(top.photos.count) * 0.8 }.prefix(3))
        let ids = top.photos.map { day.ids[$0] }
        let step = max(1, ids.count / sample)
        let picked = stride(from: 0, to: ids.count, by: step).prefix(sample).map { PhotoRef.library(ids[$0]) }
        let look = await see(picked)
        eval.look = look
        guard looksLikeTheGround(look) else { return eval }
        let times = top.photos.map { day.times[$0] }
        let what = top.game.race == nil && !top.game.home.name.isEmpty
            ? "\(top.game.away.name) at \(top.game.home.name) at \(top.venue.name)" : "a game at \(top.venue.name)"
        var grounds: [Venue] = []
        for fit in eval.best where !grounds.contains(where: { $0.id == fit.venue.id }) { grounds.append(fit.venue) }
        let also = grounds.count > 1 ? " (or \(grounds.dropFirst().map(\.name).joined(separator: ", ")), on at the same time)" : ""
        eval.offer = PossibleDay(id: "possible-city-\(top.game.id)", day: times[times.count / 2], assetIds: ids, times: times,
                                 reason: "Photos with no location, on a day you were in \(day.city), during \(what)\(also)",
                                 suggestions: grounds)
        return eval
    }
}
