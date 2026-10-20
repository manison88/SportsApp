# Scan handling: five approaches (Witness)
Screens: png/approach-N/vK-*.png, sheets png/approach-N.png, png/overview.png. Shared Scan settings sheet: png/settings-sheet/v1-settings.png (scope, albums, videos later, rescan, clear suggestions). Source: lib.py, a12.py, a345.py, sheets.cjs.
Every approach shows: start, in-progress, a fix for a missed or wrong game, and a "private, on this iPhone" line (lock icon, on at least 2 screens each).

## 1. Scan everything, foreground
- Bet: people accept 8 minutes of waiting if one list at the end is simple. Best for: small to mid libraries, first launch, demos. Worst for: 50k+ libraries, impatient users.
- Drop-off: leaving the app pauses it (edge screen v5); a 47-row list is a chore; bulk "Add all" hides wrong matches.
- Cost LOW. New: select-all list, pause/resume checkpoint (last photo index), "Wrong game" sheet with same-day schedule candidates.
- Privacy: line on start and live screens; "Matched on this iPhone" on results.

## 2. Background scan + inbox
- Bet: the scan should never be a screen; results are mail. Best for: huge libraries, returning users, incremental new-photo pickup. Worst for: users who want instant gratification; first-run "aha" is delayed.
- Drop-off: iOS suspends work (Low Power, force-quit; edge v4), notification permission denied, inbox ignored (badge decays to noise).
- Cost HIGH. New: BGProcessingTask + resumable scan queue, Live Activity (ActivityKit), local notification, inbox model with badge, incremental PHPhotoLibrary change observer, swipe row actions.
- Privacy: line in the start sheet, on the Live Activity, and in notification body.

## 3. Swipe to confirm
- Bet: confirming 47 games is a game itself. Best for: the review phase after any scan; 20 to 100 candidates; mobile-native fans. Worst for: low-confidence rows needing detail, accessibility (needs button fallback, shown).
- Drop-off: accidental swipes (undo toast edge v4, nothing deleted), wrong teams hidden behind a nice card (fix via "Wrong game" sheet v5), fatigue past about 60 cards.
- Cost MEDIUM. New: card stack with gesture, collage layout, undo stack, "ask later" resurfacing job. Scan itself is borrowed from 1 or 2.
- Privacy: stated on the intro card ("checked on this iPhone").

## 4. Start from a place or trip
- Bet: scope on purpose beats scanning everything. Best for: privacy-minded users, huge libraries, trip albums, people who know where they went. Worst for: casual fans who forgot half their games; coverage gaps feel like missing data.
- Drop-off: the "Where have you been?" choice is work; no instant total; users never scan the second place.
- Cost MEDIUM. New: map/venue picker with fence preview, album/date predicates on the PhotoKit fetch, trip grouping, "missing place" prompt (no-GPS photos placed by asking), coverage list with Scan buttons.
- Privacy: strongest. "The other 48,100 photos were not opened" is literally true and shown on the scanning screen.

## 5. Ask first, prove later (suggestions feed)
- Bet: no scan screen; trust comes from showing evidence, one card at a time. Best for: ongoing use, low anxiety onboarding, new games after attending. Worst for: first-day backlog (drips 3 at a time, edge v4), users who want everything now.
- Drop-off: cards ignored, backlog feels endless, confidence label not trusted without the evidence view.
- Cost MEDIUM. New: suggestion card + evidence view (photos, schedule match, scoreboard seal), rate-limited feed, confidence labels from the existing signals. Scan runs silently in the background (shares 2's queue).
- Privacy: evidence screen says "Read on this iPhone. Photos never leave it."

## Recommendation
Primary: 5 (suggestions feed) on top of a quiet background scan. It has no scan screen to abandon, makes each match explainable (the product's trust problem), and works for new games after launch.
Layer on: 3 (swipe) as the "Review all" mode behind the feed's "Show all" link, which clears a 47-game backlog in minutes without a bulk checkbox list.
Keep 4 as the entry for "Scan settings" and the missing-place prompt for trips. Skip 1 except as a manual "Scan now" fallback. Full 2 (Live Activity, inbox) is the most engineering for the least first-run delight; take only the badge and the incremental pickup.
References (Mobbin, ios): swipe card stack https://mobbin.com/screens/c9812978-5743-41ad-bbc5-117e71d3c928 (talabat); what we found list with "Anything missing?" https://mobbin.com/screens/e8b6e1f2-9246-4409-b66f-8404886674b3 (Rodeo); "Add all" review queue https://mobbin.com/screens/e048afb1-3148-4d6f-acb7-c61385e7971b (Alta); notification list with tab badge https://mobbin.com/screens/1a92d28d-6be4-4ffa-97ce-2b60142cc41a (LinkedIn); "Found 13 so far" import progress https://mobbin.com/screens/3c5dd482-99f8-4a6f-b8fb-68e03a885e2b (Brink); album picker https://mobbin.com/screens/9c5b81b6-17b3-4ece-84e7-f8eb267b4042 (Tripadvisor).

## "More photos" cue on the Other review (Oct 19, 2026, picked C)
Every tile in the three review screens now opens the full-screen pager (shipped in c8ba98dc). The owner picked C, the "See all N photos" link, built the same evening. Three renders in `png/`: `badge-A-pill.jpg` (small +41 pill), `badge-B-dimmed.jpg` (last tile dimmed, big +41, the same cue the game card uses), `badge-C-link.jpg` ("See all 47 photos" link under the grid).
