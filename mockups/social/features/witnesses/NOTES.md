# Witnesses: the crowd count
- Idea: every game page shows a proud, anonymous number (how many Witness fans logged it), which friends were there, and your own collectible place ("Witness #212"). Landmark games get a Witness wall with milestone badges (First 100, Founding Witness #37) and a shareable number card.
- Why people want it: it turns "I was there" into a verifiable rank, rewards being early, and makes a game page feel alive without any feed or likes. Friends' presence is the emotional hook.
- First use / empty state: v3 opt-in explains privacy, Sign in with Apple, name + color; if nobody has logged the game, "You're Witness #1: be the first".
- Privacy: only a count leaves the phone, never photos or location. Seating is aggregated by stand (no individuals). Friends appear only by invite; "Say hi" is friends-only and sent as a quiet nudge. Kids' accounts (Maya, Leo) never appear.
- Plugs into: game page (Witnesses block under the score header), match report share sheet, You tab (a "My Witness numbers" shelf of collected badges), Timeline cards (small #n chip).
- Backend: per-game counter plus ordered join index (one row per game_id + anonymous user id + timestamp), a coarse stand/section bucket count, an invite-based friends graph, and Apple-ID-keyed identity created at the first opt-in. Matching and photos stay on-device.
- Data is stand-in: counts, section buckets and Witness numbers are illustrative.
