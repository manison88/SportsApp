import XCTest
import CoreLocation
@testable import Witness

/// Two days the scan got wrong, and the two rules that put them right.
/// The owner's onboarding scan offered "Stamford Bridge · Mar 25, 2026 · 1:04 AM · 47 photos" as a stadium visit: a landing at
/// Heathrow, window shots over west London 1 to 3 km apart half a minute apart, the phone's fix inside the ground's fence. A
/// photo on the move never places a visit. Then the Nurburgring (Aug 5, 2023): 47 photos, a day at the circuit, every one of
/// them flagged "in the air" because the circuit sits 300 m above the valley the hotel is in. Altitude is gone: speed alone
/// tells a plane from a fan. A visit with no game on the schedule is a stadium visit when three photos inside the fence span
/// twenty minutes; fewer are dropped.
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

    private static func point(_ id: String, _ utc: String, _ lat: Double, _ lon: Double, speed: Double? = nil) -> PhotoPoint {
        PhotoPoint(id: id, date: ISO8601DateFormatter().date(from: utc)!, latitude: lat, longitude: lon, speed: speed)
    }

    private func model(_ points: [PhotoPoint]) -> ScanModel {
        ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in PhotoMatcher.found(in: points, venues: venues, existing: existing) },
            look: { _, _ in .init() },
            suggest: { _, _, _, _, _, _ in [] }))
    }

    private func scan(_ points: [PhotoPoint]) async -> (ScanModel, ScanModel.Review) {
        let scan = model(points)
        scan.start(library: library)
        await scan.finished()
        return (scan, scan.takeForReview(library: library))
    }

    // MARK: The owner's landing

    /// 1:04 AM in Chicago on March 25 2026 is 06:04 GMT: the approach to Heathrow from the east, over the Thames, Battersea
    /// and Stamford Bridge (two window shots inside its fence), Hammersmith, the cabin at the gate sixteen minutes later with
    /// the fix the phone still had, and a dog on the terminal floor.
    private var landing: [PhotoPoint] {
        [
            Self.point("thames", "2026-03-25T06:01:00Z", 51.4790, -0.0500),
            Self.point("waterloo", "2026-03-25T06:01:45Z", 51.4800, -0.1000),     // 3.5 km on, 45 s later
            Self.point("battersea", "2026-03-25T06:02:30Z", 51.4810, -0.1500),
            Self.point("bridge-1", "2026-03-25T06:03:00Z", 51.4817, -0.1900),     // inside Stamford Bridge's fence
            Self.point("bridge-2", "2026-03-25T06:03:20Z", 51.4818, -0.1925),
            Self.point("hammersmith", "2026-03-25T06:03:50Z", 51.4850, -0.2300),
            Self.point("cabin-selfie", "2026-03-25T06:19:00Z", 51.4817, -0.1905), // the phone's last fix
            Self.point("terminal-dog", "2026-03-25T06:40:00Z", 51.4700, -0.4543),
        ]
    }

    /// The speed between shots (3 km in 30 s) says the phone was in a vehicle: no photo inside the fence places a visit.
    func testTheLandingIsOnTheMove() async throws {
        let moving = TransitCheck.moving(landing)
        for id in ["thames", "waterloo", "battersea", "bridge-1", "bridge-2", "hammersmith"] {
            XCTAssertGreaterThan(moving[id] ?? 0, 60, "\(id) is not on the move")
        }
        XCTAssertNil(moving["cabin-selfie"], "At the gate")
        XCTAssertNil(moving["terminal-dog"])
        // The cabin's stale fix is the only photo inside the fence on foot, and nothing else is near the ground on foot (the
        // dog is 20 km away): one photo inside the fence alone is no visit, so the scan never sees one.
        let found = PhotoMatcher.found(in: landing, venues: library.venues, existing: [])
        XCTAssertTrue(found.visits.isEmpty)
        XCTAssertTrue(found.nearby.isEmpty)
        // An album the fan chose is trusted: it would still make the visit, with every photo of the day.
        XCTAssertEqual(VisitGrouping.group(landing, venues: library.venues).visits.map(\.insideIds), [["cabin-selfie"]])
        let (scan, review) = await scan(landing)
        XCTAssertEqual(scan.state, .empty)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
        XCTAssertEqual(scan.skippedVisits, 0, "Not even a visit to drop")
        XCTAssertTrue(scan.pendingVisits.isEmpty, "Nothing waits for the background search either")
    }

    /// Without the Hammersmith shot the last window shot pairs with nothing and stays on foot: with the cabin's stale fix that
    /// is two photos inside the fence sixteen minutes apart, a visit by the grouping rule, dropped for too few photos.
    func testALandingWithTwoPhotosInsideTheFenceIsDropped() async throws {
        let stale = landing.filter { $0.id != "hammersmith" }
        let visit = try XCTUnwrap(PhotoMatcher.found(in: stale, venues: library.venues, existing: []).visits.first)
        XCTAssertEqual(visit.insideIds, ["bridge-2", "cabin-selfie"])
        XCTAssertFalse(visit.isStadiumVisit)
        let (scan, review) = await scan(stale)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
        XCTAssertEqual(scan.skippedVisits, 1)
        XCTAssertTrue(scan.pendingVisits.isEmpty, "Dropped, not deferred")
    }

    /// The fix's own speed, when the phone recorded one, is enough on its own.
    func testAFixAtAirlinerSpeedIsOnTheMove() {
        XCTAssertEqual(TransitCheck.moving([Self.point("window", "2026-03-25T06:03:00Z", 51.4817, -0.1900, speed: 75)]), ["window": 75])
        XCTAssertTrue(TransitCheck.moving([Self.point("walk", "2026-03-25T06:03:00Z", 51.4817, -0.1900, speed: 1.4)]).isEmpty)
    }

    // MARK: Real visits still stand

    /// A tour of Stamford Bridge: six photos inside the fence over forty minutes, the hotel two hours before.
    private var tour: [PhotoPoint] {
        [Self.point("hotel", "2026-03-25T09:00:00Z", 51.5010, -0.1920)]
            + (0..<6).map { n in
                Self.point("stand-\(n)", "2026-03-25T11:\(String(format: "%02d", n * 8)):00Z",
                           51.4815 + Double(n) * 0.0001, -0.1915 + Double(n) * 0.0002)
            }
    }

    func testATourOfTheGroundIsOffered() async throws {
        XCTAssertTrue(TransitCheck.moving(tour).isEmpty, "Everyone was on foot")
        let (_, review) = await scan(tour)
        XCTAssertTrue(review.games.isEmpty)
        let visit = try XCTUnwrap(review.others.first, "The tour was not offered")
        XCTAssertEqual(visit.venue.id, "stamford-bridge")
        XCTAssertEqual(visit.assetIds.count, 7)
        XCTAssertEqual(visit.insideIds?.count, 6, "The six photos inside the fence placed it")
    }

    /// Two photos inside the fence, however far apart, or three inside twenty minutes, are not a stay: dropped, not deferred.
    func testAVisitNeedsThreePhotosInsideTheFenceOverTwentyMinutes() async throws {
        let two = tour.filter { !["stand-1", "stand-2", "stand-3", "stand-4"].contains($0.id) }   // 11:00 and 11:40
        var (scan, review) = await scan(two)
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertEqual(scan.skippedVisits, 1)
        XCTAssertTrue(scan.pendingVisits.isEmpty)
        let quick = tour.filter { !["stand-3", "stand-4", "stand-5"].contains($0.id) }             // 11:00, 11:08, 11:16
        (scan, review) = await self.scan(quick)
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertEqual(scan.skippedVisits, 1)
        let five = tour.filter { $0.id != "stand-5" }                                              // 11:00 to 11:32
        (scan, review) = await self.scan(five)
        XCTAssertEqual(review.others.count, 1)
    }

    /// A visit left waiting by an earlier scan is judged the same way by the background search.
    func testTheBackgroundSearchJudgesAWaitingVisitTheSameWay() async throws {
        let cluster = try XCTUnwrap(VisitGrouping.group(tour, venues: library.venues, minimumStay: 15 * 60).visits.first)
        let offered = await ScanModel.waitingDay(cluster, venues: library.venues)
        let day = try XCTUnwrap(offered, "A stay inside the fence is offered")
        XCTAssertEqual(day.suggestions.first?.id, "stamford-bridge")
        XCTAssertTrue(day.reason.contains("Stamford Bridge"), day.reason)
        let two = try XCTUnwrap(VisitGrouping.group(tour.filter { !["stand-1", "stand-2", "stand-3", "stand-4"].contains($0.id) },
                                                    venues: library.venues, minimumStay: 15 * 60).visits.first)
        let kept = await ScanModel.waitingDay(two, venues: library.venues)
        XCTAssertNil(kept, "Two photos inside the fence are not enough for a visit with no game")
    }

    /// Red Sox at Rockies, Coors Field, June 24 2026, 1:10 PM in Denver, a mile up: a game like any other.
    func testAGameDayAMileUpIsStillAVisit() async throws {
        let denver = [
            Self.point("hotel", "2026-06-24T16:00:00Z", 39.7470, -104.9920),
            Self.point("gate", "2026-06-24T19:00:00Z", 39.7561, -104.9935),
            Self.point("first-pitch", "2026-06-24T19:12:00Z", 39.7563, -104.9942),
            Self.point("seventh", "2026-06-24T21:05:00Z", 39.7560, -104.9945),
            Self.point("final", "2026-06-24T22:10:00Z", 39.7558, -104.9940),
        ]
        XCTAssertTrue(TransitCheck.moving(denver).isEmpty)
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
        let moving = TransitCheck.moving(driveBy)
        XCTAssertEqual(try XCTUnwrap(moving["past-the-gate"], "The photo inside the fence was not on the move"), 25, accuracy: 1)
        XCTAssertNil(moving["home"])
        XCTAssertTrue(PhotoMatcher.found(in: driveBy, venues: library.venues, existing: []).visits.isEmpty)
        let (_, review) = await scan(driveBy)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    /// A fix that jumps a few hundred metres inside a full bowl is not a vehicle: a kilometre is the least that counts.
    func testAJumpingFixInsideTheBowlStaysOnFoot() {
        let jumpy = [
            Self.point("a", "2026-03-25T15:00:00Z", 51.4817, -0.1911),
            Self.point("b", "2026-03-25T15:00:10Z", 51.4845, -0.1911), // 310 m north, 31 m/s
            Self.point("c", "2026-03-25T15:00:20Z", 51.4817, -0.1911),
        ]
        XCTAssertTrue(TransitCheck.moving(jumpy).isEmpty)
    }

    // MARK: The owner's day at the Nurburgring

    /// August 5 2023, from the scan check (times are Chicago's, UTC-5): 42 photos at the circuit from 03:22 to 06:26, eighteen
    /// of them inside the fence (the grandstand, 600 m up) and the rest at the car park a kilometre east, then the road out,
    /// Adenau, two photos in the valley at 340 m and Wuppertal that evening. The old altitude rule read the circuit's 270 m
    /// above the valley as flight and dropped the day.
    private var nurburgring: [PhotoPoint] {
        let start = ISO8601DateFormatter().date(from: "2023-08-05T08:22:00Z")!
        return (0..<42).map { i in
            let inside = i % 7 < 3
            return PhotoPoint(id: "circuit-\(i)", date: start.addingTimeInterval(Double(i) * 270),
                              latitude: inside ? 50.33357 + Double(i % 7) * 0.0009 : 50.3350 + Double(i % 7 - 3) * 0.0008,
                              longitude: (inside ? 6.94552 : 6.9610) + Double(i / 7) * 0.0006)
        } + [
            Self.point("road", "2023-08-05T12:30:00Z", 50.34816, 6.96942),
            Self.point("adenau", "2023-08-05T12:39:00Z", 50.37032, 7.00584),
            Self.point("valley-1", "2023-08-05T12:59:00Z", 50.37641, 6.94981),
            Self.point("valley-2", "2023-08-05T13:10:00Z", 50.37663, 6.95096),
            Self.point("wuppertal", "2023-08-05T15:16:00Z", 51.22796, 7.23996),
        ]
    }

    func testADayAtTheNurburgringIsAVisit() async throws {
        XCTAssertTrue(TransitCheck.moving(nurburgring).isEmpty, "Nobody was on the move")
        let found = PhotoMatcher.found(in: nurburgring, venues: library.venues, existing: [])
        let visit = try XCTUnwrap(found.visits.first)
        XCTAssertEqual(visit.id, "nurburgring|2023-08-05")
        XCTAssertEqual(visit.assetIds.count, 47)
        XCTAssertEqual(visit.insideIds?.count, 18)
        XCTAssertEqual(visit.anchors, (0..<42).filter { $0 % 7 < 3 }.map { "circuit-\($0)" })
        XCTAssertTrue(visit.isStadiumVisit)
        // No race on the calendar that weekend: offered as a stadium visit.
        let (scan, review) = await scan(nurburgring)
        XCTAssertTrue(review.games.isEmpty)
        let offered = try XCTUnwrap(review.others.first, "The day at the circuit was not offered")
        XCTAssertEqual(offered.venue.id, "nurburgring")
        XCTAssertEqual(offered.insideIds?.count, 18)
        XCTAssertEqual(scan.skippedVisits, 0)
    }

    // MARK: The pieces

    /// What the photo library's fix carries: a speed only when the phone recorded one.
    func testSpeedComesFromTheFixWhenItHasOne() {
        func fix(speed: Double) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 51.48, longitude: -0.19), altitude: 0,
                       horizontalAccuracy: 10, verticalAccuracy: -1, course: -1, speed: speed, timestamp: .now)
        }
        XCTAssertNil(PhotoPoint.speed(of: fix(speed: -1)))
        XCTAssertEqual(PhotoPoint.speed(of: fix(speed: 50)), 50)
    }

    /// A visit saved before the photos inside the fence were kept still reads, and is judged by all its photos.
    func testAnOlderPendingVisitStillReads() throws {
        let json = #"{"id":"stamford-bridge|2026-03-25","venue":\#(String(decoding: try JSONEncoder().encode(library.venue("stamford-bridge")!), as: UTF8.self)),"start":0,"end":0,"assetIds":["a","b"],"times":[0,0]}"#
        let cluster = try JSONDecoder().decode(PhotoCluster.self, from: Data(json.utf8))
        XCTAssertNil(cluster.insideIds)
        XCTAssertEqual(cluster.anchors, ["a", "b"])
    }

    /// The scan check shows each photo's verdict, the visit the landing would have made and why it is dropped, and for the
    /// circuit the visit and the stay inside the fence that offers it.
    func testScanCheckShowsTheRoadAndTheStay() {
        let london = TimeZone(identifier: "Europe/London")!
        let text = ScanCheck.lines(points: landing, venues: library.venues, saved: [], zone: london).joined(separator: "\n")
        XCTAssertTrue(text.contains("Photos: 8 (8 with a location, 0 without) \u{00B7} 6 on the move: these never place a visit"), text)
        XCTAssertTrue(text.contains("06:03  51.48170,-0.19000  inside Stamford Bridge (77 m, fence 200 m) \u{00B7} on the move, 92 m/s (limit 20 m/s over 1 km)"), text)
        XCTAssertTrue(text.contains("06:40  51.47000,-0.45430  no stadium within 2 km\n"), text)
        XCTAssertTrue(text.contains("Visits (scan rule: a photo inside the fence, not on the move, and another inside or within reach of it, 15+ min apart):\n"
                                    + "  none\nVisits only an album would make (the scan drops these: too short a stay inside the fence, or already saved):\n"
                                    + "  Stamford Bridge [stamford-bridge|2026-03-25]: 8 photos, 06:01\u{2013}06:40 (1 inside the fence)"), text)
        let cabin = VisitGrouping.group(landing, venues: library.venues).visits[0]
        XCTAssertEqual(ScanCheck.visitLine(cabin), "stadium visit: 1 photos inside the fence over 0 min \u{2014} fewer than 3 or under 20 min, dropped")

        // A drive past the ground: the photo inside the fence was on the move, so the visit it would have made is shown dropped.
        let road = ScanCheck.lines(points: [
            Self.point("east-1", "2026-03-27T15:00:40Z", 51.4823, -0.1765),
            Self.point("past-the-gate", "2026-03-27T15:01:20Z", 51.4817, -0.1910),
        ], venues: library.venues, saved: [], zone: london).joined(separator: "\n")
        XCTAssertTrue(road.contains("inside Stamford Bridge (8 m, fence 200 m) \u{00B7} on the move, 25 m/s (limit 20 m/s over 1 km)"), road)
        XCTAssertTrue(road.contains("Visits (scan rule: a photo inside the fence, not on the move, and another inside or within reach of it, 15+ min apart):\n  none"), road)
        XCTAssertTrue(road.contains("Visits the photos would make if none were on the move (the scan drops these: every photo inside the fence was on the move):\n"
                                    + "  Stamford Bridge [stamford-bridge|2026-03-27]: 2 photos, 15:00\u{2013}15:01 (1 inside the fence)"), road)

        let chicago = TimeZone(identifier: "America/Chicago")!
        let circuit = ScanCheck.lines(points: nurburgring, venues: library.venues, saved: [], zone: chicago).joined(separator: "\n")
        XCTAssertTrue(circuit.contains("Photos: 47 (47 with a location, 0 without)\n"), circuit)
        XCTAssertTrue(circuit.contains("03:22  50.33357,6.94552  inside Nurburgring Grand Prix Circuit (262 m, fence 900 m)\n"), circuit)
        XCTAssertTrue(circuit.contains("Visits (scan rule: a photo inside the fence, not on the move, and another inside or within reach of it, 15+ min apart):\n"
                                       + "  Nurburgring Grand Prix Circuit [nurburgring|2023-08-05]: 47 photos, 03:22\u{2013}06:08 (18 inside the fence)"), circuit)
        let visit = PhotoMatcher.found(in: nurburgring, venues: library.venues, existing: []).visits[0]
        XCTAssertEqual(ScanCheck.visitLine(visit), "stadium visit: 18 photos inside the fence over 166 min \u{2014} offered")
        let stale = PhotoMatcher.found(in: landing.filter { $0.id != "hammersmith" }, venues: library.venues, existing: []).visits[0]
        XCTAssertEqual(ScanCheck.visitLine(stale), "stadium visit: 2 photos inside the fence over 15 min \u{2014} fewer than 3 or under 20 min, dropped")
    }
}
