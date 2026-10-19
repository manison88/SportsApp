import XCTest
@testable import Witness

/// The owner's scan check for June 24 2026: 123 photos, 5 with a location (three in Federal Way at 08:38 CDT, two at Pike Place
/// Market at 21:32 CDT), 118 without, and the match at Lumen Field (noon in Seattle, 19:00 UTC) among those. The phone is in
/// Chicago. Nothing placed a photo near a stadium, so no visit was made and no schedule asked.
@MainActor
final class CityDayTests: XCTestCase {
    private var library: Library!
    private var ledgerURL: URL!
    private var pendingURL: URL!
    private var zone: TimeZone!
    private let iso = ISO8601DateFormatter()

    override func setUp() async throws {
        zone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Chicago")!
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "cd-\(UUID().uuidString).json"))
        ledgerURL = FileManager.default.temporaryDirectory.appending(path: "cd-ledger-\(UUID().uuidString).json")
        pendingURL = FileManager.default.temporaryDirectory.appending(path: "cd-pending-\(UUID().uuidString).json")
        let worldCup = try fixture("fifa-world-scoreboard-20260624")
        let mlb = try fixture("mlb-scoreboard-20260624")
        GameLookup.responder = { url in
            let s = url.absoluteString
            guard s.contains("/scoreboard?") else { return nil }
            if s.contains("soccer/fifa.world/scoreboard?dates=20260624") { return worldCup }
            if s.contains("baseball/mlb/scoreboard?dates=20260624") { return mlb }
            return Data(#"{"events":[]}"#.utf8)
        }
    }

    override func tearDown() async throws {
        GameLookup.responder = nil
        NSTimeZone.default = zone
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    private func at(_ utc: String) -> Date { iso.date(from: utc)! }

    /// The five located photos of the report.
    private func located(federalWay: (Double, Double) = (47.34375, -122.33208), pike: (Double, Double) = (47.61062, -122.34379)) -> [PhotoPoint] {
        (0..<3).map { PhotoPoint(id: "fw-\($0)", date: at("2026-06-24T13:38:00Z").addingTimeInterval(Double($0) * 20),
                                 latitude: federalWay.0, longitude: federalWay.1) }
            + (0..<2).map { PhotoPoint(id: "pike-\($0)", date: at("2026-06-25T02:32:00Z").addingTimeInterval(Double($0) * 20),
                                       latitude: pike.0, longitude: pike.1) }
    }

    /// `count` photos with no location, evenly from `from` to `to`, ids `prefix-n`.
    private func noLocation(_ prefix: String, _ count: Int, from: String, to: String) -> [PhotoPoint] {
        let a = at(from), b = at(to)
        return (0..<count).map { n in
            PhotoPoint(id: "\(prefix)-\(n)", date: a.addingTimeInterval(b.timeIntervalSince(a) * Double(n) / Double(max(1, count - 1))),
                       latitude: nil, longitude: nil)
        }
    }

    /// The 118: a morning drive (20), the match from the march to full time (70, half of them of the bowl), and the evening (28).
    private var reportDay: [PhotoPoint] {
        located()
            + noLocation("morning", 20, from: "2026-06-24T14:30:00Z", to: "2026-06-24T16:30:00Z")
            + zip(noLocation("stadium", 35, from: "2026-06-24T18:30:00Z", to: "2026-06-24T21:30:00Z"),
                  noLocation("crowd", 35, from: "2026-06-24T18:32:00Z", to: "2026-06-24T21:28:00Z")).flatMap { [$0, $1] }
            + noLocation("evening", 28, from: "2026-06-24T23:00:00Z", to: "2026-06-25T01:40:00Z")
    }

    /// The scene check, photo by photo: "stadium-" photos show the bowl.
    private static func look(_ refs: [PhotoRef], stadiums: Bool) -> SceneCheck.DayLook {
        var out = SceneCheck.DayLook()
        for ref in refs {
            guard case .library(let id) = ref else { continue }
            out.classified += 1
            if stadiums && id.hasPrefix("stadium-") { out.venue += 1; out.structure += 1 }
        }
        return out
    }

    private func model(_ points: [PhotoPoint], stadiums: Bool = true) -> ScanModel {
        ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in PhotoMatcher.found(in: points, venues: venues, existing: existing) },
            look: { refs, _ in Self.look(refs, stadiums: stadiums) },
            suggest: { _, _, _, _, _, _ in [] }))
    }

    private func findInPhotos(_ scan: ScanModel) async -> ScanModel.Review {
        scan.reset()
        scan.start(library: library)
        await scan.finished()
        return scan.takeForReview(library: library)
    }

    func testTheReportsDayOffersTheMatchAtLumenField() async throws {
        XCTAssertEqual(reportDay.count, 123)
        let review = await findInPhotos(model(reportDay))
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty)
        XCTAssertEqual(review.possible.count, 1, review.possible.map(\.reason).joined(separator: "; "))
        let day = try XCTUnwrap(review.possible.first)
        XCTAssertEqual(day.suggestions.first?.id, "lumen-field")
        XCTAssertEqual(day.reason, "Photos with no location, on a day you were in Seattle, during Qatar at Bosnia-Herzegovina at Lumen Field")
        // Only the photos in the game's window, 18:00 to 22:30 UTC.
        XCTAssertEqual(Set(day.assetIds), Set(reportDay.filter { $0.id.hasPrefix("stadium-") || $0.id.hasPrefix("crowd-") }.map(\.id)))
        // The phone's day (Chicago) and the stadium's day (Seattle) are the same June 24; picking Lumen Field finds the match.
        XCTAssertEqual(VisitGrouping.dayString(day.day, tz: .current), "2026-06-24")
        let found = await GameLookup.gameNear(day.day, at: try XCTUnwrap(library.venue("lumen-field")))
        XCTAssertEqual(found.game?.eventId, "760462")
    }

    /// Offered again on the next Find in photos until the fan answers; skipped, it stays skipped; added, it is not asked about again.
    func testTheLedgerHolds() async throws {
        let scan = model(reportDay)
        let once = await findInPhotos(scan)
        let twice = await findInPhotos(scan)
        XCTAssertEqual(once.possible.map(\.id), twice.possible.map(\.id))
        let day = try XCTUnwrap(twice.possible.first)
        scan.dismiss(day.assetIds, on: day.day)
        let skipped = await findInPhotos(scan)
        XCTAssertTrue(skipped.possible.isEmpty)

        try? FileManager.default.removeItem(at: ledgerURL)
        library.add(GameEntry(sport: .soccer, date: at("2026-06-24T19:00:00Z"), venueId: "lumen-field",
                              photos: day.assetIds.map { PhotoRef.library($0) }, origin: .photos))
        let added = await findInPhotos(model(reportDay))
        XCTAssertTrue(added.possible.isEmpty)
    }

    func testPhotosWithNoLocationOnlyInTheMorningAreNotOffered() async {
        let points = located() + noLocation("stadium", 60, from: "2026-06-24T14:00:00Z", to: "2026-06-24T17:00:00Z")
        let review = await findInPhotos(model(points))
        XCTAssertTrue(review.possible.isEmpty, review.possible.map(\.reason).joined())
    }

    func testPhotosThatDoNotLookLikeAStadiumAreNotOffered() async {
        let review = await findInPhotos(model(reportDay, stadiums: false))
        XCTAssertTrue(review.possible.isEmpty)
    }

    /// Portland: big stadiums, no game that day.
    func testACityWithNoGameThatDayOffersNothing() async {
        let points = located(federalWay: (45.5300, -122.6650), pike: (45.5215, -122.6917)) + reportDay.filter { $0.latitude == nil }
        let review = await findInPhotos(model(points))
        XCTAssertTrue(review.possible.isEmpty)
    }

    /// Seattle in the morning and Chicago at night: no one city, nothing asked.
    func testLocatedPhotosInTwoCitiesOfferNothing() async {
        let points = located(pike: (41.8827, -87.6233)) + reportDay.filter { $0.latitude == nil }
        let review = await findInPhotos(model(points))
        XCTAssertTrue(review.possible.isEmpty)
    }

    func testScreenshotsAreNotPhotosOfTheDay() {
        let shots = reportDay.filter { $0.latitude == nil }.map {
            PhotoPoint(id: $0.id, date: $0.date, latitude: nil, longitude: nil, screenshot: true)
        }
        XCTAssertTrue(CityDays.candidates(located() + shots, venues: library.venues, taken: [], existing: []).isEmpty)
    }

    /// The scan check shows the inferred city and from which photos, the photos by hour in Seattle time, each game's window,
    /// the scene check and the verdict.
    func testScanCheckTracesTheCityDay() async throws {
        let chicago = TimeZone(identifier: "America/Chicago")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chicago
        let start = cal.startOfDay(for: at("2026-06-24T18:00:00Z"))
        let text = ScanCheck.cityLines(points: reportDay, day: start..<start.addingTimeInterval(86_400), venues: library.venues,
                                       taken: [], existing: [], zone: chicago).joined(separator: "\n")
        XCTAssertTrue(text.contains("118 this day"), text)
        XCTAssertTrue(text.contains("by hour (America/Los_Angeles): 07h"), text)
        XCTAssertTrue(text.contains("11h "), text)
        XCTAssertTrue(text.contains("13:30\u{2013}16:30 (70 photos): in Seattle, from 08:38 47.34375,-122.33208 (before), 21:32 47.61062,-122.34379 (after)"), text)
        XCTAssertTrue(text.contains("schedules asked: Lumen Field, T-Mobile Park"), text)
        XCTAssertTrue(text.contains("09:30\u{2013}11:30 (20 photos): in Seattle"), text)

        let day = try XCTUnwrap(CityDays.candidates(reportDay, venues: library.venues, taken: [], existing: []).first { $0.ids.contains("stadium-0") })
        let eval = await CityDays.evaluate(day) { Self.look($0, stadiums: true) }
        let lines = ScanCheck.cityLines(eval) { _ in true }.joined(separator: "\n")
        XCTAssertTrue(lines.contains("Qatar at Bosnia-Herzegovina, Lumen Field, kickoff 12:00 (soccer/fifa.world 760462): window 11:00\u{2013}15:30, 70 photos in it"), lines)
        XCTAssertTrue(lines.contains("scene check of the window's photos: 16 classified, "), lines)
        XCTAssertTrue(lines.contains("looks like a stadium: yes"), lines)
        XCTAssertTrue(lines.contains("\u{2192} offered as a possible game"), lines)
    }
}
