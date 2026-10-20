import XCTest

/// A visual sweep of every screen for the light/dark review (docs/LIGHT-MODE-REVIEW.md). It only runs when
/// REVIEW_OUT (a folder) and REVIEW_SCHEME (light or dark) are set, as TEST_RUNNER_REVIEW_OUT / TEST_RUNNER_REVIEW_SCHEME:
/// it saves a PNG per screen under <REVIEW_OUT>/<scheme>/. Nothing here asserts; a missing screen is skipped.
final class AppearanceReviewTests: XCTestCase {
    var app: XCUIApplication!
    var scheme = "light"
    var out = ""

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["REVIEW_OUT"], !folder.isEmpty else { throw XCTSkip("Review sweep only runs with REVIEW_OUT") }
        scheme = env["REVIEW_SCHEME"] ?? "light"
        out = folder + "/" + scheme
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        addUIInterruptionMonitor(withDescription: "Photo access") { alert in
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
    }

    // MARK: Helpers

    func launch(_ args: [String], reset: Bool = true) {
        app = XCUIApplication()
        app.launchArguments = (reset ? ["-reset"] : []) + ["-uitest", "-appearance", scheme] + args
        app.launchEnvironment["REVIEW_OUT"] = out
        app.launch()
    }

    func shot(_ name: String) {
        usleep(700_000)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    }

    func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    @discardableResult
    func tapIf(_ id: String, wait: TimeInterval = 4) -> Bool {
        let e = el(id)
        guard e.waitForExistence(timeout: wait) else { return false }
        e.tap(); return true
    }

    @discardableResult
    func tapButton(_ label: String, wait: TimeInterval = 4) -> Bool {
        let b = app.buttons[label].firstMatch
        guard b.waitForExistence(timeout: wait) else { return false }
        b.tap(); return true
    }

    func tab(_ name: String) { _ = tapButtonInTabBar(name) }
    func tapButtonInTabBar(_ name: String) -> Bool {
        let b = app.tabBars.buttons[name]
        guard b.waitForExistence(timeout: 6) else { return false }
        b.tap(); return true
    }

    func back() { if app.navigationBars.buttons.element(boundBy: 0).exists { app.navigationBars.buttons.element(boundBy: 0).tap() } }

    func closeSheet() {
        for label in ["Close", "Cancel", "Done"] where app.buttons[label].firstMatch.exists { app.buttons[label].firstMatch.tap(); return }
        app.swipeDown(velocity: .fast)
    }

    func allowPhotos() {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for source in [sb, app!] {
            for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] where source.buttons[label].exists { source.buttons[label].tap(); return }
        }
    }

    // MARK: Welcome and onboarding

    func testA_Welcome() {
        launch([])
        _ = el("welcome-start").waitForExistence(timeout: 8)
        sleep(2)
        for i in 0..<5 {
            shot("welcome-\(i)")
            if i < 4 { if !tapIf("welcome-start", wait: 3) { break }; sleep(1) }
        }
        shot("onboarding-access")
        tapIf("onboarding-privacy", wait: 2)
        sleep(1); shot("legal-privacy"); back()
    }

    func testA2_OnboardingScanAndResult() {
        launch([])
        for _ in 0..<5 where !el("onboarding-access").exists { tapIf("welcome-start", wait: 2); sleep(1) }
        tapIf("onboarding-allow", wait: 3)
        let deadline = Date().addingTimeInterval(60)
        var scanning = false
        while Date() < deadline && !el("onboarding-result").exists && !el("onboarding-empty").exists && !el("onboarding-denied").exists {
            allowPhotos(); if !scanning && el("onboarding-scanning").exists { scanning = true; shot("onboarding-scanning") }; sleep(1)
        }
        shot("onboarding-result")
        if tapIf("onboarding-review", wait: 3) {
            let d = Date().addingTimeInterval(45)
            while Date() < d && !el("discovery-count").exists && !el("discovery-empty").exists && !el("discovery-denied").exists { allowPhotos(); sleep(1) }
            _ = el("discovery-verified").waitForExistence(timeout: 20)
            shot("discovery-1")
            if tapIf("discovery-photos-all", wait: 2) { shot("discovery-photos"); closeSheet() }
            tapIf("discovery-confirm", wait: 3); shot("discovery-2")
            for _ in 0..<6 {
                if el("discovery-other-title").exists || el("discovery-done").exists { break }
                if el("discovery-skip").waitForExistence(timeout: 3) { el("discovery-skip").tap() }
            }
            if el("discovery-other-title").waitForExistence(timeout: 10) { shot("discovery-other"); tapIf("discovery-other-add") }
            if el("discovery-done").waitForExistence(timeout: 6) { shot("discovery-done"); tapIf("discovery-done") }
        }
        shot("after-onboarding")
    }

    func testA3_OnboardingEmptyAndDenied() {
        launch(["-empty"])
        sleep(2); shot("timeline-empty")
        tapIf("empty-add", wait: 2); sleep(1); shot("empty-add-menu")
    }

    // MARK: Timeline and adding

    func testB_TimelineAndAdd() {
        launch(["-demo"])
        _ = el("game-card-mlb-2026-0704").waitForExistence(timeout: 10)
        sleep(2)
        shot("timeline-top")
        app.swipeUp(); sleep(1); shot("timeline-scroll1")
        app.swipeUp(); sleep(1); shot("timeline-scroll2")
        app.swipeUp(); sleep(1); shot("timeline-scroll3")
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        tapIf("add-menu"); sleep(1); shot("add-menu")
        tapButton("Add game"); sleep(2); shot("add-game")
        if tapIf("add-kind", wait: 2) { sleep(1); shot("add-kind"); app.swipeDown() }
        tapIf("add-venue", wait: 2); sleep(1); shot("venue-picker")
        tapIf("venue-new", wait: 2); sleep(1); shot("add-venue"); closeSheet(); closeSheet(); sleep(1)
        app.swipeUp(); sleep(1); shot("add-game-2")
        closeSheet(); sleep(1)
        if app.buttons["Discard"].exists { app.buttons["Discard"].tap() }
        sleep(1)
        tapIf("add-menu"); tapButton("Plan a game"); sleep(2); shot("plan-game")
        tapIf("plan-team", wait: 2); sleep(2); shot("team-picker")
        if app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-league-'")).firstMatch.exists {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-league-'")).firstMatch.tap(); sleep(1); shot("team-picker-league")
        }
        closeSheet(); closeSheet(); sleep(1)
        tapIf("add-menu"); tapButton("Import ticket"); sleep(2); shot("ticket-import")
        tapIf("ticket-paste", wait: 2); sleep(1); shot("ticket-paste")
        closeSheet(); sleep(1)
        tapIf("add-menu"); tapButton("Import an album or trip"); sleep(3); allowPhotos(); sleep(2); shot("album-import")
        closeSheet(); sleep(1)
        tapIf("add-menu"); tapButton("Find in photos"); sleep(3); allowPhotos(); sleep(4); shot("discovery-demo")
    }

    func testB2_Plans() {
        launch(["-demo"])
        _ = el("game-card-mlb-2026-0704").waitForExistence(timeout: 10)
        sleep(2)
        let plan = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'plan-card-'")).firstMatch
        if plan.waitForExistence(timeout: 4) {
            shot("plan-card")
            plan.tap(); sleep(3); shot("plan-page")
            app.swipeUp(); sleep(1); shot("plan-page-2")
        }
    }

    func testB2b_PlanAGame() {
        launch(["-demo"])
        tapIf("add-menu"); tapButton("Plan a game"); sleep(2)
        tapIf("plan-team", wait: 2); sleep(2)
        let league = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-league-'")).firstMatch
        if league.waitForExistence(timeout: 3) { league.tap(); sleep(1) }
        let team = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'team-row-'")).firstMatch
        if team.waitForExistence(timeout: 3) { team.tap(); sleep(3) }
        shot("plan-games-list")
        let game = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'plan-game-'")).firstMatch
        if game.waitForExistence(timeout: 8) {
            game.tap(); sleep(2); shot("plan-detail")
            tapIf("plan-confirm", wait: 2); sleep(2)
        }
        shot("plan-after")
        let plan = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'plan-card-'")).firstMatch
        if plan.waitForExistence(timeout: 5) {
            shot("plan-card")
            plan.tap(); sleep(3); shot("plan-page")
            app.swipeUp(); sleep(1); shot("plan-page-2")
        }
    }

    func testB3_LiveCheckIn() {
        launch(["-demo"])
        tapIf("add-menu"); tapButton("Check in live"); sleep(2); shot("live-0")
        tapIf("live-start"); sleep(2); shot("live-1")
        tapIf("live-home-plus"); tapIf("live-home-plus"); tapIf("live-away-plus")
        tapIf("live-save-moment"); tapIf("live-save-moment"); sleep(1); shot("live-2")
        tapIf("live-end"); sleep(1)
    }

    // MARK: Game

    func testC_Game() {
        launch(["-demo"])
        tapSearchAndOpen("World Series", id: "mlb-2016-ws5")
        sleep(2); shot("game-ws5")
        app.swipeUp(); sleep(1); shot("game-ws5-2")
        app.swipeUp(); sleep(1); shot("game-ws5-3")
        app.swipeUp(); sleep(1); shot("game-ws5-4")
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
        if tapButtonIfExists("See all") { sleep(1); shot("game-photos-grid"); tapIf("photos-select", wait: 1); shot("game-photos-select"); back() }
        if tapIf("game-photo-0", wait: 2) { sleep(1); shot("photo-viewer"); tapButton("Close") }
        tapIf("game-menu"); sleep(1); shot("game-menu"); app.swipeDown()
        if app.buttons["game-share"].exists == false { /* menu closed */ }
        tapIf("hero-you-were-there", wait: 2); sleep(3); shot("ywt-0")
        app.swipeUp(); sleep(1); shot("ywt-1")
        app.swipeUp(); sleep(1); shot("ywt-2")
        app.swipeUp(); sleep(1); shot("ywt-3")
        back(); sleep(1)
        tapIf("play-recap", wait: 2); sleep(3); shot("recap-0"); sleep(4); shot("recap-1"); sleep(4); shot("recap-2")
        tapIf("recap-pause", wait: 1); tapIf("recap-close", wait: 2); sleep(1)
    }

    func tapButtonIfExists(_ l: String) -> Bool { tapButton(l, wait: 3) }

    func tapSearchAndOpen(_ q: String, id: String) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 3) { app.swipeDown() }
        _ = field.waitForExistence(timeout: 5)
        for _ in 0..<3 { field.tap(); if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break } }
        app.typeText(q)
        tapIf("game-card-\(id)")
    }

    func testC2_GameOthers() {
        launch(["-demo"])
        tapSearchAndOpen("Lambeau", id: "nfl-2025-w18-gb")
        sleep(2); shot("game-lambeau")
        app.swipeUp(); sleep(1); shot("game-lambeau-2")
        app.swipeUp(); sleep(1); shot("game-lambeau-3")
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }
        tapIf("open-trip", wait: 2); sleep(3); shot("trip-0")
        app.swipeUp(); sleep(1); shot("trip-1")
        app.swipeUp(); sleep(1); shot("trip-2")
    }

    func testC3_GameRacing() {
        launch(["-demo"])
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 3) { app.swipeDown() }
        field.tap(); sleep(1)
        app.typeText("Grand Prix"); sleep(1)
        shot("timeline-search")
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'game-card-'")).firstMatch
        if card.waitForExistence(timeout: 3) { card.tap(); sleep(3); shot("game-race"); app.swipeUp(); sleep(1); shot("game-race-2") }
    }

    func testC4_TripSpain() {
        launch(["-demo"])
        tapSearchAndOpen("Madrid", id: "lal-2020-clasico")
        sleep(2); shot("game-clasico")
        tapIf("open-trip", wait: 2); sleep(3); shot("trip-spain")
    }

    // MARK: Map, Passport, venue

    func testD_Map() {
        launch(["-demo"])
        tab("Map"); sleep(4); shot("map-0")
        if app.buttons["Expand map"].firstMatch.waitForExistence(timeout: 4) {
            app.buttons["Expand map"].firstMatch.tap(); sleep(3); shot("map-expanded")
            app.buttons["Close map"].firstMatch.tap(); sleep(1)
        }
        tapIf("map-menu-home", wait: 1)
        if app.buttons["Filter by sport"].exists { app.buttons["Filter by sport"].tap(); sleep(1); shot("map-filter-menu"); app.swipeDown(); tapIf("map-close", wait: 0) }
        if app.buttons["Set home"].exists || el("map-set-home").exists { }
        app.swipeUp(); sleep(1); shot("map-1")
        tapIf("stat-venues"); sleep(2); shot("map-venues")
        let v = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'map-venue-'")).firstMatch
        if v.exists { v.tap(); sleep(2); shot("map-venue-page"); back() }
        back(); sleep(1)
        tapIf("stat-countries"); sleep(2); shot("map-countries")
        let c = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'map-country-'")).firstMatch
        if c.exists { c.tap(); sleep(2); shot("map-country-games"); back() }
        back(); sleep(1)
        tapIf("stat-games"); sleep(2); shot("map-games"); back()
        tapIf("map-share"); sleep(10)
        shareSwipe("map-share", 4)
    }

    func shareSwipe(_ name: String, _ n: Int) {
        for i in 0..<n { shot("\(name)-\(i)"); app.swipeLeft(); sleep(2) }
    }

    func testD2_Passport() {
        launch(["-demo"])
        tab("Passport"); sleep(3); shot("passport-0")
        let sports = ["BASEBALL", "FOOTBALL", "SOCCER", "BASKETBALL", "HOCKEY", "MOTORSPORT"]
        var i = 0
        for s in sports {
            let b = app.buttons.matching(NSPredicate(format: "label ==[c] %@", s)).firstMatch
            if b.exists && s != "BASEBALL" { b.tap(); sleep(1); if s == "SOCCER" { tapIf("soccer-word-soccer", wait: 1) }; shot("passport-\(s.lowercased())"); i += 1 }
        }
        if tapIf("stamp-wrigley", wait: 2) == false { tapButton("BASEBALL") ; tapIf("stamp-wrigley", wait: 2) }
        sleep(3); shot("venue-0")
        app.swipeUp(); sleep(1); shot("venue-1")
        app.swipeUp(); sleep(1); shot("venue-2")
    }

    func testD3_PassportSoccerAndPlanned() {
        launch(["-demo"])
        tab("Passport"); sleep(2)
        let soccer = app.buttons.matching(NSPredicate(format: "label ==[c] 'SOCCER' OR label ==[c] 'FUDBAL'")).firstMatch
        if soccer.waitForExistence(timeout: 3) { soccer.tap() }
        sleep(1); shot("passport-soccer-prompt")
        tapIf("soccer-word-soccer", wait: 2); sleep(4); shot("passport-soccer-stamps")
    }

    // MARK: You

    func testE_You() {
        launch(["-demo"])
        tab("You"); sleep(2); shot("you-0")
        app.swipeUp(); sleep(1); shot("you-1")
        app.swipeUp(); sleep(1); shot("you-2")
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }
        tapIf("you-lucky"); sleep(2); shot("lucky-0")
        app.swipeUp(); sleep(1); shot("lucky-1")
        app.swipeUp(); sleep(1); shot("lucky-2")
        back()
        tapIf("you-big-games"); sleep(2); shot("big-games-0"); app.swipeUp(); sleep(1); shot("big-games-1"); back()
        tapIf("you-schedule-gaps"); sleep(3); shot("schedule-gaps"); back()
        tapIf("you-backup"); sleep(2); shot("backup")
        tapIf("backup-scan-check"); sleep(2); shot("scan-check"); tapIf("scan-check-run", wait: 2); sleep(5); shot("scan-check-ran"); back()
        back()
        for _ in 0..<2 { app.swipeDown(velocity: .fast) }
        if !el("you-teams").isHittable { app.swipeUp() }
        tapIf("you-teams"); sleep(2); shot("you-teams")
        tapIf("favorites-add", wait: 2); sleep(2); shot("favorites-add"); closeSheet()
        back()
        tapIf("you-privacy"); sleep(1); shot("legal-privacy"); back()
        tapIf("you-terms"); sleep(1); shot("legal-terms"); back()
        app.swipeUp(); sleep(1)
        if el("you-appearance").exists { shot("you-appearance") }
    }

    func testE2_Wrapped() {
        launch(["-demo", "-review-wrapped"])
        sleep(4); shot("wrapped-0")
        for i in 1..<8 { app.tap(); sleep(1); shot("wrapped-\(i)") }
        tapIf("wrapped-share", wait: 2); sleep(10)
        shareSwipe("wrapped-share", 9)
    }

    // MARK: Share

    func testF_ShareGame() {
        launch(["-demo"])
        tapSearchAndOpen("World Series", id: "mlb-2016-ws5")
        tapIf("game-menu"); tapIf("game-share"); sleep(8)
        shareSwipe("share-game", 3)
    }

    func testF2_ShareVenue() {
        launch(["-demo"])
        tab("Passport"); tapIf("stamp-wrigley"); _ = el("venue-title").waitForExistence(timeout: 6)
        tapIf("venue-share"); sleep(8)
        shareSwipe("share-venue", 3)
    }

    func testF3_SharePassport() {
        launch(["-demo"])
        tab("Passport"); sleep(3)
        app.buttons["Share passport"].firstMatch.tap(); sleep(6)
        shareSwipe("share-passport", 2)
    }

    func testF4_ShareRecapTripLuckyYou() {
        launch(["-demo"])
        tapSearchAndOpen("World Series", id: "mlb-2016-ws5")
        tapIf("play-recap"); sleep(3); tapIf("recap-pause", wait: 1); tapIf("recap-share"); sleep(8)
        shareSwipe("share-recap", 5)
        app.buttons["Close"].firstMatch.tap(); sleep(1)
        tapIf("recap-close"); sleep(1)
        back(); sleep(1)
        let field = app.searchFields.firstMatch
        if field.exists { field.tap(); app.typeText("Lambeau") }
        tapIf("game-card-nfl-2025-w18-gb")
        tapIf("open-trip"); sleep(3)
        if app.buttons["Share"].firstMatch.exists || app.buttons[app.navigationBars.buttons.element(boundBy: 1).label].exists {
            let share = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'share'")).firstMatch
            if share.exists { share.tap(); sleep(8); shareSwipe("share-trip", 5); app.buttons["Close"].firstMatch.tap() }
        }
    }

    func testF5_ShareLuckyAndYou() {
        launch(["-demo"])
        tab("You"); sleep(2)
        let share = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'share'")).firstMatch
        if share.exists { share.tap(); sleep(8); shareSwipe("share-you", 5); app.buttons["Close"].firstMatch.tap(); sleep(1) }
        tapIf("you-lucky"); sleep(2)
        tapIf("lucky-share"); sleep(8); shareSwipe("share-lucky", 5)
    }

    func testF6_ShareYouWereThereAndTrip() {
        launch(["-demo"])
        tapSearchAndOpen("World Series", id: "mlb-2016-ws5")
        tapIf("hero-you-were-there"); sleep(3)
        if tapButton("Share", wait: 3) { sleep(8); shareSwipe("share-ywt", 5); app.buttons["Close"].firstMatch.tap() }
    }

    func testF7_ShareTrip() {
        launch(["-demo"])
        tapSearchAndOpen("Lambeau", id: "nfl-2025-w18-gb")
        tapIf("open-trip"); sleep(3)
        if tapButton("Share", wait: 3) { sleep(8); shareSwipe("share-trip", 5); app.buttons["Close"].firstMatch.tap() }
    }
}
