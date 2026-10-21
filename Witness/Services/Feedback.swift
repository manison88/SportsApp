import Foundation
import UIKit

/// What a fan asks for or tells us from You → Feedback & requests. It goes to the Worker's `/feedback` and is listed at
/// `/requests` behind the dashboard password (analytics/worker.js), newest first. A sport or league we are missing is a kind
/// of its own, so those are one list.
enum FeedbackKind: String, CaseIterable, Identifiable {
    case feature, feedback, sport, problem

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feature: "Feature request"
        case .feedback: "Feedback"
        case .sport: "A sport or league"
        case .problem: "Something's wrong"
        }
    }

    var prompt: String {
        switch self {
        case .feature: "What would you like Witness to do?"
        case .feedback: "What do you think?"
        case .sport: "Which sport, league or tournament is missing?"
        case .problem: "What happened, and on which screen?"
        }
    }
}

enum Feedback {
    static let endpoint = Backend.base + "/feedback"
    static let maxLength = 2000

    enum SendError: Error, Equatable {
        case empty
        case offline
        case rejected(Int)
    }

    /// Tests hand in a transport instead of the network: it answers with the status code.
    nonisolated(unsafe) static var transport: (@Sendable (URLRequest) async throws -> Int)?

    /// The same random id the analytics events carry; never a person.
    static var device: String {
        let d = UserDefaults.standard
        if let id = d.string(forKey: "analytics.device") { return id }
        let id = UUID().uuidString
        d.set(id, forKey: "analytics.device")
        return id
    }

    /// The request as sent: trimmed, clipped to `maxLength`, the app's version and the system's, the device id and the key.
    static func request(kind: FeedbackKind, text: String, contact: String? = nil,
                        device: String, version: String, os: String) -> URLRequest? {
        let message = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !message.isEmpty, let url = URL(string: endpoint) else { return nil }
        var body: [String: Any] = ["kind": kind.rawValue, "text": message, "device": device, "v": version, "os": os]
        if let contact = contact?.trimmingCharacters(in: .whitespacesAndNewlines), !contact.isEmpty { body["contact"] = contact }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Analytics.key, forHTTPHeaderField: "x-witness-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    @MainActor
    static func send(kind: FeedbackKind, text: String, contact: String? = nil) async throws {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") + "."
            + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        guard let request = request(kind: kind, text: text, contact: contact, device: device, version: version,
                                    os: UIDevice.current.systemVersion) else { throw SendError.empty }
        let status: Int
        do {
            if let transport {
                status = try await transport(request)
            } else {
                let (_, response) = try await URLSession.shared.data(for: request)
                status = (response as? HTTPURLResponse)?.statusCode ?? 0
            }
        } catch {
            throw SendError.offline
        }
        guard (200..<300).contains(status) else { throw SendError.rejected(status) }
    }
}
