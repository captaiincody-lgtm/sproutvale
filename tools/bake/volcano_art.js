// Art for Glamrax's volcano (the Godot version only): the four maps inside the volcano (the
// laboratory, the containment bay, the cell block and Glamrax's sanctum) and their five security
// monsters. Runs inside a blank Chromium page (see volcano.mjs). Every function here draws with the 2D
// canvas and returns canvases; volcano.mjs saves them as PNGs under godot/art/volcano. All sprites are
// drawn at 2× the game's world units, like the rest of the game's art. Swap any PNG for your own art,
// keeping its size and anchor.
//
// The two bosses (the Anti-Personnel Mecha Mk II and Glamrax himself) are drawn by the game in code
// (scripts/volcano_draw.gd, scripts/glamrax_draw.gd), since their bodies move part by part.
/* eslint-disable no-unused-vars */
'use strict';

const TAU = Math.PI * 2;
const OUT = '#08060c';

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
const V = {
  steel: '#5a6070', steelD: '#3a3e4a', steelDD: '#22242e', steelL: '#8a92a4', steelLL: '#c4ccd8',
  gun: '#24262e', gunL: '#464a56',
  red: '#ff2a3a', redD: '#8a0a18', redL: '#ffc0c6',
  mana: '#d04aff', manaL: '#f6c8ff', manaD: '#5a1490',
  gold: '#e0b040', goldD: '#8a6418', goldL: '#fff0a0',
  rock: '#2a1e26', rockD: '#150d13', rockL: '#46323e', rockLL: '#5e4452',
  chrome: '#9aa4b8', chromeD: '#4a5266', chromeDD: '#2a3040', chromeL: '#e8f0ff',
  hot: '#ff6a1a', hotL: '#ffd27a', hotD: '#a01a08',
  elec: '#7af0ff', elecL: '#e8ffff',
  dna: '#ff4ad8', dnaL: '#ffc0f4',
};

// an electric arc between two points (jagged, with a bright core)
function arc(x, a, b, seed, col = V.elec, w = 1.6) {
  const r = rng(seed), pts = [a], n = 6;
  for (let i = 1; i < n; i++) { const t = i / n, p = lp(a, b, t); pts.push([p[0] + (r() - 0.5) * 8, p[1] + (r() - 0.5) * 8]); }
  pts.push(b); L(x, pts, col, w); L(x, pts, V.elecL, w * 0.4);
}
// a glowing lens (eye) with a ring
function lens(x, X, Y, r, col = V.red, bright = 1) {
  C(x, X, Y, r + 1.6, V.gun); C(x, X, Y, r, bright > 0.5 ? col : V.redD);
  if (bright > 0.5) { C(x, X, Y, r * 0.55, '#ffffff'); C(x, X - r * 0.35, Y - r * 0.35, r * 0.25, V.redL); }
}

// ---------------- Security Sentinel: a floating armoured sphere with one red eye that sweeps the room
function sentinel(pose, f) {
  return frame(72, 72, x => {
    const cx = 36, cy = 34, R0 = 21;
    if (pose === 'dead') {   // two halves of the shell, sparking
      for (const [X, a] of [[22, -0.5], [50, 0.6]]) {
        x.save(); x.translate(X, 60); x.rotate(a);
        x.fillStyle = V.steelD; x.beginPath(); x.arc(0, 0, 14, Math.PI, TAU); x.closePath(); x.fill();
        x.fillStyle = V.steel; x.beginPath(); x.arc(0, -1, 11, Math.PI * 1.1, Math.PI * 1.6); x.lineTo(0, -1); x.fill();
        R(x, -14, -2, 28, 3, V.gun); x.restore();
      }
      lens(x, 36, 62, 4, V.red, 0); L(x, [[33, 59], [39, 65]], '#ffffff', 0.8);
      arc(x, [26, 54], [44, 50], 3);
      return;
    }
    const squash = pose === 'slam' ? 0.12 : 0;
    // the thruster under it
    P(x, [[cx - 6, cy + R0 - 3], [cx + 6, cy + R0 - 3], [cx + 3, cy + R0 + 4], [cx - 3, cy + R0 + 4]], V.gun);
    const fl = pose === 'hurt' ? 3 : 7 + (f % 2) * 3;
    P(x, [[cx - 3, cy + R0 + 4], [cx + 3, cy + R0 + 4], [cx, cy + R0 + 4 + fl]], '#ff5a2a'); P(x, [[cx - 1.5, cy + R0 + 4], [cx + 1.5, cy + R0 + 4], [cx, cy + R0 + 3 + fl * 0.6]], '#fff0c0');
    // side fins
    for (const s of [-1, 1]) P(x, [[cx + s * (R0 - 3), cy - 8], [cx + s * (R0 + 7), cy - 3], [cx + s * (R0 + 7), cy + 5], [cx + s * (R0 - 3), cy + 9]], s > 0 ? V.steelD : V.gun);
    // spikes out for the slam
    if (pose === 'slam') for (let k = 0; k < 8; k++) { const a = k / 8 * TAU + 0.2, p0 = [cx + Math.cos(a) * (R0 - 2), cy + Math.sin(a) * (R0 - 2) * (1 - squash)], p1 = [cx + Math.cos(a) * (R0 + 9), cy + Math.sin(a) * (R0 + 9) * (1 - squash)], n = [-Math.sin(a) * 3.5, Math.cos(a) * 3.5]; P(x, [[p0[0] + n[0], p0[1] + n[1]], p1, [p0[0] - n[0], p0[1] - n[1]]], V.steelLL); P(x, [p0, p1, [p0[0] - n[0], p0[1] - n[1]]], V.steelD); }
    // the sphere
    x.save(); x.translate(cx, cy); x.scale(1 + squash, 1 - squash);
    const g = x.createRadialGradient(-7, -9, 2, 0, 0, R0); g.addColorStop(0, V.steelLL); g.addColorStop(0.35, V.steelL); g.addColorStop(0.75, V.steel); g.addColorStop(1, V.steelD);
    x.fillStyle = g; x.beginPath(); x.arc(0, 0, R0, 0, TAU); x.fill();
    // plating seams and rivets
    x.strokeStyle = V.steelDD; x.lineWidth = 1;
    for (const a of [-0.9, 0.9]) { x.beginPath(); x.ellipse(0, 0, R0 * Math.abs(Math.sin(a)) + 3, R0, 0, -Math.PI / 2, Math.PI / 2, a < 0); x.stroke(); }
    x.beginPath(); x.ellipse(0, -10, R0 * 0.85, 4, 0, Math.PI, TAU); x.stroke();
    for (let k = 0; k < 6; k++) { const a = Math.PI * 1.1 + k * 0.17; R(x, Math.cos(a) * (R0 - 3), Math.sin(a) * (R0 - 3), 1.5, 1.5, V.steelLL); }
    // the visor band
    x.fillStyle = V.gun; x.beginPath(); x.ellipse(0, 1, R0 + 0.5, 7, 0, 0, TAU); x.fill();
    x.fillStyle = '#3a1016'; x.beginPath(); x.ellipse(0, 1, R0 - 2, 5, 0, 0, TAU); x.fill();
    x.restore();
    // the eye sweeping along the band
    let eo = [-9, -3, 4, 10][f % 4], er = 5, bright = 1;
    if (pose === 'charge') { eo = 9; er = 6.5 + f; }
    if (pose === 'slam') { eo = 6; er = 4; }
    if (pose === 'hurt') { eo = 2; bright = 0; }
    const ex = cx + eo, ey = cy + 1;
    if (pose === 'charge') glowDot(x, ex, ey, 16, '#ff2a3a', 0.9);
    // a red scan line under the eye
    if (pose === 'idle') R(x, ex - 1, ey - 5, 2, 10, 'rgba(255,40,58,0.55)');
    lens(x, ex, ey, er, V.red, bright);
    if (pose === 'hurt') { L(x, [[ex - 4, ey - 4], [ex + 3, ey + 4]], '#ffffff', 1); arc(x, [cx - 14, cy - 8], [cx + 6, cy - 16], 7 + f); }
    // the antenna
    L(x, [[cx - 4, cy - R0 + 1], [cx - 7, cy - R0 - 7]], V.gun, 1.6); C(x, cx - 7, cy - R0 - 7, 1.8, pose === 'hurt' ? V.redD : V.red);
  });
}

// ---------------- the golems: one rig for the Security Golem and the Sentinel-Golem
// (0,0) is under the feet; units are canvas pixels (2× world), a standing golem is about 190 tall
const GL = {
  sec: { a: '#4a4f5c', aD: '#2e313b', aDD: '#1c1e25', aL: '#6e7586', aLL: '#9aa2b4', trim: '#5a3a6a', trimL: '#8a5aa0', core: V.mana, coreL: V.manaL },
  gold: { a: '#3a3d48', aD: '#25272f', aDD: '#16171c', aL: '#5e6474', aLL: '#8e96a8', trim: V.goldD, trimL: V.gold, core: V.red, coreL: V.redL, gold: true },
};
function glPlate(x, pts, col, hi, lo) { P(x, pts, col); if (hi) L(x, [pts[0], pts[1]], hi, 1.4); if (lo) L(x, [pts[pts.length - 2], pts[pts.length - 1]], lo, 1.4); }
function glRifle(x, s, o, recoil, flash, back) {   // a shoulder rifle: pointing forward (right) from the shoulder at s
  const [X, Y] = [s[0] - recoil, s[1] - 18];
  R(x, X - 12, Y, 26, 9, back ? o.aDD : o.aD); R(x, X - 12, Y, 26, 3, back ? o.aD : o.aL);
  R(x, X + 14, Y + 2, 20, 4, V.gun); R(x, X + 14, Y + 2, 20, 1.4, V.gunL);           // the barrel
  R(x, X + 30, Y + 1, 5, 6, V.gun);                                                   // muzzle brake
  R(x, X - 4, Y + 9, 6, 6, V.gun);                                                    // the mount
  R(x, X - 10, Y - 4, 10, 4, o.trim);                                                 // ammo drum
  if (flash) { const fx = X + 36, fy = Y + 4; P(x, [[fx, fy - 6], [fx + 6, fy - 1], [fx + 16, fy], [fx + 6, fy + 1], [fx, fy + 6], [fx + 2, fy]], '#ffe07a'); P(x, [[fx, fy - 3], [fx + 9, fy], [fx, fy + 3]], '#ffffff'); }
}
function glLeg(x, hip, knee, foot, o, back) {
  const c = back ? o.aD : o.a, cl = back ? o.a : o.aL;
  limb(x, [hip, knee], 30, 26, c); limb(x, [knee, foot], 26, 22, c);
  L(x, [lp(hip, knee, 0.15).map((v, i) => v - (i ? 0 : 8)), lp(hip, knee, 0.8).map((v, i) => v - (i ? 0 : 8))], cl, 2);
  glPlate(x, [[knee[0] - 12, knee[1] - 10], [knee[0] + 14, knee[1] - 12], [knee[0] + 12, knee[1] + 8], [knee[0] - 10, knee[1] + 9]], back ? o.aDD : o.aD, cl, null);   // knee pad
  C(x, knee[0] + 1, knee[1] - 1, 3, o.trimL);
  // the foot: a heavy armoured boot
  P(x, [[foot[0] - 16, foot[1]], [foot[0] - 13, foot[1] - 14], [foot[0] + 12, foot[1] - 14], [foot[0] + 22, foot[1] - 4], [foot[0] + 22, foot[1]]], back ? o.aDD : o.aD);
  R(x, foot[0] - 14, foot[1] - 14, 28, 3, cl);
}
function glArm(x, sh, el, fist, o, back, open) {
  const c = back ? o.aD : o.a, cl = back ? o.a : o.aL;
  limb(x, [sh, el], 24, 20, c); limb(x, [el, fist], 22, 26, c);
  // mana lines down the forearm
  L(x, [lp(el, fist, 0.1), lp(el, fist, 0.85)], back ? o.trim : o.core, 2);
  C(x, el[0], el[1], 7, back ? o.aDD : o.aD); C(x, el[0], el[1], 3, o.trimL);
  // the fist: a big plated block
  const a = Math.atan2(fist[1] - el[1], fist[0] - el[0]);
  x.save(); x.translate(fist[0], fist[1]); x.rotate(a);
  R(x, -6, -13, 24, 26, back ? o.aDD : o.aD); R(x, -6, -13, 24, 5, cl);
  for (let k = 0; k < 4; k++) R(x, 14, -12 + k * 6.4, 6, 5, back ? o.aD : o.a);
  R(x, 0, 9, 10, 5, back ? o.aD : o.a);   // thumb
  x.restore();
}
function golemRig(o, pose, f) {
  return frame(180, 220, x => {
    const G = 214;
    let bx = 90, by = 0, lean = 0, eye = 1, recoil = [0, 0], flash = [false, false], thrust = 0;
    let hipB = [80, 132], hipF = [100, 132], footB = [72, G], footF = [106, G], kneeB = [74, 172], kneeF = [104, 172];
    let shB = [64, 72], shF = [116, 72], elB = [54, 104], elF = [124, 104], fiB = [58, 132], fiF = [128, 130];
    if (pose === 'idle') { by = f; elB = [54, 104 + f]; elF = [124, 104 + f]; fiB = [58, 132 + f]; fiF = [128, 130 + f]; }
    if (pose === 'walk') {
      const p = f * Math.PI / 2, s = Math.sin(p), c = Math.cos(p);
      by = -Math.abs(s) * 3;
      footF = [106 + s * 14, G - (c > 0 ? c * 10 : 0)]; kneeF = [108 + s * 8, 170 - (c > 0 ? c * 6 : 0)];
      footB = [72 - s * 14, G - (c < 0 ? -c * 10 : 0)]; kneeB = [72 - s * 6, 170 - (c < 0 ? -c * 6 : 0)];
      elB = [54 + s * 4, 104]; fiB = [60 + s * 8, 132]; elF = [124 - s * 4, 104]; fiF = [128 - s * 8, 130];
    }
    if (pose === 'fire') { recoil = [f === 0 ? 4 : 0, f === 1 ? 4 : 0]; flash = [f === 0, f === 1]; by = 1; }
    if (pose === 'wind') { lean = -0.1; elF = [140, 70]; fiF = [118, 46]; elB = [60, 100]; fiB = [76, 120]; by = 2; }
    if (pose === 'punch') { lean = 0.12; elF = [148, 96]; fiF = [172, 98]; elB = [52, 100]; fiB = [44, 122]; footF = [118, G]; kneeF = [116, 172]; }
    if (pose === 'dash') { lean = 0.32; elF = [150, 92]; fiF = [174, 92]; elB = [50, 90]; fiB = [38, 104]; footF = [128, G - 10]; kneeF = [124, 166]; footB = [50, G - 20]; kneeB = [62, 172]; thrust = 1; }
    if (pose === 'laser') { lean = -0.05; elF = [128, 100]; fiF = [134, 126]; }
    if (pose === 'hurt') { lean = -0.14; eye = 0; elF = [130, 90]; fiF = [144, 110]; elB = [50, 92]; fiB = [40, 110]; }
    if (pose === 'dead') {
      // collapsed in a heap, the core flickering out
      P(x, [[30, G], [36, G - 30], [70, G - 44], [120, G - 40], [150, G - 22], [156, G]], o.aD);
      P(x, [[36, G - 30], [70, G - 44], [120, G - 40], [112, G - 34], [70, G - 38]], o.aL);
      C(x, 92, G - 24, 9, o.aDD); C(x, 92, G - 24, 5, o.trim);
      R(x, 120, G - 18, 34, 8, V.gun); R(x, 152, G - 16, 10, 4, V.gun);   // a rifle torn loose
      E(x, 44, G - 8, 14, 9, o.aD); R(x, 130, G - 50, 20, 22, o.aD);
      if (o.gold) { C(x, 60, G - 46, 12, V.steelD); lens(x, 64, G - 46, 4, V.red, 0); } else { R(x, 52, G - 52, 22, 14, o.aD); R(x, 56, G - 46, 14, 3, V.redD); }
      arc(x, [80, G - 30], [104, G - 44], 9, o.core);
      return;
    }
    x.save(); x.translate(90, 130); x.rotate(lean); x.translate(-90, -130 + by);
    // back thrusters (the Sentinel-Golem flies at you)
    if (o.gold) {
      for (const X of [52, 66]) { R(x, X - 7, 70, 14, 34, o.aDD); R(x, X - 7, 70, 14, 4, o.trimL); P(x, [[X - 6, 104], [X + 6, 104], [X + 4, 110], [X - 4, 110]], V.gun);
        const fl = thrust ? 26 + f * 4 : 6; P(x, [[X - 5, 110], [X + 5, 110], [X, 110 + fl]], '#ff6a2a'); P(x, [[X - 2.5, 110], [X + 2.5, 110], [X, 110 + fl * 0.6]], '#fff0c0'); }
    }
    glRifle(x, shB, o, recoil[0], flash[0], true);
    glArm(x, shB, elB, fiB, o, true);
    glLeg(x, hipB, kneeB, footB, o, true);
    // the torso: a broad armoured chest over a narrow waist
    glPlate(x, [[70, 120], [110, 120], [114, 140], [66, 140]], o.aD, null, null);                     // waist
    R(x, 68, 128, 44, 6, o.aDD); for (let k = 0; k < 5; k++) R(x, 70 + k * 9, 129, 6, 4, o.trim);       // belt
    glPlate(x, [[52, 60], [128, 60], [136, 76], [124, 122], [56, 122], [46, 76]], o.a, o.aLL, null);
    P(x, [[60, 66], [120, 66], [126, 80], [116, 114], [64, 114], [54, 80]], o.aD);
    P(x, [[64, 70], [116, 70], [120, 82], [90, 88], [60, 82]], o.aL);
    // the mana core in the chest, and conduits
    for (const [a, b] of [[[90, 96], [66, 74]], [[90, 96], [114, 74]], [[90, 96], [70, 112]], [[90, 96], [110, 112]]]) { L(x, [a, b], o.trim, 3); L(x, [a, b], o.core, 1.2); }
    C(x, 90, 96, 11, o.aDD); C(x, 90, 96, 8, o.core); C(x, 90, 96, 4, o.coreL); C(x, 87, 93, 1.6, '#ffffff');
    // Glamrax's mark stamped on the chest: a little double helix
    for (let k = 0; k < 7; k++) { const yy = 74 + k * 2.4, w = Math.sin(k * 0.9) * 5; R(x, 100 + w, yy, 1.6, 1.6, V.dna); R(x, 100 - w, yy, 1.6, 1.6, V.dnaL); }
    // the pauldrons
    for (const [s, back] of [[shB, true], [shF, false]]) {
      glPlate(x, [[s[0] - 18, s[1] - 2], [s[0] - 8, s[1] - 16], [s[0] + 12, s[1] - 16], [s[0] + 20, s[1] - 2], [s[0] + 14, s[1] + 12], [s[0] - 14, s[1] + 12]], back ? o.aD : o.a, back ? o.a : o.aLL, o.aDD);
      R(x, s[0] - 12, s[1] + 2, 24, 3, o.trimL);
    }
    // the head
    if (o.gold) {
      // a Sentinel's sphere in place of a head, gold-banded
      const hx = 92, hy = 46, hr = 16;
      const g = x.createRadialGradient(hx - 5, hy - 6, 2, hx, hy, hr); g.addColorStop(0, V.steelLL); g.addColorStop(0.5, V.steel); g.addColorStop(1, V.steelD);
      x.fillStyle = g; x.beginPath(); x.arc(hx, hy, hr, 0, TAU); x.fill();
      x.fillStyle = V.gold; x.beginPath(); x.ellipse(hx, hy + 1, hr + 0.5, 5.5, 0, 0, TAU); x.fill();
      x.fillStyle = '#3a1016'; x.beginPath(); x.ellipse(hx, hy + 1, hr - 2, 3.6, 0, 0, TAU); x.fill();
      if (pose === 'laser') glowDot(x, hx + 7, hy + 1, 18, '#ff2a3a', 0.9);
      lens(x, hx + 7, hy + 1, pose === 'laser' ? 6 : 4, V.red, eye);
      for (const s of [-1, 1]) P(x, [[hx + s * 12, hy - 10], [hx + s * 18, hy - 22], [hx + s * 15, hy - 8]], V.gold);   // gold crest fins
    } else {
      P(x, [[78, 56], [80, 34], [88, 28], [104, 30], [108, 40], [106, 58]], o.aD);
      P(x, [[80, 36], [88, 30], [104, 32], [100, 36], [84, 38]], o.aL);
      R(x, 86, 42, 22, 6, V.gun);
      if (eye > 0.5) { R(x, 88, 43, 19, 4, V.red); R(x, 98, 43, 7, 2, '#ffd0d4'); } else R(x, 88, 43, 19, 4, V.redD);
      P(x, [[88, 52], [106, 52], [104, 58], [90, 58]], o.aDD); for (let k = 0; k < 4; k++) R(x, 90 + k * 4, 53, 2, 4, o.aD);   // the grille
    }
    glLeg(x, hipF, kneeF, footF, o, false);
    glArm(x, shF, elF, fiF, o, false);
    glRifle(x, shF, o, recoil[1], flash[1], false);
    // gold trim on the Sentinel-Golem's front plates
    if (o.gold) { L(x, [[52, 60], [128, 60]], V.gold, 2); L(x, [[shF[0] - 18, shF[1] - 2], [shF[0] - 8, shF[1] - 16], [shF[0] + 12, shF[1] - 16]], V.goldL, 1.4); }
    x.restore();
    if (pose === 'punch' || pose === 'dash') for (const [X, Y] of [[176, 80], [178, 116], [168, 70], [170, 126]]) L(x, [[X - 18, Y], [X - 4, Y]], 'rgba(255,255,255,0.8)', 1.4);
  });
}
const secgolem = (pose, f) => golemRig(GL.sec, pose, f);
const sentgolem = (pose, f) => golemRig(GL.gold, pose, f);

// ---------------- Security Dog: a robot hound with a metal jaw and a shock collar
function dog(pose, f) {
  return frame(100, 64, x => {
    const G = 60;
    const steel = V.steel, dark = V.gun, mid = V.steelD, hi = V.steelL;
    if (pose === 'dead') {
      // on its side, legs stiff, sparking
      P(x, [[22, G - 4], [26, G - 14], [64, G - 16], [72, G - 6], [70, G]], mid);
      R(x, 28, G - 15, 34, 3, hi);
      for (const X of [30, 40, 56, 64]) L(x, [[X, G - 14], [X + 6, G - 26]], dark, 3);
      P(x, [[70, G - 4], [76, G - 14], [92, G - 12], [94, G - 4]], mid); R(x, 82, G - 10, 3, 2, V.redD);
      arc(x, [40, G - 18], [60, G - 22], 5);
      return;
    }
    let by = 0, lean = 0, jaw = 0.1, legs = null, head = [80, 22], tail = -0.6;
    // legs: [hip, knee, paw] ×4 (back-far, front-far, back-near, front-near)
    const std = [[[32, 36], [28, 46], [30, G]], [[66, 36], [70, 46], [68, G]], [[36, 36], [32, 46], [36, G]], [[62, 36], [66, 46], [64, G]]];
    legs = std;
    if (pose === 'idle') { by = f; jaw = f ? 0.25 : 0.1; legs = std.map(l => l.map((p, i) => i === 0 ? [p[0], p[1] + f] : p)); }
    if (pose === 'run') {
      const ph = f * Math.PI / 2;
      by = -Math.abs(Math.sin(ph)) * 3; lean = Math.sin(ph) * 0.06;
      legs = std.map((l, i) => { const s = Math.sin(ph + (i % 2 ? Math.PI : 0) + (i > 1 ? 0.6 : 0)); const c = Math.cos(ph + (i % 2 ? Math.PI : 0) + (i > 1 ? 0.6 : 0)); return [l[0], [l[1][0] + s * 6, l[1][1] - Math.max(0, c) * 4], [l[2][0] + s * 12, G - Math.max(0, c) * 8]]; });
      tail = -0.3 + Math.sin(ph) * 0.3;
    }
    if (pose === 'pounce') { lean = -0.18; by = -6; jaw = 0.7; head = [84, 18]; legs = [[[32, 36], [20, 40], [8, 44]], [[66, 36], [80, 40], [94, 36]], [[36, 36], [24, 42], [12, 48]], [[62, 36], [76, 42], [92, 42]]]; tail = 0.2; }
    if (pose === 'pin') { lean = 0.28; by = 6; jaw = f ? 0.5 : 0.15; head = [84, 34]; legs = [[[32, 36], [26, 48], [24, G]], [[66, 36], [74, 46], [80, G]], [[36, 36], [30, 48], [28, G]], [[62, 36], [72, 48], [76, G]]]; tail = -0.9; }
    if (pose === 'hurt') { lean = -0.15; jaw = 0.4; head = [76, 20]; }
    x.save(); x.translate(50, 40); x.rotate(lean); x.translate(-50, -40 + by);
    const leg = (l, near) => { limb(x, [l[0], l[1]], near ? 7 : 6, 5, near ? mid : dark); limb(x, [l[1], l[2]], 5, 3, near ? mid : dark); C(x, l[1][0], l[1][1], 2.6, near ? hi : mid); R(x, l[2][0] - 3, l[2][1] - 2, 7, 2.5, dark); };
    leg(legs[0], false); leg(legs[1], false);
    // the tail: a whip antenna with a red tip
    const tp = [24 + Math.cos(Math.PI + tail) * 14, 30 + Math.sin(Math.PI + tail) * 14];
    L(x, [[26, 30], tp], dark, 2); C(x, tp[0], tp[1], 1.6, V.red);
    // the body: segmented plates on a spine, a glowing power cell
    P(x, [[24, 26], [34, 20], [66, 18], [74, 24], [72, 38], [60, 42], [34, 42], [24, 36]], steel);
    P(x, [[26, 26], [34, 21], [66, 19], [70, 22], [40, 25]], hi);
    for (const X of [38, 48, 58]) L(x, [[X, 20], [X - 2, 41]], dark, 1);
    R(x, 40, 32, 18, 5, dark); R(x, 42, 33, 14, 3, V.elec); R(x, 44, 33, 4, 1, '#ffffff');
    P(x, [[34, 42], [60, 42], [56, 46], [38, 46]], mid);   // belly plate
    // the neck and head: a long armoured snout
    const H = head;
    limb(x, [[66, 26], [H[0] - 4, H[1] + 6]], 12, 9, mid);
    R(x, 64, 26, 10, 4, V.elec);   // the shock collar
    for (let k = 0; k < 3; k++) R(x, 65 + k * 3.5, 25, 2, 6, dark);
    x.save(); x.translate(H[0], H[1]);
    P(x, [[-8, -6], [2, -8], [16, -4], [16, 0], [-6, 4]], steel);                          // skull and upper jaw
    P(x, [[-8, -6], [2, -8], [12, -5], [0, -4]], hi);
    x.save(); x.translate(-4, 2); x.rotate(jaw);
    P(x, [[0, 0], [18, -1], [17, 3], [2, 5]], mid);                                        // the lower jaw
    for (let k = 0; k < 4; k++) P(x, [[4 + k * 3.5, -0.5], [5.5 + k * 3.5, -3], [7 + k * 3.5, -0.5]], '#e8eef8');
    x.restore();
    for (let k = 0; k < 4; k++) P(x, [[3 + k * 3.5, 1], [4.5 + k * 3.5, 3.5], [6 + k * 3.5, 1]], '#e8eef8');   // upper teeth
    P(x, [[-6, -6], [-10, -16], [-2, -8]], dark); P(x, [[-1, -7], [-3, -17], [4, -8]], mid);   // ears
    R(x, 2, -5, 5, 2.4, V.red); R(x, 4, -5, 2, 1, '#ffd0d4');                             // the eye
    R(x, 15, -4, 2, 2, dark);
    x.restore();
    if (pose === 'pin') { arc(x, [H[0] + 8, H[1] + 4], [H[0] + 2, H[1] + 24], 11 + f); arc(x, [62, 28], [74, 50], 21 + f); }
    leg(legs[2], true); leg(legs[3], true);
    x.restore();
  });
}

// ---------------- Ferro-Slime: a blob of living ferrofluid; spikes when it charges, red-hot when it burns
function ferro(pose, f) {
  return frame(64, 48, x => {
    const G = 44;
    let w = 22, h = 22, spikes = 3, hot = 0, elec = 0;
    if (pose === 'idle') { w = 22 + f * 1.5; h = 21 - f * 1.5; }
    if (pose === 'hop') { if (f === 0) { w = 26; h = 15; } else { w = 17; h = 30; } }
    if (pose === 'hot') { hot = 1; w = 22 + f; h = 21 - f; spikes = 4; }
    if (pose === 'spark') { elec = 1; spikes = 7; w = 21; h = 22 + f * 2; }
    if (pose === 'hurt') { w = 25; h = 17; spikes = 0; }
    if (pose === 'dead') {
      E(x, 32, G - 2, 24, 4, V.chromeDD); E(x, 30, G - 3, 18, 2.4, V.chromeD); E(x, 24, G - 4, 6, 1.2, V.chromeL);
      for (const [X, s] of [[12, 2.5], [52, 2], [44, 1.6]]) C(x, X, G - 2, s, V.chromeD);
      return;
    }
    const body = [[32 - w, G], [32 - w + 2, G - h * 0.5], [32 - w * 0.6, G - h * 0.9], [32, G - h], [32 + w * 0.6, G - h * 0.9], [32 + w - 2, G - h * 0.5], [32 + w, G]];
    // ferrofluid spikes standing up off its back
    const r = rng(7 + f);
    for (let k = 0; k < spikes; k++) {
      const t = spikes === 1 ? 0.5 : k / (spikes - 1), a = -Math.PI / 2 + (t - 0.5) * 1.8, bx = 32 + Math.cos(a) * w * 0.7, byy = G - h * 0.5 + Math.sin(a) * h * 0.55, l = (elec ? 12 : 6) + r() * 4;
      P(x, [[bx - 3, byy + 2], [bx + Math.cos(a) * l, byy + Math.sin(a) * l], [bx + 3, byy + 2]], hot ? V.hotD : V.chromeDD);
    }
    S(x, body, hot ? V.hotD : V.chromeDD);
    // chrome shading: a dark base, a bright rim, reflections of the lab's lights
    const g = x.createLinearGradient(0, G - h, 0, G);
    if (hot) { g.addColorStop(0, V.hotL); g.addColorStop(0.4, V.hot); g.addColorStop(1, V.hotD); }
    else { g.addColorStop(0, V.chromeL); g.addColorStop(0.35, V.chrome); g.addColorStop(0.7, V.chromeD); g.addColorStop(1, V.chromeDD); }
    x.fillStyle = g; smooth(x, body.map(p => [32 + (p[0] - 32) * 0.92, G - (G - p[1]) * 0.94])); x.fill();
    E(x, 32 - w * 0.35, G - h * 0.7, w * 0.25, h * 0.12, hot ? '#fff4d0' : '#ffffff', -0.3);
    E(x, 32 + w * 0.3, G - h * 0.3, w * 0.12, h * 0.06, hot ? V.hotL : V.chromeL);
    if (!hot) L(x, [[32 - w * 0.7, G - 4], [32 + w * 0.7, G - 4]], V.dna, 1);   // a magenta glint off the floor
    // two little glowing eyes
    const ey = G - h * 0.55;
    for (const k of [-1, 1]) { R(x, 36 + k * 5 - 1, ey - 1.5, 3, 3, hot ? '#ffffff' : V.gun); R(x, 36 + k * 5, ey - 1, 1.5, 2, hot ? V.hotL : V.elec); }
    if (elec) { arc(x, [32 - w, G - h * 0.4], [32 - 4, G - h - 8], 31 + f); arc(x, [32 + w, G - h * 0.4], [32 + 6, G - h - 10], 41 + f); }
    if (hot) for (let k = 0; k < 4; k++) { const X = 20 + k * 8; L(x, [[X, G - h - 3], [X + 2, G - h - 9], [X - 1, G - h - 14]], 'rgba(255,200,120,0.7)', 1); }
  });
}

// ------------------------------------------------------------------ sets
// anchor: where the feet (or the bottom of the body) sit in a frame, in pixels
const SETS = {
  sentinel: { w: 72, h: 72, ax: 36, ay: 64, draw: sentinel, keys: { idle: 4, charge: 2, slam: 1, hurt: 2, dead: 1 } },
  secgolem: { w: 180, h: 220, ax: 90, ay: 214, draw: secgolem, keys: { idle: 2, walk: 4, fire: 2, wind: 1, punch: 1, hurt: 1, dead: 1 } },
  sentgolem: { w: 180, h: 220, ax: 90, ay: 214, draw: sentgolem, keys: { idle: 2, walk: 4, fire: 2, wind: 1, punch: 1, dash: 2, laser: 1, hurt: 1, dead: 1 } },
  dog: { w: 100, h: 64, ax: 50, ay: 60, draw: dog, keys: { idle: 2, run: 4, pounce: 1, pin: 2, hurt: 1, dead: 1 } },
  ferro: { w: 64, h: 48, ax: 32, ay: 44, draw: ferro, keys: { idle: 2, hop: 2, hot: 2, spark: 2, hurt: 1, dead: 1 } },
};
const FIRST = { sentinel: 'idle', secgolem: 'idle', sentgolem: 'idle', dog: 'idle', ferro: 'idle' };
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
  residue_sentinel: icon(x => { R(x, 1, 1, 7, 7, '#3a3e4a'); R(x, 2, 2, 5, 5, '#22242e'); R(x, 3, 3, 3, 3, '#ff2a3a'); R(x, 3, 3, 1, 1, '#ffffff'); R(x, 5, 1, 1, 3, '#c4ccd8'); R(x, 6, 4, 1, 1, '#c4ccd8'); }),
  residue_secgolem: icon(x => { R(x, 3, 0, 3, 9, '#5a3a6a'); R(x, 4, 0, 1, 9, '#d04aff'); R(x, 1, 3, 7, 3, '#4a4f5c'); R(x, 2, 4, 5, 1, '#f6c8ff'); R(x, 0, 4, 1, 1, '#d04aff'); R(x, 8, 4, 1, 1, '#d04aff'); }),
  residue_sentgolem: icon(x => { R(x, 1, 1, 7, 7, '#8a6418'); R(x, 2, 2, 5, 5, '#e0b040'); R(x, 3, 3, 3, 3, '#3a1016'); R(x, 4, 4, 1, 1, '#ff2a3a'); R(x, 2, 2, 2, 1, '#fff0a0'); }),
  residue_dog: icon(x => { for (let i = 0; i < 6; i++) R(x, 3 + (i > 3 ? 1 : 0), 1 + i, 3 - (i > 3 ? 1 : 0), 1, '#e8eef8'); R(x, 4, 7, 1, 1, '#e8eef8'); R(x, 2, 0, 5, 2, '#5a6070'); R(x, 3, 2, 1, 4, '#ffffff'); R(x, 6, 0, 1, 1, '#7af0ff'); }),
  residue_ferro: icon(x => { R(x, 3, 1, 3, 1, '#9aa4b8'); R(x, 2, 2, 5, 5, '#9aa4b8'); R(x, 1, 4, 7, 3, '#4a5266'); R(x, 3, 7, 3, 1, '#2a3040'); R(x, 3, 3, 1, 1, '#ffffff'); R(x, 4, 0, 1, 1, '#4a5266'); R(x, 6, 5, 1, 1, '#ff4ad8'); }),
};

// ================================================================== MAPS
// Each map is painted whole (back wall, floor, ceiling, catwalks) at 2×. Things that move or flash
// (the scientists, monitors, alarms, the eyes in the cells, the crystals and their prisoners, Glamrax's
// machine) are drawn by the game on top; `spots` tells it where they are.
function helix(x, X, Y0, Y1, amp, col, col2, phase = 0, w = 1.6) {   // a static double helix (Glamrax's DNA)
  const n = Math.max(8, Math.round((Y1 - Y0) / 3)), a = [], b = [];
  for (let i = 0; i <= n; i++) { const t = i / n, y = lerp(Y0, Y1, t), s = Math.sin(t * TAU * (Y1 - Y0) / 60 + phase); a.push([X + s * amp, y]); b.push([X - s * amp, y]); if (i % 3 === 0) L(x, [[X + s * amp, y], [X - s * amp, y]], col2, 0.7); }
  L(x, a, col, w); L(x, b, col2, w);
}
function rivetRow(x, X0, X1, Y, col, step = 8) { for (let X = X0; X < X1; X += step) R(x, X, Y, 1.5, 1.5, col); }
function hazard(x, X, Y, w, h, step = 6) {   // yellow and black hazard stripes
  x.save(); x.beginPath(); x.rect(X, Y, w, h); x.clip(); R(x, X, Y, w, h, '#e8b81a');
  for (let k = -h; k < w + h; k += step * 2) P(x, [[X + k, Y + h], [X + k + h, Y], [X + k + h + step, Y], [X + k + step, Y + h]], '#1a1418');
  x.restore();
}
function paintMap(id, M) {
  const W = M.w * 2, H = M.h * 2, c = cv(W, H), x = g2(c), r = rng(id.length * 131 + M.w), glows = [], spots = {};
  x.save(); x.scale(2, 2);
  const G = M.floorY, CY = M.ceilY;
  const glow = (X, Y, rr, col) => glows.push([X, Y, rr, col]);
  const spot = (k, v) => { (spots[k] = spots[k] || []).push(v); };
  const rockBlob = (X, Y, s, cols, seed) => { const rr = rng(seed), pts = []; for (let k = 0; k < 7; k++) { const a = k / 7 * TAU + rr() * 0.4; pts.push([X + Math.cos(a) * s * (0.8 + rr() * 0.3), Y + Math.sin(a) * s * (0.55 + rr() * 0.2)]); } P(x, pts, cols[1]); P(x, [pts[4], pts[5], pts[6], [X, Y]], cols[0]); P(x, [pts[0], pts[1], [X, Y]], cols[2]); return pts; };
  const lavaCrack = (X, Y, n, wd = 1.6) => { const pts = [[X, Y]]; for (let k = 0; k < n; k++) { X += (r() - 0.5) * 10; Y += 3 + r() * 7; pts.push([X, Y]); } L(x, pts, '#6a1a10', wd + 1); L(x, pts, '#ff6a2a', wd * 0.6); glow(pts[Math.floor(n / 2)][0], pts[Math.floor(n / 2)][1], 14, '#ff5a1a'); };

  // ================= the back wall: raw volcanic rock, half covered in Glamrax's steel
  const bg = x.createLinearGradient(0, 0, 0, M.h); bg.addColorStop(0, '#0c070c'); bg.addColorStop(0.5, '#1a1018'); bg.addColorStop(1, '#241620');
  x.fillStyle = bg; x.fillRect(0, 0, M.w, M.h);
  for (let i = 0; i < M.w * M.h / 900; i++) rockBlob(r() * M.w, r() * M.h, 5 + r() * 14, [V.rockD, V.rock, V.rockL], i + 1);
  for (let i = 0; i < M.w / 70; i++) lavaCrack(r() * M.w, CY + r() * 60, 6);
  // the steel lining between the ceiling and the floor
  const p0 = CY + 26, p1 = G;
  const panelTone = id === 'volcano4' ? ['#1a1220', '#241a2c', '#2e2238'] : ['#1c1e26', '#262832', '#30333e'];
  for (let X = 0; X < M.w; X += 64) {
    if (id === 'volcano1' && r() < 0.18) continue;   // gaps where the rock shows through
    if (id === 'volcano4') break;                     // the sanctum is bare rock
    R(x, X + 1, p0, 62, p1 - p0, panelTone[1]); R(x, X + 1, p0, 62, 3, panelTone[2]); R(x, X + 1, p0, 2, p1 - p0, panelTone[2]); R(x, X + 61, p0, 2, p1 - p0, panelTone[0]);
    R(x, X + 1, p0 + (p1 - p0) * 0.5, 62, 2, panelTone[0]);
    rivetRow(x, X + 5, X + 60, p0 + 5, '#4a4e5a'); rivetRow(x, X + 5, X + 60, p1 - 7, '#4a4e5a');
  }
  // pipes along the top of the wall
  for (const [Y, w, col, hi] of [[p0 - 8, 5, '#2a2c36', '#4a4e5a'], [p0 - 2, 3, '#3a1a2a', '#6a2a4a']]) { R(x, 0, Y, M.w, w, col); R(x, 0, Y, M.w, 1, hi); for (let X = 30; X < M.w; X += 120) R(x, X, Y - 1, 6, w + 2, '#14141a'); }
  // Glamrax's mark everywhere: his helix painted on the wall in magenta
  for (let X = 90 + r() * 60; X < M.w - 40; X += 260 + r() * 160) {
    if (id === 'volcano4') break;
    helix(x, X, p0 + 14, p1 - 20, 7, '#8a1a70', '#5a1048', r() * 6, 2);
    R(x, X - 14, p1 - 18, 28, 3, '#3a1030');
  }

  // ================= map by map
  if (id === 'volcano1') {
    // computer banks along the back wall: a scientist works at each one (drawn by the game)
    for (let X = 180; X < M.w - 120; X += 330) {
      const dx = X;
      R(x, dx - 34, G - 26, 68, 26, '#1a1c24'); R(x, dx - 34, G - 26, 68, 3, '#3a3e4a'); R(x, dx - 30, G - 20, 60, 2, '#101016');   // the desk
      for (let k = -1; k <= 1; k++) { const mx = dx + k * 20; R(x, mx - 9, G - 50, 18, 14, '#0c0e14'); R(x, mx - 8, G - 49, 16, 12, '#0a2a2a'); R(x, mx - 1, G - 36, 2, 10, '#2a2c36'); spot('monitor', [mx, G - 43]); glow(mx, G - 43, 16, '#3af0c8'); }
      for (let k = 0; k < 8; k++) R(x, dx - 28 + k * 7, G - 24, 5, 2, k % 3 ? '#3a3e4a' : '#ff4ad8');   // keyboard and buttons
      spot('scientist', [dx + 8 + (r() < 0.5 ? -26 : 26), G]);
      // a server rack beside it
      R(x, dx + 44, G - 70, 22, 70, '#14161c'); for (let k = 0; k < 9; k++) { R(x, dx + 46, G - 66 + k * 7, 18, 5, '#22242e'); R(x, dx + 48 + (k * 5) % 12, G - 64 + k * 7, 2, 1, k % 2 ? '#3af07a' : '#ff4ad8'); }
    }
    // crystals hanging in the air, each holding a monster; great cables run down to the machines on the floor
    for (let X = 340; X < M.w - 100; X += 330) {
      const cyy = CY + 60 + r() * 30;
      spot('crystal', [X, cyy, Math.floor(r() * 4)]);
      for (const s of [-1, 1]) {
        const base = [X + s * 26, G];
        L(x, [[X + s * 6, cyy + 30], [X + s * 16, cyy + 60], base], '#0e0e14', 5); L(x, [[X + s * 6, cyy + 30], [X + s * 16, cyy + 60], base], '#3a1a3a', 2.4);
        R(x, base[0] - 9, G - 16, 18, 16, '#22242e'); R(x, base[0] - 9, G - 16, 18, 2, '#4a4e5a'); R(x, base[0] - 4, G - 11, 8, 4, '#d04aff'); glow(base[0], G - 9, 12, '#d04aff');
      }
      L(x, [[X, CY], [X, cyy - 34]], '#0e0e14', 4); L(x, [[X - 1, CY], [X - 1, cyy - 34]], '#3a3e4a', 1);   // the chain it hangs from
      R(x, X - 10, cyy - 36, 20, 6, '#2a2c36');
    }
  }
  if (id === 'volcano2') {
    // the containment bay: blast walls at both ends, a docking cradle for the mecha, hazard markings
    for (const [a, b] of [[0, 22], [M.w - 30, M.w]]) { R(x, a, 0, b - a, M.h, '#1c1e26'); R(x, a === 0 ? b - 3 : a, 0, 3, M.h, '#3a3e4a'); for (let Y = 10; Y < M.h; Y += 22) R(x, a + 2, Y, b - a - 4, 2, '#14161c'); }
    const cx = 330;
    R(x, cx - 60, CY + 20, 120, 12, '#22242e'); R(x, cx - 60, CY + 20, 120, 3, '#4a4e5a');
    for (const s of [-1, 1]) { P(x, [[cx + s * 50, CY + 32], [cx + s * 58, CY + 32], [cx + s * 70, CY + 110], [cx + s * 56, CY + 118]], '#2a2c36'); R(x, cx + s * 64 - 6, CY + 110, 12, 10, '#3a3e4a'); }   // the open clamps
    hazard(x, cx - 60, CY + 32, 120, 5);
    for (let k = 0; k < 6; k++) { const X = 70 + k * 100; hazard(x, X - 20, G - 8, 40, 4); }
    // alarm housings on the wall (the game makes them flash)
    for (const X of [110, 330, 540]) { R(x, X - 7, p0 + 6, 14, 8, '#2a2c36'); E(x, X, p0 + 14, 7, 5, '#5a0a10'); spot('alarm', [X, p0 + 14]); }
    // the locked gate on the right
    const gx = 604;
    R(x, gx - 24, G - 70, 48, 70, '#14161c'); R(x, gx - 28, G - 76, 56, 8, '#3a3e4a'); hazard(x, gx - 28, G - 76, 56, 4); R(x, gx - 28, G - 70, 5, 70, '#3a3e4a'); R(x, gx + 23, G - 70, 5, 70, '#3a3e4a');
    spot('gate', [gx, G]);
    // a viewing window high up: Glamrax's scientists watch the test
    R(x, 150, p0 + 30, 90, 30, '#0c0e14'); R(x, 152, p0 + 32, 86, 26, '#1a2a3a'); R(x, 150, p0 + 30, 90, 2, '#4a4e5a'); spot('window', [195, p0 + 45]);
  }
  if (id === 'volcano3') {
    // a long hallway of cells: dark inside behind thick bars; something looks out of each one (drawn by the game)
    for (let X = 150; X < M.w - 120; X += 150) {
      const top = G - 78;
      R(x, X - 40, top - 6, 80, 84, '#14161c'); R(x, X - 36, top, 72, 78, '#060508');
      const ig = x.createLinearGradient(0, top, 0, G); ig.addColorStop(0, '#0a0608'); ig.addColorStop(1, '#1a0c10'); x.fillStyle = ig; x.fillRect(X - 36, top + 30, 72, 48);
      spot('cell', [X, top + 30]);
      for (let k = 0; k < 9; k++) { const bx = X - 34 + k * 8.5; R(x, bx, top, 3, 78, '#3a3e4a'); R(x, bx, top, 1, 78, '#6a707e'); }
      R(x, X - 38, top + 26, 76, 4, '#2a2c36'); R(x, X - 40, top - 6, 80, 4, '#3a3e4a');
      R(x, X - 8, top - 14, 16, 7, '#22242e'); R(x, X - 6, top - 12, 12, 3, '#3a0a10');   // the cell number plate
      spot('light', [X + 75, CY + 8]);
      // claw marks and scorches round the cells
      for (let k = 0; k < 3; k++) L(x, [[X + 44 + k * 3, top + 10], [X + 50 + k * 3, top + 30]], '#0a0a0e', 1.2);
    }
    for (let X = 40; X < M.w; X += 150) R(x, X, CY - 2, 28, 6, '#2a2c36');   // light housings on the ceiling
  }
  if (id === 'volcano4') {
    // Glamrax's sanctum: carved basalt, magenta runes, the great machine on the right
    for (let i = 0; i < M.w / 30; i++) { const X = r() * (M.w - 160), Y = CY + 30 + r() * (G - CY - 60); lavaCrack(X, Y, 5, 1); }
    // the machine: tanks, coils, a great dial and a tangle of cables
    const mx = 690;
    R(x, mx - 40, CY + 10, 150, G - CY - 10, '#16121c'); R(x, mx - 40, CY + 10, 4, G - CY - 10, '#3a2e44');
    for (const [X, w] of [[mx - 22, 26], [mx + 16, 30], [mx + 56, 24]]) { R(x, X - w / 2, CY + 40, w, G - CY - 60, '#22202c'); R(x, X - w / 2, CY + 40, 3, G - CY - 60, '#3e3a4c'); E(x, X, CY + 40, w / 2, 5, '#3e3a4c'); spot('tank', [X, CY + 50, w, G - CY - 80]); }
    for (let k = 0; k < 8; k++) R(x, mx - 36, CY + 60 + k * 28, 140, 3, '#0c0a10');
    C(x, mx + 20, CY + 110, 26, '#2a2634'); C(x, mx + 20, CY + 110, 22, '#100c14'); spot('dial', [mx + 20, CY + 110]);
    for (let k = 0; k < 6; k++) { const Y = G - 30 - k * 10; R(x, mx - 40, Y, 150, 3, k % 2 ? '#3a1a3a' : '#22202c'); }
    hazard(x, mx - 40, G - 6, 150, 6);
    // carved basalt pillars with burning runes between the crystals
    for (const X of [96, 300, 504]) {
      R(x, X - 14, CY, 28, G - CY, '#140c12'); R(x, X - 14, CY, 5, G - CY, '#2a1e26'); R(x, X + 10, CY, 4, G - CY, '#0a0608');
      for (let k = 0; k < 7; k++) { const Y = CY + 40 + k * 38; R(x, X - 4, Y, 8, 14, '#3a0c30'); R(x, X - 2, Y + 2, 4, 10, '#d04aff'); glow(X, Y + 7, 10, '#d04aff'); }
      R(x, X - 18, G - 14, 36, 14, '#1e141c'); R(x, X - 18, CY + 4, 36, 10, '#1e141c');
    }
    // cables from the machine out to the crystals (the crystals themselves are drawn by the game)
    const sag = (a, b, dip) => { const pts = []; for (let k = 0; k <= 16; k++) { const t = k / 16; pts.push([lerp(a[0], b[0], t), lerp(a[1], b[1], t) + Math.sin(t * Math.PI) * dip]); } return pts; };
    for (let i = 0; i < 5; i++) {
      const X = 150 + i * 105, Y = CY + 70 + (i % 2) * 26; spot('pod', [X, Y]);
      const cab = sag([X + 10, Y + 40], [mx - 40, CY + 120 + i * 26], 40 + i * 6);
      L(x, cab, '#0a080e', 5); L(x, cab, '#5a1a5a', 2); L(x, cab.slice(4, 12), '#8a2a8a', 0.8);
      L(x, [[X, CY], [X, Y - 46]], '#0a080e', 3); L(x, [[X - 1, CY], [X - 1, Y - 46]], '#3a2e44', 1);
    }
    // two tall helices of Glamrax's DNA on either side of the crystals
    helix(x, 40, CY + 20, G - 20, 9, '#8a1a70', '#5a1048', 0, 2.4);
    helix(x, 620, CY + 20, G - 20, 9, '#8a1a70', '#5a1048', 1, 2.4);
    // the piano stands in front of the machine; Glamrax sits at it until you arrive
    spot('piano', [560, G]);
  }

  // ================= the ceiling: rock, cables, hanging lamps
  { const cp = [[0, 0], [M.w, 0]]; for (let X = M.w; X >= 0; X -= 4) cp.push([X, CY - 2 + Math.abs(Math.sin(X * 0.11)) * 4 + r() * 3]); P(x, cp, V.rockD);
    for (let i = 0; i < M.w / 12; i++) rockBlob(r() * M.w, r() * CY, 4 + r() * 8, [V.rockD, V.rock, V.rockL], i + 400);
    R(x, 0, CY - 3, M.w, 3, '#1a1418'); }
  for (let X = 20; X < M.w; X += 40 + r() * 60) { const l = 8 + r() * 26; L(x, [[X, CY], [X + (r() - 0.5) * 30, CY + l * 0.6], [X + (r() - 0.5) * 10, CY + l * 0.2 + 2]], '#0c0c12', 2); }   // dangling cables
  for (let X = 100; X < M.w; X += 200) { L(x, [[X, CY], [X, CY + 14]], '#2a2c36', 1); P(x, [[X - 6, CY + 14], [X + 6, CY + 14], [X + 4, CY + 18], [X - 4, CY + 18]], '#3a3e4a'); R(x, X - 3, CY + 18, 6, 1.5, '#ffd8a0'); glow(X, CY + 22, 30, '#ffb070'); }

  // ================= the floor: a steel deck over basalt with lava in its cracks
  const fg = x.createLinearGradient(0, G, 0, M.h); fg.addColorStop(0, '#2a1e26'); fg.addColorStop(1, '#100a0e');
  x.fillStyle = fg; x.fillRect(0, G, M.w, M.h - G);
  for (let i = 0; i < M.w / 10; i++) rockBlob(r() * M.w, G + 14 + r() * (M.h - G), 3 + r() * 6, [V.rockD, V.rock, V.rockL], i + 900);
  for (let i = 0; i < M.w / 60; i++) lavaCrack(r() * M.w, G + 14, 4, 1.2);
  R(x, 0, G, M.w, 9, '#3a3e4a'); R(x, 0, G, M.w, 2, '#8a92a4'); R(x, 0, G + 2, M.w, 1, '#5a6070'); R(x, 0, G + 8, M.w, 2, '#14161c');
  for (let X = 0; X < M.w; X += 24) { R(x, X, G + 2, 1, 6, '#22242e'); R(x, X + 3, G + 4, 1.4, 1.4, '#6a707e'); }
  for (let X = 60; X < M.w; X += 180 + r() * 100) { R(x, X, G + 1, 30, 7, '#1a1c22'); for (let k = 0; k < 6; k++) R(x, X + 2 + k * 5, G + 2, 2, 5, '#0a0a0e'); glow(X + 15, G + 6, 14, '#ff5a1a'); }   // grates with lava glow beneath
  // ================= catwalks (steel, railings) and, in the sanctum, floating slabs of runed rock
  for (const [px, py, pw] of M.plats || []) {
    if (id === 'volcano4') {
      const under = [[px, py], [px + pw, py], [px + pw - 6, py + 8], [px + pw * 0.7, py + 18], [px + pw * 0.4, py + 22], [px + 8, py + 10]];
      P(x, under, '#2a1e2a'); P(x, [[px, py], [px + pw, py], [px + pw - 4, py + 4], [px + 4, py + 4]], '#4a3a4e');
      R(x, px, py, pw, 1.5, '#8a6aa0'); for (let k = 0; k < 3; k++) { const X = px + 12 + k * (pw - 24) / 2; R(x, X - 1, py + 7, 3, 3, '#d04aff'); glow(X, py + 8, 10, '#d04aff'); }
      continue;
    }
    R(x, px, py, pw, 5, '#3a3e4a'); R(x, px, py, pw, 1.5, '#8a92a4'); R(x, px, py + 5, pw, 2, '#14161c');
    for (let X = px + 4; X < px + pw - 4; X += 8) R(x, X, py + 1.5, 4, 3, '#22242e');   // grating
    for (const X of [px + 6, px + pw - 8]) { R(x, X, py + 7, 2, 10, '#22242e'); }   // struts
    R(x, px, py - 10, pw, 1.2, '#4a4e5a'); for (let X = px; X <= px + pw; X += 16) R(x, X, py - 10, 1.2, 10, '#4a4e5a');   // the railing
    L(x, [[px + pw / 2, py + 7], [px + pw / 2, CY]], '#0e0e14', 1.4);   // hung from the ceiling
  }
  x.restore();
  return { canvas: crisp(c, 60), glows: glows.map(g => [Math.round(g[0] * 2) / 2, Math.round(g[1] * 2) / 2, g[2], g[3]]), spots };
}

window.VOLC = { SETS, bakeMobs, ITEMS, paintMap };
