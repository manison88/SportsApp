import XCTest
import Photos
@testable import Witness

/// What the fan allowed for photos, in plain words.
final class PhotoAccessTests: XCTestCase {
    func testStatusMapsToAccess() {
        XCTAssertEqual(PhotoAccess(.authorized), .full)
        XCTAssertEqual(PhotoAccess(.limited), .limited)
        XCTAssertEqual(PhotoAccess(.denied), .denied)
        XCTAssertEqual(PhotoAccess(.restricted), .denied)
        XCTAssertEqual(PhotoAccess(.notDetermined), .undetermined)
        XCTAssertTrue(PhotoAccess(.limited).isLimited)
        XCTAssertFalse(PhotoAccess(.authorized).isLimited)
    }

    func testTheEmptyScreenSaysWhenAccessIsLimited() {
        let limited = PhotoAccess.emptyBody(.limited, checked: 1_200)
        XCTAssertTrue(limited.contains("only see the photos you selected"), limited)
        XCTAssertTrue(limited.contains("Select more photos"), limited)
        let full = PhotoAccess.emptyBody(.full, checked: 1_200)
        XCTAssertFalse(full.contains("selected"), full)
        XCTAssertTrue(full.contains("none taken inside a stadium"), full)
        XCTAssertTrue(PhotoAccess.limitedMessage.contains("only see the photos you selected"))
    }

    func testTheUncheckedLine() {
        XCTAssertNil(PhotoAccess.uncheckedLine(0))
        XCTAssertEqual(PhotoAccess.uncheckedLine(1), "1 visit couldn't be checked, connect and run Find in photos again.")
        XCTAssertEqual(PhotoAccess.uncheckedLine(3), "3 visits couldn't be checked, connect and run Find in photos again.")
    }
}
