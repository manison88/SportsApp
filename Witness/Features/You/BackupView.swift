import SwiftUI
import UniformTypeIdentifiers

/// Keeps the fan's record safe: a backup file to save anywhere, a spreadsheet of every game, and a way to put a backup back.
/// Photos are not copied: they stay in the Photos library, and a restored game finds its photos again only on a phone that has them.
struct BackupView: View {
    @Environment(Library.self) private var library
    @State private var importing = false
    @State private var message: String?
    @State private var backup: URL?
    @State private var sheet: URL?

    var body: some View {
        List {
            Section {
                Text("Your games live on this phone. A backup file keeps them safe if you change or lose it. Photos stay in your Photos library and are not copied.")
                    .font(.footnote).foregroundStyle(Color.textSecondary)
            }
            .listRowBackground(Color.clear)
            // The scan check, for tracing a game the photo scan missed.
            Section {
                NavigationLink { ScanCheckView() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan check").font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                        Text("Why a day\u{2019}s photos did or did not find a game").font(.footnote).foregroundStyle(Color.textSecondary)
                    }
                    .foregroundStyle(Color.primaryText)
                    .frame(minHeight: 56)
                }
                .accessibilityIdentifier("backup-scan-check")
            }
            .listRowBackground(Color.panel)
            Section {
                if let backup {
                    ShareLink(item: backup) { row("Save a backup", "\(library.games.count) games, plans, places and people", "square.and.arrow.up") }
                        .accessibilityIdentifier("backup-share")
                }
                if let sheet {
                    ShareLink(item: sheet) { row("Export games as a spreadsheet", "One row per game, opens in Numbers or Excel", "tablecells") }
                        .accessibilityIdentifier("backup-csv")
                }
                Button { importing = true } label: { row("Restore a backup", "Adds what is in the file; nothing here is replaced", "arrow.down.doc") }
                    .accessibilityIdentifier("backup-restore")
            }
            .listRowBackground(Color.panel)
            if let message {
                Section { Text(message).font(.subheadline).foregroundStyle(Color.signal) }
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Back up & export")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prepare)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let added = try library.restore(from: url)
                    message = added == 0 ? "Everything in that backup was already here." : "Added \(added) game\(added == 1 ? "" : "s") from the backup."
                    prepare()
                } catch {
                    message = "That file isn\u{2019}t a Witness backup."
                }
            case .failure:
                message = "Couldn\u{2019}t open that file."
            }
        }
    }

    private func prepare() {
        backup = try? library.backupFile()
        sheet = try? library.csvFile()
    }

    private func row(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color.signal).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase)
                Text(detail).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.textTertiary).accessibilityHidden(true)
        }
        .foregroundStyle(Color.primaryText)
        .frame(minHeight: 56)
        .contentShape(.rect)
    }
}
