extends "res://scripts/screens.gd"
## Sproutvale: the main node. It builds the layers everything is drawn into, turns key presses
## and mouse clicks into the prototype's input, and runs the frame loop (the prototype's frame()).
##
## The game is one node whose script is split across files that extend each other:
##   core → world → player → mobs → skills → bosses → render → intro → hud → ui → screens → game
## Units: the world is measured in "world pixels" exactly like the HTML prototype (a 384×216 view),
## painted at 2× into a 768×432 pixel-art buffer. The HUD and menus are drawn on top at the
## window's own resolution so their text stays sharp.

const Layer := preload("res://scripts/layer.gd")
const Clip := preload("res://scripts/clip.gd")

const KEYNAMES := {
	KEY_LEFT: "arrowleft", KEY_RIGHT: "arrowright", KEY_UP: "arrowup", KEY_DOWN: "arrowdown",
	KEY_SPACE: " ", KEY_SHIFT: "shift", KEY_ENTER: "enter", KEY_KP_ENTER: "enter", KEY_ESCAPE: "escape", KEY_TAB: "tab",
}

var frameDt := 0.016
var _world: SubViewport


func _ready() -> void:
	init_data()
	randomize()
	save = loadSave()
	initRender()
	initHud()
	World.t = float(save.get("worldT", 0.32))
	var last = save.get("lastClass", "rock")
	selClass = last if CLASSES.has(last) and not heroLocked(last) else "rock"
	setClass(selClass)
	fillQuests()
	loadMap(save.settings.map if MAPS.has(save.settings.get("map", "")) else "meadow")
	applyVolume()
	Sfx.music("sel_" + selClass)
	toCharSelect()
	_buildLayers()


## the world goes into a 768×432 buffer shown with crisp pixels; the UI draws over it in its own layer
func _buildLayers() -> void:
	_world = SubViewport.new()
	_world.size = Vector2i(int(UW), int(UH))
	_world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_world.snap_2d_transforms_to_pixel = true
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_world)
	_layer(_world, func(ci): renderWorld(ci, frameDt), 2.0)
	var tint = _layer(_world, renderTint, 2.0)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL   # night and heavy cloud multiply over the world
	tint.material = mat
	_layer(_world, renderOverlay, 2.0)
	var view = Sprite2D.new()
	view.centered = false
	view.texture = _world.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)
	var ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_layer(ui, renderHud, 1.0, func(): return inGame and intro == null)
	_layer(ui, renderTitle, 1.0, func(): return not inGame and intro == null)
	_layer(ui, renderMenu, 1.0, func(): return inGame and menuOpen and intro == null)
	_clip(ui, renderPanel, func(): return panelRect if inGame and menuOpen and intro == null else Rect2())
	_layer(ui, renderIntro, 1.0, func(): return intro != null)
	_layer(ui, renderOver, 1.0, func(): return overlay != "")
	_clip(ui, renderOverPanel, func(): return overRect if overlay == "account" else Rect2())
	_layer(ui, func(ci): drawTip(ci, activeLayers()), 1.0)


func _layer(parent: Node, painter: Callable, scl: float, active := Callable()) -> Node2D:
	var l = Layer.new()
	l.painter = painter
	l.active = active
	l.scale = Vector2(scl, scl)
	parent.add_child(l)
	return l


func _clip(parent: Node, painter: Callable, rect_fn: Callable) -> void:
	var c = Clip.new()
	c.painter = painter
	c.rect_fn = rect_fn
	parent.add_child(c)


## the layers that can take the mouse right now, front to back
func activeLayers() -> Array:
	if intro != null:
		return []
	if overlay == "account":
		return ["overpanel", "over"]
	if overlay != "":
		return ["over"]
	if not inGame:
		return ["title"]
	if menuOpen:
		return ["panel", "menu"]
	return ["hud"]


# ================================================================ input

func _keyName(e: InputEventKey) -> String:
	if KEYNAMES.has(e.keycode):
		return KEYNAMES[e.keycode]
	return OS.get_keycode_string(e.keycode).to_lower()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		if dragSlider != "":
			setSlider(dragSlider, mouse.x)
		return
	if event is InputEventMouseButton:
		mouse = event.position
		if not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and dragSlider != "":
				dragSlider = ""
				persist()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var d = 36.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -36.0
			if overlay == "account":
				scrollBy("over", d)
			elif inGame and menuOpen:
				scrollBy("panel", d)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(event.position)
		return
	if event is InputEventKey:
		_onKey(event)


func _click(pos: Vector2) -> void:
	if intro != null:
		if introBtns.get("next", Rect2()).has_point(pos):
			introNext()
		elif introBtns.get("skip", Rect2()).has_point(pos):
			introSkip()
		return
	for L in activeLayers():
		var zs: Array = zonesBy.get(L, [])
		for i in range(zs.size() - 1, -1, -1):
			var z = zs[i]
			if z.r.has_point(pos):
				if z.cb.is_valid():
					z.cb.call()
				return


func _onKey(e: InputEventKey) -> void:
	var k = _keyName(e)
	if not e.pressed:
		K[k] = false
		return
	if k == "f11":
		if not e.echo:
			var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if intro != null:
		if not e.echo:
			if k == "enter" or k == " ":
				introNext()
			elif k == "escape":
				introSkip()
		return
	if overlay != "":
		if k == "escape" and not e.echo:
			closeOverlay()
		return
	if k == "tab" or k == "i":
		if inGame and not e.echo:
			toggleMenu()
		return
	if k == "m" and inGame:
		if not e.echo:
			if menuOpen and curTab == "map":
				toggleMenu(false)
			else:
				openTab("map")
				if not menuOpen:
					toggleMenu(true)
		return
	if k == "escape":
		if menuOpen:
			toggleMenu(false)
		return
	if not inGame:
		if not e.echo:
			if k == "enter" or k == " ":
				startGame()
			elif k == "arrowleft" or k == "arrowright":
				moveSelection(-1 if k == "arrowleft" else 1)
		return
	if menuOpen:
		return
	K[k] = true
	if not e.echo:
		pressed[k] = true
		if k == "arrowleft" or k == "arrowright":
			var t = Time.get_ticks_msec()
			if t - lastTap.get(k, 0) < 260:
				dblTap = k
			lastTap[k] = t


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		for k in K:
			K[k] = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save.size():
			persist()


# ================================================================ the frame loop

func _process(delta: float) -> void:
	var rdt = minf(0.05, delta)
	realTime += rdt
	var scl = 1.0
	if hitstop > 0:
		hitstop -= rdt
		scl = 0.05
	elif slowmo > 0:
		slowmo -= rdt
		scl = 0.35
	var dt = rdt * scl
	shake = maxf(0, shake - rdt * 12)
	if fadeTo != null:
		fade = minf(1, fade + rdt * 4)
		if fade >= 1:
			var ft = fadeTo
			fadeTo = null
			loadMap(ft.map, ft.get("x"), ft.get("y"))
	elif fade > 0:
		fade = maxf(0, fade - rdt * 3)
	if inGame and not menuOpen:
		gameTime += dt
		updatePops(dt)
		if scene != null:
			updateScene(dt)
		if scene == null and not P.frozen:
			updatePlayer(dt)
		else:
			P.vx = 0
			if P.state != "dead":
				P.state = "move" if P.grounded else P.state
		if scene != null:
			updateFX(dt)
			updateParts(dt)
		else:
			updateCrimsonRain(dt)
			updateWater(dt)
			updateSlimes(dt)
			updateFX(dt)
			updateArrows(dt)
			updateSpirit(dt)
			updateElemSpirit(dt)
			updatePets(dt)
			updateObelisk(dt)
			updateDrops(dt)
			updateParts(dt)
			updateStyle(dt)
	elif not inGame:
		P.animT += rdt
		updateSlimes(rdt)
	updateWorld(rdt)
	updateCamera(rdt)
	frameDt = rdt
	update_timers(rdt)
	updateHud(rdt)
	if intro != null:
		updateIntro(rdt)
	if menuOpen and curTab == "bestiary":
		updateBestiary(rdt)
	if inGame:
		var c = CH()
		c.playTime = c.get("playTime", 0.0) + rdt
		if P.grounded and P.state != "dead":
			c.pos = {"map": mapId, "x": roundf(P.x), "y": P.y}
	saveTimer += rdt
	if saveTimer > 10:
		saveTimer = 0.0
		if saveDirty or inGame:
			persist()
	pressed.clear()
