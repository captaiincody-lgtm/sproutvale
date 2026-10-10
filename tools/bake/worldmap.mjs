// Bakes the World Map's painted layers (tools/bake/worldmap_art.js) into godot/art/worldmap/:
// base.webp (sea + home island), crimson.webp, abyss.webp and north.webp (lossy WebP: they are painted, not pixel art), each 1500 × 960 covering map units
// x 0…1000, y -210…430. The game draws them under the area markers and portal paths (ui.gd drawWorldMap).
//
// Usage:  node tools/bake/worldmap.mjs [godot]
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }
const OUT = resolve(process.argv[2] || 'godot');
const here = dirname(fileURLToPath(import.meta.url));

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
await page.setContent('<html><body></body></html>');
await page.addScriptTag({ content: readFileSync(join(here, 'worldmap_art.js'), 'utf8') });
const out = await page.evaluate(() => paintAll());
for (const [k, url] of Object.entries(out)) {
  const p = join(OUT, 'art/worldmap', k + '.webp'); mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, Buffer.from(url.split(',')[1], 'base64')); console.log('worldmap', k);
}
await browser.close();
