import SwiftUI

/// Every photo from a game in a grid. Tap one to see it full screen; choose which one heads the game.
struct GamePhotosView: View {
    let gameId: String

    @Environment(Library.self) private var library
    @State private var viewer: PhotoViewerItem?
    @State private var picking = false
    @State private var selecting = false
    @State private var selected = Set<PhotoRef>()
    @State private var confirmRemove = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        if let game = library.game(gameId) {
            ScrollView {
                if let cover = game.heroPhoto { header(game, cover: cover) }
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(Array(game.photos.enumerated()), id: \.offset) { i, ref in
                        Button {
                            if selecting {
                                if selected.contains(ref) { selected.remove(ref) } else { selected.insert(ref) }
                            } else {
                                viewer = PhotoViewerItem(id: i)
                            }
                        } label: {
                            Color.panel
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { PhotoView(ref: ref) }
                                .overlay(alignment: .bottomLeading) {
                                    if ref == game.heroPhoto, !selecting { coverTag(auto: game.coverChosenByFan != true) }
                                }
                                .overlay { if selected.contains(ref) { Color.signal.opacity(0.28) } }
                                .overlay(alignment: .topTrailing) {
                                    if selecting {
                                        Image(systemName: selected.contains(ref) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selected.contains(ref) ? Color.signal : .white)
                                            .shadow(color: .black.opacity(0.5), radius: 2)
                                            .padding(6)
                                            .accessibilityHidden(true)
                                    }
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
                        .accessibilityAddTraits(selected.contains(ref) ? .isSelected : [])
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
                    Button(selecting ? "Done" : "Select") {
                        selecting.toggle()
                        selected = []
                    }
                    .disabled(game.photos.isEmpty)
                    .accessibilityIdentifier("photos-select")
                }
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
            .safeAreaInset(edge: .bottom) {
                if selecting {
                    HStack {
                        Button(selected.count == game.photos.count ? "Select none" : "Select all") {
                            selected = selected.count == game.photos.count ? [] : Set(game.photos)
                        }
                        .accessibilityIdentifier("photos-select-all")
                        Spacer()
                        Button(role: .destructive) { confirmRemove = true } label: {
                            Label(selected.isEmpty ? "Remove" : "Remove \(selected.count)", systemImage: "trash")
                        }
                        .disabled(selected.isEmpty)
                        .accessibilityIdentifier("photos-remove")
                    }
                    .font(.condensed(.headline, weight: .heavy))
                    .padding(.horizontal, 20)
                    .frame(minHeight: 56)
                    .background(.ultraThinMaterial)
                }
            }
            .confirmationDialog("Remove \(selected.count) \(selected.count == 1 ? "photo" : "photos") from this game?",
                                isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    library.removePhotos(game.id, selected)
                    selected = []
                    selecting = false
                }
            } message: {
                Text("They stay in your Photos library.")
            }
            .fullScreenCover(item: $viewer) { item in
                PhotoPager(photos: game.photos, start: item.id, cover: game.heroPhoto, onSetCover: { ref in
                    library.setCover(game.id, to: ref, byFan: true)
                }, onDelete: { ref in
                    library.removePhotos(game.id, [ref])
                })
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
