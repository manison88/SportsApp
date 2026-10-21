import XCTest
@testable import Witness

/// You → Feedback & requests: what leaves the phone, and what the screen makes of the answer.
@MainActor
final class FeedbackTests: XCTestCase {
    override func tearDown() { Feedback.transport = nil }

    func testTheRequestCarriesTheKindTheTrimmedTextAndTheDevice() throws {
        let request = try XCTUnwrap(Feedback.request(kind: .sport, text: "  Add the Bundesliga 2 please \n", contact: nil,
                                                     device: "DEV-1234-5678-9ABC-DEF0", version: "1.0.311", os: "26.1"))
        XCTAssertEqual(request.url?.absoluteString, Backend.base + "/feedback")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-witness-key"), Analytics.key)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["kind"] as? String, "sport")
        XCTAssertEqual(body["text"] as? String, "Add the Bundesliga 2 please")
        XCTAssertEqual(body["device"] as? String, "DEV-1234-5678-9ABC-DEF0")
        XCTAssertEqual(body["v"] as? String, "1.0.311")
        XCTAssertEqual(body["os"] as? String, "26.1")
        XCTAssertNil(body["contact"], "No contact unless given")
    }

    func testEmptyTextIsNoRequestAndLongTextIsClipped() {
        XCTAssertNil(Feedback.request(kind: .feedback, text: "   \n", device: "DEV-1234-5678-9ABC-DEF0", version: "1", os: "26"))
        let long = String(repeating: "x", count: 5_000)
        let request = Feedback.request(kind: .feedback, text: long, device: "DEV-1234-5678-9ABC-DEF0", version: "1", os: "26")
        let body = request?.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual((body?["text"] as? String)?.count, Feedback.maxLength)
    }

    func testSendingReadsTheStatus() async {
        Feedback.transport = { _ in 204 }
        do { try await Feedback.send(kind: .feature, text: "Labels on games") } catch { XCTFail("\(error)") }

        Feedback.transport = { _ in 429 }
        do {
            try await Feedback.send(kind: .feature, text: "Labels on games")
            XCTFail("A 429 is an error")
        } catch {
            XCTAssertEqual(error as? Feedback.SendError, .rejected(429))
        }

        Feedback.transport = { _ in throw URLError(.notConnectedToInternet) }
        do {
            try await Feedback.send(kind: .feature, text: "Labels on games")
            XCTFail("Offline is an error")
        } catch {
            XCTAssertEqual(error as? Feedback.SendError, .offline)
        }

        do {
            try await Feedback.send(kind: .feature, text: "   ")
            XCTFail("Nothing to send")
        } catch {
            XCTAssertEqual(error as? Feedback.SendError, .empty)
        }
    }
}
