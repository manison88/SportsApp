import SwiftUI

@main
struct WitnessApp: App {
    @State private var library: Library
    @State private var presenter = Presenter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "auto"

    init() {
        Appearance.apply()
        let args = ProcessInfo.processInfo.arguments
        let library = Library()
        if args.contains("-reset") {
            library.reset()
            try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "pending-visits.json"))
            try? FileManager.default.removeItem(at: ScanModel.ledgerURL)
            // The scan read both files when the presenter was made, above: start it again from the cleared ones.
            _presenter = State(initialValue: Presenter())
        }
        if args.contains("-demo") { library.loadSample() }
        if args.contains("-empty") { library.startEmpty() }
        if args.contains("-uitest") { UIView.setAnimationsEnabled(false) }
        if !args.contains("-uitest") { BackgroundPhotoCheck.register(library) }
        _library = State(initialValue: library)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(presenter)
                .preferredColorScheme(AppearanceChoice(stored: appearance).colorScheme)
                .tint(Color.primaryText)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        BackgroundPhotoCheck.schedule()
                        Task { await Analytics.shared.flush() }
                    }
                    if phase == .active { Analytics.shared.opened(games: library.games.count) }
                }
                .task {
                    // Packs already on the phone first (instant), then ask the host for anything new.
                    await library.applyPacks()
                    if await PackStore.shared.refresh(prefetch: library.relevantLeagues()) { await library.applyPacks() }
                    await library.backfillWeather()
                    await library.repairSoccerPlays()
                }
        }
    }
}
