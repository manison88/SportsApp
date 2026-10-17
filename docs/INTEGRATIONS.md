# Getting games into Witness: what's possible, and what it costs

The goal: a fan should never have to type a game in by hand unless they want to. The sources are tickets they bought (Ticketmaster, StubHub, SeatGeek, AXS, team apps), photos they took, and manual entry.

## Verdict

**Building and testing all of this costs $0.**
- The repo is public, so GitHub Actions macOS runners (Xcode, simulators, UI tests) are free.
- Every data source below is free or on-device.

The only cost is **$99/year for the Apple Developer Program**, needed only to ship to TestFlight or the App Store. Running on your own iPhone from Xcode is free with a personal team, re-signed every 7 days.

## Ticket marketplaces

| Source | Can we pull a user's purchased tickets? | Why |
|---|---|---|
| **Ticketmaster** | **No (not without a partnership)** | The free Discovery API returns *events* (date, venue, teams), not a user's orders. Order and account APIs are partner-only, and there's no "Sign in with Ticketmaster" for third parties. |
| **StubHub** | **No** | The public API was shut down; access is partner-only. |
| **SeatGeek** | **No** | The free public API returns events and venues only. |
| **AXS, team apps** | **No** | There's no public consumer API. |
| **Apple Wallet** | **No** | `PKPassLibrary` only exposes passes signed with *our* pass type ID, never Ticketmaster's. |
| **Email confirmations (Gmail API)** | **Possible, not free at scale** | The read scope is "restricted", so Google requires a paid third-party security assessment before public launch. Forwarding to an inbox needs a server. |

So a direct "connect your Ticketmaster account" button isn't possible for free, or without a business partnership. **What every ticket source does produce is something the user can hand us**: a screenshot of the ticket, a PDF, the confirmation email text, or a shared Wallet pass. We read those on-device, for free.

## What we build (all free, all on-device)

1. **Ticket import (OCR).**
   - The user picks a ticket screenshot or a PDF, shares it to Witness, or pastes the confirmation email text.
   - Apple's Vision text recognition reads it on-device. `TicketParser` then extracts the date, time, teams, venue, section, row and seat, and pre-fills the Add Game form.
   - It works for Ticketmaster, StubHub, SeatGeek, AXS and team apps alike, because it reads what's on the ticket rather than calling their APIs.
2. **Photo matching (PhotoKit).** Photos carry a capture time and GPS location.
   - **Discovery** scans the library and clusters photos that were taken inside a stadium geofence on the same day, giving "We found N games in your photos". Confirm each with one tap.
   - **Attach** pulls every photo taken at that venue during the game window onto the game.
   - Nothing leaves the phone.
3. **Manual add.** A form covers sport, teams, venue, date, score, seat, who you were with, a note and photos.
   - The venue comes from the built-in stadium catalog, from Apple Maps search (`MKLocalSearch`, free), or is created by hand with a map pin.
4. **Score lookup.** The **MLB Stats API** is free and needs no key. When an MLB game's teams and date are known, the final score fills in automatically.
   - Same pattern later: NHL `api-web.nhle.com`, Jolpica-F1 and TheSportsDB, all free.
5. **Live check-in.** CoreLocation detects that you're inside a stadium. "Save this moment" stamps the time, and those moments become the game's photos and timeline.

## Phase 2 (free, but not in tonight's build)

- **Share Extension** so "Share → Witness" works straight from the Ticketmaster or Mail apps. It needs an extra target and App Group; the import logic is already built.
- **`.pkpass` import** from Wallet's share sheet. A pass is a zip containing `pass.json` with the event date, venue and seat.
- **Live Activity** on the Lock Screen during a game, via a widget extension and ActivityKit.
- **Ticketmaster Discovery API** (free key, 5,000 calls/day) to turn "date + venue" into the exact event name and opponent.
