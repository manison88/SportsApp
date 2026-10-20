import SwiftUI
import Testing
import UIKit
@testable import Witness

/// A share card is exported as a real file: opaque sRGB, the format's exact pixel size, a readable name, a sane size.
@MainActor
struct ShareExportTests {
    private func card(_ scheme: ColorScheme) -> some View {
        ShareCardFrame(format: .story, accent: Color(hex: "C8102E")) {
            VStack(alignment: .leading) {
                Text("12").font(.display(400)).foregroundStyle(Color.primaryText)
                Text("GAMES").font(.display(120)).foregroundStyle(Color.signal)
            }
        }
    }

    private func check(_ export: ShareCardExport, format: ShareCardFormat) throws {
        let url = export.pngURL
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "png")
        let image = try #require(UIImage(contentsOfFile: url.path))
        #expect(Int(image.size.width * image.scale) == Int(format.size.width))
        #expect(Int(image.size.height * image.scale) == Int(format.size.height))
        let cg = try #require(image.cgImage)
        #expect([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(cg.alphaInfo), "no alpha channel: \(cg.alphaInfo.rawValue)")
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(bytes < 8_000_000)
    }

    @Test func storyCardExportsAsOpaqueFileInBothLooks() throws {
        for scheme in [ColorScheme.light, .dark] {
            let export = try #require(renderShareImage(card(scheme), format: .story, scheme: scheme,
                                                       name: ShareCardExport.fileName(["Test", "Number", scheme == .light ? "light" : "dark"])))
            try check(export, format: .story)
            #expect(export.pngURL.lastPathComponent.hasPrefix("Witness-Test-Number"))
        }
    }

    @Test func lightAndDarkLooksDiffer() throws {
        let light = try #require(renderShareImage(card(.light), format: .story, scheme: .light))
        let dark = try #require(renderShareImage(card(.dark), format: .story, scheme: .dark))
        func corner(_ e: ShareCardExport) -> CGFloat {
            var w: CGFloat = 0
            UIColor(cgColor: e.image.pixel(at: CGPoint(x: 900, y: 1500))).getWhite(&w, alpha: nil)
            return w
        }
        #expect(corner(light) > 0.7, "the light card has a light background")
        #expect(corner(dark) < 0.3, "the dark card has a dark background")
    }

    @Test func feedCardKeepsItsAspectRatio() throws {
        let export = try #require(renderShareImage(ShareCardFrame(format: .feed) { Text("1") }, format: .feed, scheme: .light))
        try check(export, format: .feed)
    }

    @Test func largePhotoCardAlsoGetsAJpegUnderTheLimit() throws {
        // A card whose PNG is over the limit (forced low here) also gets a JPEG, which is what goes out.
        let size = ShareCardFormat.story.size
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let photo = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let export = try #require(ShareCardExport(rendered: photo, size: size, name: "Witness-big", pngLimit: 1_000))
        #expect(export.prefersJPEG)
        let jpeg = try #require(export.jpegURL)
        #expect(jpeg.pathExtension == "jpg")
        let image = try #require(UIImage(contentsOfFile: jpeg.path))
        #expect(Int(image.size.width * image.scale) == 1080)
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: jpeg.path)[.size] as? Int)
        #expect(bytes < 8_000_000)
    }

    @Test func fileNamesAreSafe() {
        #expect(ShareCardExport.fileName(["Cubs at Cardinals", "From above"]) == "Witness-Cubs-at-Cardinals-From-above")
        #expect(ShareCardExport.fileName(["a/b:c"]) == "Witness-a-b-c")
    }

    @Test func theFileIsRemovedWhenTheExportIsReleased() throws {
        var export: ShareCardExport? = renderShareImage(card(.dark), format: .story, scheme: .dark)
        let url = try #require(export?.pngURL)
        #expect(FileManager.default.fileExists(atPath: url.path))
        export = nil
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}

private extension UIImage {
    /// The color of one pixel (point in pixels, scale 1).
    func pixel(at p: CGPoint) -> CGColor {
        guard let cg = cgImage, let data = cg.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return UIColor.black.cgColor }
        let bpp = cg.bitsPerPixel / 8
        let offset = Int(p.y) * cg.bytesPerRow + Int(p.x) * bpp
        return UIColor(red: CGFloat(ptr[offset]) / 255, green: CGFloat(ptr[offset + 1]) / 255, blue: CGFloat(ptr[offset + 2]) / 255, alpha: 1).cgColor
    }
}
