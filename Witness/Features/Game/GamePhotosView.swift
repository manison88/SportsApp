import SwiftUI

/// Every photo from a game in a grid. Tap one to see it full screen; choose which one heads the game.
struct GamePhotosView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @State private var viewer: PhotoViewerItem?
    @State private var picking = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        if let game = library.game(gameId) {
            ScrollView {
                if let cover = game.heroPhoto { header(game, cover: cover) }
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(Array(game.photos.enumerated()), id: \.offset) { i, ref in
                        Button { viewer = PhotoViewerItem(id: i) } label: {
                            Color.panel
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { PhotoView(ref: ref) }
                                .overlay(alignment: .bottomLeading) {
                                    if ref == game.heroPhoto { coverTag(auto: game.coverChosenByFan != true) }
                                }
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Use as cover", systemImage: "photo.badge.checkmark") {
                                library.setCover(game.id, to: ref, byFan: true)
                            }
                        }
                        .accessibilityLabel("Photo \(i + 1) of \(game.photos.count)")
                        .accessibilityIdentifier("photos-tile-\(i)")
                    }
                }
                .padding(.horizontal, 3)
                .accessibilityIdentifier("photos-grid")
            }
            .inkBackground()
            .navigationTitle(game.photos.count == 1 ? "1 photo" : "\(game.photos.count) photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        picking = true
                        Task {
                            await library.autoCover(game.id, force: true)
                            picking = false
                        }
                    } label: {
                        if picking { ProgressView() } else { Image(systemName: "sparkles") }
                    }
                    .disabled(picking || game.photos.count < 2 || game.coverChosenByFan == true)
                    .accessibilityLabel("Pick the best photo")
                    .accessibilityIdentifier("photos-auto")
                }
            }
            .fullScreenCover(item: $viewer) { item in
                PhotoPager(photos: game.photos, start: item.id, cover: game.heroPhoto) { ref in
                    library.setCover(game.id, to: ref, byFan: true)
                }
            }
        } else {
            ContentUnavailableView("Game not found", systemImage: "photo").inkBackground()
        }
    }

    private func header(_ game: GameEntry, cover: PhotoRef) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.coverChosenByFan == true ? "Your cover photo" : "Cover photo, picked for you")
                .font(.condensed(.subheadline, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color.textSecondary)
            Text(game.coverChosenByFan == true ? "Touch and hold any photo, or open it, to change it."
                                              : "Open any photo and tap Use as cover to choose your own. The sparkle button picks again.")
                .font(.footnote)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gutter()
        .padding(.vertical, 10)
        .accessibilityIdentifier("photos-cover-note")
    }

    private func coverTag(auto: Bool) -> some View {
        Label("Cover", systemImage: auto ? "sparkles" : "checkmark")
            .font(.condensed(.caption, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(.black.opacity(0.6), in: .capsule)
            .padding(6)
    }
}
