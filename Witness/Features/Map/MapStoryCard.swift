import SwiftUI
import MapKit

/// A still of the map for a share card: a MapKit snapshot with every venue (and home) projected onto it.
struct MapShot {
    struct Pin { let venue: Venue; let point: CGPoint; let color: Color }
    let image: UIImage
    let home: CGPoint?
    let pins: [Pin]
    let size: CGSize

    /// Snapshots the region around home and the venues at `size` points. Nil with no venues.
    @MainActor
    static func make(venues: [Venue], colors: [String: Color], home: CLLocationCoordinate2D?, size: CGSize,
                     type: MKMapType = .mutedStandard, dark: Bool = true) async -> MapShot? {
        guard !venues.isEmpty else { return nil }
        var coords = venues.map(\.coordinate)
        if let home { coords.append(home) }
        var rect = MKMapRect.null
        for c in coords {
            let p = MKMapPoint(c)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        // Breathing room, a sensible minimum (one stadium is not a map), then the card's shape.
        let minSide = MKMapSize(width: 600_000, height: 600_000)
        rect = rect.insetBy(dx: -max(rect.width * 0.18, (minSide.width - rect.width) / 2),
                            dy: -max(rect.height * 0.22, (minSide.height - rect.height) / 2))
        let aspect = size.width / size.height
        if rect.width / rect.height > aspect {
            let h = rect.width / aspect
            rect = MKMapRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
        } else {
            let w = rect.height * aspect
            rect = MKMapRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height)
        }
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.mapType = type
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light), UITraitCollection(displayScale: 3),
        ])
        guard let snap = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return MapShot(image: snap.image, home: home.map { snap.point(for: $0) },
                       pins: venues.map { Pin(venue: $0, point: snap.point(for: $0.coordinate), color: colors[$0.id] ?? .white) },
                       size: size)
    }
}

/// The snapshot with arcs from home to each venue in its sport's color, and a dot on every venue.
struct MapShotView: View {
    let shot: MapShot
    var arcs = true
    var lineColor: Color? = nil
    var dimmed = 0.0

    var body: some View {
        Image(uiImage: shot.image).resizable()
            .frame(width: shot.size.width, height: shot.size.height)
            .overlay(Color.black.opacity(dimmed))
            .overlay {
                Canvas { ctx, _ in
                    if arcs, let home = shot.home {
                        for pin in shot.pins {
                            var path = Path()
                            path.move(to: home)
                            let mid = CGPoint(x: (home.x + pin.point.x) / 2, y: (home.y + pin.point.y) / 2)
                            let d = hypot(pin.point.x - home.x, pin.point.y - home.y)
                            path.addQuadCurve(to: pin.point, control: CGPoint(x: mid.x, y: mid.y - d * 0.28))
                            ctx.stroke(path, with: .color((lineColor ?? pin.color).opacity(0.9)), lineWidth: 1.6)
                        }
                    }
                    for pin in shot.pins {
                        let r = CGRect(x: pin.point.x - 3.5, y: pin.point.y - 3.5, width: 7, height: 7)
                        ctx.fill(Path(ellipseIn: r), with: .color(lineColor ?? pin.color))
                        ctx.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 1)
                    }
                    if let home = shot.home {
                        ctx.fill(Path(ellipseIn: CGRect(x: home.x - 22, y: home.y - 22, width: 44, height: 44)),
                                 with: .radialGradient(Gradient(colors: [Color.signal.opacity(0.7), .clear]),
                                                       center: home, startRadius: 1, endRadius: 22))
                        ctx.fill(Path(ellipseIn: CGRect(x: home.x - 5, y: home.y - 5, width: 10, height: 10)), with: .color(.white))
                    }
                }
            }
            .clipped()
    }
}

/// The map as a story to share. Laid out at phone size (390 points wide) and scaled up to the story's pixels.
struct MapStoryCard: View {
    enum Style: CaseIterable {
        case globe, miles, grounds, countries

        var name: String {
            switch self {
            case .globe: "Globe"
            case .miles: Fmt.metric ? "Kilometers" : "Miles"
            case .grounds: "Grounds"
            case .countries: "Countries"
            }
        }

        /// The map's size on the card, in points.
        var mapSize: CGSize {
            switch self {
            case .globe: CGSize(width: 390, height: 540)
            case .miles: CGSize(width: 354, height: 300)
            case .grounds, .countries: CGSize(width: 390, height: 360)
            }
        }
    }

    struct Numbers {
        let distance: Int?
        let venues: Int
        let countries: Int
        let games: Int
        let homeCity: String
        /// Countries by venues seen there, most first.
        let countryCounts: [(code: String, venues: Int)]
        /// The grounds to show as aerial icons, newest first.
        let grounds: [(venue: Venue, sport: Sport, aerial: UIImage?)]
    }

    let style: Style
    let shot: MapShot?
    let numbers: Numbers
    /// The same map in a light style, for the light look.
    var lightShot: MapShot? = nil
    @Environment(\.shareScheme) private var scheme
    private var mapIsLight: Bool { scheme == .light && lightShot != nil }
    /// Type that sits on the map itself (not on the card): white on the dark map, ink on the light one.
    private var mapInk: Color { mapIsLight ? Color.photoInk : .white }

    static let width: CGFloat = 390
    private var scale: CGFloat { ShareCardFormat.story.size.width / Self.width }
    private var height: CGFloat { ShareCardFormat.story.size.height / scale }

    var body: some View {
        content
            .frame(width: Self.width, height: height)
            .background(Color.ink)
            .clipped()
            .environment(\.dynamicTypeSize, .large)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: ShareCardFormat.story.size.width, height: ShareCardFormat.story.size.height, alignment: .topLeading)
            .shareSurface()
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .globe: globe
        case .miles: miles
        case .grounds: grounds
        case .countries: countries
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var map: some View {
        if let shot = mapIsLight ? lightShot : shot { MapShotView(shot: shot) }
        else { Color.panel }
    }

    private func wordmark(_ size: CGFloat = 26, ink: Color = Color.primaryText) -> some View {
        ZStack(alignment: .topLeading) {
            Text("SPORTS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(Color.signal)
                .offset(x: size, y: size * 0.75)
            Text("WITNESS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(ink)
        }
        .padding(.bottom, size * 0.75)
    }

    private var unit: String { Fmt.distanceUnit.uppercased() }

    private func distanceLine(_ size: CGFloat, ink: Color = Color.primaryText) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(Fmt.number(numbers.distance ?? 0)).font(.display(size)).lineLimit(1).minimumScaleFactor(0.5)
            Text(unit).font(.display(size * 0.3))
        }
        .foregroundStyle(ink)
    }

    private func stats(ink: Color = Color.primaryText) -> some View {
        HStack(spacing: 0) {
            stat(numbers.venues, numbers.venues == 1 ? "Venue" : "Venues", ink)
            stat(numbers.countries, numbers.countries == 1 ? "Country" : "Countries", ink)
            stat(numbers.games, numbers.games == 1 ? "Game" : "Games", ink)
        }
    }

    private func stat(_ value: Int, _ label: String, _ ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.display(40)).foregroundStyle(ink)
            Text(label.uppercased()).font(.system(size: 12, weight: .heavy).width(.condensed)).tracking(2)
                .foregroundStyle(ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fromHome: String {
        numbers.homeCity.isEmpty ? "TRAVELED FOR GAMES" : "FROM \(numbers.homeCity.uppercased()) TO THE GAMES"
    }

    private func caption(_ text: String, _ color: Color = Color.signal) -> some View {
        Text(text).font(.system(size: 13, weight: .heavy).width(.condensed)).tracking(3).foregroundStyle(color)
    }

    // MARK: Looks

    /// The map fills the story; the distance and the counts sit at the bottom.
    private var globe: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) { map; Spacer(minLength: 0) }
            LinearGradient(stops: [.init(color: .clear, location: 0.45), .init(color: Color.ink, location: 0.78)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                if numbers.distance != nil {
                    distanceLine(96)
                    caption(fromHome)
                }
                stats().padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) { wordmark(ink: mapInk).padding(.top, 50).padding(.leading, 18) }
    }

    /// The distance is the picture; the map is a card under it.
    private var miles: some View {
        VStack(alignment: .leading, spacing: 16) {
            wordmark()
            Spacer(minLength: 0)
            Text(Fmt.number(numbers.distance ?? 0)).font(.display(150)).foregroundStyle(Color.primaryText)
                .lineLimit(1).minimumScaleFactor(0.4)
            Text("\(unit) TO THE GAMES").font(.display(34)).foregroundStyle(Color.signal)
            map.clipShape(.rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.primaryText.opacity(0.12)))
            caption(numbers.homeCity.isEmpty ? "\(numbers.venues) VENUES" : "FROM \(numbers.homeCity.uppercased()) \u{00B7} \(numbers.venues) VENUES",
                    Color.primaryText.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.top, 50)
        .padding(.bottom, 40)
    }

    /// The map, then the grounds themselves from above, as in the venue list.
    private var grounds: some View {
        VStack(alignment: .leading, spacing: 18) {
            map.overlay(alignment: .topLeading) { wordmark(ink: mapInk).padding(.top, 50).padding(.leading, 18) }
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(numbers.venues)").font(.display(64))
                    Text(numbers.venues == 1 ? "VENUE" : "VENUES").font(.display(26))
                    Spacer()
                    if numbers.distance != nil {
                        Text("\(Fmt.number(numbers.distance ?? 0)) \(unit)").font(.display(26)).foregroundStyle(Color.signal)
                    }
                }
                .foregroundStyle(Color.primaryText)
                let shown = Array(numbers.grounds.prefix(10))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, g in
                        VStack(spacing: 4) {
                            AerialVenueIcon(venue: g.venue, sport: g.sport, size: 52, given: g.aerial)
                            Text(g.venue.city.uppercased()).font(.system(size: 9, weight: .heavy).width(.condensed))
                                .tracking(1).foregroundStyle(Color.primaryText.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 40)
    }

    /// The map, then the countries in order of venues seen.
    private var countries: some View {
        VStack(alignment: .leading, spacing: 18) {
            map.overlay(alignment: .topLeading) { wordmark(ink: mapInk).padding(.top, 50).padding(.leading, 18) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(numbers.countries)").font(.display(64))
                    Text(numbers.countries == 1 ? "COUNTRY" : "COUNTRIES").font(.display(26))
                }
                .foregroundStyle(Color.primaryText)
                ForEach(Array(numbers.countryCounts.prefix(5).enumerated()), id: \.offset) { _, c in
                    HStack(spacing: 12) {
                        CountryGlobe(code: c.code, size: 36)
                        Text((Locale.current.localizedString(forRegionCode: c.code) ?? c.code).uppercased())
                            .font(.display(26)).foregroundStyle(Color.primaryText).lineLimit(1)
                        Spacer()
                        Text("\(c.venues)").font(.display(26)).foregroundStyle(Color.signal)
                    }
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }
            .padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 40)
    }
}
