extends Node
## Loads the game data and every sprite sheet once, so the rest of the game can ask for them by name.
## All art lives in res://art as plain PNGs (see res://art/README.md for the sizes each file needs).

const ART := "res://art/"

var data: Dictionary            # maps, monsters, moves, gear tiers… (res://data/game_data.json)
var hero: Dictionary            # hero animation table (res://art/hero/hero.json)
var mobs: Dictionary            # monster sprite table (res://art/mobs/mobs.json)
var font: FontFile              # "Press Start 2P", the pixel font used everywhere in the world
var ui_font: FontFile           # "Fredoka", the rounder font used by the HUD text

var _tex := {}


func _ready() -> void:
	data = _json("res://data/game_data.json")
	hero = _json(ART + "hero/hero.json")
	mobs = _json(ART + "mobs/mobs.json")
	font = _font("res://fonts/PressStart2P-Regular.ttf")
	ui_font = load("res://fonts/Fredoka-700.ttf")
	ui_font.fallbacks = [font]   # Fredoka has no arrow glyphs (← ↑ → ↓); borrow them from the pixel font


func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(ART + path) if ResourceLoader.exists(ART + path) else null
		if _tex[path] == null:
			push_warning("missing art: " + path)
	return _tex[path]


## One hero animation strip. Animations with wind variants (hair streaming) have five strips, 0–4.
func hero_strip(anim: String, variant: int) -> Texture2D:
	var a: Dictionary = hero.anims.get(anim, hero.anims.idle)
	var vs: Array = a.variants
	if not vs.has(float(variant)) and not vs.has(variant):
		variant = 1
	return tex("hero/%s_%d.png" % [anim, variant])


func mob_strip(set_name: String, key: String) -> Texture2D:
	return tex("mobs/%s/%s.png" % [set_name, key])


func mob_frames(set_name: String, key: String) -> int:
	return int(mobs.sets.get(set_name, {}).get(key, 1))


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("can't open " + path)
		return {}
	return JSON.parse_string(f.get_as_text())


func _font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f
