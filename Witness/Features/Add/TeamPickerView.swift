import SwiftUI

/// Pick any team for any game: every team in the catalog across every sport, your own teams first, or make a new one.
/// A handball club, a national side, a school team, a friends' league: it is all one list and one "New team".
struct TeamPickerView: View {
    @Binding var selection: String?
    let sport: Sport
    var title = "Team"
    /// Set when the picker is the first step of a flow: a pick moves forward (the caller pushes the next page) instead of closing.
    var onPick: ((String) -> Void)? = nil
    /// Set alongside `onPick`: opening a league is a step on the caller's navigation path, so every page is pushed the same way.
    var onLeague: ((String) -> Void)? = nil

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    /// What the field shows, and the search it settles into once typing pauses: filtering thousands of teams on every
    /// letter made typing lag.
    @State private var typed = ""
    @State private var query = ""
    @State private var showNew = false
    /// A team was picked inside a league's list: that list pops itself, and this picker closes once it is back on top.
    /// Dismissing this picker from under the league's list closed the whole sheet instead.
    @State private var closeOnReturn = false

    var body: some View {
        List {
            Section {
                Button { showNew = true } label: {
                    Label(trimmedQuery.isEmpty ? "New team or country" : "Add \u{201C}\(trimmedQuery)\u{201D} as a new team",
                          systemImage: "plus")
                }
                .accessibilityIdentifier("team-new")
                if selection != nil {
                    Button { selection = nil; dismiss() } label: {
                        Label("No team", systemImage: "xmark.circle").foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityIdentifier("team-none")
                }
            }
            .listRowBackground(Color.panel)

            if !custom.isEmpty {
                Section("Your teams") { rows(custom) }
                    .listRowBackground(Color.panel)
            }
            if searching {
                Section("\(results.count.formatted()) \(results.count == 1 ? "team" : "teams")") { rows(Array(results.prefix(300))) }
                    .listRowBackground(Color.panel)
            } else {
                ForEach(leagueSections, id: \.sport) { section in
                    Section(section.sport == sport ? "\(section.sport.name) leagues" : section.sport.name) {
                        ForEach(section.leagues, id: \.name) { league in
                            Group {
                                if let onLeague {
                                    Button { onLeague(league.name) } label: { leagueLabel(league) }
                                } else {
                                    NavigationLink {
                                        LeagueTeamsView(league: league.name, teams: league.teams, selection: $selection, popsSelf: onPick == nil) { picked() }
                                    } label: { leagueLabel(league) }
                                }
                            }
                            .accessibilityIdentifier("team-league-\(league.name)")
                        }
                    }
                    .listRowBackground(Color.panel)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .searchable(text: $typed, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search teams and countries")
        .task(id: typed) {
            // Cleared at once; otherwise wait for a pause in typing.
            if !typed.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
            if !Task.isCancelled { query = typed }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard closeOnReturn else { return }
            closeOnReturn = false
            dismiss()
        }
        .sheet(isPresented: $showNew) {
            NavigationStack {
                AddTeamView(initialName: trimmedQuery, sport: sport) { team in
                    selection = team.id
                    showNew = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { finish() }
                }
            }
        }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searching: Bool { !trimmedQuery.isEmpty }

    private var customIds: Set<String> { Set(library.customTeams.map(\.id)) }
    private func sorted(_ teams: [Team]) -> [Team] { teams.sorted { $0.displayName < $1.displayName } }
    private var custom: [Team] {
        let q = trimmedQuery
        return sorted(library.customTeams.filter { q.isEmpty || Self.matches($0, q) })
    }

    /// Letters and numbers only, accents folded, so "St. Louis" and "Levi's" match what people type.
    private static func fold(_ s: String) -> String {
        String(TicketParser.normalize(s).map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ").joined(separator: " ")
    }

    /// Every word typed must appear somewhere in the team's city, name, code, league or country, in any order:
    /// "chicago bears", "bears chicago", "bears nfl" and "chi" all find the Chicago Bears.
    @MainActor private static func matches(_ t: Team, _ q: String) -> Bool {
        let hay = haystack(t)
        return fold(q).split(separator: " ").allSatisfy { hay.contains($0) }
    }

    /// Each team's searchable text, folded once and kept: folding thousands of names on every search was the slow part.
    @MainActor private static var haystacks: [String: String] = [:]
    @MainActor private static func haystack(_ t: Team) -> String {
        let key = t.id + "|" + t.locationName + "|" + t.teamName
        if let hit = haystacks[key] { return hit }
        let hay = fold(([t.locationName, t.teamName, t.abbreviation, t.league, t.countryCode ?? ""] + (t.formerNames ?? [])).joined(separator: " "))
        haystacks[key] = hay
        return hay
    }

    /// Search across every sport; the current sport's teams first, the team named in full ahead of partial matches.
    private var results: [Team] {
        let q = Self.fold(trimmedQuery)
        let found = library.allTeams.filter { Self.matches($0, q) }
        func full(_ t: Team) -> Int { Self.fold("\(t.locationName) \(t.teamName)") == q || Self.fold(t.locationName) == q ? 0 : 1 }
        func order(_ list: [Team]) -> [Team] { list.sorted { full($0) != full($1) ? full($0) < full($1) : $0.displayName < $1.displayName } }
        return order(found.filter { $0.sport == sport }) + order(found.filter { $0.sport != sport })
    }

    struct LeagueGroup { let name: String; let teams: [Team] }
    struct SportGroup { let sport: Sport; let leagues: [LeagueGroup] }

    /// Leagues by sport, the current sport first; the biggest leagues lead each sport.
    private var leagueSections: [SportGroup] {
        let bySport = Dictionary(grouping: library.allTeams, by: \.sport)
        let order = [sport] + Sport.allCases.filter { $0 != sport }
        return order.compactMap { s in
            guard let teams = bySport[s], !teams.isEmpty else { return nil }
            let leagues = Dictionary(grouping: teams, by: \.league).map { LeagueGroup(name: $0.key, teams: $0.value) }
                .sorted { $0.teams.count != $1.teams.count ? $0.teams.count > $1.teams.count : $0.name < $1.name }
            return SportGroup(sport: s, leagues: leagues)
        }
    }

    private func leagueLabel(_ league: LeagueGroup) -> some View {
        HStack {
            Text(league.name).font(.condensed(.headline)).foregroundStyle(Color.primaryText)
            Spacer()
            Text("\(league.teams.count)").font(.footnote).foregroundStyle(Color.textSecondary)
            if onLeague != nil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.textTertiary)
            }
        }
        .contentShape(.rect)
    }

    private func rows(_ teams: [Team]) -> some View {
        TeamRows(teams: teams, selection: $selection) { finish() }
    }

    /// A team was picked on this page: move forward, or close.
    private func finish() {
        if let onPick, let selection { onPick(selection) } else { dismiss() }
    }

    /// A team was picked inside a league's list. Moving forward happens from there; closing waits for that list to pop.
    private func picked() {
        if let onPick, let selection { onPick(selection) } else { closeOnReturn = true }
    }
}

/// One league's teams, A to Z.
struct LeagueTeamsView: View {
    let league: String
    let teams: [Team]
    @Binding var selection: String?
    /// Whether this list pops itself after a pick (the picker then closes), or stays for the next page to push on top.
    var popsSelf = true
    let done: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section { TeamRows(teams: teams.sorted { $0.displayName < $1.displayName }, selection: $selection) { done(); if popsSelf { dismiss() } } }
                .listRowBackground(Color.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle(league)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TeamRows: View {
    let teams: [Team]
    @Binding var selection: String?
    let done: () -> Void

    var body: some View {
        ForEach(teams) { t in
            Button {
                selection = t.id
                done()
            } label: {
                HStack(spacing: 12) {
                    TeamTile(team: t, compact: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.displayName).font(.condensed(.headline)).foregroundStyle(Color.primaryText)
                        Text(t.league).font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    if t.id == selection { Image(systemName: "checkmark").foregroundStyle(Color.primaryText).accessibilityHidden(true) }
                }
                .contentShape(.rect)
            }
            .accessibilityIdentifier("team-row-\(t.id)")
            .accessibilityAddTraits(t.id == selection ? .isSelected : [])
        }
    }
}

/// A team made by hand: any name, a short code and a color. No logos; the tile is the code in the team's color.
struct AddTeamView: View {
    let initialName: String
    let sport: Sport
    let onSaved: (Team) -> Void

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var code = ""
    @State private var codeEdited = false
    @State private var color = Color(hex: "3A6BFF")
    @State private var teamSport: Sport
    @State private var league = ""
    @State private var didPrefill = false

    init(initialName: String, sport: Sport, onSaved: @escaping (Team) -> Void) {
        self.initialName = initialName
        self.sport = sport
        self.onSaved = onSaved
        _teamSport = State(initialValue: sport)
    }

    var body: some View {
        Form {
            Section {
                TextField("Team or country name", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("team-new-name")
                TextField("Short code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("team-new-code")
                    .onChange(of: code) { _, new in
                        let cleaned = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                        if cleaned != new { code = cleaned }
                    }
                ColorPicker("Color", selection: $color, supportsOpacity: false)
                HStack {
                    Text("Preview").foregroundStyle(Color.textSecondary)
                    Spacer()
                    TeamTile(team: previewTeam)
                }
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.panel)

            Section {
                Picker("Sport", selection: $teamSport) {
                    ForEach(Sport.allCases) { s in Text(s.name).tag(s) }
                }
                TextField("League or competition (optional)", text: $league)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("team-new-league")
            } footer: {
                Text("Examples: Croatia, national team \u{00B7} Zadar, EuroLeague \u{00B7} Riverside High, varsity.")
            }
            .listRowBackground(Color.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("New team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedName.isEmpty || code.isEmpty)
                    .accessibilityIdentifier("team-new-save")
            }
        }
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            name = initialName
            code = Self.suggestCode(initialName)
        }
        .onChange(of: name) { _, new in
            if !codeEdited { code = Self.suggestCode(new) }
        }
        .onChange(of: code) { _, new in
            if new != Self.suggestCode(name) { codeEdited = true }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var previewTeam: Team {
        let hex = color.hexString
        return Team(id: "preview", sport: teamSport, league: league, abbreviation: code.isEmpty ? "\u{2014}" : code,
                    locationName: trimmedName, teamName: trimmedName, monogram: String(code.prefix(1)),
                    colors: .init(primary: hex, secondary: "FFFFFF", accent: hex))
    }

    /// "Croatia" -> "CRO", "Real Madrid" -> "RM", "KK Zadar" -> "KZ".
    static func suggestCode(_ name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.count >= 2 { return String(words.prefix(3).compactMap(\.first).map(String.init).joined().uppercased()) }
        return String((words.first ?? "").uppercased().prefix(3))
    }

    private func save() {
        let hex = color.hexString
        let leagueName = league.trimmingCharacters(in: .whitespacesAndNewlines)
        let team = Team(id: "custom-\(UUID().uuidString)", sport: teamSport, league: leagueName.isEmpty ? "Custom" : leagueName,
                        abbreviation: code, locationName: trimmedName, teamName: trimmedName,
                        monogram: String(code.prefix(1)), colors: .init(primary: hex, secondary: "FFFFFF", accent: hex))
        onSaved(library.addTeam(team))
    }
}

extension Color {
    /// "RRGGBB" in sRGB, for storing a picked color.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// Two teams, tap the one you were there for. Used on a game, in the review and when adding.
struct RootingChips: View {
    let teams: [Team]
    @Binding var selection: String?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(teams) { team in
                let on = selection == team.id
                Button { selection = team.id } label: {
                    HStack(spacing: 8) {
                        TeamTile(team: team, compact: true)
                        Text(team.locationName).font(.condensed(.subheadline, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.signal).accessibilityHidden(true) }
                    }
                    .foregroundStyle(Color.primaryText)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.panel, in: .rect(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(on ? Color.signal : Color.hairline, lineWidth: on ? 2 : 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(team.locationName), rooting for")
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("rooting-\(team.abbreviation)")
            }
        }
    }
}

/// "I was there for", folded to one line when it is already settled (your team is playing, or you chose); tap to change.
struct RootingPicker: View {
    let teams: [Team]
    @Binding var selection: String?
    /// True when it is already settled: one of your teams plays, or it was chosen before.
    let known: Bool

    @State private var expanded = false
    @State private var chosen = false

    var body: some View {
        let collapsed = (known || chosen) && !expanded
        VStack(alignment: .leading, spacing: 8) {
            if collapsed, let team = teams.first(where: { $0.id == selection }) {
                Button {
                    withAnimation(.snappy) { expanded = true }
                } label: {
                    HStack(spacing: 10) {
                        Text("I was there for").font(.footnote.weight(.semibold)).foregroundStyle(Color.textSecondary)
                        TeamTile(team: team, compact: true)
                        Text(team.locationName).font(.condensed(.subheadline, weight: .heavy)).foregroundStyle(Color.primaryText).lineLimit(1)
                        Spacer(minLength: 8)
                        Text("Change").font(.footnote.weight(.semibold)).foregroundStyle(Color.signal)
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Color.signal).accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.panel, in: .rect(cornerRadius: 12))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("I was there for \(team.locationName). Change")
                .accessibilityIdentifier("rooting-collapsed")
            } else {
                Text("I was there for").font(.condensed(.subheadline, weight: .heavy)).tracking(1.2).textCase(.uppercase)
                    .foregroundStyle(Color.textSecondary)
                RootingChips(teams: teams, selection: Binding(
                    get: { selection },
                    set: { new in
                        selection = new
                        chosen = true
                        withAnimation(.snappy) { expanded = false }
                    }))
            }
        }
    }
}

/// "Select your teams": the teams you follow. They are who you were rooting for at any game they play in, unless a game says otherwise.
struct FavoriteTeamsView: View {
    @Environment(Library.self) private var library

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TeamPickerView(selection: addBinding, sport: startSport)
                } label: {
                    Label("Add a team", systemImage: "plus")
                }
                .accessibilityIdentifier("favorites-add")
            } footer: {
                Text("Your teams are who you were rooting for at every game they play in. You can change it on any single game.")
            }
            .listRowBackground(Color.panel)

            if !library.favoriteTeams.isEmpty {
                Section("Your teams") {
                    ForEach(library.favoriteTeams) { team in
                        HStack(spacing: 12) {
                            TeamTile(team: team, compact: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(team.locationName).font(.condensed(.headline)).foregroundStyle(Color.primaryText)
                                Text(team.league).font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("favorite-\(team.id)")
                    }
                    .onDelete { offsets in
                        let teams = library.favoriteTeams
                        for i in offsets { library.removeFavorite(teams[i].id) }
                    }
                }
                .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Your teams")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addBinding: Binding<String?> {
        Binding(get: { nil }, set: { if let id = $0 { library.addFavorite(id) } })
    }

    /// The picker opens on the sport of your latest team, else of your latest game.
    private var startSport: Sport {
        library.favoriteTeams.last?.sport ?? library.games.first?.sport ?? .baseball
    }
}
