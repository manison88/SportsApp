# Witness mockups, round 2: three directions × 15 features

Round 1 explored 75 screens (15 features × 5 directions). The client voted, and this round turns those votes into **three complete, consistent app directions**, each applied to **all 15 features**: 45 screens in total. The client's words: *"very sleek and eye catchy, super simple to use, minimalistic type vibes."* Every screen must feel like a finished App Store screenshot of one coherent app.

Read `/home/user/SportsApp/mockups/BRIEF.md` (round 1) for the kit, rendering, persona and quality bar. Everything there still applies unless this file overrides it.

## What the votes told us

**Loved:** Cinematic game page, Magazine feed timeline, Trailer recap, Bold Blocks Wrapped and Movie Poster Wrapped. These all share one big photo or one big statement, confident type, dark and cinematic, little chrome. The emotion is pride and nostalgia, a sense of *"I was there."*

**Liked:**
- clean, instantly readable data: Quiet list, Gauge, Heat map, Play-by-play, Editorial stats, Simple flight routes
- broadcast energy used sparingly: Scoreboard, Jumbotron, Broadcast replay, Versus
- light-touch tactility: Ink stamps, Ticket stack, Boarding passes, Contact sheet, Super 8, Postcards

**Passed:** prop-heavy skeuomorphism (patches, enamel pins, coins, scrapbook, museum, photo booth, family tree, trophy shelf), novelty gimmicks (darkroom, ticket printer, radar, fortune teller, coin flip, terminal, clock face, music video), and dense newspaper layouts.

**So, across all three directions:**
- Keep one focal point per screen and plenty of space.
- Use real photography as the emotional hero.
- Make each number read in a second.
- Keep at most one playful touch per screen, and only where it adds meaning (a stamp, a ticket edge). Never a whole prop scene.
- Fewer elements than round 1, with bigger and calmer type.

## The three directions

Each direction has a shared stylesheet in `round2/system/`. **You must use its tokens and components** (classes prefixed `a-`, `b-` or `c-`) for type, buttons, chips, nav and tab bar, so all 15 screens of a direction look like one app. You may add screen-specific CSS, but never redefine the system's type scale or colors.

| | A · Cinema (`cinema.css`, `body class="phone a"`) | B · Broadcast (`broadcast.css`, `body class="phone b"`) | C · Clean (`clean.css`, `body class="phone c"`, `data-chrome="dark"`) |
|---|---|---|---|
| Feel | A film's title sequence. Quiet, emotional, premium. | The best TV sports package, minus the clutter. Live, bold, proud. | Apple Sports meets Things. Calm, effortless, airy. |
| Ground | Near-black, photo-first | Near-black with solid team-color fields | Warm off-white, white cards |
| Display type | Instrument Serif (headlines), Inter Tight numbers | Barlow Condensed 800 uppercase, giant numerals | Inter Tight 700, tight tracking |
| Accent | Amber, once per screen | Team colors as solid blocks; red only for live | Black pill for the primary action; team colors only |
| Signature | Full-bleed photo with serif headline over a scrim | A giant number or score bug and a framed "video board" photo | One large rounded photo or visual, everything else white space |
| Tab bar | `.a-tabs` floating glass | `.b-tabs` docked bar | `.c-tabs` frosted floating |

**Tabs** are the same four in every direction, in this order: **Timeline · Map · Passport · You**, using simple stroked 24-viewBox SVG icons drawn in the same style. Show the tab bar only on top-level screens: 01 (no tabs; it's onboarding), 02 Map, 03 Passport, 04 Timeline, 09 You, 13 (a pushed screen, so no tabs). Detail screens get a back button in the nav instead. Use your judgment on the rest.

## Canonical data (round 1 had inconsistencies, so use exactly these numbers)

**Sam Okafor, Logan Square, Chicago:**
- **Games:** 60, from Jun 14, 2014 to Jul 4, 2026. 43 of them in Chicago.
- **Record (Sam's teams):** 35–22–2, plus 1 F1 race, so **61%** with Sam there versus **48%** when he isn't.
- **Witnessed:** 487 runs, 1,204 points, 162 goals.
- **Travel:** 42,900 miles traveled, 3 countries, 21 venues.
- **Ballparks:** 14 of 30 MLB parks.
- **Extremes:** coldest game 19°F (Lambeau, Jan 5, 2025); farthest trip Spain (4,413 mi).

**Venues (60 games):**
- Wrigley Field 17 (record 11–6, first Jun 14, 2014, last Jul 4, 2026, usual seat Bleachers 314)
- Soldier Field 14 (Bears 10, Fire 4)
- United Center 11 (Bulls 5, Blackhawks 6)
- Guaranteed Rate Field 1, Fenway 1, Lambeau 1
- One game each at Busch, American Family Field, Target Field, Comerica, Progressive, PNC, Great American, Yankee Stadium, Dodger Stadium, Oracle Park and Kauffman (11)
- COTA 1, Camp Nou 1, Bernabéu 1, Signal Iduna Park 1

**Companions:**
- Maya (daughter, b. 2010): **17 games together**, all with Sam; 11–6 (65%), the family's real lucky charm. Color #ff7a8a.
- Leo (son, b. 2012): 15 games, color #6fd3ff.
- Dad (Ray): 11, #8fe3a0.
- Dana (partner): 9, #b79cff.
- Chris (friend): 6, #ffd36e.

**Camera roll:** 2,814 photos scanned on device, **47 games found**.

**2025 season:** 9 games, 6–3, 3 new venues (Lambeau, American Family Field, Target Field), top companion Maya with 5, coldest 19°F, most-photographed moment the Lambeau walk-off.

**Hero games (scores are real):**
- 2016 World Series Game 5, Oct 30, 2016, Wrigley: Chicago 3, Cleveland 2, with Dad. Down 3–1 in the series. Ramírez HR in the 2nd; Bryant HR at 8:34 PM plus two more runs in the 4th; Lindor RBI in the 6th; Chapman's 8-out save; final out 10:42 PM. Sam's photo was taken 40 seconds after the final out. 63°F clear, Bleachers 314. Inning line: CLE 0-1-0-0-0-1-0-0-0, CHC 0-0-0-3-0-0-0-0-x.
- Jan 5, 2025, Lambeau: Chicago 24, Green Bay 22, a 51-yard walk-off FG as time expired. With Maya & Leo. 19°F, light snow, Section 112, Row 41. Quarters CHI 7-7-7-3, GB 0-7-0-15. Attendance 77,412.
- 2016 NLCS Game 6: Chicago 5, Los Angeles 0 (the pennant).
- 2015 Stanley Cup Final Game 6: Chicago 2, Tampa Bay 0.
- 2019 Wild Card: Philadelphia 16, Chicago 15 (the double doink).
- 2017 Revierderby: Dortmund 4, Schalke 4.
- Spain trip, Feb 20 to Mar 2, 2020, with Dana, Maya & Leo: Chicago → Barcelona (Barcelona 5, Eibar 0 on Feb 22) → Valencia → Madrid (Real Madrid 2, Barcelona 0 on Mar 1, "the last game before the world went quiet") → Chicago.
- 2021 US Grand Prix, COTA: Verstappen P1, Hamilton P2.

**Live tonight (feature 12):** Sat Jul 4, 2026, Wrigley, Chicago 4, Milwaukee 3, bottom 7th, 1 out, runner on 2nd. Sam in Section 209. His 17th Wrigley visit and 17th game with Maya.

Team naming stays as before: city names or codes (CHC, CLE, CHI, GB, MIL, BAR, RMA), with typographic monograms on team colors. No logos or nicknames.

## Per-feature synthesis: merge the variations the client liked

For each feature, the liked variations are listed with **what each does for the user** and **its emotion**. Your screen in every direction must fold in the best of each, translated into that direction's system rather than pasted side by side.

**01 Auto-discovery** (onboarding: "We found 47 games in your photos")
- *Contact sheet:* shows the evidence. Your own photos prove the match, which feels like rediscovery.
- *Quiet list:* fast, one-tap confirm with progress, which feels effortless.
- **Merge:** a big count, a row or grid of the actual matching photos for the current game, one game card to confirm (Confirm / Skip), and a calm list of what's next. Note "matched on this iPhone from photo dates and places."

**02 Life map** (top-level Map tab)
- *Glowing globe:* awe at the scale of a life.
- *Flight routes:* legible routes you can actually read.
- *Heat map:* home is where most nights happen, which feels warm.
- **Merge:** one map hero with arcs from Chicago to every venue, brighter for repeat visits, plus a heat glow at Chicago (43 games), and a minimal 3-stat row (miles · venues · countries). Use real geography (d3 and the vendored atlases); a globe or a flat projection is up to the direction.

**03 Stadium passport** (top-level Passport tab)
- *Holo foil:* collectible delight, things worth completing.
- *Ink stamps:* authentic record with dates, like travel memories.
- **Merge:** a progress hero (14 of 30 MLB parks, with a ring or bar) and a clean grid of stamps that carry a real date and look subtly foil or inked. Missing parks are ghost outlines. Elegant, not a prop scene.

**04 Timeline** (top-level Timeline tab, the home screen; the client **loved** Magazine feed)
- *Magazine feed:* editorial photo cards with emotional headlines. Your life as a magazine.
- *Ticket stack:* the tactile record of seat and score.
- **Merge:** a feed of large photo cards with a headline each. Each card has a slim ticket-stub detail strip (date · venue · seat · score, perhaps with a notched edge). Show one hero card and part of the next.

**05 Game memory** (Lambeau, Jan 5, 2025; the client **loved** Cinematic)
- *Cinematic:* full-bleed hero photo and an emotional headline, pure nostalgia.
- *Scoreboard:* the facts at a glance (line score, stats), confidence.
- **Merge:** a cinematic hero and headline, a compact line score by quarter, who you were with, and one note line. Keep it short.

**06 You were there** (World Series Game 5)
- *Win-prob curve:* the drama of the game in one shape.
- *Play-by-play:* context in readable sentences.
- *Broadcast replay:* scrub through the night.
- **Merge:** the win-probability curve doubling as a scrubber with Sam's photos pinned on it, a selected-moment card ("Taken 40 seconds after the final out."), and 2–3 play-by-play rows around that moment.

**07 Recap film**, mid-playback (World Series Game 5; the client **loved** Trailer)
- *Trailer:* cinematic title cards and Ken Burns movement, which gives goosebumps.
- *Super 8:* warmth and home-movie nostalgia.
- *Story slides:* shareable in one tap.
- **Merge:** a trailer-style player with a title card over a photo and a warm grade, chapter progress, and an obvious Share-as-story action. Optionally a 9:16 toggle.

**08 Venue page** (Wrigley Field)
- *Flyover:* aerial wow and sense of place.
- *Blueprint:* precision, the place understood.
- *Seat map:* "here's where I sat," which feels personal.
- **Merge:** an aerial or hero image of Wrigley, the record 11–6 big, and a minimal seating diagram with your sections glowing (314 most). First and last visit.

**09 Lifetime stats** (top-level You tab)
- *Editorial:* huge numbers with a story.
- *Infographic:* playful and scannable.
- **Merge:** one hero number (61% or 60 games) with a one-line story, then a tidy grid of 4–6 stats, each with a tiny bespoke visual (a mini bar, a dot row, a thermometer tick). Calm, not a poster.

**10 Lucky charm**
- *Gauge:* an instant read on whether you're lucky.
- *Versus poster:* bold, you versus the odds, bragging rights.
- **Merge:** a big gauge or dial reading +13 pts, framed as "You vs. the odds: 61% vs 48%", with a share action. Optionally note that Maya is at 65%.

**11 Season Wrapped 2025**, a story card with progress segments (the client **loved** both Bold Blocks and Movie Poster)
- *Bold Blocks:* punchy claims in color blocks, very shareable.
- *Movie Poster:* your season as an epic film.
- **Merge:** a poster-like story card: a full-bleed Lambeau photo or bold color field, a giant claim ("6–3"), a film-credit style line ("Starring Sam Okafor · with Maya"), and a share button.

**12 Live check-in** (Wrigley tonight)
- *Live Activity:* utility at a glance on the lock screen.
- *Jumbotron:* the live score, big and electric.
- *Ambient glow:* the screen feels the game in team color.
- **Merge:** the in-app live screen: giant score, inning and base state, team-color ambient glow, and one huge "Save this moment" button. Somewhere, show a small inset preview of the Live Activity ("on your Lock Screen").

**13 Shared passport with Maya**
- *Venn:* an instant read of overlap.
- *Head to head:* playful rivalry.
- *Braided map:* the roads we shared, which is heartfelt.
- **Merge:** "17 games together" as the hero, with an overlap visual (Venn or two rings), a mini head-to-head row (win rate Maya 65% vs Sam 61%, venues, firsts), and a small map strip of shared trips (Spain, Lambeau).

**14 Trip view: Spain 2020.** The client liked all five (route map, boarding passes, journal, departure board, postcards).
- **Merge:** a route map hero of Spain with stops, then legs as slim boarding-pass cards (ORD→BCN flight, BCN→VLC train, VLC→MAD train, MAD→ORD), with the two games as highlighted stops. Add one small handwritten-journal or postcard touch, such as a single quote: "the last game before the world went quiet." Keep it light.

**15 Print shop** (the 2016 season book)
- *Product shot:* desire, a real object.
- *Tour poster:* graphic pride.
- **Merge:** a photoreal product hero (the hardcover "2016: The Year It Happened") with a segmented toggle for Book · Poster, one or two options (cover color), the price $89, and an Add to bag button. Optionally a small thumbnail of the tour-poster alternative.

## Files and rendering

- Write `mockups/round2/features/<NN-slug>/v1-cinema.html`, `v2-broadcast.html` and `v3-clean.html`, plus a `feature.json` with `{"title": "NN · Name", "summary": "<one sentence on what the merge combines>"}`. Folder slugs: 01-discovery, 02-life-map, 03-passport, 04-timeline, 05-game-memory, 06-you-were-there, 07-recap-film, 08-venue, 09-lifetime-stats, 10-lucky-charm, 11-season-wrapped, 12-live-checkin, 13-shared-passport, 14-trip, 15-print-shop. If the folder or `feature.json` already exists (another builder may own a sibling file), don't overwrite it.
- In each file, link `../../../kit/kit.css`, then `../../system/<cinema|broadcast|clean>.css`, and include `../../../kit/kit.js` at the end. Photos are at `../../../photos/<name>.jpg` (only names listed in `mockups/photos/INDEX.md`). The vendored map libraries are at `../../../kit/vendor/`.
- The `<title>` is the direction name: `Cinema`, `Broadcast` or `Clean`.
- Render with `cd /home/user/SportsApp/mockups && FEATURES_DIR=round2/features OUT_DIR=round2/png NODE_PATH=$(npm root -g) node render.cjs <NN-slug>`. Note the contact sheet only shows the variation files present at render time.
- Review every PNG with Read and critique it hard against the round-1 bar plus: **is this the simplest version that still wows?** Remove anything that doesn't earn its place. Iterate until it's genuinely good.
