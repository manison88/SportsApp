import SwiftUI

/// The first screen. A wall of photos counts down, one tap at a time, from a whole camera roll to the games in it, then
/// those games appear: the app's promise, shown at the fan's own pace before it asks for anything.
struct WelcomeView: View {
    @Environment(Library.self) private var library
    let onStart: () -> Void

    /// 0...4: the count's steps; the wall dims a share of its dots at each one.
    @State private var stage = 0
    @State private var cards = 0

    static let steps: [(count: Int, label: String, how: String)] = [
        (40_000, "Photos in your camera roll", "Somewhere in there is every game you went to. Nothing in your phone knows which."),
        (6_400, "Taken away from home", "Witness reads only when and where each photo was taken. Home, work and school drop out."),
        (1_284, "Taken at a stadium", "It keeps the photos taken inside a ballpark, arena, ground or circuit."),
        (312, "On a real game day", "Then it checks the real schedule for that stadium, that day."),
        (23, "Games you were at", ""),
    ]
    private static var last: Int { steps.count - 1 }

    /// Examples from the sample library, one per sport.
    static var examples: [(photo: String, venue: String, line: String, sport: String)] { [
        ("united-center-court", "United Center", "Feb 14, 2026 · CHI 112–109 MIA", "Basketball"),
        ("soldier-soccer", "Soldier Field", "Oct 4, 2025 · CHI 2–1 MIA", SoccerWord.name),
        ("lambeau-concourse", "Lambeau Field", "Jan 5, 2025 · CHI 24–22 GB", "NFL"),
        ("wrigley-night-2", "Wrigley Field", "Oct 30, 2016 · CHC 3–2 CLE", "Baseball"),
    ] }

    var body: some View {
        let step = Self.steps[stage]
        let done = stage == Self.last
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                DotWall(stage: stage)
                    .opacity(cards > 0 ? 0 : 1)
                VStack(spacing: 8) {
                    ForEach(Array(Self.examples.enumerated()), id: \.offset) { i, e in
                        if i < cards {
                            card(e).transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: 280, alignment: .top)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.count.formatted())
                    .displayFont(96)
                    .foregroundStyle(done ? Color.signal : .white)
                    .contentTransition(.numericText(value: Double(step.count)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(step.label)
                    .font(.condensed(.subheadline, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(2.4)
                    .foregroundStyle(done ? .white : Color.textSecondary)
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
                            Text("Your camera roll").foregroundStyle(.white)
                            Text("already knows.").foregroundStyle(Color.signal)
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
            if ProcessInfo.processInfo.arguments.contains("-uitest") { stage = Self.last; cards = Self.examples.count }
        }
    }

    /// One step down the count per tap; the last one brings the games in where the photos were.
    private func advance() {
        if stage == Self.last { onStart(); return }
        withAnimation(.smooth(duration: 0.5)) { stage += 1 }
        Analytics.shared.track(.onboardingStep, ["step": "welcome_\(stage)"])
        guard stage == Self.last else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            for i in 1...Self.examples.count {
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) { cards = i }
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }

    private func card(_ e: (photo: String, venue: String, line: String, sport: String)) -> some View {
        ZStack(alignment: .leading) {
            PhotoView(ref: .bundled(e.photo))
            LinearGradient(colors: [Color.ink.opacity(0.94), Color.ink.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.venue).font(.condensed(.title3, weight: .heavy)).textCase(.uppercase).foregroundStyle(.white)
                Text(e.line).font(.caption).foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 62)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            Text(e.sport)
                .font(.condensed(.caption2, weight: .heavy)).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(Color.signal)
                .padding(.horizontal, 8).frame(minHeight: 20)
                .background(Color.ink.opacity(0.7), in: .capsule)
                .padding(8)
        }
        .accessibilityElement(children: .combine)
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
                    .fill(isGold ? Color.signal : Color.panelRaised)
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(stands ? 1 : 0.07)
                    .scaleEffect(isGold ? 1.15 : (stands ? 1 : 0.55))
                    .shadow(color: isGold ? Color.signal.opacity(0.8) : .clear, radius: 6)
                    .animation(.easeIn(duration: 0.45).delay(Double((i * 37) % 23) * 0.015), value: stage)
            }
        }
        .accessibilityHidden(true)
    }

    /// Which dots still stand at a step: about 45% go at the first, 30% at the second, 18% at the third, the rest at the last.
    private static func lives(_ i: Int, at stage: Int) -> Bool {
        let r = Double((i * 97) % count) / Double(count)
        let goneAt = r < 0.45 ? 1 : r < 0.75 ? 2 : r < 0.93 ? 3 : 4
        return stage < goneAt
    }
}
