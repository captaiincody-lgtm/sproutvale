# Painted art overhaul

Work happens on `codex/painted-meadow-sample` in playable batches. The original main scene and normal saves stay available. Each batch records completed assets, remaining work, and verification here.

## Batch 1 - core Rock and green-slime cycles

Completed: 48 painted frames in 12 four-frame strips, exported at four art pixels per world unit.

| Character | Cycles |
| --- | --- |
| Male starter Rock | Idle, walk, run, jump, slash, heavy, dash, block |
| Green slime | Idle, hop, hurt recovery, death |

The current game owns movement, enemy AI, damage frames, attack speed, hitstop and collisions. The painted slash and heavy strike poses are synchronized to the first active damage frame. Unsupported Rock moves still use the sample's earlier key-pose fallback; they have not been completed by this batch. Painted equipment is still drawn as part of the hero, rather than as separate armor and weapon layers.

Review: run `godot/samples/painted_meadow.tscn` with F6. Press V for the animation gallery; Space pauses, Left/Right steps all cycles, and Esc returns to a fresh meadow session. The gallery loops non-looping actions for review; gameplay uses state-specific timing instead.

![Batch 1 animation review](docs/art/animation-batch1.webp)

Verified with Godot 4.7.2: controller smoke checks; twelve valid strips; forty-eight nonempty frames with pose changes; slash/heavy strike timing; gallery playback and four captured review frames.

## Batch 2 - complete starter Rock action coverage

Added 96 frames across 24 distinct strips: rising, thrust, spin, air, climb, swim, crouch, slide, rest, hurt, down, cheer, air2, air3, plungeStart, plungeLand, aegis, whirl, flip, plunge, prone, crawl, proneStab and land. Starter male Rock now has a dedicated painted strip for each of his 32 animation states, totaling 128 hero frames. Green slime adds another 16 frames.

Attacks select their own strip and revisit the strike pose on every active hit of multi-hit moves. Movement and reaction playback preserve the original controller's action durations. The gallery now has pages (PgUp/PgDn); four poses remain intentionally limited animation rather than matching the original per-action frame counts.

Godot 4.7.2 validation: 36 strips, 144 nonempty frames with distinct poses, all 32 Rock state selections, and eleven Rock attack timelines including their extra active hits. Review captured all four frames on each gallery page. Visual review replaced an overlapping knockout source with a separate isolated strip and adjusted rising's startup scale. Local source checkout is partial; unrelated missing original card portraits produce warnings and are not removed from the repository.

![Batch 2 animation review](docs/art/animation-batch2.webp)

Equipment is still baked into these starter poses. Armor tiers, weapon replacement, female Rock, other heroes and full-game integration remain unfinished; this batch does not claim those features.

## Batch 3 - five meadow slime families

Added 64 frames for blue, red, silver and gold slimes: idle, hop, hurt and death for each. These are separately generated designs with crystal, ember, pearl-star and treasure details, respectively. Together with green slime and Rock, the published library contains 52 strips and 208 frames.

The meadow art sample now cycles through all five families when spawning. This isolated encounter uses green-slime level/HP/attack/defense/EXP for every family, retains each family's size and behavior, and disables random shiny conversion. Normal game data and production encounter balance are unchanged. Shiny and elite mobs use original art until their own painted variants exist. Unsupported families also use the original renderer rather than an unrelated painted slime.

Verified in Godot 4.7.2: all 52 strips and 208 nonempty frames; fresh encounter includes every family; real damage selects hurt art and lethal damage selects death art for each family; death reaches its final pose; eleven Rock move timelines; paginated gallery capture. Movement/jump/attack/dodge/block/reset/comparison checks cover the expanded sample. Original mob textures were restored into the partial local checkout to verify the B comparison. Original unrelated card portrait warnings remain.

The sample now restores its texture-cache changes when leaving for the gallery, so returning does not overwrite the original-art comparison reference.

Switching away from male starter Rock or equipping upgraded armor/weapons restores the original hero renderer. The painted starter does not conceal class, gender or equipment changes while their replacement assets are unfinished.

![Batch 3 slime review](docs/art/animation-batch3.webp)

## Remaining batches

1. Rock equipment-compatible layers, armor tiers and appearance variants. The starter action set is covered by batch 2.
2. Archer, Remy, Jojo and Tank: approve their painted silhouettes, then movement, combat, skills, variants and equipment progression.
3. Remaining monster families and their animation cycles, followed by shiny, elite and lunar variants. The five base meadow slime families are covered by batches 1 and 3. The original base monster table contains 61 sprite sets including variants; expansion folders add more.
4. World art by region: homes and interiors, ridge/hollow/pond, Crimson, Abyss, mountain/volcano, lunar areas and map screens. Preserve all collision geometry and parallax behavior.
5. Bosses and live-drawn body parts, NPCs, pets, drops, skill effects and remaining interface assets; final consistency and performance pass.

These are work groups, not claims that the remaining assets are finished. Large groups can be split further without mixing unfinished art into the normal game.

## Animation files

`godot/art/painted/animations.json` describes every published strip, scale, foot anchor and source crop. `godot/samples/painted_animation_library.gd` handles reusable playback. Generated source PNGs from the chat can be normalized with `tools/art/prepare_painted_animations.gd` after placing them in `godot/art/painted/sources/`.

Batch 2 sources can be rebuilt with the same importer, passing the source directory and `tools/art/batch2.json` as two user arguments after `--`. The importer merges new strips into the existing manifest. The final knockout repair entry deliberately replaces the original overlapping source.

