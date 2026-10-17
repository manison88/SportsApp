import SwiftUI

/// "19° · Snow" with the WMO symbol. Open-Meteo backed.
struct WeatherChip: View {
    let weather: WeatherSnapshot
    var showFeelsLike = false
    var indoor = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: indoor ? "building.2.fill" : weather.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 12, weight: .semibold))
            if indoor {
                Text("Indoors")
            } else {
                Text(weather.temperatureText).monospacedDigit()
                Text(weather.condition).foregroundStyle(Palette.textSecondary)
                if showFeelsLike {
                    Text("feels \(Int(weather.apparentTemperature.rounded()))°")
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .font(WType.caption)
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, 11)
        .frame(height: 28)
        .glass(radius: Radius.chip)
    }
}

/// Small capsule label.
struct Pill: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Palette.textPrimary
    var filled = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text)
        }
        .font(WType.eyebrowSmall)
        .tracking(1.2)
        .textCase(.uppercase)
        .foregroundStyle(filled ? Palette.ink : tint)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background {
            Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)))
        }
        .overlay { Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.25), lineWidth: Size.hairline) }
    }
}

/// Overlapping companion avatars. Initials on each person's own color.
struct CompanionStack: View {
    let people: [Person]
    var size: CGFloat = Size.avatar

    var body: some View {
        HStack(spacing: -size * 0.28) {
            ForEach(people) { person in
                Avatar(person: person, size: size)
            }
        }
    }
}

struct Avatar: View {
    let person: Person
    var size: CGFloat = Size.avatar

    var body: some View {
        let color = Color(hex: person.colorHex)
        Circle()
            .fill(LinearGradient(colors: [color, color.mix(with: .black, by: 0.45)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Text(person.initials)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 2.5) }
            .frame(width: size, height: size)
            .accessibilityLabel(person.name)
    }
}

/// 44pt circular glass control for screen chrome (back, share, more).
struct ChromeButton: View {
    let symbol: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 40, height: 40)
                .glass(radius: 20)
                .frame(width: Size.tapTarget, height: Size.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Eyebrow + serif title, the standard section opener.
struct SectionHeader: View {
    let eyebrow: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).eyebrow()
                Text(title).displayTitle(WType.sectionTitle)
            }
            Spacer(minLength: Space.m)
            if let trailing {
                Text(trailing)
                    .font(WType.subhead)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

/// Thin gradient rule in the game's team colors.
struct TeamRule: View {
    let pair: TeamPair?
    var height: CGFloat = 2

    var body: some View {
        Capsule()
            .fill(pair?.gradient ?? LinearGradient(colors: [Palette.signal, Palette.signalSoft], startPoint: .leading, endPoint: .trailing))
            .frame(height: height)
    }
}
