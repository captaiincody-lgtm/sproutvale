# Sproutvale

A side-scrolling platformer RPG.

- `Sproutvale 2D — prototype.html`: the original browser prototype.
- `godot/`: the standalone Godot 4 version (work in progress).
- `tools/bake/`: copies the prototype's generated art, sounds and music into `godot/`.

## Play the Godot version

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, click **Import**, and pick `godot/project.godot`.
3. Press **F5** (or the ▶ button at the top right) to play.

Controls: arrows move, Space jumps, Z attacks, X heavy attack, C dodge,
Shift block, H/J potions, Tab opens your character panel, F11 fullscreen.

## Make a Windows .exe

In Godot choose **Project → Export…**, click **Add… → Windows Desktop**,
download the export templates when Godot asks, then **Export Project**.

## Use your own art

See [`godot/art/README.md`](godot/art/README.md).
