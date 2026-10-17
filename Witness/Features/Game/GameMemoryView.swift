import SwiftUI

/// 05 · Game memory. A tall photo hero carries the headline; under it the
/// line score, who you were with, and one action: Play recap.
struct GameMemoryView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    private let heroHeight: CGFloat = 470

    var body: some View {
        if let game = library.game(gameId) {
            content(game)
        } else {
            ContentUnavailableView("Game not found", systemImage: "ticket")
                .inkBackground()
        }
    }

    private func content(_ game: GameEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                heroLink(game)
                scoreBlock(game).gutter()
                peopleBlock(game)
                links(game)
                Button {
                    presenter.modal = .recap(game.id)
                } label: {
                    Label("Play recap", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("play-recap")
                .gutter()
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { menu(game) }
        }
        .sheet(isPresented: $editing) {
            AddGameView(editing: game)
        }
        .confirmationDialog("Delete this game?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.delete(game.id)
                dismiss()
            }
        } message: {
            Text("Its photos stay in your library.")
        }
    }

    // MARK: Hero

    private func hasDetail(_ game: GameEntry) -> Bool {
        !game.plays.isEmpty || !game.winProbability.isEmpty
    }

    @ViewBuilder
    private func heroLink(_ game: GameEntry) -> some View {
        if hasDetail(game) {
            NavigationLink(value: Route.youWereThere(game.id)) { hero(game) }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the moments you were there for")
                .accessibilityIdentifier("hero-you-were-there")
        } else {
            hero(game)
        }
    }

    private func hero(_ game: GameEntry) -> some View {
        let venue = library.venue(game.venueId)
        let tz = venue?.tz ?? .current
        return ZStack(alignment: .bottomLeading) {
            GameBackdrop(game: game)
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
            Scrim()
            if game.bigGame?.kind == .championship {
                // A warm floor of light under title-game headlines.
                LinearGradient(colors: [Color.trophy.opacity(0.22), .clear], startPoint: .bottom, endPoint: .center)
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 10) {
                if let stage = game.bigGame {
                    EventMark(game: game, stage: stage)
                }
                Text(headlineText(game, library).uppercased().replacingOccurrences(of: ". ", with: ".\n"))
                    .displayFont(52)
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("game-title")
                    .accessibilityAddTraits(.isHeader)
                Text([venue?.name, Fmt.dayTitle(game.date, in: tz)].compactMap { $0 }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .gutter()
            .padding(.bottom, 8)
        }
        .frame(height: heroHeight)
        .contentShape(.rect)
    }

    // MARK: Score

    @ViewBuilder
    private func scoreBlock(_ game: GameEntry) -> some View {
        if game.sport == .motorsport {
            if !game.podium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(game.podium.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.condensed(.title3, weight: .heavy))
                            .foregroundStyle(i == 0 ? Color.white : Color.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                if i < game.podium.count - 1 { Rectangle().fill(Color.hairline).frame(height: 1) }
                            }
                    }
                }
            }
        } else if !game.lineHome.isEmpty || !game.lineAway.isEmpty {
            LineScoreTable(game: game)
        } else if game.hasScore {
            HStack { ScoreBug(game: game, showFinal: true); Spacer() }
        }
    }

    // MARK: People

    @ViewBuilder
    private func peopleBlock(_ game: GameEntry) -> some View {
        let people = game.companionIds.compactMap { library.person($0) }
        let note = game.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !people.isEmpty || !note.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.inner) {
                if !people.isEmpty {
                    HStack(spacing: 10) {
                        AvatarStack(people: people)
                        Text("With \(people.namesText)")
                            .font(.condensed(.headline, weight: .heavy))
                            .textCase(.uppercase)
                    }
                    .accessibilityElement(children: .combine)
                }
                if !note.isEmpty {
                    Text("“\(note)”")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
            }
            .gutter()
        }
    }

    // MARK: Links

    @ViewBuilder
    private func links(_ game: GameEntry) -> some View {
        let venue = library.venue(game.venueId)
        let trip = library.trip(game.tripId)
        if venue != nil || trip != nil || hasDetail(game) {
            VStack(spacing: 0) {
                if hasDetail(game) {
                    linkRow("You were there", symbol: "waveform.path.ecg", route: .youWereThere(game.id))
                        .accessibilityIdentifier("open-you-were-there")
                }
                if let venue {
                    linkRow(venue.name, symbol: "building.columns", route: .venue(venue.id))
                        .accessibilityIdentifier("open-venue")
                }
                if let trip {
                    linkRow(trip.title, symbol: "airplane", route: .trip(trip.id))
                        .accessibilityIdentifier("open-trip")
                }
            }
            .gutter()
        }
    }

    private func linkRow(_ title: String, symbol: String, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.condensed(.headline, weight: .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            .contentShape(.rect)
            .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Menu

    private func menu(_ game: GameEntry) -> some View {
        Menu {
            ShareLink(item: summary(game)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                .accessibilityIdentifier("game-delete")
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("game-menu")
    }

    private func summary(_ game: GameEntry) -> String {
        let venue = library.venue(game.venueId)
        var parts = [headlineText(game, library)]
        parts.append([venue?.name, Fmt.dayTitle(game.date, in: venue?.tz ?? .current)].compactMap { $0 }.joined(separator: ", "))
        parts.append("I was there. · Witness")
        return parts.joined(separator: "\n")
    }
}

/// A clean line score: periods, then the total in heavier white.
private struct LineScoreTable: View {
    @Environment(Library.self) private var library
    let game: GameEntry

    private var columns: Int { max(game.lineHome.count, game.lineAway.count) }

    private func label(_ i: Int) -> String {
        let labels = game.sport.periodLabels
        if i < labels.count { return labels[i] }
        return game.sport == .baseball ? "\(i + 1)" : "OT"
    }

    var body: some View {
        let showCity = columns <= 5
        let awayTotal = game.awayScore ?? game.lineAway.reduce(0, +)
        let homeTotal = game.homeScore ?? game.lineHome.reduce(0, +)
        Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: 14) {
            GridRow {
                Color.clear.frame(width: 1, height: 1)
                    .gridColumnAlignment(.leading)
                ForEach(0..<columns, id: \.self) { i in
                    Text(label(i)).unitLabel()
                        .frame(minWidth: showCity ? 30 : 22, alignment: .trailing)
                }
                Text("T").unitLabel().frame(minWidth: 40, alignment: .trailing)
            }
            row(teamId: game.awayTeamId, line: game.lineAway, total: awayTotal, won: awayTotal > homeTotal, showCity: showCity)
            row(teamId: game.homeTeamId, line: game.lineHome, total: homeTotal, won: homeTotal > awayTotal, showCity: showCity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(awayTotal: awayTotal, homeTotal: homeTotal))
    }

    private func row(teamId: String?, line: [Int], total: Int, won: Bool, showCity: Bool) -> some View {
        let team = library.team(teamId)
        let tone: Color = won ? .white : .textSecondary
        return GridRow {
            HStack(spacing: 10) {
                TeamTile(team: team, compact: true)
                if showCity {
                    Text(team?.locationName ?? "")
                        .font(.condensed(.headline, weight: .bold))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .foregroundStyle(tone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<columns, id: \.self) { i in
                Text(i < line.count ? "\(line[i])" : "–")
                    .font(.condensed(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tone)
            }
            Text("\(total)")
                .displayFont(26, relativeTo: .title2)
                .foregroundStyle(tone)
        }
    }

    private func accessibilityText(awayTotal: Int, homeTotal: Int) -> String {
        let away = library.team(game.awayTeamId)?.locationName ?? "Away"
        let home = library.team(game.homeTeamId)?.locationName ?? "Home"
        return "Final: \(away) \(awayTotal), \(home) \(homeTotal)"
    }
}
