import XCTest
@testable import Witness

/// The competition catalog (Catalog/competitions.json) is read by the app: national sides of any sport merge into one team per
/// country and gender, album titles name them, and a schedule pack keyed by the competition id is found by the lookups.
@MainActor
final class CompetitionCatalogTests: XCTestCase {
    private var library: Library!
    private let catalog = CompetitionCatalog.shared

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "cc-\(UUID().uuidString).json"))
        GameLookup.responder = { _ in nil }
    }

    override func tearDown() async throws {
        GameLookup.responder = nil
        LocalSchedule.testPacks = nil
    }

    private func side(_ code: String, _ name: String, id: String? = nil) -> FoundGame.Side {
        FoundGame.Side(espnId: id ?? code, abbreviation: code, location: name, name: name, color: nil, altColor: nil, score: nil, line: [])
    }

    private func game(_ league: String, sport: Sport, _ home: FoundGame.Side, _ away: FoundGame.Side) -> FoundGame {
        FoundGame(league: league, leagueName: league, eventId: "1", sport: sport, start: .now, venueName: "Hall", venueCity: nil,
                  home: home, away: away, completed: false, note: nil)
    }

    private func known(_ side: FoundGame.Side, league: String, sport: Sport) -> Team {
        library.addTeam(GameLookup.team(from: side, game: game(league, sport: sport, side, side)))
    }

    // MARK: The catalog

    func testCompetitionsByIdAliasAndTeam() throws {
        let worldCup = try XCTUnwrap(catalog.competition("basketball/fiba.worldcup"))
        XCTAssertTrue(worldCup.isNational)
        XCTAssertEqual(worldCup.nextEdition?.year, 2027)
        XCTAssertEqual(worldCup.nextLine, "Aug 27 \u{2013} Sep 12, 2027 \u{00B7} Qatar")
        XCTAssertEqual(catalog.competition(named: "FIBA World Cup", sport: .basketball, gender: "men")?.id, "basketball/fiba.worldcup")
        XCTAssertEqual(catalog.competition(named: "EuroBasket", sport: .basketball, gender: "men")?.id, "basketball/fiba.eurobasket")
        XCTAssertEqual(catalog.competition("basketball/fiba")?.id, "basketball/fiba.worldcup.w", "ESPN's path finds the women's World Cup")

        let plays = catalog.competitions(forTeam: "fibam-bih").map(\.id)
        XCTAssertTrue(plays.contains("basketball/fiba.worldcup"), "\(plays)")
        XCTAssertTrue(plays.contains("basketball/fiba.worldcupq"))
        XCTAssertTrue(plays.contains("basketball/fiba.eurobasket"))
        XCTAssertFalse(plays.contains("basketball/fiba.eurobasket.w"), "Women's tournaments list the women's side")
        XCTAssertTrue(catalog.competitions(forTeam: "fibaw-bih").map(\.id).contains("basketball/fiba.eurobasket.w"))
        XCTAssertTrue(catalog.teams(in: "basketball/fiba.worldcupq", library: library).contains { $0.id == "fibam-qat" })
        XCTAssertFalse(catalog.isNational("basketball/euroleague"))
        XCTAssertTrue(catalog.isNational("soccer/fifa.friendly"), "The friendlies the lookup always asked about are in the catalog now")
        XCTAssertTrue(Set(GameLookup.nationalCompetitions).isSuperset(of: ["soccer/fifa.world", "soccer/uefa.nations", "soccer/caf.nations_qual"]))
        XCTAssertFalse(GameLookup.nationalCompetitions.contains("soccer/fifa.wwc"), "The men's list has no women's tournament")
    }

    // MARK: One team per country, any sport

    func testFibaSideWithAnotherSpellingIsTheCatalogTeam() {
        let bosnia = side("BIH", "Bosnia and Herzegovina")
        for league in ["basketball/fiba.worldcupq", "basketball/fiba.eurobasket", "basketball/fiba.eurobasketq", "basketball/fiba.worldcup"] {
            XCTAssertEqual(known(bosnia, league: league, sport: .basketball).id, "fibam-bih", league)
        }
        XCTAssertEqual(known(bosnia, league: "basketball/fiba.eurobasket.w", sport: .basketball).id, "fibaw-bih", "Women's Bosnia is its own team")
        XCTAssertEqual(known(bosnia, league: "basketball/fiba.worldcup.w", sport: .basketball).id, "fibaw-bih")
        XCTAssertTrue(library.customTeams.isEmpty, "\(library.customTeams.map(\.id))")
        XCTAssertEqual(library.teams(for: .basketball).filter { $0.abbreviation == "BIH" && $0.league == "FIBA national teams (men)" }.count, 1)
        XCTAssertEqual(library.teams(for: .basketball).filter { $0.abbreviation == "BIH" && $0.league == "FIBA national teams (women)" }.count, 1)
        // Hockey and handball sides too, in their own sport.
        XCTAssertEqual(known(side("FIN", "Finland"), league: "hockey/iihf.worlds", sport: .hockey).id, "iihf-fin")
        XCTAssertEqual(known(side("FIN", "Finland"), league: "hockey/iihf.worlds.w", sport: .hockey).id, "iihfw-fin")
        XCTAssertEqual(known(side("DEN", "Denmark"), league: "handball/ihf.worldchamp", sport: .handball).id, "ehfn-den")
        XCTAssertTrue(library.customTeams.isEmpty)
    }

    func testClubsAndOtherSportsWithACountryCodeAreNotMerged() {
        let colors = Team.Colors(primary: "3A4150", secondary: "3A4150", accent: "3A4150")
        let club = Team(id: "espn-basketball-esp.acb-77", sport: .basketball, league: "Liga ACB", abbreviation: "BIH", locationName: "Bilbao",
                        teamName: "Surne Bilbao", monogram: "B", colors: colors, externalIds: .init(espn: "77", espnLeague: "basketball/esp.acb"),
                        leagueKey: "basketball/esp.acb")
        XCTAssertEqual(library.addTeam(club).id, club.id)
        // A basketball team from a soccer national competition is not a basketball country.
        let wrongSport = Team(id: "x-1", sport: .basketball, league: "FIFA World Cup", abbreviation: "QAT", locationName: "Qatar Hoops", teamName: "Hoops",
                              monogram: "Q", colors: colors, externalIds: .init(espn: "x1", espnLeague: "soccer/fifa.world"), leagueKey: "soccer/fifa.world")
        XCTAssertEqual(library.addTeam(wrongSport).id, "x-1")
    }

    func testWomensSoccerSideFromAnotherCompetitionFoldsByEspnId() throws {
        let women = try XCTUnwrap(library.allTeams.first { $0.league == "Women's national teams" && $0.externalIds?.espn != nil })
        let feed = side(women.abbreviation, women.locationName + " W", id: women.externalIds!.espn!)
        XCTAssertEqual(known(feed, league: "soccer/uefa.weuro", sport: .soccer).id, women.id,
                       "One women's side across the Women's World Cup, Euro and friendlies")
        XCTAssertTrue(library.customTeams.isEmpty)
    }

    func testDuplicateFibaTeamsFoldOnLoad() throws {
        let colors = Team.Colors(primary: "112855", secondary: "FFFFFF", accent: "FFFFFF")
        let dup = Team(id: "espn-basketball-fiba.worldcupq-BIH", sport: .basketball, league: "basketball/fiba.worldcupq", abbreviation: "BIH",
                       locationName: "BIH", teamName: "BIH", monogram: "B", colors: colors,
                       externalIds: .init(espn: "BIH", espnLeague: "basketball/fiba.worldcupq"), leagueKey: "basketball/fiba.worldcupq")
        let url = FileManager.default.temporaryDirectory.appending(path: "cc-fold-\(UUID().uuidString).json")
        let game = GameEntry(sport: .basketball, date: .now, venueId: "tbilisi-sports-palace", homeTeamId: dup.id, awayTeamId: "fibam-qat", origin: .manual)
        try Library.encoder.encode(Library.Stored(games: [game], customVenues: [], customPeople: [], customTeams: [dup],
                                                  favoriteTeamIds: [dup.id], plans: [])).write(to: url)
        let loaded = Library(storeURL: url)
        XCTAssertTrue(loaded.customTeams.isEmpty)
        XCTAssertEqual(loaded.game(game.id)?.homeTeamId, "fibam-bih")
        XCTAssertEqual(loaded.profile.favoriteTeamIds, ["fibam-bih"])
    }

    // MARK: Album titles

    func testBosniaVQatarResolvesForBasketballNationalTeams() throws {
        let teams = library.teams(for: .basketball)
        let parsed = MatchupAlbums.parse("Bosnia v Qatar", teams: teams)
        XCTAssertTrue(parsed.isMatchup)
        XCTAssertTrue(parsed.home.contains { $0.id == "fibam-bih" }, "\(parsed.home.map(\.id))")
        XCTAssertEqual(parsed.away.first?.id, "fibam-qat")
        XCTAssertTrue(MatchupAlbums.parse("BiH vs Qatar 2026", teams: teams).home.contains { $0.id == "fibam-bih" })
        XCTAssertTrue(MatchupAlbums.parse("Bosnia-Herzegovina v Qatar", teams: teams).isMatchup)
        // The competitions a team asks are its catalog tournaments.
        let leagues = MatchupAlbums.leagues(for: try XCTUnwrap(library.team("fibam-bih")))
        XCTAssertTrue(leagues.contains("basketball/fiba.worldcupq") && leagues.contains("basketball/fiba.worldcup"), "\(leagues)")
        XCTAssertFalse(leagues.contains("basketball/fiba.eurobasket.w"))
        XCTAssertTrue(MatchupAlbums.leagues(for: try XCTUnwrap(library.team("fibaw-bih"))).contains("basketball/fiba.eurobasket.w"))
        // Soccer is unchanged: every men's competition the team plays in, none of the women's.
        let soccer = MatchupAlbums.leagues(for: try XCTUnwrap(library.team("nat-452")))
        XCTAssertTrue(soccer.contains("soccer/fifa.world") && soccer.contains("soccer/uefa.nations") && soccer.contains("soccer/fifa.friendly"), "\(soccer)")
        XCTAssertFalse(soccer.contains("soccer/fifa.wwc"))
    }

    // MARK: A schedule pack keyed by the competition id

    private static let pack = """
    {"league":"basketball/fiba.worldcupq","season":2026,"teams":{"1":"BIH","2":"QAT","3":"GER"},
     "venues":{"9":["Tbilisi Sports Palace","Tbilisi","","GE"]},
     "games":[["q1","2026-11-26T17:00Z","1","2",null,null,"9","S","Window 5"],
              ["q2","2026-11-29T17:00Z","3","1",null,null,"9","S","Window 5"]]}
    """

    func testFixturePackGamesAreFoundByTheLookupsAndAlbumTitles() async throws {
        LocalSchedule.testPacks = [try JSONDecoder().decode(SchedulePack.self, from: Data(Self.pack.utf8))]
        let venue = try XCTUnwrap(library.venue("tbilisi-sports-palace"))
        XCTAssertTrue(venue.leagues?.contains("basketball/fiba.worldcupq") == true)
        XCTAssertTrue(CompetitionCatalog.shared.isPackOnly("basketball/fiba.worldcupq"))

        // The venue lookup: the key routes to the pack, no ESPN request is made for it.
        GameLookup.responder = { url in
            XCTAssertFalse(url.absoluteString.contains("fiba.worldcupq"), "No ESPN request for a pack-only competition: \(url)")
            return nil
        }
        let day = ISO8601DateFormatter().date(from: "2026-11-26T12:00:00Z")!
        let found = await GameLookup.gamesChecked(at: venue, from: day, to: day.addingTimeInterval(10 * 3600))
        XCTAssertTrue(found.complete)
        XCTAssertEqual(found.games.filter { $0.league == "basketball/fiba.worldcupq" }.map(\.eventId), ["q1"])
        let first = try XCTUnwrap(found.games.first { $0.eventId == "q1" })
        XCTAssertEqual(first.sport, .basketball)
        XCTAssertEqual(first.home.abbreviation, "BIH")
        // Saving it names the catalog teams, not new ones.
        var entry = GameEntry(sport: .basketball, date: first.start, venueId: venue.id, origin: .photos)
        GameLookup.apply(first, detail: nil, to: &entry, library: library)
        XCTAssertEqual(entry.homeTeamId, "fibam-bih")
        XCTAssertEqual(entry.awayTeamId, "fibam-qat")
        XCTAssertTrue(library.customTeams.isEmpty)

        // The album title: "Bosnia v Qatar" finds the same game at any ground, and "Qatar v Germany" does not.
        let parsed = MatchupAlbums.parse("Bosnia v Qatar", teams: library.teams(for: .basketball))
        let games = await MatchupAlbums.games(between: parsed.home, and: parsed.away, from: day.addingTimeInterval(-6 * 3600),
                                              to: day.addingTimeInterval(30 * 3600), around: day)
        XCTAssertEqual(games.map(\.eventId), ["q1"])
        let other = MatchupAlbums.parse("Qatar v Germany", teams: library.teams(for: .basketball))
        let none = await MatchupAlbums.games(between: other.home, and: other.away, from: day.addingTimeInterval(-6 * 3600),
                                             to: day.addingTimeInterval(30 * 3600), around: day)
        XCTAssertTrue(none.isEmpty)

        // The team page: coming games from the pack.
        let coming = await LocalSchedule.upcoming(for: try XCTUnwrap(library.team("fibam-bih")), now: day.addingTimeInterval(-86_400))
        XCTAssertEqual(coming.map(\.eventId), ["q1", "q2"])
    }

    func testWithoutAPackThereIsNoGameAndNoNetworkForIt() async throws {
        LocalSchedule.testPacks = []
        GameLookup.responder = { url in
            XCTAssertFalse(url.absoluteString.contains("fiba.worldcupq"), "\(url)")
            return nil
        }
        let venue = try XCTUnwrap(library.venue("tbilisi-sports-palace"))
        let day = ISO8601DateFormatter().date(from: "2026-11-26T12:00:00Z")!
        let found = await GameLookup.gamesChecked(at: venue, from: day, to: day.addingTimeInterval(10 * 3600))
        XCTAssertTrue(found.games.isEmpty)
    }

    // MARK: Picker

    func testBasketballCountriesSplitByZone() throws {
        let men = library.allTeams.filter { $0.league == "FIBA national teams (men)" }
        let zones = try XCTUnwrap(catalog.zones(for: men))
        XCTAssertEqual(Set(zones.map(\.title)), ["FIBA Europe", "FIBA Asia", "FIBA Americas", "FIBA Africa"])
        XCTAssertEqual(zones.map(\.teams.count).reduce(0, +), men.count)
        XCTAssertNil(catalog.zones(for: library.allTeams.filter { $0.league == "National teams" }), "Soccer's 217 sides are not split")
    }
}
