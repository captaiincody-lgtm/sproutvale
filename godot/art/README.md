# Swapping in your own art

Every picture in the game is a plain PNG in this folder. Right now they are
"baked" copies of the art the HTML prototype draws in code. To use your own
art, overwrite a PNG with yours **using the same file name and the same
frame size**, then reopen Godot. Nothing in the code needs to change.

## Heroes (`hero/`)

Rock, the Archer, Remy and Jojo are drawn in **layers**, so every armor tier can be worn with every
weapon tier without a separate drawing for each combination:

- `hero/<class>_<m|f>_<armor tier>/<animation>_<variant>.png` — the hero's body in that armor tier (0–5),
  e.g. `rock_f_3/walk_1.png`.
- `hero/gear/<set>_<tier>/<animation>.png` — a weapon in that tier (0–10). The sets are `sword` (Rock's
  sword and shield), `bow`, `wand` and `staff` (Remy), and `ring` (Jojo's ring, earring and spirit gems).
  Weapons are shared by both genders.
- Each file is a horizontal strip of frames. Every frame is **168 × 152** px, with the hero's feet at
  **x 80, y 132**.
- The layers are stacked **top to bottom** inside each file, one frame-height (152 px) apart:
  body files have 5 rows, weapon files 4. The game draws them in this order:
  body row 1 · weapon row 1 · body row 2 · weapon row 2 · body row 3 · weapon row 3 · body row 4 · weapon row 4 · body row 5.
  (For Rock: back hair · shield · body and head · sword · near arm · raised shield · slash trails.)
- **Your own art can be simpler:** a body file that is a single row (152 px tall) is used as the whole hero,
  with the weapon rows drawn on top of it.
- Frame counts and playback speed live in `hero/hero.json` under `looks.<class>_<m|f>.anims`.
- `idle`, `rest`, `walk`, `run`, `jump` and `land` have five variants (0–4): the hair blowing in no, light,
  normal, strong and stormy wind. If you only draw variant `1`, the game uses it for every wind level.
- Tank is drawn in one piece per exosuit stage: `hero/tank_<m|f>_<0-5>/<animation>_1.png`.
- The art is drawn at 2× (the game world is 384 × 216, shown on a 768 × 432 canvas), so a 168 × 152 frame
  shows as 84 × 76 world pixels.
- To re-bake the heroes from the prototype's drawing code (this overwrites the hero PNGs):
  `node tools/bake/heroes.mjs` then `python3 tools/bake/pngpal.py godot/art/hero`, and `node tools/bake/tank.mjs` for Tank.

## Monsters (`mobs/<monster>/`)

- One strip per pose, e.g. `mobs/green/hop.png`. Frames are **88 × 72** px,
  with the feet at **x 44, y 66**. Frame counts are in `mobs/mobs.json`.
- `<monster>_shiny/` folders hold the rare shiny recolours.

## Everything else

| Folder | What | Notes |
|---|---|---|
| `maps/<map>.png` | The whole level (ground, platforms, signs) | 2× the map size; `home_<class>`/`house_<class>` are each hero's room and house |
| `sky/<theme>_far.png`, `_mid.png` | Far and near background layers | Tiled sideways, scrolled slower than the level |
| `sky/galaxy.png`, `sky/clouds/` | Night sky, rain and snow clouds | |
| `items/coin.png` | Spinning coin | 4 frames of 9 × 9 |
| `items/residue_<monster>.png` | Material each monster drops | |
| `worldmap/base.webp`, `crimson.webp`, `abyss.webp`, `north.webp` | The painted World Map: the home island, then each region as it opens | 1500 × 960, covering map x 0–1000, y -210–430; re-bake with `node tools/bake/worldmap.mjs godot` |

Sounds and music work the same way: replace any `.ogg` in `../audio/`.

## The Abyss (`abyss/`)

The areas past the Warlord's Keep (the five Abyss maps, their monsters, The
Dreamer and the bubble) were made for the Godot version only, so their art
lives in its own folder with the same layout. The game looks in `abyss/` for
any file it can't find in the main folders.

| File | What | Size |
|---|---|---|
| `abyss/mobs/<monster>/<pose>.png` | Toad, seagull, bass, crab, shark, squid, orca, octopus | Strips of frames; frame size and counts per monster are in `abyss/mobs/mobs.json` (`w`, `h`, `keys`). Sprites face right. `_shiny` and `_elite` folders are the recolours |
| `abyss/boss/dreamer_head.png` | The Dreamer's head, rising behind the floor | 560 × 340 |
| `abyss/boss/dreamer_eye.png` | One eye (used for both) | 4 frames of 64 × 44: open, glowing, shut, hurt |
| `abyss/boss/dreamer_mouth.png` | The mouth | 2 frames of 120 × 96: closed, open |
| `abyss/boss/dreamer_portrait.png` | Bestiary picture and monster card | 2 frames of 220 × 170: calm, glaring |
| `abyss/maps/<map>.png` | Each level, painted at 2× | `<map>.json` lists the spots that glow (runes, seaweed) as `[x, y, radius, colour]` in world pixels |
| `abyss/sky/abyss_*`, `abyssdeep_*`, `abyssruin_*` | Background layers: the surface, the deep and the ruins | `_far` 1536 × 240, `_mid` 1536 × 180 |
| `abyss/sky/bubble_0..2.png` | The colours racing round inside the bubble | 768 × 432 |
| `abyss/items/residue_<monster>.png`, `dream_key.png` | Materials and the Dream Key | 9 × 9 and 32 × 32 |

The tentacles are drawn by the game (a chain of circles), not from a PNG.
To re-bake the Abyss art and music from their generators (this overwrites
any PNGs you replaced in `abyss/`):

```
node tools/bake/abyss.mjs godot
python3 tools/bake/abyss_music.py godot
```

## Re-baking from the HTML prototype

If you change the prototype and want fresh copies, run this from the repo root
(it needs Node and Playwright):

```
node tools/bake/bake.mjs "Sproutvale 2D — prototype.html" godot
```

This overwrites the PNGs and sounds, including any you replaced. Set
`ONLY=art`, `ONLY=data` or `ONLY=audio` to bake only one group.
