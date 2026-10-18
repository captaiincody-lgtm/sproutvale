# Painted Meadow playable art sample

This is an early visual prototype inside Sproutvale's existing Godot game. It uses the real Rock controller, combat, collisions, enemy AI and HUD. The new art covers Rock, five meadow slime families, four forest creature families, meadow terrain, decorative trees and the distant background.

## Play
1. Open the repository's `godot/project.godot` in Godot 4.7.2.
2. Open `godot/samples/painted_meadow.tscn`.
3. Press **F6** (Run Current Scene). F5 still starts the regular game.

For rat, boar, tortoise and ferret encounters, open `godot/samples/painted_forest.tscn` instead, or press **F2** in either painted sample. Both encounters use the same meadow scenery and collision geometry.

Arrow keys move; Space jumps; Z attacks; X heavy attacks; C dodges; Shift blocks. **B** switches between painted and original art. **R** restores health and returns Rock to the meadow entrance. Tab opens the existing menu.

This scene creates a fresh session and overrides saving. It does not read or write your normal save. The preview stays inside the meadow, with a choice of slime or forest creature encounters; other areas and heroes keep their original artwork.

The art encounter rotates through all five slime families or all four forest creature families with starter combat stats. Shiny conversion is disabled in this preview; normal-game balance remains unchanged.

## Scope
Batches 1-4 provide 312 painted frames in 78 strips: all 32 starter Rock actions, twenty slime action strips, and 26 forest creature strips. Press V to open the animation gallery, Tab to filter, Space to pause, Left/Right to step, PgUp/PgDn to change page, and Esc to return to the selected encounter. Upgraded equipment, female Rock and other heroes use their original art until painted replacements are ready. See ART_ROADMAP.md for completed and remaining work.

The existing map geometry and physics are preserved. The world is rendered at 1536 x 864 and displayed at the existing logical size so painted textures retain detail. The HUD and many existing effects remain unchanged.

## Files
- `godot/art/painted/atlas.webp`: generated character, slime and environment assets.
- `godot/art/painted/backdrop.webp`: generated distant scenery.
- `godot/samples/painted_meadow.gd`: scene-specific renderer and isolated sample setup.
- `godot/tests/painted_sample.tscn`: scripted input checks and screenshot capture.

The PNG generations were encoded as WebP for a smaller download; the sprite regions are explicitly measured in the renderer. No art bake scripts are run.

## Verification
With a graphical display available:

```
godot --path godot res://tests/painted_sample.tscn -- /absolute/path/to/screenshots
```

The check exercises movement, jump, attack, dodge, block, reset and both directions of the comparison toggle. It saves seven screenshots and prints `PAINTED_SAMPLE_PASS` on success. A failed check exits with code 1.


The additional `godot/tests/painted_forest.tscn` check exercises actual creature AI attacks, hurt/death art, F2 switching, Tab gallery filtering, gallery return and the B comparison. It prints `PAINTED_FOREST_PASS` and saves a lineup screenshot plus the forest animation review frames.

