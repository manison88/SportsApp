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

        let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
        let recordText: String = theirs.record.decided > 0 ? theirs.record.text : ""
        let sortedGames = together.sorted { $0.date > $1.date }
        let photoRefs: [PhotoRef] = Array(sortedGames.compactMap { $0.photos.first }.prefix(3))
        let recentLine: String = {
            guard let latest = sortedGames.first else { return "" }
            let venueName = library.venue(latest.venueId)?.name ?? ""
            let when = latest.date.formatted(.dateTime.month(.abbreviated).year())
            return venueName.isEmpty ? when : "\(venueName) · \(when)"
        }()

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
                ShareCardSheetLink(
                    title: "\(together.count) games with \(person.name)",
                    format: .story,
                    key: "\(person.id)-\(together.count)-\(theirs.record.text)-\(recentLine)-\(photoRefs.count)"
                ) {
                    var photos: [UIImage] = []
                    for ref in photoRefs {
                        if let image = await PhotoLoader.load(ref) { photos.append(image) }
                    }
                    let styles: [PassportShareCard.Style] = [.photo, .number, .field, .paper, .stub]
                    return styles.map { style in
                        ShareCardVariant(style.title) {
                            PassportShareCard(style: style, count: together.count, name: firstName,
                                              record: recordText, recent: recentLine,
                                              color: person.color, photos: photos)
                        }
                    }
                } label: {
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

/// 1080x1920 story cards: five looks for the games you have seen with one friend.
private struct PassportShareCard: View {
    enum Style {
        case photo, number, field, paper, stub
        var title: String {
            switch self {
            case .photo: "Photo"
            case .number: "Number"
            case .field: "Color"
            case .paper: "Paper"
            case .stub: "Stub"
            }
        }
    }

    let style: Style
    let count: Int
    let name: String
    let record: String
    let recent: String
    let color: Color
    let photos: [UIImage]

    var body: some View {
        switch style {
        case .photo: photoCard
        case .number: numberCard
        case .field: fieldCard
        case .paper: paperCard
        case .stub: stubCard
        }
    }

    private func label(_ text: String, _ tint: Color, size: CGFloat = 40) -> some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold).width(.condensed))
            .tracking(6)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var withName: String { "With \(name)" }

    // 1. Full-bleed photo, big type at the bottom.
    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [color.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
            if let first = photos.first {
                Image(uiImage: first)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            }
            LinearGradient(stops: [
                .init(color: .black.opacity(0.45), location: 0),
                .init(color: .black.opacity(0), location: 0.25),
                .init(color: .black.opacity(0.9), location: 0.7),
                .init(color: .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(count)")
                    .font(.display(520))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("GAMES WITH \(name.uppercased())")
                    .font(.display(120))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                if !record.isEmpty {
                    label("Record \(record)", .white.opacity(0.75), size: 48).padding(.top, 20)
                }
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(.white)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 84)
            .padding(.bottom, 200)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // 2. Pure typographic number on ink.
    private var numberCard: some View {
        ShareCardFrame(format: .story, accent: color) {
            VStack(alignment: .leading, spacing: 0) {
                label("Games together", .white.opacity(0.6))
                Text("\(count)")
                    .font(.display(720))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.top, 20)
                Text("WITH \(name.uppercased())")
                    .font(.display(170))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                if !record.isEmpty {
                    label("Record \(record)", .white.opacity(0.6), size: 48).padding(.top, 48)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // 3. Solid field of the friend's color, black type.
    private var fieldCard: some View {
        ZStack(alignment: .topLeading) {
            color
            VStack(alignment: .leading, spacing: 0) {
                label("Games together", .black.opacity(0.7))
                Spacer(minLength: 20)
                Text("\(count)")
                    .font(.display(680))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("\(name.uppercased())")
                    .font(.display(220))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                if !record.isEmpty {
                    label("Record \(record)", .black.opacity(0.7), size: 48).padding(.top, 36)
                }
                Spacer(minLength: 40)
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // 4. Light paper, black type, photo strip.
    private var paperCard: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.96, green: 0.95, blue: 0.92)
            VStack(alignment: .leading, spacing: 0) {
                label(withName, .black.opacity(0.55))
                Text("\(count)")
                    .font(.display(560))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.top, 16)
                Text("GAMES TOGETHER")
                    .font(.display(120))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Rectangle().fill(Color.black).frame(height: 4).padding(.vertical, 48)
                if !record.isEmpty {
                    label("Record together", .black.opacity(0.55))
                    Text(record)
                        .font(.display(200))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                Spacer(minLength: 30)
                if !photos.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(photos.indices, id: \.self) { i in
                            Image(uiImage: photos[i])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: (912 - 16 * CGFloat(photos.count - 1)) / CGFloat(photos.count), height: 260)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                    .frame(height: 260)
                    .padding(.bottom, 32)
                }
                Text("WITNESS")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .tracking(10)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 84)
            .padding(.top, 230)
            .padding(.bottom, 250)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .light)
    }

    // 5. Data-forward stub: ruled rows of figures.
    private var stubCard: some View {
        ShareCardFrame(format: .story, accent: color) {
            VStack(alignment: .leading, spacing: 0) {
                label("Shared passport", .white.opacity(0.6))
                Text(name.uppercased())
                    .font(.display(260))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                stubRow("Games together", "\(count)")
                if !record.isEmpty { stubRow("Record", record) }
                if !recent.isEmpty { stubRow("Latest", recent, small: true) }
                if let first = photos.first {
                    Image(uiImage: first)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 912, height: 300)
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.top, 40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stubRow(_ title: String, _ value: String, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Color.white.opacity(0.25)).frame(height: 2)
            label(title, .white.opacity(0.6), size: 34).padding(.top, 20)
            Text(small ? value.uppercased() : value)
                .font(small ? .system(size: 64, weight: .bold).width(.condensed) : .display(190))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(.bottom, 24)
        }
    }
}
