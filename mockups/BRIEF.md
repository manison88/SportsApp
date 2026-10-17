# Witness mockups: build brief

**Witness** is an iOS app that turns every live game a fan has attended into a cinematic, emotional keepsake. It covers where they sat, what happened while they were there, and their own photos from that night. It's multi-sport: MLB, NFL, NBA, NHL, soccer and F1. Competitors (Futbology, BoxdSeats, Sports Passport) are list-and-badge loggers. Witness wins on **beauty**, and its share outputs are its marketing.

We are exploring **15 features × 5 design variations**. Each variation is a genuinely different visual direction for the same feature, not a recolor. Each one is a single high-fidelity iPhone screen that should look like a shipped App Store screenshot.

## The bar

Ask of every screen: **would Apple feature this?** Reference quality: Luma, Once, Oura's year review, Polarsteps, Apple Sports, Arc, Things, Airbnb.

- One clear signature visual moment per screen, and a strong focal point.
- Real hierarchy: one dominant element, then a secondary layer, then quiet details. No walls of equal-weight boxes.
- Generous, consistent spacing on a 4pt grid. Side gutters are 16–24pt and the same on both sides.
- Type is set with care: tight display leading, tracked caps for eyebrows, tabular numbers for scores, no orphans.
- Contrast: body text must be readable. Low-opacity text is only for tertiary labels.
- **Nothing overlaps by accident, nothing clips, no text wraps awkwardly.** Check the bottom ~90pt (home indicator) and the top ~54pt (status bar).
- It must feel like a real, populated app. Use specific, true-sounding content from the persona below, never lorem ipsum, "Title", or "Lorem".
- No real team logos or wordmarks, and avoid nicknames as branding. Teams are city names ("Chicago", "Green Bay") or 2–3 letter codes (CHI, GB, CHC, CLE), drawn as typographic monograms on their two colors. Real stadium names and real historical scores are fine.

## Files and kit

Each variation is one standalone HTML file: `mockups/features/<NN-feature>/v<N>-<slug>.html`. The `<title>` is the variation's short display name (2–3 words). Each folder has a `feature.json`: `{"title": "NN · Feature name", "summary": "one sentence"}`.

Use this template:

```html
<!doctype html>
<html><head><meta charset="utf-8"><title>Variation name</title>
<link rel="stylesheet" href="../../kit/kit.css">
<style> /* all screen styles here, absolute positioning is fine */ </style></head>
<body class="phone">            <!-- add data-chrome="dark" on light backgrounds for black status-bar glyphs -->
  ...
<script src="../../kit/kit.js"></script>
</body></html>
```

**Canvas:** 393 × 852 pt, rendered @3x. The kit injects the status bar (9:41) and the home indicator, so don't draw your own. Keep tappable content clear of y < 54 and of the bottom 34pt.

**`kit/kit.css`** provides:
- Tokens: `--ink #050506`, `--surface #121215`, `--text #f5f1ea`, `--text-2/3/4`, `--signal #ffb547` (amber "you" accent), `--paper #f3ece0`, plus team colors (`--chc`, `--chi-bears`, `--gb`, `--bulls`, `--hawks`, `--fire`, `--bar`, `--rma`, `--bvb`).
- Font stacks, all real fonts loaded from Google Fonts:
  - `--f-ui` Inter, `--f-tight` Inter Tight, `--f-grot` Space Grotesk
  - `--f-serif` Instrument Serif, `--f-fraunces` Fraunces, `--f-dm` DM Serif Display
  - `--f-cond` Barlow Condensed, `--f-anton` Anton, `--f-bebas` Bebas Neue, `--f-black` Archivo Black
  - `--f-mono` JetBrains Mono, `--f-type` Special Elite (typewriter), `--f-hand` Caveat, `--f-marker` Permanent Marker
- Helpers: `.glass` (iOS dark glass), `.btn-circle` (40pt round button; put a 24-viewBox stroked SVG inside), `.eyebrow`, `.mono-badge` (monogram tile), `.grain` (film-grain overlay div), `.paper-tex` (paper texture overlay div), `.tnum`, `.nowrap`.
- `img.ph` is a cover-fit photo. Add `.graded` for the cinematic grade or `.bw` for black and white.

**`kit/kit.js`** must be included. It injects the chrome, waits for fonts and images, and paints generative canvases:
`<canvas class="photo" data-style="…" data-seed="7" data-accent="#hex" data-secondary="#hex" data-board="CHI 24|GB 22" data-sport="hockey">`, sized by its parent. The styles are `diamond nightField pitch dayGame snowGame lightTower crowd celebration scoreboard concourse arena skyline trackside tailgate`. Prefer real photos. Use generative canvases for small thumbnails, a scoreboard showing a specific score, or when no real photo fits.

**Maps:** use real geography. Include `kit/vendor/d3.min.js`, `kit/vendor/topojson-client.min.js` and an atlas script: `kit/vendor/countries-110m.js` / `land-50m.js` / `states-10m.js`. Each sets `window.__atlas['countries-110m']` (etc.) to TopoJSON. Then draw with d3-geo into an SVG: orthographic globe, Natural Earth, or Albers USA, with great-circle arcs via `d3.geoInterpolate` or GeoJSON LineStrings. Run drawing code synchronously in an inline script after these includes. If you need to run after layout, define `window.afterPaint = async () => {...}` and the kit awaits it before signaling ready.

**Photos:** real photos live in `mockups/photos/*.jpg` (Wikimedia Commons, free licenses; credits in `photos/CREDITS.md`). Reference them as `../../photos/<name>.jpg`. **Only use filenames listed in `photos/INDEX.md`.** Don't download new images.

**Render and check:** from `mockups/`, run `NODE_PATH=$(npm root -g) node render.cjs <NN-feature>`. This writes `png/<NN-feature>/v*.png` (1179×2556) and `png/<NN-feature>.png` (a contact sheet of all 5). **Open every PNG with the Read tool and critique it hard against "The bar"** for spacing, alignment, clipping, overlaps, contrast, and whether it looks premium. Fix and re-render until each one is genuinely good. Expect two or three passes per screen.

## Persona and content (keep it consistent across screens)

- **Fan:** Sam Okafor, Logan Square, Chicago. Member since 2026 and has logged 60 games over 2014–2026 at 21 venues in 3 countries.
- **Venues:** Wrigley Field ×17, Soldier Field (football ×10 and Chicago Fire soccer ×5), United Center (Bulls ×5, Blackhawks ×6), Guaranteed Rate Field, Fenway Park, Lambeau Field, 10 other MLB parks (14 of 30 MLB parks in total), Circuit of the Americas, Camp Nou, Santiago Bernabéu, and Signal Iduna Park (Dortmund).
- **Miles traveled:** 42,900. **Home win rate with Sam there:** 61% (the "lucky charm").
- **Companions:** Maya (daughter, b. 2010, **17 games together**, color #ff7a8a), Leo (son, b. 2012, color #6fd3ff), Dana (partner, #b79cff), Dad / Ray (#8fe3a0), Chris (college friend, #ffd36e). Use initials avatars on those colors. No photos of faces.
- **Real games (verified scores):**
  - 2016 World Series Game 5, Oct 30, 2016, Wrigley: Chicago 3, Cleveland 2, with Dad. Down 3–1 in the series. Chapman's 8-out save, Bryant HR in the 4th. Sam's photo was "taken 40 seconds after the final out." Weather 63°F, clear. Bleachers Sec 314.
  - 2016 NLCS Game 6, Oct 22, 2016, Wrigley: Chicago 5, Los Angeles 0. The pennant.
  - 2015 Stanley Cup Final Game 6, Jun 15, 2015, United Center: Chicago 2, Tampa Bay 0. Cup won on home ice.
  - Week 18, Jan 5, 2025, Lambeau Field: Chicago 24, Green Bay 22. 51-yard walk-off FG as time expired. With Maya & Leo. 19°F light snow. Sec 112 Row 41. Quarters CHI 7-7-7-3, GB 0-7-0-15.
  - NFC Wild Card, Jan 6, 2019, Soldier Field: Philadelphia 16, Chicago 15 (the "double doink").
  - Revierderby, Nov 25, 2017, Dortmund: Dortmund 4, Schalke 4 (4–0 at 25 minutes).
  - Spain trip, Feb–Mar 2020, with Dana, Maya & Leo: Barcelona 5, Eibar 0 at Camp Nou (Feb 22, 2020, four goals from one player), then the Clásico, Real Madrid 2, Barcelona 0 at the Bernabéu (Mar 1, 2020), "the last game before the world went quiet." The route was Chicago → Barcelona → Valencia → Madrid → Chicago.
  - US Grand Prix, Oct 24, 2021, COTA, with Leo & Chris: Verstappen P1, Hamilton P2 (+1.333s), Pérez P3. Driver codes are fine.
  - Opening Night, Apr 5, 2015: St. Louis 3, Chicago 0. Inter Miami 4, Chicago Fire 1 on Oct 4, 2023 at Soldier Field (62,000 came for one player, and he didn't play).
- **2025 season (for Wrapped):** 9 games, 6 wins, 3 venues new to Sam. Top companion Maya (5 games). Coldest: 19°F at Lambeau. Most-photographed moment: the Lambeau walk-off.

## Variation definitions

Each feature folder lists its five variations below. The slug is in parentheses. Make each one distinct and fully committed to its direction.

01-discovery: **Auto-discovery from your camera roll** ("We found 47 games in your photos", matched on-device from photo dates and locations, confirm or skip each)
1. Darkroom (darkroom): photos developing in a red-lit tray become game cards as they match.
2. Ticket printer (ticket-printer): each match prints as a thermal ticket stub; swipe to keep or toss.
3. Radar sweep (radar): a sonar map pings stadiums as games are found while the count ticks up.
4. Contact sheet (contact-sheet): the camera roll as a film contact sheet with matched frames circled in grease pencil.
5. Quiet list (quiet-list): minimal; games fill in one at a time with a single confirm. Fast, no theatrics.

02-life-map: **Life map / globe** (every venue, plotted from home)
1. Glowing globe (glowing-globe): an orthographic dark globe with light arcs from Chicago that brighten with repeat visits.
2. Flight routes (flight-routes): an airline-magazine route map, flat, with dashed great-circle routes.
3. Transit diagram (transit-diagram): venues as stops on a subway-style diagram, one line per sport.
4. Pin board (pin-board): a corkboard map with pins, string between trips, and pinned polaroids.
5. Heat map (heat-map): no lines, just glowing heat where you've spent the most game nights.

03-passport: **Stadium passport** (a stamp per venue, progress like "14 of 30 MLB parks")
1. Holo foil (holo-foil): metallic iridescent stamps in a dark grid, frozen mid-tilt shimmer.
2. Ink stamps (ink-stamps): real passport pages with smudged, crooked rubber stamps and dates.
3. Patches (patches): embroidered venue patches on a denim jacket or backpack.
4. Enamel pins (enamel-pins): glossy pins on a felt board, with ghost outlines for missing ones.
5. Coin set (coin-set): minted coins in a velvet display case, with a tray per sport.

04-timeline: **Timeline of memories**
1. Magazine feed (magazine-feed): big photo-led cards with editorial headlines.
2. Ticket stack (ticket-stack): a fanned stack of ticket stubs, one per game.
3. Calendar wall (calendar-wall): years as grids of days, with game days lit in team colors.
4. Film reel (film-reel): a vertical film strip, one frame per game, with the year on the edge.
5. Scorebook (scorebook): hand-ruled scorebook pages, pencil style.

06-you-were-there: **"You were there" moments** (your photos matched to the game's moments; use 2016 WS G5)
1. Win-probability curve (win-prob-curve): photos pinned on the curve at their timestamps.
2. Play-by-play (play-by-play): the play log with your photos dropped in between plays.
3. Broadcast replay (broadcast-replay): a TV replay scrub bar with your photos as thumbnails.
4. Clock face (clock-face): the game as a ring, with photos placed around it.
5. Split screen (split-screen): your photo on top, the on-field moment below.

07-recap-film: **Recap film player mid-playback** (auto-made short film of one game)
1. Trailer (trailer): cinematic, big title cards, letterbox, Ken Burns.
2. Broadcast intro (broadcast-intro): TV-graphics style with a score bug and swooshes.
3. Super 8 (super-8): grainy home movie with light leaks and warm frames.
4. Story slides (story-slides): tap-through slides made to share.
5. Music video (music-video): beat-synced cuts with a waveform, the score ticking up on the drops.

08-venue: **Venue page** (use Wrigley Field: 17 visits, record 11–6, first visit Jun 14, 2014, last Jul 4, 2026)
1. Flyover (flyover): an aerial hero with your record overlaid.
2. Blueprint (blueprint): a technical drawing with your seats marked.
3. Postcard (postcard): a vintage travel postcard with stats on the back.
4. Seat map (seat-map): the seating chart with every seat you've sat in glowing.
5. Field guide (field-guide): an encyclopedia entry (opened 1914, capacity 41,649) with your notes.

09-lifetime-stats: **Lifetime stats** (win rate when attending, runs/goals/points witnessed, miles, coldest game, longest trip)
1. Editorial (editorial): huge numbers and serif headlines like a magazine data story.
2. Card back (card-back): baseball-card-back stat tables with a "rookie year".
3. Infographic (infographic): an illustrated, playful poster.
4. Terminal (terminal): a monospaced data readout.
5. Trophy shelf (trophy-shelf): stats as trophies and plaques.

10-lucky-charm: **Lucky charm** (team record with Sam there versus not: 61% vs 48%)
1. Fortune teller (fortune-teller): a tarot-card reveal of your luck rating.
2. Gauge (gauge): an analog needle from "jinx" to "lucky charm".
3. Coin flip (coin-flip): the record as stacks of heads and tails coins.
4. Versus (versus): a fight-poster "You vs. the odds".
5. Simple bars (simple-bars): two clean bars, with and without you.

11-season-wrapped: **Season Wrapped 2025** (shareable story cards; show the story UI with a progress bar)
1. Bold blocks (bold-blocks): Spotify-style color-blocked bold claims.
2. Yearbook (yearbook): a yearbook page with superlatives.
3. Movie poster (movie-poster): the season as a film poster with credits.
4. Card pack (card-pack): trading cards flipped from an opened pack.
5. Special edition (special-edition): a special-edition newspaper.

12-live-checkin: **Live check-in** (at a game right now: Wrigley, tonight, Chicago 4, Milwaukee 3, bottom 7th; venue detected)
1. Live Activity (live-activity): the lock screen with a Live Activity and a "save moment" action.
2. Jumbotron (jumbotron): the phone becomes a mini scoreboard.
3. Capture (capture): one giant "save this moment" button.
4. Gate scan (gate-scan): check-in styled as scanning your ticket at the gate.
5. Ambient glow (ambient-glow): the screen glows in the team's color and pulses on runs.

13-shared-passport: **Shared passport with Maya** (17 games together)
1. Venn (venn): two circles of games, shared ones in the middle.
2. Head to head (head-to-head): "Sam 60, Maya 17", a two-player scoreboard.
3. Family tree (family-tree): games branching by who came.
4. Photo booth (photo-booth): a photo-booth strip of shared moments.
5. Braided map (braided-map): two colors of arcs braided where you went together.

14-trip: **Trip view: Spain, Feb–Mar 2020**
1. Route map (route-map): a drawn route with game stops, cities and photos.
2. Boarding passes (boarding-passes): each leg as a boarding pass.
3. Travel journal (journal): a Moleskine itinerary with sketches and stamps.
4. Departure board (departure-board): split-flap letters for each stop.
5. Postcards (postcards): a stack of postcards, one per city.

15-print-shop: **Print shop** (order a hardcover 2016 season book or a poster)
1. Product shot (product-shot): a photoreal book on a table.
2. Spec sheet (spec-sheet): a technical print layout with what you'll get.
3. Bookshelf (bookshelf): your books on a shelf, one spine per season.
4. Frame builder (frame-builder): pick a frame, mat and layout with a live preview.
5. Tour poster (tour-poster): a minimalist poster listing your games like a concert tour.
