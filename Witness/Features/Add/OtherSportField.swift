import SwiftUI

/// What to call a sport or event that isn't one of the app's sports: a text field and suggestion chips.
/// Used by Add Game, Live check-in and the stadium-visit review whenever the sport is Other.
struct OtherSportField: View {
    @Binding var text: String
    var prompt = "What sport or event?"

    static let suggestions = ["Rugby", "Cricket", "Tennis", "Volleyball", "Rodeo", "Concert", "Other"]
    static let maxLength = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("other-sport-field")
                .onChange(of: text) { _, new in
                    if new.count > Self.maxLength { text = String(new.prefix(Self.maxLength)) }
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.suggestions, id: \.self) { s in
                        let on = text.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(s) == .orderedSame
                        Button { text = s } label: {
                            Text(s)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(on ? Color.onPrimary : Color.primaryText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(on ? Color.primaryText : Color.panelRaised, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("other-sport-chip-\(s)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }
}

extension String {
    /// Trimmed, or nil when nothing is left.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
