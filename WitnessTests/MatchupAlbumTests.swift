import XCTest
@testable import Witness

/// The owner's BiH v Qatar photos carry no location (118 of 123 that day) and sit in an album titled for the match. National
/// sides have no home ground, so the title pointed at no stadium and only the fan's home stadiums were asked: the World Cup
/// game in Seattle was never found. Now the title's two teams ask their own schedules. The phone is in Chicago, the game in
/// Seattle; the schedules are ESPN's real responses for June 24 2026.
@MainActor
final class MatchupAlbumTests: XCTestCase {
    private var library: Library!
    private var ledgerURL: URL!
    private var pendingURL: URL!
    private var zone: TimeZone!

    override func setUp() async throws {
        zone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/Chicago")!
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "ma-\(UUID().uuidString).json"))
        ledgerURL = FileManager.default.temporaryDirectory.appending(path: "ma-ledger-\(UUID().uuidString).json")
        pendingURL = FileManager.default.temporaryDirectory.appending(path: "ma-pending-\(UUID().uuidString).json")
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
        NSTimeZone.default = zone
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "Missing fixture \(name)")
        return try Data(contentsOf: url)
    }

    /// 40 photos with no location, every five minutes from 11:20 to 14:35 in Seattle (18:20 to 21:35 UTC): the match.
    private func matchPhotos(shift: TimeInterval = 0) -> [PhotoPoint] {
        let start = ISO8601DateFormatter().date(from: "2026-06-24T18:20:00Z")!.addingTimeInterval(shift)
        return (0..<40).map { PhotoPoint(id: "m\($0)", date: start.addingTimeInterval(Double($0) * 300), latitude: nil, longitude: nil) }
    }

    private func album(_ title: String, _ points: [PhotoPoint]) -> PhotoAlbum {
        PhotoAlbum(id: "album-1", title: title, count: points.count, coverId: points.last?.id,
                   start: points.first?.date, end: points.last?.date)
    }

    private func model(albums: [(PhotoAlbum, [PhotoPoint])]) -> ScanModel {
        ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in
                PhotoMatcher.found(in: albums.flatMap(\.1), venues: venues, existing: existing)
            },
            look: { _, _ in SceneCheck.DayLook() },
            suggest: { _, _, _, _, _, _ in [] },
            matchups: { venues, teams, existing in
                await MatchupAlbums.find(albums: albums.map(\.0), points: { a in albums.first { $0.0.id == a.id }?.1 ?? [] },
                                         teams: teams, venues: venues, existing: existing)
            }))
    }

    private func findInPhotos(_ scan: ScanModel) async -> ScanModel.Review {
        scan.reset()
        scan.start(library: library)
        await scan.finished()
        return scan.takeForReview(library: library)
    }

    static let titles = ["BiH v Qatar", "BiH vs Qatar", "Bosnia vs Qatar", "Bosnia vs. Qatar 2026 \u{1F1E7}\u{1F1E6}\u{1F1F6}\u{1F1E6}",
                         "Bosnia and Herzegovina - Qatar", "Bosna i Hercegovina \u{2013} Katar", "World Cup: BiH x Qatar",
                         "Bosnia-Herzegovina v Qatar", "BIH @ QAT", "Seattle! BiH vs Qatar \u{26BD}\u{FE0F}", "Qatar v Bosnia",
                         "bih v qatar world cup 2026", "BiH-Qatar", "Bosnia : Qatar"]

    func testTitlesNameBothSides() {
        for title in Self.titles {
            let parsed = MatchupAlbums.parse(title, teams: library.allTeams)
            XCTAssertTrue(parsed.isMatchup, "\(title): \(parsed.sides)")
            let codes = Set([parsed.home.first?.abbreviation, parsed.away.first?.abbreviation])
            XCTAssertEqual(codes, ["BIH", "QAT"], title)
        }
        for title in ["Summer 2026", "Family", "Seattle trip", "Favorites", "Recents", "Wedding - Sarah & Tom"] {
            XCTAssertFalse(MatchupAlbums.parse(title, teams: library.allTeams).isMatchup, title)
        }
    }

    /// Find in photos: the album's photos, none with a location, become a possible game at Lumen Field, for every title.
    func testFindInPhotosOffersTheMatchFromItsAlbum() async throws {
        for title in Self.titles {
            let points = matchPhotos()
            let review = await findInPhotos(model(albums: [(album(title, points), points)]))
            XCTAssertTrue(review.games.isEmpty, title)
            let day = try XCTUnwrap(review.possible.first, "\(title): the album was not offered")
            XCTAssertEqual(review.possible.count, 1, title)
            XCTAssertEqual(day.suggestions.first?.id, "lumen-field", title)
            XCTAssertTrue(day.reason.contains("\u{201C}\(title)\u{201D}"), day.reason)
            XCTAssertTrue(day.reason.contains("Qatar at Bosnia-Herzegovina, Lumen Field"), day.reason)
            XCTAssertEqual(Set(day.assetIds), Set(points.map(\.id)))
            // Picking the stadium in the review finds the match from the photos' date (the phone's day, Chicago).
            let found = await GameLookup.gameNear(day.day, at: try XCTUnwrap(library.venue("lumen-field")))
            XCTAssertEqual(found.game?.eventId, "760462", title)
        }
    }

    /// Photos added to the album the evening after (the trip home), still one outing: the match is found.
    func testAlbumFromTheMorningMarchToTheNightStillFindsIt() async throws {
        let points = matchPhotos(shift: -5 * 3600) + matchPhotos(shift: 4 * 3600).map {
            PhotoPoint(id: "late-" + $0.id, date: $0.date, latitude: nil, longitude: nil)
        }
        let review = await findInPhotos(model(albums: [(album("BiH v Qatar", points), points)]))
        XCTAssertEqual(review.possible.first?.suggestions.first?.id, "lumen-field")
    }

    func testAlbumOnAnotherDayIsNotOffered() async {
        let points = matchPhotos(shift: -4 * 86_400)
        let review = await findInPhotos(model(albums: [(album("BiH v Qatar", points), points)]))
        XCTAssertTrue(review.possible.isEmpty)
    }

    func testTeamsThatDidNotPlayEachOtherAreNotOffered() async {
        let points = matchPhotos()
        for title in ["Brazil v Qatar", "Bosnia vs Canada", "Cubs vs Cardinals"] {
            let review = await findInPhotos(model(albums: [(album(title, points), points)]))
            XCTAssertTrue(review.possible.isEmpty, title)
        }
    }

    func testAnAlbumOfAnAppIsSkipped() async {
        let points = matchPhotos()
        let review = await findInPhotos(model(albums: [(album("WhatsApp BiH v Qatar", points), points)]))
        XCTAssertTrue(review.possible.isEmpty)
    }

    /// Once added, the match is not offered again; once skipped, it stays skipped.
    func testTheReviewLedgerHolds() async throws {
        let points = matchPhotos()
        let scan = model(albums: [(album("BiH v Qatar", points), points)])
        let first = await findInPhotos(scan)
        let day = try XCTUnwrap(first.possible.first)
        scan.dismiss(day.assetIds, on: day.day, asGame: true)
        let again = await findInPhotos(scan)
        XCTAssertTrue(again.possible.isEmpty)

        let fresh = model(albums: [(album("BiH v Qatar", points), points)])
        try? FileManager.default.removeItem(at: ledgerURL)
        var game = GameEntry(sport: .soccer, date: ISO8601DateFormatter().date(from: "2026-06-24T19:00:00Z")!, venueId: "lumen-field",
                             photos: [], origin: .photos)
        game.source = GameEntry.Source(provider: "espn", league: "soccer/fifa.world", eventId: "760462")
        library.add(game)
        let saved = await findInPhotos(fresh)
        XCTAssertTrue(saved.possible.isEmpty)
    }

    /// The scan check names the album, how its title was read, the game and the verdict.
    func testScanCheckReadsTheAlbum() async {
        let points = matchPhotos()
        let a = album("Bosnia vs Qatar", points)
        let parsed = MatchupAlbums.parse(a.title, teams: library.allTeams)
        let outcome = await MatchupAlbums.check(a, points: points, parsed: parsed, venues: library.venues, existing: [])
        let text = ScanCheck.albumLines(outcome, inDay: 40, venues: library.venues, offered: { _ in true },
                                        zone: TimeZone(identifier: "America/Chicago")!).joined(separator: "\n")
        XCTAssertTrue(text.contains("\u{201C}Bosnia vs Qatar\u{201D}: 40 photos, 40 of them from this day"), text)
        XCTAssertTrue(text.contains("\"bosnia\" \u{2192} Bosnia-Herzegovina (BIH, National teams)"), text)
        XCTAssertTrue(text.contains("Qatar at Bosnia-Herzegovina, Lumen Field, Jun 24 12:00 PDT (soccer/fifa.world 760462) \u{2192} offered"), text)
        XCTAssertTrue(text.contains("photos Jun 24 13:20"), text)

        let plain = await MatchupAlbums.check(album("Summer", points), points: points,
                                              parsed: MatchupAlbums.parse("Summer", teams: library.allTeams), venues: library.venues, existing: [])
        XCTAssertTrue(ScanCheck.albumLines(plain, inDay: 3, venues: library.venues, offered: { _ in true }).joined().contains("no \"v\""))
    }
}
