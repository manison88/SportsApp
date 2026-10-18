/* Abstract stadium bowl: own shapes only. Home plate at the bottom, outfield bleachers at the top. */
window.drawBowl = function (svg, o) {
  const W = o.w, H = o.h, cx = W / 2, cy = o.cy || H / 2 + 6, rx = W / 2 - 6, ry = H / 2 - 8;
  const NS = 'http://www.w3.org/2000/svg';
  const P = (r, a) => { const t = a * Math.PI / 180; return [cx + rx * r * Math.sin(t), cy - ry * r * Math.cos(t)]; };
  const el = (n, at, par) => { const e = document.createElementNS(NS, n); for (const k in at) e.setAttribute(k, at[k]); (par || svg).appendChild(e); return e; };
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  const sector = (r0, r1, a0, a1) => {
    let d = '', s = 5;
    for (let i = 0; i <= s; i++) { const [x, y] = P(r1, a0 + (a1 - a0) * i / s); d += (i ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1); }
    for (let i = s; i >= 0; i--) { const [x, y] = P(r0, a0 + (a1 - a0) * i / s); d += 'L' + x.toFixed(1) + ' ' + y.toFixed(1); }
    return d + 'Z';
  };
  // concourse glow
  el('ellipse', { cx, cy, rx: rx + 2, ry: ry + 2, fill: 'none', stroke: 'rgba(255,255,255,.06)', 'stroke-width': 1 });
  const rings = [[.52, .70, 22, 'l'], [.75, .95, 26, 'u']];
  const hi = o.hi || {};
  rings.forEach(([r0, r1, n, k]) => {
    const step = 360 / n;
    for (let i = 0; i < n; i++) {
      const a0 = i * step + 1.1, a1 = (i + 1) * step - 1.1, mid = (a0 + a1) / 2;
      const m = ((mid + 540) % 360) - 180; // -180..180, 0 = outfield
      const bleach = k === 'l' && Math.abs(m) < 24;
      const key = k + i;
      const h = hi[k] && hi[k].find(q => Math.abs(((q.a - mid + 540) % 360) - 180) < step / 2);
      let fill = bleach ? 'rgba(255,255,255,.14)' : (k === 'l' ? 'rgba(255,255,255,.10)' : 'rgba(255,255,255,.055)');
      let stroke = 'none';
      if (h) { fill = h.color; stroke = h.color; }
      const p = el('path', { d: sector(r0, r1, a0, a1), fill, 'fill-opacity': h ? .42 : 1, stroke, 'stroke-width': h ? 1.2 : 0 });
    }
  });
  // field
  el('ellipse', { cx, cy: cy - ry * .02, rx: rx * .44, ry: ry * .44, fill: '#0f2a1d', stroke: 'rgba(255,255,255,.08)' });
  // infield diamond
  const D = [[0, .02], [.22, .20], [0, .38], [-.22, .20]].map(([x, y]) => [cx + rx * x * 1.0, cy + ry * (.34 - y * 1.3)]);
  el('path', { d: 'M' + D.map(p => p.map(v => v.toFixed(1)).join(' ')).join('L') + 'Z', fill: '#3a2d1d', 'fill-opacity': .8, stroke: 'rgba(255,255,255,.25)', 'stroke-width': .8 });
  el('circle', { cx, cy: cy - ry * .06, r: 2.3, fill: 'rgba(255,255,255,.5)' });
  // gate marker
  if (o.gate) {
    const [gx, gy] = P(1.02, o.gate);
    el('rect', { x: gx - 4, y: gy - 4, width: 8, height: 8, rx: 2, fill: '#f5f1ea' });
  }
  // dots
  (o.dots || []).forEach(d => {
    const [x, y] = P(d.ring === 'l' ? .61 : .85, d.a);
    if (d.you) { el('circle', { cx: x, cy: y, r: 15, fill: d.color, 'fill-opacity': .12 }); el('circle', { cx: x, cy: y, r: 10, fill: 'none', stroke: d.color, 'stroke-opacity': .5, 'stroke-width': 1 }); }
    else { el('circle', { cx: x, cy: y, r: 12, fill: d.color, 'fill-opacity': .16 }); }
    el('circle', { cx: x, cy: y, r: d.you ? 6.5 : 6, fill: d.color, stroke: '#050506', 'stroke-width': 2 });
    if (d.label) {
      const w = d.label.length * 6.1 + 14, lx = x + (d.dx || 0) - w / 2, ly = y + (d.dy || -26);
      el('rect', { x: lx, y: ly, width: w, height: 19, rx: 9.5, fill: 'rgba(8,8,10,.88)', stroke: d.color, 'stroke-opacity': .7, 'stroke-width': 1 });
      const t = el('text', { x: lx + w / 2, y: ly + 13, 'text-anchor': 'middle', fill: '#f5f1ea', 'font-size': 10.5, 'font-weight': 600, 'font-family': 'Inter' }); t.textContent = d.label;
    }
  });
  if (o.text) o.text.forEach(t => { const e = el('text', { x: t.x, y: t.y, 'text-anchor': 'middle', fill: 'rgba(245,241,234,.4)', 'font-size': 8.5, 'font-weight': 600, 'letter-spacing': 1.4, 'font-family': 'Inter' }); e.textContent = t.s; });
  return { P };
};
