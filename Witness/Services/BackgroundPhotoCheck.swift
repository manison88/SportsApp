import BackgroundTasks
import Foundation

/// The game-day check that runs by itself: about hourly while a planned game is on or just over, when iOS allows it.
/// Each run turns a started plan with photos at its stadium into a game and keeps adding that day's photos and videos.
/// iOS decides when a run happens, so opening the app does the same check as a backup.
@MainActor
enum BackgroundPhotoCheck {
    static let identifier = "app.witness.ios.photocheck"
    private static weak var library: Library?

    /// The task is only used when the app's Info.plist lists it: asking for an unlisted one would crash the app.
    private static var permitted: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String])?.contains(identifier) == true
    }

    /// Call once, early, with the library the app runs on.
    static func register(_ library: Library) {
        self.library = library
        guard permitted else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            Task { @MainActor in await run(refresh) }
        }
    }

    /// Asks iOS for another run in about an hour, if there is a game day to watch.
    static func schedule() {
        guard permitted, let library, library.needsGameDayChecks else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func run(_ task: BGAppRefreshTask) async {
        schedule()
        let work = Task { await library?.gameDayPhotoCheck() }
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
}
