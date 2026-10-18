# Going
- Idea: mark an upcoming game Going / Maybe / Can't, see which friends are going, plan the day (seats, meet-up note, drive, forecast); afterward it becomes a Together memory with a shared match report automatically.
- Why: planning is half the fun. A countdown plus friends' avatars makes the game feel like an event, not a calendar entry.
- v1 Upcoming (Timeline top section/sheet): next-game hero with countdown, friends going, Add ticket / Invite / Add to calendar; later games below. v2 Game plan page. v3 Pick a game (search team or venue, schedule) then share sheet with generated invite card.
- Mock "today" is Dec 26, 2026 (Jan 4 = 9 days). The Jan 4 Lambeau game, United Center Jan 17 and Wrigley Apr 2 are invented future fixtures; no weekdays shown on purpose.
- First use / empty state: "Nothing planned. Pick a game and see who's in" with the schedule search; the section is hidden on Timeline until one game is marked.
- Privacy: opt-in, friends only via invite link/contacts. Invite card shows only game, date and who's going: no photos, no location, no kids' accounts. Seats and meet-up note are visible only to people who RSVPed. Photos stay on the phone; the shared match report uses only photos each person chooses to add.
- Plugs in: Timeline top (Upcoming), game page (Going button before game, becomes the match report after), You tab (Together memories), match report (shared edition for everyone who went).
- Backend: schedule feed (teams/venues/times), a "plan" record (game id, RSVPs, seat strings, note), invite links with a signed token, push on RSVP change, weather/drive-time lookups by venue, and a post-game job that links attendees' confirmed visits into a Together memory.
