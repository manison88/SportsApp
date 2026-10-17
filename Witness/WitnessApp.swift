import SwiftUI

@main
struct WitnessApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Palette.signal)
        }
    }
}

/// Opens the gallery, or jumps straight to one screen when launched with
/// `-screen <n>` (used by Tools/export_screenshots.sh with `simctl launch`).
struct RootView: View {
    private let screen = UserDefaults.standard.integer(forKey: "screen")

    var body: some View {
        NavigationStack {
            if screen > 0 {
                ScreenCatalog.destination(screen)
            } else {
                ScreenGallery()
            }
        }
    }
}
