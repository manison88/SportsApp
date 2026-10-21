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

                NavigationLink { FavoriteTeamsView() } label: { favoritesRow }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("you-teams")

                if !chrono.isEmpty {
                    ResultDots(games: chrono, stats: stats, color: favoriteColor)
                }

                VStack(spacing: Spacing.block) {
                    StatRow(items: [
                        .init(value: "\(stats.games)", label: "Games"),
                        .init(value: Fmt.number(stats.distance), label: Fmt.distanceUnit),
                        .init(value: "\(stats.venues)", label: "Venues"),
                    ])
                    StatRow(items: [
                        .init(value: Fmt.number(stats.points), label: "Points"),
                        .init(value: stats.coldestF.map { Fmt.temperature($0) } ?? "–", label: "Coldest"),
                        .init(value: "\(stats.countries)", label: stats.countries == 1 ? "Country" : "Countries"),
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
                shareLink(stats)
            }
        }
        .confirmationDialog("Remove the sample games?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove sample games", role: .destructive) { library.removeSample() }
        }
    }

    /// "Select your teams", or the chips of the teams already chosen.
    private var favoritesRow: some View {
        let teams = library.favoriteTeams
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(teams.isEmpty ? "Select your teams" : "Your teams")
                    .font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                if teams.isEmpty {
                    Text("Pick who you root for and every game starts with them.")
                        .font(.footnote).foregroundStyle(Color.textSecondary).multilineTextAlignment(.leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) { ForEach(teams.prefix(12)) { TeamTile(team: $0, compact: true) } }
                    }
                    .scrollDisabled(true)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
        }
        .foregroundStyle(Color.primaryText)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .contentShape(.rect)
    }

    @ViewBuilder
    private func links(stats: Stats) -> some View {
        VStack(spacing: 0) {
            let big = library.games.filter { $0.bigGame != nil }.count
            if big > 0 {
                NavigationLink(value: Route.bigGames) {
                    HStack {
                        Text("Big games").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                        Spacer()
                        Text("\(big)").foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.primaryText)
                .accessibilityIdentifier("you-big-games")
            }
            if !library.scheduleLog.isEmpty {
                NavigationLink { ScheduleGapsView() } label: {
                    HStack {
                        Text("Schedule gaps").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                        Spacer()
                        Text("\(library.scheduleLog.filter { $0.misses > 0 }.count)").foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.primaryText)
                .accessibilityIdentifier("you-schedule-gaps")
            }
            NavigationLink { FeedbackView() } label: {
                HStack {
                    Text("Feedback & requests").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primaryText)
            .accessibilityIdentifier("you-feedback")
            NavigationLink { BackupView() } label: {
                HStack {
                    Text("Back up & export").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primaryText)
            .accessibilityIdentifier("you-backup")
            SoccerWordRow()
            AppearanceRow()
            Toggle(isOn: Binding(get: { Analytics.shared.enabled }, set: { Analytics.shared.setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share anonymous usage").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                    Text("Which features get used, never your photos, places or names.").font(.footnote).foregroundStyle(Color.textSecondary)
                }
            }
            .tint(Color.signal)
            .frame(minHeight: 56)
            .foregroundStyle(Color.primaryText)
            .accessibilityIdentifier("you-analytics")
            LegalLinksRows()
            // Wrapped is off for now: its row returns when the redesign is built (WrappedView and Modal.wrapped stay in place).
            if library.isSample {
                Button("Remove sample games", role: .destructive) { confirmRemove = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                    .accessibilityIdentifier("you-remove-sample")
            }
        }
    }

    /// One team only when it is clearly yours (most of your games); otherwise the page stays about all your teams.
    private var favoriteTeam: Team? {
        let ids = library.games.compactMap { library.rootingTeam($0) }
        guard let top = Dictionary(grouping: ids, by: { $0 }).max(by: { $0.value.count < $1.value.count }),
              top.value.count * 10 >= library.games.count * 6 else { return nil }
        return library.team(top.key)
    }

    private var favoriteCity: String? { favoriteTeam?.locationName }
    private var favoriteColor: Color { favoriteTeam?.accent ?? Color(hex: "2F6BFF") }

    /// Hero is the win-loss record when any game has a result, otherwise the games count.
    /// Three supporting numbers sit under it, never repeating the hero.
    private func shareLink(_ s: Stats) -> some View {
        let hasRecord = s.record.decided > 0
        let rows: [YouShareStat] = hasRecord
            ? [YouShareStat(label: "Games", value: "\(s.games)"),
               YouShareStat(label: "Venues", value: "\(s.venues)"),
               YouShareStat(label: Fmt.distanceUnit, value: Fmt.number(s.distance))]
            : [YouShareStat(label: "Venues", value: "\(s.venues)"),
               YouShareStat(label: Fmt.distanceUnit, value: Fmt.number(s.distance)),
               YouShareStat(label: "Countries", value: "\(s.countries)")]
        let heroValue = hasRecord ? s.record.text : "\(s.games)"
        let heroLabel = hasRecord ? "My record when I'm there" : "Games I've witnessed"
        let accent = favoriteColor
        let variants: [ShareCardVariant] = YouShareCard.Style.allCases.map { st in
            ShareCardVariant(st.name) {
                YouShareCard(heroValue: heroValue, heroLabel: heroLabel, rows: rows, accent: accent, style: st)
            }
        }
        let key = "\(s.games)|\(s.record.text)|\(s.venues)|\(s.miles)|\(s.countries)|\(favoriteCity ?? "")"
        return ShareCardSheetLink(kind: "numbers", title: "My numbers", format: .story, key: key, variants: { variants }) {
            Image(systemName: "square.and.arrow.up").fontWeight(.bold)
        }
        .accessibilityLabel("Share your numbers")
    }
}

private struct YouShareStat: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// 1080x1920 story cards, five looks. Story because the hero wants the height.
private struct YouShareCard: View {
    enum Style: CaseIterable {
        case number, color, paper, stub, split

        var name: String {
            switch self {
            case .number: return "Number"
            case .color: return "Color"
            case .paper: return "Paper"
            case .stub: return "Stub"
            case .split: return "Split"
            }
        }
    }

    let heroValue: String
    let heroLabel: String
    let rows: [YouShareStat]
    let accent: Color
    let style: Style
    @Environment(\.shareScheme) private var scheme

    private var fg: Color {
        switch style {
        case .paper: return Color.sharePaperInk(scheme)
        case .color: return accent.readableInk
        default: return Color.primaryText
        }
    }

    var body: some View {
        Group {
            if style == .split {
                splitBody
            } else {
                standardBody
            }
        }
        .frame(width: 1080, height: 1920)
        .shareSurface()
    }

    // MARK: Pieces

    private func eyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 44, weight: .bold).width(.condensed))
            .tracking(8)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func hero(size: CGFloat, color: Color) -> some View {
        Text(heroValue)
            .font(.display(size))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
    }

    private func caption(_ color: Color) -> some View {
        Text(heroLabel.uppercased())
            .font(.system(size: 56, weight: .bold).width(.condensed))
            .tracking(2)
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 44, weight: .bold).width(.condensed))
            .tracking(6)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func value(_ text: String, size: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.display(size))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private func footer(_ color: Color) -> some View {
        Text("WITNESS")
            .font(.system(size: 40, weight: .heavy).width(.compressed))
            .tracking(10)
            .foregroundStyle(color)
    }

    // MARK: Standard layouts

    @ViewBuilder
    private var background: some View {
        switch style {
        case .color:
            accent
        case .paper:
            Color.sharePaper(scheme)
        default:
            ZStack {
                Color.ink
                LinearGradient(colors: [accent.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
            }
        }
    }

    private var standardBody: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                layout
                Spacer(minLength: 40)
                footer(fg.opacity(0.9))
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var layout: some View {
        switch style {
        case .number:
            numberLayout
        case .color:
            colorLayout
        case .paper:
            paperLayout
        default:
            stubLayout
        }
    }

    /// Giant number on ink, three ruled rows. Amber marks "you" once.
    private var numberLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                Rectangle().fill(Color.signal).frame(width: 56, height: 8)
                eyebrow("MY NUMBERS", color: fg.opacity(0.7))
            }
            hero(size: 400, color: fg).padding(.top, 40)
            caption(fg.opacity(0.85)).padding(.top, 8)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        label(row.label, color: fg.opacity(0.6))
                        Spacer(minLength: 24)
                        value(row.value, size: 130, color: fg)
                    }
                    .padding(.vertical, 28)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.primaryText.opacity(0.2)).frame(height: 2)
                    }
                }
            }
            .padding(.top, 90)
        }
    }

    /// Solid team color, caption on top, hero low, stats in three columns.
    private var colorLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow("MY NUMBERS", color: fg.opacity(0.7))
            caption(fg).padding(.top, 30)
            hero(size: 440, color: fg).padding(.top, 150)
            Rectangle().fill(fg).frame(height: 8).padding(.top, 60)
            HStack(alignment: .top, spacing: 24) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        value(row.value, size: 120, color: fg)
                        label(row.label, color: fg.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 50)
        }
    }

    /// Off-white paper, black type, values on the left and labels on the right.
    private var paperLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow("MY NUMBERS", color: fg.opacity(0.6))
            caption(fg).padding(.top, 40)
            hero(size: 340, color: fg).padding(.top, 20)
            Rectangle().fill(fg).frame(height: 10).padding(.top, 60)
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        value(row.value, size: 130, color: fg)
                        Spacer(minLength: 24)
                        label(row.label, color: fg.opacity(0.6))
                    }
                    .padding(.vertical, 26)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(fg.opacity(0.2)).frame(height: 2)
                    }
                }
            }
        }
    }

    /// A ticket stub: hero above a dashed tear line, stats below.
    private var stubLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow("MY NUMBERS", color: fg.opacity(0.7))
            VStack(alignment: .leading, spacing: 0) {
                hero(size: 320, color: fg)
                caption(fg.opacity(0.85)).padding(.top, 8)
                Rectangle()
                    .stroke(Color.primaryText.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [16, 12]))
                    .frame(height: 3)
                    .padding(.vertical, 50)
                VStack(spacing: 30) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            label(row.label, color: fg.opacity(0.6))
                            Spacer(minLength: 24)
                            value(row.value, size: 100, color: fg)
                        }
                    }
                }
            }
            .padding(56)
            .background(Color.primaryText.opacity(0.08), in: .rect(cornerRadius: 40))
            .overlay(RoundedRectangle(cornerRadius: 40).strokeBorder(Color.primaryText.opacity(0.25), lineWidth: 2))
            .padding(.top, 50)
        }
    }

    // MARK: Split

    /// Top block in team color holds the hero, bottom block on ink holds the stats.
    private var splitBody: some View {
        let top = accent.readableInk
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                eyebrow("MY NUMBERS", color: top.opacity(0.7))
                Spacer(minLength: 20)
                hero(size: 400, color: top)
                caption(top).padding(.top, 8)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 1000)
            .background(accent)

            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 28) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            label(row.label, color: Color.primaryText.opacity(0.6))
                            Spacer(minLength: 24)
                            value(row.value, size: 110, color: Color.primaryText)
                        }
                    }
                }
                .padding(.top, 50)
                Spacer(minLength: 20)
                footer(Color.primaryText.opacity(0.9))
            }
            .padding(.horizontal, 84)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.ink)
        }
    }
}

private struct HeroCard: View {
    let stats: Stats
    let city: String?
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
        if rate > 0.5 { return "\(city ?? "Your teams") win\(city == nil ? "" : "s") more when you show up." }
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
            Circle().fill(Color.primaryText)
        case .loss:
            Circle().strokeBorder(Color.textSecondary, lineWidth: 2)
        case .draw:
            Circle().strokeBorder(Color.primaryText, lineWidth: 2)
                .overlay { HalfCircle().fill(Color.primaryText).padding(2) }
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
        .foregroundStyle(Color.primaryText)
    }
}

/// "Soccer" or "fudbal": the fan's word for the sport, used on the passport, its share card and sport names.
private struct SoccerWordRow: View {
    @AppStorage("soccerWord") private var soccerWord = ""

    var body: some View {
        HStack {
            Text("Call it").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
            Spacer()
            Picker("Call it", selection: Binding(get: { soccerWord.isEmpty ? (SoccerWord.usesFudbal ? "fudbal" : "soccer") : (soccerWord == "football" ? "fudbal" : soccerWord) },
                                                 set: { soccerWord = $0 })) {
                Text("Soccer").tag("soccer")
                Text("Fudbal").tag("fudbal")
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
            .accessibilityIdentifier("you-soccer-word")
        }
        .frame(minHeight: 56)
        .foregroundStyle(Color.primaryText)
    }
}

/// Auto follows the phone; Light and Dark force it. Applied at the root in WitnessApp.
private struct AppearanceRow: View {
    @AppStorage("appearance") private var appearance = "auto"

    var body: some View {
        HStack {
            Text("Appearance").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
            Spacer()
            Picker("Appearance", selection: Binding(get: { AppearanceChoice(stored: appearance).rawValue }, set: { appearance = $0 })) {
                ForEach(AppearanceChoice.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("you-appearance")
        }
        .frame(minHeight: 56)
        .foregroundStyle(Color.primaryText)
    }
}
