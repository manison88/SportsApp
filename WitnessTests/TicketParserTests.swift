import XCTest
@testable import Witness

@MainActor
final class TicketParserTests: XCTestCase {
    private var library: Library!

    override func setUp() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "parser-\(UUID().uuidString).json")
        library = Library(storeURL: url)
    }

    private func parse(_ text: String) -> TicketDraft {
        TicketParser.parse(text, teams: library.allTeams, venues: library.venues,
                           now: ISO8601DateFormatter().date(from: "2026-10-17T12:00:00Z")!)
    }

    private func parts(_ date: Date?, _ tz: String) -> [Int] {
        guard let date else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [c.year!, c.month!, c.day!, c.hour!, c.minute!]
    }

    func testCatalogLoaded() {
        XCTAssertGreaterThan(library.allTeams.count, 40)
        XCTAssertGreaterThan(library.venues.count, 40)
    }

    func testTicketmasterEmail() {
        let d = parse("""
        Ticketmaster
        You Got The Tickets!
        Cleveland Guardians at Chicago Cubs
        Wrigley Field, Chicago, IL
        Sun, Oct 30, 2016 7:08 PM
        Sec 314, Row 7, Seat 12
        Order # 12-34567/CHI
        """)
        XCTAssertEqual(d.source, "Ticketmaster")
        XCTAssertEqual(d.sport, .baseball)
        XCTAssertEqual(d.homeTeamId, "mlb-chc")
        XCTAssertEqual(d.awayTeamId, "mlb-cle")
        XCTAssertEqual(d.venueId, "wrigley")
        XCTAssertEqual(parts(d.date, "America/Chicago"), [2016, 10, 30, 19, 8])
        XCTAssertEqual(d.seatLine, "Sec 314 · Row 7 · Seat 12")
    }

    func testStubHubConfirmation() {
        let d = parse("""
        StubHub Order confirmation
        Chicago Cubs vs. Milwaukee Brewers
        Saturday, August 9, 2025 at 1:20 PM
        Wrigley Field
        Section 112, Row 9, Seats 3-4
        """)
        XCTAssertEqual(d.source, "StubHub")
        XCTAssertEqual(d.homeTeamId, "mlb-chc")
        XCTAssertEqual(d.awayTeamId, "mlb-mil")
        XCTAssertEqual(parts(d.date, "America/Chicago"), [2025, 8, 9, 13, 20])
        XCTAssertEqual(d.section, "112")
        XCTAssertEqual(d.row, "9")
        XCTAssertEqual(d.seat, "3-4")
    }

    func testSeatGeekFootballAtLambeauWithStackedLabels() {
        let d = parse("""
        SeatGeek
        Bears at Packers
        Sun • Jan 05 • 3:25 PM 2025
        Lambeau Field · Green Bay, WI
        SEC
        ROW
        SEAT
        112
        22
        5
        """)
        XCTAssertEqual(d.source, "SeatGeek")
        XCTAssertEqual(d.sport, .football)
        XCTAssertEqual(d.homeTeamId, "nfl-gb")
        XCTAssertEqual(d.awayTeamId, "nfl-chi")
        XCTAssertEqual(d.venueId, "lambeau")
        XCTAssertEqual(parts(d.date, "America/Chicago"), [2025, 1, 5, 15, 25])
        XCTAssertEqual(d.seatLine, "Sec 112 · Row 22 · Seat 5")
    }

    func testOCRScreenshotWithCodesOnly() {
        let d = parse("""
        CHC
        vs
        MIL
        Wrigley Field
        7/04/2026
        7:05 PM
        Gate K
        SECTION
        209
        ROW
        4
        SEAT
        11
        """)
        XCTAssertEqual(d.homeTeamId, "mlb-chc")
        XCTAssertEqual(d.awayTeamId, "mlb-mil")
        XCTAssertEqual(d.venueId, "wrigley")
        XCTAssertEqual(parts(d.date, "America/Chicago"), [2026, 7, 4, 19, 5])
        XCTAssertEqual(d.section, "209")
        XCTAssertEqual(d.row, "4")
        XCTAssertEqual(d.seat, "11")
    }

    func testAXSSoccerWithAccentsAndEuropeanDate() {
        let d = parse("""
        AXS Mobile Ticket
        Real Madrid v FC Barcelona
        Estadio Santiago Bernabeu
        01 Mar 2020 21:00
        Sector 104
        """)
        XCTAssertEqual(d.source, "AXS")
        XCTAssertEqual(d.sport, .soccer)
        XCTAssertEqual(d.homeTeamId, "lal-rma")
        XCTAssertEqual(d.awayTeamId, "lal-bar")
        XCTAssertEqual(d.venueId, "bernabeu")
        XCTAssertEqual(parts(d.date, "Europe/Madrid"), [2020, 3, 1, 21, 0])
        XCTAssertEqual(d.section, "104")
    }

    func testMLSAtSoldierFieldISODate() {
        let d = parse("Your tickets: Chicago Fire FC vs Inter Miami CF at Soldier Field 2023-10-04 7:30 p.m. Sec 107 Row 12 Seat 1")
        XCTAssertEqual(d.sport, .soccer)
        XCTAssertEqual(d.homeTeamId, "mls-chi")
        XCTAssertEqual(d.awayTeamId, "mls-mia")
        XCTAssertEqual(d.venueId, "soldier")
        XCTAssertEqual(parts(d.date, "America/Chicago"), [2023, 10, 4, 19, 30])
    }

    func testNothingUsefulGivesEmptyDraft() {
        let d = parse("Thanks for shopping with us!")
        XCTAssertNil(d.date)
        XCTAssertNil(d.homeTeamId)
        XCTAssertNil(d.venueId)
    }
}
