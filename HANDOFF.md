# Witness: handoff

Last updated 2026-10-17. Branch `claude/witness-mockups-phase1` is the repo default. Remote: github.com/manison88/SportsApp (public).

## What it is
Witness is a SwiftUI iOS 18 app (XcodeGen, `project.yml`) that finds every live game a fan attended from the photos they already have,
matches it to the real schedule (ESPN public API), and keeps Timeline, Map, Passport and Recap. Everything runs on the phone. Dark "broadcast,
cleaned" design. No team, league or event logos or trademarks anywhere: team tiles are abbreviation chips, events are text.

## How work gets verified and shipped
- **GitHub Actions** (`.github/workflows/ios.yml`, macos-15) runs unit + UI tests on every push that touches app code, tests, `project.yml`,
  `ci/**`. Results are published to the `ci-results` branch: `RUN.txt`, `summary.json`, `errors.txt`, `log-tail.txt`, `shots/` (screenshots,
  screen recordings, debug descriptions). Read them with `git fetch origin ci-results; git show origin/ci-results:RUN.txt`. A newer push cancels a
  running run. Mockup-only commits do not trigger it. Last green: 65 of 66 on `c5309d6` before the scene-check fix; `fb286bf` is awaiting its run.
- **Xcode Cloud** (user's Apple account) builds on every push to the branch and sends to TestFlight (internal). Claude cannot see or start it.
  It builds from the COMMITTED `Witness.xcodeproj`, not from XcodeGen. **Whenever a Swift file is added or removed, update
  `Witness.xcodeproj/project.pbxproj` in the same commit** (refresh from `ci-results` or edit by hand like the existing entries). Missing this
  made builds fail silently once (fixed in `95f0392`).
- User preferences: no Terminal steps ever; do not open PRs unless asked; commits end with the Co-Authored-By and Claude-Session trailers; the
  stop hook demands commit + push of everything.

## Built and shipped (all on the branch)
Timeline, Map (sport-colored lines, zoom buttons, expandable), Passport (stadium names), Game memory (photos strip, See all grid, cover photo
chosen by the fan or auto-picked by Apple's aesthetics model), You were there (photos pinned on the win-probability chart, scrub or swipe),
Recap, Venue, Wrapped, Live check-in (finds the game from location and time), Add game (any team vs any team, custom teams with name/code/color,
free-text competition, any venue), ticket import, album import, big-game badges and event themes, 954 venues in 59 countries.
**Onboarding:** welcome (full-bleed photo) -> problem -> solution (one lit photo in a dimmed grid) -> photo access -> a paced five-step scan
(read photos, find stadiums, match to the schedule, check the photos look like a game, build the timeline) -> results in beats -> review games
-> review "Other" (concerts, tours, tailgates). The scan model (`Witness/Services/ScanModel.swift`) owns the pipeline; `ScanProgressView` paces
the display; `DiscoveryView` reviews. Tickets are read during the scan. A game must match the schedule AND the photos must not clearly be
somewhere else (`SceneVerdict.clearlyElsewhere`); thresholds are guesses until real classifier labels are read (see below).

## In flight when this was written
- Four research agents writing data under `Tools/` (no app code): `Tools/teams/` (soccer Europe incl. the Balkans, soccer rest of world,
  "other sports" plus `GAPS.md` for the app) and `Tools/f1/` (circuits, calendar and results 2018 to now, constructors and drivers, `GAPS.md` for race
  weekends). Spec: `Tools/teams/SPEC.md`; validate with `python3 Tools/teams/validate.py <scope>`. Next step: merge into the seed
  (`Tools/build_seed.py`), then generalize the Passport from MLB-only `ballparks.json` to per-league checklists, and make
  `GameLookup.team(from:)` match catalog records by ESPN id instead of creating gray custom teams.
- CI run for `fb286bf`. It adds `testRecordsSceneLabelsForStadiumPhotos`, which attaches the classifier's real labels for stadium photos
  to the run (`shots/scene-*`). Use them to tune `SceneCheck` word lists and thresholds.

## Open items and decisions
1. **Images not loading on the user's phone** (report, cause unknown). `PhotoLoader` was hardened (cache, retries, single resume, failure
   icon). Need: which screens, library or sample photos, Full or Limited access.
2. User must confirm on a rescan: the kid's-room visit (photos taken at home near the United Center on a game day) is no longer a game.
3. Timeline view modes: user to pick. Recommendation: season shelf (default) + cover mosaic. Mockups in `mockups/timeline-views/`.
4. Scan handling beyond onboarding: recommended suggestions feed + swipe review, scope picker in Scan settings. Mockups in `mockups/scan-handling/`.
5. Welcome and onboarding mockups and the user's picks are on the published artifact (private to the user). Built: welcome v1, pages A, scan B.
6. Not built: video in the scan, incremental rescans, Pause on the scan, "Choose photos instead" via PhotosPicker (now "Choose an album instead"),
   F1 race-weekend grouping, event themes for more events, App Store assets (privacy policy, screenshots).
7. Waiting scan numbers are real; only the pace is controlled (minimum time per step, `ScanPacing`).

## Pitfalls learned
- An `accessibilityIdentifier` on a container hides its children's identifiers from XCUITest. Put identifiers on leaf elements, or find by label.
- Simulator launches sometimes show a black screen (flake): re-run failed jobs once before digging.
- Photos permission alerts in UI tests: `allowPhotoAccessIfAsked()` loop. CI seeds photos in `ci/seed_photos.py` (Fenway 2017 game, Wrigley WS5
  2016, Soldier Field 2019-02-12 "other" visit, a downtown photo, a scoreboard with no GPS).
- No Swift compiler in the cloud sandbox: compile errors only show up in CI. Keep changes small and read `errors.txt` first.
- Bundled photo names for samples/onboarding live in `Witness/Assets.xcassets/Photos`.

## Where things are
`Witness/` app; `WitnessTests/`, `WitnessUITests/`; `Tools/` data pipeline and research; `mockups/` all design explorations (onboarding,
welcome-onboarding, scan-handling, scan-waiting, timeline-views, big-games, final); `docs/INTEGRATIONS.md`; `README.md`.


## Parked ideas
See `PARKING_LOT.md`. All six social ideas (Together, Witnesses, Head to head, Circles, Going, Here now) are parked as designs only, with mockups in `mockups/social/`.
