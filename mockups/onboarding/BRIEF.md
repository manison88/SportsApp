# Welcome and onboarding: shared brief (all design agents)

Witness is a dark "Broadcast, cleaned" iOS app that finds every game a fan attended from their photos and keeps them
as a timeline, map, passport and recap. First launch today (see Witness/Features/Onboarding/WelcomeView.swift): one
Wrigley night photo, the line "EVERY GAME YOU WERE AT.", and three ways in: Find games in my photos (primary), Add a
game, Explore sample games, plus "Everything stays on this iPhone." Nothing else.

## What onboarding must do
1. Make the promise in one glance (your games, found from photos you already have, private).
2. Earn the Photos permission (and optionally Location) in context, with the reason shown BEFORE the system alert.
3. Cover the three fears: "is this private?", "what if there are tens of thousands of photos?", "what if it finds nothing?"
4. Land on a first result that feels like a reward, not an empty app.
5. Always keep an exit: Explore sample games, Add a game manually, Skip.
Target: 3 to 6 screens from launch to first result. Every screen: one hero, <=3 blocks, one primary action.

## Hard constraints
- Design system: mockups/final/BRIEF.md and mockups/final/system/final.css (broadcast dark, amber = "you", champagne trophy tone,
  20pt gutters, >=12pt text, no slop). Phone frame 393x852. Look at the existing renders in mockups/final/ and
  mockups/big-games/explorations/subtle/png/ for the visual language, and the photos in mockups/photos.
- No team, league or event logos or trademarks. Team tiles are abbreviation chips in team colors. Event names as text only.
- On-device scan, no account, no sign-in anywhere. Do not invent an account/sign-up step.
- Honest states only: never fake a progress number. A scan has: photos checked / total, photos near a stadium, venues found, games matched.
- Copy: plain, confident, short. No exclamation marks, no emoji, no "unlock", no "journey".
- Accessibility: contrast, Dynamic Type friendly layouts, a visible Skip/Not now that is not tiny.

## Mobbin references (use as inspiration, do not copy brands)
You may run 2 more Mobbin searches (ios) of your own; cite each reference you use by its mobbin_url in NOTES.md.
- Apple Sports onboarding (welcome, follow leagues): https://mobbin.com/flows/8eda1da5-d35f-4917-b535-1faf27a057e4
- NBA onboarding (follow teams, interests sheet): https://mobbin.com/flows/5759b0b4-9e76-4d2f-9cfa-28fb70c9c2a4
- (Not Boring) Camera onboarding, theatrical welcome and permissions checklist: https://mobbin.com/flows/1d328006-8692-4556-a642-f60fab639b3d
- Halide permission checklist, "what and why": https://mobbin.com/screens/bd436aa4-c569-4472-8d10-9b7769c63193
- Cash App "Not now" + "Continue" priming: https://mobbin.com/screens/a83fa99d-5202-4250-898a-8ccb1745143d
- Waymo permissions list: https://mobbin.com/screens/682f61a7-dd62-4771-aa6b-493ccf16725d
- Google Photos enabling access: https://mobbin.com/flows/f289ade5-5b4e-40d4-a647-bb2058e8cbaf
- Google Health first-run setup checklist card: https://mobbin.com/screens/5c761a21-21d4-4ebd-a88b-27d5a41202a0
- Pool recap story (progress segments, big type reveal): https://mobbin.com/screens/c7f09d97-179b-466b-bdbf-0a2a755c8f21

## Deliverables (in mockups/onboarding/<your-direction>/)
1. features/*.html: the full flow, one page per screen, numbered v1..vN in order, 393x852. Include:
   - the happy path (launch to first result),
   - the permission-denied fallback,
   - the nothing-found fallback,
   - the first-run Timeline (what the user sees after, including any first-run checklist/tips).
2. NOTES.md (<=45 lines): the flow as a numbered list with screen purpose; what each variation bets on; step count;
   risks (where users drop off) and how the design reduces them; SwiftUI hints (TabView(.page), Canvas, matchedGeometry,
   PhotosPicker vs PHPhotoLibrary auth, scenePhase); which existing views/components to reuse; what needs new data.
   Mobbin citations.
3. Render: cd /home/user/SportsApp/mockups && FEATURES_DIR=onboarding/<dir>/features OUT_DIR=onboarding/<dir>/png NODE_PATH=$(npm root -g) node render.cjs
   Pages need <script src=".../kit/kit.js"></script> at the right ../ depth (each folder level adds one ../, see mockups/big-games/explorations/subtle/features for a working example).
   Read your PNGs back and fix anything broken. Also produce one contact sheet PNG of the whole flow (all screens side by side, scaled so the long edge is <= 5000px) at png/flow.png.
Do not modify anything outside your folder. Do not run git commands.
