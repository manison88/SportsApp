import XCTest

/// End-to-end flows through the real app. Every test starts from a clean
/// library (-reset). Screenshots are kept so CI can publish them for design review.
final class WitnessUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    @discardableResult
    func launch(_ args: [String]) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = ["-reset", "-uitest"] + args
        app.launch()
        return app
    }

    func snap(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func tap(_ id: String, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
        e.tap()
    }

    func tab(_ name: String) {
        let b = app.tabBars.buttons[name]
        XCTAssertTrue(b.waitForExistence(timeout: 5), "Missing tab \(name)")
        b.tap()
    }

    func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func search(_ text: String) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 3) {
            app.swipeDown()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    func openGame(_ id: String, query: String) {
        search(query)
        tap("game-card-\(id)")
    }

    // MARK: Flows

    func testWelcome() {
        launch([])
        XCTAssertTrue(el("welcome-sample").waitForExistence(timeout: 8))
        snap("01-welcome")
        tap("welcome-sample")
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 8))
    }

    func testTabsTour() {
        launch(["-demo"])
        XCTAssertTrue(el("game-card-mlb-2026-0704").waitForExistence(timeout: 10))
        snap("04-timeline")

        tab("Map")
        XCTAssertTrue(el("map-miles").waitForExistence(timeout: 5))
        sleep(3) // let map tiles load for the screenshot
        snap("02-map")

        tab("Passport")
        XCTAssertTrue(el("passport-count").waitForExistence(timeout: 5))
        snap("03-passport")
        tap("stamp-wrigley")
        XCTAssertTrue(el("venue-title").waitForExistence(timeout: 5))
        snap("08-venue")
        back()

        tab("You")
        XCTAssertTrue(el("you-lucky").waitForExistence(timeout: 5))
        snap("09-you")
        tap("you-lucky")
        XCTAssertTrue(el("lucky-title").waitForExistence(timeout: 5))
        snap("10-lucky")
        back()

        tap("person-row-maya")
        XCTAssertTrue(el("shared-count").waitForExistence(timeout: 5))
        snap("13-shared-passport")
        back()

        tap("you-wrapped")
        XCTAssertTrue(el("wrapped-record").waitForExistence(timeout: 5))
        snap("11-wrapped")
        tap("wrapped-close")
    }

    func testGameMemoryRecapAndYouWereThere() {
        launch(["-demo"])
        openGame("mlb-2016-ws5", query: "World Series")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        snap("05-game-memory-ws5")

        tap("open-you-were-there")
        XCTAssertTrue(el("ywt-plays").waitForExistence(timeout: 5))
        snap("06-you-were-there")
        back()

        tap("play-recap")
        XCTAssertTrue(el("recap-close").waitForExistence(timeout: 5))
        sleep(2)
        snap("07-recap")
        tap("recap-pause")
        tap("recap-close")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
    }

    func testLambeauMemoryAndTrip() {
        launch(["-demo"])
        openGame("nfl-2025-w18-gb", query: "Lambeau")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        snap("05-game-memory-lambeau")
        tap("open-trip")
        XCTAssertTrue(el("trip-title").waitForExistence(timeout: 5))
        snap("14-trip")
    }

    func testSpainTrip() {
        launch(["-demo"])
        openGame("lal-2020-clasico", query: "Madrid")
        tap("open-trip")
        XCTAssertTrue(el("trip-title").waitForExistence(timeout: 5))
        sleep(2)
        snap("14-trip-spain")
    }

    /// Manual entry: catalog venue, scores, seat, then it shows on the timeline and in detail.
    func testAddGameManually() {
        launch(["-empty"])
        tap("empty-add")
        XCTAssertTrue(el("add-save").waitForExistence(timeout: 5))
        XCTAssertFalse(el("add-save").isEnabled, "Save must wait for a venue")
        snap("add-game-empty")

        tap("add-venue")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Wrigley")
        tap("venue-row-wrigley")

        XCTAssertTrue(el("add-venue-name").waitForExistence(timeout: 5))
        tap("add-away-score"); app.typeText("2")
        tap("add-home-score"); app.typeText("5")
        tap("add-seat"); app.typeText("Section 209")
        snap("add-game-filled")
        tap("add-save")

        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        snap("add-game-timeline")
        card.tap()
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        snap("add-game-detail")
    }

    /// A venue that isn't in the catalog: created by hand with a pin.
    func testAddCustomVenue() {
        launch(["-empty"])
        tap("empty-add")
        tap("add-venue")
        tap("venue-new")
        tap("venue-name"); app.typeText("Sandlot Park")
        tap("venue-city"); app.typeText("Naperville")
        el("venue-map").tap()
        snap("add-venue")
        tap("venue-save")
        let name = el("add-venue-name")
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        XCTAssertTrue(name.label.contains("Sandlot"), "Got \(name.label)")
        tap("add-save")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// Ticket import: paste a confirmation email, it pre-fills the form.
    func testImportTicketFromPastedEmail() {
        launch(["-empty"])
        tap("add-menu")
        app.buttons["Import ticket"].tap()
        tap("ticket-paste")
        app.typeText("""
        Ticketmaster
        Your tickets are ready
        Chicago Cubs vs. Milwaukee Brewers
        Sat, Aug 9, 2025 1:20 PM
        Wrigley Field, Chicago, IL
        SEC 209  ROW 4  SEAT 11
        """)
        snap("ticket-pasted")
        tap("ticket-parse")
        XCTAssertTrue(el("add-venue-name").waitForExistence(timeout: 8))
        XCTAssertTrue(el("add-venue-name").label.contains("Wrigley"), "Got \(el("add-venue-name").label)")
        snap("ticket-prefilled")
        tap("add-save")
        XCTAssertTrue(el("game-card-").exists || app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testLiveCheckIn() {
        launch(["-demo"])
        tap("add-menu")
        app.buttons["Check in live"].tap()
        tap("live-start")
        XCTAssertTrue(el("live-save-moment").waitForExistence(timeout: 5))
        tap("live-home-plus")
        tap("live-home-plus")
        tap("live-away-plus")
        tap("live-save-moment")
        tap("live-save-moment")
        XCTAssertTrue(el("live-moment-count").waitForExistence(timeout: 3))
        snap("12-live")
        tap("live-end")
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 5))
    }

    /// Discovery runs against photos CI seeds into the simulator with GPS + dates at real stadiums.
    func testDiscoveryFromPhotos() {
        launch([])
        tap("welcome-photos")
        addUIInterruptionMonitor(withDescription: "Photos") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "OK", "Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
        app.tap()
        let found = el("discovery-count")
        let empty = el("discovery-empty")
        let denied = el("discovery-denied")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline && !found.exists && !empty.exists && !denied.exists { sleep(1) }
        snap("01-discovery")
        XCTAssertTrue(found.exists, "Expected the seeded stadium photos to be discovered")
        tap("discovery-confirm")
        snap("01-discovery-after-confirm")
        tap("discovery-close")
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 8))
    }
}
