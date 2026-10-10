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
	# …and the climb to the volcano keeps its art in art/climb
	if FileAccess.file_exists(ART + "climb/mobs/mobs.json"):
		mobs.sets.merge(_json(ART + "climb/mobs/mobs.json").sets)
	# …and Glamrax's volcano keeps its art in art/volcano
	if FileAccess.file_exists(ART + "volcano/mobs/mobs.json"):
		mobs.sets.merge(_json(ART + "volcano/mobs/mobs.json").sets)
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
		if _tex[path] == null and ResourceLoader.exists(ART + "climb/" + path):
			_tex[path] = load(ART + "climb/" + path)
		if _tex[path] == null and ResourceLoader.exists(ART + "volcano/" + path):
			_tex[path] = load(ART + "volcano/" + path)
		if _tex[path] == null:
			push_warning("missing art: " + path)
	return _tex[path]


## A hero "look" names a sprite set. Tank's are plain folders ("tank_m_3"). The other four heroes are baked in
## layers (tools/bake/heroes.mjs) and their look also carries the gear to wear: "rock_f|3|sword_7" is female
## Rock in armor tier 3 holding sword tier 7; Remy carries two sets ("mage_m|2|staff_4,wand_6").
## hero_look() gives the animation table either way.
func hero_look(look: String) -> Dictionary:
	return hero.looks.get(look.get_slice("|", 0), hero.looks.get("rock_m", hero.looks.values()[0]))


## One hero animation strip for a look. Animations with wind variants (hair and hem streaming) have five
## strips, 0–4; the rest only have strip 1.
func hero_anim(look: String, anim: String) -> Dictionary:
	var L: Dictionary = hero_look(look)
	return L.anims.get(anim, L.anims.idle)


func hero_variant(look: String, anim: String, variant: int) -> int:
	var vs: Array = hero_anim(look, anim).variants
	return variant if vs.has(variant) or vs.has(float(variant)) else 1


func hero_strip(look: String, anim: String, variant: int) -> Texture2D:
	var L: Dictionary = hero_look(look)
	if not L.anims.has(anim):
		anim = "idle"
	var v := hero_variant(look, anim, variant)
	if not L.get("layered", false):
		return tex("hero/%s/%s_%d.png" % [look, anim, v])
	return _stacked(look, anim, v)


const LAYER_CACHE := 160
var _stack := {}        # stacked strips, most recently used last
var _layerImg := {}     # decoded layer sheets, so changing one gear piece re-stacks without re-decoding the rest


## Puts a layered hero strip back together: body and weapon layers interleaved
## B_pre, W0, B0, W1, B1, W2, B2, W3, B3 (see tools/bake/heroes.mjs).
func _stacked(look: String, anim: String, v: int) -> Texture2D:
	var key := "%s|%s|%d" % [look, anim, v]
	if _stack.has(key):
		var t: Texture2D = _stack[key]
		_stack.erase(key)
		_stack[key] = t
		return t
	var parts := look.split("|")
	var base := parts[0]
	var armor := int(parts[1]) if parts.size() > 1 else 0
	var body := _layers("hero/%s_%d/%s_%d.png" % [base, armor, anim, v])
	if body == null:
		body = _layers("hero/%s_0/%s_%d.png" % [base, anim, v])
	if body == null:
		return null
	var H := int(hero.get("frame_h", 152))
	var W := body.get_width()
	var gear := []
	if parts.size() > 2 and parts[2] != "":
		for g in parts[2].split(","):
			var gi := _layers("hero/gear/%s/%s.png" % [g, anim])
			if gi != null and gi.get_width() == W:
				gear.append(gi)
	var nb := body.get_height() / H   # 5 body layers, or 1 for a flat, hand-drawn strip
	var out := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var whole := Rect2i(0, 0, W, H)
	if nb < 5:
		out.blend_rect(body, Rect2i(0, 0, W, H), Vector2i.ZERO)
		for gi in gear:
			for r in 4:
				out.blend_rect(gi, Rect2i(0, r * H, W, H), Vector2i.ZERO)
	else:
		out.blend_rect(body, whole, Vector2i.ZERO)
		for r in 4:
			for gi in gear:
				out.blend_rect(gi, Rect2i(0, r * H, W, H), Vector2i.ZERO)
			out.blend_rect(body, Rect2i(0, (r + 1) * H, W, H), Vector2i.ZERO)
	var t := ImageTexture.create_from_image(out)
	_stack[key] = t
	if _stack.size() > LAYER_CACHE:
		_stack.erase(_stack.keys()[0])
	return t


func _layers(path: String) -> Image:
	if _layerImg.has(path):
		return _layerImg[path]
	var t := tex(path) if ResourceLoader.exists(ART + path) else null
	var img: Image = null
	if t != null:
		img = t.get_image()
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_tex.erase(path)   # the image is what we keep; the texture was only the way in
	_layerImg[path] = img
	if _layerImg.size() > LAYER_CACHE * 2:
		_layerImg.erase(_layerImg.keys()[0])
	return img


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
	var fr: Array = heads.get(look.get_slice("|", 0), {}).get(anim, [])
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
