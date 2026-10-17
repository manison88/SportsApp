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
}
