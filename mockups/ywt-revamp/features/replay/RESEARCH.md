# Recap: research and directions (Oct 19, 2026)

Owner's complaint about today's Play film: "it can't be skipped and it's just picture by picture." This note is what the best apps do, eight directions for Witness, and a pick. The HTML mockups beside it (`v1-soccer-main`, `v2-baseball-wp`, `v3-sparse`) and `NOTES.md` are the "Replay" concept this recommends.

## What the recap does today (`Witness/Features/Game/RecapFilmView.swift`)
- One chapter per photo, 4 s each, `max(3, photos.count)` chapters; a 33 ms timer loop. Stops on the last frame, no ending card.
- Overlays: headline on most chapters, the score on chapter 1, companions on the last. Videos show as frozen posters.
- One Ken Burns (scale 1→1.12, ±14 pt drift), 0.8 s crossfades, a warm grade and letterbox.
- Controls: close, play/pause, "Share story", segment bar, m:ss clock. No tap-to-advance, no hold, no swipe-down, no scrub.
- Share is five 1080×1920 images, not a video.
- Data it has but ignores: `plays` (timestamped, `isKey`), `winProbability`, line scores, `savedMoments`, weather, seat, attendance, companions, photo capture times, video detection. `MatchReport.beats` already computes moments from these.

## What the good ones do
- **Stories grammar** (Instagram, Snapchat, now universal): tap right = next, tap left = back, hold = pause, swipe down = close, segmented bar on top. Anything full-screen that ignores this feels broken.
- **Apple Photos Memories**: tap to pause, skip, jump; music keeps playing and cuts stay on the beat; Memory Mixes (song + look + pacing) re-render instantly; one color look across every photo; Ken Burns on stills, best segment of each video.
- **Spotify Wrapped**: tap-through, one big number a card, build-up then reveal, every card a share on its own. The copy carries it.
- **Google Photos highlights**: cuts synced to the track; Beat Match coming.
- **NBA app, MLB "My Daily Story"**: broadcast idiom in a 9:16 story; the editorial unit is the play, not the clip.
- Shared shape: cold open → setup → chapters → the turning point → score reveal → ending card.

## Eight directions

| | Direction | Spine | Interaction | Audio | Length | Effort |
|---|---|---|---|---|---|---|
| A | **Skippable film** (ship this week) | today's photos | tap/hold/swipe-down, bar-tap seek, ending card; drop the pause button and clock | none | ≤30 s | 1–2 d |
| B | **Wrapped for one game** | 7 data cards: cold open, headline, score count-up, turning point (+34% on the curve), your night, conditions, with Maya & Leo | tap-through, no timer | none | user-paced | 3–4 d |
| C | **Live scoreboard** | the game clock compressed to 45 s; score bug ticks as plays pass; photos appear at their real times with an amber "YOU · 9:47 PM"; the WP line draws itself | the curve is the scrubber, snaps to key plays | optional ambience | 40–60 s | 5–7 d |
| D | **Replay** (the mockups) | one segment per MOMENT: Arrival, Kickoff, each key play, Final, After, Recap card; photoless moments still exist as type-only beats; the turning point gets a longer hold and "THE MOMENT" in amber | full stories grammar + a scrub dock with key-play snapping and haptics | optional ambience | 30–50 s | 6–8 d |
| E | **Auto edit** (Apple-Photos style) | saliency-driven Ken Burns, deduped shots, video clips, one of three looks, cuts on a grid; "Mixes" for look + pacing | tap pause, swipe skip, swipe up for Mixes | bundled royalty-free loops (fixed BPM); Apple Music live-only for subscribers | 20–30 s | 8–12 d (+4 export) |
| F | **Stadium ambience** (add-on) | crowd room tone + swell + PA hit, swell scaled by the WP delta of each key play | speaker toggle | synthesized, nothing to license | | 2–3 d |
| G | **Turning point** (one beat) | 12 s on the biggest WP swing: the photo nearest it, the curve draws to it, "+34%" lands, the play, the score, "You were there" | tap to replay | none | 12 s | 2–3 d |
| H | **Vertical video export** | turns D/E/G into an MP4 for the share sheet | | | | 3–4 d |

Building blocks: `TimelineView(.animation)` + one `playhead` value (play, pause, scrub and export become one code path); `PhaseAnimator` for lower thirds; `KeyframeAnimator` for Ken Burns and counters; `.contentTransition(.numericText())` for the score bug; `Charts`/`Canvas` for the curve; `SpatialTapGesture`, `LongPressGesture`, `DragGesture`, `.sensoryFeedback`; Vision `GenerateAttentionBasedSaliencyImageRequest` for crops; `PHImageManager.requestPlayerItem` for clips; `MusicKit` gated on `canPlayCatalogContent`; `AVAudioEngine` for ambience; `ImageRenderer` → `AVAssetWriter` (chrome-heavy, ~30–60 s export for 30 s of video) or `AVMutableComposition` + Core Animation tool (clip-heavy) for MP4.

## Pick: D, with A as step 1
D is the only one that uses what makes Witness different: the score bug flipping at the minute you took the picture. Apple Photos will always make a prettier slideshow of the same photos. It is already designed (three mockups here), its data is already computed in `MatchReport.beats`, it degrades to no photos / no plays (`v3-sparse`), and it gives the Live check-in "Save this moment" taps a home. B is a strong second but reads as a Wrapped clone; E is the most expensive and least distinctive; C folds into D as its scrub dock.

1. **Week 1 (A):** `TimelineView` + playhead; tap/hold/swipe-down; bar-tap seek; ending card; delete the pause button and clock. Removes the complaint on its own.
2. **Weeks 2–3 (D):** `ReplayModel` on `MatchReport.Beat`; segments per moment; score bug, lower third, amber time chip; type-only beats; the turning-point hold; the scrub dock from `ProbabilityCurve`; videos play muted. Open from Play and from the match report's timeline.
3. **Week 4 (H + F):** the same `(playhead) → View` rendered through `ImageRenderer` into `AVAssetWriter` at 1080×1920 with the crowd swell mixed in. "Share story" becomes "Share video"; the image cards stay as a second tab.

## Sources
- https://photofocus.com/mobile/ios-15-preview-create-movie-like-scenes-with-memories/
- https://www.tomsguide.com/phones/iphones/how-to-create-a-memory-movie-with-apple-intelligence-on-your-iphone
- https://support.apple.com/en-au/guide/tv/atvb4928b087/tvos
- https://www.dummies.com/social-media/how-to-find-and-interact-with-instagram-stories
- https://figuresandfigures.substack.com/p/how-spotify-wrapped-nails-data-storytelling
- https://alexjimenezdesign.substack.com/p/three-design-elements-that-made-spotify
- https://techcrunch.com/2025/12/09/google-photos-launches-new-video-editing-tools
- https://androidauthority.com/google-photos-highlight-videos-beat-match-apk-teardown-3712456
- https://press.wbd.com/ca/media-release/tnt-sports/nba-launches-reimagined-app-all-one-destination-nba-fans-every-team
- https://www.sportsvideo.org/2025/05/19/mlb-google-cloud-launch-new-my-daily-story-personalized-highlight-videos/
- https://developer.apple.com/forums/thread/699930
- https://developer.apple.com/documentation/vision/cropping-images-using-saliency.md
- https://www.kodeco.com/6236502-avfoundation-tutorial-adding-overlays-and-animations-to-videos
- https://img.ly/blog/how-to-make-videos-from-still-images-with-avfoundation-and-swift.md
- https://developer.apple.com/forums/thread/51928
