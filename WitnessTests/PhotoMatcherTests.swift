import XCTest
@testable import Witness

final class PhotoMatcherTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_477_872_000)

    func testSinglePhotoIsNotAGame() {
        XCTAssertFalse(PhotoMatcher.looksLikeAGame([t0]))
    }

    func testQuickBurstIsNotAGame() {
        XCTAssertFalse(PhotoMatcher.looksLikeAGame([t0, t0.addingTimeInterval(60), t0.addingTimeInterval(300)]))
    }

    func testPhotosAcrossAnEveningAreAGame() {
        XCTAssertTrue(PhotoMatcher.looksLikeAGame([t0, t0.addingTimeInterval(90 * 60), t0.addingTimeInterval(220 * 60)]))
    }

    func testGameDayKeyUsesVenueTimeZone() {
        // 03:40 UTC on Oct 31 is still the night of Oct 30 in Chicago.
        let late = ISO8601DateFormatter().date(from: "2016-10-31T03:40:00Z")!
        let key = PhotoMatcher.key(venueId: "wrigley", date: late, tz: TimeZone(identifier: "America/Chicago")!)
        XCTAssertEqual(key, "wrigley|2016-10-30")
    }
}
