// Records where each hero's head is in every animation frame, for things drawn on the head
// (the air bubble underwater). Runs the prototype's own drawing code, like bake.mjs, and writes
// godot/art/hero/heads.json: { "<look>": { "<anim>": [[x, y], ...one per frame] } } in the same
// units as the tail points in hero.json (hero pixels, feet at RX, GROUND).
//
// Usage:  node tools/bake/heads.mjs ["Sproutvale 2D — prototype.html"] [godot]
// Needs:  Node 18+ and the `playwright` package with Chromium.

import { createRequire } from 'module';
import { mkdirSync, writeFileSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const SRC = resolve(process.argv[2] || 'Sproutvale 2D — prototype.html');
const OUT = resolve(process.argv[3] || 'godot');
const LOOKS = [['rock', 'm'], ['rock', 'f'], ['archer', 'm'], ['archer', 'f'], ['mage', 'm'], ['mage', 'f'], ['summoner', 'm'], ['summoner', 'f']];
const PREFIX = { rock: null, archer: 'a_', mage: 'm_', summoner: 'j_' };

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
await page.route(/fonts\.(gstatic|googleapis)\.com/, r => r.abort());
await page.goto('file://' + SRC);

const heads = {};
for (const [cls, g] of LOOKS) {
  heads[`${cls}_${g}`] = await page.evaluate(([cls, g, prefix]) => {
    const c = save.chars[cls]; c.look = Object.assign({ gender: g }, DEFAULT_LOOK[cls][g]); ensureLook(cls, c);
    setClass(cls); buildRock(0, 0); clearTimeout(warmTimer); WARM = [];
    const out = {};
    for (const id of ANIMS.map(a => a.id).filter(id => !/^[amj]_/.test(id) || (prefix && id.startsWith(prefix)))) {
      out[id] = RF[id].map((_, f) => { const t = heroFrame(id, 1, f).tail; return t ? [+t[0].toFixed(1), +(t[1] + 3).toFixed(1)] : null; });
    }
    return out;
  }, [cls, g, PREFIX[cls]]);
  console.log('heads', cls, g, Object.keys(heads[`${cls}_${g}`]).length, 'animations');
}
const p = join(OUT, 'art/hero/heads.json');
mkdirSync(dirname(p), { recursive: true });
writeFileSync(p, JSON.stringify(heads) + '\n');
await browser.close();
