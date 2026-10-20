import SwiftUI
import MapKit

/// Pick a venue from the built-in catalog, from Apple Maps, or make a new one.
struct VenuePickerView: View {
    @Binding var venueId: String?
    var sport: Sport?

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showNew = false
    @State private var mapResults: [MKMapItem] = []

    var body: some View {
        List {
            Section {
                Button {
                    showNew = true
                } label: {
                    Label("New venue", systemImage: "plus")
                }
                .accessibilityIdentifier("venue-new")
            }
            .listRowBackground(Color.panel)

            Section {
                ForEach(filtered) { v in
                    Button {
                        venueId = v.id
                        dismiss()
                    } label: {
                        row(name: v.name, detail: v.cityLine, selected: v.id == venueId)
                    }
                    .accessibilityIdentifier("venue-row-\(v.id)")
                    .accessibilityAddTraits(v.id == venueId ? .isSelected : [])
                }
            }
            .listRowBackground(Color.panel)

            if !mapResults.isEmpty {
                Section("Apple Maps") {
                    ForEach(mapResults, id: \.self) { item in
                        Button {
                            choose(item)
                        } label: {
                            row(name: item.name ?? "Venue",
                                detail: [item.placemark.locality, item.placemark.country].compactMap { $0 }.joined(separator: ", "),
                                selected: false)
                        }
                    }
                }
                .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationDestination(isPresented: $showNew) {
            // Pop the new-venue form first, then this picker, so Add Game is shown with the venue set.
            AddVenueView(venueId: $venueId, sport: sport, initialName: query, onSaved: {
                showNew = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
            })
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search venues")
        .navigationTitle("Venue")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) { await searchMaps() }
    }

    private func row(name: String, detail: String, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.condensed(.headline))
                    .foregroundStyle(Color.primaryText)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark").foregroundStyle(Color.primaryText).accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }

    /// Venues for this sport first; a search looks across every venue.
    private var filtered: [Venue] {
        let q = TicketParser.normalize(query.trimmingCharacters(in: .whitespaces))
        if q.isEmpty {
            let forSport = library.venues(for: sport)
            return forSport.isEmpty ? library.venues(for: nil) : forSport
        }
        return Array(library.searchVenues(query, sport: sport).prefix(200))
    }

    private func searchMaps() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else {
            mapResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.stadium])
        let response = try? await MKLocalSearch(request: request).start()
        guard !Task.isCancelled else { return }
        let known = Set(library.venues.map { TicketParser.normalize($0.name) })
        mapResults = Array((response?.mapItems ?? [])
            .filter { !known.contains(TicketParser.normalize($0.name ?? "")) }
            .prefix(8))
    }

    private func choose(_ item: MKMapItem) {
        let pm = item.placemark
        let venue = Venue(
            id: "custom-\(UUID().uuidString)",
            name: item.name ?? "Venue",
            city: pm.locality ?? "",
            region: pm.administrativeArea,
            country: pm.country ?? "",
            countryCode: pm.isoCountryCode ?? "",
            latitude: pm.coordinate.latitude,
            longitude: pm.coordinate.longitude,
            sports: sport.map { [$0] } ?? [],
            timeZone: (item.timeZone ?? .current).identifier,
            capacity: nil,
            opened: nil,
            isCustom: true)
        venueId = library.addVenue(venue).id
        dismiss()
    }
}
