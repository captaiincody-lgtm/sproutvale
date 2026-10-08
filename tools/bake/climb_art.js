// Art for the climb up the Abyssal Volcano (the Godot version only): the four cave/mountain maps, the
// summit, their monsters and King Yeti.
// Runs inside a blank Chromium page (see climb.mjs). Every function here draws with the 2D canvas and
// returns canvases; climb.mjs saves them as PNGs under godot/art/climb. All sprites are drawn at 2× the
// game's world units, like the rest of the game's art.
/* eslint-disable no-unused-vars */
'use strict';

const TAU = Math.PI * 2;
const OUT = '#0a0c14';

// ------------------------------------------------------------------ helpers (same as abyss_art.js)
function rng(seed) { let s = (seed >>> 0) || 1; return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; }; }
function cv(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function g2(c) { const x = c.getContext('2d'); x.imageSmoothingEnabled = false; return x; }
function hex(c) { const n = parseInt(c.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function E(x, cx, cy, rx, ry, col, rot = 0) { x.fillStyle = col; x.beginPath(); x.ellipse(cx, cy, Math.max(0.1, rx), Math.max(0.1, ry), rot, 0, TAU); x.fill(); }
function C(x, cx, cy, r, col) { E(x, cx, cy, r, r, col); }
function P(x, pts, col) { x.fillStyle = col; x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) x.lineTo(pts[i][0], pts[i][1]); x.closePath(); x.fill(); }
function L(x, pts, col, w) { x.strokeStyle = col; x.lineWidth = w; x.lineCap = 'round'; x.lineJoin = 'round'; x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) x.lineTo(pts[i][0], pts[i][1]); x.stroke(); }
function R(x, X, Y, w, h, col) { x.fillStyle = col; x.fillRect(X, Y, w, h); }
function smooth(x, pts, closed = true) {   // a smooth closed shape through points (quadratic midpoints)
  const n = pts.length; x.beginPath();
  const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  if (closed) {
    const m0 = mid(pts[n - 1], pts[0]); x.moveTo(m0[0], m0[1]);
    for (let i = 0; i < n; i++) { const m = mid(pts[i], pts[(i + 1) % n]); x.quadraticCurveTo(pts[i][0], pts[i][1], m[0], m[1]); }
    x.closePath();
  } else {
    x.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < n - 1; i++) { const m = mid(pts[i], pts[i + 1]); x.quadraticCurveTo(pts[i][0], pts[i][1], m[0], m[1]); }
    x.lineTo(pts[n - 1][0], pts[n - 1][1]);
  }
}
function S(x, pts, col) { smooth(x, pts); x.fillStyle = col; x.fill(); }
// a tapered limb (tentacle, leg, tongue) along a polyline: width w0 at the root to w1 at the tip
function limb(x, pts, w0, w1, col) {
  const n = pts.length, Lp = [], Rp = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const d = Math.hypot(dx, dy) || 1; dx /= d; dy /= d;
    const w = (w0 + (w1 - w0) * (i / (n - 1))) / 2;
    Lp.push([pts[i][0] - dy * w, pts[i][1] + dx * w]); Rp.push([pts[i][0] + dy * w, pts[i][1] - dx * w]);
  }
  P(x, Lp.concat(Rp.reverse()), col);
  C(x, pts[0][0], pts[0][1], w0 / 2, col);
}
// points along a curl: start, initial angle, length, curl (radians over the length), segments
function curl(x0, y0, ang, len, bend, n = 10) {
  const pts = [[x0, y0]]; let a = ang, X = x0, Y = y0;
  for (let i = 1; i <= n; i++) { a += bend / n * (0.4 + 1.2 * i / n); X += Math.cos(a) * len / n; Y += Math.sin(a) * len / n; pts.push([X, Y]); }
  return pts;
}
function clip(x, shape, draw) { x.save(); shape(); x.clip(); draw(); x.restore(); }
// hard pixel edges, like the rest of the game's art
function crisp(c, th = 96) {
  const x = c.getContext('2d'), d = x.getImageData(0, 0, c.width, c.height), a = d.data;
  for (let i = 3; i < a.length; i += 4) a[i] = a[i] < th ? 0 : 255;
  x.putImageData(d, 0, 0); return c;
}
// a 1px dark outline around everything solid
function outline(c, col = OUT) {
  const w = c.width, h = c.height, x = c.getContext('2d'), d = x.getImageData(0, 0, w, h), a = d.data, o = new Uint8ClampedArray(a), [r, g, b] = hex(col);
  for (let y = 0; y < h; y++) for (let X = 0; X < w; X++) {
    const i = (y * w + X) * 4; if (a[i + 3]) continue;
    const on = (X > 0 && a[i - 1]) || (X < w - 1 && a[i + 7]) || (y > 0 && a[i - w * 4 + 3]) || (y < h - 1 && a[i + w * 4 + 3]);
    if (on) { o[i] = r; o[i + 1] = g; o[i + 2] = b; o[i + 3] = 255; }
  }
  x.putImageData(new ImageData(o, w, h), 0, 0); return c;
}
const fin = (c, col) => outline(crisp(c), col);
function whiteOf(c) { const o = cv(c.width, c.height), x = g2(o); x.drawImage(c, 0, 0); x.globalCompositeOperation = 'source-atop'; R(x, 0, 0, o.width, o.height, '#ffffff'); return o; }
function filtered(c, f) { const o = cv(c.width, c.height), x = g2(o); x.filter = f; x.drawImage(c, 0, 0); return o; }
function frame(w, h, draw) { const c = cv(w, h), x = g2(c); draw(x); return c; }
function glowDot(x, X, Y, r, col, a = 0.5) { const [R_, G, B] = hex(col); const g = x.createRadialGradient(X, Y, 0, X, Y, r); g.addColorStop(0, `rgba(${R_},${G},${B},${a})`); g.addColorStop(1, `rgba(${R_},${G},${B},0)`); x.fillStyle = g; x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill(); }

// ------------------------------------------------------------------ extra helpers
const lerp = (a, b, t) => a + (b - a) * t;
const lp = (p, q, t) => [lerp(p[0], q[0], t), lerp(p[1], q[1], t)];
const add = (p, q) => [p[0] + q[0], p[1] + q[1]];
// draw with a translucent wash (shading over an opaque base stays opaque after crisp)
function wash(x, a, draw) { const g = x.globalAlpha; x.globalAlpha = a; draw(); x.globalAlpha = g; }
// a polygon with a shaggy (fur) or jagged (rock) edge: every edge gets little spikes pointing outwards
function shaggy(x, pts, col, amp = 3, seg = 5, seed = 1, droop = 0.5) {
  const r = rng(seed), out = [];
  let area = 0; for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; area += a[0] * b[1] - b[0] * a[1]; }
  const sgn = area > 0 ? -1 : 1;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length], len = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.max(1, Math.round(len / seg));
    const nx = sgn * (b[1] - a[1]) / (len || 1), ny = -sgn * (b[0] - a[0]) / (len || 1);
    for (let k = 0; k < n; k++) {
      const p = lp(a, b, k / n), q = lp(a, b, (k + 0.5) / n), s = amp * (0.5 + r());
      out.push(p); out.push([q[0] + nx * s, q[1] + ny * s + s * droop * 0.6]);
    }
  }
  P(x, out, col);
}
// a fur-covered limb: a tapered limb with tufts hanging off both sides
function furLimb(x, pts, w0, w1, col, seed = 1, amp = 3) {
  limb(x, pts, w0, w1, col);
  const r = rng(seed), n = pts.length;
  for (let i = 0; i < n - 1; i++) {
    const a = pts[i], b = pts[i + 1], len = Math.hypot(b[0] - a[0], b[1] - a[1]), steps = Math.max(1, Math.round(len / 5));
    const dx = (b[0] - a[0]) / (len || 1), dy = (b[1] - a[1]) / (len || 1);
    for (let k = 0; k < steps; k++) {
      const t = (i + k / steps) / (n - 1), w = (w0 + (w1 - w0) * t) / 2, p = lp(a, b, k / steps);
      for (const s of [-1, 1]) {
        const ex = p[0] - dy * w * s, ey = p[1] + dx * w * s, s2 = amp * (0.6 + r() * 0.8);
        P(x, [[ex - dx * 2.5, ey - dy * 2.5], [ex + dx * 2.5, ey + dy * 2.5], [ex - dy * s * s2 + dx * 1.5, ey + dx * s * s2 + s2 * 0.7]], col);
      }
    }
  }
}
// short fur strokes inside an area (call inside a clip)
function furStrokes(x, X0, Y0, w, h, col, n, seed, len = 4) {
  const r = rng(seed);
  for (let i = 0; i < n; i++) { const X = X0 + r() * w, Y = Y0 + r() * h, a = Math.PI / 2 + (r() - 0.5) * 0.8; L(x, [[X, Y], [X + Math.cos(a) * len * 0.4, Y + Math.sin(a) * len * 0.5], [X + Math.cos(a) * len, Y + Math.sin(a) * len]], col, 1); }
}
// cursed veins: branching violet lines with bright nodes
function veins(x, X, Y, ang, len, seed, col = '#8a2ad0', hi = '#e08aff', w = 1.4) {
  const r = rng(seed); let a = ang, px = X, py = Y; const pts = [[px, py]];
  for (let k = 0; k < 6; k++) { a += (r() - 0.5) * 0.9; px += Math.cos(a) * len / 6; py += Math.sin(a) * len / 6; pts.push([px, py]); if (r() < 0.35) L(x, [[px, py], [px + Math.cos(a + 1) * len * 0.25, py + Math.sin(a + 1) * len * 0.25]], col, w * 0.7); }
  L(x, pts, col, w); C(x, pts[2][0], pts[2][1], w * 0.8, hi); C(x, pts[5][0], pts[5][1], w * 0.6, hi);
}

// ------------------------------------------------------------------ palette
const K = {
  stone: '#6a7888', stoneD: '#465262', stoneDD: '#2c3442', stoneL: '#8e9cac', stoneLL: '#b4c0cc',
  snow: '#eef4fa', snowS: '#c4d4e6', snowD: '#8ea4c0', ice: '#9fe0f4', iceD: '#5aa8d0', iceL: '#dcf6ff',
  bone: '#e2d8c4', boneS: '#b8aa92', boneD: '#7e725e', violet: '#8a2ad0', glow: '#d07aff', cyan: '#5af0ff', ember: '#ff6a2a', lava: '#ffb03a',
};

// ================================================================== MONSTERS (all face right)

// ---------------- a realistic human eye set into something (boulder): almond opening, sclera, veins, iris, pupil, wet highlight
function humanEye(x, cx, cy, rx, ry, o = {}) {
  const top = o.top ?? 1, bot = o.bot ?? 1, lid = o.lid || K.stone, rim = o.rim || K.stoneDD, iris = o.iris || '#3c8a6a';
  E(x, cx, cy + 0.3, rx + 1.6, ry + 1.7, rim);                        // the socket
  E(x, cx, cy, rx + 0.8, ry + 1, lid);                                // the lids
  if (o.shut || o.squeeze) {
    if (o.squeeze) {
      L(x, [[cx - rx, cy - 0.5], [cx - rx * 0.3, cy + 0.8], [cx + rx * 0.4, cy + 0.6], [cx + rx, cy - 0.8]], '#141820', 1.3);
      L(x, [[cx - rx * 0.7, cy - ry * 0.9], [cx, cy - ry * 0.5], [cx + rx * 0.7, cy - ry * 1.0]], rim, 1);
      L(x, [[cx - rx * 0.6, cy + ry * 0.9], [cx + rx * 0.5, cy + ry * 1.0]], rim, 1);
      L(x, [[cx + rx + 0.5, cy - 1], [cx + rx + 2.5, cy - 2.5]], rim, 0.9); L(x, [[cx + rx + 0.5, cy + 0.5], [cx + rx + 2.5, cy + 1.5]], rim, 0.9);
    } else {
      L(x, [[cx - rx, cy], [cx, cy + ry * 0.45], [cx + rx, cy]], '#141820', 1.2);
      for (let i = 1; i < 4; i++) { const t = i / 4, X = cx - rx + rx * 2 * t; L(x, [[X, cy + ry * 0.35 * Math.sin(t * Math.PI)], [X + 0.4, cy + ry * 0.35 * Math.sin(t * Math.PI) + 1.6]], '#141820', 0.7); }
    }
    return;
  }
  const shape = () => { x.beginPath(); x.moveTo(cx - rx, cy + 0.3); x.quadraticCurveTo(cx - rx * 0.1, cy - 2 * ry * top, cx + rx, cy - 0.3); x.quadraticCurveTo(cx + rx * 0.1, cy + 2 * ry * bot * 0.8, cx - rx, cy + 0.3); x.closePath(); };
  clip(x, shape, () => {
    R(x, cx - rx - 1, cy - ry * 3, rx * 2 + 2, ry * 6, '#f6f2ec');
    E(x, cx - rx * 0.85, cy, rx * 0.25, ry * 0.5, '#e8b0a8');            // tear duct corner
    E(x, cx + rx * 0.9, cy, rx * 0.2, ry * 0.5, '#e8c4b8');
    const vr = rng(o.seed || 5);
    for (let i = 0; i < 6; i++) {                                         // bloodshot veins from the corners
      const s = i % 2 ? 1 : -1, y0 = cy + (vr() - 0.5) * ry * 1.4;
      L(x, [[cx + s * rx, y0], [cx + s * rx * (0.6 - vr() * 0.1), y0 + (vr() - 0.5) * 1.6], [cx + s * rx * 0.38, y0 + (vr() - 0.5) * 2]], '#d03a3a', 0.55);
    }
    const ix = cx + (o.look ?? 0.25) * rx * 0.45, ir = ry * 1.0;
    C(x, ix, cy, ir, '#1c3a30');                                          // limbal ring
    C(x, ix, cy, ir * 0.86, iris);
    for (let i = 0; i < 10; i++) { const a = i / 10 * TAU; L(x, [[ix + Math.cos(a) * ir * 0.4, cy + Math.sin(a) * ir * 0.4], [ix + Math.cos(a) * ir * 0.8, cy + Math.sin(a) * ir * 0.8]], o.iris2 || '#8ad0a0', 0.5); }
    C(x, ix, cy, ir * (o.pupil ?? 0.42), '#08090c');
    R(x, ix - ir * 0.62, cy - ir * 0.66, 1.6, 1.4, '#ffffff');           // wet highlight
    R(x, ix + ir * 0.3, cy + ir * 0.3, 0.8, 0.8, '#e0f0ff');
    wash(x, 0.3, () => E(x, cx, cy - ry * 1.2 * top, rx * 1.2, ry * 0.7, '#7a7c90'));   // the lid's shadow on the eyeball
  });
  x.strokeStyle = '#1a1e26'; x.lineWidth = 1; x.beginPath(); x.moveTo(cx - rx, cy + 0.3); x.quadraticCurveTo(cx - rx * 0.1, cy - 2 * ry * top, cx + rx, cy - 0.3); x.stroke();
  x.strokeStyle = rim; x.lineWidth = 0.9; x.beginPath(); x.moveTo(cx - rx * 0.9, cy - ry * top * 0.9 - 1.6); x.quadraticCurveTo(cx, cy - 2 * ry * top - 1.8, cx + rx * 0.9, cy - ry * top * 0.7 - 1.6); x.stroke();   // lid crease
  x.strokeStyle = '#c88a80'; x.lineWidth = 0.6; x.beginPath(); x.moveTo(cx - rx * 0.8, cy + 0.6); x.quadraticCurveTo(cx + rx * 0.1, cy + 1.6 * ry * bot * 0.8, cx + rx * 0.8, cy + 0.2); x.stroke();   // wet lower rim
}

// ---------------- Cursed Boulder (88×72, the bottom of the rock at 44,66)
const BOULDER_TEX = (() => {   // rock texture for a quarter of the stone, repeated four times so a quarter turn loops
  const r = rng(404), q = { cracks: [], facets: [], frost: [], lump: [r() * TAU, r() * TAU] };
  for (let i = 0; i < 2; i++) { const a0 = r() * Math.PI / 2, d0 = 5 + r() * 12, pts = [[Math.cos(a0) * d0, Math.sin(a0) * d0]]; let a = a0 + (r() - 0.5) * 2; for (let k = 0; k < 3; k++) { const p = pts[pts.length - 1]; a += (r() - 0.5) * 1.2; pts.push([p[0] + Math.cos(a) * (3 + r() * 4), p[1] + Math.sin(a) * (3 + r() * 4)]); } q.cracks.push(pts); }
  for (let i = 0; i < 3; i++) { const a = (i + r() * 0.6) / 3 * Math.PI / 2, d = 8 + r() * 12, s = 4 + r() * 5, pts = []; for (let k = 0; k < 5; k++) { const b = k / 5 * TAU + r() * 0.5; pts.push([Math.cos(a) * d + Math.cos(b) * s, Math.sin(a) * d + Math.sin(b) * s * 0.8]); } q.facets.push([pts, i % 3]); }
  for (let i = 0; i < 4; i++) { const a = r() * Math.PI / 2, d = 10 + r() * 10; q.frost.push([Math.cos(a) * d, Math.sin(a) * d]); }
  return q;
})();
function boulderShape(x, cx, cy, rad, rot) {   // lumpy outline with a four-fold repeat, so it also loops on a quarter turn
  x.beginPath();
  for (let i = 0; i <= 48; i++) { const a = i / 48 * TAU, rr = rad * (1 + 0.045 * Math.sin(4 * (a - rot) + BOULDER_TEX.lump[0]) + 0.03 * Math.sin(8 * (a - rot) + BOULDER_TEX.lump[1])); const X = cx + Math.cos(a) * rr, Y = cy + Math.sin(a) * rr * 0.94; i ? x.lineTo(X, Y) : x.moveTo(X, Y); }
  x.closePath();
}
function boulderBody(x, cx, cy, rad, rot, opts = {}) {
  const shape = () => boulderShape(x, cx, cy, rad, rot);
  shape(); x.fillStyle = K.stone; x.fill();
  clip(x, shape, () => {
    x.save(); x.translate(cx, cy); x.rotate(rot);
    for (let q = 0; q < 4; q++) {
      x.save(); x.rotate(q * Math.PI / 2);
      for (const [pts, t] of BOULDER_TEX.facets) P(x, pts, ['#74849a', '#5e6c7e', '#687890'][t]);
      for (const c of BOULDER_TEX.cracks) { L(x, c, K.stoneDD, 1.3); L(x, c.map(p => [p[0] + 1, p[1] + 1]), K.stoneL, 0.6); }
      for (const [X, Y] of BOULDER_TEX.frost) { R(x, X, Y, 1, 1, '#c8d8ea'); }
      x.restore();
    }
    x.restore();
    // light from the upper left: flat bands, like the rest of the art
    wash(x, 0.6, () => { E(x, cx + rad * 0.45, cy + rad * 0.5, rad * 1.05, rad * 0.8, K.stoneDD); });
    wash(x, 0.45, () => { E(x, cx - rad * 0.35, cy - rad * 0.5, rad * 0.7, rad * 0.45, K.stoneLL, -0.4); });
    P(x, [[cx - rad * 0.7, cy - rad * 0.45], [cx - rad * 0.45, cy - rad * 0.78], [cx - rad * 0.05, cy - rad * 0.92], [cx - rad * 0.25, cy - rad * 0.72], [cx - rad * 0.55, cy - rad * 0.5]], '#c8d6e4');   // frost on the crown
    wash(x, 0.7, () => E(x, cx, cy + rad * 1.08, rad * 1.1, rad * 0.32, '#1c2230'));
  });
  if (opts.aura) {   // the curse that holds it up: violet runes ringing its middle
    for (let i = 0; i < 7; i++) { const a = rot + i / 7 * TAU, X = cx + Math.cos(a) * rad * 0.82, Y = cy + Math.sin(a) * rad * 0.2 + rad * 0.15; if (Math.sin(a) > -0.2) R(x, X - 0.5, Y - 1, 1.5, 2, '#d07aff'); }
  }
}
function boulder(pose, f) {
  return frame(88, 72, x => {
    const rad = 22, cx = 44; let cy = 66 - rad * 0.95, rot = 0;
    const eye = { lid: '#6e7c8c', rim: '#2c3442', iris: '#4a7ab0', iris2: '#a8d0f0', look: 0.35 };
    let eyes = { top: 1, bot: 1 };
    if (pose === 'idle' && f === 1) eyes = { top: 0.35, bot: 0.8 };
    if (pose === 'roll') rot = f * Math.PI / 8;
    if (pose === 'float') { cy -= 8; eyes = { top: 1.3, bot: 1.2, pupil: 0.3 }; }
    if (pose === 'launch') eyes = { top: 0.45, bot: 0.6, look: 0.6 };
    if (pose === 'hurt') eyes = { squeeze: true };
    if (pose === 'dead') {
      // split in two: the back half tipped left, the front half (with the shut eyes) tipped right
      for (const s of [-1, 1]) {
        x.save(); x.translate(cx + s * 7, 66); x.rotate(s * 0.32); x.translate(-cx, -66);
        clip(x, () => { x.beginPath(); if (s < 0) x.rect(0, 0, cx - 1 + 2, 72); else x.rect(cx + 1, 0, 88, 72); }, () => {
          boulderBody(x, cx, 66 - rad * 0.95, rad, 0.3);
          // the broken face, paler stone inside
          P(x, s < 0 ? [[cx + 1, 25], [cx - 3, 36], [cx + 1, 46], [cx - 2, 56], [cx + 1, 66], [cx + 2, 66], [cx + 2, 25]] : [[cx + 1, 25], [cx + 5, 36], [cx + 1, 46], [cx + 4, 56], [cx + 1, 66], [cx - 1, 66], [cx - 1, 25]], '#9aa8b8');
          if (s > 0) { humanEye(x, cx + 9, 40, 4.6, 3.2, { ...eye, shut: true }); }
        });
        x.restore();
      }
      for (const [X, Y, s] of [[30, 64, 2], [58, 65, 1.6], [44, 65, 2.4], [66, 64, 1.2]]) E(x, X, Y, s * 1.3, s, K.stoneD);
      return;
    }
    if (pose === 'float') {
      // a faint curse aura and pebbles lifted with it
      for (let i = 0; i < 5; i++) { const X = cx - 14 + i * 7, Y = 60 + ((i + f) % 2) * 3; L(x, [[X, Y], [X + (i - 2) * 0.6, Y - 3]], i % 2 ? '#8a3ad0' : '#c87aff', 1.2); }
      R(x, cx - 12, 65, 24, 1, '#6a2aa0');
      for (const [X, Y, s] of [[22, 58 - f * 2, 2.2], [66, 55 + f * 2, 1.8], [34, 62 - f, 1.5], [58, 62 + f, 1.4], [16, 48 + f * 2, 1.2]]) { E(x, X, Y, s * 1.2, s, K.stoneD); R(x, X - s * 0.6, Y - s * 0.7, 1, 1, K.stoneL); }
      for (const [X, Y] of [[28, 66], [50, 60], [62, 67], [40, 58]]) R(x, X, Y - f, 1, 2, '#e0a0ff');
    }
    if (pose === 'launch') {
      for (const [Y, l, X0] of [[cy - 12, 12, 0], [cy - 2, 18, -2], [cy + 9, 10, 2]]) { L(x, [[cx - rad - 3 - l + X0, Y], [cx - rad - 2 + X0, Y]], '#dce8f4', 1.6); }
      for (const [X, Y] of [[8, 34], [12, 52], [4, 44]]) R(x, X, Y, 2, 2, K.stoneD);
    }
    boulderBody(x, cx, cy, rad, rot, { aura: pose === 'float' });
    // the eyes: one near, one turned slightly away (it faces right)
    humanEye(x, cx + 2, cy - 3, 6.4, 4.4, { ...eye, ...eyes, seed: 3 });
    humanEye(x, cx + 16, cy - 2, 4.6, 4.1, { ...eye, ...eyes, seed: 9 });
    if (pose === 'launch') { L(x, [[cx - 5, cy - 12], [cx + 8, cy - 8.5]], '#1a1e26', 1.8); L(x, [[cx + 12, cy - 8], [cx + 21, cy - 10.5]], '#1a1e26', 1.8); }
  });
}

// ---------------- lizard folk: shared bits
const LZ = { sk: '#4e8c3a', dk: '#2e5c24', dd: '#1e3a1a', hi: '#7ab452', belly: '#d8cc8a', bellyD: '#a8985a', fr: '#c8502e', frD: '#8a3020', lth: '#6e4428', lthD: '#42281a', lthL: '#9a6a3e', metal: '#d0a848', claw: '#e8e0c8' };
// a digitigrade leg: hip → knee (forward) → ankle (back) → toes
function lzLeg(x, hip, foot, col, hiCol, lift = 0) {
  const ank = [foot[0] - 6, foot[1] - 7 - lift * 0.4], toe = [foot[0] + 4, foot[1] - lift * 0.2];
  const knee = [(hip[0] + ank[0]) / 2 + 8, (hip[1] + ank[1]) / 2 - 2];
  limb(x, [hip, knee], 12, 9, col); limb(x, [knee, ank], 8, 6, col);
  if (hiCol) L(x, [[hip[0] + 2, hip[1] - 2], [knee[0] - 1, knee[1] - 2]], hiCol, 1.6);
  limb(x, [ank, toe], 6, 4, col);
  for (let k = 0; k < 2; k++) P(x, [[toe[0] - 1 - k * 3, toe[1] - 1], [toe[0] + 4 - k * 3, toe[1] + 0.6], [toe[0] - 1 - k * 3, toe[1] + 1.2]], LZ.claw);
  return { knee, ank, toe };
}
// an arm: shoulder → elbow → hand, a clawed hand at the end
function lzArm(x, pts, col, open = false) {
  const [sh, el, hd] = pts;
  limb(x, [sh, el], 8, 6.5, col); limb(x, [el, hd], 6.5, 5, col);
  C(x, hd[0], hd[1], 3.4, col);
  const a = Math.atan2(hd[1] - el[1], hd[0] - el[0]);
  for (let k = -1; k <= 1; k++) { const b = a + k * (open ? 0.6 : 0.35), X = hd[0] + Math.cos(b) * 3, Y = hd[1] + Math.sin(b) * 3; P(x, [[X - 1, Y - 1], [X + Math.cos(b) * 3.5, Y + Math.sin(b) * 3.5], [X + 1, Y + 1]], LZ.claw); }
}
// the head, in its own frame: (0,0) at the back of the skull, snout pointing +x
function lzHead(x, H, tilt, o = {}) {
  x.save(); x.translate(H[0], H[1]); x.rotate(tilt);
  const sk = o.sk || LZ.sk, dk = o.dk || LZ.dk;
  if (!o.hood) for (let i = 0; i < 4; i++) P(x, [[-6 - i * 2, -3 + i * 3], [-12 - i * 3, -6 + i * 3.5], [-7 - i * 2, 1 + i * 3]], i % 2 ? LZ.frD : LZ.fr);   // crest frills
  const open = o.mouth || 0;
  // lower jaw
  P(x, [[-4, 3], [14, 3 + open * 4], [15, 5 + open * 6], [2, 8]], dk);
  if (open) { P(x, [[0, 3], [14, 1.5], [14, 3 + open * 4]], '#7a1e24'); for (let k = 0; k < 3; k++) P(x, [[5 + k * 3, 3 + open * k], [6 + k * 3, 5 + open * k], [7 + k * 3, 3 + open * k]], LZ.claw); }
  // skull and snout
  S(x, [[-8, -1], [-5, -7], [3, -8], [12, -5], [17, -2], [17, 1.5], [10, 3], [0, 4], [-6, 3]], sk);
  clip(x, () => smooth(x, [[-8, -1], [-5, -7], [3, -8], [12, -5], [17, -2], [17, 1.5], [10, 3], [0, 4], [-6, 3]]), () => {
    E(x, 2, -7, 9, 2.5, o.hi || LZ.hi); E(x, 4, 4, 14, 2.5, dk);
    for (let k = 0; k < 5; k++) R(x, -3 + k * 3, -4 + (k % 2), 1.2, 1.2, dk);   // scales
  });
  L(x, [[3, 2.5], [16, 1]], LZ.dd, 1);                                            // the mouth line
  R(x, 15, -1.5, 1.2, 1, LZ.dd);                                                   // nostril
  if (!open) P(x, [[9, 2], [10, 4], [11, 2]], LZ.claw);                            // a tooth showing
  // brow and eye
  P(x, [[-1, -6], [7, -6.5], [5, -4], [0, -4]], dk);
  const ey = o.eye || 'open', ec = o.eyeCol || '#f0c830';
  if (ey === 'shut') L(x, [[1, -3], [6, -2.5]], LZ.dd, 1.3);
  else if (ey === 'x') { L(x, [[1.5, -5], [5.5, -1]], LZ.dd, 1.1); L(x, [[5.5, -5], [1.5, -1]], LZ.dd, 1.1); }
  else { E(x, 3.5, -3, 2.6, 2.2, ec); R(x, 3.2, -5, 1, 4, '#141008'); R(x, 2, -4, 0.8, 0.8, '#fff8d0'); }
  x.restore();
}
function lzTorso(x, hip, chest, o = {}) {
  const v = [chest[0] - hip[0], chest[1] - hip[1]], l = Math.hypot(v[0], v[1]), u = [v[0] / l, v[1] / l], n = [-u[1], u[0]];
  const nn = n[0] < 0 ? [-n[0], -n[1]] : n;                                        // the front (belly) side
  const at = (t, s) => [hip[0] + v[0] * t + nn[0] * s, hip[1] + v[1] * t + nn[1] * s];
  const pts = [at(-0.12, -7), at(0.3, -9), at(0.75, -10), at(1.05, -6), at(1.12, 2), at(0.95, 11), at(0.55, 9), at(0.15, 9), at(-0.1, 4)];
  const shape = () => smooth(x, pts);
  shape(); x.fillStyle = o.sk || LZ.sk; x.fill();
  clip(x, shape, () => {
    // pale belly plates down the front
    const bp = [at(0.05, 5), at(0.5, 6), at(0.95, 8), at(1.1, 14), at(0.5, 14), at(0, 12)];
    P(x, bp, LZ.belly);
    for (let t = 0.12; t < 1; t += 0.14) L(x, [at(t, 4), at(t + 0.03, 12)], LZ.bellyD, 1);
    L(x, [at(-0.1, -8), at(0.9, -10)], o.dk || LZ.dk, 4);                            // shadowed back
    for (let k = 0; k < 7; k++) { const p = at(0.15 + k * 0.12, -3 + (k % 2) * 3); R(x, p[0], p[1], 1.2, 1.2, o.dk || LZ.dk); }
  });
  return { at, nn, u };
}
// whip handle (+ a short bit of lash, the game draws the rest)
function lzWhip(x, hand, ang, lash) {
  const d = [Math.cos(ang), Math.sin(ang)];
  limb(x, [[hand[0] - d[0] * 5, hand[1] - d[1] * 5], [hand[0] + d[0] * 9, hand[1] + d[1] * 9]], 3.4, 2.8, LZ.lthD);
  for (let k = -3; k < 8; k += 2.5) C(x, hand[0] + d[0] * k, hand[1] + d[1] * k, 1.2, LZ.lthL);
  C(x, hand[0] - d[0] * 6, hand[1] - d[1] * 6, 2, LZ.metal);
  const tip = [hand[0] + d[0] * 10, hand[1] + d[1] * 10];
  if (lash === 'coil') {   // the lash coiled and hanging from the handle
    for (let k = 0; k < 3; k++) { x.strokeStyle = k % 2 ? LZ.lth : LZ.lthL; x.lineWidth = 1.6; x.beginPath(); x.ellipse(tip[0] + 1, tip[1] + 7 + k * 1.5, 4.5 - k * 0.5, 6 - k, 0.3, 0, TAU); x.stroke(); }
    L(x, [[tip[0] + 1, tip[1] + 13], [tip[0] - 1, tip[1] + 18], [tip[0] + 1, tip[1] + 21]], LZ.lth, 1.4);
  } else if (lash === 'trail') { L(x, curl(tip[0], tip[1], ang + 0.6, 14, 1.6, 6), LZ.lth, 1.6); }
  else if (lash === 'straight') { L(x, [tip, [tip[0] + d[0] * 6, tip[1] + d[1] * 6]], LZ.lth, 1.8); }
}

// ---------------- Lizardman (100×96, feet at 50,90; about as tall as the hero)
function lizard(pose, f) {
  return frame(100, 96, x => {
    let hip = [46, 58], chest = [53, 30], head = [57, 17], tilt = -0.05, mouth = 0, eye = 'open';
    let footB = [40, 90], footF = [58, 90], liftB = 0, liftF = 0;
    let armB = [[48, 33], [40, 45], [46, 54]], armF = [[56, 33], [58, 45], [66, 46]];
    let whip = { ang: 1.25, lash: 'coil' }, tailEnd = [4, 86], tailMid = [22, 74], openF = false;
    if (pose === 'idle') { const b = f; hip = [46, 58 + b]; chest = [53, 30 + b]; head = [57, 17 + b]; armB = [[48, 33 + b], [40, 45 + b], [46, 54 + b]]; armF = [[56, 33 + b], [58, 45 + b], [66, 46 + b]]; tailEnd = [4, 86 - f * 2]; }
    if (pose === 'walk') {
      const p = f * Math.PI / 2, s = Math.sin(p), c = Math.cos(p), b = Math.abs(s) * 1.5;
      hip = [47, 58 - b]; chest = [55, 30 - b]; head = [60, 17 - b];
      footF = [52 + s * 12, 90]; liftF = c > 0 ? c * 6 : 0; footB = [46 - s * 12, 90]; liftB = c < 0 ? -c * 6 : 0;
      footF[1] -= liftF; footB[1] -= liftB;
      armB = [[50, 33 - b], [44 + s * 4, 45 - b], [48 + s * 8, 54 - b]]; armF = [[58, 33 - b], [58 - s * 3, 45 - b], [66 - s * 5, 47 - b]];
      tailMid = [22, 74 + s * 2]; tailEnd = [4, 84 + s * 3]; whip.ang = 1.25 - s * 0.2;
    }
    if (pose === 'whip') {
      if (f === 0) { hip = [44, 58]; chest = [48, 30]; head = [52, 17]; tilt = -0.15; armF = [[52, 33], [44, 22], [38, 14]]; armB = [[48, 33], [58, 42], [66, 44]]; whip = { ang: -2.3, lash: 'trail' }; mouth = 0.5; openF = false; }
      else { hip = [48, 58]; chest = [58, 31]; head = [64, 19]; tilt = 0.1; armF = [[61, 34], [70, 38], [80, 40]]; armB = [[56, 34], [46, 42], [42, 52]]; whip = { ang: 0.05, lash: 'straight' }; mouth = 0.8; footB = [36, 90]; footF = [64, 90]; }
    }
    if (pose === 'hurt') { hip = [44, 59]; chest = [46, 31]; head = [46, 19]; tilt = -0.5; mouth = 0.9; eye = 'shut'; armF = [[50, 34], [58, 28], [64, 22]]; armB = [[44, 34], [36, 28], [30, 24]]; whip.lash = 'trail'; whip.ang = -1.2; }
    if (pose === 'leap') {   // tucked into a ball for the somersault (the game spins it)
      const cx = 50, cy = 58;
      limb(x, curl(cx - 4, cy + 14, Math.PI, 30, -4.2, 12), 11, 3, LZ.dk);         // tail wrapped round the ball
      E(x, cx, cy, 19, 18, LZ.sk);
      clip(x, () => { x.beginPath(); x.ellipse(cx, cy, 19, 18, 0, 0, TAU); }, () => {
        E(x, cx - 4, cy - 8, 14, 9, LZ.hi); E(x, cx + 6, cy + 10, 16, 8, LZ.dk);
        for (let k = 0; k < 9; k++) { const a = -2.6 + k * 0.32; R(x, cx + Math.cos(a) * 14, cy + Math.sin(a) * 13, 1.4, 1.4, LZ.dk); }
        x.strokeStyle = LZ.lth; x.lineWidth = 3; x.beginPath(); x.arc(cx, cy, 13, -1.2, 1.6); x.stroke();   // the strap
      });
      for (let i = 0; i < 5; i++) { const a = -2.4 + i * 0.5; P(x, [[cx + Math.cos(a) * 17, cy + Math.sin(a) * 16], [cx + Math.cos(a + 0.2) * 23, cy + Math.sin(a + 0.2) * 22], [cx + Math.cos(a + 0.35) * 17, cy + Math.sin(a + 0.35) * 16]], i % 2 ? LZ.frD : LZ.fr); }
      limb(x, [[cx + 4, cy + 4], [cx + 14, cy - 2], [cx + 10, cy + 10]], 10, 7, LZ.sk);  // knees pulled up
      lzHead(x, [cx + 4, cy + 4], 1.1, { mouth: 0 });
      lzArm(x, [[cx - 2, cy - 4], [cx + 10, cy + 2], [cx + 14, cy + 12]], LZ.sk);
      lzWhip(x, [cx + 14, cy + 12], -0.4, 'none');
      return;
    }
    if (pose === 'dead') {   // lying face-down, tail limp
      limb(x, [[38, 84], [22, 86], [6, 88]], 10, 2, LZ.dk);
      lzLeg(x, [38, 82], [20, 88], LZ.dk);
      lzArm(x, [[60, 80], [56, 87], [48, 88]], LZ.dk);
      lzTorso(x, [38, 82], [64, 80]);
      lzLeg(x, [40, 82], [26, 90], LZ.sk);
      lzHead(x, [70, 80], 0.35, { eye: 'x', mouth: 0.4 });
      lzArm(x, [[62, 78], [70, 86], [80, 88]], LZ.sk, true);
      lzWhip(x, [88, 88], 3.0, 'none');
      return;
    }
    // tail
    limb(x, [[hip[0] - 2, hip[1] + 2], [hip[0] - 12, hip[1] + 8], tailMid, [tailMid[0] - 10, (tailMid[1] + tailEnd[1]) / 2 + 2], tailEnd], 13, 2, LZ.sk);
    L(x, [[hip[0] - 10, hip[1] + 5], [tailMid[0], tailMid[1] - 3], [tailEnd[0] + 6, tailEnd[1] - 2]], LZ.hi, 1.4);
    for (let k = 0; k < 4; k++) { const p = lp([hip[0] - 10, hip[1] + 2], tailMid, k / 3); P(x, [[p[0] - 2, p[1] - 3], [p[0] - 4, p[1] - 7], [p[0] + 1, p[1] - 4]], LZ.frD); }
    lzLeg(x, [hip[0] - 2, hip[1]], footB, LZ.dk, null, liftB);
    lzArm(x, armB, LZ.dk);
    const T = lzTorso(x, hip, chest);
    // straps: a bandolier across the chest, a belt and a loincloth
    L(x, [T.at(1.0, -7), T.at(0.15, 9)], LZ.lthD, 4); L(x, [T.at(1.0, -7), T.at(0.15, 9)], LZ.lth, 2.4);
    for (let k = 0; k < 3; k++) { const p = lp(T.at(0.9, -4), T.at(0.25, 7), k / 2.5); R(x, p[0] - 1, p[1] - 1, 2, 2, LZ.metal); }
    L(x, [T.at(0.02, -8), T.at(0.0, 9)], LZ.lthD, 4.5); L(x, [T.at(0.02, -8), T.at(0.0, 9)], LZ.lth, 3);
    const bk = T.at(0.0, 6); R(x, bk[0] - 2, bk[1] - 2.5, 4, 4, LZ.metal); R(x, bk[0] - 1, bk[1] - 1.5, 2, 2, LZ.lthD);
    P(x, [T.at(-0.02, 1), T.at(-0.02, 9), [hip[0] + 8, hip[1] + 14], [hip[0] + 3, hip[1] + 15]], LZ.lthD);
    lzLeg(x, [hip[0] + 3, hip[1] + 1], footF, LZ.sk, LZ.hi, liftF);
    // neck and head
    limb(x, [T.at(1.0, -1), [head[0] - 2, head[1] + 2]], 11, 9, LZ.sk);
    lzHead(x, head, tilt, { mouth, eye });
    // shoulder guard, front arm and the whip
    E(x, armF[0][0], armF[0][1] + 1, 6, 4.5, LZ.lth, -0.3); E(x, armF[0][0] - 1, armF[0][1], 4, 2, LZ.lthL, -0.3);
    lzArm(x, armF, LZ.sk, openF);
    lzWhip(x, armF[2], whip.ang, whip.lash);
  });
}
// ---------------- Lizard Warlock (100×100, feet at 50,94)
const WL = { robe: '#3a1a5c', robeD: '#22103a', robeL: '#5a2e84', trim: '#120822', rune: '#c87aff', runeL: '#f0c8ff', wood: '#5a3e2a', woodD: '#36241a', woodL: '#86603e', cry: '#7ae8ff', cryD: '#3a8ad0', cryL: '#e8fcff' };
function wlCrystal(x, X, Y, s, bright) {
  if (bright) { for (let i = 0; i < 8; i++) { const a = i / 8 * TAU + 0.2; L(x, [[X + Math.cos(a) * s * 1.3, Y + Math.sin(a) * s * 1.6], [X + Math.cos(a) * s * (1.8 + bright * 0.6), Y + Math.sin(a) * s * (2.1 + bright * 0.6)]], i % 2 ? WL.rune : WL.cry, 1); } }
  P(x, [[X, Y - s * 1.8], [X + s, Y - s * 0.3], [X + s * 0.6, Y + s * 1.1], [X - s * 0.6, Y + s * 1.1], [X - s, Y - s * 0.3]], bright ? '#aef4ff' : WL.cry);
  P(x, [[X, Y - s * 1.8], [X + s, Y - s * 0.3], [X + s * 0.6, Y + s * 1.1], [X + s * 0.1, Y - s * 0.1]], bright ? WL.cry : WL.cryD);
  P(x, [[X - s * 0.2, Y - s * 1.3], [X - s * 0.7, Y - s * 0.3], [X - s * 0.2, Y + 0.2]], WL.cryL);
}
function wlStaff(x, bot, top, bright) {
  const d = [top[0] - bot[0], top[1] - bot[1]], l = Math.hypot(d[0], d[1]), n = [-d[1] / l, d[0] / l];
  const pts = []; for (let k = 0; k <= 6; k++) { const t = k / 6, w = Math.sin(t * 9) * 1.2; pts.push([bot[0] + d[0] * t + n[0] * w, bot[1] + d[1] * t + n[1] * w]); }
  limb(x, pts, 3, 3.6, WL.wood); L(x, pts.map(p => [p[0] - 0.6, p[1]]), WL.woodL, 0.7);
  for (const t of [0.3, 0.55, 0.8]) { const p = lp(bot, top, t); C(x, p[0], p[1], 2.2, WL.woodD); }
  // gnarled claws cupping the crystal
  for (const s of [-1, 1]) L(x, [[top[0] + n[0] * s * 1, top[1] + n[1] * s * 1], [top[0] + n[0] * s * 5 - d[0] / l * 3, top[1] + n[1] * s * 5 - d[1] / l * 3], [top[0] + n[0] * s * 4 - d[0] / l * 8, top[1] + n[1] * s * 4 - d[1] / l * 8]], WL.woodD, 2);
  wlCrystal(x, top[0] - d[0] / l * 6, top[1] - d[1] / l * 6, 4.2 + (bright || 0) * 0.6, bright);
}
function warlock(pose, f) {
  return frame(100, 100, x => {
    let lean = 0, sway = pose === 'idle' ? (f ? 2 : -1) : 0, hand = [66, 56], staffBot = [70, 94], staffTop = [72, 12], bright = pose === 'idle' && f ? 0.4 : 0;
    let eye = 'glow', mouth = 0, armUp = false, slump = 0;
    if (pose === 'cast') { hand = [68, 26]; staffBot = [66, 62]; staffTop = [72, 2]; bright = f ? 2 : 1; armUp = true; mouth = 0.6; }
    if (pose === 'hurt') { lean = -0.12; hand = [64, 58]; staffBot = [76, 94]; staffTop = [60, 16]; eye = 'shut'; mouth = 0.8; }
    if (pose === 'dead') {
      // a heap of robes, the staff dropped beside it
      wlStaff(x, [10, 92], [86, 88], 0);
      S(x, [[22, 94], [26, 80], [40, 72], [58, 74], [72, 84], [78, 94]], WL.robe);
      clip(x, () => smooth(x, [[22, 94], [26, 80], [40, 72], [58, 74], [72, 84], [78, 94]]), () => { E(x, 44, 76, 14, 4, WL.robeL); E(x, 52, 94, 30, 8, WL.robeD); R(x, 20, 90, 60, 3, WL.trim); for (let k = 0; k < 6; k++) R(x, 26 + k * 9, 90.5, 2, 2, WL.rune); });
      limb(x, [[24, 90], [12, 92], [6, 88]], 7, 2, LZ.dk);
      lzHead(x, [64, 82], 0.5, { eye: 'x', mouth: 0.3, hood: true });
      P(x, [[56, 72], [70, 74], [66, 82], [56, 84]], WL.robeD);
      return;
    }
    x.save(); x.translate(50, 94); x.rotate(lean); x.translate(-50, -94);
    // tail peeking out under the hem
    limb(x, [[38, 88], [26, 92], [18, 90], [14, 85]], 7, 2, LZ.sk);
    // back sleeve
    limb(x, [[44, 40], [38, 56], [44, 66]], 10, 12, WL.robeD);
    if (pose !== 'cast' && pose !== 'hurt') wlStaff(x, staffBot, staffTop, bright);
    // the robe
    const robe = [[42, 36], [37, 50], [33, 70], [27 + sway, 94], [36 + sway, 92], [46 + sway * 0.6, 95], [56 + sway * 0.5, 92], [66 + sway * 0.4, 95], [70 + sway * 0.3, 94], [64, 70], [61, 50], [60, 36], [51, 33]];
    P(x, robe, WL.robe);
    clip(x, () => { x.beginPath(); P(x, robe, WL.robe); x.beginPath(); x.moveTo(robe[0][0], robe[0][1]); for (const p of robe) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      P(x, [[30, 60], [40, 40], [44, 96], [24, 96]], WL.robeD);                  // folds
      L(x, [[52, 40], [54 + sway * 0.3, 94]], WL.robeD, 2);
      L(x, [[58, 44], [64 + sway * 0.3, 94]], WL.robeL, 1.5);
      L(x, [[46, 50], [44 + sway * 0.5, 94]], WL.robeL, 1);
      R(x, 20, 86, 60, 9, WL.trim);                                              // rune-embroidered hem
      for (let k = 0; k < 8; k++) { const X = 30 + k * 5 + sway * 0.5; R(x, X, 88, 1, 4, WL.rune); R(x, X, 88 + (k % 3), 3, 1, WL.rune); }
      R(x, 20, 86, 60, 1, WL.rune);
      R(x, 34, 56, 32, 4, WL.trim); R(x, 34, 57, 32, 1, '#7a4aa8');            // sash
      L(x, [[60, 36], [62, 56], [66, 94]], WL.trim, 2.5); L(x, [[60.5, 38], [62.5, 56], [66.5, 92]], WL.rune, 0.8);   // the front edge
    });
    L(x, [[46, 60], [44, 70], [46, 74]], '#7a4aa8', 1.5); C(x, 46, 75, 1.6, WL.rune);   // tassel
    // the hood with the snout poking out
    const hood = [[38, 44], [38, 30], [42, 20], [48, 16], [52, 17], [60, 22], [64, 32], [62, 42], [52, 46]];
    S(x, hood, WL.robe);
    clip(x, () => smooth(x, hood), () => { E(x, 42, 30, 6, 14, WL.robeD); E(x, 50, 19, 6, 2.5, WL.robeL); });
    P(x, [[42, 20], [34, 22], [28, 30], [38, 26]], WL.robeD);                    // the hood's point flopping back
    E(x, 57, 32, 6, 9, '#0e0618');                                               // the dark opening
    x.save(); x.beginPath(); x.ellipse(57, 32, 6, 9, 0, 0, TAU); x.rect(56, 22, 30, 24); x.clip();
    lzHead(x, [52, 32], 0.12, { mouth, eye: eye === 'shut' ? 'shut' : 'open', eyeCol: '#ffe040', hood: true, sk: '#3e7430', dk: '#244a1e', hi: '#5a9440' });
    x.restore();
    R(x, 56, 23, 9, 3, WL.robe); R(x, 57, 25, 6, 1, '#0e0618');                   // hood's brim over the eyes
    if (eye === 'glow') { C(x, 56, 29, 1.6, '#ffe860'); R(x, 55.5, 28.5, 1, 1, '#ffffff'); }
    L(x, [[42, 44], [50, 47], [60, 42]], WL.rune, 1);                            // trim on the hood
    // front sleeve and hand
    const sh = [57, 40], el = armUp ? [64, 34] : [60, 52];
    limb(x, [sh, el, [hand[0] - 3, hand[1] + (armUp ? 4 : 0)]], 9, 13, WL.robeL);
    limb(x, [sh, el], 8, 9, WL.robe);
    if (pose === 'cast' || pose === 'hurt') wlStaff(x, staffBot, staffTop, bright);
    C(x, hand[0], hand[1], 3.4, LZ.sk);
    for (let k = 0; k < 3; k++) R(x, hand[0] + 1.5, hand[1] - 2 + k * 1.8, 2, 1, LZ.claw);
    if (pose === 'cast' && f) {   // the spell ring around the crystal
      x.strokeStyle = WL.rune; x.lineWidth = 1.4; x.beginPath(); x.ellipse(staffTop[0] - 1, staffTop[1] + 6, 13, 13, 0, 0, TAU); x.stroke();
      for (let k = 0; k < 8; k++) { const a = k / 8 * TAU; R(x, staffTop[0] - 1 + Math.cos(a) * 13 - 1, staffTop[1] + 6 + Math.sin(a) * 13 - 1, 2, 2, WL.runeL); }
    }
    x.restore();
  });
}
function warlockBlink(f) {   // half dissolved into violet sparkles (already outlined: the holes must not get outlines)
  const c = fin(warlock('idle', 0)), x = g2(c), r = rng(31);
  x.globalCompositeOperation = 'source-atop'; wash(x, 0.4, () => R(x, 0, 0, 100, 100, '#b05aff'));
  x.globalCompositeOperation = 'destination-out';
  for (let Y = 8; Y < 100; Y++) for (let X = 20; X < 90; X += 1 + Math.floor(r() * 3)) { const t = (Y - 8) / 92; if (r() < 0.12 + t * t * 0.95) { R(x, X, Y, 1 + Math.floor(r() * 5), 1, '#000'); } }
  x.globalCompositeOperation = 'source-over';
  for (let i = 0; i < 46; i++) { const X = 24 + r() * 56, Y = 10 + r() * 86, big = r() < 0.25; if (big) { R(x, X - 1, Y, 3, 1, WL.rune); R(x, X, Y - 1, 1, 3, WL.rune); R(x, X, Y, 1, 1, WL.runeL); } else R(x, X, Y, 1, 1, r() < 0.5 ? WL.rune : WL.runeL); }
  c.__done = true; return c;
}
// ---------------- Snow Golem (170×150, feet at 85,144)
const GM = { sn: '#e4edf6', snS: '#b8c8dc', snD: '#8496b2', snL: '#ffffff', rk: '#5c6676', rkD: '#3a4252', rkL: '#7e8a9a', ice: '#a8e4f6', iceD: '#5ab0d8', gem: '#4af0ff', gemD: '#1a8ab0', gemL: '#e0ffff' };
function snowLump(x, pts, seed, shadeDir = 1) {   // a mass of packed snow with a clumpy edge
  shaggy(x, pts, GM.sn, 2.2, 7, seed, 0.1);
  clip(x, () => { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
    let mx = 0, my = 0, top = 1e9, bot = -1e9, lft = 1e9, rgt = -1e9; for (const p of pts) { mx += p[0] / pts.length; my += p[1] / pts.length; top = Math.min(top, p[1]); bot = Math.max(bot, p[1]); lft = Math.min(lft, p[0]); rgt = Math.max(rgt, p[0]); }
    const w = rgt - lft, h = bot - top;
    E(x, mx + w * 0.25 * shadeDir, my + h * 0.35, w * 0.6, h * 0.45, GM.snS);
    E(x, mx + w * 0.35 * shadeDir, my + h * 0.55, w * 0.45, h * 0.3, GM.snD);
    const r = rng(seed * 7); for (let i = 0; i < w * h / 90; i++) { const X = lft + r() * w, Y = top + r() * h; L(x, [[X, Y], [X + 3 + r() * 4, Y + (r() - 0.5) * 2]], r() < 0.5 ? GM.snS : GM.snL, 1); }
  });
}
function embedRock(x, X, Y, s, seed, ice) {
  const r = rng(seed), pts = []; for (let k = 0; k < 6; k++) { const a = k / 6 * TAU + r() * 0.5; pts.push([X + Math.cos(a) * s * (0.7 + r() * 0.4), Y + Math.sin(a) * s * (0.6 + r() * 0.3)]); }
  P(x, pts, ice ? GM.ice : GM.rk); P(x, [pts[3], pts[4], pts[5], [X, Y]], ice ? GM.iceD : GM.rkD); P(x, [pts[0], pts[1], [X, Y]], ice ? '#e8fbff' : GM.rkL);
  if (!ice) R(x, pts[4][0], pts[4][1] - 1, s * 0.8, 1, GM.sn);   // snow caught on it
}
function boneClub(x, hand, ang, len = 56) {
  const d = [Math.cos(ang), Math.sin(ang)], n = [-d[1], d[0]];
  const a = [hand[0] - d[0] * 8, hand[1] - d[1] * 8], b = [hand[0] + d[0] * len, hand[1] + d[1] * len];
  limb(x, [a, lp(a, b, 0.5), b], 7, 11, K.bone);
  L(x, [lp(a, b, 0.1).map((v, i) => v + n[i] * -2), lp(a, b, 0.85).map((v, i) => v + n[i] * -3.5)], '#f6f0e2', 1.4);
  L(x, [lp(a, b, 0.2).map((v, i) => v + n[i] * 2.5), lp(a, b, 0.9).map((v, i) => v + n[i] * 4)], K.boneS, 1.6);
  for (const s of [-1, 1]) { C(x, b[0] + n[0] * s * 6, b[1] + n[1] * s * 6, 8, K.bone); C(x, b[0] + n[0] * s * 6 - d[0] * 2, b[1] + n[1] * s * 6 - d[1] * 2, 4, '#f6f0e2'); }   // the big knuckle end
  C(x, b[0] + d[0] * 2, b[1] + d[1] * 2, 7, K.bone); E(x, b[0] + d[0] * 4 + n[0] * 2, b[1] + d[1] * 4 + n[1] * 2, 4, 3, K.boneS);
  for (const s of [-1, 1]) C(x, a[0] + n[0] * s * 3.5, a[1] + n[1] * s * 3.5, 4.5, K.bone);
  // spikes of ice driven into the head
  for (const [s, k] of [[-1, 0.2], [1, -0.3], [0, 0.6]]) { const o = [b[0] + n[0] * s * 9 + d[0] * 4, b[1] + n[1] * s * 9 + d[1] * 4], aa = ang + s * 0.9 + k; P(x, [[o[0] - n[0] * 2, o[1] - n[1] * 2], [o[0] + Math.cos(aa) * 9, o[1] + Math.sin(aa) * 9], [o[0] + n[0] * 2, o[1] + n[1] * 2]], GM.ice); }
}
function golem(pose, f) {
  return frame(170, 150, x => {
    let bx = 0, by = 0, lean = 0, eye = 1;
    let footB = [72, 144], footF = [100, 144], liftB = 0, liftF = 0;
    let armB = [[66, 58], [54, 84], [60, 106]], armF = [[106, 58], [116, 82], [120, 100]], club = 1.1, clen = 34;
    if (pose === 'idle') { by = f; armF = [[106, 58 + f], [116, 82 + f], [120, 100 + f]]; armB = [[66, 58 + f], [54, 84 + f], [60, 106 + f]]; club = 1.1 - f * 0.04; }
    if (pose === 'walk') {
      const p = f * Math.PI / 2, s = Math.sin(p), c = Math.cos(p);
      by = -Math.abs(s) * 2; bx = s * 1.5;
      footF = [100 + s * 9, 144]; liftF = c > 0 ? c * 7 : 0; footB = [72 - s * 9, 144]; liftB = c < 0 ? -c * 7 : 0;
      armB = [[66, 58 + by], [56 - s * 3, 84 + by], [62 - s * 6, 106 + by]]; armF = [[106, 58 + by], [116 + s * 2, 82 + by], [120 + s * 4, 100 + by]]; club = 1.1 - s * 0.15;
    }
    if (pose === 'wind') { by = -2; lean = -0.08; armF = [[104, 58], [118, 46], [104, 36]]; club = -2.75; clen = 30; armB = [[66, 58], [50, 74], [44, 92]]; }
    if (pose === 'smash') { bx = 4; by = 8; lean = 0.16; armF = [[108, 66], [116, 96], [114, 124]]; club = 0.1; clen = 34; armB = [[70, 66], [82, 92], [96, 118]]; }
    if (pose === 'hurt') { bx = -4; lean = -0.12; eye = 0.4; armF = [[104, 58], [116, 76], [124, 90]]; club = -0.55; armB = [[64, 58], [48, 70], [40, 84]]; }
    if (pose === 'dead') {
      boneClub(x, [96, 138], 0.08, 50);
      snowLump(x, [[34, 145], [42, 128], [58, 116], [80, 110], [102, 114], [120, 124], [134, 145]], 11);
      for (const [X, Y, s, sd, ice] of [[60, 128, 9, 2], [92, 120, 7, 3, true], [110, 134, 8, 4], [46, 140, 6, 5], [80, 138, 10, 6]]) embedRock(x, X, Y, s, sd, ice);
      snowLump(x, [[128, 145], [134, 134], [146, 132], [152, 145]], 13);
      for (const X of [70, 78]) { C(x, X, 117, 2.6, GM.gemD); R(x, X - 1, 116, 1, 1, '#8ac8d8'); }   // the gems gone dim
      return;
    }
    // heavy body pivot at the hips
    x.save(); x.translate(85, 110); x.rotate(lean); x.translate(-85 + bx, -110 + by);
    // back arm and back leg (shaded)
    const legPts = (hip, foot, lift) => [hip, [lerp(hip[0], foot[0], 0.5) + 4, lerp(hip[1], foot[1] - lift, 0.5)], [foot[0], foot[1] - lift - by]];
    const drawLeg = (hip, foot, lift, back, seed) => {
      const p = legPts(hip, foot, lift);
      limb(x, p, 28, 22, back ? GM.snS : GM.sn);
      if (!back) { E(x, p[1][0] + 7, p[1][1] + 6, 6, 14, GM.snS); C(x, p[0][0] - 6, p[0][1] + 4, 6, GM.sn); C(x, p[1][0] - 9, p[1][1] + 2, 4, GM.snL); }
      embedRock(x, p[1][0] + 2, p[1][1], 7, seed, false);                        // a boulder knee
      E(x, p[2][0] + 3, p[2][1] - 4, 15, 6, back ? GM.rkD : GM.rk); E(x, p[2][0] + 1, p[2][1] - 6, 10, 2.5, back ? GM.rk : GM.rkL);   // a flat boulder foot
    };
    const drawArm = (pts, back, seed) => {
      const col = back ? GM.snS : GM.sn;
      limb(x, [pts[0], pts[1]], 26, 22, col); limb(x, [pts[1], pts[2]], 22, 20, col);
      if (!back) { L(x, [lp(pts[0], pts[1], 0.2), lp(pts[1], pts[2], 0.6)].map(p => [p[0] - 6, p[1] - 3]), GM.snL, 2); }
      embedRock(x, pts[1][0], pts[1][1], 8, seed, !back);
      for (let k = 0; k < 3; k++) { const p = lp(pts[0], pts[1], 0.4 + k * 0.2); P(x, [[p[0] - 2, p[1] + 9], [p[0], p[1] + 15 + k * 2], [p[0] + 2, p[1] + 9]], GM.ice); }   // icicles under the arm
      E(x, pts[2][0], pts[2][1], 13, 11, back ? GM.rkD : GM.rk);                  // a boulder fist
      E(x, pts[2][0] - 3, pts[2][1] - 4, 7, 4, back ? GM.rk : GM.rkL);
      L(x, [[pts[2][0] - 6, pts[2][1] + 2], [pts[2][0] + 6, pts[2][1] + 3]], GM.rkD, 1.2);
    };
    drawArm(armB, true, 21);
    drawLeg([72, 108], footB, liftB, true, 31);
    // torso: a hunched mound of packed snow and stone
    snowLump(x, [[50, 112], [46, 86], [52, 60], [66, 44], [88, 38], [108, 42], [122, 56], [126, 80], [120, 104], [100, 116], [70, 118]], 41);
    for (const [X, Y, s, sd, ice] of [[60, 74, 10, 1], [98, 96, 8, 2], [72, 100, 6, 3, true], [112, 70, 7, 4, true], [82, 54, 6, 5]]) embedRock(x, X, Y, s, sd, ice);
    for (const [X, Y, a, l] of [[58, 54, -2.2, 14], [68, 46, -1.9, 18], [80, 42, -1.6, 12], [52, 66, -2.6, 10]]) { const d = [Math.cos(a), Math.sin(a)], n = [-d[1] * 3.5, d[0] * 3.5]; P(x, [[X + n[0], Y + n[1]], [X + d[0] * l, Y + d[1] * l], [X - n[0], Y - n[1]]], GM.ice); P(x, [[X, Y], [X + d[0] * l, Y + d[1] * l], [X - n[0], Y - n[1]]], GM.iceD); }   // ice spikes on the hump
    drawLeg([100, 108], footF, liftF, false, 32);
    // the head, sunk between the shoulders
    snowLump(x, [[84, 50], [84, 36], [94, 27], [110, 26], [122, 34], [126, 48], [116, 60], [96, 60]], 51);
    // a face of cracked stone pressed into the snow
    P(x, [[98, 34], [112, 31], [126, 36], [127, 52], [118, 60], [102, 58], [97, 48]], GM.rk);
    P(x, [[112, 31], [126, 36], [127, 52], [120, 50], [116, 38]], GM.rkD);
    P(x, [[98, 34], [112, 31], [109, 35], [99, 38]], GM.rkL);
    L(x, [[104, 50], [108, 46], [107, 42]], GM.rkD, 1);
    for (const [X, s] of [[107, 1], [120, 0.8]]) {
      E(x, X, 42, 5 * s, 4, '#1a2030');                                          // deep socket
      if (eye > 0.5) { P(x, [[X, 37.5], [X + 3.4 * s, 42], [X, 46.5], [X - 3.4 * s, 42]], GM.gem); P(x, [[X, 37.5], [X + 3.4 * s, 42], [X, 42]], GM.gemD); R(x, X - 1.5, 40, 1.5, 1.5, GM.gemL); }
      else { R(x, X - 3 * s, 42, 6 * s, 1.2, GM.gem); }
    }
    P(x, [[98, 37], [106, 33], [114, 36], [124, 33], [128, 38], [116, 40], [104, 40]], GM.ice);   // an icy brow
    P(x, [[104, 34], [114, 36], [108, 37]], '#e8fbff');
    P(x, [[104, 52], [120, 51], [117, 55], [106, 55]], '#1a2030');              // a craggy mouth
    for (let k = 0; k < 4; k++) P(x, [[103 + k * 4.5, 55], [104.5 + k * 4.5, 60 + (k % 2) * 3], [106 + k * 4.5, 55]], GM.ice);   // icicle beard
    // front arm with the club
    if (pose === 'wind') boneClub(x, armF[2], club, clen);
    drawArm(armF, false, 22);
    if (pose !== 'wind') boneClub(x, armF[2], club, clen);
    // fingers over the grip
    for (let k = 0; k < 3; k++) E(x, armF[2][0] + 3, armF[2][1] - 5 + k * 5, 5, 2.6, GM.rk);
    x.restore();
    if (pose === 'smash') { for (const [X, Y, s] of [[136, 142, 3], [166, 140, 3], [140, 130, 2], [164, 126, 2.4]]) C(x, X, Y, s, GM.sn); for (const [X, Y] of [[146, 120], [158, 116], [168, 128], [132, 126]]) R(x, X, Y, 2, 2, GM.snS); }
    if (pose === 'hurt') { for (const [X, Y, s] of [[44, 60, 4], [38, 76, 3], [50, 44, 3]]) { C(x, X, Y, s, GM.sn); } }
  });
}
// ---------------- yetis: one rig for the Cursed Yeti and King Yeti
// Poses are in "yeti units": (0,0) is the ground under the feet, y up is negative, a standing yeti is ~160 tall.
const YT = {
  mob: { fur: '#e6eaf0', furS: '#b4bccb', furD: '#848ea2', furL: '#ffffff', skin: '#56668a', skinD: '#38445e', skinL: '#7888a8', eye: '#f0b0ff', eyeD: '#a040e0', bulk: 1, head: 1.3, cursed: true },
  king: { fur: '#f2f1ee', furS: '#c6c8ca', furD: '#8e94a0', furL: '#ffffff', skin: '#62708e', skinD: '#3e4862', skinL: '#8494b2', eye: '#9af4ff', eyeD: '#2a9ad0', bulk: 1.16, head: 1.42, king: true },
};
function ytHand(x, P0, P1, kind, Y, w) {   // P0 = wrist, P1 = the hand's centre; kind: fist | open | knuckle | palmUp
  const a = Math.atan2(P1[1] - P0[1], P1[0] - P0[0]), d = [Math.cos(a), Math.sin(a)], n = [-d[1], d[0]];
  const r = w * 0.55;
  if (kind === 'open' || kind === 'palmUp') {
    E(x, P1[0], P1[1], r * 1.05, r * 0.9, Y.skin, a);
    for (let k = -1.5; k <= 1.5; k++) {
      const b = a + k * 0.32, base = [P1[0] + Math.cos(b) * r * 0.7, P1[1] + Math.sin(b) * r * 0.7], tip = [base[0] + Math.cos(b) * r * 1.0, base[1] + Math.sin(b) * r * 1.0];
      limb(x, [base, tip], r * 0.42, r * 0.32, Y.skin);
      P(x, [[tip[0] - n[0] * 1.4, tip[1] - n[1] * 1.4], [tip[0] + Math.cos(b) * r * 0.45, tip[1] + Math.sin(b) * r * 0.45], [tip[0] + n[0] * 1.4, tip[1] + n[1] * 1.4]], '#e8e4d8');
    }
    const th = [P1[0] - d[0] * r * 0.2 - n[0] * r * 0.8, P1[1] - d[1] * r * 0.2 - n[1] * r * 0.8];
    limb(x, [th, [th[0] + Math.cos(a - 0.9) * r * 0.9, th[1] + Math.sin(a - 0.9) * r * 0.9]], r * 0.45, r * 0.35, Y.skin);
    E(x, P1[0] - d[0] * r * 0.1, P1[1] - d[1] * r * 0.1, r * 0.6, r * 0.45, kind === 'palmUp' ? Y.skinL : Y.skinD, a);
    return;
  }
  // fist / knuckles
  E(x, P1[0], P1[1], r * 1.1, r * 0.95, Y.skin, a);
  E(x, P1[0] - n[0] * r * 0.3 - d[0] * r * 0.2, P1[1] - n[1] * r * 0.3 - d[1] * r * 0.2, r * 0.6, r * 0.45, Y.skinL, a);
  for (let k = -1; k <= 1; k++) { const p = [P1[0] + d[0] * r * 0.55 + n[0] * k * r * 0.45, P1[1] + d[1] * r * 0.55 + n[1] * k * r * 0.45]; L(x, [[p[0] - d[0] * 2, p[1] - d[1] * 2], [p[0] + d[0] * r * 0.4, p[1] + d[1] * r * 0.4]], Y.skinD, 1.2); }
  if (kind === 'knuckle') R(x, P1[0] - r, P1[1] + r * 0.7, r * 2, 2, Y.skinD);
}
function ytArm(x, A, Y, back, seed) {   // A = [shoulder, elbow, wrist-ish hand centre, kind]
  const b = Y.bulk, col = back ? Y.furS : Y.fur, w0 = 27 * b, w1 = 22 * b, w2 = 17 * b;
  const [sh, el, hd] = A, wr = lp(el, hd, 0.8);
  if (!back) { limb(x, [lp(sh, el, 0.35), el], w0 + 2.5, w1 + 2.5, Y.furD); limb(x, [el, wr], w1 + 2.5, w2 + 2.5, Y.furD); }   // a contour line so the near arm reads against the body
  furLimb(x, [sh, lp(sh, el, 0.5), el], w0, w1, col, seed, 2.6 * b);
  furLimb(x, [el, lp(el, wr, 0.5), wr], w1, w2, col, seed + 1, 2.4 * b);
  // fur strands and shade along the underside
  const da = Math.atan2(el[1] - sh[1], el[0] - sh[0]), db = Math.atan2(wr[1] - el[1], wr[0] - el[0]);
  const off = (p, a, s) => [p[0] - Math.sin(a) * s, p[1] + Math.cos(a) * s];
  const side = Math.cos(da) >= 0 ? 1 : -1, rr = rng(seed * 3);
  for (const [p0, p1, a, w] of [[sh, el, da, w0], [el, wr, db, w1]]) {
    for (let t = 0.1; t < 0.95; t += 0.12) {
      const p = lp(p0, p1, t), q = off(p, a, w * (0.18 + rr() * 0.2) * side);
      L(x, [q, [q[0] + Math.cos(a) * 3 + 0.5, q[1] + Math.sin(a) * 3 + 2]], back ? Y.furD : Y.furS, 1.2);
      const q2 = off(p, a, -w * (0.1 + rr() * 0.15) * side); if (rr() < 0.5) L(x, [q2, [q2[0] + Math.cos(a) * 3, q2[1] + Math.sin(a) * 3 + 1.5]], back ? Y.furS : Y.furS, 1);
    }
  }
  if (!back) L(x, [off(sh, da, -w0 * 0.3 * side), off(lp(sh, el, 0.8), da, -w1 * 0.3 * side)], Y.furL, 1.5);
  if (Y.cursed && !back) { veins(x, lp(sh, el, 0.3)[0], lp(sh, el, 0.3)[1], da, 26, seed + 5, '#8a2ad0', '#f0b0ff', 1.3); }
  if (Y.king) { for (const t of [0.42, 0.55]) { const p = lp(sh, el, t); limb(x, [[p[0] - Math.sin(da) * w0 * 0.45, p[1] + Math.cos(da) * w0 * 0.45], [p[0] + Math.sin(da) * w0 * 0.45, p[1] - Math.cos(da) * w0 * 0.45]], 4 * b, 4 * b, t < 0.5 ? '#6e5434' : '#9a7a4a'); } const p = lp(sh, el, 0.48); C(x, p[0], p[1], 2.2 * b, K.ice); }   // arm bands with an ice stud
  ytHand(x, wr, hd, A[3] || 'fist', Y, w2);
}
function ytLeg(x, G, Y, back, seed, by = 0) {   // G = [hip, knee, foot]
  const b = Y.bulk, col = back ? Y.furS : Y.fur, [hip, kn, ft] = G, ank = [ft[0] - 4, ft[1] - 8];
  if (!back) { limb(x, [lp(hip, kn, 0.15), kn], 32 * b + 2.5, 26 * b + 2.5, Y.furD); limb(x, [kn, ank], 26 * b + 2.5, 20 * b + 2.5, Y.furD); }
  furLimb(x, [hip, kn], 32 * b, 26 * b, col, seed, 3 * b);
  furLimb(x, [kn, ank], 26 * b, 20 * b, col, seed + 1, 3.4 * b);
  const rr = rng(seed * 5);
  for (let t = 0.15; t < 1; t += 0.14) { const p = lp(hip, kn, t), X = p[0] + (6 + rr() * 6) * b, Y0 = p[1]; L(x, [[X, Y0], [X + 1, Y0 + 4]], back ? Y.furD : Y.furS, 1.2); }
  // a big flat foot
  const fl = ft[1] < -4 && Math.abs(ft[1] - kn[1]) < 30 ? 0.4 : 0;
  E(x, ft[0] + 6 * b, ft[1] - 4, 15 * b, 6 * b, back ? Y.skinD : Y.skin, fl);
  for (let k = 0; k < 3; k++) C(x, ft[0] + (14 + k * 0.5) * b, ft[1] - 7 + k * 3 * b, 2.6 * b, back ? Y.skinD : Y.skin);
  for (let k = 0; k < 3; k++) R(x, ft[0] + 17 * b, ft[1] - 8 + k * 3 * b, 2.5, 1.4, '#e8e4d8');
  furLimb(x, [[ank[0] - 2, ank[1] - 6], [ft[0] + 2, ft[1] - 6]], 18 * b, 18 * b, col, seed + 3, 3 * b);   // fur spilling over the ankle
}
function ytTorso(x, hip, chest, Y) {
  const b = Y.bulk, v = [chest[0] - hip[0], chest[1] - hip[1]], l = Math.hypot(v[0], v[1]) || 1, n0 = [-v[1] / l, v[0] / l], n = n0[0] < 0 ? [-n0[0], -n0[1]] : n0;
  const at = (t, s) => [hip[0] + v[0] * t + n[0] * s * b, hip[1] + v[1] * t + n[1] * s * b];
  const pts = [at(-0.12, -20), at(0.3, -28), at(0.72, -36), at(1.0, -30), at(1.16, -14), at(1.2, 4), at(1.06, 22), at(0.7, 27), at(0.3, 24), at(0.0, 18), at(-0.14, 2)];
  shaggy(x, pts, Y.fur, 3.4 * b, 7, 77, 0.6);
  clip(x, () => { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
    P(x, [at(-0.2, 6), at(0.4, 12), at(0.9, 16), at(1.2, 30), at(-0.2, 30)], Y.furS);     // shaded belly
    P(x, [at(-0.2, 18), at(0.5, 20), at(1.0, 26), at(-0.2, 40)], Y.furD);
    P(x, [at(0.55, -30), at(0.85, -34), at(1.1, -18), at(0.9, -14)], Y.furL);            // light on the hump
    const r = rng(91); for (let i = 0; i < 22; i++) { const t = r() * 1.1, s = (r() - 0.5) * 50; const p = at(t, s); L(x, [p, [p[0] + 1, p[1] + 4 * b]], r() < 0.5 ? Y.furS : Y.furD, 1); }
    if (Y.cursed) { veins(x, ...at(0.85, 10), 1.9, 34, 12); veins(x, ...at(0.5, -6), 1.2, 28, 13); veins(x, ...at(0.95, -20), 2.4, 22, 14); }
    if (Y.king) { L(x, [at(0.9, 4), at(0.65, 16)], '#c88a8a', 1.6); L(x, [at(0.85, -2), at(0.6, 10)], '#c88a8a', 1.2); }   // old scars
  });
  return { at, n, v };
}
function ytHead(x, H, tilt, Y, o = {}) {
  const b = Y.bulk; x.save(); x.translate(H[0], H[1]); x.rotate(tilt); x.scale(Y.head, Y.head);
  // shaggy mane and skull
  const mane = [[-16, 10], [-18, -3], [-12, -12], [0, -15], [12, -12], [18, -5], [18, 8], [8, 16], [-8, 16]];
  shaggy(x, mane.map(p => [p[0] * 1.1, p[1] * 1.1 + 0.5]), Y.furD, 3.5, 6, 61, 0.7);   // contour so the head reads against the white body
  shaggy(x, mane, Y.fur, 3.5, 6, 61, 0.7);
  E(x, -5, 7, 11, 8, Y.furS); E(x, -2, -9, 9, 3.5, Y.furL);
  // face
  const fx = 9, fy = 2;
  S(x, [[fx - 7, fy - 9], [fx + 6, fy - 10], [fx + 12, fy - 4], [fx + 13, fy + 5], [fx + 9, fy + 13], [fx - 2, fy + 13], [fx - 7, fy + 4]], Y.skin);
  E(x, fx + 2, fy + 8, 8, 4, Y.skinD);
  E(x, fx - 1, fy - 3, 3, 4, Y.skinL);
  // heavy brow
  shaggy(x, [[fx - 10, fy - 7], [fx, fy - 12], [fx + 14, fy - 8], [fx + 13, fy - 4], [fx + 2, fy - 5], [fx - 8, fy - 2]], Y.furS, 1.6, 4, 63, 0.9);
  // eyes
  const ex = fx + 5, ey = fy - 2;
  if (o.eye === 'shut') { L(x, [[ex - 3, ey], [ex + 2, ey + 1]], '#141824', 1.4); }
  else if (o.eye === 'x') { L(x, [[ex - 2, ey - 2], [ex + 2, ey + 2]], '#141824', 1.2); L(x, [[ex + 2, ey - 2], [ex - 2, ey + 2]], '#141824', 1.2); }
  else { E(x, ex, ey, 3.2, 2.4, Y.eyeD); E(x, ex + 0.5, ey, 2, 1.6, Y.eye); R(x, ex, ey - 1, 1, 1, '#ffffff'); if (Y.cursed) { R(x, ex - 4, ey - 0.5, 2, 1, Y.eyeD); } }
  // nose and mouth
  P(x, [[fx + 11, fy], [fx + 15, fy + 2], [fx + 11, fy + 4]], Y.skinD);
  const m = o.mouth || 0;
  if (m > 0.1) {
    P(x, [[fx + 2, fy + 7], [fx + 14, fy + 6], [fx + 13, fy + 8 + m * 9], [fx + 3, fy + 9 + m * 6]], '#3a1020');
    E(x, fx + 8, fy + 9 + m * 5, 3.5, 1.6 + m, '#8a3040');
    for (let k = 0; k < 3; k++) P(x, [[fx + 5 + k * 3, fy + 6.5], [fx + 6 + k * 3, fy + 9.5], [fx + 7 + k * 3, fy + 6.5]], '#f4f0e4');
    P(x, [[fx + 11, fy + 7 + m * 8], [fx + 12, fy + 3 + m * 8], [fx + 13, fy + 7 + m * 8]], '#f4f0e4');
  } else {
    L(x, [[fx + 3, fy + 8], [fx + 9, fy + 9], [fx + 13, fy + 7]], '#1c2030', 1.2);
    P(x, [[fx + 10, fy + 8], [fx + 11, fy + 4.5], [fx + 12.5, fy + 8]], '#f4f0e4');   // a fang
  }
  if (Y.king) {
    // tusks jutting up from the lower jaw
    P(x, [[fx + 4, fy + 9 + m * 6], [fx + 1, fy - 1], [fx + 6, fy + 8 + m * 6]], '#efe6cf');
    P(x, [[fx + 12, fy + 8 + m * 6], [fx + 14, fy - 1], [fx + 15, fy + 8 + m * 6]], '#efe6cf');
    L(x, [[fx - 4, fy - 6], [fx + 2, fy + 4]], '#c88a8a', 1.3);                        // a scar over the eye
    // a crude crown of bone and ice
    x.save(); x.translate(0, 7); R(x, -14, -20, 26, 5, '#d8ccb0'); R(x, -14, -20, 26, 1.5, '#f2ead6'); R(x, -14, -16, 26, 1, '#8a7e66');
    for (const [X, h, ice] of [[-12, 6, 0], [-6, 9, 1], [0, 11, 0], [6, 8, 1], [11, 6, 0]]) {
      if (ice) { P(x, [[X - 2.5, -19], [X, -19 - h], [X + 2.5, -19]], K.ice); P(x, [[X, -19], [X, -19 - h], [X + 2.5, -19]], K.iceD); }
      else { P(x, [[X - 2, -19], [X - 1, -19 - h], [X + 1, -19 - h], [X + 2, -19]], '#e2d8c0'); C(x, X, -19 - h, 2, '#e2d8c0'); }
    }
    C(x, 0, -17.5, 2, K.cyan); R(x, -0.5, -18.5, 1, 1, '#ffffff'); x.restore();
  }
  if (Y.cursed) { L(x, [[-6, -14], [-2, -8], [-6, -2]], Y.eyeD, 1.2); C(x, -2, -8, 1, Y.eye); }
  x.restore();
}
// pendant: an icy cyan gem in a bone setting on a cord
function ytPendant(x, G, s = 1, glow = true) {
  if (glow) { for (let i = 0; i < 6; i++) { const a = i / 6 * TAU + 0.3; R(x, G[0] + Math.cos(a) * 9 * s - 0.5, G[1] + Math.sin(a) * 9 * s - 0.5, 1.5, 1.5, '#bffcff'); } }
  P(x, [[G[0], G[1] - 7 * s], [G[0] + 6 * s, G[1]], [G[0], G[1] + 8 * s], [G[0] - 6 * s, G[1]]], '#d8ccb0');     // bone setting
  P(x, [[G[0], G[1] - 5 * s], [G[0] + 4 * s, G[1]], [G[0], G[1] + 6 * s], [G[0] - 4 * s, G[1]]], K.cyan);
  P(x, [[G[0], G[1] - 5 * s], [G[0] + 4 * s, G[1]], [G[0], G[1] + 1]], '#2ab8e0');
  R(x, G[0] - 2 * s, G[1] - 2 * s, 1.5 * s, 1.5 * s, '#ffffff');
}
// draws the whole yeti; returns the points the game needs (front hand, pendant) in the same units
function ytDraw(x, Q, Y) {
  const out = {};
  if (Q.pre) Q.pre(x);
  ytArm(x, Q.armB, Y, true, 11);
  ytLeg(x, Q.legB, Y, true, 21);
  const T = ytTorso(x, Q.hip, Q.chest, Y);
  ytLeg(x, Q.legF, Y, false, 31);
  ytHead(x, Q.head, Q.tilt || 0, Y, Q);
  ytArm(x, Q.armF, Y, false, 41);
  if (Y.king) {   // the pendant hangs on a cord round his neck, in front of everything so it always shows
    const g = T.at(0.98, 22), c0 = T.at(1.1, 8), c1 = T.at(1.12, 20);
    L(x, [c0, lp(c0, g, 0.6), g], '#5a4030', 1.6); L(x, [c1, g], '#5a4030', 1.6);
    ytPendant(x, g, Y.bulk, true); out.neck = g;
  }
  out.hand = Q.armF[2];
  if (Q.post) Q.post(x);
  return out;
}

// ---- Cursed Yeti poses (200×200, feet at 100,192)
function yetiPose(pose, f) {
  let Q = {
    hip: [-6, -66], chest: [8, -118], head: [24, -134], tilt: 0.05,
    legB: [[-14, -62], [-12, -32], [-18, 0]], legF: [[2, -62], [10, -32], [8, 0]],
    armB: [[-6, -114], [-22, -80], [-16, -44], 'fist'], armF: [[22, -112], [32, -76], [34, -42], 'fist'],
  };
  if (pose === 'idle') { const b = f * 2; Q.chest[1] += b; Q.head[1] += b; Q.armF = [[22, -112 + b], [33, -76 + b], [35, -41 + b * 0.5], 'fist']; Q.armB = [[-6, -114 + b], [-23, -80 + b], [-17, -43 + b * 0.5], 'fist']; }
  if (pose === 'run') {
    const p = f * Math.PI / 2, s = Math.sin(p), c = Math.cos(p), bob = Math.abs(c) * 4;
    Q = { hip: [-16, -60 - bob], chest: [16, -100 - bob], head: [40, -104 - bob], tilt: 0.25,
      legB: [[-22, -58 - bob], [-8 + s * 10, -30 - bob], [-18 + s * 22, -(c < 0 ? -c * 10 : 0)]], legF: [[-8, -58 - bob], [6 - s * 10, -30 - bob], [-2 - s * 22, -(c > 0 ? c * 10 : 0)]],
      armB: [[4, -98 - bob], [26 - s * 8, -60], [36 - s * 22, -8 - (s < 0 ? 0 : s * 10)], 'knuckle'], armF: [[28, -96 - bob], [44 + s * 8, -60], [52 + s * 22, -8 - (s > 0 ? 0 : -s * 10)], 'knuckle'] };
  }
  if (pose === 'swipe') {
    if (f === 0) { Q.chest = [-2, -116]; Q.head = [14, -134]; Q.tilt = -0.1; Q.armF = [[12, -114], [-6, -140], [-30, -150], 'open']; Q.armB = [[-10, -112], [10, -84], [24, -66], 'fist']; Q.mouth = 0.5; }
    else {
      Q.chest = [20, -112]; Q.head = [38, -126]; Q.tilt = 0.15; Q.armF = [[32, -108], [58, -98], [84, -86], 'open']; Q.armB = [[2, -110], [-18, -84], [-30, -64], 'fist']; Q.mouth = 0.8; Q.legF = [[4, -62], [20, -32], [24, 0]];
      Q.pre = (x) => { for (let k = 0; k < 3; k++) { x.strokeStyle = k % 2 ? '#f0b0ff' : '#ffffff'; x.lineWidth = 2; x.beginPath(); x.arc(30, -100, 60 + k * 8, -1.9 + k * 0.1, -0.1 + k * 0.15); x.stroke(); } };
    }
  }
  if (pose === 'leap') {
    Q = { hip: [-4, -84], chest: [6, -132], head: [24, -144], tilt: -0.1, mouth: 0.7,
      legB: [[-12, -80], [4, -58], [-16, -42]], legF: [[2, -80], [20, -60], [8, -40]],
      armB: [[-6, -128], [-16, -158], [-6, -178], 'fist'], armF: [[22, -126], [24, -160], [14, -180], 'fist'] };
  }
  if (pose === 'slam') {
    Q = { hip: [-12, -50], chest: [18, -94], head: [38, -96], tilt: 0.3, mouth: 0.9,
      legB: [[-20, -48], [-34, -26], [-30, 0]], legF: [[-4, -48], [18, -30], [12, 0]],
      armB: [[8, -92], [30, -56], [42, -10], 'fist'], armF: [[30, -88], [52, -52], [62, -10], 'fist'],
      post: (x) => { for (const [X, s] of [[76, 6], [30, 5], [88, 4], [20, 3]]) C(x, X, -4, s, '#c8d4e2'); L(x, [[48, 0], [58, -3], [66, 0], [76, -2]], '#3a4252', 1.4); for (const [X, Y] of [[44, -24], [80, -22], [70, -32], [36, -18]]) R(x, X, Y, 3, 3, '#7a8494'); } };
  }
  if (pose === 'hurt') { Q.chest = [-6, -114]; Q.head = [6, -132]; Q.tilt = -0.45; Q.eye = 'shut'; Q.mouth = 0.7; Q.armF = [[14, -110], [32, -96], [44, -110], 'open']; Q.armB = [[-14, -112], [-34, -96], [-46, -104], 'open']; Q.hip = [-10, -66]; }
  if (pose === 'dead') {
    Q = { hip: [-34, -20], chest: [26, -26], head: [52, -18], tilt: 0.5, eye: 'x', mouth: 0.3,
      legB: [[-36, -18], [-60, -26], [-80, 0]], legF: [[-30, -16], [-50, -10], [-72, 0]],
      armB: [[16, -30], [34, -22], [52, -6], 'open'], armF: [[18, -18], [0, -8], [-14, -4], 'open'] };
  }
  return Q;
}
function yeti(pose, f) {
  return frame(200, 200, x => { x.translate(100, 192); ytDraw(x, yetiPose(pose, f), YT.mob); });
}

// ---------------- Enchanted Sword (120×40, the centre of the sword at 60,20; tip to the right)
function sword(pose, f) {
  return frame(120, 40, x => {
    const bright = pose === 'fly' && f === 1, cy = 20;
    const blade = (x0, x1, top = 0) => {
      P(x, [[x0, cy - 5], [x1 - 12, cy - 5], [x1, cy], [x1 - 12, cy + 5], [x0, cy + 5]], '#b8c4d4');
      P(x, [[x0, cy], [x1 - 12, cy], [x1, cy], [x1 - 12, cy + 5], [x0, cy + 5]], '#7e8ca2');
      R(x, x0, cy - 5, Math.max(0, x1 - 12 - x0), 1, '#eef4fa');
      R(x, x0, cy - 1.5, Math.max(0, x1 - 20 - x0), 3, '#3a3e62');                   // the fuller
      for (let X = x0 + 3; X < x1 - 22; X += 7) { const c = ((X / 7) | 0) % 2 ? '#5af0ff' : '#d07aff'; R(x, X, cy - 1, 3, 2, bright ? '#ffffff' : c); R(x, X + 1, cy - 1.5, 1, 3, c); }
    };
    if (pose === 'dead') {   // snapped in two
      x.save(); x.translate(44, 22); x.rotate(-0.15); x.translate(-44, -22); swordHilt(x, cy); blade(34, 66); P(x, [[64, cy - 5], [68, cy - 2], [65, cy + 1], [68, cy + 5], [64, cy + 5]], '#b8c4d4'); x.restore();
      x.save(); x.translate(90, 24); x.rotate(0.3); x.translate(-90, -20); blade(72, 116); x.restore();
      for (const [X, Y] of [[70, 12], [74, 30], [68, 28]]) R(x, X, Y, 2, 2, '#dce8f4');
      return;
    }
    if (bright) { for (const [X, Y] of [[44, 10], [70, 30], [90, 11], [58, 31], [100, 28], [30, 8]]) { R(x, X - 1, Y, 3, 1, '#bffcff'); R(x, X, Y - 1, 1, 3, '#bffcff'); } }
    blade(34, 116);
    swordHilt(x, cy, bright);
    if (pose === 'hurt') { L(x, [[60, 13], [64, 19], [61, 23], [66, 27]], '#2a2e44', 1.2); }
  });
}
function swordHilt(x, cy, bright) {
  // ornate crossguard, wrapped grip and a pommel gem
  P(x, [[30, cy - 13], [36, cy - 9], [36, cy + 9], [30, cy + 13], [27, cy + 8], [29, cy], [27, cy - 8]], '#8a6aa8');
  P(x, [[30, cy - 13], [33, cy - 10], [33, cy + 10], [30, cy + 13], [29, cy]], '#c8a8e8');
  C(x, 32, cy, 3, '#3a1a5a'); C(x, 32, cy, 2, bright ? '#ffffff' : '#d07aff');
  R(x, 12, cy - 3, 15, 6, '#3e2a4a');
  for (let X = 13; X < 27; X += 3) L(x, [[X, cy - 3], [X + 2, cy + 3]], '#6a4a7a', 1.2);
  E(x, 9, cy, 4.5, 4.5, '#8a6aa8'); C(x, 9, cy, 2.6, bright ? '#bffcff' : '#5af0ff'); R(x, 8, cy - 2, 1, 1, '#ffffff');
}
// ================================================================== KING YETI (320×280 frames, feet at 160,272)
const KY = { w: 320, h: 280, ax: 160, ay: 272, s: 1.375, swordLen: 226 };
const KEYS = { sit: 1, rise: 1, idle: 2, run: 4, punch: 2, throw: 2, grab: 1, hold: 1, slam: 2, lift: 1, roar: 1, hurt: 1, kneel: 1, fallen: 1 };
// sword: a fixed angle, 'ground' (tip resting on the ground in front) or 'back' (dragged behind, tip on the ground)
function kingPose(k, f) {
  const braced = { legF: [[2, -60], [16, -30], [20, 0]], legB: [[-14, -60], [-24, -30], [-34, 0]] };
  let Q = {
    hip: [-8, -62], chest: [6, -110], head: [20, -126], tilt: 0,
    legB: [[-16, -60], [-16, -30], [-24, 0]], legF: [[0, -60], [8, -30], [8, 0]],
    armB: [[-10, -106], [-28, -76], [-26, -44], 'fist'], armF: [[22, -104], [38, -78], [46, -52], 'fist'], sw: 'ground',
  };
  if (k === 'idle') { const b = f * 2; Q.chest[1] += b; Q.head[1] += b; Q.armF = [[22, -104 + b], [38, -78 + b], [46, -52 + b * 0.5], 'fist']; Q.armB = [[-10, -106 + b], [-28, -76 + b], [-26, -44 + b * 0.5], 'fist']; }
  if (k === 'sit') Q = { hip: [-28, -64], chest: [-30, -108], head: [-14, -124], tilt: 0.05,
    legF: [[-18, -60], [30, -52], [26, 0]], legB: [[-28, -62], [20, -56], [12, 0]],
    armF: [[-12, -102], [8, -80], [30, -64], 'fist'], armB: [[-40, -104], [-20, -82], [16, -66], 'fist'], sw: 0 };
  if (k === 'rise') Q = { hip: [-14, -78], chest: [8, -114], head: [26, -124], tilt: 0.25,
    legF: [[-8, -76], [18, -58], [14, 0]], legB: [[-18, -76], [8, -56], [0, 0]],
    armF: [[24, -108], [28, -84], [22, -62], 'fist'], armB: [[-4, -108], [4, -86], [12, -64], 'fist'], sw: 0.3 };
  if (k === 'run') {
    const p = f * Math.PI / 2, s = Math.sin(p), c = Math.cos(p), bob = Math.abs(c) * 4;
    Q = { hip: [-6, -64 - bob], chest: [12, -108 - bob], head: [28, -122 - bob], tilt: 0.12,
      legF: [[2, -62 - bob], [10 + s * 14, -34 - bob - Math.max(0, c) * 8], [6 + s * 26, -(c > 0 ? c * 14 : 0)]],
      legB: [[-12, -62 - bob], [-8 - s * 14, -34 - bob - Math.max(0, -c) * 8], [-14 - s * 26, -(c < 0 ? -c * 14 : 0)]],
      armF: [[24, -102 - bob], [34 - s * 14, -76 - bob], [40 - s * 24, -52 - bob], 'fist'],
      armB: [[-6, -104 - bob], [-18 + s * 14, -76 - bob], [-14 + s * 26, -50 - bob], 'fist'], sw: 'back' };
  }
  if (k === 'punch') {
    if (f === 0) Q = { ...braced, hip: [-8, -62], chest: [-2, -108], head: [14, -124], tilt: -0.05, armF: [[16, -102], [-8, -90], [-22, -104], 'fist'], armB: [[-14, -104], [6, -82], [24, -80], 'fist'], sw: -2.4 };
    else Q = { ...braced, hip: [-4, -62], chest: [16, -106], head: [32, -120], tilt: 0.1, mouth: 0.6, armF: [[28, -100], [58, -98], [90, -98], 'fist'], armB: [[-4, -102], [-22, -80], [-20, -58], 'fist'], sw: 0 };
  }
  if (k === 'throw') {
    if (f === 0) Q = { ...braced, hip: [-10, -62], chest: [-8, -106], head: [8, -122], tilt: -0.1, armF: [[10, -100], [-24, -110], [-56, -128], 'open'], armB: [[-18, -102], [6, -90], [26, -96], 'open'], sw: -2.7 };
    else Q = { ...braced, hip: [-4, -62], chest: [18, -104], head: [34, -118], tilt: 0.15, mouth: 0.7, armF: [[30, -98], [62, -94], [92, -80], 'open'], armB: [[-2, -100], [-26, -84], [-40, -70], 'open'], sw: 0.35 };
  }
  if (k === 'grab') Q = { hip: [-4, -60], chest: [16, -104], head: [32, -120], tilt: 0.05, mouth: 0.4, legF: [[4, -58], [26, -34], [30, 0]], legB: [[-12, -58], [-26, -28], [-40, 0]],
    armF: [[28, -98], [62, -92], [98, -88], 'open'], armB: [[-4, -100], [-20, -76], [-16, -50], 'fist'], sw: 0.15 };
  if (k === 'hold') { Q.chest = [4, -112]; Q.head = [16, -128]; Q.tilt = -0.25; Q.mouth = 0.3; Q.armF = [[22, -106], [32, -144], [24, -178], 'fist']; Q.sw = -Math.PI / 2; }
  if (k === 'slam') {
    if (f === 0) { Q.chest = [2, -114]; Q.head = [16, -128]; Q.tilt = -0.15; Q.mouth = 0.5; Q.armF = [[20, -108], [26, -144], [14, -176], 'fist']; Q.armB = [[-10, -108], [-12, -144], [-2, -174], 'fist']; Q.sw = -Math.PI / 2 - 0.5; }
    else Q = { hip: [-12, -50], chest: [16, -94], head: [34, -100], tilt: 0.3, mouth: 0.9,
      legB: [[-20, -48], [-36, -24], [-32, 0]], legF: [[-4, -48], [20, -30], [14, 0]],
      armB: [[8, -92], [34, -56], [48, -12], 'fist'], armF: [[28, -88], [56, -50], [68, -12], 'fist'], sw: 'ground',
      post: (x) => { for (const [X, s] of [[84, 7], [30, 5], [96, 4], [20, 3]]) C(x, X, -4, s, '#c8d4e2'); L(x, [[50, 0], [60, -3], [70, 0], [82, -2]], '#3a4252', 1.4); for (const [X, Y] of [[46, -26], [88, -24], [76, -34], [36, -20], [100, -14]]) R(x, X, Y, 3, 3, '#7a8494'); } };
  }
  if (k === 'lift') { Q.chest = [4, -112]; Q.head = [14, -128]; Q.tilt = -0.35; Q.mouth = 0.4; Q.armF = [[22, -106], [40, -140], [42, -172], 'palmUp']; Q.armB = [[-12, -106], [-30, -140], [-32, -170], 'palmUp']; Q.sw = -Math.PI / 2; }
  if (k === 'roar') { Q.chest = [10, -110]; Q.head = [22, -126]; Q.tilt = -0.6; Q.mouth = 1; Q.armF = [[22, -104], [46, -90], [64, -104], 'fist']; Q.armB = [[-10, -106], [-36, -92], [-54, -104], 'fist']; Q.sw = -0.5; }
  if (k === 'hurt') { Q.hip = [-12, -62]; Q.chest = [-6, -108]; Q.head = [6, -122]; Q.tilt = -0.45; Q.eye = 'shut'; Q.mouth = 0.7; Q.armF = [[14, -102], [30, -90], [42, -104], 'open']; Q.armB = [[-16, -104], [-36, -90], [-48, -98], 'open']; Q.sw = -1.0; }
  if (k === 'kneel') Q = { hip: [-6, -52], chest: [14, -96], head: [30, -100], tilt: 0.45, eye: 'shut', mouth: 0.3,
    legB: [[-12, -50], [-22, -10], [-48, -4]], legF: [[2, -50], [28, -46], [26, 0]],
    armF: [[26, -90], [42, -56], [46, -12], 'fist'], armB: [[-2, -92], [-6, -66], [2, -44], 'open'], sw: 'ground' };
  if (k === 'fallen') Q = { hip: [-50, -22], chest: [20, -28], head: [52, -18], tilt: 0.6, eye: 'x', mouth: 0.2,
    legB: [[-54, -20], [-80, -12], [-104, 0]], legF: [[-46, -16], [-72, -6], [-98, 0]],
    armF: [[22, -18], [50, -10], [78, -8], 'open'], armB: [[10, -34], [-4, -14], [-20, -6], 'open'], sw: 0 };
  return Q;
}
function kingFrame(k, f) {
  const Q = kingPose(k, f), c = cv(KY.w, KY.h), x = g2(c);
  x.save(); x.translate(KY.ax, KY.ay); x.scale(KY.s, KY.s);
  const pts = ytDraw(x, Q, YT.king);
  x.restore();
  const px = p => [Math.round(KY.ax + p[0] * KY.s), Math.round(KY.ay + p[1] * KY.s)];
  const hand = px(pts.hand), neck = px(pts.neck);
  let ang = Q.sw;
  if (ang === 'ground' || ang === 'back') { const h = KY.ay - hand[1] - 3, a = h >= KY.swordLen ? Math.PI / 2 : Math.asin(Math.max(0, h) / KY.swordLen); ang = Q.sw === 'ground' ? a : Math.PI - a; }
  return { c: fin(c), hand: [hand[0], hand[1], Math.round(ang * 1000) / 1000], neck };
}
function yetiSword() {   // 260×56, tip right, grip at 34,28
  const c = cv(260, 56), x = g2(c), cy = 28;
  // blade
  P(x, [[58, cy - 12], [228, cy - 10], [258, cy], [228, cy + 10], [58, cy + 12]], '#c4d4e4');
  P(x, [[58, cy], [258, cy], [228, cy + 10], [58, cy + 12]], '#8698b2');
  R(x, 58, cy - 12, 170, 2, '#f0f8ff');
  for (const [a, b] of [[90, 4], [150, 3], [200, 5]]) P(x, [[a, cy + 12 - (a - 58) * 0.012], [a + b, cy + 8], [a + b * 2, cy + 12 - (a - 58) * 0.012]], '#5a6a84');   // nicks in the edge
  R(x, 62, cy - 3, 156, 6, '#1e3a5a');                                       // the fuller
  for (let X = 66, i = 0; X < 212; X += 11, i++) {                            // icy runes
    const g = i % 4; x.fillStyle = '#7af4ff';
    if (g === 0) { R(x, X, cy - 2, 1.5, 4, '#7af4ff'); R(x, X, cy - 2, 5, 1.5, '#7af4ff'); R(x, X + 3.5, cy, 1.5, 2, '#7af4ff'); }
    if (g === 1) { R(x, X, cy - 0.75, 6, 1.5, '#7af4ff'); R(x, X + 2.25, cy - 2, 1.5, 4, '#7af4ff'); }
    if (g === 2) { R(x, X, cy - 2, 1.5, 4, '#7af4ff'); R(x, X + 4, cy - 2, 1.5, 4, '#7af4ff'); R(x, X, cy - 0.5, 5.5, 1.2, '#7af4ff'); }
    if (g === 3) { P(x, [[X, cy + 2], [X + 3, cy - 2.5], [X + 6, cy + 2]], '#7af4ff'); R(x, X + 2.5, cy, 1, 1, '#1e3a5a'); }
    R(x, X + 1, cy - 1, 1, 1, '#ffffff');
  }
  for (const [X, Y] of [[120, 14], [180, 40], [234, 22], [96, 41]]) { R(x, X - 2, Y, 5, 1, '#bffcff'); R(x, X, Y - 2, 1, 5, '#bffcff'); }   // frost sparkles
  // a huge crossguard of bone and ice
  P(x, [[48, 2], [60, 8], [62, 48], [48, 54], [44, 44], [50, cy], [44, 12]], '#d8ccb0');
  P(x, [[48, 2], [56, 7], [56, 49], [48, 54], [50, cy]], '#f2ead6');
  P(x, [[46, 4], [40, -2], [44, 10]], K.ice); P(x, [[46, 52], [40, 58], [44, 46]], K.ice);
  C(x, 54, cy, 5, '#2a5a7a'); C(x, 54, cy, 3.4, K.cyan); R(x, 52, cy - 2, 1.5, 1.5, '#ffffff');
  // grip wrapped in hide and the pommel
  R(x, 16, cy - 5, 30, 10, '#4a3424');
  for (let X = 17; X < 46; X += 4) L(x, [[X, cy - 5], [X + 3, cy + 5]], '#7a5a3a', 1.6);
  E(x, 11, cy, 7, 8, '#d8ccb0'); C(x, 10, cy, 4, '#2a5a7a'); C(x, 10, cy, 2.6, K.cyan); R(x, 9, cy - 2, 1, 1, '#ffffff');
  return fin(c);
}
function throne(broken) {   // 200×220, bottom-centre at 100,220, the seat's top at 70 above the bottom (y 150)
  const c = cv(200, 220), x = g2(c), r = rng(broken ? 88 : 77), B = K.bone, BS = K.boneS, BD = K.boneD;
  const rib = (y, s, len, snap) => { const pts = curl(100 + s * 6, y, s > 0 ? -0.15 : Math.PI + 0.15, snap ? len * 0.45 : len, s * -1.9, 10); limb(x, pts, 7, 3, B); L(x, pts.slice(1, -2).map(p => [p[0], p[1] - 1.5]), '#f4eedc', 1); L(x, pts.slice(1, -1).map(p => [p[0], p[1] + 2]), BS, 1.2); if (snap) { const t = pts[pts.length - 1]; P(x, [[t[0] - 3, t[1] - 3], [t[0] + 2, t[1] - 5], [t[0] + 3, t[1] + 2]], BS); } };
  const skull = (X, Y, s, big) => {
    E(x, X, Y, 12 * s, 10 * s, B); E(x, X, Y + 8 * s, 8 * s, 6 * s, B);
    E(x, X - 2 * s, Y - 4 * s, 8 * s, 4 * s, '#f4eedc');
    for (const k of [-1, 1]) { E(x, X + k * 5 * s, Y + 1 * s, 3.2 * s, 3.6 * s, '#1a1a24'); if (big) C(x, X + k * 5 * s, Y + 1.5 * s, 1.2 * s, K.cyan); }
    P(x, [[X - 1.5 * s, Y + 6 * s], [X, Y + 3.5 * s], [X + 1.5 * s, Y + 6 * s]], '#1a1a24');
    for (let k = -2; k <= 2; k++) R(x, X + k * 2.6 * s - 1, Y + 10 * s, 2 * s, 3 * s, '#f4eedc');
    if (big) for (const k of [-1, 1]) { const pts = curl(X + k * 10 * s, Y - 4 * s, k > 0 ? -0.6 : Math.PI + 0.6, 26 * s, k * -2.2, 8); limb(x, pts, 6 * s, 1.5 * s, '#d0c4a8'); }   // curled horns
  };
  if (!broken) {
    // the spine and the great ribcage fanning up behind the seat
    limb(x, [[100, 152], [100, 90], [100, 34]], 12, 10, BS);
    for (let k = 0; k < 12; k++) R(x, 94, 40 + k * 9.5, 12, 3, BD);
    for (let i = 0; i < 6; i++) for (const s of [-1, 1]) rib(52 + i * 15, s, 60 - i * 4);
    skull(100, 30, 1.5, true);
  } else {
    limb(x, [[100, 156], [101, 120], [106, 96]], 12, 10, BS);
    for (let k = 0; k < 5; k++) R(x, 95, 104 + k * 9.5, 12, 3, BD);
    P(x, [[100, 92], [108, 88], [112, 98], [104, 100]], BS);
    for (let i = 2; i < 6; i++) for (const s of [-1, 1]) rib(52 + i * 15, s, 60 - i * 4, i < 4 || (i === 4 && s > 0));
  }
  // tusks for armrests
  for (const s of [-1, 1]) {
    const pts = broken && s > 0 ? curl(100 + s * 52, 168, -Math.PI / 2 + s * 0.1, 30, s * -0.6, 8) : curl(100 + s * 52, 168, -Math.PI / 2 + s * 0.15, 66, s * -1.7, 12);
    limb(x, pts, 14, 3, '#efe6cf'); L(x, pts.slice(1, -2).map(p => [p[0] - s * 2, p[1]]), '#fffaf0', 1.4); L(x, pts.slice(1, -1).map(p => [p[0] + s * 3, p[1] + 1]), BS, 1.6);
    for (let k = 1; k < 4; k++) { const p = pts[k * 2]; L(x, [[p[0] - 6, p[1]], [p[0] + 6, p[1] + 1]], BD, 1); }
  }
  // the seat: a slab draped with a white pelt
  if (!broken) {
    R(x, 40, 150, 120, 12, BS); R(x, 40, 150, 120, 3, B);
    shaggy(x, [[44, 150], [156, 150], [150, 178], [120, 172], [100, 182], [76, 172], [50, 178]], '#e8eaee', 2.4, 6, 19, 0.8);
    R(x, 44, 150, 112, 2, '#ffffff'); E(x, 100, 170, 40, 6, '#c4c8d0');
  } else {
    P(x, [[40, 160], [150, 146], [156, 156], [44, 172]], BS); P(x, [[40, 160], [150, 146], [150, 149], [40, 163]], B);
    shaggy(x, [[60, 160], [120, 152], [126, 176], [90, 182], [64, 178]], '#d4d8e0', 2.4, 6, 23, 0.8);
  }
  // base: piled bones and skulls
  P(x, [[30, 220], [36, 176], [164, 176], [170, 220]], '#3e4656');
  for (let i = 0; i < 26; i++) { const X = 40 + r() * 120, Y = 182 + r() * 34, a = (r() - 0.5) * 1.2, l = 8 + r() * 12; limb(x, [[X - Math.cos(a) * l, Y - Math.sin(a) * l], [X + Math.cos(a) * l, Y + Math.sin(a) * l]], 3.5, 3.5, r() < 0.5 ? B : BS); C(x, X - Math.cos(a) * l, Y - Math.sin(a) * l, 3, B); C(x, X + Math.cos(a) * l, Y + Math.sin(a) * l, 3, B); }
  for (const [X, Y, s] of broken ? [[60, 204, 0.9], [134, 208, 0.8]] : [[56, 200, 1], [100, 204, 1.1], [144, 200, 1]]) skull(X, Y, s, false);
  if (broken) {
    // the great skull fallen and cracked, half buried in rocks
    skull(150, 180, 1.3, true); L(x, [[146, 166], [152, 176], [148, 186]], '#2a2a34', 1.4);
    const rr = rng(5);
    for (let i = 0; i < 16; i++) { const X = 20 + rr() * 160, Y = 196 + rr() * 22, s = 6 + rr() * 12; const pts = []; for (let k = 0; k < 6; k++) { const a = k / 6 * TAU + rr() * 0.5; pts.push([X + Math.cos(a) * s, Y + Math.sin(a) * s * 0.7]); } P(x, pts, rr() < 0.5 ? '#3e4858' : '#525e70'); P(x, [pts[3], pts[4], pts[5], [X, Y]], '#2c3442'); R(x, X - s * 0.4, Y - s * 0.55, s * 0.6, 1.5, '#6e7c90'); }
    for (const [X, Y, a] of [[30, 150, 0.3], [176, 168, -0.4], [70, 136, 1.1]]) limb(x, [[X, Y], [X + Math.cos(a) * 18, Y + Math.sin(a) * 18]], 5, 3, BS);
  }
  return fin(c);
}
function bigBoulder() {   // 48×44: the boulder he throws
  const c = cv(48, 44), x = g2(c);
  boulderBody(x, 24, 22, 19.5, 0.6);
  P(x, [[10, 12], [20, 5], [28, 6], [18, 9]], '#dcecf8');
  return fin(c);
}
function stalactite() {   // 24×64, wide at the top, pointed at the bottom
  const c = cv(24, 64), x = g2(c);
  const pts = [[0, 0], [24, 0], [22, 8], [19, 18], [17, 30], [14, 44], [12.5, 56], [12, 64], [10, 54], [8, 42], [6, 30], [3, 16], [1, 8]];
  P(x, pts, '#4a5668');
  P(x, [[12, 0], [24, 0], [22, 8], [19, 18], [17, 30], [14, 44], [12.5, 56], [12, 64], [12, 30]], '#323c4c');
  P(x, [[2, 0], [8, 0], [7, 20], [9, 40], [11, 58], [6, 34], [3, 14]], '#6a7a8e');
  for (const [X, Y] of [[6, 10], [14, 22], [9, 36], [16, 8]]) L(x, [[X, Y], [X + 2, Y + 3]], '#28303c', 1);
  // an ice glaze down the front
  P(x, [[4, 4], [12, 6], [13, 30], [12.5, 56], [11, 62], [9, 46], [7, 30], [5, 16]], '#9fd8f0');
  P(x, [[8, 6], [12, 6], [13, 30], [12.5, 56], [11, 30]], '#5aa0cc');
  L(x, [[6, 8], [8, 26], [10, 44]], '#e8fbff', 1);
  R(x, 0, 0, 24, 3, '#2a3240');
  return fin(c);
}
function kingPortrait() {   // 220×170: face, shoulders and the pendant
  const c = cv(220, 170), x = g2(c);
  const Q = kingPose('idle', 0); Q.armF = [[22, -104], [38, -78], [46, -52], 'fist']; Q.mouth = 0.35;
  x.save(); x.translate(76, 262); x.scale(1.6, 1.6);
  ytDraw(x, Q, YT.king);
  x.restore();
  return fin(c);
}
function pendantItem() {   // 32×32 key item
  const c = cv(32, 32), x = g2(c);
  glowDot(x, 16, 18, 16, '#5af0ff', 1);
  for (let i = 0; i < 8; i++) { const a = i / 8 * TAU + 0.39, l = i % 2 ? 12 : 15; L(x, [[16 + Math.cos(a) * 9, 18 + Math.sin(a) * 9], [16 + Math.cos(a) * l, 18 + Math.sin(a) * l]], '#bffcff', 1); }
  x.strokeStyle = '#6a4a30'; x.lineWidth = 1.4; x.beginPath(); x.ellipse(16, 11, 7, 8, 0, Math.PI, TAU); x.stroke();
  ytPendant(x, [16, 18], 1.9, false);
  R(x, 22, 9, 1, 3, '#ffffff'); R(x, 21, 10, 3, 1, '#ffffff');
  return fin(c);
}
function bakeYeti() {
  const strips = {}, meta = { w: KY.w, h: KY.h, ax: KY.ax, ay: KY.ay, keys: {}, hand: {}, neck: {}, swordGrip: [34, 28] };
  for (const [k, n] of Object.entries(KEYS)) {
    strips[k] = []; meta.keys[k] = n; meta.hand[k] = []; meta.neck[k] = [];
    for (let f = 0; f < n; f++) { const r = kingFrame(k, f); strips[k].push(r.c); meta.hand[k].push(r.hand); meta.neck[k].push(r.neck); }
  }
  const pics = {
    'boss/yeti_sword.png': yetiSword(), 'boss/yeti_portrait.png': kingPortrait(),
    'boss/throne.png': throne(false), 'boss/throne_broken.png': throne(true),
    'boss/boulder.png': bigBoulder(), 'boss/stalactite.png': stalactite(),
  };
  return { strips, meta, pics };
}
// ------------------------------------------------------------------ sets
// anchor: where the feet (or the bottom of the body) sit in a frame, in pixels
const SETS = {
  boulder: { w: 88, h: 72, ax: 44, ay: 66, draw: boulder, keys: { idle: 2, roll: 4, float: 2, launch: 1, hurt: 1, dead: 1 } },
  lizard: { w: 100, h: 96, ax: 50, ay: 90, draw: lizard, keys: { idle: 2, walk: 4, whip: 2, leap: 1, hurt: 1, dead: 1 } },
  golem: { w: 170, h: 150, ax: 85, ay: 144, draw: golem, keys: { idle: 2, walk: 4, wind: 1, smash: 1, hurt: 1, dead: 1 } },
  warlock: { w: 100, h: 100, ax: 50, ay: 94, draw: (k, f) => k === 'blink' ? warlockBlink(f) : warlock(k, f), keys: { idle: 2, cast: 2, blink: 1, hurt: 1, dead: 1 } },
  yeti: { w: 200, h: 200, ax: 100, ay: 192, draw: yeti, keys: { idle: 2, run: 4, swipe: 2, leap: 1, slam: 1, hurt: 1, dead: 1 } },
  sword: { w: 120, h: 40, ax: 60, ay: 20, draw: sword, keys: { fly: 2, hurt: 1, dead: 1 } },
};
const FIRST = { boulder: 'idle', lizard: 'idle', golem: 'idle', warlock: 'idle', yeti: 'idle', sword: 'fly' };
const SHINY = 'hue-rotate(150deg) saturate(1.5) brightness(1.35)';
const ELITE = 'brightness(0.8) saturate(1.6) hue-rotate(-25deg) contrast(1.15)';

function bakeMobs(only) {
  const out = {};
  for (const [name, S0] of Object.entries(SETS)) {
    if (only && !only.includes(name)) continue;
    const base = {};
    for (const [k, n] of Object.entries(S0.keys)) base[k] = Array.from({ length: n }, (_, f) => { const c = S0.draw(k, f); return c.__done ? c : fin(c); });
    base.white = [whiteOf(base[FIRST[name]][0])];
    const dim = { ax: S0.ax / 2, ay: S0.ay / 2, w: S0.w / 2, h: S0.h / 2 };
    out[name] = { sets: base, dim };
    const tint = (f) => Object.fromEntries(Object.entries(base).map(([k, fr]) => [k, k === 'white' ? fr : fr.map(c => filtered(c, f))]));
    out[name + '_shiny'] = { sets: tint(SHINY), dim };
    out[name + '_elite'] = { sets: tint(ELITE), dim };
  }
  return out;
}

// ================================================================== ITEMS (9×9 like the other residues)
function icon(draw) { const c = cv(9, 9), x = g2(c); draw(x); return c; }
const ITEMS = {
  residue_boulder: icon(x => { R(x, 1, 2, 7, 6, '#5a6878'); R(x, 2, 1, 5, 1, '#5a6878'); R(x, 2, 2, 3, 1, '#8e9cac'); R(x, 3, 4, 3, 2, '#f2ece4'); R(x, 4, 4, 1, 2, '#3a6ab0'); R(x, 4, 4, 1, 1, '#0a0c14'); R(x, 2, 7, 6, 1, '#3a4656'); }),
  residue_lizard: icon(x => { R(x, 2, 2, 5, 5, '#6e4428'); R(x, 3, 3, 3, 3, '#42281a'); R(x, 4, 4, 1, 1, '#9a6a3e'); R(x, 1, 6, 2, 2, '#9a6a3e'); R(x, 7, 1, 1, 2, '#d0a848'); R(x, 6, 2, 1, 1, '#9a6a3e'); }),
  residue_golem: icon(x => { R(x, 4, 0, 1, 9, '#4af0ff'); R(x, 3, 1, 3, 7, '#4af0ff'); R(x, 2, 3, 5, 3, '#4af0ff'); R(x, 5, 2, 1, 5, '#1a8ab0'); R(x, 6, 4, 1, 1, '#1a8ab0'); R(x, 3, 2, 1, 2, '#e0ffff'); }),
  residue_warlock: icon(x => { R(x, 2, 1, 5, 6, '#5a2e84'); R(x, 3, 7, 3, 1, '#5a2e84'); R(x, 4, 8, 1, 1, '#5a2e84'); R(x, 2, 1, 2, 2, '#8a5ac0'); R(x, 4, 3, 2, 3, '#3a1a5c'); R(x, 5, 4, 1, 1, '#d07aff'); }),
  residue_yeti: icon(x => { R(x, 3, 1, 3, 7, '#e6eaf0'); R(x, 2, 2, 5, 5, '#e6eaf0'); R(x, 1, 6, 2, 2, '#b4bccb'); R(x, 6, 6, 2, 2, '#b4bccb'); R(x, 4, 2, 1, 4, '#8a2ad0'); R(x, 5, 4, 1, 1, '#f0b0ff'); }),
  residue_sword: icon(x => { for (let i = 0; i < 6; i++) R(x, 1 + i, 7 - i, 2, 1, '#c4d4e4'); R(x, 6, 1, 2, 1, '#f0f8ff'); R(x, 3, 5, 1, 1, '#5af0ff'); R(x, 5, 3, 1, 1, '#d07aff'); R(x, 7, 5, 1, 1, '#ffffff'); R(x, 1, 2, 1, 1, '#ffffff'); }),
};
// ================================================================== BACKDROPS (1536×240 far, 1536×180 mid; tiled sideways)
// periodic value noise over the width, so every silhouette wraps round seamlessly
function loopNoise(seed, n) { const r = rng(seed), v = Array.from({ length: n }, () => r() * 2 - 1); return (t) => { const u = ((t % 1) + 1) % 1 * n, i = Math.floor(u), f = u - i, a = v[i % n], b = v[(i + 1) % n], s = (1 - Math.cos(f * Math.PI)) / 2; return a + (b - a) * s; }; }
function ridgeY(W, base, amp, seed, oct = [[5, 1], [13, 0.45], [37, 0.2], [97, 0.08]], ridged = true) {
  const ns = oct.map(([n], i) => loopNoise(seed + i * 101, n));
  return (X) => { let v = 0, t = 0; oct.forEach(([, a], i) => { const q = ns[i](X / W); v += (ridged && i < 2 ? 1 - Math.abs(q) * 2 : q) * a; t += a; }); return base - amp * (v / t * 0.5 + 0.5); };
}
function fillRidge(x, W, H, fy, col, step = 2) { x.fillStyle = col; x.beginPath(); x.moveTo(0, H); for (let X = 0; X <= W; X += step) x.lineTo(X, fy(X)); x.lineTo(W, H); x.closePath(); x.fill(); }
function wrapDraw(W, X, fn) { fn(X); if (X < 200) fn(X + W); if (X > W - 200) fn(X - W); }
// snow caps: paint the top band of a ridge, down to `depth` below the crest, only where the crest is high
function capRidge(x, W, fy, col, depth, above) { x.fillStyle = col; for (let X = 0; X < W; X += 2) { const y = fy(X); if (y < above) { const d = depth * (above - y) / 60 + 2; x.fillRect(X, y, 2, d * (0.6 + 0.4 * Math.sin(X * 0.21) * Math.sin(X * 0.057))); } } }
function pine(x, X, Y, h, col, snow, lean = 0) {
  R(x, X - 1, Y - h * 0.2, 2, h * 0.2, col);
  for (let k = 0; k < 4; k++) { const y0 = Y - h * 0.15 - k * h * 0.2, w = h * (0.32 - k * 0.06); P(x, [[X - w + lean * k, y0], [X + lean * (k + 1) * 1.3, y0 - h * 0.34], [X + w + lean * k, y0]], col); if (snow) P(x, [[X - w * 0.6 + lean * k, y0 - h * 0.1], [X + lean * (k + 1) * 1.3, y0 - h * 0.33], [X + w * 0.5 + lean * k, y0 - h * 0.12]], snow); }
}
// a range of peaks (tileable): each peak is a jittered triangle; the right-hand faces are shaded and the tops snow-capped
function range(x, W, H, o) {
  const r = rng(o.seed), peaks = [];
  for (let i = 0; i < o.n; i++) { const X0 = (i + r() * 0.8) / o.n * W; if (o.avoid && Math.abs(X0 - o.avoid[0]) < o.avoid[1]) { r(); r(); r(); r(); continue; } peaks.push({ X: X0, h: o.hMin + r() * (o.hMax - o.hMin), sl: o.slope * (0.7 + r() * 0.6), sr: o.slope * (0.7 + r() * 0.6) }); }
  const jit = loopNoise(o.seed + 7, 220), jit2 = loopNoise(o.seed + 9, 53), jit3 = loopNoise(o.seed + 11, 13);
  const prof = (X) => {
    let best = -1e9, pk = null;
    for (const p of peaks) for (const d of [-W, 0, W]) { const dx = X - (p.X + d), y = p.h - Math.abs(dx) * (dx < 0 ? p.sl : p.sr); if (y > best) { best = y; pk = { p, dx }; } }
    const j = jit(X / W) * o.jag + jit2(X / W) * o.jag * 2 + Math.abs(jit3(X / W)) * o.jag * 3;
    return { y: o.base - Math.max(best, o.floor || 0) + j, pk };
  };
  for (let X = 0; X < W; X++) {
    const { y, pk } = prof(X), Y = Math.round(y);
    R(x, X, Y, 1, H - Y, o.col);
    if (pk.dx > 0) { const fac = Math.min(1, pk.dx / 8); R(x, X, Y + (1 - fac) * 3, 1, H - Y, o.shade); }
    if (o.snow) { const top = o.base - pk.p.h, depth = (o.capFrac * pk.p.h) * (0.75 + 0.25 * Math.sin(X * 0.37) * Math.sin(X * 0.11)); if (Y < top + depth) R(x, X, Y, 1, top + depth - Y, pk.dx > 0 ? o.snowS : o.snow); }
    if (o.rib && pk.dx > 0 && (X * 13) % 29 === 0) L(x, [[X, Y + 4], [X + 6, Y + 26]], o.rib, 1);
  }
  return (X) => prof(((X % W) + W) % W).y;
}
function climbFar() {
  const W = 1536, H = 240, c = cv(W, H), x = g2(c), r = rng(101);
  // the Abyssal Volcano on the horizon, with a plume of smoke
  const vx = 980;
  for (let i = 0; i < 9; i++) E(x, vx + 20 + i * 22 + Math.sin(i) * 8, 40 - i * 6, 22 + i * 4, 12 + i * 2, i % 2 ? '#4a4450' : '#3e3846');
  P(x, [[vx - 260, H], [vx - 60, 62], [vx - 30, 56], [vx + 26, 58], [vx + 60, 64], [vx + 280, H]], '#2e2836');
  P(x, [[vx - 60, 62], [vx - 30, 56], [vx - 10, 62], [vx - 120, H], [vx - 260, H]], '#3a3444');
  for (let k = 0; k < 7; k++) L(x, [[vx - 40 + k * 12, 64], [vx - 70 + k * 22 + (r() - 0.5) * 30, 150 + r() * 60]], '#24202c', 2);
  R(x, vx - 30, 56, 56, 3, '#ff6a2a'); R(x, vx - 22, 54, 40, 2, '#ffb03a');
  for (let k = 0; k < 4; k++) L(x, [[vx - 20 + k * 14, 60], [vx - 26 + k * 16, 80 + k * 8], [vx - 30 + k * 18, 96 + k * 10]], k % 2 ? '#c03a1a' : '#ff6a2a', 1.5);   // lava runs
  // the far range (cold grey-blue), low in front of the volcano
  range(x, W, H, { seed: 11, n: 10, base: 236, hMin: 60, hMax: 150, slope: 1.1, jag: 5, avoid: [vx, 110], floor: 20, col: '#7d8ca2', shade: '#68778e', snow: '#dae4ee', snowS: '#b6c4d6', capFrac: 0.22, rib: '#5e6c84' });
  range(x, W, H, { seed: 13, n: 16, base: 240, hMin: 14, hMax: 40, slope: 0.9, jag: 2, floor: 8, col: '#66748a', shade: '#5a6880' });
  crisp(c);
  glowDot(x, vx, 52, 40, '#ff5a2a', 0.45); glowDot(x, vx, 56, 18, '#ffb03a', 0.5);
  return c;
}
function climbMid() {
  const W = 1536, H = 180, c = cv(W, H), x = g2(c), r = rng(111);
  const fy = range(x, W, H, { seed: 21, n: 9, base: 180, hMin: 50, hMax: 130, slope: 0.8, jag: 6, floor: 24, col: '#4a5668', shade: '#3c4658', snow: '#c8d4e2', snowS: '#a8b6c8', capFrac: 0.12, rib: '#56627a' });
  for (let i = 0; i < 50; i++) { const X = r() * W, Y = fy(X) + 14 + r() * 80; if (Y < H - 4) L(x, [[X, Y], [X + 14 + r() * 30, Y + 4 + (r() - 0.5) * 4]], '#56627a', 1.2); }   // strata
  for (let i = 0; i < 26; i++) { const X = r() * W; wrapDraw(W, X, X0 => pine(x, X0, fy(X0) + 4, 14 + r() * 12, '#2a3442', null, 0.8)); }
  return crisp(c);
}
function snowFar() {
  const W = 1536, H = 240, c = cv(W, H), x = g2(c);
  range(x, W, H, { seed: 31, n: 9, base: 236, hMin: 90, hMax: 200, slope: 1.2, jag: 5, floor: 30, col: '#dfe9f4', shade: '#b4c6dc', snow: '#f4f8fc', snowS: '#cad8e8', capFrac: 0.3, rib: '#98aec8' });
  range(x, W, H, { seed: 33, n: 14, base: 240, hMin: 20, hMax: 60, slope: 0.8, jag: 2, floor: 10, col: '#c8d8ea', shade: '#aec0d6' });
  return crisp(c);
}
function snowMid() {
  const W = 1536, H = 180, c = cv(W, H), x = g2(c), r = rng(121);
  const fy = ridgeY(W, 176, 90, 41, [[4, 1], [12, 0.4], [33, 0.15]], false);
  for (let i = 0; i < 70; i++) { const X = r() * W; wrapDraw(W, X, X0 => pine(x, X0, fy(X0) + 6, 22 + r() * 22, '#2e4656', '#e6f0fa', 0.5)); }
  fillRidge(x, W, H, fy, '#c8d8ea');
  for (let X = 0; X < W; X += 1) { const y = fy(X); R(x, X, y, 1, 1, '#f4f8fc'); R(x, X, y + 22 + Math.sin(X * 0.02) * 8, 1, H, '#b8cadf'); }
  for (let i = 0; i < 26; i++) { const X = r() * W; wrapDraw(W, X, X0 => pine(x, X0, fy(X0) + 10, 18 + r() * 14, '#24384a', '#eef4fa', 0.5)); }
  return crisp(c);
}
function caveFar() {   // a dark rock wall with ice in it, filling the whole picture
  const W = 1536, H = 240, c = cv(W, H), x = g2(c), r = rng(131);
  R(x, 0, 0, W, H, '#0e1420');
  for (let i = 0; i < 260; i++) { const X = r() * W, Y = r() * H, s = 6 + r() * 26; wrapDraw(W, X, X0 => E(x, X0, Y, s * 1.4, s, r() < 0.5 ? '#121a28' : '#0b101a', r())); }   // lumpy rock
  for (let i = 0; i < 40; i++) { const X = r() * W, Y = r() * H; wrapDraw(W, X, X0 => L(x, [[X0, Y], [X0 + 10 + r() * 30, Y + (r() - 0.5) * 20], [X0 + 30 + r() * 30, Y + (r() - 0.5) * 30]], '#070a12', 1.5)); }   // cracks
  for (let i = 0; i < 10; i++) {   // frozen falls: pale ice running down the wall in wavy sheets
    const X = r() * W, w = 10 + r() * 22, top = r() * 80, ph = r() * 9;
    wrapDraw(W, X, X0 => {
      const Lp = [], Rp = []; for (let Y = top; Y <= H; Y += 8) { const t = (Y - top) / (H - top); Lp.push([X0 - w * (0.4 + t * 0.5) + Math.sin(Y * 0.09 + ph) * 3, Y]); Rp.push([X0 + w * (0.3 + t * 0.5) + Math.sin(Y * 0.07 + ph * 2) * 3, Y]); }
      P(x, Lp.concat(Rp.reverse()), '#18263c');
      L(x, Lp.map(p => [p[0] + 3, p[1]]), '#2e4868', 1.5); L(x, Lp.slice(2).map(p => [p[0] + w * 0.4, p[1]]), '#22385a', 1);
    });
  }
  for (let i = 0; i < 40; i++) {   // ice crystals glinting in the wall
    const X = r() * W, Y = 20 + r() * (H - 30), s = 2 + r() * 4;
    wrapDraw(W, X, X0 => { for (const [dx, a, l] of [[0, -1.57, 1.6], [-s * 0.5, -2.1, 1.1], [s * 0.5, -1.0, 1.2]]) { const tx = X0 + dx + Math.cos(a) * s * l, ty = Y + Math.sin(a) * s * l; P(x, [[X0 + dx - 1.2, Y], [tx, ty], [X0 + dx + 1.2, Y]], '#3a6a9a'); } R(x, X0 - 0.5, Y - s, 1, 1, '#8ac8f0'); });
  }
  for (let i = 0; i < 30; i++) { const X = r() * W; wrapDraw(W, X, X0 => P(x, [[X0 - 4, 0], [X0 + 4, 0], [X0, 14 + r() * 30]], '#182436')); }   // icicles from the far roof
  return crisp(c);
}
function caveMid() {   // ice columns and hanging icicles, closer
  const W = 1536, H = 180, c = cv(W, H), x = g2(c), r = rng(141);
  const fy = ridgeY(W, 176, 34, 51, [[6, 1], [19, 0.4], [60, 0.2]], false);
  for (let i = 0; i < 9; i++) {   // full columns: a stalactite met by a stalagmite
    const X = 60 + i * 170 + r() * 60, w = 10 + r() * 14;
    wrapDraw(W, X, X0 => {
      P(x, [[X0 - w * 1.6, 0], [X0 + w * 1.6, 0], [X0 + w * 0.6, 60], [X0 + w * 0.5, 120], [X0 + w * 1.4, H], [X0 - w * 1.4, H], [X0 - w * 0.5, 120], [X0 - w * 0.6, 60]], '#0c1220');
      L(x, [[X0 - w * 0.8, 10], [X0 - w * 0.3, 70], [X0 - w * 0.4, 150]], '#2a5a88', 2); L(x, [[X0 - w * 0.4, 30], [X0 - w * 0.1, 90]], '#4a8ab8', 1);
    });
  }
  for (let i = 0; i < 46; i++) {   // icicles and stalactites hanging from the top
    const X = r() * W, w = 3 + r() * 9, h = 16 + r() * 60;
    wrapDraw(W, X, X0 => { P(x, [[X0 - w, 0], [X0 + w, 0], [X0 + w * 0.2, h * 0.7], [X0, h], [X0 - w * 0.3, h * 0.6]], '#0e1626'); L(x, [[X0 - w * 0.5, 2], [X0 - w * 0.1, h * 0.6]], '#3a78a8', 1); });
  }
  R(x, 0, 0, W, 6, '#0c1220');
  fillRidge(x, W, H, fy, '#0c1220');
  for (let i = 0; i < 34; i++) { const X = r() * W, w = 4 + r() * 10, h = 14 + r() * 40; wrapDraw(W, X, X0 => { const b = fy(X0) + 4; P(x, [[X0 - w, b], [X0, b - h], [X0 + w, b]], '#0e1626'); L(x, [[X0 - w * 0.3, b - h * 0.2], [X0 - 1, b - h * 0.8]], '#3a78a8', 1); }); }
  return crisp(c);
}
function peakFar() {   // a sea of clouds lit red from below, black crags rising out of it
  const W = 1536, H = 240, c = cv(W, H), x = g2(c), r = rng(151);
  for (let i = 0; i < 7; i++) {   // the distant crags
    const X = r() * W, h = 70 + r() * 110, w = 26 + r() * 40;
    wrapDraw(W, X, X0 => { P(x, [[X0 - w, H], [X0 - w * 0.4, H - h * 0.6], [X0 - w * 0.1, H - h], [X0 + w * 0.15, H - h * 0.8], [X0 + w * 0.5, H - h * 0.55], [X0 + w, H]], '#2a2028'); P(x, [[X0 - w * 0.1, H - h], [X0 + w * 0.15, H - h * 0.8], [X0 + w * 0.5, H - h * 0.55], [X0 + w, H], [X0 + w * 0.3, H]], '#1e161e'); L(x, [[X0 - w * 0.3, H - h * 0.5], [X0 - w * 0.1, H - h * 0.3], [X0 - w * 0.25, H - h * 0.1]], '#a02a1a', 1.5); });
  }
  const fy = ridgeY(W, 214, 60, 61, [[8, 1], [21, 0.6], [53, 0.3]], false);
  // billowing cloud tops, warm underneath
  for (let row = 0; row < 3; row++) {
    const rr = rng(70 + row);
    for (let X = 0; X < W; X += 18 + rr() * 20) {
      const y = fy(X) + row * 14 + rr() * 6, s = 12 + rr() * 16;
      wrapDraw(W, X, X0 => { C(x, X0, y, s, ['#d8c8d0', '#c8a8b4', '#b88894'][row]); C(x, X0 - s * 0.25, y - s * 0.35, s * 0.6, ['#f0e4ea', '#dcc4cc', '#c8a0a8'][row]); E(x, X0 + s * 0.2, y + s * 0.6, s * 0.9, s * 0.3, ['#c8a8b4', '#b88894', '#a87882'][row]); });
    }
  }
  R(x, 0, 228, W, 12, '#a87882');
  crisp(c);
  for (let i = 0; i < 6; i++) { const X = 120 + i * 260; glowDot(x, X, 236, 110, '#ff6a3a', 0.25); }
  return c;
}
function peakMid() {   // jagged black volcanic crags with lava in their cracks
  const W = 1536, H = 180, c = cv(W, H), x = g2(c), r = rng(161);
  x.save();
  const fy = range(x, W, H, { seed: 71, n: 13, base: 180, hMin: 50, hMax: 150, slope: 1.9, jag: 8, floor: 30, col: '#1e181e', shade: '#141016' });
  for (let i = 0; i < 40; i++) {   // glowing cracks
    let X = r() * W, Y = fy(X) + 10 + r() * 60; const pts = [[X, Y]];
    for (let k = 0; k < 5; k++) { X += (r() - 0.5) * 16; Y += 6 + r() * 10; pts.push([X, Y]); }
    wrapDraw(W, pts[0][0], X0 => { const d = X0 - pts[0][0]; L(x, pts.map(p => [p[0] + d, p[1]]), '#c03a1a', 2); L(x, pts.map(p => [p[0] + d, p[1]]), '#ffb03a', 0.8); });
  }
  for (let X = 0; X < W; X += 1) { const y = fy(X); if (Math.sin(X * 0.05) * Math.sin(X * 0.013) > 0.25 && y < 110) R(x, X, y, 1, 2 + Math.sin(X * 0.3) * 1.5, '#d8e0ea'); }   // windblown snow on the crests
  x.restore();
  crisp(c);
  for (let i = 0; i < 8; i++) glowDot(x, 100 + i * 190, 178, 70, '#ff4a1a', 0.35);
  return c;
}
const SKY = { climb_far: climbFar, climb_mid: climbMid, snow_far: snowFar, snow_mid: snowMid, cave_far: caveFar, cave_mid: caveMid, peak_far: peakFar, peak_mid: peakMid };
// ================================================================== MAPS (2× the map size)
// returns { canvas, glows: [[x, y, r, colour], …] in world units }
const THEME = {
  climb: { rock: ['#262e3a', '#36404e', '#4a5566', '#62708a'], strata: '#56627a', crack: '#1a2028', top: ['#9aaabc', '#dce8f4'] },
  snow: { rock: ['#28303e', '#36404f', '#4a5668', '#64728a'], strata: '#56627a', crack: '#1a2028', top: ['#c4d4e6', '#f4f8fc'] },
  cave: { rock: ['#0b1018', '#121a26', '#1a2636', '#2a3a52'], strata: '#22324a', crack: '#05080e', top: ['#4a90c0', '#a8e4f6'] },
  peak: { rock: ['#120e12', '#1e181e', '#2e262e', '#4a3e48'], strata: '#3a3038', crack: '#050305', top: ['#4a3e46', '#6a5a62'] },
};
function paintMap(id, M) {
  const W = M.w * 2, H = M.h * 2, c = cv(W, H), x = g2(c), r = rng(id.length * 977 + M.w + (M.ruin ? 5 : 0)), glows = [];
  x.save(); x.scale(2, 2);
  const theme = M.theme, T = THEME[theme], ruin = !!M.ruin;
  const pieces = (M.floor || [[20, M.w - 20, M.floorY]]).slice().sort((a, b) => a[0] - b[0]);
  const groundAt = (X) => { let g = Infinity; for (const p of pieces) if (X >= p[0] && X <= p[1]) g = Math.min(g, p[2]); return g; };
  const gAt = (X) => groundAt(Math.max(pieces[0][0], Math.min(pieces[pieces.length - 1][1], X)));
  const top = Math.min(...pieces.map(p => p[2]));
  const glow = (X, Y, rr, col) => glows.push([X, Y, rr, col]);
  const jag = (n, amp) => { const v = []; for (let i = 0; i < n; i++) v.push((r() - 0.5) * amp); return v; };
  const rockBlob = (X, Y, s, cols, seed) => { const rr = rng(seed), pts = []; for (let k = 0; k < 7; k++) { const a = k / 7 * TAU + rr() * 0.4; pts.push([X + Math.cos(a) * s * (0.8 + rr() * 0.3), Y + Math.sin(a) * s * (0.55 + rr() * 0.2)]); } P(x, pts, cols[1]); P(x, [pts[4], pts[5], pts[6], [X, Y]], cols[0]); P(x, [pts[0], pts[1], [X, Y]], cols[2]); return pts; };
  const iceCrystal = (X, Y, s, col = '#7ad8f4', hi = '#e0faff', dark = '#3a8ab8') => {
    for (const [dx, a, l] of [[0, -1.57, 1.8], [-s * 0.45, -2.15, 1.2], [s * 0.45, -0.95, 1.3], [-s * 0.2, -1.85, 0.9]]) {
      const tx = X + dx + Math.cos(a) * s * l, ty = Y + Math.sin(a) * s * l, w = s * 0.32, nx = -Math.sin(a) * w, ny = Math.cos(a) * w;
      P(x, [[X + dx - nx, Y - ny], [tx, ty], [X + dx + nx, Y + ny]], col); P(x, [[X + dx, Y], [tx, ty], [X + dx + nx, Y + ny]], dark); L(x, [[X + dx - nx * 0.4, Y - ny * 0.4], [lerp(X + dx, tx, 0.7), lerp(Y, ty, 0.7)]], hi, 0.6);
    }
  };
  const pineWind = (X, base, h, snow) => {   // a scraggly pine bent by the wind (blowing to the right)
    const trunk = [[X, base + 2], [X + h * 0.04, base - h * 0.4], [X + h * 0.12, base - h * 0.8], [X + h * 0.2, base - h]];
    limb(x, trunk, 2.6, 1, '#2a2018');
    for (let k = 0; k < 6; k++) {
      const t = 0.3 + k * 0.12, p = lp(trunk[1], trunk[3], (t - 0.3) / 0.7), l = h * (0.34 - k * 0.04);
      if (k % 3 !== 1) P(x, [[p[0] - 1, p[1] - 1], [p[0] + l, p[1] + 2 + l * 0.1], [p[0] + l * 0.6, p[1] + 3], [p[0], p[1] + 3]], '#24382e');
      if (k % 2) P(x, [[p[0], p[1]], [p[0] - l * 0.35, p[1] + 3], [p[0] + 1, p[1] + 2.5]], '#1c2c24');
      if (snow) R(x, p[0], p[1] - 0.6, l * 0.7, 1, snow);
    }
  };
  const deadGrass = (X, Y) => { for (let k = 0; k < 4; k++) L(x, [[X + k * 1.4, Y + 0.5], [X + k * 1.4 + 1.5 + r(), Y - 2.5 - r() * 2.5]], k % 2 ? '#a8a084' : '#c8c2a4', 0.8); };
  const cairn = (X, Y) => { let y = Y; for (const [w, h] of [[10, 3.5], [8, 3], [6, 3], [3.5, 2.5]]) { E(x, X + (r() - 0.5), y - h / 2, w / 2, h / 2, '#5a6678'); E(x, X - w * 0.12, y - h * 0.7, w * 0.35, h * 0.25, '#8a98aa'); y -= h - 0.3; } R(x, X - 2, y + 0.6, 3, 1, '#e8f0f8'); };
  const skullAt = (X, Y, s, eyes) => { E(x, X, Y, 6 * s, 5 * s, K.bone); E(x, X + 2 * s, Y + 4 * s, 4.5 * s, 3 * s, K.bone); E(x, X - 1 * s, Y - 2 * s, 4 * s, 2 * s, '#f4eedc'); for (const k of [-1, 1]) { E(x, X + 1 * s + k * 2.4 * s, Y + 0.4 * s, 1.5 * s, 1.7 * s, '#14141c'); if (eyes) { R(x, X + 1 * s + k * 2.4 * s - 0.5, Y, 1, 1, eyes); } } for (let k = -1; k <= 1; k++) R(x, X + 2 * s + k * 1.5 * s - 0.4, Y + 6 * s, 1 * s, 1.6 * s, '#f4eedc'); P(x, [[X + 5 * s, Y + 5 * s], [X + 6 * s, Y + 1 * s], [X + 7 * s, Y + 6 * s]], '#f4eedc'); };
  const bonePile = (X, Y, n, seed) => { const rr = rng(seed); for (let i = 0; i < n; i++) { const bx = X + (rr() - 0.5) * n * 3, by = Y - rr() * 3, a = (rr() - 0.5) * 1.6, l = 3 + rr() * 4; L(x, [[bx - Math.cos(a) * l, by - Math.sin(a) * l], [bx + Math.cos(a) * l, by + Math.sin(a) * l]], rr() < 0.5 ? K.bone : K.boneS, 1.4); C(x, bx - Math.cos(a) * l, by - Math.sin(a) * l, 1, K.bone); C(x, bx + Math.cos(a) * l, by + Math.sin(a) * l, 1, K.bone); } };

  // ================= behind the ground =================
  // climb4: the cavern's carved back wall
  if (id === 'climb4' || id === 'climb4_ruin') {
    const cy = M.ceilY;
    R(x, 0, 0, M.w, M.h, '#0e141e');
    for (let i = 0; i < 160; i++) { const X = r() * M.w, Y = cy + r() * (M.floorY - cy), s = 4 + r() * 16; E(x, X, Y, s * 1.4, s, r() < 0.5 ? '#121a26' : '#0b1018', r()); }
    // great carved columns along the back, with yeti faces near the top
    for (const X of [70, 190, 310, 430]) {
      if (ruin && X === 310) { R(x, X - 12, 200, 24, 70, '#182232'); P(x, [[X - 12, 200], [X - 4, 192], [X + 4, 198], [X + 12, 190], [X + 12, 200]], '#182232'); continue; }
      R(x, X - 12, cy, 24, M.floorY - cy, '#182232'); R(x, X - 12, cy, 5, M.floorY - cy, '#22304a'); R(x, X + 8, cy, 4, M.floorY - cy, '#101824');
      for (let k = 0; k < 6; k++) R(x, X - 12, cy + 30 + k * 30, 24, 1.5, '#0b1018');
      E(x, X, cy + 22, 9, 11, '#22304a'); E(x, X + 1, cy + 22, 7, 8, '#2a3a52');      // a carved yeti face
      R(x, X - 5, cy + 18, 4, 2, '#0b1018'); R(x, X + 2, cy + 18, 4, 2, '#0b1018'); R(x, X - 4, cy + 26, 9, 2, '#0b1018'); P(x, [[X - 3, cy + 27], [X - 2, cy + 31], [X - 1, cy + 27]], '#c8d0dc'); P(x, [[X + 2, cy + 27], [X + 3, cy + 31], [X + 4, cy + 27]], '#c8d0dc');
      R(x, X - 5, cy + 18, 1, 1, '#5af0ff'); R(x, X + 5, cy + 18, 1, 1, '#5af0ff');
    }
    // the throne's alcove: a carved arch with ice
    x.strokeStyle = '#1e2a3c'; x.lineWidth = 10; x.beginPath(); x.arc(566, 170, 56, Math.PI, TAU); x.stroke();
    x.strokeStyle = '#2a3a52'; x.lineWidth = 2; x.beginPath(); x.arc(566, 170, 61, Math.PI, TAU); x.stroke();
    R(x, 505, 170, 10, 100, '#1e2a3c'); R(x, 617, 170, 10, 100, '#1e2a3c');
    P(x, [[515, 170], [617, 170], [617, 270], [515, 270]], '#0a0f17');
    E(x, 566, 170, 51, 51, '#0a0f17');
    for (let k = 0; k < 9; k++) { const a = Math.PI + (k + 0.5) / 9 * Math.PI; P(x, [[566 + Math.cos(a) * 52 - 2, 170 + Math.sin(a) * 52], [566 + Math.cos(a) * 44, 170 + Math.sin(a) * 44 + 5], [566 + Math.cos(a) * 52 + 2, 170 + Math.sin(a) * 52]], '#7ad8f4'); }
    glow(566, 150, 70, '#5ad0ff');
    // claw marks scratched into the wall
    for (const [X, Y] of [[130, 150], [250, 120], [370, 170], [470, 110]]) for (let k = 0; k < 4; k++) L(x, [[X + k * 4, Y], [X + k * 4 + 8, Y + 24]], '#060a10', 1.4);
    // ice veins in the wall
    for (let i = 0; i < 14; i++) { const X = 20 + r() * 600, Y = cy + 30 + r() * 150; if (X > 500) continue; iceCrystal(X, Y, 3 + r() * 3); glow(X, Y - 3, 16, '#5ad0ff'); }
    if (ruin) {   // shafts of light through the broken ceiling
      for (const [X, w] of [[200, 28], [395, 34], [92, 18]]) { wash(x, 0.22, () => P(x, [[X - w / 2, cy - 10], [X + w / 2, cy - 10], [X + w / 2 + 40, M.floorY], [X - w / 2 + 40, M.floorY]], '#d8e8ff')); wash(x, 0.18, () => P(x, [[X - w / 4, cy - 10], [X + w / 4, cy - 10], [X + w / 4 + 40, M.floorY], [X - w / 4 + 40, M.floorY]], '#ffffff')); glow(X + 20, M.floorY - 30, 50, '#dce8ff'); }
    }
  }
  // the summit: the volcano's flank rising on the right, with the gate into Glamrax's lair
  if (id === 'peak') {
    const G = 309, gx0 = 1340, gx1 = 1484, gTop = G - 150, mid = (gx0 + gx1) / 2;
    const wall = [[1268, G], [1276, 270], [1262, 230], [1284, 190], [1272, 150], [1296, 110], [1290, 70], [1312, 30], [1306, 0], [M.w, 0], [M.w, G]];
    P(x, wall, '#1a1418');
    clip(x, () => { x.beginPath(); x.moveTo(wall[0][0], wall[0][1]); for (const p of wall) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      for (let i = 0; i < 70; i++) { const X = 1260 + r() * 240, Y = r() * G; rockBlob(X, Y, 6 + r() * 12, ['#100c10', '#1e171c', '#2c2228'], i + 900); }
      for (let i = 0; i < 12; i++) { let X = 1270 + r() * 220, Y = r() * 200; const pts = [[X, Y]]; for (let k = 0; k < 6; k++) { X += (r() - 0.5) * 14; Y += 6 + r() * 10; pts.push([X, Y]); } L(x, pts, '#8a2a12', 2); L(x, pts, '#ffb03a', 0.8); glow(pts[3][0], pts[3][1], 18, '#ff6a2a'); }
      for (let i = 0; i < 6; i++) { const X = 1290 + r() * 200, Y = 20 + r() * 100; P(x, [[X - 12, Y], [X + 14, Y - 2], [X + 10, Y + 3], [X - 10, Y + 4]], '#e4ecf4'); }   // snow caught on ledges
    });
    // the gate: a jagged maw glowing from inside
    const arch = []; for (let i = 0; i <= 24; i++) { const t = i / 24, a = Math.PI + t * Math.PI, rx = (gx1 - gx0) / 2, ry = G - gTop; arch.push([mid + Math.cos(a) * rx + (i % 2 ? 3 : -2) * Math.sin(t * Math.PI), G + Math.sin(a) * ry + (i % 2 ? 6 : 0) * Math.sin(t * Math.PI)]); }
    P(x, [[gx0 - 16, G], ...arch.map(p => [mid + (p[0] - mid) * 1.14, G + (p[1] - G) * 1.1]), [gx1 + 16, G]], '#2c2228');   // a carved frame round the opening
    for (let i = 0; i < 12; i++) { const t = (i + 0.5) / 12, a = Math.PI + t * Math.PI, X = mid + Math.cos(a) * (gx1 - gx0) / 2 * 1.08, Y = G + Math.sin(a) * (G - gTop) * 1.05; R(x, X - 2, Y - 2, 4, 4, '#3a2e34'); }
    const inside = x.createRadialGradient(mid, G - 10, 6, mid, G - 40, 150);
    inside.addColorStop(0, '#ffe08a'); inside.addColorStop(0.18, '#ff9a2a'); inside.addColorStop(0.45, '#c8361a'); inside.addColorStop(0.8, '#5a1010'); inside.addColorStop(1, '#2a0808');
    x.fillStyle = inside; x.beginPath(); x.moveTo(arch[0][0], arch[0][1]); for (const p of arch) x.lineTo(p[0], p[1]); x.closePath(); x.fill();
    for (const [X, w, h] of [[gx0 + 22, 10, 70], [gx1 - 26, 12, 84], [gx0 + 40, 6, 40], [gx1 - 44, 7, 50]]) { P(x, [[X - w, G], [X - w * 0.7, G - h], [X + w * 0.6, G - h - 4], [X + w, G]], '#6a1a10'); }   // pillars deep inside, black against the fire
    P(x, [[gx0 + 30, G], [mid - 10, G - 14], [mid + 14, G - 14], [gx1 - 30, G]], '#4a120c');   // the path leading in
    for (let k = 0; k < 4; k++) L(x, [[gx0 + 20 + k * 30, G - 40 - k * 10], [gx0 + 34 + k * 30, G - 50 - k * 10]], '#ffe08a', 1);   // heat shimmer
    // fangs of basalt round the mouth
    for (let i = 1; i < 24; i += 2) { const p = arch[i], q = [mid + (p[0] - mid) * 0.86, G + (p[1] - G) * 0.86]; const t = i / 24; if (t < 0.12 || t > 0.88) continue; P(x, [[p[0] - 5, p[1]], [q[0], q[1]], [p[0] + 5, p[1]]], '#1a1418'); L(x, [[p[0] - 3, p[1]], [lerp(p[0], q[0], 0.7) - 1, lerp(p[1], q[1], 0.7)]], '#ff7a2a', 0.8); }
    glow(mid, G - 60, 130, '#ff4a1a'); glow(mid, G - 20, 80, '#ffb03a'); glow(mid, G - 110, 70, '#ff6a2a');
    // Glamrax's sigil carved above: a dragon's head with spread wings, burning
    // two great horns of basalt curling over the gate
    for (const s0 of [-1, 1]) { const b0 = s0 < 0 ? gx0 - 26 : gx1 + 2; const pts = curl(b0 + 12, G, -Math.PI / 2 - s0 * 0.1, 230, s0 * 1.25, 14); limb(x, pts, 30, 3, '#3a2e36'); L(x, pts.slice(2, -2).map(p => [p[0] - s0 * 6, p[1]]), '#56464e', 2); for (let k = 2; k < 12; k += 2) { const p = pts[k]; L(x, [[p[0] - 9, p[1] + 3], [p[0] + 9, p[1] - 1]], '#120e12', 1.4); } L(x, pts.slice(3, 9).map(p => [p[0] + s0 * 5, p[1] + 2]), '#ff6a2a', 1); }
    const sx = mid, sy = gTop - 56;
    x.save(); x.translate(sx, sy); x.scale(1.4, 1.4); x.translate(-sx, -sy);
    E(x, sx, sy, 34, 32, '#120e12'); E(x, sx, sy, 31, 29, '#1e161c');
    x.strokeStyle = '#ff6a2a'; x.lineWidth = 2; x.beginPath(); x.arc(sx, sy, 28, 0, TAU); x.stroke();
    x.strokeStyle = '#8a2a12'; x.lineWidth = 1; x.beginPath(); x.arc(sx, sy, 31, 0, TAU); x.stroke();
    const sig = (pts, w = 2) => { L(x, pts, '#ff8a2a', w); L(x, pts, '#ffe08a', w * 0.4); };
    sig([[sx - 6, sy + 16], [sx, sy - 4], [sx + 6, sy + 16]]);                                       // body
    sig([[sx, sy - 4], [sx - 10, sy - 14], [sx - 24, sy - 10], [sx - 16, sy - 2], [sx - 24, sy + 4], [sx - 6, sy + 4]]);   // wings
    sig([[sx, sy - 4], [sx + 10, sy - 14], [sx + 24, sy - 10], [sx + 16, sy - 2], [sx + 24, sy + 4], [sx + 6, sy + 4]]);
    sig([[sx, sy - 4], [sx, sy - 16], [sx - 4, sy - 22], [sx, sy - 20], [sx + 4, sy - 22], [sx, sy - 16]]);   // horned head
    sig([[sx, sy + 16], [sx + 4, sy + 22], [sx - 2, sy + 24]], 1.5);                                 // tail
    R(x, sx - 2.5, sy - 18, 1.5, 1.5, '#ffffff'); R(x, sx + 1, sy - 18, 1.5, 1.5, '#ffffff');
    x.restore();
    glow(sx, sy, 70, '#ff5a1a'); glow(sx, sy - 25, 18, '#ffd06a');
    // chains of cooled lava running down beside the gate
    for (const X of [gx0 - 24, gx1 + 10]) { L(x, [[X, gTop - 30], [X + 3, gTop + 30], [X - 2, G - 30], [X + 2, G]], '#8a2a12', 3); L(x, [[X, gTop - 30], [X + 3, gTop + 30], [X - 2, G - 30], [X + 2, G]], '#ff9a3a', 1); glow(X, gTop + 40, 26, '#ff6a2a'); }
  }
  // climb2: the cliff with the cave mouth at the right end
  if (M.caveMouth) {
    const X0 = M.caveMouth, G = gAt(X0), oy = G - 92;
    const cliff = [[X0 - 14, G], [X0 - 20, G - 60], [X0 - 8, G - 120], [X0 - 22, G - 180], [X0 - 6, G - 240], [X0 - 16, 0], [M.w, 0], [M.w, G]];
    P(x, cliff, T.rock[1]);
    clip(x, () => { x.beginPath(); x.moveTo(cliff[0][0], cliff[0][1]); for (const p of cliff) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      for (let i = 0; i < 40; i++) rockBlob(X0 - 20 + r() * 160, r() * G, 8 + r() * 14, [T.rock[0], T.rock[1], T.rock[2]], i + 500);
      for (let k = 0; k < 14; k++) { const Y = 10 + k * 22; L(x, [[X0 - 30, Y], [M.w, Y + (r() - 0.5) * 10]], T.strata, 1); }
      for (let k = 0; k < 9; k++) { const Y = 14 + k * 32 + r() * 10, X = X0 - 10 + r() * 120; if (Y > oy - 14) continue; R(x, X - 16, Y + 2, 36, 4, T.rock[3]); S(x, [[X - 18, Y + 2], [X - 6, Y - 2], [X + 14, Y - 3], [X + 20, Y + 2], [X + 8, Y + 4]], '#eef4fa'); }   // snowy ledges
    });
    // the mouth: dark inside, icicles hanging off the arch
    const mx0 = X0 + 12, mx1 = M.w + 4, my = oy;
    const mouth = [[mx0, G], [mx0 + 2, G - 40], [mx0 + 14, my + 20], [mx0 + 34, my + 4], [mx0 + 60, my - 2], [mx1, my - 6], [mx1, G]];
    P(x, mouth.map(p => [p[0] - 6, p[1] - (p[1] < G ? 6 : 0)]), T.rock[3]); P(x, mouth.map(p => [p[0] - 3, p[1] - (p[1] < G ? 3 : 0)]), T.rock[2]); S(x, [[mx0 - 8, my - 2], [mx0 + 30, my - 16], [mx1, my - 20], [mx1, my - 8], [mx0 + 20, my - 2]], '#eef4fa');
    const g = x.createLinearGradient(mx0, 0, mx1, 0); g.addColorStop(0, '#141c2a'); g.addColorStop(0.35, '#080b12'); g.addColorStop(1, '#030407');
    P(x, mouth, '#080b12'); x.fillStyle = g; x.beginPath(); x.moveTo(mouth[0][0], mouth[0][1]); for (const p of mouth) x.lineTo(p[0], p[1]); x.closePath(); x.fill();
    for (let i = 0; i < 11; i++) { const t = (i + r() * 0.6) / 11, X = lerp(mx0 + 6, mx1 - 4, t), Y = t < 0.3 ? lerp(G - 40, my + 4, t / 0.3) : lerp(my + 4, my - 6, (t - 0.3) / 0.7), l = 3 + r() * r() * 22; P(x, [[X - 2.5, Y - 2], [X + 2.5, Y - 2], [X, Y + l]], '#cdeefa'); L(x, [[X - 1, Y], [X - 0.3, Y + l * 0.7]], '#ffffff', 0.6); }
    for (let i = 0; i < 6; i++) { const X = mx0 + 30 + r() * 100; iceCrystal(X, G, 3 + r() * 2, '#3a6a8a', '#8ac8e0', '#24405a'); }
    glow(mx0 + 60, G - 30, 40, '#4a8ac8');
  }
  // windswept pines and boulders behind the ground (climb1, climb2)
  if (theme === 'climb' || theme === 'snow') {
    for (let i = 0; i < M.w / (theme === 'snow' ? 60 : 70); i++) {
      const X = 40 + r() * (M.w - 80); if (M.caveMouth && X > M.caveMouth - 40) continue;
      const b = gAt(X);
      if (theme === 'snow') { const h = 26 + r() * 30, sunk = r() < 0.4 ? h * 0.45 : 6; pine(x, X, b + sunk, h, '#24382e', '#eef4fa', 0.6); if (sunk > 6) E(x, X, b - 1, h * 0.4, 4, '#eef4fa'); }
      else if (r() < 0.65) pineWind(X, b, 24 + r() * 26, null);
      else rockBlob(X, b - 3, 8 + r() * 8, ['#36404e', '#4a5566', '#6a788c'], i + 50);
    }
  }

  // ================= the ground =================
  const prof = [];
  for (const p of pieces) { prof.push([p[0], p[2]]); prof.push([p[1], p[2]]); }
  const groundPath = () => {
    x.beginPath(); x.moveTo(pieces[0][0], M.h + 10);
    x.lineTo(pieces[0][0], pieces[0][2] + 30); x.lineTo(pieces[0][0] - 3, pieces[0][2] + 10);
    for (let i = 0; i < prof.length; i++) {
      const [X, Y] = prof[i];
      if (i % 2 === 0 && i > 0) { const [px, py] = prof[i - 1]; const up = Y < py; for (let k = 1; k < 4; k++) x.lineTo(px + (up ? -1 : 1) * (0.5 + r() * 2), py + (Y - py) * k / 4); }
      x.lineTo(X, Y);
    }
    const last = pieces[pieces.length - 1]; x.lineTo(last[1] + 3, last[2] + 10); x.lineTo(last[1], last[2] + 30);
    x.lineTo(last[1], M.h + 10); x.closePath();
  };
  groundPath();
  const gg = x.createLinearGradient(0, top, 0, M.h); gg.addColorStop(0, T.rock[2]); gg.addColorStop(0.35, T.rock[1]); gg.addColorStop(1, T.rock[0]);
  x.fillStyle = gg; x.fill();
  x.save(); groundPath(); x.clip();
  // strata bands, blocky cracks, buried stones
  for (let i = 0; i < M.h / 13; i++) { const Y = top + i * 13 + r() * 6; let X = r() * 60; while (X < M.w) { const l = 30 + r() * 90; if (Y > gAt(X) + 16) wash(x, 0.55, () => L(x, [[X, Y + (r() - 0.5) * 3], [X + l * 0.5, Y + (r() - 0.5) * 4], [X + l, Y + (r() - 0.5) * 3]], i % 2 ? T.strata : T.rock[0], i % 2 ? 1 : 1.6)); X += l + 10 + r() * 40; } }
  // a lighter weathered band under every top edge
  for (const p of pieces) {
    const [x0, x1, y] = p, pts = [[x0, y]], pts2 = [[x0, y]];
    for (let X = x0; X <= x1; X += 5) { pts.push([X, y + 10 + r() * 7]); pts2.push([X, y + 4 + r() * 3]); }
    pts.push([x1, y + 12]); pts.push([x1, y]); pts2.push([x1, y + 4]); pts2.push([x1, y]);
    if (theme === 'snow') {   // thick packed snow instead of bare rock
      const sp = [[x0, y]]; for (let X = x0; X <= x1; X += 4) sp.push([X, y + 9 + r() * 6]); sp.push([x1, y + 10]); sp.push([x1, y]);
      P(x, pts.map(q => [q[0], q[1] + 4]), T.rock[2]); P(x, sp, '#b4c6dc'); P(x, sp.map(q => [q[0], y + (q[1] - y) * 0.75]), '#dce8f4');
      for (let X = x0 + 3; X < x1 - 3; X += 8 + r() * 12) L(x, [[X, y + 5], [X + 6 + r() * 6, y + 6]], '#c8d6e8', 1);
      continue;
    }
    P(x, pts, T.rock[2]); P(x, pts2, T.rock[3]);
    for (let X = x0 + 3; X < x1 - 3; X += 6 + r() * 10) L(x, [[X, y + 3], [X + (r() - 0.5) * 3, y + 9 + r() * 6]], T.rock[1], 1);
  }
  for (let i = 0; i < M.w / 14; i++) { const X = r() * M.w, Y = gAt(X) + 6 + r() * 120; rockBlob(X, Y, 3 + r() * 6, [T.rock[0], T.rock[1], T.rock[3]], i + 300); }
  for (let i = 0; i < M.w / 40; i++) { let X = r() * M.w, Y = gAt(X) + 1; const pts = [[X, Y]]; for (let k = 0; k < 5; k++) { X += (r() - 0.5) * 8; Y += 3 + r() * 7; pts.push([X, Y]); } L(x, pts, T.crack, 1); }
  if (theme === 'cave') for (let i = 0; i < M.w / 50; i++) { const X = r() * M.w, Y = gAt(X) + 10 + r() * 60; iceCrystal(X, Y, 2 + r() * 2, '#2a5a80', '#7ab8e0', '#1a3a5a'); }
  if (theme === 'peak') for (let i = 0; i < M.w / 60; i++) { let X = r() * M.w, Y = gAt(X) + 3; const pts = [[X, Y]]; for (let k = 0; k < 6; k++) { X += (r() - 0.5) * 10; Y += 3 + r() * 8; pts.push([X, Y]); } L(x, pts, '#8a2a12', 1.8); L(x, pts, '#ffb03a', 0.7); glow(pts[2][0], pts[2][1], 14, '#ff6a2a'); }
  if (theme === 'climb' || theme === 'snow') for (let i = 0; i < M.w / 200; i++) { const X = r() * M.w, Y = gAt(X) + 30 + r() * 60; L(x, [[X, Y], [X + 6, Y + 1]], K.boneS, 1.2); }
  // the step faces: lit cliff faces with cracks
  for (let i = 0; i < pieces.length - 1; i++) {
    const X = pieces[i][1], ya = pieces[i][2], yb = pieces[i + 1][2];
    if (yb < ya) { R(x, X, yb, 6, ya - yb + 6, T.rock[2]); R(x, X, yb, 2.5, ya - yb + 4, T.rock[3]); for (let Y = yb + 3; Y < ya + 2; Y += 5 + r() * 6) { L(x, [[X, Y], [X + 4 + r() * 4, Y + 1]], T.crack, 1); L(x, [[X + 6, Y - 2], [X + 6, Y + 4]], T.rock[1], 1); if (theme === 'snow') R(x, X, Y - 1.5, 3 + r() * 3, 1.2, '#e8f0f8'); } }
    else if (yb > ya) { R(x, X - 4, ya, 4, yb - ya + 3, T.rock[0]); }
  }
  x.restore();
  // a crust on every top edge
  for (const p of pieces) {
    const [x0, x1, y] = p, len = x1 - x0;
    if (theme === 'climb') {
      R(x, x0, y, len, 2, T.top[0]); R(x, x0, y, len, 0.8, T.top[1]);
      for (let X = x0 + 2; X < x1 - 2; X += 2 + r() * 5) R(x, X, y + 1.5, 1 + r() * 2, 1, r() < 0.5 ? T.top[0] : T.rock[3]);
    } else if (theme === 'snow') {
      const pts = [[x0 - 1, y]]; for (let X = x0; X <= x1; X += 4) pts.push([X, y + 4 + r() * 3]); pts.push([x1 + 1, y + 3]); pts.push([x1 + 1, y]);
      P(x, pts, T.top[1]); R(x, x0, y + 2.5, len, 1, '#dce6f2'); R(x, x0, y, len, 1, '#ffffff');
      // a cornice of snow curling over the edge of each step
      P(x, [[x0 - 2, y], [x0 + 6, y], [x0 + 2, y + 10 + r() * 6], [x0 - 2, y + 4]], T.top[1]); L(x, [[x0 - 1, y + 3], [x0 + 1, y + 9]], T.top[0], 1);
    } else if (theme === 'cave') {
      R(x, x0, y, len, 3, '#2a5a80'); R(x, x0, y, len, 2, T.top[0]); R(x, x0, y, len, 0.8, T.top[1]);
      for (let X = x0 + 2; X < x1 - 2; X += 4 + r() * 8) P(x, [[X, y + 1.5], [X + 1, y + 4 + r() * 3], [X + 2, y + 1.5]], T.top[0]);   // ice drips off the lip
    } else if (theme === 'peak') {
      R(x, x0, y, len, 2, T.top[0]); R(x, x0, y, len, 0.8, T.top[1]);
    }
  }
  // ================= on the ground =================
  for (const p of pieces) {
    const [x0, x1, y] = p, len = x1 - x0;
    for (let i = 0; i < len / 26; i++) {
      const X = x0 + 6 + r() * (len - 12), k = r();
      if (M.caveMouth && X > M.caveMouth + 10) continue;
      if ((id === 'climb4' || id === 'climb4_ruin') && X > 505) continue;
      if (theme === 'climb') {
        if (k < 0.35) deadGrass(X, y);
        else if (k < 0.5) { E(x, X, y - 1.5, 3 + r() * 3, 2 + r() * 1.5, '#5a6678'); R(x, X - 2, y - 3, 3, 1, '#c8d8ea'); }
        else if (k < 0.55) cairn(X, y);
      } else if (theme === 'snow') {
        if (k < 0.25) { E(x, X, y + 0.5, 6 + r() * 10, 2.2, '#ffffff'); }      // a drift
        else if (k < 0.33) { E(x, X, y - 1, 3, 2, '#4a5668'); E(x, X - 0.5, y - 2.2, 2.6, 1, '#ffffff'); }
      } else if (theme === 'cave') {
        if (k < 0.2) { E(x, X, y + 0.6, 6 + r() * 6, 1.2, '#4a90c0'); R(x, X - 3, y, 4, 0.8, '#c8f0ff'); glow(X, y, 10, '#5ab0e0'); }   // a frozen puddle
        else if (k < 0.32) { iceCrystal(X, y, 2.5 + r() * 2.5); glow(X, y - 5, 14, '#5ad0ff'); }
        else if (k < 0.4) bonePile(X, y, 3, i + X | 0);
        else if (k < 0.48) { E(x, X, y - 2, 4, 3, T.rock[2]); R(x, X - 2, y - 4.5, 3, 1, T.top[1]); }
      } else if (theme === 'peak') {
        if (k < 0.18) { E(x, X, y + 0.5, 5 + r() * 8, 1.6, '#e4ecf4'); }       // a snow patch
        else if (k < 0.3 && X < 1250) {   // a steam vent
          E(x, X, y, 3, 1.2, '#2a0c08'); R(x, X - 1, y - 0.5, 2, 1, '#ff8a2a'); glow(X, y, 12, '#ff6a2a');
          for (let s = 0; s < 4; s++) C(x, X + s * 2.5 + r() * 2, y - 5 - s * 6, 2.5 + s * 1.2, s % 2 ? '#c8c8d0' : '#e4e4ea');
        }
        else if (k < 0.42) { const s = 3 + r() * 5; P(x, [[X - s, y], [X - s * 0.4, y - s * 1.2], [X + s * 0.5, y - s * 0.9], [X + s, y]], '#221a22'); }
      }
    }
  }
  // ================= the cave's ceiling (climb3) and the throne room's ceiling (climb4) =================
  if (theme === 'cave') {
    const flat = !M.floor;
    const ceilAt = flat ? () => M.ceilY : (X) => gAt(X) - M.ceil;
    const cpts = [[0, 0], [M.w, 0]];
    for (let X = M.w; X >= 0; X -= 3) { let y = ceilAt(X); y -= 2 + Math.abs(Math.sin(X * 0.13) * 3) + r() * 2; if (flat && ruin && ((X > 180 && X < 222) || (X > 376 && X < 420) || (X > 80 && X < 102))) y = -10; cpts.push([X, y]); }
    P(x, cpts, T.rock[1]);
    clip(x, () => { x.beginPath(); x.moveTo(cpts[0][0], cpts[0][1]); for (const p of cpts) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      const cg = x.createLinearGradient(0, 0, 0, flat ? M.ceilY : M.h); cg.addColorStop(0, T.rock[0]); cg.addColorStop(1, T.rock[2]); x.fillStyle = cg; x.fillRect(0, 0, M.w, M.h);
      for (let i = 0; i < M.w / 10; i++) rockBlob(r() * M.w, r() * (flat ? M.ceilY : M.h * 0.6), 4 + r() * 10, [T.rock[0], T.rock[1], T.rock[2]], i + 700);
      for (let i = 0; i < M.w / 40; i++) { const X = r() * M.w, Y = ceilAt(X) - 4 - r() * 20; iceCrystal(X, Y, 2 + r() * 2, '#2a5a80', '#7ab8e0', '#1a3a5a'); }
      // a lighter, icier band along the underside
      { const bp = []; for (let X = 0; X <= M.w; X += 4) bp.push([X, ceilAt(X) - 12 - r() * 8]); for (let X = M.w; X >= 0; X -= 4) bp.push([X, ceilAt(X) + 2]); P(x, bp, T.rock[2]); const bp2 = []; for (let X = 0; X <= M.w; X += 4) bp2.push([X, ceilAt(X) - 5 - r() * 3]); for (let X = M.w; X >= 0; X -= 4) bp2.push([X, ceilAt(X) + 2]); P(x, bp2, '#2a4060'); }
      for (let i = 0; i < M.w / 30; i++) { const X = r() * M.w, Y = ceilAt(X) - 6 - r() * 14; L(x, [[X, Y], [X + 8 + r() * 10, Y + (r() - 0.5) * 3]], '#3a6a98', 1); }
      if (ruin) for (const [a, b] of [[180, 222], [376, 420], [80, 102]]) for (const X of [a, b]) R(x, X - 1, 0, 2, M.ceilY, T.rock[3]);   // freshly broken, lit edges round the holes
    });
    // the ceiling's underside: an icy rim, stalactites and icicles
    for (let X = 0; X < M.w; X += 2) { const y = ceilAt(X) - 2; if (flat && ruin && ((X > 180 && X < 222) || (X > 376 && X < 420) || (X > 80 && X < 102))) continue; R(x, X, y, 2, 1.2, '#2a4a6a'); }
    const n = flat ? 0 : M.w / 14;
    for (let i = 0; i < n; i++) {
      const X = r() * M.w, y = ceilAt(X) - 3, big = r() < 0.45, l = big ? 14 + r() * 20 : 5 + r() * 10, w = big ? 4 + r() * 4 : 1.5 + r();
      if (big) { P(x, [[X - w, y], [X + w, y], [X + w * 0.3, y + l * 0.7], [X, y + l]], '#2a3a52'); P(x, [[X, y], [X + w, y], [X + w * 0.3, y + l * 0.7], [X, y + l]], T.rock[2]); P(x, [[X - w * 0.7, y], [X - w * 0.2, y], [X - 0.2, y + l * 0.85]], '#5aa0cc'); L(x, [[X - w * 0.5, y + 1], [X - 0.3, y + l * 0.8]], '#c8f0ff', 0.7); if (r() < 0.3) glow(X, y + l * 0.6, 12, '#5ad0ff'); }
      else { P(x, [[X - w, y], [X + w, y], [X, y + l]], '#a8e4f6'); L(x, [[X - w * 0.3, y], [X - 0.2, y + l * 0.7]], '#ffffff', 0.5); if (r() < 0.3) { R(x, X - 0.5, y + l + 3, 1, 1.6, '#a8e4f6'); } }
    }
    if (flat) {   // the throne room: big stalactites hanging from the ceiling (the hero gets flung into them)
      for (const [X, l, w] of [[96, 46, 9], [164, 32, 7], [236, 54, 10], [318, 36, 8], [392, 50, 9], [462, 34, 7]]) {
        if (ruin && X !== 164 && X !== 462 && X !== 318) continue;
        const y = M.ceilY - 3;
        P(x, [[X - w, y], [X + w, y], [X + w * 0.6, y + l * 0.4], [X + w * 0.3, y + l * 0.75], [X, y + l], [X - w * 0.35, y + l * 0.6], [X - w * 0.7, y + l * 0.3]], '#2a3a52');
        P(x, [[X, y], [X + w, y], [X + w * 0.6, y + l * 0.4], [X + w * 0.3, y + l * 0.75], [X, y + l]], '#1a2636');
        P(x, [[X - w * 0.6, y + 2], [X - w * 0.1, y + 2], [X - 0.5, y + l * 0.85], [X - w * 0.35, y + l * 0.5]], '#7ad0f0');
        L(x, [[X - w * 0.45, y + 4], [X - w * 0.15, y + l * 0.55]], '#e0faff', 0.8);
        glow(X, y + l * 0.6, 14, '#5ad0ff');
      }
      // the stone sides of the cavern
      for (const [a, b] of [[0, 20], [M.w - 20, M.w]]) { const sp = [[a, 0], [b, 0]]; for (let Y = 0; Y <= M.floorY + 30; Y += 10) sp.push([a === 0 ? b + (r() - 0.3) * 6 : a - (r() - 0.3) * 6, Y]); sp.push([a === 0 ? 0 : M.w, M.floorY + 30]); if (a !== 0) { sp.reverse(); } P(x, a === 0 ? [[0, 0], ...sp.slice(1)] : [[M.w, 0], ...sp], T.rock[1]); }
    }
  }
  // climb3: the strange glow at the back of the cave where the way to the throne opens
  if (M.glowEnd) {
    const G = gAt(1740);
    for (const [X, Y, s, up] of [[1696, G, 9, 1], [1712, G, 5, 1], [1724, G, 7, 1], [1768, G, 6, 1], [1780, G, 11, 1], [1706, G - M.ceil - 4, 8, -1], [1736, G - M.ceil - 4, 5, -1], [1766, G - M.ceil - 4, 9, -1]]) {
      x.save(); x.translate(X, Y); x.scale(1, up); iceCrystal(0, 0, s, '#a88aff', '#f0e4ff', '#5a3ab8'); x.restore();
      glow(X, Y - up * s, 20, '#b48aff');
    }
    for (let i = 0; i < 30; i++) { const X = 1690 + r() * 100, Y = G - 10 - r() * (M.ceil - 20), b = r() < 0.3; R(x, X, Y, b ? 2 : 1, b ? 2 : 1, r() < 0.5 ? '#d0b8ff' : '#8ad8ff'); }
    for (let k = 0; k < 3; k++) { x.strokeStyle = k % 2 ? '#7a5ae0' : '#a88aff'; x.lineWidth = 1; x.beginPath(); x.ellipse(1740, G - 0.5, 30 - k * 9, 2.5 - k * 0.6, 0, 0, TAU); x.stroke(); }   // a faint ring of light on the floor
    glow(1740, G - 70, 90, '#7a5aff'); glow(1740, G - 40, 60, '#a07aff'); glow(1745, G - 100, 50, '#5ab0ff');
  }
  // climb3: the warning before the throne room: a bone totem topped with a yeti skull
  if (M.bossSign) {
    const X = M.bossSign, G = gAt(X);
    bonePile(X, G, 8, 77);
    for (let k = 0; k < 9; k++) { E(x, X, G - 4 - k * 4, 2.6, 2, k % 2 ? K.bone : K.boneS); }     // a spine of stacked vertebrae
    L(x, [[X - 7, G - 30], [X + 7, G - 28]], K.boneS, 2); C(x, X - 7, G - 30, 1.5, K.bone); C(x, X + 7, G - 28, 1.5, K.bone);
    shaggy(x, [[X - 6, G - 32], [X + 6, G - 32], [X + 5, G - 22], [X - 5, G - 24]], '#d8dce4', 1.5, 3, 5, 1);   // a scrap of white fur
    // the yeti skull: a heavy brow, long fangs, glowing sockets
    const sy = G - 42;
    E(x, X, sy, 9, 8, K.bone); E(x, X + 3, sy + 6, 7, 4, K.bone); P(x, [[X - 8, sy - 3], [X + 10, sy - 4], [X + 9, sy - 1], [X - 8, sy]], K.boneS);
    E(x, X - 2, sy - 5, 5, 2.4, '#f4eedc');
    for (const k of [-1, 1]) { E(x, X + 2 + k * 3.4, sy + 0.5, 2.2, 2.4, '#10141c'); R(x, X + 1.5 + k * 3.4, sy, 1, 1, '#5af0ff'); glow(X + 2 + k * 3.4, sy, 8, '#5af0ff'); }
    for (const k of [0, 6]) P(x, [[X + 1 + k, sy + 8], [X + 2 + k, sy + 14], [X + 3 + k, sy + 8]], '#f4eedc');
    L(x, [[X - 4, sy - 7], [X - 1, sy - 2]], '#6a5a46', 0.8);
  }
  // climb4: piles of bones along the floor, the broken throne after the cave-in
  if (id === 'climb4' || id === 'climb4_ruin') {
    for (const X of [60, 140, 260, 360, 450]) { bonePile(X, M.floorY, 7, X); if (r() < 0.6) skullAt(X + 4, M.floorY - 4, 0.5, null); }
    if (ruin) {
      // rubble mounds over the raised floor pieces, and fallen stalactites
      for (const p of pieces) if (p[2] < M.floorY) {
        const [x0, x1, y] = p;
        P(x, [[x0 - 12, M.floorY], [x0 - 2, y + 2], [x0, y], [x1, y], [x1 + 2, y + 2], [x1 + 12, M.floorY]], T.rock[1]);
        for (let k = 0; k < 14; k++) { const t = r(), X = x0 - 8 + t * (x1 - x0 + 16), edge = Math.min(X - x0 + 10, x1 + 10 - X), Y = edge < 10 ? lerp(M.floorY - 2, y + 4, edge / 10) : y + 5 + r() * 6; rockBlob(X, Y, 3 + r() * 5, [T.rock[1], T.rock[2], T.rock[3]], k + x0); }
        for (let k = 0; k < 3; k++) { const X = x0 + 4 + r() * (x1 - x0 - 8); E(x, X, y - 1.5, 3 + r() * 3, 1.8, T.rock[2]); }
        R(x, x0, y, x1 - x0, 1.5, T.top[0]); R(x, x0, y, x1 - x0, 0.6, T.top[1]);
      }
      for (const [X, a, l, w] of [[236, 0.5, 46, 9], [92, -0.4, 34, 7], [392, 0.35, 40, 8], [300, -0.6, 22, 5]]) {   // fallen stalactites, points buried in the floor
        x.save(); x.translate(X, M.floorY + 4); x.rotate(a);
        P(x, [[-w, -l], [w, -l], [w * 0.6, -l * 0.55], [w * 0.3, -l * 0.2], [0, 0], [-w * 0.35, -l * 0.35], [-w * 0.7, -l * 0.7]], '#2a3a52');
        P(x, [[0, -l], [w, -l], [w * 0.6, -l * 0.55], [w * 0.3, -l * 0.2], [0, 0]], '#1a2636');
        P(x, [[-w * 0.6, -l + 1], [-w * 0.1, -l + 1], [-0.5, -l * 0.15], [-w * 0.35, -l * 0.45]], '#7ad0f0');
        P(x, [[-w - 1, -l], [w + 1, -l], [w - 1, -l - 3], [w * 0.2, -l - 1], [-w * 0.4, -l - 4], [-w + 1, -l - 2]], '#3a4a62');   // the broken-off top
        x.restore(); glow(X, M.floorY - l * 0.5, 14, '#5ad0ff');
      }
      for (let i = 0; i < 26; i++) { const X = 30 + r() * 480, gy = gAt(X); if (gy < M.floorY) continue; rockBlob(X, gy - 1.5, 2 + r() * 3, [T.rock[1], T.rock[2], T.rock[3]], i + 1000); }
      x.drawImage(throne(true), 566 - 50, M.floorY - 110, 100, 110);
    }
  }
  // ================= platforms =================
  for (const [px, py, pw] of M.plats || []) {
    const under = [[px, py], [px + pw, py], [px + pw - 3, py + 6], [px + pw * 0.75, py + 12 + r() * 4], [px + pw * 0.55, py + 18 + r() * 6], [px + pw * 0.35, py + 14 + r() * 4], [px + pw * 0.15, py + 10], [px + 3, py + 5]];
    P(x, under, T.rock[1]);
    clip(x, () => { x.beginPath(); x.moveTo(under[0][0], under[0][1]); for (const p of under) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      R(x, px, py + 2, pw, 4, T.rock[2]); E(x, px + pw * 0.6, py + 16, pw * 0.4, 6, T.rock[0]);
      for (let k = 0; k < 5; k++) L(x, [[px + r() * pw, py + 4 + r() * 6], [px + r() * pw, py + 6 + r() * 8]], T.crack, 0.8);
    });
    if (theme === 'snow') { const pts = [[px - 1, py]]; for (let X = px; X <= px + pw; X += 4) pts.push([X, py + 3 + r() * 2.5]); pts.push([px + pw + 1, py]); P(x, pts, '#f4f8fc'); R(x, px, py, pw, 1, '#ffffff'); P(x, [[px - 3, py], [px + 4, py], [px - 1, py + 7]], '#f4f8fc'); P(x, [[px + pw - 4, py], [px + pw + 3, py], [px + pw + 1, py + 6]], '#f4f8fc'); }
    else if (theme === 'cave') { R(x, px, py, pw, 2, T.top[0]); R(x, px, py, pw, 0.8, T.top[1]); for (let X = px + 4; X < px + pw - 4; X += 6 + r() * 8) P(x, [[X, py + 8], [X + 1, py + 14 + r() * 6], [X + 2, py + 8]], '#a8e4f6'); }
    else { R(x, px, py, pw, 2, T.top[0]); R(x, px, py, pw, 0.8, T.top[1]); for (let k = 0; k < 3; k++) deadGrass(px + 6 + r() * (pw - 12), py); }
  }
  x.restore();
  return { canvas: crisp(c, 60), glows: glows.map(g => [Math.round(g[0] * 2) / 2, Math.round(g[1] * 2) / 2, g[2], g[3]]) };
}

window.CLIMB = { SETS, bakeMobs, bakeYeti, ITEMS, pendantItem, SKY, paintMap };
