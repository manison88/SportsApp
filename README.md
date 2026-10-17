# Witness

An iOS app for every game you've been to. Each one becomes a memory: the score, where you sat, who you were with, and your own photos from that night. It works for any sport, all on your iPhone, with no accounts and no servers.

The design is "Broadcast, cleaned": the final mockups in `mockups/final/`, built here in SwiftUI.

## What's in the app

| Screen | How to get there |
|---|---|
| Welcome | First launch. Choose "Find games in my photos", "Add a game", or "Explore sample games" |
| 01 Discovery | Welcome, or Timeline **+** then **Find in photos**. Scans your photos for stadium GPS and dates, then asks you to confirm each game |
| 02 Map | Tab. A globe with arcs from home, your total miles, and venue, country and game counts |
| 03 Passport | Tab. One stamp per ballpark (out of 30) or venue, with a filter per league |
| 04 Timeline | Tab (home). Photo cards with ticket stubs, plus search |
| 05 Game memory | Tap any game. Shows the line score, who you were with and Play recap, with edit and delete in the **…** menu |
| 06 You were there | From a game. A scrubbable win-probability curve with the key plays |
| 07 Recap film | Play recap. A Ken Burns film of the game you can share as a story image |
| 08 Venue | From Passport or a game. Your record there and a seat map |
| 09 You | Tab. Your win rate, a dot for every result, and lifetime stats |
| 10 Lucky charm | Tap the win-rate card. You compared with the pre-game odds |
| 11 Wrapped | You, then Wrapped. A season story card |
| 12 Live check-in | Timeline **+** then **Check in live**. Keep score and save moments, then save the game when it ends |
| 13 Shared passport | You, then tap a person |
| 14 Trip | From a game that was part of a trip |

### Getting games in (all free, all on the device)
- **Add a game by hand:** pick a sport, teams, venue, date, score, seat, the people you were with, a note and photos.
  - **Venues** come from a bundled catalog of 48 venues (all 30 MLB parks included) or from Apple Maps search. You can also create one yourself and drop a pin.
  - **"Look up final score"** fills in MLB scores and line scores from the free MLB Stats API.
- **Import a ticket:** use a screenshot, a PDF or pasted confirmation-email text from Ticketmaster, StubHub, SeatGeek, AXS or a team app. Apple's Vision framework reads it on the iPhone and fills in the form.
- **Photos:** Discovery groups photos taken at stadiums on the same day into games. **Find photos from this game** attaches the photos you took at that venue during that game.
- **Live check-in:** finds the venue from your location and keeps time-stamped moments.

`docs/INTEGRATIONS.md` explains why there's no "Connect Ticketmaster" button: none of the marketplaces offer a free API for a customer's purchased tickets. It also covers what phase 2 adds (a Share extension, Wallet passes and Live Activities).

## Build and run

You need Xcode 16 or later and the iOS 18 SDK. The Xcode project is generated from `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open Witness.xcodeproj
```

Run the **Witness** scheme on a simulator or a device. A device needs your personal team for signing.

| Launch argument | Effect |
|---|---|
| `-demo` | Loads the sample library: Sam Okafor, a Chicago fan with 60 games |
| `-reset` | Wipes the saved library first |
| `-empty` | Starts with an empty library and skips Welcome |
| `-uitest` | Turns off animations and location updates, for UI tests |

The library is saved as JSON in the app's Documents folder. Sample data comes from `Witness/Resources/SeedData`; after you edit it, rebuild the bundled files with `python3 Tools/build_seed.py`.

## Tests

`xcodebuild test -scheme Witness -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`

- **Unit tests** (`WitnessTests`): ticket parsing for 8 real-world formats, a rendered ticket screenshot and a ticket PDF run through Vision OCR and the parser, library persistence, custom venues, the sample library, outcomes and stats.
- **End-to-end UI tests** (`WitnessUITests`):
  - Welcome and a tour of every tab
  - Game memory, You were there and Recap
  - Lambeau and Spain trips
  - Adding a game by hand
  - Creating a custom venue
  - Importing a ticket from pasted email text
  - Live check-in
  - Discovery against real photos seeded into the simulator

  Every test saves screenshots.

CI (`.github/workflows/ios.yml`) runs everything on a free macOS runner. Before the tests it gets the simulator ready:
- adds JPEGs with real stadium GPS and capture dates (`ci/seed_photos.py`)
- grants permissions
- sets the location to Wrigley

Results, including screenshots named by test, are published to the `ci-results` branch:

```sh
git fetch origin ci-results && git checkout origin/ci-results -- shots
```

## Layout

```
Witness/
  App/        WitnessApp (launch args), RootView (tabs, modals, routes)
  Design/     Theme (colors, compressed display type, buttons, nav bar), Components
  Model/      Models, Library (persistence + catalog), Stats
  Services/   TicketParser, TextRecognizer (Vision), PhotoMatcher (PhotoKit),
              LocationService, ScoreLookup (MLB Stats API)
  Features/   Timeline, Map, Passport, You, Game, Venue, Trip, Social, Live,
              Discovery, Onboarding, Add
  Resources/  Catalog (venues, ballparks, teams), Sample (library), SeedData (source)
```

Team marks are city names and codes in team colors only. There are no logos or nicknames in the UI. Photo credits are in `Witness/Resources/PhotoCredits.md`.
