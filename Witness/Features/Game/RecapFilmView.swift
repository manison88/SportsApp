import SwiftUI

/// 07 · Recap film. A slow Ken Burns pass over the game's photos with the
/// headline, one quote line, chapter segments, pause and Share story.
struct RecapFilmView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var elapsed: Double = 0
    @State private var playing = true
    @State private var story: Image?

    private let chapterLength: Double = 4

    var body: some View {
        if let game = library.game(gameId) {
            film(game)
        } else {
            Color.ink.ignoresSafeArea().onAppear { dismiss() }
        }
    }

    private func chapterCount(_ game: GameEntry) -> Int { max(3, game.photos.count) }

    private func film(_ game: GameEntry) -> some View {
        let count = chapterCount(game)
        let total = Double(count) * chapterLength
        let index = min(Int(elapsed / chapterLength), count - 1)
        let local = min(1, max(0, (elapsed - Double(index) * chapterLength) / chapterLength))

        return ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                photoLayer(game, index: index)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(reduceMotion ? 1 : 1 + 0.12 * local)
                    .offset(x: reduceMotion ? 0 : (index.isMultiple(of: 2) ? -14 : 14) * local,
                            y: reduceMotion ? 0 : -8 * local)
                    .clipped()
                    .id(index)
                    .transition(.opacity)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: index)
            .accessibilityHidden(true)

            grade.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    CircleButton(systemName: "xmark", label: "Close") { dismiss() }
                        .accessibilityIdentifier("recap-close")
                    Spacer()
                }
                Spacer(minLength: 0)
                chapterText(game, index: index, count: count)
                    .padding(.bottom, Spacing.block)
                    .animation(.easeInOut(duration: 0.5), value: index)
                progress(count: count, index: index, local: local)
                Text("\(Self.clock(elapsed)) / \(Self.clock(total))")
                    .font(.condensed(.caption, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 8)
                    .accessibilityLabel("\(Int(elapsed)) of \(Int(total)) seconds")
                controls(total: total)
                    .padding(.top, 14)
            }
            .gutter()
            .padding(.bottom, 8)
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .task(id: playing) {
            guard playing else { return }
            var last = Date()
            while !Task.isCancelled && playing {
                try? await Task.sleep(for: .milliseconds(33))
                let now = Date()
                elapsed = min(total, elapsed + now.timeIntervalSince(last))
                last = now
                if elapsed >= total { playing = false }
            }
        }
        .task { await prepareStory(game) }
    }

    // MARK: Layers

    @ViewBuilder
    private func photoLayer(_ game: GameEntry, index: Int) -> some View {
        if game.photos.isEmpty {
            GameBackdrop(game: game)
        } else {
            PhotoView(ref: game.photos[index % game.photos.count])
        }
    }

    /// Warm grade, a soft letterbox and a dark foot for the type.
    private var grade: some View {
        ZStack {
            Color(hex: "3A1E00").opacity(0.18).blendMode(.overlay)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.75), location: 0),
                .init(color: .black.opacity(0), location: 0.16),
                .init(color: .black.opacity(0), location: 0.42),
                .init(color: .black.opacity(0.85), location: 0.78),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }

    // MARK: Chapters

    @ViewBuilder
    private func chapterText(_ game: GameEntry, index: Int, count: Int) -> some View {
        let people = game.companionIds.compactMap { library.person($0) }
        if index == 1, game.hasScore, let hs = game.homeScore, let aw = game.awayScore {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(aw)–\(hs)")
                    .displayFont(120)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: 8) {
                    TeamTile(team: library.team(game.awayTeamId))
                    TeamTile(team: library.team(game.homeTeamId))
                    Text(library.venue(game.venueId)?.name ?? "")
                        .font(.condensed(.headline, weight: .heavy))
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .id("score")
        } else if index == count - 1, index > 0, !people.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                AvatarStack(people: people)
                Text("With \(people.namesText)".uppercased())
                    .displayFont(56)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                Text(Fmt.dayTitle(game.date, in: library.venue(game.venueId)?.tz ?? .current))
                    .font(.condensed(.headline, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .id("people")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(Self.title(headlineText(game, library)))
                    .displayFont(96)
                    .lineLimit(4)
                    .minimumScaleFactor(0.4)
                    .accessibilityIdentifier("recap-title")
                    .accessibilityAddTraits(.isHeader)
                Text(quote(game))
                    .font(.condensed(.title3, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .id("title")
        }
    }

    /// "Down 3–1. Still alive." -> "DOWN\n3–1." style line breaks on sentences.
    static func title(_ headline: String) -> String {
        headline.uppercased()
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) + "." }
            .prefix(2)
            .joined(separator: "\n")
    }

    private func quote(_ game: GameEntry) -> String {
        let note = game.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let firstHeadline = headlineText(game, library).split(separator: ".").first.map(String.init) ?? ""
        if !note.isEmpty, let first = note.split(separator: ".").first {
            let s = String(first).trimmingCharacters(in: .whitespaces)
            if s.count <= 70, s != firstHeadline { return s + "." }
        }
        return "One more night at \(Self.shortName(library.venue(game.venueId)?.name ?? "the park"))."
    }

    static func shortName(_ name: String) -> String {
        var words = name.split(separator: " ").map(String.init)
        let generic: Set<String> = ["Field", "Stadium", "Park", "Center", "Centre", "Arena", "Ballpark", "Grounds"]
        if words.count > 1, let last = words.last, generic.contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }

    // MARK: Progress and controls

    private func progress(count: Int, index: Int, local: Double) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule().fill(Color.white)
                            .frame(width: geo.size.width * (i < index ? 1 : (i == index ? local : 0)))
                    }
                }
                .frame(height: 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Chapter \(index + 1) of \(count)")
    }

    private func controls(total: Double) -> some View {
        HStack(spacing: 12) {
            Button {
                if !playing, elapsed >= total { elapsed = 0 }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.panelRaised, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
            }
            .accessibilityLabel(playing ? "Pause" : "Play")
            .accessibilityIdentifier("recap-pause")

            if let story {
                ShareLink(item: story, preview: SharePreview("Witness recap", image: story)) {
                    Label("Share story", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("recap-share")
            } else {
                Button {} label: { Label("Share story", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.primary)
                    .disabled(true)
                    .opacity(0.6)
                    .accessibilityIdentifier("recap-share")
            }
        }
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    // MARK: Story card

    @MainActor
    private func prepareStory(_ game: GameEntry) async {
        var background: UIImage?
        if let ref = game.photos.first { background = await PhotoLoader.load(ref) }
        let card = RecapStoryCard(
            background: background,
            accent: library.team(library.rootingTeam(game))?.accent ?? Color.signal,
            title: Self.title(headlineText(game, library)),
            quote: quote(game),
            footer: [library.venue(game.venueId)?.name, Fmt.dayTitle(game.date, in: library.venue(game.venueId)?.tz ?? .current)]
                .compactMap { $0 }.joined(separator: " · ")
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        if let ui = renderer.uiImage {
            story = Image(uiImage: ui)
        }
    }
}

/// The 1080×1920 image shared to stories.
private struct RecapStoryCard: View {
    let background: UIImage?
    let accent: Color
    let title: String
    let quote: String
    let footer: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [accent.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
            if let background {
                Image(uiImage: background)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.5), location: 0),
                .init(color: .black.opacity(0), location: 0.25),
                .init(color: .black.opacity(0.9), location: 0.72),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 36) {
                Text(title)
                    .font(.display(220))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.4)
                Text(quote.uppercased())
                    .font(.system(size: 52, weight: .bold).width(.condensed))
                    .foregroundStyle(.white.opacity(0.85))
                Text(footer.uppercased())
                    .font(.system(size: 36, weight: .bold).width(.condensed))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.6))
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(8)
                    .foregroundStyle(.white)
                    .padding(.top, 24)
            }
            .padding(90)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}
