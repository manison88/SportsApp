# Parking lot

Ideas that are designed or explored but deliberately not being built now. Nothing here is in the app.

## Social (parked Oct 18, 2026)
Six ideas, 19 mockup screens, privacy rules and backend notes. Overview page: https://claude.ai/artifact/JaEjsWMviVRTusNcFhvzqU (private to the owner). Source: `mockups/social/` (brief in `BRIEF.md`, screens in `features/<idea>/`, renders in `png/`).

Order if it is picked up again: Together, Witnesses, Head to head, Circles, Going, Here now.

| Idea | One line | Backend | Notes |
|---|---|---|---|
| Together | Everyone who went merges their night into one match report, each person's photos on the shared game clock in their own colour. | Heavy (shared photo storage) | Reuses the match report. Default share is nothing. Most wanted. |
| Witnesses | Each game shows how many Witness fans were there, which friends, and your own number ("Witness #212"). | Light (counters) | Anonymous. Cheapest to ship. |
| Head to head | Compare with one friend: totals, shared stadiums, rivalry ledger, friends-only passport race. | Medium | Works with a single friend. |
| Circles | Small private groups with a shared card wall, combined passport and a season challenge. | Heavy | "I was there too" counts people, not likes. |
| Going | Mark upcoming games, see who is going, plan the day; becomes a Together memory after. | Medium to heavy (schedules, push) | Needs a schedule feed. |
| Here now | Live check-in with friends by section, a ping to meet up, and a share log. | Heavy | Highest privacy risk, so last. |

Shared groundwork all six need: Sign in with Apple at the first social action (never at onboarding), a friend invite link, per-friend visibility switches. Rules that hold for every idea: photos never leave the phone unless a person picks them, no public feed, no follower counts, no location shared silently, kids' profiles never shown.

Open facts for a future start: Together and Going need the same "memory with members" record; Witnesses needs an ordered join index per game; the mockup photos are stand-ins and some show real signage.

## Share cards, new variations (parked Oct 18, 2026)
Two rounds of share-card mockups (9:16 story cards), designed but not built. The shipped cards stay as they are. Source: `mockups/share-variants/` (briefs `BRIEF.md` and `BRIEF-2.md`, files in `features/<set>/`, renders in `png/`).

- **Round 1** (baseball-based; rejected for that reason, except the Game set): `game`, `passport`, `venue`, `trip`, `numbers`, `recap`. The client picked Game styles 1 (photo hero, giant score in the sky) and 2 (framed photo, serif score) from this round.
- **Round 2, built for every sport** (the one to start from): `game2` (Game 1 and 2 in soccer, football, basketball), `passport2` (venue count, not "of 30"), `venue2` (generic seating bowl), `numbers2` (My numbers and Lucky charm, sport-mix bar and dot grid). Not redone for all sports: Trip and Recap / You were there (their round-1 sets already used soccer), and Shared Passport was never done.

Open items before building: Bears at Soldier Field is 6-3 in the sample data (the brief said 5-4); the seat sections 118 and 205 and the 42,900 miles are placeholders; Trip miles (9,000) were estimated; the mockup photos are stand-ins (Camp Nou is a miniature model; there are no hockey or racing photos); the giant score has to shrink for two- and three-digit scores.

## Wrapped revamp (parked Oct 18, 2026)
Ten mockups with a way to reach every previous year (story slides, scroll reports, year hubs, poster, calendar, versus last year). Source: `mockups/wrapped-revamp/` (`BRIEF.md`, `features/wrapped/`, renders in `png/`). The Wrapped entry was removed from the You tab; `WrappedView` and `Modal.wrapped` are still in the code. Pick: the swipe-deck hub into the color-block story, with the poster as the share card. Sample numbers for 2025 (5 games, 5-0) and the miles are estimates.

## Printed keepsakes (parked Oct 19, 2026)
Three rounds of print mockups: the passport book, hard tickets and a yearly edition (round 1), thirteen framed prints the owner rejected (round 2), and seven formats for the book itself (round 3), all rendered from the sample library with the app's own stamps. Source: `mockups/print/` (`BRIEF.md`, renders in `png/`).

Pick if it is picked up again: round 3, the **scratch-off passport** or the **sticker album** (they sell before the fan has a history; the album has recurring revenue), with the full-page aerial stamp inside. Vendor: Prodigi for books and prints, a 32 pt card printer in weekly batches for tickets. Blocker: the aerial views are Apple Maps and cannot be printed for sale; a print-licensed map source is needed first.
