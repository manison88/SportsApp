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
                controls(total: total, game: game)
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
                if let stage = game.bigGame {
                    EventMark(game: game, stage: stage)
                }
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
        if headline.contains("\n") { return headline.uppercased() }
        return headline.uppercased()
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

    private func controls(total: Double, game: GameEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                if !playing, elapsed >= total { elapsed = 0 }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .frame(width: 54, height: 54)
                    .background(Color.panelRaised, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
            }
            .accessibilityLabel(playing ? "Pause" : "Play")
            .accessibilityIdentifier("recap-pause")

            ShareCardSheetLink(kind: "recap", title: "Recap", format: .story, key: gameId, variants: { await storyVariants(game) }) {
                Label("Share story", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("recap-share")
        }
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    // MARK: Story card

    @MainActor
    private func storyVariants(_ game: GameEntry) async -> [ShareCardVariant] {
        var photo: UIImage?
        if let ref = game.photos.first { photo = await PhotoLoader.load(ref) }
        let venue = library.venue(game.venueId)?.name ?? ""
        let day = Fmt.dayAndKickoff(game, in: library.venue(game.venueId)?.tz ?? .current)
        var score = ""
        if game.hasScore, let hs = game.homeScore, let aw = game.awayScore { score = "\(aw)–\(hs)" }
        let accent = library.team(library.rootingTeam(game))?.accent ?? Color.signal
        let title = Self.title(headlineText(game, library))
        let q = quote(game)
        func card(_ style: RecapStoryCard.Style) -> RecapStoryCard {
            RecapStoryCard(style: style, background: photo, accent: accent, title: title, quote: q,
                           venue: venue, day: day, score: score)
        }
        return [
            ShareCardVariant("Photo") { card(.photo) },
            ShareCardVariant("Type") { card(.type) },
            ShareCardVariant("Color") { card(.color) },
            ShareCardVariant("Paper") { card(.paper) },
            ShareCardVariant("Stub") { card(.stub) },
        ]
    }
}

/// The 1080×1920 image shared to stories, in five looks.
private struct RecapStoryCard: View {
    enum Style { case photo, type, color, paper, stub }

    let style: Style
    let background: UIImage?
    let accent: Color
    let title: String
    let quote: String
    let venue: String
    let day: String
    let score: String

    @Environment(\.shareScheme) private var scheme
    private var paperInk: Color { Color.sharePaperInk(scheme) }

    private var footer: String { [venue, day].filter { !$0.isEmpty }.joined(separator: " · ") }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch style {
            case .photo: photoLook
            case .type: typeLook
            case .color: colorLook
            case .paper: paperLook
            case .stub: stubLook
            }
        }
        .frame(width: 1080, height: 1920)
        .shareSurface()
    }

    private func titleText(_ size: CGFloat, _ color: Color, lines: Int = 4) -> some View {
        Text(title)
            .font(.display(size))
            .foregroundStyle(color)
            .lineLimit(lines)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quoteText(_ color: Color) -> some View {
        Text(quote.uppercased())
            .font(.system(size: 56, weight: .bold).width(.condensed))
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func footerText(_ color: Color) -> some View {
        Text(footer.uppercased())
            .font(.system(size: 36, weight: .bold).width(.condensed))
            .tracking(4)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wordmark(_ color: Color) -> some View {
        Text("WITNESS")
            .font(.system(size: 40, weight: .heavy).width(.compressed))
            .tracking(10)
            .foregroundStyle(color)
    }

    private func safe<C: View>(alignment: Alignment = .topLeading, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(width: 1080, height: 1920, alignment: alignment)
    }

    // 1 Full-bleed photo with big type.
    private var photoLook: some View {
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
            safe(alignment: .bottomLeading) {
                Spacer(minLength: 0)
                Rectangle().fill(accent).frame(width: 140, height: 12).padding(.bottom, 44)
                titleText(240, .white)
                quoteText(.white.opacity(0.9)).padding(.top, 40)
                footerText(.white.opacity(0.6)).padding(.top, 28)
                wordmark(.white.opacity(0.9)).padding(.top, 56)
            }
        }
    }

    // 2 Pure type on ink.
    private var typeLook: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
            safe {
                titleText(330, Color.primaryText, lines: 5)
                Spacer(minLength: 40)
                quoteText(Color.primaryText.opacity(0.85))
                footerText(Color.primaryText.opacity(0.55)).padding(.top, 28)
                wordmark(Color.primaryText.opacity(0.9)).padding(.top, 56)
            }
        }
    }

    // 3 Solid team color field.
    private var colorLook: some View {
        ZStack(alignment: .topLeading) {
            accent.deepenedForWhiteText
            safe {
                footerText(.white.opacity(0.8))
                Spacer(minLength: 40)
                titleText(260, .white)
                quoteText(.white).padding(.top, 40)
                wordmark(.white).padding(.top, 56)
            }
        }
    }

    // 4 Light paper, black type, photo as a framed print.
    private var paperLook: some View {
        ZStack(alignment: .topLeading) {
            Color.sharePaper(scheme)
            safe {
                footerText(paperInk.opacity(0.55))
                if let background {
                    paperInk.opacity(0.1)
                        .frame(height: 620)
                        .overlay {
                            Image(uiImage: background)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .padding(.top, 36)
                }
                Spacer(minLength: 36)
                titleText(190, paperInk, lines: 3)
                quoteText(paperInk.opacity(0.7)).padding(.top, 32)
                wordmark(paperInk).padding(.top, 48)
            }
        }
    }

    // 5 Data-forward ticket stub.
    private var stubLook: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            safe {
                wordmark(Color.primaryText.opacity(0.9))
                titleText(150, Color.primaryText, lines: 3).padding(.top, 48)
                Spacer(minLength: 40)
                stubRow("Score", score.isEmpty ? "FINAL" : score, big: true)
                stubRow("Venue", venue, big: false)
                stubRow("Date", day, big: false)
                Rectangle().fill(accent).frame(height: 8).padding(.top, 36)
            }
        }
    }

    private func stubRow(_ label: String, _ value: String, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Color.primaryText.opacity(0.25)).frame(height: 2)
            Text(label.uppercased())
                .font(.system(size: 32, weight: .bold).width(.condensed))
                .tracking(6)
                .foregroundStyle(Color.primaryText.opacity(0.55))
            Text(value.uppercased())
                .font(.display(big ? 200 : 84))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 24)
    }
}
