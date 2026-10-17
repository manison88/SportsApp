import SwiftUI

/// First launch. One photo, one line, one way in.
struct WelcomeView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoView(ref: .bundled("wrigley-night"))
                .ignoresSafeArea()
            Scrim().ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.block) {
                Text("Every game\nyou were at.")
                    .displayFont(72)
                    .textCase(.uppercase)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: Spacing.inner) {
                    Button {
                        presenter.modal = .discovery
                    } label: {
                        Label("Find games in my photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("welcome-photos")

                    HStack(spacing: 0) {
                        Button("Add a game") {
                            library.startEmpty()
                            presenter.modal = .addGame
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("welcome-add")

                        Button("Explore sample games") {
                            library.loadSample()
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("welcome-sample")
                    }
                    .font(.condensed(.headline, weight: .bold))
                    .foregroundStyle(.white)

                    Label("Everything stays on this iPhone.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .gutter()
            .padding(.bottom, 12)
        }
        .background(Color.ink.ignoresSafeArea())
    }
}
