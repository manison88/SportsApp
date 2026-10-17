# A · Photo-first, value in 60 seconds
Bet: the fastest route from launch to a real found game wins trust. Show one big photo, ask for Photos with the reason on screen, make the scan watchable, land on a big number plus the newest game.

## Flow (features/flow/, 5 screens to first result)
1. v1 Welcome: one full-bleed Wrigley night photo, "Every game you were at." ("you" in amber), primary Find my games; Explore samples and Add a game stay as text exits.
2. v2 Priming: shows what is read (date, place) on a real photo with chips, a Reads / Never split, primary Allow photo access, Choose photos and Not now at equal tap size. System alert follows.
3. v3 Scan: real counters only: photos checked of total (bar is checked/total), near a stadium, venues, games, plus venues named live. Dismissible "a few minutes" note, Pause, primary Keep going in background.
4. v4 First result: "47 games found", newest game as hero card (score bug, date, section), primary Review games.
5. v5 First-run Timeline: dismissible 3-step Get started card (Review 47 games / Add a trip album / Try Check in live), newest game card below, tab bar.
Fallbacks: v6 Denied (Open Settings primary; Choose a few photos, Add by hand, Explore samples). v7 Nothing found (0 games, honest counts, Choose an album primary, manual and sample exits). v8 Limited access variant of v4: "Scanned the 148 photos you chose", Add photos.
Background run: tapping Keep going in background drops to v5; the scan continues and the card/Timeline shows a thin "Scanning 1,692 of 2,814" strip (not drawn, same data as v3).
Step count: 4 taps to first result (Find my games, Allow, system alert, wait), 5 screens.

## Risks and how the design answers them
- Private?: v2 is a whole screen on it, plus lock lines on v2 and v4.
- Tens of thousands of photos: counters move honestly, note sets expectation, scan keeps going off-screen, results appear as found.
- Finds nothing: v7 shows the work done (checked / near stadium / matched) and a way forward, never an empty app.
- Drop-off at priming: Not now is a full-size control, not a hairline link; denial still lands on v6 with exits.
- Drop-off during wait: the venue list names real places, so waiting shows proof.
Copy: no exclamation marks, no account step, amber used once per screen as "you" or progress.

## SwiftUI hints
- Welcome/priming/scan/result as a TabView(.page) with indicators hidden, or a NavigationStack with a step enum; matchedGeometryEffect for the newest-game photo from v4 card to the Timeline card.
- Auth: PHPhotoLibrary.requestAuthorization(for: .readWrite); handle .limited (v8, offer presentLimitedLibraryPicker) and .denied (v6, open UIApplication.openSettingsURLString). Choose photos can use PhotosPicker, which needs no permission.
- Observe scenePhase to refresh status when returning from Settings and to continue the scan; run the scan in a Task, publish counts via an @Observable model; BGProcessingTask for the long tail.
- Canvas for the optional pulse; the bar is a plain Capsule.
## Reuse
WelcomeView photo and headline, existing Timeline game card with ticket stub and score bug, venue/team chips, existing game review (Auto-discovery) from Review games, Check in live and trip album entry points.
## New data
Scan progress model (checked, total, nearStadium, venues[name, count], matched), photo auth status, checklist completion flags, "newest game" query, limited-library selection count.

## Mobbin (from the brief; no extra searches run)
- Halide permission checklist, what and why: https://mobbin.com/screens/bd436aa4-c569-4472-8d10-9b7769c63193
- Cash App Not now + Continue priming: https://mobbin.com/screens/a83fa99d-5202-4250-898a-8ccb1745143d
- Google Photos enabling access: https://mobbin.com/flows/f289ade5-5b4e-40d4-a647-bb2058e8cbaf
- Google Health first-run checklist card: https://mobbin.com/screens/5c761a21-21d4-4ebd-a88b-27d5a41202a0
- Pool recap big type reveal: https://mobbin.com/screens/c7f09d97-179b-466b-bdbf-0a2a755c8f21
