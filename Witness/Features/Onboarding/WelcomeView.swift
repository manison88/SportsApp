import SwiftUI

/// The first screen. One photo, one line, one way in.
struct WelcomeView: View {
    @Environment(Library.self) private var library
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoView(ref: .bundled("wrigley-night"))
                .ignoresSafeArea()
            Scrim().ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.block) {
                (Text("Every game\n") + Text("you").foregroundStyle(Color.signal) + Text(" were at."))
                    .displayFont(68)
                    .textCase(.uppercase)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("welcome-title")

                VStack(spacing: Spacing.inner) {
                    Button("Get started", action: onStart)
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("welcome-start")

                    Button("Explore sample games") { library.loadSample() }
                        .font(.subheadline)
                        .underline()
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("welcome-sample")
                }
            }
            .gutter()
            .padding(.bottom, 12)
        }
        .background(Color.ink.ignoresSafeArea())
    }
}
