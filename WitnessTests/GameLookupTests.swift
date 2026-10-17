import XCTest
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
        XCTAssertEqual(GameLookup.leagues(for: lambeau), ["football/nfl", "football/college-football"])
        var camp = lambeau
        camp.sports = [.soccer]
        camp.countryCode = "ES"
        XCTAssertEqual(GameLookup.leagues(for: camp), ["soccer/esp.1"])
    }

    func testDaysFollowTheVenueTimeZone() {
        let start = GameLookup.date("2016-10-31T00:15Z")!   // 7:15 PM Oct 30 in Chicago
        let days = GameLookup.dayStrings(from: start.addingTimeInterval(-5 * 3600), to: start.addingTimeInterval(4 * 3600),
                                         tz: TimeZone(identifier: "America/Chicago")!)
        XCTAssertEqual(days, ["20161030"])
    }
}
