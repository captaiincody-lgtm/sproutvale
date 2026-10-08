// Bakes the art for the climb up the Abyssal Volcano (Coldstone Foothills, Whiteout Ridge, Icefang Cave,
// King Yeti's Throne and Glamrax's Gate), their monsters and King Yeti.
//
// Like abyss.mjs: opens a blank page in headless Chromium, runs the drawing code in climb_art.js and saves
// PNG and JSON files under godot/art/climb (same layout as godot/art/abyss). Swap any PNG for your own
// artwork afterwards, keeping the sizes and anchors.
//
// Usage:  node tools/bake/climb.mjs [godot]
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
const OUT = join(GODOT, 'art', 'climb');
const data = JSON.parse(readFileSync(join(GODOT, 'data', 'climb.json'), 'utf8'));
// CLIMB_ONLY=mobs,boss,items,sky,maps bakes just those parts (handy while drawing)
const ONLY = (process.env.CLIMB_ONLY || 'mobs,boss,items,sky,maps').split(',');

const write = (rel, buf) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, buf); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));
const json = (rel, obj) => write(rel, JSON.stringify(obj, null, 1) + '\n');

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
let errors = 0;
page.on('pageerror', e => { errors++; console.warn('page error:', e.message); });
page.on('console', m => { if (m.type() === 'error') { errors++; console.warn('page:', m.text()); } });
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ path: join(HERE, 'climb_art.js') });
await page.evaluate(() => {
  window.__strip = (frames) => {
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
  window.__url = c => c.toDataURL('image/png');
});

for (const d of ONLY) rmSync(join(OUT, d), { recursive: true, force: true });
if (ONLY.includes('boss')) rmSync(join(OUT, 'items'), { recursive: true, force: true });

// ---- monsters: one strip per animation, plus the manifest (same format as art/abyss/mobs/mobs.json)
if (ONLY.includes('mobs')) {
  const names = await page.evaluate(() => Object.keys(CLIMB.SETS));
  const manifest = { sets: {} };
  for (const n of names) {   // one monster at a time keeps the page's memory down
    const mobs = await page.evaluate((n) => {
      const all = CLIMB.bakeMobs([n]), out = {};
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

// ---- King Yeti: animation strips, the hand/neck points, his sword, portrait, the throne and his projectiles
if (ONLY.includes('boss')) {
  const b = await page.evaluate(() => {
    const y = CLIMB.bakeYeti(), out = { strips: {}, meta: y.meta, pics: {} };
    for (const [k, fr] of Object.entries(y.strips)) out.strips[k] = __strip(fr);
    for (const [k, c] of Object.entries(y.pics)) out.pics[k] = __url(c);
    return out;
  });
  for (const [k, s] of Object.entries(b.strips)) png(`boss/yeti_${k}.png`, s.url);
  for (const [k, u] of Object.entries(b.pics)) png(k, u);
  json('boss/yeti.json', b.meta);
  console.log('king yeti:', Object.entries(b.strips).map(([k, s]) => `${k}×${s.n}`).join(' '));
}

// ---- items
if (ONLY.includes('boss') || ONLY.includes('items')) {
  const items = await page.evaluate(() => {
    const out = {};
    for (const [k, c] of Object.entries(CLIMB.ITEMS)) out[k] = __url(c);
    out.yeti_pendant = __url(CLIMB.pendantItem());
    return out;
  });
  for (const [k, u] of Object.entries(items)) png(`items/${k}.png`, u);
}

// ---- backdrops
if (ONLY.includes('sky')) {
  const sky = await page.evaluate(() => {
    const out = {};
    for (const [k, fn] of Object.entries(CLIMB.SKY)) out[k] = __url(fn());
    return out;
  });
  for (const [k, u] of Object.entries(sky)) png(`sky/${k}.png`, u);
  console.log('backdrops:', Object.keys(sky).join(' '));
}

// ---- maps: the painted terrain plus the list of glowing spots the game lights up
if (ONLY.includes('maps')) {
  const jobs = Object.entries(data.maps).map(([id, M]) => [id, M]);
  // the throne room after the cave-in: rubble mounds instead of the flat floor, and the broken throne
  const c4 = data.maps.climb4;
  jobs.splice(jobs.findIndex(j => j[0] === 'climb4') + 1, 0, ['climb4_ruin', { ...c4, ruin: true, floor: [[20, 150, 270], [150, 210, 260], [210, 430, 270], [430, 500, 256], [500, 620, 270]] }]);
  const want = process.env.CLIMB_MAPS ? process.env.CLIMB_MAPS.split(',') : null;
  for (const [id, M] of jobs) {
    if (want && !want.includes(id)) continue;
    const m = await page.evaluate(([id, M]) => { const r = CLIMB.paintMap(id, M); return { url: __url(r.canvas), glows: r.glows }; }, [id, M]);
    png(`maps/${id}.png`, m.url);
    json(`maps/${id}.json`, { glows: m.glows });
    console.log('map', id, m.glows.length, 'glows');
  }
}

await browser.close();
if (errors) { console.error(errors, 'page error(s)'); process.exit(1); }
