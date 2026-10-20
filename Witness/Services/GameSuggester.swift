import Foundation
import CoreLocation

/// A day of photos that might be a game, where the stadium is not known. The fan picks the stadium, then the photos' date
/// finds the game there (or says there was none).
struct PossibleDay: Identifiable, Hashable {
    let id: String
    let day: Date
    let assetIds: [String]
    let times: [Date]
    /// Why it is worth asking about: an album name, a trip, photos that look like a game.
    let reason: String
    /// Stadiums to offer first: the home grounds of a team the album names, the stadiums near a trip.
    var suggestions: [Venue] = []
}

/// Looks past the photos that carry a stadium location: albums the fan made, trips, and days with no location at all.
/// Nothing here is added on its own: a scoreboard could be a kid's game, so every day is only a possible game and the fan picks the stadium.
enum GameSuggester {
    /// Where a search is: the stadium visits with no game on the schedule, reading the albums and trips, keeping the ones
    /// with stadium photos, then looking at each day.
    enum Step: Int, Sendable { case visits, reading, sorting, days }

    /// Pure: an album the fan keeps adding to over months ("Favorites", "Family", "2019") is a collection, not a day out.
    /// The middle 80% of its `collectionPhotos`+ photos must fall within `collectionDays`, unless the title is about sport
    /// (`sportTitleWords`: "Baseball", "Cubs games" are read even when they run for months).
    static func isCollection(_ dates: [Date], title: String, settings: ScanSettings = .current) -> Bool {
        let words = Set(fold(title).split(separator: " ").map(String.init))
        guard words.isDisjoint(with: settings.sportTitleWords), dates.count >= settings.collectionPhotos else { return false }
        let sorted = dates.sorted()
        let low = sorted[sorted.count / 10], high = sorted[sorted.count - 1 - sorted.count / 10]
        return high.timeIntervalSince(low) > settings.collectionDays * 86_400
    }

    /// When a day's photos were taken: its busiest stretch of up to `outingWindowHours`.
    struct DayShape: Hashable {
        /// First and last photo of the busiest stretch.
        let first: Date
        let last: Date
        let inside: Int
        let total: Int

        /// Pure: the stretch of up to `outingWindowHours` holding the most photos.
        static func of(_ times: [Date], settings: ScanSettings = .current) -> DayShape? {
            let t = times.sorted()
            guard !t.isEmpty else { return nil }
            let window = settings.outingWindowHours * 3600
            var best = (0, 0), j = 0
            for i in t.indices {
                j = max(j, i)
                while j + 1 < t.count && t[j + 1].timeIntervalSince(t[i]) <= window { j += 1 }
                if j - i > best.1 - best.0 { best = (i, j) }
            }
            return DayShape(first: t[best.0], last: t[best.1], inside: best.1 - best.0 + 1, total: t.count)
        }

        /// Most of the day in one stretch, long enough to be at a game: not photos from morning to night, nor a two-minute burst
        /// (`outingPhotos` photos, `outingShare` of the day's, over `outingMinutes`).
        var looksLikeAnOuting: Bool { looksLikeAnOuting(.current) }
        func looksLikeAnOuting(_ settings: ScanSettings) -> Bool {
            inside >= settings.outingPhotos && Double(inside) >= Double(total) * settings.outingShare
                && last.timeIntervalSince(first) >= settings.outingMinutes * 60
        }
        /// A game that started then was on while the busiest photos were taken (from `outingBeforeHours` before the first to
        /// `outingAfterHours` after the last).
        func covers(_ start: Date, settings: ScanSettings = .current) -> Bool {
            start >= first.addingTimeInterval(-settings.outingBeforeHours * 3600) && start <= last.addingTimeInterval(settings.outingAfterHours * 3600)
        }
        /// An evening or a weekend, when most games are played.
        func isPrime(_ calendar: Calendar = .current) -> Bool {
            calendar.isDateInWeekend(first) || calendar.component(.hour, from: last) >= 17
        }
    }

    /// Where a day's photos with a location say the fan was.
    enum Whereabouts: Equatable {
        /// Most photos carry a location and none is near a stadium. A phone inside a stadium places its photos there, so these
        /// days are not games.
        case elsewhere
        /// Some photos are near these stadiums (nearest first).
        case near([Venue])
        /// Too few photos carry a location to say.
        case unknown
    }

    /// Pure: what the located photos of a day say. A photo within `suggestReachMeters` of a stadium could be a game whose fix
    /// drifted; farther, the fan was somewhere else.
    static func whereabouts(_ located: [CLLocation], total: Int, index: VenueIndex, settings: ScanSettings = .current) -> Whereabouts {
        var near: [Venue: CLLocationDistance] = [:]
        for p in located {
            guard let v = index.nearest(lat: p.coordinate.latitude, lon: p.coordinate.longitude, radius: settings.suggestReachMeters) else { continue }
            near[v] = min(near[v] ?? .infinity, p.distance(from: v.location))
        }
        if !near.isEmpty { return .near(Array(near.sorted { $0.value < $1.value }.map(\.key).prefix(3))) }
        return located.count >= 2 && Double(located.count) >= Double(total) * 0.5 ? .elsewhere : .unknown
    }

    /// What the schedules say about the stadiums a day could be at.
    enum Schedule {
        /// A game whose time fits the photos. `specific` when the stadium came from the photos' location or the album's title,
        /// not just the trip's or the fan's city, where some game is on most nights.
        case game(FoundGame, Venue, specific: Bool)
        /// The schedules cover these stadiums and none had a game then.
        case none
        /// No stadium to check, or none whose schedule is known.
        case unknown
    }

    /// Pure: how sure the day is, or nil when it is not offered. The schedule decides first: a day with no game at any stadium
    /// it could be at is dropped, whatever the photos look like. Then the photos have to agree, more of them the less the
    /// schedule and the title say.
    static func confidence(look: SceneCheck.DayLook, shape: DayShape, schedule: Schedule, titled: Bool,
                           calendar: Calendar = .current) -> Double? {
        guard shape.looksLikeAnOuting, look.classified > 0 else { return nil }
        let base: Double
        switch schedule {
        case .none:
            return nil
        case .game(_, _, let specific) where specific:
            let ok = titled ? look.venue >= 1 && look.elsewhereShare < 0.5
                            : look.venue >= 2 && look.venueShare >= 0.15 && look.elsewhereShare < 0.35
            guard ok else { return nil }
            base = 2
        case .game:
            guard look.isGame(), look.structure >= 1 else { return nil }
            base = 1.5
        case .unknown:
            let ok = titled ? look.isGame() && look.structure >= 1
                            : look.venue >= 4 && look.venueShare >= 0.5 && look.structure >= 2 && look.elsewhereShare < 0.15
            guard ok else { return nil }
            base = 1
        }
        let structureShare = Double(look.structure) / Double(look.classified)
        return base + (titled ? 0.5 : 0) + look.venueShare + structureShare * 0.5 - look.elsewhereShare + (shape.isPrime(calendar) ? 0.2 : 0)
    }

    /// The first game at these stadiums whose time fits the photos, from the downloaded seasons or the schedules. Each stadium's
    /// neighbours in `venues` are asked too (photos placed at T-Mobile Park on a World Cup day were at Lumen Field, 440 m away).
    static func scheduled(at candidates: [Venue], shape: DayShape, specific: Bool, venues: [Venue] = [],
                          settings: ScanSettings = .current) async -> Schedule {
        var grounds: [Venue] = []
        for venue in candidates {
            for v in [venue] + PhotoMatcher.neighbors(of: venue, in: venues, settings: settings) where !grounds.contains(where: { $0.id == v.id }) {
                grounds.append(v)
            }
        }
        let checkable = grounds.filter { !GameLookup.leagues(for: $0).isEmpty || $0.sports.contains(.motorsport) }
        guard !checkable.isEmpty else { return .unknown }
        for venue in checkable {
            if Task.isCancelled { return .unknown }
            let games = await GameLookup.games(at: venue, from: shape.first, to: shape.last, settings: settings)
            if let game = games.first(where: { shape.covers($0.start, settings: settings) }) { return .game(game, venue, specific: specific) }
        }
        // Only a stadium the photos or the title point at can rule a day out. Checking the fan's home stadiums finds
        // nothing for a game abroad or at a ground the schedules miss, and that is no reason to drop it.
        return specific ? .none : .unknown
    }

    /// Pure: whether an album's title names an app or a system collection rather than an occasion (`appAlbums`: albums that
    /// apps and the system make, saved from Instagram, WhatsApp, screenshots, are never a day out).
    static func isAppAlbum(_ title: String, settings: ScanSettings = .current) -> Bool {
        let t = fold(title)
        let words = Set(t.split(separator: " ").map(String.init))
        return settings.appAlbums.contains { app in app.contains(" ") ? t.contains(app) : words.contains { $0 == app || $0 == app + "s" } }
    }

    /// Pure: the days worth a look. Enough photos (`suggestMinPhotos`), none the library already covers, newest first.
    static func candidates(_ piles: [DayPile], skipping claimed: Set<String>, settings: ScanSettings = .current) -> [DayPile] {
        piles.filter { $0.assetIds.count >= settings.suggestMinPhotos && !claimed.contains($0.id) }.sorted { $0.day > $1.day }
    }

    /// Pure: the stadiums an album's title points at: a team's home ground ("Cubs game"), or a stadium named outright ("Wrigley 2019").
    static func venues(named title: String, teams: [Team], venues: [Venue], lookup: (String) -> Venue?) -> [Venue] {
        let words = Set(fold(title).split(separator: " ").map(String.init))
        guard !words.isEmpty else { return [] }
        var out: [Venue] = []
        func add(_ v: Venue?) { if let v, !out.contains(where: { $0.id == v.id }) { out.append(v) } }
        var byTeam: [Venue] = []
        // A matchup title ("BiH v Qatar", "Cubs vs Cards", "CHI @ GB") may name a side by its code.
        let matchup = words.contains("v") || words.contains("vs") || title.contains("@")
        for team in teams {
            let name = fold(team.teamName).split(separator: " ").map(String.init)
            let city = fold(team.locationName).split(separator: " ").map(String.init)
            let code = fold(team.abbreviation)
            // "Cubs" alone is enough only when the nickname is a distinctive word; "Chicago Bears" matches on city plus name.
            guard !name.isEmpty, name.allSatisfy({ $0.count >= 4 && words.contains($0) }) || (!city.isEmpty && Set(city + name).isSubset(of: words))
                || (matchup && code.count >= 3 && words.contains(code))
            else { continue }
            if let home = team.homeVenueId.flatMap(lookup) {
                byTeam.append(home)
            } else {
                let full = fold(team.locationName + " " + team.teamName)
                byTeam += venues.filter { v in (v.homeTeams ?? []).contains { fold($0) == full } }
            }
        }
        // The biggest ground first: the Cubs album is about Wrigley, not a minor-league namesake.
        for v in byTeam.sorted(by: { ($0.capacity ?? 0) > ($1.capacity ?? 0) }) { add(v); if out.count >= 3 { return out } }
        for venue in venues {
            let name = fold(venue.name).split(separator: " ").map(String.init).filter { !["stadium", "field", "park", "arena", "center", "centre"].contains($0) }
            if let first = name.first, first.count >= 5, name.allSatisfy({ words.contains($0) }) { add(venue) }
            if out.count >= 3 { break }
        }
        return out
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private struct Source {
        let reason: String
        let points: [PhotoPoint]
        let hints: [Venue]
        /// The title names a team or stadium, which is evidence on its own. A trip's nearby stadiums are not.
        var titled = false
        /// The fan's album behind it (nil for a trip).
        var album: PhotoAlbum? = nil
    }

    /// How a game's teams read in a reason: "Cardinals at Cubs", or the stadium when the schedule has no sides (a race).
    static func describe(_ game: FoundGame, at venue: Venue) -> String {
        guard game.race == nil, !game.home.name.isEmpty, !game.away.name.isEmpty else { return "a game at \(venue.name) that day" }
        return "\(game.away.name) at \(game.home.name), \(venue.name), that day"
    }

    /// The days that are only possible games.
    /// `claimed` holds "yyyy-MM-dd" days a visit or a saved game already covers.
    static func find(venues: [Venue], teams: [Team], home: CLLocation, hasHome: Bool, claimed: Set<String>,
                     progress: @escaping @MainActor (_ step: Step, _ done: Int, _ total: Int) -> Void) async -> [PossibleDay] {
        let settings = ScanSettings.current
        // Everything that touches the photo library runs off the main thread.
        let sources: [Source] = await Task.detached(priority: .utility) {
            var out: [Source] = []
            let albums = Array(AlbumImporter.albums()
                .filter { $0.count >= settings.suggestMinPhotos && $0.count <= settings.albumMaxPhotos && !isAppAlbum($0.title, settings: settings) }
                .prefix(settings.suggestMaxAlbums))
            for (n, album) in albums.enumerated() {
                Task { @MainActor in progress(.reading, n, albums.count) }
                let hints = Self.venues(named: album.title, teams: teams, venues: venues) { id in venues.first { $0.id == id } }
                let points = AlbumImporter.points(in: album)
                // "Favorites", "Family", "2019": an album that runs for months is a collection, not a day out.
                if hints.isEmpty && isCollection(points.compactMap(\.date), title: album.title, settings: settings) { continue }
                out.append(Source(reason: "In your album \u{201C}\(album.title)\u{201D}", points: points, hints: hints, titled: !hints.isEmpty,
                                  album: album))
            }
            if hasHome {
                for trip in TripFinder.find(home: home, venues: venues).prefix(settings.tripMaxCount) {
                    let points = AlbumImporter.points(in: trip)
                    let located = points.compactMap { p in p.latitude.flatMap { la in p.longitude.map { CLLocation(latitude: la, longitude: $0) } } }
                    var near: [Venue] = []
                    if !located.isEmpty {
                        let lat = located.map { $0.coordinate.latitude }.reduce(0, +) / Double(located.count)
                        let lon = located.map { $0.coordinate.longitude }.reduce(0, +) / Double(located.count)
                        let center = CLLocation(latitude: lat, longitude: lon)
                        near = Array(venues.filter { ($0.capacity ?? 0) >= settings.suggestVenueCapacity && $0.location.distance(from: center) < settings.tripReachMeters }
                            .sorted { $0.location.distance(from: center) < $1.location.distance(from: center) }.prefix(3))
                    }
                    out.append(Source(reason: "On your \(trip.title.lowercased())", points: points, hints: near))
                }
            }
            return out
        }.value

        // The stadiums near home, for days with no location and no title: the fan's most likely grounds.
        let local: [Venue] = hasHome
            ? Array(venues.filter { ($0.capacity ?? 0) >= settings.suggestVenueCapacity && $0.closed == nil && $0.location.distance(from: home) < settings.homeReachMeters }
                .sorted { ($0.capacity ?? 0) > ($1.capacity ?? 0) }.prefix(settings.homeVenues))
            : []
        let index = VenueIndex(venues, settings: settings)

        // An album titled for a game ("BiH v Qatar") names both sides: the schedule is asked for a game between them on the
        // photos' dates, in every competition they play, and the stadium comes from the schedule. National sides have no home
        // ground, so before this the title pointed at no stadium, the album counted as untitled, and only the fan's home
        // stadiums were asked: a World Cup game abroad was never found.
        var possible: [(PossibleDay, Double)] = []
        var claimed = claimed
        var keyer = DayKeyer()
        let reader = MatchupAlbums.Reader(teams: teams, settings: settings)
        for source in sources {
            guard let album = source.album else { continue }
            let parsed = reader.parse(album.title)
            guard parsed.isMatchup else { continue }
            for day in await MatchupAlbums.check(album, points: source.points, parsed: parsed, venues: venues, existing: [], settings: settings).days
            where !claimed.contains(keyer.day(day.day, tz: .current)) {
                claimed.formUnion(day.times.map { keyer.day($0, tz: .current) })
                possible.append((day, 10))
            }
        }

        // The unplaced days of every source, then the cheapest filter first: only days that look like a game are kept. A day
        // is looked at once per source: an album that fails on a day does not keep the trip from looking at it.
        var work: [(DayPile, Source)] = []
        var queued = Set<String>()
        for (n, source) in sources.enumerated() {
            await progress(.sorting, n, sources.count)
            // An album or trip counts only if some of its photos show a stadium, arena, scoreboard or sport (or its title names
            // a team or stadium). A crowd alone is a wedding, a party or a school event.
            if !source.titled {
                let look = await SceneCheck.look(at: source.points.map { PhotoRef.library($0.id) }, max: settings.sourceLookPhotos, settings: settings)
                guard look.isGame(minVenue: settings.sourceLookMinVenue, minShare: settings.sourceLookMinShare, settings: settings) else { continue }
            }
            let scan = await Task.detached { VisitGrouping.group(source.points, venues: venues, settings: settings) }.value
            for pile in candidates(scan.unplacedDays, skipping: claimed, settings: settings) where queued.insert("\(n)|\(pile.id)").inserted {
                work.append((pile, source))
            }
        }
        work = Array(work.sorted { $0.0.day > $1.0.day }.prefix(settings.suggestMaxDays))
        await progress(.days, 0, work.count)

        for (n, (pile, source)) in work.enumerated() {
            defer { Task { await progress(.days, n + 1, work.count) } }
            if Task.isCancelled { break }
            // Cheapest first. The time shape: most photos in one stretch of a few hours.
            guard let shape = DayShape.of(pile.times, settings: settings), shape.looksLikeAnOuting(settings) else { continue }
            // The place: a phone inside a stadium places its photos there, so a day whose photos mostly carry a location
            // far from every stadium was spent somewhere else.
            let ids = Set(pile.assetIds)
            let located = source.points.filter { ids.contains($0.id) }
                .compactMap { p in p.latitude.flatMap { la in p.longitude.map { CLLocation(latitude: la, longitude: $0) } } }
            let place = whereabouts(located, total: pile.assetIds.count, index: index, settings: settings)
            if place == .elsewhere { continue }

            // The photos of the busiest stretch, most of them looked at (no time pressure here).
            let busy = zip(pile.assetIds, pile.times).filter { $0.1 >= shape.first && $0.1 <= shape.last }.map(\.0)
            let look = await SceneCheck.look(at: busy.map { PhotoRef.library($0) }, max: settings.dayLookPhotos, settings: settings)
            // Not worth asking the schedules about a day the photos already rule out.
            guard look.venue >= 1, !look.mostlyElsewhere(settings) else { continue }

            // The schedule: some stadium the day could be at had a game while the photos were taken.
            let schedule: Schedule
            if case .near(let near) = place {
                schedule = await scheduled(at: near, shape: shape, specific: true, venues: venues, settings: settings)
            } else if source.titled {
                schedule = await scheduled(at: source.hints, shape: shape, specific: true, venues: venues, settings: settings)
            } else {
                schedule = await scheduled(at: source.hints.isEmpty ? local : source.hints, shape: shape, specific: false, settings: settings)
            }
            guard let score = confidence(look: look, shape: shape, schedule: schedule, titled: source.titled) else { continue }

            var suggestions = source.hints
            var why = "\(look.venue) of \(look.classified) photos show a game"
            if case .game(let game, let venue, _) = schedule {
                suggestions = [venue] + suggestions.filter { $0.id != venue.id }
                why = describe(game, at: venue)
            } else if case .near(let near) = place {
                suggestions = near + suggestions.filter { v in !near.contains { $0.id == v.id } }
            }
            let middle = pile.times.sorted()[pile.times.count / 2]
            possible.append((PossibleDay(id: "possible-" + pile.id, day: middle, assetIds: pile.assetIds, times: pile.times,
                                         reason: "\(source.reason) \u{00B7} \(why)", suggestions: Array(suggestions.prefix(3))), score))
        }
        // The surest handful, newest first, each day once (the album or the trip, whichever is surer).
        var days = Set<String>()
        return possible.sorted { $0.1 > $1.1 }.filter { days.insert(keyer.day($0.0.day, tz: .current)).inserted }
            .prefix(settings.suggestMaxOffered).map(\.0).sorted { $0.day > $1.day }
    }
}
