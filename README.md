# Witness — high-fidelity iOS mockups

A sports memory app, not a tracker. Every game you've been to becomes an artifact: where you sat, what happened while you were there, and your own photos from that night.

This repo holds SwiftUI mockups built on static mock data. There's no networking and no persistence yet.

**Status: phase 1 is ready for review.** The design system, mock data, and screens 3 (Life Globe), 6 (Game memory), and 7 (You were there) are written. The other 12 screens come after review.

> These files were written in a Linux environment with no Swift toolchain, so they have **not been compiled or run yet**. The first build on a Mac may surface small compile errors. See "Build" below.

## Build

Requirements: Xcode 16 or later, iOS 18 SDK.

```sh
open Witness.xcodeproj        # Xcode 16 synchronized folder: every file under Witness/ is included
# or regenerate the project:  brew install xcodegen && xcodegen
```

Run the **Witness** scheme on an iPhone 16 Pro simulator. The app opens on the screen gallery. To jump straight to one screen:

```sh
xcrun simctl launch booted app.witness.mockups -screen 7
```

Launch arguments:

| Argument | Effect |
|---|---|
| `-screen <n>` | Opens screen *n* directly (3, 6, 7 so far) |
| `-noShaders` | Swaps the Metal effects for their static SwiftUI fallbacks |

Each screen file also has a `#Preview`.

## Layout

```
Witness/
  DesignSystem/   Colors, Typography, Spacing, Motion, Materials (grain, glass, scrims), Shaders.metal
  MockData/       *.json and the Codable models + MockStore
  Components/     StadiumPhoto, TeamMonogram, WinProbabilityChart, chips, tab bar, formatting
  Screens/        One file per screen, each with a #Preview
  ScreenGallery.swift
  WitnessApp.swift
Tools/generate_mock_data.py   Regenerates MockData/*.json deterministically
```

## Design rationale

**Cinematic, not utilitarian.** The competitors are list-and-badge loggers. Witness is closer to a film title sequence or a magazine spread: near-black surfaces, film grain, big type, and one signature visual per screen.

- **Dark first, warm neutrals.** The background is `#050506`, not pure black, and every neutral is a warm white (`#F5F1EA`) at stepped opacity. The warmth reads like sodium stadium light and film stock rather than stock iOS gray.
- **Color comes from the teams.** Chrome is neutral. Saturated color appears only where teams do: monograms, score rules, chart fills, and photo tints all come from each game's two team colors. Every team has an `accent` color tuned to read on black, because many team primaries (navy, forest green) disappear on a dark background.
- **Three typographic voices, all built into iOS.** New York (SF's serif) for editorial headlines and pull quotes. SF Compressed Heavy with monospaced digits for scoreboard numerals. SF Pro for UI. Eyebrows use SF Expanded in caps with wide tracking, like a broadcast lower-third. Nothing needs to be licensed or bundled.
- **No marks.** Teams appear as typographic monograms on their color pair, and the UI shows city names only. There are no logos or wordmarks anywhere. Real stadium names and real historical scores are used.
- **Placeholder photos are generative.** `StadiumPhoto` paints believable stadium imagery in `Canvas`: light banks with anamorphic flare, crowd textures, ribbon boards, mowed fields with perspective stripes, snow, bokeh concourses, backlit crowd silhouettes. Each image is deterministic per PhotoKit asset seed and tinted by the game's teams. Scoreboards in the photos show **the score at the moment the photo was taken**. There are no faces and no stock images.
- **Motion is physical.** Springs by default, a parallax/stretch hero, a globe that settles in from deep space, and matched-geometry selection. Linear timing is reserved for ambient loops.

### Signature moments so far

| # | Screen | Signature moment |
|---|---|---|
| 3 | Life Globe | A satellite globe (MapKit imagery, realistic elevation) settles in from 46,000 km. Geodesic arcs run from home to every venue, drawn as three stacked strokes (halo, body, core) whose brightness scales logarithmically with repeat visits. The headline is spelled out in serif: *Sixty games. Twenty-one places. Three countries.* |
| 6 | Game memory | A full-bleed parallax hero that stretches on pull-down. The final score is set like a broadcast bug, with the loser dimmed. Then your note as a pull quote, a scroll-snapping photo strip, a moment rail, and a sparkline teaser for screen 7. |
| 7 | You were there | The win-probability curve (Swift Charts) filled in each team's color above and below 50%, with your own photos hung from it on stems at the exact second they were taken. Tap any photo: *"Taken 40 seconds after the final out."* |

## Design tokens

**Color** (`DesignSystem/Colors.swift`)

| Token | Value | Use |
|---|---|---|
| `ink` | `#050506` | App background |
| `night` | `#0A0A0C` | Scroll content |
| `surface` | `#121215` | Cards |
| `surfaceRaised` | `#1A1A1F` | Chips, raised controls |
| `surfaceHigh` | `#24242A` | Pressed / selected |
| `textPrimary` | `#F5F1EA` | Primary text |
| `textSecondary` | `#F5F1EA` 64% | Secondary text |
| `textTertiary` | `#F5F1EA` 40% | Labels, eyebrows |
| `textQuaternary` | `#F5F1EA` 22% | Footnotes, losing scores |
| `hairline` / `hairlineStrong` | white 8% / 16% | Dividers, card borders |
| `signal` | `#FFB547` | "You" markers, highlights |
| `signalSoft` | `#FFD9A0` | Secondary highlight |
| `live` | `#FF4D3D` | Live / recording only |
| `arc` / `arcHot` | `#FFC870` / `#FFF1D6` | Globe arcs |
| Team `primary` / `secondary` / `accent` | per team (teams.json) | Monograms, gradients, chart fills |

**Type** (`DesignSystem/Typography.swift`)

| Token | Spec |
|---|---|
| `heroTitle` | New York 44 |
| `screenTitle` | New York 34 |
| `sectionTitle` | New York 24 |
| `pullQuote` | New York 21 italic |
| `scoreHero` / `scoreLarge` / `scoreCard` | SF Compressed Heavy 108 / 64 / 40, monospaced digits |
| `statNumber` | SF Compressed Bold 56 |
| `headline` / `body` / `callout` / `subhead` / `footnote` / `caption` / `micro` | SF Pro 17 semibold / 16 / 15 / 14 medium / 13 / 12 medium / 10 semibold |
| `eyebrow` / `eyebrowSmall` | SF Expanded semibold 11 / 9.5, caps, +1.8 tracking |
| Tracking | display −0.6, score −1.5, eyebrow +1.8 |

**Spacing and shape** (`DesignSystem/Spacing.swift`): 4pt grid with `xxs 4`, `xs 8`, `s 12`, `m 16`, `l 24`, `xl 32`, `xxl 48`, `xxxl 64`. The page `gutter` is 22 (wider than stock iOS, for an editorial feel) and `section` spacing is 44. Radii: `small 10`, `photo 18`, `card 28`, `sheet 38`, `chip` capsule. Hero height 560, tab bar 64.

**Motion** (`DesignSystem/Motion.swift`)

| Token | Spec |
|---|---|
| `hero` | spring(response 0.55, damping 0.82) |
| `snappy` | snappy(0.32) |
| `reveal` | spring(response 0.8, damping 0.9) |
| `stagger(i)` | reveal + 0.06s × i |
| `ambientPan` | easeInOut 16s, repeating |
| `globeSettle` | easeOut 2.6s |
| `parallax` | 0.42 × scroll |
| `pressScale` | 0.97 |

**Materials and effects** (`DesignSystem/Materials.swift`, `Shaders.metal`)

| Effect | Shader | Static fallback |
|---|---|---|
| Film grain | `filmGrain` | Canvas noise |
| Stamp foil (screen 4) | `holoFoil` | — |
| Light sweep (screens 1, 11) | `lightSweep` | — |
| Globe halo | `atmosphere` | — |

Also: dark glass panels (ultra-thin material, warm hairline, top sheen), top and bottom scrims, and a vignette. `FX.shadersEnabled` switches between shader and fallback.

## Mock data and how it maps to the real APIs

`Tools/generate_mock_data.py` writes `Witness/MockData/*.json`. Each file mirrors its future source, so going live means swapping `MockStore`'s JSON loader for a network client. The models and UI stay the same.

**Persona:** Sam, Logan Square, Chicago. 60 games across 2014–2026 at 21 venues in 3 countries:

- Chicago: Wrigley, Soldier Field (Bears and Fire), United Center (Bulls and Blackhawks), Guaranteed Rate Field
- Road trips: Fenway, Lambeau, 10 more MLB parks (14 of 30 in total), COTA for the 2021 US Grand Prix
- Europe: a Spain trip to Camp Nou and the Bernabéu in Feb–Mar 2020, and the 4–4 Revierderby in Dortmund

Companions are Maya (daughter, 17 games together), Leo (son), Dana (partner), Dad, and Chris.

`provenance: "verified"` games have their real date, venue, and final score. Examples: 2016 NLCS G6, World Series G3 and G5, the 2015 Stanley Cup clincher, the "double doink" wild-card game, Bears 24–22 at Lambeau on Jan 5, 2025, the 2017 Revierderby, and Clásico 2–0 on Mar 1, 2020. `illustrative` games are plausible filler. For verified games, intermediate play-by-play is approximate, and weather is mock data throughout.

| File / model | Future source | Mapping notes |
|---|---|---|
| `teams.json` → `Team` | MLB Stats API `/api/v1/teams`, NHL `api-web.nhle.com`, TheSportsDB `lookupteam.php`, Jolpica-F1 `/constructors`, StatsBomb team ids | `externalIds` carries each source's key (`mlbStatsApi`, `nhlTriCode`, `theSportsDb`, `jolpicaConstructorId`, `statsBombTeamId`). `colors.accent` and `monogram` are app-owned. |
| `venues.json` → `Venue` | MLB `/api/v1/venues`, TheSportsDB `lookupvenue.php`, Jolpica `/circuits` | Coordinates, time zone, capacity and elevation come from the source. Elevation feeds the 3D flyovers. |
| `games.json` → `Game` | MLB `/api/v1.1/game/{pk}/feed/live`, NHL `/v1/gamecenter/{id}/play-by-play`, TheSportsDB `lookupevent.php`, Jolpica `/{season}/{round}/results`, StatsBomb `events/{match_id}.json` | `home`/`away` map to the boxscore teams with scores. `race` is the Jolpica results shape. `source.endpoint` records the template URL for each game. |
| `Game.events` → `GameEvent` | MLB `liveData.plays.allPlays[]` (`about.startTime`, `result.description`), NHL `plays[]`, StatsBomb `events[]` | Every event carries an absolute `timestamp`, which is how photos are matched to moments. `shortLabel` and `phrase` are app-side enrichment. |
| `Game.winProbability` → `WinProbabilityPoint` | MLB `/api/v1/game/{pk}/winProbability` | Same field names (`homeTeamWinProbability` as a 0–100 percent, `atBatIndex`). Other sports get a series from a model fed by the play-by-play score state. |
| `Game.periods` | MLB linescore innings, NHL periods, quarter and half starts | Used for chart axis ticks. |
| `Game.weather` → `WeatherSnapshot` | Open-Meteo archive `archive-api.open-meteo.com/v1/archive?hourly=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,precipitation&temperature_unit=fahrenheit` | Exact Open-Meteo snake_case keys via `CodingKeys`. `weather_code` is WMO. |
| `photos.json` → `PhotoAsset` | PhotoKit `PHAsset` | `localIdentifier`, `creationDate`, `location` (CLLocation fields), `pixelWidth/Height`, `mediaType`, `mediaSubtypes`, `isFavorite`. `placeholder` stands in for the image until `PHImageManager` is wired up. Matching photos to games uses creationDate within the game window and location within the venue geofence, entirely on device. |
| `Game.memory`, `people.json`, `trips.json`, `profile.json` | App-owned (future SwiftData / CloudKit) | Companions, notes, seat, rating, trips, home location and favorite teams. |
