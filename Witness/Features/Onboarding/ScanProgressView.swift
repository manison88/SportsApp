import SwiftUI

/// The scan, start to finish: photos read, then every stadium visit checked against the real schedule.
/// Real progress only. The person stays here until it is all done, and the next screen shows the matches.
struct ScanProgressView: View {
    let scan: ScanModel
    /// True when the scan is over and this is only a backdrop (nothing found).
    var finished = false

    var body: some View {
        let p = scan.progress
        let matching = scan.state == .matching || finished && scan.totalVisits > 0
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(Color.signal).frame(width: 7, height: 7)
                Text(eyebrow).unitLabel().foregroundStyle(Color.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text((matching ? scan.checkedVisits : p.scanned).formatted())
                    .displayFont(88)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("onboarding-scanning")
                Text(matching ? "of \(scan.totalVisits.formatted()) visits checked against the schedule"
                              : "of \(p.total.formatted()) photos checked")
                    .unitLabel().foregroundStyle(Color.textSecondary)
            }
            ThumbStrip(ids: p.recentIds)
            ProgressView(value: Double(matching ? scan.checkedVisits : p.scanned),
                         total: Double(max(matching ? scan.totalVisits : p.total, 1)))
                .tint(Color.signal)
            HStack(alignment: .top) {
                stat(p.atStadiums, "Near a\nstadium")
                stat(p.venues.count, "Venues\nfound")
                if matching { stat(scan.matchedCount, "Games\nmatched") } else { stat(p.visits, "Visits\nso far") }
            }
            if !p.venues.isEmpty {
                Text("Venues found so far").unitLabel().foregroundStyle(Color.textTertiary)
                VStack(spacing: 0) {
                    ForEach(Array(p.venues.reversed().prefix(4).enumerated()), id: \.element.id) { i, v in
                        VenueRow(venue: v, isNew: i == 0 && scan.state == .scanning)
                    }
                }
            }
            Spacer(minLength: 0)
            if !finished {
                Label("This can take a few minutes. Keep Witness open until it finishes and your games appear.",
                      systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.panel, in: .rect(cornerRadius: 12))
            }
        }
        .gutter()
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth, value: p.venues.count)
    }

    private var eyebrow: String {
        if finished { return "Scan finished" }
        return scan.state == .matching ? "Matching to the real schedule" : "Scanning on this iPhone"
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted()).displayFont(44).contentTransition(.numericText()).foregroundStyle(.white)
            Text(label).unitLabel().foregroundStyle(Color.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The last photos that landed inside a stadium, lit; the rest of the strip stays dim.
private struct ThumbStrip: View {
    let ids: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Color.panel
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if i < ids.count {
                            PhotoView(ref: .library(ids[i]))
                        }
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(i < ids.count ? Color.signal : Color.hairline, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct VenueRow: View {
    let venue: PhotoMatcher.VenueTally
    let isNew: Bool

    var body: some View {
        let color = venue.sport?.lineColor ?? Color.panelRaised
        HStack(spacing: 12) {
            Text(String(venue.name.filter(\.isLetter).prefix(3)).uppercased())
                .font(.condensed(.caption, weight: .heavy))
                .foregroundStyle(color.readableInk)
                .frame(width: 44, height: 44)
                .background(color, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(venue.name).font(.condensed(.headline, weight: .heavy)).textCase(.uppercase).lineLimit(1)
                    if isNew {
                        Text("New").font(.condensed(.caption2, weight: .heavy)).textCase(.uppercase)
                            .foregroundStyle(Color.signal)
                    }
                }
                if let sport = venue.sport { Text(sport.name).font(.footnote).foregroundStyle(Color.textSecondary) }
            }
            Spacer()
            Text(venue.count.formatted()).font(.condensed(.title3, weight: .heavy)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(minHeight: 56)
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}
