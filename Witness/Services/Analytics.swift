import Foundation
import Observation
import UIKit

/// The fifteen things the app reports, by the names the analytics Worker accepts. Nothing here carries a photo, a location
/// or a person's name. The properties are short labels and counts ("source": "scan", "found": 0).
enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case onboardingStep = "onboarding_step"
    case scanFinished = "scan_finished"
    case gameAdded = "game_added"
    case gameOpened = "game_opened"
    case photosAction = "photos_action"
    case planTeamSearch = "plan_team_search"
    case planCreated = "plan_created"
    case planAttended = "plan_attended"
    case checkinStarted = "checkin_started"
    case shareOpened = "share_opened"
    /// The Share button was tapped. iOS does not say whether the person then posted.
    case shareTapped = "share_tapped"
    case tabViewed = "tab_viewed"
    case venueOrListOpened = "venue_or_list_opened"
    case settingChanged = "setting_changed"
}

/// Anonymous usage events, sent in small batches to our own analytics Worker (analytics/worker.js). It is off in tests, until the
/// Worker's address is filled in below, and whenever the person turns it off in You.
@Observable
@MainActor
final class Analytics {
    static let shared = Analytics()

    /// Fill in the address printed by the analytics deploy (the analytics-deploy branch, URL.txt), then add "/e".
    static let endpoint = "https://witness-analytics.SUBDOMAIN.workers.dev/e"
    /// Ships inside the app, so it only keeps casual junk out. The Worker validates and limits everything anyway.
    private static let key = "5ujo3n8yQh1uI6jbaVIoUucWMvja2S-9"

    private(set) var enabled: Bool
    @ObservationIgnored private var queue: [[String: Any]] = []
    @ObservationIgnored private var lastOpened = Date.distantPast
    @ObservationIgnored private var flushing = false
    @ObservationIgnored private let device: String
    @ObservationIgnored private let session = UUID().uuidString
    @ObservationIgnored private let active: Bool

    private init() {
        let d = UserDefaults.standard
        enabled = d.object(forKey: "analytics.enabled") as? Bool ?? true
        if let id = d.string(forKey: "analytics.device") {
            device = id
        } else {
            device = UUID().uuidString
            d.set(device, forKey: "analytics.device")
        }
        active = !ProcessInfo.processInfo.arguments.contains("-uitest") && !Self.endpoint.contains("SUBDOMAIN")
    }

    func setEnabled(_ on: Bool) {
        if !on { track(.settingChanged, ["setting": "analytics", "value": "off"]); Task { await flush() } }
        enabled = on
        UserDefaults.standard.set(on, forKey: "analytics.enabled")
        if on { track(.settingChanged, ["setting": "analytics", "value": "on"]) }
    }

    /// Records one event. Cheap: it only queues; sending happens in batches.
    func track(_ event: AnalyticsEvent, _ props: [String: Any] = [:]) {
        guard enabled, active else { return }
        var clean: [String: Any] = [:]
        for (k, v) in props {
            switch v {
            case let s as String: clean[k] = String(s.prefix(80))
            case let n as Int: clean[k] = n
            case let n as Double: clean[k] = (n * 10).rounded() / 10
            case let b as Bool: clean[k] = b
            default: break
            }
        }
        queue.append(["n": event.rawValue, "t": Int(Date().timeIntervalSince1970 * 1000), "p": clean])
        if queue.count >= 15 { Task { await flush() } }
    }

    /// The app came to the front. Counted once per half hour, so switching back and forth is not a new open.
    func opened(games: Int) {
        guard Date().timeIntervalSince(lastOpened) > 30 * 60 else { return }
        lastOpened = Date()
        track(.appOpened, ["games": Self.bucket(games)])
    }

    /// "0", "1-5", "6-20", "21-50", "51+": counts without exact numbers.
    static func bucket(_ n: Int) -> String {
        switch n {
        case ..<1: "0"
        case 1...5: "1-5"
        case 6...20: "6-20"
        case 21...50: "21-50"
        default: "51+"
        }
    }

    /// Sends what is waiting. Events that fail to send stay queued, up to a few hundred.
    func flush() async {
        guard enabled, active, !flushing, !queue.isEmpty, let url = URL(string: Self.endpoint) else { return }
        flushing = true
        defer { flushing = false }
        let batch = Array(queue.prefix(50))
        queue.removeFirst(batch.count)
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") + "."
            + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        let body: [String: Any] = ["device": device, "session": session, "v": version, "os": UIDevice.current.systemVersion, "events": batch]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(Self.key, forHTTPHeaderField: "x-witness-key")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = data
        let ok = (try? await URLSession.shared.data(for: request)).map { ($0.1 as? HTTPURLResponse)?.statusCode == 204 } ?? false
        if !ok { queue.insert(contentsOf: batch, at: 0); queue = Array(queue.prefix(300)) }
    }
}
