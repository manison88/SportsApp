import SwiftUI
import MapKit

/// 02 · Map. Every venue on a globe, arcs from home, and the miles it took.
struct LifeMapView: View {
    @Environment(Library.self) private var library
    @State private var sport: Sport?
    @State private var expanded = false

    private var games: [GameEntry] {
        guard let sport else { return library.games }
        return library.games.filter { $0.sport == sport }
    }

    var body: some View {
        let stats = Stats(library: library, games: games)
        let home = library.profile.homeLocation.coordinate
        let venues = Set(games.map(\.venueId)).compactMap { library.venue($0) }
        let labeled = Set(farthest(venues, from: library.profile.homeLocation).map(\.id))
        let legs = Self.legs(games)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                WorldMapCanvas(legs: legs, venues: venues, home: home, homeCity: library.profile.homeCity, labeled: labeled,
                               initialCamera: Self.camera(home: home, venues: venues), resetToken: sport?.rawValue ?? "all",
                               linksToVenues: true, onExpand: { expanded = true })
                    .frame(height: 400)
                    .containerRelativeFrame(.horizontal) { width, _ in width - 2 * Spacing.gutter }
                    .clipShape(.rect(cornerRadius: 22))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("life-map")

                legend

                VStack(alignment: .leading, spacing: Spacing.block) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(Fmt.number(stats.miles))
                            .displayFont(96)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("Miles")
                            .font(.condensed(.title2, weight: .heavy))
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("map-miles")

                    StatRow(items: [
                        .init(value: "\(stats.venues)", label: "Venues"),
                        .init(value: "\(stats.countries)", label: stats.countries == 1 ? "Country" : "Countries"),
                        .init(value: "\(stats.games)", label: "Games"),
                    ])
                }
                .gutter()
            }
            .padding(.bottom, Spacing.block)
        }
        .scrollBounceBehavior(.basedOnSize)
        .inkBackground()
        .tabTitle("Map")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sport", selection: $sport) {
                        Text("All sports").tag(Sport?.none)
                        ForEach(Sport.allCases) { s in
                            Label(s.name, systemImage: s.symbol).tag(Sport?.some(s))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .fontWeight(.bold)
                }
                .accessibilityLabel("Filter by sport")
            }
        }
        .fullScreenCover(isPresented: $expanded) {
            ExpandedMap(legs: legs, venues: venues, home: home, homeCity: library.profile.homeCity, labeled: labeled,
                        initialCamera: Self.camera(home: home, venues: venues))
        }
    }

    // MARK: Legend

    /// Sports on the map, each in its line color. Tap one to show only that sport; tap again for all.
    private var legend: some View {
        let counts = Dictionary(grouping: library.games, by: \.sport).mapValues(\.count)
        let present = Sport.allCases.filter { counts[$0, default: 0] > 0 }
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(present) { s in
                    Button { sport = sport == s ? nil : s } label: {
                        HStack(spacing: 6) {
                            Capsule().fill(s.lineColor).frame(width: 18, height: 4)
                            Text(s.name).font(.condensed(.subheadline, weight: .bold)).textCase(.uppercase)
                            Text("\(counts[s, default: 0])").font(.condensed(.subheadline)).foregroundStyle(Color.textSecondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(sport == s ? Color.panelRaised : Color.panel, in: .capsule)
                        .overlay(Capsule().strokeBorder(sport == s ? s.lineColor : Color.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(s.name), \(counts[s, default: 0]) games")
                    .accessibilityAddTraits(sport == s ? .isSelected : [])
                    .accessibilityIdentifier("map-legend-\(s.rawValue)")
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("map-legend")
    }

    /// One line per venue and sport played there, so a venue that hosted two sports gets two colors.
    static func legs(_ games: [GameEntry]) -> [MapLeg] {
        var seen = Set<String>()
        var out: [MapLeg] = []
        for g in games {
            let key = "\(g.venueId)|\(g.sport.rawValue)"
            if seen.insert(key).inserted { out.append(MapLeg(venueId: g.venueId, sport: g.sport)) }
        }
        return out
    }

    /// The two venues farthest from home get their city printed on the globe.
    private func farthest(_ venues: [Venue], from home: CLLocation) -> [Venue] {
        Array(venues.sorted { $0.location.distance(from: home) > $1.location.distance(from: home) }
            .filter { $0.location.distance(from: home) > 300_000 }
            .prefix(2))
    }

    /// Frames home and the farthest venue, pulled back far enough to read as a globe.
    static func camera(home: CLLocationCoordinate2D, venues: [Venue]) -> MapCamera {
        let homeLoc = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let far = venues.map { $0.location.distance(from: homeLoc) }.max() ?? 0
        let center = venues.isEmpty ? home : CLLocationCoordinate2D(
            latitude: (venues.map(\.latitude).reduce(home.latitude, +)) / Double(venues.count + 1) + 8,
            longitude: (venues.map(\.longitude).max()! + venues.map(\.longitude).min()!) / 2 * 0.5 + home.longitude * 0.5)
        let distance = min(max(far * 4, 2_500_000), 30_000_000)
        return MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 0)
    }
}


// MARK: - Map pieces

struct MapLeg: Identifiable, Hashable {
    let venueId: String
    let sport: Sport
    var id: String { "\(venueId)|\(sport.rawValue)" }
}

/// The globe: a line from home to each venue in its sport's color, zoom buttons, and an expand button.
/// Pinch and double-tap work as on any map; the buttons are there for one-handed use.
struct WorldMapCanvas: View {
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let legs: [MapLeg]
    let venues: [Venue]
    let home: CLLocationCoordinate2D
    let homeCity: String
    let labeled: Set<String>
    let initialCamera: MapCamera
    let resetToken: String
    var linksToVenues = false
    var onExpand: (() -> Void)?

    @State private var position: MapCameraPosition
    @State private var current: MapCamera?

    init(legs: [MapLeg], venues: [Venue], home: CLLocationCoordinate2D, homeCity: String, labeled: Set<String>,
         initialCamera: MapCamera, resetToken: String, linksToVenues: Bool = false, onExpand: (() -> Void)? = nil) {
        self.legs = legs; self.venues = venues; self.home = home; self.homeCity = homeCity; self.labeled = labeled
        self.initialCamera = initialCamera; self.resetToken = resetToken
        self.linksToVenues = linksToVenues; self.onExpand = onExpand
        _position = State(initialValue: .camera(initialCamera))
    }

    var body: some View {
        Map(position: $position) {
            ForEach(legs) { leg in
                if let v = library.venue(leg.venueId) {
                    MapPolyline(coordinates: [home, v.coordinate], contourStyle: .geodesic)
                        .stroke(leg.sport.lineColor.opacity(0.9), lineWidth: 1.8)
                }
            }
            ForEach(venues) { v in
                Annotation(labeled.contains(v.id) ? v.city.uppercased() : "", coordinate: v.coordinate, anchor: .center) {
                    let dot = Circle()
                        .fill(dotColor(v))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                        .frame(width: 9, height: 9)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                    if linksToVenues {
                        NavigationLink(value: Route.venue(v.id)) { dot }.accessibilityLabel(v.name)
                    } else {
                        dot.accessibilityLabel(v.name)
                    }
                }
                .annotationTitles(labeled.contains(v.id) ? .visible : .hidden)
            }
            Annotation(homeCity.uppercased(), coordinate: home, anchor: .center) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color.signal.opacity(0.7), .clear], center: .center, startRadius: 2, endRadius: 46))
                        .frame(width: 92, height: 92)
                    Circle().fill(.white).frame(width: 12, height: 12)
                }
                .allowsHitTesting(false)
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControlVisibility(.hidden)
        .onMapCameraChange(frequency: .onEnd) { current = $0.camera }
        .onChange(of: resetToken) {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.8)) { position = .camera(initialCamera) }
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                if let onExpand {
                    mapButton("arrow.up.left.and.arrow.down.right", "Expand map", action: onExpand)
                        .accessibilityIdentifier("map-expand")
                }
                mapButton("plus", "Zoom in") { zoom(by: 0.5) }.accessibilityIdentifier("map-zoom-in")
                mapButton("minus", "Zoom out") { zoom(by: 2) }.accessibilityIdentifier("map-zoom-out")
            }
            .padding(10)
        }
    }

    /// A venue's dot wears the color of the sport played there most.
    private func dotColor(_ v: Venue) -> Color {
        let here = legs.filter { $0.venueId == v.id }.map(\.sport)
        let top = Dictionary(grouping: library.games.filter { $0.venueId == v.id && here.contains($0.sport) }, by: \.sport)
            .max { $0.value.count < $1.value.count }?.key
        return (top ?? here.first)?.lineColor ?? .white
    }

    private func zoom(by factor: Double) {
        let cam = current ?? initialCamera
        let next = MapCamera(centerCoordinate: cam.centerCoordinate, distance: min(max(cam.distance * factor, 400), 40_000_000),
                             heading: cam.heading, pitch: cam.pitch)
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { position = .camera(next) }
    }

    private func mapButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: .circle)
        }
        .accessibilityLabel(label)
    }
}

/// The map on its own full screen, where pinch and double-tap have the whole screen to themselves.
struct ExpandedMap: View {
    @Environment(\.dismiss) private var dismiss
    let legs: [MapLeg]
    let venues: [Venue]
    let home: CLLocationCoordinate2D
    let homeCity: String
    let labeled: Set<String>
    let initialCamera: MapCamera

    var body: some View {
        ZStack(alignment: .topLeading) {
            WorldMapCanvas(legs: legs, venues: venues, home: home, homeCity: homeCity, labeled: labeled,
                           initialCamera: initialCamera, resetToken: "expanded")
                .ignoresSafeArea()
            CircleButton(systemName: "xmark", label: "Close map") { dismiss() }
                .padding(.leading, 12)
                .padding(.top, 4)
                .accessibilityIdentifier("map-close")
        }
        .background(Color.ink)
        .accessibilityIdentifier("life-map-expanded")
    }
}
