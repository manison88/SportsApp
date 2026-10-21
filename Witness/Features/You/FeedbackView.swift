import SwiftUI

/// You → Feedback & requests: pick what it is, say it in one box, send. A sport or league we don't have is one of the kinds,
/// so those requests land in the same list as everything else.
struct FeedbackView: View {
    @State private var kind: FeedbackKind = .feature
    @State private var text = ""
    @State private var sending = false
    @State private var sent = false
    @State private var failure: String?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                if sent {
                    thanks
                } else {
                    form
                }
            }
            .gutter()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .inkBackground()
        .navigationTitle("Feedback & requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Text("What would you like to see, what's missing, or what isn't working? A sport or league we don't have yet counts too.")
                .font(.footnote).foregroundStyle(Color.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("What is it?").unitLabel()
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(FeedbackKind.allCases) { k in
                            Button { kind = k } label: {
                                Text(k.label)
                                    .font(.condensed(.subheadline, weight: .heavy))
                                    .textCase(.uppercase)
                                    .foregroundStyle(kind == k ? Color.onPrimary : Color.primaryText)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .background(kind == k ? Color.primaryText : Color.panelRaised, in: .capsule)
                            }
                            .accessibilityAddTraits(kind == k ? .isSelected : [])
                            .accessibilityIdentifier("feedback-kind-\(k.rawValue)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField(kind.prompt, text: $text, axis: .vertical)
                    .lineLimit(4...14)
                    .padding(14)
                    .background(Color.panel, in: .rect(cornerRadius: 12))
                    .focused($focused)
                    .accessibilityIdentifier("feedback-text")
                    .onChange(of: text) { _, new in
                        if new.count > Feedback.maxLength { text = String(new.prefix(Feedback.maxLength)) }
                    }
                Text("Add an email if you'd like a reply. Nothing else about you is sent.")
                    .font(.footnote).foregroundStyle(Color.textTertiary)
            }

            if let failure {
                Text(failure).font(.footnote).foregroundStyle(Color.signal)
                    .accessibilityIdentifier("feedback-error")
            }

            Button { send() } label: {
                if sending {
                    ProgressView().tint(Color.onPrimary).frame(maxWidth: .infinity)
                } else {
                    Label("Send", systemImage: "paperplane")
                }
            }
            .buttonStyle(.primary)
            .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("feedback-send")
        }
    }

    private var thanks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Got it. Thank you.").font(.condensed(.title2, weight: .heavy)).textCase(.uppercase)
            Text("Every one of these gets read.").font(.subheadline).foregroundStyle(Color.textSecondary)
            Button("Send another") { sent = false; text = "" }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("feedback-another")
        }
        .accessibilityIdentifier("feedback-sent")
    }

    private func send() {
        focused = false
        sending = true
        failure = nil
        Task {
            do {
                try await Feedback.send(kind: kind, text: text)
                sent = true
            } catch Feedback.SendError.rejected(429) {
                failure = "That's a lot for one day. Try again tomorrow."
            } catch {
                failure = "Couldn't send. Check your connection and try again."
            }
            sending = false
        }
    }
}
