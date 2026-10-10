// The World Map, painted as natural-looking land: noisy coastlines, shallow water and surf, hill shading,
// forests, mountains with snow, rivers, and each region's own ground. Runs inside a blank Chromium page
// (see worldmap.mjs). Map units match the game's world map: x 0…1000, y -210…430 (the northern strip above
// y 0 is the volcano climb). Painted at SCALE pixels per unit.
//
// Layers, each a full-size canvas (transparent where the layer has nothing):
//   base     the sea and the home island (home, pond, meadow, hollow, ridge, lair)
//   crimson  the Crimson Wastes to the east (shown once Doc Croc falls)
//   abyss    the trench across the northern sea (shown once the Warlord falls)
//   north    the frozen ridge and the abyssal volcano (shown once the Dreamer falls)
'use strict';

const SCALE = 1.5, X0 = 0, Y0 = -210, MW = 1000, MH = 640;
const W = Math.round(MW * SCALE), H = Math.round(MH * SCALE);

// ------------------------------------------------------------------ noise
function hash(x, y, s) { let h = (x * 374761393 + y * 668265263 + s * 1442695041) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); h ^= h >>> 16; return (h >>> 0) / 4294967296; }
function vnoise(x, y, s) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, y, s, oct = 5) { let t = 0, a = 0.5, f = 1, n = 0; for (let i = 0; i < oct; i++) { t += vnoise(x * f, y * f, s + i * 17) * a; n += a; a *= 0.5; f *= 2.03; } return t / n; }
function ridged(x, y, s, oct = 5) { let t = 0, a = 0.5, f = 1, n = 0; for (let i = 0; i < oct; i++) { t += (1 - Math.abs(vnoise(x * f, y * f, s + i * 31) * 2 - 1)) * a; n += a; a *= 0.5; f *= 2.1; } return t / n; }
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const hex = h => [(h >> 16) & 255, (h >> 8) & 255, h & 255];
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (a, b, v) => { const t = clamp((v - a) / (b - a)); return t * t * (3 - 2 * t); };

// ------------------------------------------------------------------ land shapes (blobs in map units)
const blob = (B, x, y) => { let m = -9; for (const [cx, cy, rx, ry] of B) { const d = Math.hypot((x - cx) / rx, (y - cy) / ry); m = Math.max(m, 1 - d); } return m; };
const HOME_B = [[150, 300, 105, 105], [210, 125, 115, 95], [235, 250, 135, 100], [400, 262, 135, 115], [560, 190, 135, 105], [640, 322, 105, 85], [330, 175, 95, 85], [480, 340, 120, 70], [115, 215, 70, 95], [300, 360, 110, 60], [470, 160, 80, 60]];
const CRIM_B = [[860, 240, 120, 175], [790, 340, 85, 70], [905, 105, 80, 75], [760, 245, 60, 90], [735, 365, 45, 30]];
const NORTH_B = [[160, -40, 130, 55], [320, -80, 130, 60], [470, -110, 140, 70], [620, -130, 140, 75], [760, -120, 130, 85], [880, -70, 110, 75], [860, -20, 90, 45], [80, -20, 80, 40]];
const landOf = (B, x, y, s) => blob(B, x, y) + (fbm(x / 90, y / 90, s) - 0.5) * 0.7 + (fbm(x / 32, y / 32, s + 5) - 0.5) * 0.35 + (fbm(x / 10, y / 10, s + 9) - 0.5) * 0.14;

// region centres, for the ground colour of each part of the home island
const REG = { home: [110, 330], pond: [205, 100], meadow: [215, 262], hollow: [405, 262], ridge: [565, 188], lair: [650, 330] };
function regionWeights(x, y) {
  const w = {}; let t = 0;
  const jx = (fbm(x / 60, y / 60, 71) - 0.5) * 120 + (fbm(x / 15, y / 15, 73) - 0.5) * 30, jy = (fbm(x / 60, y / 60, 72) - 0.5) * 120 + (fbm(x / 15, y / 15, 74) - 0.5) * 30;   // ragged borders
  for (const k in REG) { const d = Math.hypot(x + jx - REG[k][0], y + jy - REG[k][1]); w[k] = Math.pow(1 / Math.max(8, d), 3); t += w[k]; }
  for (const k in w) w[k] /= t;
  return w;
}

// ------------------------------------------------------------------ painters
function newLayer() { const c = document.createElement('canvas'); c.width = W; c.height = H; const x = c.getContext('2d'); return { c, x, img: x.createImageData(W, H) }; }
const put = (L, i, col, a = 255) => { L.img.data[i] = col[0]; L.img.data[i + 1] = col[1]; L.img.data[i + 2] = col[2]; L.img.data[i + 3] = a; };
// fixed light from the north-west: shading from the height gradient
const shadeOf = (hf, x, y, k) => { const e = 1.2; const dx = hf(x + e, y) - hf(x - e, y), dy = hf(x, y + e) - hf(x, y - e); return clamp(1 + (-dx - dy) * k, 0.55, 1.35); };

function paintSea(L) {
  for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
    const x = px / SCALE + X0, y = py / SCALE + Y0, i = (py * W + px) * 4;
    const n = fbm(x / 60, y / 60, 3), sw = fbm(x / 9 + y / 30, y / 7, 5);
    let c = mix(hex(0x2f78bd), hex(0x1d5a9a), clamp(n * 1.3 - 0.2));
    if (sw > 0.68) c = mix(c, hex(0x5fa4dc), (sw - 0.68) * 2.5);   // swell highlights
    put(L, i, c);
  }
}
// land + its shallows, coloured by `ground(x, y, h)` → [r,g,b]; h is height above the shore (0…1)
function paintLand(L, B, seed, ground, opts = {}) {
  const hf = (x, y) => landOf(B, x, y, seed);
  for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
    const x = px / SCALE + X0, y = py / SCALE + Y0, i = (py * W + px) * 4;
    const m = hf(x, y);
    if (m < 0.06) {   // shallow water and surf around the coast
      if (m > -0.05) {
        const t = (m + 0.05) / 0.11, surf = m > 0.035 && (Math.floor((m * 400 + fbm(x / 6, y / 6, seed + 4) * 6)) % 3 === 0);
        if (surf) put(L, i, [235, 248, 255], 230);
        else put(L, i, mix(hex(0x3f8fd0), hex(0x7cc8ea), t), Math.round(80 + t * 175));
      }
      continue;
    }
    if (m < 0.085) { put(L, i, opts.sand ? hex(opts.sand) : hex(0xe8d49a)); continue; }   // beach
    const h = clamp((m - 0.085) / 0.6);
    let c = ground(x, y, h, m);
    c = mix([0, 0, 0], c, shadeOf(hf, x, y, opts.relief || 9));
    put(L, i, c.map(v => clamp(Math.round(v), 0, 255)));
  }
}

function homeGround(x, y, h) {
  const w = regionWeights(x, y), d = fbm(x / 14, y / 14, 41), fine = vnoise(x / 2.2, y / 2.2, 43);
  const col = { home: mix(hex(0x8fd06a), hex(0x6ab64f), d), pond: mix(hex(0x9ad69a), hex(0x6fbf7a), d), meadow: mix(hex(0x9fd85f), hex(0x74bf48), d),
    hollow: mix(hex(0x3c6a44), hex(0x2a4e34), d), ridge: mix(hex(0xd8a454), hex(0xb47a38), d), lair: mix(hex(0x5a6a3c), hex(0x3c4a2a), d) };
  let c = [0, 0, 0]; for (const k in w) c = [c[0] + col[k][0] * w[k], c[1] + col[k][1] * w[k], c[2] + col[k][2] * w[k]];
  // the ridge rises into rocky hills
  const rk = w.ridge * smooth(0.25, 0.7, ridged(x / 40, y / 40, 51) * h * 2.2);
  if (rk > 0.05) c = mix(c, mix(hex(0x9a6a3a), hex(0xe8c088), ridged(x / 12, y / 12, 52)), clamp(rk * 1.6));
  // the lair's swamp pools
  if (w.lair > 0.5 && fbm(x / 10, y / 10, 61) > 0.62) c = mix(c, hex(0x3a5a4a), 0.75);
  return mix(c, mix(c, [255, 255, 255], 0.12), fine > 0.8 ? 0.6 : 0);
}

function crimsonGround(x, y, h) {
  const d = fbm(x / 16, y / 16, 81), r = ridged(x / 30, y / 30, 82);
  let c = mix(hex(0x6a1a22), hex(0x3a0c14), d);
  if (r > 0.72) c = mix(c, hex(0x2a0810), (r - 0.72) * 3);
  if (r > 0.86 && h > 0.2) c = mix(c, hex(0xff5a2a), (r - 0.86) * 5);   // lava cracks
  return c;
}

function northGround(x, y, h) {
  const r = ridged(x / 28, y / 28, 91), r2 = ridged(x / 9, y / 9, 92), snow = smooth(240, 420, x) * 0.65 + smooth(0.3, 0.75, h) * 0.5;
  let c = mix(hex(0x3e4250), hex(0x7e8494), r * 0.7 + r2 * 0.3);
  if (x < 300) c = mix(c, hex(0x4a6a4a), smooth(300, 160, x) * 0.6);   // grassy foothills in the west
  const sv = snow + (r - 0.55) * 0.9 + (r2 - 0.5) * 0.3;
  if (sv > 0.74) c = mix(c, mix(hex(0xc8d6e8), hex(0xf4f8ff), r2), clamp((sv - 0.74) * 3));
  // the volcano's purple ash fields
  const dv = Math.hypot(x - 820, (y + 120) * 1.2);
  if (dv < 150) c = mix(c, mix(hex(0x3a1450), hex(0x5a2070), fbm(x / 10, y / 10, 93)), smooth(150, 60, dv));
  return c;
}

// small hand-placed decorations, drawn with the 2D context over the pixels
function trees(L, B, seed, pick, density) {
  const x = L.x;
  for (let gy = Y0; gy < Y0 + MH; gy += 7) for (let gx = X0; gx < X0 + MW; gx += 7) {
    const jx = gx + hash(gx, gy, seed) * 7, jy = gy + hash(gx, gy, seed + 1) * 7;
    if (landOf(B, jx, jy, seed === 1 ? 11 : seed === 2 ? 21 : 31) < 0.14) continue;
    const kind = pick(jx, jy); if (!kind) continue;
    if (hash(gx, gy, seed + 2) > density(jx, jy)) continue;
    const X = (jx - X0) * SCALE, Y = (jy - Y0) * SCALE;
    if (kind === 'pine' || kind === 'dead') {
      x.fillStyle = kind === 'dead' ? '#2a0a10' : '#1e3a24';
      x.beginPath(); x.moveTo(X, Y - 7); x.lineTo(X + 3.6, Y + 2); x.lineTo(X - 3.6, Y + 2); x.fill();
      x.fillStyle = kind === 'dead' ? '#5a1a22' : '#2f6a3a'; x.beginPath(); x.moveTo(X, Y - 6); x.lineTo(X + 2.4, Y + 1); x.lineTo(X - 1.6, Y + 1); x.fill();
    } else if (kind === 'mush') {
      x.fillStyle = '#e8dcc0'; x.fillRect(X - 0.6, Y - 1, 1.6, 3);
      x.fillStyle = '#c24058'; x.beginPath(); x.ellipse(X, Y - 1.4, 3, 2, 0, Math.PI, Math.PI * 2); x.fill();
      x.fillStyle = '#fff'; x.fillRect(X - 1, Y - 2.6, 1, 1);
    } else {
      const big = kind === 'oak' ? 4 : 3, col = kind === 'blossom' ? ['#c86a8a', '#ec8fb0'] : kind === 'autumn' ? ['#a8502a', '#e0843a'] : kind === 'swamp' ? ['#2a3a24', '#4a5a34'] : ['#2f7a35', '#4aa04a'];
      x.fillStyle = 'rgba(0,0,0,0.25)'; x.beginPath(); x.ellipse(X + 1.2, Y + 2.4, big, big * 0.45, 0, 0, Math.PI * 2); x.fill();
      x.fillStyle = col[0]; x.beginPath(); x.arc(X, Y, big, 0, Math.PI * 2); x.fill();
      x.fillStyle = col[1]; x.beginPath(); x.arc(X - big * 0.3, Y - big * 0.3, big * 0.62, 0, Math.PI * 2); x.fill();
    }
  }
}

function river(L, pts, w) {
  const x = L.x; x.lineCap = 'round'; x.lineJoin = 'round';
  const path = () => { x.beginPath(); x.moveTo((pts[0][0] - X0) * SCALE, (pts[0][1] - Y0) * SCALE); for (let i = 1; i < pts.length - 1; i++) { const mx = (pts[i][0] + pts[i + 1][0]) / 2, my = (pts[i][1] + pts[i + 1][1]) / 2; x.quadraticCurveTo((pts[i][0] - X0) * SCALE, (pts[i][1] - Y0) * SCALE, (mx - X0) * SCALE, (my - Y0) * SCALE); } x.lineTo((pts.at(-1)[0] - X0) * SCALE, (pts.at(-1)[1] - Y0) * SCALE); };
  x.strokeStyle = '#2a6aa8'; x.lineWidth = w * SCALE + 2; path(); x.stroke();
  x.strokeStyle = '#5fb2e8'; x.lineWidth = w * SCALE; path(); x.stroke();
}
function lake(L, cx, cy, rx, ry, seed) {
  const x = L.x, pts = [];
  for (let a = 0; a < Math.PI * 2; a += 0.15) { const r = 1 + (fbm(Math.cos(a) * 2 + 5, Math.sin(a) * 2 + 5, seed) - 0.5) * 0.5; pts.push([(cx + Math.cos(a) * rx * r - X0) * SCALE, (cy + Math.sin(a) * ry * r - Y0) * SCALE]); }
  const poly = (grow) => { x.beginPath(); pts.forEach(([px, py], i) => { const qx = (px - (cx - X0) * SCALE) * grow + (cx - X0) * SCALE, qy = (py - (cy - Y0) * SCALE) * grow + (cy - Y0) * SCALE; i ? x.lineTo(qx, qy) : x.moveTo(qx, qy); }); x.closePath(); };
  x.fillStyle = '#e8d49a'; poly(1.12); x.fill();
  x.fillStyle = '#2a6aa8'; poly(1.0); x.fill();
  x.fillStyle = '#4aa0e0'; poly(0.86); x.fill();
  x.fillStyle = 'rgba(255,255,255,0.55)'; for (let k = 0; k < 5; k++) x.fillRect((cx - rx * 0.4 + k * rx * 0.2 - X0) * SCALE, (cy - ry * 0.2 + (k % 2) * ry * 0.3 - Y0) * SCALE, 4, 1);
}
function mountain(L, cx, cy, s, rock, snow) {
  const x = L.x, X = (cx - X0) * SCALE, Y = (cy - Y0) * SCALE, w = 9 * s * SCALE, h = 12 * s * SCALE;
  x.fillStyle = 'rgba(0,0,0,0.22)'; x.beginPath(); x.moveTo(X - w, Y); x.lineTo(X + w * 1.3, Y); x.lineTo(X + w * 0.2, Y - h * 0.8); x.fill();
  x.fillStyle = rock[0]; x.beginPath(); x.moveTo(X - w, Y); x.lineTo(X, Y - h); x.lineTo(X + w, Y); x.fill();
  x.fillStyle = rock[1]; x.beginPath(); x.moveTo(X, Y - h); x.lineTo(X + w, Y); x.lineTo(X + w * 0.15, Y); x.fill();
  if (snow) { x.fillStyle = snow; x.beginPath(); x.moveTo(X - w * 0.36, Y - h * 0.64); x.lineTo(X, Y - h); x.lineTo(X + w * 0.36, Y - h * 0.64); x.lineTo(X + w * 0.12, Y - h * 0.7); x.lineTo(X - w * 0.05, Y - h * 0.6); x.fill(); }
}
function house(L, cx, cy, roof) {
  const x = L.x, X = (cx - X0) * SCALE, Y = (cy - Y0) * SCALE;
  x.fillStyle = '#f4ead0'; x.fillRect(X - 5, Y - 5, 10, 7); x.fillStyle = '#6e4428'; x.fillRect(X - 1, Y - 2, 3, 4);
  x.fillStyle = roof; x.beginPath(); x.moveTo(X - 7, Y - 4); x.lineTo(X, Y - 10); x.lineTo(X + 7, Y - 4); x.fill();
  x.strokeStyle = '#3a2418'; x.lineWidth = 1; x.strokeRect(X - 5 + 0.5, Y - 5 + 0.5, 10, 7);
}

function paintAll() {
  const out = {};
  // base: sea + home island
  const B = newLayer(); paintSea(B); paintLand(B, HOME_B, 11, homeGround, { relief: 10 });
  B.x.putImageData(B.img, 0, 0);
  river(B, [[205, 120], [230, 170], [215, 215], [250, 255], [300, 300], [330, 370], [330, 420]], 2.6);
  river(B, [[420, 140], [440, 200], [470, 250], [520, 300], [560, 380]], 2);
  lake(B, 205, 104, 40, 20, 5);
  lake(B, 655, 340, 16, 8, 6);
  trees(B, HOME_B, 1, (x, y) => { const w = regionWeights(x, y), k = Object.keys(w).sort((a, b) => w[b] - w[a])[0];
    return k === 'hollow' ? (hash(Math.round(x), Math.round(y), 9) < 0.14 ? 'mush' : hash(Math.round(x), Math.round(y), 8) < 0.5 ? 'pine' : 'oak') : k === 'meadow' ? (hash(Math.round(x), Math.round(y), 7) < 0.3 ? 'blossom' : 'oak') : k === 'ridge' ? 'autumn' : k === 'lair' ? 'swamp' : k === 'pond' ? 'oak' : 'oak'; },
  (x, y) => { const w = regionWeights(x, y); return w.hollow * 0.9 + w.meadow * 0.18 + w.pond * 0.25 + w.home * 0.12 + w.lair * 0.4 + w.ridge * 0.1; });
  for (const [mx, my, s] of [[540, 160, 1.3], [575, 145, 1.6], [610, 170, 1.2], [520, 200, 0.9], [600, 210, 1], [640, 150, 1.1]]) mountain(B, mx, my, s, ['#b8743a', '#8a5226'], '#f4e8d0');
  for (const [hx, hy, r] of [[100, 330, '#c0392b'], [125, 342, '#3f6fb5'], [96, 352, '#e0a030']]) house(B, hx, hy, r);
  out.base = B.c.toDataURL('image/webp', 0.92);

  // crimson wastes
  const C = newLayer(); paintLand(C, CRIM_B, 21, crimsonGround, { relief: 12, sand: 0x5a2a20 });
  C.x.putImageData(C.img, 0, 0);
  trees(C, CRIM_B, 2, () => 'dead', (x, y) => 0.35);
  for (const [mx, my, s] of [[880, 150, 1.4], [910, 120, 1.8], [830, 110, 1.1], [940, 200, 1.2]]) mountain(C, mx, my, s, ['#4a0c14', '#2a060c'], null);
  // the Warlord's keep
  { const x = C.x, X = (950 - X0) * SCALE, Y = (52 - Y0) * SCALE; x.fillStyle = '#1a0408'; x.fillRect(X - 10, Y - 6, 20, 14); for (const dx of [-10, -4, 2, 8]) x.fillRect(X + dx, Y - 10, 3, 4); x.fillStyle = '#c0282a'; x.fillRect(X - 1, Y + 1, 3, 7); }
  out.crimson = C.c.toDataURL('image/webp', 0.92);

  // the abyss trench: a dark rift in the northern sea
  const A = newLayer();
  for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
    const x = px / SCALE + X0, y = py / SCALE + Y0, i = (py * W + px) * 4;
    if (y < -30 || y > 120 || x < 30 || x > 780) continue;
    const mid = 42 + (fbm(x / 120, 3, 101) - 0.5) * 60 + Math.sin(x / 70) * 6, half = (26 + (fbm(x / 50, 7, 102) - 0.5) * 30) * smooth(30, 160, x) * smooth(780, 640, x);
    const d = Math.abs(y - mid) + (fbm(x / 9, y / 9, 104) - 0.5) * 10;
    const inT = smooth(half + 12, half - 8, d);
    if (inT <= 0.01) continue;
    const r = ridged(x / 22, y / 22, 103);
    let c = mix(hex(0x2a0c3a), hex(0x08040e), clamp(inT * 1.2));
    if (r > 0.82) c = mix(c, hex(0x4a1a5a), (r - 0.82) * 4);
    put(A, i, c, Math.round(255 * clamp(inT * 1.3)));
  }
  A.x.putImageData(A.img, 0, 0);
  out.abyss = A.c.toDataURL('image/webp', 0.92);

  // the north: the frozen ridge and the abyssal volcano
  const N = newLayer(); paintLand(N, NORTH_B, 31, northGround, { relief: 7, sand: 0x8a8e9a });
  N.x.putImageData(N.img, 0, 0);
  trees(N, NORTH_B, 3, (x, y) => x < 330 ? 'pine' : null, (x, y) => 0.3);
  for (const [mx, my, s] of [[260, -80, 1.2], [330, -112, 1.6], [400, -125, 1.4], [480, -140, 1.9], [560, -150, 1.6], [640, -160, 2.1], [700, -150, 1.4], [200, -60, 1]]) mountain(N, mx, my, s, ['#6a6e7a', '#3a3e48'], '#f2f8ff');
  { // the volcano: a shaded cone, a glowing crater and lava running down its flanks
    const x = N.x, cx = (820 - X0) * SCALE, base = (-30 - Y0) * SCALE, top = (-150 - Y0) * SCALE, bw = 115 * SCALE, tw = 26 * SCALE;
    const sk = x.createRadialGradient(cx, base - 4, 4, cx, base - 4, bw * 1.25); sk.addColorStop(0, 'rgba(30,10,44,0.85)'); sk.addColorStop(1, 'rgba(30,10,44,0)');
    x.fillStyle = sk; x.beginPath(); x.ellipse(cx, base - 4, bw * 1.25, 26 * SCALE, 0, 0, Math.PI * 2); x.fill();   // ash skirt so the cone sits in the land
    const g = x.createLinearGradient(cx - bw, 0, cx + bw, 0); g.addColorStop(0, '#1e0a2c'); g.addColorStop(0.45, '#3a1450'); g.addColorStop(0.62, '#5a2070'); g.addColorStop(1, '#2a0c3a');
    x.fillStyle = g; x.beginPath(); x.moveTo(cx - bw, base);
    for (let k = 0; k <= 12; k++) { const t = k / 12, xx = cx - bw + (bw - tw) * t, yy = base + (top - base) * Math.pow(t, 0.8) + (hash(k, 1, 33) - 0.5) * 6; x.lineTo(xx, yy); }
    x.lineTo(cx + tw, top);
    for (let k = 12; k >= 0; k--) { const t = k / 12, xx = cx + bw - (bw - tw) * t, yy = base + (top - base) * Math.pow(t, 0.8) + (hash(k, 2, 33) - 0.5) * 6; x.lineTo(xx, yy); }
    x.closePath(); x.fill();
    x.strokeStyle = 'rgba(20,6,30,0.6)'; x.lineWidth = 1.5;   // erosion gullies
    for (let k = 0; k < 14; k++) { const t = k / 13, sx = cx - tw + 2 * tw * t; x.beginPath(); x.moveTo(sx, top + 4); x.quadraticCurveTo(sx + (t - 0.5) * bw * 0.6, (top + base) / 2, cx - bw * 0.9 + bw * 1.8 * t, base - 2); x.stroke(); }
    for (let k = 0; k < 5; k++) {   // lava
      const t = 0.15 + k * 0.17, sx = cx - tw + 2 * tw * t, ex = cx - bw * 0.7 + bw * 1.4 * t + (hash(k, 3, 7) - 0.5) * 30;
      x.strokeStyle = 'rgba(255,58,216,0.35)'; x.lineWidth = 5; x.beginPath(); x.moveTo(sx, top + 3); x.quadraticCurveTo((sx + ex) / 2 + (hash(k, 4, 7) - 0.5) * 30, (top + base) / 2, ex, base - 20 - hash(k, 5, 7) * 40); x.stroke();
      x.strokeStyle = '#ff6ae6'; x.lineWidth = 1.6; x.stroke();
    }
    const cg = x.createRadialGradient(cx, top, 2, cx, top, tw * 1.4); cg.addColorStop(0, '#fff0ff'); cg.addColorStop(0.35, '#ff5ae6'); cg.addColorStop(1, 'rgba(255,58,216,0)');
    x.fillStyle = cg; x.beginPath(); x.ellipse(cx, top + 1, tw * 1.4, 8 * SCALE, 0, 0, Math.PI * 2); x.fill();
    x.fillStyle = '#141820'; x.beginPath(); x.ellipse((452 - X0) * SCALE, (-112 - Y0) * SCALE, 14 * SCALE, 8 * SCALE, 0, Math.PI, Math.PI * 2); x.fill();   // the cave mouth
  }
  out.north = N.c.toDataURL('image/webp', 0.92);
  return out;
}
