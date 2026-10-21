import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Witness

/// The renderer writes a real MP4 of the planned length at the story size, hands the same file back the second time, and
/// carries a clip's own sound when there is one.
struct RecapRendererTests {
    private let refs: [PhotoRef] = [.bundled("wrigley-night"), .bundled("wrigley-bleachers"), .bundled("wrigley-scoreboard")]

    private func removeCached(_ gameId: String) {
        if let files = try? FileManager.default.contentsOfDirectory(at: RecapRenderer.folder, includingPropertiesForKeys: nil) {
            for f in files where f.lastPathComponent.hasPrefix(gameId) { try? FileManager.default.removeItem(at: f) }
        }
    }

    @Test func rendersThreeBundledPhotosToAStoryMP4AndThenHitsTheCache() async throws {
        let gameId = "recap-test-" + UUID().uuidString
        defer { removeCached(gameId) }
        let plan = RecapEdit.plan(media: refs.map { RecapMedia(ref: $0) }, cover: refs[0])
        let key = RecapCacheKey(gameId: gameId, refs: refs, score: nil, reduceMotion: false)
        let steps = Steps()

        let first = try await RecapRenderer.render(plan, key: key, artwork: RecapArtwork()) { steps.add($0) }
        #expect(!first.fromCache)
        #expect(!first.hasAudio)
        #expect(FileManager.default.fileExists(atPath: first.url.path))
        #expect(first.url.pathExtension == "mp4")
        #expect(first.url.lastPathComponent.hasPrefix(gameId + "-"))
        let seen = steps.values
        #expect(!seen.isEmpty && seen.last == 1, "progress ran to one: \(seen.suffix(3))")

        let asset = AVURLAsset(url: first.url)
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - plan.duration) < 0.1, "the file runs the planned \(plan.duration) s, not \(seconds)")
        #expect(seconds >= 10 && seconds <= 15)
        let video = try await asset.loadTracks(withMediaType: .video)
        #expect(video.count == 1)
        let size = try await video[0].load(.naturalSize)
        #expect(size == CGSize(width: 1080, height: 1920))
        #expect(try await asset.loadTracks(withMediaType: .audio).isEmpty)

        let before = steps.values.count
        let second = try await RecapRenderer.render(plan, key: key, artwork: RecapArtwork()) { steps.add($0) }
        #expect(second.fromCache)
        #expect(second.url == first.url)
        #expect(steps.values.count == before, "a cached film reports no progress")
    }

    @Test func aStaleCutOfTheSameGameIsRemoved() async throws {
        let gameId = "recap-stale-" + UUID().uuidString
        defer { removeCached(gameId) }
        try FileManager.default.createDirectory(at: RecapRenderer.folder, withIntermediateDirectories: true)
        let stale = RecapRenderer.folder.appending(path: gameId + "-old.mp4")
        try Data("x".utf8).write(to: stale)
        let plan = RecapEdit.plan(media: [], cover: nil)
        let key = RecapCacheKey(gameId: gameId, refs: [], score: nil, reduceMotion: false)
        let result = try await RecapRenderer.render(plan, key: key, artwork: RecapArtwork()) { _ in }
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(FileManager.default.fileExists(atPath: result.url.path))
    }

    @Test func aClipBringsItsOwnSoundAndTheFilmGetsAnAudioTrack() async throws {
        let gameId = "recap-clip-" + UUID().uuidString
        let clipName = "recap-test-clip.mov"
        let clipURL = URL.documentsDirectory.appending(path: clipName)
        try? FileManager.default.removeItem(at: clipURL)
        defer { removeCached(gameId); try? FileManager.default.removeItem(at: clipURL) }
        try await Self.writeClip(to: clipURL, seconds: 3)

        let media = [RecapMedia(ref: refs[0]), RecapMedia(ref: .file(clipName), isVideo: true, duration: 3), RecapMedia(ref: refs[1])]
        let plan = RecapEdit.plan(media: media, cover: refs[0])
        let clip = try #require(plan.segments.first { if case .clip = $0.content { return true } else { return false } })
        let key = RecapCacheKey(gameId: gameId, refs: media.map(\.ref), score: "2–1", reduceMotion: false)
        let result = try await RecapRenderer.render(plan, key: key, artwork: RecapArtwork()) { _ in }
        #expect(result.hasAudio)

        let asset = AVURLAsset(url: result.url)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        #expect(audio.count == 1)
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - plan.duration) < 0.1)

        // The tone plays inside the clip's segment and nowhere else.
        let levels = try Self.levels(asset, tracks: audio)
        func loud(_ t: TimeInterval) -> Bool { levels.first { abs($0.time - t) < 0.06 }?.level ?? 0 > 500 }
        #expect(loud(clip.start + 1), "sound mid-clip")
        #expect(!loud(clip.start - 0.5), "silence before the clip")
        #expect(!loud(clip.end + 0.5), "silence after the clip")
    }

    /// Progress values, collected from the render queue.
    private final class Steps: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [Double] = []
        func add(_ v: Double) { lock.lock(); list.append(v); lock.unlock() }
        var values: [Double] { lock.lock(); defer { lock.unlock() }; return list }
    }

    /// Peak sample level per decoded audio buffer, with the buffer's time.
    private static func levels(_ asset: AVAsset, tracks: [AVAssetTrack]) throws -> [(time: TimeInterval, level: Int)] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        reader.startReading()
        var out: [(TimeInterval, Int)] = []
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let count = CMBlockBufferGetDataLength(block)
            var bytes = [UInt8](repeating: 0, count: count)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: &bytes)
            let peak = bytes.withUnsafeBytes { $0.bindMemory(to: Int16.self).reduce(0) { max($0, Int(abs(Int32($1)))) } }
            out.append((CMSampleBufferGetPresentationTimeStamp(buffer).seconds, peak))
        }
        return out
    }

    /// A small clip with colour bars and a 440 Hz tone, written with real-time inputs so the two interleave.
    private static func writeClip(to url: URL, seconds: Int) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000])
        video.expectsMediaDataInRealTime = true
        audio.expectsMediaDataInRealTime = true
        writer.add(video)
        writer.add(audio)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        var asbd = AudioStreamBasicDescription(mSampleRate: 44_100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
        let total = 44_100 * seconds
        let samples = (0..<total).map { Int16(sin(Double($0) * 2 * .pi * 440 / 44_100) * 12_000) }
        var cursor = 0
        for i in 0..<(30 * seconds) {
            while !video.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var pixels: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, try #require(adaptor.pixelBufferPool), &pixels)
            let pb = try #require(pixels)
            CVPixelBufferLockBaseAddress(pb, [])
            let ctx = try #require(CGContext(data: CVPixelBufferGetBaseAddress(pb), width: 320, height: 180, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
            ctx.setFillColor(UIColor.systemTeal.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            ctx.setFillColor(UIColor.systemRed.cgColor)
            ctx.fill(CGRect(x: CGFloat(i) * 3, y: 50, width: 40, height: 80))
            CVPixelBufferUnlockBaseAddress(pb, [])
            #expect(adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 30)))
            let upTo = min(total, (i + 1) * 1470)
            while cursor < upTo {
                while !audio.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                let n = min(4096, upTo - cursor)
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 2, blockAllocator: nil, customBlockSource: nil,
                                                   offsetToData: 0, dataLength: n * 2, flags: 0, blockBufferOut: &block)
                let data = try #require(block)
                samples.withUnsafeBytes { raw in
                    if let base = raw.baseAddress { _ = CMBlockBufferReplaceDataBytes(with: base + cursor * 2, blockBuffer: data, offsetIntoDestination: 0, dataLength: n * 2) }
                }
                var sample: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: data, formatDescription: try #require(format), sampleCount: n,
                                                                     presentationTimeStamp: CMTime(value: CMTimeValue(cursor), timescale: 44_100),
                                                                     packetDescriptions: nil, sampleBufferOut: &sample)
                #expect(audio.append(try #require(sample)))
                cursor += n
            }
        }
        video.markAsFinished()
        audio.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed, "\(String(describing: writer.error))")
    }
}
