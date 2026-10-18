# "You were there" revamp: mockup brief

Read `../BRIEF.md` first (the bar, the kit, fonts, rules: no real team logos, city names or 2-3 letter codes as typographic monograms, no lorem ipsum, 393x852 canvas rendered @3x, nothing clips or overlaps, check every PNG with the Read tool and iterate 2-3 passes). The design language is the same: dark ink, amber `--signal` is "you", condensed type for numbers, broadcast feel but cleaned up.

## The screen today (and why we are redoing it)
The page is opened from a game ("You were there"). Today: a big photo with a "lower third" (game-clock label like "3:20 AFTER THE GAME"), a win-probability curve under it that you scrub, round dots for your photos, small dots for key plays, then a short truncated list of three key plays. Problems:
1. The whole idea depends on a win-probability curve, which only baseball/football/basketball/hockey have. Soccer and F1 games get no chart at all, just a photo and a list.
2. Labels say nothing: "3:20 AFTER THE GAME", "104 / 104" (a position in a pile of photos).
3. The photo fills the screen but gives no sense of WHEN in the game it was taken or what the score was then.
4. Three truncated plays ("right footed shot f...") and no link between your photos and the plays.
5. No story: arriving, the game, leaving.

## What the new screen must do (every direction)
- Work for EVERY sport from one idea: a time axis made of the game's own clock or phases (soccer minutes, baseball innings, hockey/basketball periods, football quarters). Win probability is an optional extra layer, not the backbone.
- Put the fan's photos ON that axis by the time each was taken, including before the game (arrival, warm-ups, anthems) and after (celebration, leaving). Fans take most photos before and after.
- Scrubbing or swiping shows the photo with the answer to "what was happening": score at that moment, game minute/inning, and the nearest key play ("taken 2 min after the goal"). Never "104 / 104".
- Key plays are readable and complete (no ellipsis): minute, scorer or play, new score. Substitution/delay noise is excluded.
- A summary line that tells the story: photo count, how many during play, how many within a minute of a key play, first and last photo time.
- A strong share moment (the best photo with its score at that instant).
- The header keeps the broadcast score bug (QAT 1 · BIH 3 · FINAL in the top bar). Use real, verified content below.

## Content (use exactly; it is real data)
**Main game (soccer)**: FIFA World Cup 2026, group stage. Wed Jun 24, 2026, Lumen Field, Seattle. Qatar 1, Bosnia and Herzegovina 3. Kickoff 12:00 PT. Attendance 66,925.
Key plays: 29' Goal, Bosnia and Herzegovina 1-0 (Kerim Alajbegovic, right-footed shot from outside the box). 34' Own goal by Mahmoud Abunada (Qatar), 2-0. 42' Goal for Qatar, Hassan Al Haydos from very close range: Bosnia and Herzegovina 2, Qatar 1. 45'+6' Halftime, BIH 2-1. 64' Ermin Mahmic replaces Edin Dzeko. 80' Goal, Bosnia and Herzegovina 3, Qatar 1, Ermin Mahmic. Full time 3-1. (Delays at 23', 55' and 62' for injuries and a drinks break are noise.)
The fan was with the Bosnian supporters group; they took 104 photos between 10:40 and 14:35 (arrival and flags before kickoff, warm-ups, 38 during play, the supporters group photo after the final whistle, 31 after). The best one is the group photo in the stands with the pitch behind it. Fan rooting for Bosnia and Herzegovina (BIH, deep blue/white/yellow, accent #2F6BFF with #F4E04D).
Photos: use the real photos in `../../photos/` (see `../../photos/INDEX.md`) as stand-ins, crop different windows of them for different thumbnails (soldier-soccer, soldier-aerial, camp-nou-aerial and others, see `../timeline-views/build.py` WIN crop table for good windows). Do not invent filenames.

**Second game (baseball, with win probability)**: 2016 World Series Game 5, Oct 30, 2016, Wrigley Field. Chicago 3, Cleveland 2. Down 3-1 in the series. Bryant HR in the 4th; Chapman's 8-out save; Sam's photo was taken 40 seconds after the final out. Fan with Dad, Bleachers Sec 314, 63F clear. Win-probability curve (home Chicago) dips to about 28% in the 6th, climbs to the final out. Use `../../Witness/Resources/Sample/library.json` for that game's plays if useful.

**Edge state**: a game with only 2 photos and no play data (a lower-league match, or a photo-less game). It must still feel intentional, not empty.

## Deliverables per direction
Folder `features/<dir>/` with `feature.json` ({"title": "...", "summary": "one sentence"}) and exactly three screens:
- `v1-soccer-main.html`: the main soccer game, mid-scrub on a strong photo (about 42' / just after the goal), full layout visible.
- `v2-baseball-wp.html`: the baseball game with the win-probability layer used well.
- `v3-sparse.html`: the edge state.
Each file uses the template in `../../BRIEF.md` but with kit paths `../../../kit/kit.css` and `../../../kit/kit.js`, photos at `../../../photos/<name>.jpg`.
Render from `mockups/`: `FEATURES_DIR=ywt-revamp/features OUT_DIR=ywt-revamp/png NODE_PATH=$(npm root -g) node render.cjs <dir>` and look at every PNG. Do not touch other folders. Do not git commit.
Also write `features/<dir>/NOTES.md` (max 12 lines): the idea, the gestures (what scrubbing/swiping/tapping does), how it works for sports without a win-probability curve, how it degrades with 0-2 photos, and a SwiftUI sketch (views/containers to use).
