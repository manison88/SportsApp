import SwiftUI

/// What the Map's Venues, Countries and Games numbers open, pushed (not a sheet, so the swipe back still works): every one of them as a compact tile. Tap a venue for its page,
/// a game for its page, a country for the games played there.
enum MapList: String, Identifiable {
    case venues, countries, games
    var id: String { rawValue }

    var title: String {
        switch self {
        case .venues: "Venues"
        case .countries: "Countries"
        case .games: "Games"
        }
    }
}

struct MapListSheet: View {
    let kind: MapList
    let games: [GameEntry]

    @Environment(Library.self) private var library

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                switch kind {
                case .venues: venueTiles
                case .countries: countryTiles
                case .games: gameTiles(games.sorted { $0.date > $1.date })
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Venues

    private var venueTiles: some View {
        let grouped = Dictionary(grouping: games, by: \.venueId)
        let rows = grouped.compactMap { id, list in library.venue(id).map { VenueRow(venue: $0, games: list) } }
            .sorted { $0.games.count != $1.games.count ? $0.games.count > $1.games.count : $0.venue.name < $1.venue.name }
        return ForEach(rows) { row in
            let venue = row.venue, list = row.games
            NavigationLink(value: Route.venue(venue.id)) {
                tile(lead: AnyView(VenueGlyph(sport: Self.mainSport(of: venue, in: list), size: 40)),
                     title: venue.name,
                     detail: venue.cityLine + " \u{00B7} " + venue.country,
                     trailTop: "\(list.count) \(list.count == 1 ? "game" : "games")",
                     trailBottom: list.map(\.date).max().map { "Last " + Fmt.short($0, in: venue.tz) })
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-venue-\(venue.id)")
        }
    }

    /// The sport most seen at a venue, else the first sport it hosts.
    private static func mainSport(of venue: Venue, in games: [GameEntry]) -> Sport {
        let counts = Dictionary(grouping: games, by: \.sport).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? venue.sports.first ?? .baseball
    }

    // MARK: Countries

    private var countryTiles: some View {
        let grouped = Dictionary(grouping: games) { library.venue($0.venueId)?.countryCode ?? "" }
        let rows = grouped.filter { !$0.key.isEmpty }.map { CountryRow(code: $0.key, games: $0.value) }
            .sorted { $0.games.count != $1.games.count ? $0.games.count > $1.games.count : $0.code < $1.code }
        return ForEach(rows) { row in
            let code = row.code, list = row.games
            let venues = Set(list.map(\.venueId))
            let name = venues.compactMap { library.venue($0)?.country }.first ?? code
            NavigationLink(value: CountryRoute(code: code)) {
                tile(lead: AnyView(CountryGlobe(code: code, size: 40)),
                     title: name,
                     detail: "\(venues.count) \(venues.count == 1 ? "venue" : "venues")",
                     trailTop: "\(list.count) \(list.count == 1 ? "game" : "games")",
                     trailBottom: list.map(\.date).max().map { "Last " + String(Fmt.year($0)) })
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-country-\(code)")
        }
    }

    // MARK: Games

    private func gameTiles(_ list: [GameEntry]) -> some View {
        ForEach(list) { game in
            let venue = library.venue(game.venueId)
            NavigationLink(value: Route.game(game.id)) {
                tile(lead: AnyView(dateChip(game, tz: venue?.tz ?? .current)),
                     title: matchupText(game, library),
                     detail: [venue?.name, game.competition].compactMap { $0 }.joined(separator: " \u{00B7} "),
                     trailTop: nil, trailBottom: nil, trailing: AnyView(ScoreBug(game: game)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("map-game-\(game.id)")
        }
    }

    private func dateChip(_ game: GameEntry, tz: TimeZone) -> some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.day, .month, .year], from: game.date)
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return VStack(spacing: 0) {
            Text("\(c.day ?? 1)").font(.condensed(.title2, weight: .heavy)).monospacedDigit()
            Text(months[((c.month ?? 1) - 1) % 12]).font(.condensed(.caption2, weight: .heavy)).tracking(1.5)
                .foregroundStyle(Color.textSecondary)
        }
        .foregroundStyle(.white)
    }

    // MARK: Tile

    private func tile(lead: AnyView, title: String, detail: String, trailTop: String?, trailBottom: String?,
                      trailing: AnyView? = nil) -> some View {
        HStack(spacing: 12) {
            lead.frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                trailing
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    if let trailTop { Text(trailTop).font(.condensed(.subheadline, weight: .heavy)) }
                    if let trailBottom { Text(trailBottom).font(.caption).foregroundStyle(Color.textSecondary) }
                }
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(Color.panel, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
    }
}

private struct CountryRow: Identifiable {
    let code: String
    let games: [GameEntry]
    var id: String { code }
}

private struct VenueRow: Identifiable {
    let venue: Venue
    let games: [GameEntry]
    var id: String { venue.id }
}

/// A country picked from the list.
struct CountryRoute: Hashable { let code: String }

/// The games played in one country.
struct CountryGames: View {
    let code: String
    let games: [GameEntry]
    @Environment(Library.self) private var library

    var body: some View {
        let list = games.filter { library.venue($0.venueId)?.countryCode == code }.sorted { $0.date > $1.date }
        let name = list.compactMap { library.venue($0.venueId)?.country }.first ?? code
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(list) { game in
                    let venue = library.venue(game.venueId)
                    NavigationLink(value: Route.game(game.id)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(matchupText(game, library)).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text([venue?.name, Fmt.dayTitle(game.date, in: venue?.tz ?? .current)].compactMap { $0 }.joined(separator: " \u{00B7} "))
                                    .font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            ScoreBug(game: game)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 64)
                        .background(Color.panel, in: .rect(cornerRadius: 14))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map-country-game-\(game.id)")
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, Spacing.block)
        }
        .inkBackground()
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}


// MARK: - Venue glyph

/// A little top-down stadium: the bowl around a field drawn with the sport's own markings. One look per sport.
struct VenueGlyph: View {
    let sport: Sport
    var size: CGFloat = 40

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width, h = canvas.height
            let rect = CGRect(origin: .zero, size: canvas.size)
            ctx.fill(Path(roundedRect: rect, cornerRadius: w * 0.28), with: .color(Color.panelRaised))
            // The bowl: two rings, like seating tiers seen from above.
            let bowl = rect.insetBy(dx: w * 0.1, dy: h * 0.18)
            ctx.stroke(Path(roundedRect: bowl, cornerRadius: bowl.height * 0.5), with: .color(.white.opacity(0.28)), lineWidth: w * 0.07)
            let inner = bowl.insetBy(dx: w * 0.1, dy: h * 0.1)
            ctx.stroke(Path(roundedRect: inner, cornerRadius: inner.height * 0.5), with: .color(.white.opacity(0.14)), lineWidth: w * 0.04)
            // The field.
            let field = inner.insetBy(dx: w * 0.07, dy: h * 0.05)
            let line = sport.lineColor
            let lw = max(w * 0.032, 1)
            switch sport {
            case .baseball:
                ctx.fill(Path(ellipseIn: field.insetBy(dx: field.width * 0.02, dy: 0)), with: .color(line.opacity(0.18)))
                var d = Path()
                let c = CGPoint(x: field.midX, y: field.maxY - field.height * 0.08)
                let r = field.height * 0.42
                d.move(to: CGPoint(x: c.x, y: c.y))
                d.addLine(to: CGPoint(x: c.x + r, y: c.y - r)); d.addLine(to: CGPoint(x: c.x, y: c.y - 2 * r))
                d.addLine(to: CGPoint(x: c.x - r, y: c.y - r)); d.closeSubpath()
                ctx.stroke(d, with: .color(line), lineWidth: lw)
            case .football:
                ctx.fill(Path(roundedRect: field, cornerRadius: 2), with: .color(line.opacity(0.18)))
                ctx.stroke(Path(roundedRect: field, cornerRadius: 2), with: .color(line), lineWidth: lw)
                for i in 1..<5 {
                    var p = Path(); let x = field.minX + field.width * CGFloat(i) / 5
                    p.move(to: CGPoint(x: x, y: field.minY)); p.addLine(to: CGPoint(x: x, y: field.maxY))
                    ctx.stroke(p, with: .color(line.opacity(0.7)), lineWidth: lw * 0.7)
                }
            case .basketball, .handball:
                ctx.stroke(Path(roundedRect: field, cornerRadius: 2), with: .color(line), lineWidth: lw)
                var p = Path(); p.move(to: CGPoint(x: field.midX, y: field.minY)); p.addLine(to: CGPoint(x: field.midX, y: field.maxY))
                ctx.stroke(p, with: .color(line.opacity(0.8)), lineWidth: lw * 0.8)
                let key = field.height * 0.46
                ctx.stroke(Path(CGRect(x: field.minX, y: field.midY - key / 2, width: field.width * 0.22, height: key)), with: .color(line), lineWidth: lw * 0.8)
                ctx.stroke(Path(CGRect(x: field.maxX - field.width * 0.22, y: field.midY - key / 2, width: field.width * 0.22, height: key)), with: .color(line), lineWidth: lw * 0.8)
            case .hockey:
                ctx.stroke(Path(roundedRect: field, cornerRadius: field.height * 0.35), with: .color(line), lineWidth: lw)
                var p = Path(); p.move(to: CGPoint(x: field.midX, y: field.minY)); p.addLine(to: CGPoint(x: field.midX, y: field.maxY))
                ctx.stroke(p, with: .color(.red.opacity(0.8)), lineWidth: lw * 0.8)
                ctx.stroke(Path(ellipseIn: CGRect(x: field.midX - field.height * 0.2, y: field.midY - field.height * 0.2, width: field.height * 0.4, height: field.height * 0.4)),
                           with: .color(line.opacity(0.8)), lineWidth: lw * 0.7)
            case .motorsport:
                var t = Path()
                t.move(to: CGPoint(x: field.minX + field.width * 0.1, y: field.midY))
                t.addCurve(to: CGPoint(x: field.midX, y: field.minY), control1: CGPoint(x: field.minX, y: field.minY), control2: CGPoint(x: field.minX + field.width * 0.3, y: field.minY))
                t.addCurve(to: CGPoint(x: field.maxX - field.width * 0.05, y: field.midY + field.height * 0.1), control1: CGPoint(x: field.midX + field.width * 0.3, y: field.minY), control2: CGPoint(x: field.maxX, y: field.midY - field.height * 0.3))
                t.addCurve(to: CGPoint(x: field.midX, y: field.maxY), control1: CGPoint(x: field.maxX, y: field.maxY), control2: CGPoint(x: field.midX + field.width * 0.2, y: field.maxY))
                t.addCurve(to: CGPoint(x: field.minX + field.width * 0.1, y: field.midY), control1: CGPoint(x: field.minX + field.width * 0.2, y: field.maxY), control2: CGPoint(x: field.minX, y: field.maxY))
                ctx.stroke(t, with: .color(line), style: StrokeStyle(lineWidth: lw * 1.6, lineCap: .round, lineJoin: .round))
            case .soccer:
                ctx.fill(Path(roundedRect: field, cornerRadius: 2), with: .color(line.opacity(0.18)))
                ctx.stroke(Path(roundedRect: field, cornerRadius: 2), with: .color(line), lineWidth: lw)
                var p = Path(); p.move(to: CGPoint(x: field.midX, y: field.minY)); p.addLine(to: CGPoint(x: field.midX, y: field.maxY))
                ctx.stroke(p, with: .color(line.opacity(0.8)), lineWidth: lw * 0.8)
                let r = field.height * 0.22
                ctx.stroke(Path(ellipseIn: CGRect(x: field.midX - r, y: field.midY - r, width: 2 * r, height: 2 * r)), with: .color(line.opacity(0.8)), lineWidth: lw * 0.8)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Country globe

/// Outlines of the world's countries, for the little globes.
enum CountryShapes {
    /// Rings of (longitude, latitude) in degrees, by two-letter country code.
    static let all: [String: [[CGPoint]]] = {
        struct Item: Decodable { let c: String; let r: [[Int]] }
        guard let url = Bundle.main.url(forResource: "country-shapes", withExtension: "json", subdirectory: "Catalog")
                ?? Bundle.main.url(forResource: "country-shapes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [:] }
        var out: [String: [[CGPoint]]] = [:]
        for item in items {
            out[item.c] = item.r.map { flat in
                stride(from: 0, to: flat.count - 1, by: 2).map { CGPoint(x: Double(flat[$0]) / 10, y: Double(flat[$0 + 1]) / 10) }
            }
        }
        return out
    }()

    /// The middle of a country's biggest piece, to centre a globe on.
    static func center(_ code: String) -> CGPoint? {
        guard let rings = all[code], let biggest = rings.max(by: { $0.count < $1.count }), !biggest.isEmpty else { return nil }
        // Average on the circle so a country across the date line (Fiji, Russia) still lands in the right place.
        var sx = 0.0, sy = 0.0, lat = 0.0
        for p in biggest {
            sx += cos(p.x * .pi / 180); sy += sin(p.x * .pi / 180); lat += p.y
        }
        return CGPoint(x: atan2(sy, sx) * 180 / .pi, y: lat / Double(biggest.count))
    }
}

/// A small globe turned to a country, with that country filled in yellow.
struct CountryGlobe: View {
    let code: String
    var size: CGFloat = 40

    private static let yellow = Color(hex: "F7D64A")

    var body: some View {
        Canvas { ctx, canvas in
            let r = min(canvas.width, canvas.height) / 2 - 1
            let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let globe = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(globe, with: .color(Color.panelRaised))
            let center = CountryShapes.center(code) ?? CGPoint(x: 0, y: 20)
            let lon0 = center.x * .pi / 180, lat0 = center.y * .pi / 180
            func project(_ p: CGPoint) -> CGPoint? {
                let lam = p.x * .pi / 180 - lon0, phi = p.y * .pi / 180
                let visible = sin(lat0) * sin(phi) + cos(lat0) * cos(phi) * cos(lam)
                guard visible > 0 else { return nil }
                let x = cos(phi) * sin(lam)
                let y = cos(lat0) * sin(phi) - sin(lat0) * cos(phi) * cos(lam)
                return CGPoint(x: c.x + x * r, y: c.y - y * r)
            }
            // A light grid of latitude and longitude lines.
            var grid = Path()
            for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
                var started = false
                for lon in stride(from: -180.0, through: 180.0, by: 6.0) {
                    if let q = project(CGPoint(x: lon, y: lat)) { if started { grid.addLine(to: q) } else { grid.move(to: q); started = true } } else { started = false }
                }
            }
            for lon in stride(from: -180.0, to: 180.0, by: 30.0) {
                var started = false
                for lat in stride(from: -90.0, through: 90.0, by: 6.0) {
                    if let q = project(CGPoint(x: lon, y: lat)) { if started { grid.addLine(to: q) } else { grid.move(to: q); started = true } } else { started = false }
                }
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.10)), lineWidth: 0.5)
            // Every country, dim; then the one that matters, yellow.
            func draw(_ rings: [[CGPoint]], fill: Color) {
                for ring in rings {
                    var path = Path()
                    var any = false
                    for p in ring {
                        guard let q = project(p) else { continue }
                        if any { path.addLine(to: q) } else { path.move(to: q); any = true }
                    }
                    if any { path.closeSubpath(); ctx.fill(path, with: .color(fill)) }
                }
            }
            for (other, rings) in CountryShapes.all where other != code { draw(rings, fill: .white.opacity(0.22)) }
            if let rings = CountryShapes.all[code] {
                draw(rings, fill: Self.yellow)
            } else {
                // No outline for this one (a very small country): a yellow dot at the centre of the globe.
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.12, y: c.y - r * 0.12, width: r * 0.24, height: r * 0.24)), with: .color(Self.yellow))
            }
            ctx.stroke(globe, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
