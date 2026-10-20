import XCTest
import CoreLocation
@testable import Witness

/// The owner's onboarding scan offered "Stamford Bridge · Mar 25, 2026 · 1:04 AM · 47 photos" as a stadium visit. The photos
/// were a landing at Heathrow: window shots over west London, a selfie in the cabin, a dog on the terminal floor. The approach
/// crosses the ground at 1,000 m and the phone's fix put the window shots inside its fence. A photo in the air, or on the
/// move, never places a visit; a visit with no game needs the photos inside its fence to show the ground from the ground.
@MainActor
final class AirborneTests: XCTestCase {
    private var library: Library!
    private var ledgerURL: URL!
    private var pendingURL: URL!

    override func setUp() async throws {
        library = Library(storeURL: temp("library"))
        ledgerURL = temp("ledger")
        pendingURL = temp("pending")
        let mlb = try fixture("mlb-scoreboard-20260624")
        GameLookup.responder = { url in
            let s = url.absoluteString
            guard s.contains("/scoreboard?") else { return nil }
            if s.contains("baseball/mlb/scoreboard?dates=20260624") { return mlb }
            return Data(#"{"events":[]}"#.utf8)
        }
    }

    override func tearDown() async throws {
        GameLookup.responder = nil
    }

    private func temp(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "air-\(name)-\(UUID().uuidString).json")
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    private static func point(_ id: String, _ utc: String, _ lat: Double, _ lon: Double, up altitude: Double? = nil,
                              speed: Double? = nil) -> PhotoPoint {
        PhotoPoint(id: id, date: ISO8601DateFormatter().date(from: utc)!, latitude: lat, longitude: lon, altitude: altitude, speed: speed)
    }

    private func model(_ points: [PhotoPoint], look: SceneCheck.DayLook = .init()) -> ScanModel {
        ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in PhotoMatcher.found(in: points, venues: venues, existing: existing) },
            look: { _, _ in look },
            suggest: { _, _, _, _, _, _ in [] }))
    }

    private func scan(_ points: [PhotoPoint], look: SceneCheck.DayLook = .init()) async -> (ScanModel, ScanModel.Review) {
        let scan = model(points, look: look)
        scan.start(library: library)
        await scan.finished()
        return (scan, scan.takeForReview(library: library))
    }

    /// A scene check that would have passed every gate: most photos a stadium, half of them the ground itself.
    private let convincing = SceneCheck.DayLook(classified: 7, venue: 5, elsewhere: 1, structure: 4)

    // MARK: The owner's landing

    /// 1:04 AM in Chicago on March 25 2026 is 06:04 GMT: the approach to Heathrow from the east, over the Thames, Battersea
    /// and Stamford Bridge (two window shots inside its fence at 1,000 m), the cabin at the gate sixteen minutes later with the
    /// fix the phone still had, and a dog on the terminal floor at 25 m.
    private var landing: [PhotoPoint] {
        [
            Self.point("thames", "2026-03-25T06:01:00Z", 51.4790, -0.0500, up: 1_500),
            Self.point("waterloo", "2026-03-25T06:01:45Z", 51.4800, -0.1000, up: 1_350),     // 3.5 km on, 45 s later
            Self.point("battersea", "2026-03-25T06:02:30Z", 51.4810, -0.1500, up: 1_200),
            Self.point("bridge-1", "2026-03-25T06:03:00Z", 51.4817, -0.1900, up: 1_050),     // inside Stamford Bridge's fence
            Self.point("bridge-2", "2026-03-25T06:03:20Z", 51.4818, -0.1925, up: 1_000),
            Self.point("cabin-selfie", "2026-03-25T06:19:00Z", 51.4817, -0.1905, up: 1_000), // the phone's last fix
            Self.point("terminal-dog", "2026-03-25T06:40:00Z", 51.4700, -0.4543, up: 25),
        ]
    }

    func testTheLandingIsInTheAir() {
        let verdicts = TransitCheck.verdicts(landing)
        for id in ["thames", "waterloo", "battersea", "bridge-1", "bridge-2", "cabin-selfie"] {
            guard case .airborne(let above) = verdicts[id] else { return XCTFail("\(id) is not in the air: \(String(describing: verdicts[id]))") }
            XCTAssertGreaterThan(above, 900, id)
        }
        XCTAssertNil(verdicts["terminal-dog"], "The terminal floor is the ground")
        // The grouping rule itself: nothing inside the fence was on the ground, so there is no visit, and no day around one.
        let found = PhotoMatcher.found(in: landing, venues: library.venues, existing: [])
        XCTAssertTrue(found.visits.isEmpty, found.visits.map(\.id).joined(separator: ", "))
        XCTAssertTrue(found.nearby.isEmpty)
    }

    /// Onboarding: nothing is offered, however convincing the window shots look to the classifier.
    func testTheLandingIsNotOfferedAsAStadiumVisit() async throws {
        let (scan, review) = await scan(landing, look: convincing)
        XCTAssertEqual(scan.state, .empty)
        XCTAssertTrue(review.games.isEmpty)
        XCTAssertTrue(review.others.isEmpty, "The landing was offered as a stadium visit at \(review.others.map(\.venue.name))")
        XCTAssertTrue(review.possible.isEmpty)
        XCTAssertTrue(scan.pendingVisits.isEmpty, "Nothing waits for the background search either")
    }

    /// The same approach with no altitude on the fixes: the speed between shots (3 km in 30 s) says the phone was in a vehicle.
    func testTheLandingWithNoAltitudeIsOnTheMove() async throws {
        let flat = [
            Self.point("thames", "2026-03-25T06:01:00Z", 51.4790, -0.0500),
            Self.point("waterloo", "2026-03-25T06:01:45Z", 51.4800, -0.1000),
            Self.point("battersea", "2026-03-25T06:02:30Z", 51.4810, -0.1500),
            Self.point("bridge-1", "2026-03-25T06:03:00Z", 51.4817, -0.1900),
            Self.point("bridge-2", "2026-03-25T06:03:20Z", 51.4818, -0.1925),
            Self.point("hammersmith", "2026-03-25T06:03:50Z", 51.4850, -0.2300),
            Self.point("terminal-dog", "2026-03-25T06:40:00Z", 51.4700, -0.4543),
        ]
        let verdicts = TransitCheck.verdicts(flat)
        for id in ["thames", "waterloo", "battersea", "bridge-1", "bridge-2", "hammersmith"] {
            guard case .moving(let speed) = verdicts[id] else { return XCTFail("\(id) is not on the move: \(String(describing: verdicts[id]))") }
            XCTAssertGreaterThan(speed, 60, id)
        }
        XCTAssertNil(verdicts["terminal-dog"])
        let (_, review) = await scan(flat, look: convincing)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    /// The fix's own speed, when the phone recorded one, is enough on its own.
    func testAFixAtAirlinerSpeedIsOnTheMove() {
        let verdicts = TransitCheck.verdicts([Self.point("window", "2026-03-25T06:03:00Z", 51.4817, -0.1900, speed: 75)])
        XCTAssertEqual(verdicts["window"], .moving(speed: 75))
        XCTAssertTrue(TransitCheck.verdicts([Self.point("walk", "2026-03-25T06:03:00Z", 51.4817, -0.1900, speed: 1.4)]).isEmpty)
    }

    // MARK: Real visits still stand

    /// A tour of Stamford Bridge: six photos inside the fence at 30 m over forty minutes, the hotel two hours before.
    private var tour: [PhotoPoint] {
        [Self.point("hotel", "2026-03-25T09:00:00Z", 51.5010, -0.1920, up: 28)]
            + (0..<6).map { n in
                Self.point("stand-\(n)", "2026-03-25T11:\(String(format: "%02d", n * 8)):00Z",
                           51.4815 + Double(n) * 0.0001, -0.1915 + Double(n) * 0.0002, up: 30 + Double(n))
            }
    }

    func testATourOfTheGroundIsStillOffered() async throws {
        XCTAssertTrue(TransitCheck.verdicts(tour).isEmpty, "Everyone was on the ground")
        let (_, review) = await scan(tour, look: SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 4))
        XCTAssertTrue(review.games.isEmpty)
        let visit = try XCTUnwrap(review.others.first, "The tour was not offered")
        XCTAssertEqual(visit.venue.id, "stamford-bridge")
        XCTAssertEqual(visit.assetIds.count, 7)
        XCTAssertEqual(visit.insideIds?.count, 6, "The six photos inside the fence placed it")
    }

    /// The same tour judged by photos that do not show the ground (the museum, the shop, a selfie by the gate) waits for the
    /// background search instead; one with a plane in the window never passes.
    func testATourNeedsThreePhotosOfTheGroundFromTheGround() async throws {
        var (scan, review) = await scan(tour, look: SceneCheck.DayLook(classified: 6, venue: 4, elsewhere: 0, structure: 2))
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertEqual(scan.pendingVisits.count, 1, "Waits for the background search")
        (scan, review) = await self.scan(tour, look: SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 4, aerial: 1))
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertEqual(scan.pendingVisits.count, 1)
    }

    /// The background search's offer for a waiting visit is judged by the photos inside the fence too.
    func testTheBackgroundSearchJudgesAWaitingVisitByThePhotosInsideTheFence() async throws {
        let cluster = try XCTUnwrap(VisitGrouping.group(tour, venues: library.venues, minimumStay: 15 * 60).visits.first)
        var seen: [String] = []
        let offered = await ScanModel.waitingDay(cluster, venues: library.venues) { ids in
            seen = ids
            return SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 3)
        }
        XCTAssertEqual(seen, cluster.insideIds)
        let day = try XCTUnwrap(offered, "A visit whose photos show the ground is offered")
        XCTAssertEqual(day.suggestions.first?.id, "stamford-bridge")
        XCTAssertTrue(day.reason.contains("Stamford Bridge"), day.reason)
        let kept = await ScanModel.waitingDay(cluster, venues: library.venues) { _ in SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 2) }
        XCTAssertNil(kept, "Two photos of the ground are not enough for a visit with no game")
    }

    /// Red Sox at Rockies, Coors Field, June 24 2026, 1:10 PM in Denver, a mile up: the hotel downtown that morning is at
    /// 1,605 m and the ballpark at 1,610 to 1,625 m, so nothing is in the air. The rule is relative to the photos nearby.
    func testAGameDayAMileUpIsStillAVisit() async throws {
        let denver = [
            Self.point("hotel", "2026-06-24T16:00:00Z", 39.7470, -104.9920, up: 1_605),
            Self.point("gate", "2026-06-24T19:00:00Z", 39.7561, -104.9935, up: 1_610),
            Self.point("first-pitch", "2026-06-24T19:12:00Z", 39.7563, -104.9942, up: 1_622),
            Self.point("seventh", "2026-06-24T21:05:00Z", 39.7560, -104.9945, up: 1_625),
            Self.point("final", "2026-06-24T22:10:00Z", 39.7558, -104.9940, up: 1_612),
        ]
        XCTAssertTrue(TransitCheck.verdicts(denver).isEmpty, "A town at 1,600 m is on the ground")
        let (scan, review) = await scan(denver)
        XCTAssertEqual(review.games.count, 1)
        let game = try XCTUnwrap(review.games.first)
        XCTAssertEqual(game.venue.id, "mlb-col")
        // The schedule may come from a downloaded pack rather than the fixture, so the teams, not the event id.
        let match = try XCTUnwrap(scan.matches[game.id])
        XCTAssertEqual(match.home.abbreviation, "COL")
        XCTAssertEqual(match.away.abbreviation, "BOS")
    }

    /// A car along the Fulham Road at 25 m/s: a photo a kilometre before the ground, one inside the fence, one a kilometre
    /// past, forty seconds apart, then home two hours later. The one inside the fence was taken on the move.
    func testADriveByIsNotAVisit() async throws {
        let driveBy = [
            Self.point("east-2", "2026-03-27T15:00:00Z", 51.4830, -0.1620),
            Self.point("east-1", "2026-03-27T15:00:40Z", 51.4823, -0.1765),
            Self.point("past-the-gate", "2026-03-27T15:01:20Z", 51.4817, -0.1910),
            Self.point("west-1", "2026-03-27T15:02:00Z", 51.4811, -0.2055),
            Self.point("west-2", "2026-03-27T15:02:40Z", 51.4805, -0.2200),
            Self.point("home", "2026-03-27T17:10:00Z", 51.5100, -0.2500),
        ]
        let verdicts = TransitCheck.verdicts(driveBy)
        guard case .moving(let speed) = verdicts["past-the-gate"] else { return XCTFail("The photo inside the fence was not on the move") }
        XCTAssertEqual(speed, 25, accuracy: 1)
        XCTAssertNil(verdicts["home"])
        XCTAssertTrue(PhotoMatcher.found(in: driveBy, venues: library.venues, existing: []).visits.isEmpty)
        let (_, review) = await scan(driveBy, look: convincing)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    /// A fix that jumps a few hundred metres inside a full bowl is not a vehicle: a kilometre is the least that counts.
    func testAJumpingFixInsideTheBowlStaysOnTheGround() {
        let jumpy = [
            Self.point("a", "2026-03-25T15:00:00Z", 51.4817, -0.1911),
            Self.point("b", "2026-03-25T15:00:10Z", 51.4845, -0.1911), // 310 m north, 31 m/s
            Self.point("c", "2026-03-25T15:00:20Z", 51.4817, -0.1911),
        ]
        XCTAssertTrue(TransitCheck.verdicts(jumpy).isEmpty)
    }

    // MARK: The pieces

    /// What the photo library's fix carries: EXIF with no altitude reads as 0 with no vertical accuracy.
    func testAltitudeAndSpeedComeFromTheFixWhenItHasThem() {
        func fix(altitude: Double, vertical: Double, speed: Double = -1) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 51.48, longitude: -0.19), altitude: altitude,
                       horizontalAccuracy: 10, verticalAccuracy: vertical, course: -1, speed: speed, timestamp: .now)
        }
        XCTAssertNil(PhotoPoint.altitude(of: fix(altitude: 0, vertical: -1)))
        XCTAssertEqual(PhotoPoint.altitude(of: fix(altitude: 1_200, vertical: -1)), 1_200)
        XCTAssertEqual(PhotoPoint.altitude(of: fix(altitude: 0, vertical: 5)), 0, "Sea level with an accuracy is real")
        XCTAssertNil(PhotoPoint.speed(of: fix(altitude: 0, vertical: -1)))
        XCTAssertEqual(PhotoPoint.speed(of: fix(altitude: 0, vertical: -1, speed: 50)), 50)
    }

    func testTheClassifierTellsAWindowSeatFromTheStands() {
        XCTAssertTrue(SceneCheck.fromTheAir([("airplane", 0.6), ("sky", 0.5)]))
        XCTAssertTrue(SceneCheck.fromTheAir([("airport", 0.4), ("dog", 0.7)]))
        XCTAssertFalse(SceneCheck.fromTheAir([("stadium", 0.8), ("arena", 0.7), ("airplane", 0.1)]))
        XCTAssertTrue(SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 3).showsTheGround())
        XCTAssertFalse(SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 2).showsTheGround())
        XCTAssertFalse(SceneCheck.DayLook(classified: 6, venue: 5, elsewhere: 0, structure: 4, aerial: 1).showsTheGround())
        XCTAssertFalse(SceneCheck.DayLook(classified: 6, venue: 3, elsewhere: 3, structure: 3).showsTheGround())
    }

    /// A visit saved before the photos inside the fence were kept still reads, and is judged by all its photos.
    func testAnOlderPendingVisitStillReads() throws {
        let json = #"{"id":"stamford-bridge|2026-03-25","venue":\#(String(decoding: try JSONEncoder().encode(library.venue("stamford-bridge")!), as: UTF8.self)),"start":0,"end":0,"assetIds":["a","b"],"times":[0,0]}"#
        let cluster = try JSONDecoder().decode(PhotoCluster.self, from: Data(json.utf8))
        XCTAssertNil(cluster.insideIds)
        XCTAssertEqual(cluster.anchors, ["a", "b"])
    }

    /// The scan check shows each photo's altitude and verdict, the visit the landing would have made, and why it is dropped.
    func testScanCheckShowsTheAirAndTheRoad() {
        let zone = TimeZone(identifier: "Europe/London")!
        let text = ScanCheck.lines(points: landing, venues: library.venues, saved: [], zone: zone).joined(separator: "\n")
        XCTAssertTrue(text.contains("Photos: 7 (7 with a location, 0 without) \u{00B7} 6 in the air, 0 on the move: these never place a visit"), text)
        XCTAssertTrue(text.contains("06:03  51.48170,-0.19000  inside Stamford Bridge (77 m, fence 200 m) \u{00B7} 1050 m up \u{00B7} in the air, 1025 m above the lowest photo nearby (limit 250 m)"), text)
        XCTAssertTrue(text.contains("06:40  51.47000,-0.45430  no stadium within 2 km \u{00B7} 25 m up\n"), text)
        XCTAssertTrue(text.contains("Visits (scan rule: a photo inside the fence, on the ground and not on the move, and the day's photos 15+ min apart):\n  none"), text)
        XCTAssertTrue(text.contains("Visits the photos would make if every one were on the ground (the scan drops these: every photo inside the fence was in the air or on the move):\n  Stamford Bridge [stamford-bridge|2026-03-25]: 7 photos, 06:01\u{2013}06:40 (3 inside the fence)"), text)

        let road = ScanCheck.lines(points: [
            Self.point("east-1", "2026-03-27T15:00:40Z", 51.4823, -0.1765),
            Self.point("past-the-gate", "2026-03-27T15:01:20Z", 51.4817, -0.1910),
        ], venues: library.venues, saved: [], zone: zone).joined(separator: "\n")
        XCTAssertTrue(road.contains("inside Stamford Bridge (8 m, fence 200 m) \u{00B7} on the move, 25 m/s (limit 20 m/s over 1 km)"), road)

        let kept = ScanCheck.tourLine(PhotoCluster(id: "x", venue: library.venue("stamford-bridge")!, start: .now, end: .now, assetIds: ["a", "b", "c", "d"],
                                                   times: [.now, .now, .now, .now], insideIds: ["a", "b", "c"]),
                                      look: SceneCheck.DayLook(classified: 3, venue: 3, elsewhere: 0, structure: 3))
        XCTAssertEqual(kept, "scene check of the 3 photos inside the fence: 3 classified, 3 the ground itself, 0 from the air, 0 somewhere else \u{2192} offered as a stadium visit (needs 3+ of the ground itself, none from the air, under half somewhere else)")
    }
}
