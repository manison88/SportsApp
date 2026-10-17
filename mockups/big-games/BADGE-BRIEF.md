# Big-game badges: design brief (shared by both UI agents)

Witness is a dark "Broadcast, cleaned" iOS app for every game a fan attended. Big games (title games, playoffs,
tournaments, rivalries, All-Star) get themed visuals. We have NO license for event logos, so we design OUR OWN badge
system that feels as official as possible using:
- the event's OFFICIAL COLOR PALETTE (exact hex values)
- the event's name as plain text, edition numerals and year ("SUPER BOWL LIX", "WORLD SERIES 2016")
- shapes, patterns and type we draw ourselves

## Hard legal line (do not cross)
No reproductions or close imitations of: the Lombardi Trophy, the Stanley Cup, the Commissioner's Trophy, the Larry
O'Brien trophy, the World Cup trophy, the UEFA "starball" (8 black-and-white stars in a ball), any league shield, any
event logo lockup or wordmark styling. A generic cup/trophy pictogram (SF Symbol style) is fine. Stars, stripes,
bunting, numerals, laurels, shields and roundels as GENERIC shapes are fine.

## Read first
- /home/user/SportsApp/mockups/final/BRIEF.md (rules: one hero, ≤3 blocks, 20pt gutters, ≥12pt text, no slop)
- /home/user/SportsApp/mockups/final/system/final.css and /home/user/SportsApp/mockups/round2/system/broadcast.css
- The first pass: /home/user/SportsApp/mockups/big-games/build.py and the render
  /home/user/SportsApp/mockups/big-games/png/event-themes.png (Read it). Your job is to go well beyond it.

## The six reference events (real games, use these facts)
1. World Series 2016 Game 5 — Wrigley Field, Oct 30 2016, CLE 2 CHC 3. Photo wrigley-night.jpg. Palette: navy #0C2340, red #C8102E, cream #F4EFE3 (refine if you know better).
2. Stanley Cup Final 2015 Game 6 — United Center, Jun 15 2015, TB 0 CHI 2. Photo united-center-court.jpg. Palette: platinum/silver gradient, black.
3. UEFA Champions League Final 1999 — Camp Nou, May 26 1999, Bayern 1 Man United 2. Photo camp-nou-aerial.jpg. Palette: midnight navy #081548, silver.
4. FIFA World Cup 1994 opening match — Soldier Field, Jun 17 1994, BOL 0 GER 1. Photo soldier-soccer.jpg. Palette: red #C8102E, blue #002868, white.
5. Super Bowl LIX — Caesars Superdome, Feb 9 2025, PHI 40 KC 22. No photo of this venue: design the no-photo state. Host palette: purple #4B2A7B, gold #F2B705, green #0B7A3E.
6. El Clásico "La Manita" — Camp Nou, Nov 29 2010, FCB 5 RMA 0. Rivalry: both clubs' colors (Barça #004D98/#A50044, Madrid #FFFFFF/#FEBE10).

## Deliverables (in your own folder, mockups/big-games/explorations/<your-direction>/)
1. `features/badges/` HTML pages rendered by our renderer (see below):
   - v1: the BADGE SYSTEM sheet: all six badges at three sizes — chip (28pt tall, in lists/cards),
     stamp (72pt, passport/timeline corner), hero (160–200pt, game memory / recap / share card).
   - v2–v7: one Game memory screen per event (393×852 phone, like the first pass) using the badge + palette.
   - v8: a Timeline screen with two themed cards (World Series + Super Bowl) and one normal card.
   - v9: a Passport screen showing stamps that wear the badge treatment.
2. `NOTES.md`: the system in ≤40 lines, covering:
   - badge anatomy
   - how a theme is specified as data: palette roles (field, ink, accent, metal), motif type, badge shape, numerals rule
   - how it degrades for an event we have no theme for (generic title / playoff / tournament)
   - how a rivalry derives its theme from the two clubs' colors automatically
3. Render: `cd /home/user/SportsApp/mockups && FEATURES_DIR=big-games/explorations/<dir>/features OUT_DIR=big-games/explorations/<dir>/png NODE_PATH=$(npm root -g) node render.cjs`
   Pages need `<script src="../../../../../kit/kit.js"></script>` at the end (adjust ../ depth so kit.css, kit.js and
   ../photos resolve; each folder level adds one ../), and must set nothing else for readiness (kit.js sets window.__ready).
   Read your PNGs back and fix anything broken before finishing.

Quality bar: it should look like a premium broadcast graphics package (think the Apple Sports app, ESPN and Sky
Sports graphics, and Nike-level type), not clip art. Restraint: the photo and the score are still the heroes.
