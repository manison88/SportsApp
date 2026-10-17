# Witness welcome: six clean variations
All: ink background, one primary "Get started", one quiet "Explore sample games" link (44pt), no logos. "Add a game" moves
to onboarding page 3 / Settings. Sample data (CHC 3 CLE 2, 47 games, Jun 14 2025) is labeled "Sample" on screen.
1. v1 Full-bleed photo: Wrigley night, headline bottom-left. Warmest, closest to today.
2. v2 Type only: 5-line stack, amber YOU, thin champagne stub outline. Boldest, no asset cost.
3. v3 Ticket: tilted oversized stub (photo, tiles, score, venue, date). Shows the product output.
4. v4 Mosaic: 9 dimmed photos fading to ink. Says "your camera roll"; busiest.
5. v5 Stamp: champagne passport stamp (CHC tile, venue, date), small wide-tracked WITNESS. Most distinctive.
6. v6 Scoreboard: amber "47 GAMES" (sample), sport-color bar. Strong idea, but a new user has 0 games.

## Copy (3 headlines / 3 sub-lines each, pair by order)
v1: Every game you were at. | Your seat. Your night. | The games you were at, kept.
    Found in the photos you already have. | Witness finds it. Nothing leaves this iPhone. | A timeline built from your own photos.
v2: Every game you were at. | You were there. | Prove you were there.
    Private, on this iPhone. | Now there is proof. | Your photos already hold the evidence.
v3: Every game you were at. | Your camera roll holds tickets. | Keep every night.
    One ticket per night, found for you. | Witness turns them into games. | Matched from your photos, stored on this iPhone.
v4: Every game you were at. | Your photos, sorted into games. | Thousands of photos. Every game.
    Found in the photos you already have. | Venue, date and score, found for you. | Witness finds the nights that mattered.
v5: Every game you were at. | Stamp every stadium. | Been there. Keep it.
    Stamped from your photos. | Your passport, built from photos you took. | Each game, venue and date, on this iPhone.
v6: Every game you were at. | How many have you seen? | Your number, found.
    Counted from your own photos. | Witness counts them for you. | Games, venues and teams from your camera roll.
## Recommendation: v1 (full-bleed photo)
Proven current structure, one idea, a real night photo says "sports, mine" in one glance, no sample-data caveat, lowest
build risk. Runner-up v3 if we want the output visible; keep v6 for a recap (needs real games). Copy: "Every game you
were at." / "Found in the photos you already have." / button "Get started".
## SwiftUI (v1), reuse
PhotoView(ref: .bundled("wrigley-night")) + Scrim() (ignoresSafeArea); headline .displayFont(68).textCase(.uppercase), "you"
in amber (Text + Text); .buttonStyle(.primary) "Get started" -> onboarding page 1 (TabView .page); plain 44pt Button
"Explore sample games" (library.loadSample()). Remove lock label, Add a game, icon. Rename id welcome-photos to welcome-start.
## Dark-mode only, safe areas, Dynamic Type
- .preferredColorScheme(.dark). Photo and Scrim ignore safe areas; text/CTA block sits in safeAreaInset(.bottom) with 20pt
  gutters, clear of the status bar, Dynamic Island and home indicator.
- Headline is display art: fixed 68pt, minimumScaleFactor(0.6), lineLimit(3); it does not scale with Dynamic Type. Sub-line,
  button and link use text styles. At the largest accessibility size the sub-line wraps to 4+ lines, the button label wraps to
  2 lines (min height 56, never fixed), the link grows. Use ViewThatFits: drop the sub-line first, then ScrollView with the CTA
  block pinned; the button and exit always stay. Check white on Scrim >= 7:1, link (66% white) >= 4.5:1.
Files: features/welcome/v1..v6.html (+welcome.css), png/welcome/v1..v6.png, png/welcome.png, png/welcome-sheet.png (5000px). Mobbin: none.
