// Bakes the art for Glamrax's volcano (the laboratory, the containment bay, the cell block and the
// sanctum) and its five security monsters.
//
// Like climb.mjs: opens a blank page in headless Chromium, runs the drawing code in volcano_art.js and
// saves PNG and JSON files under godot/art/volcano (same layout as godot/art/climb). Swap any PNG for
// your own artwork afterwards, keeping the sizes and anchors.
//
// Usage:  node tools/bake/volcano.mjs [godot]
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
const OUT = join(GODOT, 'art', 'volcano');
const data = JSON.parse(readFileSync(join(GODOT, 'data', 'volcano.json'), 'utf8'));
// VOLCANO_ONLY=mobs,items,maps bakes just those parts (handy while drawing)
const ONLY = (process.env.VOLCANO_ONLY || 'mobs,items,maps').split(',');

const write = (rel, buf) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, buf); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));
const json = (rel, obj) => write(rel, JSON.stringify(obj, null, 1) + '\n');

const launch = { args: ['--no-sandbox'] };
if (process.env.CHROMIUM) launch.executablePath = process.env.CHROMIUM;
const browser = await playwright.chromium.launch(launch);
const page = await browser.newPage();
let errors = 0;
page.on('pageerror', e => { errors++; console.warn('page error:', e.message); });
page.on('console', m => { if (m.type() === 'error') { errors++; console.warn('page:', m.text()); } });
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ path: join(HERE, 'volcano_art.js') });
await page.evaluate(() => {
  window.__strip = (frames) => {
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
  window.__url = c => c.toDataURL('image/png');
});

for (const d of ONLY) rmSync(join(OUT, d), { recursive: true, force: true });

// ---- monsters: one strip per animation, plus the manifest (same format as art/climb/mobs/mobs.json)
if (ONLY.includes('mobs')) {
  const names = await page.evaluate(() => Object.keys(VOLC.SETS));
  const manifest = { sets: {} };
  for (const n of names) {
    const mobs = await page.evaluate((n) => {
      const all = VOLC.bakeMobs([n]), out = {};
      for (const [name, set] of Object.entries(all)) {
        const keys = {};
        for (const [k, fr] of Object.entries(set.sets)) keys[k] = __strip(fr);
        out[name] = { keys, dim: set.dim };
      }
      return out;
    }, n);
    for (const [name, set] of Object.entries(mobs)) {
      const first = Object.values(set.keys)[0];
      manifest.sets[name] = { w: first.w, h: first.h, dim: set.dim, keys: {} };
      for (const [k, s] of Object.entries(set.keys)) { png(`mobs/${name}/${k}.png`, s.url); manifest.sets[name].keys[k] = s.n; }
    }
  }
  json('mobs/mobs.json', manifest);
  console.log('monsters:', Object.keys(manifest.sets).length, 'sets');
}

// ---- items
if (ONLY.includes('items')) {
  const items = await page.evaluate(() => { const out = {}; for (const [k, c] of Object.entries(VOLC.ITEMS)) out[k] = __url(c); return out; });
  for (const [k, u] of Object.entries(items)) png(`items/${k}.png`, u);
  console.log('items:', Object.keys(items).length);
}

// ---- maps: the painted rooms plus their glows and the spots where the game draws moving things
if (ONLY.includes('maps')) {
  const want = process.env.VOLCANO_MAPS ? process.env.VOLCANO_MAPS.split(',') : null;
  for (const [id, M] of Object.entries(data.maps)) {
    if (want && !want.includes(id)) continue;
    const m = await page.evaluate(([id, M]) => { const r = VOLC.paintMap(id, M); return { url: __url(r.canvas), glows: r.glows, spots: r.spots }; }, [id, M]);
    png(`maps/${id}.png`, m.url);
    json(`maps/${id}.json`, { glows: m.glows, spots: m.spots });
    console.log('map', id, m.glows.length, 'glows', Object.keys(m.spots).join(' '));
  }
}

await browser.close();
if (errors) { console.error(errors, 'page error(s)'); process.exit(1); }
