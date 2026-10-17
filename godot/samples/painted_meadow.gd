extends "res://scripts/game.gd"
## A contained art preview using Sproutvale's real movement, combat, enemies and HUD.
## This scene never reads or writes the player's normal save.
const ATLAS: Texture2D = preload("res://art/painted/atlas.webp")
const BACKDROP: Texture2D = preload("res://art/painted/backdrop.webp")
var painted := true
var original_meadow: Texture2D
var original_far: Texture2D
var original_mid: Texture2D
var empty_art: Texture2D
var sample_label: Label
# Regions and foot anchors are measured from the generated atlas; they are not uniform cells.
const HERO_REGIONS := [
	Rect2(0, 0, 310, 340), Rect2(310, 0, 320, 340),
	Rect2(630, 0, 320, 340), Rect2(950, 0, 313, 340),
	Rect2(0, 340, 310, 340), Rect2(310, 340, 375, 340),
	Rect2(650, 340, 310, 340), Rect2(960, 340, 303, 340)]
const HERO_FEET := [
	Vector2(160, 328), Vector2(480, 328), Vector2(805, 328), Vector2(1112, 280),
	Vector2(150, 666), Vector2(477, 666), Vector2(800, 666), Vector2(1120, 666)]

func loadSave() -> Dictionary:
	var fresh := newSave()
	for cls in CLASSES:
		ensureLook(cls, fresh.chars[cls])
	return fresh

func persist() -> void:
	saveDirty = false

func _ready() -> void:
	original_meadow = Assets.tex("maps/meadow.png")
	original_far = Assets.tex("sky/meadow_far.png")
	original_mid = Assets.tex("sky/meadow_mid.png")
	empty_art = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	_apply_art_cache()
	super._ready()
	selClass = "rock"
	setClass("rock")
	save.lastClass = "rock"
	save.settings.weather = "sunny"
	save.settings.shake = 0.35
	save.chars.rock.introSeen = true
	save.chars.rock.pos = {"map": "meadow", "x": 90, "y": 380}
	# Keep the art sample inside the meadow; the normal game and its portals are untouched.
	MAPS.meadow = MAPS.meadow.duplicate(true)
	MAPS.meadow.portals = []
	MAPS.meadow.spawn = {"green": 1.0}
	MAPS.meadow.target = 8
	startGame()
	World.t = 0.32
	clouds.clear()
	wclouds.clear()
	_make_sample_label()

func _buildLayers() -> void:
	super._buildLayers()
	# Draw the existing 384 x 216 world at 4x rather than 2x; retain original physics units.
	_world.size = Vector2i(1536, 864)
	_world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	_world.snap_2d_transforms_to_pixel = false
	for child in _world.get_children():
		if child is Node2D:
			child.scale = Vector2(4, 4)
	for child in get_children():
		if child is Sprite2D and child.texture == _world.get_texture():
			child.scale = Vector2(0.5, 0.5)
			child.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _make_sample_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var ribbon := PanelContainer.new()
	ribbon.position = Vector2(12, 401)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172e2ce8")
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	ribbon.add_theme_stylebox_override("panel", style)
	canvas.add_child(ribbon)
	sample_label = Label.new()
	sample_label.add_theme_font_override("font", Assets.ui_font)
	sample_label.add_theme_font_size_override("font_size", 12)
	ribbon.add_child(sample_label)
	_update_sample_label()

func _update_sample_label() -> void:
	sample_label.text = "%s  |  B compare  �  R reset  �  Arrows move  �  Space jump  �  Z/X attack  �  C dodge  �  Shift block" % ("PAINTED MEADOW" if painted else "ORIGINAL ART")

func _apply_art_cache() -> void:
	Assets._tex["maps/meadow.png"] = ATLAS if painted else original_meadow
	Assets._tex["sky/meadow_far.png"] = empty_art if painted else original_far
	Assets._tex["sky/meadow_mid.png"] = empty_art if painted else original_mid

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			painted = not painted
			_apply_art_cache()
			_update_sample_label()
			return
		if event.keycode == KEY_R:
			menuOpen = false
			overlay = ""
			intro = null
			PS = calcStats()
			P.hp = PS.hp
			P.en = PS.enMax
			P.iframes = 1.2
			loadMap("meadow", 90, 380)
			setAnim("idle")
			return
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	World.t = 0.32

func drawSky(x: Ctx, D: Dictionary) -> void:
	if not painted:
		super.drawSky(x, D)
		return
	# Overscan permits a slow horizontal drift without repeating an obvious seam.
	var width := VW * 1.22
	var shift := (cam.x / maxf(1.0, M.w - VW)) * (width - VW)
	x.drawImage(BACKDROP, -shift, 0, width, VH)

func drawTerrain(x: Ctx, mt: Texture2D, sx: float, sy: float) -> void:
	if not painted or mapId != "meadow":
		super.drawTerrain(x, mt, sx, sy)
		return
	# Align art to the existing collision surfaces, including all raised platforms.
	for surface in surfaces:
		var left: float = surface.x0 - sx
		var top: float = surface.y - sy
		var width: float = surface.x1 - surface.x0
		if left > VW or left + width < 0:
			continue
		x.fillStyle = "#34452f"
		x.fillRect(maxf(0, left), top + 3, minf(VW, left + width) - maxf(0, left), 31)
		if surface.floor:
			x.fillStyle = "#354337"
			x.fillRect(maxf(0, left), top + 20, minf(VW, left + width) - maxf(0, left), maxf(0, VH - top))
		var start := maxf(0, floorf(-left / 64.0) * 64.0)
		var at := start
		while at < width:
			var tile_width := minf(64, width - at)
			x.drawImageRegion(ATLAS, 8, 1038, 333 * tile_width / 64.0, 207,
				left + at, top - 7, tile_width, 42)
			at += 64
	# Decorative trees sit on the floor and never change collision or jump clearance.
	for tx in [55.0, 375.0, 755.0, 1155.0, 1635.0]:
		var screen_x: float = tx - sx
		if screen_x > -70 and screen_x < VW + 70:
			x.drawImageRegion(ATLAS, 350, 945, 300, 300, screen_x - 30, M.floorY - sy - 64, 60, 64)
	# Keep the existing climb ropes readable over the painted background.
	x.strokeStyle = "#a47745"
	x.lineWidth = 0.8
	for rope in M.ropes:
		var rx: float = rope[0] - sx
		if rx >= 0 and rx <= VW:
			x.beginPath()
			x.moveTo(rx, rope[1] - sy)
			x.lineTo(rx, rope[2] - sy)
			x.stroke()

func drawPlayer(x: Ctx, sx: float, sy: float, dt: float) -> void:
	if not painted:
		super.drawPlayer(x, sx, sy, dt)
		return
	var pose := 0
	if not P.grounded:
		pose = 3
	if absf(P.vx) > 4 and P.grounded:
		pose = 1 + int(P.animT * (10 if absf(P.vx) > 70 else 7)) % 2
	if P.state == "attack" or P.state == "plunge":
		pose = 4 if P.moveT * PS.aspd < 0.10 else 5
	elif P.state in ["dash", "slide", "prone", "knocked", "dead"]:
		pose = 6
	elif P.state == "block":
		pose = 7
	var feet: Vector2 = HERO_FEET[pose]
	var region: Rect2 = HERO_REGIONS[pose]
	var unit := 0.148
	heroHead = Vector2(P.x, P.y - 39)
	if P.iframes > 0 and P.iframes < 0.9 and int(gameTime * 18) % 2 == 0:
		return
	x.save()
	x.translate(P.x - sx, P.y - sy)
	if P.spin != 0:
		x.translate(0, -20)
		x.rotate(P.spin)
		x.translate(0, 20)
	x.scale(P.face, 1)
	x.drawImageRegion(ATLAS, region.position.x, region.position.y, region.size.x, region.size.y,
		(region.position.x - feet.x) * unit, (region.position.y - feet.y) * unit,
		region.size.x * unit, region.size.y * unit)
	x.restore()

func drawMob(x: Ctx, e, sx: float, sy: float) -> void:
	if not painted or e.boss:
		super.drawMob(x, e, sx, sy)
		return
	var pose := 0
	if e.y < e.surf.y - 1:
		pose = 2
	elif e.sq > 0.2:
		pose = 1
	if e.state in ["hurt", "dead"] or e.flash > 0:
		pose = 3
	var cell_x: float = [0.0, 315.0, 650.0, 965.0][pose]
	var base_x: float = [155.0, 477.0, 795.0, 1112.0][pose]
	var ratio := 0.12
	x.save()
	x.translate(e.x - sx, e.y - sy)
	if e.state == "dead":
		x.globalAlpha = maxf(0, 1 - e.deadT / 0.45)
	x.scale(e.face, 1)
	x.drawImageRegion(ATLAS, cell_x, 690, 300, 245,
		(cell_x - base_x) * ratio, (690 - 924) * ratio, 300 * ratio, 245 * ratio)
	x.restore()
	if e.state != "dead" and (e.showBar > 0 or e.aggro):
		x.fillStyle = "#173c36"
		x.fillRect(e.x - sx - 12, e.y - sy - 32, 24, 3)
		x.fillStyle = "#e97b72"
		x.fillRect(e.x - sx - 11, e.y - sy - 31, 22 * maxf(0, e.hp / e.maxHp), 1)


