# C · Your fan profile first (onboarding)
Bet: 30 seconds of profile (home, sports, teams) makes the scan smarter and the first result about THEM ("47 games, 12 of them your Cubs").
Files: features/flow/v1..v11 (HTML), png/flow/*.png, png/flow.png (contact sheet). Render with the command in BRIEF.md.

## Flow (5 setup screens, then scan; 6 counting the system alert)
1. v1 Welcome: the promise, one Continue. Exits: Add a game, Explore sample games. Wrigley photo cropped so no seat sign or big logo reads.
2. v2 Where's home: city by Current location or typing. Drives the Map home dot and travel miles. City only. Skip.
3. v3 What do you watch: 7 sport tiles, our glyphs in the map line colors, multi-select. Skip = all sports equal.
4. v4 Who do you cheer for: abbreviation chips in team colors, grouped by league, search, suggested from home city. No logos. Skip.
5. v5 What Witness needs, and why: Photos required (dates and places only), Location optional (Check in live), Notifications optional, off by default. One Continue. "Not now" goes to v9.
   v6 iOS Photos alert over v5 (system sheet, reason already shown). Location prompt follows if its switch is on.
6. v7 Scan: honest counts only (photos checked of total, near a venue, venues, games matched). Profile order shown: "Chicago venues first, then baseball, football and 4 more". Rows tagged "Your Cubs".
   v8 First result: giant 47, "12 of them your Cubs", plus 10 Bears and 5 Bulls, sport color bar. See my games.
Fallbacks: v9 Photos off (Open Settings, choose photos from one game via picker, add by hand, samples; profile kept). v10 Nothing found (0 of 2,814 checked, Cubs-aware add by date, picker, samples).
After: v11 first-run Timeline: filter chips from the profile (All 47, Cubs 12, Bears 10, Bulls 5), "Finish setting up 2 of 4" checklist (hide-able), then the first memory card.

## Skip map
Welcome: no skip, three exits. Home, Sports, Teams: Skip (top right, 44pt, full label). Permissions: Not now. Every skip leaves the scan working, just less targeted. Back button on 2 to 5.

## Drop-off risks and answers
- "Why do you want my photos?" Reason block precedes the alert; "dates and places only, never uploads"; lock line on v1, v5, v7.
- Profile feels like a form: 3 questions, all skippable, progress segments, defaults pre-filled, each states what it drives.
- Tens of thousands of photos: scan shows checked/total, runs in background, home-first ordering gives early hits.
- Finds nothing / denies Photos: v9, v10 always offer picker, manual add, samples; profile not lost.
Step count: welcome + 4 setup screens = 5, plus the system alert, then scan.

## SwiftUI hints
TabView(.page) with page index dots hidden and custom segment bar; hold a @Observable FanProfile (home, sports, teams) in Environment. Sport tiles reuse Sport.lineColor/symbol; chips reuse mono-badge style. matchedGeometryEffect on the 47 count from scan to result. PhotosPicker for the no-permission path; PHPhotoLibrary.requestAuthorization(for: .readWrite) then handle .limited and .denied; recheck on scenePhase == .active after Settings. Scan order: PHFetchOptions on creationDate, prefilter by CLLocation near home and venues, then favorite sports/teams first. Reuse: WelcomeView photo/scrim, ScoreStack, PrimaryButtonStyle, Timeline cards, the Passport/Map tokens.
## New data needed
FanProfile storage (home city + coordinates, sports set, team ids with abbreviation and color), team catalog by league with suggested-by-region, venue index for the scan priority, first-run checklist state, "your team" counts per game.
Glyphs in the mockups are hand-drawn approximations of the SF Symbols the app uses (baseball.fill, football.fill, etc.).

## Mobbin references used (no extra searches run)
- Apple Sports follow flow: https://mobbin.com/flows/8eda1da5-d35f-4917-b535-1faf27a057e4
- NBA follow teams and interests: https://mobbin.com/flows/5759b0b4-9e76-4d2f-9cfa-28fb70c9c2a4
- Halide checklist: https://mobbin.com/screens/bd436aa4-c569-4472-8d10-9b7769c63193
- Cash App Not now + Continue: https://mobbin.com/screens/a83fa99d-5202-4250-898a-8ccb1745143d
- Google Health setup checklist card (v11): https://mobbin.com/screens/5c761a21-21d4-4ebd-a88b-27d5a41202a0
