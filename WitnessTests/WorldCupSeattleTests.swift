import XCTest
@testable import Witness

/// Bosnia and Herzegovina 3, Qatar 1, World Cup group B, Lumen Field, June 24 2026, noon in Seattle (19:00 UTC).
/// The fan's phone filed the matchday at T-Mobile Park, 440 m south, where the Mariners were away (at Pittsburgh). An earlier
/// build found no game there and the day was saved as a stadium visit. Schedules are ESPN's real responses for that day.
@MainActor
final class WorldCupSeattleTests: XCTestCase {
    private var library: Library!
    private let kickoff = ISO8601DateFormatter().date(from: "2026-06-24T19:00:00Z")!

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "wc-\(UUID().uuidString).json"))
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
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    /// The day in Seattle time: the fan meeting in Occidental Park, the march down Occidental Ave, then photos the phone placed
    /// at the ballpark's north end through the match and after (a bowl full of people is a poor place for a GPS fix).
    private var matchday: [PhotoPoint] {
        let f = ISO8601DateFormatter()
        func p(_ id: String, _ utc: String, _ lat: Double, _ lon: Double) -> PhotoPoint {
            PhotoPoint(id: id, date: f.date(from: utc), latitude: lat, longitude: lon)
        }
        return [
            p("occidental-park", "2026-06-24T17:05:00Z", 47.6000, -122.3330),  // 10:05, 540 m north of Lumen Field
            p("march", "2026-06-24T17:50:00Z", 47.5975, -122.3330),            // 10:50, just outside Lumen's fence
            p("gate", "2026-06-24T18:25:00Z", 47.5925, -122.3327),             // 11:25
            p("anthem", "2026-06-24T18:58:00Z", 47.5921, -122.3330),           // 11:58
            p("goal", "2026-06-24T19:31:00Z", 47.5928, -122.3324),             // 12:31
            p("full-time", "2026-06-24T20:52:00Z", 47.5923, -122.3326),        // 13:52
            p("after", "2026-06-24T21:20:00Z", 47.5930, -122.3322),            // 14:20
        ]
    }

    private var ballparkVisit: PhotoCluster {
        get throws {
            let scan = VisitGrouping.group(matchday, venues: library.venues, minimumStay: 15 * 60)
            return try XCTUnwrap(scan.visits.first { $0.venue.id == "mlb-sea" }, "The phone's fixes put the day at T-Mobile Park")
        }
    }

    func testScheduleHasTheMatchAtLumenField() throws {
        let games = GameLookup.parseScoreboard(try fixture("fifa-world-scoreboard-20260624"), league: "soccer/fifa.world")
        let lumen = try XCTUnwrap(library.venue("lumen-field"))
        let game = try XCTUnwrap(games.first { GameLookup.venueMatches($0, venue: lumen) })
        XCTAssertEqual(game.eventId, "760462")
        XCTAssertEqual(game.home.abbreviation, "BIH")
        XCTAssertEqual(game.away.abbreviation, "QAT")
        XCTAssertEqual(game.start, kickoff)
        XCTAssertEqual(VisitGrouping.dayString(game.start, tz: lumen.tz), "2026-06-24")
        XCTAssertTrue(GameLookup.leagues(for: lumen).contains("soccer/fifa.world"))
        XCTAssertFalse(GameLookup.venueMatches(game, venue: try XCTUnwrap(library.venue("mlb-sea"))))
    }

    /// The scan skipped every stadium on a day the library already had something for, a stadium visit included, so once
    /// the day was saved as a visit no later scan looked at it again. Now the visit's photos are matched again and the
    /// visit becomes the game, at the ground it was played at.
    func testSavedStadiumVisitNoLongerHidesTheMatch() async throws {
        let visit = try ballparkVisit
        var saved = GameEntry(sport: .baseball, date: visit.start, venueId: "mlb-sea",
                              photos: visit.assetIds.map { PhotoRef.library($0) }, origin: .photos)
        saved.kind = .visit
        saved.competition = "Stadium visit"
        library.add(saved)

        let keys = PhotoMatcher.settledKeys(library.games, venues: library.venues)
        let scan = VisitGrouping.group(matchday, venues: library.venues, minimumStay: 15 * 60, skipping: keys)
        let cluster = try XCTUnwrap(scan.visits.first, "The saved stadium visit hid the matchday from the scan")
        let matched = await ScanModel.match(cluster, venues: library.venues)
        let game = try XCTUnwrap(matched, "No game at T-Mobile Park or next door")
        XCTAssertEqual(game.eventId, "760462")

        ScanModel().commit([cluster], matches: [cluster.id: game], into: library)
        let day = library.games.filter { abs($0.date.timeIntervalSince(kickoff)) < 12 * 3600 }
        XCTAssertEqual(day.count, 1, "The visit became the game, not a second card")
        let entry = try XCTUnwrap(day.first)
        XCTAssertEqual(entry.id, saved.id)
        XCTAssertEqual(entry.venueId, "lumen-field")
        XCTAssertFalse(entry.isVisit)
        XCTAssertEqual(entry.sport, .soccer)
        XCTAssertEqual(entry.source?.eventId, "760462")
        XCTAssertEqual(entry.date, kickoff)
        XCTAssertNotEqual(entry.competition, "Stadium visit")
        XCTAssertEqual(library.team(entry.homeTeamId)?.abbreviation, "BIH")
        XCTAssertEqual(library.team(entry.awayTeamId)?.abbreviation, "QAT")
        XCTAssertEqual(Set(entry.photos), Set(visit.assetIds.map { PhotoRef.library($0) }))
    }

    /// The scan check the fan can share from the phone names where each photo landed and what the saved visit does.
    func testScanCheckTracesTheDay() throws {
        let visit = try ballparkVisit
        var saved = GameEntry(sport: .baseball, date: visit.start, venueId: "mlb-sea", photos: [.library("gate")], origin: .photos)
        saved.kind = .visit
        let text = ScanCheck.lines(points: matchday, venues: library.venues, saved: [saved],
                                   zone: TimeZone(identifier: "America/Los_Angeles")!).joined(separator: "\n")
        XCTAssertTrue(text.contains("Photos: 7 (7 with a location, 0 without)"), text)
        XCTAssertTrue(text.contains("11:25  47.59250,-122.33270  inside T-Mobile Park"), text)
        XCTAssertTrue(text.contains("near Lumen Field"), text)
        XCTAssertTrue(text.contains("stadium visit at T-Mobile Park, 1 photos \u{00B7} checked again by the scan"), text)
        // The meeting point and the march, outside every fence, belong to the day's visit.
        XCTAssertTrue(text.contains("T-Mobile Park [mlb-sea|2026-06-24]: 7 photos, 10:05\u{2013}14:20"), text)
    }

    /// A real game is still a game: a saved one keeps its day to itself.
    func testSavedGameStillKeepsItsDay() throws {
        var game = GameEntry(sport: .soccer, date: kickoff, venueId: "mlb-sea", origin: .photos)
        game.source = GameEntry.Source(provider: "espn", league: "soccer/fifa.world", eventId: "760462")
        library.add(game)
        let keys = PhotoMatcher.settledKeys(library.games, venues: library.venues)
        XCTAssertTrue(VisitGrouping.group(matchday, venues: library.venues, minimumStay: 15 * 60, skipping: keys).visits.isEmpty)
    }

    /// Stadium visits waiting for the background search were offered as "no game that day" without asking the schedule, so a
    /// visit left over from a scan that never looked next door stayed a visit. The schedule is asked first now, next door too.
    func testWaitingVisitIsCheckedAgainstTheScheduleNextDoor() async throws {
        let visit = try ballparkVisit
        // The photos are in iCloud and not loaded: the scene check sees nothing.
        let waiting = await ScanModel.waitingDay(visit, venues: library.venues) { _ in SceneCheck.DayLook() }
        let day = try XCTUnwrap(waiting, "A matched visit is offered whatever its photos look like")
        XCTAssertEqual(day.suggestions.first?.id, "lumen-field")
        XCTAssertTrue(day.reason.contains("Bosnia"), day.reason)
        // Picking that stadium in the review finds the match from the photos' date.
        let lumen = try XCTUnwrap(library.venue("lumen-field"))
        let found = await GameLookup.gameNear(day.day, at: lumen)
        XCTAssertEqual(found.game?.eventId, "760462")
        XCTAssertEqual(found.shift, 0)
    }

    /// The background search ruled a day out when the stadium its photos were near had no game, without asking the
    /// ground next door.
    func testBackgroundSearchAsksTheGroundNextDoorBeforeRulingADayOut() async throws {
        let ballpark = try XCTUnwrap(library.venue("mlb-sea"))
        let shape = try XCTUnwrap(GameSuggester.DayShape.of(matchday.compactMap(\.date)))
        let result = await GameSuggester.scheduled(at: [ballpark], shape: shape, specific: true, venues: library.venues)
        guard case .game(let game, let venue, let specific) = result else {
            return XCTFail("T-Mobile Park's schedule alone ruled the World Cup day out")
        }
        XCTAssertEqual(game.eventId, "760462")
        XCTAssertEqual(venue.id, "lumen-field")
        XCTAssertTrue(specific)
    }
}
