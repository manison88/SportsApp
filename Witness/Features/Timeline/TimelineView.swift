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
                if query.trimmingCharacters(in: .whitespaces).isEmpty { UpcomingSection() }
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
            if library.games.isEmpty && library.plans.isEmpty {
                EmptyTimeline()
            } else if games.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                DuplicateBanner()
                ScanBanner()
            }
        }
        .inkBackground()
        .task { await library.sweepPlans() }
        .tabTitle("Timeline")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Teams, places, years")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.bigGames) {
                    Image(systemName: "flame")
                }
                .accessibilityLabel("Big games")
                .accessibilityIdentifier("timeline-big-games")
            }
            ToolbarItem(placement: .topBarTrailing) { AddMenu() }
        }
    }
}

/// Entries that look like the same game (a scan and an album both added it): offer to combine their photos.
private struct DuplicateBanner: View {
    @Environment(Library.self) private var library
    @State private var confirming = false
    @State private var hidden = false

    var body: some View {
        let groups = library.duplicateGroups
        if !groups.isEmpty && !hidden {
            Button { confirming = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.on.square")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(groups.count == 1 ? "1 game appears twice" : "\(groups.count) games appear twice")
                            .font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                        Text("Same game at the same stadium. Combine their photos?")
                            .font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text("Combine").font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                        .foregroundStyle(Color.signal)
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.panel, in: .rect(cornerRadius: 14))
                .gutter()
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("duplicate-banner")
            .confirmationDialog("Combine duplicate games?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Combine") { for group in groups { library.combine(group) } }
                Button("Not now", role: .cancel) { hidden = true }
            } message: {
                Text("Photos from each copy stay together on one game.")
            }
        }
    }
}

/// The one trailing action on the Timeline: every way to get a game in.
struct AddMenu: View {
    @Environment(Presenter.self) private var presenter

    var body: some View {
        Menu {
            Button("Add game", systemImage: "plus") { presenter.modal = .addGame }
            Button("Plan a game", systemImage: "calendar.badge.plus") { presenter.modal = .planGame }
            Button("Import ticket", systemImage: "ticket") { presenter.modal = .importTicket }
            Button("Find in photos", systemImage: "photo.on.rectangle.angled") { presenter.modal = .discovery }
            Button("Import an album or trip", systemImage: "rectangle.stack.badge.plus") { presenter.modal = .importAlbum }
            Button("Check in live", systemImage: "dot.radiowaves.left.and.right") { presenter.modal = .live }
        } label: {
            Image(systemName: "plus")
                .fontWeight(.bold)
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
        let tz = venue?.tz ?? .current
        let title = game.bigGame?.kind == .championship
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color.panel
                    .overlay { GameBackdrop(game: game) }
                    .clipped()
                Scrim()
                DateBlock(date: game.date, tz: tz, venue: venue, championship: title)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
            .frame(height: 420)
            .overlay(alignment: .topTrailing) {
                if let stage = game.bigGame {
                    EventMark(game: game, stage: stage).padding(16)
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

            TicketStub(trailingInset: 0, minHeight: 100) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Self.firstLine(game, tz: tz))
                                .font(.condensed(.title3, weight: .heavy))
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            if let seat = Self.seatLine(game.seat) {
                                Text(seat)
                                    .font(.condensed(.subheadline, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(Color.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Rectangle().fill(Color.hairline).frame(height: 1)
                        facts
                    }
                    .padding(.trailing, 14)
                    TearOff(game: game)
                }
                .foregroundStyle(.white)
            }
        }
        .overlay {
            // Title games get a champagne keyline around the whole ticket.
            if title {
                RoundedRectangle(cornerRadius: 22).strokeBorder(Color.trophy.opacity(0.7), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .task(id: game.id) {
            // Pick a cover for games with several photos, as their cards scroll into view.
            if !ProcessInfo.processInfo.arguments.contains("-uitest") { await library.autoCover(game.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([game.bigGame?.label, headlineText(game, library), matchupText(game, library), venue?.name, Fmt.dayTitle(game.date)]
            .compactMap { $0 }.joined(separator: ", "))
    }

    // MARK: Stub

    /// Start time when the schedule gave one (a matched game, a ticket, a live check-in), else the date.
    private static func firstLine(_ game: GameEntry, tz: TimeZone) -> String {
        if game.source != nil || game.origin == .ticket || game.origin == .live || game.origin == .sample {
            return Fmt.time(game.date, in: tz)
        }
        return Fmt.day(game.date, in: tz)
    }

    /// "SEC 314 · ROW 8", whichever parts the seat has.
    private static func seatLine(_ seat: String?) -> String? {
        guard let seat, !seat.isEmpty else { return nil }
        let sec = section(seat)
        var parts: [String] = []
        if let sec { parts.append(sec) }
        if let m = seat.firstMatch(of: #/(?i)row\s*([A-Z]?\d+[A-Z]?)/#) { parts.append("ROW \(m.1)") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// Weather, attendance, game length and a ticket glyph; whatever is unknown is left out.
    private var facts: some View {
        let items = factItems
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { Rectangle().fill(Color.hairline).frame(width: 1, height: 18).padding(.horizontal, 10) }
                HStack(spacing: 5) {
                    Image(systemName: item.symbol).font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint ?? Color.textSecondary)
                    if let text = item.text { Text(text).font(.condensed(.subheadline, weight: .heavy)).monospacedDigit() }
                }
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 20)
    }

    private struct Fact { let symbol: String; let text: String?; var tint: Color? = nil }

    private var factItems: [Fact] {
        var out: [Fact] = []
        if let w = game.weather {
            out.append(Fact(symbol: w.symbol, text: "\(Int(w.temperatureF.rounded()))\u{00B0}F"))
        } else if [.basketball, .hockey, .handball].contains(game.sport) {
            out.append(Fact(symbol: "building.2", text: "Indoors"))
        }
        if let a = game.attendance, a > 0 { out.append(Fact(symbol: "person.2", text: Fmt.number(a))) }
        if let length = Self.length(game) { out.append(Fact(symbol: "clock", text: length)) }
        if game.origin == .ticket { out.append(Fact(symbol: "ticket", text: nil, tint: Color.signal)) }
        if out.isEmpty, game.photos.count > 0 { out.append(Fact(symbol: "photo", text: "\(game.photos.count)")) }
        return out
    }

    /// How long the game ran: kickoff to the last play, for sports whose play list reaches the end.
    private static func length(_ game: GameEntry) -> String? {
        guard [.baseball, .basketball, .hockey, .football].contains(game.sport), let last = game.plays.last?.time else { return nil }
        let seconds = last.timeIntervalSince(game.date)
        guard seconds > 3600, seconds < 6 * 3600 else { return nil }
        return "\(Int(seconds) / 3600)h \(Int(seconds) % 3600 / 60)m"
    }

    /// "Bleachers \u{00B7} Section 314" -> "SEC 314"
    static func section(_ seat: String?) -> String? {
        guard let seat, !seat.isEmpty else { return nil }
        let pattern = #/(?i)(?:sec(?:tion)?\.?\s*)([A-Z]?\d+[A-Z]?)/#
        if let m = seat.firstMatch(of: pattern) { return "SEC \(m.1)" }
        return seat.count <= 12 ? seat.uppercased() : nil
    }
}

/// The date as the card's title: a big day number over the month, with the venue beside it.
private struct DateBlock: View {
    let date: Date
    let tz: TimeZone
    let venue: Venue?
    let championship: Bool

    var body: some View {
        let parts = Self.parts(date, tz)
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(parts.day)
                    .displayFont(104, relativeTo: .largeTitle)
                    .foregroundStyle(championship ? Color.trophy : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(parts.month)
                    .font(.condensed(.title2, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(.white)
                Rectangle().fill(Color.signal).frame(width: 84, height: 2)
                Text("\(parts.weekday) \u{00B7} \(parts.year)")
                    .font(.condensed(.footnote, weight: .heavy))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .fixedSize()
            if let venue {
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(venue.name)
                        .font(.condensed(.subheadline, weight: .heavy))
                        .tracking(3)
                        .textCase(.uppercase)
                        .lineLimit(2)
                    Text(venue.city)
                        .font(.condensed(.footnote, weight: .heavy))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 2)
            }
            Spacer(minLength: 0)
        }
        .shadow(color: .black.opacity(0.35), radius: 6)
    }

    private static func parts(_ date: Date, _ tz: TimeZone) -> (day: String, month: String, weekday: String, year: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .year, .weekday], from: date)
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return ("\(c.day ?? 1)", months[((c.month ?? 1) - 1) % 12], days[((c.weekday ?? 1) - 1) % 7], String(c.year ?? 0))
    }
}

/// The tear-off end of the stub: the score, stacked, behind a perforation.
private struct TearOff: View {
    @Environment(Library.self) private var library
    let game: GameEntry

    var body: some View {
        VStack(spacing: 6) {
            if game.sport == .motorsport {
                Text("RACE").font(.condensed(.caption2, weight: .heavy)).tracking(2).foregroundStyle(Color.textSecondary)
                Text(game.podium.first.map { $0.split(separator: " ").prefix(2).joined(separator: " ") } ?? "\u{2014}")
                    .font(.condensed(.title3, weight: .heavy))
            } else if game.isVisit {
                Text((game.competition ?? "Visit").uppercased())
                    .font(.condensed(.caption2, weight: .heavy)).tracking(2).foregroundStyle(Color.textSecondary)
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                if let team = library.team(game.homeTeamId) {
                    TeamTile(team: team, compact: true)
                    Text("\(team.locationName) home")
                        .font(.caption2).foregroundStyle(Color.textSecondary).lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    Image(systemName: "building.columns").font(.title2).foregroundStyle(Color.signal)
                }
            } else {
                Text(label).font(.condensed(.caption2, weight: .heavy)).tracking(2).foregroundStyle(Color.textSecondary)
                side(game.awayTeamId, game.awayScore)
                side(game.homeTeamId, game.homeScore)
            }
        }
        .frame(width: 138)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) { Perforation() }
    }

    private var label: String {
        guard game.hasScore else { return "VS" }
        switch library.outcome(game) {
        case .win: return "FINAL \u{00B7} W"
        case .loss: return "FINAL \u{00B7} L"
        case .draw: return "FINAL \u{00B7} D"
        case .none: return "FINAL"
        }
    }

    /// A team tile and its score. Both tiles share one width, so the two codes sit centered above each other.
    private func side(_ id: String?, _ score: Int?) -> some View {
        HStack(spacing: 6) {
            Group {
                if let team = library.team(id) { TeamTile(team: team, compact: true) } else { Color.clear }
            }
            .frame(width: 62)
            Text(score.map(String.init) ?? "")
                .font(.condensed(.title3, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
    }

    /// A dashed line with a half-moon notch at each end.
    private struct Perforation: View {
        var body: some View {
            GeometryReader { geo in
                Path { p in p.move(to: CGPoint(x: 0, y: 10)); p.addLine(to: CGPoint(x: 0, y: geo.size.height - 10)) }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.hairline)
                Circle().fill(Color.ink).frame(width: 18, height: 18).position(x: 0, y: 0)
                Circle().fill(Color.ink).frame(width: 18, height: 18).position(x: 0, y: geo.size.height)
            }
            .frame(width: 1)
            .allowsHitTesting(false)
        }
    }
}

/// The ticket stub under a card: notched corners and a perforated top edge.
private struct TicketStub<Content: View>: View {
    var trailingInset: CGFloat = 22
    var minHeight: CGFloat = 92
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.leading, 22)
            .padding(.trailing, trailingInset)
            .frame(maxWidth: .infinity, minHeight: minHeight)
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
