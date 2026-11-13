# Pixel-art tools

Python scripts that keep Sproutvale's sprites crisp, shaded and on a true pixel grid. They need
Python 3 with Pillow, NumPy and SciPy (`pip install pillow numpy scipy`).

| Script | What it's for |
|---|---|
| `shade.py` | Gives flat-coloured sprites real volume: form shading, hue-shifted shadows and highlights, contact shadows, a rim light and a tinted outline. Works on the game's monsters, or on anything you paint in flat colours. |
| `clean.py` | Turns an AI-made, upscaled or blurry sprite sheet into true pixel art: measures the real pixel size, snaps to the grid, locks every frame to one shared palette, and slices the frames out on the game's frame size. |
| `mobset.py` | Builds a complete monster folder the game can load (all the poses, the hit flash, the shiny and elite recolours, the `mobs.json` entry) from a handful of cleaned frames and a small recipe. |
| `pixelkit.py` | The shared helpers (OKLab colour, k-means, colour ramps, the game's shiny/elite recolours). |

## Shading the game's monsters

The monsters are baked from the prototype's drawing code as flat colours. To shade some of them in place:

```
python3 tools/pixel/shade.py --mobs godot/art/mobs green blue red silver gold rat boar ferret tortoise evileye
```

Each monster's `_shiny` and `_elite` folders are shaded too. Run it on fresh, flat art only: shading art
that is already shaded muddies it. (`git checkout godot/art/mobs` gets the flat art back, and so does
re-baking with `node tools/bake/bake.mjs`, which overwrites the shaded PNGs.)

Useful knobs: `--strength` (how strongly the shape bends the light, default 1.5), `--radius` (how far in
from the edge a body is fully round, default 9 px), `--dither` (2x2 ordered dither in the soft shadows),
`--no-outline`, `--palette lospec.hex` (snap everything to a fixed palette at the end).

To shade a drawing of your own, paint it in flat colours (one colour per body part, no shading) on the
right frame size, then `python3 tools/pixel/shade.py my_folder out_folder --frame 88x72`.

## Cleaning an AI or hand-drawn sheet

```
python3 tools/pixel/clean.py sheet.png work/mymonster --names idle_row,run_row
```

* Background: transparent PNGs are used as they are; a flat background colour is found from the border
  and removed (or pass `--bg "#ffffff"`).
* Grid: `--px auto` measures the art-pixel size (e.g. 2.67 screen pixels per art pixel for a typical AI
  upscale). Each sprite gets its own grid alignment, so slow drift across the sheet doesn't matter.
* Size: `--scale fit` (default) shrinks the art just enough that the biggest frame fits the
  `--frame 88x72` canvas with the feet on `--anchor 44,66`. `--scale 1` keeps the sheet's own resolution.
* Palette: `--colors 32` (k-means in OKLab, plus a few accent colours so small bright details like a
  red eye survive), or `--palette my.hex` to lock to a palette you chose.
* Output: `<row>_<n>.png` per frame, a strip per row, `palette.png`, `preview.png` (4x, checkerboard)
  and `clean.json` with what it measured.

## Making a monster set from cleaned frames

Write a recipe that says which frame plays each pose (see the top of `mobset.py`), then:

```
python3 tools/pixel/mobset.py work/mymonster/recipe.json godot/art/mobs/rat --variants
```

This replaces the rat's art with the new frames, updates `godot/art/mobs/mobs.json`, and rebuilds
`rat_shiny` and `rat_elite`.

## Checking the result in the game

```
xvfb-run -a godot --path godot res://tests/mobshow.tscn -- /tmp/shots meadow green,rat,boar,rat! after
```

stands the listed monsters in a row next to the hero and saves `/tmp/shots/after.png`
(`!` = shiny, `*` = elite).
