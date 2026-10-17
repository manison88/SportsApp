#!/usr/bin/env node
/* Renders every mockup to PNG with headless Chromium.
 *
 *   NODE_PATH=$(npm root -g) node mockups/render.cjs                 # everything
 *   NODE_PATH=$(npm root -g) node mockups/render.cjs 05-game-memory  # one feature folder
 *
 * Output:
 *   mockups/png/<feature>/<variation>.png   iPhone 16 Pro @3x (1179×2556)
 *   mockups/png/<feature>.png               contact sheet of the feature's variations
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
// FEATURES_DIR / OUT_DIR let other rounds (e.g. round2/) reuse this renderer.
const FEATURES = process.env.FEATURES_DIR ? path.resolve(process.env.FEATURES_DIR) : path.join(ROOT, 'features');
const OUT = process.env.OUT_DIR ? path.resolve(process.env.OUT_DIR) : path.join(ROOT, 'png');

(async () => {
  const only = process.argv.slice(2);
  const folders = fs.readdirSync(FEATURES).filter(f => fs.statSync(path.join(FEATURES, f)).isDirectory())
    .filter(f => !only.length || only.includes(f)).sort();
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 3 });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.error('  page error:', e.message));

  for (const folder of folders) {
    const dir = path.join(FEATURES, folder);
    const files = fs.readdirSync(dir).filter(f => /^v\d.*\.html$/.test(f)).sort();
    fs.mkdirSync(path.join(OUT, folder), { recursive: true });
    const shots = [];
    for (const f of files) {
      await page.goto('file://' + path.join(dir, f));
      await page.waitForFunction(() => window.__ready === true, null, { timeout: 20000 }).catch(() => console.error('  timeout waiting for', f));
      await page.waitForTimeout(150);
      const out = path.join(OUT, folder, f.replace('.html', '.png'));
      await page.screenshot({ path: out });
      const title = await page.title();
      shots.push({ out, title, file: f });
      console.log('rendered', path.relative(ROOT, out));
    }
    // contact sheet
    const meta = fs.existsSync(path.join(dir, 'feature.json')) ? JSON.parse(fs.readFileSync(path.join(dir, 'feature.json'))) : { title: folder };
    const sheet = await ctx.newPage();
    await sheet.setViewportSize({ width: 144 + shots.length * 393 + (shots.length - 1) * 36, height: 1200 });
    const cards = shots.map((s, i) => `
      <figure><img src="file://${s.out}"><figcaption><b>${String(i + 1).padStart(2, '0')}</b> ${s.title}</figcaption></figure>`).join('');
    const sheetHtml = path.join(OUT, folder, '_sheet.html');
    fs.writeFileSync(sheetHtml, `<html><head><link rel="stylesheet" href="file://${ROOT}/kit/kit.css"><style>
      html,body{width:auto;height:auto;overflow:visible;background:#0b0b0d;color:#f5f1ea;font-family:Inter,sans-serif}
      body{padding:64px 72px 72px}
      h1{font:400 64px/1 'Instrument Serif',serif;letter-spacing:-1px;margin-bottom:10px}
      p{font:500 18px/1.4 Inter;color:rgba(245,241,234,.55);margin-bottom:40px;max-width:1400px}
      .row{display:flex;gap:36px}
      figure{width:393px}
      img{width:393px;height:852px;border-radius:44px;display:block;box-shadow:0 0 0 1px rgba(255,255,255,.1),0 30px 60px rgba(0,0,0,.6)}
      figcaption{margin-top:18px;font:500 17px/1.3 Inter;color:rgba(245,241,234,.8)}
      figcaption b{color:#ffb547;margin-right:6px}
    </style></head><body><h1>${meta.title}</h1><p>${meta.summary || ''}</p><div class="row">${cards}</div></body></html>`);
    await sheet.goto('file://' + sheetHtml, { waitUntil: 'load' });
    await sheet.evaluate(() => document.fonts.ready);
    await sheet.screenshot({ path: path.join(OUT, folder + '.png'), fullPage: true });
    await sheet.close();
    console.log('sheet', folder + '.png');
  }
  await browser.close();
})();
