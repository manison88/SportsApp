import XCTest
@testable import Witness

/// The review ask: once, after a real game of the fan's own, when a game page was opened and left; never over the samples.
@MainActor
final class ReviewPromptTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "review-prompt-tests-\(UUID().uuidString)")
        ReviewPrompt.reset(defaults: defaults)
    }

    override func tearDown() { ReviewPrompt.reset(defaults: defaults) }

    private func library(withGame: Bool) -> Library {
        let library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "review-\(UUID().uuidString).json"))
        library.startEmpty()
        if withGame {
            library.add(GameEntry(sport: .soccer, date: Date(), venueId: "lumen-field", photos: [], origin: .manual))
        }
        return library
    }

    func testAsksOnceAfterAGamePageWasOpenedWithARealGameInTheLibrary() {
        let library = library(withGame: true)
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: library, defaults: defaults, arguments: []), "No game page opened yet")
        ReviewPrompt.noteGameOpened()
        XCTAssertTrue(ReviewPrompt.shouldAsk(library: library, defaults: defaults, arguments: []))
        ReviewPrompt.markAsked(defaults: defaults)
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: library, defaults: defaults, arguments: []), "Asked already")
        ReviewPrompt.noteGameOpened()
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: library, defaults: defaults, arguments: []), "Once, ever")
    }

    func testNoGameOfTheirOwnNoSampleAndNoUITestAsks() {
        let empty = library(withGame: false)
        ReviewPrompt.noteGameOpened()
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: empty, defaults: defaults, arguments: []), "Nothing of their own yet")

        let sample = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "review-sample-\(UUID().uuidString).json"))
        sample.loadSample()
        ReviewPrompt.noteGameOpened()
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: sample, defaults: defaults, arguments: []), "The sample games are not theirs")

        let real = library(withGame: true)
        ReviewPrompt.noteGameOpened()
        XCTAssertFalse(ReviewPrompt.shouldAsk(library: real, defaults: defaults, arguments: ["-uitest"]), "Never in a UI test")
    }
}
