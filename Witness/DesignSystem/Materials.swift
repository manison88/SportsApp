import SwiftUI

// MARK: - FX switch

enum FX {
    /// Metal shader effects. Disable with the `-noShaders` launch argument to
    /// review the static fallbacks (and for older GPUs / Low Power Mode later).
    static var shadersEnabled: Bool = !ProcessInfo.processInfo.arguments.contains("-noShaders")
}

// MARK: - Film grain

/// Full-bleed film grain. Composite on top of imagery and dark surfaces.
struct GrainOverlay: View {
    var intensity: Double = 0.10
    var frame: Double = 0

    var body: some View {
        Group {
            if FX.shadersEnabled {
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(ShaderLibrary.filmGrain(.float(frame), .float(intensity)))
            } else {
                StaticGrain(intensity: intensity)
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Fallback grain drawn once with Canvas.
struct StaticGrain: View {
    var intensity: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 0x5EED)
            let count = Int(size.width * size.height / 24)
            for _ in 0..<count {
                let x = rng.cg(0...size.width)
                let y = rng.cg(0...size.height)
                let v = rng.next(in: 0.0...1.0)
                let color = v > 0.5 ? Color.white : Color.black
                ctx.fill(Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                         with: .color(color.opacity(intensity * abs(v - 0.5) * 2)))
            }
        }
        .drawingGroup()
    }
}

// MARK: - Vignette

struct Vignette: View {
    var strength: Double = 0.65
    var body: some View {
        RadialGradient(colors: [.clear, .black.opacity(strength)],
                       center: .center, startRadius: 80, endRadius: 520)
            .allowsHitTesting(false)
    }
}

// MARK: - Scrims

/// Bottom-weighted fade that lets type sit on photography.
struct BottomScrim: View {
    var color: Color = Palette.ink
    var body: some View {
        LinearGradient(stops: [
            .init(color: color.opacity(0), location: 0),
            .init(color: color.opacity(0.55), location: 0.55),
            .init(color: color.opacity(0.92), location: 0.85),
            .init(color: color, location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }
}

struct TopScrim: View {
    var color: Color = Palette.ink
    var body: some View {
        LinearGradient(colors: [color.opacity(0.85), color.opacity(0)], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

// MARK: - Glass

/// Dark glass panel: ultra-thin material, a warm hairline, and a top sheen.
struct GlassBackground: ViewModifier {
    var radius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.07), .clear],
                                                 startPoint: .top, endPoint: .center))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.hairlineStrong, lineWidth: Size.hairline)
                    }
            }
    }
}

/// Solid card surface for content that should not show what's behind it.
struct CardBackground: ViewModifier {
    var radius: CGFloat = Radius.card
    var fill: Color = Palette.surface

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: Size.hairline)
                    }
            }
    }
}

extension View {
    func glass(radius: CGFloat = Radius.card) -> some View { modifier(GlassBackground(radius: radius)) }
    func card(radius: CGFloat = Radius.card, fill: Color = Palette.surface) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }
}

// MARK: - Seeded randomness (deterministic placeholder art)

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    mutating func cg(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(next(in: Double(range.lowerBound)...Double(range.upperBound)))
    }

    mutating func chance(_ p: Double) -> Bool { next(in: 0.0...1.0) < p }
}
