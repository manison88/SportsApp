import SwiftUI

/// Typographic stand-in for a team mark: the team's two colors and a compressed
/// monogram. Never a logo.
struct TeamMonogram: View {
    let team: Team
    var size: CGFloat = Size.monogram
    var dimmed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [team.primaryColor, team.primaryColor.mix(with: team.secondaryColor, by: 0.35)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            // secondary color as a thin inner keyline, like a jersey trim
            shape.inset(by: size * 0.07)
                .strokeBorder(team.secondaryColor.opacity(0.85), lineWidth: max(1, size * 0.035))
            Text(team.monogram)
                .font(.system(size: size * fontScale, weight: .black).width(.compressed))
                .tracking(-0.5)
                .foregroundStyle(team.primaryIsLight ? Color.black.opacity(0.85) : .white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size)
        .overlay { shape.strokeBorder(.white.opacity(0.14), lineWidth: Size.hairline) }
        .shadow(color: team.accentColor.opacity(dimmed ? 0 : 0.35), radius: size * 0.25, y: size * 0.08)
        .saturation(dimmed ? 0.35 : 1)
        .opacity(dimmed ? 0.6 : 1)
        .accessibilityLabel(team.displayName)
    }

    private var fontScale: CGFloat {
        switch team.monogram.count {
        case 1: 0.6
        case 2: 0.48
        default: 0.38
        }
    }
}

#Preview {
    let store = MockStore.shared
    HStack(spacing: 12) {
        ForEach(["mlb-chc", "mlb-cle", "nfl-chi", "nfl-gb", "lal-rma", "bun-bvb"], id: \.self) { id in
            TeamMonogram(team: store.teams[id]!)
        }
    }
    .padding()
    .background(Palette.ink)
}
