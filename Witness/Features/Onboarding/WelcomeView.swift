import SwiftUI

/// The first screen. A wall of photos counts down, one tap at a time, from a whole camera roll to the games in it, then
/// those games appear: the app's promise, shown at the fan's own pace before it asks for anything.
struct WelcomeView: View {
    @Environment(Library.self) private var library
    let onStart: () -> Void

    /// 0...4: the count's steps; the wall dims a share of its dots at each one.
    @State private var stage = 0
    /// The last step: the amber dots burst into a collage of game photos.
    @State private var revealed = false

    static let steps: [(count: Int, label: String, how: String)] = [
        (40_000, "Photos in your camera roll", "Somewhere in there is every game you went to. Nothing in your phone knows which."),
        (6_400, "Taken away from home", "Witness reads only when and where each photo was taken. Home, work and school drop out."),
        (1_284, "Taken at a stadium", "It keeps the photos taken inside a ballpark, arena, ground or circuit."),
        (312, "On a real game day", "Then it checks the real schedule for that stadium, that day."),
        (23, "Games you were at", ""),
    ]
    private static var last: Int { steps.count - 1 }

    /// Photos from the sample library for the collage, one per game.
    static let photos = ["wrigley-night", "soldier-soccer", "lambeau-exterior", "united-center-court", "camp-nou-aerial",
                         "fenway-night", "wrigley-bleachers", "soldier-skyline", "lambeau-concourse", "wrigley-scoreboard",
                         "fenway-day", "soldier-aerial", "fenway-postcard", "wrigley-night-2"]

    var body: some View {
        let step = Self.steps[stage]
        let done = stage == Self.last
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                DotWall(stage: stage)
                    .opacity(revealed ? 0 : 1)
                    .animation(.easeOut(duration: 0.35), value: revealed)
                Collage(revealed: revealed)
            }
            .frame(height: 280, alignment: .top)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.count.formatted())
                    .displayFont(96)
                    .foregroundStyle(done ? Color.signal : Color.primaryText)
                    .contentTransition(.numericText(value: Double(step.count)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(step.label)
                    .font(.condensed(.subheadline, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(2.4)
                    .foregroundStyle(done ? Color.primaryText : Color.textSecondary)
                    .contentTransition(.opacity)
            }
            .padding(.top, 18)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("welcome-count")

            Spacer(minLength: 12)

            Group {
                if done {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: -4) {
                            Text("Every night,").foregroundStyle(Color.primaryText)
                            Text("back in one place.").foregroundStyle(Color.signal)
                        }
                        .displayFont(48)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("welcome-title")
                        Text("The score, the weather and your photos for every game. Every sport, no typing.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(step.how)
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(stage)
                }
            }
            .transition(.opacity.combined(with: .offset(y: 10)))

            VStack(spacing: Spacing.inner) {
                Button(done ? "Get started" : stage == 0 ? "Start" : "Next") { advance() }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("welcome-start")

                Button("Explore sample games") { library.loadSample() }
                    .font(.subheadline)
                    .underline()
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("welcome-sample")
            }
            .padding(.top, 20)
        }
        .gutter()
        .padding(.bottom, 12)
        .background(Color.ink.ignoresSafeArea())
        .onAppear {
            // UI tests go straight to the end, so one tap on the button starts onboarding.
            if ProcessInfo.processInfo.arguments.contains("-uitest") { stage = Self.last; revealed = true }
        }
    }

    /// One step down the count per tap; the last one brings the games in where the photos were.
    private func advance() {
        if stage == Self.last { onStart(); return }
        withAnimation(.smooth(duration: 0.5)) { stage += 1 }
        Analytics.shared.track(.onboardingStep, ["step": "welcome_\(stage)"])
        guard stage == Self.last else { return }
        Task {
            // The amber dots light up first, then burst into the photos.
            try? await Task.sleep(for: .milliseconds(550))
            revealed = true
        }
    }
}

/// One tile per game, a few of them big, bursting out of amber in a quick ripple.
private struct Collage: View {
    let revealed: Bool
    /// Column, row, width, height on a 6 x 5 grid: 23 tiles, three of them bigger.
    private static let tiles: [(c: Int, r: Int, w: Int, h: Int)] = [
        (0, 0, 2, 2), (2, 0, 1, 1), (3, 0, 1, 1), (4, 0, 1, 1), (5, 0, 1, 1), (2, 1, 1, 1), (3, 1, 1, 1), (4, 1, 2, 1),
        (0, 2, 1, 1), (1, 2, 1, 1), (2, 2, 1, 1), (3, 2, 2, 2), (5, 2, 1, 1),
        (0, 3, 1, 1), (1, 3, 1, 1), (2, 3, 1, 1), (5, 3, 1, 1),
        (0, 4, 1, 1), (1, 4, 1, 1), (2, 4, 1, 1), (3, 4, 1, 1), (4, 4, 1, 1), (5, 4, 1, 1),
    ]

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 5
            let side = min((geo.size.width - gap * 5) / 6, (geo.size.height - gap * 4) / 5)
            ForEach(Array(Self.tiles.enumerated()), id: \.offset) { i, t in
                let w = side * CGFloat(t.w) + gap * CGFloat(t.w - 1)
                let h = side * CGFloat(t.h) + gap * CGFloat(t.h - 1)
                Color.panel
                    .overlay { Image(WelcomeView.photos[(i * 5) % WelcomeView.photos.count]).resizable().scaledToFill() }
                    .overlay { Color.signal.opacity(revealed ? 0 : 1) }
                    .frame(width: w, height: h)
                    .clipShape(.rect(cornerRadius: 8))
                    .scaleEffect(revealed ? 1 : 0.15)
                    .opacity(revealed ? 1 : 0)
                    .position(x: CGFloat(t.c) * (side + gap) + w / 2, y: CGFloat(t.r) * (side + gap) + h / 2)
                    .animation(.spring(duration: 0.6, bounce: 0.3).delay(Double((i * 7) % 23) * 0.035), value: revealed)
            }
        }
        .frame(height: 280)
        .accessibilityHidden(true)
    }
}

/// A camera roll as a wall of dots. Each step of the count dims its share; the last few, the games, turn amber.
struct DotWall: View {
    let stage: Int
    private static let count = 216
    private static let gold: Set<Int> = [22, 57, 101, 140, 175, 198]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 18), spacing: 3) {
            ForEach(0..<Self.count, id: \.self) { i in
                let isGold = Self.gold.contains(i) && stage == WelcomeView.steps.count - 1
                let stands = Self.gold.contains(i) || Self.lives(i, at: stage)
                RoundedRectangle(cornerRadius: 2)
                    .fill(isGold ? Color.signal : (stands ? Self.survivor(stage) : Color.panelRaised))
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(stands ? 1 : 0.35)
                    .scaleEffect(isGold ? 1.15 : (stands ? 1 : 0.5))
                    .shadow(color: isGold ? Color.signal.opacity(0.8) : (stands && stage == 3 ? Color.signal.opacity(0.35) : .clear),
                            radius: isGold ? 6 : 3)
                    .animation(.easeInOut(duration: 0.45).delay(Double((i * 37) % 23) * 0.015), value: stage)
            }
        }
        .accessibilityHidden(true)
    }

    /// The photos still in the running get brighter and warmer at every step, so the wall narrows visibly toward the games.
    private static func survivor(_ stage: Int) -> Color {
        switch stage {
        case 0: Color(white: 0.30)
        case 1: Color(white: 0.45)
        case 2: Color(white: 0.62)
        case 3: Color.signal.opacity(0.55)
        default: Color.signal
        }
    }

    /// Which dots still stand at a step: about 45% go at the first, 30% at the second, 18% at the third, the rest at the last.
    private static func lives(_ i: Int, at stage: Int) -> Bool {
        let r = Double((i * 97) % count) / Double(count)
        let goneAt = r < 0.45 ? 1 : r < 0.75 ? 2 : r < 0.93 ? 3 : 4
        return stage < goneAt
    }
}
