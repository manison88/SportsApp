import SwiftUI
import MapKit
import CoreLocation

/// Create a venue that isn't in the catalog: a name, a city and a pin.
struct AddVenueView: View {
    @Binding var venueId: String?
    var sport: Sport?
    var initialName: String = ""
    var onSaved: (() -> Void)?

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var country = ""
    @State private var pin: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .automatic
    @State private var locator = LocationService()
    @State private var saving = false
    @State private var didAppear = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("venue-name")
                TextField("City", text: $city)
                    .accessibilityIdentifier("venue-city")
                TextField("Country", text: $country)
                    .accessibilityIdentifier("venue-country")
            }
            .listRowBackground(Color.panel)

            Section {
                MapReader { proxy in
                    Map(position: $position) {
                        if let pin {
                            Marker(name.isEmpty ? "Venue" : name, systemImage: "mappin", coordinate: pin)
                                .tint(Color.signal)
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.stadium])))
                    .onTapGesture { point in
                        if let coordinate = proxy.convert(point, from: .local) {
                            pin = coordinate
                        }
                    }
                }
                .frame(height: 240)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("venue-map")

                Button {
                    locator.start()
                } label: {
                    Label("Use my location", systemImage: "location.fill")
                }
                .accessibilityIdentifier("venue-use-location")
            }
            .listRowBackground(Color.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("New venue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                            .foregroundStyle(trimmedName.isEmpty ? Color.textTertiary : Color.black)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .disabled(trimmedName.isEmpty || saving)
                .accessibilityLabel("Save venue")
                .accessibilityIdentifier("venue-save")
            }
        }
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            name = initialName
            let home = CLLocationCoordinate2D(latitude: library.profile.homeLatitude, longitude: library.profile.homeLongitude)
            position = .region(MKCoordinateRegion(center: home, span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)))
        }
        .onChange(of: locator.location) { _, location in
            guard let location else { return }
            pin = location.coordinate
            position = .region(MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            locator.stop()
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() async {
        saving = true
        defer { saving = false }
        var coordinate = pin
        var placemark: CLPlacemark?
        if coordinate == nil {
            let query = [trimmedName, city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            placemark = try? await CLGeocoder().geocodeAddressString(query).first
            coordinate = placemark?.location?.coordinate
        } else if let c = coordinate {
            placemark = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude)).first
        }
        let c = coordinate ?? CLLocationCoordinate2D(latitude: library.profile.homeLatitude, longitude: library.profile.homeLongitude)
        let cityText = city.trimmingCharacters(in: .whitespaces)
        let countryText = country.trimmingCharacters(in: .whitespaces)
        let venue = Venue(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            city: cityText.isEmpty ? (placemark?.locality ?? "") : cityText,
            region: placemark?.administrativeArea,
            country: countryText.isEmpty ? (placemark?.country ?? "") : countryText,
            countryCode: placemark?.isoCountryCode ?? Locale.current.region?.identifier ?? "",
            latitude: c.latitude,
            longitude: c.longitude,
            sports: sport.map { [$0] } ?? [],
            timeZone: (placemark?.timeZone ?? .current).identifier,
            capacity: nil,
            opened: nil,
            isCustom: true)
        venueId = library.addVenue(venue).id
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}
