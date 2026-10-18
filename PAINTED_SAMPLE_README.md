# Painted Meadow playable art sample

This is an early visual prototype inside Sproutvale's existing Godot game. It uses the real Rock controller, combat, collisions, enemy AI and HUD. The new art covers Rock, five meadow slime families, four forest creature families, eight Crimson enemy families, and six regional environments. All 17 enemy families in the original base data table now have painted animation sets; expansion enemies and variants remain future work.

## Play
1. Open the repository's `godot/project.godot` in Godot 4.7.2.
2. Open `godot/samples/painted_meadow.tscn`.
3. Press **F6** (Run Current Scene). F5 still starts the regular game.

Open `painted_hollow.tscn`, `painted_ridge.tscn`, or `painted_crimson.tscn` in the same samples folder for the new regions. **F3** cycles Meadow / Mossy Hollow / Tusk Ridge / Crimson Wastes / Willow Pond / Bone Hollow using each original map layout. **F2** cycles Slimes / Forest / Crimson creatures / Crimson armor independently. Open `painted_armor.tscn` for Knights and Crusaders in the Crimson region. `painted_pond.tscn` and `painted_bone_hollow.tscn` open the new maps directly. `painted_forest.tscn` still opens forest creatures in the meadow.

Arrow keys move; Space jumps; Z attacks; X heavy attacks; C dodges; Shift blocks. **B** switches between painted and original art. **R** restores health and returns Rock to the selected region entrance. Tab opens the existing menu.

This scene creates a fresh session and overrides saving. It does not read or write your normal save. The preview has six isolated regional maps with portals disabled; F3 selects the region. The regular game still starts with its original renderer.

The art encounter rotates through all five slime families, all four forest creature families, all six Crimson creature families, or the two armored Crimson families with starter combat stats. Shiny conversion is disabled in this preview; normal-game balance remains unchanged.

## Scope
Batches 1-8 provide 512 painted frames in 128 strips: all 32 starter Rock actions, twenty slime action strips, 26 forest creature strips, 36 Crimson creature strips, and 14 armored Crimson strips. Batch 6 adds three regional backdrops and three terrain tiles. The Crimson set covers Evil Eye, Hand, Traveler feet, Torso, Hair Spike, and Floating Head, including rolling, hopping, hurt and death art. Batch 7 adds Crimson Knight sword and shield-bash actions, and Crimson Crusader cleave and leaping-cleave actions. Batch 8 adds Floating Head hover, flight, bite, hurt and death art, Willow Pond scenery and riverbank terrain, and the Bone Hollow backdrop. Its terrain reuses the Crimson tile; both maps preserve original geometry. Pond water remains animated by the existing simulation. Press V to open the animation gallery, Tab to filter, Space to pause, Left/Right to step, PgUp/PgDn to change page, and Esc to return to the selected encounter. Upgraded equipment, female Rock and other heroes use their original art until painted replacements are ready. See ART_ROADMAP.md for completed and remaining work.

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

The additional `godot/tests/painted_regions.tscn` check exercises the original five Crimson AI families, paired Travelers, rolling Hair Spikes, damage/death playback, all six original map layouts, comparison caching, Crimson gallery filtering, and region/encounter preservation after leaving the gallery. It prints `PAINTED_REGIONS_PASS`. The animation test checks 128 strips and 512 nonempty frames.

`godot/tests/painted_armor.tscn` checks real Knight swing and shield-bash AI, Crusader cleave and leap AI, sword damage windows, leap landing damage, hurt/death poses, F2 wraparound, B comparison, Armor gallery filtering and return. It prints `PAINTED_ARMOR_PASS` and captures the playable encounter, combat poses and every gallery frame.

`godot/tests/painted_pond_head.tscn` verifies original pond water/platform/rope geometry, horizontal swimming, swim strokes, submerged bank collision, splash ripples, painted detail below the waterline, Floating Head bite AI and damage, hurt/death art, Bone Hollow layout and gallery return. It prints `PAINTED_POND_HEAD_PASS`.
