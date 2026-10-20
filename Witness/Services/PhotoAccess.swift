import SwiftUI
import Photos

/// What the fan allowed for photos, and the plain words for each case. With limited access the scan runs, but only over the photos
/// the fan picked, so an empty result there says so instead of "none taken inside a stadium".
enum PhotoAccess: Equatable {
    case full, limited, denied, undetermined

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .full
        case .limited: self = .limited
        case .notDetermined: self = .undetermined
        default: self = .denied
        }
    }

    static var current: PhotoAccess { PhotoAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite)) }

    var isLimited: Bool { self == .limited }

    /// Shown wherever a limited library could be the reason nothing was found.
    static let limitedMessage = "Witness can only see the photos you selected, so it can only find games in those. "
        + "Select more photos, or allow all photos in Settings."

    /// The empty result's explanation: the photos checked, or, with limited access, that only the selected photos were.
    static func emptyBody(_ access: PhotoAccess, checked: Int) -> String {
        if access.isLimited {
            return "Witness can only see the photos you selected (\(checked.formatted()) checked), and none were taken inside a stadium. "
                + "Select more photos, or allow all photos in Settings."
        }
        return "\(checked.formatted()) photos checked, none taken inside a stadium. Older photos, or ones with location off, may be missing a date or a place."
    }

    /// The line for visits whose schedule lookup could not run (no connection), nil when every visit was checked.
    static func uncheckedLine(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? "visit" : "visits") couldn't be checked, connect and run Find in photos again."
    }

    /// Opens the system's picker for adding more photos to the selection.
    @MainActor
    static func presentPicker() {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    @MainActor
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// The two ways out of limited access.
struct LimitedAccessButtons: View {
    var body: some View {
        Button("Select more photos") { PhotoAccess.presentPicker() }
            .buttonStyle(.primary)
            .accessibilityIdentifier("limited-access-select")
        Button("Open Settings") { PhotoAccess.openSettings() }
            .buttonStyle(.secondary)
            .accessibilityIdentifier("limited-access-settings")
    }
}
