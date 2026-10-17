import SwiftUI
import PhotosUI

/// Add or edit a game by hand. Prefilled when it comes from a ticket.
struct AddGameView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss

    let draft: TicketDraft?
    let editing: GameEntry?
    var embedded: Bool
    var onDone: (() -> Void)?

    @State private var sport: Sport = .baseball
    @State private var homeTeamId: String?
    @State private var awayTeamId: String?
    @State private var raceName = ""
    @State private var venueId: String?
    @State private var date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var homeScore = ""
    @State private var awayScore = ""
    @State private var rootingForTeamId: String?
    @State private var seat = ""
    @State private var companionIds: Set<String> = []
    @State private var newPerson = ""
    @State private var note = ""
    @State private var photoIds: [String] = []
    @State private var keptPhotos: [PhotoRef] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var lineHome: [Int] = []
    @State private var lineAway: [Int] = []
    @State private var lookingUp = false
    @State private var lookupFailed = false
    @State private var findingPhotos = false
    @State private var didPrefill = false

    init(draft: TicketDraft? = nil, editing: GameEntry? = nil, embedded: Bool = false, onDone: (() -> Void)? = nil) {
        self.draft = draft
        self.editing = editing
        self.embedded = embedded
        self.onDone = onDone
    }

    var body: some View {
        if embedded {
            form
        } else {
            NavigationStack { form }
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Sport", selection: $sport) {
                    ForEach(Sport.allCases) { s in
                        Text(s.name).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("add-sport")

                if sport == .motorsport {
                    TextField("Race", text: $raceName)
                        .accessibilityIdentifier("add-race")
                } else {
                    teamPicker("Away", selection: $awayTeamId, id: "add-away-team")
                    teamPicker("Home", selection: $homeTeamId, id: "add-home-team")
                }

                NavigationLink {
                    VenuePickerView(venueId: $venueId, sport: sport)
                } label: {
                    LabeledContent("Venue") {
                        Text(venueName)
                            .foregroundStyle(venueId == nil ? Color.textTertiary : Color.white)
                            .accessibilityIdentifier("add-venue-name")
                    }
                }
                .accessibilityIdentifier("add-venue")

                DatePicker("Date", selection: $date)
                    .accessibilityIdentifier("add-date")
            }
            .listRowBackground(Color.panel)

            if sport != .motorsport {
                Section {
                    scoreRow
                    if let home = homeTeamId, let away = awayTeamId {
                        LabeledContent("Rooting for") {
                            Picker("Rooting for", selection: $rootingForTeamId) {
                                Text(library.team(away)?.abbreviation ?? "Away").tag(Optional(away))
                                Text(library.team(home)?.abbreviation ?? "Home").tag(Optional(home))
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 180)
                        }
                        .accessibilityIdentifier("add-rooting")
                    }
                    if sport == .baseball, venueId != nil {
                        Button {
                            Task { await lookup() }
                        } label: {
                            HStack {
                                Label("Look up final score", systemImage: "sparkle.magnifyingglass")
                                Spacer()
                                if lookingUp { ProgressView() }
                            }
                        }
                        .disabled(lookingUp)
                        .accessibilityIdentifier("add-lookup")
                        if lookupFailed {
                            Text("No final score found for that day.")
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.panel)
            }

            Section {
                TextField("Seat", text: $seat)
                    .accessibilityIdentifier("add-seat")
                ForEach(library.people) { p in
                    Toggle(isOn: companion(p.id)) {
                        HStack(spacing: 10) {
                            Avatar(person: p, size: 26)
                            Text(p.name)
                        }
                    }
                    .accessibilityIdentifier("add-with-\(p.id)")
                }
                HStack {
                    TextField("Add person", text: $newPerson)
                        .onSubmit(addPerson)
                        .accessibilityIdentifier("add-person")
                    if !newPerson.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add", action: addPerson)
                    }
                }
            }
            .listRowBackground(Color.panel)

            Section {
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityIdentifier("add-note")
            }
            .listRowBackground(Color.panel)

            Section {
                if !allPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allPhotos, id: \.self) { ref in
                                PhotoView(ref: ref)
                                    .frame(width: 64, height: 64)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                        }
                    }
                }
                PhotosPicker(selection: $pickerItems, matching: .images, photoLibrary: .shared()) {
                    Label(allPhotos.isEmpty ? "Add photos" : "\(allPhotos.count) photos", systemImage: "photo.on.rectangle")
                }
                .accessibilityIdentifier("add-photos")
                Button {
                    Task { await findPhotos() }
                } label: {
                    HStack {
                        Label("Find photos from this game", systemImage: "location.magnifyingglass")
                        Spacer()
                        if findingPhotos { ProgressView() }
                    }
                }
                .disabled(venueId == nil || findingPhotos)
                .accessibilityIdentifier("add-find-photos")
            }
            .listRowBackground(Color.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle(editing == nil ? "Add game" : "Edit game")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(embedded)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: finish) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancel")
                .accessibilityIdentifier("add-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .foregroundStyle(venueId == nil ? Color.textTertiary : Color.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .disabled(venueId == nil)
                .accessibilityLabel("Save")
                .accessibilityIdentifier("add-save")
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: sport) { _, newSport in
            if let t = library.team(homeTeamId), t.sport != newSport { homeTeamId = nil }
            if let t = library.team(awayTeamId), t.sport != newSport { awayTeamId = nil }
            if let v = venueId.flatMap({ library.venue($0) }), !v.sports.isEmpty, !v.sports.contains(newSport) { venueId = nil }
        }
        .onChange(of: homeTeamId) { _, _ in fixRooting() }
        .onChange(of: awayTeamId) { _, _ in fixRooting() }
        .onChange(of: pickerItems) { _, items in
            for item in items {
                if let id = item.itemIdentifier, !photoIds.contains(id) { photoIds.append(id) }
            }
        }
    }

    // MARK: Pieces

    private var venueName: String {
        if let v = venueId.flatMap({ library.venue($0) }) { return v.name }
        return draft?.venueName ?? "Choose"
    }

    private var allPhotos: [PhotoRef] { keptPhotos + photoIds.map { PhotoRef.library($0) } }

    private var scoreRow: some View {
        HStack(spacing: 12) {
            TeamTile(team: library.team(awayTeamId), compact: true)
            TextField("0", text: $awayScore)
                .keyboardType(.numberPad)
                .font(.condensed(.title2, weight: .heavy))
                .frame(width: 64)
                .accessibilityLabel("Away score")
                .accessibilityIdentifier("add-away-score")
            Spacer()
            TextField("0", text: $homeScore)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.condensed(.title2, weight: .heavy))
                .frame(width: 64)
                .accessibilityLabel("Home score")
                .accessibilityIdentifier("add-home-score")
            TeamTile(team: library.team(homeTeamId), compact: true)
        }
    }

    private func teamPicker(_ title: String, selection: Binding<String?>, id: String) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(String?.none)
            ForEach(library.teams(for: sport)) { t in
                Text("\(t.locationName) · \(t.abbreviation)").tag(Optional(t.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(id)
    }

    private func companion(_ id: String) -> Binding<Bool> {
        Binding(
            get: { companionIds.contains(id) },
            set: { on in
                if on { companionIds.insert(id) } else { companionIds.remove(id) }
            })
    }

    // MARK: Actions

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        if let g = editing {
            sport = g.sport
            homeTeamId = g.homeTeamId
            awayTeamId = g.awayTeamId
            raceName = g.sport == .motorsport ? (g.competition ?? "") : ""
            venueId = g.venueId
            date = g.date
            homeScore = g.homeScore.map { String($0) } ?? ""
            awayScore = g.awayScore.map { String($0) } ?? ""
            rootingForTeamId = g.rootingForTeamId
            seat = g.seat ?? ""
            companionIds = Set(g.companionIds)
            note = g.note ?? ""
            lineHome = g.lineHome
            lineAway = g.lineAway
            photoIds = g.photos.compactMap { ref -> String? in
                if case .library(let id) = ref { return id }
                return nil
            }
            keptPhotos = g.photos.filter { ref in
                if case .library = ref { return false }
                return true
            }
        } else if let d = draft {
            if let s = d.sport { sport = s }
            homeTeamId = d.homeTeamId
            awayTeamId = d.awayTeamId
            venueId = d.venueId
            if let date = d.date { self.date = date }
            seat = d.seatLine ?? ""
            fixRooting()
        }
    }

    private func fixRooting() {
        let sides = [homeTeamId, awayTeamId].compactMap { $0 }
        if let r = rootingForTeamId, sides.contains(r) { return }
        let favorites = Set(library.profile.favoriteTeamIds)
        rootingForTeamId = sides.first { favorites.contains($0) } ?? homeTeamId ?? awayTeamId
    }

    private func addPerson() {
        let name = newPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let p = library.addPerson(named: name)
        companionIds.insert(p.id)
        newPerson = ""
    }

    private func lookup() async {
        lookingUp = true
        lookupFailed = false
        defer { lookingUp = false }
        let venue = venueId.flatMap { library.venue($0) }
        guard let r = await ScoreLookup.mlb(on: date, venue: venue, teams: library.allTeams, homeTeamId: homeTeamId) else {
            lookupFailed = true
            return
        }
        if homeTeamId == nil { homeTeamId = r.homeTeamId }
        if awayTeamId == nil { awayTeamId = r.awayTeamId }
        homeScore = String(r.homeScore)
        awayScore = String(r.awayScore)
        lineHome = r.lineHome
        lineAway = r.lineAway
    }

    private func findPhotos() async {
        guard let venue = venueId.flatMap({ library.venue($0) }) else { return }
        findingPhotos = true
        defer { findingPhotos = false }
        guard await PhotoMatcher.requestAccess() else { return }
        let ids = await PhotoMatcher.photos(at: venue, around: date)
        for id in ids where !photoIds.contains(id) { photoIds.append(id) }
    }

    private func save() {
        guard let venueId else { return }
        var g = editing ?? GameEntry(sport: sport, date: date, venueId: venueId, origin: draft == nil ? .manual : .ticket)
        g.sport = sport
        g.date = date
        g.venueId = venueId
        if sport == .motorsport {
            g.homeTeamId = nil
            g.awayTeamId = nil
            g.homeScore = nil
            g.awayScore = nil
            g.rootingForTeamId = nil
            let race = raceName.trimmingCharacters(in: .whitespaces)
            g.competition = race.isEmpty ? nil : race
        } else {
            g.homeTeamId = homeTeamId
            g.awayTeamId = awayTeamId
            g.homeScore = Int(homeScore.trimmingCharacters(in: .whitespaces))
            g.awayScore = Int(awayScore.trimmingCharacters(in: .whitespaces))
            g.rootingForTeamId = rootingForTeamId
            // A looked-up line score only stays if it still adds up to the score.
            if lineHome.reduce(0, +) == g.homeScore, lineAway.reduce(0, +) == g.awayScore {
                g.lineHome = lineHome
                g.lineAway = lineAway
            } else if editing == nil {
                g.lineHome = []
                g.lineAway = []
            }
        }
        let seatText = seat.trimmingCharacters(in: .whitespacesAndNewlines)
        g.seat = seatText.isEmpty ? nil : seatText
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        g.note = noteText.isEmpty ? nil : noteText
        g.companionIds = companionIds.sorted()
        g.photos = allPhotos
        if editing == nil {
            library.add(g)
        } else {
            library.update(g)
        }
        finish()
    }

    private func finish() {
        if let onDone {
            onDone()
        } else {
            presenter.modal = nil
            dismiss()
        }
    }
}
