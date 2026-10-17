import SwiftUI

/// 04 · Timeline, the home screen. Every game as a photo card with a ticket stub.
struct TimelineView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @State private var query = ""

    private var games: [GameEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return library.games }
        return library.games.filter { g in
            let words = [headlineText(g, library), matchupText(g, library), library.venue(g.venueId)?.name ?? "",
                         library.venue(g.venueId)?.city ?? "", g.competition ?? "", String(Fmt.year(g.date)),
                         library.team(g.homeTeamId)?.abbreviation ?? "", library.team(g.awayTeamId)?.abbreviation ?? ""]
            return words.joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.block) {
                ForEach(games) { game in
                    NavigationLink(value: Route.game(game.id)) {
                        TimelineCard(game: game)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("game-card-\(game.id)")
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .overlay {
            if library.games.isEmpty {
                EmptyTimeline()
            } else if games.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .inkBackground()
        .navigationTitle("Timeline")
        .searchable(text: $query, prompt: "Teams, places, years")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AddMenu() }
        }
    }
}

/// The one trailing action on the Timeline: every way to get a game in.
struct AddMenu: View {
    @Environment(Presenter.self) private var presenter

    var body: some View {
        Menu {
            Button("Add game", systemImage: "plus") { presenter.modal = .addGame }
            Button("Import ticket", systemImage: "ticket") { presenter.modal = .importTicket }
            Button("Find in photos", systemImage: "photo.on.rectangle.angled") { presenter.modal = .discovery }
            Button("Check in live", systemImage: "dot.radiowaves.left.and.right") { presenter.modal = .live }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
        }
        .accessibilityLabel("Add")
        .accessibilityIdentifier("add-menu")
    }
}

private struct TimelineCard: View {
    @Environment(Library.self) private var library
    let game: GameEntry

    var body: some View {
        let venue = library.venue(game.venueId)
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color.panel
                    .overlay { GameBackdrop(game: game) }
                    .clipped()
                Scrim()
                Text(headlineText(game, library).uppercased())
                    .displayFont(54, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
            .frame(height: 420)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

            TicketStub {
                HStack(spacing: 20) {
                    Text(Fmt.day(game.date, in: venue?.tz ?? .current))
                    if let sec = Self.section(game.seat) { Text(sec) }
                    Spacer(minLength: 0)
                    ScoreBug(game: game)
                }
                .font(.condensed(.headline, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headlineText(game, library)) \(matchupText(game, library)), \(Fmt.dayTitle(game.date))")
    }

    /// "Bleachers · Section 314" -> "SEC 314"
    static func section(_ seat: String?) -> String? {
        guard let seat, !seat.isEmpty else { return nil }
        let pattern = #/(?i)(?:sec(?:tion)?\.?\s*)([A-Z]?\d+[A-Z]?)/#
        if let m = seat.firstMatch(of: pattern) { return "SEC \(m.1)" }
        return seat.count <= 12 ? seat.uppercased() : nil
    }
}

/// The ticket stub under a card: notched corners and a perforated top edge.
private struct TicketStub<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(StubShape().fill(Color.panelRaised))
            .overlay(alignment: .top) {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: rect.width, y: 0)) }
        }
    }

    private struct StubShape: Shape {
        func path(in rect: CGRect) -> Path {
            let r: CGFloat = 22, notch: CGFloat = 10
            var p = Path()
            p.move(to: CGPoint(x: notch, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX - notch, y: 0))
            p.addArc(center: CGPoint(x: rect.maxX, y: 0), radius: notch, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: r, y: rect.maxY))
            p.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: 0, y: notch))
            p.addArc(center: .zero, radius: notch, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            p.closeSubpath()
            return p
        }
    }
}

private struct EmptyTimeline: View {
    @Environment(Presenter.self) private var presenter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Text("YOUR FIRST GAME GOES HERE.")
                .displayFont(56)
                .foregroundStyle(.white)
            VStack(spacing: Spacing.inner) {
                Button("Add a game") { presenter.modal = .addGame }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("empty-add")
                Button("Import a ticket") { presenter.modal = .importTicket }
                    .buttonStyle(.secondary)
                Button("Find games in my photos") { presenter.modal = .discovery }
                    .buttonStyle(.secondary)
            }
        }
        .gutter()
    }
}
