import SwiftUI

/// Where the app's legal links point. The pages are served by the analytics Worker (/privacy and /terms), so they share its address.
enum LegalLinks {
    private static var base: String { Analytics.endpoint.replacingOccurrences(of: "/e", with: "", options: [.backwards, .anchored]) }
    static var isOnline: Bool { !base.contains("SUBDOMAIN") }
    static var privacy: URL? { isOnline ? URL(string: base + "/privacy") : nil }
    static var terms: URL? { isOnline ? URL(string: base + "/terms") : nil }
}

/// The privacy policy or the terms of use, read inside the app, so they are always available, even offline.
struct LegalView: View {
    let document: LegalDocument
    let online: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(document.title).displayFont(44, relativeTo: .largeTitle).textCase(.uppercase)
                Text("Effective \(document.effective)").font(.footnote).foregroundStyle(Color.textSecondary)
                Text(document.summary).font(.title3)
                ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                    Text(section.heading).font(.condensed(.title3, weight: .heavy)).textCase(.uppercase).padding(.top, 10)
                    ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, p in
                        Text(p).font(.body).foregroundStyle(Color.textSecondary)
                    }
                }
                if let online {
                    Link("Open on the web", destination: online).font(.subheadline.weight(.semibold)).padding(.top, 14)
                }
            }
            .foregroundStyle(.white)
            .gutter()
            .padding(.vertical, 12)
        }
        .inkBackground()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("legal-\(document.title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

/// The two rows that open them: in You, and under the photo-access page of the first run.
struct LegalLinksRows: View {
    var body: some View {
        Group {
            NavigationLink { LegalView(document: LegalContent.privacy, online: LegalLinks.privacy) } label: { row("Privacy policy") }
                .accessibilityIdentifier("you-privacy")
            NavigationLink { LegalView(document: LegalContent.terms, online: LegalLinks.terms) } label: { row("Terms of use") }
                .accessibilityIdentifier("you-terms")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func row(_ title: String) -> some View {
        HStack {
            Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
        }
        .frame(minHeight: 56)
        .contentShape(.rect)
    }
}
