import SwiftUI

/// A game as a story to share, built from the Timeline's own pieces (the date block, the ticket stub, the score tear-off), so it
/// looks the same for every sport. Laid out at phone size (390 points wide) and scaled up to the story's pixels.
/// Needs `Library` in the environment; the photo and the aerial view come in already loaded.
struct GameStoryCard: View {
    enum Style: CaseIterable {
        case ticket, fullBleed

        var name: String {
            switch self {
            case .ticket: "Ticket"
            case .fullBleed: "Full bleed"
            }
        }
    }

    @Environment(Library.self) private var library
    @Environment(\.colorScheme) private var scheme
    let style: Style
    let game: GameEntry
    let photo: UIImage?
    let aerial: UIImage?

    private static let width: CGFloat = 390
    private var scale: CGFloat { ShareCardFormat.story.size.width / Self.width }
    private var height: CGFloat { ShareCardFormat.story.size.height / scale }

    private var venue: Venue? { library.venue(game.venueId) }
    private var tz: TimeZone { venue?.tz ?? .current }
    private var accent: Color { library.team(library.rootingTeam(game))?.accent ?? Color.signal }
    private var championship: Bool { game.bigGame?.kind == .championship }

    var body: some View {
        content
            .frame(width: Self.width, height: height)
            .background(Color.ink)
            .clipped()
            .environment(\.dynamicTypeSize, .large)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: ShareCardFormat.story.size.width, height: ShareCardFormat.story.size.height, alignment: .topLeading)
            .shareSurface()
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .ticket: ticket
        case .fullBleed: fullBleed.shareOnPhoto()
        }
    }

    // MARK: Pieces

    /// The cover, or the team-color field the Timeline shows when a game has no photo.
    @ViewBuilder
    private var cover: some View {
        if let photo {
            Image(uiImage: photo).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [accent.opacity(0.55), Color.ink], startPoint: .topTrailing, endPoint: .bottomLeading)
                .overlay {
                    Image(systemName: game.sport.symbol)
                        .font(.system(size: 160, weight: .bold))
                        .foregroundStyle(.white.opacity(0.07))
                        .rotationEffect(.degrees(-12))
                }
        }
    }

    @ViewBuilder
    private var mark: some View {
        if let stage = game.bigGame { EventMark(game: game, stage: stage) }
    }

    private var dateBlock: some View {
        DateBlock(date: game.date, tz: tz, venue: venue, championship: championship, aerial: aerial, sport: game.sport)
    }

    /// WITNESS with SPORTS in yellow tucked under it, the same mark as the passport card; the card's headline brand.
    private func wordmark(_ size: CGFloat = 26) -> some View {
        ZStack(alignment: .topLeading) {
            Text("SPORTS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(Color.signal)
                .offset(x: size, y: size * 0.75)
            Text("WITNESS")
                .font(.system(size: size, weight: .heavy).width(.compressed)).tracking(size * 0.32)
                .foregroundStyle(Color.primaryText)
        }
        .padding(.bottom, size * 0.75)
        .shadow(color: .black.opacity(scheme == .light && style == .ticket ? 0 : 0.3), radius: 4)
    }

    // MARK: Looks

    /// The Timeline card itself, on ink.
    private var ticket: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)
            wordmark()
            TimelineCard(game: game, photo: photo, aerial: aerial)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 40)
        .padding(.bottom, 24)
    }

    /// The photo fills the story; the date and the stub sit at the bottom.
    private var fullBleed: some View {
        ZStack(alignment: .bottomLeading) {
            cover.frame(width: Self.width, height: height).clipped()
            Scrim()
            VStack(alignment: .leading, spacing: 18) {
                dateBlock
                GameStub(game: game).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .overlay(alignment: .topLeading) { wordmark().padding(.top, 50).padding(.leading, 18) }
        .overlay(alignment: .topTrailing) { mark.padding(.top, 50).padding(.trailing, 18) }
    }
}
