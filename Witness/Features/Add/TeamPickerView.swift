import SwiftUI

/// Pick any team for any game: every team in the catalog across every sport, your own teams first, or make a new one.
/// A handball club, a national side, a school team, a friends' league: it is all one list and one "New team".
struct TeamPickerView: View {
    @Binding var selection: String?
    let sport: Sport

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showNew = false

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
            if !sameSport.isEmpty {
                Section(sport.name) { rows(sameSport) }
                    .listRowBackground(Color.panel)
            }
            if !others.isEmpty {
                Section("Other sports") { rows(others) }
                    .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search teams and countries")
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNew) {
            NavigationStack {
                AddTeamView(initialName: trimmedQuery, sport: sport) { team in
                    selection = team.id
                    showNew = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() }
                }
            }
        }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var everyTeam: [Team] {
        let q = TicketParser.normalize(trimmedQuery)
        let all = library.allTeams + library.customTeams
        guard !q.isEmpty else { return all }
        return all.filter {
            TicketParser.normalize($0.locationName).contains(q) || TicketParser.normalize($0.teamName).contains(q)
                || TicketParser.normalize($0.abbreviation).contains(q) || TicketParser.normalize($0.league).contains(q)
        }
    }

    private func sorted(_ teams: [Team]) -> [Team] { teams.sorted { $0.locationName < $1.locationName } }
    private var custom: [Team] { sorted(everyTeam.filter { library.customTeams.contains($0) }) }
    private var sameSport: [Team] { sorted(everyTeam.filter { $0.sport == sport && !library.customTeams.contains($0) }) }
    private var others: [Team] { sorted(everyTeam.filter { $0.sport != sport && !library.customTeams.contains($0) }) }

    private func rows(_ teams: [Team]) -> some View {
        ForEach(teams) { t in
            Button {
                selection = t.id
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    TeamTile(team: t, compact: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.locationName).font(.condensed(.headline)).foregroundStyle(.white)
                        Text(t.league).font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    if t.id == selection { Image(systemName: "checkmark").foregroundStyle(.white).accessibilityHidden(true) }
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
