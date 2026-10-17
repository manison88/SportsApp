import Foundation
import Observation

/// The first scan of the photo library, started from onboarding. It is owned by the app, not by a screen, so it keeps
/// running when the person leaves the scan screen and the Timeline can show where it has got to.
@Observable
@MainActor
final class ScanModel {
    enum State: Equatable { case idle, scanning, done, empty, denied }

    private(set) var state: State = .idle
    private(set) var progress = PhotoMatcher.ScanProgress()
    private(set) var clusters: [PhotoCluster] = []
    /// The newest visit's game on the real schedule, when there is one.
    private(set) var newest: FoundGame?
    /// Set once the review screen has taken the results, so the Timeline banner goes away.
    private(set) var reviewed = false

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Asks for photo access if needed, then scans. Safe to call again after access is granted in Settings.
    func start(library: Library) {
        guard state != .scanning else { return }
        task = Task { await run(library: library) }
    }

    func markReviewed() { reviewed = true }

    func reset() {
        task?.cancel()
        state = .idle
        progress = .init()
        clusters = []
        newest = nil
        reviewed = false
    }

    private func run(library: Library) async {
        guard await PhotoMatcher.requestAccess() else { state = .denied; return }
        progress = .init()
        clusters = []
        newest = nil
        reviewed = false
        state = .scanning
        let found = await PhotoMatcher.discover(venues: library.venues, existing: library.games) { p in
            Task { @MainActor [weak self] in
                guard let self, self.state == .scanning else { return }
                self.progress = p
            }
        }
        progress.scanned = progress.total
        clusters = found
        state = found.isEmpty ? .empty : .done
        if let first = found.first {
            newest = await GameLookup.games(at: first.venue, from: first.start, to: first.end).first
        }
    }
}
