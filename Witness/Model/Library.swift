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
    /// Catalog teams by "leagueKey#espnId", so a schedule's team finds the team the app already has.
    private(set) var espnIndex: [String: Team] = [:]

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
        // Photos or a ticket for a game already in the library join it instead of making a second card.
        if game.origin == .photos || game.origin == .ticket,
           let i = games.firstIndex(where: { Self.sameGame($0, game) }) {
            games[i] = Self.merged(games[i], with: game)
            sortAndSave()
            return
        }
        games.append(game)
        sortAndSave()
    }

    // MARK: Duplicates

    /// True when two entries are the same real game: the same schedule event, or, when either has no event to
    /// compare, the same venue within a few hours.
    nonisolated static func sameGame(_ a: GameEntry, _ b: GameEntry) -> Bool {
        guard a.id != b.id else { return false }
        if let x = a.source, let y = b.source {
            return x.provider == y.provider && x.league == y.league && x.eventId == y.eventId
        }
        guard a.venueId == b.venueId else { return false }
        return abs(a.date.timeIntervalSince(b.date)) < 8 * 3600
    }

    /// `keep` with everything `other` knows added: photos, schedule details, notes. What `keep` already has wins.
    nonisolated static func merged(_ keep: GameEntry, with other: GameEntry) -> GameEntry {
        var g = keep
        var seen = Set(g.photos)
        for ref in other.photos where seen.insert(ref).inserted { g.photos.append(ref) }
        if g.kind == .visit && other.kind != .visit {
            g.kind = nil
            g.sport = other.sport
            g.date = other.date
        }
        if g.source == nil { g.source = other.source }
        if g.homeTeamId == nil { g.homeTeamId = other.homeTeamId }
        if g.awayTeamId == nil { g.awayTeamId = other.awayTeamId }
        if g.homeScore == nil { g.homeScore = other.homeScore }
        if g.awayScore == nil { g.awayScore = other.awayScore }
        if g.rootingForTeamId == nil { g.rootingForTeamId = other.rootingForTeamId }
        if g.competition == nil { g.competition = other.competition }
        if g.headline == nil { g.headline = other.headline }
        if g.seat == nil { g.seat = other.seat }
        if g.note == nil { g.note = other.note }
        if g.tripId == nil { g.tripId = other.tripId }
        if g.weather == nil { g.weather = other.weather }
        if g.attendance == nil { g.attendance = other.attendance }
        if g.stage == nil { g.stage = other.stage }
        if g.plays.isEmpty { g.plays = other.plays }
        if g.winProbability.isEmpty { g.winProbability = other.winProbability }
        if g.lineHome.isEmpty { g.lineHome = other.lineHome }
        if g.lineAway.isEmpty { g.lineAway = other.lineAway }
        if g.podium.isEmpty { g.podium = other.podium }
        if g.coverPhoto == nil { g.coverPhoto = other.coverPhoto; g.coverChosenByFan = other.coverChosenByFan }
        for id in other.companionIds where !g.companionIds.contains(id) { g.companionIds.append(id) }
        for moment in other.savedMoments where !g.savedMoments.contains(moment) { g.savedMoments.append(moment) }
        return g
    }

    /// Groups of entries that look like the same game, such as a scan and an album that both added it.
    var duplicateGroups: [[GameEntry]] {
        let real = games.filter { $0.origin != .sample }
        var groups: [[GameEntry]] = []
        var used = Set<String>()
        for g in real where !used.contains(g.id) {
            let same = real.filter { $0.id == g.id || (!used.contains($0.id) && Self.sameGame($0, g)) }
            guard same.count > 1 else { continue }
            groups.append(same)
            for member in same { used.insert(member.id) }
        }
        return groups
    }

    /// Folds a group of duplicates into one game: the entry with the schedule match (else the most photos) keeps going.
    func combine(_ group: [GameEntry]) {
        func weight(_ g: GameEntry) -> Int { (g.source == nil ? 0 : 1000) + g.photos.count }
        guard let best = group.max(by: { weight($0) < weight($1) }) else { return }
        var result = best
        for other in group where other.id != best.id { result = Self.merged(result, with: other) }
        let removed = Set(group.map(\.id))
        games.removeAll { removed.contains($0.id) }
        games.append(result)
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
        if let known = catalogTeam(league: team.externalIds?.espnLeague ?? team.leagueKey, espnId: team.externalIds?.espn) {
            return known
        }
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

    // MARK: Downloaded packs

    /// What a downloaded teams pack holds: new teams, and league keys and ESPN ids for teams the app ships with.
    private struct PackTeams: Decodable {
        struct Overlay: Decodable {
            struct Ids: Decodable { var espn: String?; var espnLeague: String? }
            let id: String
            var leagueKey: String?
            var externalIds: Ids?
        }
        let teams: [Lossy<Team>]
        let overlays: [Overlay]
    }

    /// Decodes an element or skips it, so one unreadable record never loses the whole pack.
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    /// Merges downloaded catalog packs over what the app ships with. The shipped records win; packs add.
    func applyPacks() async {
        if let data = await PackStore.shared.data("catalog/teams"),
           let pack = try? Self.decoder.decode(PackTeams.self, from: data) {
            for overlay in pack.overlays {
                guard let i = allTeams.firstIndex(where: { $0.id == overlay.id }) else { continue }
                var team = allTeams[i]
                if team.leagueKey == nil { team.leagueKey = overlay.leagueKey }
                var ids = team.externalIds ?? Team.ExternalIds()
                if ids.espn == nil { ids.espn = overlay.externalIds?.espn }
                if ids.espnLeague == nil { ids.espnLeague = overlay.externalIds?.espnLeague }
                team.externalIds = ids
                allTeams[i] = team
            }
            let known = Set(allTeams.map(\.id))
            allTeams += pack.teams.compactMap(\.value).filter { !known.contains($0.id) }
            teams = Dictionary(allTeams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            espnIndex = [:]
            for team in allTeams {
                guard let espn = team.externalIds?.espn, let league = team.externalIds?.espnLeague ?? team.leagueKey else { continue }
                espnIndex["\(league)#\(espn)"] = espnIndex["\(league)#\(espn)"] ?? team
            }
        }
        if let data = await PackStore.shared.data("catalog/venues"),
           let extra = try? Self.decoder.decode([Lossy<Venue>].self, from: data) {
            let known = Set(catalogVenues.map(\.id))
            catalogVenues += extra.compactMap(\.value).filter { !known.contains($0.id) }
        }
        await ScheduleCache.shared.reset()
    }

    /// The team the app has for an ESPN team in a league, if any.
    func catalogTeam(league: String?, espnId: String?) -> Team? {
        guard let league, let espnId else { return nil }
        return espnIndex["\(league)#\(espnId)"]
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
