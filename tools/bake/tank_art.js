// Art for Tank, the fifth hero (the Godot version only): his empty field's cardboard box and the meteor that
// wrecks it, his futuristic house (outside and in), his helper drone and summoned robot, grenade / part icons
// and his weapon effects. Runs inside a blank Chromium page (see tank_world.mjs). Every function here draws
// with the 2D canvas and returns canvases; sprites are drawn at 2× the game's world units like the rest of
// the game's art.
/* eslint-disable no-unused-vars */
'use strict';

const TAU = Math.PI * 2;
const OUT = '#0a0e16';

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
function RR(x, X, Y, w, h, r, col) { x.fillStyle = col; x.beginPath(); x.roundRect(X, Y, w, h, r); x.fill(); }
function ring(x, cx, cy, rx, ry, col, w) { x.strokeStyle = col; x.lineWidth = w; x.beginPath(); x.ellipse(cx, cy, rx, ry, 0, 0, TAU); x.stroke(); }
function limb(x, pts, w0, w1, col) {
  const n = pts.length, Lp = [], Rp = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const d = Math.hypot(dx, dy) || 1; dx /= d; dy /= d;
    const w = (w0 + (w1 - w0) * (i / (n - 1))) / 2;
    Lp.push([pts[i][0] - dy * w, pts[i][1] + dx * w]); Rp.push([pts[i][0] + dy * w, pts[i][1] - dx * w]);
  }
  P(x, Lp.concat(Rp.reverse()), col);
}
function clip(x, shape, draw) { x.save(); shape(); x.clip(); draw(); x.restore(); }
function crisp(c, th = 96) {
  const x = c.getContext('2d'), d = x.getImageData(0, 0, c.width, c.height), a = d.data;
  for (let i = 3; i < a.length; i += 4) a[i] = a[i] < th ? 0 : 255;
  x.putImageData(d, 0, 0); return c;
}
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
function frame(w, h, draw) { const c = cv(w, h), x = g2(c); draw(x); return c; }

// ------------------------------------------------------------------ palette
const T = {
  st0: '#141a22', st1: '#232c38', st2: '#3a4658', st3: '#5c6e84', st4: '#8a9cb2', st5: '#c4d2e2', st6: '#eef4fa',
  bl0: '#0c2a4e', bl1: '#1a62c0', bl2: '#3aa8ff', bl3: '#8ae0ff', bl4: '#e6fbff',
  red: '#ff3a30', redD: '#a01818', or: '#ff8a20', yel: '#ffd84a', wht: '#fff8e0',
  rust0: '#3e2416', rust1: '#6e3e22', rust2: '#9a5a2e', rust3: '#c8824a',
  card0: '#6a4422', card1: '#8e5e30', card2: '#b47c44', card3: '#d29c5e', card4: '#e8bc80',
};

// ================================================================== THE CARDBOARD BOX (72×56, feet at 36,56)
function box() {
  const c = frame(72, 56, x => {
    // back flap standing up, slightly bent
    P(x, [[18, 20], [62, 20], [60, 5], [21, 8]], T.card1);
    P(x, [[21, 8], [60, 5], [60, 8], [22, 11]], T.card2);
    L(x, [[40, 7], [41, 19]], T.card0, 1);
    // the open top: a dark, empty inside
    P(x, [[10, 24], [58, 24], [64, 20], [18, 20]], '#2a1808');
    P(x, [[14, 23], [56, 23], [60, 21], [20, 21]], '#3e2614');
    // a ragged grey blanket hanging over the back edge — somebody slept in it
    P(x, [[26, 21], [40, 21], [38, 26], [33, 24], [29, 27]], '#6a6e78');
    L(x, [[28, 22], [37, 22]], '#8a8e98', 1);
    // right side face (in perspective)
    P(x, [[58, 24], [64, 20], [64, 50], [58, 55]], T.card1);
    L(x, [[61, 24], [61, 52]], T.card0, 1);
    // front face
    R(x, 10, 24, 48, 31, T.card2);
    R(x, 10, 48, 48, 7, T.card1);
    R(x, 10, 24, 48, 2, T.card3);
    // water stain and dents
    E(x, 22, 44, 7, 5, '#9a6a38'); E(x, 21, 43, 5, 3, '#a87440');
    L(x, [[46, 34], [50, 40], [47, 46]], T.card1, 1.2);
    // a torn hole in the front
    P(x, [[40, 42], [46, 40], [49, 45], [45, 50], [39, 48]], '#2a1808');
    L(x, [[40, 42], [46, 40], [49, 45]], T.card4, 1);
    // printed "this side up" arrows and a glass icon
    for (const ax of [16, 26]) { P(x, [[ax, 31], [ax + 3, 27], [ax + 6, 31]], '#5a3618'); R(x, ax + 2, 31, 2, 4, '#5a3618'); }
    R(x, 50, 27, 4, 1, '#5a3618'); P(x, [[50, 27], [54, 27], [52.5, 31], [51.5, 31]], '#5a3618'); R(x, 51.5, 31, 1, 3, '#5a3618'); R(x, 50, 34, 4, 1, '#5a3618');
    // left flap fallen open outward
    P(x, [[10, 24], [18, 20], [7, 10], [1, 15]], T.card3);
    P(x, [[10, 24], [1, 15], [2, 18], [9, 26]], T.card1);
    L(x, [[5, 14], [12, 21]], T.card2, 1);
    // front flap folded down over the face, with a strip of peeling tape
    P(x, [[10, 24], [58, 24], [57, 33], [50, 31], [44, 34], [30, 32], [12, 33]], T.card3);
    R(x, 10, 24, 48, 1, T.card4);
    P(x, [[31, 24], [37, 24], [37, 33], [34, 30], [31, 32]], '#d8b878');
    P(x, [[34, 30], [37, 33], [39, 37], [35, 34]], '#e8cc90');
    // right flap hanging down the side
    P(x, [[58, 24], [64, 20], [71, 30], [65, 35]], T.card2);
    L(x, [[63, 24], [68, 31]], T.card1, 1);
    // corrugated edge
    for (let X = 12; X < 58; X += 3) R(x, X, 54, 1, 1, T.card0);
  });
  return fin(c, '#24140a');
}

// ================================================================== THE WRECKED BOX IN ITS CRATER (180×60, feet at 90,60)
function boxWreck() {
  const c = frame(180, 60, x => {
    const r = rng(77);
    // thrown-up dirt rims and the scorched hollow
    E(x, 30, 62, 32, 16, '#5a3e24'); E(x, 32, 58, 24, 9, '#7a5a34'); E(x, 34, 52, 14, 3, '#8e6e44');
    E(x, 150, 62, 32, 16, '#5a3e24'); E(x, 148, 58, 24, 9, '#7a5a34'); E(x, 146, 52, 14, 3, '#8e6e44');
    E(x, 90, 64, 56, 14, '#2a1a12'); E(x, 90, 64, 42, 10, '#1a100c'); E(x, 90, 64, 26, 6, '#3a1a0c');
    // grass tufts burnt black on the rims
    for (let i = 0; i < 14; i++) { const gx = i < 7 ? 6 + i * 6 : 132 + (i - 7) * 6; L(x, [[gx, 54 + r() * 3], [gx + r() * 3 - 1.5, 49 + r() * 3]], '#1e1610', 1.2); }
    // flying clods
    for (let i = 0; i < 6; i++) C(x, 10 + r() * 160, 30 + r() * 18, 1.5 + r(), '#6a4a2c');
    // flattened, torn cardboard
    P(x, [[34, 52], [78, 46], [82, 53], [70, 57], [38, 58]], T.card2);
    P(x, [[34, 52], [78, 46], [79, 48], [36, 54]], T.card3);
    L(x, [[50, 50], [56, 56]], T.card1, 1); L(x, [[64, 48], [62, 55]], T.card1, 1);
    P(x, [[70, 57], [82, 53], [86, 55], [80, 59]], '#2a1a10');   // charred edge
    P(x, [[104, 54], [138, 50], [140, 57], [108, 59]], T.card1);
    P(x, [[104, 54], [138, 50], [138, 52], [105, 56]], T.card2);
    P(x, [[100, 54], [106, 53], [108, 59], [99, 59]], '#2a1a10');
    // one flap stuck upright in the rim
    P(x, [[122, 52], [134, 32], [141, 35], [130, 55]], T.card3);
    P(x, [[134, 32], [141, 35], [139, 38], [133, 35]], '#2a1a10');
    R(x, 129, 40, 4, 1, '#5a3618'); P(x, [[128, 41], [131, 37], [134, 41]], '#5a3618');
    // a curled strip and bits
    P(x, [[18, 50], [28, 47], [30, 50], [20, 53]], T.card2);
    P(x, [[152, 47], [160, 44], [162, 47], [154, 50]], T.card1);
    // the grey blanket, singed
    P(x, [[84, 56], [96, 54], [100, 58], [86, 59]], '#5a5e68'); R(x, 92, 55, 4, 2, '#2a2a30');
    // the meteor, still glowing, half buried
    E(x, 90, 52, 11, 8, '#2a1a16'); E(x, 88, 50, 8, 5, '#4a3026'); E(x, 86, 48, 4, 2, '#6a4430');
    L(x, [[83, 52], [88, 49], [92, 53], [97, 50]], T.or, 1.4); L(x, [[86, 55], [90, 53]], T.yel, 1);
    // little fires on the cardboard
    const flame = (fx, fy, h) => { P(x, [[fx - 3, fy], [fx - 1, fy - h * 0.6], [fx, fy - h], [fx + 2, fy - h * 0.5], [fx + 3, fy]], '#e0401a'); P(x, [[fx - 1.5, fy], [fx, fy - h * 0.6], [fx + 1.5, fy]], T.yel); };
    flame(74, 52, 9); flame(112, 55, 7); flame(137, 37, 6); flame(24, 50, 5);
    // smoke column
    const puffs = [[90, 40, 8, '#4a4a52'], [95, 30, 7, '#5a5a62'], [88, 21, 6.5, '#6a6a72'], [94, 12, 5.5, '#7a7a82'], [89, 5, 4, '#8a8a92'], [74, 44, 4, '#4a4a52'], [113, 46, 3.5, '#4a4a52']];
    for (const [sx, sy, sr, col] of puffs) { C(x, sx, sy, sr, col); C(x, sx - sr * 0.3, sy - sr * 0.3, sr * 0.55, '#9a9aa2'); }
    // embers
    for (let i = 0; i < 10; i++) R(x, 70 + r() * 40, 14 + r() * 30, 1, 1, i % 2 ? T.or : T.yel);
  });
  return fin(c, '#120806');
}

// ================================================================== THE METEOR (4 frames, 56×56, falling to the lower-right)
function meteor(f) {
  const c = frame(56, 56, x => {
    const r = rng(11 + f * 31), cx = 38, cy = 38;
    const dx = -Math.SQRT1_2, dy = -Math.SQRT1_2, px_ = Math.SQRT1_2, py_ = -Math.SQRT1_2;
    const layer = (len, w0, col, jit) => {
      const Lp = [], Rp = [], n = 9;
      for (let i = 0; i <= n; i++) {
        const t = i / n, w = w0 * Math.pow(1 - t, 0.75) + (r() - 0.5) * jit * (1 - t) * 2, ox = cx + dx * len * t, oy = cy + dy * len * t;
        const wob = Math.sin(t * 9 + f * 1.7) * jit * t;
        Lp.push([ox + px_ * (w + wob), oy + py_ * (w + wob)]); Rp.push([ox - px_ * (w - wob), oy - py_ * (w - wob)]);
      }
      P(x, [[cx - dx * w0 * 0.6, cy - dy * w0 * 0.6]].concat(Lp, Rp.reverse()), col);
    };
    layer(48 + (f % 2) * 3, 12, '#c0281a', 3);
    layer(40 + ((f + 1) % 2) * 3, 9.5, '#ff6a1a', 2.5);
    layer(30 + (f % 2) * 2, 7, '#ffb02a', 2);
    layer(18, 4.5, '#fff0a0', 1);
    // trailing sparks
    for (let i = 0; i < 5; i++) { const t = 0.4 + r() * 0.6, d = (r() - 0.5) * 16; R(x, cx + dx * 50 * t + px_ * d, cy + dy * 50 * t + py_ * d, 1.5, 1.5, i % 2 ? T.yel : T.or); }
    // the rock: lumpy, lit orange from the fire behind it, dark on the leading edge
    const pts = []; for (let i = 0; i < 10; i++) { const a = i / 10 * TAU + f * 0.4, rr = 8 + r() * 2.5; pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); }
    P(x, pts, '#3a2420');
    clip(x, () => { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
      C(x, cx + 4, cy + 4, 8, '#22140f');
      C(x, cx - 4, cy - 4, 6, '#6a3a24'); C(x, cx - 6, cy - 6, 3, '#a85a2a');
      L(x, [[cx - 5, cy + 1], [cx, cy - 1], [cx + 2, cy + 4], [cx + 6, cy + 3]], T.or, 1.3);
      L(x, [[cx - 1, cy - 6], [cx + 1, cy - 2]], T.yel, 1);
      C(x, cx + 3, cy - 3, 1.5, '#1a0e0a'); C(x, cx - 2, cy + 5, 1.2, '#1a0e0a');
    });
  });
  return fin(c, '#2a0a04');
}

// ================================================================== TANK'S HOUSE, OUTSIDE (320×240, door at the bottom-centre)
function houseExterior() {
  const c = frame(320, 240, x => {
    // antenna mast with a blinking tip, and a little dish
    R(x, 214, 8, 3, 46, T.st3); R(x, 214, 8, 1, 46, T.st5);
    for (const yy of [16, 26, 36]) R(x, 209, yy, 13, 2, T.st2);
    C(x, 215.5, 6, 3, T.red); C(x, 215, 5.5, 1.3, '#ffd0c8');
    P(x, [[118, 40], [132, 30], [136, 36], [124, 46]], T.st4); L(x, [[127, 38], [134, 31]], T.st2, 1); R(x, 124, 42, 3, 10, T.st2);
    // solar fins on struts either side of the upper cabin
    const fin_ = (x0, y0, flip) => {
      for (let i = 0; i < 3; i++) {
        const X = x0 + i * 17 * flip, top = y0 - i * 4;
        R(x, X + (flip > 0 ? 7 : -9), top + 10, 2, 92 - top - 10 + 0, T.st2);
        const pts = flip > 0 ? [[X, top + 12], [X + 15, top], [X + 17, top + 3], [X + 2, top + 15]] : [[X, top + 12], [X - 15, top], [X - 17, top + 3], [X - 2, top + 15]];
        P(x, pts, '#1a2a5a');
        clip(x, () => { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath(); }, () => {
          for (let k = 0; k < 4; k++) L(x, [[X + flip * k * 4 + flip * 2, top + 16], [X + flip * k * 4 + flip * 2 + flip * 4, top - 2]], '#3a5aa0', 1);
          L(x, [[X - 20, top + 10 - 2], [X + 20, top - 2 - 2]].map(p => flip > 0 ? p : [2 * X - p[0], p[1]]), '#6a8ad0', 1);
        });
      }
    };
    fin_(44, 66, 1); fin_(276, 66, -1);
    // upper cabin
    RR(x, 100, 48, 120, 50, [22, 22, 4, 4], T.st3);
    RR(x, 100, 48, 120, 8, [22, 22, 0, 0], T.st4);
    R(x, 108, 52, 104, 2, T.st5);
    R(x, 110, 60, 100, 24, T.st1);
    R(x, 112, 62, 96, 20, T.bl0);
    P(x, [[112, 62], [208, 62], [208, 68], [112, 76]], T.bl1);
    for (const sx of [130, 170]) P(x, [[sx, 62], [sx + 8, 62], [sx - 4, 82], [sx - 12, 82]], '#5ab8f0');
    R(x, 159, 62, 2, 20, T.st1);
    R(x, 100, 88, 120, 2, T.bl2); R(x, 100, 88.5, 120, 1, T.bl4);
    // main pod body
    RR(x, 34, 92, 252, 136, [30, 30, 6, 6], T.st3);
    RR(x, 34, 92, 252, 14, [30, 30, 0, 0], T.st4);
    R(x, 50, 96, 220, 2, T.st5);
    R(x, 34, 196, 252, 32, T.st2);
    R(x, 34, 196, 252, 2, T.st4);
    // panel seams and rivets
    for (const sx of [70, 106, 214, 250]) { R(x, sx, 110, 1, 86, T.st2); R(x, sx + 1, 110, 1, 86, T.st4); }
    for (const sx of [42, 78, 114, 206, 242, 278]) for (const sy of [112, 190]) R(x, sx, sy, 2, 2, T.st2);
    // glowing trim band
    R(x, 34, 104, 252, 3, T.bl1); R(x, 34, 105, 252, 1, T.bl3);
    R(x, 34, 194, 252, 2, T.bl1); R(x, 34, 194.5, 252, 1, T.bl3);
    // big windows with reflections
    for (const wx of [52, 196]) {
      RR(x, wx - 2, 118, 76, 48, 6, T.st1);
      RR(x, wx, 120, 72, 44, 5, T.bl0);
      P(x, [[wx, 120], [wx + 72, 120], [wx + 72, 128], [wx, 146]], T.bl1);
      P(x, [[wx + 14, 120], [wx + 24, 120], [wx + 8, 164], [wx - 2, 164]], '#5ab8f0');
      P(x, [[wx + 30, 120], [wx + 34, 120], [wx + 18, 164], [wx + 14, 164]], '#5ab8f0');
      R(x, wx + 35, 120, 2, 44, T.st1);
      R(x, wx, 158, 72, 6, T.st2); R(x, wx, 158, 72, 1, T.st4);   // sill
    }
    // vents and side lamps
    for (let i = 0; i < 4; i++) { R(x, 46, 202 + i * 5, 18, 2, T.st1); R(x, 256, 202 + i * 5, 18, 2, T.st1); }
    // sliding door, centred on the image
    R(x, 136, 154, 48, 74, T.st0);
    R(x, 138, 156, 44, 72, T.bl2); R(x, 140, 158, 40, 70, T.st1);
    R(x, 141, 159, 18, 69, T.st3); R(x, 161, 159, 18, 69, T.st3);
    R(x, 141, 159, 18, 3, T.st4); R(x, 161, 159, 18, 3, T.st4);
    R(x, 159, 159, 2, 69, T.bl3);
    R(x, 145, 168, 10, 22, T.bl0); R(x, 165, 168, 10, 22, T.bl0); R(x, 146, 169, 3, 20, T.bl1); R(x, 166, 169, 3, 20, T.bl1);
    for (let i = 0; i < 4; i++) { R(x, 143, 200 + i * 6, 14, 2, '#e0a020'); R(x, 163, 200 + i * 6, 14, 2, '#e0a020'); R(x, 147 + i * 0, 200 + i * 6, 4, 2, T.st1); R(x, 167, 200 + i * 6, 4, 2, T.st1); }
    P(x, [[154, 148], [166, 148], [160, 152]], T.bl3);   // arrow light over the door
    R(x, 190, 182, 7, 11, T.st0); R(x, 191, 183, 5, 4, T.bl2); R(x, 192, 189, 1, 1, '#5aff8a'); R(x, 194, 189, 1, 1, T.st4);
    for (const lx of [124, 196]) { R(x, lx, 160, 4, 8, T.st1); R(x, lx, 168, 4, 3, T.bl3); }
    // foundation plinth and step
    R(x, 22, 226, 276, 14, T.st1); R(x, 22, 226, 276, 2, T.st3); R(x, 22, 232, 276, 1, T.bl1);
    R(x, 130, 228, 60, 6, T.st3); R(x, 130, 228, 60, 1, T.st5);
    for (let i = 0; i < 9; i++) { R(x, 30 + i * 30, 236, 12, 2, T.st0); }
  });
  return fin(c, OUT);
}

// ================================================================== THE HELPER DRONE (4 tiers × 4 frames, 44×32, facing right)
function rotor(x, hx, hy, f, col, hi, len = 16) {
  const L_ = [len, len * 0.62, len * 0.18, len * 0.62][f % 4];
  R(x, hx - 1, hy, 2, 4, T.st1);
  R(x, hx - L_ / 2, hy - 1, L_, 2, col);
  if (f % 2 === 0) R(x, hx - L_ / 2, hy - 1, L_ / 2, 1, hi);
  else R(x, hx, hy - 1, L_ / 2, 1, hi);
}
function drone(tier, f) {
  const c = frame(44, 32, x => {
    const bob = [0, -1, 0, 1][f];
    x.translate(0, bob);
    if (tier === 0) {   // scrap quadcopter: mismatched plates, one red eye, a dangling wire
      L(x, [[16, 16], [9, 9]], T.st2, 2.5); L(x, [[28, 15], [35, 8]], T.rust1, 2.5);
      rotor(x, 9, 7, f, T.st3, T.st5, 14); rotor(x, 35, 7, f + 1, T.rust2, T.rust3, 14);
      RR(x, 12, 13, 20, 11, 2, T.rust2);
      R(x, 12, 13, 20, 2, T.rust3);
      R(x, 13, 17, 8, 6, T.st3); R(x, 13, 17, 8, 1, T.st4); R(x, 14, 18, 1, 1, T.st1); R(x, 19, 21, 1, 1, T.st1);
      R(x, 22, 20, 7, 3, T.rust1);
      L(x, [[14, 24], [12, 28], [15, 29]], '#c8743a', 1);
      L(x, [[18, 24], [17, 28]], T.st2, 1.5); L(x, [[27, 24], [29, 28]], T.st2, 1.5); R(x, 14, 28, 6, 1.5, T.st2); R(x, 26, 28, 6, 1.5, T.st2);
      C(x, 31, 18, 3.5, T.st1); C(x, 31.5, 18, 2.3, T.red); R(x, 31, 16.5, 1, 1, '#ffd0c8');
      L(x, [[20, 13], [21, 9], [24, 8]], T.st4, 1); C(x, 24, 8, 1, T.yel);
    } else if (tier === 1) {   // sleek armed drone: smooth hull, blue visor, one gun
      R(x, 6, 4, 6, 1, T.st2); R(x, 32, 4, 6, 1, T.st2);
      L(x, [[15, 15], [9, 9]], T.st3, 2.5); L(x, [[29, 15], [35, 9]], T.st3, 2.5);
      rotor(x, 9, 7, f, T.st4, T.st6, 16); rotor(x, 35, 7, f + 2, T.st4, T.st6, 16);
      E(x, 22, 17, 13, 6, T.st3); E(x, 21, 15, 11, 3.5, T.st4); E(x, 20, 14, 7, 1.5, T.st5);
      E(x, 22, 21, 11, 2.5, T.st2);
      E(x, 32, 16, 3.5, 2.2, T.bl1); E(x, 32.5, 15.5, 2, 1.2, T.bl3);
      R(x, 22, 22, 14, 3, T.st1); R(x, 34, 21.5, 3, 4, T.st2); R(x, 22, 22, 14, 1, T.st3);
      R(x, 10, 17, 4, 1, T.bl2);
    } else if (tier === 2) {   // twin-gun drone: heavier, hazard stripe, ammo drum
      L(x, [[14, 14], [8, 9]], T.st2, 3); L(x, [[30, 14], [36, 9]], T.st2, 3);
      rotor(x, 13, 5, f + 1, T.st2, T.st3, 14); rotor(x, 31, 5, f + 3, T.st2, T.st3, 14);   // far pair
      rotor(x, 8, 7, f, T.st4, T.st6, 13); rotor(x, 36, 7, f + 2, T.st4, T.st6, 13);
      RR(x, 9, 11, 26, 13, 4, T.st2); R(x, 10, 11, 24, 3, T.st3); R(x, 12, 12, 18, 1, T.st4);
      for (let i = 0; i < 4; i++) P(x, [[12 + i * 5, 15], [15 + i * 5, 15], [13 + i * 5, 18], [10 + i * 5, 18]], i % 2 ? T.st1 : '#e0a020');
      C(x, 31, 15, 2.6, T.st0); C(x, 31.5, 15, 1.6, T.red); C(x, 26, 15.5, 1.6, T.st0); C(x, 26.2, 15.5, 1, T.bl2);
      C(x, 18, 25, 4, T.st1); C(x, 18, 25, 2.5, T.st3); R(x, 17, 24, 2, 2, '#c8a040');
      R(x, 24, 20, 18, 2.5, T.st1); R(x, 24, 24, 16, 2.5, T.st1); R(x, 24, 20, 18, 1, T.st3); R(x, 24, 24, 16, 1, T.st3);
      R(x, 40, 19.5, 3, 3.5, T.st3); R(x, 38, 23.5, 3, 3.5, T.st3);
    } else {   // energy drone: dark hull, glowing core, ring rotors that spin with light
      L(x, [[15, 14], [9, 9]], T.st1, 2.5); L(x, [[29, 14], [35, 9]], T.st1, 2.5);
      for (const hx of [9, 35]) {
        E(x, hx, 7, 7.5, 2.8, T.bl1); E(x, hx, 7, 5.8, 1.5, T.st0);
        const a = (f / 4) * TAU + (hx > 20 ? 1.5 : 0), sx = hx + Math.cos(a) * 6.4;
        E(x, sx, 7 + Math.sin(a) * 2, 2.5, 1.6, T.bl4);
        R(x, hx - 1, 7, 2, 4, T.st2);
      }
      E(x, 22, 17, 12, 7, T.st1); E(x, 21, 14, 9, 3, T.st2);
      P(x, [[30, 13], [38, 15], [38, 19], [30, 21]], T.st0);
      R(x, 36, 13, 4, 1.5, T.st2); R(x, 36, 19.5, 4, 1.5, T.st2);
      C(x, 40.5, 17, [2.4, 1.8, 2.4, 3][f], T.bl2); C(x, 40.5, 17, 1.2, T.bl4);
      C(x, 21, 18, 5, T.bl0); C(x, 21, 18, 3.5 + (f % 2) * 0.6, T.bl2); C(x, 21, 18, 1.8, T.bl4);
      R(x, 12, 22, 20, 1.5, T.bl1);
      E(x, 22, 26, 6, 1.5, T.bl1); E(x, 22, 26, 3, 0.8, T.bl3);
    }
  });
  return fin(c, OUT);
}

// ================================================================== THE SUMMONED ROBOT (3 tiers; 72×76 frames, feet at 36,76, facing right)
const BOT = [
  { s: 0.7, plate: T.rust2, plateD: T.rust1, plateL: T.rust3, frame: T.st2, frameD: T.st1, acc: '#c8a040', eye: T.red, eyeL: '#ffd0c8' },
  { s: 0.86, plate: T.st3, plateD: T.st2, plateL: T.st4, frame: T.st1, frameD: T.st0, acc: '#ff9a20', eye: T.bl2, eyeL: T.bl4 },
  { s: 1, plate: '#b4c2d2', plateD: '#7a8ca2', plateL: '#e4ecf4', frame: T.st1, frameD: T.st0, acc: T.bl2, eye: T.bl3, eyeL: T.bl4 },
];
function bot(tier, pose, f) {
  const B = BOT[tier];
  const c = frame(72, 76, x => {
    x.translate(36, 76); x.scale(B.s, B.s);
    // pose: leg swing, body bob, lean, arm reach
    let bob = 0, lean = 0, legA = 0, legB = 0, liftA = 0, liftB = 0, armSwing = 0, reach = 0, recoil = 0, flash = 0, impact = 0, glow = 0;
    if (pose === 'idle') { bob = [0, 1, 1, 0][f]; glow = f % 2; armSwing = [0, 1, 1, 0][f]; }
    if (pose === 'walk') {
      const a = f / 6 * TAU; legA = Math.sin(a) * 7; legB = -legA; liftA = Math.max(0, Math.cos(a)) * 4; liftB = Math.max(0, -Math.cos(a)) * 4;
      bob = Math.abs(Math.cos(a)) > 0.7 ? 0 : 1.5; armSwing = Math.sin(a) * 4;
    }
    if (pose === 'attack') { reach = [-7, 12, 12, 3][f]; lean = [-2, 3, 2, 0][f]; impact = f === 1; flash = f === 2; recoil = f === 2 ? -2 : 0; legA = [-1, 3, 3, 1][f]; legB = [-2, -4, -4, -2][f]; glow = f === 2 ? 1 : 0; }
    const big = tier === 2, hipY = -24 + bob, chestTop = -52 + bob - (big ? 4 : 0);
    // ---- far side: back arm and back leg (darker)
    const leg = (hx, dx, lift, near) => {
      const col = near ? B.frame : B.frameD, pl = near ? B.plate : B.plateD;
      const kx = hx + dx * 0.5 + 3, ky = (hipY - lift) / 2 - 2;
      limb(x, [[hx, hipY], [kx, ky - lift * 0.5]], 9, 8, col);
      limb(x, [[kx, ky - lift * 0.5], [hx + dx, -4 - lift]], 8, 7, col);
      RR(x, kx - 4.5, ky - 4 - lift * 0.5, 9, 8, 2, pl);   // knee plate
      if (big) { R(x, hx + dx - 1, ky - lift, 2, -ky - 6, T.st4); }   // piston
      RR(x, hx + dx - 6, -6 - lift, 15, 6, [3, 4, 1, 1], pl);   // foot
      R(x, hx + dx - 6, -1.5 - lift, 15, 1.5, col);
    };
    const backArm = () => {
      const sx = lean - 10, sy = chestTop + 8, ex = sx - 3 - armSwing * 0.5, ey = sy + 12, hx = ex + 3 + armSwing, hy = ey + 11;
      limb(x, [[sx, sy], [ex, ey], [hx, hy]], 7, 6, B.frameD);
      if (tier === 0) { P(x, [[hx - 3, hy], [hx + 3, hy], [hx + 4, hy + 5], [hx + 1, hy + 2], [hx - 2, hy + 5]], B.plateD); }
      else RR(x, hx - 4, hy - 2, 8, 7, 2, B.plateD);
    };
    leg(-5 + lean * 0.3, legB, liftB, false);
    backArm();
    if (tier === 2) {   // missile pod on the back
      R(x, lean - 22, chestTop - 4, 14, 18, B.plateD); R(x, lean - 22, chestTop - 4, 14, 3, B.plate);
      for (let i = 0; i < 3; i++) { R(x, lean - 20 + i * 4, chestTop - 9, 3, 6, T.st5); R(x, lean - 20 + i * 4, chestTop - 10, 3, 2, T.red); }
    }
    if (tier === 0) {   // exhaust pipe
      R(x, lean - 18, chestTop + 2, 5, 16, T.st2); R(x, lean - 19, chestTop, 7, 3, T.st3);
      if (pose !== 'walk' || f % 2) C(x, lean - 16, chestTop - 4 - (f % 2) * 2, 2.5, '#6a6a72');
    }
    // ---- torso
    const tw = big ? 30 : 26, tx = lean - tw / 2, th = hipY - chestTop + 4;
    RR(x, tx, chestTop, tw, th, tier === 0 ? 3 : 5, B.plate);
    R(x, tx, chestTop + th - 6, tw, 6, B.plateD);
    R(x, tx + 2, chestTop + 1, tw - 4, 2, B.plateL);
    R(x, tx - 1, hipY - 3, tw + 2, 4, B.frame);   // belt
    if (tier === 0) {
      R(x, tx + 3, chestTop + 6, 10, 9, T.st3); R(x, tx + 3, chestTop + 6, 10, 1, T.st4);
      for (const [rx, ry] of [[4, 7], [11, 7], [4, 13], [11, 13]]) R(x, tx + rx, chestTop + ry, 1, 1, T.st1);
      R(x, tx + 16, chestTop + 12, 7, 4, B.plateD); L(x, [[tx + 17, chestTop + 5], [tx + 21, chestTop + 9]], B.plateD, 1);
      for (let i = 0; i < 3; i++) R(x, tx + 16 + i * 3, chestTop + 18, 2, 2, i === glow ? T.yel : '#5a4020');
    } else if (tier === 1) {
      for (let i = 0; i < 4; i++) R(x, tx + 4, chestTop + 8 + i * 4, 12, 2, B.frame);
      R(x, tx + 18, chestTop + 7, 5, 5, B.frameD); R(x, tx + 19, chestTop + 8, 3, 3, glow ? T.bl3 : T.bl2);
      R(x, tx + 2, chestTop + th - 9, tw - 4, 2, B.acc);
    } else {
      P(x, [[tx + 4, chestTop + 6], [tx + tw - 4, chestTop + 6], [tx + tw - 8, chestTop + 22], [tx + 8, chestTop + 22]], B.plateD);
      C(x, lean + 1, chestTop + 13, 6, T.st0); C(x, lean + 1, chestTop + 13, 4.5, glow ? T.bl3 : T.bl2); C(x, lean + 1, chestTop + 13, 2, T.bl4);
      R(x, tx + 2, chestTop + th - 9, tw - 4, 1.5, T.bl2);
    }
    // ---- head
    const hw = big ? 18 : 16, hh = big ? 14 : 13, hx0 = lean + 1 - hw / 2 + (big ? 2 : 0), hy0 = chestTop - hh + 1;
    R(x, lean - 3, chestTop - 2, 6, 3, B.frame);
    if (tier === 0) {
      L(x, [[hx0 + 4, hy0], [hx0 + 2, hy0 - 6], [hx0 + 5, hy0 - 9]], T.st4, 1.2); C(x, hx0 + 5, hy0 - 9, 1.6, glow ? T.yel : '#c8a040');
      RR(x, hx0, hy0, hw, hh, 2, B.plate); R(x, hx0, hy0, hw, 2, B.plateL); R(x, hx0, hy0 + hh - 3, hw, 3, B.plateD);
      C(x, hx0 + hw - 4, hy0 + 6, 4.5, T.st1); C(x, hx0 + hw - 3.5, hy0 + 6, 3.2, B.eye); C(x, hx0 + hw - 3, hy0 + 6, 1.5, glow ? B.eyeL : '#ff8a80');
      R(x, hx0 + 2, hy0 + 9, 5, 1, T.st1); R(x, hx0 + 2, hy0 + 4, 3, 2, T.st3);
    } else if (tier === 1) {
      RR(x, hx0, hy0, hw, hh, [5, 5, 2, 2], B.plate); R(x, hx0 + 2, hy0 + 1, hw - 6, 2, B.plateL);
      R(x, hx0 + 3, hy0 + 5, hw - 2, 3, T.st0); R(x, hx0 + 6, hy0 + 6, hw - 6, 1.5, glow ? B.eyeL : B.eye);
      R(x, hx0, hy0 + hh - 3, hw, 3, B.plateD);
      for (let i = 0; i < 3; i++) R(x, hx0 + 2 + i * 3, hy0 + 10, 2, 1, T.st1);
    } else {
      P(x, [[hx0, hy0 + 4], [hx0 + 6, hy0 - 2], [hx0 + hw, hy0 + 1], [hx0 + hw + 2, hy0 + hh - 3], [hx0 + hw - 2, hy0 + hh], [hx0, hy0 + hh]], B.plate);
      P(x, [[hx0 + 4, hy0 - 1], [hx0 + 7, hy0 - 7], [hx0 + 10, hy0 - 1]], B.acc);   // crest
      P(x, [[hx0 + 6, hy0 + 4], [hx0 + hw + 1, hy0 + 4], [hx0 + hw + 1, hy0 + 8], [hx0 + 8, hy0 + 8]], T.st0);
      R(x, hx0 + 9, hy0 + 5, hw - 8, 2, glow ? B.eyeL : B.eye);
      R(x, hx0 + 1, hy0 + hh - 3, hw, 3, B.plateD);
    }
    // ---- near leg
    leg(5 + lean * 0.3, legA, liftA, true);
    // ---- near arm: cannon gauntlet that punches
    const sx = lean + 9, sy = chestTop + 8;
    let ex = sx + 2 + reach * 0.4 - armSwing * 0.3, ey = sy + 13 - Math.max(0, reach) * 0.9;
    const gx = ex + 2 + Math.max(0, reach) * 0.9 + recoil, gy = reach > 0 ? sy + 4 : ey;
    if (reach < 0) { ex = sx - 5; ey = sy + 9; }
    limb(x, [[sx, sy], [ex, ey]], 10.5, 9.5, OUT); limb(x, [[sx, sy], [ex, ey]], 8, 7, B.frame);
    const gl = big ? 20 : 16, gh = big ? 10 : 9, gX = reach < 0 ? ex - 2 : Math.min(gx - 4, 36 / B.s - gl - 2), gY = (reach > 0 ? gy : ey) - gh / 2;
    if (reach > 0) limb(x, [[ex, ey], [gX + 2, gY + gh / 2]], 7, 7, B.frame);
    RR(x, gX - 1.5, gY - 5, gl + 4.5, gh + 6.5, 3, OUT);
    RR(x, gX, gY, gl, gh, 2, B.plate);
    R(x, gX, gY, gl, 2, B.plateL); R(x, gX, gY + gh - 2, gl, 2, B.plateD);
    R(x, gX + gl - 4, gY + 1, 4, gh - 2, B.plateD);   // knuckle block
    // barrel along the top
    R(x, gX + 3, gY - 3.5, gl - 2, 3.5, B.frame); R(x, gX + gl - 1, gY - 4, 3, 4.5, B.frameD);
    if (tier === 1) { for (let i = 0; i < 3; i++) P(x, [[gX + 2 + i * 4, gY + 3], [gX + 4 + i * 4, gY + 3], [gX + 2 + i * 4, gY + 6], [gX + i * 4, gY + 6]], B.acc); }
    if (tier === 2) { for (let i = 0; i < 3; i++) R(x, gX + 4 + i * 4, gY + 3, 2, gh - 6, glow ? T.bl3 : T.bl2); }
    if (tier === 0) { R(x, gX + 3, gY + 3, 2, 2, T.st1); R(x, gX + 9, gY + 4, 3, 1, T.st3); }
    // shoulder pad over it
    if (tier === 1) { RR(x, sx - 7.5, sy - 7.5, 16, 12, [6, 6, 2, 2], OUT); RR(x, sx - 6, sy - 6, 13, 9, [5, 5, 1, 1], B.plate); for (let i = 0; i < 3; i++) R(x, sx - 5 + i * 4, sy - 2, 2, 4, B.acc); R(x, sx - 5, sy - 6, 10, 1.5, B.plateL); }
    else if (tier === 2) { RR(x, sx - 8.5, sy - 8.5, 18, 13, [7, 7, 3, 3], OUT); RR(x, sx - 7, sy - 7, 15, 10, [6, 6, 2, 2], B.plate); R(x, sx - 6, sy - 7, 12, 2, B.plateL); R(x, sx - 6, sy, 13, 1.5, B.acc); }
    else { C(x, sx, sy, 5.8, OUT); C(x, sx, sy, 4.5, B.plateD); C(x, sx - 0.5, sy - 0.5, 2.5, B.plate); }
    // hit spark / muzzle flash
    const tipX = gX + gl + 2, tipY = gY - 2;
    if (impact) { const kx = gX + gl + 3, ky = gY + gh / 2; P(x, [[kx, ky - 7], [kx + 2, ky - 2], [kx + 7, ky], [kx + 2, ky + 2], [kx, ky + 7], [kx - 1, ky + 2]], T.yel); C(x, kx + 1, ky, 2, T.wht); }
    if (flash) { const fc = tier === 2 ? [T.bl2, T.bl4] : [T.or, T.yel]; P(x, [[tipX, tipY - 4], [tipX + 9, tipY], [tipX, tipY + 4]], fc[0]); P(x, [[tipX, tipY - 2], [tipX + 5, tipY], [tipX, tipY + 2]], fc[1]); }
  });
  return fin(c, OUT);
}

// ================================================================== ICONS (20×20; missile 28×12)
function icon(draw, w = 20, h = 20) { return fin(frame(w, h, draw), OUT); }
const ICONS = {
  nade_frag: () => icon(x => {
    E(x, 10, 12.5, 6, 6.5, '#4a6a2a'); E(x, 9, 11, 4, 4, '#5e8236');
    for (const yy of [10, 13, 16]) R(x, 4, yy, 12, 1, '#2e4a1a'); for (const xx of [7, 10, 13]) R(x, xx, 7, 1, 11, '#2e4a1a');
    R(x, 7.5, 3.5, 5, 3, T.st3); R(x, 7.5, 3.5, 5, 1, T.st5);
    L(x, [[12, 4], [15, 6], [15.5, 11]], T.st4, 1.4);
    ring(x, 5.5, 4.5, 2, 2, '#e0c060', 1);
  }),
  nade_shrapnel: () => icon(x => {
    for (let i = 0; i < 8; i++) { const a = i / 8 * TAU + 0.2; L(x, [[10, 11.5], [10 + Math.cos(a) * 8.5, 11.5 + Math.sin(a) * 8.5]], T.st4, 1.2); }
    C(x, 10, 11.5, 5.5, T.st2); C(x, 9, 10.5, 3.5, T.st3); C(x, 8, 9.5, 1.2, T.st5);
    R(x, 8.5, 3.5, 3, 3, '#c8743a');
  }),
  nade_energy: () => icon(x => {
    RR(x, 5, 6, 10, 12, 3, T.st1); R(x, 6, 7, 2, 10, T.st2);
    R(x, 8, 8, 4, 8, T.bl1); R(x, 9, 9, 2, 6, T.bl3); R(x, 9.5, 10, 1, 4, T.bl4);
    R(x, 7, 3, 6, 3, T.st3); R(x, 7, 3, 6, 1, T.st5); C(x, 10, 2.5, 1.2, T.bl3);
  }),
  nade_napalm: () => icon(x => {
    RR(x, 5, 6, 10, 12, 2, '#c03a1a'); R(x, 6, 7, 2, 10, '#e0602a');
    R(x, 5, 10, 10, 2, T.yel);
    P(x, [[10, 12.5], [12, 15], [10.5, 17], [8, 15.5]], T.or); P(x, [[10, 14], [11, 15.5], [9.5, 16.5]], T.yel);
    R(x, 7, 3, 6, 3, T.st3); R(x, 7, 3, 6, 1, T.st5); R(x, 9, 1.5, 2, 2, T.st2);
  }),
  nade_cryo: () => icon(x => {
    RR(x, 5, 6, 10, 12, 3, '#3aa0c8'); R(x, 6, 7, 2, 10, '#8ae0f8');
    L(x, [[10, 9], [10, 16]], T.bl4, 1); L(x, [[7, 10.5], [13, 14.5]], T.bl4, 1); L(x, [[13, 10.5], [7, 14.5]], T.bl4, 1);
    R(x, 7, 3, 6, 3, T.st4); R(x, 7, 3, 6, 1, T.st6); R(x, 13, 17, 3, 2, '#e6fbff'); R(x, 4, 13, 2, 2, '#e6fbff');
  }),
  nade_emp: () => icon(x => {
    C(x, 10, 12, 6.5, T.st1); C(x, 10, 12, 5, '#d8b020'); C(x, 9, 11, 3, '#f0d050');
    P(x, [[11, 7], [7, 13], [10, 13], [8.5, 17], [13, 11], [10, 11]], T.bl2); P(x, [[10.5, 8.5], [8.5, 12], [10, 12]], T.bl4);
    R(x, 8, 3, 4, 3, T.st3);
  }),
  nade_cluster: () => icon(x => {
    for (const [cx, cy] of [[10, 8], [5.5, 13], [14.5, 13]]) { C(x, cx, cy, 4.6, OUT); C(x, cx, cy, 3.6, '#5a6a32'); C(x, cx - 1, cy - 1, 2, '#7a8a48'); R(x, cx - 1, cy - 5, 2, 2, T.st3); }
    R(x, 2, 14, 16, 2, '#8a6a3a'); R(x, 2, 14, 16, 1, '#b08a50');
  }),
  missile: () => icon(x => {
    P(x, [[0, 6], [5, 3], [5, 9]], T.or); P(x, [[2, 6], [5, 4.5], [5, 7.5]], T.yel);
    R(x, 5, 4, 16, 4, T.st5); R(x, 5, 4, 16, 1, T.st6); R(x, 5, 7, 16, 1, T.st4);
    P(x, [[21, 4], [27, 6], [21, 8]], T.red); R(x, 21, 4, 1, 4, T.redD);
    P(x, [[5, 4], [9, 4], [6, 1], [4, 1]], T.st3); P(x, [[5, 8], [9, 8], [6, 11], [4, 11]], T.st3);
    R(x, 13, 4, 2, 4, '#e0a020');
  }, 28, 12),
  part_scrap: () => icon(x => {
    P(x, [[2, 13], [8, 6], [13, 8], [18, 4], [17, 11], [11, 16], [5, 17]], T.st3);
    P(x, [[2, 13], [8, 6], [10, 7], [4, 15]], T.st4);
    P(x, [[11, 16], [17, 11], [18, 13], [12, 17]], T.st2);
    C(x, 9, 11, 1.3, T.st1); C(x, 14, 9, 1.1, T.st1); E(x, 6, 14, 2, 1.2, T.rust2); R(x, 15, 6, 2, 1, T.rust2);
  }),
  part_wire: () => icon(x => {
    R(x, 3, 3, 3, 14, T.st3); R(x, 14, 3, 3, 14, T.st3); R(x, 3, 3, 1, 14, T.st5); R(x, 14, 3, 1, 14, T.st5);
    R(x, 6, 5, 8, 10, '#c8743a'); for (let i = 0; i < 5; i++) { R(x, 6, 5.5 + i * 2, 8, 1, '#e8a060'); R(x, 6, 6.5 + i * 2, 8, 0.6, '#8a4a20'); }
    L(x, [[13, 15], [15, 18], [18, 17], [18, 14]], '#e8a060', 1.2);
  }),
  part_circuit: () => icon(x => {
    R(x, 2, 4, 16, 13, '#1e7a34'); R(x, 2, 4, 16, 1, '#3aa04a');
    L(x, [[4, 7], [8, 7], [10, 9]], '#e0c060', 0.9); L(x, [[4, 14], [9, 14], [11, 12]], '#e0c060', 0.9); L(x, [[15, 6], [15, 15]], '#e0c060', 0.9);
    R(x, 9, 8, 5, 5, T.st0); R(x, 10, 9, 1, 1, T.st3);
    for (let i = 0; i < 3; i++) { R(x, 8, 9 + i * 1.5, 1, 0.8, T.st4); R(x, 14, 9 + i * 1.5, 1, 0.8, T.st4); }
    R(x, 4, 10, 2, 2, '#c03a1a'); C(x, 16.5, 4.5, 0.9, '#e0c060');
  }),
  part_core: () => icon(x => {
    R(x, 5, 3, 10, 3, T.st3); R(x, 5, 14, 10, 3, T.st3); R(x, 5, 3, 10, 1, T.st5); R(x, 5, 16, 10, 1, T.st2);
    R(x, 6, 6, 8, 8, T.bl1); R(x, 7, 6, 6, 8, T.bl2); R(x, 8.5, 6, 3, 8, T.bl3); R(x, 9.5, 7, 1, 6, T.bl4);
    R(x, 4, 8, 1, 4, T.bl3); R(x, 15, 8, 1, 4, T.bl3);
  }),
};

// ================================================================== WEAPON EFFECTS
function bullet() { return frame(8, 4, x => { R(x, 0, 1, 3, 2, '#ff9a20'); R(x, 2, 1, 4, 2, '#ffe080'); R(x, 4, 1, 4, 2, '#fffbe8'); R(x, 6, 0.5, 2, 3, '#ffffff'); }); }
function energyBolt(f) {
  const c = frame(20, 12, x => {
    const r = rng(5 + f * 13);
    for (let k = 0; k < 2; k++) { const pts = []; for (let i = 0; i <= 5; i++) pts.push([1 + i * 2.6, 6 + (r() - 0.5) * 7]); L(x, pts, k ? T.bl3 : T.bl1, 1); }
    E(x, 13, 6, 7, 3.6, T.bl1); E(x, 13.5, 6, 5.5, 2.6, T.bl2); E(x, 14.5, 6, 3.5, 1.6, T.bl3); E(x, 15.5, 6, 2, 1, T.bl4);
    R(x, 6 + f, 2, 1, 1, T.bl3); R(x, 8 - f, 9, 1, 1, T.bl3);
  });
  return crisp(c);
}
function blob(x, r, cx, cy, rad, n, col, jit = 0.35) { for (let i = 0; i < n; i++) { const a = r() * TAU, d = r() * rad * jit * 2; C(x, cx + Math.cos(a) * d, cy + Math.sin(a) * d, rad * (0.45 + r() * 0.35), col); } }
function explosion(f) {
  const c = frame(80, 80, x => {
    const r = rng(3 + f * 7), cx = 40, cy = 40;
    if (f === 0) { for (let i = 0; i < 8; i++) { const a = i / 8 * TAU; P(x, [[cx + Math.cos(a - 0.2) * 5, cy + Math.sin(a - 0.2) * 5], [cx + Math.cos(a) * 16, cy + Math.sin(a) * 16], [cx + Math.cos(a + 0.2) * 5, cy + Math.sin(a + 0.2) * 5]], T.yel); } C(x, cx, cy, 9, '#ffe890'); C(x, cx, cy, 6, '#ffffff'); }
    if (f === 1) { C(x, cx, cy, 22, '#ff7a1a'); blob(x, r, cx, cy, 20, 9, '#ffb02a'); C(x, cx, cy, 13, '#ffe070'); C(x, cx, cy, 8, '#fffbe0'); }
    if (f === 2) { blob(x, r, cx, cy, 30, 12, '#d8401a', 0.4); blob(x, r, cx, cy - 2, 24, 10, '#ff8a1a'); blob(x, r, cx, cy - 3, 16, 8, '#ffc83a'); C(x, cx, cy - 3, 6, '#fff0a0'); }
    if (f === 3) { blob(x, r, cx, cy - 2, 32, 12, '#4a3a38', 0.4); blob(x, r, cx, cy - 2, 26, 12, '#c0301a'); blob(x, r, cx, cy - 3, 18, 9, '#ff7a1a'); blob(x, r, cx, cy - 4, 9, 5, '#ffc83a'); }
    if (f === 4) { blob(x, r, cx, cy - 4, 32, 14, '#3a3236', 0.45); blob(x, r, cx, cy - 5, 24, 10, '#5a4e50'); blob(x, r, cx, cy - 4, 12, 6, '#a0301a'); for (let i = 0; i < 5; i++) R(x, cx - 12 + r() * 24, cy - 12 + r() * 20, 2, 2, T.or); }
    if (f === 5) { for (let i = 0; i < 9; i++) { const a = r() * TAU, d = 14 + r() * 14; C(x, cx + Math.cos(a) * d, cy - 6 + Math.sin(a) * d * 0.8, 5 + r() * 5, i % 2 ? '#5a5258' : '#6e666c'); } blob(x, r, cx, cy - 8, 12, 6, '#7a7278'); }
    if (f === 6) { for (let i = 0; i < 7; i++) { const a = r() * TAU, d = 22 + r() * 12; C(x, cx + Math.cos(a) * d, cy - 10 + Math.sin(a) * d * 0.7, 3 + r() * 3, '#8a8288'); } }
  });
  return f >= 4 ? outline(crisp(c), '#1a1416') : crisp(c);
}
function energyBurst(f) {
  const c = frame(80, 80, x => {
    const r = rng(9 + f * 5), cx = 40, cy = 40;
    const arcs = (rad, n, col) => { for (let i = 0; i < n; i++) { const a = r() * TAU, pts = [[cx + Math.cos(a) * rad * 0.4, cy + Math.sin(a) * rad * 0.4]]; for (let k = 1; k <= 4; k++) { const d = rad * (0.4 + k * 0.17), b = a + (r() - 0.5) * 0.5; pts.push([cx + Math.cos(b) * d, cy + Math.sin(b) * d]); } L(x, pts, col, 1.3); } };
    if (f === 0) { C(x, cx, cy, 10, T.bl2); C(x, cx, cy, 7, T.bl3); C(x, cx, cy, 4, '#ffffff'); }
    if (f === 1) { arcs(26, 6, T.bl3); C(x, cx, cy, 17, T.bl1); C(x, cx, cy, 14, T.bl2); C(x, cx, cy, 9, T.bl3); C(x, cx, cy, 5, '#ffffff'); }
    if (f === 2) { ring(x, cx, cy, 24, 24, T.bl1, 7); ring(x, cx, cy, 24, 24, T.bl3, 3); arcs(34, 7, T.bl3); C(x, cx, cy, 8, T.bl2); C(x, cx, cy, 4, T.bl4); }
    if (f === 3) { ring(x, cx, cy, 31, 31, T.bl1, 4); ring(x, cx, cy, 31, 31, T.bl3, 1.6); arcs(36, 6, T.bl2); C(x, cx, cy, 4, T.bl2); }
    if (f === 4) { for (let i = 0; i < 14; i++) { const a = i / 14 * TAU + r() * 0.2, d = 33 + r() * 4; L(x, [[cx + Math.cos(a) * d, cy + Math.sin(a) * d], [cx + Math.cos(a + 0.18) * d, cy + Math.sin(a + 0.18) * d]], i % 2 ? T.bl2 : T.bl3, 2); } }
    if (f === 5) { for (let i = 0; i < 10; i++) { const a = r() * TAU, d = 30 + r() * 8; R(x, cx + Math.cos(a) * d, cy + Math.sin(a) * d, 2, 2, i % 2 ? T.bl3 : T.bl2); } }
  });
  return crisp(c);
}
function napalm(f) {
  const c = frame(48, 24, x => {
    const r = rng(21 + f * 9);
    E(x, 24, 22.5, 23, 2.5, '#2a1208'); E(x, 24, 22, 18, 1.5, '#5a2a0a');
    const tongues = [[6, 7], [12, 12], [18, 9], [24, 15], [30, 10], [36, 13], [42, 7]];
    for (const [tx, th0] of tongues) {
      const th = th0 * (0.7 + r() * 0.5), lean = (r() - 0.5) * 4, w = 3.6;
      P(x, [[tx - w, 22], [tx - w * 0.5 + lean * 0.4, 22 - th * 0.55], [tx + lean, 22 - th], [tx + w * 0.6 + lean * 0.5, 22 - th * 0.5], [tx + w, 22]], '#d8301a');
      P(x, [[tx - w * 0.6, 22], [tx + lean * 0.6, 22 - th * 0.68], [tx + w * 0.6, 22]], T.or);
      P(x, [[tx - w * 0.3, 22], [tx + lean * 0.3, 22 - th * 0.35], [tx + w * 0.3, 22]], T.yel);
    }
    for (let i = 0; i < 3; i++) R(x, 6 + r() * 36, 2 + r() * 6, 1, 1, T.yel);
  });
  return crisp(c);
}

// ================================================================== TANK'S HOUSE, INSIDE (384×300 world → 768×600)
function paintInterior() {
  const W = 384, H = 300, Y = 274, LX = 226, LY = 196, LW = 140, LAD = 234;
  const c = cv(W * 2, H * 2), x = g2(c); x.scale(2, 2);
  const px = (col, X, Yy, w = 1, h = 1) => { x.fillStyle = col; x.fillRect(Math.round(X * 2) / 2, Math.round(Yy * 2) / 2, w, h); };
  // back wall: steel panels with rivets
  px('#1c242e', 0, 0, W, Y);
  for (let X = 0; X < W; X += 32) {
    for (const [y0, y1] of [[20, 140], [141, Y - 34]]) {
      px('#2c3644', X + 1, y0, 30, y1 - y0); px('#3a4658', X + 1, y0, 30, 1); px('#18202a', X + 1, y1 - 1, 30, 1);
      for (const [rx, ry] of [[3, y0 + 3], [27, y0 + 3], [3, y1 - 4], [27, y1 - 4]]) { px('#4a5a6e', X + rx, ry, 1, 1); px('#141a22', X + rx + 0.5, ry + 0.5, 0.5, 0.5); }
    }
    px('#11161e', X, 20, 1, Y - 54);
  }
  // ceiling, conduits and the cold light strip
  px('#10151c', 0, 0, W, 12); px(T.bl1, 0, 10, W, 1.5); px(T.bl3, 0, 10.5, W, 0.5);
  px('#2e3846', 0, 13, W, 3); px('#4a5868', 0, 13, W, 0.5); px('#232c38', 0, 17, W, 2);
  for (let X = 10; X < W; X += 48) { px('#141a22', X, 12, 3, 8); }
  px('#ff5a4a', 200, 15, 1, 1);
  // lower wall: dark wainscot with vents and a glowing rail
  px('#161c25', 0, Y - 34, W, 34); px(T.bl1, 0, Y - 34, W, 1); px(T.bl3, 0, Y - 33.5, W, 0.5);
  for (let X = 8; X < W; X += 24) for (let k = 0; k < 4; k++) px('#0e131a', X, Y - 26 + k * 4, 12, 1.5);
  // floor: diamond-plate steel
  px('#1e2530', 0, Y, W, H - Y); px('#6a7c92', 0, Y, W, 1); px(T.bl2, 0, Y + 1, W, 0.5);
  for (let yy = Y + 3; yy < H; yy += 3) for (let X = ((yy - Y) % 6 === 0 ? 0 : 3); X < W; X += 6) { px('#2e3846', X, yy, 2, 0.5); px('#141a22', X + 0.5, yy + 0.5, 1.5, 0.5); }
  // wall monitors with the mecha suit schematic (the one thing he's building towards)
  px('#141a22', 120, 104, 2, 30);   // mount
  px('#0a0e16', 90, 56, 74, 50); px('#3a4658', 91, 57, 72, 48); px('#06142a', 93, 59, 68, 44);
  for (let X = 95; X < 160; X += 6) px('#0c2a4e', X, 59, 0.5, 44);
  for (let yy = 61; yy < 103; yy += 6) px('#0c2a4e', 93, yy, 68, 0.5);
  const sch = (pts) => { x.strokeStyle = T.bl2; x.lineWidth = 0.6; x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts.slice(1)) x.lineTo(p[0], p[1]); x.stroke(); };
  sch([[123, 64], [131, 64], [131, 71], [123, 71], [123, 64]]); px(T.bl3, 125, 66.5, 4, 1);   // helmet
  sch([[119, 73], [135, 73], [133, 86], [121, 86], [119, 73]]); sch([[124, 77], [130, 77], [130, 81], [124, 81], [124, 77]]);   // chest + core
  sch([[119, 74], [113, 82], [114, 90]]); sch([[135, 74], [141, 82], [140, 90]]);   // arms
  sch([[123, 86], [121, 96], [119, 99], [124, 99]]); sch([[131, 86], [133, 96], [131, 99], [136, 99]]);   // legs + boots
  px(T.bl3, 119, 98, 6, 1.5); px(T.bl3, 130, 98, 6, 1.5);   // boots already built: highlighted
  for (let i = 0; i < 4; i++) { px(T.bl1, 96, 63 + i * 4, 12 - i * 2, 0.8); px(T.bl1, 144, 75 + i * 4, 12 - i * 3, 0.8); }
  sch([[108, 64], [119, 67]]); sch([[143, 78], [136, 79]]);
  // small side screens: a waveform and a radar
  px('#0a0e16', 64, 66, 22, 30); px('#3a4658', 65, 67, 20, 28); px('#06142a', 66, 68, 18, 26);
  x.strokeStyle = '#5aff8a'; x.lineWidth = 0.5; x.beginPath(); for (let i = 0; i <= 18; i++) { const yy = 78 + Math.sin(i * 0.9) * (i % 3 ? 3 : 6); i ? x.lineTo(66 + i, yy) : x.moveTo(66, yy); } x.stroke();
  for (let i = 0; i < 5; i++) px('#2a8a4a', 68 + i * 3, 92 - i * 1.6, 2, i * 1.6 + 1);
  px('#0a0e16', 168, 60, 28, 22); px('#3a4658', 169, 61, 26, 20); px('#06142a', 170, 62, 24, 18);
  for (let i = 0; i < 5; i++) px(i === 2 ? T.bl3 : T.bl1, 172, 64 + i * 3, 6 + ((i * 7) % 13), 1);
  px('#0a0e16', 168, 86, 28, 22); px('#3a4658', 169, 87, 26, 20); px('#06142a', 170, 88, 24, 18);
  x.strokeStyle = '#2a8a4a'; x.lineWidth = 0.5; for (const rr of [3, 6, 8.5]) { x.beginPath(); x.arc(182, 97, rr, 0, TAU); x.stroke(); }
  x.strokeStyle = '#5aff8a'; x.beginPath(); x.moveTo(182, 97); x.lineTo(189, 93); x.stroke(); px('#ff5a4a', 177, 94, 1, 1);
  // cables from the screens down into the wall
  x.strokeStyle = '#0e131a'; x.lineWidth = 1; x.beginPath(); x.moveTo(75, 96); x.quadraticCurveTo(76, 120, 62, 130); x.lineTo(62, Y - 34); x.stroke();
  // the loft: a steel catwalk on a truss
  const LT = LY;
  px('#3a4658', LX, LT, LW, 4); px('#8a9cb2', LX, LT, LW, 1); px(T.bl2, LX, LT + 4, LW, 1);
  px('#1c242e', LX, LT + 5, LW, 5);
  for (let X = LX; X < LX + LW - 6; X += 10) { x.strokeStyle = '#3a4658'; x.lineWidth = 1; x.beginPath(); x.moveTo(X, LT + 5); x.lineTo(X + 5, LT + 10); x.lineTo(X + 10, LT + 5); x.stroke(); }
  px('#3a4658', LX, LT + 10, LW, 1);
  px('#2e3846', LX + LW - 4, LT + 11, 4, Y - LT - 11); px('#4a5868', LX + LW - 4, LT + 11, 1, Y - LT - 11);   // support column
  // ladder
  for (const rx of [LAD - 4, LAD + 3]) { px('#5c6e84', rx, LT - 2, 1.5, Y - LT + 2); px('#8a9cb2', rx, LT - 2, 0.5, Y - LT + 2); }
  for (let yy = LT + 4; yy < Y; yy += 7) px('#8a9cb2', LAD - 3, yy, 7, 1);
  // upstairs: a porthole onto the night (nobody out there)
  const wx = 286, wy = 134; for (let a = 0; a < TAU; a += 0.02) px('#5c6e84', wx + Math.cos(a) * 12, wy + Math.sin(a) * 12, 1.5, 1.5);
  for (let yy = -11; yy <= 11; yy += 0.5) for (let xx = -11; xx <= 11; xx += 0.5) if (xx * xx + yy * yy < 110) px(yy > 4 ? '#14204a' : '#0a1030', wx + xx, wy + yy, 0.5, 0.5);
  for (const [sx, sy] of [[-6, -5], [3, -7], [6, 1], [-2, 2], [-8, 4]]) px('#e6fbff', wx + sx, wy + sy, 0.5, 0.5);
  C(x, wx + 4, wy - 3, 2.2, '#d8e0f0'); C(x, wx + 5, wy - 3.5, 1.8, '#0a1030');   // a thin moon
  // workbench with a half-built robot arm, tools and one mug
  const bx = 250, bw = 56, bt = LT - 15;
  px('#2e3846', bx + 2, bt + 2, 3, 13); px('#2e3846', bx + bw - 5, bt + 2, 3, 13); px('#232c38', bx + 4, LT - 5, bw - 8, 2);
  px('#5c6e84', bx, bt, bw, 3); px('#8a9cb2', bx, bt, bw, 1);
  px('#141a22', bx + 6, bt + 4, 14, 6); px('#3a4658', bx + 7, bt + 5, 12, 1); px('#3a4658', bx + 7, bt + 8, 12, 1);   // drawer
  // the robot arm: shoulder joint, segments, a claw and loose wires
  C(x, bx + 12, bt - 4, 3.5, '#8a9cb2'); C(x, bx + 12, bt - 4, 1.5, T.bl2);
  x.save(); x.translate(bx + 12, bt - 4); x.rotate(-0.25); px('#c4d2e2', 0, -2, 16, 4); px('#8a9cb2', 0, 1, 16, 1); x.restore();
  C(x, bx + 27, bt - 8, 2.5, '#5c6e84');
  x.save(); x.translate(bx + 27, bt - 8); x.rotate(0.5); px('#c4d2e2', 0, -1.5, 11, 3); x.restore();
  px('#3a4658', bx + 35, bt - 4, 2, 4); px('#3a4658', bx + 38, bt - 5, 1.5, 5);   // claw fingers
  x.strokeStyle = '#c03a1a'; x.lineWidth = 0.5; x.beginPath(); x.moveTo(bx + 15, bt - 2); x.quadraticCurveTo(bx + 20, bt + 2, bx + 22, bt); x.stroke();
  x.strokeStyle = '#e0c060'; x.beginPath(); x.moveTo(bx + 16, bt - 3); x.quadraticCurveTo(bx + 22, bt + 3, bx + 26, bt - 6); x.stroke();
  px('#8a9cb2', bx + 42, bt - 2, 8, 1.5); px('#8a9cb2', bx + 49, bt - 3, 2, 3.5);   // wrench
  px('#c03a1a', bx + 44, bt - 4.5, 4, 1.5); px('#c4d2e2', bx + 48, bt - 4, 3, 0.5);   // screwdriver
  px('#5c6e84', bx + 52, bt - 5, 3, 5); px('#e6fbff', bx + 52.5, bt - 4, 2, 1);   // the one mug
  // desk lamp arm with its glow, and a pegboard of tools
  x.strokeStyle = '#3a4658'; x.lineWidth = 1; x.beginPath(); x.moveTo(bx + 4, bt); x.lineTo(bx + 2, bt - 18); x.lineTo(bx + 12, bt - 24); x.stroke();
  P(x, [[bx + 10, bt - 26], [bx + 16, bt - 24], [bx + 14, bt - 20], [bx + 9, bt - 22]], '#5c6e84'); px(T.bl3, bx + 13, bt - 21, 2, 1);
  px('#18202a', 316, 142, 22, 26); for (let i = 0; i < 5; i++) for (let k = 0; k < 6; k++) px('#0e131a', 318 + i * 4, 144 + k * 4, 0.5, 0.5);
  px('#8a9cb2', 319, 146, 1, 9); px('#8a9cb2', 318, 145, 3, 2); px('#e0a020', 324, 146, 2, 7); px('#5c6e84', 324.5, 152, 1, 6); px('#8a9cb2', 330, 146, 4, 1); px('#8a9cb2', 331.5, 146, 1, 10); px('#c03a1a', 318, 158, 6, 2); px('#3a4658', 327, 158, 8, 6);
  // charging pod for the suit, with the half-built suit glowing inside
  const pX = 340, pW = 24, pT = LT - 50;
  px('#232c38', pX, pT, pW, 50); px('#3a4658', pX, pT, pW, 4); px('#3a4658', pX, LT - 4, pW, 4); px(T.bl2, pX + 1, LT - 4, pW - 2, 1); px(T.bl2, pX + 1, pT + 3, pW - 2, 1);
  px('#06142a', pX + 3, pT + 5, pW - 6, 40); px('#0c2a4e', pX + 4, pT + 6, 3, 38);
  px(T.bl1, pX + 9, pT + 9, 6, 6); px('#06142a', pX + 10, pT + 11, 4, 1.5);   // helmet outline (not built yet: dim)
  px(T.bl1, pX + 8, pT + 17, 8, 10); px('#06142a', pX + 9, pT + 18, 6, 8);
  px(T.bl1, pX + 9, pT + 28, 2, 10); px(T.bl1, pX + 13, pT + 28, 2, 10);
  px(T.bl3, pX + 8, pT + 38, 4, 3); px(T.bl3, pX + 12, pT + 38, 4, 3);   // the boots: built, glowing
  px('#5c6e84', pX - 1, pT, 1, 50); px('#5c6e84', pX + pW, pT, 1, 50);
  x.strokeStyle = '#0e131a'; x.lineWidth = 1.2; x.beginPath(); x.moveTo(pX + pW, pT + 10); x.quadraticCurveTo(pX + pW + 6, pT + 20, W, pT + 14); x.stroke();
  // downstairs, out of the way: a tall tool locker by the front door and a scrap bin under the loft
  px('#232c38', 3, Y - 54, 16, 54); px('#3a4658', 3, Y - 54, 16, 2); px('#0e131a', 11, Y - 52, 0.5, 52);
  for (let k = 0; k < 3; k++) { px('#0e131a', 5, Y - 48 + k * 3, 4, 1); px('#0e131a', 13, Y - 48 + k * 3, 4, 1); }
  px(T.bl2, 9.5, Y - 30, 0.5, 4); px(T.bl2, 12, Y - 30, 0.5, 4);
  px('#3a4658', 304, Y - 12, 20, 12); px('#5c6e84', 304, Y - 12, 20, 1.5); px('#e0a020', 306, Y - 7, 16, 2); for (let i = 0; i < 4; i++) px('#141a22', 307 + i * 4, Y - 7, 2, 2);
  P(x, [[306, Y - 12], [309, Y - 18], [312, Y - 12]], '#8a9cb2'); px('#c8743a', 313, Y - 15, 4, 3); P(x, [[317, Y - 12], [320, Y - 16], [322, Y - 12]], '#5c6e84');
  // sliding doors (out at 40, Trophy Hall at 344)
  for (const X of [40, 344]) {
    px('#0a0e16', X - 17, Y - 58, 34, 58); px(T.bl2, X - 16, Y - 57, 32, 57); px('#141a22', X - 15, Y - 56, 30, 56);
    px('#4a5868', X - 14, Y - 55, 13.5, 55); px('#4a5868', X + 0.5, Y - 55, 13.5, 55);
    px('#6a7c92', X - 14, Y - 55, 13.5, 2); px('#6a7c92', X + 0.5, Y - 55, 13.5, 2);
    px(T.bl3, X - 0.5, Y - 55, 1, 55);
    px('#0c2a4e', X - 11, Y - 46, 8, 14); px('#0c2a4e', X + 3, Y - 46, 8, 14); px(T.bl1, X - 10, Y - 45, 2, 12); px(T.bl1, X + 4, Y - 45, 2, 12);
    for (let i = 0; i < 3; i++) { px('#e0a020', X - 13, Y - 16 + i * 5, 12, 2); px('#e0a020', X + 1.5, Y - 16 + i * 5, 12, 2); px('#141a22', X - 9, Y - 16 + i * 5, 3, 2); px('#141a22', X + 5, Y - 16 + i * 5, 3, 2); }
    P(x, [[X - 4, Y - 63], [X + 4, Y - 63], [X, Y - 60]], T.bl3);
    px('#0a0e16', X + 19, Y - 34, 5, 8); px(T.bl2, X + 20, Y - 33, 3, 3); px('#5aff8a', X + 20.5, Y - 29, 1, 1);
    px('#3a4658', X - 18, Y - 1, 36, 1);
  }
  return c;
}

window.TANK = { box, boxWreck, meteor, houseExterior, drone, bot, ICONS, bullet, energyBolt, explosion, energyBurst, napalm, paintInterior };
