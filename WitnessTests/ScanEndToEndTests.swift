import XCTest
import CoreLocation
@testable import Witness

/// BiH v Qatar (Lumen Field, June 24 2026, noon in Seattle) through the same calls the buttons make: onboarding and Find in
/// photos start the scan and take what it found for the review; "Look for more games?" starts the background search. The
/// photos are handed in; the schedules are ESPN's real responses for the day.
@MainActor
final class ScanEndToEndTests: XCTestCase {
    private var library: Library!
    private var ledgerURL: URL!
    private var pendingURL: URL!
    private let kickoff = ISO8601DateFormatter().date(from: "2026-06-24T19:00:00Z")!
    /// Set to false to make the World Cup schedule fail, like a lookup throttled under load.
    nonisolated(unsafe) private static var worldCupAnswers = true

    override func setUp() async throws {
        library = Library(storeURL: temp("library"))
        ledgerURL = temp("ledger")
        pendingURL = temp("pending")
        Self.worldCupAnswers = true
        let worldCup = try fixture("fifa-world-scoreboard-20260624")
        let mlb = try fixture("mlb-scoreboard-20260624")
        GameLookup.responder = { url in
            let s = url.absoluteString
            guard s.contains("/scoreboard?") else { return nil }
            if s.contains("soccer/fifa.world/scoreboard?dates=20260624") { return ScanEndToEndTests.worldCupAnswers ? worldCup : nil }
            if s.contains("baseball/mlb/scoreboard?dates=20260624") { return mlb }
            return Data(#"{"events":[]}"#.utf8)
        }
    }

    override func tearDown() async throws {
        GameLookup.responder = nil
        GameLookup.simulatedFailure = nil
    }

    private func temp(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "e2e-\(name)-\(UUID().uuidString).json")
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    private static func point(_ id: String, _ seattle: String, _ lat: Double?, _ lon: Double?) -> PhotoPoint {
        // Seattle is UTC-7 in June.
        PhotoPoint(id: id, date: ISO8601DateFormatter().date(from: "2026-06-24T\(seattle):00-07:00"),
                   latitude: lat, longitude: lon)
    }

    /// The matchday as the phone placed it: Occidental Park, the march, then photos filed at the ballpark's north end through
    /// the match and after. Plus an unrelated morning at home and a dinner downtown the day before.
    private var matchday: [PhotoPoint] {
        [
            Self.point("home-coffee", "07:40", 47.6740, -122.3870),     // Ballard, 9 km away
            Self.point("occidental-park", "10:05", 47.6000, -122.3330),
            Self.point("march", "10:50", 47.5975, -122.3330),
            Self.point("gate", "11:25", 47.5925, -122.3327),
            Self.point("anthem", "11:58", 47.5921, -122.3330),
            Self.point("goal", "12:31", 47.5928, -122.3324),
            Self.point("full-time", "13:52", 47.5923, -122.3326),
            Self.point("after", "14:20", 47.5930, -122.3322),
        ]
    }

    /// A World Cup day photographed outside: the fan zone, the north plaza, the west side by the waterfront, the walk out, and
    /// no fix inside the bowl (a full stadium is a poor place for GPS). None of it makes a visit.
    private var aroundTheGround: [PhotoPoint] {
        [
            Self.point("fan-zone", "10:05", 47.6000, -122.3330),       // Occidental Park, 540 m north of Lumen Field
            Self.point("plaza-1", "10:40", 47.5986, -122.3330),        // north plaza, ~375 m
            Self.point("plaza-2", "11:10", 47.5982, -122.3317),        // ~325 m
            Self.point("west-gate", "11:35", 47.5957, -122.3360),      // ~330 m west
            Self.point("walk-out", "14:10", 47.5984, -122.3322),       // ~345 m
        ]
    }

    private func model(_ points: [PhotoPoint], look: SceneCheck.DayLook = .init()) -> ScanModel {
        ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in PhotoMatcher.found(in: points, venues: venues, existing: existing) },
            look: { _, _ in look },
            suggest: { _, _, _, _, _, _ in [] }))
    }

    /// Find in photos: a fresh scan, then the review takes what it found.
    private func findInPhotos(_ scan: ScanModel) async -> ScanModel.Review {
        scan.reset()
        scan.start(library: library)
        await scan.finished()
        return scan.takeForReview(library: library)
    }

    private func savedVisit(photos ids: [String], game: Bool = false) -> GameEntry {
        var saved = GameEntry(sport: .baseball, date: ISO8601DateFormatter().date(from: "2026-06-24T17:05:00Z")!, venueId: "mlb-sea",
                              photos: ids.map { PhotoRef.library($0) }, origin: .photos)
        if !game {
            saved.kind = .visit
            saved.competition = "Stadium visit"
        }
        library.add(saved)
        return saved
    }

    private var stadiumIds: [String] { ["occidental-park", "march", "gate", "anthem", "goal", "full-time", "after"] }

    private func assertTheMatch(_ entry: GameEntry?, file: StaticString = #filePath, line: UInt = #line) throws {
        let entry = try XCTUnwrap(entry, "BiH v Qatar is not in the library", file: file, line: line)
        XCTAssertEqual(entry.source?.eventId, "760462", file: file, line: line)
        XCTAssertEqual(entry.venueId, "lumen-field", file: file, line: line)
        XCTAssertFalse(entry.isVisit, file: file, line: line)
        XCTAssertEqual(library.team(entry.homeTeamId)?.abbreviation, "BIH", file: file, line: line)
        XCTAssertEqual(library.team(entry.awayTeamId)?.abbreviation, "QAT", file: file, line: line)
    }

    private var matchdayEntries: [GameEntry] {
        library.games.filter { abs($0.date.timeIntervalSince(kickoff)) < 12 * 3600 }
    }

    // MARK: (a) An empty library

    func testOnboardingFindsTheMatchInAnEmptyLibrary() async throws {
        let scan = model(matchday)
        scan.start(library: library)
        await scan.finished()
        XCTAssertEqual(scan.state, .done)
        // The result screen's "N games found" and its first card.
        XCTAssertEqual(scan.games.count, 1)
        XCTAssertEqual(scan.newest?.eventId, "760462")
        let review = scan.takeForReview(library: library)
        XCTAssertEqual(review.games.count, 1)
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertEqual(scan.commit(review.games, into: library), 1)
        try assertTheMatch(matchdayEntries.first)
    }

    // MARK: (b) A saved stadium visit at T-Mobile Park

    /// The saved visit's photos are the library's, and the review dropped every game whose photos the library had: the scan
    /// found the match again and the review threw it away.
    func testFindInPhotosOffersTheMatchForASavedStadiumVisit() async throws {
        let saved = savedVisit(photos: stadiumIds)
        let scan = model(matchday)
        let review = await findInPhotos(scan)
        XCTAssertEqual(review.games.count, 1, "The match found for the saved visit's photos was left out of the review")
        let card = try XCTUnwrap(review.games.first)
        XCTAssertTrue(Set(card.assetIds).isSuperset(of: stadiumIds))
        XCTAssertEqual(scan.matches[card.id]?.eventId, "760462")

        // Confirming it turns the visit into the game: one card, the visit's id.
        scan.commit([card], into: library)
        XCTAssertEqual(matchdayEntries.count, 1)
        try assertTheMatch(matchdayEntries.first)
        XCTAssertEqual(matchdayEntries.first?.id, saved.id)
    }

    /// The same through the onboarding result screen's "Add all".
    func testOnboardingAddAllUpgradesASavedStadiumVisit() async throws {
        let saved = savedVisit(photos: Array(stadiumIds.prefix(3)))
        let scan = model(matchday)
        scan.start(library: library)
        await scan.finished()
        XCTAssertEqual(scan.games.count, 1)
        scan.commit(scan.games, into: library)
        XCTAssertEqual(matchdayEntries.count, 1)
        try assertTheMatch(matchdayEntries.first)
        XCTAssertEqual(matchdayEntries.first?.id, saved.id)
        XCTAssertTrue(Set(matchdayEntries.first?.photos ?? []).isSuperset(of: stadiumIds.map { PhotoRef.library($0) }))
    }

    /// A game card saved from these photos before its lookup came back (no teams, no event) kept the day from every scan.
    func testFindInPhotosOffersTheMatchForAGameCardWithNoTeams() async throws {
        let saved = savedVisit(photos: stadiumIds, game: true)
        let scan = model(matchday)
        let review = await findInPhotos(scan)
        let card = try XCTUnwrap(review.games.first, "A game card with no teams hid the matchday from the scan")
        scan.commit([card], into: library)
        XCTAssertEqual(matchdayEntries.count, 1)
        try assertTheMatch(matchdayEntries.first)
        XCTAssertEqual(matchdayEntries.first?.id, saved.id)
    }

    /// A real game saved for the day still keeps it: nothing is offered twice.
    func testASavedMatchIsNotOfferedAgain() async throws {
        let scan = model(matchday)
        var review = await findInPhotos(scan)
        scan.commit(review.games, into: library)
        review = await findInPhotos(scan)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
        XCTAssertEqual(matchdayEntries.count, 1)
    }

    // MARK: (c) A saved visit and an earlier skip

    /// Skipping the day as a stadium visit (or as a possible day) said nothing about a game the schedule finds for it later.
    func testASkippedStadiumVisitDoesNotHideTheMatch() async throws {
        savedVisit(photos: stadiumIds)
        let scan = model(matchday)
        scan.dismiss(stadiumIds, on: kickoff)
        scan.dismiss(["occidental-park", "march"], on: kickoff)
        let review = await findInPhotos(scan)
        XCTAssertEqual(review.games.count, 1, "A skipped stadium visit hid the game found for its photos")
    }

    /// Skipping the game itself still holds, after a relaunch too.
    func testASkippedGameStaysSkipped() async throws {
        let scan = model(matchday)
        let first = await findInPhotos(scan)
        let card = try XCTUnwrap(first.games.first)
        scan.dismiss(card.assetIds, on: card.start, asGame: true)
        let again = await findInPhotos(model(matchday))
        XCTAssertTrue(again.games.isEmpty)
    }

    /// A ledger written before game skips were kept apart still reads.
    func testAnOlderLedgerStillReads() throws {
        try Data(#"{"dismissedAssets":["a"],"dismissedDays":["2026-06-24"]}"#.utf8).write(to: ledgerURL)
        let ledger = ReviewLedger.load(from: ledgerURL)
        XCTAssertEqual(ledger.dismissedAssets, ["a"])
        XCTAssertEqual(ledger.dismissedDays, ["2026-06-24"])
        XCTAssertTrue(ledger.dismissedGames.isEmpty)
    }

    // MARK: (d) Photos in iCloud, not loaded

    /// The first pass needs only each photo's time and place; nothing it sees in the photos can keep a schedule match out.
    func testPhotosInICloudStillMatch() async throws {
        let review = await findInPhotos(model(matchday, look: SceneCheck.DayLook()))
        XCTAssertEqual(review.games.count, 1)
    }

    /// A lookup that failed in the first pass leaves the day a stadium visit (five photos inside the fence over three hours),
    /// offered as one and nothing waiting; saved as a visit, the next Find in photos asks the schedule again and offers the match.
    func testAVisitWhoseLookupFailedIsOfferedAndMatchedNextTime() async throws {
        Self.worldCupAnswers = false
        let scan = model(matchday, look: SceneCheck.DayLook())
        let first = await findInPhotos(scan)
        XCTAssertTrue(first.games.isEmpty)
        XCTAssertEqual(first.others.map(\.venue.id), ["mlb-sea"], "Offered as a stadium visit")
        XCTAssertTrue(scan.pendingVisits.isEmpty, "Nothing waits for the background search")
        scan.commit(first.others, asVisits: true, into: library)
        Self.worldCupAnswers = true
        let review = await findInPhotos(scan)
        XCTAssertEqual(review.games.count, 1)
        scan.commit(review.games, into: library)
        XCTAssertEqual(matchdayEntries.count, 1)
        try assertTheMatch(matchdayEntries.first)
    }

    // MARK: No connection

    /// Requests the schedule server was asked for, counted for the tests below.
    nonisolated(unsafe) private static var requests = 0
    nonisolated private static let requestLock = NSLock()
    nonisolated private static func count() { requestLock.lock(); requests += 1; requestLock.unlock() }

    /// The matchday repeated on `days` earlier days: one visit each.
    private func manyMatchdays(_ days: Int) -> [PhotoPoint] {
        (0..<days).flatMap { n in
            matchday.map {
                PhotoPoint(id: "\($0.id)-\(n)", date: $0.date?.addingTimeInterval(-Double(n) * 86_400 * 3), latitude: $0.latitude, longitude: $0.longitude)
            }
        }
    }

    /// Offline, the scan finishes without deciding anything about the visit: it is not a stadium visit, not dropped, and the
    /// screens say how many could not be checked. Back online, the next Find in photos finds the match.
    func testOfflineScanLeavesTheVisitUncheckedAndTheNextScanFindsIt() async throws {
        GameLookup.simulatedFailure = { _ in .notConnectedToInternet }
        defer { GameLookup.simulatedFailure = nil }
        let scan = model(matchday, look: SceneCheck.DayLook())
        let offline = await findInPhotos(scan)
        XCTAssertEqual(scan.state, .empty)
        XCTAssertTrue(offline.games.isEmpty && offline.others.isEmpty && offline.possible.isEmpty,
                      "A visit whose lookup could not run was judged a stadium visit or a game")
        XCTAssertEqual(scan.uncheckedVisits, 1)
        XCTAssertEqual(scan.skippedVisits, 0, "Not dropped either")
        XCTAssertEqual(scan.pendingVisits.count, 1, "Kept for the next look")
        XCTAssertEqual(PhotoAccess.uncheckedLine(scan.uncheckedVisits), "1 visit couldn't be checked, connect and run Find in photos again.")

        GameLookup.simulatedFailure = nil
        let online = await findInPhotos(scan)
        XCTAssertEqual(online.games.count, 1)
        XCTAssertEqual(scan.uncheckedVisits, 0)
    }

    /// The first offline failure stops every later lookup: a scan of many visits sends a few requests, not all of them.
    func testOfflineStopsFurtherLookups() async throws {
        let points = manyMatchdays(12)
        Self.requests = 0
        GameLookup.simulatedFailure = { _ in Self.count(); return nil }
        let scan = model(points, look: SceneCheck.DayLook())
        _ = await findInPhotos(scan)
        let connected = Self.requests
        XCTAssertEqual(scan.uncheckedVisits, 0)
        XCTAssertGreaterThan(connected, 12)

        Self.requests = 0
        GameLookup.simulatedFailure = { _ in Self.count(); return .networkConnectionLost }
        defer { GameLookup.simulatedFailure = nil }
        let review = await findInPhotos(scan)
        // A visit the phone's own downloaded schedule can answer needs no connection, so it may be a game; the rest are
        // unchecked. None is judged "no game" or a stadium visit.
        XCTAssertGreaterThan(scan.uncheckedVisits, 0)
        XCTAssertEqual(scan.uncheckedVisits + review.games.count, 12, "Every visit is a game from the on-device schedule or unchecked, none judged")
        XCTAssertTrue(review.others.isEmpty && review.possible.isEmpty)
        XCTAssertLessThan(Self.requests, connected / 2, "Lookups kept going after the device was offline")
    }

    /// A lookup that fails some other way (a timeout under load) is not "no game" either: unchecked, and tried once more.
    func testALookupThatTimedOutIsNotAVisitWithNoGame() async throws {
        GameLookup.simulatedFailure = { _ in .timedOut }
        defer { GameLookup.simulatedFailure = nil }
        let scan = model(matchday, look: SceneCheck.DayLook())
        let review = await findInPhotos(scan)
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty)
        XCTAssertEqual(scan.uncheckedVisits, 1)
    }

    /// The background search does not turn a visit whose lookup could not run into a stadium visit either.
    func testTheBackgroundSearchDoesNotJudgeAVisitItCouldNotCheck() async throws {
        let cluster = try XCTUnwrap(PhotoMatcher.found(in: matchday, venues: library.venues, existing: []).visits.first)
        GameLookup.simulatedFailure = { _ in .notConnectedToInternet }
        defer { GameLookup.simulatedFailure = nil }
        let offline = await ScanModel.waitingDay(cluster, venues: library.venues)
        XCTAssertNil(offline)
        GameLookup.simulatedFailure = nil
        Self.worldCupAnswers = false
        let answered = await ScanModel.waitingDay(cluster, venues: library.venues)
        XCTAssertNotNil(answered, "Answered with no game, a stadium visit is offered")
    }

    func testWhichErrorsMeanOffline() {
        XCTAssertTrue(LookupOutage.isOfflineError(.notConnectedToInternet))
        XCTAssertTrue(LookupOutage.isOfflineError(.networkConnectionLost))
        XCTAssertTrue(LookupOutage.isOfflineError(.dataNotAllowed))
        XCTAssertFalse(LookupOutage.isOfflineError(.timedOut))
    }

    // MARK: (e) Photos around the ground, not inside it

    /// A World Cup crowd photographs the plaza and the march, and the phone placed nothing inside the bowl. No visit, so the
    /// first pass found nothing; now the day is offered as a possible game at Lumen Field.
    func testPhotosAroundTheGroundAreOfferedAsAPossibleGame() async throws {
        let scan = model(aroundTheGround)
        scan.start(library: library)
        await scan.finished()
        XCTAssertEqual(scan.state, .done)
        XCTAssertTrue(scan.games.isEmpty)
        let review = scan.takeForReview(library: library)
        let day = try XCTUnwrap(review.possible.first, "Photos around Lumen Field on a World Cup day were not offered")
        XCTAssertEqual(day.suggestions.first?.id, "lumen-field")
        XCTAssertTrue(day.reason.contains("Bosnia"), day.reason)
        XCTAssertEqual(Set(day.assetIds), Set(aroundTheGround.map(\.id)))
        // Picking the stadium in the review finds the match from the day.
        let found = await GameLookup.gameNear(day.day, at: try XCTUnwrap(library.venue("lumen-field")))
        XCTAssertEqual(found.game?.eventId, "760462")
    }

    /// The same photos on a day with no game anywhere near are not offered: living by the ground is not going to games.
    func testPhotosAroundTheGroundWithNoGameAreLeftAlone() async throws {
        let dayBefore = aroundTheGround.map {
            PhotoPoint(id: $0.id, date: $0.date?.addingTimeInterval(-86_400), latitude: $0.latitude, longitude: $0.longitude)
        }
        let review = await findInPhotos(model(dayBefore))
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    /// Photos around the ground on the day of a match already found from photos inside it are that match, not another day to ask about.
    func testPhotosAroundTheGroundJoinTheMatchDay() async throws {
        let review = await findInPhotos(model(matchday + aroundTheGround.map {
            PhotoPoint(id: "x-" + $0.id, date: $0.date, latitude: $0.latitude, longitude: $0.longitude)
        }))
        XCTAssertEqual(review.games.count, 1)
        XCTAssertTrue(review.possible.isEmpty)
    }

    /// One fix inside the bowl is not a game: the photos of that day with no stadium fix, or far away, do not count toward the
    /// stay (the fan zone at 540 m is outside the 500 m reach), and a lone fix is a drive past. (This test once said the day around
    /// it made the match; photos that are not near the ground no longer make or stretch a visit.)
    func testOnePhotoInsideTheBowlWithNothingNearItIsNotAGame() async throws {
        let review = await findInPhotos(model([Self.point("fan-zone", "10:05", 47.6000, -122.3330),
                                               Self.point("bowl", "12:20", 47.5955, -122.3318),
                                               Self.point("home", "20:00", 47.6740, -122.3870),
                                               Self.point("no-gps", "21:00", nil, nil)]))
        XCTAssertTrue(review.games.isEmpty, "games \(review.games.map(\.id))")
        XCTAssertTrue(review.others.isEmpty, "others \(review.others.map(\.id))")
        XCTAssertTrue(review.possible.isEmpty, "possible \(review.possible.map(\.reason))")
    }

    /// A taxi past the ground with one red-light shot, and breakfast at home that morning: nothing.
    func testATaxiPastTheGroundAndBreakfastAtHomeIsNothing() async throws {
        let review = await findInPhotos(model([Self.point("breakfast", "07:40", 47.6740, -122.3870),
                                               Self.point("red-light", "11:50", 47.5955, -122.3318),
                                               Self.point("lunch-no-gps", "13:00", nil, nil)]))
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    /// One fix inside the bowl and one within the near reach 20 minutes later span the stay: a game.
    func testOnePhotoInsideAndANearPhotoTwentyMinutesLaterIsTheMatch() async throws {
        let review = await findInPhotos(model([Self.point("bowl", "12:20", 47.5955, -122.3318),
                                               Self.point("plaza", "12:40", 47.5982, -122.3317)]))
        XCTAssertEqual(review.games.count, 1)
        XCTAssertEqual(Set(review.games.first?.assetIds ?? []), ["bowl", "plaza"])
    }

    /// Photos with no place join a visit that exists, but do not make it or stretch the window the schedule is asked about.
    func testLoosePhotosJoinAVisitButDoNotStretchIt() async throws {
        let found = PhotoMatcher.found(in: [Self.point("in-1", "11:50", 47.5955, -122.3318), Self.point("in-2", "12:30", 47.5950, -122.3312),
                                            Self.point("home", "07:40", 47.6740, -122.3870), Self.point("no-gps", "22:00", nil, nil)],
                                       venues: library.venues, existing: [])
        let visit = try XCTUnwrap(found.visits.first)
        XCTAssertEqual(Set(visit.assetIds), ["in-1", "in-2", "home", "no-gps"], "Adopted as photos of the visit")
        XCTAssertEqual(visit.end.timeIntervalSince(visit.start), 40 * 60, "The window is the photos at the ground")
    }

    /// The visit rule itself: two photos inside a fence at least 15 minutes apart. Two inside the bowl are enough.
    func testTwoPhotosThirtyMinutesApartInsideTheBowlMakeAVisit() async throws {
        let review = await findInPhotos(model([Self.point("in-1", "11:50", 47.5955, -122.3318), Self.point("in-2", "12:20", 47.5950, -122.3312)]))
        XCTAssertEqual(review.games.count, 1)
    }

    func testTwoPhotosInsideTheBowlMakeAVisit() async throws {
        let points = [Self.point("in-1", "11:50", 47.5955, -122.3318), Self.point("in-2", "12:40", 47.5950, -122.3312)]
        let review = await findInPhotos(model(points))
        XCTAssertEqual(review.games.count, 1)
    }

    // MARK: (f) No location

    /// Photos with a date and no location say nothing about where the fan was: the first pass offers nothing, and only an album
    /// or a trip can bring the day to the background search.
    func testPhotosWithNoLocationAreNotGuessed() async throws {
        let points = matchday.map { PhotoPoint(id: $0.id, date: $0.date, latitude: nil, longitude: nil) }
        let review = await findInPhotos(model(points))
        XCTAssertTrue(review.games.isEmpty && review.others.isEmpty && review.possible.isEmpty)
    }

    // MARK: The scan check

    /// The scan check names each gate between the photos and the review: the skips on disk, what waits for the background
    /// search, the days around a stadium, and whether the review would show the match.
    func testScanCheckNamesWhatKeepsTheMatchOut() throws {
        let saved = savedVisit(photos: stadiumIds)
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        var ledger = ReviewLedger()
        let cluster = try XCTUnwrap(PhotoMatcher.found(in: matchday, venues: library.venues, existing: library.games).visits.first)
        XCTAssertEqual(ScanCheck.verdict(cluster, library: library.games, venues: library.venues, ledger: ledger), "the review shows it")
        ledger.dismiss(stadiumIds, span: matchday[1].date!...matchday[7].date!, game: true)
        XCTAssertEqual(ScanCheck.verdict(cluster, library: library.games, venues: library.venues, ledger: ledger),
                       "left out: skipped as a game in an earlier review")
        let text = ScanCheck.gates(points: matchday, venues: library.venues, library: library.games, ledger: ledger,
                                   pending: [cluster], zone: zone).joined(separator: "\n")
        XCTAssertTrue(text.contains("7 of this day's photos skipped, 7 of them as a game \u{00B7} outing skipped near this day's photos: yes"), text)
        XCTAssertTrue(text.contains("Waiting for the background search (pending-visits.json): T-Mobile Park [mlb-sea|2026-06-24]"), text)
        XCTAssertTrue(text.contains("Around a stadium, no photo inside its fence"), text)
        // A saved game holds its photos.
        var game = saved
        game.kind = nil
        game.source = GameEntry.Source(provider: "espn", league: "soccer/fifa.world", eventId: "760462")
        library.update(game)
        XCTAssertTrue(ScanCheck.verdict(cluster, library: library.games, venues: library.venues, ledger: .init())
            .hasPrefix("left out: its photos are on a saved game"))

        let around = ScanCheck.gates(points: aroundTheGround, venues: library.venues, library: [], ledger: .init(), pending: [],
                                     zone: zone).joined(separator: "\n")
        XCTAssertTrue(around.contains("Lumen Field [lumen-field|2026-06-24]: 5 photos, 10:05\u{2013}14:10"), around)
    }
}
