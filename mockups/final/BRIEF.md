# Witness · final mockups (one per feature)

This is the last round. The client picked **Broadcast** as the app and wants **one super clean mockup per feature**. Print shop is dropped, which leaves 14 screens.

Read first:
1. `/home/user/SportsApp/mockups/round2/BRIEF.md` for the canonical data and the product context. Its data section is still the source of truth.
2. `/home/user/SportsApp/mockups/round2/system/broadcast.css` for the base system.
3. `/home/user/SportsApp/mockups/final/system/final.css`. Its five rules are law.
4. The round-2 renders named under each screen below: `/home/user/SportsApp/mockups/round2/png/<feature>/v1-cinema.png`, `v2-broadcast.png` and `v3-clean.png`.

## What the votes said

- **Broadcast** was loved on 01, 02, 03, 04, 05, 06, 07, 08, 09, 10 and 14, and liked on 11, 12 and 13. It is the base for every screen.
- **Cinema** was loved on 05, 06, 07, 09, 10, 11 and 14. Take its **photo-led emotion**: full-bleed cinematic heroes on memory screens, and an occasional editorial line.
- **Clean** was loved on 05, 11, 12 and 14. Take its **restraint and air**: fewer elements, generous spacing, one obvious action, and calm list rows instead of boxed tiles. Its **layouts** for 11 (Wrapped) and 12 (Live) won, so rebuild them in the dark Broadcast system.

The client says **"super clean"**. Round-2 Broadcast was bold but busy in places: too many tiles and rows, and tiny 9–10pt labels. Every final screen must be **simpler than its round-2 Broadcast version**: fewer elements, bigger type, more air, the same punch.

## System rules

- Load in this order: `../../../kit/kit.css`, `../../../round2/system/broadcast.css`, `../../system/final.css`. At the end, include `../../../kit/kit.js`.
- Use `<body class="phone b">`. Photos are at `../../../photos/` (only names in `mockups/photos/INDEX.md`). Map libraries are at `../../../kit/vendor/`.
- File name: `v1-final.html` in the existing folder `mockups/final/features/<NN-slug>/` (folders and feature.json already exist; don't edit them). `<title>`: the feature name, e.g. `Game memory`.
- **Top-level tab screens** are 02 Map, 03 Passport, 04 Timeline and 09 You. They use `.b-nav` with a `.f-title` page title on the left and one `.b-icon-btn` on the right, and this exact tab bar (mark the current tab `.on`):

```html
<nav class="b-tabs">
  <span><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="9" rx="2"/><path d="M4 17h16M4 21h10"/></svg>Timeline</span>
  <span><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.4 3.2 14.6 0 18M12 3c-3.2 3.4-3.2 14.6 0 18"/></svg>Map</span>
  <span><svg viewBox="0 0 24 24"><rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="11" r="3.5"/><path d="M9 17.5h6"/></svg>Passport</span>
  <span><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.4-4 4.4-6 8-6s6.6 2 8 6"/></svg>You</span>
</nav>
```

- **Pushed screens** (05, 06, 08, 10, 13, 14) use `.b-nav` with a back `.b-icon-btn` (chevron) on the left and at most one action on the right. **Modal screens** (01, 07, 11, 12) use a close (✕) instead of back.
- **Primary action:** one `.b-btn` (white) per screen at most.
- **Team codes:** CHC/CLE/MIL for baseball; CHI/GB for football. Use `.f-mono` or `.b-bug` with team colors (CHC #2f6bff, CLE #e31937, CHI #f05a1a, GB #ffb612, MIL #ffc52f). No logos, no nicknames.
- **Real-photo signage:** crop so no team "G" banner or big sponsor logo is legible. For Lambeau, prefer the misty stairs region of lambeau-concourse.jpg. Wrigley night photos contain a "209" seat sign: crop it out except on 12, where Sam is in 209.

## The 14 screens

Each screen lists its **base** (start from that render), what to **borrow** from the others, and what to **cut**.

**01 Auto-discovery** (modal onboarding)
- Base: round-2 Broadcast. Giant "47" + "Games in your photos", progress 12 of 47, one World Series G5 card (score bug, a row of 4 matched photo thumbnails with times, Skip / Confirm).
- Borrow from Cinema: the matched photos as the hero of the card (bigger thumbnails, contact-sheet feel).
- Cut: the Up-next list down to 2 rows, or remove it. Keep the "Matched on this iPhone" line.

**02 Map** (tab)
- Base: round-2 Broadcast globe with arcs from Chicago and an amber heat glow, plus the giant "42,900 miles" (loved).
- Cut: the tiny city labels on the globe (keep 3: Chicago, Boston, Madrid). Use `.f-stats` for 21 venues · 3 countries · 60 games instead of boxed tiles.

**03 Passport** (tab)
- Base: round-2 Broadcast giant "14 of 30 MLB parks", the 30-segment bar, and the team-color stamps.
- Borrow from Cinema: its stamps felt more like stamps (round, dated). Make the 14 earned stamps rounded-square team-color tiles with code and date, plus a subtle inner keyline.
- Cut: show the 14 earned stamps in a 3-column grid with large tiles, plus one row of ghost tiles hinting at what's missing, not all 16 missing parks. Keep the sport filter pills.

**04 Timeline** (tab, the home screen)
- Base: round-2 Broadcast. A large photo card "DOWN 3–1. NOT TONIGHT." with a notched ticket strip (date · seat · score bug), and the next card peeking.
- Keep it nearly as is. Tidy the type sizes: the ticket strip labels are at least 11pt.

**05 Game memory** (pushed; all three were loved)
- Base: round-2 Broadcast (Lambeau, "51 YARDS. NO TIME LEFT.", line score, Maya & Leo, Play recap).
- Borrow from Cinema: a taller full-bleed hero (to about y=470) with a softer scrim.
- Borrow from Clean: a clean line-score table with lots of air.
- Cut: the note to one short line. One button: Play recap.

**06 You were there** (pushed)
- Base: round-2 Broadcast (photo with lower third "Taken 40 seconds after the final out", the win-probability curve as scrubber with photo pins, 3 play rows).
- Borrow from Cinema: its curve is elegant; use a thin line with a soft area fill and round photo pins.
- Cut: the play rows to 3 at most, with no boxes, as `.f-list` rows. The final-out row is highlighted white.

**07 Recap film** (modal, mid-playback)
- Base: round-2 Broadcast (full-screen warm Wrigley frame, "DOWN 3–1.", "One more night at Wrigley.", chapter segments, pause, Share as story).
- Borrow from Cinema: its trailer gravitas. Use one subtle quote line under the title, and letterbox or a soft grade.
- Cut: anything beyond title, quote, chapters, controls and Share.

**08 Venue · Wrigley** (pushed)
- Base: round-2 Broadcast (photo hero, "WRIGLEY FIELD", giant "11–6", seat diagram with 314 glowing, first and last visit).
- Cut: make the seat diagram simpler and larger, with only 3 sections lit (314 bright, 209, 112). First and last visit go in one `.f-stats` row. No boxes around it.

**09 You · lifetime stats** (tab)
- Base: round-2 Broadcast giant "61%" on a Chicago-blue field.
- Borrow from Cinema: the line "Chicago wins more when you show up."
- Borrow from Clean: the 60-dot grid (one dot per game: won, lost, drawn, race) as the single supporting visual.
- Cut: the six tiles become two `.f-stats` rows (60 games · 42,900 mi · 21 venues / 487 runs · 19°F coldest · 14 of 30 parks). Nothing else.

**10 Lucky charm** (pushed)
- Base: round-2 Broadcast "YOU VS. THE ODDS" with the dial at +13.
- Borrow from Cinema: its dial was the most elegant; use a thin arc, a needle and a big centered number.
- Then a 61% (blue field) vs 48% (grey) pair, one Maya row (65%), and Share. Nothing else.

**11 Season Wrapped 2025** (modal story card)
- Base: the Clean layout (loved) on a solid Bears-orange full-bleed card. Story progress at top; giant "6–3"; the claim "Chicago won two of every three games you walked into."; one rounded Lambeau "best scene" photo; the credit line "Starring Sam Okafor · with Maya"; Share to story.
- Borrow from Cinema: the movie-poster credit line.
- Use Broadcast type (Barlow Condensed) for the numbers and claim. Dark status bar glyphs are fine if the orange is light; otherwise keep the default white glyphs.

**12 Live check-in** (modal; Clean loved)
- Base: the Clean layout, rebuilt dark. Centered giant score CHC 4 – 3 MIL (MIL dimmed), and between them ▼7th, the base diamond with 2nd lit, and the outs. Add a soft Chicago-blue ambient glow behind it, a single pill "17th Wrigley visit · 17th game with Maya", a compact Live Activity preview ("On your Lock Screen"), and one huge "Save this moment" button at the bottom.
- Cut: anything else.

**13 Shared passport · Maya** (pushed)
- Base: round-2 Broadcast (giant "17" in Maya's pink circle inside Sam's 60 ring).
- Then a 3-row head to head as `.f-list` rows (Win rate 65% vs 61%, Venues, Countries), and one small map strip of shared trips (Lambeau, Spain).
- Cut: extra buttons. At most one action: "Invite Maya" or none.

**14 Trip · Spain 2020** (pushed; all three loved)
- Base: round-2 Broadcast (giant "SPAIN", map of Spain with the route, legs as slim ticket rows, the two games as highlighted score rows, the handwritten quote).
- Borrow from Clean: lighter rows with more air. Legs as `.f-list` rows with a small mode icon (plane or train), the route ORD → BCN in condensed type, and the date right-aligned. The two game rows use a team-color score bug.
- Keep the quote "the last game before the world went quiet." as one line, in a quiet handwritten style.

## Process

- Render with: `cd /home/user/SportsApp/mockups && FEATURES_DIR=final/features OUT_DIR=final/png NODE_PATH=$(npm root -g) node render.cjs <NN-slug>`
- Open every PNG with Read and critique it against the five rules and the question: **"Is this the cleanest version that still feels like Witness?"** Check alignment to the 20pt gutters, consistent nav position (y=56), no clipping, and nothing within 34pt of the bottom except the home indicator and tab bar.
- Iterate until each screen is excellent, usually 2–3 passes.

## Client addendum: no AI slop (overrides anything above)

The client: *"I don't want subheadings everywhere and other typical AI slop."* These are hard rules:

1. **No eyebrows or kickers.** No small tracked-caps label above titles or blocks (e.g. "LIFE MAP · 2014–2026", "HEAD TO HEAD", "UP NEXT", "WHERE YOU SAT"). The title or the content speaks for itself.
   - The only small caps allowed are functional state: LIVE, FINAL, a score bug, and units directly attached to a number ("MILES", "OF 30 MLB PARKS").
   - Budget: **at most one small label per screen**, beyond tab labels.
2. **No subtitle under every title.** A title stands alone. A supporting line is allowed only on the single hero, and only if it adds a fact.
3. **No section headers inside a screen.** Separate blocks with space, not labels.
4. **No filler or marketing copy.** No "Keep buying tickets", "Rare, but real", "Every road starts…", "Your numbers", "Found in 2,814 photos" footers, invented quotes or taglines. Exceptions:
   - The user's own note on 05: one short line.
   - The trip quote on 14.
   - The one-line claim on the 11 share card and 09's single line.
5. **No ornament.** No decorative dots, bullets, sparkles, emoji, "·"-chained metadata strings longer than 2 items, badges, or pills that repeat what's already on screen.
6. **No duplicate information.** If a number is the hero, don't repeat it in a stat row.
7. **Plain words.** Buttons are verbs: Confirm, Skip, Share, Save. Labels are nouns.

## UX checklist (ui-ux-pro-max)

- **Contrast:** all text at least 4.5:1 on its background. No body or label text below rgba(255,255,255,.55) on near-black.
- **Touch targets:** at least 44 × 44pt. Icon buttons are 40pt visual inside a 44pt hit area.
- **Body text:** at least 15pt. The single smallest text is 12pt (data labels only).
- **Icons:** one stroked SVG icon set (24 viewBox, 2px stroke). No emoji or text glyphs as icons (no ✓ ✕ ▶ ❄ characters); draw them as SVG.
- **Color is never the only signal:** W/L uses letters or position, and the selected state has a shape change too.
- **Consistency:** same nav y, same title style, same tab bar, same list rows on every screen.
