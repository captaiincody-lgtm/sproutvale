// Bakes Tank, the fifth hero (a mechanic who builds an exosuit around himself), from the prototype's
// own hero rasteriser. Tank has no drawing code in the prototype: this script patches drawRock()
// inside the page (string-patching its source and redefining it) with a 'tank' branch that reuses
// the rig and helpers, then bakes six looks, tank_m_0 … tank_m_5, one per exosuit stage:
//   0 no suit · 1 rocket boots · 2 + leg servos · 3 + chest plate and gauntlets · 4 + helmet · 5 full mecha
//
// Writes (merging into the existing manifests, never touching the other heroes):
//   godot/art/hero/tank_m_N/<anim>_1.png     strips, same frame size and origin as the other heroes
//   godot/art/hero/hero.json                  looks.tank_m_N
//   godot/art/hero/heads.json                 tank_m_N head centres per frame
//   godot/art/hero/tank_points.json           pistol muzzle tip and near hand per frame (hero pixels)
//   godot/art/hero/tank_card.png, tank_card_mecha.png   idle frame for the character-select card
//
// Usage:  node tools/bake/tank.mjs ["Sproutvale 2D — prototype.html"] [godot]
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, existsSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const SRC = resolve(process.argv[2] || 'Sproutvale 2D — prototype.html');
const OUT = resolve(process.argv[3] || 'godot');
const SHEET = process.env.SHEET || '';   // optional contact-sheet path
const STAGES = [0, 1, 2, 3, 4, 5];

const write = (rel, data) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, data); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));

/* ------------------------------------------------------------------ page-side drawing code */
// helpers inserted into drawRock (they see its locals: F, P, TT, torso, head, HC, armN, along, pick, glowDot …)
const TANK_HELPERS = String.raw`
  // ---------- Tank: mechanic, pistol, grenades and a home-built exosuit ----------
  const TK = {
    steel: hex(0x76818e), steelS: hex(0x4b535e), steelL: hex(0xb4c0cc), dark: hex(0x2f343b), darkL: hex(0x4c535c),
    orange: hex(0xf28a22), orangeS: hex(0xb65c0e), yellow: hex(0xffcf3e),
    blue: hex(0x5fd8ff), blueL: hex(0xdaf7ff), red: hex(0xff3a2e), redL: hex(0xffd0c8),
    gun: hex(0x3a3f47), gunS: hex(0x24282d), gunL: hex(0x6c747e),
    glove: hex(0x3b302a), gloveS: hex(0x272019), gloveL: hex(0x5a4a40),
    nade: hex(0x55702f), nadeS: hex(0x3a4e1e), nadeL: hex(0x7f9a4a),
    out: hex(0x16191e),
  };
  const ST = LOOK.stage | 0, BIG = ST >= 5 ? 0.6 : 0;
  const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  const metal = (dk, stripe) => (x, y, t) => dk(stripe && stripe(x, y) ? (t === 1 ? TK.orangeS : TK.orange) : pick(TK.steel, TK.steelS, TK.steelL, t));
  const tkArm = (A, near) => {
    const dk = c => near ? c : mix(c, PAL.outline, 0.14);
    const [sx, sy] = TT(A.sh), [ex, ey] = TT(A.el), [hx, hy] = TT(A.hd);
    F.capsule(sx, sy, ex, ey, 1.9 + BIG, 1.7 + BIG);
    if (ST >= 5) F.commit(along(A.sh, A.el, (t, tone) => dk(t > 0.55 && t < 0.68 ? pick(TK.dark, TK.dark, TK.darkL, tone) : pick(TK.steel, TK.steelS, TK.steelL, tone))), { outline: TK.out });
    else F.commit(along(A.sh, A.el, (t, tone) => t < 0.58 ? dk(pick(PAL.tunic, PAL.tunicS, PAL.tunicL, tone)) : t < 0.76 ? dk(pick(PAL.tunicL, PAL.tunic, PAL.tunicL, tone)) : dk(pick(PAL.skin, PAL.skinS, PAL.skinL, tone))));   // rolled sleeve
    F.capsule(ex, ey, hx, hy, 1.8 + BIG, 1.6 + BIG);
    F.commit((x, y, tone) => dk(ST >= 5 ? pick(TK.dark, TK.dark, TK.darkL, tone) : pick(PAL.skin, PAL.skinS, PAL.skinL, tone)), ST >= 5 ? { outline: TK.out } : {});
    if (ST >= 3) {   // forearm gauntlet
      const g0 = TT(lerp(A.el, A.hd, 0.12)), g1 = TT(lerp(A.el, A.hd, 0.86));
      F.capsule(g0[0], g0[1], g1[0], g1[1], 2.15 + BIG, 2.0 + BIG);
      F.commit(along(lerp(A.el, A.hd, 0.12), lerp(A.el, A.hd, 0.86), (t, tone) => dk(t > 0.78 ? pick(TK.orange, TK.orangeS, TK.yellow, tone) : (t > 0.35 && t < 0.5 && tone !== 1) ? TK.blue : pick(TK.steel, TK.steelS, TK.steelL, tone))), { band: 1, outline: TK.out });
      const el = TT(A.el); F.ellipse(el[0], el[1], 1.5 + BIG * 0.6, 1.5 + BIG * 0.6); F.commit((x, y, t) => dk(pick(TK.dark, TK.dark, TK.steelL, t)), { outline: TK.out });
    }
    if (ST >= 3) {   // shoulder plate
      const c = TT(lerp(A.sh, A.el, 0.12)), r = ST >= 5 ? 4.2 : 2.9;
      F.ellipse(c[0], c[1] - 0.4, r, r * 0.8);
      F.commit((x, y, t) => dk(y < c[1] - 0.4 - r * 0.45 && t !== 1 ? TK.orange : pick(TK.steel, TK.steelS, TK.steelL, t)), { band: 1, outline: TK.out });
      if (ST >= 5) { F.set(Math.floor(c[0]), Math.floor(c[1] + 0.6), TK.yellow); }
    }
    return [hx, hy];
  };
  const tkFist = (h, near) => {
    const dk = c => near ? c : mix(c, PAL.outline, 0.14), r = 2.1 + BIG * 0.7;
    F.ellipse(h[0], h[1], r, r);
    if (ST >= 3) F.commit((x, y, t) => dk(y < h[1] - 0.4 ? pick(TK.steel, TK.steelS, TK.steelL, t) : pick(TK.dark, TK.dark, TK.darkL, t)), { outline: TK.out });
    else F.commit((x, y, t) => dk(y > h[1] + 0.5 ? pick(PAL.skin, PAL.skinS, PAL.skinL, t) : pick(TK.glove, TK.gloveS, TK.gloveL, t)));   // fingerless work glove
  };
  const footPts = (Lg, pts) => { const fa = Lg.sa * 0.45; return pts.map(([x, y]) => { const [a, b] = rot(x, y, -fa * 0.8); return TT([Lg.an[0] + a, Lg.an[1] + b]); }); };
  const footAt = (Lg, x, y) => footPts(Lg, [[x, y]])[0];
  const tkLeg = (Lg, near) => {
    const BIG = ST >= 5 ? 1.0 : 0;
    const dk = c => near ? c : mix(c, PAL.outline, 0.14);
    if (ST < 2) {   // cargo pocket on the thigh
      const p0 = TT(lerp(Lg.hip, Lg.kn, 0.42)), p1 = TT(lerp(Lg.hip, Lg.kn, 0.66));
      F.capsule(p0[0], p0[1], p1[0], p1[1], 1.25); F.commit((x, y, t) => dk(t === 2 ? PAL.shortsL : PAL.shortsS), { noOutline: true });
    }
    if (ST >= 2) {   // leg servos: thigh and shin plates on a round knee joint
      const a = lerp(Lg.hip, Lg.kn, 0.2), b = lerp(Lg.hip, Lg.kn, 0.82), A = TT(a), B = TT(b);
      F.capsule(A[0], A[1], B[0], B[1], 2.5 + BIG, 2.2 + BIG);
      F.commit(along(a, b, (t, tone) => dk(t > 0.44 && t < 0.56 && tone !== 1 ? TK.orange : pick(TK.steel, TK.steelS, TK.steelL, tone))), { band: 1, outline: TK.out });
      const c = lerp(Lg.kn, Lg.an, 0.12), d = lerp(Lg.kn, Lg.an, 0.62), C = TT(c), D = TT(d);
      F.capsule(C[0], C[1], D[0], D[1], 2.3 + BIG, 2.2 + BIG);
      F.commit(along(c, d, (t, tone) => dk((t > 0.3 && t < 0.42 && tone !== 1) ? TK.blue : pick(TK.steel, TK.steelS, TK.steelL, tone))), { band: 1, outline: TK.out });
      const K = TT(Lg.kn); F.ellipse(K[0], K[1], 1.9 + BIG * 0.6, 1.9 + BIG * 0.6);
      F.commit((x, y, t) => dk(Math.hypot(x - K[0], y - K[1]) < 0.75 ? TK.blue : pick(TK.darkL, TK.dark, TK.steelL, t)), { outline: TK.out });
    }
    if (ST >= 1) {   // rocket boots: chunky metal boots with a heel thruster
      const a = lerp(Lg.kn, Lg.an, 0.6), A = TT(a), N = TT(Lg.an);
      F.capsule(A[0], A[1], N[0], N[1], 2.6 + BIG, 2.6 + BIG);
      F.poly(footPts(Lg, [[-3, -1.8], [3.4, -2], [6, 0.2], [5.9, 2.4], [-3.2, 2.4]].map(([x, y]) => [x * (1 + BIG * 0.15), y])));
      const sole = footAt(Lg, 0, 1.5)[1];
      F.commit((x, y, t) => dk(y > sole + (P.rot ? 99 : 0) ? TK.dark : Math.abs(y - A[1]) < 0.75 && t !== 1 ? TK.orange : pick(TK.steel, TK.steelS, TK.steelL, t)), { band: 1, outline: TK.out });
      F.poly(footPts(Lg, [[-2.8, -0.6], [-4.8, -1], [-5.2, 2.1], [-2.8, 1.7]]));   // heel nozzle
      F.commit((x, y, t) => dk(pick(TK.dark, TK.dark, TK.darkL, t)), { outline: TK.out });
      const nz = footAt(Lg, -5, 1.6);
      glowDot(nz[0], nz[1] + 0.6, 2.2 + BIG, TK.blue, 0.55);
      F.set(Math.floor(nz[0]), Math.floor(nz[1]) + 1, TK.blueL);
    }
  };
  const tkTorso = () => {
    if (ST < 3) {   // work shirt: a chest pocket with a button
      F.poly([[0.8, -8.6], [3.6, -8.8], [3.7, -6.2], [0.9, -6]].map(([x, y]) => TT(torso(x, y))));
      F.commit((x, y, t) => t === 2 ? PAL.tunic : PAL.tunicS, { noOutline: true });
      const b = TT(torso(2.2, -8.2)); F.set(Math.floor(b[0]), Math.floor(b[1]), PAL.trim);
    }
    // tool belt: a wrench hanging at the front of the hip
    const w0 = TT(torso(2.6, -0.8)), w1 = TT(torso(3.3, 4.2));
    F.capsule(w0[0], w0[1], w1[0], w1[1], 0.6); F.commit((x, y, t) => pick(TK.steel, TK.steelS, TK.steelL, t), { outline: TK.out });
    const wh = TT(torso(3.45, 5.2)); F.ellipse(wh[0], wh[1], 1.35, 1.25); F.commit((x, y, t) => pick(TK.steel, TK.steelS, TK.steelL, t), { outline: TK.out });
    { const n = TT(torso(3.5, 5.9)); F.set(Math.floor(n[0]), Math.floor(n[1]), TK.out); }
    if (ST >= 3) {   // breastplate with a glowing core
      const plate = ST >= 5 ? [[-5.2, -11.2], [3.8, -11.6], [5.9, -8.4], [5.8, -2.6], [4.6, 1.4], [-4.6, 1.4], [-5.8, -2.6], [-6, -7.4]] : [[-4.4, -10.6], [3.4, -10.9], [5.1, -8], [5, -4.6], [3.6, -3.1], [-4.2, -3.1], [-5.2, -7]];
      F.poly(plate.map(([x, y]) => TT(torso(x, y))));
      const inv = (x0, y0) => { const [x, y] = unS(x0, y0); let X = x; if (P.mirror) X = 2 * RX - X; const dx = X - piv[0], dy = y - piv[1]; const ux = piv[0] + dx * cr + dy * sr, uy = piv[1] - dx * sr + dy * cr; return rot(ux - root[0], uy - root[1], -P.t); };
      F.commit((x, y, t) => {
        const [lx, ly] = inv(x, y);
        if (ST < 5 && ly > -3.9 && t !== 1) return TK.orange;
        if (ST >= 5 && (Math.abs(ly + 2.4) < 0.3 || Math.abs(ly + 0.4) < 0.3)) return TK.steelS;   // segmented abdomen plates
        if (ST >= 5 && ly > -2.6 && Math.abs(lx + 0.6) < 0.35) return TK.dark;
        return pick(TK.steel, TK.steelS, TK.steelL, t);
      }, { band: 2, outline: TK.out });
      const c = TT(torso(1.6, -7)), r = ST >= 5 ? 1.8 : 1.35;
      glowDot(c[0], c[1], ST >= 5 ? 5 : 3.6, TK.blue, ST >= 5 ? 0.55 : 0.4);
      F.ellipse(c[0], c[1], r, r); F.commit((x, y, t) => Math.hypot(x - c[0], y - c[1]) < r * 0.5 ? TK.blueL : TK.blue, { outline: TK.dark });
      if (ST >= 5) {   // hazard-striped hip plates
        F.poly([[-6.2, 1.2], [6, 1.2], [6.8, 4.6], [0.4, 5.3], [-6.4, 4.8]].map(([x, y]) => TT(torso(x, y))));
        F.commit((x, y, t) => { const [lx, ly] = inv(x, y); return ly > 3.6 && t !== 1 ? ((Math.floor(lx + ly + 40) % 2) ? TK.yellow : TK.dark) : pick(TK.steel, TK.steelS, TK.steelL, t); }, { band: 1, outline: TK.out });
      }
    }
  };
  const tkJetpack = () => {   // backpack thruster (full mecha)
    F.poly([[-3.6, -12.2], [-9.4, -11.6], [-10.2, -3], [-8.6, -0.4], [-3.6, -1.2]].map(([x, y]) => TT(torso(x, y))));
    F.commit((x, y, t) => pick(TK.steel, TK.steelS, TK.steelL, t), { band: 2, outline: TK.out });
    const s0 = TT(torso(-9.6, -9)), s1 = TT(torso(-9.9, -5)); F.capsule(s0[0], s0[1], s1[0], s1[1], 0.7); F.commit(() => TK.orange, { noOutline: true });
    for (const ox of [-8.6, -5.6]) {
      const a = TT(torso(ox, -1.2)), b = TT(torso(ox - 0.2, 1.4)); F.capsule(a[0], a[1], b[0], b[1], 1.2, 1.6); F.commit((x, y, t) => pick(TK.dark, TK.dark, TK.darkL, t), { outline: TK.out });
      const g = TT(torso(ox - 0.25, 2.6)); glowDot(g[0], g[1], 3.4, TK.blue, 0.6); F.set(Math.floor(g[0]), Math.floor(g[1]), TK.blueL);
    }
  };
  const tkFine = (lx, ly, rows, M) => {
    const [X0, Y0] = TT(head(lx, ly)), k = F.k, sx2 = P.mirror ? -1 : 1, ax = Math.floor(X0 * k), ay = Math.floor(Y0 * k);
    for (let r = 0; r < rows.length; r++) for (let c = 0; c < rows[r].length; c++) { const ch = rows[r][c]; if (ch !== '.') F.setFine(ax + c * sx2, ay + r, M[ch]); }
  };
  const tkRedEye = (lx, ly, big) => {   // the robotic eye: a hot red pixel and a soft red glow
    const e = TT(head(lx, ly));
    glowDot(e[0], e[1], big ? 4 : 2.8, TK.red, big ? 0.6 : 0.5);
    tkFine(lx - 0.6, ly - 0.6, ['.rr.', 'rRRr', 'rRRr', '.rr.'], { r: TK.red, R: TK.redL });
  };
  const FEM = !!LOOK.female;
  const tkCrop = () => {   // her undercut: clipped sides (the stubble cap) under a longer top swept forward into a short fringe
    const top = [[-6.6, -6.4], [-7.9, -8.2], [-6.0, -10.4], [-2.0, -11.4], [2.8, -11.3], [6.8, -9.9], [9.2, -7.6], [10.6, -4.9], [8.9, -5.5], [7.9, -4.5], [6.6, -5.8], [4.6, -5.3], [3.0, -6.6], [0.6, -6.5], [-2.0, -7.5], [-4.6, -7.2]];
    F.poly(top.map(([x, y]) => TT(head(x, y))));
    const hinv = (x0, y0) => { const [x, y] = unS(x0, y0); let X = x; if (P.mirror) X = 2 * RX - X; const dx = X - piv[0], dy = y - piv[1]; const ux = piv[0] + dx * cr + dy * sr, uy = piv[1] - dx * sr + dy * cr; const [a, b] = rot(ux - HC[0], uy - HC[1], -headAng); return [a / HS, b / HS]; };
    F.commit((x, y, t) => {
      const [lx, ly] = hinv(x, y), band = -9.2 + lx * lx * 0.035;
      if (t !== 1 && Math.abs(ly - band) < 0.7 && lx > -6 && lx < 6) return PAL.hairHi;
      if (t === 0 && ly > -8 && Math.abs(((lx - ly * 0.6 + 40) % 3.2) - 1.6) < 0.35) return PAL.hairS;   // strand lines sweeping forward
      return pick(PAL.hair, PAL.hairS, PAL.hairL, t);
    }, { band: 2, outline: PAL.hairOut });
  };
  const tkHead = () => {
    const M = { K: PAL.lash, D: hex(0x2c3a48), E: hex(0x6d8296), '+': hex(0xa6b8c8), B: PAL.brow, m: PAL.mouth, s: PAL.skinS, x: hex(0x8a5a48), g: TK.steelL };
    if (ST < 4) {
      // buzz cut: a short stubble cap hugging the skull, no fringe
      const cap = [];
      for (let i = 0; i <= 16; i++) { const th = -0.92 - (Math.PI - 0.12) * i / 16; cap.push([8.55 * Math.cos(th), -0.5 + 8.05 * Math.sin(th)]); }
      cap.push([-5.3, 4.0], [-4.9, 0.6], [-2.5, -0.5], [-1.6, 1.4], [-0.9, -1.6], [0.2, -4.4], [2.4, -6.0], [4.6, -6.9]);
      F.poly(cap.map(([x, y]) => TT(head(x, y))));
      F.commit((x, y, t) => t === 2 ? PAL.hairL : t === 1 ? PAL.hairS : ((Math.floor(x * 2) + Math.floor(y * 2)) % 2 ? PAL.hair : PAL.hairS), { band: 1, outline: PAL.hairOut });
      const ec = TT(head(-3.4, 2.2)); F.ellipse(ec[0], ec[1], 1.5, 2.1); F.commit((x, y, t) => pick(PAL.skin, PAL.skinS, PAL.skinL, t === 2 ? 0 : 1));
      if (FEM) {   // her face: lashes on the far eye, finer brows, a set mouth, a steel stud in the ear
        tkCrop();
        tkFine(7.3, -1.5, ['.KK', 'KKK', 'DDK', 'EE.', 'E+.', 'K..'], M);
        tkFine(0.8, -3.9, ['..BBBB....', 'BB...BBBBB'], M); tkFine(7.1, -3.6, ['BBB', '...'], M);
        tkFine(4.4, 5.6, ['mmmm', '.mm.'], M); tkFine(8.5, 2.6, ['s', 's'], M);
        { const er = TT(head(-3.4, 4.0)); F.set(Math.floor(er[0]), Math.floor(er[1]), TK.steelL); }
      } else {
      // stern face: heavy brows, a hard mouth, one ordinary eye on the far side
      tkFine(7.4, -0.9, ['KKK', 'DDK', 'EE.', 'E+.', 'K..'], M);
      tkFine(0.6, -3.7, ['BBB.......', '.BBBBB....', '....BBBBBB'], M); tkFine(7.1, -3.3, ['BBBB', '..BB'], M);
      tkFine(4.2, 5.8, ['mmmmm'], M); tkFine(8.5, 2.6, ['s', 's'], M);
      tkFine(1.2, 6.2, ['.s.s', 's.s.'], M);   // a shadow of stubble on the jaw
      }
      // the near eye is a metal socket with a glowing red lens
      const so = TT(head(3.3, 0.4)); F.ellipse(so[0], so[1], 1.95, 1.75);
      F.commit((x, y, t) => pick(TK.steel, TK.steelS, TK.steelL, t), { band: 1, outline: TK.out });
      { const sc = TT(head(1.6, -2.6)); F.set(Math.floor(sc[0]), Math.floor(sc[1]), PAL.skinS); }
      tkRedEye(3.4, 0.4, false);
      return;
    }
    // helmet: a visor helm over the buzz cut, the red eye burning through the lens
    const helm = [[-6.8, 7.2], [-9.4, 2.6], [-9.6, -3.2], [-7.2, -8.8], [-2, -11], [4, -10.6], [8.6, -7.4], [10.3, -3.4], [10.4, 2.6], [9, 3.6], [0.6, 3.8], [-1.6, 5.4], [-3.2, 7.8]];
    if (ST >= 5) helm.splice(10, 0, [9.6, 6.4], [6.2, 10.2], [1.8, 10], [-0.6, 7.4]);
    F.poly(helm.map(([x, y]) => TT(head(x * 0.92 + 0.5, y * 0.92 + 0.7))));
    const hinv = (x0, y0) => { const [x, y] = unS(x0, y0); let X = x; if (P.mirror) X = 2 * RX - X; const dx = X - piv[0], dy = y - piv[1]; const ux = piv[0] + dx * cr + dy * sr, uy = piv[1] - dx * sr + dy * cr; const [a, b] = rot(ux - HC[0], uy - HC[1], -headAng); return [a / HS, b / HS]; };
    F.commit((x, y, t) => {
      const [lx, ly] = hinv(x, y);
      if (Math.abs(lx + 1.2 - (ly + 9) * 0.05) < 0.9 && ly < -2 && t !== 1) return TK.orange;   // hazard stripe over the crown
      if (ST >= 5 && ly > 5.2 && lx > 1 && Math.abs(((lx * 2) | 0) % 3) === 0) return TK.dark;   // jaw-guard vents
      return pick(TK.steel, TK.steelS, TK.steelL, t);
    }, { band: 2, outline: TK.out });
    F.poly([[0.2, -3.6], [10.3, -4.0], [10.3, 1.4], [0.6, 1.9]].map(([x, y]) => TT(head(x * 0.92 + 0.5, y * 0.92 + 0.7))));
    F.commit((x, y, t) => t === 2 ? hex(0x34506a) : hex(0x101820), { noOutline: true });   // visor
    { const s0 = TT(head(5.5, -2.8)), s1 = TT(head(9.5, -3)); F.set(Math.floor(s0[0]), Math.floor(s0[1]), hex(0x6a90b0)); F.set(Math.floor(s1[0]), Math.floor(s1[1]), hex(0x4a6a88)); }
    const ear = TT(head(-3.4, 1.4)); F.ellipse(ear[0], ear[1], 2.3, 2.3); F.commit((x, y, t) => Math.hypot(x - ear[0], y - ear[1]) < 0.8 ? TK.blue : pick(TK.darkL, TK.dark, TK.steelL, t), { outline: TK.out });
    const an0 = TT(head(-5.6, -7)), an1 = TT(head(-8.4, -12.6)); F.capsule(an0[0], an0[1], an1[0], an1[1], 0.45); F.commit(() => TK.dark, { noOutline: true });
    F.set(Math.floor(an1[0]), Math.floor(an1[1]), TK.red);
    tkRedEye(3.6, -0.6, true);
    if (ST < 5) { tkFine(4.4, 6.2, FEM ? ['mmmm', '.mm.'] : ['mmmmm'], M); tkFine(8.5, 4.2, ['s'], M); }
  };
  const tkGunAng = () => P.ba != null ? P.ba : armN.fa + (P.sw != null && P.sa == null ? 0.25 : 0);
  const tkGun = (hand, ang) => {   // a chunky sidearm: grip in the fist, slide and muzzle along the aim
    const s = ST >= 5 ? 1.25 : 1, d = dir(ang), n = [-d[1], d[0]];
    const at = (u, v) => [hand[0] + d[0] * u * s - n[0] * v * s, hand[1] + d[1] * u * s - n[1] * v * s];
    F.poly([at(-1.0, 1.2), at(0.6, 1.2), at(0.0, -2.6), at(-1.7, -2.4)].map(TT));   // grip, raked back
    F.commit((x, y, t) => pick(TK.gunS, TK.gunS, TK.gun, t), { outline: TK.out });
    F.poly([at(-2.4, 0.4), at(6.2, 0.4), at(6.2, 2.6), at(-2.4, 2.6)].map(TT));   // slide
    F.commit((x, y, t) => pick(TK.gun, TK.gunS, TK.gunL, t), { band: 1, outline: TK.out });
    { const a = TT(at(1, 1.5)), b = TT(at(3.6, 1.5)); F.set(Math.floor(a[0]), Math.floor(a[1]), TK.blue); F.set(Math.floor(b[0]), Math.floor(b[1]), TK.blue); }
    F.poly([at(6.0, 0.8), at(7.4, 0.8), at(7.4, 2.2), at(6.0, 2.2)].map(TT));   // muzzle
    F.commit((x, y, t) => pick(TK.steelS, TK.dark, TK.steelL, t), { outline: TK.out });
    return at(7.6, 1.5);
  };
  const tkMuzzle = (hand, ang) => { const s = ST >= 5 ? 1.25 : 1, d = dir(ang), n = [-d[1], d[0]]; return [hand[0] + d[0] * 7.6 * s - n[0] * 1.5 * s, hand[1] + d[1] * 7.6 * s - n[1] * 1.5 * s]; };
  const tkGrenade = (hand, ang) => {
    const d = dir(ang), c = TT([hand[0] + d[0] * 1.6, hand[1] + d[1] * 1.6]);
    F.ellipse(c[0], c[1], 1.9, 2.1); F.commit((x, y, t) => pick(TK.nade, TK.nadeS, TK.nadeL, t), { outline: TK.out });
    F.set(Math.floor(c[0]) - 1, Math.floor(c[1]), TK.nadeS); F.set(Math.floor(c[0]) + 1, Math.floor(c[1]), TK.nadeS);
    F.set(Math.floor(c[0]), Math.floor(c[1]) - 2, TK.steelL); F.set(Math.floor(c[0]) + 1, Math.floor(c[1]) - 3, TK.yellow);
  };
`;

const TANK_BRANCH = String.raw`
  } else if (LOOK.kind === 'tank') {
    if (ST >= 5) tkJetpack();
    const fh = tkArm(armF, false); tkFist(fh, false);
    drawLeg(legF, false); tkLeg(legF, false); drawLeg(legN, true); tkLeg(legN, true);
    drawTorso(); tkTorso();
    drawHead(); tkHead();
    F.headC = TT(ST >= 4 ? head(0.9, 0.4) : head(0.3, 0.8));   // middle of the head (helmet from stage 4), for the air bubble
    const ga = tkGunAng();
    F.hand = TT(armN.hd); F.muzzle = TT(tkMuzzle(armN.hd, ga));
    if (!P.noWeapon && !P.noGun) tkGun(armN.hd, ga);
    const nh = tkArm(armN, true); tkFist(nh, true);
    if (P.grenade) tkGrenade(armN.hd, armN.fa);
  } else if (LOOK.kind === 'archer') {`;

// back view (climbing): steel boots/greaves come from the palette; these add the backplate and helmet
const TANK_BACK = String.raw`
window.__tankBack1 = (F, cx, base, P, pick) => {
  const st = LOOK.stage | 0, S = [hex(0x76818e), hex(0x4b535e), hex(0xb4c0cc)], O = hex(0x16191e);
  if (st >= 3) {
    F.poly([[cx - 4.6, base - 12], [cx + 4.6, base - 12], [cx + 5.2, base - 6], [cx + 4.4, base - 2.6], [cx - 4.4, base - 2.6], [cx - 5.2, base - 6]]);
    F.commit((x, y, t) => y > base - 3.6 && t !== 1 ? hex(0xf28a22) : pick(S[0], S[1], S[2], t), { band: 2, outline: O });
  }
  if (st >= 5) {
    F.poly([[cx - 4, base - 12.5], [cx + 4, base - 12.5], [cx + 4.6, base - 3], [cx - 4.6, base - 3]]); F.commit((x, y, t) => pick(S[0], S[1], S[2], t), { band: 2, outline: O });
    for (const ox of [-2.4, 2.4]) { F.capsule(cx + ox, base - 3.4, cx + ox, base - 1.4, 1.2, 1.5); F.commit(() => hex(0x2f343b), { outline: O }); F.set(Math.round(cx + ox), Math.round(base - 0.4), hex(0xdaf7ff)); F.set(Math.round(cx + ox), Math.round(base + 0.6), hex(0x5fd8ff)); }
  }
};
window.__tankBack2 = (F, cx, base, P, pick) => {
  const st = LOOK.stage | 0, hx = cx, hy = base - 23, O = hex(0x16191e);
  if (st < 4) return;
  F.ellipse(hx, hy - 0.4, 8.2 * 0.9, 8 * 0.9);
  F.commit((x, y, t) => Math.abs(x - hx) < 0.9 && y < hy - 1 && t !== 1 ? hex(0xf28a22) : pick(hex(0x76818e), hex(0x4b535e), hex(0xb4c0cc), t), { band: 2, outline: O });
  for (const s of [-1, 1]) { F.ellipse(hx + s * 7.2, hy + 1, 1.8, 1.8); F.commit((x, y, t) => pick(hex(0x4c535c), hex(0x2f343b), hex(0xb4c0cc), t), { outline: O }); }
  F.capsule(hx - 3, hy - 6, hx - 4.6, hy - 11.6, 0.45); F.commit(() => hex(0x2f343b), { noOutline: true }); F.set(Math.floor(hx - 4.6), Math.floor(hy - 11.6), hex(0xff3a2e));
};`;

/* ------------------------------------------------------------------ bake */
const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
await page.route(/fonts\.(gstatic|googleapis)\.com/, r => r.abort());
await page.goto('file://' + SRC);

await page.evaluate(([HELP, BRANCH, BACK]) => {
  const must = (src, a, b) => { if (!src.includes(a)) throw new Error('tank patch: anchor not found: ' + a.slice(0, 60)); return src.replace(a, b); };
  let s = drawRock.toString();
  s = must(s, "const SC = LOOK.kind === 'mage'", "const SC = LOOK.kind === 'tank' ? (LOOK.stage >= 5 ? 1.1 : 1) : LOOK.kind === 'mage'");
  s = must(s, "LOOK.kind === 'summoner' ? 0.88 / SC : 0.88", "LOOK.kind === 'summoner' || LOOK.kind === 'tank' ? 0.88 / SC : 0.88");
  s = must(s, "const ARCH = LOOK.kind === 'archer';", "const ARCH = LOOK.kind === 'archer' || !!P.aimSwap;");
  s = must(s, "const ROCKLEG = LOOK.kind === 'rock' && !LOOK.armored;", "const ROCKLEG = (LOOK.kind === 'rock' || LOOK.kind === 'tank') && !LOOK.armored;");
  s = must(s, "  // draw order: shield (at rest)", HELP + "\n  // draw order: shield (at rest)");
  s = must(s, "  } else if (LOOK.kind === 'archer') {", BRANCH);
  (0, eval)(s);
  let b = drawRockBack.toString();
  b = must(b, "const rockLeg = LOOK.kind === 'rock';", "const rockLeg = LOOK.kind === 'rock' || LOOK.kind === 'tank';");
  b = must(b, "  // arms reaching up to the rope", "  if (LOOK.kind === 'tank') __tankBack1(F, cx, base, P, pick);\n  // arms reaching up to the rope");
  b = must(b, "  if (LOOK.kind === 'archer') { F.capsule(cx + 9", "  if (LOOK.kind === 'tank') __tankBack2(F, cx, base, P, pick);\n  if (LOOK.kind === 'archer') { F.capsule(cx + 9");
  (0, eval)(b);
  (0, eval)(BACK);
  window.__strip = (frames) => {
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
}, [TANK_HELPERS, TANK_BRANCH, TANK_BACK]);

// the look: set up as Rock (male), then swap in Tank's look and palette
const lookFor = async (stage, g) => page.evaluate(([stage, g]) => {
  const c = save.chars.rock; c.look = Object.assign({ gender: 'm' }, DEFAULT_LOOK.rock.m); ensureLook('rock', c);
  setClass('rock'); buildRock(0, 0); clearTimeout(warmTimer); WARM = [];
  LOOK = { kind: 'tank', female: g === 'f', style: g === 'f' ? 'crop' : 'buzz', stage };
  CHARM = { on: false };
  const tri3 = (h, key, k = 0.28) => { PAL[key] = hex(h); PAL[key + 'S'] = shadeHex(h, -k); PAL[key + 'L'] = shadeHex(h, 0.3); };
  tri3(0xe8b996, 'skin', 0.2); PAL.skinL = shadeHex(0xe8b996, 0.25);
  tri3(0x6b6f45, 'tunic'); PAL.stripe = hex(0x6b6f45);          // olive work shirt
  tri3(0x3c3f38, 'shorts', 0.3);                                  // dark cargo trousers
  tri3(0x5a4230, 'boot', 0.35);                                   // heavy work boots
  tri3(0x6a5038, 'leather');                                      // tool belt
  PAL.trim = hex(0x55593a); PAL.trimS = hex(0x404429);
  PAL.collar = hex(0x5c6040); PAL.collarS = hex(0x474a30); PAL.ribbon = hex(0x8a8a70);
  PAL.buckleA = hex(0xc8ccd2); PAL.buckleB = hex(0x3a3f47);
  PAL.hair = hex(0x4b3d35); PAL.hairS = hex(0x33291f); PAL.hairL = hex(0x6e5e54); PAL.hairHi = hex(0x5a4c44); PAL.hairOut = hex(0x16110e);
  PAL.brow = hex(0x2a201b); PAL.lash = hex(0x1a120e); PAL.mouth = hex(0x8a4a3e);
  if (g === 'f') {   // her crop is a warm dark copper; the mouth a touch rosier
    PAL.hair = hex(0x6a3b29); PAL.hairS = hex(0x47261a); PAL.hairL = hex(0x8c5638); PAL.hairHi = hex(0xa66a46); PAL.hairOut = hex(0x1c0f0a);
    PAL.brow = hex(0x3a2016); PAL.mouth = hex(0xa04a4c);
  }
  if (stage >= 1) { tri3(0x76818e, 'boot', 0.36); }               // the back view picks these up for the boots…
  if (stage >= 2) { tri3(0x76818e, 'greave', 0.36); PAL.legPlate = true; }   // …and the leg plates
  if (stage >= 5) { tri3(0x4c535c, 'shorts', 0.35); tri3(0x76818e, 'tunic', 0.36); tri3(0x4c535c, 'warm', 0.3); tri3(0x2f343b, 'skin', 0.3); }   // under the mecha: no cloth or skin shows
  FCACHE.clear();
}, [stage, g]);

const ids = await page.evaluate(() => ANIMS.map(a => a.id).filter(id => !/^[amj]_/.test(id) || id.startsWith('a_') || id === 'j_throw' || id === 'j_push'));
// poses for Tank: a_* swap the arms so the near hand aims the pistol (with the far hand steadying it)
const setupPoses = () => page.evaluate((ids) => {
  window.__TP = {};
  for (const id of ids) {
    __TP[id] = RF[id].map((p, f) => {
      const q = Object.assign({}, p);
      if (id.startsWith('a_')) {
        q.aimSwap = true;
        if (q.ba != null && q.draw) { q.nA = q.ba - 0.35; q.nE = 0.75; }   // two-handed grip while aiming
      }
      if (id === 'j_throw') { q.noGun = true; if (f < 2) q.grenade = true; }
      if (id === 'j_push') q.noGun = true;
      return q;
    });
  }
  // ---- Tank's own poses. Limb angles: 0 = down, π/2 = forward, π = up. Lying prone the body is turned by
  // rot = 1.5, so a world angle w is drawn with the local angle w + 1.5.
  const B = o => Object.assign({}, BASE_POSE, o);
  const PR = 1.5, prone = { rot: PR, y: 20.6, x: -3, t: 0, nL: 0.06, nK: 0.25, fL: -0.08, fK: 0.55, eyes: 'fierce' };
  // prone shot: both hands on the pistol, aimed dead ahead just above the floor; the shot (frame 1) kicks the muzzle up and him back
  __TP.a_low = [[0, 0, 0], [0.13, -1.2, 0.6], [0.06, -0.6, 0.3], [0.015, -0.1, 0]].map(([kick, dx, hr]) => {
    const w = Math.PI / 2 - 0.04 + kick, a = w + PR;
    return B(Object.assign({}, prone, { x: -3 + dx, h: -1.3 - kick * 0.3, nA: a - 0.02, nE: 0.02, ba: a, fA: a - 0.3, fE: 0.6, hair: 0.3 + hr }));
  });
  // prone grenade lob with the near arm: cock it up and back, swing it over, let go on frame 2
  __TP.p_throw = [[3.4, 0.9, 1, -1.3], [2.7, 0.8, 1, -1.22], [1.75, 0.15, 0, -1.2], [1.35, 0.2, 0, -1.28], [1.2, 0.4, 0, -1.33]].map(([w, e, nade, h]) =>
    B(Object.assign({}, prone, { h, nA: w + PR, nE: e, fA: 2.35, fE: 0.9, noGun: true, grenade: !!nade, hair: 0.3 + (nade ? 0 : 0.4) })));
  // standing throw, steeply up (~60°): wind down and back, come over the top, release on frame 2
  const stand = { nL: 0.3, nK: 0.2, fL: -0.34, fK: 0.25, eyes: 'fierce', noGun: true };
  __TP.j_throwUp = [
    { nA: -0.7, nE: 1.3, fA: 0.9, fE: 0.6, t: -0.05, h: -0.1, y: 1.2, nK: 0.45, fK: 0.45, grenade: true },
    { nA: 2.9, nE: 1.3, fA: 0.6, fE: 0.4, t: -0.12, h: -0.2, y: 0.4, grenade: true },
    { nA: 2.45, nE: 0.15, fA: -0.5, fE: 0.4, t: -0.18, h: -0.28, y: -0.6, hair: 0.6 },
    { nA: 2.35, nE: 0.1, fA: -0.6, fE: 0.4, t: -0.14, h: -0.22, y: -0.4, hair: 0.4 },
    { nA: 1.2, nE: 0.6, fA: -0.4, fE: 0.4, t: -0.02, h: -0.05, y: 0.2 },
  ].map(o => B(Object.assign({}, stand, o)));
  // mid-air throw, forward and a little up: release on frame 1
  const air = { nL: 0.8, nK: 1.4, fL: 0.25, fK: 1.3, eyes: 'fierce', noGun: true };
  __TP.a_airThrow = [
    { nA: 3.0, nE: 1.4, fA: 1.2, fE: 0.5, t: -0.12, h: -0.1, grenade: true },
    { nA: 2.0, nE: 0.1, fA: -0.5, fE: 0.5, t: 0.12, h: -0.12, hair: 0.6 },
    { nA: 1.7, nE: 0.15, fA: -0.6, fE: 0.5, t: 0.14, h: -0.05, hair: 0.4 },
    { nA: 1.0, nE: 0.5, fA: -0.3, fE: 0.5, t: 0.06 },
  ].map(o => B(Object.assign({}, air, o)));
  // aim strips: frame i points the pistol at -60° + 15°·i from facing (negative = up), two-handed grip as in a_shoot
  const aimPose = (i, legs) => {
    // aiming up he tips his head back so the pistol clears his face
    const a = Math.PI / 2 + (60 - 15 * i) * Math.PI / 180, up = Math.max(0, a - Math.PI / 2), dn = Math.max(0, Math.PI / 2 - a);
    return B(Object.assign({ eyes: 'fierce', t: 0.04 - up * 0.12 + dn * 0.12, h: -up * 0.5 + dn * 0.12, nA: a - 0.02, nE: 0.02, ba: a, fA: a - 0.35, fE: 0.75 }, legs));
  };
  __TP.a_aim = Array.from({ length: 9 }, (_, i) => aimPose(i, { nL: 0.32, nK: 0.2, fL: -0.34, fK: 0.25 }));
  __TP.a_airAim = Array.from({ length: 9 }, (_, i) => aimPose(i, { nL: 0.8, nK: 1.4, fL: 0.25, fK: 1.3 }));
  window.__TMETA = { p_throw: [18, false], j_throwUp: [18, false], a_airThrow: [20, false], a_aim: [1, false], a_airAim: [1, false] };
}, ids);
const EXTRA = ['p_throw', 'j_throwUp', 'a_airThrow', 'a_aim', 'a_airAim'];
const allIds = ids.concat(EXTRA);

const manifestPath = join(OUT, 'art/hero/hero.json'), headsPath = join(OUT, 'art/hero/heads.json'), pointsPath = join(OUT, 'art/hero/tank_points.json');
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const heads = existsSync(headsPath) ? JSON.parse(readFileSync(headsPath, 'utf8')) : {};
const points = existsSync(pointsPath) ? JSON.parse(readFileSync(pointsPath, 'utf8')) : {};
const r2 = v => v ? [+v[0].toFixed(2), +v[1].toFixed(2)] : null;
const sheetCols = ['idle', 'run', 'a_shoot', 'a_shootUp', 'a_air', 'j_throw', 'slash', 'prone', 'swim', 'dash', 'climb', 'a_low', 'p_throw', 'j_throwUp', 'a_airThrow', 'a_aim', 'a_airAim'];
const sheetRows = [];

for (const g of ['m', 'f']) for (const stage of STAGES) {
  const look = `tank_${g}_${stage}`;
  await lookFor(stage, g); await setupPoses();
  const info = await page.evaluate(([ids, sheetCols]) => {
    const out = {};
    for (const id of ids) {
      const A = ANIM_BY_ID[id] ? { fps: ANIM_BY_ID[id].fps, loop: ANIM_BY_ID[id].loop } : { fps: __TMETA[id][0], loop: __TMETA[id][1] };
      const poses = __TP[id], frames = [], hd = [], mz = [], hn = [];
      for (const p of poses) {
        const Fr = drawRock(Object.assign({}, p, { wind: WIND_V[1] })), c = toCanvas(Fr);
        frames.push(c); const t = Fr.headC || (Fr.tail && [Fr.tail[0], Fr.tail[1] + 3]);   // the climbing back view has no headC
        hd.push(t ? [+t[0].toFixed(1), +t[1].toFixed(1)] : null);
        mz.push(Fr.muzzle || null); hn.push(Fr.hand || null);
      }
      out[id] = { fps: A.fps || 10, loop: !!A.loop, frames: frames.length, strip: __strip(frames), head: hd, muzzle: mz, hand: hn };
      if (id === 'idle') out[id].card = frames[0].toDataURL('image/png');
      if (sheetCols.includes(id)) out[id].sheet = frames[Math.min(frames.length - 1, id === 'idle' ? 0 : id === 'a_aim' || id === 'a_airAim' ? 2 : id.startsWith('a_') ? 1 : Math.floor(frames.length / 2))].toDataURL('image/png');
    }
    return out;
  }, [allIds, sheetCols]);
  const L = { anims: {}, tail: null };
  heads[look] = {}; points[look] = {};
  for (const id of allIds) {
    const a = info[id];
    png(`art/hero/${look}/${id}_1.png`, a.strip.url);
    L.anims[id] = { fps: a.fps, loop: a.loop, frames: a.frames, variants: [1] };
    heads[look][id] = a.head;
    points[look][id] = { muzzle: a.muzzle.map(r2), hand: a.hand.map(r2) };
  }
  manifest.looks[look] = L;
  const card = g === 'f' ? 'tank_card_f' : 'tank_card';
  if (stage === 0) png(`art/hero/${card}.png`, info.idle.card);
  if (stage === 5) png(`art/hero/${card}_mecha.png`, info.idle.card);
  sheetRows.push(sheetCols.map(id => info[id] && info[id].sheet));
  console.log(look, allIds.length, 'animations');
}
writeFileSync(manifestPath, JSON.stringify(manifest, null, 1) + '\n');
writeFileSync(headsPath, JSON.stringify(heads) + '\n');
writeFileSync(pointsPath, JSON.stringify(points) + '\n');

if (SHEET) {   // contact sheet: rows = stages, columns = animations, 3× with a muzzle marker
  const url = await page.evaluate(async (rows) => {
    const load = u => new Promise(r => { const i = new Image(); i.onload = () => r(i); i.src = u; });
    const W = 168, H = 152, K = 2, cols = rows[0].length;
    const c = document.createElement('canvas'); c.width = cols * W * K; c.height = rows.length * H * K;
    const x = c.getContext('2d'); x.imageSmoothingEnabled = false;
    for (let r = 0; r < rows.length; r++) for (let k = 0; k < cols; k++) {
      x.fillStyle = (r + k) % 2 ? '#8fb7d8' : '#a9c9e2'; x.fillRect(k * W * K, r * H * K, W * K, H * K);
      if (rows[r][k]) x.drawImage(await load(rows[r][k]), k * W * K, r * H * K, W * K, H * K);
    }
    return c.toDataURL('image/png');
  }, sheetRows);
  writeFileSync(SHEET, Buffer.from(url.split(',')[1], 'base64'));
  console.log('sheet', SHEET);
}
await browser.close();
