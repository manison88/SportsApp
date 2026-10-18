import SwiftUI

@main
struct WitnessApp: App {
    @State private var library: Library
    @State private var presenter = Presenter()

    init() {
        Appearance.apply()
        let args = ProcessInfo.processInfo.arguments
        let library = Library()
        if args.contains("-reset") { library.reset() }
        if args.contains("-demo") { library.loadSample() }
        if args.contains("-empty") { library.startEmpty() }
        if args.contains("-uitest") { UIView.setAnimationsEnabled(false) }
        _library = State(initialValue: library)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(presenter)
                .preferredColorScheme(.dark)
                .tint(.white)
                .task {
                    // Packs already on the phone first (instant), then ask the host for anything new.
                    await library.applyPacks()
                    if await PackStore.shared.refresh() { await library.applyPacks() }
                    await library.backfillWeather()
                    await library.repairSoccerPlays()
                }
        }
    }
}
