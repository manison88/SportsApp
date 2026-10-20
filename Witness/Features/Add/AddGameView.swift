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
    /// Planning a game that is coming up (one the schedules don't list): saved as a plan, with no score or photos.
    var planning = false
    var presetTeamId: String?
    var onPlanned: ((String) -> Void)?

    @State private var sport: Sport = .baseball
    @State private var isVisit = false
    @State private var visitType = Self.visitTypes[0]
    @State private var homeTeamId: String?
    @State private var awayTeamId: String?
    @State private var raceName = ""
    @State private var competition = ""
    /// What the fan calls the sport when it is Other.
    @State private var sportLabel = ""
    /// A free-text title for an Other game ("Sevens final").
    @State private var otherTitle = ""
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
    @State private var found: FoundGame?
    @State private var foundDetail: FoundDetail?
    @State private var foundTeams: [String?] = []
    @State private var findingPhotos = false
    @State private var didPrefill = false
    @State private var didAutoLookup = false
    @State private var photoDistanceMiles: Double?

    init(draft: TicketDraft? = nil, editing: GameEntry? = nil, embedded: Bool = false, planning: Bool = false, presetTeamId: String? = nil,
         onPlanned: ((String) -> Void)? = nil, onDone: (() -> Void)? = nil) {
        self.draft = draft
        self.editing = editing
        self.embedded = embedded
        self.planning = planning
        self.presetTeamId = presetTeamId
        self.onPlanned = onPlanned
        self.onDone = onDone
    }

    var body: some View {
        if embedded {
            form
        } else {
            NavigationStack { form }
        }
    }

    /// What a stadium visit can be tagged as, so it is a choice and not free text.
    static let visitTypes = ["Stadium tour", "Walk past", "Museum or hall of fame", "Tailgate", "Other visit"]

    private var form: some View {
        Form {
            if !planning {
                Section {
                    Picker("What is it", selection: $isVisit) {
                        Text("Game").tag(false)
                        Text("Stadium visit").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("add-kind")
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("Sport", selection: $sport) {
                    ForEach(Sport.allCases) { s in
                        Text(s.name).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("add-sport")

                if sport == .other {
                    OtherSportField(text: $sportLabel)
                    if !isVisit && !planning {
                        TextField("Title (optional)", text: $otherTitle)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("add-other-title")
                    }
                }

                if isVisit {
                    teamPicker("Whose stadium", selection: $homeTeamId, id: "add-home-team")
                    Picker("Type", selection: $visitType) {
                        ForEach(Self.visitTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("add-visit-type")
                } else if sport == .motorsport {
                    TextField("Race", text: $raceName)
                        .accessibilityIdentifier("add-race")
                    NavigationLink {
                        RacePickerView { race in pickRace(race) }
                    } label: {
                        Label("Choose from the race calendar", systemImage: "calendar")
                    }
                    .accessibilityIdentifier("add-race-calendar")
                } else {
                    teamPicker("Away", selection: $awayTeamId, id: "add-away-team")
                    teamPicker("Home", selection: $homeTeamId, id: "add-home-team")
                }

                if sport != .motorsport, !isVisit {
                    TextField("Competition or event (optional)", text: $competition)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("add-competition")
                }

                NavigationLink {
                    VenuePickerView(venueId: $venueId, sport: sport)
                } label: {
                    LabeledContent("Venue") {
                        Text(venueName)
                            .foregroundStyle(venueId == nil ? Color.textTertiary : Color.primaryText)
                            .accessibilityIdentifier("add-venue-name")
                    }
                }
                .accessibilityIdentifier("add-venue")

                DatePicker("Date", selection: $date)
                    .accessibilityIdentifier("add-date")

                if let warning = venueWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color.signal)
                        .accessibilityIdentifier("add-venue-warning")
                }
            }
            .listRowBackground(Color.panel)

            if !isVisit, sport == .motorsport, let venue = venueId.flatMap({ library.venue($0) }), !F1Calendar.races(at: venue.id).isEmpty {
                Section {
                    Button {
                        Task { await lookup() }
                    } label: {
                        HStack {
                            Label(isMatched ? "Found on the calendar" : "Find this race",
                                  systemImage: isMatched ? "checkmark.seal.fill" : "sparkle.magnifyingglass")
                            Spacer()
                            if lookingUp { ProgressView() }
                        }
                    }
                    .disabled(lookingUp)
                    .accessibilityIdentifier("add-lookup")
                    if let line = matchLine {
                        Text(line).font(.footnote).foregroundStyle(Color.textSecondary)
                            .accessibilityIdentifier("add-lookup-result")
                    }
                    if lookupFailed {
                        Text("No race weekend at this circuit on that day.").font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                }
                .listRowBackground(Color.panel)
            }

            if sport != .motorsport, !isVisit, !planning {
                Section {
                    scoreRow
                    if let home = homeTeamId, let away = awayTeamId {
                        VStack(alignment: .leading, spacing: 8) {
                            if let h = library.team(home), let a = library.team(away) {
                                RootingPicker(teams: [a, h], selection: $rootingForTeamId,
                                              known: !Set(library.profile.favoriteTeamIds).isDisjoint(with: [h.id, a.id]))
                            }
                        }
                        .accessibilityIdentifier("add-rooting")
                    }
                    if sport != .other, let venue = venueId.flatMap({ library.venue($0) }), !GameLookup.leagues(for: venue).isEmpty {
                        Button {
                            Task { await lookup() }
                        } label: {
                            HStack {
                                Label(isMatched ? "Found on the schedule" : "Find this game",
                                      systemImage: isMatched ? "checkmark.seal.fill" : "sparkle.magnifyingglass")
                                Spacer()
                                if lookingUp { ProgressView() }
                            }
                        }
                        .disabled(lookingUp)
                        .accessibilityIdentifier("add-lookup")
                        if lookingUp {
                            Text("Looking on the schedule\u{2026}")
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                        } else if let line = matchLine {
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                                .accessibilityIdentifier("add-lookup-result")
                        }
                        if lookupFailed {
                            Text("No game on the schedule at this venue that day.")
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

            if !planning {
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
                        Label(isVisit ? "Find photos from this visit" : "Find photos from this game", systemImage: "location.magnifyingglass")
                        Spacer()
                        if findingPhotos { ProgressView() }
                    }
                }
                .disabled(venueId == nil || findingPhotos)
                .accessibilityIdentifier("add-find-photos")
            }
            .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle(planning ? "Plan a game" : (editing == nil ? (isVisit ? "Add visit" : "Add game") : (isVisit ? "Edit visit" : "Edit game")))
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
                        .foregroundStyle(!canSave ? Color.textTertiary : Color.onPrimary)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primaryText)
                .disabled(!canSave)
                .accessibilityLabel("Save")
                .accessibilityIdentifier("add-save")
            }
        }
        .onAppear {
            prefill()
            autoLookup()
        }
        .onChange(of: sport) { _, _ in
            // Any team and any venue can host any sport (a national handball side in a basketball arena), so
            // changing the sport keeps what was picked.
        }
        .onChange(of: venueId) { _, _ in autoLookup() }
        .task(id: "\(venueId ?? "")-\(photoIds.count)") { await checkPhotoDistance() }
        .onChange(of: date) { _, _ in autoLookup() }
        .onChange(of: homeTeamId) { _, _ in verifyPicked() }
        .onChange(of: awayTeamId) { _, _ in verifyPicked() }
        .onChange(of: homeTeamId) { _, _ in fixRooting() }
        .onChange(of: awayTeamId) { _, _ in fixRooting() }
        .onChange(of: pickerItems) { _, items in
            for item in items {
                if let id = item.itemIdentifier, !photoIds.contains(id) { photoIds.append(id) }
            }
        }
    }

    // MARK: Pieces

    /// A stadium that does not fit what was entered: it does not host the sport, or the photos were taken far from it.
    private var venueWarning: String? {
        guard let venue = venueId.flatMap({ library.venue($0) }), !isVisit, sport != .motorsport, sport != .other else { return nil }
        if !library.hosts(venue, sport) {
            return "\(venue.name) doesn\u{2019}t usually host \(sport.name.lowercased()). Is it the right stadium?"
        }
        if let miles = photoDistanceMiles, miles > 12 {
            return "Your photos were taken about \(Fmt.distance(meters: miles * 1609.344)) from \(venue.name). Is it the right stadium?"
        }
        return nil
    }

    /// A ground, and for Other a name for what it was.
    private var canSave: Bool { venueId != nil && (sport != .other || sportLabel.trimmedOrNil != nil) }

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

    /// Any team for any game: opens the full team list (all sports) with a New team option.
    private func teamPicker(_ title: String, selection: Binding<String?>, id: String) -> some View {
        NavigationLink {
            TeamPickerView(selection: selection, sport: sport)
        } label: {
            LabeledContent(title) {
                if let t = library.team(selection.wrappedValue) {
                    HStack(spacing: 8) {
                        TeamTile(team: t, compact: true)
                        Text(t.locationName).foregroundStyle(Color.primaryText)
                    }
                } else {
                    Text("Choose").foregroundStyle(Color.textTertiary)
                }
            }
        }
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
            sportLabel = g.sportLabel ?? ""
            otherTitle = g.sport == .other ? (g.headline ?? "") : ""
            isVisit = g.isVisit
            if g.isVisit, let c = g.competition, Self.visitTypes.contains(c) { visitType = c }
            homeTeamId = g.homeTeamId
            awayTeamId = g.awayTeamId
            raceName = g.sport == .motorsport ? (g.competition ?? "") : ""
            competition = g.sport == .motorsport ? "" : (g.competition ?? "")
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
        } else if planning {
            if let id = presetTeamId, let team = library.team(id) {
                sport = team.sport
                homeTeamId = id
            }
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
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

    /// How far the first located photo is from the chosen stadium.
    private func checkPhotoDistance() async {
        photoDistanceMiles = nil
        guard let venue = venueId.flatMap({ library.venue($0) }), !photoIds.isEmpty,
              let here = await PhotoMatcher.location(ofPhotos: photoIds) else { return }
        photoDistanceMiles = venue.location.distance(from: here) / 1609.34
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

    /// True once this game is tied to a real schedule entry: found just now, or matched when it was saved.
    private var isMatched: Bool { found != nil || editing?.source != nil }

    /// What was matched, so it is plain whether the automatic lookup worked.
    private var matchLine: String? {
        let tz = venueId.flatMap { library.venue($0)?.tz } ?? .current
        if let race = found?.race {
            return "\(race.title) \u{00B7} Round \(race.round)" + (race.results?.winner?.name.map { " \u{00B7} Won by \($0)" } ?? "")
        }
        if let found {
            return "\(found.away.abbreviation) at \(found.home.abbreviation) \u{00B7} \(found.leagueName) \u{00B7} "
                + "\(Fmt.dayTitle(found.start, in: tz)), \(Fmt.time(found.start, in: tz))"
        }
        if let source = editing?.source { return "Matched to the schedule when it was saved \u{00B7} \(source.league)" }
        return nil
    }

    /// The day the fan means: the venue's calendar day and the fan's own calendar day for the form's date, so a game
    /// that starts in the evening at a stadium a few time zones away (or after midnight UTC) is still found.
    private func dayWindow(at venue: Venue) -> (Date, Date) {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = venue.tz
        var mine = Calendar(identifier: .gregorian)
        mine.timeZone = .current
        let venueDay = local.startOfDay(for: date)
        let myDay = mine.startOfDay(for: date)
        return (min(venueDay, myDay).addingTimeInterval(5 * 3600), max(venueDay, myDay).addingTimeInterval(24 * 3600))
    }

    /// A saved game that has teams but no schedule match: find the same game and attach it, leaving what the fan entered alone.
    private func verify() async {
        defer { lookingUp = false }
        guard let venue = venueId.flatMap({ library.venue($0) }),
              let home = library.team(homeTeamId), let away = library.team(awayTeamId) else { return }
        let window = dayWindow(at: venue)
        let games = await GameLookup.games(at: venue, from: window.0, to: window.1)
        guard let game = games.first(where: { Set([$0.home.abbreviation, $0.away.abbreviation]) == Set([home.abbreviation, away.abbreviation]) })
        else { return }
        found = game
        if game.home.abbreviation != home.abbreviation {   // the schedule has them the other way round
            homeTeamId = away.id
            awayTeamId = home.id
        }
        date = game.start
        foundTeams = [homeTeamId, awayTeamId]
        foundDetail = await GameLookup.detail(game)
    }

    /// Teams picked by hand at a venue on a day: if the schedule has that game, attach it.
    private func verifyPicked() {
        guard !planning else { return }
        guard found == nil, !lookingUp, sport != .motorsport, homeTeamId != nil, awayTeamId != nil,
              let venue = venueId.flatMap({ library.venue($0) }), !GameLookup.leagues(for: venue).isEmpty else { return }
        lookingUp = true
        Task { await verify() }
    }

    /// Looks the game up as soon as a venue and day are set, but only on a new game with no teams picked yet, so
    /// nothing the fan typed is overwritten. "Find this game" stays for everything else.
    private func autoLookup() {
        guard !planning, !isVisit, sport != .other, found == nil, !lookingUp,
              let venue = venueId.flatMap({ library.venue($0) }), !GameLookup.leagues(for: venue).isEmpty else { return }
        let noTeamsYet = homeTeamId == nil && awayTeamId == nil
        if let editing {
            // A saved stadium visit, or an entry with no teams and no schedule match: look for its game once.
            guard !didAutoLookup, editing.source == nil else { return }
            if !(editing.isVisit || (editing.homeTeamId == nil && editing.awayTeamId == nil)) {
                // It has teams: verify them against the schedule without touching what is there.
                didAutoLookup = true
                lookingUp = true
                Task { await verify() }
                return
            }
        } else if !noTeamsYet {
            // A ticket brings its teams along: verify them against the schedule once, when the form opens.
            guard draft != nil, !didAutoLookup else { return }
        }
        didAutoLookup = true
        lookingUp = true   // set now, so a second change in the same moment does not start another lookup
        Task { await lookup() }
    }

    /// A race chosen from the calendar sets the circuit, the date and the name in one go.
    private func pickRace(_ race: F1Race) {
        sport = .motorsport
        venueId = race.circuitId
        date = race.start
        raceName = race.title
        homeTeamId = nil
        awayTeamId = nil
        found = F1Calendar.found(race, venue: library.venue(race.circuitId))
        foundTeams = [nil, nil]
        lookupFailed = false
    }

    /// Finds the real game at this venue on this day and fills the form from it.
    private func lookup() async {
        guard sport != .other, let venue = venueId.flatMap({ library.venue($0) }) else { return }
        lookingUp = true
        lookupFailed = false
        defer { lookingUp = false }
        let window = dayWindow(at: venue)
        let games = await GameLookup.games(at: venue, from: window.0, to: window.1)
        // Closest start to the time on the form wins (doubleheaders).
        guard let game = games.min(by: { abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date)) }) else {
            lookupFailed = true
            return
        }
        found = game
        sport = game.sport
        date = game.start
        if let race = game.race {
            raceName = race.title
            homeTeamId = nil
            awayTeamId = nil
            foundTeams = [nil, nil]
            return
        }
        homeTeamId = library.addTeam(GameLookup.team(from: game.home, game: game)).id
        awayTeamId = library.addTeam(GameLookup.team(from: game.away, game: game)).id
        foundTeams = [homeTeamId, awayTeamId]
        if game.completed {
            homeScore = game.home.score.map(String.init) ?? ""
            awayScore = game.away.score.map(String.init) ?? ""
        }
        lineHome = game.home.line
        lineAway = game.away.line
        foundDetail = await GameLookup.detail(game)
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
        if planning {
            var plan = GameEntry(sport: sport, date: date, venueId: venueId, origin: .manual)
            plan.homeTeamId = sport == .motorsport ? nil : homeTeamId
            plan.awayTeamId = sport == .motorsport ? nil : awayTeamId
            let title = (sport == .motorsport ? raceName : competition).trimmingCharacters(in: .whitespacesAndNewlines)
            plan.competition = title.isEmpty ? nil : title
            plan.sportLabel = sport == .other ? sportLabel.trimmedOrNil : nil
            let seatText = seat.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.seat = seatText.isEmpty ? nil : seatText
            let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
            plan.note = noteText.isEmpty ? nil : noteText
            plan.companionIds = companionIds.sorted()
            library.addManualPlan(plan)
            onPlanned?(plan.id)
            finish()
            return
        }
        var g = editing ?? GameEntry(sport: sport, date: date, venueId: venueId, origin: draft == nil ? .manual : .ticket)
        g.sport = sport
        g.sportLabel = sport == .other ? sportLabel.trimmedOrNil : nil
        if sport == .other, !isVisit { g.headline = otherTitle.trimmedOrNil }
        g.date = date
        g.venueId = venueId
        if isVisit {
            // A visit needs a ground and, to say whose it is, a home team.
            g.kind = .visit
            g.homeTeamId = homeTeamId
            g.awayTeamId = nil
            g.homeScore = nil
            g.awayScore = nil
            g.rootingForTeamId = nil
            g.competition = visitType
            g.lineHome = []
            g.lineAway = []
            g.plays = []
            g.winProbability = []
        } else if sport == .motorsport {
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
            // Typed freely: "EHF Champions League", "Group stage", "Friendly". A title or playoff wording earns the badge.
            let comp = competition.trimmingCharacters(in: .whitespacesAndNewlines)
            g.competition = comp.isEmpty ? nil : comp
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
        // Only keep the schedule's stats if the fan didn't change the teams afterwards.
        if !isVisit, let found, foundTeams == [homeTeamId, awayTeamId] {
            let keepScores = (g.homeScore, g.awayScore)
            GameLookup.apply(found, detail: foundDetail, to: &g, library: library)
            // What the fan typed wins over the schedule.
            if keepScores.0 != nil { g.homeScore = keepScores.0 }
            if keepScores.1 != nil { g.awayScore = keepScores.1 }
            g.rootingForTeamId = rootingForTeamId
            // A stadium visit that turned out to be a scheduled game is a game now.
            g.kind = nil
        } else if !isVisit {
            g.kind = nil
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

/// Every race on the calendar, newest season first. Picking one fills the circuit, the date and the race.
struct RacePickerView: View {
    let onPick: (F1Race) -> Void

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            ForEach(sections, id: \.season) { section in
                Section(String(section.season)) {
                    ForEach(section.races) { race in
                        Button {
                            onPick(race)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text("R\(race.round)").font(.condensed(.subheadline, weight: .heavy))
                                    .foregroundStyle(Color.textSecondary).frame(width: 34, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(race.shortName).font(.condensed(.headline)).foregroundStyle(Color.primaryText)
                                    Text([library.venue(race.circuitId)?.name, race.raceLocalDate].compactMap { $0 }.joined(separator: " \u{00B7} "))
                                        .font(.footnote).foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                if race.status == "cancelled" {
                                    Text("Cancelled").font(.footnote).foregroundStyle(Color.textTertiary)
                                } else if let winner = race.results?.winner?.code {
                                    Text(winner).font(.condensed(.subheadline, weight: .heavy)).foregroundStyle(Color.textSecondary)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .disabled(race.status == "cancelled")
                        .accessibilityIdentifier("race-row-\(race.id)")
                    }
                }
                .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search races and circuits")
        .navigationTitle("Race calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sections: [(season: Int, races: [F1Race])] {
        let q = TicketParser.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return F1Calendar.seasons().compactMap { s in
            let races = q.isEmpty ? s.races : s.races.filter {
                TicketParser.normalize($0.name).contains(q) || TicketParser.normalize($0.shortName).contains(q)
                    || TicketParser.normalize(library.venue($0.circuitId)?.name ?? "").contains(q)
                    || TicketParser.normalize(library.venue($0.circuitId)?.city ?? "").contains(q)
                    || String(s.season).contains(q)
            }
            return races.isEmpty ? nil : (s.season, races)
        }
    }
}
