# Wrapped revamp: 10 mockups (mockups only, do not build)

Read first: `../BRIEF.md` and `../final/BRIEF.md` (the bar, the kit, fonts, rules: no real team logos, no lorem ipsum, nothing clips or overlaps, check every PNG with the Read tool and iterate 2-3 passes), and `../final/features/11-season-wrapped/v1-final.html` plus its render `../final/png/11-season-wrapped/v1-final.png` (the current Wrapped design, which the client says "sucks"). Design language: dark ink, amber `--signal` is "you", condensed type for numbers, Broadcast feel, super clean. Read the real implementation to see what data exists: `../../Witness/Features/You/WrappedView.swift` (record, games, miles, home ground, big game, coldest, calendar, top five, etc.) and the sample library `../../Witness/Resources/Sample/library.json` (the sample fan Sam, games from 2014 to 2026, Cubs / Bears fan from Chicago). Photos are in `../photos/` (names in `../photos/INDEX.md`).

## What Wrapped is
A year-in-review of the fan's games, opened from the You tab and shareable as story cards. Today it is a single static card with a few stats. The client wants it to feel like a real celebration of the year, and **there must be a way to look at Wrapped for every previous year**, not only the latest.

## Your task
Design **10 different mockups** of the revamped Wrapped. Mix structures, not just skins:
- At least 3 are **story-style** experiences (tap through slides with progress bars at the top: opener, record, the big game, miles, home ground, a photo moment, closer). Show the key slides as separate frames or a clear filmstrip inside ONE html page per mockup, or one slide per file when that reads better; name files so the sequence is obvious.
- At least 2 are **single-scroll reports** (an editorial page you scroll, one big idea per section).
- At least 2 are **hubs / year pickers**: the entry screen that lists every year the fan has games (2014 to 2026) as beautiful cards (cover photo of that year's best game, game count, record, a one-line highlight), tap one to open its Wrapped. Include a way to switch years from inside a year too (a swipeable year strip, a scrubber, or prev/next years).
- The remaining are your best other ideas (a "your year in one poster" view, a calendar heatmap year, a map year, a timeline-of-games year, a comparison with last year, a "streaks and firsts" view).
- Every mockup shows the year switcher or a clear way to reach other years. Where the mockup is a single slide or section, show the current year's number big and the switcher visible.
- Use real numbers from the sample library for a believable year (pick 2025 as the main example; show at least one other year in the hubs with plausible numbers derived from the library). Include honest empty/short states where it fits: a year with only 1 game must still feel good.
- Remember the shareable moment: each mockup should make clear which part becomes a share card.

## Canvas and files
- 393x852 phone pages. `<body class="phone b">`. Your folder is `mockups/wrapped-revamp/features/wrapped/`, so link `../../../kit/kit.css`, `../../../round2/system/broadcast.css`, `../../../final/system/final.css`, photos at `../../../photos/`, and end with `../../../kit/kit.js` (compare with a final mockup's `<link>` lines and adjust for depth).
- Put the 10 files in `mockups/wrapped-revamp/features/wrapped/` named `v1-<name>.html` ... `v10-<name>.html`, `<title>` = a short description, and `feature.json` `{"title": "Wrapped revamp", "summary": "..."}`.
- Render: `cd /home/user/SportsApp/mockups && FEATURES_DIR=wrapped-revamp/features OUT_DIR=wrapped-revamp/png NODE_PATH=$(npm root -g) node render.cjs wrapped`. Look at every PNG and the contact sheet with the Read tool; fix and re-render (2-3 passes).
- **Do not run any git command.** Do not touch files outside your folder.
- Reply with the 10 files, one line each: what it is and why it works. Be honest about weak ones.
