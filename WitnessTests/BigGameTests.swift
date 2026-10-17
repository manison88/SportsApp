import XCTest
@testable import Witness

/// Classification runs on what real schedules say (verified against ESPN responses) and on hand-entered labels.
final class BigGameTests: XCTestCase {
    private func stage(_ league: String, _ slug: String?, _ type: Int?, _ notes: [String]) -> GameEntry.Stage? {
        BigGame.classify(league: league, seasonSlug: slug, seasonType: type, notes: notes)
    }

    func testTitleGamesAcrossSports() {
        XCTAssertEqual(stage("football/nfl", "post-season", 3, ["Super Bowl LIX"]), .init(kind: .championship, label: "Super Bowl LIX"))
        XCTAssertEqual(stage("baseball/mlb", "post-season", 3, ["World Series - GAME 5"]), .init(kind: .championship, label: "World Series · Game 5"))
        XCTAssertEqual(stage("hockey/nhl", "post-season", 3, ["Stanley Cup Final - Game 7"])?.kind, .championship)
        XCTAssertEqual(stage("football/college-football", "post-season", 3,
                             ["College Football Playoff National Championship Presented by AT&T"]),
                       .init(kind: .championship, label: "College Football Playoff National Championship"))
        XCTAssertEqual(stage("soccer/uefa.champions", "final", 12082, []), .init(kind: .championship, label: "Champions League Final"))
        XCTAssertEqual(stage("soccer/fifa.world", "final", 10948, ["Argentina win 4-2 on penalties"]), .init(kind: .championship, label: "World Cup Final"))
        XCTAssertEqual(stage("soccer/usa.1", "mls-cup", 12312, []), .init(kind: .championship, label: "MLS Cup"))
    }

    func testPlayoffsAndKnockouts() {
        XCTAssertEqual(stage("football/nfl", "post-season", 3, ["AFC Wild Card Playoffs"]), .init(kind: .playoff, label: "AFC Wild Card Playoffs"))
        XCTAssertEqual(stage("football/college-football", "post-season", 3, ["ReliaQuest Bowl"])?.kind, .playoff)
        XCTAssertEqual(stage("soccer/uefa.champions", "semifinals", 12083, ["1st Leg"]), .init(kind: .playoff, label: "Champions League · Semifinal"))
        XCTAssertEqual(stage("basketball/mens-college-basketball", "post-season", 3, ["Men's Basketball Championship - Final Four"])?.kind, .playoff)
    }

    func testQualifyingPlayoffs() {
        // Wales v Bosnia and Herzegovina, Cardiff, 26 March 2026: as ESPN lists it.
        XCTAssertEqual(stage("soccer/fifa.worldq.uefa", "playoff-semifinals", 1, ["Bosnia-Herzegovina advance 4-2 on penalties"]),
                       .init(kind: .playoff, label: "World Cup qualifying · Playoff semifinal"))
        XCTAssertEqual(stage("soccer/fifa.worldq.uefa", "playoff-final", 1, []),
                       .init(kind: .playoff, label: "World Cup qualifying · Playoff final"))
        XCTAssertNil(stage("soccer/fifa.friendly", nil, 1, []))
    }

    func testQualifyingAndContinentalMatchesCountButLeagueGamesDoNot() {
        XCTAssertEqual(stage("soccer/fifa.worldq.uefa", "group-stage", 1, []),
                       .init(kind: .tournament, label: "World Cup qualifying · Group stage"))
        XCTAssertEqual(stage("soccer/uefa.nations", nil, 1, []), .init(kind: .tournament, label: "Nations League"))
        XCTAssertEqual(stage("soccer/uefa.champions", "league-phase", 12080, []),
                       .init(kind: .tournament, label: "Champions League · League phase"))
        XCTAssertEqual(stage("soccer/uefa.europa", "group-stage", 12080, []),
                       .init(kind: .tournament, label: "Europa League · Group stage"))
        XCTAssertNil(stage("soccer/uefa.champions", "1st-qualifying-round", 12079, []), "Early qualifying rounds are not big")
        XCTAssertNil(stage("soccer/usa.1", "regular-season", 2, []), "MLS regular season is a league, not a cup")
        XCTAssertEqual(stage("soccer/fifa.world", "round-of-16", 10950, []), .init(kind: .playoff, label: "World Cup · Round of 16"))
    }

    func testTournamentsAllStarsAndOrdinaryGames() {
        XCTAssertEqual(stage("soccer/fifa.world", "group-stage", 10953, []), .init(kind: .tournament, label: "World Cup · Group stage"))
        XCTAssertEqual(stage("baseball/mlb", "regular-season", 2, ["MLB All-Star Game"])?.kind, .allStar)
        XCTAssertNil(stage("soccer/eng.1", "2023-24-english-premier-league", 11864, []))
        XCTAssertNil(stage("football/nfl", "regular-season", 2, []))
    }

    func testHandEnteredLabels() {
        func label(_ s: String) -> GameEntry.Stage.Kind? {
            BigGame.classify(league: nil, seasonSlug: nil, seasonType: nil, notes: [s])?.kind
        }
        XCTAssertEqual(label("World Series · Game 5"), .championship)
        XCTAssertEqual(label("Stanley Cup Final · Game 6"), .championship)
        XCTAssertEqual(label("NLCS · Game 6"), .playoff)
        XCTAssertEqual(label("Wild Card"), .playoff)
        XCTAssertEqual(label("El Clásico"), .rivalry)
        XCTAssertEqual(label("Revierderby"), .rivalry)
        XCTAssertNil(label("Week 18"))
        XCTAssertNil(label("Opening Night"))
    }

    @MainActor
    func testSampleLibraryHasBigGames() {
        let library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "big-\(UUID().uuidString).json"))
        library.loadSample()
        let ws5 = library.game("mlb-2016-ws5")
        XCTAssertEqual(ws5?.bigGame?.kind, .championship)
        XCTAssertGreaterThanOrEqual(library.games.filter { $0.bigGame != nil }.count, 6)
    }

    @MainActor
    func testBundledThemesDressTheRightEvents() {
        XCTAssertGreaterThan(EventThemes.all.count, 40, "event-themes.json should be bundled")
        let library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "theme-\(UUID().uuidString).json"))
        var superBowl = GameEntry(sport: .football, date: ISO8601DateFormatter().date(from: "2025-02-10T00:30:00Z")!,
                                  venueId: "x", origin: .manual)
        superBowl.source = .init(provider: "espn", league: "football/nfl", eventId: "1")
        superBowl.stage = .init(kind: .championship, label: "Super Bowl LIX")
        let theme = EventThemes.theme(for: superBowl, library: library)
        XCTAssertEqual(theme?.id.hasPrefix("super-bowl"), true, "Got \(theme?.id ?? "nil")")
        var ordinary = superBowl
        ordinary.stage = nil
        ordinary.competition = nil
        XCTAssertNil(EventThemes.theme(for: ordinary, library: library))
    }

    @MainActor
    func testScoreHeadlineIsOneTeamPerLine() {
        let library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "headline-\(UUID().uuidString).json"))
        var entry = GameEntry(sport: .soccer, date: .now, venueId: "x", origin: .manual)
        entry.homeTeamId = library.addTeam(Team(id: "t-can", sport: .soccer, league: "FIFA", abbreviation: "CAN", locationName: "Canada",
                                                teamName: "Canada", monogram: "C", colors: .init(primary: "D52B1E", secondary: "FFFFFF", accent: "D52B1E"))).id
        entry.awayTeamId = library.addTeam(Team(id: "t-bih", sport: .soccer, league: "FIFA", abbreviation: "BIH", locationName: "Bosnia-Herzegovina",
                                                teamName: "Bosnia-Herzegovina", monogram: "B", colors: .init(primary: "002F6C", secondary: "FFFFFF", accent: "002F6C"))).id
        entry.homeScore = 2
        entry.awayScore = 1
        XCTAssertEqual(headlineText(entry, library), "Canada 2\nBosnia-Herzegovina 1")
        entry.homeScore = 0
        XCTAssertEqual(headlineText(entry, library), "Bosnia-Herzegovina 1\nCanada 0", "The winner leads")
    }
}
