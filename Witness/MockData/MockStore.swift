import Foundation
import CoreLocation

/// Loads the bundled JSON once and answers the questions screens ask.
/// When real data arrives this becomes a protocol with a live implementation.
final class MockStore {
    static let shared = MockStore()

    let teams: [String: Team]
    let venues: [String: Venue]
    /// Chronological, oldest first.
    let games: [Game]
    let photos: [String: PhotoAsset]
    let people: [String: Person]
    let trips: [Trip]
    let profile: Profile

    init(bundle: Bundle = .main) {
        let teamList: [Team] = MockStore.load("teams", bundle: bundle)
        let venueList: [Venue] = MockStore.load("venues", bundle: bundle)
        let gameList: [Game] = MockStore.load("games", bundle: bundle)
        let photoList: [PhotoAsset] = MockStore.load("photos", bundle: bundle)
        let personList: [Person] = MockStore.load("people", bundle: bundle)
        teams = Dictionary(uniqueKeysWithValues: teamList.map { ($0.id, $0) })
        venues = Dictionary(uniqueKeysWithValues: venueList.map { ($0.id, $0) })
        games = gameList.sorted { $0.startTime < $1.startTime }
        photos = Dictionary(uniqueKeysWithValues: photoList.map { ($0.id, $0) })
        people = Dictionary(uniqueKeysWithValues: personList.map { ($0.id, $0) })
        trips = MockStore.load("trips", bundle: bundle)
        profile = MockStore.load("profile", bundle: bundle)
    }

    private static func load<T: Decodable>(_ name: String, bundle: Bundle) -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("MockData/\(name).json is missing from the app bundle.")
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not decode \(name).json: \(error)")
        }
    }

    // MARK: Lookups

    func game(_ id: String) -> Game? { games.first { $0.id == id } }
    func team(_ id: String?) -> Team? { id.flatMap { teams[$0] } }
    func venue(for game: Game) -> Venue { venues[game.venueId]! }
    func person(_ id: String) -> Person? { people[id] }
    func trip(_ id: String?) -> Trip? { id.flatMap { tid in trips.first { $0.id == tid } } }

    func photos(for game: Game) -> [PhotoAsset] {
        game.memory.photoIds.compactMap { photos[$0] }.sorted { $0.creationDate < $1.creationDate }
    }

    func companions(for game: Game) -> [Person] {
        game.memory.companionIds.compactMap { people[$0] }
    }

    func pair(for game: Game) -> TeamPair? {
        guard let h = team(game.home?.teamId), let a = team(game.away?.teamId) else { return nil }
        return TeamPair(home: h, away: a)
    }

    /// The team the fan was there for: a favorite if one played, else home.
    func perspectiveTeam(for game: Game) -> Team? {
        if let h = game.home, profile.favoriteTeamIds.contains(h.teamId) { return team(h.teamId) }
        if let a = game.away, profile.favoriteTeamIds.contains(a.teamId) { return team(a.teamId) }
        return team(game.home?.teamId)
    }

    func perspectiveIsHome(for game: Game) -> Bool {
        perspectiveTeam(for: game)?.id == game.home?.teamId
    }

    /// Whether the fan's team won. nil for draws and races.
    func fanWon(_ game: Game) -> Bool? {
        guard game.race == nil, !game.isDraw else { return nil }
        return perspectiveIsHome(for: game) ? game.homeWon : !game.homeWon
    }

    /// Games attended with a given person.
    func games(with personId: String) -> [Game] {
        games.filter { $0.memory.companionIds.contains(personId) }
    }

    // MARK: Aggregates

    struct VenueVisits: Identifiable, Hashable {
        let venue: Venue
        let games: [Game]
        var id: String { venue.id }
        var count: Int { games.count }
        var first: Game { games.first! }
        var last: Game { games.last! }
    }

    var venueVisits: [VenueVisits] {
        Dictionary(grouping: games, by: \.venueId)
            .compactMap { id, list in venues[id].map { VenueVisits(venue: $0, games: list) } }
            .sorted { $0.count > $1.count }
    }

    var countries: Set<String> { Set(games.map { venue(for: $0).countryCode }) }

    var seasons: Int {
        let years = games.map { Calendar.current.component(.year, from: $0.startTime) }
        guard let lo = years.min(), let hi = years.max() else { return 0 }
        return hi - lo + 1
    }

    /// Miles from home, there and back, for every game more than 40 miles away.
    var milesTraveled: Int {
        let home = profile.homeLocation
        let meters = games.reduce(0.0) { sum, game in
            let d = venue(for: game).location.distance(from: home)
            return d > 64_000 ? sum + d * 2 : sum
        }
        return Int(meters / 1609.344)
    }

    func milesFromHome(_ venue: Venue) -> Int {
        Int(venue.location.distance(from: profile.homeLocation) / 1609.344)
    }
}

// MARK: - Preview helpers

extension MockStore {
    static let worldSeriesGame5 = "mlb-2016-ws5"
    static let lambeau2025 = "nfl-2025-w18-gb"
}
