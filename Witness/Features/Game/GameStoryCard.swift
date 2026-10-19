import SwiftUI

/// A game as a story to share, built from the Timeline's own pieces (the date block, the ticket stub, the score tear-off), so it
/// looks the same for every sport. Laid out at phone size (390 points wide) and scaled up to the story's pixels.
/// Needs `Library` in the environment; the photo and the aerial view come in already loaded.
struct GameStoryCard: View {
    enum Style: CaseIterable {
        case ticket, fullBleed, scoreboard, aerial, split, framed

        var name: String {
            switch self {
            case .ticket: "Ticket"
            case .fullBleed: "Full bleed"
            case .scoreboard: "Scoreboard"
            case .aerial: "Aerial"
            case .split: "Split"
            case .framed: "Framed"
            }
        }
    }

    @Environment(Library.self) private var library
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
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .ticket: ticket
        case .fullBleed: fullBleed
        case .scoreboard: scoreboard
        case .aerial: aerialCard
        case .split: split
        case .framed: framed
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
        DateBlock(date: game.date, tz: tz, venue: venue, championship: championship)
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
                .foregroundStyle(.white)
        }
        .padding(.bottom, size * 0.75)
        .shadow(color: .black.opacity(0.3), radius: 4)
    }

    // MARK: Looks

    /// The Timeline card itself, on ink.
    private var ticket: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)
            wordmark()
            TimelineCard(game: game, photo: photo)
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

    /// No photo: the score is the picture.
    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) { wordmark(); Spacer(minLength: 8); mark }
            dateBlock
            Spacer(minLength: 0)
            bigScore
            Spacer(minLength: 0)
            GameStub(game: game).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
        .padding(.bottom, 24)
        .background {
            LinearGradient(colors: [accent.opacity(0.45), Color.ink.opacity(0)], startPoint: .top, endPoint: .center)
        }
    }

    /// Both sides large, or the race winner, or the visit; the same three cases as the stub's tear-off.
    @ViewBuilder
    private var bigScore: some View {
        if game.sport == .motorsport || game.isVisit || game.homeTeamId == nil {
            TearOff(game: game).scaleEffect(1.8, anchor: .leading).frame(height: 160, alignment: .leading)
        } else {
            VStack(spacing: 14) {
                scoreRow(game.awayTeamId, game.awayScore)
                scoreRow(game.homeTeamId, game.homeScore)
            }
        }
    }

    private func scoreRow(_ teamId: String?, _ score: Int?) -> some View {
        let team = library.team(teamId)
        let mine = teamId != nil && teamId == library.rootingTeam(game)
        return HStack(spacing: 16) {
            if let team { TeamTile(team: team).scaleEffect(1.5, anchor: .leading).frame(width: 96, alignment: .leading) }
            Text(team?.locationName.uppercased() ?? "")
                .font(.display(34)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(mine ? .white : .white.opacity(0.7))
            Spacer(minLength: 8)
            Text(score.map(String.init) ?? "")
                .font(.display(96)).monospacedDigit()
                .foregroundStyle(mine ? .white : .white.opacity(0.7))
        }
    }

    /// The ground from above in the team's color, like a passport stamp.
    private var aerialCard: some View {
        ZStack(alignment: .bottomLeading) {
            accent
                .overlay {
                    if let aerial {
                        Image(uiImage: aerial).resizable().scaledToFill()
                            .saturation(0).opacity(0.6).blendMode(.luminosity)
                    }
                }
                .frame(width: Self.width, height: height)
                .clipped()
            LinearGradient(colors: [.clear, Color.ink.opacity(0.95)], startPoint: .center, endPoint: .bottom)
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

    /// Photo on top, the date and the stub on ink below.
    private var split: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover.frame(width: Self.width, height: height * 0.44).clipped()
                .overlay(alignment: .topTrailing) { mark.padding(.top, 50).padding(.trailing, 18) }
            VStack(alignment: .leading, spacing: 18) {
                wordmark()
                dateBlock
                Spacer(minLength: 0)
                GameStub(game: game).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    /// The photo framed like a print, with the date under it rather than over it.
    private var framed: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) { wordmark(); Spacer(minLength: 8); mark }
            cover
                .frame(width: Self.width - 36, height: (Self.width - 36) * 0.68)
                .clipShape(.rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12)))
            dateBlock
            Spacer(minLength: 0)
            GameStub(game: game).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
        .padding(.bottom, 24)
    }
}
