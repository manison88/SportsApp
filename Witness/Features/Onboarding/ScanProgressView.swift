import SwiftUI

/// Walks the display through the scan one step at a time, so a person can follow it even when the work is instant.
/// Each step holds for a minimum time and its numbers count up to the real values (they never run ahead of them).
@Observable
@MainActor
final class ScanPacing {
    enum Step: Int, CaseIterable {
        case reading, stadiums, matching, verifying, building

        var title: String {
            switch self {
            case .reading: "Reading dates and places"
            case .stadiums: "Finding stadiums"
            case .matching: "Matching to the real schedule"
            case .verifying: "Checking the photos look like a game"
            case .building: "Building your timeline"
            }
        }
    }

    private(set) var step: Step = .reading
    private(set) var photos = 0
    private(set) var near = 0
    private(set) var venues = 0
    private(set) var checked = 0
    private(set) var matched = 0
    private(set) var verified = 0
    private(set) var found = 0
    /// How many of the stadiums found are listed so far; they appear one at a time.
    private(set) var venuesRevealed = 0
    private var stageStart = Date()
    private var lastReveal = Date.distantPast

    /// Moves a displayed number toward the real one: quick at first, never past it, and never slower than ~3 seconds.
    nonisolated static func approach(_ shown: Int, _ target: Int) -> Int {
        guard shown < target else { return target }
        let delta = target - shown
        let step = max(Int((Double(delta) * 0.08).rounded(.up)), Int((Double(target) / 80).rounded(.up)), 1)
        return min(target, shown + step)
    }

    /// The finished picture, for a screen that only wants to show where the scan ended.
    func snapshot(_ scan: ScanModel) {
        step = .building
        photos = scan.progress.total; near = scan.progress.atStadiums; venues = scan.progress.venues.count
        checked = scan.totalVisits; matched = scan.matchedCount; verified = scan.verifyTotal; found = scan.games.count
        venuesRevealed = scan.progress.venues.count
    }

    func run(_ scan: ScanModel) async {
        stageStart = .now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(40))
            let t = Date().timeIntervalSince(stageStart)
            let p = scan.progress
            switch step {
            case .reading:
                photos = Self.approach(photos, p.scanned)
                let over = scan.state != .scanning && scan.state != .idle
                if over && photos >= p.total && t >= 2.2 { advance(.stadiums) }
            case .stadiums:
                near = Self.approach(near, p.atStadiums)
                venues = Self.approach(venues, p.venues.count)
                reveal(p.venues.count)
                if t >= 1.8 && venuesRevealed >= p.venues.count && near >= p.atStadiums { advance(.matching) }
            case .matching:
                checked = Self.approach(checked, scan.checkedVisits)
                matched = Self.approach(matched, scan.matchedCount)
                let over = scan.state != .scanning && scan.state != .matching && scan.state != .idle
                if over && checked >= scan.totalVisits && matched >= scan.matchedCount && t >= 2.2 { advance(.verifying) }
            case .verifying:
                verified = Self.approach(verified, scan.verifiedVisits)
                let over = scan.state == .done || scan.state == .empty
                if over && verified >= scan.verifyTotal && t >= 1.8 { advance(.building) }
            case .building:
                found = Self.approach(found, scan.games.count)
                if t >= 1.4 && found >= scan.games.count {
                    if scan.state == .done { scan.markShown() }
                    return
                }
            }
        }
    }

    private func advance(_ next: Step) {
        step = next
        stageStart = .now
    }

    /// One stadium at a time, quickly enough that a long list still finishes in about four seconds.
    private func reveal(_ count: Int) {
        guard venuesRevealed < count else { return }
        let gap = max(0.12, min(0.4, 4.0 / Double(max(count, 1))))
        if Date().timeIntervalSince(lastReveal) >= gap {
            venuesRevealed += 1
            lastReveal = .now
        }
    }

    /// 0...1 across all four steps.
    func fraction(_ scan: ScanModel) -> Double {
        let p = scan.progress
        let within: Double
        switch step {
        case .reading: within = Double(photos) / Double(max(p.total, 1))
        case .stadiums: within = Double(venuesRevealed) / Double(max(p.venues.count, 1))
        case .matching: within = Double(checked) / Double(max(scan.totalVisits, 1))
        case .verifying: within = Double(verified) / Double(max(scan.verifyTotal, 1))
        case .building: within = Double(found) / Double(max(scan.games.count, 1))
        }
        return (Double(step.rawValue) + min(max(within, 0), 1)) / Double(Step.allCases.count)
    }
}

/// The scan, start to finish: photos read, stadiums found, every visit checked against the real schedule, the timeline
/// built. Real numbers only, shown at a pace a person can follow. The next screen shows the matches.
struct ScanProgressView: View {
    let scan: ScanModel
    /// True when the scan is over and this is only a backdrop (nothing found).
    var finished = false

    @State private var pace = ScanPacing()

    var body: some View {
        let p = scan.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle().fill(Color.signal).frame(width: 7, height: 7)
                    Text(finished ? "Scan finished" : "Scanning on this iPhone").unitLabel().foregroundStyle(Color.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bigNumber.formatted())
                        .displayFont(80)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("onboarding-scanning")
                    Text(caption).unitLabel().foregroundStyle(Color.textSecondary)
                }
                ThumbStrip(ids: p.recentIds)
                ProgressView(value: finished ? 1 : pace.fraction(scan)).tint(Color.signal)
                    .animation(.smooth, value: pace.fraction(scan))

                VStack(spacing: 0) {
                    ForEach(ScanPacing.Step.allCases, id: \.self) { step in
                        stepRow(step)
                    }
                }

                if pace.venuesRevealed > 0 {
                    Text("Venues found").unitLabel().foregroundStyle(Color.textTertiary).padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(p.venues.prefix(pace.venuesRevealed).reversed().prefix(3).enumerated()), id: \.element.id) { i, v in
                            VenueRow(venue: v, isNew: i == 0 && pace.step == .stadiums)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.smooth, value: pace.venuesRevealed)
                }

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
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .animation(.smooth, value: pace.step)
        .task {
            if finished { pace.snapshot(scan) } else { await pace.run(scan) }
        }
    }

    private var bigNumber: Int {
        switch pace.step {
        case .reading: pace.photos
        case .stadiums: pace.near
        case .matching: pace.matched
        case .verifying: pace.verified
        case .building: pace.found
        }
    }

    private var caption: String {
        let p = scan.progress
        switch pace.step {
        case .reading: return "of \(p.total.formatted()) photos read"
        case .stadiums: return "photos taken at a stadium \u{00B7} \(pace.venues) venues"
        case .matching: return "games matched \u{00B7} \(pace.checked) of \(scan.totalVisits) visits checked"
        case .verifying: return "of \(scan.verifyTotal) visits looked at"
        case .building: return "games found"
        }
    }

    private func stepRow(_ step: ScanPacing.Step) -> some View {
        let state: StepState = finished || step.rawValue < pace.step.rawValue ? .done : (step == pace.step ? .active : .pending)
        return HStack(spacing: 12) {
            Group {
                switch state {
                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.signal)
                case .active: ProgressView().controlSize(.small).tint(Color.signal)
                case .pending: Image(systemName: "circle").foregroundStyle(Color.textTertiary)
                }
            }
            .frame(width: 22, height: 22)
            Text(step.title)
                .font(.condensed(.headline, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(state == .pending ? Color.textTertiary : .white)
            Spacer()
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title), \(state == .done ? "done" : state == .active ? "in progress" : "waiting")")
    }

    private enum StepState { case pending, active, done }
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
