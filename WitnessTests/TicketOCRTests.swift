import XCTest
import UIKit
@testable import Witness

/// Runs the real import path: a rendered ticket image or PDF goes through
/// Vision text recognition, then the parser, exactly as a screenshot or a
/// Ticketmaster PDF would on a phone.
@MainActor
final class TicketOCRTests: XCTestCase {
    private var library: Library!

    private let lines = [
        "ticketmaster",
        "Chicago Cubs vs. Milwaukee Brewers",
        "Sat, Aug 9, 2025 1:20 PM",
        "Wrigley Field, Chicago, IL",
        "SEC 209    ROW 4    SEAT 11",
    ]

    override func setUp() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "ocr-\(UUID().uuidString).json")
        library = Library(storeURL: url)
    }

    private func draw(in rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                                                    .foregroundColor: UIColor.black]
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 40, y: 60 + CGFloat(i) * 70), withAttributes: attrs)
        }
    }

    private func check(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let draft = TicketParser.parse(text, teams: library.allTeams, venues: library.venues,
                                       now: ISO8601DateFormatter().date(from: "2026-10-17T12:00:00Z")!)
        XCTAssertEqual(draft.venueId, "wrigley", "OCR text: \(text)", file: file, line: line)
        XCTAssertEqual(draft.homeTeamId, "mlb-chc", file: file, line: line)
        XCTAssertEqual(draft.awayTeamId, "mlb-mil", file: file, line: line)
        XCTAssertEqual(draft.section, "209", file: file, line: line)
        XCTAssertNotNil(draft.date, file: file, line: line)
    }

    func testScreenshotThroughVision() async throws {
        let size = CGSize(width: 1000, height: 460)
        let image = UIGraphicsImageRenderer(size: size).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
        let text = try await TextRecognizer.text(in: image)
        check(text)
    }

    func testPDFThroughImport() async throws {
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 460)
        let url = FileManager.default.temporaryDirectory.appending(path: "ticket-\(UUID().uuidString).pdf")
        try UIGraphicsPDFRenderer(bounds: rect).writePDF(to: url) { ctx in
            ctx.beginPage()
            draw(in: rect)
        }
        let text = try await TextRecognizer.text(inPDF: url)
        check(text)
    }
}
