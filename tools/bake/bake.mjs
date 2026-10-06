// Bakes the HTML prototype's generated art, sounds and music into files the Godot project loads.
//
// The prototype draws everything with code at runtime. This script opens it in headless Chromium,
// runs those same drawing and synth functions, and saves the results as PNG and OGG files under
// godot/art and godot/audio, plus JSON data under godot/data. Swap any PNG for your own artwork
// afterwards; the game only cares about the file names and frame sizes listed in godot/art/README.md.
//
// Usage:  node tools/bake/bake.mjs ["Sproutvale 2D — prototype.html"] [godot]
// Needs:  Node 18+, the `playwright` package with Chromium, and ffmpeg (for OGG encoding).

import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, rmSync } from 'fs';
import { execFileSync } from 'child_process';
import { join, resolve, dirname } from 'path';
import { tmpdir } from 'os';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(join(execFileSync('npm', ['root', '-g']).toString().trim(), 'playwright')); }

const SRC = resolve(process.argv[2] || 'Sproutvale 2D — prototype.html');
const OUT = resolve(process.argv[3] || 'godot');
const ONLY = (process.env.ONLY || 'art,audio,data').split(',');

const write = (rel, data) => { const p = join(OUT, rel); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, data); };
const png = (rel, dataUrl) => write(rel, Buffer.from(dataUrl.split(',')[1], 'base64'));
const json = (rel, obj) => write(rel, JSON.stringify(obj, null, 1) + '\n');

const browser = await playwright.chromium.launch();
const page = await browser.newPage();
page.on('pageerror', e => console.warn('page error:', e.message));
// serve the game's web fonts from the bundled copies so painted signs use the real pixel font
const FONTS = join(OUT, 'fonts'), font64 = f => readFileSync(join(FONTS, f)).toString('base64');
await page.route(/fonts\.gstatic\.com/, r => r.abort());
await page.route(/fonts\.googleapis\.com\/css/, r => r.fulfill({ contentType: 'text/css', body:
  `@font-face{font-family:'Press Start 2P';src:url(data:font/ttf;base64,${font64('PressStart2P-Regular.ttf')})}` +
  `@font-face{font-family:'Fredoka';font-weight:500;src:url(data:font/ttf;base64,${font64('Fredoka-500.ttf')})}` +
  `@font-face{font-family:'Fredoka';font-weight:700;src:url(data:font/ttf;base64,${font64('Fredoka-700.ttf')})}` }));
await page.goto('file://' + SRC);
await page.evaluate(async () => { await document.fonts.load('8px "Press Start 2P"'); await document.fonts.ready; });

// helpers that live inside the page
await page.evaluate(() => {
  window.__strip = (frames) => {   // frames: canvases of equal size → one horizontal strip
    const w = frames[0].width, h = frames[0].height, c = document.createElement('canvas');
    c.width = w * frames.length; c.height = h; const x = c.getContext('2d');
    frames.forEach((f, i) => x.drawImage(f, i * w, 0)); return { url: c.toDataURL('image/png'), w, h, n: frames.length };
  };
  window.__url = c => c.toDataURL('image/png');
});

/* ------------------------------------------------------------------ art */
const HERO_ANIMS = ['idle', 'rest', 'walk', 'run', 'land', 'jump', 'flip', 'dash', 'block', 'slash', 'rising', 'thrust', 'spin', 'heavy', 'air',
  'climb', 'swim', 'aegis', 'air2', 'air3', 'plunge', 'plungeStart', 'plungeLand', 'crouch', 'slide', 'prone', 'crawl', 'proneStab', 'cheer', 'hurt', 'down', 'whirl'];
const WIND_ANIMS = ['idle', 'rest', 'walk', 'run', 'jump', 'land'];   // these also get the four other hair/wind variants
const MOB_TYPES = ['green', 'blue', 'red', 'silver', 'gold', 'rat', 'ferret', 'boar', 'tortoise'];
const MAP_IDS = ['home', 'house', 'meadow', 'pond', 'hollow', 'ridge'];
const THEMES = ['meadow', 'ridge', 'hollow', 'interior'];

if (ONLY.includes('art')) {
  console.log('hero…');
  const heroInfo = await page.evaluate(([ids, windy]) => {
    setClass('rock'); buildRock(0, 0); clearTimeout(warmTimer); WARM = [];
    const out = {};
    for (const id of ids) {
      const A = ANIM_BY_ID[id], n = RF[id].length, vs = windy.includes(id) && !WINDLESS.has(id) ? [0, 1, 2, 3, 4] : [1];
      out[id] = { fps: A.fps || 10, loop: !!A.loop, frames: n, variants: vs, strips: {} };
      for (const vi of vs) out[id].strips[vi] = __strip(Array.from({ length: n }, (_, f) => heroFrame(id, vi, f)));
    }
    return out;
  }, [HERO_ANIMS, WIND_ANIMS]);
  const heroManifest = { frame_w: 0, frame_h: 0, origin: [80, 132], anims: {} };
  for (const [id, a] of Object.entries(heroInfo)) {
    for (const [vi, s] of Object.entries(a.strips)) { png(`art/hero/${id}_${vi}.png`, s.url); heroManifest.frame_w = s.w; heroManifest.frame_h = s.h; }
    heroManifest.anims[id] = { fps: a.fps, loop: a.loop, frames: a.frames, variants: a.variants };
  }
  json('art/hero/hero.json', heroManifest);

  console.log('monsters…');
  const mobs = await page.evaluate((types) => {
    const out = {};
    for (const t of types) for (const [suffix, set] of [['', SF[t]], ['_shiny', SFS[t]]]) {
      const m = {};
      for (const k in set) { if (k === 'dim') continue; const v = set[k]; m[k] = __strip(Array.isArray(v) ? v : [v]); }
      out[t + suffix] = m;
    }
    return out;
  }, MOB_TYPES);
  const mobManifest = { frame_w: 88, frame_h: 72, origin: [44, 66], sets: {} };
  for (const [name, set] of Object.entries(mobs)) {
    mobManifest.sets[name] = {};
    for (const [k, s] of Object.entries(set)) { png(`art/mobs/${name}/${k}.png`, s.url); mobManifest.sets[name][k] = s.n; }
  }
  json('art/mobs/mobs.json', mobManifest);

  console.log('items…');
  const items = await page.evaluate((types) => ({ coin: __strip(COIN_F).url, res: Object.fromEntries(types.map(t => [t, __url(RES_F[t])])) }), MOB_TYPES);
  png('art/items/coin.png', items.coin);
  for (const [t, u] of Object.entries(items.res)) png(`art/items/residue_${t}.png`, u);

  console.log('maps…');
  const maps = await page.evaluate((ids) => {
    configureHome('rock');
    return Object.fromEntries(ids.map(id => [id, __url(paintMap(MAPS[id]))]));
  }, MAP_IDS);
  for (const [id, u] of Object.entries(maps)) png(`art/maps/${id}.png`, u);

  console.log('backdrops…');
  const layers = await page.evaluate((themes) => {
    const o = {}; for (const t of themes) { o[t + '_far'] = __url(paintFar(t)); o[t + '_mid'] = __url(paintMid(t)); }
    o.galaxy = __url(buildGalaxy());
    for (const kind of ['rain', 'snow']) for (let r = 22; r <= 48; r++) o[`cloud_${kind}_${r}`] = __url(cloudSprite(kind, r));
    return o;
  }, THEMES);
  for (const [k, u] of Object.entries(layers)) png(k.startsWith('cloud_') ? `art/sky/clouds/${k}.png` : `art/sky/${k}.png`, u);
}

/* ------------------------------------------------------------------ data */
if (ONLY.includes('data')) {
  console.log('data…');
  const data = await page.evaluate((ids) => {
    configureHome('rock');
    const strip = m => { const o = {}; for (const k of ['name', 'sub', 'theme', 'w', 'h', 'floorY', 'target', 'safe', 'indoor', 'plats', 'ropes', 'portals', 'spawn', 'lvBonus', 'ignoreUnlock', 'start', 'house', 'pond', 'notes', 'music', 'variant']) if (m[k] !== undefined) o[k] = m[k]; return o; };
    const pond = MAPS.pond.pond;
    const maps = Object.fromEntries(ids.map(id => [id, strip(MAPS[id])]));
    if (pond && !maps.pond.pond) maps.pond.pond = pond;
    const mobs = {}; for (const k of Object.keys(SLIME_TYPES)) mobs[k] = Object.assign({}, SLIME_TYPES[k], { residue: matName(k) });
    const anims = Object.fromEntries(ANIMS.map(a => [a.id, { fps: a.fps || 10, loop: !!a.loop, frames: sampleAnim(a).length }]));
    return { maps, mobs, moves: MOVES, anims, themes: THEMES, armor: ARMOR_TIERS, weapon: WEAPON_TIERS, ranks: RANKS, rankMult: RANK_MULT, rankCap: RANK_CAP, jobs: JOBS_BY.rock };
  }, MAP_IDS);
  json('data/game_data.json', data);
}

/* ------------------------------------------------------------------ audio */
if (ONLY.includes('audio')) {
  const tmp = join(tmpdir(), 'sproutvale-bake'); rmSync(tmp, { recursive: true, force: true }); mkdirSync(tmp, { recursive: true });
  const toOgg = (rel, b64, q = 4) => {
    const wav = join(tmp, rel.replace(/[\/]/g, '_') + '.wav'); writeFileSync(wav, Buffer.from(b64, 'base64'));
    const dst = join(OUT, rel); mkdirSync(dirname(dst), { recursive: true });
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', String(q), dst]);
  };
  await page.evaluate(() => {
    const RATE = 44100;
    window.__wav = (buf) => {   // AudioBuffer → 16-bit PCM WAV, base64
      const ch = buf.numberOfChannels, n = buf.length, bytes = new DataView(new ArrayBuffer(44 + n * ch * 2));
      const s = (o, t) => { for (let i = 0; i < t.length; i++) bytes.setUint8(o + i, t.charCodeAt(i)); };
      s(0, 'RIFF'); bytes.setUint32(4, 36 + n * ch * 2, true); s(8, 'WAVE'); s(12, 'fmt '); bytes.setUint32(16, 16, true); bytes.setUint16(20, 1, true);
      bytes.setUint16(22, ch, true); bytes.setUint32(24, buf.sampleRate, true); bytes.setUint32(28, buf.sampleRate * ch * 2, true); bytes.setUint16(32, ch * 2, true); bytes.setUint16(34, 16, true);
      s(36, 'data'); bytes.setUint32(40, n * ch * 2, true);
      const data = Array.from({ length: ch }, (_, c) => buf.getChannelData(c));
      for (let i = 0, o = 44; i < n; i++) for (let c = 0; c < ch; c++, o += 2) { const v = Math.max(-1, Math.min(1, data[c][i])); bytes.setInt16(o, v < 0 ? v * 0x8000 : v * 0x7fff, true); }
      const u8 = new Uint8Array(bytes.buffer); let bin = ''; for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
      return btoa(bin);
    };
    // point the prototype's synth at an offline context so it renders into a buffer instead of the speakers
    window.__offline = (seconds, channels = 1) => {
      const c = new OfflineAudioContext(channels, Math.ceil(seconds * RATE), RATE);
      Sfx.ctx = c; Sfx.master = c.createGain(); Sfx.master.gain.value = 1; Sfx.master.connect(c.destination);
      const len = RATE * 2, b = c.createBuffer(1, len, RATE), d = b.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      Sfx.noise = b;
      const bb = c.createBuffer(1, len, RATE), e = bb.getChannelData(0); let last = 0;
      for (let i = 0; i < len; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; e[i] = last * 3.5; }
      Sfx.brown = bb; Sfx.streak = 0; Sfx.lastCoin = -9;
      const quiet = { setTargetAtTime() {} }; Sfx.rainL = Sfx.windL = { g: { gain: quiet }, f: { frequency: quiet } };   // the page's ambience timer pokes these
      return c;
    };
    window.__sfx = async (name, args, seconds) => { const c = __offline(seconds); Sfx[name](...args); return __wav(await c.startRendering()); };
    window.__loop = async (bufName, type, freq, seconds) => {   // seamless ambient noise loops (rain, wind)
      const c = __offline(seconds + 1); const s = c.createBufferSource(); s.buffer = Sfx[bufName]; s.loop = true;
      const f = c.createBiquadFilter(); f.type = type; f.frequency.value = freq; s.connect(f); f.connect(Sfx.master); s.start();
      const buf = await c.startRendering(); const out = c.createBuffer(1, Math.ceil(seconds * RATE), RATE), o = out.getChannelData(0), src = buf.getChannelData(0), fadeN = RATE;
      for (let i = 0; i < o.length; i++) o[i] = src[i + fadeN] !== undefined ? src[i + fadeN] : 0;
      for (let i = 0; i < fadeN; i++) { const k = i / fadeN; o[o.length - fadeN + i] = o[o.length - fadeN + i] * (1 - k) + src[i] * k; }   // crossfade the tail into the head
      return __wav(out);
    };
    window.__music = async (id) => {
      const T = TRACKS[id], steps = 256, s16 = 60 / T.bpm / 4, loopLen = steps * s16, tail = 4;
      const c = __offline(loopLen + tail + 0.2, 2);
      Music.bus = c.createGain(); Music.bus.gain.value = 0.5 * T.gain;
      Music.comp = c.createDynamicsCompressor(); Music.comp.threshold.value = -18; Music.comp.ratio.value = 3;
      Music.bus.connect(Music.comp); Music.comp.connect(c.destination);
      Music.echo = c.createDelay(1); Music.echo.delayTime.value = T.crystal ? 0.48 : 0.36; Music.fb = c.createGain(); Music.fb.gain.value = T.crystal ? 0.28 : 0.32;
      Music.echoOut = c.createGain(); Music.echoOut.gain.value = T.echo ? 0.4 : T.crystal ? 0.22 : 0.12;
      Music.echo.connect(Music.fb); Music.fb.connect(Music.echo); Music.echo.connect(Music.echoOut); Music.echoOut.connect(Music.bus);
      Music.tr = T; Music.mel = buildMelody(T); Music.intensity = 0;
      for (let step = 0; step < steps; step++) { const sw = step % 2 === 1 ? s16 * (T.swing || 0) : 0; Music.playStep(step, 0.1 + step * s16 + sw, s16); }
      const buf = await c.startRendering();
      // wrap everything that rings past the loop point back onto the start, so the loop is seamless
      const n = Math.round(loopLen * c.sampleRate), off = Math.round(0.1 * c.sampleRate), out = c.createBuffer(2, n, c.sampleRate);
      for (let ch = 0; ch < 2; ch++) { const src = buf.getChannelData(ch), o = out.getChannelData(ch); for (let i = 0; i < n; i++) o[i] = src[i + off]; for (let i = n + off; i < src.length; i++) o[(i - off) % n] += src[i]; }
      return __wav(out);
    };
  });

  console.log('sound effects…');
  const SFX = {
    coin: [[], 0.6], swing: [[false], 0.4], swing_heavy: [[true], 0.5, 'swing'], hit: [[false], 0.4], hit_crit: [[true], 0.4, 'hit'], squish: [[], 0.5], jump: [[], 0.3],
    djump: [[], 0.4], dodge: [[], 0.4], land: [[], 0.3], parry: [[], 0.6], block: [[], 0.3], hurt: [[], 0.4], goo: [[], 0.3], bang: [[], 0.2], levelUp: [[], 1.4],
    thunder: [[], 3.6], buy: [[], 0.6], slam: [[], 0.7], slide: [[], 0.6], guard: [[], 0.3], rope: [[], 0.3], swim: [[], 0.4], ui: [[], 0.2], buff: [[], 0.6],
    step_grass: [[false, 'grass'], 0.2, 'step'], step_grass_heavy: [[true, 'grass'], 0.2, 'step'], step_wood: [[false, 'wood'], 0.2, 'step'], step_snow: [[false, 'snow'], 0.2, 'step'], step_wet: [[false, 'wet'], 0.2, 'step'],
    whoosh: [[1, false], 0.3], whoosh_heavy: [[0.7, true], 0.4, 'whoosh'],
  };
  for (let r = 4; r <= 9; r++) SFX['rankUp_' + r] = [[r], 0.5, 'rankUp'];
  for (const [file, [args, secs, fn]] of Object.entries(SFX)) toOgg(`audio/sfx/${file}.ogg`, await page.evaluate(([f, a, s]) => __sfx(f, a, s), [fn || file, args, secs]), 5);
  // one-off tones the game plays directly (Sfx.tone / Sfx.burst calls scattered through the code)
  const TONES = {
    portal: ['tone', [520, 0.25, 'sine', 0.12, 980], 0.4], aggro_critter: ['tone', [1500, 0.06, 'square', 0.05, 2100], 0.2], lunge: ['tone', [300, 0.12, 'sine', 0.1, 520], 0.3],
    lunge_critter: ['tone', [1300, 0.08, 'square', 0.06, 700], 0.2], charge: ['tone', [140, 0.25, 'sawtooth', 0.08, 90], 0.4], spin_start: ['tone', [600, 0.2, 'triangle', 0.06, 1200], 0.3],
    shell_clink: ['tone', [900, 0.06, 'square', 0.05, 700], 0.2], plunge_start: ['tone', [700, 0.15, 'square', 0.06, 1200], 0.3], dodge_perfect: ['tone', [900, 0.2, 'triangle', 0.1, 1400], 0.3],
    note: ['tone', [440, 0.4, 'sine', 0.05, 330], 0.5], splash: ['burst', [0.3, 'bandpass', 1400, 300, 0.3], 0.4],
  };
  for (const [file, [fn, args, secs]] of Object.entries(TONES)) toOgg(`audio/sfx/${file}.ogg`, await page.evaluate(([f, a, s]) => __sfx(f, a, s), [fn, args, secs]), 5);
  const combo = async (calls, secs) => page.evaluate(async ([cs, s]) => { const c = __offline(s); for (const [f, a] of cs) Sfx[f](...a); return __wav(await c.startRendering()); }, [calls, secs]);
  toOgg('audio/sfx/critter_die.ogg', await combo([['tone', [1700, 0.1, 'square', 0.07, 900]], ['tone', [1200, 0.15, 'square', 0.05, 600, 0.08]]], 0.4), 5);
  toOgg('audio/sfx/potion.ogg', await combo([['tone', [520, 0.12, 'sine', 0.07, 880]], ['tone', [780, 0.15, 'triangle', 0.05, 1200, 0.08]]], 0.4), 5);
  toOgg('audio/sfx/cheer.ogg', await combo([['tone', [660, 0.12, 'triangle', 0.08, 880]], ['tone', [990, 0.2, 'triangle', 0.07, 1320, 0.12]]], 0.5), 5);
  toOgg('audio/sfx/empty.ogg', await combo([['tone', [160, 0.12, 'square', 0.05, 120]]], 0.3), 5);
  console.log('ambience…');
  toOgg('audio/ambience/rain.ogg', await page.evaluate(() => __loop('noise', 'lowpass', 1400, 6)), 3);
  toOgg('audio/ambience/wind.ogg', await page.evaluate(() => __loop('brown', 'bandpass', 420, 6)), 3);

  console.log('music…');
  for (const id of ['home', 'house', 'meadow', 'pond', 'hollow', 'ridge', 'trophy', 'lair', 'crimson', 'warlord', 'sel_rock']) {
    toOgg(`audio/music/${id}.ogg`, await page.evaluate(id => __music(id), id), 4);
    console.log('  ', id);
  }
  rmSync(tmp, { recursive: true, force: true });
}

await browser.close();
console.log('done →', OUT);
