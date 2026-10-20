import SwiftUI
import MapKit
import CoreLocation

/// Where you live: search a city, or use where you are now. Miles traveled and the map's arcs start there.
struct HomePickerView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var location = LocationService()
    @State private var locating = false

    var body: some View {
        List {
            Section {
                Button {
                    locating = true
                    location.start()
                } label: {
                    HStack {
                        Label("Use my current location", systemImage: "location")
                        Spacer()
                        if locating { ProgressView() }
                    }
                }
                .accessibilityIdentifier("home-use-location")
                if location.denied {
                    Text("Location is off for Witness. Search for your city instead.")
                        .font(.footnote).foregroundStyle(Color.textSecondary)
                }
            }
            .listRowBackground(Color.panel)

            if !results.isEmpty {
                Section("Cities") {
                    ForEach(results, id: \.self) { item in
                        Button { choose(item) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Self.city(item)).foregroundStyle(Color.primaryText)
                                Text([item.placemark.administrativeArea, item.placemark.country].compactMap { $0 }.joined(separator: ", "))
                                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Set home")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Your city")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
            }
        }
        .task(id: query) { await search() }
        .onChange(of: location.location) { _, newValue in
            guard locating, let loc = newValue else { return }
            locating = false
            location.stop()
            Task { await useCurrent(loc) }
        }
        .onDisappear { location.stop() }
    }

    private static func city(_ item: MKMapItem) -> String { item.placemark.locality ?? item.name ?? "Home" }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { results = []; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        results = (try? await MKLocalSearch(request: request).start())?.mapItems.prefix(8).map { $0 } ?? []
    }

    private func choose(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        library.setHome(city: Self.city(item), latitude: c.latitude, longitude: c.longitude)
        dismiss()
    }

    private func useCurrent(_ loc: CLLocation) async {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(loc)
        let name = marks?.first?.locality ?? marks?.first?.name ?? "Home"
        library.setHome(city: name, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        dismiss()
    }
}
