# Witness — handoff (Oct 19, 2026, evening)

Branch `claude/witness-mockups-phase1`. Latest pushed commit: see `git log -1`. Everything below is pushed unless marked **in flight**.
Unit tests: `xcodebuild test -project Witness.xcodeproj -scheme Witness -destination 'platform=iOS Simulator,id=BF1B6818-F1B6-4A92-A11C-5AB81BF15E7D' -only-testing:WitnessTests` (161 pass).
New Swift files must be registered: `python3 Tools/add_to_xcodeproj.py <new> <sibling>` (Xcode Cloud builds the committed project).
Another Claude session pushes to this branch: `git pull --no-rebase` before pushing.

## In flight (two agents, worktrees under `.claude/worktrees/`, branches not pushed)

- **Logic review** → writes `docs/SCAN-LOGIC.md` (the pipeline as numbered rules with thresholds and file:function, findings ranked, test-coverage map, ≤5 fixes before shipping). Read-only; commit the doc when it lands.
- **OTA scan settings** → branch `claude/ota-scan-settings`: `Witness/Services/ScanSettings.swift` (every threshold/cap/word list, defaults = today's values, `clamped()`), loaded from a signed `scan-settings` pack entry via `PackStore` when newer, persisted; services read `ScanSettings.current`; Scan check prints `settings v<n> (built-in | pack)`; `Tools/packs/build_packs.py` signs `scan-settings.json`. Merge, run tests, push, then ship a change by editing the JSON + bumping version + `build_packs` + publish.
- Owner's ask behind both: review the logic once more **before the next App Review submission**, and make the matching tunable without a release.

## The scan, as shipped (plain rules; thresholds will move to ScanSettings)

1. **Place each photo**: inside = within the ground's fence (200 m default; circuits 800–1500 m; the index box is the venue's own fence, filed under every cell it reaches); near = within 500 m (joins a visit, can't start one); grounds within 1 km are neighbours.
2. **On the move** (`TransitCheck.swift`): fix speed > 40 m/s, or consecutive photos ≥ 1 km apart within 5 min (≥ 20 m/s). Never places a visit. **No altitude rule** (terrain read as flight at the Nurburgring) and **no scene check for tours** (owner: not worth it).
3. **Visit**: ≥ 1 in-fence on-foot photo + the day's photos within reach, spanning 15+ min. A saved real game skips the day; a saved stadium visit is re-checked so a game can replace it.
4. **Schedule**: every competition the ground hosts, −5 h / +1 h around the photos, the ground and its neighbours; 6 lookups at a time, retries, finished days cached; F1 from the bundled calendar (`F1Calendar`, offline).
5. **No game** → stadium visit if ≥ 3 in-fence photos over ≥ 20 min (`PhotoCluster.isStadiumVisit`), else dropped.
6. **Other ways in**: matchup-titled albums (both teams' schedules, every competition; `MatchupAlbums.swift`); photos around a ground (600 m, 3+, 15+ min) on a game day; no-GPS photos on a day the located ones put you in one city (5+ over 30 min in a game's window + scene check; `CityDays.swift`, 12 days a scan).
7. **Review**: games, then possible games (fan picks the stadium), then stadium visits. Each candidate once; adds and skips persist (`review-ledger.json`); a skipped visit never hides a game found later for the same photos. Background search skips days with anything saved.
8. **Scan check** (You → Back up & export → Scan check, a plain row now): prints all of the above for one day. It found every bug today; ask for it first.

## Decisions made today (keep these)

- Review screens fit the phone: Possible game checks the likeliest stadium as it opens (game + Add there without a tap), stadium rows carry a chevron, the bar always has a primary; Other: one-line title, Skip/Add pinned, "Add all" a line above. Every photo tile opens the full-screen pager; with > 6 photos, "See all N photos" (owner picked C of three mockups, `mockups/scan-handling/png/badge-*.jpg`).
- Game page toolbar: Play, +, ⋯ in one toolbar item (tight); the group has its own identifier `game-toolbar`.
- Venue share: "games", not "nights".
- Team picker: racing teams show their name (Mercedes), not the factory town; the "whose stadium" list is a team list by design.
- National teams: any national side merges into the catalog team by ESPN id (or FIFA code in an international competition); pack duplicates (`uefa-*`) dropped; libraries fold existing duplicates on load (`mergeNationalDuplicates`). Follow-up: `Tools/packs/build_packs.py` still emits the 55 `uefa-*` rows.
- F1: circuits from `Catalog/f1-circuits.json` are the motorsport venues; the 11 factories are gone; teams have no `homeVenueId`.
- Live check-in lists stadiums within 20 miles (was 5).
- Printed keepsakes and the recap redesign are parked: `PARKING_LOT.md`, `mockups/print/`, `mockups/ywt-revamp/features/replay/RESEARCH.md` (pick: Replay — one segment per moment, score bug, scrub dock; step 1 is making today's film skippable).

## Fixed today, to confirm on device

- BiH v Qatar (Lumen Field, Jun 24 2026): found via the album title "BiH v Qatar" (no located match photos). USA v BiH found the same way. Confirm both are in the Timeline.
- Stamford Bridge from a plane (Mar 25 2026) must not come back; Nurburgring (Aug 5 2023) must be offered as a stadium visit. Run Find in photos; Scan check on either date shows why.
- Bosnia: one team after relaunch; games/favorites rewritten to `Bosnia-Herzegovina`.
- Tours/results no longer shown twice; skips persist.

## Open / next

- **Instagram announcement video** (`brag-output/`): draft rendered (`brag-draft.mp4`, 20 s, 1080×1920, music + SFX, Hyperframes composition in `brag-output/composition/`, `npx hyperframes check` passes). Owner's verdict on the draft: "atrocious" — reason not yet given (asked: look / pacing / copy / sample-data screens / draft quality). Proposed redo: one big phone, the app in use from the owner's real screen recording + screenshots (Timeline, USA v BiH page, Passport Soccer, Map, the 71% You screen), almost no overlaid words. Do not re-render until he says which.
- Device-test background search precision on the real library.
- Onboarding scan time on big libraries (10k/30k/60k seeded test proposed, not built).
- Monetization: Witness Pro + ticket affiliates; printed keepsakes parked.
- App Store: screenshots in `AppStore/out/`, `AppStore/listing.md` (name pending).
- Design canvas with all mockups: https://claude.ai/artifact/KiDAecHeuiF5v6KwN9gQ1a
