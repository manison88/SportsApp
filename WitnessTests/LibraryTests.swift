import XCTest
@testable import Witness

@MainActor
final class LibraryTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "library-\(UUID().uuidString).json")
    }

    /// A person the fan added can be removed, and comes off every game they were on; the sample cast cannot.
    func testRemovingAPersonTakesThemOffTheirGames() throws {
        let url = tempURL()
        let library = Library(storeURL: url)
        library.startEmpty()
        let steve = library.addPerson(named: "Steve")
        var game = GameEntry(sport: .baseball, date: Date(), venueId: "mlb-chc", photos: [], origin: .manual)
        game.companionIds = [steve.id]
        library.add(game)
        XCTAssertTrue(library.isCustomPerson(steve.id))
        XCTAssertEqual(library.games(with: steve.id).count, 1)

        library.removePerson(steve.id)
        XCTAssertFalse(library.people.contains { $0.id == steve.id })
        XCTAssertTrue(library.games(with: steve.id).isEmpty, "Off the game too")
        XCTAssertTrue(Library(storeURL: url).people.isEmpty, "Gone after a relaunch")

        let sample = Library(storeURL: tempURL())
        sample.loadSample()
        let cast = sample.people.count
        XCTAssertGreaterThan(cast, 0)
        sample.removePerson(sample.people[0].id)
        XCTAssertEqual(sample.people.count, cast, "The sample library's people stay")
    }

    func testAddPersistsAndReloads() throws {
        let url = tempURL()
        let library = Library(storeURL: url)
        XCTAssertFalse(library.hasLibrary)
        let game = GameEntry(sport: .baseball, date: .now, venueId: "wrigley",
                             homeTeamId: "mlb-chc", awayTeamId: "mlb-stl", homeScore: 5, awayScore: 1,
                             seat: "Sec 209", origin: .manual)
        library.add(game)
        XCTAssertTrue(library.hasLibrary)

        let reloaded = Library(storeURL: url)
        XCTAssertEqual(reloaded.games.count, 1)
        XCTAssertEqual(reloaded.games.first?.id, game.id)
        XCTAssertEqual(reloaded.games.first?.seat, "Sec 209")
        XCTAssertEqual(reloaded.outcome(reloaded.games[0]), .win)

        reloaded.delete(game.id)
        XCTAssertTrue(Library(storeURL: url).games.isEmpty)
    }

    func testCustomVenueDedupesAndPersists() {
        let url = tempURL()
        let library = Library(storeURL: url)
        let v = Venue(id: "custom-1", name: "Wrigley Rooftop", city: "Chicago", region: nil, country: "United States",
                      countryCode: "US", latitude: 41.9490, longitude: -87.6560, sports: [.baseball],
                      timeZone: "America/Chicago")
        let a = library.addVenue(v)
        let dup = Venue(id: "custom-2", name: "wrigley rooftop", city: "Chicago", region: nil, country: "United States",
                    countryCode: "US", latitude: 41.9491, longitude: -87.6561, sports: [.baseball],
                    timeZone: "America/Chicago")
        let b = library.addVenue(dup)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(library.customVenues.count, 1)
        XCTAssertEqual(Library(storeURL: url).venue("custom-1")?.isCustom, true)
    }

    func testAddPerson() {
        let library = Library(storeURL: tempURL())
        let p = library.addPerson(named: "Jordan Lee")
        XCTAssertEqual(p.initials, "JL")
        XCTAssertEqual(library.addPerson(named: "jordan lee").id, p.id)
    }

    func testSampleLibrary() throws {
        let library = Library(storeURL: tempURL())
        library.loadSample()
        XCTAssertEqual(library.games.count, 60)
        XCTAssertTrue(library.isSample)
        let ws5 = try XCTUnwrap(library.game("mlb-2016-ws5"))
        XCTAssertEqual(library.outcome(ws5), .win)
        XCTAssertEqual(ws5.lineHome.reduce(0, +), 3)
        XCTAssertFalse(ws5.winProbability.isEmpty)
        XCTAssertEqual(ws5.photos.first, .bundled("wrigley-night"))
        XCTAssertNotNil(library.venue(ws5.venueId))

        // Sorted newest first.
        XCTAssertGreaterThanOrEqual(library.games[0].date, library.games[1].date)
    }

    func testStats() {
        let library = Library(storeURL: tempURL())
        library.loadSample()
        let stats = Stats(library: library)
        XCTAssertEqual(stats.games, 60)
        XCTAssertGreaterThan(stats.record.decided, 0)
        XCTAssertFalse(stats.mlbParks.isEmpty)
        XCTAssertGreaterThan(stats.venues, 10)
        XCTAssertGreaterThanOrEqual(stats.countries, 2)
        XCTAssertGreaterThan(stats.miles, 1000)
        XCTAssertFalse(stats.companions.isEmpty)
    }

    func testRemoveSampleKeepsUserGames() {
        let library = Library(storeURL: tempURL())
        library.loadSample()
        library.add(GameEntry(sport: .hockey, date: .now, venueId: "united-center", origin: .manual))
        library.removeSample()
        XCTAssertEqual(library.games.count, 1)
        XCTAssertFalse(library.isSample)
    }

    func testResetClearsEverything() {
        let url = tempURL()
        let library = Library(storeURL: url)
        library.loadSample()
        library.reset()
        XCTAssertFalse(library.hasLibrary)
        XCTAssertFalse(Library(storeURL: url).hasLibrary)
    }
}
