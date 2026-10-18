import XCTest
import UIKit
@testable import Witness

@MainActor
final class AlbumAndScoreboardTests: XCTestCase {
    private var library: Library!

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "album-\(UUID().uuidString).json"))
    }

    private func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    // MARK: Grouping

    func testAlbumGroupsVisitsAsksForTheRest() {
        let wrigley = library.venue("wrigley")!
        let points = [
            // Game night at Wrigley: two GPS photos, one copy with no location from the same evening.
            PhotoPoint(id: "a", date: date("2016-10-31T00:10:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude),
            PhotoPoint(id: "b", date: date("2016-10-31T03:40:00Z"), latitude: wrigley.latitude + 0.001, longitude: wrigley.longitude),
            PhotoPoint(id: "c", date: date("2016-10-31T02:00:00Z"), latitude: nil, longitude: nil),
            // Downtown the next day, nowhere near a stadium.
            PhotoPoint(id: "d", date: date("2016-11-01T18:00:00Z"), latitude: 41.8827, longitude: -87.6233),
            // A scan with no date at all.
            PhotoPoint(id: "e", date: nil, latitude: nil, longitude: nil),
        ]
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.count, 1)
        XCTAssertEqual(scan.visits.first?.venue.id, "wrigley")
        XCTAssertEqual(Set(scan.visits.first?.assetIds ?? []), ["a", "b", "c"], "Location-less photos from the visit's day join it")
        XCTAssertEqual(scan.unplacedDays.map(\.assetIds), [["d"]])
        XCTAssertEqual(scan.undated, ["e"])
    }

    /// A night game: photos at 22:30 local, then the walk home at 01:30 the next calendar day, are one visit.
    func testPhotosAcrossMidnightAreOneVisit() {
        let wrigley = library.venue("wrigley")!
        let points = [
            PhotoPoint(id: "late", date: date("2016-10-31T03:30:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude),
            PhotoPoint(id: "after", date: date("2016-10-31T06:30:00Z"), latitude: wrigley.latitude + 0.001, longitude: wrigley.longitude),
            // The next afternoon is another outing, not the same visit.
            PhotoPoint(id: "next", date: date("2016-11-01T15:30:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude),
        ]
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.count, 2)
        XCTAssertEqual(Set(scan.visits[0].assetIds), ["late", "after"])
        XCTAssertEqual(scan.visits[1].assetIds, ["next"])
    }

    /// Photos 6 to 12 hours apart across midnight are not joined on their own, but they are worth asking about.
    func testNineHourGapAsksInsteadOfJoining() {
        let wrigley = library.venue("wrigley")!
        func at(_ id: String, _ time: String) -> PhotoPoint {
            PhotoPoint(id: id, date: date(time), latitude: wrigley.latitude, longitude: wrigley.longitude)
        }
        // 22:00 local Oct 30, then 07:00 local Oct 31: nine hours apart.
        let scan = VisitGrouping.group([at("night", "2016-10-31T03:00:00Z"), at("morning", "2016-10-31T12:00:00Z")],
                                       venues: library.venues)
        XCTAssertEqual(scan.visits.count, 2, "Nine hours is too long to join without asking")
        let night = scan.visits[0], morning = scan.visits[1]
        XCTAssertEqual(VisitGrouping.possibleSameGame(as: night, in: [morning])?.id, morning.id)
        XCTAssertEqual(VisitGrouping.possibleSameGame(as: morning, in: [night])?.id, night.id)

        let one = night.combined(with: morning)
        XCTAssertEqual(one.id, night.id)
        XCTAssertEqual(one.assetIds, ["night", "morning"])
        XCTAssertNil(VisitGrouping.possibleSameGame(as: night, in: [night]), "A visit is never its own twin")
    }

    func testDuplicateGamesAreSpottedAndCombined() {
        let when = date("2026-06-24T19:00:00Z")
        let source = GameEntry.Source(provider: "espn", league: "soccer/fifa.world", eventId: "401")
        var a = GameEntry(sport: .soccer, date: when, venueId: "lumen-field", photos: [.library("p1"), .library("p2")], origin: .photos)
        a.source = source
        var b = GameEntry(sport: .soccer, date: when, venueId: "lumen-field", photos: [.library("p2"), .library("p3")], origin: .photos)
        b.source = source
        XCTAssertTrue(Library.sameGame(a, b))
        var other = b
        other.id = "other"
        other.source = GameEntry.Source(provider: "espn", league: "soccer/fifa.world", eventId: "402")
        XCTAssertFalse(Library.sameGame(a, other), "Different schedule events at one stadium are two games")

        library.add(a)
        library.add(b)
        XCTAssertEqual(library.games.filter { $0.venueId == "lumen-field" }.count, 1, "Photos for a game already saved join it")
        XCTAssertEqual(library.games.first { $0.venueId == "lumen-field" }?.photos.count, 3)
    }

    func testDiscoveryRuleSkipsDriveBys() {
        let wrigley = library.venue("wrigley")!
        let one = [PhotoPoint(id: "a", date: date("2016-10-31T00:10:00Z"), latitude: wrigley.latitude, longitude: wrigley.longitude)]
        XCTAssertTrue(VisitGrouping.group(one, venues: library.venues, minimumStay: 15 * 60).visits.isEmpty)
        XCTAssertEqual(VisitGrouping.group(one, venues: library.venues).visits.count, 1, "An album the fan chose is trusted")
    }

    /// A fan's matchday in Cardiff: the pub before (1.8 km away), the ground, a stadium tour in London another day.
    func testMatchdayPubJoinsTheGameAndTourStandsAlone() {
        let cardiff = library.venue("cardiff-city-stadium")!
        let bridge = library.venue("stamford-bridge")!
        let points = [
            PhotoPoint(id: "pub", date: date("2026-03-26T17:30:00Z"), latitude: 51.4810, longitude: -3.1790),
            PhotoPoint(id: "ground", date: date("2026-03-26T19:20:00Z"), latitude: cardiff.latitude + 0.0008, longitude: cardiff.longitude),
            PhotoPoint(id: "board", date: date("2026-03-26T21:40:00Z"), latitude: cardiff.latitude, longitude: cardiff.longitude + 0.001),
            PhotoPoint(id: "tour", date: date("2026-03-28T11:00:00Z"), latitude: bridge.latitude, longitude: bridge.longitude),
        ]
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.map(\.venue.id), ["cardiff-city-stadium", "stamford-bridge"])
        XCTAssertEqual(Set(scan.visits[0].assetIds), ["pub", "ground", "board"], "The pub is outside the 200 m fence but on the day")
        XCTAssertTrue(scan.unplacedDays.isEmpty)
        XCTAssertTrue(GameLookup.leagues(for: cardiff).contains("soccer/fifa.worldq.uefa"))
        XCTAssertTrue(GameLookup.leagues(for: library.venue("lumen-field")!).contains("soccer/fifa.world"))
    }

    func testTailgateWithin500mJoinsOnlyAnExistingVisit() {
        let wrigley = library.venue("wrigley")!
        let metersPerDegree = 111_000.0
        func point(_ id: String, _ time: String, north meters: Double) -> PhotoPoint {
            PhotoPoint(id: id, date: date(time), latitude: wrigley.latitude + meters / metersPerDegree, longitude: wrigley.longitude)
        }
        let game = [point("inside", "2016-10-31T00:30:00Z", north: 50), point("tailgate", "2016-10-30T20:00:00Z", north: 430),
                    point("walkout", "2016-10-31T04:10:00Z", north: 480)]
        let visit = VisitGrouping.group(game, venues: library.venues).visits
        XCTAssertEqual(visit.count, 1)
        XCTAssertEqual(Set(visit[0].assetIds), ["inside", "tailgate", "walkout"], "Within 500 m on the day counts")

        // The same pub crowd on a day with nothing inside the fence is not a visit.
        let partyOnly = [point("p1", "2016-11-05T20:00:00Z", north: 430), point("p2", "2016-11-05T23:00:00Z", north: 450)]
        let scan = VisitGrouping.group(partyOnly, venues: library.venues)
        XCTAssertTrue(scan.visits.isEmpty)
        XCTAssertEqual(scan.unplacedDays.count, 1)

        // Discovery's stay rule counts only the photos inside the fence.
        let walkBy = [point("in", "2016-10-31T00:30:00Z", north: 50), point("pub", "2016-10-30T20:00:00Z", north: 430)]
        XCTAssertTrue(VisitGrouping.group(walkBy, venues: library.venues, minimumStay: 15 * 60).visits.isEmpty)
    }

    func testOneTeamOnTheBoardBacksAKnownGame() {
        func side(_ code: String, _ name: String, _ score: Int) -> FoundGame.Side {
            .init(espnId: code, abbreviation: code, location: name, name: name, color: nil, altColor: nil, score: score, line: [])
        }
        let fire = FoundGame(league: "soccer/usa.1", leagueName: "MLS", eventId: "1", sport: .soccer, start: .now,
                             venueName: "Soldier Field", venueCity: "Chicago", home: side("CHI", "Chicago Fire FC", 2),
                             away: side("TOR", "Toronto FC", 2), completed: true, note: nil)
        let board = ScoreboardReader.reading(from: "0 TOR 0 20:33")
        XCTAssertEqual(ScoreboardReader.support(board, for: fire), 0)
        XCTAssertTrue(ScoreboardReader.confirms(board, fire))
        XCTAssertFalse(ScoreboardReader.confirms(ScoreboardReader.reading(from: "GALP PORTUGAL STORE"), fire))
    }

    func testIndexFindsTheSameVenueAsTheLinearSearch() {
        let index = VenueIndex(library.venues)
        // Every venue's own coordinates and points 150 / 450 m north of it.
        for v in library.venues {
            for meters in [0.0, 150, 450] {
                let lat = v.latitude + meters / 111_000
                XCTAssertEqual(index.nearest(lat: lat, lon: v.longitude)?.id,
                               VisitGrouping.nearestVenue(lat: lat, lon: v.longitude, in: library.venues)?.id, v.id)
                XCTAssertEqual(index.nearest(lat: lat, lon: v.longitude, radius: 500)?.id,
                               VisitGrouping.nearestVenue(lat: lat, lon: v.longitude, in: library.venues, radius: 500)?.id, v.id)
            }
        }
    }

    func testGroupingAFiftyThousandPhotoLibraryIsFast() {
        let wrigley = library.venue("wrigley")!
        let base = date("2019-01-01T12:00:00Z")
        var points: [PhotoPoint] = []
        for i in 0..<50_000 {
            let located = i % 3 != 0
            points.append(PhotoPoint(id: "p\(i)", date: base.addingTimeInterval(Double(i) * 3_000),
                                     latitude: located ? 40.0 + Double(i % 500) * 0.01 : nil,
                                     longitude: located ? -100.0 + Double(i % 700) * 0.01 : nil))
        }
        // Three real game nights hidden in it.
        for day in 0..<3 {
            for n in 0..<4 {
                points.append(PhotoPoint(id: "g\(day)-\(n)", date: base.addingTimeInterval(Double(day) * 86_400 * 40 + Double(n) * 1_800),
                                         latitude: wrigley.latitude, longitude: wrigley.longitude))
            }
        }
        let start = Date()
        let scan = VisitGrouping.group(points, venues: library.venues, minimumStay: 15 * 60)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(scan.visits.count, 3)
        XCTAssertLessThan(elapsed, 5, "Grouping 50k photos took \(elapsed)s")
    }

    func testLiveCheckInOrdersTheGamesAtYourStadium() {
        func game(_ id: String, start: String, done: Bool) -> FoundGame {
            let side = FoundGame.Side(espnId: id, abbreviation: id, location: id, name: id, color: nil, altColor: nil, score: nil, line: [])
            return FoundGame(league: "basketball/nba", leagueName: "NBA", eventId: id, sport: .basketball, start: date(start),
                             venueName: "United Center", venueCity: "Chicago", home: side, away: side, completed: done, note: nil)
        }
        let now = date("2025-11-01T01:00:00Z")
        let earlier = game("done", start: "2025-10-31T20:00:00Z", done: true)
        let live = game("live", start: "2025-11-01T00:30:00Z", done: false)
        let soon = game("soon", start: "2025-11-01T03:00:00Z", done: false)
        XCTAssertEqual(LiveGames.ordered([earlier, soon, live], now: now).map(\.eventId), ["live", "soon", "done"])
        XCTAssertEqual(LiveGames.status(live, now: now), "Live")
        XCTAssertEqual(LiveGames.status(earlier, now: now), "Final")
        XCTAssertTrue(LiveGames.status(soon, now: now).hasPrefix("Starts"))
    }

    func testCoverScoringPrefersGoodGamePhotosOverScreenshots() {
        let stadium = CoverPicker.score(aesthetics: 0.4, utility: false, sports: 0.8)
        let plainer = CoverPicker.score(aesthetics: 0.4, utility: false, sports: 0.1)
        let ticket = CoverPicker.score(aesthetics: 0.6, utility: true, sports: 0.0)
        let noModel = CoverPicker.score(aesthetics: nil, utility: false, sports: 0.8)
        XCTAssertGreaterThan(stadium, plainer)
        XCTAssertGreaterThan(plainer, ticket, "A screenshot never heads a game")
        XCTAssertGreaterThan(noModel, plainer, "Without the aesthetics model the scene signal still ranks")
    }

    func testFansCoverChoiceIsNeverReplaced() async {
        var game = GameEntry(sport: .baseball, date: .now, venueId: "wrigley", origin: .manual)
        game.photos = [.bundled("a"), .bundled("b"), .bundled("c")]
        library.add(game)
        XCTAssertEqual(library.game(game.id)?.heroPhoto, .bundled("a"), "No cover yet: the first photo")
        library.setCover(game.id, to: .bundled("c"), byFan: true)
        await library.autoCover(game.id, force: true)
        XCTAssertEqual(library.game(game.id)?.heroPhoto, .bundled("c"))
        XCTAssertEqual(library.game(game.id)?.coverChosenByFan, true)
        library.setCover(game.id, to: nil, byFan: true)
        XCTAssertEqual(library.game(game.id)?.heroPhoto, .bundled("a"), "Clearing goes back to the first photo")
    }

    func testWorldCupGameIsFoundAtAFootballStadium() throws {
        let library = self.library!
        let levis = try XCTUnwrap(library.venues.first { $0.id == "levis-stadium" })
        XCTAssertTrue(GameLookup.leagues(for: levis).contains("soccer/fifa.world"), "NFL bowls host World Cup games")
        let side = FoundGame.Side(espnId: "1", abbreviation: "USA", location: "United States", name: "", color: nil, altColor: nil, score: nil, line: [])
        let other = FoundGame.Side(espnId: "2", abbreviation: "BIH", location: "Bosnia and Herzegovina", name: "", color: nil, altColor: nil, score: nil, line: [])
        let game = FoundGame(league: "soccer/fifa.world", leagueName: "FIFA World Cup", eventId: "1", sport: .soccer, start: Date(),
                             venueName: "San Francisco Bay Area Stadium", venueCity: "Santa Clara", home: side, away: other, completed: true, note: nil)
        XCTAssertTrue(GameLookup.venueMatches(game, venue: levis), "Tournament ground names differ; the city is enough")
    }

    func testHomeNearAStadiumIsNotAGame() {
        // Photos from a kid's room and a document, taken the morning of a real game: nothing sports-like.
        let home = SceneCheck.score([("indoor", 0.9), ("bedroom", 0.8), ("document", 0.6)])
        XCTAssertLessThan(home.sports, 0.2, "A bedroom is not a game")
        XCTAssertLessThan(home.event, 0.25)
        // A seat's-eye view of an arena reads as both a game and an event.
        let arena = SceneCheck.score([("stadium", 0.7), ("crowd", 0.5)])
        XCTAssertGreaterThanOrEqual(arena.sports, 0.2)
        XCTAssertGreaterThanOrEqual(arena.event, 0.25)
        // A concert is an event without being a game.
        let concert = SceneCheck.score([("concert", 0.6), ("stage", 0.5)])
        XCTAssertLessThan(concert.sports, 0.15)
        XCTAssertGreaterThanOrEqual(concert.event, 0.25)
    }

    func testPacedNumbersNeverPassTheRealOnesAndAlwaysArrive() {
        var shown = 0
        var ticks = 0
        while shown < 16_274 && ticks < 400 {
            let next = ScanPacing.approach(shown, 16_274)
            XCTAssertGreaterThan(next, shown)
            XCTAssertLessThanOrEqual(next, 16_274)
            shown = next
            ticks += 1
        }
        XCTAssertEqual(shown, 16_274)
        XCTAssertLessThanOrEqual(ticks, 100, "About four seconds at 25 ticks a second, at most")
        XCTAssertEqual(ScanPacing.approach(5, 3), 3, "Never shows more than the real number")
    }

    // MARK: Scoreboards

    func testCrestBoardConfirmsByScoreAlone() {
        func side(_ code: String, _ name: String, _ score: Int) -> FoundGame.Side {
            .init(espnId: code, abbreviation: code, location: name, name: name, color: nil, altColor: nil, score: score, line: [])
        }
        let wal = FoundGame(league: "soccer/fifa.worldq.uefa", leagueName: "FIFA World Cup Qualifying - UEFA", eventId: "1",
                            sport: .soccer, start: .now, venueName: "Cardiff City Stadium", venueCity: "Cardiff",
                            home: side("WAL", "Wales", 1), away: side("BIH", "Bosnia-Herzegovina", 1),
                            completed: true, note: nil)
        let crests = ScoreboardReader.reading(from: "1 - 1\nCROESO")
        XCTAssertEqual(ScoreboardReader.support(crests, for: wal), 0, "No team names on a crest board")
        XCTAssertTrue(ScoreboardReader.confirms(crests, wal))
        XCTAssertFalse(ScoreboardReader.confirms(ScoreboardReader.reading(from: "2 - 0"), wal))
        XCTAssertFalse(ScoreboardReader.confirms(ScoreboardReader.reading(from: "GATE 1 1 ROW 12 SEAT 4 5 6 7"), wal),
                       "Too many numbers to trust a bare pair")
    }

    private func game(home: (String, String, Int), away: (String, String, Int)) -> FoundGame {
        func side(_ t: (String, String, Int)) -> FoundGame.Side {
            .init(espnId: t.0, abbreviation: t.0, location: t.1, name: t.1, color: nil, altColor: nil, score: t.2, line: [])
        }
        return FoundGame(league: "hockey/nhl", leagueName: "NHL", eventId: "1", sport: .hockey, start: .now,
                         venueName: "United Center", venueCity: "Chicago", home: side(home), away: side(away),
                         completed: true, note: "Stanley Cup Final - Game 6")
    }

    func testReadingTokensAndScoreSupport() {
        let scf = game(home: ("CHI", "Chicago", 2), away: ("TB", "Tampa Bay", 0))
        let finalBoard = ScoreboardReader.reading(from: "FINAL\nTB 0\nCHI 2\n3RD 00:00")
        XCTAssertEqual(ScoreboardReader.support(finalBoard, for: scf), 2, "Teams and final score on the board")
        let midGame = ScoreboardReader.reading(from: "TB0 CHI1 2ND")
        XCTAssertEqual(ScoreboardReader.support(midGame, for: scf), 1, "Mid-game score still fits")
        let wrong = ScoreboardReader.reading(from: "NYR 4 BOS 1")
        XCTAssertEqual(ScoreboardReader.support(wrong, for: scf), 0)
    }

    /// The real path: draw a scoreboard, read it with Vision, check it against the game.
    func testVisionReadsARenderedScoreboard() async throws {
        let size = CGSize(width: 900, height: 420)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.05, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 96, weight: .heavy),
                                                        .foregroundColor: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)]
            ("TB   0" as NSString).draw(at: CGPoint(x: 60, y: 40), withAttributes: attrs)
            ("CHI  2" as NSString).draw(at: CGPoint(x: 60, y: 170), withAttributes: attrs)
            ("FINAL" as NSString).draw(at: CGPoint(x: 560, y: 300),
                                       withAttributes: [.font: UIFont.systemFont(ofSize: 54, weight: .bold), .foregroundColor: UIColor.white])
        }
        let text = try await TextRecognizer.text(in: image)
        let reading = ScoreboardReader.reading(from: text)
        XCTAssertEqual(ScoreboardReader.support(reading, for: game(home: ("CHI", "Chicago", 2), away: ("TB", "Tampa Bay", 0))), 2,
                       "Vision read: \(text)")
    }
}
