extends RefCounted
## Draws the world each frame — sky, parallax hills, the painted map, monsters, Rock, water,
## particles, weather and the night tint — in the same order as the prototype's render().
## Everything here is in world units on a 384×216 view; the layer it draws into is scaled 2×.

const S := preload("res://scripts/state.gd")
const VW := 384.0
const VH := 216.0
const RX := 40.0       # hero sprite: hips/feet anchor inside the 84×76 frame (world units)
const GROUND := 66.0
const SW := 84.0
const SH := 76.0
const WIND_V := [-1.2, 0.0, 1.2, 2.4, 3.6]
const GRASS := {
	"meadow": ["#3f8f2e", "#5ab43c", "#7fd35a", "#b4ef86"], "ridge": ["#8a6a24", "#b88a30", "#dab050", "#f2d27a"],
	"hollow": ["#2b5e3a", "#3f7e4c", "#5ea36a", "#8fd08c"], "interior": ["#6e4428", "#8e5c36", "#b07a4a", "#d8a870"],
}
const FLOAT_COL := {"dmg": "#ffb03a", "crit": "#ff5d73", "hurt": "#c79bff", "coin": "#ffe14d", "exp": "#8ff0a4", "call": "#ffffff"}
const OUTLINE := Color("#1a1030")

var G
var P: S.Player
var font: FontFile
var clouds := []
var wclouds := []
var rain := []
var snow := []
var leaves := []
var life := {"flies": [], "birds": [], "bird_t": 4.0, "bugs": []}
var glow_tex: GradientTexture2D
var vig_tex: GradientTexture2D
var last_cam_x := 0.0
var _dt := 0.016


func _init(game) -> void:
	G = game
	P = game.P
	font = Assets.font
	for i in 9:
		clouds.append({"x": G.hsh(i + 90) * VW * 1.6, "y": 10 + G.hsh(i + 91) * 60, "w": 24 + G.hsh(i + 92) * 40, "k": G.hsh(i + 93)})
	for i in 22:
		wclouds.append({"x": G.hsh(i + 300) * (VW + 160) - 80, "y": 4 + G.hsh(i + 301) * 70, "r": 22 + G.hsh(i + 302) * 26, "k": G.hsh(i + 303), "flash": 0.0})
	for i in 220:
		rain.append({"x": randf() * VW, "y": randf() * VH, "s": randf_range(0.8, 1.2)})
	for i in 160:
		snow.append({"x": randf() * VW, "y": randf() * VH, "s": randf_range(0.5, 1.2), "p": randf() * 6})
	var leaf_cols = [Color("#6cc25a"), Color("#9be07c"), Color("#ec8fb0")]
	for i in 22:
		leaves.append({"x": randf() * VW, "y": randf() * VH, "p": randf() * 6, "c": leaf_cols[randi_range(0, 2)]})
	var fly_cols = [Color("#ffd23a"), Color.WHITE, Color("#9fc9ff"), Color("#ff9ecf")]
	for i in 7:
		life.flies.append({"x": randf_range(0, 1600), "y": 0.0, "p": randf() * 6, "c": fly_cols[i % 4], "vx": randf_range(-12, 12)})
	for i in 26:
		life.bugs.append({"x": randf(), "y": randf(), "p": randf() * 6})
	glow_tex = _radial([Color(1, 220 / 255.0, 150 / 255.0, 1), Color(1, 220 / 255.0, 150 / 255.0, 0)], [4.0 / 56.0, 1.0])
	vig_tex = _radial([Color(1, 40 / 255.0, 70 / 255.0, 0), Color(1, 40 / 255.0, 70 / 255.0, 0), Color(1, 40 / 255.0, 70 / 255.0, 0.6)], [0.0, 0.55, 1.0])


func _radial(cols: Array, offs: Array) -> GradientTexture2D:
	var g = Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# ------------------------------------------------------------------ small drawing helpers

static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0, 1))


func blit(ci: CanvasItem, tex: Texture2D, x: float, y: float, mod := Color.WHITE) -> void:
	if tex:
		ci.draw_texture_rect(tex, Rect2(x, y, tex.get_width() / 2.0, tex.get_height() / 2.0), false, mod)


## frame `f` of a horizontal strip of `n` frames, drawn at (x, y) in world units
func blit_frame(ci: CanvasItem, tex: Texture2D, n: int, f: int, x: float, y: float, w: float, h: float, mod := Color.WHITE) -> void:
	if tex == null:
		return
	var fw = tex.get_width() / float(n)
	ci.draw_texture_rect_region(tex, Rect2(x, y, w, h), Rect2(fw * clampi(f, 0, n - 1), 0, fw, tex.get_height()), mod)


func text(ci: CanvasItem, s: String, x: float, y: float, col: Color, size := 8, outline := OUTLINE, center := true) -> void:
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var X = roundf(x - w / 2) if center else roundf(x)
	var Y = roundf(y)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		ci.draw_string(font, Vector2(X, Y) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(outline, outline.a * col.a))
	ci.draw_string(font, Vector2(X, Y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), col)


# ------------------------------------------------------------------ the world

func draw_world(ci: CanvasItem) -> void:
	_dt = minf(0.05, ci.get_process_delta_time())
	var dt = _dt
	var M: Dictionary = G.M
	var D: Dictionary = G.day_info()
	var W: Dictionary = G.world
	var sh: float = G.shake
	var sx = roundf(G.cam.x + (randf_range(-sh, sh) if sh > 0.2 else 0.0))
	var sy = roundf(G.cam.y + (randf_range(-sh, sh) if sh > 0.2 else 0.0))
	var tt: float = G.real_time
	var theme: String = M.theme
	draw_sky(ci, D)
	draw_clouds(ci, D, dt)
	draw_weather_clouds(ci, D, dt)
	# parallax
	var floor_scr: float = M.floorY - sy
	var far_y = roundf(floor_scr * 0.35 + VH * 0.42 - 120)
	var mid_y = roundf(floor_scr * 0.6 + VH * 0.4 - 90)
	var fo = -fmod(roundf(sx * 0.15), VW * 2)
	var mo = -fmod(roundf(sx * 0.4), VW * 2)
	var far = Assets.tex("sky/%s_far.png" % theme)
	var mid = Assets.tex("sky/%s_mid.png" % theme)
	blit(ci, far, fo, far_y, Color(1, 1, 1, 0.9)); blit(ci, far, fo + VW * 2, far_y, Color(1, 1, 1, 0.9))
	blit(ci, mid, mo, mid_y); blit(ci, mid, mo + VW * 2, mid_y)
	if mid_y + 90 < VH:
		var base = {"hollow": "#2f4a3c", "ridge": "#b89448"}.get(theme, "#6fb86a")
		rect(ci, 0, mid_y + 90, VW, VH, Color(base))
	# terrain
	var map_tex = Assets.tex("maps/%s.png" % G.map_id)
	if map_tex:
		ci.draw_texture_rect_region(map_tex, Rect2(0, 0, VW, VH), Rect2(sx * 2, sy * 2, VW * 2, VH * 2))
	# snow caps
	if W.snow_cover > 0.05:
		var h = ceilf(W.snow_cover * 3)
		for s in G.surfaces:
			if s.x1 < sx or s.x0 > sx + VW:
				continue
			rect(ci, roundf(s.x0 - sx), roundf(s.y - sy - h + 1), roundf(s.x1 - s.x0), h, Color("#f4f8ff"))
	# raindrops splashing on every surface in view
	if W.rain > 0.3 and not M.get("indoor", false):
		for i in int(W.rain * 4):
			var s: Dictionary = G.surfaces[randi_range(0, G.surfaces.size() - 1)]
			var X = randf_range(maxf(s.x0, sx), minf(s.x1, sx + VW))
			if X > s.x0 and s.y - sy > 0 and s.y - sy < VH:
				rect(ci, roundf(X - sx) - 1, roundf(s.y - sy) - 2, 1, 1, Color(200 / 255.0, 225 / 255.0, 1, 0.8))
				rect(ci, roundf(X - sx) + 1, roundf(s.y - sy) - 2, 1, 1, Color(200 / 255.0, 225 / 255.0, 1, 0.8))
	# grass tufts sway in the wind
	var gr: Array = GRASS.get(theme, GRASS.meadow)
	for g in G.tufts:
		if g.fg:
			continue
		var X: float = g.x - sx
		var Y: float = g.y - sy
		if X < -2 or X > VW + 2 or Y < -4 or Y > VH + 4:
			continue
		var pushed = 2.0 * (signf(g.x - P.x) if g.x != P.x else 1.0) if absf(g.x - P.x) < 7 and absf(g.y - P.y) < 2 else 0.0
		var lean = roundf(sin(tt * (1.6 + W.wind) + g.p) * (0.4 + W.wind) - W.wind * 0.8) + pushed
		var c = Color("#eef4ff") if W.snow_cover > 0.5 else Color(gr[2])
		rect(ci, X, Y - 1, 1, 1, c)
		rect(ci, X + signf(lean), Y - 2, 1, 1, c)
		if g.h > 2:
			rect(ci, X + lean, Y - g.h, 1, 1, c)
	_draw_notes(ci, sx, sy)
	# portals and doors
	for p in M.portals:
		var X: float = p.x - sx
		var Y: float = p.get("y", M.floorY) - sy
		if p.get("door", false):
			if absf(P.x - p.x) < 30 and absf(P.y - p.get("y", M.floorY)) < 20:
				text(ci, "↑ " + p.label, roundf(clampf(X, 70, VW - 70)), roundf(Y - 42), Color.WHITE)
			continue
		for i in 18:
			var a = tt * 3 + i / 18.0 * TAU
			var r = 8 + sin(tt * 4 + i) * 1.5
			rect(ci, roundf(X + cos(a) * r * 0.6), roundf(Y - 16 + sin(a) * r), 2, 2, Color("#9fe6ff") if i % 3 else Color.WHITE)
		rect(ci, X - 4, Y - 26, 8, 20, Color(160 / 255.0, 230 / 255.0, 1, 0.35))
		if absf(P.x - p.x) < 40:
			text(ci, "↑ " + p.label, roundf(X), roundf(Y - 34), Color.WHITE)
	# drops
	var coin = Assets.tex("items/coin.png")
	for d in G.drops:
		var X = roundf(d.x - sx)
		var Y = roundf(d.y - sy)
		if d.kind == "coin":
			var f = int(floor(fmod(tt * 8 + d.spin, 4)))
			var bob = roundf(sin(tt * 4 + d.spin)) if d.vy == 0 else 0.0
			blit_frame(ci, coin, 4, f, X - 4, Y - 9 + bob, 9, 9)
		else:
			ci.draw_texture_rect(Assets.tex("items/residue_%s.png" % d.type), Rect2(X - 4, Y - 9, 9, 9), false)
	# monsters
	for e in G.mobs:
		_draw_mob(ci, e, sx, sy)
	# Rock
	if G.mode == "play" or true:
		_draw_player(ci, sx, sy)
	# pond water drawn over whatever is submerged
	if M.has("pond") and not G.water.cols.is_empty():
		_draw_water(ci, M.pond, sx, sy, tt)
	# tall grass in front of everyone, for depth
	for g in G.tufts:
		if not g.fg:
			continue
		var X: float = g.x - sx
		var Y: float = g.y - sy
		if X < -2 or X > VW + 2 or Y < -8 or Y > VH + 8:
			continue
		var pushed = 2.0 * (signf(g.x - P.x) if g.x != P.x else 1.0) if absf(g.x - P.x) < 8 and absf(g.y - P.y) < 3 else 0.0
		var lean: float = sin(tt * (1.6 + W.wind) + g.p) * (0.5 + W.wind) - W.wind + pushed
		var c = Color("#e4ecf8") if W.snow_cover > 0.5 else Color(gr[1])
		var k = 0.0
		while k < g.h:
			rect(ci, roundf((X + lean * k / g.h) * 2) / 2, Y - k - 0.5, 0.5, 0.5, c)
			k += 0.5
		rect(ci, roundf(X + lean), Y - g.h, 1, 1, Color.WHITE if W.snow_cover > 0.5 else Color(gr[3]))
	if not M.get("indoor", false):
		_draw_ambient_life(ci, sx, sy, D, dt)
	# particles
	for p in G.parts:
		var k: float = 1 - p.t / p.life
		var c: Color = p.col
		rect(ci, roundf(p.x - sx), roundf(p.y - sy), p.sz, p.sz, Color(c, c.a * minf(1, k * 1.5)))
	_draw_pops(ci, sx, sy)
	# floating numbers
	for f in G.floaters:
		var k: float = f.t / f.life
		var a = 1 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
		var col = Color(FLOAT_COL.get(f.kind, "#ffffff"), a)
		text(ci, f.text, roundf(f.x - sx), roundf(f.y - sy), col, 10 if f.kind == "crit" else 8)
	if not M.get("indoor", false):
		draw_weather(ci, dt, sx - last_cam_x)
	last_cam_x = sx


func _draw_mob(ci: CanvasItem, e: S.Mob, sx: float, sy: float) -> void:
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	if X < -30 or X > VW + 30:
		return
	var set_name = e.type + ("_shiny" if e.shiny else "")
	var critter: bool = e.T.get("critter", false)
	var key = "idle"
	var f = 0
	if e.shiny and e.state != "dead" and randf() < 0.25:
		var cols = [Color.WHITE, Color("#fff6b0"), Color("#ff9ecf")]
		G.parts.append(S.Part.new(e.x + randf_range(-e.w / 2, e.w / 2), e.y - randf_range(0, e.h + 6), 0, -14, 0.5, cols[randi_range(0, 2)], 0, 1))
	if e.state == "dead": key = "dead"
	elif e.flash > 0: key = "white"
	elif e.state == "hurt": key = "hurt"
	elif e.state == "wind": key = "wind"
	elif e.state == "shell": key = "shell"
	elif e.state == "spin":
		key = "spin"; f = int(floor(e.t * 18)) % 4
	elif e.state == "charge":
		key = "run"; f = int(floor(e.t * 22)) % 4
	elif e.y < e.surf.y - 1 and not (critter and e.state == "lunge"):
		key = "hopA" if e.aggro else "hop"
	elif e.sq > 0.2: key = "land"
	elif critter and e.state == "lunge": key = "lunge"
	elif critter and absf(e.vx) > 8:
		key = "run"; f = int(floor(e.t * 14)) % 4
	else:
		key = "angry" if e.aggro else "idle"; f = int(floor(e.t * 2.5)) % 2
	var n = Assets.mob_frames(set_name, key)
	var tex = Assets.mob_strip(set_name, key)
	var scl = Vector2(e.face, 1)
	var alpha = 1.0
	var ox = 0.0
	if e.state == "dead":
		var k = maxf(0, 1 - e.dead_t / 0.45)
		alpha = k
		scl *= Vector2(1 + (1 - k) * 0.6, k)
	if e.state == "wind":
		ox = roundf(sin(e.t * 60))
	if e.spawn_t > 0:
		var k = 1 - e.spawn_t / 0.5
		scl *= k
	ci.draw_set_transform(Vector2(X + ox, Y), 0, scl)
	blit_frame(ci, tex, n, f, -22, -33, 44, 36, Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO)
	if e.state != "dead" and (e.show_bar > 0 or e.aggro):
		var bw = 22.0
		var bx = X - bw / 2
		var by = Y - e.h - 12
		rect(ci, bx - 1, by - 1, bw + 2, 4, OUTLINE)
		rect(ci, bx, by, bw, 2, Color("#5b2335"))
		rect(ci, bx, by, maxf(0, roundf(bw * e.hp / e.max_hp)), 2, Color("#ff5d73"))
		var d: int = e.lv - int(G.CH().level)
		text(ci, "Lv %d" % e.lv, X, by - 3, Color("#ff8a9a") if d >= 3 else (Color("#b8c0d0") if d <= -3 else Color.WHITE))
	if e.bang > 0 and e.state != "dead":
		text(ci, "!", X, Y - e.h - 16, Color("#ffd23a"))
	if e.shiny and e.state != "dead":
		text(ci, "*", X + e.w / 2 + 4, Y - e.h - 8, Color("#fff6b0"))


func _draw_player(ci: CanvasItem, sx: float, sy: float) -> void:
	var X = roundf(P.x - sx)
	var Y = roundf(P.y - sy)
	var vi = 0
	for i in WIND_V.size():
		if absf(WIND_V[i] - P.wind_v) < absf(WIND_V[vi] - P.wind_v):
			vi = i
	var anim = P.anim if Assets.hero.anims.has(P.anim) else "idle"
	var n = int(Assets.hero.anims[anim].frames)
	var f: int = G.player.frame() if G.mode == "play" else int(floor(P.anim_t * 8)) % n
	var tex = Assets.hero_strip(anim, vi)
	var blink: bool = P.state != "dash" and P.iframes > 0 and P.iframes < 0.9 and int(floor(G.game_time * 18)) % 2 == 0
	if P.grounded:
		rect(ci, X - 8, Y - 1, 16, 2, Color(20 / 255.0, 30 / 255.0, 10 / 255.0, 0.25))
	for l in G.speed_lines:
		var a: float = 1 - l.t / l.life
		var lx = roundf(l.x - sx)
		var ly = roundf(l.y - sy)
		rect(ci, lx - l.len if P.face > 0 else lx, ly, l.len, 1, Color(1, 1, 1, 0.8 * a))
		rect(ci, lx - l.len * 0.6 if P.face > 0 else lx, ly + 1, l.len * 0.6, 1, Color(200 / 255.0, 240 / 255.0, 1, 0.35 * a))
	if P.state == "dash":
		for k in range(1, 4):
			ci.draw_set_transform(Vector2(X - P.face * k * 9, Y), 0, Vector2(P.face, 1))
			blit_frame(ci, tex, n, f, -RX, -GROUND, SW, SH, Color(1, 1, 1, 0.25 / k))
	if not blink:
		ci.draw_set_transform(Vector2(X, Y), 0, Vector2(P.face, 1))
		blit_frame(ci, tex, n, f, -RX, -GROUND, SW, SH)
	ci.draw_set_transform(Vector2.ZERO)
	# name tag, classic MMO style
	rect(ci, X - 18, Y + 3, 36, 10, Color(20 / 255.0, 20 / 255.0, 40 / 255.0, 0.7))
	ci.draw_string(font, Vector2(X - font.get_string_size("Rock", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2, Y + 11), "Rock", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_water(ci: CanvasItem, W: Dictionary, sx: float, sy: float, tt: float) -> void:
	var c: Array = G.water.cols
	var st: float = G.water.step
	var pts = PackedVector2Array()
	pts.append(Vector2(W.x0 - sx, W.bottom - sy + 20))
	for i in c.size():
		pts.append(Vector2(W.x0 + i * st - sx, W.surface + c[i] - sy))
	pts.append(Vector2(W.x1 - sx, W.bottom - sy + 20))
	ci.draw_colored_polygon(pts, Color(60 / 255.0, 130 / 255.0, 210 / 255.0, 0.42))
	rect(ci, W.x0 - sx, W.surface + 14 - sy, W.x1 - W.x0, W.bottom - W.surface, Color(30 / 255.0, 70 / 255.0, 140 / 255.0, 0.25))
	for i in c.size():
		var X = roundf(W.x0 + i * st - sx)
		var Y = roundf(W.surface + c[i] - sy)
		rect(ci, X, Y, st, 1, Color(220 / 255.0, 245 / 255.0, 1, 0.9))
		if (i + int(floor(tt * 2))) % 9 == 0:
			rect(ci, X + 1, Y + 3, 2, 1, Color(1, 1, 1, 0.8))
	# lily pads riding the surface
	for lx in [0.18, 0.46, 0.63, 0.84]:
		var X: float = W.x0 + (W.x1 - W.x0) * lx
		var i = roundi((X - W.x0) / st)
		var Y = roundf(W.surface + (c[i] if i < c.size() else 0.0) - sy)
		rect(ci, roundf(X - sx) - 5, Y - 1, 10, 2, Color("#1f5a2c"))
		rect(ci, roundf(X - sx) - 4, Y - 1, 8, 1, Color("#4faa4a"))
		if lx == 0.46:
			rect(ci, roundf(X - sx) - 1, Y - 3, 3, 2, Color("#ffc4dc"))


func _draw_notes(ci: CanvasItem, sx: float, sy: float) -> void:
	var n = G.note_at() if G.M.has("notes") else null
	if n != null and G.thought == null:
		text(ci, "↑ " + n.label, roundf(n.x - sx), roundf(n.y - sy - 58), Color.WHITE)
	var th = G.thought
	if th == null:
		return
	th.t += _dt
	if th.t > 4.5 or (n == null and th.t > 1.5 and th.t < 3.4):
		G.thought = null
		return
	# a soft thought bubble above the hero's head
	var a = minf(1, minf(th.t * 4, (4.5 - th.t) * 2))
	var X = roundf(clampf(P.x - sx, 90, VW - 90))
	var Y = roundf(P.y - sy - 70)
	var words: PackedStringArray = th.text.split(" ")
	var lines = []
	var ln = ""
	for wd in words:
		var t2 = (ln + " " + wd) if ln else wd
		if font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x > 150:
			lines.append(ln); ln = wd
		else:
			ln = t2
	lines.append(ln)
	var w = 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x)
	w += 14
	var h = lines.size() * 10 + 8.0
	var ink = Color("#27335c", a)
	var paper = Color(1, 1, 1, 0.95 * a)
	var box = Rect2(X - w / 2, Y - h, w, h)
	ci.draw_rect(box, paper)
	ci.draw_rect(box, ink, false, 1)
	for b in [[-4, 4, 2.5], [-8, 10, 1.6]]:
		ci.draw_circle(Vector2(roundf(P.x - sx) + b[0], Y + b[1]), b[2], paper)
		ci.draw_arc(Vector2(roundf(P.x - sx) + b[0], Y + b[1]), b[2], 0, TAU, 12, ink, 1)
	for i in lines.size():
		var lw = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		ci.draw_string(font, Vector2(roundf(X - lw / 2), Y - h + 13 + i * 10), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, ink)


func _draw_pops(ci: CanvasItem, sx: float, sy: float) -> void:
	var n: int = G.pops.size()
	for i in n:
		var p = G.pops[i]
		var a = maxf(0, 1 - (p.t - 1.25) / 0.35) if p.t > 1.25 else 1.0
		var X = roundf(P.x - sx)
		var Y = roundf(P.y - sy - 50 - (n - 1 - i) * 10 - (1 - a) * 4)
		text(ci, "+%d %s" % [roundi(p.shown), p.label], X, Y, Color(p.col, a), 9 if p.bump > 0.4 else 8)


# ------------------------------------------------------------------ sky and weather

func draw_sky(ci: CanvasItem, D: Dictionary) -> void:
	var W: Dictionary = G.world
	var top = mix(mix(Color("#0c1638"), Color("#4aa8ff"), D.day), Color("#6b7fe0"), D.dusk * 0.6)
	var hor = mix(mix(Color("#26407a"), Color("#c8eeff"), D.day), Color("#ffb88a"), D.dusk * 0.8)
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(VW, 0), Vector2(VW, VH), Vector2(0, VH)]), PackedColorArray([top, top, hor, hor]))
	if W.cloud > 0.3:
		rect(ci, 0, 0, VW, VH, Color(110 / 255.0, 120 / 255.0, 140 / 255.0, (W.cloud - 0.3) * 0.45 * (0.3 + D.day * 0.7)))
	if D.day < 0.7:
		draw_night_sky(ci, (1 - D.day / 0.7) * maxf(0, 1 - W.cloud * 1.2))
	var sx: float = VW / 2 + D.sunX * VW * 0.42
	var sy: float = VH * 0.75 - absf(D.sunY) * VH * 0.6
	if W.cloud < 0.9:
		if D.sunY > -0.05:
			rect(ci, roundf(sx) - 5, roundf(sy) - 5, 10, 10, Color("#ffb36a") if D.dusk > 0.5 else Color("#fff4c0"))
			rect(ci, roundf(sx) - 8, roundf(sy) - 8, 16, 16, Color(1, 240 / 255.0, 180 / 255.0, 0.25))
		else:
			var mx = VW - sx
			rect(ci, roundf(mx) - 4, roundf(sy) - 4, 8, 8, Color("#eef2ff"))
			rect(ci, roundf(mx) - 1, roundf(sy) - 2, 2, 2, Color("#c9d2ee"))


func draw_night_sky(ci: CanvasItem, a: float) -> void:
	if a <= 0.01:
		return
	var t: float = G.real_time
	ci.draw_texture_rect(Assets.tex("sky/galaxy.png"), Rect2(0, 0, VW, VH), false, Color(1, 1, 1, a * 0.9))
	var cols = [Color(1, 1, 1), Color(200 / 255.0, 220 / 255.0, 1), Color(1, 230 / 255.0, 190 / 255.0), Color(1, 200 / 255.0, 230 / 255.0)]
	for i in 160:
		var sx: float = G.hsh(i * 1.7) * VW
		var sy: float = G.hsh(i * 2.3 + 50) * VH * 0.62
		var tw = 0.5 + 0.5 * sin(t * (0.6 + G.hsh(i) * 2) + i)
		var bright = i % 23 == 0
		var col: Color = cols[i % 4]
		var sz = 1.0 if i % 5 == 0 else 0.5
		rect(ci, roundf(sx * 2) / 2, roundf(sy * 2) / 2, sz, sz, Color(col, a * (0.9 if bright else 0.25 + tw * 0.55)))
		if bright:
			var g = a * (0.4 + tw * 0.6)
			rect(ci, sx - 2, sy + 0.25, 5, 0.5, Color(col, g * 0.7))
			rect(ci, sx + 0.25, sy - 2, 0.5, 5, Color(col, g * 0.7))
			rect(ci, sx - 1, sy - 1, 3, 3, Color(col, g * 0.25))
	# a ringed planet and a small red one
	var p = Vector2(VW * 0.78, 34)
	ci.draw_circle(p, 11, Color(1, 220 / 255.0, 170 / 255.0, 0.18 * a))
	ci.draw_circle(p, 7, Color("#e8c890", a))
	rect(ci, p.x - 7, p.y - 1, 14, 1.5, Color("#c8a070", a))
	rect(ci, p.x - 6, p.y + 2.5, 12, 1, Color("#c8a070", a))
	ci.draw_circle(p + Vector2(-2.5, -2.5), 2, Color("#fff0d0", a))
	var ring = PackedVector2Array()
	for i in 33:
		var th = i / 32.0 * TAU
		ring.append(p + Vector2(cos(th) * 14, sin(th) * 3.5).rotated(-0.35))
	ci.draw_polyline(ring, Color(1, 236 / 255.0, 200 / 255.0, 0.85 * a), 1)
	var cap = PackedVector2Array()   # the ring passes behind the top of the planet
	for i in 13:
		var th = PI * 1.08 + i / 12.0 * PI * 0.84
		cap.append(p + Vector2(cos(th), sin(th)) * 7)
	ci.draw_colored_polygon(cap, Color("#e8c890", a))
	ci.draw_circle(Vector2(VW * 0.18, 22), 3, Color("#c85a4a", a))
	rect(ci, VW * 0.18 - 2, 20, 1.5, 1.5, Color("#ff8a70", a))


func draw_clouds(ci: CanvasItem, D: Dictionary, dt: float) -> void:
	var W: Dictionary = G.world
	var shade = mix(mix(Color("#39406a"), Color.WHITE, D.day), Color("#8a93a3"), W.cloud * 0.6)
	for c in clouds:
		c.x -= dt * (3 + W.wind * 10) * (0.5 + c.k)
		if c.x < -c.w:
			c.x += VW + c.w * 2
		if c.k > 0.25 + W.cloud * 0.75:
			continue
		var i = 0.0
		while i < c.w:
			var h = 4 + roundf(sin(i / c.w * PI) * 6)
			rect(ci, roundf(c.x + i), roundf(c.y - h), 5, h + 3, shade)
			i += 4


func draw_weather_clouds(ci: CanvasItem, D: Dictionary, dt: float) -> void:
	var W: Dictionary = G.world
	var wet = clampf((W.cloud - 0.45) / 0.45, 0, 1)
	if wet <= 0.01:
		return
	var snowy: bool = W.snow > W.rain
	var kind = "snow" if snowy else "rain"
	var light: float = 0.45 + D.day * 0.55
	for c in wclouds:
		c.x -= dt * (4 + W.wind * 14) * (0.6 + c.k * 0.6)
		if c.x < -c.r * 3:
			c.x = VW + c.r
		var spr = Assets.tex("sky/clouds/cloud_%s_%d.png" % [kind, clampi(roundi(c.r), 22, 48)])
		blit(ci, spr, c.x, c.y, Color(1, 1, 1, wet * (0.95 if snowy else 0.92) * (1.0 if c.k < wet * 1.1 else 0.4)))
		if c.flash > 0:   # lightning lighting the cloud from inside
			c.flash -= dt
			var cc = Vector2(c.x + c.r * 1.3, c.y + c.r * 0.7)
			ci.draw_texture_rect(glow_tex, Rect2(cc - Vector2(c.r * 1.3, c.r * 1.3), Vector2(c.r * 2.6, c.r * 2.6)), false, Color(1, 1, 1, minf(1, c.flash * 6)))
	if not snowy:
		rect(ci, 0, 0, VW, VH, Color(30 / 255.0, 34 / 255.0, 50 / 255.0, wet * 0.16 * light))   # the whole sky dims under rain clouds
	if W.storm > 0.5 and randf() < dt * 0.9:
		var c = wclouds[randi_range(0, wclouds.size() - 1)]
		if c.x > -20 and c.x < VW:
			c.flash = 0.25


func draw_weather(ci: CanvasItem, dt: float, cam_dx: float) -> void:
	var W: Dictionary = G.world
	var w: float = W.wind
	var n_r = int(rain.size() * minf(1, W.rain / 1.2))
	for i in n_r:
		var r = rain[i]
		r.y += dt * 260 * r.s
		r.x -= dt * (w * 90) + cam_dx * 0.9
		if r.y > VH:
			r.y -= VH + 10; r.x = randf() * VW
		r.x = fposmod(r.x, VW)
		rect(ci, roundf(r.x), roundf(r.y), 1, 4, Color(200 / 255.0, 220 / 255.0, 1, 0.55))
	var n_s = int(snow.size() * minf(1, W.snow))
	for i in n_s:
		var s = snow[i]
		s.p += dt; s.y += dt * 22 * s.s
		s.x += sin(s.p * 1.3) * dt * 8 - dt * w * 30 - cam_dx * 0.9
		if s.y > VH:
			s.y = -2; s.x = randf() * VW
		s.x = fposmod(s.x, VW)
		var sz = 2.0 if s.s > 1 else 1.0
		rect(ci, roundf(s.x), roundf(s.y), sz, sz, Color.WHITE)
	if W.snow < 0.5 and W.rain < 0.5:
		var n_l = int(leaves.size() * minf(1, 0.3 + w * 0.6))
		for i in n_l:
			var l = leaves[i]
			l.p += dt * 3
			l.x -= dt * (20 + w * 60) + cam_dx * 0.9
			l.y += sin(l.p) * dt * 14 + dt * 8
			if l.x < -4:
				l.x = VW + 4; l.y = randf() * VH * 0.7
			if l.y > VH:
				l.y = 0
			l.x = fposmod(l.x + VW + 8, VW + 8)
			rect(ci, roundf(l.x), roundf(l.y), 2 if sin(l.p) > 0 else 1, 1, l.c)
	if W.bolt != null:
		var bx: float = W.bolt.x
		var y = 0.0
		while y < VH * 0.8:
			bx += randf_range(-3, 3)
			rect(ci, roundf(bx), y, 2, 4, Color(1, 1, 1, 0.9))
			y += 4


func _draw_ambient_life(ci: CanvasItem, sx: float, sy: float, D: Dictionary, dt: float) -> void:
	var W: Dictionary = G.world
	var M: Dictionary = G.M
	var dry: bool = W.rain < 0.3 and W.snow < 0.3
	if D.day > 0.5 and dry:   # butterflies drift around the player's area
		for b in life.flies:
			b.p += dt * 9
			b.vx = clampf(b.vx + randf_range(-40, 40) * dt, -18, 18)
			if not b.y or absf(b.x - P.x) > 260:
				b.x = P.x + randf_range(-180, 180); b.y = M.floorY - randf_range(12, 60)
			b.x += b.vx * dt - W.wind * 6 * dt
			b.y += sin(b.p * 0.3) * 8 * dt
			var X = roundf(b.x - sx)
			var Y = roundf(b.y - sy + sin(b.p) * 1.5)
			if X < 0 or X > VW:
				continue
			if sin(b.p) > 0:
				rect(ci, X - 1, Y, 1, 1, b.c); rect(ci, X + 1, Y, 1, 1, b.c)
			else:
				rect(ci, X - 1, Y - 1, 1, 2, b.c); rect(ci, X + 1, Y - 1, 1, 2, b.c)
			rect(ci, X, Y, 1, 1, Color("#241410"))
	if D.day > 0.4 and W.storm < 0.5:   # a small flock crosses the sky now and then
		life.bird_t -= dt
		if life.bird_t <= 0:
			life.bird_t = randf_range(9, 20)
			var y0 = randf_range(14, 60)
			for i in randi_range(3, 6):
				life.birds.append({"x": VW + 10 + i * 9, "y": y0 + absf(i - 2) * 4, "p": randf() * 6})
		var c = mix(Color("#2a3350"), Color("#6a7a9a"), 1 - D.day)
		for b in life.birds:
			b.x -= dt * 26; b.p += dt * 10
			var X = roundf(b.x)
			var Y = roundf(b.y)
			var up = 1 if sin(b.p) > 0 else 0
			rect(ci, X - 2, Y - up, 2, 1, c); rect(ci, X, Y, 1, 1, c); rect(ci, X + 1, Y - up, 2, 1, c)
		life.birds = life.birds.filter(func(b): return b.x > -10)
	if D.day < 0.35 and W.rain < 0.3:   # fireflies at night
		var a: float = (0.35 - D.day) / 0.35
		for f in life.bugs:
			f.p += dt
			var X = roundf(fposmod(f.x * VW + sin(f.p * 0.7) * 12 + VW, VW))
			var Y = roundf(VH * 0.35 + f.y * VH * 0.5 + cos(f.p * 0.9) * 8)
			var g = 0.5 + 0.5 * sin(f.p * 3)
			rect(ci, X, Y, 1, 1, Color(220 / 255.0, 1, 120 / 255.0, a * g))
			if g > 0.8:
				rect(ci, X - 1, Y - 1, 3, 3, Color(220 / 255.0, 1, 120 / 255.0, a * 0.25))


# ------------------------------------------------------------------ light

## drawn with a multiply blend: night turns everything moonlit blue, heavy cloud greys it
func draw_tint(ci: CanvasItem) -> void:
	var M: Dictionary = G.M
	var D: Dictionary = G.day_info()
	var W: Dictionary = G.world
	var night: float = 1 - D.day
	if M.get("indoor", false) or (night <= 0.02 and W.cloud <= 0.4):
		return
	rect(ci, 0, 0, VW, VH, mix(Color.WHITE, Color("#5a6cb8"), night * 0.62))
	if W.cloud > 0.4:
		rect(ci, 0, 0, VW, VH, mix(Color.WHITE, Color("#b4bccb"), (W.cloud - 0.4) * 0.45 * (1 - night * 0.6)))


func draw_overlay(ci: CanvasItem) -> void:
	var M: Dictionary = G.M
	var D: Dictionary = G.day_info()
	var W: Dictionary = G.world
	var night: float = 1 - D.day
	var outdoors: bool = not M.get("indoor", false)
	if outdoors and night > 0.3:   # a warm glow around Rock at night
		var l = Vector2(roundf(P.x - G.cam.x), roundf(P.y - G.cam.y - 20))
		ci.draw_texture_rect(glow_tex, Rect2(l - Vector2(56, 56), Vector2(112, 112)), false, Color(1, 1, 1, (night - 0.3) * 0.28))
	if outdoors and D.dusk > 0.1:
		rect(ci, 0, 0, VW, VH, Color(1, 140 / 255.0, 80 / 255.0, D.dusk * 0.12))
	if W.flash > 0:
		rect(ci, 0, 0, VW, VH, Color(1, 1, 1, W.flash * 0.6))
	if G.vignette > 0:
		ci.draw_texture_rect(vig_tex, Rect2(-VW * 0.2, -VH * 0.6, VW * 1.4, VH * 2.2), false, Color(1, 1, 1, G.vignette))
	if G.fade > 0:
		rect(ci, 0, 0, VW, VH, Color(10 / 255.0, 12 / 255.0, 30 / 255.0, G.fade))
