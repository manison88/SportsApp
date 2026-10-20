# Light mode review

Every screen was shot in Light and Dark on an iPhone 17 Pro simulator (iOS 26.2) with `WitnessUITests/AppearanceReviewTests.swift`
and looked at, one by one. The sweep only runs when `TEST_RUNNER_REVIEW_OUT=<folder>` and `TEST_RUNNER_REVIEW_SCHEME=light|dark`
are set; it writes PNGs under `<folder>/<scheme>/`, and review builds also copy every exported share card to `<folder>/<scheme>/export/`.

```
TEST_RUNNER_REVIEW_OUT=/tmp/shots TEST_RUNNER_REVIEW_SCHEME=light xcodebuild test -project Witness.xcodeproj -scheme Witness \
  -destination 'platform=iOS Simulator,id=<id>' -only-testing:WitnessUITests/AppearanceReviewTests
```

## Fixed

| Screen | Light problem | Fix |
|---|---|---|
| Map > Countries (and the Countries share card) | The globe disc was a pale grey circle on a white card, the land was invisible and the yellow country floated | Light globe is a deep ocean-blue disc with lighter land, a faint grid, a dark rim and the yellow country on top. Dark is unchanged |
| Map > Venues, share Grounds, venue page (until the satellite view arrives) | Pale disc and pale stadium glyph on white | Dark slate ground in Light |
| Game page, Venue page, Plan page | Status bar clock stayed dark over the dark photo hero | `lightStatusBar()` sets the nav bar style while the page shows |
| Photo viewer (full screen) | Clock invisible on black | `preferredColorScheme(.dark)` on the viewer |
| Onboarding result "Newest" card | Venue name and score were dark ink over the photo | Text stack forced dark (white type) over the photo and scrim |
| Game page, motorsport podium | First place was white on off-white | Primary text |
| Big Games list | Stage icons for non-title games were white on off-white | Stage tint is primary text (still white on photos) |
| Recap play button | White glyph on a pale button | Primary text |
| Trip map | White dashed route and white dots vanished on the light map | Primary text |
| Venue page seat map | Unlit wedges and the diamond were faint | Visible wedge fill and diamond; dark labels |
| You > Lucky dial | Progress arc was white on white | Primary text |

## Checked, fine in Light and Dark

Welcome, photo access, scan progress, scan result, Discovery (review, photos, done), Timeline (empty, top, scrolled, search, all card states: photo, no photo, upcoming), Add menu, Add game, Add visit, venue picker, new venue, team picker (leagues and teams), Plan a game, Import ticket, Paste, Album import, Live check-in (start, scoring, moments), Game page (cover, photos, people, links), photo grid and select mode, You were there (report and moments), Recap, Trip (US and Spain), Map (map, expanded, filter menu, Venues, Countries, country games, Games), Passport (every sport, soccer-or-fudbal prompt, stamps), Venue page, You (top, scrolled, Appearance row), Lucky, Big Games, Schedule gaps, Back up, Scan check, Your teams, Legal pages, Wrapped.

## Share cards

Each share sheet has a Light / Dark control (starts as the app's current look; Auto resolves through the system setting) and exports from the chosen look
through `ImageRenderer` with an explicit `shareScheme` and `colorScheme`, so an export never depends on the live UI. Sizes are unchanged (1080x1920 story, 1080x1350 feed).
Exports are written as real files (`Witness-<title>-<style>-<look>.png`, opaque sRGB, PNG or JPEG over 4 MB) and shared as files.

Photo-led looks (full-bleed photo, aerial, team-color field) keep white type on the photo in both looks; their wordmark and chrome follow the look where they sit on the card.
Type-led looks switch to the palette's light ink (or warm paper with ink type) in Light.

Done and shot in both looks: Game (Ticket, Full bleed), Venue (From above, Every game), Map (Globe, Miles, Grounds, Countries; Light uses a light map), Passport (league, full), Recap (Photo, Type, Color, Paper, Stub),
Lucky charm (5), My numbers (5), Wrapped (Record, Games, Miles, Home ground, Big game, Coldest, Calendar, Top five), Trip (Route, Count, Field, Paper, Stub), You were there (5).

Not reachable in the app today (no screen opens them), converted but not shot: the shared-passport page and its five cards.

## Share as a file (Messages fix)

`ShareLink(item: Image)` handed Messages anonymous in-memory PNG data, which showed a black "Photo / PNG image" placeholder.
Every card is now written to a temp file (`Witness-<title>-<style>-<look>.png`, opaque sRGB, exact pixel size) and shared through a `Transferable`
file representation with the image as a fallback; a JPEG is shared instead when the PNG is over 4 MB. The file lives as long as the share sheet holds it.
`WitnessTests/ShareExportTests.swift` checks the file exists, decodes, has the format's pixel size, no alpha, is under 8 MB and is named as expected.
All 40 cards were exported in both looks and checked as files (1080x1920, RGB, largest 2.6 MB). Messages itself can only be tried on a device.

## Not checked

- Plan page and countdown banner: the simulator's catalog has no upcoming games for the team picked, so no plan could be created.
- Wrapped Miles, Home ground and Top five cards: the sample library does not produce them (their code follows the same Light rules as the cards that were shot).
- Shared-passport page and its cards: nothing in the app opens it.
- Photo-access denied, limited-access and scan-banner states, and the system share sheet itself.

Before/after shots are in `docs/light-review/`.
