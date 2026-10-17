# Painted Meadow playable art sample

This is an early visual prototype inside Sproutvale's existing Godot game. It uses the real Rock controller, combat, collisions, enemy AI and HUD. The new art covers Rock, the green slimes, meadow terrain, decorative trees and the distant background.

## Play
1. Open the repository's `godot/project.godot` in Godot 4.7.2.
2. Open `godot/samples/painted_meadow.tscn`.
3. Press **F6** (Run Current Scene). F5 still starts the regular game.

Arrow keys move; Space jumps; Z attacks; X heavy attacks; C dodges; Shift blocks. **B** switches between painted and original art. **R** restores health and returns Rock to the meadow entrance. Tab opens the existing menu.

This scene creates a fresh session and overrides saving. It does not read or write your normal save. The preview stays inside the meadow, with green slimes; other areas and heroes keep their original artwork.

## Scope
Batches 1 and 2 provide 144 painted frames: all 32 starter Rock actions and four green-slime actions, each in a four-frame strip. Press V to open the animation gallery, Space to pause, Left/Right to step, PgUp/PgDn to change page, and Esc to return. Equipment changes in the menu do not change the painted hero yet. Female Rock and other heroes are not covered. See ART_ROADMAP.md for completed and remaining work.

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


