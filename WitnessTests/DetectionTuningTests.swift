import XCTest
import Vision
@testable import Witness

@MainActor
final class DetectionTuningTests: XCTestCase {
    private var library: Library!

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "tune-\(UUID().uuidString).json"))
    }

    func testGeofenceIsTightButFitsBigBowls() {
        let wrigley = library.venue("wrigley")!
        XCTAssertEqual(wrigley.geofence, 200)
        // 300 m away: the bar across the street, not the bleachers.
        let across = VisitGrouping.nearestVenue(lat: wrigley.latitude + 0.0027, lon: wrigley.longitude, in: library.venues)
        XCTAssertNotEqual(across?.id, "wrigley")
        let inside = VisitGrouping.nearestVenue(lat: wrigley.latitude + 0.0008, lon: wrigley.longitude, in: library.venues)
        XCTAssertEqual(inside?.id, "wrigley")
        if let big = library.venues.first(where: { ($0.capacity ?? 0) >= 100_000 }) {
            XCTAssertEqual(big.geofence, 300)
        }
    }

    func testSceneScoring() {
        let game = SceneCheck.score([("baseball", 0.7), ("crowd", 0.4), ("beer", 0.2)])
        XCTAssertGreaterThan(game.sports, 0.6)
        let party = SceneCheck.score([("bar", 0.6), ("cocktail", 0.4), ("people", 0.5)])
        XCTAssertEqual(party.sports, 0)
        XCTAssertTrue(SceneVerdict(sports: party.sports, elsewhere: party.elsewhere).doubtful)
        XCTAssertFalse(SceneVerdict(sports: game.sports, elsewhere: game.elsewhere).doubtful)
    }

    /// Logs the classifier's sport and nightlife labels so the word lists can be tuned against Apple's taxonomy.
    func testClassifierTaxonomyHasSportsLabels() throws {
        let ids: [String]
        do {
            ids = try VNClassifyImageRequest().supportedIdentifiers()
        } catch {
            throw XCTSkip("Image classifier not available here: \(error)")
        }
        let sports = ids.filter { id in SceneCheck.sportsWords.contains { id.contains($0) } }
        let elsewhere = ids.filter { id in SceneCheck.elsewhereWords.contains { id == $0 || id.hasPrefix($0 + "_") || id.hasSuffix("_" + $0) } }
        print("SCENE sports labels (\(sports.count)):", sports.joined(separator: ", "))
        print("SCENE elsewhere labels (\(elsewhere.count)):", elsewhere.joined(separator: ", "))
        XCTAssertGreaterThan(sports.count, 3)
    }

    func testTicketScreenshotBecomesAnAnchor() {
        let text = """
        ticketmaster
        Chicago Cubs vs. Milwaukee Brewers
        Sat, Aug 9, 2025 1:20 PM
        Wrigley Field
        SEC 209 ROW 4 SEAT 11
        """
        let anchor = TicketAnchors.anchor(from: text, assetId: "x", teams: library.allTeams, venues: library.venues)
        XCTAssertEqual(anchor?.venue.id, "wrigley")
        XCTAssertNotNil(anchor?.date)
        XCTAssertNil(TicketAnchors.anchor(from: "Dinner at Gino's, Aug 9 2025", assetId: "y",
                                          teams: library.allTeams, venues: library.venues), "Not a ticket")
    }
}
