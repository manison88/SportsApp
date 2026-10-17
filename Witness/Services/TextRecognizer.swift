import UIKit
import Vision
import PDFKit

/// On-device text recognition for ticket screenshots and PDFs. Nothing is uploaded.
enum TextRecognizer {
    enum Failure: Error { case unreadable }

    static func text(in image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { throw Failure.unreadable }
        return try await text(in: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
    }

    static func text(in cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            let lines: [String] = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    /// Uses the PDF's own text when it has some (most e-tickets), else OCRs each page.
    static func text(inPDF url: URL) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { throw Failure.unreadable }
        var out: [String] = []
        for i in 0..<min(doc.pageCount, 6) {
            guard let page = doc.page(at: i) else { continue }
            if let s = page.string, s.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 {
                out.append(s)
                continue
            }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = page.thumbnail(of: size, for: .mediaBox)
            if let cg = image.cgImage {
                out.append(try await text(in: cg))
            }
        }
        let joined = out.joined(separator: "\n")
        if joined.isEmpty { throw Failure.unreadable }
        return joined
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
