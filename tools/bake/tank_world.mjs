// Bakes the world art for Tank, the fifth hero: his empty home field, the inside of his futuristic house,
// the cardboard box / meteor / house exterior, his drone and robot, grenade and part icons, and his
// weapon effects.
//
// The home field is painted by the HTML prototype's own map painter (the meadow home field with no house
// on it), so it matches the other heroes' fields exactly. Everything else is drawn by tank_art.js in a blank
// page. Output: godot/art/maps/home_tank.png, godot/art/maps/house_tank.png and godot/art/tank/*.png plus
// godot/art/tank/tank.json (frame counts and frame sizes in world units).
//
// Usage:  node tools/bake/tank_world.mjs ["Sproutvale 2D — prototype.html"] [godot]
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = resolve(process.argv[2] || 'Sproutvale 2D — prototype.html');
const GODOT = resolve(process.argv[3] || 'godot');
const ART = join(GODOT, 'art');

const write = (rel, buf) => { const p = join(ART, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, buf); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));

const browser = await playwright.chromium.launch();
const helpers = () => {
  window.__strip = (frames) => {
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
  window.__url = c => c.toDataURL('image/png');
};

// ---- the home field: the prototype's meadow home with nothing built on it
{
  const page = await browser.newPage();
  page.on('pageerror', e => console.warn('page error:', e.message));
  const FONTS = join(GODOT, 'fonts'), font64 = f => readFileSync(join(FONTS, f)).toString('base64');
  await page.route(/fonts\.gstatic\.com/, r => r.abort());
  await page.route(/fonts\.googleapis\.com\/css/, r => r.fulfill({ contentType: 'text/css', body:
    `@font-face{font-family:'Press Start 2P';src:url(data:font/ttf;base64,${font64('PressStart2P-Regular.ttf')})}` +
    `@font-face{font-family:'Fredoka';font-weight:500;src:url(data:font/ttf;base64,${font64('Fredoka-500.ttf')})}` +
    `@font-face{font-family:'Fredoka';font-weight:700;src:url(data:font/ttf;base64,${font64('Fredoka-700.ttf')})}` }));
  await page.goto('file://' + SRC);
  await page.evaluate(helpers);
  const url = await page.evaluate(() => {
    configureHome('rock');
    const M = MAPS.home, keep = { house: M.house, tree: M.tree, hill: M.hill, modern: M.modern };
    // no house and no tree; `hill` only keeps the scattered trees and bushes clear of the middle of the field
    // (where the box sits and the meteor lands) — its painter is stubbed out so nothing is drawn there
    Object.assign(M, { house: null, tree: null, modern: null, hill: 470 });
    const realHill = window.paintHobbitHill; window.paintHobbitHill = () => {};
    const u = __url(paintMap(M));
    window.paintHobbitHill = realHill; Object.assign(M, keep);
    return u;
  });
  png('maps/home_tank.png', url);
  await page.close();
}

// ---- everything else from tank_art.js
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
page.on('console', m => { if (m.type() === 'error') console.warn('page:', m.text()); });
await page.setContent('<!doctype html><html><body></body></html>');
await page.addScriptTag({ path: join(HERE, 'tank_art.js') });
await page.evaluate(helpers);

const out = await page.evaluate(() => {
  const K = TANK, o = {}, n = (k, frames) => { o[k] = __strip(frames); };
  const seq = (len, fn) => Array.from({ length: len }, (_, i) => fn(i));
  n('box', [K.box()]);
  n('box_wreck', [K.boxWreck()]);
  n('meteor', seq(4, K.meteor));
  n('house', [K.houseExterior()]);
  for (let t = 0; t < 4; t++) n('drone_' + t, seq(4, f => K.drone(t, f)));
  for (let t = 0; t < 3; t++) for (const [pose, len] of [['idle', 4], ['walk', 6], ['attack', 4]]) n(`bot_${t}_${pose}`, seq(len, f => K.bot(t, pose, f)));
  for (const [k, fn] of Object.entries(K.ICONS)) n(k, [fn()]);
  n('bullet', [K.bullet()]);
  n('energy_bolt', seq(3, K.energyBolt));
  n('explosion', seq(7, K.explosion));
  n('energy_burst', seq(6, K.energyBurst));
  n('napalm', seq(4, K.napalm));
  o.__house = __url(K.paintInterior());
  return o;
});

png('maps/house_tank.png', out.__house); delete out.__house;
const manifest = {};
for (const [k, s] of Object.entries(out)) { png(`tank/${k}.png`, s.url); manifest[k] = { frames: s.n, w: s.w / 2, h: s.h / 2 }; }
write('tank/tank.json', JSON.stringify(manifest, null, 1) + '\n');
console.log('tank art:', Object.entries(manifest).map(([k, m]) => `${k} ${m.w}x${m.h}x${m.frames}`).join(', '));

await browser.close();
