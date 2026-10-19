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

    func testCountriesAreInTheTeamPicker() throws {
        let usa = try XCTUnwrap(library.allTeams.first { $0.sport == .soccer && $0.abbreviation == "USA" })
        XCTAssertEqual(usa.locationName, "United States")
        XCTAssertNotNil(library.allTeams.first { $0.abbreviation == "BIH" }, "Bosnia is a pickable team")
        XCTAssertGreaterThan(library.allTeams.filter { $0.league == "National teams" }.count, 100)
        let again = library.addTeam(Team(id: "x", sport: .soccer, league: "FIFA World Cup", abbreviation: "USA", locationName: "United States",
                                         teamName: "United States", monogram: "US", colors: usa.colors, externalIds: .init(espn: "660", espnLeague: "soccer/uefa.euro")))
        XCTAssertEqual(again.id, usa.id, "A found game reuses the catalog country")
    }

    func testF1RaceWeekendIsFoundAtTheCircuit() async throws {
        let monaco = try XCTUnwrap(library.venue("monaco"))
        let race = try XCTUnwrap(F1Calendar.races.first { $0.id == "2024-monaco" })
        XCTAssertEqual(race.results?.winner?.code, "LEC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = monaco.tz
        let friday = try XCTUnwrap(cal.date(from: DateComponents(year: 2024, month: 5, day: 24, hour: 14)))
        let sunday = try XCTUnwrap(cal.date(from: DateComponents(year: 2024, month: 5, day: 26, hour: 15)))
        let found = await GameLookup.games(at: monaco, from: sunday, to: sunday.addingTimeInterval(3600))
        XCTAssertEqual(found.first?.race?.id, "2024-monaco")
        var entry = GameEntry(sport: .motorsport, date: sunday, venueId: monaco.id, origin: .manual)
        GameLookup.apply(try XCTUnwrap(found.first), detail: nil, to: &entry, library: library)
        XCTAssertEqual(entry.competition, "2024 Monaco Grand Prix")
        XCTAssertTrue(entry.podium.first?.hasPrefix("P1 LEC") == true, "\(entry.podium)")
        XCTAssertEqual(entry.source?.league, "racing/f1")

        // Friday and Sunday photos are one race weekend.
        let a = PhotoCluster(id: "fri", venue: monaco, start: friday, end: friday.addingTimeInterval(1800), assetIds: ["a"], times: [friday])
        let b = PhotoCluster(id: "sun", venue: monaco, start: sunday, end: sunday.addingTimeInterval(1800), assetIds: ["b"], times: [sunday])
        var matched: [String: FoundGame] = [:]
        for c in [a, b] { matched[c.id] = await GameLookup.games(at: monaco, from: c.start, to: c.end).first }
        let merged = ScanModel.mergeRaceWeekends([a, b], matched: &matched)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.assetIds.sorted(), ["a", "b"])
        XCTAssertEqual(matched.count, 1)
    }

    func testCatalogHasEveryResearchedTeamAndVenue() throws {
        XCTAssertGreaterThan(library.allTeams.count, 4_000)
        XCTAssertGreaterThan(library.venues.count, 3_000)
        for name in ["Real Madrid", "Hajduk Split", "Partizan"] {
            XCTAssertTrue(library.allTeams.contains { $0.teamName.contains(name) }, "\(name) is in the picker")
        }
        XCTAssertEqual(library.venue("monza")?.geofence, 1200, "A circuit's grandstands are inside its geofence")
        XCTAssertEqual(library.venue("cota")?.sports.contains(.motorsport), true)
        // The current franchise wins the ESPN lookup over a relocated one's old record.
        XCTAssertEqual(library.catalogTeam(league: "football/nfl", espnId: "13")?.id, "nfl-lv")
    }

    func testVenueSearchFindsLevisHoweverItIsTyped() {
        for q in ["levi", "levis", "Levi's", "levi stadium", "santa clara stadium", "49ers"] {
            XCTAssertTrue(library.searchVenues(q, sport: .soccer).prefix(5).contains { $0.id == "levis-stadium" }, "\(q) finds Levi's")
        }
        XCTAssertTrue(library.venues(for: .soccer).contains { $0.id == "levis-stadium" }, "World Cup grounds are on the soccer list")
        XCTAssertFalse(library.venues(for: .baseball).contains { $0.id == "levis-stadium" })
    }

    func testUnitedCenterIsNotCambrianUnitedGround() throws {
        let side = FoundGame.Side(espnId: "1", abbreviation: "CHI", location: "Chicago", name: "Bulls", color: nil, altColor: nil, score: nil, line: [])
        let game = FoundGame(league: "basketball/nba", leagueName: "NBA", eventId: "1", sport: .basketball, start: Date(),
                             venueName: "United Center", venueCity: "Chicago, Illinois", home: side, away: side, completed: true, note: nil)
        let welsh = try XCTUnwrap(library.venue("cambrian-united-ground"))
        XCTAssertFalse(GameLookup.venueMatches(game, venue: welsh), "A partial name in another country is not a match")
        XCTAssertEqual(GameLookup.venue(of: game, in: library.venues)?.id, "united-center")
    }

    func testAuditMovesAnNbaGameOffAWelshFootballGround() async throws {
        var game = GameEntry(sport: .basketball, date: Date(), venueId: "cambrian-united-ground", origin: .manual)
        game.homeTeamId = "nba-chi"
        game.awayTeamId = "nba-bos"
        library.add(game)
        await library.auditVenues()
        XCTAssertEqual(library.game(game.id)?.venueId, "united-center", "A home team's own arena replaces a ground that cannot host the sport")
    }

    func testUEFANationsLeagueMatchIsParsed() throws {
        let json = """
        [{"id":"2047929","status":"UPCOMING","kickOffTime":{"date":"2026-11-17","dateTime":"2026-11-17T19:45:00Z","utcOffsetInHours":1},
          "homeTeam":{"teamCode":"BIH","internationalName":"Bosnia and Herzegovina","countryCode":"BIH"},
          "awayTeam":{"teamCode":"ROU","internationalName":"Romania","countryCode":"ROU"},
          "stadium":{"capacity":13000,"countryCode":"BIH","geolocation":{"latitude":44.2,"longitude":17.9},
                     "translations":{"name":{"EN":"Stadion Bilino Polje"}},"city":{"translations":{"name":{"EN":"Zenica"}}}},
          "group":{"league":{"metaData":{"leagueName":"League B"}},"metaData":{"groupName":"Group B2"}},
          "matchday":{"longName":"Matchday 6"},"round":{"metaData":{"name":"League phase"}}}]
        """
        let list = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let game = try XCTUnwrap(UEFASchedule.parse(list).first)
        XCTAssertEqual(game.home.abbreviation, "BIH")
        XCTAssertEqual(game.away.abbreviation, "ROU")
        XCTAssertEqual(game.venueName, "Stadion Bilino Polje")
        XCTAssertEqual(game.venueCity, "Zenica")
        XCTAssertEqual(game.note, "League B \u{00B7} Group B2 \u{00B7} Matchday 6")
        XCTAssertEqual(game.start, ISO8601DateFormatter().date(from: "2026-11-17T19:45:00Z"))
        XCTAssertFalse(game.completed)
        XCTAssertEqual(game.venueLatitude, 44.2)
    }

    func testUEFANationalSideMapsToTheCatalogTeam() throws {
        let side = FoundGame.Side(espnId: "uefa-BIH", abbreviation: "BIH", location: "Bosnia and Herzegovina", name: "Bosnia and Herzegovina",
                                  color: nil, altColor: nil, score: nil, line: [])
        let game = FoundGame(league: "soccer/uefa.nations", leagueName: "UEFA Nations League", eventId: "uefa-1", sport: .soccer, start: Date(),
                             venueName: "Stadion Bilino Polje", venueCity: "Zenica", home: side, away: side, completed: false, note: nil)
        let made = GameLookup.team(from: side, game: game)
        let known = library.addTeam(made)
        XCTAssertEqual(known.league, "National teams", "The UEFA side is the catalog's national team, not a second Bosnia")
    }

    func testAnalyticsBucketsCountsAndNamesEvents() {
        XCTAssertEqual(Analytics.bucket(0), "0")
        XCTAssertEqual(Analytics.bucket(5), "1-5")
        XCTAssertEqual(Analytics.bucket(60), "51+")
        // The Worker accepts exactly these names, so a rename here must be made in analytics/worker.js too.
        XCTAssertEqual(AnalyticsEvent.planTeamSearch.rawValue, "plan_team_search")
        XCTAssertEqual(AnalyticsEvent.shareTapped.rawValue, "share_tapped")
    }

    func testLegalPagesExistAndNameTheAnalytics() {
        XCTAssertFalse(LegalContent.privacy.sections.isEmpty)
        XCTAssertFalse(LegalContent.terms.sections.isEmpty)
        let text = LegalContent.privacy.sections.flatMap(\.paragraphs).joined(separator: " ")
        XCTAssertTrue(text.contains("Share anonymous usage"), "The policy points to the switch that exists in You")
    }

    func testYourTeamsDecideWhoYouWereRootingFor() throws {
        let cubs = try XCTUnwrap(library.team("mlb-chc"))
        let brewers = try XCTUnwrap(library.team("mlb-mil"))
        var game = GameEntry(sport: .baseball, date: Date(), venueId: "wrigley", origin: .manual)
        game.homeTeamId = cubs.id
        game.awayTeamId = brewers.id
        library.add(game)
        XCTAssertEqual(library.rootingTeam(library.games[0]), cubs.id, "No teams chosen: the home side")
        library.addFavorite(brewers.id)
        XCTAssertEqual(library.rootingTeam(library.games[0]), brewers.id, "Your team wins over home")
        library.setRooting(library.games[0].id, to: cubs.id)
        XCTAssertEqual(library.rootingTeam(library.games[0]), cubs.id, "A choice on the game wins over your teams")
        library.removeFavorite(brewers.id)
        XCTAssertTrue(library.favoriteTeams.isEmpty)
    }

    func testRemovingPhotosFromAGame() throws {
        var game = GameEntry(sport: .baseball, date: Date(), venueId: "wrigley", origin: .manual)
        game.photos = [.library("a"), .library("b"), .library("c")]
        library.add(game)
        let id = library.games[0].id
        library.setCover(id, to: .library("b"), byFan: true)
        library.removePhotos(id, [.library("a"), .library("b")])
        let after = try XCTUnwrap(library.game(id))
        XCTAssertEqual(after.photos, [.library("c")])
        XCTAssertNil(after.coverPhoto, "Removing the cover clears it so another can be picked")
        XCTAssertNil(after.coverChosenByFan)
    }

    func testNeutralGroundStampWearsTheCountry() throws {
        let lumen = try XCTUnwrap(library.venue("lumen-field"))
        let bosnia = try XCTUnwrap(library.allTeams.first { $0.sport == .soccer && $0.abbreviation == "BIH" })
        XCTAssertFalse(PassportView.isTenant(bosnia, of: lumen), "Bosnia is not Lumen Field's team")
        XCTAssertEqual(PassportView.cityCode(lumen.city), "SEA", "A neutral ground wears its city")
        XCTAssertEqual(PassportView.cityCode("San Francisco"), "SF")
        XCTAssertEqual(PassportView.cityCode("Kansas City"), "KC")
        XCTAssertEqual(CountryCodes.iso3("US"), "USA", "Circuits wear the country")
        if let sounders = library.allTeams.first(where: { $0.abbreviation == "SEA" && $0.sport == .soccer }) {
            XCTAssertTrue(PassportView.isTenant(sounders, of: lumen), "A tenant keeps its own code")
        }
        let wrigley = try XCTUnwrap(library.venue("wrigley"))
        let cubs = try XCTUnwrap(library.team("mlb-chc"))
        XCTAssertTrue(PassportView.isTenant(cubs, of: wrigley))
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

    func testBackupRoundTripAndSpreadsheet() throws {
        let venue = try XCTUnwrap(library.venues.first)
        library.add(GameEntry(sport: .baseball, date: Date(timeIntervalSince1970: 1_700_000_000), venueId: venue.id,
                              homeScore: 3, awayScore: 2, note: "Rain, then \"extra\" innings", origin: .manual))
        let backup = try library.backupFile()
        let csv = try String(contentsOf: try library.csvFile(), encoding: .utf8)
        XCTAssertTrue(csv.hasPrefix("date,sport,kind,venue"))
        XCTAssertTrue(csv.contains("\"Rain, then \"\"extra\"\" innings\""), "Commas and quotes are escaped")

        let other = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "restore-\(UUID().uuidString).json"))
        XCTAssertEqual(try other.restore(from: backup), 1)
        XCTAssertEqual(try other.restore(from: backup), 0, "Restoring twice adds nothing")
        XCTAssertEqual(other.games.count, 1)
    }

    func testFormerTeamNamesAreSearchable() throws {
        let team = try XCTUnwrap(library.allTeams.first { $0.id == "nba-okc" })
        XCTAssertEqual(team.formerNames, ["Seattle SuperSonics"])
    }

    func testTemperatureAndDistanceUnits() {
        XCTAssertEqual(Fmt.temperature(54, fahrenheit: true), "54\u{00B0}F")
        XCTAssertEqual(Fmt.temperature(54, fahrenheit: false), "12\u{00B0}C")
        XCTAssertEqual(Fmt.temperature(32, fahrenheit: false), "0\u{00B0}C")
        XCTAssertEqual(Fmt.temperature(5, fahrenheit: false), "-15\u{00B0}C")
    }

    func testAlbumTitleNamesTheStadium() {
        let hit = GameSuggester.venues(named: "Cubs game with Dad", teams: library.allTeams, venues: library.venues) { self.library.venue($0) }
        XCTAssertTrue(hit.contains { $0.name == "Wrigley Field" }, "A team nickname points at its home ground: \(hit.map(\.name))")
        let byName = GameSuggester.venues(named: "Wrigley 2019", teams: library.allTeams, venues: library.venues) { self.library.venue($0) }
        XCTAssertTrue(byName.contains { $0.name == "Wrigley Field" }, "A stadium named outright: \(byName.map(\.name))")
        XCTAssertTrue(GameSuggester.venues(named: "Summer 2019", teams: library.allTeams, venues: library.venues) { self.library.venue($0) }.isEmpty)
    }

    func testPossibleDaysNeedPhotosAndSkipCoveredDays() {
        let day = { (id: String, n: Int) in DayPile(id: id, day: Date(), assetIds: (0..<n).map { "\($0)" }, times: (0..<n).map { _ in Date() }) }
        let kept = GameSuggester.candidates([day("2020-06-01", 5), day("2020-06-02", 2), day("2020-06-03", 4)], skipping: ["2020-06-03"])
        XCTAssertEqual(kept.map(\.id), ["2020-06-01"], "Too few photos and already-covered days are left out")
    }

    func testAppAndSystemAlbumsAreSkipped() {
        for title in ["Instagram", "WhatsApp", "Facebook", "Screenshots", "Saved from TikTok", "Google Photos"] {
            XCTAssertTrue(GameSuggester.isAppAlbum(title), title)
        }
        for title in ["Cubs game", "Wrigley 2019", "Chicago trip", "Lines of Defense"] {
            XCTAssertFalse(GameSuggester.isAppAlbum(title), title)
        }
    }

    func testACrowdAloneIsNotAVenue() {
        XCTAssertEqual(SceneCheck.venueSign([("crowd", 0.9), ("audience", 0.8), ("field", 0.7), ("team", 0.6)]), 0)
        XCTAssertGreaterThan(SceneCheck.venueSign([("crowd", 0.9), ("stadium", 0.4)]), 0.3)
        XCTAssertGreaterThan(SceneCheck.venueSign([("scoreboard", 0.5)]), 0.3)
    }

    func testOneStrayPitchIsNotAGameDay() {
        // A beach day: one photo the classifier calls a pitch, the rest sand and sea.
        XCTAssertFalse(SceneCheck.DayLook(classified: 9, venue: 1, elsewhere: 7).isGame())
        // Two pitch photos are still too few next to a day at the beach.
        XCTAssertFalse(SceneCheck.DayLook(classified: 9, venue: 2, elsewhere: 5).isGame())
        // A real game: most photos show the ground or the crowd in a stadium.
        XCTAssertTrue(SceneCheck.DayLook(classified: 12, venue: 7, elsewhere: 1).isGame())
        XCTAssertTrue(GameSuggester.isAppAlbum("Meta AI"))
    }

    func testIndoorOutdoorIsASecondOpinion() throws {
        let setting = SceneCheck.setting([("indoor_arena", 0.8), ("sky", 0.1)])
        XCTAssertGreaterThan(setting.indoor, 0.5)
        let arena = try XCTUnwrap(library.venues.first { $0.name == "United Center" })
        let ballpark = try XCTUnwrap(library.venues.first { $0.name == "Wrigley Field" })
        XCTAssertTrue(arena.isIndoor)
        XCTAssertFalse(ballpark.isIndoor)
        XCTAssertTrue(SceneVerdict(sports: 0.1, elsewhere: 0.3, indoor: 0.7, outdoor: 0).fits(arena))
        XCTAssertFalse(SceneVerdict(sports: 0.1, elsewhere: 0.3, indoor: 0.7, outdoor: 0).fits(ballpark))
    }
}
