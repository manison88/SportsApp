import SwiftUI

/// Scrollable index of every mockup screen, for quick review.
struct ScreenGallery: View {
    private let columns = [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Witness · Mockups").eyebrow(Palette.signal)
                    Text("Every game you’ve been to, remembered.")
                        .font(WType.display(34))
                        .tracking(Tracking.display)
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(ScreenCatalog.all.filter(\.isBuilt).count) of \(ScreenCatalog.all.count) screens built")
                        .font(WType.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.top, Space.l)

                LazyVGrid(columns: columns, spacing: Space.s) {
                    ForEach(ScreenCatalog.all) { spec in
                        if spec.isBuilt {
                            NavigationLink { ScreenCatalog.destination(spec.id) } label: { GalleryTile(spec: spec) }
                                .buttonStyle(PressableStyle())
                        } else {
                            GalleryTile(spec: spec)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .background(Palette.ink.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct GalleryTile: View {
    let spec: ScreenSpec

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            StadiumPhoto(style: spec.art, seed: UInt64(spec.id * 7919), accent: spec.tint, grain: 0.08)
                .saturation(spec.isBuilt ? 1 : 0.15)
                .opacity(spec.isBuilt ? 1 : 0.55)
            BottomScrim(color: .black)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%02d", spec.id))
                    .font(WType.score(30))
                    .foregroundStyle(spec.isBuilt ? Palette.signal : Palette.textTertiary)
                Text(spec.title)
                    .font(WType.display(18))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(spec.isBuilt ? spec.signature : "Phase 2")
                    .font(WType.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(Space.m)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Radius.photo + 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.photo + 4, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: Size.hairline)
        }
    }
}

// MARK: - Catalog

struct ScreenSpec: Identifiable {
    let id: Int
    let title: String
    let signature: String
    let art: PhotoStyle
    let tint: Color
    let isBuilt: Bool
}

enum ScreenCatalog {
    static let all: [ScreenSpec] = [
        .init(id: 1, title: "Welcome", signature: "Slow pan over stadium lights", art: .lightTower, tint: Palette.signal, isBuilt: false),
        .init(id: 2, title: "Camera roll discovery", signature: "Games materialize from photo metadata", art: .concourse, tint: Palette.signal, isBuilt: false),
        .init(id: 3, title: "Life Globe", signature: "Arcs to every venue, brighter with each return", art: .skyline, tint: Palette.arc, isBuilt: true),
        .init(id: 4, title: "Passport", signature: "Foil stamps that tilt with your phone", art: .scoreboard, tint: Color(hex: "B79CFF"), isBuilt: false),
        .init(id: 5, title: "Timeline", signature: "Every game as a memory card", art: .diamond, tint: Color(hex: "2F6BFF"), isBuilt: false),
        .init(id: 6, title: "Game memory", signature: "Parallax hero, score set like a broadcast bug", art: .snowGame, tint: Color(hex: "F05A1A"), isBuilt: true),
        .init(id: 7, title: "You were there", signature: "Your photos pinned to the win-probability curve", art: .celebration, tint: Color(hex: "2F6BFF"), isBuilt: true),
        .init(id: 8, title: "Recap film", signature: "An auto-built short film, mid-playback", art: .nightField, tint: Palette.signal, isBuilt: false),
        .init(id: 9, title: "Venue", signature: "3D flyover and your record there", art: .dayGame, tint: Color(hex: "2F6BFF"), isBuilt: false),
        .init(id: 10, title: "Lifetime stats", signature: "Editorial data spread", art: .scoreboard, tint: Palette.signal, isBuilt: false),
        .init(id: 11, title: "Season Wrapped", signature: "Story-format share cards", art: .celebration, tint: Color(hex: "FF7A8A"), isBuilt: false),
        .init(id: 12, title: "Live check-in", signature: "Venue detected, Live Activity", art: .arena, tint: Color(hex: "E8213F"), isBuilt: false),
        .init(id: 13, title: "Shared passport", signature: "17 games together", art: .crowd, tint: Color(hex: "FF7A8A"), isBuilt: false),
        .init(id: 14, title: "Trip", signature: "Spain, before the quiet", art: .pitch, tint: Color(hex: "D3125E"), isBuilt: false),
        .init(id: 15, title: "Print shop", signature: "Hardcover season book", art: .concourse, tint: Palette.signalSoft, isBuilt: false),
    ]

    @ViewBuilder
    static func destination(_ id: Int) -> some View {
        switch id {
        case 3: LifeGlobeScreen()
        case 6: GameMemoryDetailScreen()
        case 7: YouWereThereScreen()
        default: ScreenGallery()
        }
    }
}

#Preview {
    NavigationStack { ScreenGallery() }
}
