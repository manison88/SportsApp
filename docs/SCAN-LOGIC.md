# How the photo scan decides — an audit (Oct 19, 2026, dcf71364)

Written for the owner before App Review. Plain words. Every number is what the code does today, with the file and
function it lives in. Where the code disagrees with HANDOFF.md or with what Scan check prints, it says so.

The scan has two passes. The **first pass** runs in onboarding and on "Find in photos": it reads every photo's time
and place, groups photos into stadium visits, asks the schedules, and offers games, stadium visits and "possible games".
The **background search** ("Look for more games?") is opt-in and looks through albums and trips.

---

## 1. The rules, in the order they run

### Reading the library

1. **Only still images.** `PhotoMatcher.discover` fetches `PHAsset` of type `.image` only. Videos are never scanned
   (`PhotoMatcher.videos` only adds videos to a game already saved). Live Photos count as images. Burst shots: only the
   picked frame. Screenshots are read and flagged, but the flag is only used by the no-GPS city-day path (rule 22);
   everywhere else a screenshot is an ordinary photo with no location.
2. **Each photo becomes a point**: id, capture date, latitude/longitude (if the photo has one), and the GPS fix's speed
   when the phone recorded one. Photos with no date are set aside and never used.
3. **Photo access**: full or limited both count as "granted" (`PhotoMatcher.requestAccess`). With limited access the scan
   silently sees only the photos the fan picked.

### Placing each photo

4. **Inside the fence**: the nearest stadium whose fence holds the photo. Fence = `Venue.geofence`: 200 m, 260 m for
   65k+ seats, 300 m for 90k+, or a per-venue override (F1 circuits 800–1500 m). `VisitGrouping.nearestVenue` /
   `VenueIndex.nearest`. The index files each venue in every 0.02° cell its fence reaches (`VenueIndex.init`), and the
   pre-filter box is the venue's own fence (never under 320 m) ×1.02.
5. **Near**: not inside any fence but within 500 m of one (`VisitGrouping.matchdayReach`). Joins a visit at that
   ground on that day; cannot start one.
6. **Loose**: everything else — no location, or located but nowhere near a stadium, or on the move (rule 7). Loose photos
   join whichever visit exists on their calendar day (first visit by key order in that time zone), else they form an
   "unplaced day" (only used by album import and the background search).
7. **On the move** (`TransitCheck.moving`): a photo is on the move when its fix's speed is over 40 m/s, or when it and
   the next/previous located photo are ≥1 km apart, ≤5 min apart, and the implied speed is ≥20 m/s. Both ends of such a
   pair are marked. A moving photo never places a visit; it is treated as loose and still joins the day's visit.

### Forming visits (`VisitGrouping.group`)

8. **A visit is one stadium on one calendar day in the stadium's time zone** (key `venueId|yyyy-MM-dd`).
9. **Overnight join**: two visits at one stadium on consecutive local days merge when the gap between the last photo of
   day one and the first of day two is ≤6 h (`overnightGap`). A gap of 6–12 h is not merged but the review asks
   "Same game?" (`possibleSameGame`, `askGap`).
10. **The 15-minute stay** (library scan only; albums pass nil): the visit survives when it has ≥2 anchor photos and the
    first and last are ≥15 min apart. **Anchors here = photos inside the fence plus the day's loose photos** (rule 6):
    a photo taken at home that morning counts, a photo 400 m away at the pub does not. See Finding 1.
11. **Already saved** (`PhotoMatcher.settledKeys`): a stadium-day is skipped before grouping when the library has a game
    there that day that is *not* `awaitsGame` (i.e. it has a schedule match, or teams). A saved **stadium visit**, or a
    game card with no teams and no match, is *not* skipped: its photos are grouped again so a game can be found for them.
    Sample games count as saved (see Finding 14).
12. The visit's `start`/`end` are the first and last of **all** its photos (inside + near + loose), and `insideIds` are
    the in-fence, not-moving photos.

### Asking the schedules (`ScanModel.run` → `ScanModel.match` → `GameLookup.games`)

13. **Which grounds**: the visit's venue first, then its neighbours within 1 km (`PhotoMatcher.neighbors`), one at a
    time; the first ground with a game wins.
14. **Which competitions** (`GameLookup.leagues(for:)`): the catalog's `leagues` list, or a guess by sport and country;
    plus for any soccer ground 9 tournaments (World Cup, Euro, Copa, Gold Cup, Club World Cup, UCL, UEL, Libertadores,
    friendlies) and the confederation's qualifiers/Nations League; for football bowls ≥30k seats and custom venues, the
    5 neutral-ground tournaments. F1 circuits ask the bundled calendar only (no network): a race weekend from its first
    practice day to 29 h after race-day midnight (`F1Calendar.races(at:from:to:)`).
15. **Time window**: from 5 h before the visit's first photo to 1 h after its last (`GameLookup.games`). Because
    `start`/`end` include loose photos, this is usually the whole day (Finding 1). Games are fetched for each venue-local
    day the window touches (`dayStrings`), then filtered to the window and to `venueMatches` (name/alias tokens, same
    city for partial names; neutral tournaments match any soccer-capable ground by city; else city + home team).
16. **Which game when several**: the one whose kickoff is nearest the visit's first photo. A doubleheader is one game.
17. **Source**: downloaded season packs first when they cover every season in the window and the window ends >7 days
    ago (`LocalSchedule.covered`, which also triggers a pack download attempt per league per lookup); else ESPN's site
    API. Network: at most 6 requests in flight (`RequestGate`), each tried up to 3 times on 429/5xx/no response with
    0.6 s, 2.4 s, 5.4 s sleeps, 15 s timeout, and successful pages for days ≥2 days old cached in memory for the launch
    (`GameLookup.fetch`). Tests answer through `GameLookup.responder`.
18. **Concurrency**: 4 visits at a time (`ScanModel.run`, not 6 as HANDOFF says — 6 is the request gate). Then a
    **second serial pass** re-asks every unmatched visit once more.
19. **Merging**: visits that found the same event (the walk in past the ballpark, the match next door) become one card;
    race weekends (Fri/Sat/Sun at a circuit) become one card (`mergeRaceWeekends`).

### Game vs stadium visit vs dropped

20. **Game**: any visit with a schedule match. No dwell rule, no photo-count rule, no scene check — one in-fence photo
    plus the 15-minute stay (rule 10) is enough.
21. **Stadium visit (tour)**: an unmatched visit is offered when ≥3 in-fence, not-moving photos span ≥20 min
    (`PhotoCluster.isStadiumVisit`); otherwise **dropped on the spot** (`skippedVisits`, shown nowhere). A visit at a
    ground that is already a saved visit is neither offered nor dropped — it is left alone (`savedVisitKeys`).
    The `.verifying` state and `verifiedVisits` are set in one synchronous step; "Checking your photos" is never really
    shown for any length of time.

### The "possible game" paths (fan picks the stadium; nothing is added on its own)

22. **Around a ground** (`PhotoMatcher.found` → `ScanModel.nearbyDay`): photos never inside a fence but within 600 m of a
    ground (`nearbyReach`), grouped with the same 15-min stay, ≥3 photos, none of them in a visit, no visit or saved game
    at that ground or its neighbours that day. Newest 40 such days per scan. Offered only when the schedule has a game
    there (or next door) and at least one photo falls from 2 h before kickoff to 3 h after. (Scan check's wording omits
    the kickoff window.)
23. **Matchup albums** (`MatchupAlbums`): an album whose title reads as "A v B" (separators v/vs/x/versus/against/at/@/
    -/–/:/|//; filler like "World Cup", years, emojis dropped; names, native names, codes ≥3 letters) names two known
    teams. Up to 20 such albums, up to the last 4 "outings" per album (runs with no gap >6 h, ≥3 dated photos). Both
    teams' competitions are asked for a game between them from 6 h before the outing's first photo to 6 h after its
    last; the stadium comes from the schedule. Games already in the library by event id are skipped. App/system albums
    ("WhatsApp", "Screenshots", …) are skipped by title words.
24. **City days with no GPS** (`CityDays`): runs of no-location, non-screenshot photos not already on a visit/nearby day,
    no gap >1 h, ≥5 photos over ≥30 min. Dropped if any library game is within −4 h/+2 h of the run. Needs located
    "anchors": photos during the run, or the last one ≤12 h before *and* the first one ≤12 h after; all anchors within
    40 km of each other. Candidate grounds: ≥10k seats, open, with known competitions, within 40 km of every anchor,
    biggest 6. Newest 12 runs per scan. Offered when a game at one of them has ≥5 of the run's photos over ≥30 min in
    its window (1 h before kickoff to 3.5 h after) **and** a 16-photo scene check says stadium (≥3 venue photos, ≥30 %
    of classified, ≥2 showing the structure, <25 % "elsewhere") — `CityDays.looksLikeTheGround`.

### Review queue and ledger (`ReviewQueue`, `ReviewLedger`, `ScanModel.takeForReview`)

25. **Games shown**: a game card is dropped if *any* of its photos is on a saved real game or was skipped *as a game*
    (`dismissedGames`). A stadium visit with the same photos as a game card, or on the same day at the same/neighbouring
    ground, folds into the game. A stadium visit is dropped if any photo is saved anywhere or skipped (any kind), or if
    the library has anything at that ground or next door that day.
26. **Possible days**: dropped if any photo is saved or skipped, or shares photos with a visit already shown, or its
    middle-photo day (phone time zone) is in `dismissedDays`. First offer of a day wins.
27. **Skip** (`ScanModel.dismiss`) writes every photo id and the phone-local day to `review-ledger.json`; `asGame: true`
    only from the game card's Skip. Nothing else is ever removed from the ledger. Added games live in the library.
28. **Persistence**: `review-ledger.json` (skips, forever); `pending-visits.json` (visits waiting for the background
    search — now always written empty, see Finding 6); `deepScanDeclined` in UserDefaults.

### The background search (`ScanModel.startDeepScan` → `GameSuggester.find`)

29. **Claimed days** (phone time zone): every library game's day, every game/visit/possible day already waiting, and every
    dismissed day. These days are skipped by the album and trip step.
30. **Step "visits"**: `pendingVisits` from disk, re-matched next door too, offered as a possible game, else as a stadium
    visit if `isStadiumVisit`. Always empty on current builds.
31. **Step "reading"**: the fan's albums (3–3000 photos, not app albums, first 60), dropping untitled "collections"
    (≥5 photos whose middle 80 % span >60 days, unless the title has a sport word); plus up to 20 trips (stretches >80 km
    from home, gaps ≤36 h, ≥5 photos, padded 6 h) if a home is set. Matchup-titled albums go straight to rule 23 (but
    with `existing: []`, see Finding 10).
32. **Step "sorting"**: an untitled source must have ≥2 venue photos in a 20-photo scene sample. Its unplaced days
    (≥3 photos, not claimed) are queued, newest 150.
33. **Step "days"**: the day's busiest 4-hour stretch must hold ≥3 photos, ≥50 % of the day, ≥20 min
    (`DayShape.looksLikeAnOuting`). Located photos far from every stadium (≥2 and ≥50 % located) rule the day out;
    located photos within 2 km of a stadium name it. Scene check of the stretch (≤24 photos) must show ≥1 venue photo and
    not be mostly elsewhere. Then the schedule: the named/nearby stadiums (+ neighbours) or the title's stadiums, else
    the 4 biggest grounds within 50 km of home; a game must start from 4 h before the stretch to 1 h after
    (`DayShape.covers`). `GameSuggester.confidence` then requires more venue photos the less the schedule said; "no
    game" at a stadium the photos or title point at drops the day, "no game" at home grounds does not. Top 12 by score,
    one per day.

### What Scan check prints (`ScanCheck.report`, from Back up & export)

34. Access level, catalog size, scan state; each located photo's placement and move verdict; what is saved that day and
    whether it settles the day; visits by the scan rule and by the album rule; what the air/road would have placed; the
    ledger and pending counts; around-a-ground days; each visit's schedule answers per ground and per competition;
    albums holding the day's photos and how their titles read; no-location runs with anchors, city and grounds; city-day
    evaluations; and the review verdict per visit. Wording to fix: "Waiting for the background search" is always
    "none" now; "The background search skips this day" is true only for the album/trip step; the around-a-ground line
    omits the kickoff window; the visit rule line says "the day's photos 15+ min apart", which is right but hides that
    photos 10 km away count toward it.

### Where HANDOFF.md is stale

- Lines 28 and 30 both describe the Heathrow fix; line 28 still says photo points carry altitude and a tour needs
  "none from the air". Altitude and the tour scene check are gone (line 30 is right).
- Line 12 and line 25 say the background search starts with "stadium visits with no game" / "waiting visits". The first
  pass now offers or drops those on the spot; nothing waits any more.
- Line 31 "6 at a time" is the request gate; visits are matched 4 at a time.

---

## 2. Findings, ranked

**1. (High) One photo inside the fence + any other photo that day = a game.** Rule 10's stay counts loose photos, and
rule 15's window spans all of them, so a visit built from one in-fence photo at 11:00 plus breakfast at 08:00 and
dinner at 20:00 has a 12-hour "stay" and asks the schedule for a 03:00–21:00 window. Any game at that ground that day
matches, and the game path has no dwell or photo-count gate (rule 20). Scenario: a taxi past Wrigley at 12 m/s (under
the 20 m/s move rule) on a game day, one shot at a red light; or a hotel 150 m from a 300-m-fence bowl where the GPS
drifts once. Result: "Game in your photos" with 3 photos, two of them at home. The World Cup test
`testOnePhotoInsideTheBowlAndTheDayAroundItIsTheMatch` enshrines the one-photo case: there the photo that made the
stay was the fan zone 540 m out, a case worth keeping, but the rule that keeps it also keeps breakfast 9 km away. Fix:
count inside photos and photos within ~600 m toward the stay and the lookup window; let far loose photos join the card
after the match, not drive it.

**2. (High) Offline or throttled, the scan looks stuck and then quietly says "no game".** `GameLookup.fetch` sleeps
0.6 + 2.4 + 5.4 s after each failed try even when the error is "not connected"; a soccer ground asks ~13 competitions ×
2 days ≈ 26 URLs, ×(1 + neighbours), then the second pass repeats it. Twenty visits in airplane mode ≈ several minutes
on "Matching to the schedule", after which real games are offered as stadium visits or dropped, with no message. An
App Review device on a bad connection will see exactly this. Fix: stop retrying on `.notConnectedToInternet`, skip the
second pass when the first failed for lack of network, and tell the fan "N visits couldn't be checked — try again".

**3. (High) Limited photo access is invisible.** `.limited` is treated as granted; iOS will pop its own "Select More
Photos" alert (no `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` key), and the empty screen just says no games were
found. A reviewer who taps "Select Photos" gets a confusing run. Fix: when limited, say so on the empty/denied screen
with a button to `presentLimitedLibraryPicker`.

**4. (Medium) Doubleheaders and two games at one ground on one day are one card.** A visit is one venue-day (rule 8) and
rule 16 keeps the first game. A day-night doubleheader, or a Sounders afternoon match and a Mariners night game next
door when the fan's photos all land at one fence, yields one game and silently loses the other. `Library.sameGame` then
also merges any second card at the same venue within 8 h, so a manual entry for game 2 would fold into game 1 and take
its event id (`merged` copies `source` when the keeper has none). Document as a known limit, or split a visit at a gap
>3 h when the schedule has two games.

**5. (Medium) A skipped day blocks the whole day from the album search.** `dismissedDays` is added to `claimed` (rule 29)
and `ReviewQueue.possible` drops any possible day on a dismissed day. Skipping a 3-photo tour in the morning stops the
evening's real game in an album from ever being offered. Only `dismissedGames` should block games; days should block
only the same photos.

**6. (Medium) Dead code and dead UI left by today's rewrites.** `pendingVisits` is never appended (always `[]` after a
scan), so `waitingDay`, deep step `.visits`, its progress line, and the Scan check line are reachable only for files an
older build left; `deepFraction` still divides by 4 so the bar jumps to ~25 % at once. `ScanModel.notes` and
`.tickets` are never set, so the "I was at the game" block and the "From your ticket" label in `DiscoveryView` never
show. `.verifying`, `verifiedVisits`, `verifyTotal`, `skippedVisits` are set synchronously. `PhotoMatcher.looksLikeAGame`
and `PhotoScan.unplacedDays`/`DayPile` are used only by album import and the background search. `SceneCheck.verdict`,
`fits`, `clearlyElsewhere`, `showsAVenue` survive only for the per-card "doubtful" label and album import; the tour
scene check is gone, as intended. None of this is wrong, but it is where the next bug hides.

**7. (Medium) Per-card review cost.** `DiscoveryView.lookUp` runs OCR on the card's first 8 photos and a 6-photo scene
check for every game card, with iCloud downloads allowed (`isNetworkAccessAllowed = true`). On cellular with
"Optimize Storage" this downloads originals while the fan is tapping Confirm. The scene verdict only produces a
footnote. Consider dropping the scene check from the review entirely.

**8. (Medium) Two games in one city, one of them neutral-ground.** `venueMatches` lets a World Cup / Euro / Copa game
match *any* soccer-capable ground in the same city by city name alone. Fine for Seattle (one such ground), wrong for
London, Los Angeles or Madrid once the catalog has several: a Spurs visit on an England-at-Wembley day reads as the
Wembley game. Low today, grows with the catalog.

**9. (Medium) "Visits so far" and "Photos at stadiums" on the scan screen count drive-bys and flights.** The progress
tally (`PhotoMatcher.discover`) places photos by fence only, before the move and stay rules, so the live number and the
result screen's "Venues"/"Photos at stadiums" stats can exceed what is offered. Honest-numbers promise, not quite kept.

**10. (Low) The background search's matchup step passes `existing: []`** (`GameSuggester.find`), unlike the first pass,
so a saved game is filtered only by claimed day/photos. A game saved from located photos at the ground while the album
has unlocated copies on a different phone-day (late kickoff abroad) can be re-offered.

**11. (Low) Time zones.** Visits and settled keys use the venue's day (right). Ledger days, claimed days and
`PossibleDay.day` use the phone's current zone at scan time. A fan who scans at home for a 10:00 JST Sunday game sees
"Nearest game: a day after your photos" because `gameNear` starts from the phone's calendar day. DST is handled by
`Calendar`; the overnight join is gap-based so a game crossing midnight at the venue is one visit.

**12. (Low) Partner's photos, AirDrop, shared albums.** Any image in the library with EXIF GPS and a capture date is the
fan's own. A partner's shots from a game the fan did not attend become the fan's game. HANDOFF accepts this ("a
friend's shared photos"); worth a line in the App Store notes. Screenshots with no location join the day's visit and
inflate "47 photos" (CityDays excludes them, VisitGrouping does not).

**13. (Low) Performance on 60k photos.** Grouping is tested at 50k in <5 s; the Photos enumeration itself is the
unmeasured part (HANDOFF lists it as open). `ScanCheck.report` regroups the day five times — fine for one day. The
background search classifies up to 20 photos × 80 sources + 24 × 150 days ≈ 5,000 images at 384 px, opt-in and in the
background, but on an older phone that is minutes of CPU with no "stop" button.

**14. (Low) Sample games count as saved.** `settledKeys`, `CityDays.judge` and `startDeepScan.claimed` read
`library.games` including `origin == .sample`; Scan check filters them out. If a fan explores the sample library and
runs Find in photos, the sample games' venue-days are hidden. `DiscoveryView.close` calls `startEmpty` only after adds.

**15. (Low) "Find in photos" during a running background search cancels it silently** (`DiscoveryView.run` →
`scan.reset()`), and the banner offers the search again as if it never ran.

**16. (Low) Default kind for a stadium visit is "Concert".** `DiscoveryView.otherKind` starts at "Concert"; tapping
Add without choosing saves a tour as a concert. "Add all as stadium visits" uses "Stadium visit" — inconsistent.

**17. (Low) An upgraded visit never gets plays/attendance.** `ScanModel.commit` looks up detail by the new entry's id;
when `Library.add` merged it into the saved visit (different id), the detail is dropped.

---

## 3. Test coverage map

| Rule | Covered by | Gap |
|---|---|---|
| 4 fence, index, F1 fences | DetectionTuningTests, F1CircuitTests, AlbumAndScoreboard `testIndexFindsTheSameVenueAsTheLinearSearch` | — |
| 5–6 near / loose join | AlbumAndScoreboard `testTailgateWithin500m…`, `testMatchdayPub…` | loose photos far away driving the stay (Finding 1) |
| 7 on the move | AirborneTests (landing, drive-by, jumping fix, fix speed) | bus/taxi under 20 m/s |
| 8–9 venue-day key, overnight, ask gap | PhotoMatcherTests, AlbumAndScoreboard `testPhotosAcrossMidnight…`, `testNineHourGap…` | DST night; game starting after midnight |
| 10 15-min stay | ScanEndToEnd `testTwoPhotosInsideTheBowl…`, AlbumAndScoreboard `testDiscoveryRuleSkipsDriveBys` | — |
| 11 settled / saved visit rescan | WorldCupSeattle, ScanEndToEnd (b), (c) | sample games as saved |
| 13 neighbours | NeighborGroundsTests, WorldCupSeattle, ReviewQueue `testWalkPastTheNeighbour…` | two real games next door same day |
| 14 competitions per ground | GameLookupTests `testLeagueGuess…`, AlbumAndScoreboard `testWorldCupGameIsFoundAtAFootballStadium` | — |
| 15–16 window, nearest game | GameLookupTests `testScoreboardFindsTheGame…`, `testDaysFollowTheVenueTimeZone` | doubleheader; window spanning loose photos |
| 17 packs, cache, retries | GameLookupTests local schedule + manifest; ScanEndToEnd (d) failed lookup | retry/backoff, offline, 429 |
| 18 second pass | ScanEndToEnd `testAVisitWhoseLookupFailed…` (indirect) | — |
| 19 merge same game / race weekend | ScanEndToEnd `testPhotosAroundTheGroundJoinTheMatchDay`, F1CircuitTests | — |
| 20–21 game vs tour vs dropped | AirborneTests (tour, 2/3 photos, 16/32/40 min, Nurburgring, Coors) | — |
| 22 around a ground | ScanEndToEnd (e) | kickoff-window edge |
| 23 matchup albums | MatchupAlbumTests (14 titles, wrong teams, app album, ledger, scan check) | — |
| 24 city days | CityDayTests (report day, morning only, not a stadium, no game, two cities, screenshots, scan check) | — |
| 25–27 review queue, ledger | ReviewQueueTests, ScanEndToEnd (b)(c), older ledger | skipped day blocking album games (Finding 5) |
| 28 pending-visits.json | AirborneTests `testAnOlderPendingVisitStillReads`, `testTheBackgroundSearchJudgesAWaitingVisit…` | tests a path no build writes to |
| 29–33 background search | AlbumAndScoreboard (time shape, whereabouts, confidence, collections, app albums), WorldCupSeattle next-door | `GameSuggester.find` end to end; trips; claimed days |
| 34 scan check | AirborneTests, WorldCupSeattle, CityDayTests, MatchupAlbumTests, ScanEndToEnd | — |
| Library merge / upgrade | WorldCupSeattle, ScanEndToEnd, AlbumAndScoreboard `testDuplicateGames…`, NationalTeamTests | manual + scan merge within 8 h (Finding 4) |
| UI paths (DiscoveryView, Onboarding) | none (UI tests not in this set) | Skip/Confirm ordering, Add all, combine prompt |

Untested entirely: `TransitCheck` with real `CLLocation.speed` from the library; limited access; videos; `discover`'s
progress tallies; `GameLookup.fetch` retry/gate; `PackStore.ensure` during a scan; `TripFinder`.

---

## 4. Recommendations

Fix before shipping (in this order):

1. **Tighten the game gate** (Finding 1): stay and lookup window from inside + near photos only; a game needs ≥2 inside
   photos, or 1 inside + ≥2 near, within the game's own window. Add a test for the taxi/hotel case.
2. **Offline behaviour** (Finding 2): no retries on no-network, skip the second pass, one honest line in the result
   screen when lookups failed.
3. **Limited access** (Finding 3): say so and offer the picker; add the plist key so iOS stops showing its own alert
   mid-scan.
4. **Skipped day vs skipped game** (Finding 5): stop adding `dismissedDays` to the album search's claimed set; let
   `dismissedGames` alone block games.
5. **Remove the dead paths** (Finding 6): `pendingVisits`/`waitingDay`/step `.visits`, `notes`, `tickets`, `.verifying`,
   and the two stale HANDOFF paragraphs — so the next person reads what the scan actually does.

Leave for now: doubleheaders (document it), neutral-ground city matching (watch the catalog), time-zone cosmetics,
partner photos (App Store note), background-search CPU (opt-in), sample-games-as-saved, the "Concert" default.
