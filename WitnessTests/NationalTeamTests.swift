import XCTest
@testable import Witness

/// A country is one team. ESPN keeps one id for it across the World Cup, its qualifying, the Euros, the Nations League and
/// friendlies, and the catalog lists it once (under the World Cup, "Bosnia-Herzegovina", nat-452); a qualifier's
/// "Bosnia and Herzegovina" must never become a second Bosnia in the picker.
@MainActor
final class NationalTeamTests: XCTestCase {
    private var url: URL!
    private var library: Library!

    override func setUp() async throws {
        url = FileManager.default.temporaryDirectory.appending(path: "national-\(UUID().uuidString).json")
        library = Library(storeURL: url)
    }

    private static let bosnia = FoundGame.Side(espnId: "452", abbreviation: "BIH", location: "Bosnia and Herzegovina", name: "Bosnia and Herzegovina",
                                               color: "112855", altColor: "FFFFFF", score: nil, line: [])

    private static func game(league: String, name: String, side: FoundGame.Side) -> FoundGame {
        FoundGame(league: league, leagueName: name, eventId: "1", sport: .soccer, start: .now, venueName: "Stadion Bilino Polje",
                  venueCity: "Zenica", home: side, away: side, completed: false, note: nil)
    }

    func testQualifierSideIsTheCatalogNationalTeam() {
        let competitions = [("soccer/fifa.worldq.uefa", "UEFA national teams"), ("soccer/fifa.worldq.uefa", "FIFA World Cup Qualifying - UEFA"),
                            ("soccer/uefa.euroq", "UEFA European Championship Qualifying"), ("soccer/fifa.friendly", "International Friendly"),
                            ("soccer/uefa.euro", "UEFA European Championship"), ("soccer/fifa.world", "FIFA World Cup")]
        for (league, name) in competitions {
            let known = library.addTeam(GameLookup.team(from: Self.bosnia, game: Self.game(league: league, name: name, side: Self.bosnia)))
            XCTAssertEqual(known.id, "nat-452", "\(league) (\(name))")
            XCTAssertEqual(known.locationName, "Bosnia-Herzegovina", "The catalog's name")
            XCTAssertEqual(known.colors.accent, "112855", "The catalog's colors, not the feed's")
        }
        // The UEFA feed has no ESPN ids: the FIFA code finds the country.
        let uefa = FoundGame.Side(espnId: "uefa-BIH", abbreviation: "BIH", location: "Bosnia and Herzegovina", name: "Bosnia and Herzegovina",
                                  color: nil, altColor: nil, score: nil, line: [])
        XCTAssertEqual(library.addTeam(GameLookup.team(from: uefa, game: Self.game(league: "soccer/uefa.nations", name: "UEFA Nations League", side: uefa))).id, "nat-452")
        XCTAssertTrue(library.customTeams.isEmpty, "No second Bosnia: \(library.customTeams.map(\.id))")
        // The women's side is its own team (ESPN gives it its own id, in "Women's national teams"); the men's picker list has one Bosnia.
        XCTAssertEqual(library.teams(for: .soccer).filter { $0.abbreviation == "BIH" && $0.league == "National teams" }.count, 1, "One Bosnia in the picker")
    }

    func testClubWithACountrysCodeIsNotMerged() {
        let colors = Team.Colors(primary: "3A4150", secondary: "3A4150", accent: "3A4150")
        // A soccer club coded BIH in its own league is not Bosnia.
        let club = Team(id: "espn-soccer-bih.1-99999", sport: .soccer, league: "Premijer Liga", abbreviation: "BIH", locationName: "Biha\u{107}",
                        teamName: "Jedinstvo", monogram: "J", colors: colors, externalIds: .init(espn: "99999", espnLeague: "soccer/bih.1"), leagueKey: "soccer/bih.1")
        XCTAssertEqual(library.addTeam(club).id, club.id)
        // ESPN ids are per sport: a hockey club with id 452 is not Bosnia either, whatever its code.
        let hockey = Team(id: "espn-hockey-nla-452", sport: .hockey, league: "National League", abbreviation: "BIH", locationName: "Biel",
                          teamName: "Bienne", monogram: "B", colors: colors, externalIds: .init(espn: "452", espnLeague: "hockey/nla"), leagueKey: "hockey/nla")
        XCTAssertEqual(library.addTeam(hockey).id, hockey.id)
        // A team the fan made by hand, with a country's code and no league key, is theirs.
        let own = Team(id: "custom-1", sport: .soccer, league: "Sunday league", abbreviation: "BIH", locationName: "Bosnia", teamName: "Bosnia",
                       monogram: "B", colors: colors, externalIds: nil)
        XCTAssertEqual(library.addTeam(own).id, own.id)
        XCTAssertEqual(library.customTeams.count, 3)
        XCTAssertEqual(Library(storeURL: url).customTeams.count, 3, "The load-time merge leaves them alone")
    }

    func testLoadFoldsADuplicateNationalTeamIntoTheCatalog() throws {
        // A library saved before the fix: the qualifier's Bosnia as a custom team, named by a game, a plan and the favorites.
        let dup = Team(id: "espn-soccer-fifa.worldq.uefa-452", sport: .soccer, league: "UEFA national teams", abbreviation: "BIH",
                       locationName: "Bosnia and Herzegovina", teamName: "Bosnia and Herzegovina", monogram: "B",
                       colors: .init(primary: "112855", secondary: "FFFFFF", accent: "FFFFFF"),
                       externalIds: .init(espn: "452", espnLeague: "soccer/fifa.worldq.uefa"), leagueKey: "soccer/fifa.worldq.uefa")
        var game = GameEntry(sport: .soccer, date: .now, venueId: "bilino-polje", homeTeamId: dup.id, awayTeamId: "nat-4245",
                             homeScore: 2, awayScore: 1, origin: .manual)
        game.rootingForTeamId = dup.id
        let plan = GameEntry(sport: .soccer, date: .now.addingTimeInterval(30 * 86_400), venueId: "bilino-polje", homeTeamId: "nat-4245",
                             awayTeamId: dup.id, origin: .manual)
        let stored = Library.Stored(games: [game], customVenues: [], customPeople: [], customTeams: [dup],
                                    favoriteTeamIds: [dup.id, "mlb-chc"], plans: [plan])
        try Library.encoder.encode(stored).write(to: url)

        let loaded = Library(storeURL: url)
        XCTAssertTrue(loaded.customTeams.isEmpty, "The duplicate is gone: \(loaded.customTeams.map(\.id))")
        let g = try XCTUnwrap(loaded.game(game.id))
        XCTAssertEqual(g.homeTeamId, "nat-452")
        XCTAssertEqual(g.awayTeamId, "nat-4245", "The other side is untouched")
        XCTAssertEqual(g.rootingForTeamId, "nat-452")
        XCTAssertEqual(loaded.outcome(g), .win)
        XCTAssertEqual(loaded.plan(plan.id)?.awayTeamId, "nat-452")
        XCTAssertEqual(loaded.profile.favoriteTeamIds, ["nat-452", "mlb-chc"])
        XCTAssertEqual(loaded.team(g.homeTeamId)?.locationName, "Bosnia-Herzegovina")

        // Saved, so the next launch has nothing to do, and a second load gives the same library.
        let onDisk = try Library.decoder.decode(Library.Stored.self, from: Data(contentsOf: url))
        XCTAssertEqual(onDisk.customTeams ?? [], [])
        XCTAssertEqual(onDisk.games.first?.homeTeamId, "nat-452")
        let again = Library(storeURL: url)
        XCTAssertTrue(again.customTeams.isEmpty)
        XCTAssertEqual(again.game(game.id)?.homeTeamId, "nat-452")
        XCTAssertEqual(again.profile.favoriteTeamIds, ["nat-452", "mlb-chc"])
        XCTAssertEqual(again.mergeNationalDuplicates(), 0, "Nothing left to fold")
    }

    func testTeamsPackDoesNotAddASecondBosnia() throws {
        // The downloaded teams pack carries the research's "UEFA national teams" (uefa-bih: ESPN 452 under the qualifiers), which
        // the shipped catalog already has as nat-452. A game saved under the pack's id names the catalog team once the pack is read.
        let game = GameEntry(sport: .soccer, date: .now, venueId: "bilino-polje", homeTeamId: "uefa-bih", awayTeamId: "nat-4245", origin: .manual)
        library.add(game)
        library.addFavorite("uefa-bih")
        let json = """
        {"teams": [
          {"id": "uefa-bih", "sport": "soccer", "league": "UEFA national teams", "abbreviation": "BIH", "locationName": "Bosnia and Herzegovina",
           "teamName": "Bosnia and Herzegovina national football team", "monogram": "B",
           "colors": {"primary": "112855", "secondary": "FFFFFF", "accent": "FFFFFF"}, "leagueKey": "soccer/fifa.worldq.uefa",
           "externalIds": {"espn": "452", "espnLeague": "soccer/fifa.worldq.uefa"}, "homeVenueId": "bilino-polje"},
          {"id": "bih1-jed", "sport": "soccer", "league": "Premijer Liga", "abbreviation": "BIH", "locationName": "Biha\u{107}",
           "teamName": "Jedinstvo", "monogram": "J", "colors": {"primary": "3A4150", "secondary": "3A4150", "accent": "3A4150"},
           "leagueKey": "soccer/bih.1", "externalIds": {"espn": "99999", "espnLeague": "soccer/bih.1"}}
        ], "overlays": []}
        """
        library.apply(try Library.decoder.decode(Library.PackTeams.self, from: Data(json.utf8)))
        XCTAssertNil(library.team("uefa-bih"), "The pack's Bosnia is not a catalog team")
        XCTAssertEqual(library.team("bih1-jed")?.teamName, "Jedinstvo", "A club coded BIH from the pack is")
        XCTAssertEqual(library.teams(for: .soccer).filter { $0.abbreviation == "BIH" && $0.league == Library.nationalLeague }.count, 1)
        XCTAssertNil(library.catalogTeam(league: "soccer/fifa.worldq.uefa", espnId: "452"), "The qualifiers' 452 goes through the national match")
        XCTAssertEqual(library.game(game.id)?.homeTeamId, "nat-452")
        XCTAssertEqual(library.profile.favoriteTeamIds, ["nat-452"])
        XCTAssertEqual(Library(storeURL: url).game(game.id)?.homeTeamId, "nat-452", "Saved")
        // The next game from the qualifiers, through the pack's names, is the catalog team too.
        let known = library.addTeam(GameLookup.team(from: Self.bosnia, game: Self.game(league: "soccer/fifa.worldq.uefa", name: "UEFA national teams", side: Self.bosnia)))
        XCTAssertEqual(known.id, "nat-452")
    }
}
