import SwiftUI

/// The finals, playoffs, tournaments and rivalries you were at.
struct BigGamesView: View {
    @Environment(Library.self) private var library

    private var games: [GameEntry] {
        library.games.filter { $0.bigGame != nil }
            .sorted { a, b in
                let ka = a.bigGame!.kind, kb = b.bigGame!.kind
                return ka == kb ? a.date > b.date : ka < kb
            }
    }

    var body: some View {
        let list = games
        let titles = list.filter { $0.bigGame?.kind == .championship }.count
        let playoffs = list.filter { $0.bigGame?.kind == .playoff }.count

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                HStack(alignment: .center, spacing: 14) {
                    Text("\(list.count)")
                        .displayFont(130)
                        .accessibilityIdentifier("big-games-count")
                    Text(list.count == 1 ? "Big\ngame" : "Big\ngames")
                        .displayFont(40, relativeTo: .title)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                StatRow(items: [
                    .init(value: "\(titles)", label: titles == 1 ? "Title game" : "Title games"),
                    .init(value: "\(playoffs)", label: "Playoffs"),
                    .init(value: "\(list.count - titles - playoffs)", label: "Other"),
                ])

                VStack(spacing: 0) {
                    ForEach(list) { game in
                        NavigationLink(value: Route.game(game.id)) {
                            row(game)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("big-game-\(game.id)")
                    }
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ game: GameEntry) -> some View {
        let stage = game.bigGame!
        let venue = library.venue(game.venueId)
        return HStack(spacing: 12) {
            Image(systemName: stage.kind.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(stage.kind.tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.label)
                    .font(.condensed(.headline, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(stage.kind == .championship ? Color.trophy : .white)
                    .lineLimit(1)
                Text([venue?.name, Fmt.dayTitle(game.date, in: venue?.tz ?? .current)].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ScoreBug(game: game)
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}
