extends Node
## Loads the game data and every sprite sheet once, so the rest of the game can ask for them by name.
## All art lives in res://art as plain PNGs (see res://art/README.md for the sizes each file needs).

const ART := "res://art/"

var data: Dictionary            # maps, monsters, moves, gear tiers… (res://data/game_data.json)
var hero: Dictionary            # hero animation table (res://art/hero/hero.json)
var mobs: Dictionary            # monster sprite table (res://art/mobs/mobs.json)
var heads: Dictionary           # where the hero's head is in every frame (res://art/hero/heads.json)
var font: FontFile              # "Press Start 2P", the pixel font used everywhere in the world
var ui_font: FontFile           # "Fredoka" bold, the rounder font used by the HUD text
var ui_reg: FontFile            # "Fredoka" medium, for body text in the menus
var emoji: FontFile             # "Noto Color Emoji", for skill, item and status icons

var _tex := {}


func _ready() -> void:
	data = _json("res://data/game_data.json")
	hero = _json(ART + "hero/hero.json")
	mobs = _json(ART + "mobs/mobs.json")
	if FileAccess.file_exists(ART + "hero/heads.json"):
		heads = _json(ART + "hero/heads.json")
	# the areas beyond the Warlord's Keep keep their art in art/abyss (same layout as art/)
	if FileAccess.file_exists(ART + "abyss/mobs/mobs.json"):
		mobs.sets.merge(_json(ART + "abyss/mobs/mobs.json").sets)
	font = _font("res://fonts/PressStart2P-Regular.ttf")
	emoji = load("res://fonts/NotoColorEmoji.ttf")
	ui_font = load("res://fonts/Fredoka-700.ttf")
	ui_font.fallbacks = [font, emoji]   # Fredoka has no arrow glyphs (← ↑ → ↓) or emoji; borrow them
	ui_reg = load("res://fonts/Fredoka-500.ttf")
	ui_reg.fallbacks = [font, emoji]


func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(ART + path) if ResourceLoader.exists(ART + path) else null
		if _tex[path] == null and ResourceLoader.exists(ART + "abyss/" + path):
			_tex[path] = load(ART + "abyss/" + path)
		if _tex[path] == null:
			push_warning("missing art: " + path)
	return _tex[path]


## One hero animation strip for a look ("rock_m", "archer_f"…). Animations with wind variants
## (hair and hem streaming) have five strips, 0–4; the rest only have strip 1.
func hero_anim(look: String, anim: String) -> Dictionary:
	var L: Dictionary = hero.looks.get(look, hero.looks.rock_m)
	return L.anims.get(anim, L.anims.idle)


func hero_variant(look: String, anim: String, variant: int) -> int:
	var vs: Array = hero_anim(look, anim).variants
	return variant if vs.has(variant) or vs.has(float(variant)) else 1


func hero_strip(look: String, anim: String, variant: int) -> Texture2D:
	var L: Dictionary = hero.looks.get(look, hero.looks.rock_m)
	if not L.anims.has(anim):
		anim = "idle"
	return tex("hero/%s/%s_%d.png" % [look, anim, hero_variant(look, anim, variant)])


## where the ponytail is tied on, for looks that have one: [x, y] inside the frame, in world units
func hero_tail(look: String, anim: String, variant: int, f: int):
	var A := hero_anim(look, anim)
	if not A.has("tail"):
		return null
	var t = A.tail.get(str(hero_variant(look, anim, variant)))
	if t == null or t.is_empty():
		return null
	return t[clampi(f, 0, t.size() - 1)]


## the head's middle in frame f of an animation, in hero pixels (null if unknown)
func hero_head(look: String, anim: String, f: int):
	var fr: Array = heads.get(look, {}).get(anim, [])
	if fr.is_empty():
		return null
	var p = fr[clampi(f, 0, fr.size() - 1)]
	return null if p == null else Vector2(p[0], p[1])


func mob_strip(set_name: String, key: String) -> Texture2D:
	return tex("mobs/%s/%s.png" % [set_name, key])


func mob_set(set_name: String) -> Dictionary:
	return mobs.sets.get(set_name, {})


func mob_frames(set_name: String, key: String) -> int:
	return int(mob_set(set_name).get("keys", {}).get(key, 0))


var _sil := {}

## a flat-colour silhouette of a texture (the bestiary's unseen monsters)
func silhouette(t: Texture2D, col: Color) -> Texture2D:
	if t == null:
		return null
	var key := "%d|%s" % [t.get_instance_id(), col.to_html()]
	if not _sil.has(key):
		var img := t.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a * col.a))
		_sil[key] = ImageTexture.create_from_image(img)
	return _sil[key]


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
