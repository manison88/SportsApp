import XCTest
@testable import Witness

final class SmokeTests: XCTestCase {
    func testMockDataLoads() {
        XCTAssertEqual(MockStore.shared.games.count, 60)
    }
}
