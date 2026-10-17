import SwiftUI

// MARK: - Spacing (4pt grid)

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64

    /// Horizontal page margin. Wider than stock iOS (16) for an editorial feel.
    static let gutter: CGFloat = 22
    /// Vertical rhythm between major sections.
    static let section: CGFloat = 44
}

// MARK: - Radius

enum Radius {
    static let chip: CGFloat = 999
    static let small: CGFloat = 10
    static let photo: CGFloat = 18
    static let card: CGFloat = 28
    static let sheet: CGFloat = 38
}

// MARK: - Sizes

enum Size {
    static let hairline: CGFloat = 0.5
    static let tapTarget: CGFloat = 44
    static let monogramSmall: CGFloat = 28
    static let monogram: CGFloat = 44
    static let monogramLarge: CGFloat = 64
    static let avatar: CGFloat = 36
    static let heroHeight: CGFloat = 560
    static let tabBarHeight: CGFloat = 64
}
