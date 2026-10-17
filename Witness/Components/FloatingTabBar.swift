import SwiftUI

enum WitnessTab: String, CaseIterable, Identifiable {
    case globe, timeline, passport, stats
    var id: String { rawValue }

    var title: String {
        switch self {
        case .globe: "Globe"
        case .timeline: "Timeline"
        case .passport: "Passport"
        case .stats: "Stats"
        }
    }

    var symbol: String {
        switch self {
        case .globe: "globe.americas.fill"
        case .timeline: "rectangle.stack.fill"
        case .passport: "seal.fill"
        case .stats: "chart.bar.xaxis"
        }
    }
}

/// Floating glass tab bar with a raised "I'm here" check-in button in the middle.
struct FloatingTabBar: View {
    @Binding var selection: WitnessTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            tab(.globe)
            tab(.timeline)
            checkIn
            tab(.passport)
            tab(.stats)
        }
        .padding(.horizontal, 8)
        .frame(height: Size.tabBarHeight)
        .glass(radius: Size.tabBarHeight / 2)
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        .padding(.horizontal, Space.gutter - 4)
    }

    private func tab(_ t: WitnessTab) -> some View {
        let isOn = selection == t
        return Button {
            withAnimation(Motion.snappy) { selection = t }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(t.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isOn ? Palette.textPrimary : Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                if isOn {
                    Capsule()
                        .fill(.white.opacity(0.09))
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var checkIn: some View {
        Button {} label: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.signalSoft, Palette.signal, Color(hex: "C97A1E")],
                                         center: .topLeading, startRadius: 2, endRadius: 52))
                    .shadow(color: Palette.signal.opacity(0.55), radius: 14, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            .frame(width: 50, height: 50)
            .padding(.horizontal, 6)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Check in to a game")
    }
}

#Preview {
    @Previewable @State var tab = WitnessTab.globe
    ZStack(alignment: .bottom) {
        Palette.ink.ignoresSafeArea()
        FloatingTabBar(selection: $tab)
    }
}
