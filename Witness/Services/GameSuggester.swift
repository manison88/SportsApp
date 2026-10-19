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

    static let minPhotos = 3
    static let maxDays = 150
    static let maxAlbums = 60

    /// Albums that apps and the system make (saved from Instagram, WhatsApp, screenshots...) are never a day out.
    static let appAlbums = ["instagram", "whatsapp", "facebook", "messenger", "snapchat", "tiktok", "telegram", "twitter", "pinterest",
                            "reddit", "youtube", "discord", "wechat", "viber", "slack", "gmail", "google photos",
                            "screenshot", "screen recording", "meta ai", "chatgpt", "gemini", "midjourney", "generated", "ai", "saved", "downloads", "imported", "received", "shared", "memes", "meme",
                            "camera roll", "recents", "snapseed", "lightroom", "vsco", "photoshop", "capcut", "inshot", "canva"]

    /// Pure: whether an album's title names an app or a system collection rather than an occasion.
    static func isAppAlbum(_ title: String) -> Bool {
        let t = fold(title)
        let words = Set(t.split(separator: " ").map(String.init))
        return appAlbums.contains { app in app.contains(" ") ? t.contains(app) : words.contains { $0 == app || $0 == app + "s" } }
    }

    /// Pure: the days worth a look. Enough photos, none the library already covers, newest first.
    static func candidates(_ piles: [DayPile], skipping claimed: Set<String>) -> [DayPile] {
        piles.filter { $0.assetIds.count >= minPhotos && !claimed.contains($0.id) }.sorted { $0.day > $1.day }
    }

    /// Pure: the stadiums an album's title points at: a team's home ground ("Cubs game"), or a stadium named outright ("Wrigley 2019").
    static func venues(named title: String, teams: [Team], venues: [Venue], lookup: (String) -> Venue?) -> [Venue] {
        let words = Set(fold(title).split(separator: " ").map(String.init))
        guard !words.isEmpty else { return [] }
        var out: [Venue] = []
        func add(_ v: Venue?) { if let v, !out.contains(where: { $0.id == v.id }) { out.append(v) } }
        var byTeam: [Venue] = []
        for team in teams {
            let name = fold(team.teamName).split(separator: " ").map(String.init)
            let city = fold(team.locationName).split(separator: " ").map(String.init)
            // "Cubs" alone is enough only when the nickname is a distinctive word; "Chicago Bears" matches on city plus name.
            guard !name.isEmpty, name.allSatisfy({ $0.count >= 4 && words.contains($0) }) || (!city.isEmpty && Set(city + name).isSubset(of: words))
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
    }

    /// The days that are only possible games.
    /// `claimed` holds "yyyy-MM-dd" days a visit or a saved game already covers.
    static func find(venues: [Venue], teams: [Team], home: CLLocation, hasHome: Bool, claimed: Set<String>,
                     progress: @escaping @MainActor (_ step: Step, _ done: Int, _ total: Int) -> Void) async -> [PossibleDay] {
        // Everything that touches the photo library runs off the main thread.
        let sources: [Source] = await Task.detached(priority: .utility) {
            var out: [Source] = []
            let albums = Array(AlbumImporter.albums().filter({ $0.count >= minPhotos && $0.count <= 3000 && !isAppAlbum($0.title) }).prefix(maxAlbums))
            for (n, album) in albums.enumerated() {
                Task { @MainActor in progress(.reading, n, albums.count) }
                let hints = Self.venues(named: album.title, teams: teams, venues: venues) { id in venues.first { $0.id == id } }
                out.append(Source(reason: "In your album \u{201C}\(album.title)\u{201D}", points: AlbumImporter.points(in: album), hints: hints, titled: !hints.isEmpty))
            }
            if hasHome {
                for trip in TripFinder.find(home: home, venues: venues).prefix(20) {
                    let points = AlbumImporter.points(in: trip)
                    let located = points.compactMap { p in p.latitude.flatMap { la in p.longitude.map { CLLocation(latitude: la, longitude: $0) } } }
                    var near: [Venue] = []
                    if !located.isEmpty {
                        let lat = located.map { $0.coordinate.latitude }.reduce(0, +) / Double(located.count)
                        let lon = located.map { $0.coordinate.longitude }.reduce(0, +) / Double(located.count)
                        let center = CLLocation(latitude: lat, longitude: lon)
                        near = Array(venues.filter { ($0.capacity ?? 0) >= 5000 && $0.location.distance(from: center) < 40_000 }
                            .sorted { $0.location.distance(from: center) < $1.location.distance(from: center) }.prefix(3))
                    }
                    out.append(Source(reason: "On your \(trip.title.lowercased())", points: points, hints: near))
                }
            }
            return out
        }.value

        // The unplaced days of every source, then the cheapest filter first: only days that look like a game are kept.
        var work: [(DayPile, Source)] = []
        var claimed = claimed
        for (n, source) in sources.enumerated() {
            await progress(.sorting, n, sources.count)
            // An album or trip counts only if some of its photos show a stadium, arena, scoreboard or sport (or its title names
            // a team or stadium). A crowd alone is a wedding, a party or a school event.
            if !source.titled {
                let look = await SceneCheck.look(at: source.points.map { PhotoRef.library($0.id) }, max: 20)
                guard look.isGame(minVenue: 2, minShare: 0.05) else { continue }
            }
            let scan = await Task.detached { VisitGrouping.group(source.points, venues: venues) }.value
            for pile in candidates(scan.unplacedDays, skipping: claimed) where claimed.insert(pile.id).inserted {
                work.append((pile, source))
            }
        }
        work = Array(work.sorted { $0.0.day > $1.0.day }.prefix(maxDays))
        await progress(.days, 0, work.count)

        var possible: [PossibleDay] = []
        for (n, (pile, source)) in work.enumerated() {
            defer { Task { await progress(.days, n + 1, work.count) } }
            if Task.isCancelled { break }
            // No time pressure here, so most of the day is looked at. A day needs several photos clearly at a game; an album
            // whose title names a team or stadium only needs the day not to be mostly somewhere else (a beach, a party).
            let look = await SceneCheck.look(at: pile.assetIds.map { PhotoRef.library($0) })
            let keep = source.titled ? (!look.mostlyElsewhere && look.venue >= 1) : look.isGame()
            guard keep, PhotoMatcher.looksLikeAGame(pile.times) else { continue }
            let middle = pile.times.sorted()[pile.times.count / 2]
            possible.append(PossibleDay(id: "possible-" + pile.id, day: middle, assetIds: pile.assetIds, times: pile.times,
                                        reason: "\(source.reason) \u{00B7} \(look.venue) of \(look.classified) photos show a game",
                                        suggestions: source.hints))
        }
        return possible.sorted { $0.day > $1.day }
    }
}
