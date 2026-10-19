import XCTest
@testable import Witness

/// Lumen Field and T-Mobile Park share a parking lot: photos filed at the ballpark on a World Cup day still find the game.
@MainActor
final class NeighborGroundsTests: XCTestCase {
    func testLumenAndTMobileAreNeighbors() throws {
        let library = Library()
        let ballpark = try XCTUnwrap(library.venues.first { $0.name == "T-Mobile Park" })
        XCTAssertTrue(PhotoMatcher.neighbors(of: ballpark, in: library.venues).contains { $0.name == "Lumen Field" })
    }
}
