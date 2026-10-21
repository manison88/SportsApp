import SwiftUI

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter

    var body: some View {
        @Bindable var presenter = presenter
        Group {
            if library.hasLibrary {
                tabs
            } else {
                OnboardingView()
            }
        }
        .background(Color.ink.ignoresSafeArea())
        .onChange(of: presenter.tab) { _, tab in
            Analytics.shared.track(.tabViewed, ["tab": "\(tab)"])
        }
        .sheet(item: sheetBinding) { modal in
            switch modal {
            case .addGame: AddGameView()
            case .planGame: PlanGameView()
            case .importTicket: TicketImportView()
            case .importAlbum: AlbumImportView()
            default: EmptyView()
            }
        }
        .fullScreenCover(item: coverBinding) { modal in
            switch modal {
            case .discovery: DiscoveryView()
            case .live: LiveCheckInView()
            case .recap(let id): RecapVideoView(gameId: id)
            case .wrapped(let year): WrappedView(year: year)
            default: EmptyView()
            }
        }
    }

    private var tabs: some View {
        @Bindable var presenter = presenter
        return TabView(selection: $presenter.tab) {
            Tab("Timeline", systemImage: "rectangle.stack.fill", value: AppTab.timeline) {
                NavigationStack { TimelineView().routes() }
            }
            Tab("Map", systemImage: "globe.americas.fill", value: AppTab.map) {
                LifeMapView()
            }
            Tab("Passport", systemImage: "person.text.rectangle.fill", value: AppTab.passport) {
                NavigationStack { PassportView().routes() }
            }
            Tab("You", systemImage: "person.crop.circle.fill", value: AppTab.you) {
                NavigationStack { YouView().routes() }
            }
        }
    }

    private static func isCover(_ m: Modal) -> Bool {
        switch m {
        case .addGame, .planGame, .importTicket, .importAlbum: false
        default: true
        }
    }

    private var sheetBinding: Binding<Modal?> {
        Binding(get: { presenter.modal.flatMap { Self.isCover($0) ? nil : $0 } },
                set: { if $0 == nil { presenter.modal = nil } })
    }

    private var coverBinding: Binding<Modal?> {
        Binding(get: { presenter.modal.flatMap { Self.isCover($0) ? $0 : nil } },
                set: { if $0 == nil { presenter.modal = nil } })
    }
}

extension View {
    /// Destinations for every pushed screen.
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .game(let id): GameMemoryView(gameId: id)
            case .youWereThere(let id): YouWereThereView(gameId: id)
            case .venue(let id): VenueView(venueId: id)
            case .trip(let id): TripView(tripId: id)
            case .lucky: LuckyCharmView()
            case .bigGames: BigGamesView()
            case .photos(let id): GamePhotosView(gameId: id)
            case .plan(let id): PlanView(planId: id)
            }
        }
    }
}
