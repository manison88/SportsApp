import XCTest
import CoreLocation
@testable import Witness

/// The tournament layer of the catalog (docs/TOURNAMENTS.md, Tools/teams/tournaments): every major international and continental
/// tournament of the sports the app lists is in Catalog/competitions.json with its teams, and every national side is a pickable team,
/// once per country, sport and gender. Basketball is the one the owner found lagging: a fan going to a FIBA game, EuroBasket or an
/// AmeriCup must find the country's team in the picker.
@MainActor
final class TournamentCatalogTests: XCTestCase {
    private var library: Library!

    struct Competition: Decodable {
        let id: String
        let name: String
        let sport: String
        let gender: String
        let kind: String
        let teamIds: [String]
        let aliases: [String]
        let feed: Feed
        struct Feed: Decodable { let espn: String?; let pack: String? }
    }

    private static let competitions: [Competition] = {
        let bundle = Bundle(for: Library.self)
        guard let url = bundle.url(forResource: "competitions", withExtension: "json", subdirectory: "Catalog")
                ?? bundle.url(forResource: "competitions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Competition].self, from: data) else { return [] }
        return list
    }()

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "tournaments-\(UUID().uuidString).json"))
    }

    private func competition(_ id: String) throws -> Competition {
        try XCTUnwrap(Self.competitions.first { $0.id == id }, id)
    }

    // MARK: Competitions

    func testEveryListedTournamentHasTeamsThatExist() {
        XCTAssertGreaterThan(Self.competitions.count, 60)
        XCTAssertEqual(Set(Self.competitions.map(\.id)).count, Self.competitions.count, "competition ids are unique")
        for c in Self.competitions {
            XCTAssertFalse(c.teamIds.isEmpty, "\(c.id) has teams")
            for id in c.teamIds {
                guard let team = library.teams[id] else { XCTFail("\(c.id): \(id) is not a catalog team"); continue }
                XCTAssertEqual(team.sport.rawValue, c.sport, "\(c.id): \(id)")
            }
        }
    }

    func testBasketballHasTheKeyFibaTournaments() throws {
        let key = ["basketball/fiba.worldcup", "basketball/fiba.worldcupq", "basketball/fiba.eurobasket", "basketball/fiba.americup",
                   "basketball/fiba.afrobasket", "basketball/fiba.asiacup", "basketball/mens-olympics-basketball",
                   "basketball/fiba.worldcup.w", "basketball/fiba.eurobasket.w", "basketball/fiba.americup.w", "basketball/fiba.afrobasket.w",
                   "basketball/fiba.asiacup.w", "basketball/womens-olympics-basketball",
                   "basketball/euroleague", "basketball/eurocup", "basketball/fiba.bcl", "basketball/fiba.europecup",
                   "basketball/fiba.intercontinental", "basketball/fiba.bal"]
        for id in key { XCTAssertEqual(try competition(id).sport, "basketball", id) }
        // The 2027 World Cup (Qatar): the 80 qualifier teams, the host among them, Bosnia and Qatar both pickable.
        let worldCup = try competition("basketball/fiba.worldcup")
        XCTAssertEqual(worldCup.teamIds.count, 80)
        XCTAssertTrue(worldCup.teamIds.contains("fibam-qat"))
        XCTAssertTrue(worldCup.teamIds.contains("fibam-bih"))
        XCTAssertEqual(try competition("basketball/fiba.worldcupq").teamIds.count, 80)
        // EuroBasket covers Europe, the AmeriCup the Americas, AfroBasket Africa, the Asia Cup Asia and Oceania.
        XCTAssertTrue(try competition("basketball/fiba.eurobasket").teamIds.contains("fibam-est"))
        XCTAssertTrue(try competition("basketball/fiba.americup").teamIds.contains("fibam-nca"))
        XCTAssertTrue(try competition("basketball/fiba.afrobasket").teamIds.contains("fibam-ang"))
        XCTAssertTrue(try competition("basketball/fiba.asiacup").teamIds.contains("fibam-aus"))
        XCTAssertGreaterThanOrEqual(try competition("basketball/fiba.eurobasket").teamIds.count, 40)
        XCTAssertEqual(try competition("basketball/fiba.worldcup.w").teamIds.count, 16, "the 2026 Women's World Cup field")
        XCTAssertEqual(try competition("basketball/euroleague").teamIds.count, 20)
        XCTAssertEqual(try competition("basketball/eurocup").teamIds.count, 32)
        XCTAssertEqual(try competition("basketball/fiba.bcl").teamIds.count, 54)
        // Schedules: ESPN covers the Olympics, not EuroBasket; the competition says so rather than the app guessing.
        XCTAssertEqual(try competition("basketball/mens-olympics-basketball").feed.espn, "basketball/mens-olympics-basketball")
        XCTAssertNil(try competition("basketball/fiba.eurobasket").feed.espn)
    }

    func testEverySportTheAppListsHasItsTournaments() {
        let sports = Set(Self.competitions.map(\.sport))
        for sport in Sport.allCases where sport != .other { XCTAssertTrue(sports.contains(sport.rawValue), "\(sport) has tournaments") }
        for id in ["soccer/fifa.world", "soccer/uefa.euro", "soccer/conmebol.america", "soccer/caf.nations", "soccer/afc.asian.cup",
                   "soccer/concacaf.gold", "soccer/uefa.nations", "soccer/fifa.wwc", "soccer/uefa.champions", "soccer/conmebol.libertadores",
                   "hockey/iihf.worlds", "hockey/olympics-mens-ice-hockey", "hockey/hockey-world-cup", "handball/ihf.worldchamp",
                   "handball/ehf.euro", "baseball/world-baseball-classic", "motorsport/f1"] {
            XCTAssertTrue(Self.competitions.contains { $0.id == id }, id)
        }
    }

    // MARK: National teams

    /// A country is one team per sport and gender: the same code or the same name twice is a split like "Bosnia and Herzegovina".
    func testNoCountryIsListedTwice() {
        let groups = Dictionary(grouping: library.allTeams.filter { $0.league.localizedCaseInsensitiveContains("national teams") },
                                by: { "\($0.sport.rawValue)|\($0.league)" })
        XCTAssertGreaterThanOrEqual(groups.count, 9)
        for (group, teams) in groups {
            for (what, key) in [("code", { (t: Team) in t.abbreviation.uppercased() }),
                                ("name", { (t: Team) in t.locationName.lowercased().filter { $0.isLetter || $0.isNumber } })] {
                let dupes = Dictionary(grouping: teams, by: key).filter { $0.value.count > 1 }
                XCTAssertTrue(dupes.isEmpty, "\(group): same \(what) twice: \(dupes.map { ($0.key, $0.value.map(\.id)) })")
            }
        }
    }

    func testFibaNationalTeamsArePickable() throws {
        let men = library.allTeams.filter { $0.leagueKey == "basketball/national" }
        let women = library.allTeams.filter { $0.leagueKey == "basketball/national.w" }
        XCTAssertGreaterThanOrEqual(men.count, 125)
        XCTAssertGreaterThanOrEqual(women.count, 70)
        XCTAssertEqual(men.filter { $0.locationName == "Bosnia-Herzegovina" }.count, 1, "one Bosnia")
        XCTAssertEqual(men.filter { $0.locationName == "Qatar" }.count, 1)
        // They are in the picker's basketball list, by country, found by name and by league.
        let listed = Set(library.teams(for: .basketball).map(\.id))
        for team in men + women { XCTAssertTrue(listed.contains(team.id), team.id) }
        XCTAssertEqual(try XCTUnwrap(library.teams["fibam-bih"]).league, "FIBA national teams (men)")
        XCTAssertEqual(try XCTUnwrap(library.teams["fibaw-bih"]).league, "FIBA national teams (women)")
        // Nothing new moved: the teams that shipped before keep their ids and colors.
        let usa = try XCTUnwrap(library.teams["fibam-usa"])
        XCTAssertEqual(usa.colors.primary, "FFFFFF")
        XCTAssertEqual(usa.homeVenueId, "t-mobile-arena")
        // Every national side has a country code, a name and a colour the tile can draw.
        for t in men + women {
            XCTAssertEqual(t.countryCode?.count, 2, t.id)
            XCTAssertFalse(t.locationName.isEmpty, t.id)
            XCTAssertEqual(t.colors.accent.count, 6, t.id)
        }
    }

    func testOtherSportsNationalTeams() {
        XCTAssertGreaterThanOrEqual(library.allTeams.filter { $0.leagueKey == "hockey/national" }.count, 28)
        XCTAssertGreaterThanOrEqual(library.allTeams.filter { $0.leagueKey == "hockey/national.w" }.count, 12)
        XCTAssertGreaterThanOrEqual(library.allTeams.filter { $0.leagueKey == "handball/national" }.count, 40)
        XCTAssertGreaterThanOrEqual(library.allTeams.filter { $0.leagueKey == "handball/national.w" }.count, 35)
        XCTAssertGreaterThanOrEqual(library.allTeams.filter { $0.leagueKey == "baseball/national" }.count, 24)
        // The 2026 World Baseball Classic field (Venezuela won) is all there, and the 2027 IIHF Worlds' promoted teams.
        for code in ["VEN", "DOM", "JPN", "USA", "ITA", "CZE", "NCA", "BRA", "COL", "PAN", "TPE", "ISR", "GBR"] {
            XCTAssertNotNil(library.teams["wbsc-\(code.lowercased())"], code)
        }
        for code in ["KAZ", "UKR", "GBR", "ITA"] { XCTAssertNotNil(library.teams["iihf-\(code.lowercased())"], code) }
    }

    func testSoccerWomenAreTheirOwnTeamsAndGuamIsThere() throws {
        let women = library.allTeams.filter { $0.league == "Women's national teams" }
        XCTAssertGreaterThanOrEqual(women.count, 100)
        XCTAssertEqual(Set(women.map(\.id)).count, women.count)
        // The women's Brazil is not the men's: ESPN gives it its own id.
        let brazilWomen = try XCTUnwrap(women.first { $0.locationName == "Brazil" })
        let brazilMen = try XCTUnwrap(library.allTeams.first { $0.league == "National teams" && $0.locationName == "Brazil" })
        XCTAssertNotEqual(brazilWomen.id, brazilMen.id)
        let guam = try XCTUnwrap(library.teams["nat-10529"])
        XCTAssertEqual(guam.locationName, "Guam")
        XCTAssertEqual(library.teams(for: .soccer).filter { $0.locationName == "Guam" }.count, 1)
    }

    // MARK: Grounds

    func testTournamentGroundsAreInTheirCountries() throws {
        let grounds = library.venues.filter { $0.id.hasPrefix("bbc-") || ($0.leagues ?? []).contains { $0.hasPrefix("basketball/fiba.") } }
        XCTAssertGreaterThan(grounds.count, 60)
        for v in grounds {
            XCTAssertNotNil(TimeZone(identifier: v.timeZone), "\(v.id): \(v.timeZone)")
            // Rhodes and Mykonos are Aegean islands the country-outline file does not carry.
            if v.id.contains("kallithea") || v.id.contains("chanioti") { continue }
            guard let rings = CountryShapes.all[v.countryCode] else { continue }
            XCTAssertTrue(Self.inside(v, rings), "\(v.id) at \(v.latitude), \(v.longitude) is in \(v.country)")
        }
        // Qatar 2027: the four arenas, the 2029 EuroBasket and the next Women's EuroBasket hosts, LA 2028.
        for id in ["lusail-sports-arena", "al-janoub-stadium", "ali-bin-hamad-al-attiyah-arena", "duhail-handball-sports-hall",
                   "unibet-arena-tallinn", "sportpaleis-antwerp", "intuit-dome", "oaka-indoor-hall", "movistar-arena-madrid"] {
            let v = try XCTUnwrap(library.venue(id), id)
            XCTAssertTrue(v.sports.contains(.basketball), id)
        }
        XCTAssertTrue(try XCTUnwrap(library.venue("lusail-sports-arena")).leagues?.contains("basketball/fiba.worldcup") == true)
        // The NFL's Mexico City game is back in 2026.
        XCTAssertTrue(try XCTUnwrap(library.venue("estadio-azteca")).leagues?.contains("football/nfl") == true)
    }

    func testNewClubsKeepTheirArenas() throws {
        let cluj = try XCTUnwrap(library.teams["fibac-ro-ubt"], "U-BT Cluj-Napoca, a 2026-27 EuroCup club")
        XCTAssertEqual(cluj.sport, .basketball)
        let arena = try XCTUnwrap(library.venue(try XCTUnwrap(cluj.homeVenueId)))
        XCTAssertEqual(arena.countryCode, "RO")
        XCTAssertTrue(try competition("basketball/eurocup").teamIds.contains(cluj.id))
        XCTAssertTrue(try competition("basketball/fiba.bcl").teamIds.contains("lkl-ryt"), "the champion Rytas")
    }

    /// Inside the country's 0.1-degree outline, or within 0.7 degrees of it: islands and coasts the outline rounds off (Oostende, Rhodes, Mykonos).
    private static func inside(_ v: Venue, _ rings: [[CGPoint]]) -> Bool {
        let p = CGPoint(x: v.longitude, y: v.latitude)
        for ring in rings where ring.count > 2 {
            var hit = false
            var j = ring.count - 1
            for i in ring.indices {
                let a = ring[i], b = ring[j]
                if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { hit.toggle() }
                j = i
            }
            if hit { return true }
        }
        return rings.contains { $0.contains { abs($0.x - p.x) < 0.7 && abs($0.y - p.y) < 0.7 } }
    }
}
