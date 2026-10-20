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

/// The numbers come from `ScanSettings`: a stretch is photos no more than `cityGapMinutes` apart, at least `cityPhotos` of
/// them over `citySpanMinutes`; the located photos before and after must be within `cityAnchorHours` (the evening before or
/// the next morning); one city is every located photo within `cityMetroMeters` of every other and of each stadium asked;
/// only grounds of `cityMinCapacity`+ (a crowd worth photographing; a high-school field with a schedule entry is not asked),
/// at most `cityMaxVenues`; `cityMaxDays` days per scan, newest first (each asks a city's schedules, and a game in the window
/// costs a scene check); a game's window runs from `cityBeforeMinutes` before kickoff to `cityAfterMinutes` after; `citySample`
/// photos are looked at per day.
enum CityDays {
    /// Pure: the stretches worth asking about. `taken` holds the photos a visit or a day around a stadium already has; a stretch
    /// near anything the library has saved (a game, a visit) is left alone, since that day is accounted for.
    static func candidates(_ points: [PhotoPoint], venues: [Venue], taken: Set<String>, existing: [GameEntry],
                           settings: ScanSettings = .current) -> [CityDay] {
        let located = located(points)
        let big = bigGrounds(venues, settings: settings)
        var out: [CityDay] = []
        for run in runs(points, taken: taken, settings: settings).reversed() {
            guard out.count < settings.cityMaxDays,
                  case .day(let day) = judge(run, located: located, grounds: big, existing: existing, settings: settings) else { continue }
            out.append(day)
        }
        return out
    }

    static func located(_ points: [PhotoPoint]) -> [PhotoPoint] {
        points.filter { $0.date != nil && $0.latitude != nil && $0.longitude != nil }.sorted { $0.date! < $1.date! }
    }

    static func bigGrounds(_ venues: [Venue], settings: ScanSettings = .current) -> [Venue] {
        venues.filter { ($0.capacity ?? 0) >= settings.cityMinCapacity && $0.closed == nil && !GameLookup.leagues(for: $0).isEmpty }
    }

    /// Pure: the photos with no location (screenshots and photos a visit has left out), in stretches with no gap over `cityGapMinutes`.
    static func runs(_ points: [PhotoPoint], taken: Set<String>, settings: ScanSettings = .current) -> [[PhotoPoint]] {
        let loose = points.filter { $0.date != nil && $0.latitude == nil && !$0.screenshot && !taken.contains($0.id) }
            .sorted { $0.date! < $1.date! }
        let gap = settings.cityGapMinutes * 60
        var runs: [[PhotoPoint]] = []
        for p in loose {
            if let last = runs.last?.last?.date, p.date!.timeIntervalSince(last) <= gap { runs[runs.count - 1].append(p) } else { runs.append([p]) }
        }
        return runs
    }

    /// What one stretch is: a day to ask the city's schedules about, or why not (for the scan check).
    enum Verdict: Equatable {
        case day(CityDay)
        case tooFew, saved, noAnchors, spread, noGrounds([PhotoPoint])

        func why(_ settings: ScanSettings = .current) -> String {
            switch self {
            case .day: "asked"
            case .tooFew: "fewer than \(settings.cityPhotos) photos or under \(Int(settings.citySpanMinutes)) min"
            case .saved: "something is saved then"
            case .noAnchors: "no located photo during it, nor one within \(Int(settings.cityAnchorHours)) h both before and after"
            case .spread: "the located photos around it are more than \(Int(settings.cityMetroMeters / 1000)) km apart"
            case .noGrounds: "no stadium of \(settings.cityMinCapacity / 1000)k+ within \(Int(settings.cityMetroMeters / 1000)) km of every located photo"
            }
        }
    }

    static func judge(_ run: [PhotoPoint], located: [PhotoPoint], grounds big: [Venue], existing: [GameEntry],
                      settings: ScanSettings = .current) -> Verdict {
        guard run.count >= settings.cityPhotos, let start = run.first?.date, let end = run.last?.date,
              end.timeIntervalSince(start) >= settings.citySpanMinutes * 60 else { return .tooFew }
        if existing.contains(where: {
            $0.date >= start.addingTimeInterval(-settings.citySavedBeforeHours * 3600) && $0.date <= end.addingTimeInterval(settings.citySavedAfterHours * 3600)
        }) {
            return .saved
        }
        guard let anchors = anchors(for: start...end, in: located, settings: settings) else {
            return nearby(start...end, in: located, settings: settings).isEmpty ? .noAnchors : .spread
        }
        let spots = anchors.map { CLLocation(latitude: $0.latitude!, longitude: $0.longitude!) }
        let grounds = big.filter { v in spots.allSatisfy { $0.distance(from: v.location) <= settings.cityMetroMeters } }
            .sorted { ($0.capacity ?? 0) > ($1.capacity ?? 0) }
        guard !grounds.isEmpty else { return .noGrounds(anchors) }
        return .day(CityDay(ids: run.map(\.id), times: run.compactMap(\.date), anchors: anchors, venues: Array(grounds.prefix(settings.cityMaxVenues))))
    }

    /// The located photos that would anchor a span, before the one-city check.
    private static func nearby(_ span: ClosedRange<Date>, in located: [PhotoPoint], settings: ScanSettings) -> [PhotoPoint] {
        let reach = settings.cityAnchorHours * 3600
        let during = located.filter { span.contains($0.date!) }
        let before = located.last { $0.date! < span.lowerBound && span.lowerBound.timeIntervalSince($0.date!) <= reach }
        let after = located.first { $0.date! > span.upperBound && $0.date!.timeIntervalSince(span.upperBound) <= reach }
        return !during.isEmpty || (before != nil && after != nil) ? [before].compactMap { $0 } + during + [after].compactMap { $0 } : []
    }

    /// Pure: where the fan was during `span`, from located photos: those taken during it, else the last one before and the first
    /// one after (both needed, each within `cityAnchorHours`). Nil when there are none, or they are not all in one city.
    static func anchors(for span: ClosedRange<Date>, in located: [PhotoPoint], settings: ScanSettings = .current) -> [PhotoPoint]? {
        let anchors = nearby(span, in: located, settings: settings)
        guard !anchors.isEmpty else { return nil }
        let spots = anchors.map { CLLocation(latitude: $0.latitude!, longitude: $0.longitude!) }
        for a in spots { for b in spots where a.distance(from: b) > settings.cityMetroMeters { return nil } }
        return anchors
    }

    /// Pure: the photos of the stretch in a game's window, when they make a real stay (`cityPhotos` or more, over `citySpanMinutes`).
    static func inWindow(_ day: CityDay, kickoff: Date, settings: ScanSettings = .current) -> [Int]? {
        let from = kickoff.addingTimeInterval(-settings.cityBeforeMinutes * 60), to = kickoff.addingTimeInterval(settings.cityAfterMinutes * 60)
        let at = day.times.indices.filter { day.times[$0] >= from && day.times[$0] <= to }
        guard at.count >= settings.cityPhotos, let first = at.first, let last = at.last,
              day.times[last].timeIntervalSince(day.times[first]) >= settings.citySpanMinutes * 60 else { return nil }
        return at
    }

    /// Pure: the photos look like a stadium. Stricter than a stadium visit's check, since nothing else places these photos:
    /// `cityMinVenue` or more of the sample show a stadium, arena, scoreboard or sport, at least `cityVenueShare` of those
    /// classified; `cityMinStructure` show the ground itself (a stadium, a scoreboard, the stands), not just a ball or a pitch;
    /// and under `cityElsewhereShare` look like a bar, a meal or a home (a match on a pub's TV).
    static func looksLikeTheGround(_ look: SceneCheck.DayLook, settings: ScanSettings = .current) -> Bool {
        look.venue >= settings.cityMinVenue && look.venueShare >= settings.cityVenueShare
            && look.structure >= settings.cityMinStructure && look.elsewhereShare < settings.cityElsewhereShare
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
    static func evaluate(_ day: CityDay, look see: ([PhotoRef]) async -> SceneCheck.DayLook,
                         settings: ScanSettings = .current) async -> Evaluation {
        var eval = Evaluation(day: day)
        var seen = Set<String>()
        for venue in day.venues {
            if Task.isCancelled { return eval }
            // Kickoffs from `scheduleBeforeHours` before the first photo to `scheduleAfterHours` after the last: every window the photos can be in.
            for game in await GameLookup.games(at: venue, from: day.start, to: day.end, settings: settings) where seen.insert(game.id).inserted {
                // The ground the schedule names (a World Cup game matches every soccer ground in the city by its city).
                let at = GameLookup.venue(of: game, in: day.venues) ?? venue
                eval.games.append(Fit(game: game, venue: at, photos: inWindow(day, kickoff: game.start, settings: settings) ?? []))
            }
        }
        let fitting = eval.games.filter { !$0.photos.isEmpty }.sorted { $0.photos.count > $1.photos.count }
        guard let top = fitting.first else { return eval }
        // Two games in the city at once (a ballgame and a match): the ones whose window holds nearly as many photos are offered too.
        eval.best = Array(fitting.filter { Double($0.photos.count) >= Double(top.photos.count) * 0.8 }.prefix(3))
        let ids = top.photos.map { day.ids[$0] }
        let sample = settings.citySample
        let step = max(1, ids.count / sample)
        let picked = stride(from: 0, to: ids.count, by: step).prefix(sample).map { PhotoRef.library(ids[$0]) }
        let look = await see(picked)
        eval.look = look
        guard looksLikeTheGround(look, settings: settings) else { return eval }
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
