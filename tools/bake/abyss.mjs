// Bakes the art for the areas beyond the Warlord's Keep (the Abyss maps, their monsters and The Dreamer).
//
// These areas were made for the Godot version only, so their drawing code lives in abyss_art.js rather than
// in the HTML prototype. This script opens a blank page in headless Chromium, runs that drawing code and
// saves PNG and JSON files under godot/art/abyss (same layout as godot/art, so the game finds them the same
// way). Swap any PNG for your own artwork afterwards; godot/art/README.md lists the sizes.
//
// Usage:  node tools/bake/abyss.mjs [godot]
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, rmSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const HERE = dirname(fileURLToPath(import.meta.url));
const GODOT = resolve(process.argv[2] || 'godot');
const OUT = join(GODOT, 'art', 'abyss');
const data = JSON.parse(readFileSync(join(GODOT, 'data', 'abyss.json'), 'utf8'));

const write = (rel, buf) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, buf); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));
const json = (rel, obj) => write(rel, JSON.stringify(obj, null, 1) + '\n');

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
page.on('console', m => { if (m.type() === 'error') console.warn('page:', m.text()); });
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ path: join(HERE, 'abyss_art.js') });
await page.evaluate(() => {
  window.__strip = (frames) => {
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
  window.__url = c => c.toDataURL('image/png');
});

for (const d of ['mobs', 'maps', 'sky', 'items', 'boss']) rmSync(join(OUT, d), { recursive: true, force: true });

// ---- monsters: one strip per animation, plus the manifest the game merges into art/mobs/mobs.json
const mobs = await page.evaluate(() => {
  const all = ABYSS.bakeMobs(), out = {};
  for (const [name, set] of Object.entries(all)) {
    const keys = {};
    for (const [k, fr] of Object.entries(set.sets)) keys[k] = __strip(fr);
    out[name] = { keys, dim: set.dim };
  }
  return out;
});
const manifest = { sets: {} };
for (const [name, set] of Object.entries(mobs)) {
  const first = Object.values(set.keys)[0];
  manifest.sets[name] = { w: first.w, h: first.h, dim: set.dim, keys: {} };
  for (const [k, s] of Object.entries(set.keys)) { png(`mobs/${name}/${k}.png`, s.url); manifest.sets[name].keys[k] = s.n; }
}
json('mobs/mobs.json', manifest);
console.log('monsters:', Object.keys(mobs).length, 'sets');

// ---- The Dreamer (head, eyes, mouth, portrait)
const dr = await page.evaluate(() => {
  const d = ABYSS.bakeDreamer(), out = {};
  for (const [k, fr] of Object.entries(d)) out[k] = __strip(fr);
  return out;
});
for (const [k, s] of Object.entries(dr)) png(`boss/dreamer_${k}.png`, s.url);
console.log('dreamer:', Object.entries(dr).map(([k, s]) => `${k} ${s.w}x${s.h}x${s.n}`).join(', '));

// ---- items
const items = await page.evaluate(() => {
  const out = {};
  for (const [k, c] of Object.entries(ABYSS.ITEMS)) out[k] = __url(c);
  out.dream_key = __url(ABYSS.dreamKey());
  return out;
});
for (const [k, u] of Object.entries(items)) png(`items/${k}.png`, u);

// ---- backdrops
const sky = await page.evaluate(() => ({
  abyss_far: __url(ABYSS.farShore()), abyss_mid: __url(ABYSS.midShore()),
  abyssdeep_far: __url(ABYSS.farDeep()), abyssdeep_mid: __url(ABYSS.midDeep()),
  abyssruin_far: __url(ABYSS.farRuin()), abyssruin_mid: __url(ABYSS.midRuin()),
  bubble_0: __url(ABYSS.bubbleFilm(5)), bubble_1: __url(ABYSS.bubbleFilm(17)), bubble_2: __url(ABYSS.bubbleFilm(29)),
}));
for (const [k, u] of Object.entries(sky)) png(`sky/${k}.png`, u);

// ---- maps: the painted terrain plus the list of glowing spots the game lights up
for (const [id, M] of Object.entries(data.maps)) {
  const m = await page.evaluate(([id, M]) => { const r = ABYSS.paintMap(id, M); return { url: __url(r.canvas), glows: r.glows }; }, [id, M]);
  png(`maps/${id}.png`, m.url);
  json(`maps/${id}.json`, { glows: m.glows });
  console.log('map', id, m.glows.length, 'glows');
}

await browser.close();
