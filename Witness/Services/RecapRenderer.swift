import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import Metal
import Photos
import UIKit

/// The pictures the film needs that only the UI can draw: the title and end cards, the time chips, and a backdrop for a
/// game with no photos. All drawn once, at the film's pixel size for the cards and at their own size for the chips.
struct RecapArtwork: @unchecked Sendable {
    var title: CGImage?
    var end: CGImage?
    /// By segment id. A chip sits bottom-left over its photo or clip.
    var chips: [Int: CGImage] = [:]
    /// Behind the cards when the plan has no photo to put there.
    var backdrop: CGImage?
}

/// What a finished recap is cached under: the game, its media, the score on the end card, and the motion setting.
struct RecapCacheKey: Hashable, Sendable {
    var gameId: String
    var refs: [PhotoRef]
    var score: String?
    var reduceMotion: Bool

    /// A stable digest of everything that changes the film, so an edit to the game cuts a new one.
    var digest: String {
        var text = "v1|" + refs.map { ref -> String in
            switch ref {
            case .bundled(let n): "b:\(n)"
            case .library(let id): "l:\(id)"
            case .file(let n): "f:\(n)"
            }
        }.joined(separator: "|")
        text += "|s:\(score ?? "-")|m:\(reduceMotion ? 1 : 0)"
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    var fileName: String { "\(gameId)-\(digest).mp4" }
}

struct RecapRenderResult: Sendable {
    let url: URL
    let hasAudio: Bool
    let fromCache: Bool
}

enum RecapRenderError: Error {
    case writer(String)
    case noFrames
}

/// Renders a `RecapEdit` to an MP4 (1080×1920, 30 fps, H.264, AAC when a clip brings sound) with AVAssetWriter, composing
/// every frame in Core Image: the photos with their Ken Burns move, the clips scaled to fill, a dissolve between segments,
/// the warm grade and the dark foot of today's film, the cards and chips on top. Finished films are kept in Caches/recaps.
enum RecapRenderer {
    static let size = CGSize(width: 1080, height: 1920)
    static let fps: Int32 = 30
    static let sampleRate: Double = 44_100

    static var folder: URL {
        URL.cachesDirectory.appending(path: "recaps", directoryHint: .isDirectory)
    }

    /// The film for this plan, from the cache when the same cut was rendered before. `progress` is 0…1 and is not called
    /// for a cached film. Cancelling the task stops the render and leaves nothing behind.
    static func render(_ plan: RecapEdit, key: RecapCacheKey, artwork: RecapArtwork,
                       progress: @escaping @Sendable (Double) -> Void) async throws -> RecapRenderResult {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: key.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return RecapRenderResult(url: url, hasAudio: try await hasAudioTrack(url), fromCache: true)
        }
        // Stale cuts of the same game go; the fan only ever plays the current one.
        if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for f in files where f.lastPathComponent.hasPrefix(key.gameId + "-") && f != url {
                try? FileManager.default.removeItem(at: f)
            }
        }
        let sources = try await Sources.load(plan, artwork: artwork)
        try Task.checkCancellation()
        let temp = folder.appending(path: UUID().uuidString + ".mp4")
        let job = Job(plan: plan, sources: sources, output: temp, progress: progress)
        do {
            try await job.run()
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
        return RecapRenderResult(url: url, hasAudio: sources.hasAudio, fromCache: false)
    }

    static func hasAudioTrack(_ url: URL) async throws -> Bool {
        !(try await AVURLAsset(url: url).loadTracks(withMediaType: .audio)).isEmpty
    }

    // MARK: Sources

    /// A clip ready to play: its asset, the range to take, the video track's orientation, and its sound as PCM.
    struct Clip: @unchecked Sendable {
        let asset: AVAsset
        let track: AVAssetTrack
        let range: CMTimeRange
        let orientation: CGImagePropertyOrientation
        /// 16-bit stereo interleaved at `sampleRate`, exactly the segment's length (shorter when the clip ran out).
        let audio: Data?
    }

    /// Everything loaded before a single frame is written: stills at frame size with the warm grade burned in, clips
    /// with their sound, and the artwork as CIImages.
    struct Sources: @unchecked Sendable {
        var stills: [PhotoRef: CIImage] = [:]
        var clips: [Int: Clip] = [:]
        var title: CIImage?
        var end: CIImage?
        var chips: [Int: CIImage] = [:]
        var backdrop: CIImage?
        var hasAudio: Bool { clips.values.contains { $0.audio != nil } }

        static func load(_ plan: RecapEdit, artwork: RecapArtwork) async throws -> Sources {
            var s = Sources()
            s.title = artwork.title.map { CIImage(cgImage: $0) }
            s.end = artwork.end.map { CIImage(cgImage: $0) }
            s.backdrop = artwork.backdrop.map { Grade.apply(cover(CIImage(cgImage: $0))) }
            for (id, chip) in artwork.chips { s.chips[id] = CIImage(cgImage: chip) }
            for segment in plan.segments {
                try Task.checkCancellation()
                switch segment.content {
                case .still(let ref, _):
                    if s.stills[ref] == nil, let image = await PhotoLoader.load(ref, size: size), let cg = normalized(image) {
                        s.stills[ref] = Grade.apply(cover(CIImage(cgImage: cg)))
                    }
                case .clip(let ref, let inPoint, let duration):
                    if let clip = await loadClip(ref, inPoint: inPoint, duration: duration, segment: segment.duration) {
                        s.clips[segment.id] = clip
                    }
                case .title, .end:
                    break
                }
            }
            return s
        }

        /// A CGImage the right way up (a file from the camera can carry its orientation as a flag).
        private static func normalized(_ image: UIImage) -> CGImage? {
            if image.imageOrientation == .up, let cg = image.cgImage { return cg }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }.cgImage
        }

        private static func loadClip(_ ref: PhotoRef, inPoint: TimeInterval, duration: TimeInterval, segment: TimeInterval) async -> Clip? {
            guard let asset = await videoAsset(ref) else { return nil }
            guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
            let length = (try? await asset.load(.duration).seconds) ?? 0
            let start = min(inPoint, max(0, length - duration))
            let take = max(0.1, min(duration, length - start))
            let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                    duration: CMTime(seconds: take, preferredTimescale: 600))
            let transform = (try? await videoTrack.load(.preferredTransform)) ?? .identity
            let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            var audio: Data?
            if !audioTracks.isEmpty {
                audio = readAudio(asset, tracks: audioTracks, range: range, frames: Int(segment * sampleRate))
            }
            return Clip(asset: asset, track: videoTrack, range: range, orientation: orientation(of: transform), audio: audio)
        }

        private static func videoAsset(_ ref: PhotoRef) async -> AVAsset? {
            switch ref {
            case .bundled:
                return nil
            case .file(let name):
                let url = URL.documentsDirectory.appending(path: name)
                return FileManager.default.fileExists(atPath: url.path) ? AVURLAsset(url: url) : nil
            case .library(let id):
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
                      asset.mediaType == .video else { return nil }
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                return await withCheckedContinuation { continuation in
                    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { av, _, _ in
                        continuation.resume(returning: av)
                    }
                }
            }
        }

        /// How a track's preferred transform turns the decoded frames (phones shoot portrait as rotated landscape).
        private static func orientation(of t: CGAffineTransform) -> CGImagePropertyOrientation {
            if t.a == 0, t.b == 1, t.c == -1, t.d == 0 { return .right }
            if t.a == 0, t.b == -1, t.c == 1, t.d == 0 { return .left }
            if t.a == -1, t.d == -1 { return .down }
            return .up
        }

        /// The clip's sound over `range` as 16-bit stereo PCM, at most `frames` long.
        private static func readAudio(_ asset: AVAsset, tracks: [AVAssetTrack], range: CMTimeRange, frames: Int) -> Data? {
            guard frames > 0, let reader = try? AVAssetReader(asset: asset) else { return nil }
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
            let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: settings)
            guard reader.canAdd(output) else { return nil }
            reader.add(output)
            reader.timeRange = range
            guard reader.startReading() else { return nil }
            let bytesPerFrame = 4
            var pcm = Data(count: frames * bytesPerFrame)
            var got = false
            while let buffer = output.copyNextSampleBuffer() {
                guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                let offset = Int(((pts - range.start).seconds * sampleRate).rounded())
                let count = CMBlockBufferGetDataLength(block)
                var bytes = [UInt8](repeating: 0, count: count)
                guard CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: &bytes) == kCMBlockBufferNoErr else { continue }
                // Frames before the in point are skipped; frames past the segment are dropped.
                let skip = max(0, -offset) * bytesPerFrame
                let at = max(0, offset) * bytesPerFrame
                guard skip < count, at < pcm.count else { continue }
                let n = min(count - skip, pcm.count - at)
                pcm.replaceSubrange(at..<(at + n), with: bytes[skip..<(skip + n)])
                got = true
            }
            reader.cancelReading()
            return got ? pcm : nil
        }
    }

    // MARK: Frame geometry

    static var frame: CGRect { CGRect(origin: .zero, size: size) }

    /// Scales and crops an image to fill the frame, centred.
    static func cover(_ image: CIImage) -> CIImage {
        let e = image.extent
        guard e.width > 0, e.height > 0 else { return image }
        let scale = max(size.width / e.width, size.height / e.height)
        let w = e.width * scale, h = e.height * scale
        let t = CGAffineTransform(translationX: -e.minX, y: -e.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (size.width - w) / 2, y: (size.height - h) / 2))
        return image.transformed(by: t).cropped(to: frame)
    }

    /// The part of a frame-sized image in `unit` (unit coordinates), blown up to fill the frame.
    static func zoom(_ image: CIImage, to unit: CGRect) -> CIImage {
        let r = CGRect(x: unit.minX * size.width, y: unit.minY * size.height, width: unit.width * size.width, height: unit.height * size.height)
        guard r.width > 0 else { return image }
        let scale = size.width / r.width
        let t = CGAffineTransform(translationX: -r.minX, y: -r.minY).concatenating(CGAffineTransform(scaleX: scale, y: scale))
        return image.clampedToExtent().transformed(by: t).cropped(to: frame)
    }

    static func lerp(_ a: CGRect, _ b: CGRect, _ p: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * p, y: a.minY + (b.minY - a.minY) * p,
               width: a.width + (b.width - a.width) * p, height: a.height + (b.height - a.height) * p)
    }

    /// Ease in and out, so a move starts and settles softly.
    static func ease(_ p: Double) -> Double {
        let x = min(1, max(0, p))
        return x * x * (3 - 2 * x)
    }

    // MARK: Grade

    /// Today's film's look: a faint warm overlay on the picture, and a dark letterbox gradient (heavier at the foot, where
    /// the chip and the cards sit). The overlay is burned into each still once; the gradient goes on every frame.
    enum Grade {
        static let warm: CIImage = CIImage(color: CIColor(red: 0x3A / 255, green: 0x1E / 255, blue: 0, alpha: 0.18)).cropped(to: frame)

        static let letterbox: CIImage = {
            let space = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return CIImage.empty() }
            // The stops of the old film's grade, top to bottom: drawn from the top edge down.
            let stops: [(CGFloat, CGFloat)] = [(0, 0.75), (0.16, 0), (0.42, 0), (0.78, 0.85), (1, 1)]
            let colors = stops.map { CGColor(colorSpace: space, components: [0, 0, 0, $0.1]) ?? CGColor(gray: 0, alpha: $0.1) } as CFArray
            let locations = stops.map(\.0)
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return CIImage.empty() }
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            guard let cg = ctx.makeImage() else { return CIImage.empty() }
            return CIImage(cgImage: cg)
        }()

        /// The warm overlay on a frame-sized picture.
        static func apply(_ image: CIImage) -> CIImage {
            let f = CIFilter.overlayBlendMode()
            f.inputImage = warm
            f.backgroundImage = image
            return (f.outputImage ?? image).cropped(to: frame)
        }

        /// A darker wash behind a card so its type reads over anything.
        static let cardShade: CIImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.45)).cropped(to: frame)
    }

    // MARK: Job

    /// One render: decodes clips as they come up, composes each frame, feeds the writer. The writer asks for media on
    /// `queue`, where all of the job's state lives; the drive runs on a global queue so it can wait for the inputs.
    final class Job: @unchecked Sendable {
        private let plan: RecapEdit
        private let sources: Sources
        private let output: URL
        private let progress: @Sendable (Double) -> Void
        private let queue = DispatchQueue(label: "app.witness.recap-render", qos: .userInitiated)
        private var frameIndex = 0
        private var audioCursor = 0
        private var failure: Error?
        // No working colour space option here: with one set, rendering into the writer's buffers ran ten times slower.
        private let context: CIContext = {
            let options: [CIContextOption: Any] = [.cacheIntermediates: false]
            if let device = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: device, options: options) }
            return CIContext(options: options)
        }()
        private let black = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: RecapRenderer.frame)
        private var readers: [Int: ClipReader] = [:]
        private var cancelled = false

        init(plan: RecapEdit, sources: Sources, output: URL, progress: @escaping @Sendable (Double) -> Void) {
            self.plan = plan
            self.sources = sources
            self.output = output
            self.progress = progress
        }

        func run() async throws {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try self.write()
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } onCancel: {
                queue.async { self.cancelled = true }
            }
        }

        private func write() throws {
            let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 9_000_000,
                    AVVideoExpectedSourceFrameRateKey: Int(fps),
                    AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ])
            videoInput.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ])
            guard writer.canAdd(videoInput) else { throw RecapRenderError.writer("video input refused") }
            writer.add(videoInput)

            var audioInput: AVAssetWriterInput?
            if sources.hasAudio {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000,
                ])
                input.expectsMediaDataInRealTime = false
                guard writer.canAdd(input) else { throw RecapRenderError.writer("audio input refused") }
                writer.add(input)
                audioInput = input
            }

            guard writer.startWriting() else { throw RecapRenderError.writer(writer.error?.localizedDescription ?? "could not start") }
            writer.startSession(atSourceTime: .zero)

            let totalFrames = Int((plan.duration * Double(fps)).rounded())
            guard totalFrames > 0 else { throw RecapRenderError.noFrames }
            let group = DispatchGroup()

            group.enter()
            videoInput.requestMediaDataWhenReady(on: queue) { [self] in
                while videoInput.isReadyForMoreMediaData {
                    if cancelled { failure = CancellationError(); videoInput.markAsFinished(); group.leave(); return }
                    if writer.status != .writing {
                        failure = RecapRenderError.writer(writer.error?.localizedDescription ?? "writer stopped"); videoInput.markAsFinished(); group.leave(); return
                    }
                    if frameIndex >= totalFrames { videoInput.markAsFinished(); group.leave(); return }
                    let time = CMTime(value: CMTimeValue(frameIndex), timescale: fps)
                    do {
                        try append(frame(at: time.seconds), at: time, to: adaptor)
                    } catch {
                        failure = error; videoInput.markAsFinished(); group.leave(); return
                    }
                    frameIndex += 1
                    if frameIndex % 10 == 0 || frameIndex == totalFrames { progress(Double(frameIndex) / Double(totalFrames)) }
                }
            }

            if let audioInput {
                let pcm = audioTimeline()
                let chunk = 4096
                let totalAudioFrames = pcm.count / 4
                group.enter()
                audioInput.requestMediaDataWhenReady(on: queue) { [self] in
                    while audioInput.isReadyForMoreMediaData {
                        if cancelled || audioCursor >= totalAudioFrames || writer.status != .writing { audioInput.markAsFinished(); group.leave(); return }
                        let n = min(chunk, totalAudioFrames - audioCursor)
                        guard let buffer = audioBuffer(pcm, frame: audioCursor, count: n) else {
                            failure = RecapRenderError.writer("audio buffer"); audioInput.markAsFinished(); group.leave(); return
                        }
                        audioInput.append(buffer)
                        audioCursor += n
                    }
                }
            }

            // A frame is milliseconds; a whole film is seconds. Far past that, something is wedged: give up rather than hang.
            let timedOut = group.wait(timeout: .now() + .seconds(Int(plan.duration) * 20 + 60)) == .timedOut
            let failed = queue.sync { () -> Error? in
                readers.removeAll()
                return failure ?? (timedOut ? RecapRenderError.writer("timed out") : nil)
            }
            if let failed {
                writer.cancelWriting()
                throw failed
            }
            let done = DispatchSemaphore(value: 0)
            writer.finishWriting { done.signal() }
            done.wait()
            if writer.status != .completed {
                throw RecapRenderError.writer(writer.error?.localizedDescription ?? "writer failed")
            }
        }

        private func append(_ image: CIImage, at time: CMTime, to adaptor: AVAssetWriterInputPixelBufferAdaptor) throws {
            guard let pool = adaptor.pixelBufferPool else { throw RecapRenderError.writer("no pixel buffer pool") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw RecapRenderError.writer("no pixel buffer") }
            context.render(image, to: buffer, bounds: RecapRenderer.frame, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw RecapRenderError.writer("frame \(time.seconds) refused")
            }
        }

        // MARK: Composing

        /// The picture at `t`: the segment under way, dissolving into the next when both are live.
        private func frame(at t: TimeInterval) -> CIImage {
            let live = plan.segments.filter { t >= $0.start && t < $0.end }
            guard let first = live.first else { return black }
            var image = picture(first, at: t)
            if live.count > 1 {
                let next = live[1]
                let alpha = min(1, max(0, (t - next.start) / RecapEdit.crossfade))
                image = fade(picture(next, at: t), alpha: alpha).composited(over: image)
            }
            // Segments that are over release their decoders.
            for id in Array(readers.keys) where !live.contains(where: { $0.id == id }) { readers[id] = nil }
            return image
        }

        private func picture(_ segment: RecapEdit.Segment, at t: TimeInterval) -> CIImage {
            let p = RecapRenderer.ease((t - segment.start) / segment.duration)
            switch segment.content {
            case .title:
                return card(sources.title, over: backdrop(.first), progress: p)
            case .end:
                return card(sources.end, over: backdrop(.last), progress: p)
            case .still(let ref, let kenBurns):
                var image = sources.stills[ref] ?? black
                if let kenBurns {
                    image = RecapRenderer.zoom(image, to: RecapRenderer.lerp(kenBurns.from, kenBurns.to, p))
                }
                return chip(segment, over: Grade.letterbox.composited(over: image))
            case .clip:
                let image = clipFrame(segment, at: t) ?? black
                return chip(segment, over: Grade.letterbox.composited(over: image))
            }
        }

        private enum Side { case first, last }

        /// The picture behind a card: the first or last photo of the cut, else the game's backdrop, else black.
        private func backdrop(_ side: Side) -> CIImage {
            let stills = plan.segments.compactMap { s -> CIImage? in
                if case .still(let ref, _) = s.content { return sources.stills[ref] }
                return nil
            }
            return (side == .first ? stills.first : stills.last) ?? sources.backdrop ?? black
        }

        private func card(_ card: CIImage?, over backdrop: CIImage, progress p: Double) -> CIImage {
            // A slow settle on the picture behind the card, when the photos move at all.
            let moving = plan.segments.contains { if case .still(_, let kb) = $0.content { return kb != nil } else { return false } }
            var base = backdrop
            if moving {
                let s = 1 / (1 + 0.05 * p)
                base = RecapRenderer.zoom(backdrop, to: CGRect(x: (1 - s) / 2, y: (1 - s) / 2, width: s, height: s))
            }
            var image = Grade.letterbox.composited(over: Grade.cardShade.composited(over: base))
            if let card { image = card.composited(over: image) }
            return image
        }

        private func chip(_ segment: RecapEdit.Segment, over image: CIImage) -> CIImage {
            guard let chip = sources.chips[segment.id] else { return image }
            return chip.transformed(by: CGAffineTransform(translationX: 84, y: 180)).composited(over: image)
        }

        private func fade(_ image: CIImage, alpha: Double) -> CIImage {
            let f = CIFilter.colorMatrix()
            f.inputImage = image
            f.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))
            return f.outputImage ?? image
        }

        private func clipFrame(_ segment: RecapEdit.Segment, at t: TimeInterval) -> CIImage? {
            guard let clip = sources.clips[segment.id] else { return nil }
            if readers[segment.id] == nil { readers[segment.id] = ClipReader(clip) }
            guard let reader = readers[segment.id] else { return nil }
            let source = clip.range.start.seconds + (t - segment.start)
            guard let raw = reader.frame(at: source) else { return nil }
            return Grade.apply(RecapRenderer.cover(raw.oriented(clip.orientation)))
        }

        // MARK: Audio

        /// The whole soundtrack as PCM: each clip's own sound in its segment (up to the dissolve into the next), silence elsewhere.
        private func audioTimeline() -> Data {
            let bytesPerFrame = 4
            let total = Int((plan.duration * sampleRate).rounded())
            var pcm = Data(count: total * bytesPerFrame)
            for segment in plan.segments {
                guard let audio = sources.clips[segment.id]?.audio else { continue }
                let startFrame = Int((segment.start * sampleRate).rounded())
                let room = Int(((segment.duration - RecapEdit.crossfade) * sampleRate).rounded())
                let n = min(audio.count / bytesPerFrame, room, total - startFrame)
                guard n > 0 else { continue }
                let at = startFrame * bytesPerFrame
                pcm.replaceSubrange(at..<(at + n * bytesPerFrame), with: audio.prefix(n * bytesPerFrame))
            }
            return pcm
        }

        private lazy var audioFormat: CMAudioFormatDescription? = {
            var asbd = AudioStreamBasicDescription(mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
                                                   mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                   mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
                                                   mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
            var format: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                                           extensions: nil, formatDescriptionOut: &format)
            return format
        }()

        private func audioBuffer(_ pcm: Data, frame: Int, count: Int) -> CMSampleBuffer? {
            guard let format = audioFormat else { return nil }
            let bytes = count * 4
            var block: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes, blockAllocator: nil,
                                                     customBlockSource: nil, offsetToData: 0, dataLength: bytes, flags: 0,
                                                     blockBufferOut: &block) == kCMBlockBufferNoErr, let block else { return nil }
            let ok = pcm.withUnsafeBytes { raw -> Bool in
                guard let base = raw.baseAddress else { return false }
                return CMBlockBufferReplaceDataBytes(with: base + frame * 4, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes) == kCMBlockBufferNoErr
            }
            guard ok else { return nil }
            var buffer: CMSampleBuffer?
            let pts = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(sampleRate))
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: format,
                                                                 sampleCount: count, presentationTimeStamp: pts,
                                                                 packetDescriptions: nil, sampleBufferOut: &buffer)
            return buffer
        }
    }

    /// Decodes one clip's frames in order and hands back the one showing at any time in its range.
    final class ClipReader {
        private let reader: AVAssetReader?
        private let output: AVAssetReaderTrackOutput?
        private var current: CIImage?
        private var currentTime: TimeInterval = -1
        private var pending: (CIImage, TimeInterval)?
        private var finished = false

        init(_ clip: Clip) {
            guard let reader = try? AVAssetReader(asset: clip.asset) else {
                self.reader = nil
                self.output = nil
                return
            }
            let output = AVAssetReaderTrackOutput(track: clip.track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ])
            output.alwaysCopiesSampleData = false
            reader.timeRange = clip.range
            if reader.canAdd(output) { reader.add(output) }
            self.reader = reader
            self.output = output
            if !reader.startReading() { finished = true }
        }

        deinit { reader?.cancelReading() }

        /// The frame at `time` (seconds into the asset): the latest decoded frame not after it.
        func frame(at time: TimeInterval) -> CIImage? {
            while !finished {
                if let (image, at) = pending {
                    if at > time { break }
                    current = image
                    currentTime = at
                    pending = nil
                }
                guard let buffer = output?.copyNextSampleBuffer() else { finished = true; break }
                guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { continue }
                let at = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
                pending = (CIImage(cvPixelBuffer: pixels), at)
            }
            if current == nil, let (image, at) = pending { current = image; currentTime = at; pending = nil }
            return current
        }
    }
}
