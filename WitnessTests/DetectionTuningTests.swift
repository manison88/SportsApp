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
        // Venue labels are matched whole, so each must be a real identifier.
        let known = Set(ids)
        for label in SceneCheck.venueLabels.union(SceneCheck.structureLabels) { XCTAssertTrue(known.contains(label), label) }
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

    /// Records what the classifier says about real stadium photos, so the word lists and thresholds can be tuned on facts.
    func testRecordsSceneLabelsForStadiumPhotos() async throws {
        for name in ["wrigley-night", "fenway-night", "soldier-aerial", "united-center-court", "lambeau-exterior", "camp-nou-aerial"] {
            guard let image = UIImage(named: name) else { continue }
            let labels = await SceneCheck.labels(for: image) ?? []
            let top = labels.sorted { $0.1 > $1.1 }.prefix(14).map { "\($0.0)=\(String(format: "%.2f", $0.1))" }.joined(separator: ", ")
            let score = SceneCheck.score(labels)
            let text = "\(name): sports \(String(format: "%.2f", score.sports)), event \(String(format: "%.2f", score.event)), elsewhere \(String(format: "%.2f", score.elsewhere))\n\(top)"
            let a = XCTAttachment(string: text)
            a.name = "scene-\(name)"
            a.lifetime = .keepAlways
            add(a)
            print("SCENE-PHOTO", text)
            // A stadium must never read as clearly somewhere else.
            XCTAssertFalse(SceneVerdict(sports: score.sports, elsewhere: score.elsewhere, event: score.event).clearlyElsewhere, name)
        }
    }
}
