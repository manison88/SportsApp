import XCTest
@testable import Witness

@MainActor
final class OtherSportTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "other-\(UUID().uuidString).json")
    }

    func testOtherRoundTripsThroughJSON() throws {
        var g = GameEntry(sport: .other, date: .now, venueId: "wrigley", origin: .manual)
        g.sportLabel = "Rugby"
        let back = try JSONDecoder().decode(GameEntry.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(back.sport, .other)
        XCTAssertEqual(back.sportLabel, "Rugby")
        XCTAssertEqual(try JSONDecoder().decode(Sport.self, from: Data("\"other\"".utf8)), .other)
    }

    func testUnknownSportDecodesAsOther() throws {
        XCTAssertEqual(try JSONDecoder().decode(Sport.self, from: Data("\"curling\"".utf8)), .other)
    }

    func testOldGameWithoutSportLabelLoads() throws {
        var g = GameEntry(sport: .baseball, date: .now, venueId: "wrigley", origin: .manual)
        g.sportLabel = "x"
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(g)) as! [String: Any]
        json.removeValue(forKey: "sportLabel")
        let back = try JSONDecoder().decode(GameEntry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(back.sportLabel)
        XCTAssertEqual(back.sportName, "Baseball")
    }

    func testSportName() {
        var g = GameEntry(sport: .other, date: .now, venueId: "v", origin: .manual)
        XCTAssertEqual(g.sportName, "Other", "No label yet")
        g.sportLabel = "  Rodeo "
        XCTAssertEqual(g.sportName, "Rodeo")
        g.sportLabel = "   "
        XCTAssertEqual(g.sportName, "Other")
        var h = GameEntry(sport: .hockey, date: .now, venueId: "v", origin: .manual)
        h.sportLabel = "Rugby"
        XCTAssertEqual(h.sportName, Sport.hockey.name, "A label only counts for Other")
    }

    func testOtherGameIsKeptAndShownByName() {
        let url = tempURL()
        let library = Library(storeURL: url)
        var g = GameEntry(sport: .other, date: .now, venueId: "wrigley", origin: .manual)
        g.sportLabel = "Rugby"
        library.add(g)
        let reloaded = Library(storeURL: url)
        XCTAssertEqual(reloaded.games.first?.sportName, "Rugby")
        XCTAssertTrue(reloaded.games.contains { $0.sport == .other })
        XCTAssertTrue(matchupText(reloaded.games[0], reloaded).hasPrefix("Rugby"))
        XCTAssertTrue(OtherSportField.suggestions.contains("Rugby"))
        XCTAssertTrue(reloaded.venues.allSatisfy { reloaded.hosts($0, .other) })
    }
}
