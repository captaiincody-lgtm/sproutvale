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

## Remaining batches

1. Rock's specialized moves: rising/thrust/spin attacks, aerial combos, plunge, climbing, swimming, prone/crawl, reactions, knockout and celebration; then equipment-compatible layers and armor tiers.
2. Archer, Remy, Jojo and Tank: approve their painted silhouettes, then movement, combat, skills, variants and equipment progression.
3. Monster families and their animation cycles, followed by shiny, elite and lunar variants. The original base monster table contains 61 sprite sets including variants; expansion folders add more.
4. World art by region: homes and interiors, ridge/hollow/pond, Crimson, Abyss, mountain/volcano, lunar areas and map screens. Preserve all collision geometry and parallax behavior.
5. Bosses and live-drawn body parts, NPCs, pets, drops, skill effects and remaining interface assets; final consistency and performance pass.

These are work groups, not claims that the remaining assets are finished. Large groups can be split further without mixing unfinished art into the normal game.

## Animation files

`godot/art/painted/animations.json` describes every published strip, scale, foot anchor and source crop. `godot/samples/painted_animation_library.gd` handles reusable playback. Generated source PNGs from the chat can be normalized with `tools/art/prepare_painted_animations.gd` after placing them in `godot/art/painted/sources/`.

