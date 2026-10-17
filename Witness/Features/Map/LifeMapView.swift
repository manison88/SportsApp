import SwiftUI
import MapKit

/// 02 · Map. Every venue on a globe, arcs from home, and the miles it took.
struct LifeMapView: View {
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sport: Sport?
    @State private var position: MapCameraPosition = .automatic

    private var games: [GameEntry] {
        guard let sport else { return library.games }
        return library.games.filter { $0.sport == sport }
    }

    var body: some View {
        let stats = Stats(library: library, games: games)
        let home = library.profile.homeLocation.coordinate
        let venues = Set(games.map(\.venueId)).compactMap { library.venue($0) }
        let labeled = Set(farthest(venues, from: library.profile.homeLocation).map(\.id))

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                Map(position: $position) {
                    ForEach(venues) { v in
                        MapPolyline(coordinates: [home, v.coordinate], contourStyle: .geodesic)
                            .stroke(.white.opacity(0.55), lineWidth: 1.2)
                    }
                    ForEach(venues) { v in
                        Annotation(labeled.contains(v.id) ? v.city.uppercased() : "", coordinate: v.coordinate, anchor: .center) {
                            NavigationLink(value: Route.venue(v.id)) {
                                Circle().fill(.white).frame(width: 7, height: 7)
                                    .frame(width: 44, height: 44)
                                    .contentShape(.circle)
                            }
                            .accessibilityLabel(v.name)
                        }
                        .annotationTitles(labeled.contains(v.id) ? .visible : .hidden)
                    }
                    Annotation(library.profile.homeCity.uppercased(), coordinate: home, anchor: .center) {
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
                .frame(height: 400)
                .containerRelativeFrame(.horizontal) { width, _ in width - 2 * Spacing.gutter }
                .clipShape(.rect(cornerRadius: 22))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("life-map")

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
        .navigationTitle("MAP")
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
        .onAppear { position = .camera(camera(home: home, venues: venues)) }
        .onChange(of: sport) {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.8)) {
                position = .camera(camera(home: home, venues: venues))
            }
        }
    }

    /// The two venues farthest from home get their city printed on the globe.
    private func farthest(_ venues: [Venue], from home: CLLocation) -> [Venue] {
        Array(venues.sorted { $0.location.distance(from: home) > $1.location.distance(from: home) }
            .filter { $0.location.distance(from: home) > 300_000 }
            .prefix(2))
    }

    /// Frames home and the farthest venue, pulled back far enough to read as a globe.
    private func camera(home: CLLocationCoordinate2D, venues: [Venue]) -> MapCamera {
        let homeLoc = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let far = venues.map { $0.location.distance(from: homeLoc) }.max() ?? 0
        let center = venues.isEmpty ? home : CLLocationCoordinate2D(
            latitude: (venues.map(\.latitude).reduce(home.latitude, +)) / Double(venues.count + 1) + 8,
            longitude: (venues.map(\.longitude).max()! + venues.map(\.longitude).min()!) / 2 * 0.5 + home.longitude * 0.5)
        let distance = min(max(far * 4, 2_500_000), 30_000_000)
        return MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 0)
    }
}
