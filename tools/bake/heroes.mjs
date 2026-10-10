// Bakes Rock, the Archer, Remy and Jojo from the prototype's hero rasteriser (drawRock), in layers, so the
// Godot game can show every armor tier with every weapon tier without a sprite set per combination.
//
// drawRock cuts each frame into nine layers when HERO_LAYERS is set (see the prototype): body and weapon
// interleaved, B_pre W0 B0 W1 B1 W2 B2 W3 B3, so the near hand can close over a sword grip, a bow can sit
// in front of everything, and so on. This script writes:
//   godot/art/hero/<class>_<m|f>_<armor tier>/<anim>_<wind variant>.png
//       body strips: frames side by side, the five body layers stacked top to bottom (B_pre, B0 … B3)
//   godot/art/hero/gear/<set>_<tier>/<anim>.png
//       weapon strips: the four weapon layers stacked (W0 … W3). Sets: sword (Rock), bow (Archer),
//       wand and staff (Remy), ring (Jojo). Weapons are the same for both genders.
//   godot/art/hero/hero.json   looks.<class>_<m|f> (frame counts, fps, wind variants, ponytail points),
//                              with "layered": true, "armor": number of armor tiers and "gear": the weapon sets
//   godot/art/hero/heads.json  head centres per frame (for the underwater air bubble)
// The game stacks the layers back together (Assets.hero_strip). Tank is baked separately (tank.mjs).
//
// Usage:  node tools/bake/heroes.mjs ["Sproutvale 2D — prototype.html"] [godot]
//         ONLY=rock,archer  to bake some heroes;  SHEET=path.png  for a contact sheet
// Then:   python3 tools/bake/pngpal.py godot/art/hero   (lossless re-pack to palette PNGs, about a third the size)
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const SRC = resolve(process.argv[2] || 'Sproutvale 2D — prototype.html');
const OUT = resolve(process.argv[3] || 'godot');
const ONLY = (process.env.ONLY || 'rock,archer,mage,summoner').split(',');
const WIND_ANIMS = ['idle', 'rest', 'walk', 'run', 'jump', 'land'];
const PREFIX = { rock: null, archer: 'a_', mage: 'm_', summoner: 'j_' };
const SETS = { rock: [['sword', [0, 1, 2, 3]]], archer: [['bow', [0, 1, 2, 3]]], mage: [['staff', [0, 1, 3]], ['wand', [2]]], summoner: [['ring', [0, 1, 2, 3]]] };
const ARMOR_TIERS = 6, WEAPON_TIERS = 11;

const write = (rel, data) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, data); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
await page.route(/fonts\.(gstatic|googleapis)\.com/, r => r.abort());
await page.goto('file://' + SRC);

await page.evaluate(() => {
  // one frame, cut into its nine layers (canvases), with Remy's back view shrunk the same way heroFrame does
  window.__layers = (anim, vi, f) => {
    const poses = RF[anim]; f = Math.max(0, Math.min(poses.length - 1, f | 0));
    if (WINDLESS.has(anim)) vi = 1;
    HERO_LAYERS = [];
    const Fr = drawRock(Object.assign({}, poses[f], { wind: WIND_V[vi] }));
    const L = HERO_LAYERS; HERO_LAYERS = null;
    while (L.length < 9) L.push(new Uint8ClampedArray(Fr.w * Fr.h * 4));
    let tail = Fr.tail;
    const cvs = L.map(px => { const c = document.createElement('canvas'); c.width = Fr.w; c.height = Fr.h; c.getContext('2d').putImageData(new ImageData(px, Fr.w, Fr.h), 0, 0); return c; });
    if (LOOK.kind === 'mage' && poses[f].back) {
      const k = 0.84, gx = RX * CHAR_RES, gy = GROUND * CHAR_RES;
      for (let i = 0; i < cvs.length; i++) { const [c2, x2] = cv(Fr.w, Fr.h); x2.imageSmoothingEnabled = false; x2.drawImage(cvs[i], gx - gx * k, gy - gy * k, Fr.w * k, Fr.h * k); cvs[i] = c2; }
      tail = tail && [RX + (tail[0] - RX) * k, GROUND + (tail[1] - GROUND) * k];
    }
    return { cvs, tail };
  };
  // frames side by side, chosen layers stacked top to bottom
  window.__stack = (frames, rows) => {
    const w = frames[0][0].width, h = frames[0][0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h * rows.length; const x = c.getContext('2d');
    frames.forEach((L, i) => rows.forEach((r, j) => x.drawImage(L[r], i * w, j * h)));
    return { url: c.toDataURL('image/png'), w, h };
  };
  window.__setup = (cls, g, armor, weapon) => {
    const c = save.chars[cls]; c.look = Object.assign({ gender: g }, DEFAULT_LOOK[cls][g]); ensureLook(cls, c);
    c.charm = -1; c.arrows = Math.min(12, weapon); if (cls === 'mage') c.staffPreview = weapon;
    setClass(cls); clearTimeout(warmTimer); WARM = [];
    applyTierPalette(armor, weapon, -1, cls, Math.min(12, weapon)); snapshotHero();
    RF = {}; for (const A of ANIMS) RF[A.id] = sampleAnim(A);
    FCACHE.clear();
  };
});

const manifestPath = join(OUT, 'art/hero/hero.json'), headsPath = join(OUT, 'art/hero/heads.json');
const manifest = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, 'utf8')) : { frame_w: 168, frame_h: 152, origin: [80, 132], looks: {} };
const heads = existsSync(headsPath) ? JSON.parse(readFileSync(headsPath, 'utf8')) : {};
const sheet = [];

for (const cls of ['rock', 'archer', 'mage', 'summoner']) {
  if (!ONLY.includes(cls)) continue;
  const ids = await page.evaluate((prefix) => ANIMS.map(a => a.id).filter(id => !/^[amj]_/.test(id) || (prefix && id.startsWith(prefix))), PREFIX[cls]);
  for (const g of ['m', 'f']) {
    const look = `${cls}_${g}`;
    rmSync(join(OUT, 'art/hero', look), { recursive: true, force: true });   // the old one-piece sprites
    let meta = null;
    for (let a = 0; a < ARMOR_TIERS; a++) {
      rmSync(join(OUT, 'art/hero', `${look}_${a}`), { recursive: true, force: true });
      const info = await page.evaluate(([cls, g, a, ids, windy]) => {
        __setup(cls, g, a, 0);
        const out = {}, tail = HERO.look.style === 'ponytail';
        for (const id of ids) {
          const A = ANIM_BY_ID[id], n = RF[id].length, vs = windy.includes(id) && !WINDLESS.has(id) ? [0, 1, 2, 3, 4] : [1];
          out[id] = { fps: A.fps || 10, loop: !!A.loop, frames: n, variants: vs, strips: {}, head: [] };
          if (tail) out[id].tail = {};
          for (const vi of vs) {
            const fr = Array.from({ length: n }, (_, f) => __layers(id, vi, f));
            out[id].strips[vi] = __stack(fr.map(o => o.cvs), [0, 2, 4, 6, 8]).url;
            if (vi === 1) out[id].head = fr.map(o => o.tail ? [+o.tail[0].toFixed(1), +(o.tail[1] + 3).toFixed(1)] : null);
            if (tail) out[id].tail[vi] = fr.map(o => o.tail ? [+o.tail[0].toFixed(2), +o.tail[1].toFixed(2)] : null);
          }
        }
        const P = HERO.pal, rgb = k => P[k] ? '#' + P[k].map(v => v.toString(16).padStart(2, '0')).join('') : null;
        return { anims: out, tail: tail ? { hair: rgb('hair'), out: rgb('hairOut') || '#3c2814', light: rgb('hairL'), shade: rgb('hairS') } : null };
      }, [cls, g, a, ids, WIND_ANIMS]);
      for (const [id, an] of Object.entries(info.anims)) for (const [vi, url] of Object.entries(an.strips)) png(`art/hero/${look}_${a}/${id}_${vi}.png`, url);
      if (a === 0) {
        meta = { anims: {}, tail: info.tail, layered: true, armor: ARMOR_TIERS, gear: SETS[cls].map(s => s[0]) };
        heads[look] = {};
        for (const [id, an] of Object.entries(info.anims)) {
          meta.anims[id] = { fps: an.fps, loop: an.loop, frames: an.frames, variants: an.variants };
          if (an.tail) meta.anims[id].tail = an.tail;
          heads[look][id] = an.head;
        }
      }
      console.log(`${look} armor ${a}`);
    }
    manifest.looks[look] = meta;
  }
  // the weapons: same for both genders
  for (let w = 0; w < WEAPON_TIERS; w++) {
    // one strip per weapon set (Remy's wand and staff are upgraded separately)
    for (const [set, rows] of SETS[cls]) {
      rmSync(join(OUT, 'art/hero/gear', `${set}_${w}`), { recursive: true, force: true });
      const urls = await page.evaluate(([cls, w, ids, rows]) => {
        __setup(cls, 'm', 0, w);
        const keep = [1, 3, 5, 7].map((r, i) => rows.includes(i) ? r : 9);   // layer 9 = blank
        const out = {};
        for (const id of ids) {
          const fr = Array.from({ length: RF[id].length }, (_, f) => { const L = __layers(id, 1, f).cvs; const b = document.createElement('canvas'); b.width = L[0].width; b.height = L[0].height; L.push(b); return L; });
          out[id] = __stack(fr, keep).url;
        }
        return out;
      }, [cls, w, ids, rows]);
      for (const [id, url] of Object.entries(urls)) png(`art/hero/gear/${set}_${w}/${id}.png`, url);
    }
    console.log(`${cls} weapons ${w}`);
  }
}
writeFileSync(manifestPath, JSON.stringify(manifest, null, 1) + '\n');
writeFileSync(headsPath, JSON.stringify(heads) + '\n');
await browser.close();
