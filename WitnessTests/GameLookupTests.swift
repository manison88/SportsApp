import XCTest
import CryptoKit
@testable import Witness

/// Schedule verification and stats, against saved ESPN responses
/// (Bears at Packers, Lambeau Field, Jan 5 2025).
@MainActor
final class GameLookupTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    private var lambeau: Venue {
        Venue(id: "lambeau", name: "Lambeau Field", city: "Green Bay", region: "Wisconsin", country: "United States",
              countryCode: "US", latitude: 44.5013, longitude: -88.0622, sports: [.football],
              timeZone: "America/Chicago", capacity: 81441, opened: 1957)
    }

    private func lambeauGame() throws -> FoundGame {
        let games = GameLookup.parseScoreboard(try fixture("nfl-scoreboard-20250105"), league: "football/nfl")
        return try XCTUnwrap(games.first { GameLookup.venueMatches($0, venue: lambeau) })
    }

    func testScoreboardFindsTheGameAtTheVenue() throws {
        let games = GameLookup.parseScoreboard(try fixture("nfl-scoreboard-20250105"), league: "football/nfl")
        XCTAssertEqual(games.count, 2)
        XCTAssertEqual(games.filter { GameLookup.venueMatches($0, venue: lambeau) }.count, 1, "Only one game was at Lambeau")
        let g = try lambeauGame()
        XCTAssertEqual(g.home.abbreviation, "GB")
        XCTAssertEqual(g.away.abbreviation, "CHI")
        XCTAssertEqual(g.home.score, 22)
        XCTAssertEqual(g.away.score, 24)
        XCTAssertEqual(g.home.line, [3, 10, 0, 9])
        XCTAssertEqual(g.away.line, [7, 7, 0, 10])
        XCTAssertTrue(g.completed)
        XCTAssertEqual(g.sport, .football)
    }

    func testVenueMatchingUsesAliasesAndIgnoresGenericWords() {
        var bernabeu = lambeau
        bernabeu.name = "Santiago Bernabéu Stadium"
        bernabeu.aliases = ["Estadio Bernabéu"]
        bernabeu.city = "Madrid"
        let side = FoundGame.Side(espnId: "1", abbreviation: "RMA", location: "Real Madrid", name: "Real Madrid",
                                  color: nil, altColor: nil, score: 2, line: [])
        let game = FoundGame(league: "soccer/esp.1", leagueName: "LaLiga", eventId: "1", sport: .soccer, start: .now,
                             venueName: "Estadio Bernabéu", venueCity: "Madrid", home: side, away: side,
                             completed: true, note: nil)
        XCTAssertTrue(GameLookup.venueMatches(game, venue: bernabeu))
        XCTAssertFalse(GameLookup.venueMatches(game, venue: lambeau))
    }

    func testDetailGivesScoringPlaysWinProbabilityAndAttendance() throws {
        let g = try lambeauGame()
        let d = GameLookup.parseDetail(try fixture("nfl-summary-401671844"), game: g)
        XCTAssertEqual(d.attendance, 77862)
        XCTAssertEqual(d.plays.filter(\.isKey).count, 9)
        XCTAssertEqual(d.plays.first?.period, "Q1")
        XCTAssertEqual(d.plays.last?.homeScore, 22)
        XCTAssertEqual(d.plays.last?.awayScore, 24)
        XCTAssertGreaterThan(d.winProbability.count, 50)
        XCTAssertLessThanOrEqual(d.winProbability.count, 202)
        XCTAssertEqual(d.winProbability.last?.home ?? -1, 0, accuracy: 0.001)
        XCTAssertTrue(zip(d.winProbability, d.winProbability.dropFirst()).allSatisfy { $0.time <= $1.time })
    }

    func testApplyLearnsTeamsAndFillsTheGame() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "lookup-\(UUID().uuidString).json")
        let library = Library(storeURL: url)
        let g = try lambeauGame()
        let d = GameLookup.parseDetail(try fixture("nfl-summary-401671844"), game: g)
        var entry = GameEntry(sport: .football, date: g.start, venueId: "lambeau", origin: .photos)
        GameLookup.apply(g, detail: d, to: &entry, library: library)
        XCTAssertEqual(entry.homeScore, 22)
        XCTAssertEqual(entry.awayScore, 24)
        XCTAssertEqual(entry.source?.eventId, "401671844")
        XCTAssertEqual(entry.attendance, 77862)
        XCTAssertEqual(library.team(entry.homeTeamId)?.abbreviation, "GB")
        XCTAssertEqual(library.team(entry.awayTeamId)?.locationName, "Chicago")
    }

    func testLeagueGuessForVenuesWithoutLeagues() {
        let football = GameLookup.leagues(for: lambeau)
        XCTAssertEqual(Array(football.prefix(2)), ["football/nfl", "football/college-football"])
        XCTAssertTrue(football.contains("soccer/fifa.world"), "Big football bowls host World Cup games")
        XCTAssertFalse(football.contains("soccer/uefa.champions"))
        var camp = lambeau
        camp.sports = [.soccer]
        camp.countryCode = "ES"
        let leagues = GameLookup.leagues(for: camp)
        XCTAssertEqual(leagues.first, "soccer/esp.1")
        XCTAssertTrue(leagues.contains("soccer/fifa.world"), "Any soccer ground can host a World Cup")
        XCTAssertTrue(leagues.contains("soccer/uefa.champions"))
    }

    func testDaysFollowTheVenueTimeZone() {
        let start = GameLookup.date("2016-10-31T00:15Z")!   // 7:15 PM Oct 30 in Chicago
        let days = GameLookup.dayStrings(from: start.addingTimeInterval(-5 * 3600), to: start.addingTimeInterval(4 * 3600),
                                         tz: TimeZone(identifier: "America/Chicago")!)
        XCTAssertEqual(days, ["20161030"])
    }

    // MARK: Downloaded schedule packs

    func testLocalScheduleFindsAPastGameAtTheVenue() throws {
        let json = """
        {"league":"football/nfl","season":2024,"teams":{"9":"GB","3":"CHI"},"venues":{"3731":["Lambeau Field","Green Bay","WI","US"],"1":["Soldier Field","Chicago","IL","US"]},
         "games":[["g1","2025-01-05T21:25Z","9","3",24,22,"3731","F","Regular season"],
                  ["g2","2025-01-05T21:25Z","3","9",null,null,"1","F",""],
                  ["g3","2025-01-06T21:25Z","9","3",null,null,"3731","C",""]]}
        """
        let pack = try JSONDecoder().decode(SchedulePack.self, from: Data(json.utf8))
        XCTAssertEqual(pack.games.count, 3)
        let kickoff = ISO8601DateFormatter().date(from: "2025-01-05T21:25:00Z")!
        let found = LocalSchedule.games(in: pack, at: lambeau, from: kickoff.addingTimeInterval(-3600),
                                        to: kickoff.addingTimeInterval(3600 * 4), names: [:])
        XCTAssertEqual(found.map(\.eventId), ["g1"], "Only the game at this venue, and not the cancelled one")
        XCTAssertEqual(found.first?.home.abbreviation, "GB")
        XCTAssertEqual(found.first?.home.score, 24)
        XCTAssertTrue(found.first?.completed == true)
    }

    func testLocalScheduleSeasonsAndNumericIds() throws {
        let from = ISO8601DateFormatter().date(from: "2025-01-05T00:00:00Z")!
        XCTAssertEqual(LocalSchedule.seasons(from: from, to: from), 2024...2025)
        let json = #"{"league":"soccer/eng.1","season":2024,"teams":{"1":"ARS"},"venues":{},"games":[[101,"2025-01-05T15:00Z",1,2,null,null,null,"S"]]}"#
        let pack = try JSONDecoder().decode(SchedulePack.self, from: Data(json.utf8))
        XCTAssertEqual(pack.games.first?.eventId, "101", "Numeric ids are read as text")
        XCTAssertEqual(pack.games.first?.note, "")
    }

    func testManifestSignatureIsChecked() throws {
        let body = #"{"schema":1,"minAppVersion":"1.0","packs":[]}"#
        let key = Curve25519.Signing.PrivateKey()
        let signature = try key.signature(for: Data(body.utf8)).base64EncodedString()
        let envelope = try JSONSerialization.data(withJSONObject: ["body": body, "signature": signature])
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        XCTAssertNotNil(PackStore.verified(envelope, publicKey: publicKey))
        let tampered = try JSONSerialization.data(withJSONObject: ["body": body + " ", "signature": signature])
        XCTAssertNil(PackStore.verified(tampered, publicKey: publicKey), "A changed body fails the signature")
        XCTAssertNotNil(PackStore.verified(tampered, publicKey: ""), "No key configured: development mode accepts it")
        let manifest = try XCTUnwrap(PackStore.verified(envelope, publicKey: ""))
        XCTAssertTrue(PackStore.isSupported(manifest, appVersion: "1.0"))
        XCTAssertFalse(PackStore.isSupported(PackManifest(schema: 1, minAppVersion: "2.0", packs: []), appVersion: "1.5"))
    }

    // MARK: Weather at the game's start time

    func testWeatherUsesTheHourOfTheGame() throws {
        let json = #"{"hourly":{"time":["2016-10-30T23:00","2016-10-31T00:00","2016-10-31T01:00"],"temperature_2m":[58.2,54.04,50.9],"weather_code":[3,0,61]}}"#
        let chicago = TimeZone(identifier: "America/Chicago")!
        // 7:08 PM CDT = 00:08 UTC: the 00:00 UTC hour, 54 degrees, clear and (at 7 PM) not yet night.
        let seven = ISO8601DateFormatter().date(from: "2016-10-31T00:08:00Z")!
        let weather = try XCTUnwrap(WeatherLookup.parse(Data(json.utf8), at: seven, venueTimeZone: chicago))
        XCTAssertEqual(weather.temperatureF, 54.0)
        XCTAssertEqual(weather.condition, "Clear")
        XCTAssertEqual(weather.symbol, "sun.max.fill")
        // 7:40 PM CDT reads the next hour (01:00 UTC): rain, 50.9.
        let later = ISO8601DateFormatter().date(from: "2016-10-31T00:40:00Z")!
        XCTAssertEqual(WeatherLookup.parse(Data(json.utf8), at: later, venueTimeZone: chicago)?.condition, "Rain")
        // An hour the service did not return is no weather, not a wrong one.
        let missing = ISO8601DateFormatter().date(from: "2016-11-02T00:00:00Z")!
        XCTAssertNil(WeatherLookup.parse(Data(json.utf8), at: missing, venueTimeZone: chicago))
    }

    func testIndoorVenuesGetNoWeather() {
        let arena = Venue(id: "a", name: "United Center", city: "Chicago", region: "IL", country: "United States", countryCode: "US",
                          latitude: 41.88, longitude: -87.67, sports: [.basketball, .hockey], timeZone: "America/Chicago",
                          capacity: 23500, opened: 1994)
        XCTAssertTrue(arena.likelyIndoor)
        XCTAssertFalse(lambeau.likelyIndoor)
        var dome = lambeau
        dome.name = "Caesars Superdome"
        XCTAssertTrue(dome.likelyIndoor)
    }

    // MARK: Soccer goals and own goals

    /// Bosnia and Herzegovina 3, Qatar 1, Lumen Field, 24 June 2026: ESPN lists an own goal on the beneficiary's side.
    func testOwnGoalCountsForTheSideThatGainsIt() {
        let home = FoundGame.Side(espnId: "452", abbreviation: "BIH", location: "Bosnia-Herzegovina", name: "Bosnia-Herzegovina",
                                  color: nil, altColor: nil, score: 3, line: [])
        let away = FoundGame.Side(espnId: "4398", abbreviation: "QAT", location: "Qatar", name: "Qatar",
                                  color: nil, altColor: nil, score: 1, line: [])
        let game = FoundGame(league: "soccer/fifa.world", leagueName: "FIFA World Cup", eventId: "760462", sport: .soccer,
                             start: ISO8601DateFormatter().date(from: "2026-06-24T19:00:00Z")!, venueName: "Lumen Field",
                             venueCity: "Seattle", home: home, away: away, completed: true, note: nil)
        let json = #"""
        {"keyEvents":[
          {"type":{"text":"Goal"},"clock":{"displayValue":"29'"},"team":{"id":"452"},"text":"Goal! Bosnia and Herzegovina 1, Qatar 0. Kerim Alajbegovic (Bosnia and Herzegovina) right footed shot."},
          {"type":{"text":"Own Goal"},"clock":{"displayValue":"34'"},"team":{"id":"452"},"text":"Own Goal by Mahmoud Abunada, Qatar. Bosnia and Herzegovina 2, Qatar 0."},
          {"type":{"text":"Goal"},"clock":{"displayValue":"42'"},"team":{"id":"4398"},"text":"Goal! Bosnia and Herzegovina 2, Qatar 1. Hassan Al Haydos (Qatar) right footed shot."},
          {"type":{"text":"Goal"},"clock":{"displayValue":"80'"},"team":{"id":"452"},"text":"Goal! Bosnia and Herzegovina 3, Qatar 1. Ermin Mahmic (Bosnia and Herzegovina) right footed shot."}
        ]}
        """#
        let detail = GameLookup.parseDetail(Data(json.utf8), game: game)
        XCTAssertEqual(detail.plays.prefix(4).map { "\($0.homeScore)-\($0.awayScore)" }, ["1-0", "2-0", "2-1", "3-1"])
        XCTAssertEqual(GameLookup.runningScore(in: "Goal! Bosnia and Herzegovina 2, Qatar 1. Hassan Al Haydos", game: game)?.home, 2)
        XCTAssertEqual(GameLookup.runningScore(in: "Goal! Qatar 1, Bosnia and Herzegovina 2. X", game: game)?.home, 2,
                       "The order in the text is read by team name, not assumed")
        XCTAssertNil(GameLookup.runningScore(in: "Delay in match because of an injury", game: game))
    }
}
