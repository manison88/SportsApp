import SwiftUI

/// Picks a day and shows what the photo scan makes of it (see `ScanCheck`), to share when a game was not found.
/// Reached by tapping the note at the top of Back up & export three times.
struct ScanCheckView: View {
    @Environment(Library.self) private var library
    @State private var day = Date()
    @State private var report: String?
    @State private var checking = false

    var body: some View {
        List {
            Section {
                Text("Pick the day of a game the scan missed. This lists where each photo was placed, the visits that makes, what is already saved that day and what the schedules say. Share it to report the problem.")
                    .font(.footnote).foregroundStyle(Color.textSecondary)
            }
            .listRowBackground(Color.clear)
            Section {
                DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
                    .tint(Color.signal)
                    .foregroundStyle(.white)
                Button {
                    Task {
                        checking = true
                        report = await ScanCheck.report(day: day, library: library)
                        checking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Check this day").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                        if checking { ProgressView().tint(.white) }
                    }
                }
                .disabled(checking)
                .accessibilityIdentifier("scan-check-run")
            }
            .listRowBackground(Color.panel)
            if let report {
                Section {
                    Text(report)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
                .listRowBackground(Color.panel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Scan check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let report {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: report) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share the report")
                }
            }
        }
    }
}
