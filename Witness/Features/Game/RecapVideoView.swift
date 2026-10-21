import AVFoundation
import Photos
import SwiftUI
import UniformTypeIdentifiers

/// 07 · Recap. A 10–15 second cut of the game's photos and videos, rendered to an MP4 on first open, then played on a
/// loop: tap to pause, share the video itself, or open the share image cards.
struct RecapVideoView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase {
        case rendering(Double)
        case ready(RecapFilm)
        case failed
    }

    @State private var phase: Phase = .rendering(0)
    @State private var attempt = 0
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var paused = false

    var body: some View {
        if let game = library.game(gameId) {
            screen(game)
        } else {
            Color.ink.ignoresSafeArea().onAppear { dismiss() }
        }
    }

    private func screen(_ game: GameEntry) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .rendering(let progress):
                rendering(progress)
            case .failed:
                failed
            case .ready:
                EmptyView()
            }

            // The film sits between the bar and the buttons at its own 9:16, so nothing covers its cards.
            VStack(spacing: 14) {
                HStack {
                    CircleButton(systemName: "xmark", label: "Close") { dismiss() }
                        .accessibilityIdentifier("recap-close")
                    Spacer()
                }
                if case .ready(let film) = phase {
                    playback(film)
                        .aspectRatio(9 / 16, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    controls(game, film: film)
                } else {
                    Spacer()
                }
            }
            .gutter()
            .padding(.bottom, 8)
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .task(id: "\(gameId)-\(attempt)-\(reduceMotion)") { await cut(game) }
        .onDisappear { player?.pause() }
    }

    // MARK: Phases

    private func rendering(_ progress: Double) -> some View {
        VStack(spacing: 18) {
            Text("Cutting your recap…")
                .font(.condensed(.headline, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(Color.signal).frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 180, height: 3)
            .animation(.linear(duration: 0.2), value: progress)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cutting your recap, \(Int(progress * 100)) percent")
    }

    private var failed: some View {
        VStack(spacing: 20) {
            Text("The recap couldn't be cut.")
                .font(.condensed(.headline, weight: .bold))
                .foregroundStyle(.white)
            Button("Retry") { attempt += 1; phase = .rendering(0) }
                .buttonStyle(.secondary)
                .frame(width: 160)
        }
    }

    private func playback(_ film: RecapFilm) -> some View {
        Button {
            paused.toggle()
            if paused { player?.pause() } else { player?.play() }
        } label: {
            ZStack {
                if let player {
                    RecapPlayerLayer(player: player)
                        .clipShape(.rect(cornerRadius: 18))
                }
                if paused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(.black.opacity(0.45), in: .circle)
                        .transition(.opacity)
                }
            }
            .contentShape(.rect)
            .animation(.easeOut(duration: 0.2), value: paused)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(paused ? "Play" : "Pause")
        .accessibilityIdentifier("recap-pause")
    }

    private func controls(_ game: GameEntry, film: RecapFilm) -> some View {
        HStack(spacing: 12) {
            ShareLink(item: film, preview: SharePreview(film.title, image: film.poster.map { Image(uiImage: $0) } ?? Image(systemName: "film"))) {
                Label("Share video", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)
            .simultaneousGesture(TapGesture().onEnded {
                Analytics.shared.track(.photosAction, ["action": "recap_shared"])
            })
            .accessibilityIdentifier("recap-share-video")

            ShareCardSheetLink(kind: "recap", title: "Recap", format: .story, key: gameId, variants: { await recapStoryVariants(game, library) }) {
                Label("Cards", systemImage: "rectangle.portrait.on.rectangle.portrait")
            }
            .buttonStyle(.secondary)
            .frame(width: 140)
            .accessibilityIdentifier("recap-share")
        }
    }

    // MARK: Cutting

    /// Plans the edit from the game's media, draws the cards, renders (or fetches the cached film) and starts playback.
    private func cut(_ game: GameEntry) async {
        player?.pause()
        player = nil
        looper = nil
        paused = false
        phase = .rendering(0)
        let media = await Self.media(game.photos)
        let plan = RecapEdit.plan(media: media, cover: game.heroPhoto, reduceMotion: reduceMotion)
        let artwork = RecapArtwork.make(for: game, plan: plan, library: library)
        let key = RecapCacheKey(gameId: game.id, refs: game.photos, score: RecapText.score(game), reduceMotion: reduceMotion)
        let title = headlineText(game, library).split(separator: "\n").first.map(String.init) ?? "Recap"
        do {
            let result = try await RecapRenderer.render(plan, key: key, artwork: artwork) { p in
                Task { @MainActor in
                    if case .rendering = phase { phase = .rendering(p) }
                }
            }
            if !result.fromCache { Analytics.shared.track(.photosAction, ["action": "recap_rendered"]) }
            guard !Task.isCancelled, let film = RecapFilm(result: result, title: title) else { phase = .failed; return }
            film.poster = await film.makePoster()
            start(film)
            phase = .ready(film)
        } catch is CancellationError {
            // The screen went away mid-render.
        } catch {
            phase = .failed
        }
    }

    private func start(_ film: RecapFilm) {
        let item = AVPlayerItem(url: film.url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = !film.hasAudio
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        queue.play()
    }

    /// What the planner needs to know about each photo or video: when it was shot, and for a video how long it is.
    nonisolated private static func media(_ refs: [PhotoRef]) async -> [RecapMedia] {
        let ids = refs.compactMap { ref -> String? in if case .library(let id) = ref { return id } else { return nil } }
        var assets: [String: PHAsset] = [:]
        if !ids.isEmpty {
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { asset, _, _ in
                assets[asset.localIdentifier] = asset
            }
        }
        return refs.map { ref in
            switch ref {
            case .bundled:
                return RecapMedia(ref: ref)
            case .file(let name):
                let video = ["mov", "mp4", "m4v"].contains((name as NSString).pathExtension.lowercased())
                return RecapMedia(ref: ref, isVideo: video, duration: video ? 2 : 0)
            case .library(let id):
                guard let asset = assets[id] else { return RecapMedia(ref: ref) }
                return RecapMedia(ref: ref, date: asset.creationDate, isVideo: asset.mediaType == .video, duration: asset.duration)
            }
        }
    }
}

/// The rendered film, ready to play and to share as a file named "Witness-<title>.mp4" (a hard link to the cached MP4,
/// so Messages and Instagram get a real video file with a name). The link goes when the film is released.
final class RecapFilm: @unchecked Sendable {
    let url: URL
    let hasAudio: Bool
    let title: String
    let shareURL: URL
    var poster: UIImage?
    private let folder: URL

    init?(result: RecapRenderResult, title: String) {
        self.url = result.url
        self.hasAudio = result.hasAudio
        self.title = title
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("recap-" + UUID().uuidString, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return nil }
        let share = folder.appendingPathComponent(ShareCardExport.fileName([title]) + ".mp4")
        if (try? FileManager.default.linkItem(at: result.url, to: share)) == nil {
            guard (try? FileManager.default.copyItem(at: result.url, to: share)) != nil else { return nil }
        }
        self.shareURL = share
        self.folder = folder
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    /// A frame from just after the title, for the share sheet's preview.
    func makePoster() async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 270, height: 480)
        let time = CMTime(seconds: RecapEdit.titleLength + 0.5, preferredTimescale: 600)
        guard let frame = try? await generator.image(at: time) else { return nil }
        return UIImage(cgImage: frame.image)
    }
}

extension RecapFilm: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .mpeg4Movie) { film in
            SentTransferredFile(film.shareURL, allowAccessingOriginalFile: true)
        }
    }
}

/// A bare player layer: no system controls, the film filling its 9:16 panel.
private struct RecapPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.playerLayer?.videoGravity = .resizeAspectFill
        view.playerLayer?.player = player
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.playerLayer?.player !== player { view.playerLayer?.player = player }
    }
}
