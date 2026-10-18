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
    private(set) var catalogVenues: [Venue] = [] {
        didSet { catalogVenueIndex = Dictionary(catalogVenues.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    }
    private var catalogVenueIndex: [String: Venue] = [:]
    private(set) var ballparks: [Ballpark] = []
    private var sampleTrips: [Trip] = []
    /// Trips the fan made, e.g. from an imported album.
    private(set) var customTrips: [Trip] = []
    /// The teams the fan picked as theirs: who they root for by default at every game.
    private(set) var chosenFavoriteTeamIds: [String] = []
    var trips: [Trip] { sampleTrips + customTrips }
    private var samplePeople: [Person] = []
    private var sampleProfile: Profile?

    // User data, persisted.
    private(set) var games: [GameEntry] = []
    /// Games the fan plans to go to. They are not games yet: no stats, stamps or map pins until attended.
    private(set) var plans: [GameEntry] = []
    /// Where the fan lives, picked by them. Miles traveled and the map's arcs start here.
    private(set) var customHome: HomePlace?
    /// Every team asked for in Plan a game, with how often nothing was found.
    private(set) var scheduleLog: [ScheduleSearch] = []
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
        var favoriteTeamIds: [String]? = nil
        var plans: [GameEntry]? = nil
        var home: HomePlace? = nil
        var scheduleLog: [ScheduleSearch]? = nil
    }

    /// What happened when a team's schedule was asked for: kept on this device so the teams with no schedule are known.
    struct ScheduleSearch: Codable, Hashable, Identifiable {
        var teamId: String
        var teamName: String
        var league: String
        var searches = 0
        var misses = 0
        var lastSearched: Date
        /// "5 games", "no games", "no schedule source".
        var lastOutcome: String
        var id: String { teamId }
    }

    struct HomePlace: Codable, Hashable {
        var city: String
        var latitude: Double
        var longitude: Double
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
    func venue(_ id: String) -> Venue? { customVenues.first { $0.id == id } ?? catalogVenueIndex[id] }
    func team(_ id: String?) -> Team? {
        guard let id else { return nil }
        return teams[id] ?? customTeams.first { $0.id == id }
    }
    func game(_ id: String) -> GameEntry? { games.first { $0.id == id } }
    func plan(_ id: String) -> GameEntry? { plans.first { $0.id == id } }
    func trip(_ id: String?) -> Trip? { id.flatMap { tid in trips.first { $0.id == tid } } }
    var isSample: Bool { games.contains { $0.origin == .sample } }

    /// Sam is the sample persona; a real user gets a neutral profile.
    var profile: Profile {
        if isSample, var sample = sampleProfile {
            if !chosenFavoriteTeamIds.isEmpty { sample.favoriteTeamIds = chosenFavoriteTeamIds }
            return sample
        }
        return Profile(displayName: "You", homeCity: customHome?.city ?? sampleProfile?.homeCity ?? "Chicago",
                       homeLatitude: customHome?.latitude ?? sampleProfile?.homeLatitude ?? 41.8781,
                       homeLongitude: customHome?.longitude ?? sampleProfile?.homeLongitude ?? -87.6298,
                       favoriteTeamIds: chosenFavoriteTeamIds)
    }

    /// Whether miles traveled can be worked out: the sample persona has a home, and a real fan sets theirs.
    var hasHome: Bool { isSample || customHome != nil }

    func setHome(city: String, latitude: Double, longitude: Double) {
        customHome = HomePlace(city: city, latitude: latitude, longitude: longitude)
        save()
    }

    /// Your teams, in the order you chose them.
    var favoriteTeams: [Team] { profile.favoriteTeamIds.compactMap { team($0) } }

    func addFavorite(_ id: String) {
        var ids = profile.favoriteTeamIds
        guard !ids.contains(id) else { return }
        ids.append(id)
        chosenFavoriteTeamIds = ids
        save()
    }

    func removeFavorite(_ id: String) {
        chosenFavoriteTeamIds = profile.favoriteTeamIds.filter { $0 != id }
        // An emptied list must not fall back to the sample's teams.
        if chosenFavoriteTeamIds.isEmpty && isSample { chosenFavoriteTeamIds = ["none"] }
        save()
    }

    /// Who the fan was rooting for at one game. `nil` goes back to the default (your teams, else the home side).
    func setRooting(_ gameId: String, to teamId: String?) {
        guard var g = game(gameId) else { return }
        g.rootingForTeamId = teamId
        update(g)
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
        return all.filter { hosts($0, sport) }
    }

    /// Whether a venue is a place for this sport. Big football bowls count for soccer too: World Cup and Gold Cup games.
    func hosts(_ venue: Venue, _ sport: Sport) -> Bool {
        venue.sports.contains(sport)
            || (sport == .soccer && venue.sports.contains(.football) && (venue.capacity ?? 0) >= 30_000)
    }

    /// Venues matching what was typed: every word is the start of a word in the name, an old name, the city, the region,
    /// the country or a tenant, so "levi stadium", "levis" and "santa clara" all find Levi's Stadium.
    /// Names that start with the query lead; the sport's own venues come before the rest.
    func searchVenues(_ query: String, sport: Sport?) -> [Venue] {
        let words = Self.words(query)
        guard !words.isEmpty else { return [] }
        let visited = Set(games.map(\.venueId))
        let typed = words.joined(separator: " ")
        var hits: [(venue: Venue, rank: Int)] = []
        for v in venues {
            let name = Self.words(v.name)
            let rest = Self.words(([v.city, v.region ?? "", v.country] + (v.aliases ?? []) + (v.homeTeams ?? [])).joined(separator: " "))
            let all = name + rest
            guard words.allSatisfy({ w in all.contains { $0.hasPrefix(w) } }) else { continue }
            var rank = 20
            if name.first?.hasPrefix(words[0]) == true { rank = 0 }
            else if words.allSatisfy({ w in name.contains { $0.hasPrefix(w) } }) { rank = 10 }
            // The whole name, or one of its other names, typed out: that is the one.
            if name.joined(separator: " ") == typed || (v.aliases ?? []).contains(where: { Self.words($0).joined(separator: " ") == typed }) { rank -= 20 }
            // Grounds you have been to, then the big ones, before obscure lookalikes.
            if visited.contains(v.id) { rank -= 5 }
            if (v.capacity ?? 0) >= 15_000 { rank -= 2 }
            if let sport, !hosts(v, sport) { rank += 40 }
            hits.append((v, rank))
        }
        return hits.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.venue.name < $1.venue.name }.map(\.venue)
    }

    /// Lowercase words with accents and apostrophes folded away: "Levi\u{2019}s Stadium" is ["levis", "stadium"].
    private static func words(_ s: String) -> [String] {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
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

    // MARK: Venue audit

    /// Whether the audit has run in this launch.
    private var venuesAudited = false
    /// Games filed under a ground that cannot host their sport, with nothing to correct them from: the fan reviews these.
    private(set) var venueDoubts: [String] = []

    func clearDoubt(_ id: String) { venueDoubts.removeAll { $0 == id } }

    /// Checks each saved game's stadium against what is known for sure, and corrects the ones that cannot be right:
    /// a ground that does not host the game's sport (a Welsh football pitch for an NBA game), or photos taken more
    /// than 20 km from the stadium they were filed under. A wrong match's schedule details go with it, and the right
    /// stadium's schedule is asked for the real game.
    func auditVenues() async {
        guard !venuesAudited else { return }
        venuesAudited = true
        fillVisitHomeTeams()
        for g in games where g.origin != .sample && g.sport != .motorsport {
            guard let current = venue(g.venueId) else { continue }
            var target: Venue?
            if !hosts(current, g.sport) { target = homeGround(of: g) }
            let libraryIds = g.photos.compactMap { ref -> String? in
                if case .library(let id) = ref { return id }
                return nil
            }
            if target == nil, let here = await PhotoMatcher.location(ofPhotos: libraryIds),
               current.location.distance(from: here) > 20_000 {
                target = venues.filter { hosts($0, g.sport) && $0.location.distance(from: here) <= 1_500 }
                    .min { $0.location.distance(from: here) < $1.location.distance(from: here) }
                // Photos taken at a ground that hosts nothing of this sport still say where the fan was.
                    ?? VisitGrouping.nearestVenue(lat: here.coordinate.latitude, lon: here.coordinate.longitude, in: venues)
            }
            if target == nil, !hosts(current, g.sport), g.kind == nil { venueDoubts.append(g.id) }
            guard let target, target.id != g.venueId, var fixed = game(g.id) else { continue }
            fixed.venueId = target.id
            fixed.weather = nil
            if fixed.source != nil {
                // The schedule match belonged to the wrong stadium: its teams, score and plays do too.
                fixed.source = nil
                fixed.homeTeamId = nil
                fixed.awayTeamId = nil
                fixed.homeScore = nil
                fixed.awayScore = nil
                fixed.lineHome = []
                fixed.lineAway = []
                fixed.plays = []
                fixed.winProbability = []
                fixed.stage = nil
                fixed.attendance = nil
                fixed.competition = nil
                fixed.rootingForTeamId = nil
                fixed.kind = .visit
            }
            update(fixed)
            await rematchSchedule(fixed.id)
        }
    }

    /// The ground a game's home team calls home, when the catalog lists it for that sport.
    private func homeGround(of g: GameEntry) -> Venue? {
        guard let team = team(g.homeTeamId) else { return nil }
        if let id = team.homeVenueId, let v = venue(id), hosts(v, g.sport) { return v }
        let full = "\(team.locationName) \(team.teamName)".lowercased()
        return venues.first { v in hosts(v, g.sport) && (v.homeTeams ?? []).contains { $0.lowercased() == full } }
    }

    /// A visit at a stadium that had exactly one game on its schedule that day is that game.
    private func rematchSchedule(_ id: String) async {
        guard let g = game(id), g.source == nil, let venue = venue(g.venueId) else { return }
        let found = await GameLookup.games(at: venue, from: g.date.addingTimeInterval(-4 * 3600), to: g.date.addingTimeInterval(4 * 3600))
            .filter { $0.sport == g.sport }
        guard found.count == 1, let only = found.first, var current = game(id) else { return }
        GameLookup.apply(only, detail: await GameLookup.detail(only), to: &current, library: self)
        current.kind = nil
        update(current)
    }

    // MARK: Plans

    /// A planned game from the schedule. Nothing happens if that event is already planned or its ground is unknown.
    @discardableResult
    func addPlan(_ found: FoundGame) -> GameEntry? {
        if let existing = plans.first(where: { $0.source?.eventId == found.eventId && $0.source?.league == found.league }) { return existing }
        guard let venue = GameLookup.venue(of: found, in: venues)
                ?? team(GameLookup.team(from: found.home, game: found).id).flatMap({ $0.homeVenueId }).flatMap({ self.venue($0) })
                ?? addVenue(from: found) else { return nil }
        var entry = GameEntry(sport: found.sport, date: found.start, venueId: venue.id, origin: .manual)
        GameLookup.apply(found, detail: nil, to: &entry, library: self)
        plans.append(entry)
        plans.sort { $0.date < $1.date }
        save()
        return entry
    }

    /// A stadium the schedule names and the catalog lacks, added from the coordinates the schedule gives.
    private func addVenue(from found: FoundGame) -> Venue? {
        guard let lat = found.venueLatitude, let lon = found.venueLongitude, !found.venueName.isEmpty else { return nil }
        let zone = found.utcOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        let venue = Venue(id: "custom-\(UUID().uuidString)", name: found.venueName, city: found.venueCity ?? "", region: nil,
                          country: "", countryCode: found.venueCountryCode ?? "", latitude: lat, longitude: lon, sports: [found.sport],
                          timeZone: zone.identifier, capacity: found.venueCapacity, opened: nil, isCustom: true)
        return addVenue(venue)
    }

    /// Notes that a team's schedule was asked for, and whether anything came back.
    func recordScheduleSearch(_ team: Team, found: Int, noSource: Bool = false) {
        var entry = scheduleLog.first { $0.teamId == team.id }
            ?? ScheduleSearch(teamId: team.id, teamName: "\(team.locationName) \(team.teamName)", league: team.league, lastSearched: .now, lastOutcome: "")
        entry.searches += 1
        if found == 0 { entry.misses += 1 }
        entry.lastSearched = .now
        entry.lastOutcome = noSource ? "no schedule source" : (found == 0 ? "no games" : "\(found) \(found == 1 ? "game" : "games")")
        scheduleLog.removeAll { $0.teamId == team.id }
        scheduleLog.append(entry)
        save()
    }

    func clearScheduleLog() {
        scheduleLog = []
        save()
    }

    func updatePlan(_ plan: GameEntry) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[i] = plan
        save()
    }

    func removePlan(_ id: String) {
        plans.removeAll { $0.id == id }
        save()
    }

    /// The fan is at the game: the plan becomes a game, and the schedule fills in what it knows.
    @discardableResult
    func attend(plan id: String) -> String? {
        guard var entry = plan(id) else { return nil }
        plans.removeAll { $0.id == id }
        if entry.planAutoPhotos != false { entry.autoPhotosUntil = entry.date.addingTimeInterval(14 * 3600) }
        entry.planReminder = nil
        entry.planAutoPhotos = nil
        entry.origin = .manual
        entry.kind = nil
        games.append(entry)
        sortAndSave()
        Task {
            await refreshFromSchedule(entry.id)
            await attachPhotos(entry.id)
            await attachVideos(entry.id)
            await fillWeather(entry.id)
        }
        return entry.id
    }

    /// The photos taken at the game's stadium around its start, added to the game. The fan already told us when and where.
    func attachPhotos(_ id: String) async {
        guard await PhotoMatcher.requestAccess(),
              let g = game(id), let venue = venue(g.venueId) else { return }
        let ids = await PhotoMatcher.photos(at: venue, around: g.date)
        guard var current = game(id) else { return }
        let fresh = ids.map { PhotoRef.library($0) }.filter { !current.photos.contains($0) }
        guard !fresh.isEmpty else { return }
        current.photos += fresh
        update(current)
        await autoCover(id)
    }

    /// Planned games that are over, with photos at their stadium, become games with those photos. Without access to photos
    /// or without a photo from the stadium, a plan stays a plan: a game is never invented.
    func sweepPlans(startedFor elapsed: TimeInterval = 4 * 3600) async {
        guard PhotoMatcher.hasAccess else { return }
        let now = Date()
        let due = plans.filter { $0.planAutoPhotos != false && $0.date.addingTimeInterval(elapsed) < now
                                 && $0.date > now.addingTimeInterval(-14 * 86_400) }
        for plan in due {
            guard let venue = venue(plan.venueId) else { continue }
            let ids = await PhotoMatcher.photos(at: venue, around: plan.date)
            if !ids.isEmpty { attend(plan: plan.id) }
        }
    }

    // MARK: Videos and game-day checks

    /// Videos shot at the game's stadium around its start, added after the photos. Looked for once per game.
    func attachVideos(_ id: String) async {
        guard PhotoMatcher.hasAccess, let g = game(id), let venue = venue(g.venueId) else { return }
        let ids = await PhotoMatcher.videos(at: venue, around: g.date)
        guard var current = game(id) else { return }
        let fresh = ids.map { PhotoRef.library($0) }.filter { !current.photos.contains($0) }
        current.photos += fresh
        current.videosChecked = true
        update(current)
    }

    /// The quiet pass: games that already have photos from a stadium get that day's videos too. A few at a time, only
    /// games not yet looked at, so a big library never makes this a long wait.
    func scanVideos(limit: Int = 12) async {
        guard PhotoMatcher.hasAccess else { return }
        let todo = games.filter { g in
            g.videosChecked != true && g.origin != .sample
                && g.photos.contains { if case .library = $0 { return true } else { return false } }
        }
        for g in todo.prefix(limit) {
            if Task.isCancelled { return }
            await attachVideos(g.id)
        }
    }

    /// Whether the background game-day check has anything to watch for.
    var needsGameDayChecks: Bool {
        let now = Date()
        return plans.contains { $0.planAutoPhotos != false && $0.date < now.addingTimeInterval(36 * 3600) && $0.date > now.addingTimeInterval(-36 * 3600) }
            || games.contains { ($0.autoPhotosUntil ?? .distantPast) > now }
    }

    /// What the hourly background check does on game day: a plan that has started and has photos at its stadium becomes a game,
    /// and games still inside their window keep collecting that day's photos and videos.
    func gameDayPhotoCheck() async {
        guard PhotoMatcher.hasAccess else { return }
        await sweepPlans(startedFor: -30 * 60)
        for g in games where (g.autoPhotosUntil ?? .distantPast) > Date() {
            if Task.isCancelled { return }
            await attachPhotos(g.id)
            await attachVideos(g.id)
        }
    }

    // MARK: Home grounds

    /// The team that calls a stadium home, for that sport: a catalog home venue, else a listed tenant.
    func homeTeam(at venue: Venue, sport: Sport) -> Team? {
        let pool = (allTeams + customTeams).filter { $0.sport == sport }
        if let t = pool.first(where: { $0.homeVenueId == venue.id }) { return t }
        let tenants = Set((venue.homeTeams ?? []).map { $0.lowercased() })
        return pool.first { tenants.contains("\($0.locationName) \($0.teamName)".lowercased()) }
    }

    /// Stadium visits with no home team get the ground's own team, so the card can say whose stadium it is.
    func fillVisitHomeTeams() {
        var changed = false
        for i in games.indices where games[i].kind == .visit && games[i].homeTeamId == nil {
            guard let venue = venue(games[i].venueId), let team = homeTeam(at: venue, sport: games[i].sport) else { continue }
            games[i].homeTeamId = team.id
            changed = true
        }
        if changed { save() }
    }

    /// Scores and plays for a game that has since been played, found again on its schedule.
    func refreshFromSchedule(_ id: String) async {
        guard let g = game(id), let source = g.source, let venue = venue(g.venueId) else { return }
        if source.eventId.hasPrefix("uefa-") {
            guard let match = await UEFASchedule.match(eventId: source.eventId), match.completed, var current = game(id) else { return }
            GameLookup.apply(match, detail: nil, to: &current, library: self)
            update(current)
            return
        }
        let found = await GameLookup.games(at: venue, from: g.date.addingTimeInterval(-6 * 3600), to: g.date.addingTimeInterval(8 * 3600))
        guard let match = found.first(where: { $0.eventId == source.eventId }), match.completed else { return }
        let detail = await GameLookup.detail(match)
        guard var current = game(id) else { return }
        GameLookup.apply(match, detail: detail, to: &current, library: self)
        update(current)
    }

    // MARK: Mutations

    func add(_ game: GameEntry) {
        // Photos or a ticket for a game already in the library join it instead of making a second card.
        if game.origin == .photos || game.origin == .ticket,
           let i = games.firstIndex(where: { Self.sameGame($0, game) }) {
            games[i] = Self.merged(games[i], with: game)
            sortAndSave()
            let id = games[i].id
            Task { await fillWeather(id) }
            return
        }
        games.append(game)
        sortAndSave()
        let id = game.id
        Task { await fillWeather(id) }
    }

    // MARK: Weather

    /// Looks up the temperature and sky at the game's start time and saves it on the game. Nothing is sent but the
    /// stadium's public location and the day.
    func fillWeather(_ id: String) async {
        guard let g = game(id), g.weather == nil, let venue = venue(g.venueId) else { return }
        guard let weather = await WeatherLookup.at(venue: venue, date: g.date) else { return }
        // The fan may have changed the game while the lookup ran.
        guard var latest = game(id), latest.weather == nil, latest.date == g.date, latest.venueId == g.venueId else { return }
        latest.weather = weather
        update(latest)
    }

    /// Soccer games saved before own goals were scored correctly: fetch their plays again so the running score is right.
    func repairSoccerPlays() async {
        let ids = games.filter { g in
            g.sport == .soccer && g.source?.provider == "espn" && g.plays.contains { $0.text.lowercased().hasPrefix("own goal") }
        }.map(\.id)
        for id in ids {
            guard let g = game(id), let source = g.source, let home = soccerSide(g.homeTeamId, g.homeScore),
                  let away = soccerSide(g.awayTeamId, g.awayScore) else { continue }
            let found = FoundGame(league: source.league, leagueName: "", eventId: source.eventId, sport: .soccer, start: g.date,
                                  venueName: "", venueCity: nil, home: home, away: away, completed: g.hasScore, note: nil)
            guard let detail = await GameLookup.detail(found), !detail.plays.isEmpty, var latest = game(id) else { continue }
            latest.plays = detail.plays
            update(latest)
        }
    }

    private func soccerSide(_ teamId: String?, _ score: Int?) -> FoundGame.Side? {
        guard let team = team(teamId), let espn = team.externalIds?.espn else { return nil }
        return FoundGame.Side(espnId: espn, abbreviation: team.abbreviation, location: team.locationName, name: team.teamName,
                              color: nil, altColor: nil, score: score, line: [])
    }

    /// Fills weather for saved games that lack it, most recent first, a batch at a time.
    func backfillWeather(limit: Int = 30) async {
        let ids = games.filter { $0.weather == nil && $0.origin != .sample }
            .sorted { $0.date > $1.date }.prefix(limit).map(\.id)
        for id in ids { await fillWeather(id) }
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
        var game = game
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return add(game) }
        // A game moved to another time or stadium had different weather.
        if games[i].date != game.date || games[i].venueId != game.venueId { game.weather = nil }
        games[i] = game
        sortAndSave()
        if game.weather == nil {
            let id = game.id
            Task { await fillWeather(id) }
        }
    }

    /// Takes photos off a game. They stay in the Photos library; only this game's link to them goes.
    func removePhotos(_ gameId: String, _ refs: Set<PhotoRef>) {
        guard var g = game(gameId), !refs.isEmpty else { return }
        g.photos.removeAll { refs.contains($0) }
        if let cover = g.coverPhoto, refs.contains(cover) {
            g.coverPhoto = nil
            g.coverChosenByFan = nil
        }
        update(g)
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
        let stills = MediaInfo.stills(g.photos)
        guard stills.count > 1, let best = await CoverPicker.best(stills), let again = game(id), again.coverChosenByFan != true else { return }
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
        // A national side from the UEFA feed: its FIFA code is the abbreviation of the catalog's national team.
        if team.leagueKey?.hasSuffix("uefa.nations") == true,
           let known = allTeams.first(where: { $0.sport == .soccer && $0.league == "National teams" && $0.abbreviation == team.abbreviation }) {
            return known
        }
        // ESPN and the catalog can code a team differently (GS and GSW), so city plus name matches too.
        if let known = allTeams.first(where: { $0.sport == team.sport && $0.teamName.caseInsensitiveCompare(team.teamName) == .orderedSame
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
        games = []; customVenues = []; customPeople = []; customTeams = []; customTrips = []; chosenFavoriteTeamIds = []; hasLibrary = false
        try? FileManager.default.removeItem(at: storeURL)
    }

    // MARK: Persistence

    private func sortAndSave() {
        games.sort { $0.date > $1.date }
        save()
    }

    private func save() {
        hasLibrary = true
        let stored = Stored(games: games, customVenues: customVenues, customPeople: customPeople, customTeams: customTeams, customTrips: customTrips,
                        favoriteTeamIds: chosenFavoriteTeamIds.isEmpty ? nil : chosenFavoriteTeamIds,
                        plans: plans.isEmpty ? nil : plans, home: customHome,
                        scheduleLog: scheduleLog.isEmpty ? nil : scheduleLog)
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
        chosenFavoriteTeamIds = stored.favoriteTeamIds ?? []
        plans = (stored.plans ?? []).sorted { $0.date < $1.date }
        customHome = stored.home
        scheduleLog = stored.scheduleLog ?? []
        hasLibrary = true
    }

    private func loadCatalog() {
        var teamList: [Team] = decode("teams", subdirectory: "Catalog") ?? []
        // Countries from the World Cup, Euros, Copa América, Gold Cup and qualifiers.
        let nationals: [Team] = decode("national-teams", subdirectory: "Catalog") ?? []
        var have = Set(teamList.map(\.id))
        teamList += nationals.filter { !have.contains($0.id) }
        // Every club and national side the research found: ~4,000 more across the leagues the app supports.
        have = Set(teamList.map(\.id))
        let more: [Lossy<Team>] = decode("teams-more", subdirectory: "Catalog") ?? []
        teamList += more.compactMap(\.value).filter { !have.contains($0.id) }
        allTeams = teamList
        teams = Dictionary(teamList.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        rebuildTeamIndex()
        // One unreadable record never loses the catalog.
        let rawVenues: [Lossy<Venue>] = decode("venues", subdirectory: "Catalog") ?? []
        var venueList: [Venue] = rawVenues.compactMap(\.value)
        // Formula 1 circuits: grandstand-sized geofences, and they join (or fill in) the catalog's venues.
        let circuits: [Venue] = decode("f1-circuits", subdirectory: "Catalog") ?? []
        for circuit in circuits {
            if let i = venueList.firstIndex(where: { $0.id == circuit.id }) {
                venueList[i].geofenceMeters = circuit.geofenceMeters
                venueList[i].sports = Array(Set(venueList[i].sports + circuit.sports))
                venueList[i].leagues = Array(Set((venueList[i].leagues ?? []) + (circuit.leagues ?? [])))
            } else {
                venueList.append(circuit)
            }
        }
        catalogVenues = venueList
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
    struct Lossy<T: Decodable>: Decodable {
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
            rebuildTeamIndex()
        }
        if let data = await PackStore.shared.data("catalog/venues"),
           let extra = try? Self.decoder.decode([Lossy<Venue>].self, from: data) {
            let known = Set(catalogVenues.map(\.id))
            catalogVenues += extra.compactMap(\.value).filter { !known.contains($0.id) }
        }
        await ScheduleCache.shared.reset()
    }

    private func rebuildTeamIndex() {
        espnIndex = [:]
        // Current franchises first: ESPN names today's team, and a relocated club's old record shares its id.
        for team in allTeams.filter({ !$0.id.hasPrefix("hist-") }) + allTeams.filter({ $0.id.hasPrefix("hist-") }) {
            guard let espn = team.externalIds?.espn, let league = team.externalIds?.espnLeague ?? team.leagueKey else { continue }
            espnIndex["\(league)#\(espn)"] = espnIndex["\(league)#\(espn)"] ?? team
        }
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
