# Witness — handoff (Oct 19, 2026)

Branch `claude/witness-mockups-phase1`. Latest pushed commit: see `git log -1`. Everything below is pushed.
Unit tests: `xcodebuild test -project Witness.xcodeproj -scheme Witness -destination 'platform=iOS Simulator,id=BF1B6818-F1B6-4A92-A11C-5AB81BF15E7D' -only-testing:WitnessTests` (all pass).
New Swift files must be registered: `python3 Tools/add_to_xcodeproj.py <new> <sibling>` (Xcode Cloud builds the committed project).
Another Claude session pushes to this branch: `git pull --no-rebase` before pushing.

## Decisions made (keep these)

- **Onboarding**: Welcome is the tap-paced countdown (Start → Next ×4): 40,000 → 6,400 → 1,284 → 312 → 23, the dot wall narrowing and warming each step, each step one line on what Witness does. Last step: amber dots burst into a 23-tile photo collage, "Every night, back in one place.", Get started. Then the permission screen (dimmed dot wall + amber sweep, ✓ when / ✓ where / 🔒 nothing uploaded, amber Allow). Old problem/fix pages are gone.
- **Onboarding scan**: shows matched games, then stadium visits with no game (tours) when a few photos clearly show the stadium. Everything else waits for the background search.
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

- BiH v Qatar at Lumen Field: photos were filed at T-Mobile Park (440 m away); neighbours now 1 km, same-game visits merge. Delete the game and run Find in photos to confirm.
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
