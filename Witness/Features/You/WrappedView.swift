import SwiftUI

/// 11 · A season as one story card.
struct WrappedView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let year: Int

    @State private var shareImage: Image?

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

                Group {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Wrapped \(String(shownYear))", image: shareImage)) {
                            Label("Share to story", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ShareLink(item: "My \(String(shownYear)) on Witness.") {
                            Label("Share to story", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("wrapped-share")
                .padding(.bottom, 8)
            }
            .gutter()
            .foregroundStyle(.white)
        }
        .task(id: shownYear) { renderShareImage(shownYear) }
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

    private func renderShareImage(_ y: Int) {
        let card = WrappedCard(year: y, compact: true)
            .padding(24)
            .frame(width: 360, height: 640, alignment: .top)
            .background(background)
            .foregroundStyle(.white)
            .environment(library)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = Image(uiImage: ui)
        }
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
                .foregroundStyle(.black.opacity(0.82))
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
                .foregroundStyle(.black.opacity(0.75))
                .frame(maxWidth: .infinity)
        }
    }

    private var city: String {
        library.profile.favoriteTeamIds.compactMap { library.team($0) }.first?.locationName ?? "Your teams"
    }

    private func claim(_ stats: Stats, games: Int) -> String {
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
        return "\(city) won \(phrase) you walked into."
    }

    private func bestPhoto(_ games: [GameEntry]) -> PhotoRef? {
        let wins = games.filter { library.outcome($0) == .win }.sorted { $0.date < $1.date }
        return (wins + games).first { !$0.photos.isEmpty }?.photos.first
    }

    private func credit(_ stats: Stats) -> String {
        let name = library.isSample ? "Sam Okafor" : library.profile.displayName
        if let top = stats.companions.first {
            return "Starring \(name) · with \(top.person.name)"
        }
        return "Starring \(name)"
    }
}
