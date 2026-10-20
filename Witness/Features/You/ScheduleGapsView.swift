import SwiftUI

/// The teams someone asked Plan a game for, and which of them had no schedule. It shows where the schedule sources fall short,
/// so what to add next is decided from real searches. Everything here stays on this phone until it is shared.
struct ScheduleGapsView: View {
    @Environment(Library.self) private var library
    @State private var confirmClear = false

    private var rows: [Library.ScheduleSearch] {
        library.scheduleLog.sorted { $0.misses != $1.misses ? $0.misses > $1.misses : $0.lastSearched > $1.lastSearched }
    }

    /// The report as plain text, one team per line, for sharing.
    private var report: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        let lines = rows.map { "\($0.teamName) | \($0.league) | searched \($0.searches) | no games \($0.misses) | \($0.lastOutcome) | \(f.string(from: $0.lastSearched))" }
        return (["Witness schedule searches", "team | league | searches | misses | last | date"] + lines).joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                Text("Every team you looked up in Plan a game. Teams with no games are where the schedule sources are missing data.")
                    .font(.footnote).foregroundStyle(Color.textSecondary)
            }
            .listRowBackground(Color.clear)
            Section {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.teamName).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).lineLimit(1)
                            Text("\(row.league) \u{00B7} \(row.lastOutcome)").font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Text(row.misses > 0 ? "\(row.misses) of \(row.searches) empty" : "ok")
                            .font(.condensed(.caption, weight: .heavy)).textCase(.uppercase)
                            .foregroundStyle(row.misses > 0 ? Color.signal : Color.textSecondary)
                    }
                    .foregroundStyle(Color.primaryText)
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(Color.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Schedule gaps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: report) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share the report")
                    .accessibilityIdentifier("gaps-share")
                Button(role: .destructive) { confirmClear = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Clear the list")
            }
        }
        .confirmationDialog("Clear the list?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { library.clearScheduleLog() }
        }
    }
}
