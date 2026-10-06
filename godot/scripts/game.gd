extends Node2D
## Sproutvale: the main game node. Holds the world state, runs the update loop and owns the save.
## The player and monster logic live in player.gd and mobs.gd, drawing in renderer.gd and hud.gd.
## Units: the world is measured in "world pixels" exactly like the HTML prototype (a 384×216 view);
## the window shows it at 2× (768×432) and then scales that up by whole numbers.

const S := preload("res://scripts/state.gd")
const PlayerCtl := preload("res://scripts/player.gd")
const MobsCtl := preload("res://scripts/mobs.gd")
const Renderer := preload("res://scripts/renderer.gd")
const Hud := preload("res://scripts/hud.gd")
const Layer := preload("res://scripts/layer.gd")

const VW := 384
const VH := 216
const GRAV := 950.0
const MAXFALL := 520.0
const MAX_LV := 200
const SAVE_PATH := "user://sproutvale_save.json"
var SAVE_PATH_OVERRIDE := ""   # tests use a throwaway save
# portals to places this build doesn't have yet
const NOT_YET := {"trophy": "The Trophy Hall isn't in the Godot version yet.", "lair": "Doc Croc's lair isn't in the Godot version yet."}
const WEATHERS := {"sunny": "Sunny", "cloudy": "Cloudy", "rain": "Rain", "thunderstorm": "Thunderstorm", "snow": "Snow"}
const W_PARAMS := {
	"sunny": {"cloud": 0.1, "rain": 0.0, "snow": 0.0, "wind": 0.4, "storm": 0.0},
	"cloudy": {"cloud": 0.7, "rain": 0.0, "snow": 0.0, "wind": 0.7, "storm": 0.0},
	"rain": {"cloud": 1.0, "rain": 1.0, "snow": 0.0, "wind": 0.8, "storm": 0.0},
	"thunderstorm": {"cloud": 1.0, "rain": 1.4, "snow": 0.0, "wind": 1.3, "storm": 1.0},
	"snow": {"cloud": 1.0, "rain": 0.0, "snow": 1.0, "wind": 0.5, "storm": 0.0},
}
const ATTRS := ["STR", "WIL", "VIT", "AGI", "DEX"]
const ATTR_DESC := {"STR": "Attack power", "WIL": "Energy recovery", "VIT": "Max HP and defense", "AGI": "Move and attack speed", "DEX": "Critical rate and damage"}

# --- world state
var D: Dictionary                 # Assets.data
var M: Dictionary = {}            # current map
var map_id := ""
var surfaces: Array = []
var tufts: Array = []
var mobs: Array = []
var drops: Array = []
var parts: Array = []
var floaters: Array = []
var speed_lines: Array = []
var cam := Vector2.ZERO
var game_time := 0.0
var real_time := 0.0
var hitstop := 0.0
var slowmo := 0.0
var shake := 0.0
var fade := 0.0
var fade_to = null
var thought = null
var water := {"cols": [], "vel": [], "x0": 0.0, "step": 3.0}
var world := {"t": 0.32, "weather": "sunny", "w_timer": 110.0, "cloud": 0.1, "rain": 0.0, "snow": 0.0, "wind": 0.4, "storm": 0.0,
	"snow_cover": 0.0, "flash": 0.0, "next_bolt": 6.0, "bolt": null, "amb_t": 0.0}
var style := {"pts": 0.0, "rank": 0, "hits": 0, "timer": 0.0, "last": [], "peak": 0, "since_hit": 9.0, "popped": 0.0}
var spawn_timer := 0.0
var mob_uid := 0

# --- player + save
var P: S.Player = S.Player.new()
var PS: Dictionary = {}           # computed stats
var save: Dictionary = {}
var save_dirty := false
var save_timer := 0.0

# --- input
var keys := {}       # held
var pressed := {}    # pressed this frame
var last_tap := {}
var dbl_tap := ""

# --- screens & messages
var mode := "title"  # title, play
var panel_open := false
var banner_msg := {"big": "", "sub": "", "t": 99.0}
var combo_msg := {"big": "", "sub": "", "t": 99.0}
var toasts: Array = []
var vignette := 0.0

var player: PlayerCtl
var mob_ctl: MobsCtl
var renderer: Renderer
var hud: Hud


func _ready() -> void:
	D = Assets.data
	randomize()
	load_save()
	player = PlayerCtl.new(self)
	mob_ctl = MobsCtl.new(self)
	renderer = Renderer.new(self)
	hud = Hud.new(self)
	# world, then a multiply layer for night and clouds, then flat overlays, then the HUD on top
	var world_layer = _layer(renderer.draw_world, 2.0)
	var tint = _layer(renderer.draw_tint, 2.0)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = mat
	_layer(renderer.draw_overlay, 2.0)
	var ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var hud_layer = Layer.new()
	hud_layer.painter = hud.draw
	ui.add_child(hud_layer)
	world_layer.z_index = 0
	world.t = float(save.get("world_t", 0.32))
	recalc_stats()
	var pos: Dictionary = save.char.get("pos", {})
	load_map(pos.get("map", "home") if D.maps.has(pos.get("map", "")) else "home", pos.get("x", null), pos.get("y", null))
	P.hp = PS.hp
	P.en = PS.enMax
	Sfx.music("sel_rock")


func _layer(painter: Callable, scl: float) -> Node2D:
	var l = Layer.new()
	l.painter = painter
	l.scale = Vector2(scl, scl)
	add_child(l)
	return l


# ---------------------------------------------------------------- save

func new_char() -> Dictionary:
	return {"level": 1, "exp": 0, "ap": 0, "sp": 0, "attrs": {"STR": 1, "WIL": 1, "VIT": 1, "AGI": 1, "DEX": 1}, "armor": 0, "weapon": 0, "kills": 0, "playTime": 0.0}


func load_save() -> void:
	save = {"coins": 0, "mats": {}, "char": new_char(), "settings": {"vol": 0.5, "music": 0.5, "sfx": 0.8, "timeSpeed": 1.0, "weather": "auto"}, "bestRank": -1}
	for k in D.mobs:
		save.mats[k] = 0
	if FileAccess.file_exists(_save_path()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
		if d is Dictionary:
			for k in ["coins", "bestRank", "world_t"]:
				if d.has(k):
					save[k] = d[k]
			for k in ["mats", "settings"]:
				if d.get(k) is Dictionary:
					save[k].merge(d[k], true)
			if d.get("char") is Dictionary:
				save.char.merge(d.char, true)
				var a = new_char().attrs
				a.merge(save.char.attrs, true)
				save.char.attrs = a
	apply_volume()


func persist() -> void:
	save.world_t = world.t
	var f = FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))
	save_dirty = false


func _save_path() -> String:
	return SAVE_PATH_OVERRIDE if SAVE_PATH_OVERRIDE != "" else SAVE_PATH


func apply_volume() -> void:
	Sfx.vol = save.settings.vol
	Sfx.music_vol = save.settings.music
	Sfx.sfx_vol = save.settings.sfx


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		keys.clear()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if mode == "play":
			persist()


# ---------------------------------------------------------------- stats (Rock, before skills and charms)

func CH() -> Dictionary:
	return save.char


func exp_need(lv: int) -> int:
	return int(floor(28.0 * pow(lv, 1.6)))


func recalc_stats() -> void:
	var c = CH()
	var a: Dictionary = c.attrs
	var ar: Dictionary = D.armor[int(c.armor)]
	var wp: Dictionary = D.weapon[int(c.weapon)]
	var lv = float(c.level)
	var W = float(a.WIL)
	PS = {
		"hp": roundi(90 + lv * 10 + a.VIT * 14 + ar.hp),
		"atk": roundi(10 + lv * 2 + a.STR * 3 + wp.atk),
		"def": roundi(2 + lv * 0.5 + a.VIT * 0.9 + ar.def + wp.def),
		"crit": minf(80, 5 + a.DEX * 0.7),
		"critDmg": 1.5 + a.DEX * 0.012,
		"spd": 1 + minf(0.5, a.AGI * 0.008),
		"aspd": 1 + minf(0.45, a.AGI * 0.007),
		"enMax": roundi(100 + minf(60, W * 0.6)),
		"enRegen": 6 * (1 + 1.3 * (1 - exp(-W / 55))),
		"enHit": 3 + minf(2, W * 0.02),
	}


func job_name(lv: int) -> String:
	var n = ""
	for j in D.jobs:
		if lv >= j.lv:
			n = j.name
	return n


func gain_exp(n: float) -> void:
	var c = CH()
	if c.level >= MAX_LV:
		return
	c.exp += roundi(n)
	while c.level < MAX_LV and c.exp >= exp_need(int(c.level)):
		var old_job = job_name(int(c.level))
		c.exp -= exp_need(int(c.level))
		c.level += 1
		c.ap += 3
		c.sp += 3
		recalc_stats()
		P.hp = PS.hp
		Sfx.play("levelUp")
		banner("LEVEL UP!", "Level %d · 3 attribute points (Tab to spend them)" % c.level)
		if job_name(int(c.level)) != old_job:
			toast("Rock is now a %s!" % job_name(int(c.level)))
		for i in 30:
			parts.append(S.Part.new(P.x + randf_range(-10, 10), P.y - randf_range(0, 40), randf_range(-20, 20), randf_range(-90, -40), randf_range(0.6, 1.2), [Color("#ffe14d"), Color.WHITE, Color("#6fe0ff")][i % 3], 0, 2))
	save_dirty = true


func spend_point(attr: String) -> void:
	var c = CH()
	if c.ap <= 0:
		return
	c.ap -= 1
	c.attrs[attr] += 1
	var old_hp: float = PS.hp
	recalc_stats()
	P.hp = minf(PS.hp, P.hp + PS.hp - old_hp)
	Sfx.play("ui")
	save_dirty = true


# ---------------------------------------------------------------- maps

func surfaces_of(m: Dictionary) -> Array:
	var s = []
	if m.has("pond"):
		var p: Dictionary = m.pond
		s.append({"x0": 20.0, "x1": p.x0, "y": m.floorY, "floor": true, "water": false})
		s.append({"x0": p.x1, "x1": m.w - 20.0, "y": m.floorY, "floor": true, "water": false})
		s.append({"x0": p.x0 + 2, "x1": p.x1 - 2, "y": p.bottom, "floor": true, "water": true})
	else:
		s.append({"x0": 20.0, "x1": m.w - 20.0, "y": m.floorY, "floor": true, "water": false})
	for pl in m.plats:
		s.append({"x0": pl[0], "x1": pl[0] + pl[2], "y": pl[1], "floor": false, "water": false})
	return s


func load_map(id: String, px0 = null, py0 = null) -> void:
	map_id = id
	M = D.maps[id]
	CH().pos = {"map": id, "x": px0, "y": py0}
	surfaces = surfaces_of(M)
	tufts.clear()
	for s in surfaces:
		if s.water or M.get("indoor", false):
			continue
		var x: float = s.x0 + 3
		while x < s.x1 - 3:
			var fg = hsh(x * 5.3 + s.y) > 0.8
			tufts.append({"x": x, "y": s.y, "h": (4 + floor(hsh(x * 3) * 4)) if fg else (2 + floor(hsh(x * 3) * 3)), "p": hsh(x * 7) * 6, "fg": fg})
			x += 5 + floor(hsh(x) * 5)
	mobs.clear(); drops.clear(); parts.clear(); floaters.clear()
	P.x = px0 if px0 != null else float(M.start)
	P.y = py0 if py0 != null else float(M.floorY)
	P.vx = 0; P.vy = 0; P.state = "move"; P.rope = null
	P.surf = null
	for s in surfaces:
		if absf(s.y - P.y) < 1 and P.x >= s.x0 and P.x <= s.x1:
			P.surf = s
			break
	P.grounded = P.surf != null
	thought = null
	for i in int(M.target):
		mob_ctl.spawn(true)
	cam.x = clampf(P.x - VW / 2.0, 0, M.w - VW)
	cam.y = clampf(P.y - VH * 0.66, 0, M.h - VH)
	init_water()
	if mode == "play":
		Sfx.music(M.get("music", id))
		banner(M.name, M.get("sub", "Tougher slimes live here" if M.get("lvBonus", 0) else "Starter area"))
	save_dirty = true


func travel(portal: Dictionary) -> void:
	if fade_to != null:
		return
	if NOT_YET.has(portal.to):
		toast(NOT_YET[portal.to])
		Sfx.play("empty")
		return
	fade_to = {"map": portal.to, "x": portal.tx, "y": portal.get("ty", null)}
	Sfx.play("portal")


func portal_at():
	for p in M.portals:
		if absf(P.x - p.x) < 16 and absf(P.y - p.get("y", M.floorY)) < 2:
			return p
	return null


func rope_at():
	for r in M.ropes:
		if absf(P.x - r[0]) < 11 and P.y > r[1] - 2 and P.y - 30 < r[2]:
			return {"x": float(r[0]), "y0": float(r[1]), "y1": float(r[2])}
	return null


func note_at():
	for n in M.get("notes", []):
		if absf(P.x - n.x) < 16 and absf(P.y - n.y) < 2:
			return n
	return null


func in_water() -> bool:
	return M.has("pond") and P.x > M.pond.x0 and P.x < M.pond.x1 and P.y - 4 > M.pond.surface


func init_water() -> void:
	water.cols = []; water.vel = []
	if not M.has("pond"):
		return
	water.x0 = M.pond.x0
	var n = int(ceil((M.pond.x1 - M.pond.x0) / water.step)) + 1
	for i in n:
		water.cols.append(0.0); water.vel.append(0.0)


func splash(x: float, k: float) -> void:
	if not M.has("pond"):
		return
	var i = roundi((x - water.x0) / water.step)
	for d in range(-3, 4):
		var j = i + d
		if j >= 0 and j < water.vel.size():
			water.vel[j] += (1.0 if d == 0 else 0.5) * k * 90
	var y: float = M.pond.surface
	for n in int(10 + k * 10):
		parts.append(S.Part.new(x + randf_range(-6, 6), y - 1, randf_range(-70, 70) * (0.5 + k * 0.5), randf_range(-200, -60) * (0.6 + k * 0.4), randf_range(0.35, 0.7), Color("#cfeaff") if n % 3 else Color.WHITE, 700, 1 if n % 4 else 2, y))
	Sfx.play("splash", 0.8 + k * 0.35)


func update_water(dt: float) -> void:
	if not M.has("pond") or water.cols.is_empty():
		return
	var c: Array = water.cols
	var v: Array = water.vel
	var n = c.size()
	for i in n:
		v[i] += (-60 * c[i] - 2.4 * v[i]) * dt
	for pass_i in 2:
		for i in n:
			var l: float = c[i - 1] if i > 0 else c[i]
			var r: float = c[i + 1] if i < n - 1 else c[i]
			v[i] += (l + r - 2 * c[i]) * 40 * dt
	for i in n:
		c[i] += v[i] * dt
	if randf() < dt * (1 + world.wind * 3):
		v[randi_range(0, n - 1)] += randf_range(-8, 8) * (0.4 + world.wind)
	if world.rain > 0.3:
		for k in int(world.rain * 2):
			if randf() < 0.5:
				v[randi_range(0, n - 1)] += randf_range(4, 10)
	if in_water() and absf(P.vx) > 20 and absf(P.y - 30 - M.pond.surface) < 20:
		var i = roundi((P.x - water.x0) / water.step)
		if i > 0 and i < n:
			v[i] += P.vx * 0.02


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	var rdt = minf(0.05, delta)
	real_time += rdt
	var scl = 1.0
	if hitstop > 0:
		hitstop -= rdt
		scl = 0.05
	elif slowmo > 0:
		slowmo -= rdt
		scl = 0.35
	var dt = rdt * scl
	shake = maxf(0, shake - rdt * 12)
	vignette = maxf(0, vignette - rdt / 0.45)
	if fade_to != null:
		fade = minf(1, fade + rdt * 4)
		if fade >= 1:
			var f: Dictionary = fade_to
			fade_to = null
			load_map(f.map, f.x, f.y)
	elif fade > 0:
		fade = maxf(0, fade - rdt * 3)
	if mode == "play" and not panel_open:
		game_time += dt
		player.update(dt)
		update_water(dt)
		mob_ctl.update(dt)
		update_drops(dt)
		update_parts(dt)
		update_style(dt)
		CH().playTime = CH().get("playTime", 0.0) + rdt
		if P.grounded and P.state != "dead":
			CH().pos = {"map": map_id, "x": roundf(P.x), "y": P.y}
	elif mode == "title":
		P.anim_t += rdt
		mob_ctl.update(rdt)
	update_world(rdt)
	update_camera(rdt)
	banner_msg.t += rdt
	combo_msg.t += rdt
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i].t += rdt
		if toasts[i].t > 3.4:
			toasts.remove_at(i)
	save_timer += rdt
	if save_dirty and save_timer > 5:
		save_timer = 0
		persist()
	pressed.clear()


func update_camera(dt: float) -> void:
	var tx = clampf(P.x - VW / 2.0 + P.face * 36, 0, M.w - VW)
	var ty = clampf(P.y - VH * 0.64, 0, M.h - VH)
	cam.x = damp(cam.x, tx, 6, dt)
	cam.y = damp(cam.y, ty, 5, dt)


func set_weather(w: String, announce: bool) -> void:
	if world.weather == w:
		return
	world.weather = w
	world.w_timer = randf_range(90, 170)
	if announce:
		toast({"sunny": "The clouds part. Sunshine!", "cloudy": "Clouds roll in.", "rain": "Rain starts to fall.", "thunderstorm": "Thunder rumbles. A storm is coming!", "snow": "Snowflakes drift down…"}[w])


func update_world(dt: float) -> void:
	var st: Dictionary = save.settings
	world.t = fmod(world.t + dt / 480.0 * st.timeSpeed, 1.0)
	if st.weather != "auto":
		set_weather(st.weather, false)
	else:
		world.w_timer -= dt
		if world.w_timer <= 0:
			var opts = WEATHERS.keys().filter(func(k): return k != world.weather)
			set_weather(opts[randi_range(0, opts.size() - 1)], true)
	var tg: Dictionary = W_PARAMS[world.weather]
	var k = 1.0 - exp(-dt * 0.4)
	world.cloud += (tg.cloud - world.cloud) * k
	var ready = world.cloud > 0.82   # rain and storms wait for the clouds to gather
	for key in ["rain", "snow", "storm"]:
		world[key] += ((tg[key] if key == "snow" or ready else 0.0) - world[key]) * k
	world.wind += (tg.wind * (1 + sin(real_time * 1000 / 2300.0) * 0.35) - world.wind) * k
	if world.snow > 0.4:
		world.snow_cover = minf(1, world.snow_cover + dt * 0.012 * world.snow)
	else:
		world.snow_cover = maxf(0, world.snow_cover - dt * 0.01)
	world.flash = maxf(0, world.flash - dt * 3)
	if world.storm > 0.5:
		world.next_bolt -= dt
		if world.next_bolt <= 0:
			world.next_bolt = randf_range(4, 10)
			world.flash = 1.0
			world.bolt = {"x": randf_range(20, VW - 20), "t": 0.25}
			get_tree().create_timer(randf_range(0.3, 1.3)).timeout.connect(func(): Sfx.play("thunder"))
	if world.bolt != null:
		world.bolt.t -= dt
		if world.bolt.t <= 0:
			world.bolt = null
	world.amb_t -= dt
	if world.amb_t <= 0:
		world.amb_t = 0.3
		var outdoors = mode == "play" and not M.get("indoor", false)
		Sfx.ambience(minf(1.3, world.rain) if outdoors else 0.0, minf(1.5, world.wind) if outdoors else 0.0)


func day_info() -> Dictionary:
	var a = (world.t - 0.25) * TAU
	var sun_y = sin(a)
	return {"sunY": sun_y, "day": clampf((sun_y + 0.12) / 0.34, 0, 1), "dusk": exp(-pow(sun_y / 0.2, 2)), "sunX": cos(a)}


# ---------------------------------------------------------------- drops, particles, style

func update_drops(dt: float) -> void:
	var pb = player.box()
	for i in range(drops.size() - 1, -1, -1):
		var d: S.Drop = drops[i]
		d.t += dt
		d.vy = minf(MAXFALL, d.vy + GRAV * dt)
		d.x += d.vx * dt
		d.y += d.vy * dt
		d.x = clampf(d.x, d.x0, d.x1)
		if d.y >= d.surf_y:
			d.y = d.surf_y
			if absf(d.vy) > 90:
				d.vy *= -0.45; d.vx *= 0.6
			else:
				d.vy = 0; d.vx *= exp(-dt * 10)
		if d.t > 0.35 and P.state != "dead" and d.x > pb.x0 - 4 and d.x < pb.x1 + 4 and d.y > pb.y0 and d.y < pb.y1 + 6:
			drops.remove_at(i)
			if d.kind == "coin":
				save.coins += d.val
				Sfx.coin()
				pickup_pop("coin", "Coins", d.val, Color("#ffe14d"))
			else:
				save.mats[d.type] = save.mats.get(d.type, 0) + 1
				Sfx.play("goo", 1.0, randf_range(0.9, 1.2))
				pickup_pop("m_" + d.type, D.mobs[d.type].residue, 1, Color.WHITE)
			save_dirty = true
			continue
		if d.t > 60:
			drops.remove_at(i)


var pops: Array = []
func pickup_pop(key: String, label: String, n: int, col: Color) -> void:
	var p = null
	for q in pops:
		if q.key == key:
			p = q
	if p == null:
		p = {"key": key, "label": label, "n": 0, "shown": 0.0, "t": 0.0, "col": col, "bump": 0.0}
		pops.append(p)
		if pops.size() > 5:
			pops.pop_front()
	p.n += n; p.t = 0.0; p.bump = 1.0


func update_parts(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: S.Part = parts[i]
		p.t += dt
		if p.t > p.life:
			parts.remove_at(i)
			continue
		p.vy += p.g * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.y > p.floor_y:
			p.y = p.floor_y; p.vy *= -0.3; p.vx *= 0.5
	for i in range(floaters.size() - 1, -1, -1):
		var f: S.Floater = floaters[i]
		f.t += dt
		f.y -= dt * (22 - f.t * 10)
		if f.t > f.life:
			floaters.remove_at(i)
	for i in range(pops.size() - 1, -1, -1):
		var p = pops[i]
		p.t += dt
		p.bump = maxf(0, p.bump - dt * 5)
		p.shown += (p.n - p.shown) * minf(1, dt * 14)
		if p.n - p.shown < 0.5:
			p.shown = p.n
		if p.t > 1.6:
			pops.remove_at(i)


func float_text(x: float, y: float, text: String, kind: String) -> void:
	var yy = y
	for f in floaters:
		if absf(f.x - x) < 14 and absf(f.y - yy) < 8 and f.t < 0.3:
			yy -= 9
	var f = S.Floater.new()
	f.x = x; f.y = yy; f.text = text; f.kind = kind; f.life = 1.1 if kind == "call" else 0.9
	floaters.append(f)
	if floaters.size() > 60:
		floaters.pop_front()


func sparks(x: float, y: float, col: Color, n: int) -> void:
	for i in n:
		var a = randf() * TAU
		var s = randf_range(60, 180)
		parts.append(S.Part.new(x, y, cos(a) * s, sin(a) * s - 40, randf_range(0.15, 0.3), col, 300, 1))


func goo(x: float, y: float, col: Color, n: int) -> void:
	for i in n:
		parts.append(S.Part.new(x, y, randf_range(-90, 90), randf_range(-220, -60), randf_range(0.4, 0.8), col, 700, randi_range(1, 2), y + 20))


func dust(x: float, y: float, n: int) -> void:
	for i in n:
		parts.append(S.Part.new(x + randf_range(-6, 6), y - 1, randf_range(-40, 40), randf_range(-30, -8), randf_range(0.3, 0.55), Color("#efe6cf"), 0, 2))


func rank_of(pts: float) -> int:
	var r = 0
	for i in D.ranks.size():
		if pts >= D.ranks[i].min:
			r = i
	return r


func style_add(base: float, id: String) -> void:
	var rep = style.last.count(id)
	var mult = 1.0 / (1 + rep * 0.55)
	style.last.append(id)
	if style.last.size() > 6:
		style.last.pop_front()
	style.pts = minf(D.rankCap, style.pts + base * mult)
	var r = rank_of(style.pts)
	if r > style.rank:
		style.popped = 1.0
		if r >= 4:
			Sfx.play("rankUp_%d" % clampi(r, 4, 9))
	style.rank = r
	style.peak = maxi(style.peak, r)


func combo_hit() -> void:
	style.hits += 1
	style.timer = 3.2
	style.since_hit = 0.0


func update_style(dt: float) -> void:
	style.since_hit += dt
	style.popped = maxf(0, style.popped - dt * 3)
	if style.since_hit > 1.1:
		style.pts = maxf(0, style.pts - dt * (22 + style.pts * 0.16))
		style.rank = rank_of(style.pts)
	if style.hits:
		style.timer -= dt
		if style.timer <= 0:
			end_combo(false)


func end_combo(broken: bool) -> void:
	var hits: int = style.hits
	var peak: int = style.peak
	style.hits = 0
	style.peak = style.rank
	style.timer = 0.0
	if hits < 5:
		return
	var k: float = D.rankMult[peak] * (0.5 if broken else 1.0)
	var e = roundi((hits * 3 + CH().level * 2) * k)
	var coins = roundi((hits * 2 + 4) * k)
	gain_exp(e)
	save.coins += coins
	save_dirty = true
	if not broken and peak > save.get("bestRank", -1):
		save.bestRank = peak
	combo_msg = {"big": "%d hit combo · %s" % [hits, D.ranks[peak].r], "sub": "+%d EXP · +%d coins%s" % [e, coins, " · broken, rewards halved" if broken else ""], "t": 0.0}


# ---------------------------------------------------------------- messages

func banner(big: String, sub := "") -> void:
	banner_msg = {"big": big, "sub": sub, "t": 0.0}


func toast(msg: String) -> void:
	toasts.append({"msg": msg, "t": 0.0})
	while toasts.size() > 4:
		toasts.pop_front()


# ---------------------------------------------------------------- input

const KEYNAMES := {KEY_LEFT: "left", KEY_RIGHT: "right", KEY_UP: "up", KEY_DOWN: "down", KEY_SPACE: "jump", KEY_Z: "atk", KEY_X: "heavy",
	KEY_C: "dash", KEY_SHIFT: "block", KEY_H: "pot_hp", KEY_J: "pot_sp", KEY_ENTER: "enter", KEY_KP_ENTER: "enter", KEY_ESCAPE: "esc", KEY_TAB: "menu", KEY_I: "menu",
	KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5", KEY_F11: "fullscreen", KEY_MINUS: "vol_down", KEY_EQUAL: "vol_up"}


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: String = KEYNAMES.get(event.keycode, "")
	if k == "":
		return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		keys[k] = false
		return
	if event.echo:
		return
	if k == "fullscreen":
		var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if k == "vol_down" or k == "vol_up":
		save.settings.vol = clampf(save.settings.vol + (0.1 if k == "vol_up" else -0.1), 0, 1)
		apply_volume()
		toast("Volume %d%%" % roundi(save.settings.vol * 100))
		Sfx.play("ui")
		save_dirty = true
		return
	if mode == "title":
		if k == "enter" or k == "jump":
			start_game()
		elif k == "esc":
			get_tree().quit()
		return
	if k == "menu" or (k == "esc" and panel_open):
		panel_open = not panel_open
		keys.clear()
		Sfx.play("ui")
		if not panel_open:
			persist()
		return
	if panel_open:
		if k in ["1", "2", "3", "4", "5"]:
			spend_point(ATTRS[int(k) - 1])
		return
	if k == "esc":
		persist()
		mode = "title"
		Sfx.music("sel_rock")
		return
	keys[k] = true
	pressed[k] = true
	if k == "left" or k == "right":
		var t = Time.get_ticks_msec()
		if t - last_tap.get(k, -9999) < 260:
			dbl_tap = k
		last_tap[k] = t


func start_game() -> void:
	mode = "play"
	Sfx.play("ui")
	recalc_stats()
	P.hp = PS.hp
	P.en = PS.enMax
	P.iframes = 1.2
	P.state = "move"
	player.set_anim("idle")
	Sfx.music(M.get("music", map_id))
	banner("Rock · " + job_name(int(CH().level)), "Press Tab for controls and your character")


# ---------------------------------------------------------------- helpers

static func hsh(n: float) -> float:
	var s = sin(n * 127.1) * 43758.5453
	return s - floor(s)


static func damp(a: float, b: float, k: float, dt: float) -> float:
	return lerpf(a, b, 1 - exp(-k * dt))


static func hbox(x0: float, x1: float, y0: float, y1: float) -> Dictionary:
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1}


static func overlap(a: Dictionary, b: Dictionary) -> bool:
	return a.x0 < b.x1 and a.x1 > b.x0 and a.y0 < b.y1 and a.y1 > b.y0
