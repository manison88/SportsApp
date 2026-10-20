import SwiftUI
import Testing
@testable import Witness

struct AppearanceChoiceTests {
    @Test func storedStringMapsToScheme() {
        #expect(AppearanceChoice(stored: "auto").colorScheme == nil)
        #expect(AppearanceChoice(stored: "light").colorScheme == .light)
        #expect(AppearanceChoice(stored: "dark").colorScheme == .dark)
    }

    @Test func unknownOrEmptyFollowsTheSystem() {
        #expect(AppearanceChoice(stored: "").colorScheme == nil)
        #expect(AppearanceChoice(stored: "sepia").colorScheme == nil)
    }

    @Test func everyChoiceRoundTripsThroughItsStoredString() {
        for choice in AppearanceChoice.allCases {
            #expect(AppearanceChoice(stored: choice.rawValue) == choice)
        }
    }
}
