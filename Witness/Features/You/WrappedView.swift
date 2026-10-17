import SwiftUI

/// 11 · A season as one story card.
struct WrappedView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let year: Int

    var body: some View {
        let shownYear = resolvedYear
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Wrapped \(String(shownYear))")
                        .font(.condensed(.title3, weight: .heavy))
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.18), in: .circle)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("wrapped-close")
                }
                .padding(.top, 8)

                WrappedCard(year: shownYear, compact: false)
                    .padding(.top, 8)

                Spacer(minLength: Spacing.inner)

                ShareCardSheetLink(title: "Wrapped \(String(shownYear))", format: .story, key: String(shownYear), variants: { await shareVariants(shownYear) }) {
                    Label("Share to story", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("wrapped-share")
                .padding(.bottom, 8)
            }
            .gutter()
            .foregroundStyle(.white)
        }
    }

    private var background: Color {
        let team = library.profile.favoriteTeamIds.compactMap { library.team($0) }.first { $0.sport == .football }
        return (team?.accent ?? Color(hex: "F05A1A")).deepenedForWhiteText
    }

    /// The requested year, or the most recent year with games.
    private var resolvedYear: Int {
        let years = Set(library.games.map { Fmt.year($0.date) })
        if years.contains(year) { return year }
        return years.max() ?? year
    }

    @MainActor
    private func shareVariants(_ y: Int) async -> [ShareCardVariant] {
        let games = library.games.filter { Fmt.year($0.date) == y }
        let stats = Stats(library: library, games: games)
        var photo: UIImage?
        if let ref = WrappedCopy.bestPhoto(games, library) { photo = await PhotoLoader.load(ref) }
        let year = String(y)
        let record = WrappedCopy.record(stats, games: games.count)
        let claim = WrappedCopy.claim(stats, games: games.count, library: library)
        let credit = WrappedCopy.credit(stats, library: library)
        let tint = background
        func card(_ style: WrappedShareCard.Style) -> WrappedShareCard {
            WrappedShareCard(style: style, year: year, record: record, claim: claim, credit: credit, photo: photo, tint: tint)
        }
        return [
            ShareCardVariant("Color") { card(.color) },
            ShareCardVariant("Photo") { card(.photo) },
            ShareCardVariant("Type") { card(.type) },
            ShareCardVariant("Paper") { card(.paper) },
            ShareCardVariant("Stub") { card(.stub) },
        ]
    }
}

/// The wording behind Wrapped, shared by the screen card and the story image.
@MainActor
private enum WrappedCopy {
    static func record(_ stats: Stats, games: Int) -> String {
        stats.record.decided > 0 ? stats.record.text : "\(games)"
    }

    static func city(_ library: Library) -> String {
        library.profile.favoriteTeamIds.compactMap { library.team($0) }.first?.locationName ?? "Your teams"
    }

    static func claim(_ stats: Stats, games: Int, library: Library) -> String {
        let r = stats.record
        guard r.decided > 0 else { return "\(games) games. Every one of them yours." }
        let won = r.wins
        let n = r.decided
        let frac = Double(won) / Double(n)
        let phrase: String
        if won == n { phrase = "every game" }
        else if won == 0 { phrase = "none of the \(n) games" }
        else if abs(frac - 2.0 / 3.0) < 0.04 { phrase = "two of every three games" }
        else if abs(frac - 0.5) < 0.02 { phrase = "half the games" }
        else if abs(frac - 0.75) < 0.03 { phrase = "three of every four games" }
        else if abs(frac - 1.0 / 3.0) < 0.03 { phrase = "one of every three games" }
        else { phrase = "\(won) of the \(n) games" }
        return "\(city(library)) won \(phrase) you walked into."
    }

    static func bestPhoto(_ games: [GameEntry], _ library: Library) -> PhotoRef? {
        let wins = games.filter { library.outcome($0) == .win }.sorted { $0.date < $1.date }
        return (wins + games).first { !$0.photos.isEmpty }?.photos.first
    }

    static func credit(_ stats: Stats, library: Library) -> String {
        let name = library.isSample ? "Sam Okafor" : library.profile.displayName
        if let top = stats.companions.first {
            return "Starring \(name) · with \(top.person.name)"
        }
        return "Starring \(name)"
    }
}

/// The 1080x1920 image shared to stories, in five looks.
private struct WrappedShareCard: View {
    enum Style { case color, photo, type, paper, stub }

    let style: Style
    let year: String
    let record: String
    let claim: String
    let credit: String
    let photo: UIImage?
    let tint: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch style {
            case .color: colorLook
            case .photo: photoLook
            case .type: typeLook
            case .paper: paperLook
            case .stub: stubLook
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    private func safe<C: View>(alignment: Alignment = .topLeading, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(width: 1080, height: 1920, alignment: alignment)
    }

    private func label(_ color: Color) -> some View {
        Text("WRAPPED \(year)")
            .font(.system(size: 44, weight: .heavy).width(.condensed))
            .tracking(8)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func recordText(_ size: CGFloat, _ color: Color) -> some View {
        Text(record)
            .font(.display(size))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func claimText(_ size: CGFloat, _ color: Color) -> some View {
        Text(claim.uppercased())
            .font(.system(size: size, weight: .heavy).width(.condensed))
            .foregroundStyle(color)
            .lineLimit(4)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditText(_ color: Color) -> some View {
        Text(credit.uppercased())
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

    // 1 Team color field: record, claim, a framed photo.
    private var colorLook: some View {
        ZStack(alignment: .topLeading) {
            tint
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
            safe {
                label(.white.opacity(0.85))
                recordText(360, .white).padding(.top, 24)
                claimText(64, .white).padding(.top, 36)
                Spacer(minLength: 40)
                if let photo {
                    Color.black.opacity(0.2)
                        .frame(height: 480)
                        .overlay {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(.rect(cornerRadius: 28))
                        .padding(.bottom, 36)
                }
                creditText(.white.opacity(0.8))
                wordmark(.white.opacity(0.9)).padding(.top, 40)
            }
        }
    }

    // 2 Full-bleed photo with the record over it.
    private var photoLook: some View {
        ZStack(alignment: .bottomLeading) {
            tint
            if let photo {
                Image(uiImage: photo)
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
                label(.white.opacity(0.85))
                Spacer(minLength: 0)
                recordText(420, .white)
                claimText(60, .white.opacity(0.9)).padding(.top, 28)
                creditText(.white.opacity(0.6)).padding(.top, 28)
                wordmark(.white.opacity(0.9)).padding(.top, 48)
            }
        }
    }

    // 3 Giant record on ink.
    private var typeLook: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            LinearGradient(colors: [tint.opacity(0.5), .clear], startPoint: .top, endPoint: .center)
            safe {
                label(.white.opacity(0.85))
                Spacer(minLength: 40)
                recordText(560, .white)
                Spacer(minLength: 40)
                creditText(.white.opacity(0.6))
                wordmark(.white.opacity(0.9)).padding(.top, 40)
            }
        }
    }

    // 4 Light paper, black type, team color rule.
    private var paperLook: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "F4F1EA")
            safe {
                label(.black.opacity(0.6))
                Rectangle().fill(tint).frame(width: 140, height: 12).padding(.top, 36)
                recordText(380, .black).padding(.top, 36)
                claimText(64, .black.opacity(0.85)).padding(.top, 36)
                Spacer(minLength: 40)
                creditText(.black.opacity(0.55))
                wordmark(.black).padding(.top, 40)
            }
        }
    }

    // 5 Data grid: ruled rows.
    private var stubLook: some View {
        ZStack(alignment: .topLeading) {
            Color.ink
            safe {
                wordmark(.white.opacity(0.9))
                Spacer(minLength: 40)
                row("Season", year, size: 160)
                row("Record", record, size: 260)
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().fill(.white.opacity(0.25)).frame(height: 2)
                    claimText(52, .white)
                }
                .padding(.top, 24)
                creditText(.white.opacity(0.6)).padding(.top, 32)
                Rectangle().fill(tint).frame(height: 8).padding(.top, 36)
            }
        }
    }

    private func row(_ name: String, _ value: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(.white.opacity(0.25)).frame(height: 2)
            Text(name.uppercased())
                .font(.system(size: 32, weight: .bold).width(.condensed))
                .tracking(6)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.display(size))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 24)
    }
}

/// The card content, shared by the screen and the rendered story image.
private struct WrappedCard: View {
    @Environment(Library.self) private var library
    let year: Int
    let compact: Bool

    var body: some View {
        let games = library.games.filter { Fmt.year($0.date) == year }
        let stats = Stats(library: library, games: games)
        VStack(alignment: .leading, spacing: Spacing.block - 8) {
            if compact {
                Text("Wrapped \(String(year))")
                    .font(.condensed(.title3, weight: .heavy))
                    .textCase(.uppercase)
            }
            Text(stats.record.decided > 0 ? stats.record.text : "\(games.count)")
                .displayFont(compact ? 120 : 150)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("wrapped-record")

            Text(claim(stats, games: games.count))
                .displayFont(30, relativeTo: .title)
                .textCase(.uppercase)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)

            if let photo = bestPhoto(games) {
                Color.black.opacity(0.2)
                    .frame(height: compact ? 170 : 190)
                    .overlay { PhotoView(ref: photo) }
                    .clipShape(.rect(cornerRadius: 14))
            }

            Text(credit(stats))
                .font(.condensed(.footnote, weight: .heavy))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
        }
    }

    private func claim(_ stats: Stats, games: Int) -> String {
        WrappedCopy.claim(stats, games: games, library: library)
    }

    private func bestPhoto(_ games: [GameEntry]) -> PhotoRef? {
        WrappedCopy.bestPhoto(games, library)
    }

    private func credit(_ stats: Stats) -> String {
        WrappedCopy.credit(stats, library: library)
    }
}
