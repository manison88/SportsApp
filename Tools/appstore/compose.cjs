#!/usr/bin/env node
/* Builds the App Store screenshots: each real simulator screen in a device frame under a headline.
 *   NODE_PATH=$(npm root -g) node Tools/appstore/compose.cjs
 * Reads AppStore/raw/store-NN-*.png (1320x2868, from the `appstore` workflow) and writes
 * AppStore/out/6.9in (1320x2868) and AppStore/out/6.5in (1284x2778). */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const RAW = path.join(ROOT, 'AppStore/raw');
const OUT = path.join(ROOT, 'AppStore/out');
const SIZES = [{ dir: '6.9in', w: 1320, h: 2868 }, { dir: '6.5in', w: 1284, h: 2778 }];

// [file prefix, headline (a [..] span is amber), sub line]
const COPY = [
  ['store-01', "EVERY GAME YOU'VE [BEEN TO.]", 'Your whole fan life on one timeline.'],
  ['store-02', 'RELIVE [THE NIGHT.]', 'Your photos, the score and the weather, together.'],
  ['store-03', 'SEE THE MOMENT [IT HAPPENED.]', "Your photos placed on the game's own clock."],
  ['store-04', 'COLLECT [EVERY STADIUM.]', 'A stamp for every ground you visit.'],
  ['store-05', 'COUNT [THE MILES.]', 'Every venue, mapped from home.'],
  ['store-06', 'KNOW [YOUR GROUND.]', 'Your record, your seats and every visit.'],
  ['store-07', 'YOUR WHOLE [FAN RECORD.]', 'Every win, loss and number in one place.'],
  ['store-08', '[SHARE] THE NIGHT.', 'Story cards made from your own game.'],
];

const page = (w, h, shot, head, sub) => {
  const u = w / 1320;
  const headHtml = head.replace(/\[(.*?)\]/g, '<span class="a">$1</span>');
  return `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>
html,body{margin:0;width:${w}px;height:${h}px;background:#050506;overflow:hidden}
body{position:relative;font-family:'Inter',sans-serif;color:#f5f1ea}
.bg{position:absolute;inset:0;background:
  radial-gradient(ellipse 90% 40% at 50% 0%,rgba(255,181,71,.20),transparent 70%),
  radial-gradient(ellipse 80% 35% at 50% 100%,rgba(255,181,71,.10),transparent 70%),
  linear-gradient(180deg,#0b0b0d,#050506)}
.t{position:absolute;left:${90 * u}px;right:${90 * u}px;top:${130 * u}px}
.h{font:800 ${176 * u}px/${0.93}  'Barlow Condensed','Anton',sans-serif;text-transform:uppercase;letter-spacing:${1 * u}px}
.h .a{color:#ffb547}
.s{margin-top:${36 * u}px;font:500 ${54 * u}px/1.25 'Inter',sans-serif;color:rgba(245,241,234,.72)}
.phone{position:absolute;left:${(1320 - 1010) / 2 * u}px;top:${(h / u - 2170 - 64)* u}px;width:${1010 * u}px;height:${2194 * u}px;
  border-radius:${150 * u}px;background:#000;padding:${22 * u}px;box-sizing:border-box;
  box-shadow:0 0 0 ${3 * u}px #2b2b31,0 0 0 ${8 * u}px #101013,0 ${60 * u}px ${140 * u}px rgba(0,0,0,.75),0 0 ${200 * u}px rgba(255,181,71,.10)}
.scr{width:100%;height:100%;border-radius:${130 * u}px;overflow:hidden;position:relative;background:#050506}
.scr img{width:100%;height:100%;display:block;object-fit:cover}
.island{position:absolute;left:50%;top:${14 * u}px;transform:translateX(-50%);width:${240 * u}px;height:${70 * u}px;border-radius:${40 * u}px;background:#000}
</style></head><body><div class="bg"></div><div class="t"><div class="h">${headHtml}</div><div class="s">${sub}</div></div>
<div class="phone"><div class="scr"><img src="file://${shot}"><div class="island"></div></div></div></body></html>`;
};

(async () => {
  const browser = await chromium.launch();
  for (const size of SIZES) {
    fs.mkdirSync(path.join(OUT, size.dir), { recursive: true });
    const ctx = await browser.newContext({ viewport: { width: size.w, height: size.h }, deviceScaleFactor: 1 });
    const p = await ctx.newPage();
    for (const [prefix, head, sub] of COPY) {
      const file = fs.readdirSync(RAW).find(f => f.startsWith(prefix));
      if (!file) { console.log('missing', prefix); continue; }
      const tmp = path.join(OUT, '_page.html');
      fs.writeFileSync(tmp, page(size.w, size.h, path.join(RAW, file), head, sub));
      await p.goto('file://' + tmp, { waitUntil: 'load' });
      await p.evaluate(() => document.fonts.ready);
      await p.waitForTimeout(400);
      const out = path.join(OUT, size.dir, file.replace('store-', 'appstore-'));
      await p.screenshot({ path: out });
      console.log('wrote', path.relative(ROOT, out));
    }
    await ctx.close();
  }
  await browser.close();
  fs.rmSync(path.join(OUT, '_page.html'), { force: true });
})();
