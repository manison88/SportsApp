import SwiftUI

/// 09 · You. Lifetime numbers, led by the one that matters: how often your team wins with you there.
struct YouView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @State private var confirmRemove = false

    var body: some View {
        let stats = Stats(library: library)
        let chrono = library.games.sorted { $0.date < $1.date }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                NavigationLink(value: Route.lucky) {
                    HeroCard(stats: stats, city: favoriteCity, color: favoriteColor)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("you-lucky")

                if !chrono.isEmpty {
                    ResultDots(games: chrono, stats: stats, color: favoriteColor)
                }

                VStack(spacing: Spacing.block) {
                    StatRow(items: [
                        .init(value: "\(stats.games)", label: "Games"),
                        .init(value: Fmt.number(stats.miles), label: "Miles"),
                        .init(value: "\(stats.venues)", label: "Venues"),
                    ])
                    StatRow(items: [
                        .init(value: "\(stats.runs)", label: "Runs"),
                        .init(value: stats.coldestF.map { "\(Int($0.rounded()))°F" } ?? "–", label: "Coldest"),
                        .init(value: "\(stats.mlbParks.count)/\(library.ballparks.count)", label: "MLB parks"),
                    ])
                }

                links(stats: stats)
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .tabTitle("You")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(stats)) {
                    Image(systemName: "square.and.arrow.up").fontWeight(.bold)
                }
                .accessibilityLabel("Share your numbers")
            }
        }
        .confirmationDialog("Remove the sample games?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove sample games", role: .destructive) { library.removeSample() }
        }
    }

    @ViewBuilder
    private func links(stats: Stats) -> some View {
        VStack(spacing: 0) {
            if let year = stats.years.last {
                LinkRow(title: "Wrapped \(String(year))", value: nil) { presenter.modal = .wrapped(year) }
                    .accessibilityIdentifier("you-wrapped")
            }
            ForEach(stats.companions.prefix(3)) { c in
                NavigationLink(value: Route.person(c.person.id)) {
                    HStack(spacing: 12) {
                        Avatar(person: c.person, size: 32).accessibilityHidden(true)
                        Text(c.person.name).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                        Spacer()
                        Text("\(c.games) games").font(.subheadline).foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                .accessibilityIdentifier("person-row-\(c.person.id)")
            }
            if library.isSample {
                Button("Remove sample games", role: .destructive) { confirmRemove = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                    .accessibilityIdentifier("you-remove-sample")
            }
        }
    }

    private var favoriteTeam: Team? {
        let ids = library.games.compactMap { library.rootingTeam($0) }
        let top = Dictionary(grouping: ids, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        return library.team(top)
    }

    private var favoriteCity: String { favoriteTeam?.locationName ?? library.profile.homeCity }
    private var favoriteColor: Color { favoriteTeam?.accent ?? Color(hex: "2F6BFF") }

    private func shareText(_ s: Stats) -> String {
        var t = "\(s.games) games, \(s.venues) venues, \(Fmt.number(s.miles)) miles."
        if let r = s.record.rate { t += " \(r.percentText) wins when I'm there." }
        return t
    }
}

private struct HeroCard: View {
    let stats: Stats
    let city: String
    let color: Color

    var body: some View {
        let rate = stats.record.rate
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 2) {
                Text(rate.map { "\(Int(($0 * 100).rounded()))" } ?? "–")
                    .displayFont(200)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("%").displayFont(80).padding(.top, 14)
            }
            Text(line(rate).uppercased())
                .displayFont(34, relativeTo: .title2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color.readableInk)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows you versus the odds")
    }

    private func line(_ rate: Double?) -> String {
        guard let rate else { return "Add a final score to start your record." }
        if rate > 0.5 { return "\(city) wins more when you show up." }
        if rate == 0.5 { return "Dead even when you show up." }
        return "Every game counts. Even these."
    }
}

/// One dot per game, oldest first: filled won, ring lost, half drawn, diamond no result.
private struct ResultDots: View {
    @Environment(Library.self) private var library
    let games: [GameEntry]
    let stats: Stats
    let color: Color

    var body: some View {
        let noResult = games.count - stats.record.decided
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 15), spacing: 10) {
                ForEach(games) { g in
                    dot(library.outcome(g)).aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(stats.record.wins) won, \(stats.record.losses) lost, \(stats.record.draws) drawn")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { legend(noResult) }
                VStack(alignment: .leading, spacing: 8) { legend(noResult) }
            }
            .font(.condensed(.subheadline, weight: .heavy))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder
    private func legend(_ noResult: Int) -> some View {
        Label { Text("\(stats.record.wins) won") } icon: { dot(.win).frame(width: 14, height: 14) }
        Label { Text("\(stats.record.losses) lost") } icon: { dot(.loss).frame(width: 14, height: 14) }
        if stats.record.draws > 0 {
            Label { Text("\(stats.record.draws) drawn") } icon: { dot(.draw).frame(width: 14, height: 14) }
        }
        if noResult > 0 {
            Label { Text("\(noResult) other") } icon: { dot(.none).frame(width: 14, height: 14) }
        }
    }

    @ViewBuilder
    private func dot(_ o: Outcome) -> some View {
        switch o {
        case .win:
            Circle().fill(.white)
        case .loss:
            Circle().strokeBorder(Color.textSecondary, lineWidth: 2)
        case .draw:
            Circle().strokeBorder(.white, lineWidth: 2)
                .overlay { HalfCircle().fill(.white).padding(2) }
        case .none:
            Rectangle().fill(color).rotationEffect(.degrees(45)).scaleEffect(0.7)
        }
    }
}

private struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                     startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()
        }
    }
}

private struct LinkRow: View {
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                Spacer()
                if let value { Text(value).foregroundStyle(Color.textSecondary) }
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
            }
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
