# Timeline game card: 10 tweaks

Read `../BRIEF.md` first (bar, kit, fonts, rules: no real team logos, city names or 2-3 letter codes as monograms, no lorem ipsum, 393x852 @3x, nothing clips, check every PNG with the Read tool, 2-3 passes). Same design language: dark ink, amber `--signal` is "you", champagne `--trophy` for title games, condensed type, broadcast feel.

## The card today (see `current.png`, from the real app)
Timeline home screen: large-title "TIMELINE", a search field, then one card per game, 22pt radius, 16pt gutter:
- Photo area 420pt tall: the game's best photo (or a generated backdrop), dark scrim at the bottom, a huge condensed headline bottom-left (winner first: "CHICAGO 5, MILWAUKEE 4."; display 54pt, up to 3 lines), a small event badge top-left for big games (World Series, Stanley Cup Final...), champagne keyline around the whole card for championship games.
- Ticket stub below (92pt, perforated top edge, notched corners): date ("JUL 4, 2026"), seat section ("SEC 314") when known, and the score bug on the right (away tile + score, home tile + score; rooted team's tile highlighted).
The user likes it and wants tweaks: move text around and add other useful info. Keep the DNA (photo-led, ticket stub, huge headline) in every variant; each variant changes a few things with intent.

## Data you can show (all of this exists or is easy to compute)
Date and time, venue name and city, seat (section/row), score, W/L for the side you rooted for and your record at that venue, competition or stage (Group stage, World Series Game 5), photo count and cover photo, companions (initial avatars: Maya, Leo, Dana, Dad, Chris), weather (temp, condition), attendance, trip name, "first time at this venue" or visit number ("Wrigley #17"), season/streak facts, F1 podium, game length, whether tickets are attached.

## Persona and sample content (Sam Okafor, Chicago)
Use these three cards in every variant, each rendered in that variant's treatment:
1. Chicago 5, Milwaukee 4. Sat Jul 4, 2026, Wrigley Field, Chicago. Section 314 bleachers. Sunny 84F. With Dana and Dad. 63 photos, cover `wrigley-scoreboard.jpg`. Sam's 17th game at Wrigley, 12 wins. Rooted for Chicago (CHC blue #2F6BFF, MIL gold #F4C24B).
2. 2016 World Series Game 5, Oct 30, 2016, Wrigley Field. Chicago 3, Cleveland 2. Down 3-1 in the series. With Dad. Bleachers Sec 314. 63F clear. Cover `wrigley-night.jpg` (crop a crowd-only window). Big game: championship keyline, "World Series" badge.
3. A game with no photos: Chicago Bulls vs Los Angeles (Clippers), Fri Jan 3, 2025? Use Bulls 104, Lakers 118 loss at United Center, Section 105, no photo (generated backdrop, tinted tile). And an F1 or soccer example if your variant needs it: US Grand Prix, Oct 24, 2021, COTA, Verstappen P1.
Real photos: `../photos/*.jpg` (list in `../photos/INDEX.md`; `../timeline-views/build.py` has good crop windows). Stand-ins; avoid crops showing real ad logos where you can.

## Deliverables per tweak
Folder `features/<NN-slug>/` with `feature.json` ({"title": "short name", "summary": "one sentence on what changed and why"}), two screens, and `NOTES.md` (max 6 lines: what moved/added, why, what data it needs, any risk like a longer card or a crowded stub):
- `v1-main.html`: the Timeline screen (status bar from the kit, large title, search, tab bar not needed) showing card 1 in full with the top of card 2 peeking; this is the hero view.
- `v2-states.html`: the same treatment on card 2 (the big game) and card 3 (no photo), stacked, shorter crop is fine, so the states are visible. Header and search may be dropped here; make it read as a scroll position.
Kit paths from `features/<NN-slug>/`: `../../../kit/kit.css`, `../../../kit/kit.js`, photos `../../../photos/<name>.jpg`. Render from `mockups/`: `FEATURES_DIR=timeline-cards/features OUT_DIR=timeline-cards/png NODE_PATH=$(npm root -g) node render.cjs <NN-slug>` and look at every PNG. Keep generator scripts inside your own folders. Do not touch other folders. Do not git commit.
