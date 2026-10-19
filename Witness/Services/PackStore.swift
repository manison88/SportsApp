import Foundation
import CryptoKit

/// Where downloadable data packs come from. Packs are public reference data (teams, venues, schedules): the app
/// downloads whole packs and matches photos on the phone, so no server ever hears where or when a photo was taken.
enum PackConfig {
    /// Public, read-only host for `manifest.json` and the packs: the Worker's /packs path. Empty (until the Worker is live) turns downloading off.
    static var baseURL: String { Backend.isOnline ? Backend.base + "/packs" : "" }
    /// Base64 Ed25519 public key that signs `manifest.json`. Empty accepts unsigned manifests (development only).
    static let publicKey = "Di9c9bdxUI6yJQ1d5cQ4dvS0H9zxvMds3jjbAn567eU="

    /// `-WitnessPackBaseURL <url>` on the command line (or the defaults key) overrides the built-in host, for testing.
    static var resolvedBaseURL: URL? {
        let override = UserDefaults.standard.string(forKey: "WitnessPackBaseURL")
        let text = (override?.isEmpty == false ? override : nil) ?? baseURL
        return text.isEmpty ? nil : URL(string: text)
    }
}

/// What the server says exists: one entry per pack, with the hash the downloaded bytes must match.
struct PackManifest: Codable, Sendable {
    struct Pack: Codable, Hashable, Sendable {
        let id: String
        let kind: String
        let version: String
        let path: String
        let bytes: Int
        let sha256: String
        var league: String?
        var season: Int?
        var items: Int?
    }

    let schema: Int
    let minAppVersion: String
    let packs: [Pack]
    var generated: String?
    var note: String?
}

private struct PackEnvelope: Codable {
    /// The manifest as JSON text. The signature covers exactly these bytes.
    let body: String
    let signature: String?
}

/// Downloads packs in the background, checks them, and keeps them in Application Support. Everything it hands out is
/// bytes already on the phone, so lookups work offline and a failed download never loses what was there before.
actor PackStore {
    static let shared = PackStore()

    private let directory: URL
    private var manifest: PackManifest?
    private static let etagKey = "WitnessPackManifestETag"

    init(directory: URL? = nil) {
        let dir = directory ?? URL.applicationSupportDirectory.appending(path: "Packs", directoryHint: .isDirectory)
        self.directory = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.manifest = Self.cachedManifest(in: dir)
    }

    // MARK: Reading

    /// The bytes of a pack, from the newest version on disk, or nil if it was never downloaded.
    func data(_ id: String) -> Data? {
        guard let pack = manifest?.packs.first(where: { $0.id == id }) else { return nil }
        if let data = try? Data(contentsOf: file(for: pack)) { return data }
        // A newer version is still downloading: the older copy is better than nothing.
        let prefix = Self.fileStem(id) + "."
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        guard let older = names.filter({ $0.hasPrefix(prefix) && $0.hasSuffix(".json") }).sorted().last else { return nil }
        return try? Data(contentsOf: directory.appending(path: older))
    }

    /// Season packs of one league that are on this phone, for the seasons asked about.
    func schedulePacks(league: String, seasons: ClosedRange<Int>) -> [PackManifest.Pack] {
        (manifest?.packs ?? []).filter { pack in
            pack.kind == "schedule" && pack.league == league && pack.season.map { seasons.contains($0) } == true
                && hasFile(for: pack)
        }
    }

    /// True when this version, or an older one still waiting to be replaced, is on disk.
    private func hasFile(for pack: PackManifest.Pack) -> Bool {
        if FileManager.default.fileExists(atPath: file(for: pack).path) { return true }
        let prefix = Self.fileStem(pack.id) + "."
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.contains { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }
    }

    // MARK: Updating

    /// Fetches the manifest and any packs that are new or changed. Returns true when something new was stored.
    /// Catalog packs go first (they are small). Schedules are fetched for leagues already on the phone (to keep them current) and for
    /// `prefetch` (the leagues of the fan's teams and places); every other league is fetched the first time a lookup needs it (`ensure`).
    @discardableResult
    func refresh(prefetch: Set<String> = []) async -> Bool {
        guard let base = PackConfig.resolvedBaseURL else { return false }
        var request = URLRequest(url: base.appending(path: "manifest.json"))
        request.timeoutInterval = 15
        let defaults = UserDefaults.standard
        if manifest != nil, let tag = defaults.string(forKey: Self.etagKey) {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }

        var target = manifest
        var freshData: Data?
        if http.statusCode == 200 {
            guard let fresh = Self.verified(data), Self.isSupported(fresh) else { return false }
            target = fresh
            freshData = data
        } else if http.statusCode != 304 {
            return false
        }
        guard let target else { return false }

        let onPhone = Set(target.packs.filter { $0.kind == "schedule" && hasFile(for: $0) }.compactMap(\.league))
        let wanted = onPhone.union(prefetch)
        let missing = target.packs.filter { pack in
            !FileManager.default.fileExists(atPath: file(for: pack).path)
                && (pack.kind != "schedule" || pack.league.map(wanted.contains) == true)
        }
            .sorted { a, b in
                if (a.kind == "catalog") != (b.kind == "catalog") { return a.kind == "catalog" }
                return (a.season ?? 0) > (b.season ?? 0)
            }
        var stored = false
        for start in stride(from: 0, to: missing.count, by: 6) {
            let slice = Array(missing[start..<min(start + 6, missing.count)])
            let results = await withTaskGroup(of: (PackManifest.Pack, Data?).self) { group in
                for pack in slice {
                    group.addTask { (pack, await Self.download(pack, from: base)) }
                }
                var out: [(PackManifest.Pack, Data?)] = []
                for await result in group { out.append(result) }
                return out
            }
            for (pack, bytes) in results {
                if let bytes, (try? bytes.write(to: file(for: pack), options: .atomic)) != nil { stored = true }
            }
        }

        // Adopt the new manifest once every catalog pack is here; schedules that are still missing retry next time.
        let catalogReady = target.packs.filter { $0.kind == "catalog" }
            .allSatisfy { FileManager.default.fileExists(atPath: file(for: $0).path) }
        if let freshData, catalogReady {
            manifest = target
            try? freshData.write(to: directory.appending(path: "manifest.json"), options: .atomic)
            if let tag = http.value(forHTTPHeaderField: "ETag") { defaults.set(tag, forKey: Self.etagKey) }
            prune(keeping: target)
            stored = true
        }
        return stored
    }

    /// Downloads the season packs of one league that a lookup needs and the phone does not have yet. They are small, so this runs on
    /// any connection; a failed download changes nothing and the lookup simply uses the live source.
    func ensure(league: String, seasons: ClosedRange<Int>) async {
        guard let base = PackConfig.resolvedBaseURL, let manifest else { return }
        let missing = manifest.packs.filter { pack in
            pack.kind == "schedule" && pack.league == league && pack.season.map { seasons.contains($0) } == true
                && !FileManager.default.fileExists(atPath: file(for: pack).path)
        }
        guard !missing.isEmpty else { return }
        await withTaskGroup(of: (PackManifest.Pack, Data?).self) { group in
            for pack in missing { group.addTask { (pack, await Self.download(pack, from: base, onAnyNetwork: true)) } }
            for await (pack, bytes) in group {
                if let bytes { try? bytes.write(to: file(for: pack), options: .atomic) }
            }
        }
    }

    // MARK: Checks and files (pure, so they can be tested)

    /// The manifest, if its signature holds (when a key is configured) and it decodes.
    static func verified(_ data: Data, publicKey: String = PackConfig.publicKey) -> PackManifest? {
        guard let envelope = try? JSONDecoder().decode(PackEnvelope.self, from: data) else { return nil }
        let body = Data(envelope.body.utf8)
        if !publicKey.isEmpty {
            guard let keyBytes = Data(base64Encoded: publicKey),
                  let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyBytes),
                  let text = envelope.signature, let signature = Data(base64Encoded: text),
                  key.isValidSignature(signature, for: body) else { return nil }
        }
        return try? JSONDecoder().decode(PackManifest.self, from: body)
    }

    /// Schema 1, and the app is at least the manifest's minimum version.
    static func isSupported(_ manifest: PackManifest, appVersion: String? = nil) -> Bool {
        let app = appVersion ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        return manifest.schema == 1 && app.compare(manifest.minAppVersion, options: .numeric) != .orderedAscending
    }

    /// "schedule/baseball-mlb/2024" -> "schedule__baseball-mlb__2024".
    static func fileStem(_ id: String) -> String { id.replacingOccurrences(of: "/", with: "__") }

    private func file(for pack: PackManifest.Pack) -> URL {
        directory.appending(path: "\(Self.fileStem(pack.id)).\(pack.version).json")
    }

    /// One download, checked against the manifest's size and SHA-256 before it is trusted.
    private static func download(_ pack: PackManifest.Pack, from base: URL, onAnyNetwork: Bool = false) async -> Data? {
        let config = URLSessionConfiguration.default
        let background = pack.kind == "schedule" && !onAnyNetwork
        config.allowsExpensiveNetworkAccess = !background
        config.allowsConstrainedNetworkAccess = !background
        config.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(from: base.appending(path: pack.path)),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count == pack.bytes else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == pack.sha256 ? data : nil
    }

    /// Removes files for packs that are gone, and old versions of packs whose current version is on disk.
    private func prune(keeping manifest: PackManifest) {
        let current = Dictionary(uniqueKeysWithValues: manifest.packs.map { (Self.fileStem($0.id), file(for: $0).lastPathComponent) })
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name != "manifest.json" && name.hasSuffix(".json") {
            let trimmed = String(name.dropLast(".json".count))
            guard let dot = trimmed.lastIndex(of: ".") else { continue }
            let stem = String(trimmed[..<dot])
            if let keep = current[stem] {
                if keep != name, FileManager.default.fileExists(atPath: directory.appending(path: keep).path) {
                    try? FileManager.default.removeItem(at: directory.appending(path: name))
                }
            } else {
                try? FileManager.default.removeItem(at: directory.appending(path: name))
            }
        }
    }

    private static func cachedManifest(in directory: URL) -> PackManifest? {
        guard let data = try? Data(contentsOf: directory.appending(path: "manifest.json")) else { return nil }
        return verified(data)
    }
}
