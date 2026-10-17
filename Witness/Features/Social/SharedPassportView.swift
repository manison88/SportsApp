import SwiftUI
import MapKit

/// 13 · Your games with one person, inside all of yours.
struct SharedPassportView: View {
    @Environment(Library.self) private var library
    let personId: String

    var body: some View {
        if let person = library.person(personId) {
            content(person)
        } else {
            ContentUnavailableView("Not found", systemImage: "person.crop.circle.badge.questionmark")
                .inkBackground()
        }
    }

    private func content(_ person: Person) -> some View {
        let together = library.games(with: person.id)
        let theirs = Stats(library: library, games: together)
        let mine = Stats(library: library)
        let me = Person(id: "me", name: library.profile.displayName, relation: "You",
                        initials: String(library.profile.displayName.prefix(1)), colorHex: "FFFFFF")

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                Rings(total: mine.games, shared: together.count, person: person)
                    .frame(height: 310)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    HStack {
                        Avatar(person: person, size: 26)
                        Text(person.name).font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                        Spacer()
                        Text(me.name).font(.condensed(.subheadline, weight: .heavy)).textCase(.uppercase)
                        Avatar(person: me, size: 26)
                    }
                    .frame(minHeight: 44)
                    row("Win rate", theirs.record.rate?.percentText ?? "–", mine.record.rate?.percentText ?? "–", person.color)
                    row("Venues", "\(theirs.venues)", "\(mine.venues)", person.color)
                    row("Countries", "\(theirs.countries)", "\(mine.countries)", person.color, last: true)
                }

                if let route = farthestPair(together) {
                    RouteStrip(a: route.0, b: route.1, color: person.color)
                        .frame(height: 120)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline))
                        .allowsHitTesting(false)
                        .accessibilityElement()
                        .accessibilityLabel("Map from \(route.0.name) to \(route.1.name)")
                }
            }
            .gutter()
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .inkBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(together.count) games with \(person.name), \(theirs.record.text). Witness.") {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }

    private func row(_ label: String, _ theirs: String, _ mine: String, _ color: Color, last: Bool = false) -> some View {
        HStack {
            Text(theirs)
                .displayFont(30, relativeTo: .title2)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label).unitLabel()
            Text(mine)
                .displayFont(30, relativeTo: .title2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(theirs) together, \(mine) for you")
    }

    private func farthestPair(_ games: [GameEntry]) -> (Venue, Venue)? {
        let venues = Array(Set(games.map(\.venueId))).compactMap { library.venue($0) }
        guard venues.count >= 2 else { return nil }
        var best: (Venue, Venue)?
        var bestDistance = -1.0
        for i in venues.indices {
            for j in venues.indices where j > i {
                let d = venues[i].location.distance(from: venues[j].location)
                if d > bestDistance {
                    bestDistance = d
                    best = (venues[i], venues[j])
                }
            }
        }
        return best
    }
}

private struct Rings: View {
    let total: Int
    let shared: Int
    let person: Person

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height)
            let ratio = total > 0 ? Double(shared) / Double(total) : 0
            let inner = max(outer * 0.42, outer * 0.88 * CGFloat(sqrt(ratio)))
            ZStack {
                Circle()
                    .strokeBorder(Color.hairline, lineWidth: 1.5)
                    .frame(width: outer, height: outer)
                VStack(spacing: 2) {
                    Text("\(total)").displayFont(30, relativeTo: .title2)
                    Text("Your games").unitLabel()
                }
                .offset(y: -outer / 2 + 40)
                ZStack {
                    Circle().fill(person.color)
                    VStack(spacing: 0) {
                        Text("\(shared)")
                            .displayFont(96)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.black)
                        Text("With \(person.name)")
                            .font(.condensed(.caption, weight: .heavy))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.black.opacity(0.75))
                    }
                    .padding(.bottom, 10)
                }
                .frame(width: inner, height: inner)
                .offset(y: outer * 0.06)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shared) of your \(total) games with \(person.name)")
        .accessibilityIdentifier("shared-count")
    }
}

private struct RouteStrip: View {
    let a: Venue
    let b: Venue
    let color: Color

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            MapPolyline(coordinates: [a.coordinate, b.coordinate], contourStyle: .geodesic)
                .stroke(color, lineWidth: 3)
            Annotation(a.name, coordinate: a.coordinate) {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Annotation(b.name, coordinate: b.coordinate) {
                Circle().fill(color).frame(width: 10, height: 10)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
    }
}
