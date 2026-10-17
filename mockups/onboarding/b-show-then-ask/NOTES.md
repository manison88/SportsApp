# B. Show, then ask
Bet: people grant Photos access after they have felt the product. The first minute is a guided taste on sample data; the permission comes last, in context, with the reason first.

## Flow (features/v01..v13, png/flow.png is the contact sheet)
1. v01 Welcome. Motion: three rows of sample game cards (real photos, team chips, score bugs, each tagged SAMPLE) sweep in from the right at slightly different speeds with a 1.5pt blur and light trails, then decelerate (spring, ~1.4s) and settle behind one sharp hero card ("Down 3-1. Not tonight."). Headline and promise line rise in last. Static frame shown is mid-settle. Primary: Show me. Skip top right.
2. v02 Story 1, Timeline: the real Timeline screen is the hero, SAMPLE GAMES chip, caption "Every game, in order."
3. v03 Story 2, Map: real map with arcs colored by sport (baseball blue, football orange, basketball red, hockey ice, soccer green). Caption names the sport colors.
4. v04 Story 3, Recap: real recap film frame. Last button becomes "Now do it with yours". Swipe or Next; dots; Skip always visible (44pt).
5. v05 Now do it with yours: Find games in my photos (primary), Import a trip album, Add a game by hand, Keep exploring the sample. Privacy line.
6. v06 Photos priming sheet, only after path 1. Three reasons answer the three fears: private, only stadium photos count, big library is fine. Continue / Not now.
7. v07 System alert (iOS) with our purpose string. Full, Limited, Don't Allow all have a defined next screen.
8. v08 Scanning, honest: photos checked / total, near a stadium, venues, games found. Games stream in as they match. Hide lets the user leave.
9. v09 First result: "47 games you were at" over their own photo, 6 uncertain matches kept optional. Primary: See my Timeline.
Fallbacks: v10 permission denied (Choose photos instead via PhotosPicker needs no permission; Open Settings; manual; sample). v11 nothing found (9 near a stadium shown as thumbs, Match them by hand, trip album, manual, sample).
First run: v12 Timeline on sample data. Banner "This is sample data" with Add yours (primary) and Clear; every sample card carries a SAMPLE chip; a 3-item setup checklist (circles fill as done). v13 You tab: "Sample data: On" card with Clear sample data, one tap, no confirm sheet, then an Undo toast for 6s. Sample games stay until cleared and sort below real ones.

## Steps to first result
Full taste: 1,2,3,4,5,6,(7),8,9 = 7 screens plus the system alert (over the 3-6 target). With Skip: 1 or 5, 6, 8/9 = 4 screens. Chosen on purpose: the story is optional and costs about 10 seconds; the bet is it lifts grant rate.

## Risks and answers
- Story feels like a tour and users bail: 3 pages max, real screens not illustrations, Skip never leaves the corner, skippers land on v05, not on an empty app.
- Sample data mistaken for theirs: SAMPLE chip on every card, banner on first-run Timeline, Map, Passport, Clear in two places.
- Denied at the alert: priming sheet lets "Not now" cost nothing (no alert burned); v10 offers four ways forward.
- Library of tens of thousands: real counts, batches, leave-and-return; first games stream in within seconds so there is a reward before the scan ends.
- Nothing found: say what was checked, show the near-miss photos, offer manual match.
- Location permission is not asked at all: photo EXIF carries place. Ask later, in context, for live check-in (v12 checklist item 3).
- Background limits: iOS may pause the scan; use BGProcessingTask and scenePhase to resume, and say "tells you when it's done" only if notifications are granted.

## SwiftUI hints
TabView(.page) with PageIndexViewStyle for v02-04 (custom dots); welcome sweep is a Canvas or TimelineView with three offset HStacks and a spring on the hero (matchedGeometryEffect from hero card into Timeline card 1). PHPhotoLibrary.requestAuthorization(for: .readWrite) fires only from the sheet Continue; PhotosPicker for trip album and for the denied path (no auth). Observe PHAuthorizationStatus on scenePhase .active to refresh after returning from Settings. Handle .limited like full but show "Add more photos" in You.
## Reuse and new data
Reuse: Timeline card + ticket stub, score bug, Map globe, Passport, recap frame, existing sample-games loader (WelcomeView "Explore sample games"), b-tabs. New: isSample flag on Game/Venue/Photo (one query clears them), SAMPLE chip component, SampleBanner, scan progress model (checked, total, nearVenue, venues, matched), first-run checklist state, ScanResult near-miss list.
## Mobbin (used as inspiration, no brands copied)
- Camera onboarding theatrical welcome: https://mobbin.com/flows/1d328006-8692-4556-a642-f60fab639b3d
- Cash App Not now + Continue priming: https://mobbin.com/screens/a83fa99d-5202-4250-898a-8ccb1745143d
- Halide what-and-why checklist: https://mobbin.com/screens/bd436aa4-c569-4472-8d10-9b7769c63193
- Pool recap story, page segments: https://mobbin.com/screens/c7f09d97-179b-466b-bdbf-0a2a755c8f21
- Google Photos enabling access: https://mobbin.com/flows/f289ade5-5b4e-40d4-a647-bb2058e8cbaf
- Google Health setup checklist card: https://mobbin.com/screens/5c761a21-21d4-4ebd-a88b-27d5a41202a0
(No extra Mobbin searches were run.)
