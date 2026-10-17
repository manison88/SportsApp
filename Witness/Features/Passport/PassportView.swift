import SwiftUI

/// 03 · Passport. A stamp for every park you've been to.
struct PassportView: View {
    @Environment(Library.self) private var library
    @State private var sport: Sport = .baseball

    struct Stamp: Identifiable {
        let venueId: String
        let code: String
        let color: Color
        let date: Date?
        /// Title games seen here; earns the stamp a gold star.
        var titles = 0
        var id: String { venueId }
    }

    private var sports: [Sport] {
        let present = Set(library.games.map(\.sport))
        return Sport.allCases.filter { $0 == .baseball || present.contains($0) }
    }

    var body: some View {
        let all = stamps()
        let titleVenues = Dictionary(grouping: library.games.filter { $0.sport == sport && $0.bigGame?.kind == .championship },
                                     by: \.venueId).mapValues(\.count)
        let earned = all.0.map { s -> Stamp in var s = s; s.titles = titleVenues[s.venueId] ?? 0; return s }
        let missing = all.1
        let latest = earned.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                filter

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        Text("\(earned.count)")
                            .displayFont(150)
                            .accessibilityIdentifier("passport-count")
                        Text(heroLabel(earned: earned.count))
                            .displayFont(40, relativeTo: .title)
                            .textCase(.uppercase)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)

                    if sport == .baseball {
                        SegmentBar(total: library.ballparks.count, filled: earned.count)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(earned) { stamp in
                        NavigationLink(value: Route.venue(stamp.venueId)) {
                            StampTile(stamp: stamp, isLatest: stamp.id == latest?.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stamp-\(stamp.venueId)")
                    }
                    ForEach(missing.prefix(earned.count % 3 == 0 ? 3 : 3 + (3 - earned.count % 3))) { stamp in
                        GhostTile(stamp: stamp)
                    }
                }
            }
            .gutter()
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .tabTitle("Passport")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(earned.count) \(heroLabel(earned: earned.count).lowercased()), witnessed in person.") {
                    Image(systemName: "square.and.arrow.up").fontWeight(.bold)
                }
                .accessibilityLabel("Share passport")
            }
        }
    }

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sports) { s in
                    Button {
                        sport = s
                    } label: {
                        Text(Self.league(s))
                            .font(.condensed(.subheadline, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(sport == s ? Color.black : Color.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(sport == s ? Color.white : Color.panelRaised, in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sport == s ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    static func league(_ s: Sport) -> String {
        switch s {
        case .baseball: "MLB"
        case .football: "NFL"
        case .basketball: "NBA"
        case .hockey: "NHL"
        case .soccer: "SOCCER"
        case .motorsport: "F1"
        case .handball: "HANDBALL"
        }
    }

    private func heroLabel(earned: Int) -> String {
        switch sport {
        case .baseball: "of \(library.ballparks.count)\nMLB parks"
        case .soccer: earned == 1 ? "football\nground" : "football\ngrounds"
        case .motorsport: earned == 1 ? "circuit" : "circuits"
        case .handball: earned == 1 ? "handball\narena" : "handball\narenas"
        case .basketball, .hockey: earned == 1 ? "\(Self.league(sport))\narena" : "\(Self.league(sport))\narenas"
        case .football: earned == 1 ? "NFL\nstadium" : "NFL\nstadiums"
        }
    }

    /// Earned stamps (oldest first) and the parks still to visit.
    private func stamps() -> ([Stamp], [Stamp]) {
        let games = library.games.filter { $0.sport == sport }
        var firstVisit: [String: Date] = [:]
        for g in games { firstVisit[g.venueId] = min(firstVisit[g.venueId] ?? g.date, g.date) }

        if sport == .baseball {
            let all = library.ballparks.map { bp -> Stamp in
                let team = library.allTeams.first { $0.league == "MLB" && $0.abbreviation == bp.code }
                return Stamp(venueId: bp.venueId, code: bp.code, color: team?.accent ?? Color.panelRaised, date: firstVisit[bp.venueId])
            }
            let earned = all.filter { $0.date != nil }.sorted { $0.date! < $1.date! }
            let missing = all.filter { $0.date == nil }
            // Ballpark-less venues (spring training, minor league) still earn a stamp.
            let extra = firstVisit.keys.filter { id in !all.contains { $0.venueId == id } }.compactMap { stamp(for: $0, games: games, date: firstVisit[$0]) }
            return ((earned + extra).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }, missing)
        }

        let earned = firstVisit.keys.compactMap { stamp(for: $0, games: games, date: firstVisit[$0]) }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        return (earned, [])
    }

    /// A venue's stamp wears the color of the team that plays there most.
    private func stamp(for venueId: String, games: [GameEntry], date: Date?) -> Stamp? {
        guard let venue = library.venue(venueId) else { return nil }
        let homes = games.filter { $0.venueId == venueId }.compactMap(\.homeTeamId)
        let top = Dictionary(grouping: homes, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        let team = library.team(top)
        let code = team?.abbreviation ?? String(venue.name.filter(\.isLetter).prefix(3)).uppercased()
        return Stamp(venueId: venueId, code: code, color: team?.accent ?? Color(hex: "3A4150"), date: date)
    }
}

private struct SegmentBar: View {
    let total: Int
    let filled: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < filled ? Color.white : Color.panelRaised)
                    .frame(height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(filled) of \(total)")
    }
}

private struct StampTile: View {
    @Environment(Library.self) private var library
    let stamp: PassportView.Stamp
    let isLatest: Bool

    var body: some View {
        let ink = stamp.color.readableInk
        VStack(alignment: .leading, spacing: 6) {
            Text(stamp.code)
                .displayFont(34, relativeTo: .title)
                .foregroundStyle(ink)
            // The code is the team's; the stadium is the stamp's real name.
            if let name = library.venue(stamp.venueId)?.name {
                Text(name)
                    .font(.condensed(.caption, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(stamp.date.map { Fmt.day($0) } ?? "")
                .font(.condensed(.caption2, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .background(stamp.color, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ink.opacity(0.22), lineWidth: 1.5).padding(5))
        .overlay(alignment: .topTrailing) {
            if stamp.titles > 0 {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.trophy)
                    .padding(6)
                    .background(Color.ink.opacity(0.85), in: .circle)
                    .padding(8)
                    .accessibilityLabel(stamp.titles == 1 ? "Title game seen here" : "\(stamp.titles) title games seen here")
            }
        }
        .overlay {
            if isLatest {
                RoundedRectangle(cornerRadius: 19).strokeBorder(.white, lineWidth: 2.5).padding(-4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GhostTile: View {
    @Environment(Library.self) private var library
    let stamp: PassportView.Stamp

    var body: some View {
        let name = library.venue(stamp.venueId)?.name
        VStack(alignment: .leading, spacing: 6) {
            Text(stamp.code)
                .displayFont(34, relativeTo: .title)
                .foregroundStyle(Color.textTertiary)
            if let name {
                Text(name)
                    .font(.condensed(.caption, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stamp.code), \(name ?? ""), not visited yet")
    }
}
