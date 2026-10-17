import SwiftUI

/// Generative stand-in for a fan's photo: stadium lights, crowds, scoreboards,
/// weather. Deterministic per seed, tinted by the game's team colors, with no
/// people's faces and no marks. Swapped for PhotoKit images later.
struct StadiumPhoto: View {
    let style: PhotoStyle
    let seed: UInt64
    var accent: Color = Palette.signal
    var secondary: Color = Palette.signalSoft
    var sport: Sport? = nil
    /// Lines shown on a scoreboard, e.g. ["CLE 2", "CHC 3"].
    var board: [String] = []
    var grain: Double = 0.10

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let painter = PhotoPainter(ctx: ctx, size: size, accent: accent, secondary: secondary,
                                       sport: sport, board: board)
            painter.paint(style, rng: &rng)
        }
        .overlay { GrainOverlay(intensity: grain) }
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Photo")
    }
}

extension StadiumPhoto {
    /// Placeholder for a PhotoKit asset from a game: tinted by the fan's team,
    /// and any scoreboard shows the score at the moment it was taken.
    init(photo: PhotoAsset, game: Game, store: MockStore = .shared, grain: Double = 0.10) {
        let pair = store.pair(for: game)
        let fan = store.perspectiveTeam(for: game)
        let other = fan?.id == pair?.home.id ? pair?.away : pair?.home
        var lines: [String] = []
        if let pair {
            let last = game.events.last { $0.timestamp <= photo.creationDate }
            lines = ["\(pair.away.abbreviation)  \(last?.awayScore ?? 0)",
                     "\(pair.home.abbreviation)  \(last?.homeScore ?? 0)"]
        } else if let race = game.race {
            lines = race.results.prefix(3).map { "P\($0.position) \($0.driverCode)" }
        }
        self.init(style: photo.placeholder.style, seed: photo.placeholder.seed,
                  accent: fan?.accentColor ?? Palette.signal,
                  secondary: other?.accentColor ?? Palette.signalSoft,
                  sport: game.sport, board: lines, grain: grain)
    }
}

// MARK: - Painter

private struct PhotoPainter {
    let ctx: GraphicsContext
    let size: CGSize
    let accent: Color
    let secondary: Color
    let sport: Sport?
    let board: [String]

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var bounds: CGRect { CGRect(origin: .zero, size: size) }

    func paint(_ style: PhotoStyle, rng: inout SeededRandom) {
        switch style {
        case .diamond:
            nightSky(horizon: 0.44)
            lightBank(at: CGPoint(x: w * rng.cg(0.08...0.25), y: h * rng.cg(0.08...0.16)), scale: 0.7, rng: &rng)
            lightBank(at: CGPoint(x: w * rng.cg(0.72...0.92), y: h * rng.cg(0.06...0.14)), scale: 0.8, rng: &rng)
            stands(top: 0.36, bottom: 0.56, rng: &rng)
            field(top: 0.54, markings: .baseball, palette: .night)
        case .nightField:
            nightSky(horizon: 0.42)
            lightBank(at: CGPoint(x: w * 0.18, y: h * 0.10), scale: 0.75, rng: &rng)
            lightBank(at: CGPoint(x: w * 0.82, y: h * 0.08), scale: 0.85, rng: &rng)
            stands(top: 0.34, bottom: 0.55, rng: &rng)
            field(top: 0.53, markings: sport == .baseball ? .baseball : .football, palette: .night)
        case .pitch:
            nightSky(horizon: 0.40)
            roofEdge(y: 0.16)
            lightBank(at: CGPoint(x: w * 0.12, y: h * 0.14), scale: 0.55, rng: &rng)
            lightBank(at: CGPoint(x: w * 0.88, y: h * 0.14), scale: 0.55, rng: &rng)
            stands(top: 0.18, bottom: 0.55, rng: &rng)
            field(top: 0.53, markings: .soccer, palette: .night)
        case .dayGame:
            daySky(horizon: 0.36)
            stands(top: 0.30, bottom: 0.52, rng: &rng, day: true)
            field(top: 0.50, markings: sport == .baseball || sport == nil ? .baseball : .football, palette: .day)
            shadowSweep()
        case .snowGame:
            overcastSky(horizon: 0.40)
            lightBank(at: CGPoint(x: w * 0.2, y: h * 0.1), scale: 0.6, rng: &rng, dim: true)
            lightBank(at: CGPoint(x: w * 0.85, y: h * 0.12), scale: 0.6, rng: &rng, dim: true)
            stands(top: 0.32, bottom: 0.56, rng: &rng, day: true)
            field(top: 0.54, markings: .football, palette: .snow)
            snow(rng: &rng)
        case .lightTower:
            nightSky(horizon: 0.95)
            tower(rng: &rng)
        case .crowd:
            crowd(rng: &rng, confetti: false)
        case .celebration:
            crowd(rng: &rng, confetti: true)
        case .scoreboard:
            scoreboard(rng: &rng)
        case .concourse:
            concourse(rng: &rng)
        case .arena:
            arena(rng: &rng)
        case .skyline:
            skyline(rng: &rng)
        case .trackside:
            trackside(rng: &rng)
        }
        vignette()
    }

    // MARK: Primitives

    func fill(_ rect: CGRect, _ colors: [Color], from: CGPoint, to: CGPoint) {
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: colors), startPoint: from, endPoint: to))
    }

    func glow(_ p: CGPoint, radius r: CGFloat, color: Color, intensity: Double) {
        var c = ctx
        c.blendMode = .screen
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        let g = Gradient(stops: [
            .init(color: color.opacity(intensity), location: 0),
            .init(color: color.opacity(intensity * 0.32), location: 0.35),
            .init(color: color.opacity(0), location: 1),
        ])
        c.fill(Path(ellipseIn: rect), with: .radialGradient(g, center: p, startRadius: 0, endRadius: r))
    }

    func vignette() {
        let g = Gradient(stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.6), location: 1)])
        ctx.fill(Path(bounds), with: .radialGradient(g, center: CGPoint(x: w / 2, y: h * 0.45),
                                                     startRadius: 0, endRadius: max(w, h) * 0.8))
    }

    // MARK: Skies

    func nightSky(horizon: CGFloat) {
        fill(bounds, [Color(hex: "020306"), Color(hex: "070B16"), Color(hex: "121A2E")],
             from: .zero, to: CGPoint(x: 0, y: h * horizon))
        glow(CGPoint(x: w * 0.5, y: h * horizon), radius: w * 0.9, color: Color(hex: "FFE2B0"), intensity: 0.16)
        glow(CGPoint(x: w * 0.3, y: h * horizon * 0.8), radius: w * 0.5, color: accent, intensity: 0.10)
    }

    func daySky(horizon: CGFloat) {
        fill(bounds, [Color(hex: "2E6FC2"), Color(hex: "79AEE6"), Color(hex: "D8E8F5")],
             from: .zero, to: CGPoint(x: 0, y: h * horizon))
        glow(CGPoint(x: w * 0.85, y: h * 0.02), radius: w * 0.7, color: Color(hex: "FFF6E0"), intensity: 0.75)
    }

    func overcastSky(horizon: CGFloat) {
        fill(bounds, [Color(hex: "4B535E"), Color(hex: "7F8893"), Color(hex: "A9B0B8")],
             from: .zero, to: CGPoint(x: 0, y: h * horizon))
    }

    // MARK: Lights

    func lightBank(at p: CGPoint, scale s: CGFloat, rng: inout SeededRandom, dim: Bool = false) {
        let k = dim ? 0.55 : 1.0
        glow(p, radius: w * 0.75 * s, color: Color(hex: "FFE9C4"), intensity: 0.30 * k)
        glow(p, radius: w * 0.22 * s, color: .white, intensity: 0.75 * k)
        // horizontal anamorphic flare
        var c = ctx
        c.blendMode = .screen
        let flare = CGRect(x: p.x - w * 0.6 * s, y: p.y - 1.2 * s, width: w * 1.2 * s, height: 2.4 * s)
        c.fill(Path(ellipseIn: flare), with: .color(Color(hex: "BFD8FF").opacity(0.35 * k)))
        // lamp grid
        let cols = 6, rows = 3
        let lamp = max(2.5, w * 0.018 * s)
        let gap = lamp * 0.55
        let gridW = CGFloat(cols) * (lamp + gap)
        let gridH = CGFloat(rows) * (lamp + gap)
        var lamps = Path()
        for r in 0..<rows {
            for col in 0..<cols {
                let x = p.x - gridW / 2 + CGFloat(col) * (lamp + gap)
                let y = p.y - gridH / 2 + CGFloat(r) * (lamp + gap)
                lamps.addRoundedRect(in: CGRect(x: x, y: y, width: lamp, height: lamp), cornerSize: CGSize(width: 1, height: 1))
            }
        }
        c.fill(lamps, with: .color(.white.opacity(0.95 * k)))
        // insects drifting through the beam
        var bugs = Path()
        for _ in 0..<Int(18 * s) {
            let bx = p.x + rng.cg(-w * 0.25...w * 0.25) * s
            let by = p.y + rng.cg(-h * 0.02...h * 0.18) * s
            bugs.addEllipse(in: CGRect(x: bx, y: by, width: 1.4, height: 1.4))
        }
        c.fill(bugs, with: .color(.white.opacity(0.5 * k)))
    }

    func roofEdge(y: CGFloat) {
        var roof = Path()
        roof.move(to: CGPoint(x: 0, y: h * (y - 0.06)))
        roof.addQuadCurve(to: CGPoint(x: w, y: h * (y - 0.06)), control: CGPoint(x: w / 2, y: h * (y + 0.05)))
        roof.addLine(to: CGPoint(x: w, y: 0))
        roof.addLine(to: .zero)
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(hex: "040406")))
        var rim = Path()
        rim.move(to: CGPoint(x: 0, y: h * (y - 0.06)))
        rim.addQuadCurve(to: CGPoint(x: w, y: h * (y - 0.06)), control: CGPoint(x: w / 2, y: h * (y + 0.05)))
        var c = ctx
        c.blendMode = .screen
        c.stroke(rim, with: .color(accent.opacity(0.7)), lineWidth: 2)
        c.addFilter(.blur(radius: 4))
        c.stroke(rim, with: .color(accent.opacity(0.5)), lineWidth: 6)
    }

    // MARK: Stands

    func stands(top: CGFloat, bottom: CGFloat, rng: inout SeededRandom, day: Bool = false) {
        let rect = CGRect(x: 0, y: h * top, width: w, height: h * (bottom - top))
        let shade = day ? [Color(hex: "2A2E36"), Color(hex: "1A1C21")] : [Color(hex: "0C0C12"), Color(hex: "07070A")]
        fill(rect, shade, from: CGPoint(x: 0, y: rect.minY), to: CGPoint(x: 0, y: rect.maxY))

        // crowd texture, batched into a few paths per color
        let palette: [Color] = day
            ? [accent.opacity(0.55), .white.opacity(0.35), secondary.opacity(0.4), Color(hex: "C9B79C").opacity(0.35)]
            : [accent.opacity(0.32), .white.opacity(0.10), secondary.opacity(0.22), Color(hex: "8A7F70").opacity(0.18)]
        var paths = Array(repeating: Path(), count: palette.count)
        let count = Int(rect.width * rect.height / 14)
        for _ in 0..<count {
            let x = rng.cg(0...w)
            let y = rng.cg(rect.minY...rect.maxY)
            let d = rng.cg(1.2...2.4)
            paths[Int(rng.next() % UInt64(palette.count))].addEllipse(in: CGRect(x: x, y: y, width: d, height: d))
        }
        for (path, color) in zip(paths, palette) { ctx.fill(path, with: .color(color)) }

        // upper-deck fascia ribbon board
        let ribbonY = rect.minY + rect.height * 0.34
        let ribbon = CGRect(x: 0, y: ribbonY, width: w, height: max(2, h * 0.006))
        var c = ctx
        c.blendMode = .screen
        c.fill(Path(ribbon), with: .linearGradient(Gradient(colors: [accent.opacity(0.9), secondary.opacity(0.8), accent.opacity(0.9)]),
                                                     startPoint: CGPoint(x: 0, y: ribbonY), endPoint: CGPoint(x: w, y: ribbonY)))
        glow(CGPoint(x: w * 0.5, y: ribbonY), radius: w * 0.5, color: accent, intensity: day ? 0.08 : 0.16)

        // phone flashes
        if !day {
            for _ in 0..<10 {
                let p = CGPoint(x: rng.cg(0...w), y: rng.cg(rect.minY...rect.maxY))
                glow(p, radius: 6, color: .white, intensity: 0.9)
            }
        }
        // field-level wall
        fill(CGRect(x: 0, y: rect.maxY - h * 0.02, width: w, height: h * 0.02),
             [Color(hex: "0B2A1B"), Color(hex: "06150D")], from: CGPoint(x: 0, y: rect.maxY - h * 0.02), to: CGPoint(x: 0, y: rect.maxY))
    }

    // MARK: Field

    enum Markings { case baseball, football, soccer }
    enum FieldPalette { case night, day, snow }

    func field(top: CGFloat, markings: Markings, palette: FieldPalette) {
        let y0 = h * top
        let rect = CGRect(x: 0, y: y0, width: w, height: h - y0)
        let greens: [Color]
        switch palette {
        case .night: greens = [Color(hex: "3C9A55"), Color(hex: "1D6A34"), Color(hex: "0C3A1C")]
        case .day: greens = [Color(hex: "5DB566"), Color(hex: "3A8C45"), Color(hex: "246B30")]
        case .snow: greens = [Color(hex: "E3E8EA"), Color(hex: "C7D2CF"), Color(hex: "93A39C")]
        }
        fill(rect, greens, from: CGPoint(x: 0, y: y0), to: CGPoint(x: 0, y: h))

        // mowing stripes, converging toward a vanishing point
        let n = 12
        for i in stride(from: 0, to: n, by: 2) {
            let t0 = CGFloat(i) / CGFloat(n) - 0.5
            let t1 = CGFloat(i + 1) / CGFloat(n) - 0.5
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5 + t0 * w * 1.1, y: y0))
            p.addLine(to: CGPoint(x: w * 0.5 + t1 * w * 1.1, y: y0))
            p.addLine(to: CGPoint(x: w * 0.5 + t1 * w * 3.2, y: h))
            p.addLine(to: CGPoint(x: w * 0.5 + t0 * w * 3.2, y: h))
            p.closeSubpath()
            ctx.fill(p, with: .color(.white.opacity(palette == .snow ? 0.06 : 0.045)))
        }

        let line = Color.white.opacity(palette == .snow ? 0.35 : 0.55)
        let fh = h - y0
        switch markings {
        case .baseball:
            let home = CGPoint(x: w * 0.5, y: h + fh * 0.05)
            let first = CGPoint(x: w * 0.86, y: y0 + fh * 0.55)
            let second = CGPoint(x: w * 0.5, y: y0 + fh * 0.28)
            let third = CGPoint(x: w * 0.14, y: y0 + fh * 0.55)
            var dirt = Path()
            dirt.addEllipse(in: CGRect(x: w * 0.02, y: y0 + fh * 0.18, width: w * 0.96, height: fh * 1.1))
            ctx.fill(dirt, with: .color(Color(hex: palette == .day ? "B07A50" : "7A4E33")))
            var grass = Path()
            let inset: CGFloat = 0.82
            let c = CGPoint(x: w * 0.5, y: (home.y + second.y) / 2)
            func shrink(_ p: CGPoint) -> CGPoint { CGPoint(x: c.x + (p.x - c.x) * inset, y: c.y + (p.y - c.y) * inset) }
            grass.move(to: shrink(home)); grass.addLine(to: shrink(first)); grass.addLine(to: shrink(second))
            grass.addLine(to: shrink(third)); grass.closeSubpath()
            ctx.fill(grass, with: .linearGradient(Gradient(colors: [greens[0], greens[1]]),
                                                  startPoint: CGPoint(x: 0, y: second.y), endPoint: CGPoint(x: 0, y: home.y)))
            let mound = CGRect(x: c.x - w * 0.05, y: c.y - fh * 0.03, width: w * 0.1, height: fh * 0.06)
            ctx.fill(Path(ellipseIn: mound), with: .color(Color(hex: palette == .day ? "B98458" : "84573A")))
            var chalk = Path()
            chalk.move(to: home); chalk.addLine(to: CGPoint(x: w * 1.3, y: y0 + fh * 0.1))
            chalk.move(to: home); chalk.addLine(to: CGPoint(x: -w * 0.3, y: y0 + fh * 0.1))
            ctx.stroke(chalk, with: .color(line), lineWidth: 1.4)
            for base in [first, second, third] {
                ctx.fill(Path(CGRect(x: base.x - 3, y: base.y - 2, width: 6, height: 4)), with: .color(.white.opacity(0.9)))
            }
        case .football:
            var lines = Path()
            for i in 0..<9 {
                let t = CGFloat(i) / 8
                let y = y0 + fh * pow(t, 1.6)
                lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: w, y: y))
            }
            ctx.stroke(lines, with: .color(line.opacity(0.7)), lineWidth: 1.2)
            var hashes = Path()
            for i in 0..<30 {
                let t = CGFloat(i) / 29
                let y = y0 + fh * pow(t, 1.6)
                for x in [w * 0.38 - t * w * 0.2, w * 0.62 + t * w * 0.2] {
                    hashes.move(to: CGPoint(x: x - 3, y: y)); hashes.addLine(to: CGPoint(x: x + 3, y: y))
                }
            }
            ctx.stroke(hashes, with: .color(line.opacity(0.5)), lineWidth: 1)
        case .soccer:
            var m = Path()
            let mid = y0 + fh * 0.42
            m.move(to: CGPoint(x: 0, y: mid)); m.addLine(to: CGPoint(x: w, y: mid))
            m.addEllipse(in: CGRect(x: w * 0.28, y: mid - fh * 0.12, width: w * 0.44, height: fh * 0.24))
            ctx.stroke(m, with: .color(line), lineWidth: 1.4)
        }
        // light falls off toward the camera
        fill(rect, [.clear, .black.opacity(0.45)], from: CGPoint(x: 0, y: y0 + fh * 0.3), to: CGPoint(x: 0, y: h))
    }

    func shadowSweep() {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.1, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        ctx.fill(p, with: .color(.black.opacity(0.22)))
    }

    // MARK: Weather

    func snow(rng: inout SeededRandom) {
        var flakes = Path()
        for _ in 0..<Int(w * h / 600) {
            let d = rng.cg(1...3.4)
            flakes.addEllipse(in: CGRect(x: rng.cg(0...w), y: rng.cg(0...h), width: d, height: d))
        }
        ctx.fill(flakes, with: .color(.white.opacity(0.75)))
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3.5))
            var big = Path()
            for _ in 0..<26 {
                let d = rng.cg(7...16)
                big.addEllipse(in: CGRect(x: rng.cg(0...w), y: rng.cg(0...h), width: d, height: d))
            }
            layer.fill(big, with: .color(.white.opacity(0.45)))
        }
    }

    // MARK: Scenes

    func tower(rng: inout SeededRandom) {
        let bank = CGPoint(x: w * 0.64, y: h * 0.26)
        // light rays falling toward the field
        var c = ctx
        c.blendMode = .screen
        for i in 0..<7 {
            let spread = CGFloat(i - 3) * w * 0.16
            var ray = Path()
            ray.move(to: bank)
            ray.addLine(to: CGPoint(x: bank.x - w * 0.5 + spread - w * 0.04, y: h * 1.05))
            ray.addLine(to: CGPoint(x: bank.x - w * 0.5 + spread + w * 0.04, y: h * 1.05))
            ray.closeSubpath()
            c.fill(ray, with: .linearGradient(Gradient(colors: [Color(hex: "FFF3DA").opacity(0.10), .clear]),
                                              startPoint: bank, endPoint: CGPoint(x: bank.x, y: h)))
        }
        // lattice silhouette
        var lattice = Path()
        let baseL = CGPoint(x: w * 0.58, y: h * 1.02)
        let baseR = CGPoint(x: w * 0.74, y: h * 1.02)
        let topL = CGPoint(x: w * 0.61, y: h * 0.34)
        let topR = CGPoint(x: w * 0.67, y: h * 0.34)
        lattice.move(to: baseL); lattice.addLine(to: topL)
        lattice.move(to: baseR); lattice.addLine(to: topR)
        for i in 0..<9 {
            let t0 = CGFloat(i) / 9, t1 = CGFloat(i + 1) / 9
            let l0 = CGPoint(x: baseL.x + (topL.x - baseL.x) * t0, y: baseL.y + (topL.y - baseL.y) * t0)
            let r1 = CGPoint(x: baseR.x + (topR.x - baseR.x) * t1, y: baseR.y + (topR.y - baseR.y) * t1)
            let l1 = CGPoint(x: baseL.x + (topL.x - baseL.x) * t1, y: baseL.y + (topL.y - baseL.y) * t1)
            lattice.move(to: l0); lattice.addLine(to: r1)
            lattice.move(to: l1); lattice.addLine(to: CGPoint(x: baseR.x + (topR.x - baseR.x) * t1, y: r1.y))
        }
        ctx.stroke(lattice, with: .color(Color(hex: "0A0A0E")), lineWidth: 2.2)
        // frame of the bank
        let frame = CGRect(x: bank.x - w * 0.2, y: bank.y - h * 0.08, width: w * 0.4, height: h * 0.14)
        ctx.fill(Path(roundedRect: frame, cornerRadius: 3), with: .color(Color(hex: "08080B")))
        glow(bank, radius: w * 1.1, color: Color(hex: "FFE5BA"), intensity: 0.35)
        glow(bank, radius: w * 0.42, color: .white, intensity: 0.55)
        var lamps = Path()
        let cols = 7, rows = 4
        let lw = frame.width / CGFloat(cols), lh = frame.height / CGFloat(rows)
        for r in 0..<rows {
            for col in 0..<cols {
                let cell = CGRect(x: frame.minX + CGFloat(col) * lw, y: frame.minY + CGFloat(r) * lh, width: lw, height: lh)
                lamps.addEllipse(in: cell.insetBy(dx: lw * 0.14, dy: lh * 0.14))
            }
        }
        ctx.fill(lamps, with: .color(Color(hex: "FFFDF6")))
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.blendMode = .screen
            layer.fill(lamps, with: .color(Color(hex: "FFF1D0").opacity(0.9)))
        }
        // starburst
        var star = Path()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 6 + 0.2
            star.move(to: CGPoint(x: bank.x - cos(a) * w * 0.55, y: bank.y - sin(a) * w * 0.55))
            star.addLine(to: CGPoint(x: bank.x + cos(a) * w * 0.55, y: bank.y + sin(a) * w * 0.55))
        }
        c.stroke(star, with: .color(.white.opacity(0.16)), lineWidth: 1)
        // moths
        var bugs = Path()
        for _ in 0..<60 {
            let p = CGPoint(x: bank.x + rng.cg(-w * 0.4...w * 0.3), y: bank.y + rng.cg(-h * 0.1...h * 0.35))
            bugs.addEllipse(in: CGRect(x: p.x, y: p.y, width: 1.6, height: 1.6))
        }
        c.fill(bugs, with: .color(.white.opacity(0.55)))
        // roofline in the corner
        var roof = Path()
        roof.move(to: CGPoint(x: 0, y: h * 0.78))
        roof.addLine(to: CGPoint(x: w * 0.42, y: h * 0.86))
        roof.addLine(to: CGPoint(x: w * 0.42, y: h))
        roof.addLine(to: CGPoint(x: 0, y: h))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(hex: "030304")))
        glow(CGPoint(x: w * 0.2, y: h * 0.82), radius: w * 0.3, color: accent, intensity: 0.12)
    }

    func crowd(rng: inout SeededRandom, confetti: Bool) {
        fill(bounds, [Color(hex: "0A0B10"), Color(hex: "050506")], from: .zero, to: CGPoint(x: 0, y: h))
        glow(CGPoint(x: w * 0.5, y: h * 0.05), radius: w * 1.1, color: Color(hex: "FFEACB"), intensity: 0.5)
        glow(CGPoint(x: w * 0.15, y: h * 0.2), radius: w * 0.7, color: accent, intensity: 0.45)
        glow(CGPoint(x: w * 0.9, y: h * 0.25), radius: w * 0.6, color: secondary, intensity: 0.28)
        if confetti {
            let colors: [Color] = [accent, secondary, .white, Palette.signal]
            for i in 0..<140 {
                let s = rng.cg(2...6.5)
                let rect = CGRect(x: -s / 2, y: -s * 0.3, width: s, height: s * 0.6)
                let t = CGAffineTransform(translationX: rng.cg(0...w), y: rng.cg(0...h * 0.75))
                    .rotated(by: rng.cg(0...(.pi)))
                ctx.fill(Path(rect).applying(t), with: .color(colors[i % colors.count].opacity(rng.next(in: 0.55...0.95))))
            }
        }
        let rows = 4
        for row in 0..<rows {
            let depth = CGFloat(row) / CGFloat(rows - 1)
            let y = h * (0.50 + depth * 0.16)
            let r = w * (0.034 + depth * 0.03)
            let shade = Color(hex: "040405").opacity(0.85 + depth * 0.15)
            var x = rng.cg(-r...r)
            var bodies = Path(), rims = Path(), arms = Path(), phones = Path()
            while x < w + r * 2 {
                let jitterY = y + rng.cg(-r * 0.4...r * 0.4)
                let head = CGRect(x: x - r * 0.45, y: jitterY - r * 0.55, width: r * 0.9, height: r * 1.1)
                rims.addEllipse(in: head.offsetBy(dx: 0, dy: -1.2).insetBy(dx: -0.8, dy: -0.8))
                bodies.addEllipse(in: head)
                bodies.addRoundedRect(in: CGRect(x: x - r * 1.5, y: jitterY + r * 0.55, width: r * 3, height: h),
                                      cornerSize: CGSize(width: r, height: r))
                if rng.chance(confetti ? 0.55 : 0.22) {
                    let side: CGFloat = rng.chance(0.5) ? 1 : -1
                    let tip = CGPoint(x: x + side * r * rng.cg(0.6...1.6), y: jitterY - r * rng.cg(2.4...3.6))
                    arms.move(to: CGPoint(x: x + side * r * 1.1, y: jitterY + r * 0.9))
                    arms.addLine(to: tip)
                    if rng.chance(confetti ? 0.25 : 0.6) {
                        phones.addRoundedRect(in: CGRect(x: tip.x - r * 0.28, y: tip.y - r * 0.5, width: r * 0.56, height: r * 0.95),
                                              cornerSize: CGSize(width: 2, height: 2))
                    }
                }
                x += r * rng.cg(1.9...2.6)
            }
            ctx.fill(rims, with: .color(accent.opacity(0.35 * (1 - depth * 0.6))))
            ctx.stroke(arms, with: .color(shade), style: StrokeStyle(lineWidth: r * 0.42, lineCap: .round))
            ctx.fill(bodies, with: .color(shade))
            ctx.fill(phones, with: .color(Color(hex: "DDE8FF").opacity(0.9)))
            var c = ctx
            c.blendMode = .screen
            c.addFilter(.blur(radius: 5))
            c.fill(phones, with: .color(Color(hex: "BFD4FF").opacity(0.6)))
        }
    }

    func scoreboard(rng: inout SeededRandom) {
        nightSky(horizon: 0.9)
        glow(CGPoint(x: w * 0.1, y: h * 0.1), radius: w * 0.5, color: Color(hex: "FFE9C4"), intensity: 0.25)
        let panel = CGRect(x: w * 0.08, y: h * 0.2, width: w * 0.84, height: h * 0.42)
        // supports
        ctx.fill(Path(CGRect(x: panel.midX - w * 0.2, y: panel.maxY, width: w * 0.05, height: h)), with: .color(Color(hex: "0A0A0D")))
        ctx.fill(Path(CGRect(x: panel.midX + w * 0.15, y: panel.maxY, width: w * 0.05, height: h)), with: .color(Color(hex: "0A0A0D")))
        ctx.fill(Path(roundedRect: panel.insetBy(dx: -6, dy: -6), cornerRadius: 6), with: .color(Color(hex: "101014")))
        ctx.fill(Path(roundedRect: panel, cornerRadius: 3), with: .color(Color(hex: "060607")))
        glow(CGPoint(x: panel.midX, y: panel.midY), radius: panel.width * 0.8, color: Palette.signal, intensity: 0.12)

        let lines = board.isEmpty ? ["HOME  \(rng.next() % 6)", "AWAY  \(rng.next() % 6)"] : board
        let fontSize = min(panel.height / CGFloat(lines.count + 1) * 0.95, panel.width * 0.16)
        for (i, line) in lines.enumerated() {
            let y = panel.minY + panel.height * (CGFloat(i) + 1) / CGFloat(lines.count + 1)
            let text = Text(line)
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "FFC46B"))
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: fontSize * 0.18))
                layer.draw(text, at: CGPoint(x: panel.midX, y: y), anchor: .center)
            }
            ctx.draw(text, at: CGPoint(x: panel.midX, y: y), anchor: .center)
        }
        // LED dot matrix
        var grid = Path()
        let pitch: CGFloat = 2.6
        var gx = panel.minX
        while gx < panel.maxX { grid.move(to: CGPoint(x: gx, y: panel.minY)); grid.addLine(to: CGPoint(x: gx, y: panel.maxY)); gx += pitch }
        var gy = panel.minY
        while gy < panel.maxY { grid.move(to: CGPoint(x: panel.minX, y: gy)); grid.addLine(to: CGPoint(x: panel.maxX, y: gy)); gy += pitch }
        ctx.stroke(grid, with: .color(.black.opacity(0.55)), lineWidth: 0.8)
        // accent strip under the board
        let strip = CGRect(x: panel.minX, y: panel.maxY + 10, width: panel.width, height: h * 0.035)
        ctx.fill(Path(strip), with: .linearGradient(Gradient(colors: [accent, secondary]),
                                                     startPoint: CGPoint(x: strip.minX, y: 0), endPoint: CGPoint(x: strip.maxX, y: 0)))
        glow(CGPoint(x: strip.midX, y: strip.midY), radius: strip.width * 0.6, color: accent, intensity: 0.3)
        stands(top: 0.80, bottom: 1.0, rng: &rng)
    }

    func concourse(rng: inout SeededRandom) {
        fill(bounds, [Color(hex: "1B120A"), Color(hex: "0A0705"), Color(hex: "040303")], from: .zero, to: CGPoint(x: 0, y: h))
        let colors: [Color] = [Palette.signal, Color(hex: "FFF0D6"), accent, Color(hex: "FF8F5A"), secondary]
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.blendMode = .screen
            for i in 0..<46 {
                let r = rng.cg(2...max(3, min(w, h) * 0.11))
                let p = CGPoint(x: rng.cg(0...w), y: rng.cg(0...h * 0.7))
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                let color = colors[i % colors.count].opacity(rng.next(in: 0.10...0.42))
                layer.fill(Path(ellipseIn: rect), with: .color(color))
                layer.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)), with: .color(color.opacity(0.6)), lineWidth: 1.2)
            }
        }
        // neon menu-board strips
        for i in 0..<3 {
            let y = h * (0.18 + CGFloat(i) * 0.09)
            let x0 = w * rng.cg(0.05...0.3)
            let strip = CGRect(x: x0, y: y, width: w * rng.cg(0.25...0.5), height: 3)
            ctx.fill(Path(roundedRect: strip, cornerRadius: 1.5), with: .color(accent.opacity(0.9)))
            glow(CGPoint(x: strip.midX, y: strip.midY), radius: strip.width * 0.6, color: accent, intensity: 0.25)
        }
        // floor reflection
        fill(CGRect(x: 0, y: h * 0.72, width: w, height: h * 0.28), [Color(hex: "2A1B10").opacity(0.6), .black],
             from: CGPoint(x: 0, y: h * 0.72), to: CGPoint(x: 0, y: h))
        glow(CGPoint(x: w * 0.5, y: h * 0.74), radius: w * 0.6, color: Palette.signal, intensity: 0.18)
    }

    func arena(rng: inout SeededRandom) {
        fill(bounds, [Color(hex: "040406"), Color(hex: "0B0B12")], from: .zero, to: CGPoint(x: 0, y: h * 0.6))
        // ring of catwalk lights
        var ring = Path()
        for i in 0..<28 {
            let t = CGFloat(i) / 27
            let x = w * t
            let y = h * 0.1 + sin(t * .pi) * h * 0.06
            ring.addEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
            glow(CGPoint(x: x, y: y), radius: 26, color: Color(hex: "FFF3DD"), intensity: 0.35)
        }
        ctx.fill(ring, with: .color(.white))
        // center-hung board
        let board = CGRect(x: w * 0.32, y: h * 0.2, width: w * 0.36, height: h * 0.16)
        ctx.fill(Path(roundedRect: board, cornerRadius: 4), with: .color(Color(hex: "0E0E14")))
        let screen = board.insetBy(dx: 5, dy: 5)
        ctx.fill(Path(roundedRect: screen, cornerRadius: 2),
                 with: .linearGradient(Gradient(colors: [accent, secondary.opacity(0.8)]),
                                       startPoint: CGPoint(x: screen.minX, y: screen.minY), endPoint: CGPoint(x: screen.maxX, y: screen.maxY)))
        glow(CGPoint(x: board.midX, y: board.midY), radius: w * 0.55, color: accent, intensity: 0.35)
        stands(top: 0.36, bottom: 0.6, rng: &rng)
        // playing surface
        let surface = CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)
        if sport == .hockey {
            fill(surface, [Color(hex: "EAF3F8"), Color(hex: "B9CEDB")], from: CGPoint(x: 0, y: surface.minY), to: CGPoint(x: 0, y: h))
            var lines = Path()
            lines.move(to: CGPoint(x: 0, y: surface.minY + surface.height * 0.42))
            lines.addLine(to: CGPoint(x: w, y: surface.minY + surface.height * 0.42))
            ctx.stroke(lines, with: .color(Color(hex: "C8102E").opacity(0.8)), lineWidth: 3)
            ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.35, y: surface.minY + surface.height * 0.3, width: w * 0.3, height: surface.height * 0.24)),
                       with: .color(Color(hex: "1D4EA0").opacity(0.7)), lineWidth: 2)
            // boards and glass
            fill(CGRect(x: 0, y: surface.minY - 6, width: w, height: 8), [.white, Color(hex: "D8D8D8")],
                 from: CGPoint(x: 0, y: surface.minY - 6), to: CGPoint(x: 0, y: surface.minY + 2))
        } else {
            fill(surface, [Color(hex: "D9A066"), Color(hex: "9C6534")], from: CGPoint(x: 0, y: surface.minY), to: CGPoint(x: 0, y: h))
            var boards = Path()
            for i in 0..<22 {
                let t = CGFloat(i) / 21 - 0.5
                boards.move(to: CGPoint(x: w * 0.5 + t * w * 1.1, y: surface.minY))
                boards.addLine(to: CGPoint(x: w * 0.5 + t * w * 3, y: h))
            }
            ctx.stroke(boards, with: .color(.black.opacity(0.08)), lineWidth: 1)
            let key = CGRect(x: w * 0.36, y: surface.minY + surface.height * 0.1, width: w * 0.28, height: surface.height * 0.5)
            ctx.fill(Path(key), with: .color(accent.opacity(0.75)))
            ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.33, y: surface.minY + surface.height * 0.5, width: w * 0.34, height: surface.height * 0.2)),
                       with: .color(.white.opacity(0.8)), lineWidth: 1.6)
        }
        glow(CGPoint(x: w * 0.5, y: h * 0.62), radius: w * 0.7, color: .white, intensity: 0.22)
    }

    func skyline(rng: inout SeededRandom) {
        fill(bounds, [Color(hex: "120C26"), Color(hex: "4A2348"), Color(hex: "E07A4A"), Color(hex: "F6B26B")],
             from: .zero, to: CGPoint(x: 0, y: h * 0.72))
        glow(CGPoint(x: w * 0.62, y: h * 0.7), radius: w * 0.8, color: Color(hex: "FFD08A"), intensity: 0.55)
        glow(CGPoint(x: w * 0.2, y: h * 0.3), radius: w * 0.6, color: accent, intensity: 0.15)
        var x: CGFloat = -10
        var buildings = Path()
        var windows = Path()
        while x < w {
            let bw = rng.cg(w * 0.05...w * 0.14)
            let bh = rng.cg(h * 0.1...h * 0.48)
            let rect = CGRect(x: x, y: h * 0.78 - bh, width: bw, height: bh + h * 0.3)
            buildings.addRect(rect)
            var wy = rect.minY + 6
            while wy < h * 0.78 {
                var wx = rect.minX + 4
                while wx < rect.maxX - 4 {
                    if rng.chance(0.28) { windows.addRect(CGRect(x: wx, y: wy, width: 2, height: 3)) }
                    wx += 5
                }
                wy += 7
            }
            x += bw + rng.cg(0...6)
        }
        ctx.fill(buildings, with: .color(Color(hex: "07060B")))
        ctx.fill(windows, with: .color(Color(hex: "FFD38A").opacity(0.8)))
        fill(CGRect(x: 0, y: h * 0.78, width: w, height: h * 0.22), [Color(hex: "0A0810"), .black],
             from: CGPoint(x: 0, y: h * 0.78), to: CGPoint(x: 0, y: h))
    }

    func trackside(rng: inout SeededRandom) {
        daySky(horizon: 0.32)
        stands(top: 0.22, bottom: 0.44, rng: &rng, day: true)
        // asphalt band on a diagonal
        var track = Path()
        track.move(to: CGPoint(x: 0, y: h * 0.5))
        track.addLine(to: CGPoint(x: w, y: h * 0.44))
        track.addLine(to: CGPoint(x: w, y: h * 0.86))
        track.addLine(to: CGPoint(x: 0, y: h * 0.98))
        track.closeSubpath()
        ctx.fill(track, with: .linearGradient(Gradient(colors: [Color(hex: "3A3B40"), Color(hex: "1E1F22")]),
                                              startPoint: CGPoint(x: 0, y: h * 0.45), endPoint: CGPoint(x: 0, y: h)))
        // kerbs
        let stripes = 18
        for i in 0..<stripes {
            let t0 = CGFloat(i) / CGFloat(stripes), t1 = CGFloat(i + 1) / CGFloat(stripes)
            var k = Path()
            k.move(to: CGPoint(x: w * t0, y: h * (0.5 - 0.06 * t0)))
            k.addLine(to: CGPoint(x: w * t1, y: h * (0.5 - 0.06 * t1)))
            k.addLine(to: CGPoint(x: w * t1, y: h * (0.5 - 0.06 * t1) - 6))
            k.addLine(to: CGPoint(x: w * t0, y: h * (0.5 - 0.06 * t0) - 6))
            k.closeSubpath()
            ctx.fill(k, with: .color(i % 2 == 0 ? Color(hex: "E10600") : .white))
        }
        // motion-blurred car
        let carY = h * 0.66
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            var streak = Path()
            streak.addRoundedRect(in: CGRect(x: w * 0.05, y: carY - h * 0.03, width: w * 0.75, height: h * 0.06),
                                  cornerSize: CGSize(width: 12, height: 12))
            layer.fill(streak, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.7), accent]),
                                                     startPoint: CGPoint(x: w * 0.05, y: 0), endPoint: CGPoint(x: w * 0.8, y: 0)))
        }
        let body = CGRect(x: w * 0.56, y: carY - h * 0.028, width: w * 0.3, height: h * 0.05)
        ctx.fill(Path(roundedRect: body, cornerRadius: h * 0.02), with: .color(accent))
        ctx.fill(Path(ellipseIn: CGRect(x: body.minX + 4, y: body.maxY - h * 0.02, width: h * 0.045, height: h * 0.045)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: body.maxX - h * 0.05, y: body.maxY - h * 0.02, width: h * 0.045, height: h * 0.045)), with: .color(.black))
        var speed = Path()
        for _ in 0..<14 {
            let y = rng.cg(h * 0.52...h * 0.9)
            let x = rng.cg(0...w * 0.6)
            speed.move(to: CGPoint(x: x, y: y)); speed.addLine(to: CGPoint(x: x + rng.cg(30...120), y: y - 4))
        }
        ctx.stroke(speed, with: .color(.white.opacity(0.18)), lineWidth: 1)
        glow(CGPoint(x: w * 0.5, y: h * 0.3), radius: w * 0.9, color: Color(hex: "FFF1D6"), intensity: 0.2)
    }
}
