import SwiftUI
import MapKit

/// A ground as a story to share, in the passport's language: the ground from above in its team's color, your record and
/// nights there, your seats, your photos. Laid out at phone size (390 points wide) and scaled up to the story's pixels.
/// Needs `Library` in the environment; images come in already loaded.
struct VenueStoryCard: View {
    /// Kept from seven tried: the ground from above, and every night there. The other looks stay below for now.
    enum Style: CaseIterable {
        case aerial, nights

        var name: String {
            switch self {
            case .aerial: "From above"
            case .nights: "Every night"
            }
        }
    }

    struct Data {
        let venue: Venue
        let games: [GameEntry]
        let color: Color
        let code: String
        let aerial: UIImage?
        let photo: UIImage?
        let firstPhoto: UIImage?
        let sections: [Int]
    }

    @Environment(Library.self) private var library
    let style: Style
    let data: Data

    private static let width: CGFloat = 390
    private var scale: CGFloat { ShareCardFormat.story.size.width / Self.width }
    private var height: CGFloat { ShareCardFormat.story.size.height / scale }

    private var venue: Venue { data.venue }
    private var tz: TimeZone { venue.tz }
    private var record: Stats.Record { data.games.reduce(into: Stats.Record()) { $0.add(library.outcome($1)) } }
    private var nights: Int { data.games.count }
    private var years: String {
        let cal = Calendar(identifier: .gregorian)
        guard let a = data.games.first, let b = data.games.last else { return "" }
        let y1 = cal.component(.year, from: a.date), y2 = cal.component(.year, from: b.date)
        return y1 == y2 ? "\(y1)" : "\(y1)–\(y2)"
    }

    var body: some View {
        content
            .frame(width: Self.width, height: height)
            .background(Color.ink)
            .clipped()
            .environment(\.dynamicTypeSize, .large)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: ShareCardFormat.story.size.width, height: ShareCardFormat.story.size.height, alignment: .topLeading)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .aerial: aerialCard
        case .nights: nightsCard
        }
    }

    // MARK: Pieces

    private func wordmark(_ size: CGFloat = 26) -> some View {
        ZStack(alignment: .topLeading) {
            Text("SPORTS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(Color.signal)
                .offset(x: size, y: size * 0.75)
            Text("WITNESS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(.white)
        }
        .padding(.bottom, size * 0.75)
        .shadow(color: .black.opacity(0.3), radius: 4)
    }

    private func title(_ size: CGFloat = 52) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(venue.name.uppercased()).font(.display(size)).lineLimit(2).minimumScaleFactor(0.6)
            Text(venue.cityLine.uppercased()).font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(2.4)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
    }

    private func stat(_ value: String, _ label: String, accent: Bool = false, size: CGFloat = 40) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.display(size)).foregroundStyle(accent ? Color.signal : .white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(.system(size: 11, weight: .heavy).width(.condensed)).tracking(2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(nights)", nights == 1 ? "Night" : "Nights")
            if record.decided > 0 { stat(record.text, "Your record", accent: true) }
            stat(years, years.contains("–") ? "Years" : "Year")
        }
    }

    @ViewBuilder
    private func image(_ ui: UIImage?) -> some View {
        if let ui { Image(uiImage: ui).resizable().scaledToFill() } else { data.color.opacity(0.6) }
    }

    /// The ground from above in its team's color, as on a passport stamp.
    private var tinted: some View {
        data.color
            .overlay {
                if let aerial = data.aerial {
                    Image(uiImage: aerial).resizable().scaledToFill().saturation(0).opacity(0.6).blendMode(.luminosity)
                }
            }
    }

    // MARK: Looks

    /// The ground from above fills the story in its team's color.
    private var aerialCard: some View {
        ZStack(alignment: .bottomLeading) {
            tinted.frame(width: Self.width, height: height).clipped()
            LinearGradient(colors: [.clear, Color.ink.opacity(0.95)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                title(60)
                stats
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) { wordmark().padding(.top, 52).padding(.leading, 22) }
    }

    /// The passport stamp, big, as if just pressed.
    private var stampCard: some View {
        VStack(alignment: .leading, spacing: 26) {
            wordmark()
            Spacer(minLength: 0)
            StampFace(code: data.code, name: venue.name, date: data.games.first?.date, color: data.color, aerial: data.aerial)
                .frame(width: 112, height: 148)
                .scaleEffect(2.6)
                .rotationEffect(.degrees(-4))
                .frame(width: 290, height: 385)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            Spacer(minLength: 0)
            Text("STAMPED IN MY PASSPORT").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(3)
                .foregroundStyle(Color.signal)
            stats
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 40)
    }

    /// The record is the picture.
    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            wordmark()
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                AerialVenueIcon(venue: venue, sport: venue.sports.first ?? .baseball, size: 56, given: data.aerial)
                Text("MY RECORD AT").font(.system(size: 15, weight: .heavy).width(.condensed)).tracking(3)
                    .foregroundStyle(.white.opacity(0.7))
            }
            title(46)
            Text(record.decided > 0 ? record.text : "\(nights)")
                .font(.display(170)).foregroundStyle(Color.signal).lineLimit(1).minimumScaleFactor(0.4)
            Text(record.decided > 0 ? "WINS – LOSSES\(record.draws > 0 ? " – DRAWS" : "")" : (nights == 1 ? "NIGHT HERE" : "NIGHTS HERE"))
                .font(.system(size: 14, weight: .heavy).width(.condensed)).tracking(3).foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 0)
            if let first = data.games.first, let last = data.games.last {
                HStack(spacing: 0) {
                    stat(Fmt.day(first.date, in: tz), "First visit", size: 26)
                    stat(Fmt.day(last.date, in: tz), "Last visit", size: 26)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 40)
        .background {
            LinearGradient(colors: [data.color.opacity(0.5), Color.ink.opacity(0)], startPoint: .top, endPoint: .center)
        }
    }

    /// Where you sit: the bowl with your sections lit.
    private var seatsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            wordmark()
            title(48)
            if data.sections.isEmpty {
                tinted.frame(height: 330).clipShape(.rect(cornerRadius: 22))
            } else {
                SeatMap(sections: Array(data.sections.prefix(3))).frame(height: 330)
                Text(data.sections.count == 1 ? "SECTION \(data.sections[0])" : "SECTIONS " + data.sections.prefix(3).map(String.init).joined(separator: " · "))
                    .font(.display(34)).foregroundStyle(Color.signal)
            }
            Spacer(minLength: 0)
            stats
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 40)
    }

    /// Every game here, a line each, like a ticket stub book.
    private var nightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            wordmark()
            HStack(spacing: 12) {
                AerialVenueIcon(venue: venue, sport: venue.sports.first ?? .baseball, size: 52, given: data.aerial)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(nights) \(nights == 1 ? "NIGHT" : "NIGHTS") AT").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(2.6)
                        .foregroundStyle(Color.signal)
                    Text(venue.name.uppercased()).font(.display(34)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(data.games.reversed().prefix(9).enumerated()), id: \.offset) { _, g in row(g) }
            }
            if data.games.count > 9 {
                Text("+ \(data.games.count - 9) more").font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            if record.decided > 0 {
                Text("RECORD \(record.text)").font(.display(30)).foregroundStyle(Color.signal)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 40)
    }

    private func row(_ g: GameEntry) -> some View {
        let outcome = library.outcome(g)
        let mark = switch outcome { case .win: "W"; case .loss: "L"; case .draw: "D"; case .none: "·" }
        return HStack(spacing: 10) {
            Text(Fmt.day(g.date, in: tz).uppercased()).font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1.2)
                .foregroundStyle(.white.opacity(0.7)).frame(width: 96, alignment: .leading)
            if g.hasScore, let away = library.team(g.awayTeamId), let home = library.team(g.homeTeamId) {
                TeamTile(team: away, compact: true)
                Text("\(g.awayScore ?? 0)").font(.display(20))
                TeamTile(team: home, compact: true)
                Text("\(g.homeScore ?? 0)").font(.display(20))
            } else {
                Text(g.isVisit ? "STADIUM VISIT" : (g.competition ?? "").uppercased())
                    .font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(1.2).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(mark).font(.display(20)).foregroundStyle(outcome == .win ? Color.signal : .white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .frame(height: 38)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    /// Your best photo there, full bleed, with the ground's numbers on a stub.
    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            image(data.photo).frame(width: Self.width, height: height).clipped()
            Scrim()
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 12) {
                    AerialVenueIcon(venue: venue, sport: venue.sports.first ?? .baseball, size: 54, given: data.aerial)
                    title(46)
                }
                stats
                    .padding(16)
                    .background(Color.panelRaised.opacity(0.92), in: .rect(cornerRadius: 18))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) { wordmark().padding(.top, 52).padding(.leading, 22) }
    }

    /// The first visit and the latest, side by side.
    private var thenNowCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            wordmark()
            title(48)
            HStack(spacing: 8) {
                frame(data.firstPhoto, data.games.first)
                frame(data.photo, data.games.last)
            }
            .frame(height: 330)
            Spacer(minLength: 0)
            stats
        }
        .padding(.horizontal, 22)
        .padding(.top, 52)
        .padding(.bottom, 40)
    }

    private func frame(_ ui: UIImage?, _ g: GameEntry?) -> some View {
        Color.panel
            .overlay { image(ui) }
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, Color.ink.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    Text(g.map { String(Calendar(identifier: .gregorian).component(.year, from: $0.date)) } ?? "")
                        .font(.display(44)).foregroundStyle(.white).padding(12)
                }
            }
            .frame(width: (Self.width - 44 - 8) / 2, height: 330)
            .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: Loading

    /// The ground from above, big enough to fill a story (the map's own cache keeps small ones).
    @MainActor
    static func aerial(for venue: Venue) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: venue.coordinate, latitudinalMeters: 520, longitudinalMeters: 520)
        options.size = CGSize(width: 390, height: 390)
        options.mapType = .satellite
        options.traitCollection = UITraitCollection(displayScale: 3)
        return try? await MKMapSnapshotter(options: options).start().image
    }
}
