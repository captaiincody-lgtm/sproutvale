// Art for the areas beyond the Warlord's Keep (the Godot version only).
// Runs inside a blank Chromium page (see abyss.mjs). Every function here draws with the 2D canvas
// and returns canvases; abyss.mjs saves them as PNGs under godot/art/abyss. All sprites are drawn
// at 2× the game's world units, like the rest of the game's art.
/* eslint-disable no-unused-vars */
'use strict';

const TAU = Math.PI * 2;
const OUT = '#0a0410';

// ------------------------------------------------------------------ helpers
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
// fish-like body along a spine (tail → head) with a half-height profile
function spineBody(x, spine, top, bot, col) {
  const n = spine.length, T = [], B = [];
  for (let i = 0; i < n; i++) {
    const a = spine[Math.max(0, i - 1)], b = spine[Math.min(n - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const d = Math.hypot(dx, dy) || 1; dx /= d; dy /= d;
    T.push([spine[i][0] + dy * top[i], spine[i][1] - dx * top[i]]);
    B.push([spine[i][0] - dy * bot[i], spine[i][1] + dx * bot[i]]);
  }
  smooth(x, T.concat(B.reverse())); x.fillStyle = col; x.fill();
  return { T, B };
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

// ------------------------------------------------------------------ palette
const K = {
  void: '#07030c', ink: '#12061e', deep: '#1c0a2e', purple: '#2e1248', plum: '#46195e', violet: '#6a2a9a', glow: '#c25cff', pink: '#ff6af0',
  blood: '#5a0a18', crimson: '#8a1020', red: '#c0202e', ember: '#ff4a5a', bone: '#c8bca8', boneD: '#8a7e70',
};

// ================================================================== MONSTERS
// Every pose is a list of frames. 88×72 frames have the feet (or the bottom of the body) at 44,66
// unless the set says otherwise (see SETS below).

// ---------------- Abyssal Toad
function toad(pose, f) {
  return frame(88, 72, x => {
    const sk = '#2a1238', sh = '#170a22', hi = '#4a2066', belly = '#5a2a52', wart = '#b01c34';
    let bx = 42, by = 54, rx = 21, ry = 12, rot = 0, legs = 'sit', mouth = 'shut', eye = 'open', puff = 0;
    if (pose === 'idle') { puff = f; }
    if (pose === 'hop') { by = 46; ry = 13; rx = 19; rot = -0.35; legs = 'out'; }
    if (pose === 'slam') { by = 56; rx = 25; ry = 9; legs = 'splay'; eye = 'wide'; }
    if (pose === 'tongue') { mouth = 'open'; rot = -0.12; }
    if (pose === 'hurt') { eye = 'shut'; rx = 22; ry = 11; by = 55; }
    if (pose === 'dead') { eye = 'x'; rx = 24; ry = 8; by = 60; legs = 'splay'; }
    x.save(); x.translate(bx, by); x.rotate(rot); x.translate(-bx, -by);
    // back leg (folded thigh) and front leg
    if (legs === 'sit') { E(x, bx - 13, by + 4, 10, 7, sh); E(x, bx - 13, by + 3, 8, 5.5, sk); R(x, bx - 22, by + 9, 14, 3, sh); R(x, bx + 12, by + 4, 4, 8, sk); R(x, bx + 10, by + 10, 9, 3, sh); }
    if (legs === 'out') { limb(x, [[bx - 12, by + 4], [bx - 22, by + 12], [bx - 30, by + 18]], 8, 4, sh); limb(x, [[bx - 30, by + 18], [bx - 38, by + 20]], 4, 6, sk); limb(x, [[bx + 12, by + 6], [bx + 16, by + 14]], 5, 4, sk); }
    if (legs === 'splay') { limb(x, [[bx - 14, by + 2], [bx - 26, by + 4], [bx - 32, by + 8]], 7, 4, sh); limb(x, [[bx + 14, by + 2], [bx + 24, by + 4], [bx + 30, by + 8]], 7, 4, sh); }
    // body and head
    E(x, bx, by, rx, ry, sk);
    E(x, bx + 14, by - 5, 11, 9, sk);
    clip(x, () => { x.beginPath(); x.ellipse(bx, by, rx, ry, 0, 0, TAU); x.ellipse(bx + 14, by - 5, 11, 9, 0, 0, TAU); }, () => {
      E(x, bx - 2, by - ry + 3, rx - 4, 5, hi);
      E(x, bx + 2, by + ry - 1, rx, 6, belly);
      E(x, bx - 6, by + ry + 2, rx, 6, sh);
      for (const [wx, wy] of [[-12, -6], [-4, -9], [6, -4], [-14, 0], [2, -1], [-8, 3]]) { C(x, bx + wx, by + wy, 2, wart); C(x, bx + wx - 0.5, by + wy - 0.5, 0.8, K.ember); }
    });
    if (puff) { E(x, bx + 16, by + 4, 8, 6, '#7a3a72'); E(x, bx + 15, by + 2, 5, 3, '#9a5a8a'); }
    // mouth
    if (mouth === 'open') { P(x, [[bx + 6, by - 2], [bx + 26, by - 8], [bx + 25, by + 3], [bx + 8, by + 2]], '#3a0610'); R(x, bx + 12, by - 1, 10, 2, '#a0283a'); }
    else L(x, [[bx + 24, by - 3], [bx + 16, by - 1], [bx + 6, by - 1]], '#0a0410', 1.4);
    // eyes on top of the head
    for (const ex of [bx + 10, bx + 19]) {
      E(x, ex, by - 13, 5, 5, sk);
      if (eye === 'shut') L(x, [[ex - 3, by - 13], [ex + 3, by - 12]], '#0a0410', 1.5);
      else if (eye === 'x') { L(x, [[ex - 2.5, by - 15.5], [ex + 2.5, by - 10.5]], '#0a0410', 1.2); L(x, [[ex + 2.5, by - 15.5], [ex - 2.5, by - 10.5]], '#0a0410', 1.2); }
      else { C(x, ex, by - 13.5, eye === 'wide' ? 4 : 3.4, K.red); C(x, ex, by - 13.5, 2.2, K.ember); R(x, ex - 0.5, by - 16, 1.4, 5, '#12040a'); R(x, ex - 2, by - 15.5, 1, 1, '#ffd0d6'); }
    }
    x.restore();
  });
}

// ---------------- Abyssal Seagull (bottom of the body at 44,46)
function seagull(pose, f) {
  return frame(88, 72, x => {
    const fe = '#2c2238', un = '#4a3e58', dk = '#16101e', tip = '#8a1020', sheen = '#5a2a7a';
    let bx = 44, by = 39, ang = 0, wing = [-0.9, -0.2, 0.6, -0.2][f % 4], spread = 1, eye = 'open', tail = 0;
    if (pose === 'dive') { ang = 0.65; wing = 1.4; spread = 0.55; }
    if (pose === 'drop') { wing = -0.5; tail = -0.5; }
    if (pose === 'hurt') { wing = 0.9; eye = 'shut'; ang = -0.2; }
    if (pose === 'dead') { wing = 1.2; eye = 'x'; ang = 2.6; }
    x.save(); x.translate(bx, by); x.rotate(ang);
    const wingShape = (side) => {
      const a = wing * side, len = 30 * spread;
      const p0 = [-2, -2], p1 = [-8 + Math.cos(-1.2 + a) * len * 0.5, Math.sin(-1.2 + a) * len * 0.7], p2 = [-16 + Math.cos(-1.4 + a) * len, Math.sin(-1.4 + a) * len];
      P(x, [p0, [6, -1], p1, p2, [-12, 1]], side > 0 ? fe : dk);
      P(x, [p1, p2, [p2[0] + 4, p2[1] + 3], [p1[0] + 3, p1[1] + 2]], tip);
      L(x, [[2, -1], p1], sheen, 1.2);
    };
    wingShape(-1);
    // tail, body, head, beak
    P(x, [[-12, -1], [-24, -4 + tail * 6], [-24, 3 + tail * 6], [-11, 3]], dk);
    E(x, 0, 0, 14, 6.5, fe); E(x, 1, 3, 11, 3.5, un);
    E(x, 13, -4, 6, 5.5, fe);
    P(x, [[17, -5], [28, -3], [25, 0], [17, -1]], '#3a0a14'); P(x, [[24, -3], [28, -3], [27, 1]], K.red);
    L(x, [[-6, -2], [4, -3]], K.violet, 1);
    if (eye === 'shut') L(x, [[13, -5], [17, -5]], '#0a0410', 1.2);
    else if (eye === 'x') { L(x, [[13, -7], [17, -3]], '#0a0410', 1); L(x, [[17, -7], [13, -3]], '#0a0410', 1); }
    else { C(x, 15, -5.5, 2, K.ember); R(x, 15, -6.5, 1, 1, '#ffffff'); }
    wingShape(1);
    if (pose === 'drop') { C(x, -18, 8, 2.6, '#3a1250'); C(x, -18, 8, 1.4, K.glow); }
    // legs tucked
    R(x, -2, 6, 1.5, 3, '#5a2030'); R(x, 2, 6, 1.5, 3, '#5a2030');
    x.restore();
  });
}

// ---------------- fish: spine bodies (tail → head)
function fishSpine(x0, x1, y, n, bend, phase) {
  const s = [];
  for (let i = 0; i < n; i++) { const t = i / (n - 1); s.push([x0 + (x1 - x0) * t, y + Math.sin(phase + t * 2.2) * bend * (1 - t) * (1 - t)]); }
  return s;
}

// ---------------- Abyssal Bass (bottom of the body at 44,48)
function bass(pose, f) {
  return frame(88, 72, x => {
    const sk = '#1e2a26', dk = '#0e1614', hi = '#3a4a3a', cor = '#4a1a5a', line = '#c0202e';
    const bend = pose === 'swim' ? 4 : (pose === 'charge' ? 1 : 2), ph = [0, 1.6, 3.2, 4.8][f % 4];
    const open = pose === 'bite' && f === 0, dead = pose === 'dead';
    x.save();
    if (dead) { x.translate(44, 38); x.scale(1, -1); x.translate(-44, -38); }
    if (pose === 'charge') { for (let i = 0; i < 5; i++) L(x, [[6 + i * 2, 30 + i * 4], [20 + i * 2, 30 + i * 4]], i % 2 ? K.glow : K.violet, 1.5); }
    const sp = fishSpine(18, 66, 38, 9, bend, ph);
    const tl = sp[0];
    P(x, [[tl[0] + 4, tl[1]], [tl[0] - 8, tl[1] - 9], [tl[0] - 5, tl[1]], [tl[0] - 8, tl[1] + 9]], '#3a1220');
    // spiny dorsal fin
    P(x, [[32, 31], [36, 22], [40, 29], [44, 21], [48, 29], [52, 23], [55, 31]], K.crimson);
    const top = [2, 6, 8, 9.5, 10, 9.5, 8.5, 7, 5], bot = [2, 5, 7, 8, 8.5, 8.5, 8, 7, 5];
    spineBody(x, sp, top, bot, sk);
    clip(x, () => { smooth(x, sp.map((p, i) => [p[0], p[1] - top[i]]).concat(sp.map((p, i) => [p[0], p[1] + bot[i]]).reverse())); }, () => {
      E(x, 40, 30, 22, 5, hi); E(x, 42, 47, 26, 5, dk);
      E(x, 30, 36, 6, 4, cor); E(x, 48, 42, 5, 3, cor); C(x, 30, 35, 1.2, K.glow);
      L(x, sp.slice(1, 8).map(p => [p[0], p[1] + 1]), line, 1.2);
    });
    // pelvic fin and jaw
    P(x, [[44, 44], [40, 52], [48, 46]], '#3a1220');
    if (open) { P(x, [[62, 34], [76, 28], [74, 35], [64, 38]], sk); P(x, [[62, 40], [77, 46], [72, 49], [61, 44]], sk); P(x, [[63, 37], [74, 32], [74, 44], [63, 41]], '#3a0610'); for (let i = 0; i < 4; i++) { P(x, [[66 + i * 2.5, 33 - i], [67 + i * 2.5, 36 - i], [68 + i * 2.5, 33 - i]], '#e8dcc8'); P(x, [[66 + i * 2.5, 44 + i * 0.8], [67 + i * 2.5, 41 + i * 0.8], [68 + i * 2.5, 44 + i * 0.8]], '#e8dcc8'); } }
    else { P(x, [[62, 36], [74, 38], [72, 43], [62, 43]], sk); for (let i = 0; i < 3; i++) P(x, [[66 + i * 3, 41], [67 + i * 3, 38.5], [68 + i * 3, 41]], '#e8dcc8'); }
    // eye
    if (pose === 'hurt' || dead) L(x, [[58, 34], [62, 35]], '#0a0410', 1.4);
    else { C(x, 59, 34, 3, '#2a0a2a'); C(x, 59, 34, 2, K.glow); R(x, 59, 33, 1, 1, '#ffffff'); }
    x.restore();
  });
}

// ---------------- Abyssal Crab (feet at 44,66; about the size of a tortoise)
function crab(pose, f) {
  return frame(88, 72, x => {
    const sh = '#3a1020', dk = '#1a0a20', hi = '#5a1a30', leg = '#2a0c1a', crack = '#b048ff';
    const step = pose === 'walk' ? [0, 1, 0, -1][f % 4] : 0, bob = pose === 'idle' ? f : 0;
    const dead = pose === 'dead', cy = dead ? 58 : 47 + (pose === 'hurt' ? 2 : 0);
    // legs: three a side
    for (let i = 0; i < 3; i++) for (const s of [-1, 1]) {
      const kx = 44 + s * (12 + i * 5), ph = (i % 2 ? 1 : -1) * step * s;
      if (dead) { limb(x, [[44 + s * (8 + i * 4), cy], [44 + s * (20 + i * 5), cy - 6], [44 + s * (26 + i * 5), cy - 2]], 3, 2, leg); continue; }
      limb(x, [[44 + s * (8 + i * 4), cy + 2], [kx + s * 6, cy - 4 + ph * 2], [kx + s * 9 + ph * 2, 66]], 3.4, 2, leg);
    }
    // claws: a big one in front, a small one behind
    const claw = (cx0, cyy, size, open, raised) => {
      const ax = cx0, ay = cyy - (raised ? 12 : 0);
      limb(x, [[44 + (cx0 > 44 ? 12 : -12), cy - 2], [ax - (cx0 > 44 ? 6 : -6), ay + 2], [ax, ay]], 4, 3, sh);
      E(x, ax + 3, ay - 1, size * 0.9, size * 0.65, sh, -0.3);
      E(x, ax + 1, ay - 3, size * 0.5, size * 0.3, hi, -0.3);
      P(x, [[ax + size * 0.6, ay - 3], [ax + size * 1.7, ay - 6 - open * 3], [ax + size * 1.2, ay - 1]], sh);
      P(x, [[ax + size * 0.6, ay + 1], [ax + size * 1.6, ay + 2 + open * 3], [ax + size * 1.1, ay - 0.5]], dk);
    };
    if (!dead) claw(22, cy - 6 - bob, 6, 0.3, false);
    // carapace
    E(x, 44, cy, 21, 11, sh);
    clip(x, () => { x.beginPath(); x.ellipse(44, cy, 21, 11, 0, 0, TAU); }, () => {
      E(x, 42, cy - 6, 16, 4, hi); E(x, 44, cy + 7, 22, 5, dk);
      E(x, 34, cy - 1, 6, 4, dk); E(x, 52, cy + 1, 7, 4, dk);
      L(x, [[30, cy - 2], [36, cy + 1], [40, cy - 4], [46, cy]], crack, 1); L(x, [[50, cy - 5], [55, cy - 1], [60, cy - 3]], crack, 1);
      C(x, 47, cy + 2, 1.2, K.pink);
    });
    // spikes on the rim
    for (let i = 0; i < 5; i++) P(x, [[28 + i * 8, cy - 9 + Math.abs(i - 2)], [30 + i * 8, cy - 14 + Math.abs(i - 2)], [32 + i * 8, cy - 9 + Math.abs(i - 2)]], sh);
    // eye stalks
    if (!dead) for (const ex of [50, 56]) { R(x, ex, cy - 16, 1.5, 6, leg); C(x, ex + 0.7, cy - 17, 2.2, pose === 'hurt' ? '#5a2030' : K.red); if (pose !== 'hurt') R(x, ex, cy - 18, 1, 1, '#ffd0d6'); }
    if (pose === 'beam') { E(x, 64, cy + 1, 4, 3, '#3a0610'); for (const [bx2, by2, r] of [[70, cy - 2, 2.5], [76, cy + 1, 2], [72, cy + 4, 1.6]]) { C(x, bx2, by2, r, '#9fd8ff'); C(x, bx2 - 0.6, by2 - 0.6, r * 0.4, '#ffffff'); } }
    // the big claw in front
    if (!dead) {
      if (pose === 'pinch') claw(f === 0 ? 62 : 70, cy - 4, 8.5, f === 0 ? 1.2 : 0, f === 0);
      else claw(64, cy - 3 - bob, 8, 0.5, false);
    } else { L(x, [[38, cy - 4], [42, cy], [46, cy - 4]], '#0a0410', 1); }
  });
}

// ---------------- Abyssal Shark (180×80; the bottom of the body at 90,62)
function shark(pose, f) {
  return frame(180, 80, x => {
    const bk = '#2a2638', dk = '#151320', bl = '#5a5068', sc = '#8a3aaa', gill = K.red;
    const ph = [0, 1.6, 3.2, 4.8][f % 4], bend = pose === 'swim' ? 7 : 3, open = pose === 'bite' && f === 0, dead = pose === 'dead';
    x.save();
    if (dead) { x.translate(90, 44); x.scale(1, -1); x.translate(-90, -44); }
    const sp = fishSpine(28, 158, 44, 12, bend, ph);
    const t0 = sp[0];
    // tail crescent and fins
    P(x, [[t0[0] + 6, t0[1]], [t0[0] - 14, t0[1] - 24], [t0[0] - 6, t0[1] - 2], [t0[0] - 10, t0[1] + 16]], dk);
    P(x, [[82, 30], [96, 4], [104, 6], [106, 31]], dk);
    P(x, [[96, 31], [100, 10], [103, 11], [104, 31]], bk);
    const top = [2, 5, 8, 11, 13, 14, 14.5, 14, 13, 11, 8, 5], bot = [2, 4, 7, 9, 11, 12, 12, 12, 11, 10, 8, 4];
    spineBody(x, sp, top, bot, bk);
    clip(x, () => { smooth(x, sp.map((p, i) => [p[0], p[1] - top[i]]).concat(sp.map((p, i) => [p[0], p[1] + bot[i]]).reverse())); }, () => {
      E(x, 96, 52, 62, 9, bl); E(x, 100, 34, 52, 4, '#3e3a50');
      L(x, [[70, 40], [80, 36], [86, 44]], sc, 1.2); L(x, [[110, 38], [118, 44]], sc, 1.2); C(x, 82, 40, 1.4, K.glow);
      for (let i = 0; i < 4; i++) L(x, [[132 - i * 4, 38], [130 - i * 4, 48]], gill, 1.3);
    });
    P(x, [[110, 54], [100, 70], [120, 56]], dk);
    // jaw
    if (open) {
      P(x, [[146, 40], [176, 28], [174, 40], [150, 46]], bk); P(x, [[146, 50], [174, 62], [166, 64], [144, 56]], bl);
      P(x, [[148, 44], [172, 34], [170, 58], [148, 52]], '#3a0610');
      for (let i = 0; i < 6; i++) { P(x, [[152 + i * 3.4, 42 - i * 1.3], [153.5 + i * 3.4, 47 - i * 1.3], [155 + i * 3.4, 42 - i * 1.3]], '#f0e8dc'); P(x, [[152 + i * 3.4, 55 + i * 0.9], [153.5 + i * 3.4, 50 + i * 0.9], [155 + i * 3.4, 55 + i * 0.9]], '#f0e8dc'); }
    } else {
      P(x, [[146, 38], [174, 44], [166, 52], [146, 52]], bk); L(x, [[150, 50], [168, 49]], '#0a0410', 1.2);
      for (let i = 0; i < 4; i++) P(x, [[152 + i * 4, 50], [153.5 + i * 4, 52.5], [155 + i * 4, 50]], '#f0e8dc');
    }
    if (pose === 'hurt' || dead) L(x, [[142, 38], [147, 40]], '#0a0410', 1.6);
    else { C(x, 144, 39, 2.6, '#2a0a10'); C(x, 144, 39, 1.7, K.ember); R(x, 144, 38, 1, 1, '#fff'); }
    x.restore();
  });
}

// ---------------- Abyssal Squid (100×140; tentacle tips at 50,136)
function squid(pose, f) {
  return frame(100, 140, x => {
    const sk = '#3a0e3a', dk = '#1e061e', hi = '#5a1e5a', spot = '#d0304a';
    const ph = [0, 1.5, 3, 4.5][f % 4], squeeze = pose === 'ink' ? 0.75 : (pose === 'swim' ? 1 + Math.sin(ph) * 0.06 : 1), dead = pose === 'dead';
    x.save();
    if (dead) { x.translate(50, 120); x.rotate(1.5); x.scale(0.62, 0.62); x.translate(-50, -50); }
    // arms
    const arms = 8;
    for (let i = 0; i < arms; i++) {
      const s = (i / (arms - 1)) * 2 - 1, len = i === 1 || i === 6 ? 56 : 42;
      const sway = pose === 'swim' ? Math.sin(ph + i) * 0.5 : 0;
      const a = Math.PI / 2 + s * (pose === 'swim' && f % 2 ? 0.5 : 0.25) + sway * 0.2;
      limb(x, curl(50 + s * 10, 88, a, len, -s * 0.8 + sway, 10), 6, 1.5, i % 2 ? sk : dk);
    }
    // mantle with fins
    P(x, [[50, 4], [30, 18], [50, 26], [70, 18]], dk);
    const mw = 18 * squeeze;
    S(x, [[50, 6], [50 + mw, 30], [50 + mw * 0.9, 66], [50 + mw * 0.8, 88], [50, 92], [50 - mw * 0.8, 88], [50 - mw * 0.9, 66], [50 - mw, 30]], sk);
    clip(x, () => smooth(x, [[50, 6], [50 + mw, 30], [50 + mw * 0.9, 66], [50 + mw * 0.8, 88], [50, 92], [50 - mw * 0.8, 88], [50 - mw * 0.9, 66], [50 - mw, 30]]), () => {
      E(x, 44, 40, 6, 26, hi); E(x, 62, 60, 8, 30, dk);
      const r = rng(7); for (let i = 0; i < 12; i++) C(x, 38 + r() * 24, 20 + r() * 64, 1 + r() * 1.6, spot);
      L(x, [[50, 12], [52, 40], [49, 70]], K.glow, 0.8);
    });
    // eyes
    const gz = pose === 'gaze';
    for (const s of [-1, 1]) {
      const ex = 50 + s * 11, ey = 80;
      if (gz) glowDot(x, ex, ey, 12, '#ff6af0', 0.7);
      E(x, ex, ey, 7, 6, '#0e0410');
      if (pose === 'hurt' || dead) L(x, [[ex - 4, ey], [ex + 4, ey + 1]], '#ff9ac0', 1.4);
      else { E(x, ex, ey, 5, 4.4, gz ? '#ffd6ff' : '#ffb03a'); R(x, ex - 3.5, ey - 0.7, 7, 1.6, '#12040a'); if (gz) C(x, ex, ey, 2, '#ffffff'); }
    }
    if (pose === 'ink') { C(x, 50, 96, 6, '#0a0410'); C(x, 46, 100, 3, '#1a0a20'); }
    x.restore();
  });
}

// ---------------- Abyssal Orca (260×130; the bottom of the body at 130,112)
function orca(pose, f) {
  return frame(260, 130, x => {
    const bk = '#0e0a14', dk = '#06040a', patch = '#5a2280', glowc = '#c0203a';
    let ph = [0, 1.6, 3.2, 4.8][f % 4], bend = pose === 'swim' ? 10 : 4;
    const tailUp = pose === 'tail' ? (f === 0 ? -1 : 1) : 0, open = pose === 'chomp' && f === 0, dead = pose === 'dead';
    x.save();
    if (dead) { x.translate(130, 80); x.scale(1, -1); x.translate(-130, -80); }
    const sp = [];
    for (let i = 0; i < 14; i++) { const t = i / 13; let y = 76 + Math.sin(ph + t * 2) * bend * (1 - t) * (1 - t); if (tailUp) y += tailUp * 34 * Math.pow(1 - t, 2.4); sp.push([34 + 196 * t, y]); }
    const t0 = sp[0], t1 = sp[1];
    const ta = Math.atan2(t1[1] - t0[1], t1[0] - t0[0]);
    // flukes
    x.save(); x.translate(t0[0], t0[1]); x.rotate(ta);
    P(x, [[10, 0], [-20, -22], [-10, 0], [-20, 22]], dk); x.restore();
    // dorsal fin (tall)
    P(x, [[110, 50], [118, 6], [128, 10], [136, 52]], bk);
    const top = [3, 6, 9, 13, 17, 21, 24, 26, 27, 27, 26, 24, 20, 13], bot = [3, 5, 8, 11, 14, 17, 20, 22, 23, 23, 22, 20, 17, 12];
    spineBody(x, sp, top, bot, bk);
    clip(x, () => { smooth(x, sp.map((p, i) => [p[0], p[1] - top[i]]).concat(sp.map((p, i) => [p[0], p[1] + bot[i]]).reverse())); }, () => {
      E(x, 150, 98, 70, 12, patch); E(x, 100, 92, 18, 8, patch); E(x, 150, 97, 60, 8, '#7a32a8');
      E(x, 200, 64, 13, 6, glowc); E(x, 200, 64, 9, 3.5, K.ember);          // the eye patch, glowing
      E(x, 140, 55, 60, 5, '#1e1828');
      L(x, [[80, 70], [92, 64], [100, 72]], K.violet, 1.4); L(x, [[160, 60], [170, 66]], K.violet, 1.4);
    });
    // pectoral fin
    P(x, [[156, 100], [140, 124], [168, 104]], dk);
    // mouth
    if (open) {
      P(x, [[214, 70], [256, 54], [254, 70], [218, 82]], bk); P(x, [[214, 88], [252, 102], [242, 108], [212, 96]], patch);
      P(x, [[216, 78], [250, 62], [248, 98], [216, 90]], '#3a0610');
      for (let i = 0; i < 6; i++) { P(x, [[222 + i * 4.5, 74 - i * 1.8], [224 + i * 4.5, 80 - i * 1.8], [226 + i * 4.5, 74 - i * 1.8]], '#f0e8dc'); P(x, [[222 + i * 4.5, 94 + i * 0.8], [224 + i * 4.5, 88 + i * 0.8], [226 + i * 4.5, 94 + i * 0.8]], '#f0e8dc'); }
    } else {
      L(x, [[214, 88], [232, 86], [246, 80]], '#3a1a50', 2);
      for (let i = 0; i < 4; i++) P(x, [[222 + i * 5, 87], [224 + i * 5, 90], [226 + i * 5, 87]], '#f0e8dc');
    }
    if (pose === 'hurt' || dead) L(x, [[205, 70], [211, 72]], '#0a0410', 1.6);
    else { C(x, 208, 71, 2.6, '#ffd0d6'); C(x, 208, 71, 1.4, '#12040a'); }
    x.restore();
  });
}

// ---------------- Abyssal Octopus (feet at 44,66; small)
function octopus(pose, f) {
  return frame(88, 72, x => {
    const sk = '#3a1438', dk = '#1e0a1e', hi = '#5a2458', suck = '#d0406a';
    const dead = pose === 'dead';
    let hx = 42, hy = 42, tilt = -0.25;
    if (pose === 'flurry' || pose === 'grab') { hx = 38; tilt = -0.1; }
    if (pose === 'hurt') { hy = 45; tilt = 0.1; }
    if (dead) { hy = 56; tilt = 1.2; }
    // tentacles
    const n = 7;
    for (let i = 0; i < n; i++) {
      const s = i / (n - 1);
      let pts;
      if (pose === 'scurry') { const ph = f * 1.6 + i * 1.3; pts = curl(hx - 6 + s * 12, hy + 8, Math.PI / 2 + (s - 0.5) * 1.6 + Math.sin(ph) * 0.4, 20, (s - 0.5) * -2 + Math.cos(ph) * 0.6, 8); }
      else if (pose === 'flurry' && i >= 4) { const reach = f === 0 ? [24, 34, 18] : [32, 22, 30]; pts = curl(hx + 6, hy + 4 + (i - 4) * 3, -0.2 + (i - 5) * 0.25, reach[i - 4], 0.3, 8); }
      else if (pose === 'grab' && i >= 3) { pts = curl(hx + 6, hy + 2 + (i - 3) * 3, -0.15 + (i - 4) * 0.2, 36, 0.4 - (i - 3) * 0.1, 9); }
      else if (dead) { pts = curl(hx - 10 + s * 20, hy + 2, Math.PI / 2 + (s - 0.5) * 2.4, 16, 0, 6); }
      else { const ph = (pose === 'idle' ? f : 0) * 0.5 + i; pts = curl(hx - 6 + s * 12, hy + 8, Math.PI / 2 + (s - 0.5) * 1.9, 20, (s - 0.5) * -2.4 + Math.sin(ph) * 0.3, 8); }
      limb(x, pts, 5, 1.2, i % 2 ? sk : dk);
      for (let k = 2; k < pts.length - 1; k += 2) C(x, pts[k][0], pts[k][1] + 1, 0.9, suck);
    }
    // head
    x.save(); x.translate(hx, hy); x.rotate(tilt);
    E(x, -2, -6, 11, 13, sk);
    clip(x, () => { x.beginPath(); x.ellipse(-2, -6, 11, 13, 0, 0, TAU); }, () => { E(x, -6, -12, 5, 6, hi); E(x, 4, 2, 9, 7, dk); C(x, -4, -14, 1.3, K.glow); C(x, 2, -9, 1, K.glow); });
    for (const ex of [3, 9]) {
      if (pose === 'hurt' || dead) L(x, [[ex - 2, 2], [ex + 2, 3]], '#0a0410', 1.2);
      else { E(x, ex, 2, 2.6, 2.2, '#ffcf5a'); R(x, ex - 2, 1.6, 4, 1, '#12040a'); }
    }
    x.restore();
  });
}

// ------------------------------------------------------------------ sets
// anchor: where the feet (or the bottom of the body) sit in a frame, in pixels
const SETS = {
  toad: { w: 88, h: 72, ax: 44, ay: 66, draw: toad, keys: { idle: 2, hop: 1, slam: 1, tongue: 1, hurt: 1, dead: 1 } },
  seagull: { w: 88, h: 72, ax: 44, ay: 46, draw: seagull, keys: { fly: 4, dive: 1, drop: 1, hurt: 1, dead: 1 } },
  bass: { w: 88, h: 72, ax: 44, ay: 48, draw: bass, keys: { swim: 4, bite: 2, charge: 1, hurt: 1, dead: 1 } },
  crab: { w: 88, h: 72, ax: 44, ay: 66, draw: crab, keys: { walk: 4, idle: 2, pinch: 2, beam: 1, hurt: 1, dead: 1 } },
  shark: { w: 180, h: 80, ax: 90, ay: 62, draw: shark, keys: { swim: 4, bite: 2, hurt: 1, dead: 1 } },
  squid: { w: 100, h: 140, ax: 50, ay: 136, draw: squid, keys: { swim: 4, ink: 1, gaze: 1, hurt: 1, dead: 1 } },
  orca: { w: 260, h: 130, ax: 130, ay: 112, draw: orca, keys: { swim: 4, chomp: 2, tail: 2, hurt: 1, dead: 1 } },
  octopus: { w: 88, h: 72, ax: 44, ay: 66, draw: octopus, keys: { scurry: 4, idle: 2, flurry: 2, grab: 1, hurt: 1, dead: 1 } },
};
const FIRST = { toad: 'idle', seagull: 'fly', bass: 'swim', crab: 'idle', shark: 'swim', squid: 'swim', orca: 'swim', octopus: 'idle' };
const SHINY = 'hue-rotate(150deg) saturate(1.5) brightness(1.35)';
const ELITE = 'brightness(0.8) saturate(1.6) hue-rotate(-25deg) contrast(1.15)';

function bakeMobs() {
  const out = {};
  for (const [name, S0] of Object.entries(SETS)) {
    const base = {};
    for (const [k, n] of Object.entries(S0.keys)) base[k] = Array.from({ length: n }, (_, f) => fin(S0.draw(k, f)));
    base.white = [whiteOf(base[FIRST[name]][0])];
    const dim = { ax: S0.ax / 2, ay: S0.ay / 2, w: S0.w / 2, h: S0.h / 2 };
    out[name] = { sets: base, dim };
    const tint = (f) => Object.fromEntries(Object.entries(base).map(([k, fr]) => [k, k === 'white' ? fr : fr.map(c => filtered(c, f))]));
    out[name + '_shiny'] = { sets: tint(SHINY), dim };
    out[name + '_elite'] = { sets: tint(ELITE), dim };
  }
  return out;
}

// ================================================================== THE DREAMER
const DR = { skin: '#2a1040', dark: '#120620', mid: '#3e1858', hi: '#5a2878', vein: '#a0203a', spot: '#c25cff', sucker: '#d0406a', tip: '#7a2a8a' };

// the head: 560×340, bottom-centre on the floor (the eyes and mouth are separate pictures)
function dreamerHead() {
  const c = cv(560, 340), x = g2(c);
  const r = rng(77);
  // cranium
  const dome = [[280, 6], [380, 20], [470, 80], [530, 180], [548, 280], [540, 340], [20, 340], [12, 280], [30, 180], [90, 80], [180, 20]];
  S(x, dome, DR.skin);
  clip(x, () => smooth(x, dome), () => {
    // shading bands and ridges
    E(x, 280, 40, 200, 50, DR.mid); E(x, 240, 30, 120, 22, DR.hi);
    E(x, 280, 330, 300, 60, DR.dark); E(x, 40, 220, 40, 140, DR.dark); E(x, 520, 220, 40, 140, DR.dark);
    for (let i = 0; i < 9; i++) { const yy = 34 + i * 10; L(x, [[120 + i * 6, yy + 40], [200, yy + 8], [280, yy], [360, yy + 8], [440 - i * 6, yy + 40]], i % 2 ? DR.dark : DR.mid, 2); }
    // veins
    for (let i = 0; i < 14; i++) {
      let X = 60 + r() * 440, Y = 60 + r() * 220; const pts = [[X, Y]];
      for (let k = 0; k < 7; k++) { X += (r() - 0.5) * 40; Y += (r() - 0.2) * 26; pts.push([X, Y]); }
      L(x, pts, DR.vein, 1.5 + r()); L(x, pts.map(p => [p[0] + 1, p[1] - 1]), '#5a0a20', 0.8);
    }
    // bioluminescent spots and barnacle-like growths
    for (let i = 0; i < 46; i++) { const X = 40 + r() * 480, Y = 30 + r() * 270; if (Math.abs(X - 280) < 70 && Y > 180) continue; C(x, X, Y, 1 + r() * 2.2, DR.spot); C(x, X - 0.5, Y - 0.5, 0.6, '#f0c8ff'); }
    for (let i = 0; i < 18; i++) { const X = 30 + r() * 500, Y = 120 + r() * 200; C(x, X, Y, 3 + r() * 4, '#1a0a26'); C(x, X, Y, 1.4 + r() * 1.5, '#0a0410'); }
    // brow ridges over the eye sockets
    for (const s of [-1, 1]) {
      const ex = 280 + s * 104;
      E(x, ex, 112, 52, 34, DR.dark);
      P(x, [[ex - 58 * s, 98], [ex - 10 * s, 64], [ex + 50 * s, 78], [ex + 56 * s, 96], [ex, 84]], DR.hi);
      E(x, ex, 114, 38, 26, '#08020e');
      E(x, ex, 136, 46, 14, DR.dark);
    }
    // the face: folds that lead down to the mouth, where the tentacles grow
    S(x, [[200, 160], [280, 150], [360, 160], [400, 260], [380, 340], [180, 340], [160, 260]], DR.mid);
    for (let i = 0; i < 6; i++) L(x, [[214 + i * 26, 168], [206 + i * 30, 240], [190 + i * 34, 330]], i % 2 ? DR.dark : DR.skin, 3);
    E(x, 280, 222, 64, 48, DR.dark);
  });
  return crisp(c);
}

function dreamerEye(state) {   // 64×44: open, glow, shut, hurt
  const c = cv(64, 44), x = g2(c);
  if (state === 'glow') glowDot(x, 32, 22, 30, '#ff6af0', 0.8);
  E(x, 32, 22, 26, 17, '#1a0610');
  if (state === 'shut') { E(x, 32, 20, 27, 16, DR.mid); L(x, [[8, 24], [32, 30], [56, 24]], '#0a0410', 2.4); for (let i = 0; i < 7; i++) L(x, [[12 + i * 7, 27], [11 + i * 7, 33]], '#0a0410', 1); return fin(c); }
  E(x, 32, 22, 24, 15, state === 'glow' ? '#ffd6f4' : '#e8c8b0');
  if (state !== 'glow') { const r = rng(3); for (let i = 0; i < 8; i++) { const a = r() * TAU; L(x, [[32 + Math.cos(a) * 22, 22 + Math.sin(a) * 13], [32 + Math.cos(a) * 12, 22 + Math.sin(a) * 7]], '#c03040', 0.9); } }
  const ir = state === 'glow' ? '#ff40d8' : (state === 'hurt' ? '#8a2040' : '#c0202e');
  E(x, 32, 22, 13, 13, ir); E(x, 32, 22, 9, 9, state === 'glow' ? '#ffffff' : '#ff4a5a');
  if (state === 'hurt') { E(x, 32, 22, 3, 6, '#12040a'); L(x, [[8, 12], [56, 16]], DR.mid, 6); }
  else E(x, 32, 22, 3.2, 11, '#12040a');
  C(x, 26, 16, 2.5, '#ffffff');
  return fin(c);
}

function dreamerMouth(open) {   // 120×96
  const c = cv(120, 96), x = g2(c);
  if (!open) {
    E(x, 60, 48, 44, 30, DR.dark);
    for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; P(x, [[60, 48], [60 + Math.cos(a - 0.3) * 40, 48 + Math.sin(a - 0.3) * 26], [60 + Math.cos(a + 0.3) * 40, 48 + Math.sin(a + 0.3) * 26]], i % 2 ? DR.mid : DR.skin); }
    E(x, 60, 48, 8, 6, '#0a0410'); C(x, 60, 48, 3, DR.vein);
    return fin(c);
  }
  E(x, 60, 48, 56, 44, DR.mid);
  E(x, 60, 48, 48, 38, '#1a0208');
  for (let ring = 0; ring < 3; ring++) {
    const rx = 44 - ring * 12, ry = 34 - ring * 9, n = 16 - ring * 3;
    for (let i = 0; i < n; i++) { const a = i / n * TAU + ring * 0.3; P(x, [[60 + Math.cos(a - 0.12) * rx, 48 + Math.sin(a - 0.12) * ry], [60 + Math.cos(a) * (rx - 9), 48 + Math.sin(a) * (ry - 7)], [60 + Math.cos(a + 0.12) * rx, 48 + Math.sin(a + 0.12) * ry]], ring === 2 ? '#d8c0b0' : '#f0e4d4'); }
  }
  glowDot(x, 60, 50, 18, '#ff3a6a', 0.9); E(x, 60, 50, 6, 5, '#ff8aa0');
  return crisp(c);
}

// tentacles for the portrait (the game draws them live in the same colours)
function dreamerTentacle(x, x0, y0, ang, len, bend, w = 16) {
  const pts = curl(x0, y0, ang, len, bend, 14);
  limb(x, pts, w, 2, DR.skin);
  const pts2 = pts.map((p, i) => [p[0] + 1.5, p[1] + 1.5]);
  for (let k = 2; k < pts.length - 1; k++) C(x, pts2[k][0], pts2[k][1], Math.max(0.8, w * 0.12 * (1 - k / pts.length)), DR.sucker);
}

function dreamerPortrait(gaze) {   // 220×170, for the bestiary and the monster card
  const c = cv(220, 170), x = g2(c);
  x.save(); x.translate(110, 170); x.scale(0.36, 0.36); x.translate(-280, -340);
  x.drawImage(dreamerHead(), 0, 0);
  const eye = dreamerEye(gaze ? 'glow' : 'open');
  for (const s of [-1, 1]) x.drawImage(eye, 280 + s * 104 - 32, 110 - 22);
  x.drawImage(dreamerMouth(false), 280 - 60, 222 - 48);
  for (let i = 0; i < 7; i++) { const s = (i / 6) * 2 - 1; dreamerTentacle(x, 280 + s * 50, 240, Math.PI / 2 + s * 0.6, 150 + (i % 2) * 40, -s * 1.4, 22); }
  for (const s of [-1, 1]) for (let k = 0; k < 2; k++) dreamerTentacle(x, 280 + s * (200 + k * 70), 345, -Math.PI / 2 - s * (0.25 + k * 0.2), 170 - k * 40, s * (1.6 + k), 30 - k * 6);
  x.restore();
  return fin(c);
}

function bakeDreamer() {
  return {
    head: [dreamerHead()],
    eye: ['open', 'glow', 'shut', 'hurt'].map(dreamerEye),
    mouth: [dreamerMouth(false), dreamerMouth(true)],
    portrait: [dreamerPortrait(false), dreamerPortrait(true)],
  };
}

// ================================================================== ITEMS (9×9 like the other residues)
function icon(draw) { const c = cv(9, 9), x = g2(c); draw(x); return c; }
const ITEMS = {
  residue_toad: icon(x => { R(x, 1, 3, 7, 5, '#2a1238'); R(x, 2, 2, 5, 1, '#2a1238'); R(x, 2, 4, 2, 2, K.red); R(x, 5, 5, 2, 2, K.red); R(x, 2, 4, 1, 1, K.ember); }),
  residue_seagull: icon(x => { for (let i = 0; i < 7; i++) R(x, 1 + i, 7 - i, 1, 1, '#16101e'); R(x, 2, 4, 2, 3, '#2c2238'); R(x, 4, 2, 2, 3, '#2c2238'); R(x, 6, 1, 1, 2, K.crimson); }),
  residue_bass: icon(x => { R(x, 2, 2, 5, 5, '#1e2a26'); R(x, 1, 3, 7, 3, '#1e2a26'); R(x, 3, 3, 2, 2, '#4a1a5a'); R(x, 5, 4, 1, 1, K.glow); }),
  residue_crab: icon(x => { R(x, 1, 3, 7, 4, '#3a1020'); R(x, 2, 2, 5, 1, '#3a1020'); R(x, 3, 4, 3, 1, '#b048ff'); R(x, 4, 5, 1, 1, '#b048ff'); }),
  residue_shark: icon(x => { R(x, 3, 1, 3, 1, '#f0e8dc'); R(x, 3, 2, 3, 2, '#f0e8dc'); R(x, 4, 4, 1, 3, '#f0e8dc'); R(x, 2, 7, 5, 1, '#8a3aaa'); }),
  residue_squid: icon(x => { R(x, 2, 2, 5, 5, '#1a0a20'); R(x, 3, 1, 3, 7, '#1a0a20'); R(x, 3, 3, 2, 2, '#3a0e3a'); R(x, 6, 2, 1, 1, '#d0304a'); }),
  residue_orca: icon(x => { R(x, 1, 2, 7, 5, '#0e0a14'); R(x, 2, 5, 5, 2, '#5a2280'); R(x, 2, 3, 2, 1, '#c0203a'); }),
  residue_octopus: icon(x => { R(x, 2, 2, 5, 5, '#3a1438'); R(x, 3, 3, 3, 3, '#d0406a'); R(x, 4, 4, 1, 1, '#3a1438'); }),
};
function dreamKey() {   // 32×32: the key the Dreamer drops
  const c = cv(32, 32), x = g2(c);
  glowDot(x, 16, 16, 15, '#c25cff', 0.6);
  C(x, 16, 9, 6, '#5a2878'); C(x, 16, 9, 3, '#0a0410'); C(x, 16, 9, 1.5, '#ff6af0');
  R(x, 15, 14, 3, 14, '#5a2878'); R(x, 18, 22, 4, 2, '#5a2878'); R(x, 18, 26, 3, 2, '#5a2878'); R(x, 15, 14, 1, 14, '#9a5ac8');
  for (const [a, l] of [[-0.8, 7], [3.9, 7], [-2.3, 6]]) L(x, [[16 + Math.cos(a) * 5, 9 + Math.sin(a) * 5], [16 + Math.cos(a) * (5 + l), 9 + Math.sin(a) * (5 + l)]], '#3e1858', 1.6);
  return fin(c);
}

// ================================================================== BACKDROPS (768×240 far, 768×180 mid; tiled sideways)
function hills(x, w, base, amp, col, seed, step = 24) {
  const r = rng(seed); x.fillStyle = col; x.beginPath(); x.moveTo(0, x.canvas.height);
  for (let X = 0; X <= w; X += step) x.lineTo(X, base - r() * amp);
  x.lineTo(w, x.canvas.height); x.closePath(); x.fill();
}
function farShore() {   // the surface: sea stacks and a far, broken coastline (bottom edge = the horizon)
  const c = cv(1536, 240), x = g2(c), r = rng(11);
  for (let i = 0; i < 9; i++) {
    const X = 40 + i * 170 + r() * 60, w = 30 + r() * 50, h = 60 + r() * 110;
    P(x, [[X - w, 240], [X - w * 0.5, 240 - h * 0.7], [X - w * 0.2, 240 - h], [X + w * 0.3, 240 - h * 0.9], [X + w * 0.6, 240 - h * 0.5], [X + w, 240]], '#1c0814');
    P(x, [[X - w * 0.2, 240 - h], [X + w * 0.3, 240 - h * 0.9], [X + w * 0.1, 240 - h * 0.6]], '#2a0c1c');
  }
  hills(x, 1536, 236, 18, '#14060e', 12, 30);
  return crisp(c);
}
function midShore() {
  const c = cv(1536, 180), x = g2(c), r = rng(21);
  hills(x, 1536, 170, 30, '#0e0410', 22, 40);
  for (let i = 0; i < 5; i++) {   // a wrecked ship's masts leaning out of the water
    const X = 120 + i * 300 + r() * 80, h = 80 + r() * 60, lean = (r() - 0.5) * 0.4;
    L(x, [[X, 180], [X + Math.sin(lean) * h, 180 - h]], '#1a0810', 5);
    L(x, [[X + Math.sin(lean) * h * 0.7 - 20, 180 - h * 0.7], [X + Math.sin(lean) * h * 0.7 + 22, 180 - h * 0.72]], '#1a0810', 3);
    L(x, [[X + Math.sin(lean) * h * 0.7 + 22, 180 - h * 0.72], [X + 30, 176]], '#2a0c18', 1);
  }
  return crisp(c);
}
function farDeep() {   // underwater: far rock spires and kelp silhouettes
  const c = cv(1536, 240), x = g2(c), r = rng(31);
  for (let i = 0; i < 12; i++) {
    const X = r() * 1536, w = 20 + r() * 40, h = 80 + r() * 150;
    P(x, [[X - w, 240], [X - w * 0.3, 240 - h], [X + w * 0.2, 240 - h * 0.85], [X + w, 240]], '#0c0a22');
  }
  for (let i = 0; i < 40; i++) { const X = r() * 1536, h = 40 + r() * 120; L(x, curl(X, 240, -Math.PI / 2, h, (r() - 0.5) * 1.4, 8), '#100a24', 3); }
  hills(x, 1536, 236, 20, '#0a0818', 32, 26);
  return crisp(c);
}
function midDeep() {
  const c = cv(1536, 180), x = g2(c), r = rng(41);
  hills(x, 1536, 172, 26, '#070512', 42, 34);
  for (let i = 0; i < 26; i++) { const X = r() * 1536, h = 30 + r() * 90; L(x, curl(X, 180, -Math.PI / 2, h, (r() - 0.5) * 2, 9), i % 3 ? '#0e0818' : '#2a0814', 4); }
  for (let i = 0; i < 6; i++) { const X = 100 + i * 260 + r() * 60; E(x, X, 168, 30 + r() * 30, 18, '#0a0614'); for (let k = 0; k < 5; k++) L(x, curl(X - 20 + k * 10, 160, -Math.PI / 2 - 0.4 + k * 0.2, 20 + r() * 20, 0.6, 5), '#160a22', 2); }
  return crisp(c);
}
function farRuin() {   // the deep: ancient pillars and arches, far away
  const c = cv(1536, 240), x = g2(c), r = rng(51);
  for (let i = 0; i < 8; i++) {
    const X = 60 + i * 190 + r() * 50, h = 90 + r() * 120, w = 16 + r() * 10;
    R(x, X, 240 - h, w, h, '#0a0818'); R(x, X - 4, 240 - h, w + 8, 8, '#0a0818');
    if (r() < 0.6) { x.strokeStyle = '#0a0818'; x.lineWidth = 12; x.beginPath(); x.arc(X + 70, 240 - h + 10, 64, Math.PI, TAU); x.stroke(); }
    if (r() < 0.7) { R(x, X + w / 2 - 1, 240 - h + 20 + r() * 40, 2, 2, '#3a1050'); }
  }
  hills(x, 1536, 238, 14, '#070512', 52, 30);
  return crisp(c);
}
function midRuin() {
  const c = cv(1536, 180), x = g2(c), r = rng(61);
  hills(x, 1536, 174, 18, '#05030c', 62, 36);
  for (let i = 0; i < 7; i++) {
    const X = 80 + i * 220 + r() * 60, h = 60 + r() * 80, w = 22;
    R(x, X, 180 - h, w, h, '#0a0614'); R(x, X - 5, 180 - h, w + 10, 7, '#0a0614');
    P(x, [[X - 30, 180], [X - 10, 180 - h * 0.4], [X + 40, 180 - h * 0.3], [X + 60, 180]], '#08040e');
    R(x, X + 8, 180 - h + 18, 2, 3, '#4a1020'); R(x, X + 12, 180 - h + 30, 2, 3, '#3a1050');
  }
  return crisp(c);
}
// the bubble's film: soft bands of thin-film colour (tileable sideways), scrolled and layered live
function bubbleFilm(seed) {
  const c = cv(768, 432), x = g2(c), r = rng(seed);
  const cols = ['#ff5aa8', '#ffb84a', '#fff36a', '#5affb0', '#4ad8ff', '#7a6aff', '#d65aff'];
  for (let i = 0; i < 36; i++) {
    const X = r() * 768, Y = r() * 432, rx = 60 + r() * 160, ry = 20 + r() * 60, col = cols[i % cols.length], [R_, G, B] = hex(col);
    for (const dx of [-768, 0, 768]) {
      const g = x.createRadialGradient(X + dx, Y, 0, X + dx, Y, rx);
      g.addColorStop(0, `rgba(${R_},${G},${B},0.55)`); g.addColorStop(0.6, `rgba(${R_},${G},${B},0.2)`); g.addColorStop(1, `rgba(${R_},${G},${B},0)`);
      x.fillStyle = g; x.save(); x.translate(X + dx, Y); x.scale(1, ry / rx); x.translate(-(X + dx), -Y); x.beginPath(); x.arc(X + dx, Y, rx, 0, TAU); x.fill(); x.restore();
    }
  }
  // swirling interference lines
  for (let i = 0; i < 18; i++) {
    const y0 = r() * 432, col = cols[i % cols.length], amp = 10 + r() * 40, ph = r() * TAU;
    x.strokeStyle = col; x.globalAlpha = 0.35; x.lineWidth = 2 + r() * 3; x.beginPath();
    for (let X = 0; X <= 768; X += 8) { const Y = y0 + Math.sin(X / 768 * TAU * 2 + ph) * amp; X ? x.lineTo(X, Y) : x.moveTo(X, Y); }
    x.stroke(); x.globalAlpha = 1;
  }
  return c;
}

// ================================================================== MAPS (2× the map size)
// returns { canvas, glows: [[x, y, r, colour], …] in world units }
function paintMap(id, M) {
  const W = M.w * 2, H = M.h * 2, c = cv(W, H), x = g2(c), r = rng(id.length * 977 + M.w), glows = [];
  x.save(); x.scale(2, 2);
  const deep = M.depth || 0, theme = M.theme;
  const pieces = (M.floor || [[20, M.w - 20, M.floorY]]).slice().sort((a, b) => a[0] - b[0]);
  const groundAt = (X) => { let g = Infinity; for (const p of pieces) if (X >= p[0] && X <= p[1]) g = Math.min(g, p[2]); return g; };
  const rock = deep > 0.6 ? ['#0a0612', '#120a1e', '#1a0e2a'] : (deep > 0.2 ? ['#0e0a1a', '#181026', '#22142e'] : ['#120814', '#1e0c1c', '#2a1020']);
  const sand = theme === 'bubble' ? null : (deep > 0.6 ? ['#1e1428', '#2e2038'] : ['#2a1c2e', '#3e2a3a']);

  // ---- ancient structures behind the ground (deep maps)
  const runeGlyph = (X, Y, col) => {
    const g = Math.floor(r() * 4);
    x.fillStyle = col;
    if (g === 0) { x.fillRect(X - 1.5, Y - 3, 1, 6); x.fillRect(X - 1.5, Y - 3, 3, 1); x.fillRect(X + 0.5, Y, 1, 3); }
    if (g === 1) { x.fillRect(X - 2, Y - 2, 4, 1); x.fillRect(X - 0.5, Y - 3, 1, 6); x.fillRect(X - 2, Y + 2, 4, 1); }
    if (g === 2) { x.beginPath(); x.arc(X, Y, 2, 0, TAU); x.lineWidth = 0.8; x.strokeStyle = col; x.stroke(); x.fillRect(X - 0.5, Y - 4, 1, 2); }
    if (g === 3) { x.fillRect(X - 2, Y - 3, 1, 6); x.fillRect(X + 1, Y - 3, 1, 6); x.fillRect(X - 2, Y - 0.5, 4, 1); }
    glows.push([X, Y, 9, col]);
  };
  const pillar = (X, base, h, w, broken) => {
    const top = base - h;
    R(x, X - w / 2, top, w, h, '#1a1428'); R(x, X - w / 2, top, w * 0.3, h, '#241c36'); R(x, X + w * 0.25, top, w * 0.25, h, '#100c1c');
    for (let k = 0; k < h; k += 14) R(x, X - w / 2, top + k, w, 1, '#0c0a16');
    if (!broken) { R(x, X - w / 2 - 3, top - 4, w + 6, 5, '#221a32'); R(x, X - w / 2 - 3, top - 4, w + 6, 1, '#2e2442'); }
    else P(x, [[X - w / 2, top], [X - w / 4, top - 6], [X, top - 2], [X + w / 4, top - 7], [X + w / 2, top]], '#1a1428');
    // corruption creeping up it
    L(x, [[X - w / 2 + 1, base], [X - w / 4, base - h * 0.4], [X + w / 4, base - h * 0.55]], '#2a0838', 1.6);
    for (let k = 0; k < 2 + Math.floor(h / 40); k++) runeGlyph(X + (r() - 0.5) * w * 0.4, top + 10 + r() * (h - 20), r() < 0.5 ? '#c25cff' : '#ff3a4a');
  };
  const arch = (X, base, span, h) => {
    pillar(X - span / 2, base, h, 12, false); pillar(X + span / 2, base, h, 12, false);
    x.strokeStyle = '#1a1428'; x.lineWidth = 9; x.beginPath(); x.arc(X, base - h, span / 2, Math.PI, TAU); x.stroke();
    x.strokeStyle = '#241c36'; x.lineWidth = 2; x.beginPath(); x.arc(X, base - h, span / 2 + 3, Math.PI, TAU); x.stroke();
    for (let k = 0; k < 5; k++) { const a = Math.PI + (k + 0.5) / 5 * Math.PI; runeGlyph(X + Math.cos(a) * span / 2, base - h + Math.sin(a) * span / 2, k % 2 ? '#ff3a4a' : '#c25cff'); }
  };
  const idol = (X, base) => {   // a toppled stone head with a tentacled face
    E(x, X, base - 16, 18, 16, '#1e1630'); E(x, X - 4, base - 22, 9, 6, '#2a2040');
    for (let k = 0; k < 5; k++) limb(x, curl(X - 8 + k * 4, base - 8, Math.PI / 2 + (k - 2) * 0.3, 12, (k - 2) * -0.4, 5), 3, 1, '#16101e');
    C(x, X - 6, base - 18, 2, '#0a0410'); C(x, X + 6, base - 18, 2, '#0a0410');
    glows.push([X - 6, base - 18, 7, '#ff3a4a']); glows.push([X + 6, base - 18, 7, '#ff3a4a']);
    R(x, X - 6.5, base - 18.5, 1, 1, '#ff3a4a'); R(x, X + 5.5, base - 18.5, 1, 1, '#ff3a4a');
  };
  if (id === 'abyss3') {
    for (const [X, h] of [[300, 130], [640, 150], [1010, 120], [1330, 170], [1650, 150]]) { const b = groundAt(X); if (r() < 0.5) arch(X, b, 70, h * 0.6); else pillar(X, b, h, 18, r() < 0.4); }
    for (const X of [520, 1180, 1500]) idol(X, groundAt(X));
  }
  if (id === 'abyss4') {
    for (let X = 120; X < 1800; X += 160 + r() * 60) { const b = 520; if (r() < 0.4) arch(X + 40, b, 80, 90 + r() * 40); else pillar(X, b, 110 + r() * 90, 20, r() < 0.35); }
    for (const X of [600, 1400]) idol(X, 520);
  }
  if (id === 'abyss5') {
    for (const [X, h] of [[44, 190], [600, 190]]) pillar(X, M.floorY, h, 26, true);
  }
  if (id === 'abyss2') {
    for (const X of [1220, 1600]) pillar(X, groundAt(X), 60 + r() * 30, 14, true);
  }

  // ---- the ground: one profile across all the pieces, filled down to the bottom
  if (theme !== 'bubble') {
    const prof = [];
    for (const p of pieces) { prof.push([p[0], p[2]]); prof.push([p[1], p[2]]); }
    x.beginPath(); x.moveTo(pieces[0][0], H);
    for (let i = 0; i < prof.length; i++) {
      const [X, Y] = prof[i];
      if (i % 2 === 0 && i > 0) { const [px, py] = prof[i - 1]; for (let k = 1; k < 4; k++) x.lineTo(px + (r() - 0.5) * 3, py + (Y - py) * k / 4); }
      x.lineTo(X, Y);
    }
    x.lineTo(pieces[pieces.length - 1][1], M.h + 10); x.lineTo(pieces[0][0], M.h + 10); x.closePath();
    const gg = x.createLinearGradient(0, Math.min(...pieces.map(p => p[2])), 0, M.h);
    gg.addColorStop(0, rock[2]); gg.addColorStop(0.3, rock[1]); gg.addColorStop(1, rock[0]);
    x.fillStyle = gg; x.fill();
    // strata, stones and bones inside the rock
    x.save(); x.clip();
    for (let i = 0; i < M.w * M.h / 900; i++) { const X = r() * M.w, Y = r() * M.h; R(x, X, Y, 2 + r() * 6, 1, rock[0]); }
    for (let i = 0; i < M.w / 30; i++) { const X = r() * M.w, Y = groundAt(X) + 10 + r() * 100; E(x, X, Y, 2 + r() * 4, 1.5 + r() * 2, rock[2]); }
    for (let i = 0; i < M.w / 120; i++) { const X = r() * M.w, Y = groundAt(X) + 14 + r() * 60; L(x, [[X, Y], [X + 8, Y + 1]], K.boneD, 1.4); C(x, X, Y, 1.2, K.boneD); C(x, X + 8, Y + 1, 1.2, K.boneD); }
    // abyssal veins that grow thicker the deeper you go
    for (let i = 0; i < M.w / (deep > 0.6 ? 40 : 80); i++) { let X = r() * M.w, Y = groundAt(X) + 2; const pts = [[X, Y]]; for (let k = 0; k < 6; k++) { X += (r() - 0.5) * 14; Y += 4 + r() * 10; pts.push([X, Y]); } L(x, pts, '#2a0838', 1 + deep * 1.5); if (r() < 0.4) L(x, pts, '#5a1478', 0.5); }
    x.restore();
    // a crust on every top edge: silt, crimson-black on land
    for (const p of pieces) {
      const land = M.sea ? (p[2] < (M.sea.surface ?? -1e9) || p[0] < M.sea.x0) : true;
      const top = land ? ['#3a0e1c', '#5a1426'] : sand;
      R(x, p[0], p[2], p[1] - p[0], 3, top[0]); R(x, p[0], p[2], p[1] - p[0], 1, top[1]);
      for (let X = p[0] + 2; X < p[1] - 2; X += 3 + r() * 6) R(x, X, p[2] - (r() < 0.3 ? 1 : 0), 1 + r() * 2, 1, top[1]);
    }
    // corruption goo, shells, bones, pebbles on the surface
    for (const p of pieces) {
      const len = p[1] - p[0];
      for (let i = 0; i < len / 40; i++) {
        const X = p[0] + 6 + r() * (len - 12), Y = p[2];
        const kind = r();
        if (kind < 0.3) { E(x, X, Y + 0.5, 6 + r() * 8 * (0.5 + deep), 1.6, '#1a0626'); for (let k = 0; k < 3; k++) C(x, X + (r() - 0.5) * 8, Y - 0.5, 0.8, k % 2 ? '#c25cff' : '#5a1478'); }
        else if (kind < 0.45) { E(x, X, Y - 1, 2.5, 1.6, K.boneD); E(x, X - 0.5, Y - 1.5, 1.2, 0.7, K.bone); }
        else if (kind < 0.6) { E(x, X, Y - 1.5, 3 + r() * 3, 2 + r() * 2, rock[2]); }
        else if (kind < 0.7 && deep > 0.3) { for (let k = 0; k < 4; k++) P(x, [[X + k * 2 - 4, Y], [X + k * 2 - 3, Y - 4 - r() * 6], [X + k * 2 - 2, Y]], k % 2 ? '#7a2aa0' : '#a03ac8'); glows.push([X - 1, Y - 4, 8, '#c25cff']); }
      }
    }
  }

  // ---- seaweed and kelp (glowing red bits deep down)
  if (theme === 'abyss') {
    const under = (X, Y) => M.sea && X > M.sea.x0 && X < M.sea.x1 && (M.sea.surface == null || Y > M.sea.surface);
    for (const p of pieces) {
      const len = p[1] - p[0];
      for (let i = 0; i < len / (deep > 0.8 ? 26 : 34); i++) {
        const X = p[0] + 4 + r() * (len - 8), Y = p[2];
        if (!under(X, Y - 2)) continue;
        const h = 10 + r() * (18 + deep * 20), pts = curl(X, Y, -Math.PI / 2 + (r() - 0.5) * 0.4, h, (r() - 0.5) * 1.6, 8);
        const col = deep > 0.6 ? (r() < 0.6 ? '#3a0a14' : '#1e0a22') : (r() < 0.5 ? '#3a0c18' : '#20122a');
        limb(x, pts, 3, 1, col);
        for (let k = 2; k < pts.length; k += 2) if (r() < 0.6) { const q = pts[k]; P(x, [[q[0], q[1]], [q[0] + 3 * (k % 4 ? 1 : -1), q[1] - 2], [q[0], q[1] - 1]], col); }
        if (deep > 0.6 && r() < 0.55) { const q = pts[pts.length - 2]; C(x, q[0], q[1], 1.2, '#ff3a4a'); R(x, q[0] - 0.5, q[1] - 0.5, 1, 1, '#ffb0b8'); glows.push([q[0], q[1], 10, '#ff3a4a']); }
        else if (deep > 0.25 && r() < 0.2) { const q = pts[pts.length - 1]; C(x, q[0], q[1], 1, '#ff4a5a'); glows.push([q[0], q[1], 7, '#ff3a4a']); }
      }
    }
  }

  // ---- the land at the Drowned Shore: dead trees, a broken pier
  if (id === 'abyss1') {
    for (const X of [80, 150, 230]) {
      const h = 50 + r() * 30, pts = [[X, 380], [X + 2, 380 - h * 0.5], [X - 2, 380 - h]];
      limb(x, pts, 5, 2, '#1e0814');
      for (let k = 0; k < 4; k++) { const y0 = 380 - h * (0.4 + k * 0.15), s = k % 2 ? 1 : -1; L(x, [[X, y0], [X + s * 10, y0 - 6], [X + s * 16, y0 - 4]], '#1e0814', 1.2); }
    }
    for (let i = 0; i < 3; i++) R(x, 276 + i * 14, 380, 3, 30 + i * 8, '#2a1410');   // pier posts sinking into the water
    R(x, 268, 378, 44, 3, '#3a1c14'); R(x, 268, 378, 44, 1, '#5a2e1e');
    // a sign
    R(x, 40, 362, 2, 18, '#2a1410'); R(x, 30, 356, 22, 9, '#3a1c14'); R(x, 32, 359, 18, 1, '#8a1020'); R(x, 34, 361, 12, 1, '#8a1020');
  }

  // ---- the boss warning: a rune-carved tablet with a red eye, before the Dreamer's Hollow
  if (M.bossSign) {
    const X = M.bossSign, G = M.floorY;
    P(x, [[X - 11, G], [X - 10, G - 28], [X - 6, G - 32], [X + 6, G - 32], [X + 10, G - 28], [X + 11, G]], '#1a1428');
    R(x, X - 9, G - 29, 18, 2, '#3a3058'); R(x, X - 12, G - 2, 24, 2, '#120c1c');
    E(x, X, G - 18, 6, 3.5, '#ff3a4a'); C(x, X, G - 18, 1.8, '#1a0408');
    runeGlyph(X - 5, G - 8, '#c25cff'); runeGlyph(X + 5, G - 8, '#c25cff');
    glows.push([X, G - 18, 18, '#ff3a4a']);
  }

  // ---- platforms
  for (const [px, py, pw] of M.plats || []) {
    if (id === 'abyss1') {   // floating wreckage: planks, barnacles, a snapped mast
      R(x, px, py, pw, 5, '#2a140e'); R(x, px, py, pw, 1.5, '#4a2418'); R(x, px + 2, py + 5, pw - 4, 2, '#1a0a08');
      for (let X = px + 8; X < px + pw - 4; X += 12 + r() * 6) R(x, X, py + 1, 1, 4, '#140806');
      for (let k = 0; k < pw / 12; k++) { C(x, px + 4 + r() * (pw - 8), py + 6, 1.4, '#3a3040'); }
      if (r() < 0.5) { R(x, px + pw * 0.6, py - 16, 2.5, 16, '#2a140e'); }
    } else if (theme === 'abyss') {   // stone slabs (with runes in the deep) or rock ledges
      const stone = deep > 0.5;
      const top = stone ? '#2a2240' : '#2a1e30', body = stone ? '#1a1428' : '#1a1020';
      P(x, [[px, py], [px + pw, py], [px + pw - 4, py + 8], [px + pw * 0.7, py + 14], [px + pw * 0.3, py + 13], [px + 5, py + 8]], body);
      R(x, px, py, pw, 3, top); R(x, px, py, pw, 1, stone ? '#3a3058' : '#3e2a3e');
      if (stone) { for (let X = px + 10; X < px + pw - 8; X += 22) runeGlyph(X, py + 7, r() < 0.5 ? '#c25cff' : '#ff3a4a'); }
      else { for (let k = 0; k < 3; k++) limb(x, curl(px + 8 + r() * (pw - 16), py + 10, Math.PI / 2, 8 + r() * 10, (r() - 0.5), 5), 2, 1, '#2a0c18'); }
    }
  }

  // ---- the bubble's floor: a thin, glassy, rainbow-sheened film
  if (theme === 'bubble') {
    const y = M.floorY;
    const g = x.createLinearGradient(0, y, 0, M.h);
    g.addColorStop(0, 'rgba(255,255,255,0.9)'); g.addColorStop(0.05, 'rgba(200,230,255,0.55)'); g.addColorStop(0.4, 'rgba(160,140,255,0.25)'); g.addColorStop(1, 'rgba(120,100,220,0.12)');
    x.fillStyle = g; x.fillRect(0, y, M.w, M.h - y);
    const cols = ['#ff7ac8', '#ffd27a', '#7affc8', '#7ad8ff', '#b88aff'];
    for (let X = 0; X < M.w; X += 6) { x.fillStyle = cols[Math.floor(X / 6) % cols.length]; x.globalAlpha = 0.5; x.fillRect(X, y + 1, 6, 1); }
    x.globalAlpha = 1; R(x, 0, y, M.w, 1, '#ffffff');
  }
  x.restore();
  return { canvas: theme === 'bubble' ? c : crisp(c, 60), glows: glows.map(g => [Math.round(g[0] * 2) / 2, Math.round(g[1] * 2) / 2, g[2], g[3]]) };
}

window.ABYSS = { bakeMobs, bakeDreamer, ITEMS, dreamKey, farShore, midShore, farDeep, midDeep, farRuin, midRuin, bubbleFilm, paintMap, DR };
