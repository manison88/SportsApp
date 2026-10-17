import Foundation
import Observation
import CoreLocation

/// The fan's library: every game they were at, plus the catalogs (teams,
/// venues, ballparks) the app ships with. Games, custom venues and people the
/// user adds are saved as JSON in Documents. Everything stays on the device.
@Observable
@MainActor
final class Library {
    // Catalog, read-only, bundled.
    private(set) var teams: [String: Team] = [:]
    private(set) var allTeams: [Team] = []
    private(set) var catalogVenues: [Venue] = []
    private(set) var ballparks: [Ballpark] = []
    private var sampleTrips: [Trip] = []
    /// Trips the fan made, e.g. from an imported album.
    private(set) var customTrips: [Trip] = []
    var trips: [Trip] { sampleTrips + customTrips }
    private var samplePeople: [Person] = []
    private var sampleProfile: Profile?

    // User data, persisted.
    private(set) var games: [GameEntry] = []
    private(set) var customVenues: [Venue] = []
    private(set) var customPeople: [Person] = []
    /// Teams learned from real schedules (any league, any country).
    private(set) var customTeams: [Team] = []
    private(set) var hasLibrary = false

    let storeURL: URL
    private let bundle: Bundle

    struct Stored: Codable {
        var games: [GameEntry]
        var customVenues: [Venue]
        var customPeople: [Person]
        var customTeams: [Team]? = nil
        var customTrips: [Trip]? = nil
    }

    nonisolated static var defaultStoreURL: URL {
        URL.documentsDirectory.appending(path: "library.json")
    }

    init(storeURL: URL = Library.defaultStoreURL, bundle: Bundle = .main) {
        self.storeURL = storeURL
        self.bundle = bundle
        loadCatalog()
        loadStore()
    }

    // MARK: Lookups

    var venues: [Venue] { catalogVenues + customVenues }
    func venue(_ id: String) -> Venue? { venues.first { $0.id == id } }
    func team(_ id: String?) -> Team? {
        guard let id else { return nil }
        return teams[id] ?? customTeams.first { $0.id == id }
    }
    func game(_ id: String) -> GameEntry? { games.first { $0.id == id } }
    func trip(_ id: String?) -> Trip? { id.flatMap { tid in trips.first { $0.id == tid } } }
    var isSample: Bool { games.contains { $0.origin == .sample } }

    /// Sam is the sample persona; a real user gets a neutral profile.
    var profile: Profile {
        if isSample, let sampleProfile { return sampleProfile }
        return Profile(displayName: "You", homeCity: sampleProfile?.homeCity ?? "Chicago",
                       homeLatitude: sampleProfile?.homeLatitude ?? 41.8781,
                       homeLongitude: sampleProfile?.homeLongitude ?? -87.6298,
                       favoriteTeamIds: [])
    }

    /// People you can tag at a game. "me" is never a companion.
    var people: [Person] {
        (isSample ? samplePeople : []).filter { $0.id != "me" } + customPeople
    }
    func person(_ id: String) -> Person? { people.first { $0.id == id } }

    func teams(for sport: Sport) -> [Team] {
        (allTeams + customTeams).filter { $0.sport == sport }.sorted { $0.locationName < $1.locationName }
    }

    func venues(for sport: Sport?) -> [Venue] {
        let all = venues.sorted { $0.name < $1.name }
        guard let sport else { return all }
        return all.filter { $0.sports.contains(sport) }
    }

    func games(at venueId: String) -> [GameEntry] { games.filter { $0.venueId == venueId } }

    func games(in trip: Trip) -> [GameEntry] {
        games.filter { $0.tripId == trip.id || trip.gameIds.contains($0.id) }.sorted { $0.date < $1.date }
    }

    func games(with personId: String) -> [GameEntry] { games.filter { $0.companionIds.contains(personId) } }

    /// The team the fan was there for.
    func rootingTeam(_ game: GameEntry) -> String? {
        if let r = game.rootingForTeamId { return r }
        let favorites = Set(profile.favoriteTeamIds)
        if let h = game.homeTeamId, favorites.contains(h) { return h }
        if let a = game.awayTeamId, favorites.contains(a) { return a }
        return game.homeTeamId
    }

    func outcome(_ game: GameEntry) -> Outcome {
        guard let hs = game.homeScore, let a = game.awayScore, let r = rootingTeam(game) else { return .none }
        if hs == a { return .draw }
        let homeWon = hs > a
        if r == game.homeTeamId { return homeWon ? .win : .loss }
        if r == game.awayTeamId { return homeWon ? .loss : .win }
        return .none
    }

    // MARK: Mutations

    func add(_ game: GameEntry) {
        games.append(game)
        sortAndSave()
    }

    func update(_ game: GameEntry) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return add(game) }
        games[i] = game
        sortAndSave()
    }

    /// Sets a game's cover photo (nil clears it so it can be picked again).
    func setCover(_ id: String, to ref: PhotoRef?, byFan: Bool) {
        guard var g = game(id) else { return }
        g.coverPhoto = ref
        g.coverChosenByFan = ref == nil ? nil : byFan
        update(g)
    }

    @ObservationIgnored private var coverWork = Set<String>()

    /// Picks a cover for a game that has several photos and none chosen yet. Never touches the fan's own pick.
    func autoCover(_ id: String, force: Bool = false) async {
        guard let g = game(id), g.photos.count > 1, !coverWork.contains(id) else { return }
        guard force ? g.coverChosenByFan != true : (g.coverPhoto == nil && g.coverChosenByFan != true) else { return }
        coverWork.insert(id)
        defer { coverWork.remove(id) }
        guard let best = await CoverPicker.best(g.photos), let again = game(id), again.coverChosenByFan != true else { return }
        setCover(id, to: best, byFan: false)
    }

    func delete(_ id: String) {
        games.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func addVenue(_ venue: Venue) -> Venue {
        if let existing = venues.first(where: { $0.name.caseInsensitiveCompare(venue.name) == .orderedSame
            && abs($0.latitude - venue.latitude) < 0.01 && abs($0.longitude - venue.longitude) < 0.01 }) {
            return existing
        }
        var v = venue
        v.isCustom = true
        customVenues.append(v)
        save()
        return v
    }

    func addTrip(_ trip: Trip) {
        customTrips.removeAll { $0.id == trip.id }
        customTrips.append(trip)
        save()
    }

    /// Returns the catalog team that matches, or remembers a new one.
    @discardableResult
    func addTeam(_ team: Team) -> Team {
        if let known = allTeams.first(where: { $0.sport == team.sport && $0.abbreviation == team.abbreviation
            && $0.locationName.caseInsensitiveCompare(team.locationName) == .orderedSame }) {
            return known
        }
        if let known = customTeams.first(where: { $0.id == team.id }) { return known }
        customTeams.append(team)
        save()
        return team
    }

    @discardableResult
    func addPerson(named name: String) -> Person {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = people.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) { return existing }
        let palette = ["FF7A8A", "6FD3FF", "B48CFF", "7BE0A0", "FFB547", "FF9F5A"]
        let initials = trimmed.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        let p = Person(name: trimmed, relation: "Friend", initials: initials.isEmpty ? "?" : initials,
                       colorHex: palette[customPeople.count % palette.count])
        customPeople.append(p)
        save()
        return p
    }

    /// Loads Sam's sample library so the app can be explored without data.
    func loadSample() {
        guard let sample: [GameEntry] = decode("library", subdirectory: "Sample") else { return }
        games.removeAll { $0.origin == .sample }
        games.append(contentsOf: sample)
        hasLibrary = true
        sortAndSave()
    }

    func removeSample() {
        games.removeAll { $0.origin == .sample }
        save()
    }

    /// Starts an empty library (the fan will add games themselves).
    func startEmpty() {
        hasLibrary = true
        save()
    }

    func reset() {
        games = []; customVenues = []; customPeople = []; customTeams = []; customTrips = []; hasLibrary = false
        try? FileManager.default.removeItem(at: storeURL)
    }

    // MARK: Persistence

    private func sortAndSave() {
        games.sort { $0.date > $1.date }
        save()
    }

    private func save() {
        hasLibrary = true
        let stored = Stored(games: games, customVenues: customVenues, customPeople: customPeople, customTeams: customTeams, customTrips: customTrips)
        do {
            let data = try Self.encoder.encode(stored)
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("Library save failed: \(error)")
        }
    }

    private func loadStore() {
        guard let data = try? Data(contentsOf: storeURL),
              let stored = try? Self.decoder.decode(Stored.self, from: data) else { return }
        games = stored.games.sorted { $0.date > $1.date }
        customVenues = stored.customVenues
        customPeople = stored.customPeople
        customTeams = stored.customTeams ?? []
        customTrips = stored.customTrips ?? []
        hasLibrary = true
    }

    private func loadCatalog() {
        let teamList: [Team] = decode("teams", subdirectory: "Catalog") ?? []
        allTeams = teamList
        teams = Dictionary(teamList.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        catalogVenues = decode("venues", subdirectory: "Catalog") ?? []
        ballparks = decode("ballparks", subdirectory: "Catalog") ?? []
        sampleTrips = decode("trips", subdirectory: "Sample") ?? []
        samplePeople = decode("people", subdirectory: "Sample") ?? []
        sampleProfile = decode("profile", subdirectory: "Sample")
    }

    private func decode<T: Decodable>(_ name: String, subdirectory: String) -> T? {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else {
            print("Missing bundled \(subdirectory)/\(name).json")
            return nil
        }
        do { return try Self.decoder.decode(T.self, from: data) } catch {
            print("Decoding \(name).json failed: \(error)")
            return nil
        }
    }

    nonisolated(unsafe) static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let f = ISO8601DateFormatter()
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date \(s)")
        }
        return d
    }()

    nonisolated(unsafe) static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
