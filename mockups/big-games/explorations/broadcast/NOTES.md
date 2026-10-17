# Broadcast lockup: big-game badges

**Idea.** Every big game gets the title card a network would run before kickoff: a solid color field, a huge condensed edition numeral, the "Witness slash" and the event name stacked behind a thin metal rule. It's all our own type and shapes. No marks, no trophies.

**Anatomy** (left to right): `field` (solid, 8pt corners, 1px inner keyline) · `numeral` (Barlow Condensed 900, −3% tracking, fitted to a fixed box and bottom-aligned) · `slash` (2–3 parallel bars at a fixed 14° lean, full bleed) · `name` (1–2 stacked lines, 800, fitted) · `metal rule` (2px gradient) · `detail` (round · city, 13pt, tracked 1.4).
- **Hero** 160–176pt × full gutter width: all parts. Use it on game memory, recap and share cards.
- **Stamp** 72pt × 104–112pt: numeral, short slash, rule and short name. Use it in Passport and the timeline corner.
- **Chip** 28pt: numeral, mini slash and short name inline. Use it on timeline cards and in lists.

**Theme = data** (`THEMES` in build.py, rendered via CSS variables in system/lockup.css):
- `field` is the ground. `ink` is all text, picked for 4.5:1 or better on the field. `num` is the numeral fill: ink, an accent like SB gold, or `metal` for a metallic clip. `metal` is the gold or silver gradient for the rule.
- `bars` is a list of [(color, width)] for the slash, mostly the official palette (thick accent plus thin counter-color). Rivalries add a third bar.
- `name[]`, `short` (12 characters or fewer for the stamp and chip), `detail`, `numeral`.
- **Numerals rule:** use the official Roman edition when the event numbers itself (Super Bowl LIX). Otherwise use the two-digit year with an apostrophe (’16, ’94). Never a score or a logo.
- **Motif type:** always the slash. Events differ only in color, bar count and metal. That's why the six events read as one package.

**Fallback (no theme on file):** `generic(tier, home_team_color, …)` gives a graphite #1A1D24 field, white ink, a slash in the home team's color plus a white hairline, and a metal rule by tier: gold for title games, silver for playoffs and tournaments. The name is plain text from the schedule ("NLCS", "Conference Final", "Group Stage"). The sheet's last row shows NLCS 2016.

**Rivalry auto-derivation:** `rivalry(home=(primary, secondary), away=(primary, secondary))` sets field = home primary. The slash becomes home secondary, away primary and away secondary, so the bars carry the "versus". Ink is white or near-black by relative luminance against the field (threshold 0.18). Metal is silver. El Clásico: field #004D98 with bars #A50044 / #FFFFFF / #FEBE10.

**No-photo state** (Super Bowl LIX): the hero photo area becomes the theme field, and the slash bars are scaled up to poster size and fade into the page scrim. An "Add photos" button sits under the nav. The timeline card uses the same treatment.

**Motion (recap film intro, about 900ms, then a 2s hold):**
1. 0–180ms: the field wipes in left to right behind a leading accent bar (ease-out-cubic).
2. 120–420ms: the slash bars sweep in from off-left along their 14° axis, staggered by 60ms, and overshoot 4px before settling.
3. 200–520ms: the numeral rises 24px out of a mask at the card baseline (ease-out-expo). It's metal-clipped on SCF.
4. 380–640ms: the name lines slide out from behind the slash, masked at its edge, 40ms apart.
5. 560–860ms: the metal rule draws left to right. A specular glint runs along it once (180ms), then the detail fades up.
- **Exit:** the thick bar widens to cover the card, then wipes off right to reveal the photo or score. The chip and stamp reuse steps 2 and 5 only (300ms) when they appear in lists.

**Rules kept:** body text is 12pt or larger and every text/field pair is 4.5:1 or better (checked: WS 13.8, SB 11.0, gold on purple 6.0, Clásico 8.4). Each screen has one hero (photo plus title card) and three blocks or fewer (headline, line score, Play recap). Sponsor signage is cropped under the card or softened.
