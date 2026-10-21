import XCTest
import CryptoKit
import CoreLocation
@testable import Witness

/// The scan's thresholds and word lists come from `ScanSettings`: the built-in defaults, or a newer signed pack. A pack that
/// does not verify, or is not newer, changes nothing; a value out of range is clamped; a key the pack leaves out keeps its
/// default; and a changed value changes what the scan offers.
@MainActor
final class ScanSettingsTests: XCTestCase {
    private var library: Library!
    private var ledgerURL: URL!
    private var pendingURL: URL!

    override func setUp() async throws {
        library = Library(storeURL: temp("library"))
        ledgerURL = temp("ledger")
        pendingURL = temp("pending")
        GameLookup.responder = { _ in Data(#"{"events":[]}"#.utf8) }
        ScanSettings.install(.defaults)
    }

    override func tearDown() async throws {
        GameLookup.responder = nil
        ScanSettings.install(.defaults)
    }

    private func temp(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "settings-\(name)-\(UUID().uuidString).json")
    }

    // MARK: Decoding

    func testMissingAndUnknownKeysKeepTheDefaults() throws {
        let json = #"{"version": 7, "dwellMinutes": 45, "somethingNew": true, "nationalNames": {"XYZ": ["nowhere"]}, "cityPhotos": "five"}"#
        let decoded = try JSONDecoder().decode(ScanSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.version, 7)
        XCTAssertEqual(decoded.dwellMinutes, 45)
        XCTAssertEqual(decoded.dwellPhotos, ScanSettings.defaults.dwellPhotos, "A key left out keeps its default")
        XCTAssertEqual(decoded.cityPhotos, ScanSettings.defaults.cityPhotos, "A key of the wrong type keeps its default")
        XCTAssertEqual(decoded.nationalNames, ["XYZ": ["nowhere"]])
        XCTAssertEqual(decoded.sceneElsewhereWords, ScanSettings.defaults.sceneElsewhereWords)
        let noVersion = try JSONDecoder().decode(ScanSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(noVersion.version, 0, "No version reads as 0, so it never replaces the built-in defaults")
        XCTAssertNil(ScanSettings.fromPack(Data("{}".utf8)))
    }

    func testDefaultsRoundTrip() throws {
        let data = try JSONEncoder().encode(ScanSettings.defaults)
        XCTAssertEqual(try JSONDecoder().decode(ScanSettings.self, from: data), .defaults)
        XCTAssertTrue(ScanSettings.defaults.differences().isEmpty)
        XCTAssertEqual(ScanSettings.defaults.clamped(), .defaults, "Today's values are inside every range")
    }

    /// The pack source in the repo is the built-in defaults, key for key, so what is published is what the app ships with. Its
    /// version may run ahead of the built-in one: that is how a rule change reaches phones on an earlier build.
    func testThePublishedSourceFileMatchesTheBuiltInDefaults() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let file = repo.appending(path: "Tools/packs/scan-settings.json")
        guard let data = try? Data(contentsOf: file) else { throw XCTSkip("Tools/packs/scan-settings.json is not beside the tests") }
        var published = try JSONDecoder().decode(ScanSettings.self, from: data)
        XCTAssertGreaterThanOrEqual(published.version, ScanSettings.defaults.version)
        published.version = ScanSettings.defaults.version
        XCTAssertEqual(published, .defaults)
        let keys = Set((try JSONSerialization.jsonObject(with: data) as? [String: Any])?.keys.map { $0 } ?? [])
        XCTAssertEqual(keys, Set(ScanSettings.CodingKeys.allCases.map(\.rawValue)), "Every setting is in the file, and nothing else")
    }

    // MARK: Clamping

    func testOutOfRangeValuesAreClamped() throws {
        var wild = ScanSettings.defaults
        wild.fenceMeters = 20
        wild.fenceHugeMeters = 50_000
        wild.vehicleSpeed = 1
        wild.movingSpeed = 900
        wild.dwellPhotos = 0
        wild.dwellMinutes = 100_000
        wild.lookupConcurrency = 0
        wild.lookupAttempts = 99
        wild.cityVenueShare = 4
        wild.cityElsewhereShare = -1
        wild.indexBoxSlack = 0.5
        wild.cityMetroMeters = 10
        wild.scheduleBeforeHours = -3
        wild.matchupSeparator = "(["
        wild.sportTitleWords = ["", "  game ", ""]
        wild.nationalNames = ["bih": ["bosna", ""]]
        wild.version = -2
        let clamped = wild.clamped()
        XCTAssertEqual(clamped.fenceMeters, 50)
        XCTAssertEqual(clamped.fenceHugeMeters, 5_000)
        XCTAssertEqual(clamped.vehicleSpeed, 5)
        XCTAssertEqual(clamped.movingSpeed, 120)
        XCTAssertEqual(clamped.dwellPhotos, 1)
        XCTAssertEqual(clamped.dwellMinutes, 600)
        XCTAssertEqual(clamped.lookupConcurrency, 1)
        XCTAssertEqual(clamped.lookupAttempts, 10)
        XCTAssertEqual(clamped.cityVenueShare, 1)
        XCTAssertEqual(clamped.cityElsewhereShare, 0)
        XCTAssertEqual(clamped.indexBoxSlack, 1)
        XCTAssertEqual(clamped.cityMetroMeters, 1_000)
        XCTAssertEqual(clamped.scheduleBeforeHours, 0)
        XCTAssertEqual(clamped.matchupSeparator, ScanSettings.defaults.matchupSeparator, "A separator that does not compile falls back")
        XCTAssertEqual(clamped.sportTitleWords, ["game"])
        XCTAssertEqual(clamped.nationalNames, ["BIH": ["bosna"]])
        XCTAssertEqual(clamped.version, 0)
        XCTAssertEqual(clamped.neighborMeters, ScanSettings.defaults.neighborMeters, "Values in range are untouched")
    }

    func testDifferencesNameEachChangedValue() {
        var changed = ScanSettings.defaults
        changed.dwellMinutes = 60
        changed.sceneElsewhereWords.append("golf")
        let lines = changed.differences()
        XCTAssertEqual(lines.count, 2, "\(lines)")
        XCTAssertTrue(lines.contains("dwellMinutes: 60 (default 0)"), "\(lines)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("sceneElsewhereWords: ") && $0.contains("entries (default") }, "\(lines)")
        XCTAssertEqual(ScanCheck.settingsLines(changed, source: .pack).first, "Settings: v1 (pack)")
    }

    // MARK: Loading from the signed packs

    /// A packs directory as `PackStore` leaves it: a signed manifest naming the settings pack, and the pack file beside it.
    private struct Packs {
        let directory: URL
        let key = Curve25519.Signing.PrivateKey()
        var publicKey: String { key.publicKey.rawRepresentation.base64EncodedString() }

        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(path: "packs-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        /// Writes the pack and a manifest listing it. `tamper` changes the pack's bytes after the manifest was made.
        func publish(_ json: String, signed: Bool = true, tamper: Bool = false, kind: String = ScanSettings.packKind,
                     id: String = ScanSettings.packId) throws {
            let data = Data(json.utf8)
            let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let version = String(sha.prefix(8))
            let pack: [String: Any] = ["id": id, "kind": kind, "version": version, "path": "\(id).\(version).json", "bytes": data.count, "sha256": sha]
            let body = try JSONSerialization.data(withJSONObject: ["schema": 1, "minAppVersion": "1.0", "packs": [pack]])
            var envelope: [String: Any] = ["body": String(decoding: body, as: UTF8.self)]
            if signed { envelope["signature"] = try key.signature(for: body).base64EncodedString() }
            try JSONSerialization.data(withJSONObject: envelope).write(to: directory.appending(path: "manifest.json"))
            let stored = tamper ? Data((json + " ").utf8) : data
            try stored.write(to: directory.appending(path: "\(PackStore.fileStem(id)).\(version).json"))
        }
    }

    func testANewerPackReplacesTheDefaultsAndAnOlderOneDoesNot() throws {
        let packs = try Packs()
        try packs.publish(#"{"version": 2, "dwellMinutes": 60, "neighborMeters": 99999}"#)
        let newer = ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey)
        XCTAssertEqual(newer.source, .pack)
        XCTAssertEqual(newer.settings.version, 2)
        XCTAssertEqual(newer.settings.dwellMinutes, 60)
        XCTAssertEqual(newer.settings.neighborMeters, 5_000, "Clamped on the way in")
        XCTAssertEqual(newer.settings.dwellPhotos, 2, "A key the pack leaves out keeps its default")

        try packs.publish(#"{"version": 1, "dwellMinutes": 60}"#)
        let same = ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey)
        XCTAssertEqual(same.source, .builtIn, "The same version as the built-in defaults is not newer")
        XCTAssertEqual(same.settings, .defaults)

        try packs.publish(#"{"version": 0, "dwellMinutes": 60}"#)
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey).settings, .defaults)

        // A built-in newer than the pack (the app shipped with the change) keeps its own values.
        var builtIn = ScanSettings.defaults
        builtIn.version = 5
        try packs.publish(#"{"version": 3, "dwellMinutes": 60}"#)
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey, builtIn: builtIn).settings, builtIn)
    }

    func testATamperedOrUnsignedPackIsIgnored() throws {
        let packs = try Packs()
        let json = #"{"version": 9, "dwellMinutes": 60}"#

        try packs.publish(json, signed: false)
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey).source, .builtIn, "No signature")

        try packs.publish(json, tamper: true)
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey).source, .builtIn,
                       "The pack's bytes don't match the hash the signed manifest carries")

        try packs.publish(json)
        let other = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: other).source, .builtIn, "Signed with another key")
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey).source, .pack, "The same pack, verified, applies")

        try packs.publish(json, kind: "catalog", id: "catalog/scan-settings")
        XCTAssertEqual(ScanSettings.loaded(from: packs.directory, publicKey: packs.publicKey).source, .builtIn, "Only the settings pack counts")

        XCTAssertEqual(ScanSettings.loaded(from: packs.directory.appending(path: "nowhere"), publicKey: packs.publicKey).source, .builtIn,
                       "No packs on the phone yet")

        // `reload` is what `PackStore` calls after adopting a manifest; `current` follows it.
        try packs.publish(json)
        ScanSettings.reload(from: packs.directory)
        if PackConfig.publicKey.isEmpty {
            XCTAssertEqual(ScanSettings.current.dwellMinutes, 60, "Development mode accepts any manifest")
        } else {
            XCTAssertEqual(ScanSettings.current, .defaults, "Not signed with the app's key: nothing changes")
            XCTAssertEqual(ScanSettings.source, .builtIn)
        }
    }

    // MARK: A changed setting changes what the scan offers

    private static func point(_ id: String, _ utc: String, _ lat: Double, _ lon: Double) -> PhotoPoint {
        PhotoPoint(id: id, date: ISO8601DateFormatter().date(from: utc)!, latitude: lat, longitude: lon)
    }

    /// A tour of Stamford Bridge: six photos inside the fence over forty minutes, the hotel two hours before (`AirborneTests`).
    private var tour: [PhotoPoint] {
        [Self.point("hotel", "2026-03-25T09:00:00Z", 51.5010, -0.1920)]
            + (0..<6).map { n in
                Self.point("stand-\(n)", "2026-03-25T11:\(String(format: "%02d", n * 8)):00Z",
                           51.4815 + Double(n) * 0.0001, -0.1915 + Double(n) * 0.0002)
            }
    }

    private func scan(_ points: [PhotoPoint]) async -> (ScanModel, ScanModel.Review) {
        let scan = ScanModel(ledgerURL: ledgerURL, pendingURL: pendingURL, photos: .init(
            access: { true },
            discover: { venues, existing, _ in PhotoMatcher.found(in: points, venues: venues, existing: existing) },
            look: { _, _ in .init() },
            suggest: { _, _, _, _, _, _ in [] }))
        scan.start(library: library)
        await scan.finished()
        return (scan, scan.takeForReview(library: library))
    }

    func testADwellOfAnHourDropsAFortyMinuteTour() async throws {
        // Today's rule: three photos inside the fence over twenty minutes, so the forty-minute tour is offered.
        let visit = try XCTUnwrap(PhotoMatcher.found(in: tour, venues: library.venues, existing: []).visits.first)
        XCTAssertTrue(visit.isStadiumVisit(.defaults))
        var (scan, review) = await scan(tour)
        XCTAssertEqual(review.others.count, 1, "Offered as a stadium visit at the defaults")
        XCTAssertEqual(scan.skippedVisits, 0)

        // The same photos under a pack that asks for an hour: not a stadium visit, dropped on the spot, nowhere else either.
        var hour = ScanSettings.defaults
        hour.version = 2
        hour.dwellMinutes = 60
        XCTAssertFalse(visit.isStadiumVisit(hour))
        let waiting = await ScanModel.waitingDay(visit, venues: library.venues, settings: hour)
        XCTAssertNil(waiting, "The background search judges by the same settings")
        XCTAssertEqual(ScanCheck.visitLine(visit, settings: hour), "stadium visit: 6 photos inside the fence over 40 min \u{2014} fewer than 2 or under 60 min, dropped")

        ScanSettings.install(hour, source: .pack)
        (scan, review) = await self.scan(tour)
        XCTAssertTrue(review.others.isEmpty, "The scan reads the installed settings")
        XCTAssertEqual(scan.skippedVisits, 1)
        XCTAssertTrue(scan.pendingVisits.isEmpty)
        XCTAssertEqual(ScanCheck.settingsLines().first, "Settings: v2 (pack)")
        XCTAssertEqual(ScanCheck.settingsLines().dropFirst().first, "  changed: dwellMinutes: 60 (default 0)")
    }

    /// The fence tiers are settings too: a wider default fence takes in the bar across the street.
    func testAWiderFenceTakesInThePhotoAcrossTheStreet() throws {
        let wrigley = try XCTUnwrap(library.venue("wrigley"))
        XCTAssertNil(VisitGrouping.nearestVenue(lat: wrigley.latitude + 0.0027, lon: wrigley.longitude, in: library.venues),
                     "300 m north is outside the 200 m fence")
        var wide = ScanSettings.defaults
        wide.fenceMeters = 400
        XCTAssertEqual(wrigley.geofence(wide), 400)
        XCTAssertEqual(VisitGrouping.nearestVenue(lat: wrigley.latitude + 0.0027, lon: wrigley.longitude, in: library.venues, settings: wide)?.id,
                       wrigley.id)
        XCTAssertEqual(VenueIndex(library.venues, settings: wide).nearest(lat: wrigley.latitude + 0.0027, lon: wrigley.longitude)?.id, wrigley.id)
        XCTAssertEqual(library.venue("monza")?.geofence(wide), 1200, "A circuit's own fence always wins")
    }
}
