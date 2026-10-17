/* Witness mockup kit runtime.
 *  - Injects the iOS status bar + home indicator (body data-chrome="dark" for black glyphs,
 *    data-chrome="none" to skip).
 *  - Paints generative "photos" into <canvas class="photo" data-style="…" data-seed="…"
 *    data-accent="#hex" data-secondary="#hex" data-board="CLE 2|CHC 3" data-sport="hockey">.
 *    Styles: diamond nightField pitch dayGame snowGame lightTower crowd celebration scoreboard
 *            concourse arena skyline trackside tailgate
 *  - Sets window.__ready = true when fonts are loaded and every canvas is painted.
 */
(function () {
  // ---------------- chrome ----------------
  const SIGNAL = '<svg width="19" height="12" viewBox="0 0 19 12"><rect x="0" y="8" width="3.2" height="4" rx="1"/><rect x="5" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="10" y="3" width="3.2" height="9" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>';
  const WIFI = '<svg width="17" height="12" viewBox="0 0 17 12"><path d="M8.5 2.2c2.4 0 4.6.9 6.3 2.5l1.2-1.2A10.6 10.6 0 0 0 8.5.5 10.6 10.6 0 0 0 1 3.5l1.2 1.2a8.9 8.9 0 0 1 6.3-2.5Zm0 3.4c1.5 0 2.9.6 3.9 1.5l1.2-1.2a7.3 7.3 0 0 0-10.2 0l1.2 1.2a5.6 5.6 0 0 1 3.9-1.5Zm0 3.4c.6 0 1.2.2 1.6.6L8.5 11.3 6.9 9.6c.4-.4 1-.6 1.6-.6Z"/></svg>';
  const BATT = '<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.6" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2.3"/><path d="M25 4.5v4c.8-.3 1.4-1.1 1.4-2s-.6-1.7-1.4-2Z" opacity=".45"/></svg>';

  function chrome() {
    const mode = document.body.dataset.chrome;
    if (mode === 'none') return;
    const dark = mode === 'dark' ? ' dark' : '';
    const sb = document.createElement('div');
    sb.className = 'statusbar' + dark;
    sb.innerHTML = `<span>9:41</span><span class="icons">${SIGNAL}${WIFI}${BATT}</span>`;
    document.body.appendChild(sb);
    if (document.body.dataset.homebar !== 'none') {
      const hb = document.createElement('div');
      hb.className = 'homebar' + dark;
      document.body.appendChild(hb);
    }
  }

  // ---------------- seeded rng ----------------
  function rng(seed) {
    let s = (seed >>> 0) || 1;
    const f = () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
    f.r = (a, b) => a + (b - a) * f();
    f.chance = (p) => f() < p;
    return f;
  }

  const hex = (h, a = 1) => {
    h = h.replace('#', '');
    const n = parseInt(h, 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
  };

  // ---------------- painter ----------------
  function paint(canvas) {
    const dpr = 3;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (!w || !h) return;
    canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    const c = canvas.getContext('2d');
    c.scale(dpr, dpr);
    const d = canvas.dataset;
    const R = rng(parseInt(d.seed || '7', 10) * 2654435761);
    const A = d.accent || '#ffb547', B = d.secondary || '#ffd9a0';
    const P = new Painter(c, w, h, A, B, R, d);
    (P[d.style] || P.nightField).call(P);
    P.vignette(d.vignette ? parseFloat(d.vignette) : 0.6);
  }

  class Painter {
    constructor(c, w, h, A, B, R, d) { Object.assign(this, { c, w, h, A, B, R, d }); }

    lin(x0, y0, x1, y1, stops) { const g = this.c.createLinearGradient(x0, y0, x1, y1); stops.forEach(([o, col]) => g.addColorStop(o, col)); return g; }
    rect(x, y, w, h, style) { this.c.fillStyle = style; this.c.fillRect(x, y, w, h); }
    glow(x, y, r, col, a) {
      const c = this.c; c.save(); c.globalCompositeOperation = 'screen';
      const g = c.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, hex(col, a)); g.addColorStop(.35, hex(col, a * .32)); g.addColorStop(1, hex(col, 0));
      c.fillStyle = g; c.fillRect(x - r, y - r, r * 2, r * 2); c.restore();
    }
    vignette(s) {
      const { c, w, h } = this;
      const g = c.createRadialGradient(w / 2, h * .45, 0, w / 2, h * .45, Math.max(w, h) * .8);
      g.addColorStop(.45, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${s})`);
      c.fillStyle = g; c.fillRect(0, 0, w, h);
    }

    // skies
    nightSky(hz) {
      const { w, h } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h * hz, [[0, '#020306'], [.6, '#070b16'], [1, '#121a2e']]));
      this.glow(w * .5, h * hz, w * .9, '#ffe2b0', .16);
      this.glow(w * .3, h * hz * .8, w * .5, this.A, .10);
    }
    daySky(hz) {
      const { w, h } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h * hz, [[0, '#2e6fc2'], [.6, '#79aee6'], [1, '#d8e8f5']]));
      this.glow(w * .85, h * .02, w * .7, '#fff6e0', .75);
    }
    overcast(hz) {
      const { w, h } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h * hz, [[0, '#4b535e'], [.6, '#7f8893'], [1, '#a9b0b8']]));
    }

    lightBank(x, y, s, dim) {
      const { c, w, R } = this; const k = dim ? .55 : 1;
      this.glow(x, y, w * .75 * s, '#ffe9c4', .30 * k);
      this.glow(x, y, w * .22 * s, '#ffffff', .75 * k);
      c.save(); c.globalCompositeOperation = 'screen';
      c.fillStyle = `rgba(191,216,255,${.35 * k})`;
      c.beginPath(); c.ellipse(x, y, w * .6 * s, 1.2 * s, 0, 0, Math.PI * 2); c.fill();
      const lamp = Math.max(2.5, w * .018 * s), gap = lamp * .55, cols = 6, rows = 3;
      const gw = cols * (lamp + gap), gh = rows * (lamp + gap);
      c.fillStyle = `rgba(255,255,255,${.95 * k})`;
      for (let r = 0; r < rows; r++) for (let q = 0; q < cols; q++) c.fillRect(x - gw / 2 + q * (lamp + gap), y - gh / 2 + r * (lamp + gap), lamp, lamp);
      c.fillStyle = `rgba(255,255,255,${.5 * k})`;
      for (let i = 0; i < 18 * s; i++) c.fillRect(x + R.r(-.25, .25) * w * s, y + R.r(-.02, .18) * this.h * s, 1.4, 1.4);
      c.restore();
    }

    stands(top, bot, day) {
      const { c, w, h, R, A, B } = this;
      const y0 = h * top, y1 = h * bot;
      this.rect(0, y0, w, y1 - y0, this.lin(0, y0, 0, y1, day ? [[0, '#2a2e36'], [1, '#1a1c21']] : [[0, '#0c0c12'], [1, '#07070a']]));
      const pal = day ? [hex(A, .55), 'rgba(255,255,255,.35)', hex(B, .4), 'rgba(201,183,156,.35)']
                      : [hex(A, .32), 'rgba(255,255,255,.10)', hex(B, .22), 'rgba(138,127,112,.18)'];
      const n = Math.floor(w * (y1 - y0) / 14);
      for (let i = 0; i < n; i++) { c.fillStyle = pal[i % 4]; const s = R.r(1.2, 2.4); c.fillRect(R() * w, R.r(y0, y1), s, s); }
      const ry = y0 + (y1 - y0) * .34;
      c.save(); c.globalCompositeOperation = 'screen';
      c.fillStyle = this.lin(0, 0, w, 0, [[0, hex(A, .9)], [.5, hex(B, .8)], [1, hex(A, .9)]]);
      c.fillRect(0, ry, w, Math.max(2, h * .006)); c.restore();
      this.glow(w * .5, ry, w * .5, A, day ? .08 : .16);
      if (!day) for (let i = 0; i < 10; i++) this.glow(R() * w, R.r(y0, y1), 6, '#ffffff', .9);
      this.rect(0, y1 - h * .02, w, h * .02, this.lin(0, y1 - h * .02, 0, y1, [[0, '#0b2a1b'], [1, '#06150d']]));
    }

    field(top, mark, pal) {
      const { c, w, h } = this; const y0 = h * top, fh = h - y0;
      const greens = { night: ['#3c9a55', '#1d6a34', '#0c3a1c'], day: ['#5db566', '#3a8c45', '#246b30'], snow: ['#e3e8ea', '#c7d2cf', '#93a39c'] }[pal];
      this.rect(0, y0, w, fh, this.lin(0, y0, 0, h, [[0, greens[0]], [.5, greens[1]], [1, greens[2]]]));
      c.fillStyle = `rgba(255,255,255,${pal === 'snow' ? .06 : .045})`;
      for (let i = 0; i < 12; i += 2) {
        const t0 = i / 12 - .5, t1 = (i + 1) / 12 - .5;
        c.beginPath(); c.moveTo(w * .5 + t0 * w * 1.1, y0); c.lineTo(w * .5 + t1 * w * 1.1, y0);
        c.lineTo(w * .5 + t1 * w * 3.2, h); c.lineTo(w * .5 + t0 * w * 3.2, h); c.fill();
      }
      const line = `rgba(255,255,255,${pal === 'snow' ? .35 : .55})`;
      if (mark === 'baseball') {
        const home = [w * .5, h + fh * .05], first = [w * .86, y0 + fh * .55], second = [w * .5, y0 + fh * .28], third = [w * .14, y0 + fh * .55];
        c.fillStyle = pal === 'day' ? '#b07a50' : '#7a4e33';
        c.beginPath(); c.ellipse(w * .5, y0 + fh * .18 + fh * .55, w * .48, fh * .55, 0, 0, Math.PI * 2); c.fill();
        const cx = w * .5, cy = (home[1] + second[1]) / 2, k = .82, s = p => [cx + (p[0] - cx) * k, cy + (p[1] - cy) * k];
        c.fillStyle = this.lin(0, second[1], 0, home[1], [[0, greens[0]], [1, greens[1]]]);
        c.beginPath(); [home, first, second, third].map(s).forEach((p, i) => i ? c.lineTo(...p) : c.moveTo(...p)); c.fill();
        c.fillStyle = pal === 'day' ? '#b98458' : '#84573a';
        c.beginPath(); c.ellipse(cx, cy, w * .05, fh * .03, 0, 0, Math.PI * 2); c.fill();
        c.strokeStyle = line; c.lineWidth = 1.4; c.beginPath();
        c.moveTo(...home); c.lineTo(w * 1.3, y0 + fh * .1); c.moveTo(...home); c.lineTo(-w * .3, y0 + fh * .1); c.stroke();
        c.fillStyle = 'rgba(255,255,255,.9)'; [first, second, third].forEach(b => c.fillRect(b[0] - 3, b[1] - 2, 6, 4));
      } else if (mark === 'football') {
        c.strokeStyle = line; c.globalAlpha = .7; c.lineWidth = 1.2; c.beginPath();
        for (let i = 0; i < 9; i++) { const y = y0 + fh * Math.pow(i / 8, 1.6); c.moveTo(0, y); c.lineTo(w, y); }
        c.stroke(); c.globalAlpha = .5; c.beginPath();
        for (let i = 0; i < 30; i++) { const t = i / 29, y = y0 + fh * Math.pow(t, 1.6); [w * .38 - t * w * .2, w * .62 + t * w * .2].forEach(x => { c.moveTo(x - 3, y); c.lineTo(x + 3, y); }); }
        c.stroke(); c.globalAlpha = 1;
      } else if (mark === 'soccer') {
        const mid = y0 + fh * .42; c.strokeStyle = line; c.lineWidth = 1.4; c.beginPath();
        c.moveTo(0, mid); c.lineTo(w, mid); c.stroke();
        c.beginPath(); c.ellipse(w * .5, mid, w * .22, fh * .12, 0, 0, Math.PI * 2); c.stroke();
      }
      this.rect(0, y0, w, fh, this.lin(0, y0 + fh * .3, 0, h, [[0, 'rgba(0,0,0,0)'], [1, 'rgba(0,0,0,.45)']]));
    }

    snow() {
      const { c, w, h, R } = this;
      c.fillStyle = 'rgba(255,255,255,.75)';
      for (let i = 0; i < w * h / 600; i++) { const s = R.r(1, 3.4); c.beginPath(); c.arc(R() * w, R() * h, s / 2, 0, 7); c.fill(); }
      c.save(); c.filter = 'blur(3.5px)'; c.fillStyle = 'rgba(255,255,255,.45)';
      for (let i = 0; i < 26; i++) { const s = R.r(7, 16); c.beginPath(); c.arc(R() * w, R() * h, s / 2, 0, 7); c.fill(); }
      c.restore();
    }

    // ---- scenes ----
    diamond() { const { w, h, R } = this; this.nightSky(.44); this.lightBank(w * R.r(.08, .25), h * R.r(.08, .16), .7); this.lightBank(w * R.r(.72, .92), h * R.r(.06, .14), .8); this.stands(.36, .56); this.field(.54, 'baseball', 'night'); }
    nightField() { const { w, h } = this; this.nightSky(.42); this.lightBank(w * .18, h * .10, .75); this.lightBank(w * .82, h * .08, .85); this.stands(.34, .55); this.field(.53, this.d.sport === 'baseball' ? 'baseball' : 'football', 'night'); }
    pitch() { const { w, h } = this; this.nightSky(.40); this.roof(.16); this.lightBank(w * .12, h * .14, .55); this.lightBank(w * .88, h * .14, .55); this.stands(.18, .55); this.field(.53, 'soccer', 'night'); }
    dayGame() { this.daySky(.36); this.stands(.30, .52, true); this.field(.50, this.d.sport === 'football' ? 'football' : 'baseball', 'day'); this.shadow(); }
    snowGame() { const { w, h } = this; this.overcast(.40); this.lightBank(w * .2, h * .1, .6, true); this.lightBank(w * .85, h * .12, .6, true); this.stands(.32, .56, true); this.field(.54, 'football', 'snow'); this.snow(); }
    roof(y) {
      const { c, w, h, A } = this;
      c.fillStyle = '#040406'; c.beginPath(); c.moveTo(0, h * (y - .06)); c.quadraticCurveTo(w / 2, h * (y + .05), w, h * (y - .06)); c.lineTo(w, 0); c.lineTo(0, 0); c.fill();
      c.save(); c.globalCompositeOperation = 'screen'; c.strokeStyle = hex(A, .7); c.lineWidth = 2;
      c.beginPath(); c.moveTo(0, h * (y - .06)); c.quadraticCurveTo(w / 2, h * (y + .05), w, h * (y - .06)); c.stroke();
      c.filter = 'blur(4px)'; c.lineWidth = 6; c.strokeStyle = hex(A, .5); c.stroke(); c.restore();
    }
    shadow() { const { c, w, h } = this; c.fillStyle = 'rgba(0,0,0,.22)'; c.beginPath(); c.moveTo(0, h * .5); c.lineTo(w * .42, h * .5); c.lineTo(w * .1, h); c.lineTo(0, h); c.fill(); }

    lightTower() {
      const { c, w, h, R, A } = this;
      this.nightSky(.95);
      const bx = w * .64, by = h * .26;
      c.save(); c.globalCompositeOperation = 'screen';
      for (let i = 0; i < 7; i++) {
        const sp = (i - 3) * w * .16;
        c.fillStyle = this.lin(bx, by, bx, h, [[0, 'rgba(255,243,218,.10)'], [1, 'rgba(255,243,218,0)']]);
        c.beginPath(); c.moveTo(bx, by); c.lineTo(bx - w * .5 + sp - w * .04, h * 1.05); c.lineTo(bx - w * .5 + sp + w * .04, h * 1.05); c.fill();
      }
      c.restore();
      c.strokeStyle = '#0a0a0e'; c.lineWidth = 2.2; c.beginPath();
      const bl = [w * .58, h * 1.02], br = [w * .74, h * 1.02], tl = [w * .61, h * .34], tr = [w * .67, h * .34];
      c.moveTo(...bl); c.lineTo(...tl); c.moveTo(...br); c.lineTo(...tr);
      for (let i = 0; i < 9; i++) {
        const t0 = i / 9, t1 = (i + 1) / 9, L = t => [bl[0] + (tl[0] - bl[0]) * t, bl[1] + (tl[1] - bl[1]) * t], Rr = t => [br[0] + (tr[0] - br[0]) * t, br[1] + (tr[1] - br[1]) * t];
        c.moveTo(...L(t0)); c.lineTo(...Rr(t1)); c.moveTo(...L(t1)); c.lineTo(...Rr(t1));
      }
      c.stroke();
      const fw = w * .4, fh = h * .14, fx = bx - w * .2, fy = by - h * .08;
      c.fillStyle = '#08080b'; c.fillRect(fx, fy, fw, fh);
      this.glow(bx, by, w * 1.1, '#ffe5ba', .35); this.glow(bx, by, w * .42, '#ffffff', .55);
      const cols = 7, rows = 4, lw = fw / cols, lh = fh / rows;
      c.save(); c.shadowColor = 'rgba(255,241,208,.95)'; c.shadowBlur = 10; c.fillStyle = '#fffdf6';
      for (let r = 0; r < rows; r++) for (let q = 0; q < cols; q++) { c.beginPath(); c.ellipse(fx + q * lw + lw / 2, fy + r * lh + lh / 2, lw * .36, lh * .36, 0, 0, 7); c.fill(); }
      c.restore();
      c.save(); c.globalCompositeOperation = 'screen'; c.strokeStyle = 'rgba(255,255,255,.16)'; c.lineWidth = 1; c.beginPath();
      for (let i = 0; i < 6; i++) { const a = i * Math.PI / 6 + .2; c.moveTo(bx - Math.cos(a) * w * .55, by - Math.sin(a) * w * .55); c.lineTo(bx + Math.cos(a) * w * .55, by + Math.sin(a) * w * .55); }
      c.stroke(); c.fillStyle = 'rgba(255,255,255,.55)';
      for (let i = 0; i < 60; i++) c.fillRect(bx + R.r(-.4, .3) * w, by + R.r(-.1, .35) * h, 1.6, 1.6);
      c.restore();
      c.fillStyle = '#030304'; c.beginPath(); c.moveTo(0, h * .78); c.lineTo(w * .42, h * .86); c.lineTo(w * .42, h); c.lineTo(0, h); c.fill();
      this.glow(w * .2, h * .82, w * .3, A, .12);
    }

    crowd(confetti) {
      const { c, w, h, R, A, B } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h, [[0, '#0a0b10'], [1, '#050506']]));
      this.glow(w * .5, h * .05, w * 1.1, '#ffeacb', .5); this.glow(w * .15, h * .2, w * .7, A, .45); this.glow(w * .9, h * .25, w * .6, B, .28);
      if (confetti) {
        const cols = [A, B, '#ffffff', '#ffb547'];
        for (let i = 0; i < 140; i++) { const s = R.r(2, 6.5); c.save(); c.translate(R() * w, R() * h * .75); c.rotate(R() * 3.14); c.fillStyle = hex(cols[i % 4], R.r(.55, .95)); c.fillRect(-s / 2, -s * .3, s, s * .6); c.restore(); }
      }
      for (let row = 0; row < 4; row++) {
        const dp = row / 3, y = h * (.5 + dp * .16), r = w * (.034 + dp * .03);
        const shade = `rgba(4,4,5,${.85 + dp * .15})`;
        let x = R.r(-r, r);
        const heads = [], arms = [], phones = [];
        while (x < w + r * 2) {
          const jy = y + R.r(-r * .4, r * .4);
          heads.push([x, jy]);
          if (R.chance(confetti ? .55 : .22)) {
            const side = R.chance(.5) ? 1 : -1, tip = [x + side * r * R.r(.6, 1.6), jy - r * R.r(2.4, 3.6)];
            arms.push([x + side * r * 1.1, jy + r * .9, ...tip]);
            if (R.chance(confetti ? .25 : .6)) phones.push(tip);
          }
          x += r * R.r(1.9, 2.6);
        }
        c.fillStyle = hex(A, .35 * (1 - dp * .6));
        heads.forEach(([x, y]) => { c.beginPath(); c.ellipse(x, y - 1.2, r * .45 + .8, r * .55 + .8, 0, 0, 7); c.fill(); });
        c.strokeStyle = shade; c.lineWidth = r * .42; c.lineCap = 'round';
        arms.forEach(a => { c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(a[2], a[3]); c.stroke(); });
        c.fillStyle = shade;
        heads.forEach(([x, y]) => { c.beginPath(); c.ellipse(x, y, r * .45, r * .55, 0, 0, 7); c.fill(); c.beginPath(); c.roundRect(x - r * 1.5, y + r * .55, r * 3, h, r); c.fill(); });
        c.save(); c.shadowColor = 'rgba(191,212,255,.9)'; c.shadowBlur = 10; c.fillStyle = 'rgba(221,232,255,.92)';
        phones.forEach(([x, y]) => { c.beginPath(); c.roundRect(x - r * .28, y - r * .5, r * .56, r * .95, 2); c.fill(); });
        c.restore();
      }
    }
    celebration() { this.crowd(true); }

    scoreboard() {
      const { c, w, h, R, A, B, d } = this;
      this.nightSky(.9); this.glow(w * .1, h * .1, w * .5, '#ffe9c4', .25);
      const px = w * .08, py = h * .2, pw = w * .84, ph = h * .42;
      c.fillStyle = '#0a0a0d'; c.fillRect(px + pw / 2 - w * .2, py + ph, w * .05, h); c.fillRect(px + pw / 2 + w * .15, py + ph, w * .05, h);
      c.fillStyle = '#101014'; c.beginPath(); c.roundRect(px - 6, py - 6, pw + 12, ph + 12, 6); c.fill();
      c.fillStyle = '#060607'; c.fillRect(px, py, pw, ph);
      this.glow(px + pw / 2, py + ph / 2, pw * .8, '#ffb547', .12);
      const lines = d.board ? d.board.split('|') : ['HOME  ' + Math.floor(R() * 6), 'AWAY  ' + Math.floor(R() * 6)];
      const fs = Math.min(ph / (lines.length + 1) * .95, pw * .16);
      c.font = `800 ${fs}px "JetBrains Mono", monospace`; c.textAlign = 'center'; c.textBaseline = 'middle';
      lines.forEach((ln, i) => {
        const y = py + ph * (i + 1) / (lines.length + 1);
        c.save(); c.shadowColor = 'rgba(255,196,107,.9)'; c.shadowBlur = fs * .5; c.fillStyle = '#ffc46b'; c.fillText(ln, px + pw / 2, y); c.restore();
        c.fillStyle = '#ffd08a'; c.fillText(ln, px + pw / 2, y);
      });
      c.strokeStyle = 'rgba(0,0,0,.55)'; c.lineWidth = .8; c.beginPath();
      for (let x = px; x < px + pw; x += 2.6) { c.moveTo(x, py); c.lineTo(x, py + ph); }
      for (let y = py; y < py + ph; y += 2.6) { c.moveTo(px, y); c.lineTo(px + pw, y); }
      c.stroke();
      c.fillStyle = this.lin(px, 0, px + pw, 0, [[0, A], [1, B]]); c.fillRect(px, py + ph + 10, pw, h * .035);
      this.glow(px + pw / 2, py + ph + 10, pw * .6, A, .3);
      this.stands(.8, 1.0);
    }

    concourse() {
      const { c, w, h, R, A, B } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h, [[0, '#1b120a'], [.5, '#0a0705'], [1, '#040303']]));
      const cols = ['#ffb547', '#fff0d6', A, '#ff8f5a', B];
      c.save(); c.filter = 'blur(3px)'; c.globalCompositeOperation = 'screen';
      for (let i = 0; i < 46; i++) {
        const r = R.r(2, Math.max(3, Math.min(w, h) * .11)), x = R() * w, y = R() * h * .7, a = R.r(.1, .42);
        c.fillStyle = hex(cols[i % 5], a); c.beginPath(); c.arc(x, y, r, 0, 7); c.fill();
        c.strokeStyle = hex(cols[i % 5], a * .6); c.lineWidth = 1.2; c.stroke();
      }
      c.restore();
      for (let i = 0; i < 3; i++) {
        const y = h * (.18 + i * .09), x = w * R.r(.05, .3), sw = w * R.r(.25, .5);
        c.fillStyle = hex(A, .9); c.fillRect(x, y, sw, 3); this.glow(x + sw / 2, y, sw * .6, A, .25);
      }
      this.rect(0, h * .72, w, h * .28, this.lin(0, h * .72, 0, h, [[0, 'rgba(42,27,16,.6)'], [1, '#000']]));
      this.glow(w * .5, h * .74, w * .6, '#ffb547', .18);
    }

    tailgate() {
      const { c, w, h, R, A } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h, [[0, '#1d2a44'], [.45, '#e6825a'], [.62, '#f4b26a'], [1, '#2a1f1a']]));
      this.glow(w * .7, h * .55, w * .9, '#ffd08a', .5);
      // stadium silhouette on the horizon
      c.fillStyle = '#120d10'; c.beginPath(); c.moveTo(0, h * .62); c.lineTo(w * .1, h * .5); c.quadraticCurveTo(w * .5, h * .42, w * .9, h * .5); c.lineTo(w, h * .62); c.lineTo(w, h); c.lineTo(0, h); c.fill();
      this.lightBank(w * .14, h * .44, .45); this.lightBank(w * .86, h * .44, .45);
      // smoke + string lights
      c.save(); c.filter = 'blur(14px)'; c.fillStyle = 'rgba(255,255,255,.18)';
      for (let i = 0; i < 6; i++) { c.beginPath(); c.arc(w * .3 + i * 12, h * .66 - i * 18, 30 + i * 6, 0, 7); c.fill(); }
      c.restore();
      for (let i = 0; i < 22; i++) { const x = i / 21 * w, y = h * .72 + Math.sin(i / 21 * Math.PI) * h * .05; this.glow(x, y, 9, '#ffcf7a', .9); }
      this.glow(w * .3, h * .8, w * .4, A, .2);
    }

    arena() {
      const { c, w, h, A, B, d } = this;
      this.rect(0, 0, w, h * .6, this.lin(0, 0, 0, h * .6, [[0, '#040406'], [1, '#0b0b12']]));
      for (let i = 0; i < 28; i++) { const t = i / 27, x = w * t, y = h * .1 + Math.sin(t * Math.PI) * h * .06; this.glow(x, y, 26, '#fff3dd', .35); c.fillStyle = '#fff'; c.beginPath(); c.arc(x, y, 2, 0, 7); c.fill(); }
      const bx = w * .32, by = h * .2, bw = w * .36, bh = h * .16;
      c.fillStyle = '#0e0e14'; c.beginPath(); c.roundRect(bx, by, bw, bh, 4); c.fill();
      c.fillStyle = this.lin(bx, by, bx + bw, by + bh, [[0, A], [1, hex(B, .8)]]); c.fillRect(bx + 5, by + 5, bw - 10, bh - 10);
      this.glow(bx + bw / 2, by + bh / 2, w * .55, A, .35);
      this.stands(.36, .6);
      const sy = h * .58, sh = h * .42;
      if (d.sport === 'hockey') {
        this.rect(0, sy, w, sh, this.lin(0, sy, 0, h, [[0, '#eaf3f8'], [1, '#b9cedb']]));
        c.strokeStyle = 'rgba(200,16,46,.8)'; c.lineWidth = 3; c.beginPath(); c.moveTo(0, sy + sh * .42); c.lineTo(w, sy + sh * .42); c.stroke();
        c.strokeStyle = 'rgba(29,78,160,.7)'; c.lineWidth = 2; c.beginPath(); c.ellipse(w * .5, sy + sh * .42, w * .15, sh * .12, 0, 0, 7); c.stroke();
        this.rect(0, sy - 6, w, 8, this.lin(0, sy - 6, 0, sy + 2, [[0, '#fff'], [1, '#d8d8d8']]));
      } else {
        this.rect(0, sy, w, sh, this.lin(0, sy, 0, h, [[0, '#d9a066'], [1, '#9c6534']]));
        c.strokeStyle = 'rgba(0,0,0,.08)'; c.lineWidth = 1; c.beginPath();
        for (let i = 0; i < 22; i++) { const t = i / 21 - .5; c.moveTo(w * .5 + t * w * 1.1, sy); c.lineTo(w * .5 + t * w * 3, h); } c.stroke();
        c.fillStyle = hex(A, .75); c.fillRect(w * .36, sy + sh * .1, w * .28, sh * .5);
        c.strokeStyle = 'rgba(255,255,255,.8)'; c.lineWidth = 1.6; c.beginPath(); c.ellipse(w * .5, sy + sh * .6, w * .17, sh * .1, 0, 0, 7); c.stroke();
      }
      this.glow(w * .5, h * .62, w * .7, '#ffffff', .22);
    }

    skyline() {
      const { c, w, h, R, A } = this;
      this.rect(0, 0, w, h, this.lin(0, 0, 0, h * .72, [[0, '#120c26'], [.35, '#4a2348'], [.75, '#e07a4a'], [1, '#f6b26b']]));
      this.glow(w * .62, h * .7, w * .8, '#ffd08a', .55); this.glow(w * .2, h * .3, w * .6, A, .15);
      let x = -10; c.fillStyle = '#07060b'; const win = [];
      while (x < w) {
        const bw = R.r(w * .05, w * .14), bh = R.r(h * .1, h * .48), top = h * .78 - bh;
        c.fillRect(x, top, bw, bh + h * .3);
        for (let wy = top + 6; wy < h * .78; wy += 7) for (let wx = x + 4; wx < x + bw - 4; wx += 5) if (R.chance(.28)) win.push([wx, wy]);
        x += bw + R.r(0, 6);
      }
      c.fillStyle = 'rgba(255,211,138,.8)'; win.forEach(([a, b]) => c.fillRect(a, b, 2, 3));
      this.rect(0, h * .78, w, h * .22, this.lin(0, h * .78, 0, h, [[0, '#0a0810'], [1, '#000']]));
    }

    trackside() {
      const { c, w, h, R, A } = this;
      this.daySky(.32); this.stands(.22, .44, true);
      c.fillStyle = this.lin(0, h * .45, 0, h, [[0, '#3a3b40'], [1, '#1e1f22']]);
      c.beginPath(); c.moveTo(0, h * .5); c.lineTo(w, h * .44); c.lineTo(w, h * .86); c.lineTo(0, h * .98); c.fill();
      for (let i = 0; i < 18; i++) {
        const t0 = i / 18, t1 = (i + 1) / 18; c.fillStyle = i % 2 ? '#fff' : '#e10600';
        c.beginPath(); c.moveTo(w * t0, h * (.5 - .06 * t0)); c.lineTo(w * t1, h * (.5 - .06 * t1)); c.lineTo(w * t1, h * (.5 - .06 * t1) - 6); c.lineTo(w * t0, h * (.5 - .06 * t0) - 6); c.fill();
      }
      const cy = h * .66;
      c.save(); c.filter = 'blur(6px)'; c.fillStyle = this.lin(w * .05, 0, w * .8, 0, [[0, hex(A, 0)], [.6, hex(A, .7)], [1, A]]);
      c.beginPath(); c.roundRect(w * .05, cy - h * .03, w * .75, h * .06, 12); c.fill(); c.restore();
      c.fillStyle = A; c.beginPath(); c.roundRect(w * .56, cy - h * .028, w * .3, h * .05, h * .02); c.fill();
      c.fillStyle = '#000'; [[w * .56 + 4, 0], [w * .86 - h * .05, 0]].forEach(([x]) => { c.beginPath(); c.arc(x + h * .022, cy + h * .02, h * .022, 0, 7); c.fill(); });
      c.strokeStyle = 'rgba(255,255,255,.18)'; c.lineWidth = 1; c.beginPath();
      for (let i = 0; i < 14; i++) { const y = R.r(h * .52, h * .9), x = R.r(0, w * .6); c.moveTo(x, y); c.lineTo(x + R.r(30, 120), y - 4); } c.stroke();
      this.glow(w * .5, h * .3, w * .9, '#fff1d6', .2);
    }
  }

  async function boot() {
    chrome();
    try { await document.fonts.ready; } catch (e) {}
    await Promise.all([...document.images].map(img => img.complete ? null :
      new Promise(r => { img.onload = img.onerror = r; })));
    document.querySelectorAll('canvas.photo').forEach(paint);
    // allow layout-dependent scripts to run after paint
    if (window.afterPaint) await window.afterPaint();
    window.__ready = true;
  }
  window.WitnessKit = { paint, rng, hex };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
