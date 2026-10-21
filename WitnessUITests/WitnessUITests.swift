import XCTest

/// End-to-end flows through the real app. Every test starts from a clean
/// library (-reset). Screenshots are kept so CI can publish them for design review.
final class WitnessUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        // CI grants photo access with simctl before the build, but running the unit tests first reinstalls the app and clears
        // that grant. Then the first test that touches photos (adding a game looks for photos) meets the system prompt, and
        // an unanswered prompt is recorded as "Don't Allow" for every test after it. Always allow, like the fan would.
        addUIInterruptionMonitor(withDescription: "Photo access") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
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
        for _ in 0..<3 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break }
        }
        app.typeText(text)
    }

    /// Taps "Allow" on the system photo prompt if it's showing. SpringBoard draws it on iOS 18.
    @discardableResult
    func allowPhotoAccessIfAsked() -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for source in [springboard, app!] {
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] where source.buttons[label].exists {
                source.buttons[label].tap()
                return true
            }
        }
        return false
    }

    func openGame(_ id: String, query: String) {
        search(query)
        tap("game-card-\(id)")
    }

    // MARK: Flows

    /// The sample can be left from the Timeline: Exit goes back to the first screen.
    func testExitSampleGoesBackToTheStart() {
        launch([])
        tap("welcome-sample")
        XCTAssertTrue(el("sample-banner").waitForExistence(timeout: 8))
        tap("sample-exit")
        XCTAssertTrue(el("welcome-start").waitForExistence(timeout: 8), "Exit returns to the welcome")
    }

    func testWelcome() {
        launch([])
        XCTAssertTrue(el("welcome-sample").waitForExistence(timeout: 8))
        snap("01-welcome")
        tap("welcome-sample")
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 8))
    }

    func testWelcomeSteps() {
        app = XCUIApplication()
        app.launchArguments = ["-reset"]
        app.launch()
        for i in 0..<5 {
            XCTAssertTrue(el("welcome-start").waitForExistence(timeout: 5))
            sleep(2)
            snap("welcome-step-\(i)")
            if i < 4 { tap("welcome-start") }
        }
    }

    func testOnboardingAccessPage() {
        launch([])
        tap("welcome-start")
        XCTAssertTrue(el("onboarding-access").waitForExistence(timeout: 5))
        sleep(1)
        snap("ob-access")
    }

    func testTabsTour() {
        launch(["-demo"])
        XCTAssertTrue(el("game-card-mlb-2026-0704").waitForExistence(timeout: 10))
        XCTAssertTrue(el("timeline-big-games").exists, "Big games sits in the Timeline header beside Add")
        snap("04-timeline")

        tab("Map")
        XCTAssertTrue(el("map-miles").waitForExistence(timeout: 5))
        XCTAssertTrue(el("map-legend").exists, "The map names each sport's line color")
        let expand = app.buttons["Expand map"].firstMatch
        XCTAssertTrue(expand.waitForExistence(timeout: 5), "Missing the expand button")
        expand.tap()
        XCTAssertTrue(el("life-map-expanded").waitForExistence(timeout: 5))
        app.buttons["Zoom in"].firstMatch.tap()
        snap("02b-map-expanded")
        app.buttons["Close map"].firstMatch.tap()
        sleep(3) // let map tiles load for the screenshot
        snap("02-map")

        tab("Passport")
        XCTAssertTrue(el("passport-count").waitForExistence(timeout: 5))
        snap("03-passport")
        XCTAssertFalse(app.staticTexts["CHASE FIELD"].exists || app.staticTexts["Chase Field"].exists,
                       "Passport lists only parks you have been to, with no empty tiles")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'of 30'")).firstMatch.exists)
        XCTAssertTrue(el("stamp-wrigley").label.localizedCaseInsensitiveContains("Wrigley"),
                      "A stamp names the stadium, not just the team's initials: \(el("stamp-wrigley").label)")
        tap("stamp-wrigley")
        XCTAssertTrue(el("venue-title").waitForExistence(timeout: 5))
        snap("08-venue")
        back()

        tab("You")
        XCTAssertTrue(el("you-lucky").waitForExistence(timeout: 5))
        snap("09-you")
        XCTAssertTrue(app.staticTexts["Points"].exists || app.staticTexts["POINTS"].exists, "You shows sport-neutral stats")
        XCTAssertFalse(app.staticTexts["Runs"].exists || app.staticTexts["RUNS"].exists)
        tap("you-lucky")
        XCTAssertTrue(el("lucky-title").waitForExistence(timeout: 5))
        snap("10-lucky")
        back()

        tap("you-big-games")
        XCTAssertTrue(el("big-games-count").waitForExistence(timeout: 5))
        snap("15-big-games")
        back()

    }

    func testGameMemoryRecapAndYouWereThere() {
        launch(["-demo"])
        openGame("mlb-2016-ws5", query: "World Series")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        XCTAssertTrue(el("big-game-badge").exists, "World Series games wear the title-game badge")
        snap("05-game-memory-ws5")

        // The fan's photos are one tap from the game: a strip under the score opens a full-screen viewer.
        if el("game-photos").exists {
            // "See all" opens a grid of every photo, not a single picture.
            let seeAll = app.buttons["See all"].firstMatch
            XCTAssertTrue(seeAll.waitForExistence(timeout: 8), "Missing the See all button")
            seeAll.tap()
            XCTAssertTrue(el("photos-grid").waitForExistence(timeout: 5), "See all should show a grid")
            XCTAssertTrue(el("photos-tile-1").exists, "The grid shows more than one photo")
            XCTAssertTrue(el("photos-select").exists, "The grid can select several photos to remove")
            snap("05a-photo-grid")
            back()
            tap("game-photo-0")
            XCTAssertTrue(el("photo-viewer").waitForExistence(timeout: 5), "A photo should open full screen")
            XCTAssertTrue(el("photo-viewer-delete").exists, "A photo can be removed from the viewer")
            XCTAssertTrue(el("photo-viewer-strip").exists, "A strip of thumbnails shows the other photos and jumps to them")
            snap("05b-photo-viewer")
            app.buttons["Close"].firstMatch.tap()
        }

        XCTAssertTrue(el("hero-venue").exists, "The stadium is a link on the cover")
        XCTAssertTrue(el("hero-you-were-there").exists, "You were there is an icon on the cover")
        tap("hero-you-were-there")
        XCTAssertTrue(el("ywt-hero").waitForExistence(timeout: 5), "The match report opens with the story of your night")
        XCTAssertTrue(el("ywt-timeline").exists, "A timeline of the game clock stays pinned above the report")
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
        let save = app.buttons["add-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "Save must wait for a venue")
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

    /// A sport the app doesn't list: Other, with a name the fan types.
    func testAddOtherSportByTyping() { addOtherSport(extra: []) }

    func testAddOtherSportByTypingLight() { addOtherSport(extra: ["-appearance", "light"]) }

    private func addOtherSport(extra: [String]) {
        launch(["-empty"] + extra)
        tap("empty-add")
        tap("add-sport")
        app.buttons["Other"].firstMatch.tap()
        let name = el("other-sport-field")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["add-save"].isEnabled, "Save waits for a venue and a name")
        snap("add-other-empty")

        tap("add-venue")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Wrigley")
        tap("venue-row-wrigley")
        XCTAssertTrue(el("add-venue-name").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["add-save"].isEnabled, "A venue alone is not enough for Other")

        name.tap(); app.typeText("Rugby")
        tap("add-other-title"); app.typeText("Sevens final")
        snap("add-other-filled")
        XCTAssertTrue(app.buttons["add-save"].isEnabled)
        tap("add-save")

        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        snap("add-other-timeline")
        card.tap()
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        snap("add-other-detail")
        back()

        tab("Passport")
        XCTAssertTrue(el("passport-count").waitForExistence(timeout: 5))
        XCTAssertTrue(el("passport-other-Rugby").waitForExistence(timeout: 5), "The passport lists the typed name")
        snap("add-other-passport")
    }

    /// Any team against any team: a national side and a club from a league the catalog doesn't have, made by hand.
    func testAddGameWithCustomTeams() {
        launch(["-empty"])
        tap("empty-add")
        tap("add-away-team")
        tap("team-new")
        tap("team-new-name"); app.typeText("Croatia")
        XCTAssertTrue(el("team-new-save").isEnabled, "A name and its suggested code are enough")
        snap("add-team-new")
        tap("team-new-save")
        tap("add-home-team")
        tap("team-new")
        tap("team-new-name"); app.typeText("KK Zadar")
        tap("team-new-league"); app.typeText("EuroLeague")
        tap("team-new-save")
        tap("add-competition"); app.typeText("EuroLeague Final")
        // Both made-up teams now sit on the form, and the sport is still free to change.
        XCTAssertTrue(el("add-away-team").label.contains("Croatia"), "Away should show Croatia: \(el("add-away-team").label)")
        XCTAssertTrue(el("add-home-team").label.contains("Zadar"), "Home should show Zadar: \(el("add-home-team").label)")
        snap("add-game-custom-teams")
    }

    /// The full catalog: a club from a league the app has never heard of by hand, found by search; and a Formula 1 race
    /// chosen from the calendar, which sets the circuit and names the race.
    func testPickClubFromCatalogAndRaceFromCalendar() {
        launch(["-empty"])
        tap("empty-add")
        tap("add-away-team")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Hajduk")
        tap("team-row-cro1-haj")
        XCTAssertTrue(el("add-away-team").label.contains("Split"), "Away should show Hajduk Split: \(el("add-away-team").label)")

        tap("add-sport")
        app.buttons["Motorsport"].tap()
        tap("add-race-calendar")
        let races = app.searchFields.firstMatch
        XCTAssertTrue(races.waitForExistence(timeout: 5))
        races.tap()
        races.typeText("Monaco")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'race-row-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The calendar lists Monaco")
        snap("add-race-calendar")
        row.tap()
        XCTAssertTrue(el("add-venue-name").waitForExistence(timeout: 5))
        XCTAssertTrue(el("add-venue-name").label.contains("Monaco"), "The circuit is set: \(el("add-venue-name").label)")
        snap("add-race-picked")
        tap("add-save")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// Plan a game: a team picked inside any league lands back on the plan, never closes it.
    func testPlanPickTeamFromLeagues() {
        launch(["-empty"])
        tap("add-menu")
        app.buttons["Plan a game"].tap()
        for n in 0..<4 {
            let leagues = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-league-'"))
            XCTAssertTrue(leagues.firstMatch.waitForExistence(timeout: 8))
            let league = leagues.element(boundBy: n)
            let name = league.identifier
            league.tap()
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-row-'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Teams in \(name)")
            row.tap()
            XCTAssertTrue(el("plan-team").waitForExistence(timeout: 5), "The team's schedule opens after picking a team in \(name)")
            back()
            sleep(1)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Back goes to the league's teams: \(app.navigationBars.firstMatch.identifier) leagues=\(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-league-'")).count) plan=\(el("plan-team").exists)")
            back()
        }
    }

    /// A fan who wants a FIBA game finds the country in the picker (search, and the league's zones), sees the tournaments it plays
    /// with their next dates, and an honest line where no schedule exists yet.
    func testPlanBasketballNationalTeam() {
        launch(["-empty"])
        tap("add-menu")
        app.buttons["Plan a game"].tap()
        let league = el("team-league-FIBA national teams (men)")
        for _ in 0..<12 where !league.exists { app.swipeUp() }
        XCTAssertTrue(league.exists, "Basketball's national teams are a league group")
        league.tap()
        // The header is set in uppercase; some iOS builds report the label as shown, some as written.
        let europe = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "FIBA Europe \u{00B7} 42")).firstMatch
        XCTAssertTrue(europe.waitForExistence(timeout: 5), "The 132 sides are split by FIBA zone")
        shot("fiba-league")
        search("Bosnia")
        let row = el("team-row-fibam-bih")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Search finds the country")
        row.tap()
        XCTAssertTrue(el("plan-team").waitForExistence(timeout: 5))
        sleep(3)
        shot("fiba-team")
        XCTAssertTrue(el("team-plays").waitForExistence(timeout: 5), "The tournaments are listed")
        XCTAssertTrue(el("plan-no-schedule").waitForExistence(timeout: 8), "No schedule feed: an honest line, not a blank")
        shot("fiba-team")
    }

    /// Screenshots for review, written where a reviewer can open them when the folder exists.
    func shot(_ name: String) {
        snap(name)
        let dir = "/private/tmp/claude-501/shots"
        guard FileManager.default.fileExists(atPath: dir) else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? "x").png"))
    }

    func testShareGameLooks() {
        launch(["-demo"])
        openGame("mlb-2016-ws5", query: "World Series")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 5))
        tap("game-menu")
        tap("game-share")
        sleep(6)
        for i in 0..<2 {
            snap("game-share-\(i)")
            app.swipeLeft()
            sleep(2)
        }
    }

    func testShareMapLooks() {
        launch([])
        tap("welcome-sample")
        tab("Map")
        sleep(3)
        tap("map-share")
        sleep(12)
        for i in 0..<4 {
            snap("map-share-\(i)")
            app.swipeLeft()
            sleep(2)
        }
    }

    func testShareVenueLooks() {
        launch([])
        tap("welcome-sample")
        tab("Passport")
        tap("stamp-wrigley")
        XCTAssertTrue(el("venue-title").waitForExistence(timeout: 8))
        tap("venue-share")
        sleep(8)
        for i in 0..<2 {
            snap("venue-share-\(i)")
            app.swipeLeft()
            sleep(2)
        }
    }

    func testSharePassportPage() {
        launch([])
        tap("welcome-sample")
        tab("Passport")
        sleep(3)
        app.buttons["Share passport"].firstMatch.tap()
        sleep(6)
        snap("passport-share")
        app.swipeLeft()
        sleep(3)
        snap("passport-share-full")
    }

    /// "Select your teams" on You: pick a team once and it is on the list.
    func testSelectYourTeams() {
        launch(["-empty"])
        tab("You")
        tap("you-teams")
        tap("favorites-add")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Cubs")
        tap("team-row-mlb-chc")
        XCTAssertTrue(el("favorite-mlb-chc").waitForExistence(timeout: 5), "The team is on Your teams")
        snap("you-teams")
    }

    /// The Map's Venues, Countries and Games numbers open a list of compact tiles; a tile opens the real page.
    func testMapListsOpenVenueAndGamePages() {
        launch(["-demo"])
        tab("Map")
        tap("stat-venues")
        XCTAssertTrue(app.navigationBars["Venues"].waitForExistence(timeout: 8), "Venues opens a list")
        tap("map-venue-wrigley")
        XCTAssertTrue(el("venue-title").waitForExistence(timeout: 8), "A venue tile opens the venue page")
        snap("map-list-venue")
        back()
        back()
        tap("stat-games")
        XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 8))
        let game = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'map-game-'")).firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 8))
        game.tap()
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 8), "A game tile opens the game page")
        back()
        back()
        tap("stat-countries")
        XCTAssertTrue(app.navigationBars["Countries"].waitForExistence(timeout: 8))
        snap("map-list-countries")
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
        // Welcome, then the problem, the fix, and photo access; allowing it runs the scan and shows the first result.
        XCTAssertTrue(el("welcome-title").waitForExistence(timeout: 8))
        snap("ob-0-welcome")
        tap("welcome-start")
        XCTAssertTrue(el("onboarding-access").waitForExistence(timeout: 5))
        snap("ob-3-access")
        tap("onboarding-allow")
        let result = el("onboarding-result")
        let scanDeadline = Date().addingTimeInterval(90)
        while Date() < scanDeadline && !result.exists && !el("onboarding-empty").exists && !el("onboarding-denied").exists {
            allowPhotoAccessIfAsked()
            sleep(1)
        }
        XCTAssertTrue(result.exists, "Expected the scan to find the seeded stadium photos")
        snap("ob-4-result")
        tap("onboarding-review")
        let found = el("discovery-count")
        let empty = el("discovery-empty")
        let denied = el("discovery-denied")
        // The prompt can appear at any point while the scan starts, so keep answering it.
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline && !found.exists && !empty.exists && !denied.exists {
            allowPhotoAccessIfAsked()
            sleep(1)
        }
        XCTAssertTrue(found.exists, "Expected the seeded stadium photos to be discovered")
        // Newest first: the Fenway photos are from Tigers at Red Sox, June 9 2017, so the schedule check must match it.
        XCTAssertTrue(el("discovery-verified").waitForExistence(timeout: 25), "Expected the real game on the schedule")
        snap("01-discovery")
        tap("discovery-confirm")
        snap("01-discovery-after-confirm")
        // Games come first. Then the visits near a stadium with no game that day are reviewed as stadium visits.
        for _ in 0..<6 {
            if el("discovery-other-title").exists || el("discovery-done").exists { break }
            if el("discovery-skip").waitForExistence(timeout: 4) { tap("discovery-skip") }
        }
        if el("discovery-other-title").waitForExistence(timeout: 15) {
            snap("01-discovery-other")
            tap("discovery-other-add")
        }
        XCTAssertTrue(el("discovery-done").waitForExistence(timeout: 8))
        tap("discovery-done")
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 8))
    }

    /// Album import: CI seeds stadium photos with GPS, a scoreboard photo with only a date, and a downtown photo.
    /// The album must yield the GPS games, find the Stanley Cup Final from the scoreboard alone, and ask about the rest.
    func testImportAlbumWithScoreboardReading() {
        launch(["-empty", "-seedAlbum"])
        tap("add-menu")
        app.buttons["Import an album or trip"].tap()
        let album = el("album-Chicago weekend")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline && !album.exists {
            allowPhotoAccessIfAsked()
            sleep(1)
        }
        XCTAssertTrue(album.exists, "The seeded album should be listed")
        snap("album-list")
        album.tap()
        XCTAssertTrue(el("album-found").waitForExistence(timeout: 120), "Scanning the album should finish")
        XCTAssertTrue(el("album-scoreboard").waitForExistence(timeout: 5), "A game should be confirmed from a scoreboard photo")
        // A skyline photo is either skipped as not-a-game or, where the classifier is unavailable, asked about.
        let asked = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'album-ask-'")).firstMatch.exists
        XCTAssertTrue(asked || el("album-skipped").exists, "The downtown photo should be skipped or prompt for a stadium")
        snap("album-review")
        tap("album-add")
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        snap("album-timeline")
    }

    // MARK: App Store screenshots

    /// The eight screens for the App Store listing, shot on the biggest iPhone by the `appstore` workflow only.
    func testAppStoreScreens() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APPSTORE"] == "1", "Only the App Store workflow takes these")
        launch(["-demo"])
        XCTAssertTrue(app.tabBars.buttons["Timeline"].waitForExistence(timeout: 10))
        sleep(3)
        // Past the first card, so the shot shows several sports.
        app.swipeUp()
        sleep(3)
        snap("store-01-timeline")
        app.swipeDown()
        sleep(1)

        openGame("nfl-2025-w18-gb", query: "Lambeau")
        XCTAssertTrue(el("game-title").waitForExistence(timeout: 8))
        sleep(3)
        snap("store-02-game")

        if el("hero-you-were-there").waitForExistence(timeout: 3) {
            tap("hero-you-were-there")
            XCTAssertTrue(el("ywt-hero").waitForExistence(timeout: 8))
            sleep(3)
            snap("store-03-match-report")
            back()
        }

        tap("game-menu")
        tap("game-share")
        sleep(5)
        snap("store-08-share")
        app.buttons["Close"].firstMatch.tap()

        tab("Passport")
        sleep(1)
        let soccer = app.buttons.matching(NSPredicate(format: "label ==[c] 'SOCCER' OR label ==[c] 'FUDBAL'")).firstMatch
        if soccer.waitForExistence(timeout: 3) { soccer.tap() }
        if el("soccer-word-soccer").waitForExistence(timeout: 2) { tap("soccer-word-soccer") }
        sleep(6)
        snap("store-04-passport")

        tab("Map")
        XCTAssertTrue(el("map-miles").waitForExistence(timeout: 8))
        sleep(6)
        snap("store-05-map")

        tab("Passport")
        tap("stamp-soldier")
        XCTAssertTrue(el("venue-title").waitForExistence(timeout: 8))
        sleep(4)
        snap("store-06-venue")
        back()

        tab("You")
        sleep(3)
        snap("store-07-you")
    }

}

