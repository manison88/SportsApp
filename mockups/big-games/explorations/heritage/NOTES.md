# Heritage badges: the system

A badge is a commemorative pin you earned by being there. It uses generic heraldic shapes, a metal rim and
engraved numerals. It never uses an event logo, trophy, league shield or wordmark style. Source: `build.py` (`badge()`, `T`).

**Anatomy, from outside to inside**
1. Metal rim: a 6–7u band filled with a 6-stop diagonal gradient (gold, silver or platinum), plus a dark bevel line on its inner edge.
2. Field: the event's darkest palette colour.
3. Keyline: a 0.9u metal hairline inset 4u, the "engraved" edge.
4. Motif: drawn by us. Stars, laurel, guilloché, hatch or sash.
5. Name: Barlow Condensed 700 caps at 12–13u, tracked, set straight or on an arc.
6. Numeral: Fraunces 600, metal-gradient fill with a 1.3u dark offset so it reads as struck or engraved.
7. Sub: GAME 5, a year or a match label, in ink colour on the field or an accent band.

**Three levels of detail from one function**
- **hero** (160–200pt): every layer.
- **stamp** (72pt): rim, field, motif and numeral only. Names drop out, so no text falls below 12pt.
- **glyph** (20pt, inside the 28pt **chip**): the shape, rim and motif. The chip label is the event name in ink on the field colour.

**Shape follows format**
- Shield: title series (World Series, Stanley Cup Final).
- Medal on a ribbon in palette stripes: single-game final (Champions League Final, Super Bowl).
- Roundel: tournament match (World Cup).
- Hanging pennant on a metal rod: rivalry.

**A theme is data**
`{shape, metal, field, ink, accent, accent2?, ribbon?, motif, numeral, top, bottom?, sub}`
- Roles: `field` is the badge ground. `ink` is small text, at ≥4.5:1 on the field. `accent` is a band, stripe or sash. `metal` sets the rim, the numerals and the screen's Play button.
- Numerals rule: use the event's own numbering when it has one (LIX). Otherwise use the year (2016). A rivalry uses the scoreline (5–0).
- Small text never uses the gradient. It uses a solid ink: cream, gold #F1D88E, silver #DCE1E7 or platinum #E4E9EE.

**Unthemed events (fallback)**
- Pick the shape by format: playoff or title series gets a shield, a tournament gets a roundel, a one-off final gets a medal.
- Metal: gold for a title, silver for a semifinal or playoff round, platinum for an all-star game.
- Field: the home team's darkest colour. If none passes 4.5:1 with white ink, use #121418.
- Motif: hatch. Numeral: the year. Top: the plain round name ("NLCS", "PLAYOFFS", "ALL-STAR GAME"). Sub: "GAME n".
- No photo: the hero area becomes the field colour with a fine guilloché in the ink colour, and the hero badge is centred (v6).

**Rivalries derive their theme automatically** (`derive_rivalry(home, away)`)
- `field` = the darkest saturated colour of the two clubs (luminance under .15, saturation over .3). The home club wins ties.
- `accent` and `accent2` = the most saturated remaining colour of each club. They become two parallel sashes across the pennant.
- `metal` = gold if either club carries a yellow or gold, otherwise silver.
- `ink` = white if it reaches 4.5:1 on the field, otherwise near-black.
- For El Clásico this gives: field #004D98, sashes #A50044 and #FEBE10, gold rim, white ink.

**Where badges appear**
- Game memory: a hero badge (168pt) pinned at the top-left of the photo, above the title.
- Timeline: a themed card gets a stamp in the top-right corner and a metal hairline ring.
- Passport: stamps in a 3-column grid, with dashed ghost shapes for formats not yet earned.
