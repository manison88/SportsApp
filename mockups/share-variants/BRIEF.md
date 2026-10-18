# Share cards: visual-first variations (mockups only, do not build)

Read first: `../BRIEF.md` and `../final/BRIEF.md` (the bar, the kit, fonts, the rules: no real team logos, city names or 2-3 letter codes as typographic monograms, no lorem ipsum, nothing clips or overlaps, check every PNG with the Read tool and iterate 2-3 passes). Design language: dark ink, amber `--signal` is "you", condensed type for numbers, Broadcast feel, super clean. Content/data source of truth: `../round2/BRIEF.md` data section, plus the final mockup of the feature you are given in `../final/features/<NN-slug>/v1-final.html` and the sample data in `../../Witness/Resources/Sample/library.json`. Photos live in `../photos/` (names in `../photos/INDEX.md`); crop different windows of them for different looks.

## What a share card is
Every screen in Witness has a Share button. It opens a sheet that shows the thing as a **9:16 story card** (Instagram/TikTok story), in 5 styles the user swipes between. The user is posting it for friends. The client's feedback on the current styles, for EVERY share experience: **the first style and the fourth are the best** (the first is the photo/hero-number style, the fourth is the paper/light style). The others are weak.

## Your task
For the share experience you are assigned, design **6 new variations**, organised as **3 directions x 2 treatments**. All three directions must be **focused on the visuals of the thing being shared** (not on layout chrome or stat boxes):
- Pick the 3 directions that make the best-looking, most shareable picture of THIS thing. Examples: the photo itself as the hero with one beautiful overlay; the thing drawn as a picture (a seating chart lit up, a route drawn across a map, a stadium aerial, a stamp grid, a scoreboard); a bold poster-style typographic treatment; a paper/print keepsake. Make the 3 directions clearly different from each other.
- Each direction gets 2 treatments (for example dark vs light/paper, or two different crops/compositions/accent colors). So files v1/v2 are direction A, v3/v4 direction B, v5/v6 direction C.
- Keep what the client liked about styles 1 and 4 (a big confident hero, restraint, air, one idea per card), improve on the rest.
- Real, specific content only (use the data above). Big type, few elements, nothing under 12pt on a 393pt-wide canvas.

## Canvas and files
- Each mockup is an HTML page at 393x852 (the phone viewport the renderer uses). Draw the share card as a **353x628 (9:16) card centered on the ink background** with 12px radius and a subtle shadow, and a one-line caption under it (direction name + treatment) in small `--text-3` type. Nothing else on the page.
- Put the files in `mockups/share-variants/features/<your-slug>/` named `v1-<name>.html` ... `v6-<name>.html` with a short `<title>` that names the direction and treatment, and a `feature.json` like `{"title": "<Experience> share, 6 variations", "summary": "<one sentence>"}`. Your folder is `mockups/share-variants/features/<slug>/`, so link `../../../kit/kit.css`, `../../../kit/kit.js` and photos at `../../../photos/`.
- Render: `cd /home/user/SportsApp/mockups && FEATURES_DIR=share-variants/features OUT_DIR=share-variants/png NODE_PATH=$(npm root -g) node render.cjs <your-slug>`. It writes `share-variants/png/<slug>/vN-*.png` and a contact sheet `share-variants/png/<slug>.png`. Look at every PNG and the contact sheet with the Read tool, fix problems, render again (2-3 passes).
- **Do not run any git command** (another process commits). Do not touch files outside your own folders.
- When done, reply with: the slug, and for each of the 6 files one line (what it is and why it is shareable). Be honest about weak ones.
