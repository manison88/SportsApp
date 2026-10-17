import SwiftUI
import MapKit

/// Screen 3 — Home: Life Globe.
/// Signature moment: a satellite globe settling into place, with glowing arcs
/// from home to every venue. Arcs burn brighter the more often you've returned.
struct LifeGlobeScreen: View {
    private let store = MockStore.shared
    @State private var camera: MapCameraPosition = .camera(LifeGlobeScreen.approach)
    @State private var tab: WitnessTab = .globe
    @State private var revealed = false

    /// Starts far out in space and settles over the North Atlantic, so Chicago,
    /// the road-trip venues, and Europe are all on the visible hemisphere.
    static let approach = MapCamera(centerCoordinate: .init(latitude: 30, longitude: -62),
                                    distance: 46_000_000, heading: 0, pitch: 0)
    static let rest = MapCamera(centerCoordinate: .init(latitude: 37, longitude: -50),
                                distance: 19_800_000, heading: 0, pitch: 0)

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()

            GlobeMap(camera: $camera, store: store)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopScrim().frame(height: 330)
                Spacer()
                BottomScrim().frame(height: 420)
            }
            .ignoresSafeArea()

            GrainOverlay(intensity: 0.06).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.xs)
                Spacer()
                legend
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.s)
                statsPanel
                    .padding(.horizontal, Space.gutter - 6)
                FloatingTabBar(selection: $tab)
                    .padding(.top, Space.s)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(Motion.globeSettle) { camera = .camera(Self.rest) }
            withAnimation(Motion.reveal.delay(0.5)) { revealed = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(store.profile.displayName)'s life in the stands").eyebrow(Palette.signal)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Self.spelled(store.games.count)) games.")
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(Self.spelled(store.venues.count)) places.")
                        .foregroundStyle(Palette.textSecondary)
                    Text("\(Self.spelled(store.countries.count)) countries.")
                        .foregroundStyle(Palette.textTertiary)
                }
                .font(WType.display(40))
                .tracking(Tracking.display)
                .lineSpacing(-2)
            }
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 12)
            Spacer()
            ChromeButton(symbol: "magnifyingglass")
        }
    }

    private var legend: some View {
        HStack(spacing: Space.xs) {
            Capsule()
                .fill(LinearGradient(colors: [Palette.arc.opacity(0.15), Palette.arc, Palette.arcHot],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 34, height: 3)
                .shadow(color: Palette.arc, radius: 4)
            Text("Arcs brighten with every return")
                .font(WType.caption)
                .foregroundStyle(Palette.textTertiary)
            Spacer()
            Text("Drag to spin")
                .font(WType.caption)
                .foregroundStyle(Palette.textQuaternary)
        }
    }

    // MARK: Stats

    private var statsPanel: some View {
        let top = store.venueVisits.first!
        let last = store.games.last!
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                stat(value: "\(store.seasons)", label: "Seasons")
                divider
                stat(value: Fmt.number(store.milesTraveled), label: "Miles traveled")
                divider
                stat(value: "\(top.count)×", label: top.venue.name)
            }
            .padding(.vertical, Space.m)

            Rectangle().fill(Palette.hairline).frame(height: Size.hairline)

            LastGameRow(game: last, store: store)
                .padding(.vertical, Space.s)
                .padding(.horizontal, Space.m)
        }
        .glass(radius: Radius.card)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(WType.score(34, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .eyebrow(small: true)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Space.m)
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(width: Size.hairline, height: 44)
    }

    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "en_US")
        let s = f.string(from: NSNumber(value: n)) ?? "\(n)"
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - Globe

private struct GlobeMap: View {
    @Binding var camera: MapCameraPosition
    let store: MockStore

    private var visits: [MockStore.VenueVisits] { store.venueVisits }
    private var maxVisits: Int { visits.map(\.count).max() ?? 1 }
    private var home: CLLocationCoordinate2D { store.profile.homeCoordinate }

    var body: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            // Arcs: three stacked strokes (halo, body, core) so each reads as light.
            ForEach(visits) { v in
                let t = heat(v.count)
                let path = [home, v.venue.coordinate]
                MapPolyline(coordinates: path, contourStyle: .geodesic)
                    .stroke(Palette.arc.opacity(0.08 + 0.22 * t), lineWidth: 10 + 6 * t)
                MapPolyline(coordinates: path, contourStyle: .geodesic)
                    .stroke(Palette.arc.opacity(0.35 + 0.4 * t), lineWidth: 2.6 + 1.6 * t)
                MapPolyline(coordinates: path, contourStyle: .geodesic)
                    .stroke(Palette.arcHot.opacity(0.55 + 0.45 * t), lineWidth: 0.9 + 0.6 * t)
            }

            ForEach(visits) { v in
                Annotation(v.venue.name, coordinate: v.venue.coordinate, anchor: .center) {
                    VenueGlow(heat: heat(v.count),
                              label: showsLabel(v) ? v.venue.city : nil,
                              labelLeading: labelOnLeft(v))
                }
            }
            .annotationTitles(.hidden)

            Annotation("Home", coordinate: home, anchor: .center) {
                HomeBeacon(localGames: store.games.filter { store.milesFromHome(store.venue(for: $0)) < 40 }.count)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.imagery(elevation: .realistic))
    }

    /// 0...1, logarithmic so one-off trips still glow.
    private func heat(_ count: Int) -> Double {
        guard maxVisits > 1 else { return 1 }
        return log(Double(count)) / log(Double(maxVisits))
    }

    private func showsLabel(_ v: MockStore.VenueVisits) -> Bool {
        store.milesFromHome(v.venue) > 600
    }

    /// Put the label on the left when another labeled venue sits just east,
    /// so pairs like Madrid / Barcelona don't collide.
    private func labelOnLeft(_ v: MockStore.VenueVisits) -> Bool {
        visits.contains { other in
            other.id != v.id && showsLabel(other)
                && other.venue.longitude > v.venue.longitude
                && other.venue.location.distance(from: v.venue.location) < 800_000
        }
    }
}

private struct VenueGlow: View {
    let heat: Double
    let label: String?
    let labelLeading: Bool

    var body: some View {
        let d = 5 + 7 * heat
        ZStack {
            Circle()
                .fill(Palette.arc.opacity(0.35 + 0.35 * heat))
                .frame(width: d * 3.2, height: d * 3.2)
                .blur(radius: d)
            Circle()
                .fill(Palette.arcHot)
                .frame(width: d, height: d)
                .shadow(color: Palette.arc, radius: 4)
        }
        .overlay {
            if let label {
                Text(label)
                    .font(WType.eyebrowSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .shadow(color: .black, radius: 3)
                    .fixedSize()
                    // pin the label's near edge just beside the dot
                    .alignmentGuide(HorizontalAlignment.center) { dim in
                        labelLeading ? dim[.trailing] + d / 2 + 6 : dim[.leading] - d / 2 - 6
                    }
            }
        }
    }
}

/// Pulsing amber beacon for home, with the count of games played locally.
private struct HomeBeacon: View {
    let localGames: Int
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.signal.opacity(pulse ? 0 : 0.8), lineWidth: 1.5)
                .frame(width: pulse ? 64 : 14, height: pulse ? 64 : 14)
            Circle()
                .fill(Palette.signal.opacity(0.45))
                .frame(width: 40, height: 40)
                .blur(radius: 12)
            Circle()
                .fill(Palette.signalSoft)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
        }
        .frame(width: 64, height: 64)
        .overlay(alignment: .bottom) {
            VStack(spacing: 1) {
                Text("Chicago").font(WType.eyebrowSmall).tracking(1.4).textCase(.uppercase)
                    .foregroundStyle(Palette.signal)
                Text("\(localGames) games at home")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .fixedSize()
            .shadow(color: .black, radius: 3)
            .offset(y: 26)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - Last game row

private struct LastGameRow: View {
    let game: Game
    let store: MockStore

    var body: some View {
        let venue = store.venue(for: game)
        let photo = store.photos(for: game).first { $0.isFavorite } ?? store.photos(for: game).first
        HStack(spacing: Space.s) {
            Group {
                if let photo {
                    StadiumPhoto(photo: photo, game: game, grain: 0.05)
                } else {
                    Palette.surfaceRaised
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Most recent · \(Fmt.eyebrowDate(game.startTime, tz: venue.tz))")
                    .eyebrow(small: true)
                Text(game.headline)
                    .font(WType.subhead)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}

#Preview {
    LifeGlobeScreen()
}
