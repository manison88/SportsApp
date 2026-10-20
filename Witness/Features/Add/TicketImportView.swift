import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Turns a ticket from any seller into a game: a screenshot, a PDF, or the
/// confirmation email's text. Read on this iPhone with Vision.
struct TicketImportView: View {
    @Environment(Library.self) private var library
    @Environment(Presenter.self) private var presenter
    @Environment(\.dismiss) private var dismiss

    @State private var path: [TicketDraft] = []
    @State private var shotItem: PhotosPickerItem?
    @State private var showPDF = false
    @State private var pasted = ""
    @State private var working = false
    @State private var failed = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    PhotosPicker(selection: $shotItem, matching: .images) {
                        bigRow("Screenshot", systemImage: "photo")
                    }
                    .accessibilityIdentifier("ticket-screenshot")

                    Button {
                        showPDF = true
                    } label: {
                        bigRow("PDF", systemImage: "doc.richtext")
                    }
                    .accessibilityIdentifier("ticket-pdf")
                }
                .listRowBackground(Color.panel)

                Section {
                    bigRow("Paste confirmation", systemImage: "doc.on.clipboard", chevron: false)
                    TextEditor(text: $pasted)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .font(.callout)
                        .accessibilityLabel("Confirmation text")
                        .accessibilityIdentifier("ticket-paste")
                    Button {
                        Task { await read(pasted) }
                    } label: {
                        Text("Read ticket")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
                    .accessibilityIdentifier("ticket-parse")
                }
                .listRowBackground(Color.panel)

                Text("Works with Ticketmaster, StubHub, SeatGeek, AXS and team apps. Read on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("Import ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityIdentifier("ticket-cancel")
                }
            }
            .navigationDestination(for: TicketDraft.self) { draft in
                AddGameView(draft: draft, embedded: true, onDone: close)
            }
            .overlay {
                if working {
                    ProgressView()
                        .controlSize(.large)
                        .padding(28)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
            }
            .fileImporter(isPresented: $showPDF, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    Task { await readPDF(url) }
                }
            }
            .onChange(of: shotItem) { _, item in
                guard let item else { return }
                Task { await readScreenshot(item) }
            }
            .alert("Couldn't read that ticket", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a clearer screenshot, or add the game by hand.")
            }
        }
    }

    private func bigRow(_ title: String, systemImage: String, chevron: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.condensed(.title3, weight: .heavy))
                .textCase(.uppercase)
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(Color.primaryText)
        .frame(minHeight: 52)
        .contentShape(.rect)
    }

    private func readScreenshot(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false; shotItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let text = try? await TextRecognizer.text(in: image) else {
            failed = true
            return
        }
        await read(text)
    }

    private func readPDF(_ url: URL) async {
        working = true
        defer { working = false }
        guard let text = try? await TextRecognizer.text(inPDF: url) else {
            failed = true
            return
        }
        await read(text)
    }

    private func read(_ text: String) async {
        let draft = TicketParser.parse(text, teams: library.allTeams, venues: library.venues)
        if draft.date == nil, draft.homeTeamId == nil, draft.awayTeamId == nil, draft.venueId == nil {
            failed = true
            return
        }
        path.append(draft)
    }

    private func close() {
        presenter.modal = nil
        dismiss()
    }
}
