// Quick contact sheet of hero frames straight from the prototype's drawing code (no layers), for checking
// art changes before a full bake.
// Usage: node tools/bake/hero_preview.mjs out.png [cls=rock] [g=m] [armor=0] [weapon=0] [anims=idle:0,run:2,...] [scale=2]
import { createRequire } from 'module';
import { writeFileSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve } from 'path';
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }
const PROTO = process.env.PROTO || 'Sproutvale 2D — prototype.html';
const [out, cls = 'rock', g = 'm', armor = '0', weapon = '0', anims = 'idle:0,walk:3,run:2,jump:1,slash:3,block:0,hurt:0,cheer:0', scale = '2'] = process.argv.slice(2);
const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
await page.route(/fonts\.(gstatic|googleapis)\.com/, r => r.abort());
await page.goto('file://' + resolve(PROTO));
const url = await page.evaluate(([cls, g, armor, weapon, anims, scale]) => {
  const c = save.chars[cls]; c.look = Object.assign({ gender: g }, DEFAULT_LOOK[cls][g]); ensureLook(cls, c);
  c.charm = -1; c.arrows = Math.min(12, weapon); if (cls === 'mage') c.staffPreview = weapon;
  setClass(cls); clearTimeout(warmTimer); WARM = [];
  applyTierPalette(armor, weapon, -1, cls, Math.min(12, weapon)); snapshotHero();
  RF = {}; for (const A of ANIMS) RF[A.id] = sampleAnim(A); FCACHE.clear();
  const list = anims.split(',').map(s => s.split(':'));
  const frames = list.map(([id, f]) => { const poses = RF[id]; const p = poses[Math.min(poses.length - 1, +f)]; return drawRock(Object.assign({}, p, { wind: WIND_V[1] })); });
  const w = frames[0].w, h = frames[0].h, cvs = document.createElement('canvas');
  cvs.width = w * frames.length * scale; cvs.height = h * scale; const x = cvs.getContext('2d'); x.imageSmoothingEnabled = false;
  x.fillStyle = '#78a070'; x.fillRect(0, 0, cvs.width, cvs.height);
  frames.forEach((F, i) => { const c = document.createElement('canvas'); c.width = F.w; c.height = F.h; c.getContext('2d').putImageData(new ImageData(F.px, F.w, F.h), 0, 0); x.drawImage(c, i * w * scale, 0, w * scale, h * scale); });
  return cvs.toDataURL('image/png');
}, [cls, g, +armor, +weapon, anims, +scale]);
writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
await browser.close();
