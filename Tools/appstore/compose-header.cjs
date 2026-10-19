#!/usr/bin/env node
/* Builds the App Store product page header (21:9, 3840x1646) and search results image (3:2, 3840x2560).
 *   NODE_PATH=$(npm root -g) node Tools/appstore/compose-header.cjs
 * Writes opaque PNGs to AppStore/out/header/. */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const RAW = path.join(ROOT, 'AppStore/raw');
const OUT = path.join(ROOT, 'AppStore/out/header');
const ICON = 'file://' + path.join(ROOT, 'Witness/Assets.xcassets/AppIcon.appiconset/icon-1024.png');
const brand = `<div class="brand"><img class="icon" src="${ICON}"><span>WITNESS <span class="a">SPORTS</span></span></div>`;
const raw = p => 'file://' + path.join(RAW, fs.readdirSync(RAW).find(f => f.startsWith(p)));

const css = (w, h) => `<link rel="stylesheet" href="file://${ROOT}/mockups/kit/kit.css"><style>
html,body{margin:0;width:${w}px;height:${h}px;background:#050506;overflow:hidden}
body{position:relative;font-family:'Inter',sans-serif;color:#f5f1ea}
.bg{position:absolute;inset:0;background:radial-gradient(ellipse 60% 90% at 78% 40%,rgba(255,181,71,.22),transparent 70%),linear-gradient(180deg,#0b0b0d,#050506)}
.h{font:800 var(--hs)/.92 'Barlow Condensed','Anton',sans-serif;text-transform:uppercase;letter-spacing:1px}
.h .a{color:#ffb547}
.s{margin-top:28px;font:500 var(--ss)/1.25 'Inter',sans-serif;color:rgba(245,241,234,.72)}
.brand{display:flex;align-items:center;gap:22px;font:800 40px 'Barlow Condensed',sans-serif;letter-spacing:6px;color:#f5f1ea;margin-bottom:30px}
.brand .a{color:#ffb547}
.brand .icon{width:96px;height:96px;border-radius:22px;box-shadow:0 10px 30px rgba(0,0,0,.6),0 0 0 1px rgba(255,255,255,.08)}
.t.c .brand{justify-content:center}
.ph{position:absolute;width:var(--pw);aspect-ratio:1320/2868;border-radius:calc(var(--pw)*.15);background:#000;padding:calc(var(--pw)*.022);box-sizing:border-box;
 box-shadow:0 0 0 3px #2b2b31,0 0 0 7px #101013,0 50px 120px rgba(0,0,0,.75),0 0 160px rgba(255,181,71,.12)}
.ph img{width:100%;height:100%;display:block;object-fit:cover;border-radius:calc(var(--pw)*.13)}
</style>`;

const header = () => `<!doctype html><html><head><meta charset="utf-8">${css(1920, 823)}<style>:root{--hs:128px;--ss:32px;--pw:330px}
.t{position:absolute;left:110px;top:230px;width:900px}
</style></head><body><div class="bg"></div>
<div class="t">${brand}<div class="h">Every game<br>you've <span class="a">been to.</span></div><div class="s">Your photos, scores and stadiums in one place.</div></div>
<div class="ph" style="left:1010px;top:90px;transform:rotate(-5deg)"><img src="${raw('store-04')}"></div>
<div class="ph" style="left:1330px;top:150px;transform:rotate(0deg);z-index:2"><img src="${raw('store-01')}"></div>
<div class="ph" style="left:1650px;top:80px;transform:rotate(5deg)"><img src="${raw('store-02')}"></div>
</body></html>`;

const search = () => `<!doctype html><html><head><meta charset="utf-8">${css(1920, 1280)}<style>:root{--hs:150px;--ss:38px;--pw:620px}
.bg{background:radial-gradient(ellipse 70% 50% at 50% 85%,rgba(255,181,71,.24),transparent 70%),linear-gradient(180deg,#0b0b0d,#050506)}
.t{position:absolute;left:0;right:0;top:90px;text-align:center}
.ph{left:680px;top:640px}
</style></head><body><div class="bg"></div>
<div class="t c">${brand}<div class="h">Every game you've <span class="a">been to.</span></div><div class="s">Find them in your photos. Relive the night.</div></div>
<div class="ph" style="left:190px;top:560px;transform:rotate(-6deg)"><img src="${raw('store-04')}"></div>
<div class="ph" style="left:650px;top:520px;z-index:2"><img src="${raw('store-01')}"></div>
<div class="ph" style="left:1110px;top:560px;transform:rotate(6deg)"><img src="${raw('store-02')}"></div>
</body></html>`;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  for (const [name, html, w, h] of [['header-3840x1646.png', header(), 1920, 823], ['search-3840x2560.png', search(), 1920, 1280]]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
    const p = await ctx.newPage();
    const tmp = path.join(OUT, '_page.html');
    fs.writeFileSync(tmp, html);
    await p.goto('file://' + tmp, { waitUntil: 'load' });
    await p.evaluate(() => document.fonts.ready);
    await p.waitForTimeout(400);
    await p.screenshot({ path: path.join(OUT, name) });
    await ctx.close();
  }
  await browser.close();
  fs.rmSync(path.join(OUT, '_page.html'), { force: true });
})();
