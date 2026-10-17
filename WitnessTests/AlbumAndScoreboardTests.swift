import XCTest
import UIKit
@testable import Witness

@MainActor
final class AlbumAndScoreboardTests: XCTestCase {
    private var library: Library!

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "album-\(UUID().uuidString).json"))
    }

    private func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    // MARK: Grouping

    func testAlbumGroupsVisitsAsksForTheRest() {
        let wrigley = library.venue("wrigley")!
        let points = [
            // Game night at Wrigley: two GPS photos, one copy with no location from the same evening.
            PhotoPoint(id: "a", date: date("2016-10-31T00:10:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude),
            PhotoPoint(id: "b", date: date("2016-10-31T03:40:00Z"), latitude: wrigley.latitude + 0.001, longitude: wrigley.longitude),
            PhotoPoint(id: "c", date: date("2016-10-31T02:00:00Z"), latitude: nil, longitude: nil),
            // Downtown the next day, nowhere near a stadium.
            PhotoPoint(id: "d", date: date("2016-11-01T18:00:00Z"), latitude: 41.8827, longitude: -87.6233),
            // A scan with no date at all.
            PhotoPoint(id: "e", date: nil, latitude: nil, longitude: nil),
        ]
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.count, 1)
        XCTAssertEqual(scan.visits.first?.venue.id, "wrigley")
        XCTAssertEqual(Set(scan.visits.first?.assetIds ?? []), ["a", "b", "c"], "Location-less photos from the visit's day join it")
        XCTAssertEqual(scan.unplacedDays.map(\.assetIds), [["d"]])
        XCTAssertEqual(scan.undated, ["e"])
    }

    func testDiscoveryRuleSkipsDriveBys() {
        let wrigley = library.venue("wrigley")!
        let one = [PhotoPoint(id: "a", date: date("2016-10-31T00:10:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude)]
        XCTAssertTrue(VisitGrouping.group(one, venues: library.venues, minimumStay: 15 * 60).visits.isEmpty)
        XCTAssertEqual(VisitGrouping.group(one, venues: library.venues).visits.count, 1, "An album the fan chose is trusted")
    }

    /// A fan's matchday in Cardiff: the pub before (1.8 km away), the ground, a stadium tour in London another day.
    func testMatchdayPubJoinsTheGameAndTourStandsAlone() {
        let cardiff = library.venue("cardiff-city-stadium")!
        let bridge = library.venue("stamford-bridge")!
        let points = [
            PhotoPoint(id: "pub", date: date("2026-03-26T17:30:00Z"), latitude: 51.4810, longitude: -3.1790),
            PhotoPoint(id: "ground", date: date("2026-03-26T19:20:00Z"), latitude: cardiff.latitude + 0.0008, longitude: cardiff.longitude),
            PhotoPoint(id: "board", date: date("2026-03-26T21:40:00Z"), latitude: cardiff.latitude, longitude: cardiff.longitude + 0.001),
            PhotoPoint(id: "tour", date: date("2026-03-28T11:00:00Z"), latitude: bridge.latitude, longitude: bridge.longitude),
        ]
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.map(\.venue.id), ["cardiff-city-stadium", "stamford-bridge"])
        XCTAssertEqual(Set(scan.visits[0].assetIds), ["pub", "ground", "board"], "The pub is outside the 200 m fence but on the day")
        XCTAssertTrue(scan.unplacedDays.isEmpty)
        XCTAssertTrue(GameLookup.leagues(for: cardiff).contains("soccer/fifa.worldq.uefa"))
        XCTAssertTrue(GameLookup.leagues(for: library.venue("lumen-field")!).contains("soccer/fifa.world"))
    }

    // MARK: Scoreboards

    func testCrestBoardConfirmsByScoreAlone() {
        func side(_ code: String, _ name: String, _ score: Int) -> FoundGame.Side {
            .init(espnId: code, abbreviation: code, location: name, name: name, color: nil, altColor: nil, score: score, line: [])
        }
        let wal = FoundGame(league: "soccer/fifa.worldq.uefa", leagueName: "FIFA World Cup Qualifying - UEFA", eventId: "1",
                            sport: .soccer, start: .now, venueName: "Cardiff City Stadium", venueCity: "Cardiff",
                            home: side("WAL", "Wales", 1), away: side("BIH", "Bosnia-Herzegovina", 1),
                            completed: true, note: nil)
        let crests = ScoreboardReader.reading(from: "1 - 1\nCROESO")
        XCTAssertEqual(ScoreboardReader.support(crests, for: wal), 0, "No team names on a crest board")
        XCTAssertTrue(ScoreboardReader.confirms(crests, wal))
        XCTAssertFalse(ScoreboardReader.confirms(ScoreboardReader.reading(from: "2 - 0"), wal))
        XCTAssertFalse(ScoreboardReader.confirms(ScoreboardReader.reading(from: "GATE 1 1 ROW 12 SEAT 4 5 6 7"), wal),
                       "Too many numbers to trust a bare pair")
    }

    private func game(home: (String, String, Int), away: (String, String, Int)) -> FoundGame {
        func side(_ t: (String, String, Int)) -> FoundGame.Side {
            .init(espnId: t.0, abbreviation: t.0, location: t.1, name: t.1, color: nil, altColor: nil, score: t.2, line: [])
        }
        return FoundGame(league: "hockey/nhl", leagueName: "NHL", eventId: "1", sport: .hockey, start: .now,
                         venueName: "United Center", venueCity: "Chicago", home: side(home), away: side(away),
                         completed: true, note: "Stanley Cup Final - Game 6")
    }

    func testReadingTokensAndScoreSupport() {
        let scf = game(home: ("CHI", "Chicago", 2), away: ("TB", "Tampa Bay", 0))
        let finalBoard = ScoreboardReader.reading(from: "FINAL\nTB 0\nCHI 2\n3RD 00:00")
        XCTAssertEqual(ScoreboardReader.support(finalBoard, for: scf), 2, "Teams and final score on the board")
        let midGame = ScoreboardReader.reading(from: "TB0 CHI1 2ND")
        XCTAssertEqual(ScoreboardReader.support(midGame, for: scf), 1, "Mid-game score still fits")
        let wrong = ScoreboardReader.reading(from: "NYR 4 BOS 1")
        XCTAssertEqual(ScoreboardReader.support(wrong, for: scf), 0)
    }

    /// The real path: draw a scoreboard, read it with Vision, check it against the game.
    func testVisionReadsARenderedScoreboard() async throws {
        let size = CGSize(width: 900, height: 420)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.05, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 96, weight: .heavy),
                                                        .foregroundColor: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)]
            ("TB   0" as NSString).draw(at: CGPoint(x: 60, y: 40), withAttributes: attrs)
            ("CHI  2" as NSString).draw(at: CGPoint(x: 60, y: 170), withAttributes: attrs)
            ("FINAL" as NSString).draw(at: CGPoint(x: 560, y: 300),
                                       withAttributes: [.font: UIFont.systemFont(ofSize: 54, weight: .bold), .foregroundColor: UIColor.white])
        }
        let text = try await TextRecognizer.text(in: image)
        let reading = ScoreboardReader.reading(from: text)
        XCTAssertEqual(ScoreboardReader.support(reading, for: game(home: ("CHI", "Chicago", 2), away: ("TB", "Tampa Bay", 0))), 2,
                       "Vision read: \(text)")
    }
}
