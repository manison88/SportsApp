# Witness social: mockup brief

Read `../BRIEF.md` first (the bar, kit, fonts, rules: no real team logos, city names or 2-3 letter codes as typographic monograms, no lorem ipsum, 393x852 canvas @3x, nothing clips or overlaps, check every PNG with the Read tool and iterate 2-3 passes). Same design language as the rest of the app: dark ink, amber `--signal` is "you", condensed type for numbers, broadcast feel, cleaned up. Look at `../ywt-revamp/png/match-report/v1-soccer-main.png` and `../final/` for the current look and match the quality.

## Product constraints (non-negotiable, show them in the UI where natural)
- Witness finds the games a fan attended from the photos on their phone. **Photos never leave the phone** unless the person picks specific ones to share. Matching stays on-device.
- Social is **optional and opt-in**. No account to use the app. Identity is created only at the first social action (Sign in with Apple, a display name, a color). Never show a feed of strangers' photos. Crowd numbers are anonymous aggregates.
- Location is never shared silently; anything live is explicit, time-boxed and visible ("Sharing until the final whistle").
- Friends only by invite link / contacts, no public discovery of people. Kids' accounts (Maya, Leo) are never shown socially.
- Tone: warm, a little proud, never a feed full of likes. Reactions are one tap and meaningful ("I was there too"), no follower counts.

## Persona
Fan: Sam Okafor, Chicago (amber `--signal`). Friends/people: Chris Dunn (college friend, #ffd36e), Dana Reyes (partner, #b79cff), Ray Okafor (dad, #8fe3a0), plus Jordan Park (#6fd3ff), Priya Nair (#ff7a8a), Marcus Bell (#ff9f5a). Initials avatars only, no face photos.
Real games to use (verified): FIFA World Cup 2026 group stage, Wed Jun 24 2026, Lumen Field Seattle, Qatar 1 Bosnia and Herzegovina 3, attendance 66,925 (goals 29', 34' own goal, 42', 80'); 2016 World Series Game 5, Oct 30 2016, Wrigley Field, Chicago 3 Cleveland 2; 2015 Stanley Cup Final Game 6, Jun 15 2015, United Center, Chicago 2 Tampa Bay 0; Week 18 Jan 5 2025 Lambeau, Chicago 24 Green Bay 22; US Grand Prix Oct 24 2021 COTA. Upcoming (for "Going"): invent plausible future games with real stadium names (no real ticket prices claims).
Photos: real photos in `../photos/` (see `../photos/INDEX.md`; use only listed files; crop windows as in `../timeline-views/build.py` WIN). They are stand-ins; some show real logos, so prefer crops that avoid them or blur small signage. Stats/numbers must be internally consistent.

## Deliverables per idea
Folder `features/<dir>/` with `feature.json` ({"title","summary"}) and 3 screens named `v1-<slug>.html`, `v2-<slug>.html`, `v3-<slug>.html` showing the idea's key moments (listed in your task), plus `NOTES.md` (max 12 lines: the idea, why people want it, the first-use / empty state, privacy handling, how it plugs into existing screens (Timeline, game page, You tab, match report), and the minimum backend it needs). Kit paths from `features/<dir>/`: `../../../kit/kit.css`, `../../../kit/kit.js`, photos `../../../photos/<name>.jpg`.
Render from `mockups/`: `FEATURES_DIR=social/features OUT_DIR=social/png NODE_PATH=$(npm root -g) node render.cjs <dir>` and look at every PNG. Put any generator scripts inside YOUR OWN folder (never in /tmp or a shared path: parallel agents overwrite each other). Do not touch other folders. Do not git commit.
