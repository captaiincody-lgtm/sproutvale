extends "res://scripts/climb_draw.gd"
## Sproutvale, part 7⅞: drawing the inside of Glamrax's volcano. The painted rooms come from
## art/volcano/maps; on top of them go the things that move: Glamrax's scientists at their screens,
## the monsters sealed in hanging crystals, alarms and security lights, eyes in the cells, the
## sanctum's machine. Then the security monsters' extras (glowing eyes, lasers, rifle fire, sparks).

const BEAST_COLS := [["#ff4ad8", "#5a1048"], ["#7af0ff", "#1a4a5a"], ["#ffb03a", "#5a2a10"], ["#b8ff6a", "#2a4a14"]]


# ================================================================ backgrounds

func drawClimbBack(x: Ctx, sx: float, sy: float, dt: float, D: Dictionary) -> void:
	if not volcanoMap():
		super.drawClimbBack(x, sx, sy, dt, D)
		return
	x.fillStyle = "#0c070c"
	x.fillRect(0, 0, VW, VH)
	drawVolcanoBack(x, sx, sy)


func drawClimbMid(x: Ctx, sx: float, sy: float) -> void:
	if not volcanoMap():
		super.drawClimbMid(x, sx, sy)
		return
	drawVolcanoMid(x, sx, sy)


## between the painted room and the monsters: everything in it that moves
func drawVolcanoMid(x: Ctx, sx: float, sy: float) -> void:
	var t = realTime
	var S: Dictionary = vSpots()
	for m in S.get("monitor", []):
		_monitor(x, m[0] - sx, m[1] - sy, t, m[0])
	for c in S.get("crystal", []):
		_beastCrystal(x, c[0] - sx, c[1] - sy, int(c[2]), t, c[0])
	for p in S.get("scientist", []):
		_scientist(x, p[0] - sx, p[1] - sy, t, p[0])
	for a in S.get("alarm", []):
		_alarm(x, a[0] - sx, a[1] - sy, t, _alarmOn())
	for w in S.get("window", []):
		_viewWindow(x, w[0] - sx, w[1] - sy, t)
	for g in S.get("gate", []):
		_blastDoor(x, g[0] - sx, g[1] - sy, heroBeat("mk2"))
	for c in S.get("cell", []):
		_cellEyes(x, c[0] - sx, c[1] - sy, t, c[0])
	for d in S.get("dial", []):
		_dial(x, d[0] - sx, d[1] - sy, t)
	for k in S.get("tank", []):
		_tank(x, k[0] - sx, k[1] - sy, k[2], k[3], t)
	drawSanctumMid(x, sx, sy)


func _alarmOn() -> bool:
	return mapId == "volcano2" and slimes.any(func(e): return e.boss and e.state != "dead")


func _monitor(x: Ctx, X: float, Y: float, t: float, seed: float) -> void:
	if X < -20 or X > VW + 20:
		return
	# readouts scroll: a DNA trace, numbers, a radar sweep
	var kind = int(hsh(seed) * 3)
	x.fillStyle = "#06201c"
	x.fillRect(X - 8, Y - 6, 16, 12)
	match kind:
		0:
			for i in 14:
				var yy = Y + sin(t * 3 + i * 0.6 + seed) * 3
				x.fillStyle = "#3af0c8" if i % 2 else "#ff4ad8"
				x.fillRect(X - 7 + i, yy, 1, 1)
				x.fillRect(X - 7 + i, Y - (yy - Y), 1, 1)
		1:
			for r in 4:
				var w = 4 + int(hsh(floorf(t * 2) + r + seed) * 10)
				x.fillStyle = "#3af0c8"
				x.fillRect(X - 7, Y - 5 + r * 3, w, 1)
		_:
			var a = t * 2.5 + seed
			x.strokeStyle = "#1a6a5a"; x.lineWidth = 0.6
			x.beginPath(); x.arc(X, Y, 5, 0, TAU); x.stroke()
			x.strokeStyle = "#3af0c8"; x.lineWidth = 1
			x.beginPath(); x.moveTo(X, Y); x.lineTo(X + cos(a) * 5, Y + sin(a) * 5); x.stroke()
			if fmod(t + seed, 2.0) < 1.0:
				x.fillStyle = "#ff2a3a"; x.fillRect(roundf(X + 2), roundf(Y - 2), 1, 1)
	if hsh(floorf(t * 8) + seed) > 0.96:
		x.fillStyle = rgba(255, 255, 255, 0.4); x.fillRect(X - 8, Y - 6, 16, 12)   # a flicker


## one of Glamrax's scientists: lab coat, goggles, typing; now and then they glance at the fight
func _scientist(x: Ctx, X: float, Y: float, t: float, seed: float) -> void:
	if X < -20 or X > VW + 20:
		return
	X = roundf(X)
	Y = roundf(Y)
	var face = -1 if hsh(seed * 3) < 0.5 else 1
	var desk = X + face * 0.0
	var look = fmod(t * 0.3 + hsh(seed) * 10, 7.0) < 0.8   # turns round to look at you
	var typing = int(t * 10 + seed) % 2
	x.save()
	x.translate(X, Y)
	var dir = -1 if X + cam.x > P.x else 1
	if look:
		x.scale(dir, 1)
	elif face < 0:
		x.scale(-1, 1)
	# legs, coat, arms, head
	x.fillStyle = "#1a1c24"; x.fillRect(-3, -8, 2, 8); x.fillRect(1, -8, 2, 8)
	x.fillStyle = "#e8eaf0"; x.fillRect(-4, -19, 8, 12)
	x.fillStyle = "#c4c8d4"; x.fillRect(-4, -12, 8, 1); x.fillRect(0, -19, 1, 12)
	x.fillStyle = "#ff4ad8"; x.fillRect(-3, -17, 2, 1)   # Glamrax's badge
	x.fillStyle = "#e8eaf0"
	if look:
		x.fillRect(3, -18, 2, 7)
	else:
		x.fillRect(3, -18, 2, 4); x.fillRect(4 + typing, -15, 3, 2)
	x.fillStyle = "#e0b090"; x.fillRect(-2, -24, 5, 5)
	x.fillStyle = "#3a2a20"; x.fillRect(-2, -25, 5, 2)
	x.fillStyle = "#3af0c8"; x.fillRect(1, -23, 3, 1)   # goggles catching the screen's light
	x.restore()


## a crystal hanging in the air with a monster frozen inside it; now and then its eyes open
func _beastCrystal(x: Ctx, X: float, Y: float, kind: int, t: float, seed: float) -> void:
	if X < -50 or X > VW + 50:
		return
	Y += sin(t * 0.8 + seed) * 2
	var C = BEAST_COLS[kind % 4]
	var gl = x.createRadialGradient(X, Y, 4, X, Y, 52)
	gl.addColorStop(0, Color(css(C[0]), 0.28)); gl.addColorStop(1, Color(css(C[0]), 0))
	x.fillStyle = gl; x.beginPath(); x.arc(X, Y, 52, 0, TAU); x.fill()
	# the crystal: a long shard, violet glass with hard facets
	var pts = [[0, -38], [16, -18], [18, 16], [6, 36], [-8, 34], [-18, 12], [-15, -20]]
	x.fillStyle = "#2a1a3a"
	x.beginPath()
	for i in pts.size():
		if i == 0: x.moveTo(X + pts[i][0], Y + pts[i][1])
		else: x.lineTo(X + pts[i][0], Y + pts[i][1])
	x.closePath(); x.fill()
	# the prisoner: a dark silhouette curled up inside
	x.fillStyle = C[1]
	match kind % 4:
		0:   # a horned beast, curled up
			x.beginPath(); x.ellipse(X, Y + 4, 10, 14, 0.2, 0, TAU); x.fill()
			x.beginPath(); x.ellipse(X + 2, Y - 12, 6, 5, 0, 0, TAU); x.fill()
			x.fillRect(X - 4, Y - 20, 2, 5); x.fillRect(X + 6, Y - 20, 2, 5)
		1:   # a coiled serpent
			for i in 5:
				x.beginPath(); x.arc(X + sin(i * 1.6) * 6, Y + 18 - i * 8, 5 - i * 0.4, 0, TAU); x.fill()
		2:   # a winged demon, wings folded
			x.beginPath(); x.moveTo(X - 14, Y - 14); x.lineTo(X, Y - 4); x.lineTo(X + 14, Y - 14); x.lineTo(X + 8, Y + 22); x.lineTo(X - 8, Y + 22); x.closePath(); x.fill()
			x.beginPath(); x.arc(X, Y - 10, 5, 0, TAU); x.fill()
		_:   # something with too many legs
			x.beginPath(); x.ellipse(X, Y + 2, 8, 10, 0, 0, TAU); x.fill()
			x.strokeStyle = C[1]; x.lineWidth = 1.2
			for i in 4:
				for s in [-1, 1]:
					x.beginPath(); x.moveTo(X, Y - 4 + i * 4); x.lineTo(X + s * 12, Y - 10 + i * 6); x.lineTo(X + s * 14, Y + 2 + i * 6); x.stroke()
	var open = fmod(t * 0.4 + hsh(seed) * 7, 6.0) < 1.2
	if open:
		x.fillStyle = C[0]
		x.fillRect(roundf(X - 3), roundf(Y - 12), 2, 1); x.fillRect(roundf(X + 2), roundf(Y - 12), 2, 1)
	# the glass over it: translucent facets and a hard highlight
	x.globalAlpha = 0.45
	x.fillStyle = C[0]
	x.beginPath(); x.moveTo(X, Y - 38); x.lineTo(X + 16, Y - 18); x.lineTo(X + 18, Y + 16); x.lineTo(X + 4, Y + 2); x.closePath(); x.fill()
	x.globalAlpha = 0.25
	x.beginPath(); x.moveTo(X, Y - 38); x.lineTo(X - 15, Y - 20); x.lineTo(X - 18, Y + 12); x.lineTo(X - 4, Y - 4); x.closePath(); x.fill()
	x.globalAlpha = 1
	x.strokeStyle = "#f0d8ff"; x.lineWidth = 1
	x.beginPath(); x.moveTo(X - 10, Y - 22); x.lineTo(X - 13, Y + 8); x.stroke()
	# energy crawling down the cables
	var k = fmod(t * 0.9 + hsh(seed), 1.0)
	for s in [-1, 1]:
		x.fillStyle = C[0]
		x.fillRect(roundf(X + s * (6 + k * 20)), roundf(Y + 30 + k * 60), 2, 2)


func _alarm(x: Ctx, X: float, Y: float, t: float, on: bool) -> void:
	if not on:
		x.fillStyle = "#3a0a10"; x.beginPath(); x.ellipse(X, Y, 7, 5, 0, 0, TAU); x.fill()
		return
	var k = 0.5 + 0.5 * sin(t * 10)
	x.fillStyle = mixc("#5a0a10", "#ff2a3a", k); x.beginPath(); x.ellipse(X, Y, 7, 5, 0, 0, TAU); x.fill()
	# a beam sweeping round
	var a = t * 5
	var g = x.createRadialGradient(X, Y, 2, X, Y, 90)
	g.addColorStop(0, rgba(255, 40, 58, 0.45)); g.addColorStop(1, rgba(255, 40, 58, 0))
	x.fillStyle = g
	x.beginPath(); x.moveTo(X, Y)
	x.lineTo(X + cos(a - 0.25) * 90, Y + absf(sin(a - 0.25)) * 90); x.lineTo(X + cos(a + 0.25) * 90, Y + absf(sin(a + 0.25)) * 90); x.closePath(); x.fill()


func _viewWindow(x: Ctx, X: float, Y: float, t: float) -> void:
	# scientists behind the glass, watching the test; their goggles glint
	for i in 3:
		var wx = X - 26 + i * 24 + sin(t * 0.4 + i) * 3
		x.fillStyle = "#0a1018"
		x.fillRect(roundf(wx - 4), roundf(Y - 4), 9, 14)
		x.fillRect(roundf(wx - 3), roundf(Y - 9), 6, 6)
		x.fillStyle = "#3af0c8" if fmod(t + i * 1.3, 3.0) < 2.6 else "#0a1018"
		x.fillRect(roundf(wx - 1), roundf(Y - 7), 4, 1)
	x.fillStyle = rgba(160, 220, 255, 0.08); x.fillRect(X - 43, Y - 13, 86, 26)


## the Containment Bay's way on: two steel slabs until the Mk II is scrap
func _blastDoor(x: Ctx, X: float, Y: float, open: bool) -> void:
	if open:
		x.fillStyle = "#060508"; x.fillRect(X - 23, Y - 69, 46, 69)
		x.fillStyle = "#3af07a"; x.fillRect(X - 3, Y - 74, 6, 2)
		return
	x.fillStyle = "#3a3e4a"; x.fillRect(X - 23, Y - 69, 23, 69)
	x.fillStyle = "#30333e"; x.fillRect(X, Y - 69, 23, 69)
	x.fillStyle = "#14161c"; x.fillRect(X - 1, Y - 69, 2, 69)
	for k in 5:
		x.fillStyle = "#4a4e5a"; x.fillRect(X - 21, Y - 62 + k * 13, 42, 1)
	x.fillStyle = "#ff2a3a" if fmod(realTime, 1.0) < 0.5 else "#5a0a10"
	x.fillRect(X - 3, Y - 74, 6, 2)


func _cellEyes(x: Ctx, X: float, Y: float, t: float, seed: float) -> void:
	if X < -50 or X > VW + 50:
		return
	# whatever is in there drifts about in the dark, blinks, and follows you with its eyes
	var n = 1 + int(hsh(seed * 1.7) * 2)
	for i in n:
		var s = seed + i * 13.7
		var big = hsh(s * 2.3) > 0.6
		var ex = X + (hsh(s) - 0.5) * 40 + sin(t * 0.3 + s) * 6
		var ey = Y + 6 + hsh(s * 3.1) * 26 + sin(t * 0.5 + s) * 2
		var blink = fmod(t * 0.7 + hsh(s) * 9, 4.0) < 0.12
		var hidden = fmod(t * 0.13 + hsh(s * 5) * 9, 9.0) < 2.0   # it backs away into the dark sometimes
		if blink or hidden:
			continue
		var look = clampf((P.x - cam.x - ex) / 120.0, -1, 1)
		var sep = 6.0 if big else 4.0
		var gl = x.createRadialGradient(ex, ey, 1, ex, ey, 12 if big else 8)
		gl.addColorStop(0, rgba(255, 40, 40, 0.4)); gl.addColorStop(1, rgba(255, 40, 40, 0))
		x.fillStyle = gl; x.beginPath(); x.arc(ex, ey, 12 if big else 8, 0, TAU); x.fill()
		for k in [-1, 1]:
			x.fillStyle = "#ff3a2a"
			x.fillRect(roundf(ex + k * sep / 2 - 1), roundf(ey), 3 if big else 2, 2 if big else 1)
			x.fillStyle = "#1a0000"
			x.fillRect(roundf(ex + k * sep / 2 + look), roundf(ey), 1, 1)


func _dial(x: Ctx, X: float, Y: float, t: float) -> void:
	var a = -PI * 0.75 + (0.5 + 0.5 * sin(t * 0.7)) * PI * 1.5 + sin(t * 23) * 0.03
	x.strokeStyle = "#5a1a5a"; x.lineWidth = 2
	x.beginPath(); x.arc(X, Y, 18, PI * 0.75, PI * 2.25); x.stroke()
	x.strokeStyle = "#ff4ad8"; x.lineWidth = 1.4
	x.beginPath(); x.moveTo(X, Y); x.lineTo(X + cos(a - PI / 2) * 16, Y + sin(a - PI / 2) * 16); x.stroke()
	x.fillStyle = "#ff4ad8"; x.beginPath(); x.arc(X, Y, 2, 0, TAU); x.fill()


func _tank(x: Ctx, X: float, Y: float, w: float, h: float, t: float) -> void:
	# glowing liquid: the power the machine has drawn out of its prisoners
	var lvl = 0.55 + 0.1 * sin(t * 0.6 + X)
	var top = Y + h * (1 - lvl)
	var g = x.createLinearGradient(0, top, 0, Y + h)
	g.addColorStop(0, rgba(255, 74, 216, 0.75)); g.addColorStop(1, rgba(90, 16, 72, 0.9))
	x.fillStyle = g
	x.fillRect(X - w / 2 + 3, top, w - 6, Y + h - top)
	x.fillStyle = rgba(255, 200, 250, 0.8); x.fillRect(X - w / 2 + 3, top, w - 6, 1)
	for i in 4:
		var by = Y + h - fmod(t * 20 + i * 17 + X, h * lvl)
		x.fillStyle = rgba(255, 220, 250, 0.7)
		x.fillRect(roundf(X - w / 4 + hsh(i + X) * w / 2), roundf(by), 1, 1)


# ================================================================ the security monsters

func _climbKey(e) -> Array:
	if not (e.type in VOLCANO_MOBS):
		return super._climbKey(e)
	var tt: float = e.t
	var D: Dictionary = e.data
	if e.state == "dead":
		return ["dead", 0]
	if e.flash > 0:
		return ["white", 0]
	if e.state == "hurt":
		return ["hurt", int(tt * 12) % 2]
	match e.type:
		"sentinel":
			if e.state == "wind":
				return ["charge", int(tt * 10) % 2]
			if e.state == "act":
				return ["slam", 0]
			return ["idle", int(tt * 3 + e.id) % 4]
		"secgolem", "sentgolem":
			if e.state == "wind":
				if e.move == "dash":
					return ["dash", int(tt * 14) % 2]
				if e.move == "laser":
					return ["laser", 0]
				return ["wind", 0]
			if e.state == "act":
				return ["dash", int(tt * 14) % 2] if e.move == "dash" else ["punch", 0]
			if D.get("flash", 0.0) > 0:
				return ["fire", int(D.get("which", 0))]
			if absf(e.vx) > 3:
				return ["walk", int(tt * 5) % 4]
			return ["idle", int(tt * 1.5) % 2]
		"dog":
			if e.state == "pin":
				return ["pin", int(tt * 8) % 2]
			if e.state == "wind" and e.move == "pounce":
				return ["idle", 1]
			if e.state == "act" and e.move == "pounce":
				return ["pounce", 0]
			if e.state == "act" or (e.state == "wind" and e.move == "bite"):
				return ["pin", 1 if e.state == "act" else 0]
			if absf(e.vx) > 5:
				return ["run", int(tt * 12) % 4]
			return ["idle", int(tt * 2) % 2]
		"ferro":
			if e.state == "wind" and e.move == "spark" or e.state == "act":
				return ["spark", int(tt * 12) % 2]
			if D.get("hot", 0.0) > 0 or (e.state == "wind" and e.move == "heat" and int(tt * 8) % 2 == 0):
				return ["hot", int(tt * 6) % 2]
			if not _grounded(e):
				return ["hop", 1 if e.vy < 0 else 0]
			return ["idle", int(tt * 3) % 2]
	return ["idle", 0]


func drawAbyssMob(x: Ctx, e, sx: float, sy: float) -> void:
	super.drawAbyssMob(x, e, sx, sy)
	if not (e.type in VOLCANO_MOBS) or e.state == "dead":
		return
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	if X < -140 or X > VW + 140:
		return
	var D: Dictionary = e.data
	var sc: float = D.get("scale", 1.0) if e.elite else 1.0
	match e.type:
		"secgolem", "sentgolem":
			# the eyes glow red
			var ex = X + e.face * (5 if e.type == "secgolem" else 4) * sc
			var ey = Y - (84 if e.type == "secgolem" else 84) * sc
			var g = x.createRadialGradient(ex, ey, 1, ex, ey, 12 * sc)
			g.addColorStop(0, rgba(255, 40, 58, 0.55)); g.addColorStop(1, rgba(255, 40, 58, 0))
			x.fillStyle = g; x.beginPath(); x.arc(ex, ey, 12 * sc, 0, TAU); x.fill()
			# the mana core pulses
			var cy = Y - 59 * sc
			var a = 0.25 + 0.15 * sin(realTime * 4 + e.id)
			var cg = x.createRadialGradient(X, cy, 1, X, cy, 16 * sc)
			var cc = css("#ff2a3a") if e.type == "sentgolem" else css("#d04aff")
			cg.addColorStop(0, Color(cc, a)); cg.addColorStop(1, Color(cc, 0))
			x.fillStyle = cg; x.beginPath(); x.arc(X, cy, 16 * sc, 0, TAU); x.fill()
		"sentinel":
			# its red eye scans: a faint cone of light sweeping the floor
			if e.state in ["idle", "chase"]:
				var a = PI / 2 + sin(realTime * 2.2 + e.id) * 0.5
				var ox = X + e.face * 3
				var oy = Y - 15
				x.fillStyle = rgba(255, 40, 58, 0.08)
				x.beginPath(); x.moveTo(ox, oy); x.lineTo(ox + cos(a - 0.18) * 70, oy + sin(a - 0.18) * 70); x.lineTo(ox + cos(a + 0.18) * 70, oy + sin(a + 0.18) * 70); x.closePath(); x.fill()
	# aiming lines while a laser charges
	if e.state == "wind" and e.move == "laser" and D.has("aim"):
		var o = Vector2(e.x + e.face * 5, e.y - e.h / 2) if e.type == "sentinel" else Vector2(e.x + e.face * 8, e.y - 96)
		var dir = (D.aim - o).normalized()
		var k = minf(1, e.t / 0.6)
		x.strokeStyle = rgba(255, 40, 58, 0.25 + 0.5 * k * absf(sin(e.t * 30)))
		x.lineWidth = 0.7
		x.beginPath(); x.moveTo(o.x - sx, o.y - sy); x.lineTo(o.x - sx + dir.x * 300, o.y - sy + dir.y * 300); x.stroke()


# ================================================================ in front of everyone

func drawClimbFront(x: Ctx, sx: float, sy: float, dt: float) -> void:
	super.drawClimbFront(x, sx, sy, dt)
	drawVolcanoFront(x, sx, sy)


func drawVolcanoFront(x: Ctx, sx: float, sy: float) -> void:
	for s in volcShots:
		var X = s.x - sx
		var Y = s.y - sy
		match s.kind:
			"beam":
				var k = 1 - s.t / s.life
				var bx = X + s.dx * s.len
				var by = Y + s.dy * s.len
				var c = css(s.get("col", "#ff2a3a"))
				x.strokeStyle = Color(c, 0.45 * k); x.lineWidth = s.w * 2.4
				x.beginPath(); x.moveTo(X, Y); x.lineTo(bx, by); x.stroke()
				x.strokeStyle = Color(c, 0.9 * k); x.lineWidth = s.w
				x.beginPath(); x.moveTo(X, Y); x.lineTo(bx, by); x.stroke()
				x.strokeStyle = rgba(255, 255, 255, k); x.lineWidth = maxf(0.6, s.w * 0.35)
				x.beginPath(); x.moveTo(X, Y); x.lineTo(bx, by); x.stroke()
			"round":
				x.strokeStyle = "#ffe07a"; x.lineWidth = 1
				x.beginPath(); x.moveTo(X, Y); x.lineTo(X - s.vx * 0.012, Y - s.vy * 0.012); x.stroke()
			"ring":
				var r: float = s.r * minf(1, s.t / 0.18)
				var k = 1 - s.t / 0.35
				x.strokeStyle = rgba(122, 240, 255, 0.8 * k); x.lineWidth = 2
				x.beginPath(); x.ellipse(X, Y, r, r * 0.6, 0, 0, TAU); x.stroke()
				for i in 8:
					var a = i / 8.0 * TAU + s.t * 9
					x.fillStyle = "#ffffff" if i % 2 else "#7af0ff"
					x.fillRect(roundf(X + cos(a) * r), roundf(Y + sin(a) * r * 0.6), 2, 2)
	drawMk2Front(x, sx, sy)


# ================================================================ light

func climbTint(x: Ctx, D: Dictionary) -> void:
	if not volcanoMap():
		super.climbTint(x, D)
		return
	x.fillStyle = css("#f0dce8")
	x.fillRect(0, 0, VW, VH)


func climbOverlay(x: Ctx) -> void:
	super.climbOverlay(x)
	if not volcanoMap():
		return
	var sx = cam.x
	var sy = cam.y
	var t = realTime
	for g in vGlows(mapId):
		var X: float = g[0] - sx
		var Y: float = g[1] - sy
		if X < -60 or X > VW + 60 or Y < -60 or Y > VH + 60:
			continue
		var c = css(g[3])
		var a = 0.22 * (0.75 + 0.25 * sin(t * 1.7 + g[0] * 0.13))
		var gr = x.createRadialGradient(X, Y, 0, X, Y, g[2] * 1.3)
		gr.addColorStop(0, Color(c, a)); gr.addColorStop(1, Color(c, 0))
		x.fillStyle = gr
		x.beginPath(); x.arc(X, Y, g[2] * 1.3, 0, TAU); x.fill()
	# the Containment Bay's alarm: the whole room pulses red while the Mk II is up
	if _alarmOn():
		x.fillStyle = rgba(255, 20, 40, 0.1 + 0.08 * sin(t * 10))
		x.fillRect(0, 0, VW, VH)
	# the Cell Block's security lights: strobing, sweeping, never still
	for l in vSpots().get("light", []):
		var X: float = l[0] - sx
		var Y: float = l[1] - sy
		if X < -120 or X > VW + 120:
			continue
		var ph = hsh(l[0]) * 10
		var on = fmod(t * (3 + hsh(l[0] * 2) * 4) + ph, 1.0) < 0.55
		var col = Color8(255, 40, 40) if fmod(t * 0.5 + ph, 2.0) < 1.2 else Color8(255, 160, 40)
		var a = t * 2.4 + ph
		if on:
			var g = x.createRadialGradient(X, Y, 1, X, Y, 140)
			g.addColorStop(0, Color(col, 0.35)); g.addColorStop(1, Color(col, 0))
			x.fillStyle = g
			x.beginPath(); x.moveTo(X, Y)
			x.lineTo(X + sin(a) * 120 - 30, Y + 200); x.lineTo(X + sin(a) * 120 + 30, Y + 200); x.closePath(); x.fill()
			x.fillStyle = Color(col, 0.9); x.fillRect(X - 3, Y - 1, 6, 3)
		else:
			x.fillStyle = "#3a1010"; x.fillRect(X - 3, Y - 1, 6, 3)


# forward declaration: the sanctum's pods and piano (glamrax_draw.gd)
func drawSanctumMid(_x: Ctx, _sx: float, _sy: float) -> void: pass
