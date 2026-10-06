# Swapping in your own art

Every picture in the game is a plain PNG in this folder. Right now they are
"baked" copies of the art the HTML prototype draws in code. To use your own
art, overwrite a PNG with yours **using the same file name and the same
frame size**, then reopen Godot. Nothing in the code needs to change.

## Heroes (`hero/<class>_<m|f>/`)

- One folder per hero look: `rock_m`, `rock_f`, `archer_m`, `archer_f`,
  `mage_m`, `mage_f`, `summoner_m`, `summoner_f`.
- One file per animation: `<animation>_<variant>.png`, e.g. `rock_m/walk_1.png`.
- Each file is a horizontal strip of frames. Every frame is **168 × 152** px.
- The hero's feet (the point that touches the ground) sit at **x 80, y 132**
  inside every frame.
- Frame counts and playback speed live in `hero/hero.json` under `looks.<folder>.anims` (`frames`, `fps`).
  If you draw a different number of frames, change `frames` there.
- `idle`, `rest`, `walk`, `run`, `jump` and `land` have five variants (0–4):
  the hair blowing in no, light, normal, strong and stormy wind. If you only
  draw variant `1`, the game uses it for every wind level. Delete the other
  variants and remove them from the `variants` list in `hero.json`.
- Gear and cosmetics don't change the hero's picture: every hero always uses
  the starter look in their folder.
- The art is drawn at 2× (the game world is 384 × 216, shown on a
  768 × 432 canvas), so a 168 × 152 frame shows as 84 × 76 world pixels.

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

Sounds and music work the same way: replace any `.ogg` in `../audio/`.

## Re-baking from the HTML prototype

If you change the prototype and want fresh copies, run this from the repo root
(it needs Node and Playwright):

```
node tools/bake/bake.mjs "Sproutvale 2D — prototype.html" godot
```

This overwrites the PNGs and sounds, including any you replaced. Set
`ONLY=art`, `ONLY=data` or `ONLY=audio` to bake only one group.
