# Witness scan logic — review against HANDOFF.md "The scan, as shipped"

Read-only review of branch `claude/witness-mockups-phase1` at `fed094d2` (Oct 19, 2026). No source changed.
Line numbers are from that commit. "HANDOFF" = `HANDOFF.md` rules 1–8.

## 1. The pipeline as numbered rules

Each rule: what the code does, the constants as written, where, and a one-line note where the code differs from HANDOFF.

**R1. Read the library.** Every image asset, newest first; a `PhotoPoint` per asset (date, lat/lon, screenshot flag, fix speed). Progress every 1,000 photos; 40 recent in-fence ids kept for the strip.
`PhotoMatcher.swift:discover` (:177–224), `PhotoPoint.speed(of:)` `VisitGrouping.swift:16`.

**R2. Place each photo.**
- *inside* = within the venue's own fence: `Venue.geofence` = `geofenceMeters` if set, else 300 m (capacity ≥ 90,000), 260 m (65,000–89,999), 200 m (default). `Models.swift:123–130`. Circuits carry `geofenceMeters` from `Resources/Catalog/f1-circuits.json`: 48 circuits, **700–1,500 m** (HANDOFF says 800–1,500).
- Index: 0.02° cells; a venue is filed under every cell its fence box reaches; box = max(320 m, fence × 1.02) with a 0.1 floor on cos(lat). `VenueIndex` `VisitGrouping.swift:80–130`. Nearest venue whose fence holds the point wins (`nearest`, :110–128; linear twin `nearestVenue`, :257–269).
- *near* = within `matchdayReach` 500 m (`VisitGrouping.swift:136`): joins a visit that day, cannot start one (:171, :199–203).
- *neighbours* = venues within 1,000 m (`PhotoMatcher.swift:neighbors`, :96–99).
- Note: HANDOFF says "200 m default"; code has the 260/300 tiers.

**R3. On the move.** `TransitCheck.moving` (`TransitCheck.swift:25–43`): fix speed > `vehicleSpeed` 40 m/s (:10, :29); or consecutive located photos with 0 < Δt ≤ `movingWindow` 300 s, distance ≥ `movingDistance` 1,000 m and speed ≥ `movingSpeed` 20 m/s (:14–16, :33–41) — both ends flagged. A moving photo goes to `loose` (`VisitGrouping.swift:163`): it never places a visit but **does** join the day's visit as one of its photos (:222–232) and counts toward the stay (see R4). No altitude rule, no scene check for tours. Matches HANDOFF.

**R4. Visit.** `VisitGrouping.group` (`VisitGrouping.swift:147–252`), called from `PhotoMatcher.found` (:152) with `minimumStay` 15 × 60 (:152, :157; `looksLikeAGame` :299 is the same 15 min, unused by the scan).
- Key = `venueId|yyyy-MM-dd` in the venue's time zone (:165, `DayKeyer` :59–75). Keys in `skipping` (settled days, R6) are dropped at placement (:166).
- Consecutive-day visits at one venue join when the gap between last and first photo ≤ `overnightGap` 6 h (:140, :178–196); 6–12 h (`askGap`, :273) is asked about in the review (`possibleSameGame`, :277–286).
- Photos with no fix, and photos on the move, that fall on a visit's local day join that visit (:206–232). Day lookup is by zone, then **first sorted key** wins when two visits share a day (:210–214).
- The stay test (:236–238): the visit's in-fence photos **plus every adopted photo** (no-GPS, on-the-move, anywhere else that day) must contain ≥ 2 points ≥ 15 min apart. Photos *near* (≤ 500 m) are added only after (:239) and do not count.
- Note: HANDOFF R3 says "≥ 1 in-fence on-foot photo + the day's photos within reach, spanning 15+ min". Code: photos **within reach do not count**; photos **outside reach (and on the move) do**. See F1.

**R5. Skipped days.** `settledKeys` (`PhotoMatcher.swift:230–235`): saved entries with `!awaitsGame` (`Models.swift:273–275`: has a `source`, or is not a visit / has teams / is motorsport), keyed by venue + the saved date in the venue tz. Saved visits and team-less photo cards are re-grouped and re-matched; `savedVisitKeys` (:238–243) keeps them out of the "stadium visit" offer only (`ScanModel.swift:371–372`).

**R6. Schedule.** `ScanModel.match` (`ScanModel.swift:460–465`): the visit's venue, then each neighbour (R2), first game wins. `GameLookup.games` (`GameLookup.swift:64–98`): window = first photo − 5 h to last photo + 1 h (:66–67); leagues = `leagues(for:)` (:141–154: catalog list, else sport/country guess + 9 soccer tournaments + confederation qualifiers; football bowls ≥ 30,000 capacity get the 5 neutral tournaments); scoreboard day strings in the **venue** tz, one per local day the window touches (:72, :465–480); results sorted by |start − first photo| (:97). Local packs serve leagues whose seasons are downloaded when the window ends > 7 days ago (`LocalSchedule.swift:124–134`). Racing: `F1Calendar.races(at:from:to:)` (`F1Calendar.swift:97–102`), weekend = first practice 00:00 local to race day + 29 h (:93), no network.
- Concurrency: visits matched 4 at a time (`ScanModel.swift:325`); HTTP gate 6 in flight (`RequestGate`, `GameLookup.swift:694`); 3 attempts, 15 s timeout, back-off 600 ms × (n+1)² (:496–510); 200s for days ≥ 2 days old cached per launch (:501, :514–522). A second, serial pass re-matches every unmatched visit (`ScanModel.swift:342–345`).
- Note: HANDOFF "6 lookups at a time" is the HTTP gate; visit chunks are 4.

**R7. Decide.** `ScanModel.run` (`ScanModel.swift:293–405`):
- Race weekends → one visit (`mergeRaceWeekends`, :440–457). Visits that found the same game → one card, earlier cluster's id/venue (:357–369).
- Matched → *game*. Unmatched and not a saved visit → *stadium visit* iff `isStadiumVisit`: ≥ `visitPhotos` 3 in-fence on-foot photos spanning ≥ `visitStay` 20 min (`PhotoMatcher.swift:31–33`, `insideSpan` :21–26). Otherwise dropped (`skippedVisits`, :376–380). `pendingVisits` cleared (:378); leftovers from older builds are judged the same way by `waitingDay` (:408–424).

**R8. Other ways in** (first pass, all three run in `run`, :383–401):
- *Around a ground*: `PhotoMatcher.found` (:155–168): located photos not in a visit, grouped with radius `nearbyReach` 600 m and the 15-min stay, ≥ `GameSuggester.minPhotos` 3 photos, no visit/settled day at that ground or a neighbour; newest `maxNearby` 40 kept (:145, :168). Offered when the schedule has a game and a photo lies in [kickoff − 2 h, kickoff + 3 h] (`nearbyDay`, `ScanModel.swift:428–437`).
- *Matchup albums*: `MatchupAlbums.find` (`MatchupAlbums.swift:219–230`): albums 3–3,000 photos, not an app album, title parses to two known teams (separators :19–20, filler :23–26, `nationalNames` :30–39), first `maxAlbums` 20. Per album, last 4 outings (gap ≤ 6 h, :172–180, :198) of ≥ 3 photos; schedules of both teams (national: all 18 `nationalCompetitions`; soccer clubs: + 7 cups, :127–139) for UTC days from first − 6 h − 12 h to last + 6 h + 12 h (:153, :201–202); game must have the two sides (:164–168). Saved event ids skipped (:197).
- *City days*: `CityDays.candidates` (`CityDays.swift:44–53`): no-GPS, non-screenshot, un-taken photos in runs with gaps ≤ `maxGap` 1 h; a run needs ≥ `minPhotos` 5 over ≥ `minSpan` 30 min, nothing saved in [start − 4 h, end + 2 h] (:94), anchors (located photos during it, else the last before and first after within `anchorReach` 12 h, :108–123) all within `metro` 40 km of each other; grounds ≥ `minCapacity` 10,000 with leagues within 40 km of every anchor, biggest `maxVenues` 6; newest `maxDays` 12 (:35). `evaluate` (:158–190): each ground's schedule; a game fits when ≥ 5 photos over ≥ 30 min fall in [kickoff − `before` 1 h, kickoff + `after` 3.5 h] (:126–131); `sample` 16 photos through `SceneCheck.look`; offered iff `looksLikeTheGround`: venue ≥ 3, venueShare ≥ 0.3, structure ≥ 2, elsewhereShare < 0.25 (:137–139); games with ≥ 80 % of the top count, up to 3, listed as alternatives (:173).
- Matches HANDOFF R6 (600 m / 3+ / 15+; 5+ over 30 min; 12 days).

**R9. Background search** (fan-started; HANDOFF R7 last sentence): `ScanModel.startDeepScan` (:176–220) claims phone-tz days of library games, review games/others/possible, and `ledger.dismissedDays` (:180–187). `GameSuggester.find` (`GameSuggester.swift:239–364`): albums (first `maxAlbums` 60, 3–3,000 photos, not app, not a collection = middle 80 % of dates > 60 days unless sport-titled, :38–44) and trips (`TripFinder`: > 80 km from home, gap ≤ 36 h, ≥ 5 photos, ±6 h pad; first 20); matchup albums re-run with `existing: []` (:287–296, score 10); untitled sources need `SceneCheck.look(max 20).isGame(minVenue 2, minShare 0.05)` (:306–309); unplaced days ≥ 3 photos not on claimed days, newest `maxDays` 150; per day: `DayShape` (busiest ≤ 4 h stretch holds ≥ 3 photos, ≥ 50 % of the day, ≥ 20 min, :47–80), `whereabouts` (any located photo within `reach` 2,000 m of a ground → near; ≥ 2 located and ≥ 50 % located and none near → elsewhere, dropped; :94–102), `SceneCheck.look` of the stretch (venue ≥ 1, elsewhereShare < 0.5), schedule at the near/hinted/home grounds + neighbours with `covers` = [first − 4 h, last + 1 h] (:73–75, :145–162), `confidence` (:118–141); surest `maxOffered` 12, one per phone-day.

**R10. Review.** `ReviewQueue.firstPass` (`ReviewQueue.swift:84–108`): games drop if any photo is on a saved non-awaiting game or in `dismissedGames`; a visit drops if any photo is in the library or `dismissedAssets`, merges into a game at the same ground or one ≤ 1,000 m away on the same venue-day (`sameOuting`, :73–76), or drops if the library has anything on that ground/neighbour day. `ReviewQueue.possible` (:113–126): drops days sharing a photo with the library, a skip, a visit up for review or an earlier possible day, **or whose phone-day is in `dismissedDays`**. Skip → `ScanModel.dismiss` (`ScanModel.swift:163–172`) → `ReviewLedger.dismiss` (`ReviewQueue.swift:19–23`), `asGame` only from the games screen (`DiscoveryView.swift:149`; :400 and :597 pass false). Adds → `Library.add` merges by `sameGame` (`Library.swift:579–589`: same source; or awaiting-vs-not with a shared photo; or same venue within 8 h). Matches HANDOFF R7, with the caveat in F2.

**R11. Scan check.** `ScanCheck.report` (`ScanCheck.swift:253–344`): the phone-calendar day; prints R2–R4 per photo (first 150, :10), saved entries and whether they settle the day, skips/pending/nearby gates, each visit's schedules incl. neighbours, albums (first 12, :298), city lines over ±12 h, and the review verdict. Pure parts unit-tested.

## 2. Findings, ranked

Severity: **High** = offers or hides a game on realistic input; **Medium** = wrong on a plausible day or hides a candidate; **Low** = cosmetic, perf, or doc drift. "plausible" = reasoned from the code path but not reproduced against a fixture.

**F1 · High — one in-fence fix plus any same-day photo is a visit, and a matched visit is never checked for a real stay.**
`VisitGrouping.swift:222–239`, `ScanModel.swift:359–376`. The 15-min stay counts the in-fence photos *and every adopted photo of that local day*: no-GPS photos, on-the-move photos, located photos anywhere (the stay in `AirborneTests:89–92` is the cabin's stale fix at 06:19 + the terminal dog 30 km away at 06:40). Photos within 500 m are excluded from the stay (:239). The 3-photo / 20-min `isStadiumVisit` test applies **only when the schedule has no game** (:376). Input: a game night at Stamford Bridge, the fan drives past on the Fulham Road in traffic at 5 m/s (under the 20 m/s rule) and takes one photo, then one at home two hours later → a visit with 1 in-fence photo → matched → offered as a *game* with the home photo attached. Same for a stale airport fix on a match day, or a friend's single photo at the ground. What should happen: a matched visit should need the same stay inside the fence (or inside + near) that an unmatched one needs, or at least 2 in-fence on-foot photos; photos ≤ 500 m should count toward the stay before photos 30 km away do. Also fixes the inconsistency in `ScanEndToEndTests.testOnePhotoInsideTheBowlAndTheDayAroundItIsTheMatch`, which passes only because the fan-zone photo is 540 m out (loose, counts) rather than 450 m (near, would not count).

**F2 · Medium — skipping anything on a day hides every later possible game on that phone-day.**
`ReviewQueue.swift:121`, `ScanModel.swift:165`. `dismiss` writes the phone-tz day into `dismissedDays` for every skip (visit, possible day, game); `ReviewQueue.possible` drops any possible day on such a day, whatever its photos. Input: fan skips a 3-photo stadium visit (or a trip's "2 of 10 look like a game" day) on Jun 24; later the matchup album "BiH v Qatar" or the city-day path finds the World Cup match from 40 other photos → never offered, and `ScanCheck.gates` only says "day skipped: yes". HANDOFF R7 ("a skipped visit never hides a game found later") holds for first-pass games only. `ReviewQueueTests.testSkippedTourIsNotOfferedAgainEvenAfterARelaunch:73–76` asserts the day-level block, so this is by design for the album search but over-reaches for schedule-matched possible days. Should: block by photo overlap (already done) and keep the day block for untitled album/trip days only, or exempt possible days that carry a schedule match.

**F3 · Medium — a travel day's airport photo voids the city check even when located photos during the stretch place the fan in one city.**
`CityDays.swift:108–113, :117–123`. `nearby` returns `[before] + during + [after]` whenever before/after exist (within 12 h), and `anchors` requires every pair within 40 km. Input: 06:00 CT photo at O'Hare, Seattle photos at 14:00 PT, no-GPS stadium photos 15:00–18:00 PT → before = O'Hare (11 h earlier) → `.spread` → the day is never asked. Fly-in-and-watch is the World Cup pattern. Should: when `during` is non-empty, judge the city from `during` only.

**F4 · Medium — the day's no-GPS photos all join one visit when two visits share a day in one zone, picked by key order.**
`VisitGrouping.swift:210–230`. `visitByDay` keeps the first sorted key per zone-day ("united-center|…" beats "wrigley|…"). Input: Cubs afternoon, Bulls evening, 20 no-GPS/shared photos → all 20 land on the Bulls card; the Cubs card has none. Also makes `ReviewQueue` photo-overlap checks day-wide: any one of those photos saved elsewhere drops the whole cluster. Should: pick the visit whose in-fence photos are nearest in time to the loose photo.

**F5 · Medium (plausible) — venue-local scoreboard days vs ESPN's filing day.**
`GameLookup.swift:72` asks `dates=` for venue-local days only; `MatchupAlbums.swift:152–153` pads ±12 h in UTC on the stated premise that ESPN files a game under the US day it starts on. If that premise is right, `GameLookup.games` misses games in UTC+9…+11 that kick off before ~14:00 local (a 13:00 J-League or A-League match is filed under the previous US day; the −5 h window does not reach it). Exposure today is small (no Asian/Australian club leagues in `soccerLeague`, F1 is offline) but the two call sites disagree. Should: one fixture test for a UTC+9 morning kickoff; if it fails, add the day before to `dayStrings` (cached, cheap).

**F6 · Medium (plausible) — the match is chosen by distance from the visit's first photo, which may be a no-GPS breakfast photo.**
`ScanModel.swift:460–465` → `GameLookup.swift:97`. `cluster.start` includes adopted photos (R4). Input: MLB doubleheader (13:10 and 19:05), fan at the night game, in-fence photos from 19:00, a no-GPS photo at 09:00 adopted → window 04:00–23:00, sort by |start − 09:00| → the 13:10 game wins. Should: sort by distance from the first *in-fence* photo (`insideIds`), or prefer the game whose [start − 1 h, start + typical length] holds the most anchors.

**F7 · Low — screenshots join visits as "the day's photos".**
`VisitGrouping.swift:162` ignores `screenshot`; only `CityDays.runs:65` excludes them. A game card collects the day's memes and chat screenshots; `ReviewQueue.firstPass` then treats a screenshot saved on another card as a shared photo (drops the cluster). Should: keep screenshots out of `loose` (ticket screenshots are handled by `TicketAnchors` separately).

**F8 · Low — a saved game with no photos does not settle the neighbour's day.**
`PhotoMatcher.swift:230–235` keys the saved venue only; `ReviewQueue.firstPass:90` keeps a game cluster unless its photos are on a saved game. Input: manual/ticket entry for the World Cup match at Lumen Field (no photos); scan places the day at T-Mobile Park → matched to the same game → offered every scan until added (then `sameGame` merges, no duplicate card) or skipped. Should: in `settledKeys`, also key each neighbour of the saved venue, or in `firstPass` drop a game cluster whose match `(league, eventId)` equals a saved `source`.

**F9 · Low — skipping a schedule-matched possible day is recorded as a plain skip.**
`DiscoveryView.swift:400` passes no `asGame`. If the same photos later form a first-pass game cluster (e.g. iCloud later delivers located originals for the day), the game is offered again; `ScanCheck.verdict` would then say "the review shows it" for a game the fan already turned down. Should: pass `asGame: possibleMatch?.game != nil`.

**F10 · Low — `gameNear` reads the phone's calendar day, not the stadium's.**
`GameLookup.swift:675–678`: `Calendar.current.dateComponents` then rebuilt in the venue tz. A 22:30 PT photo viewed from Chicago is Jun 25 CT → looks up Jun 25 at the venue → the ±1-day shift finds Jun 24 and the UI says "a day before your photos". Cosmetic; the comment on :671–673 claims the opposite.

**F11 · Low — ledger and claimed days use the phone's zone at call time.**
`ScanModel.swift:165, :182–187`, `ReviewQueue.swift:121`, `GameSuggester.swift:292, :362`. A skip recorded while abroad (phone in PT) and checked at home (CT) keys a different day for outings whose middle is 22:00–23:59 local. Rare; consistent within one session.

**F12 · Low (perf) — non-200 league responses are not cached, and the retry pass repeats them.**
`GameLookup.swift:501–505`. A soccer ground asks up to 13 leagues × 2 days per visit; a league ESPN answers 404 for (e.g. a qualifier path with no page) is re-requested for every visit and again in the serial retry pass (`ScanModel.swift:342–345`). On a library with 60 unmatched visits that is hundreds of pointless requests under the 6-gate. Should: cache 4xx per launch too.

**F13 · Low (perf) — matchup albums can fan out to thousands of requests.**
`MatchupAlbums.swift:149–170, :198`: a national-team album → 18 competitions × 3 UTC days × up to 4 outings; × 20 albums ≈ 4,300 requests worst case, serialised 6 at a time, on every Find in photos (past days cached after the first). Should: ask the team's own `/teams/{id}/schedule` once per team per season instead of day scoreboards, or cap outings to 2.

**F14 · Low — doc drift.** HANDOFF R1: fence "200 m default" (code 200/260/300), circuits "800–1500" (catalog 700–1,500). R4: "6 lookups at a time" (4 visits at a time; 6 HTTP). R3's stay sentence (see F1). `ScanCheck.lines:61` prints "the day's photos 15+ min apart", which is what the code does.

Verified-not-a-bug, for the record: overnight join + settled day 1 (post-midnight leftovers fall outside the −5 h window, dropped); `mergeRaceWeekends` id bookkeeping; `VenueIndex` cell coverage for 1.5 km fences and 2 km queries; force-unwraps in `group`, `evaluate`, `find`, `check` (all guarded by counts); `settledKeys`/visit keys both in venue tz.

## 3. Test-coverage map

| Rule | Covered by | Not covered |
|---|---|---|
| R1 read library | — (device only) | progress cadence, screenshot flag from `mediaSubtypes` |
| R2 fence tiers / index | `DetectionTuningTests.testGeofenceIsTightButFitsBigBowls`; `AlbumAndScoreboardTests.testIndexFindsTheSameVenueAsTheLinearSearch`; `F1CircuitTests.testRaceDayPhotosAtTheGrandstandsPlaceAtTheCircuit`, `.testMiamiWeekendPhotosAtHardRockStadiumReachTheCircuit`; `NeighborGroundsTests` | the 260 m tier; `minimumBox` 320; high-latitude cos floor; neighbours at exactly 1,000 m |
| R3 on the move | `AirborneTests.testTheLandingIsOnTheMove`, `.testAFixAtAirlinerSpeedIsOnTheMove`, `.testADriveByIsNotAVisit`, `.testAJumpingFixInsideTheBowlStaysOnFoot`, `.testSpeedComesFromTheFixWhenItHasOne`, `.testADayAtTheNurburgringIsAVisit` | the 5-min window boundary; a moving photo joining a real visit's photos |
| R4 visit / stay / overnight / near | `AlbumAndScoreboardTests.testAlbumGroupsVisitsAsksForTheRest`, `.testPhotosAcrossMidnightAreOneVisit`, `.testNineHourGapAsksInsteadOfJoining`, `.testDiscoveryRuleSkipsDriveBys`, `.testMatchdayPubJoinsTheGameAndTourStandsAlone`, `.testTailgateWithin500mJoinsOnlyAnExistingVisit`, `.testGroupingAFiftyThousandPhotoLibraryIsFast`; `ScanEndToEndTests.testTwoPhotosInsideTheBowlMakeAVisit`, `.testOnePhotoInsideTheBowlAndTheDayAroundItIsTheMatch`; `PhotoMatcherTests.testGameDayKeyUsesVenueTimeZone` | that loose/moving photos count toward the stay while near photos do not (F1, only incidentally); two visits on one day (F4); screenshots adopted (F7); `askGap` upper bound 12 h |
| R5 settled days | `WorldCupSeattleTests.testSavedStadiumVisitNoLongerHidesTheMatch`, `.testSavedGameStillKeepsItsDay`; `ScanEndToEndTests.testFindInPhotosOffersTheMatchForASavedStadiumVisit`, `.testOnboardingAddAllUpgradesASavedStadiumVisit`, `.testFindInPhotosOffersTheMatchForAGameCardWithNoTeams`, `.testASavedMatchIsNotOfferedAgain` | saved game at the neighbour with no photos (F8); motorsport `awaitsGame` branch |
| R6 schedule window / leagues / days / packs / F1 | `GameLookupTests.testScoreboardFindsTheGameAtTheVenue`, `.testVenueMatchingUsesAliasesAndIgnoresGenericWords`, `.testLeagueGuessForVenuesWithoutLeagues`, `.testDaysFollowTheVenueTimeZone`, `.testLocalScheduleFindsAPastGameAtTheVenue`, `.testLocalScheduleSeasonsAndNumericIds`; `F1CircuitTests.testAVisitAtSilverstoneOnRaceDayIsTheBritishGrandPrix`; `AlbumAndScoreboardTests.testF1RaceWeekendIsFoundAtTheCircuit`, `.testWorldCupGameIsFoundAtAFootballStadium`, `.testUnitedCenterIsNotCambrianUnitedGround`; `ScanEndToEndTests.testAVisitWhoseLookupFailedIsOfferedAndMatchedNextTime` (retry pass) | −5 h / +1 h edges; `RequestGate` limit; back-off/timeout; page cache & `isPastDay`; `LocalSchedule.covered` 7-day rule; UTC+9 morning kickoff (F5); doubleheader choice (F6); `canHostSoccer` 30,000 cut |
| R7 decide: game / stadium visit / dropped / race merge | `AirborneTests.testATourOfTheGroundIsOffered`, `.testAVisitNeedsThreePhotosInsideTheFenceOverTwentyMinutes`, `.testTheBackgroundSearchJudgesAWaitingVisitTheSameWay`, `.testAGameDayAMileUpIsStillAVisit`, `.testALandingWithTwoPhotosInsideTheFenceIsDropped`, `.testAnOlderPendingVisitStillReads`; `ReviewQueueTests.testWalkPastTheNeighbourOnGameDayJoinsTheGame` (same-game merge via review) | `mergeRaceWeekends` (no test); same-game merge in `run` (:357–369) directly; exactly 20 min / exactly 3 photos boundaries |
| R8a around a ground | `ScanEndToEndTests.testPhotosAroundTheGroundAreOfferedAsAPossibleGame`, `.testPhotosAroundTheGroundWithNoGameAreLeftAlone`, `.testPhotosAroundTheGroundJoinTheMatchDay`, `.testScanCheckNamesWhatKeepsTheMatchOut` | `maxNearby` 40 cap; the [−2 h, +3 h] window edges; 600 m boundary |
| R8b matchup albums | `MatchupAlbumTests` (all 8) | `maxAlbums` 20; outings `suffix(4)`; 3,000-photo cap; club (non-national) matchups end-to-end (`testTeamsThatDidNotPlayEachOtherAreNotOffered` covers one negative) |
| R8c city days | `CityDayTests` (all 8) | `maxDays` 12 cap; `maxVenues` 6; `minCapacity`; travel-day anchors (F3); the 80 % alternatives list; `.saved` window |
| R9 background search | `AlbumAndScoreboardTests.testAlbumTitleNamesTheStadium`, `.testPossibleDaysNeedPhotosAndSkipCoveredDays`, `.testAppAndSystemAlbumsAreSkipped`, `.testTimeShapeOfAGameDay`, `.testLongRunningAlbumsAreCollections`, `.testPhotosWithALocationFarFromAnyStadiumWereElsewhere`, `.testTheScheduleDecides`, `.testMatchupTitleNamesTeamsByCode`, `.testOneStrayPitchIsNotAGameDay`, `.testACrowdAloneIsNotAVenue`, `.testVenueLabelsAreWholeIdentifiers`; `WorldCupSeattleTests.testWaitingVisitIsCheckedAgainstTheScheduleNextDoor`, `.testBackgroundSearchAsksTheGroundNextDoorBeforeRulingADayOut` | `GameSuggester.find` end to end (no test drives it); `TripFinder`; `maxOffered` 12 / `maxDays` 150; `local` grounds (50 km, ≥ 5,000); `claimed` day logic |
| R10 review / ledger | `ReviewQueueTests` (all 5); `ScanEndToEndTests.testASkippedStadiumVisitDoesNotHideTheMatch`, `.testASkippedGameStaysSkipped`, `.testAnOlderLedgerStillReads`; `CityDayTests.testTheLedgerHolds`; `MatchupAlbumTests.testTheReviewLedgerHolds`; `AlbumAndScoreboardTests.testDuplicateGamesAreSpottedAndCombined` | `dismissedDays` hiding a schedule-matched possible day (F2 — the opposite is asserted); possible-day skip without `asGame` (F9); `sameGame` 8 h window; `sameOuting` 1,000 m boundary |
| R11 scan check | `AirborneTests.testScanCheckShowsTheRoadAndTheStay`; `ScanEndToEndTests.testScanCheckNamesWhatKeepsTheMatchOut`; `WorldCupSeattleTests.testScanCheckTracesTheDay`; `CityDayTests.testScanCheckTracesTheCityDay`; `MatchupAlbumTests.testScanCheckReadsTheAlbum` | `report` itself (device) |

Thresholds with **no test at all**: `overnightGap` upper edge, `askGap`, `minimumBox`, `maxNearby`, `maxDays` (both), `maxVenues`, `maxAlbums` (both), `maxOffered`, `sample`, `RequestGate` limit, retry/back-off, `isPastDay`, `LocalSchedule.covered` 7 days, `F1Calendar.weekend` +29 h, `sameGame` 8 h, TripFinder constants, `GameSuggester.reach` 2,000 (only via `whereabouts`), all `SceneCheck` word lists except `venueLabels`.

## 4. Fixes to make before shipping (at most 5, not applied)

1. **Count the stay from photos at the ground** — `VisitGrouping.swift:236–239`. Build the stay from in-fence photos plus `joined[k]` (≤ 500 m) and leave `loose`/moving photos out of it; keep adopting them as the visit's photos afterwards. Then in `ScanModel.run:359` require `insideIds.count >= 2` (or `isStadiumVisit`) for a matched visit too, and set `skippedVisits` accordingly. Update `AirborneTests:89–92` and `ScanEndToEndTests.testOnePhotoInsideTheBowlAndTheDayAroundItIsTheMatch` (move the fan-zone photo to ≤ 500 m, which is the case the test describes). Fixes F1.
2. **Narrow the day-level skip** — `ReviewQueue.swift:119–124`. Apply `dismissedDays` only to possible days whose `reason`/id marks them as untitled album or trip days (`possible-<pile>` from `GameSuggester`), not to `possible-near-*`, `possible-album-*`, `possible-city-*`; or add a `scheduled: Bool` to `PossibleDay` and skip the day check when true. Keep `startDeepScan`'s `claimed` as is. Fixes F2; add a test that a skipped visit does not hide a matchup-album offer on the same day.
3. **City anchors from `during` first** — `CityDays.swift:112`: `return !during.isEmpty ? during : (before != nil && after != nil ? [before!, after!] : [])`. Fixes F3; add a fly-in day to `CityDayTests`.
4. **Nearest-in-time adoption** — `VisitGrouping.swift:222–232`. When a zone-day has several visits, choose the one whose in-fence times are closest to the loose photo's time (keep `visitByDay` for the single-visit fast path). Also drop `screenshot` points from `loose` (:162). Fixes F4, F7.
5. **Pick the game by the in-fence photos** — `ScanModel.swift:462` pass `from: cluster.insideIds` first time (or `max(cluster.start, first inside time)`) and `to:` the last inside time; `GameLookup.games` keeps −5 h/+1 h. Fixes F6; add a doubleheader fixture. (If only four can be done, drop this one.)

## 5. Every tunable (checklist for `ScanSettings`)

Numbers, caps, windows and word lists in the scan, with the current value and location. Grouped by file; line numbers at `fed094d2`.

**Models.swift**
- Fence tiers: 300 m for capacity ≥ 90,000; 260 m for 65,000–89,999; 200 m default — `Models.swift:126–128`

**VisitGrouping.swift**
- `VenueIndex.cell` 0.02° — :81
- `VenueIndex.minimumBox` 320 m — :83
- Box slack ×1.02; cos(lat) floor 0.1 — :105–106
- `VenueIndex.key` multiplier 20,000 — :100
- `matchdayReach` 500 m — :136
- `overnightGap` 6 h — :140
- `askGap` 12 h — :273

**TransitCheck.swift**
- `vehicleSpeed` 40 m/s — :10
- `movingSpeed` 20 m/s — :14
- `movingDistance` 1,000 m — :15
- `movingWindow` 5 min — :16

**PhotoMatcher.swift**
- `PhotoCluster.visitPhotos` 3 — :31
- `PhotoCluster.visitStay` 20 min — :32
- `neighbors(within:)` 1,000 m — :96
- `nearbyReach` 600 m — :143
- `maxNearby` 40 — :145
- `minimumStay` 15 min (visits and nearby) — :152, :157
- nearby minimum photos = `GameSuggester.minPhotos` 3 — :160
- `looksLikeAGame` 15 min (unused by scan) — :299
- `recentIds` cap 40 — :210
- progress every 1,000 photos — :214
- `photos(at:around:hours:)` 6 h (−3 h / +6 h) — :245–247
- `videos(at:around:hours:)` 6 h — :273–275
- `location(ofPhotos:)` first 24 ids — :286

**ScanModel.swift**
- Visits matched per chunk 4 — :325
- `waitingDay` neighbour suggestions `prefix(2)` — :423
- `nearbyDay` window kickoff −2 h … +3 h — :430
- `deepFraction` quarters 4 — :49

**GameLookup.swift**
- Window −5 h / +1 h — :66–67
- Soccer tournament list (9 paths) — :145–147
- `canHostSoccer` capacity ≥ 30,000 (default 30,000 when unknown) — :161
- `neutralTournaments` (5) — :164–166
- `nationalLeagues` country lists (CONMEBOL 10, CONCACAF 8) — :171–172
- `europe` country set (31) — :177–180
- `clubLeagues` sport/country map — :185–197
- `soccerLeague` map (28 countries) — :201–208
- `schedule(league:)` −6 h — :108
- `stopwords` (24) — :397–399
- scoreboard `limit=500`, `groups=80` (CFB), `groups=50` (CBB) — :458–460
- `dayStrings` step 1 h — :475
- `fetch` attempts 3, timeout 15 s, back-off 600 ms × (n+1)², retry on 429/5xx — :496–509
- `isPastDay` 2 days — :520
- `RequestGate` limit 6 — :694
- `nationalCompetitions` (18 paths) — :636–643
- `gameNear` shifts [0, −1, +1]; "evening" 19 h — :679, :683
- `upcoming` limit 14, −3 h, 75-day range (not scan) — :557–571

**LocalSchedule.swift**
- `covered` only when window ends > 7 days ago — :125
- `ScheduleCache` holds 6 packs — :92
- `seasons` = year − 1 … year — :198–200

**F1Calendar.swift**
- Weekend end = race day + 29 h — :93
- `apply` date pull-forward within 2 days — :125

**CityDays.swift**
- `maxGap` 1 h — :24
- `minPhotos` 5 — :25
- `minSpan` 30 min — :26
- `anchorReach` 12 h — :28
- `metro` 40 km — :30
- `minCapacity` 10,000 — :32
- `maxVenues` 6 — :33
- `maxDays` 12 — :35
- `before` 1 h / `after` 3.5 h — :37–38
- `sample` 16 — :40
- `.saved` window −4 h / +2 h — :94
- `looksLikeTheGround`: venue ≥ 3, venueShare ≥ 0.3, structure ≥ 2, elsewhereShare < 0.25 — :138
- alternatives ≥ 80 % of top, `prefix(3)` — :173

**MatchupAlbums.swift**
- `separator` regex — :19–20
- `filler` words (41) — :23–26
- `nationalNames` (34 codes) — :30–39
- name scores: teamName 4, location 2/4, full 5, former 3, abbreviation 3 (≥ 3 chars), alias 4, first word 2 (≥ 5 chars, multi-word) — :55–63
- side match length up to 5 words, `prefix(3)` teams — :80, :91
- `leagues(for:)` club soccer cups (7) — :135–136
- UTC day padding ±12 h — :153
- `outings` gap 6 h — :177
- `check` window −6 h / +6 h, last 4 outings, ≥ `GameSuggester.minPhotos` — :198–202
- `maxAlbums` 20 — :216
- album size 3 … 3,000 — :223

**SceneCheck.swift**
- `sportsWords` (25) — :36–38
- `venueLabels` (17) — :42–44
- `structureLabels` (4) — :47
- `indoorWords` (8), `outdoorWords` (10), `eventWords` (9) — :48–50
- `elsewhereWords` (56) — :51–56
- `fits` 0.3 — :21; `doubtful` sports < 0.15 & elsewhere ≥ 0.3 — :24; `looksLikeGame` 0.25 — :25; `showsAVenue` 0.25 — :27; `clearlyElsewhere` 0.25 / 0.2 / 0.25 — :31
- `verdict` sample 6, 512 px — :60, :67
- `kind` thresholds 0.3 (venue, structure, elsewhere) — :94–98
- `DayLook.isGame` defaults minVenue 2, minShare 0.25, elsewhereShare < 0.35 — :112–113
- `mostlyElsewhere` 0.5 — :115
- `look` max 24, 384 px — :118, :124
- label confidence > 0.05 — :169

**GameSuggester.swift**
- `minPhotos` 3 — :24
- `maxDays` 150 — :25
- `maxAlbums` 60 — :26
- `maxOffered` 12 — :28
- `reach` 2,000 m — :30
- `sportTitleWords` (20) — :33–34
- `isCollection`: ≥ 5 dates, middle 80 % (10 % trim), > 60 days — :40–43
- `DayShape.window` 4 h — :48
- `looksLikeAnOuting`: ≥ 3, ≥ 50 %, ≥ 20 min — :70
- `covers` −4 h / +1 h — :74
- `isPrime` hour ≥ 17 or weekend — :78
- `whereabouts`: near `prefix(3)`; elsewhere needs ≥ 2 located and ≥ 50 % — :100–101
- `confidence`: specific+titled venue ≥ 1 & elsewhereShare < 0.5; specific untitled venue ≥ 2, venueShare ≥ 0.15, elsewhereShare < 0.35; unspecific `isGame()` & structure ≥ 1; unknown titled `isGame()` & structure ≥ 1, untitled venue ≥ 4, venueShare ≥ 0.5, structure ≥ 2, elsewhereShare < 0.15; bases 2 / 1.5 / 1; +0.5 titled, +0.5 × structureShare, +0.2 prime — :126–140
- `appAlbums` (41) — :165–168
- `venues(named:)`: nickname words ≥ 4 chars, code ≥ 3 chars (matchup only), venue first word ≥ 5, stop words [stadium, field, park, arena, center, centre], max 3 — :196–211
- album size 3 … 3,000 — :244
- trips `prefix(20)` — :255
- trip grounds capacity ≥ 5,000 within 40 km, `prefix(3)` — :263–264
- `local` grounds capacity ≥ 5,000 within 50 km, `prefix(4)` — :274–275
- matchup-album score 10 — :294
- untitled source `look(max: 20)`, `isGame(minVenue: 2, minShare: 0.05)` — :307–308
- stretch look: venue ≥ 1, `!mostlyElsewhere` — :335

**AlbumImporter.swift (TripFinder)**
- `awayMeters` 80 km — :105
- `maxGap` 36 h — :107
- `minPhotos` 5 — :109
- pad 6 h — :135

**ReviewQueue.swift**
- `sameOuting` neighbour distance 1,000 m — :75

**Library.swift**
- `sameGame` same-venue window 8 h — :588
- `refreshFromSchedule` −6 h / +8 h — :504
- `gameDayPhotoCheck` plans started ≥ 30 min ago — :466

**ScanCheck.swift**
- `listed` 150 photos — :10
- albums `prefix(12)` — :298

**BackgroundPhotoCheck.swift**
- refresh `earliestBeginDate` 60 min — :31
