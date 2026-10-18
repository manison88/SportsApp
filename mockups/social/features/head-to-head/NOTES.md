# Head to head: NOTES
- Idea: set yourself next to one friend. v1 comparison page (counts, shared stadium stamps, shared games, a verdict line), v2 rivalry ledger for friends who back opposing teams, v3 "My people" on the You tab with a friends-only passport race.
- Why: sports friendships are banter. Witness gives it a scoreboard, and every share card is an invite.
- Empty state: no friends yet shows only the invite link and "Invite from contacts". A friend with no shared games shows just the number comparison. The rivalry ledger needs 3+ shared games to appear.
- Privacy: friends only, by invite link or contacts, no public search, no follower counts. Per-friend toggles (games, venues, photos). Photos default off and never leave the phone unless you pick them. Kids' accounts never appear.
- Plugs into: You tab (My people entry), friend profile (v1) from the race or list, game page ("Chris was there too") and match report (shared games link to the game page).
- Consistency: Sam 60 games, 21 venues, 3 countries, 42.9k miles; Chris 41, 17, 5, 38.4k; 13 shared venues (so Chris has 4 Sam lacks); 60 minus 41 = 19 ahead on games.
- Backend: friend edges with permission flags; per-user aggregate counts (games, venue ids, countries, miles); shared game ids computed server-side from game ids only; per-year park counts for the race. Win rates when attending come from game result + each user's attended game ids. No photo or location data stored.
