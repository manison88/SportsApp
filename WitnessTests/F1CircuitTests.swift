import XCTest
import CoreLocation
@testable import Witness

/// Formula 1 circuits are catalog venues: the venue picker lists them (not the teams' factories), the scan places
/// race-day photos at them although a circuit is kilometres wide, and a visit on a race weekend becomes that Grand Prix
/// from the bundled calendar without a network call.
@MainActor
final class F1CircuitTests: XCTestCase {
    private var library: Library!

    /// Every circuit on the 2025 and 2026 calendars (Sepang: the 2026 Bahrain round moved to Malaysia).
    static let current = ["bahrain", "jeddah", "albert-park", "suzuka", "shanghai", "miami", "imola", "monaco", "catalunya", "madring",
                          "gilles-villeneuve", "red-bull-ring", "silverstone", "hungaroring", "spa", "zandvoort", "monza", "baku",
                          "marina-bay", "cota", "hermanos-rodriguez", "interlagos", "las-vegas", "losail", "yas-marina", "sepang"]
    /// The team bases that used to be the catalog's only motorsport "venues".
    static let factories = ["mercedes-f1-brackley", "alpine-enstone", "racing-bulls-faenza", "cadillac-f1-fishers", "williams-grove",
                            "audi-f1-hinwil", "haas-kannapolis", "ferrari-maranello", "red-bull-technology-campus",
                            "aston-martin-silverstone-campus", "mclaren-technology-centre"]

    override func setUp() async throws {
        library = Library(storeURL: FileManager.default.temporaryDirectory.appending(path: "f1-\(UUID().uuidString).json"))
    }

    override func tearDown() { GameLookup.responder = nil }

    // MARK: The catalog

    func testEveryCircuitIsAMotorsportVenueInItsCountry() throws {
        for id in Self.current {
            let v = try XCTUnwrap(library.venue(id), id)
            XCTAssertEqual(v.sports, [.motorsport], id)
            XCTAssertEqual(v.leagues, [F1Calendar.leagueKey], "\(id): race weekends come from the F1 calendar")
            XCTAssertEqual(v.homeTeams ?? [], [], "\(id): nobody calls a circuit home")
            XCTAssertNotNil(TimeZone(identifier: v.timeZone), "\(id): \(v.timeZone)")
            XCTAssertNotNil(v.capacity, id)
            XCTAssertNotNil(v.opened, id)
            XCTAssertFalse(v.aliases?.isEmpty ?? true, "\(id) has other names to search by")
            XCTAssertTrue((800...1500).contains(v.geofence), "\(id): a circuit's fence (\(v.geofence) m) reaches its grandstands")
            XCTAssertTrue(Self.inside(v), "\(id) at \(v.latitude), \(v.longitude) is in \(v.country)")
            XCTAssertFalse(F1Calendar.races(at: id).isEmpty, "\(id) has race weekends")
        }
        // The one circuit the catalog already had keeps its id and gains the circuit's names and fence.
        let cota = try XCTUnwrap(library.venue("cota"))
        XCTAssertEqual(cota.aliases?.contains("COTA"), true)
        XCTAssertEqual(cota.geofence, 1200)
        XCTAssertEqual(cota.capacity, 120_000)
    }

    /// Inside the country's outline (0.1-degree resolution), or on a coast or island its outline rounds off (Yas Island,
    /// Marina Bay, Zandvoort's beach). Monaco, Singapore and Bahrain have no outline: a tight box each.
    private static func inside(_ v: Venue) -> Bool {
        let p = CGPoint(x: v.longitude, y: v.latitude)
        switch v.countryCode {
        case "MC": return (43.72...43.76).contains(v.latitude) && (7.40...7.45).contains(v.longitude)
        case "SG": return (1.2...1.5).contains(v.latitude) && (103.6...104.1).contains(v.longitude)
        case "BH": return (25.8...26.3).contains(v.latitude) && (50.4...50.7).contains(v.longitude)
        default: break
        }
        guard let rings = CountryShapes.all[v.countryCode] else { return false }
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
        return rings.contains { $0.contains { abs($0.x - p.x) < 0.15 && abs($0.y - p.y) < 0.15 } }
    }

    func testTheVenuePickerListsCircuitsNotFactories() {
        let listed = Set(library.venues(for: .motorsport).map(\.id))
        for id in Self.current { XCTAssertTrue(listed.contains(id), "\(id) is on the motorsport list") }
        for id in Self.factories { XCTAssertNil(library.venue(id), "\(id) is a factory, not a place to watch a race") }
        XCTAssertFalse(library.venues(for: .motorsport).contains { !($0.homeTeams ?? []).isEmpty && $0.leagues == [] },
                       "No team base is listed as a motorsport ground")
        for (query, id) in [("Silverstone", "silverstone"), ("Monza", "monza"), ("Spa", "spa"), ("COTA", "cota"), ("Yas Marina", "yas-marina"),
                            ("Las Vegas", "las-vegas"), ("Miami", "miami"), ("Montreal", "gilles-villeneuve"), ("Sakhir", "bahrain"),
                            ("Interlagos", "interlagos"), ("Zandvoort", "zandvoort")] {
            XCTAssertEqual(library.searchVenues(query, sport: .motorsport).first?.id, id, query)
        }
        // The teams keep no factory as a home ground, so a circuit never reads as "Mercedes' stadium".
        for team in library.allTeams where team.sport == .motorsport {
            XCTAssertNil(team.homeVenueId, team.id)
        }
        for id in ["silverstone", "monza", "cota"] {
            XCTAssertNil(library.homeTeam(at: library.venue(id)!, sport: .motorsport), id)
        }
    }

    // MARK: The scan

    func testRaceDayPhotosAtTheGrandstandsPlaceAtTheCircuit() throws {
        let silverstone = try XCTUnwrap(library.venue("silverstone"))
        let index = VenueIndex(library.venues)
        // The far grandstands: 1 km north of the pit straight, and 1.3 km east across a 0.02-degree index cell boundary.
        let north = (lat: silverstone.latitude + 0.009, lon: silverstone.longitude)
        let east = (lat: silverstone.latitude, lon: silverstone.longitude + 0.019)
        for p in [north, east] {
            XCTAssertEqual(index.nearest(lat: p.lat, lon: p.lon)?.id, "silverstone", "\(p)")
            XCTAssertEqual(VisitGrouping.nearestVenue(lat: p.lat, lon: p.lon, in: library.venues)?.id, "silverstone", "\(p)")
        }
        // 2 km out is the campsite, which can join a visit but never start one.
        XCTAssertNil(index.nearest(lat: silverstone.latitude + 0.018, lon: silverstone.longitude))
        // Ordinary stadiums keep their tight fence.
        let wrigley = try XCTUnwrap(library.venue("wrigley"))
        XCTAssertEqual(index.nearest(lat: wrigley.latitude + 0.001, lon: wrigley.longitude)?.id, "wrigley")
        XCTAssertNil(index.nearest(lat: wrigley.latitude + 0.004, lon: wrigley.longitude), "450 m from Wrigley is the bar, not the ballpark")

        // An afternoon in the Copse grandstand is one visit at Silverstone.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = silverstone.tz
        let start = try XCTUnwrap(cal.date(from: DateComponents(year: 2025, month: 7, day: 6, hour: 13)))
        let points = (0..<6).map { i in
            PhotoPoint(id: "p\(i)", date: start.addingTimeInterval(Double(i) * 1200), latitude: north.lat + Double(i) * 0.0002, longitude: north.lon)
        }
        let scan = VisitGrouping.group(points, venues: library.venues)
        XCTAssertEqual(scan.visits.count, 1)
        XCTAssertEqual(scan.visits.first?.venue.id, "silverstone")
        XCTAssertEqual(scan.visits.first?.assetIds.count, 6)
    }

    func testMiamiWeekendPhotosAtHardRockStadiumReachTheCircuit() async throws {
        // The Miami circuit wraps Hard Rock Stadium: a photo at the stadium places there, and the circuit is its neighbour.
        let stadium = try XCTUnwrap(library.venue("hard-rock-stadium"))
        let miami = try XCTUnwrap(library.venue("miami"))
        XCTAssertEqual(VenueIndex(library.venues).nearest(lat: stadium.latitude, lon: stadium.longitude)?.id, stadium.id)
        XCTAssertTrue(PhotoMatcher.neighbors(of: stadium, in: library.venues).contains { $0.id == miami.id })
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = miami.tz
        let raceDay = try XCTUnwrap(cal.date(from: DateComponents(year: 2025, month: 5, day: 4, hour: 16)))
        let found = await GameLookup.games(at: miami, from: raceDay, to: raceDay.addingTimeInterval(3600))
        XCTAssertEqual(found.first?.race?.id, "2025-miami")
    }

    // MARK: The race

    func testAVisitAtSilverstoneOnRaceDayIsTheBritishGrandPrix() async throws {
        GameLookup.responder = { url in XCTFail("The race comes from the bundled calendar, not \(url)"); return nil }
        let silverstone = try XCTUnwrap(library.venue("silverstone"))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = silverstone.tz
        let raceDay = try XCTUnwrap(cal.date(from: DateComponents(year: 2025, month: 7, day: 6, hour: 13)))

        let found = await GameLookup.games(at: silverstone, from: raceDay, to: raceDay.addingTimeInterval(3 * 3600))
        XCTAssertEqual(found.count, 1, found.map(\.id).description)
        let race = try XCTUnwrap(found.first?.race)
        XCTAssertEqual(race.id, "2025-british")
        XCTAssertEqual(race.shortName, "British Grand Prix")
        XCTAssertEqual(race.name, "Qatar Airways British Grand Prix", "the sponsor stays in the full name")
        XCTAssertEqual(found.first?.leagueName, "Formula 1")
        XCTAssertEqual(found.first?.sport, .motorsport)
        XCTAssertEqual(race.results?.winner?.code, "NOR")
        XCTAssertEqual(race.results?.podium, ["P1 NOR", "P2 PIA", "P3 HUL"])

        var entry = GameEntry(sport: .motorsport, date: raceDay, venueId: silverstone.id, origin: .photos)
        GameLookup.apply(try XCTUnwrap(found.first), detail: nil, to: &entry, library: library)
        XCTAssertEqual(entry.competition, "2025 British Grand Prix")
        XCTAssertEqual(entry.venueId, "silverstone")
        XCTAssertEqual(entry.source?.league, "racing/f1")
        XCTAssertEqual(entry.podium.first?.hasPrefix("P1 NOR"), true, entry.podium.description)
        XCTAssertNil(entry.homeTeamId)

        // Friday practice is the same weekend; the Monday after is not.
        let friday = try XCTUnwrap(cal.date(byAdding: .day, value: -2, to: raceDay))
        let fridayFound = await GameLookup.games(at: silverstone, from: friday, to: friday.addingTimeInterval(3600))
        XCTAssertEqual(fridayFound.first?.race?.id, "2025-british")
        let monday = try XCTUnwrap(cal.date(byAdding: .day, value: 1, to: raceDay))
        let mondayFound = await GameLookup.games(at: silverstone, from: monday, to: monday.addingTimeInterval(3600))
        XCTAssertTrue(mondayFound.isEmpty, mondayFound.map(\.id).description)
    }
}
