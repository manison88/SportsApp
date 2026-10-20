# Witness — handoff (Oct 19, 2026)

Branch `claude/witness-mockups-phase1`. Latest pushed commit: see `git log -1`. Everything below is pushed.
Unit tests: `xcodebuild test -project Witness.xcodeproj -scheme Witness -destination 'platform=iOS Simulator,id=BF1B6818-F1B6-4A92-A11C-5AB81BF15E7D' -only-testing:WitnessTests` (all pass).
New Swift files must be registered: `python3 Tools/add_to_xcodeproj.py <new> <sibling>` (Xcode Cloud builds the committed project).
Another Claude session pushes to this branch: `git pull --no-rebase` before pushing.

## Decisions made (keep these)

- **Onboarding**: Welcome is the tap-paced countdown (Start → Next ×4): 40,000 → 6,400 → 1,284 → 312 → 23, the dot wall narrowing and warming each step, each step one line on what Witness does. Last step: amber dots burst into a 23-tile photo collage, "Every night, back in one place.", Get started. Then the permission screen (dimmed dot wall + amber sweep, ✓ when / ✓ where / 🔒 nothing uploaded, amber Allow). Old problem/fix pages are gone.
- **Onboarding scan**: shows matched games, then stadium visits with no game (tours) when 3+ photos inside the fence, none on the move, span 20+ min (`PhotoCluster.isStadiumVisit`); fewer are dropped, not deferred (the review screen and the ledger filter after that). Photos on the move (20+ m/s between shots 1+ km apart, or a fix over 40 m/s) never place a visit (`TransitCheck.swift`). No altitude rule and no scene check for tours: altitude is terrain as often as flight (the Nurburgring day, Aug 5 2023, read as 43 photos "in the air"), and the move rule alone catches the Heathrow approach.
- **Background search** ("Look for more games?" on the Timeline, opt-in): progress bar with steps; stadium visits with no game first (tours offered as visits), then albums/trips. The schedule decides; only a stadium the photos or album title point at can rule a day out. Matchup titles ("BiH v Qatar") name sides by code. App/AI albums skipped.
- **Shares**:
  - Game: Ticket and Full bleed, aerial icon beside the venue (`Witness/Features/Game/GameStoryCard.swift`).
  - Passport: the page itself (tiles sized to fit, planned included) + Full passport (all sports).
  - Map: Globe, Miles, Grounds, Countries (globe icons) (`Witness/Features/Map/MapStoryCard.swift`).
  - **Venue: From above (#1) and Every game (#5)** (`Witness/Features/Venue/VenueStoryCard.swift`; the other five looks were removed, see d974b4f1 to bring one back).
  - All shares use the WITNESS / SPORTS wordmark (SPORTS amber, offset under).
- **Soccer naming**: Soccer or Fudbal (asked on the soccer passport, changeable on You). American football is always "Football".
- **Sample games**: Timeline banner with Exit back to the welcome.
- **Game page**: + beside the menu adds photos/videos.

## Fixed today, to confirm on device

- BiH v Qatar at Lumen Field: photos were filed at T-Mobile Park (440 m away); neighbours now 1 km, same-game visits merge. A saved stadium visit no longer hides its day from the scan (it is matched again and becomes the game); waiting visits and the background search ask the ground next door. Run Find in photos (no need to delete anything). If it is still missing: Back up & export, Scan check, pick Jun 24 2026, share the report.
- BiH v Qatar, second fix (after the two fixes merged): the review dropped every game whose photos the library had, so the match found again for the saved stadium visit was thrown away. A saved visit (or a game card with no teams) no longer hides its game; skipping a stadium visit no longer hides a game found later for its photos (game skips kept apart in review-ledger.json); days of photos only around a stadium (within 600 m, none inside the fence) are offered as possible games when the schedule had one. Scan check now shows photo access (full/limited), skips, waiting visits, days around a stadium and whether the review would show the match. End-to-end tests: `WitnessTests/ScanEndToEndTests.swift`.
- BiH v Qatar, third fix (the owner's scan check: 118 of 123 photos that day have no location, kept in an album titled for the match): national sides have no home ground, so a matchup title ("BiH v Qatar") pointed at no stadium, the album counted as untitled and only the home stadiums were asked. Now a title naming two teams (codes, names, native names, any separator, emojis/years ignored) asks both teams' schedules (every competition, World Cup included) for a game while the album's photos were taken; the stadium comes from the schedule (`MatchupAlbums.swift`, in Find in photos and the background search). Also: photos with no location on a day the located photos (during, or the last before and first after within 12 h) place in one city are checked against that city's big stadiums' schedules, and offered when 5+ of them fall in a game's window (1 h before to 3.5 h after kickoff) over 30+ min and a 16-photo scene check shows a stadium (`CityDays.swift`, Find in photos, 12 days a scan). Scan check lists the day's albums (title read, game, verdict) and the photos with no location (by hour, city and from which photos, each game's window, scene check, verdict). Tests: `MatchupAlbumTests`, `CityDayTests`.
- Landing at Heathrow offered as "Stamford Bridge · Mar 25, 2026 · 47 photos" (the approach crosses the ground at 1,000 m and the fix put window shots inside the fence; one in-fence fix plus the day's other photos made the 15-minute stay, and one of six sampled photos reading "stadium" made it a tour). Photo points now carry altitude and speed; a photo in the air or on the move never places a visit; a tour needs 3+ in-fence photos of the ground itself, none from the air; the background search judges waiting visits the same way. Scan check shows each photo's altitude and verdict, the visit the air would have made, and the tour scene check. Tests: `WitnessTests/AirborneTests.swift`.
- F1 circuits: the 48 circuits in `Catalog/f1-circuits.json` (25 on the 2025–26 calendars, points at the pit straight / main grandstand, checked against Ergast/Jolpica and Wikidata, fences 800–1500 m) are the motorsport venues; the 11 team factories (Brackley, Maranello, …) are gone from `venues.json` and the F1 teams have no `homeVenueId`. The venue index and `nearestVenue` pre-filtered with a fixed 320 m box, so a photo at a grandstand 1 km from the circuit's point never placed; the box is now each venue's own fence and a venue is filed under every index cell its fence reaches. A race weekend at a circuit comes from the bundled calendar (`F1Calendar`, no network): Silverstone on Jul 6 2025 is the 2025 British Grand Prix. Tests: `WitnessTests/F1CircuitTests.swift`.
- Landing at Heathrow offered as "Stamford Bridge · Mar 25, 2026 · 47 photos" (the approach crosses the ground at 1,000 m and the fix put window shots inside the fence; one in-fence fix plus the day's other photos made the 15-minute stay, and one of six sampled photos reading "stadium" made it a tour). Photo points carry speed; a photo on the move never places a visit; a visit with no game is offered when 3+ in-fence photos span 20+ min, else dropped. (The altitude rule and the tour scene check that came with this fix were removed the next day: the Nurburgring, 300 m above its valley, read as flight and the day was dropped.) Scan check shows each photo's verdict, the visit the road would have made, and the in-fence stay that offers or drops a visit with no game. Tests: `WitnessTests/AirborneTests.swift`.
- Schedule lookups: 6 at a time, retries on throttling, finished days cached, second pass for unmatched visits.
- Scan screen photo strip now really cross-fades (the timer read an empty list).
- Covers: picked at add time, preloaded, cross-faded.
- Team search: debounced, cached folded text.
- Forecast on planned games (within 15 days), Plan a game flow (leagues → teams → schedule → Plan).

## Open / next

- Device-test the background search precision on the real library (was 38 results, ~95% wrong; now much stricter).
- Onboarding scan time on big libraries: per-step timing + a 10k/30k/60k seeded-library test were proposed, not built.
- OTA scan settings (thresholds, word lists, caps) via the signed pack manifest: proposed, not built.
- Monetization: Witness Pro (background search, share looks, Wrapped, widgets, iCloud) + ticket affiliate links on Plan a game. Paywall not designed yet.
- App Store: screenshots (6.9/6.5/6.3 in `AppStore/out/`), header/search images, `AppStore/listing.md` (name options "Witness Sports: …" pending the owner's pick).
- Design canvas with all mockups: https://claude.ai/artifact/KiDAecHeuiF5v6KwN9gQ1a
