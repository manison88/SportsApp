import SwiftUI

/// The words on a recap: the headline broken for display, the one quote line, a venue's short name.
enum RecapText {
    /// "Down 3–1. Still alive." -> "DOWN 3–1.\nSTILL ALIVE." style line breaks on sentences.
    static func title(_ headline: String) -> String {
        if headline.contains("\n") { return headline.uppercased() }
        return headline.uppercased()
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) + "." }
            .prefix(2)
            .joined(separator: "\n")
    }

    /// The fan's note's first sentence when it is short and not the headline again, else a line about the ground.
    @MainActor
    static func quote(_ game: GameEntry, _ library: Library) -> String {
        let note = game.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let firstHeadline = headlineText(game, library).split(separator: ".").first.map(String.init) ?? ""
        if !note.isEmpty, let first = note.split(separator: ".").first {
            let s = String(first).trimmingCharacters(in: .whitespaces)
            if s.count <= 70, s != firstHeadline { return s + "." }
        }
        return "One more night at \(shortName(library.venue(game.venueId)?.name ?? "the park"))."
    }

    static func shortName(_ name: String) -> String {
        var words = name.split(separator: " ").map(String.init)
        let generic: Set<String> = ["Field", "Stadium", "Park", "Center", "Centre", "Arena", "Ballpark", "Grounds"]
        if words.count > 1, let last = words.last, generic.contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }

    /// "5–3" when the game has a score.
    static func score(_ game: GameEntry) -> String? {
        guard game.hasScore, let hs = game.homeScore, let aw = game.awayScore else { return nil }
        return "\(aw)–\(hs)"
    }
}

// MARK: - Story cards (share images)

/// The five looks of the recap's share image.
@MainActor
func recapStoryVariants(_ game: GameEntry, _ library: Library) async -> [ShareCardVariant] {
    var photo: UIImage?
    if let ref = game.heroPhoto { photo = await PhotoLoader.load(ref) }
    let venue = library.venue(game.venueId)?.name ?? ""
    let day = Fmt.dayAndKickoff(game, in: library.venue(game.venueId)?.tz ?? .current)
    let score = RecapText.score(game) ?? ""
    let accent = library.team(library.rootingTeam(game))?.accent ?? Color.signal
    let title = RecapText.title(headlineText(game, library))
    let q = RecapText.quote(game, library)
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

/// The 1080×1920 image shared to stories, in five looks.
struct RecapStoryCard: View {
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

// MARK: - Film cards (video overlays)

/// The title card of the recap film: the stage for a big game, the headline, the ground and the day. Transparent, laid
/// over the first photo by the renderer, which also supplies the dark foot.
struct RecapTitleCard: View {
    let stage: String?
    let title: String
    let footer: String

    /// "CHICAGO 5, MILWAUKEE 4." breaks at the comma, so a score line never leaves one number alone on the last line.
    private var lines: String {
        title.contains("\n") ? title : title.replacingOccurrences(of: ", ", with: ",\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if let stage, !stage.isEmpty {
                Text(stage.uppercased())
                    .font(.system(size: 40, weight: .heavy).width(.condensed))
                    .tracking(6)
                    .foregroundStyle(Color.signal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.bottom, 28)
            }
            Text(lines)
                .font(.display(190))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(footer.uppercased())
                .font(.system(size: 36, weight: .bold).width(.condensed))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 36)
        }
        .padding(.horizontal, 84)
        .padding(.bottom, 300)
        .frame(width: 1080, height: 1920, alignment: .bottomLeading)
        .environment(\.colorScheme, .dark)
    }
}

/// The end card: the score with the teams' codes, else the ground and the day; the Witness mark under it.
struct RecapEndCard: View {
    let score: String?
    /// "CHC · STL", under the score.
    let teams: String
    let venue: String
    let day: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if let score {
                Text(score)
                    .font(.display(300))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !teams.isEmpty {
                    Text(teams.uppercased())
                        .font(.system(size: 64, weight: .heavy).width(.condensed))
                        .tracking(6)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.top, 8)
                }
                line([venue, day].filter { !$0.isEmpty }.joined(separator: " · "))
                    .padding(.top, 32)
            } else {
                Text(venue.uppercased())
                    .font(.display(160))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                line(day).padding(.top, 32)
            }
            Text("WITNESS")
                .font(.system(size: 40, weight: .heavy).width(.compressed))
                .tracking(10)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 84)
        .padding(.bottom, 300)
        .frame(width: 1080, height: 1920, alignment: .bottomLeading)
        .environment(\.colorScheme, .dark)
    }

    private func line(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 36, weight: .bold).width(.condensed))
            .tracking(4)
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// The small amber time chip in the corner of a photo or clip: "8:12 PM".
struct RecapTimeChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .heavy).width(.condensed))
            .monospacedDigit()
            .foregroundStyle(Color.signal.readableInk)
            .padding(.horizontal, 24)
            .frame(height: 64)
            .background(Color.signal, in: .capsule)
    }
}

// MARK: - Drawing the artwork

extension RecapArtwork {
    /// Draws the cards and chips for a plan, once each, at the film's pixel size.
    @MainActor
    static func make(for game: GameEntry, plan: RecapEdit, library: Library) -> RecapArtwork {
        let tz = library.venue(game.venueId)?.tz ?? .current
        let venue = library.venue(game.venueId)?.name ?? ""
        let day = Fmt.dayTitle(game.date, in: tz)
        var art = RecapArtwork()
        art.title = draw(RecapTitleCard(stage: game.stage?.label, title: RecapText.title(headlineText(game, library)),
                                        footer: [venue, day].filter { !$0.isEmpty }.joined(separator: " · ")))
        let teams = [library.team(game.awayTeamId)?.abbreviation, library.team(game.homeTeamId)?.abbreviation]
            .compactMap { $0 }.joined(separator: " · ")
        art.end = draw(RecapEndCard(score: RecapText.score(game), teams: teams, venue: venue, day: day))
        for segment in plan.segments where segment.isMedia {
            if let date = segment.date { art.chips[segment.id] = draw(RecapTimeChip(text: Fmt.time(date, in: tz)), size: nil) }
        }
        let hasStill = plan.segments.contains { if case .still = $0.content { return true } else { return false } }
        if !hasStill {
            art.backdrop = draw(GameBackdrop(game: game, index: .max).environment(library).frame(width: 1080, height: 1920), opaque: true)
        }
        return art
    }

    @MainActor
    private static func draw<V: View>(_ view: V, size: CGSize? = RecapRenderer.size, opaque: Bool = false) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = opaque
        if let size { renderer.proposedSize = ProposedViewSize(size) }
        return renderer.cgImage
    }
}
