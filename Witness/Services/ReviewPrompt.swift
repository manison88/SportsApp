import SwiftUI
import StoreKit

/// The App Store review ask, once: after onboarding, with a real game of the fan's own in the library (found in photos or
/// added by hand, with or without photo access), when they open a game page and come back out of it. The game page notes
/// that it was opened; the home screen it pops back to does the asking, so a push deeper (photos, the venue) never asks
/// mid-flow. Never over the sample games, never in UI tests. Apple shows the sheet at most a few times a year anyway.
@MainActor
enum ReviewPrompt {
    static let askedKey = "WitnessAskedForReview"
    /// Set when a game page appears; cleared once the ask has gone out.
    private(set) static var gameOpened = false

    static func noteGameOpened() { gameOpened = true }

    static func shouldAsk(library: Library, defaults: UserDefaults = .standard,
                          arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        guard gameOpened, library.hasLibrary, !library.isSample, !arguments.contains("-uitest"),
              !defaults.bool(forKey: askedKey) else { return false }
        return library.games.contains { $0.origin != .sample }
    }

    static func markAsked(defaults: UserDefaults = .standard) {
        gameOpened = false
        defaults.set(true, forKey: askedKey)
    }

    /// Tests start clean.
    static func reset(defaults: UserDefaults = .standard) {
        gameOpened = false
        defaults.removeObject(forKey: askedKey)
    }
}

private struct AsksForReviewAfterAGame: ViewModifier {
    @Environment(Library.self) private var library
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onAppear {
            guard ReviewPrompt.shouldAsk(library: library) else { return }
            ReviewPrompt.markAsked()
            // After the pop animation, so the sheet comes up over a settled screen.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.7))
                requestReview()
            }
        }
    }
}

extension View {
    /// On a tab's home screen: asks for a review when the fan comes back from a game page, under `ReviewPrompt`'s rule.
    func asksForReviewAfterAGame() -> some View { modifier(AsksForReviewAfterAGame()) }
}
