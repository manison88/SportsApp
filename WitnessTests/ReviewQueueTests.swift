import XCTest
@testable import Witness

/// Every visit a scan finds is asked about once: in onboarding, then never again by the background search, a rescan or a
/// relaunch, whether the fan added it or skipped it.
@MainActor
final class ReviewQueueTests: XCTestCase {
    private func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString).json")
    }

    private func venue(_ name: String, in library: Library) throws -> Venue {
        try XCTUnwrap(library.venues.first { $0.name == name })
    }

    private func visit(_ id: String, at venue: Venue, _ start: Date, photos: Int = 4) -> PhotoCluster {
        let times = (0..<photos).map { start.addingTimeInterval(Double($0) * 600) }
        return PhotoCluster(id: id, venue: venue, start: start, end: times.last ?? start,
                            assetIds: (0..<photos).map { "\(id)-photo-\($0)" }, times: times)
    }

    /// The background search's version of a first-pass visit: the same photos, offered as a possible game.
    private func possible(_ cluster: PhotoCluster) -> PossibleDay {
        PossibleDay(id: "possible-" + cluster.id, day: cluster.start, assetIds: cluster.assetIds, times: cluster.times,
                    reason: "Photos inside \(cluster.venue.name) with no game that day", suggestions: [cluster.venue])
    }

    private func day(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    func testTourAddedInOnboardingIsNotOfferedByTheBackgroundSearch() throws {
        let library = Library(storeURL: tempURL("library"))
        let scan = ScanModel(ledgerURL: tempURL("ledger"))
        let tour = visit("tour", at: try venue("Fenway Park", in: library), day("2019-03-02T15:00:00Z"))
        let album = PossibleDay(id: "album-day", day: day("2018-07-04T18:00:00Z"), assetIds: ["album-1", "album-2", "album-3"],
                                times: [], reason: "Album \"Summer\"")
        scan.settleFirstPass(games: [], others: [tour], library: library)

        let first = scan.takeForReview(library: library)
        XCTAssertEqual(first.others.map(\.id), ["tour"])
        XCTAssertEqual(scan.commit(first.others, asVisits: true, into: library), 1)

        // The search finds the same photos again (the stadium visit, and an album that holds them) plus one new day.
        scan.settleDeep([possible(tour), album], library: library)
        XCTAssertEqual(scan.possible.map(\.id), ["album-day"])
        let second = scan.takeForReview(library: library)
        XCTAssertTrue(second.games.isEmpty)
        XCTAssertTrue(second.others.isEmpty, "The first pass's visits are not shown again after the search")
        XCTAssertEqual(second.possible.map(\.id), ["album-day"])
    }

    func testSkippedTourIsNotOfferedAgainEvenAfterARelaunch() throws {
        let library = Library(storeURL: tempURL("library"))
        let ledgerURL = tempURL("ledger")
        let scan = ScanModel(ledgerURL: ledgerURL)
        let tour = visit("tour", at: try venue("Fenway Park", in: library), day("2019-03-02T15:00:00Z"))
        scan.settleFirstPass(games: [], others: [tour], library: library)
        let first = scan.takeForReview(library: library)
        XCTAssertEqual(first.others.count, 1)
        scan.dismiss(tour.assetIds, on: tour.start)

        // Same session: the background search finds it again.
        scan.settleDeep([possible(tour)], library: library)
        XCTAssertTrue(scan.takeForReview(library: library).possible.isEmpty)

        // After a relaunch: a new scan model reads the skips from disk; neither a rescan nor the search offers it.
        let relaunched = ScanModel(ledgerURL: ledgerURL)
        XCTAssertEqual(relaunched.ledger.dismissedAssets, Set(tour.assetIds))
        relaunched.settleFirstPass(games: [], others: [tour], library: library)
        relaunched.settleDeep([possible(tour)], library: library)
        let review = relaunched.takeForReview(library: library)
        XCTAssertTrue(review.others.isEmpty)
        XCTAssertTrue(review.possible.isEmpty)
        // Other photos of the same outing (the same hours) from an album are the same outing.
        let sameDay = PossibleDay(id: "album", day: tour.start, assetIds: ["a", "b", "c"], times: [], reason: "Album")
        relaunched.settleDeep([sameDay], library: library)
        XCTAssertTrue(relaunched.possible.isEmpty)
    }

    /// A skipped morning stadium visit says nothing about the evening: a game found later that day (an album, a city day) is offered.
    func testASkippedMorningVisitDoesNotHideTheEveningGame() throws {
        let library = Library(storeURL: tempURL("library"))
        let ledgerURL = tempURL("ledger")
        let scan = ScanModel(ledgerURL: ledgerURL)
        let tour = visit("tour", at: try venue("Fenway Park", in: library), day("2019-03-02T15:00:00Z"))
        scan.settleFirstPass(games: [], others: [tour], library: library)
        XCTAssertEqual(scan.takeForReview(library: library).others.count, 1)
        scan.dismiss(tour.assetIds, on: tour.start, times: tour.times)

        let evening = PossibleDay(id: "album-evening", day: day("2019-03-02T23:30:00Z"), assetIds: ["e1", "e2", "e3"], times: [], reason: "Album \"Game night\"")
        scan.settleDeep([evening], library: library)
        XCTAssertEqual(scan.takeForReview(library: library).possible.map(\.id), ["album-evening"])

        // After a relaunch too; the skip is not kept as a day.
        let relaunched = ScanModel(ledgerURL: ledgerURL)
        relaunched.settleDeep([evening], library: library)
        XCTAssertEqual(relaunched.possible.map(\.id), ["album-evening"])
        XCTAssertTrue(relaunched.ledger.dismissedDays.isEmpty)
    }

    /// A ledger from before skips were kept per outing still loads, and its day-level skips hide nothing new.
    func testAnOlderDayLevelSkipNoLongerHidesTheWholeDay() throws {
        let library = Library(storeURL: tempURL("library"))
        let ledgerURL = tempURL("ledger")
        try Data(#"{"dismissedAssets":["old-1"],"dismissedDays":["2019-03-02"]}"#.utf8).write(to: ledgerURL)
        let scan = ScanModel(ledgerURL: ledgerURL)
        XCTAssertEqual(scan.ledger.dismissedAssets, ["old-1"])
        let evening = PossibleDay(id: "album-evening", day: day("2019-03-02T23:30:00Z"), assetIds: ["e1", "e2", "e3"], times: [], reason: "Album")
        let oldPhotos = PossibleDay(id: "again", day: day("2019-03-02T15:00:00Z"), assetIds: ["old-1", "x"], times: [], reason: "Album")
        scan.settleDeep([evening, oldPhotos], library: library)
        XCTAssertEqual(scan.possible.map(\.id), ["album-evening"], "The skipped photos stay skipped; the day does not")
    }

    func testOnboardingCountIsWhatAddAllAdds() throws {
        let library = Library(storeURL: tempURL("library"))
        let scan = ScanModel(ledgerURL: tempURL("ledger"))
        let fenway = try venue("Fenway Park", in: library), wrigley = try venue("Wrigley Field", in: library)
        let games = [visit("g1", at: fenway, day("2017-06-09T23:00:00Z")),
                     visit("g2", at: wrigley, day("2018-05-01T23:00:00Z")),
                     visit("g3", at: wrigley, day("2019-08-10T23:00:00Z"))]
        let tours = [visit("t1", at: fenway, day("2016-01-15T16:00:00Z")), visit("t2", at: wrigley, day("2015-02-20T16:00:00Z"))]
        scan.settleFirstPass(games: games, others: tours, library: library)

        // "N games found" counts games only; the tours are asked about after, not added with them.
        XCTAssertEqual(scan.games.count, 3)
        XCTAssertEqual(scan.others.count, 2)
        let before = library.games.count
        let headline = scan.games.count
        XCTAssertEqual(scan.commit(scan.games, into: library), headline)
        XCTAssertEqual(library.games.count - before, 3)
        XCTAssertTrue(ReviewQueue.photos(in: library.games).isDisjoint(with: tours.flatMap(\.assetIds)))
        let review = scan.takeForReview(library: library)
        XCTAssertTrue(review.games.isEmpty)
        XCTAssertEqual(Set(review.others.map(\.id)), ["t1", "t2"])
    }

    func testVisitFoundByTwoPassesIsShownOnce() throws {
        let library = Library(storeURL: tempURL("library"))
        let scan = ScanModel(ledgerURL: tempURL("ledger"))
        let fenway = try venue("Fenway Park", in: library)
        let tour = visit("tour", at: fenway, day("2019-03-02T15:00:00Z"))
        scan.settleFirstPass(games: [], others: [tour], library: library)
        // Offered by the stadium-visit step and by the album step, while the first pass still has it waiting.
        let fromAlbum = PossibleDay(id: "album", day: tour.start, assetIds: [tour.assetIds[0], "extra"], times: [], reason: "Album")
        scan.settleDeep([possible(tour), fromAlbum], library: library)
        let review = scan.takeForReview(library: library)
        XCTAssertEqual(review.others.count + review.possible.count, 1)
    }

    func testWalkPastTheNeighbourOnGameDayJoinsTheGame() throws {
        let library = Library(storeURL: tempURL("library"))
        let lumen = try venue("Lumen Field", in: library), ballpark = try venue("T-Mobile Park", in: library)
        let game = visit("match", at: lumen, day("2026-06-24T19:00:00Z"))
        let walk = visit("walk", at: ballpark, day("2026-06-24T16:00:00Z"))
        let settled = ReviewQueue.firstPass(games: [game], others: [walk], library: [], venues: library.venues, ledger: .init())
        XCTAssertTrue(settled.others.isEmpty)
        XCTAssertEqual(settled.games.map(\.id), ["match"], "The game keeps its id, so its schedule match still applies")
        XCTAssertEqual(settled.games.first?.assetIds.count, 8)
    }
}
