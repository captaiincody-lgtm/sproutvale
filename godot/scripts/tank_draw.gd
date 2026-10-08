extends "res://scripts/intro.gd"
## Sproutvale, part 8b: drawing Tank. His bullets, grenades, missiles and explosions, the drone,
## turrets and the robot, weak-point markers, components on the ground, the box, the meteor and his
## house on the home field, and the scenes of his story (out of the Dreamer's dream, to the shore,
## and Glamrax watching from the volcano).

var _tankMeta := {}


func tankArt(k: String) -> Dictionary:
	if _tankMeta.is_empty() and FileAccess.file_exists("res://art/tank/tank.json"):
		_tankMeta = Assets._json("res://art/tank/tank.json")
	return _tankMeta.get(k, {"frames": 1, "w": 10, "h": 10})


## one tank sprite, centred on X and standing on Y (or centred on both when `mid`)
func tankSprite(x: Ctx, k: String, f: int, X: float, Y: float, face := 1, mid := false, sc := 1.0) -> void:
	var tex = Assets.tex("tank/%s.png" % k)
	if tex == null:
		return
	var A = tankArt(k)
	var w: float = A.w * sc
	var h: float = A.h * sc
	x.save()
	x.translate(roundf(X), roundf(Y))
	if face < 0:
		x.scale(-1, 1)
	x.drawFrame(tex, int(A.frames), posmod(f, int(A.frames)), -w / 2, -h / 2 if mid else -h, w, h)
	x.restore()


# ================================================================ in the world

func drawTankBack(x: Ctx, sx: float, sy: float) -> void:
	var tt = realTime
	if mapId == "home" and M.get("variant") == "tank":
		var bx = 560.0 - sx
		var fy = M.floorY - sy
		var Mt = TK.meteor
		var hit = meteorDone() or (Mt != null and Mt.hit)
		if houseBuilt():
			tankSprite(x, "house", 0, bx, fy + 2)
		elif hit:
			tankSprite(x, "box_wreck", 0, bx, fy + 3)
			if Mt != null and Mt.t < 8:
				for i in 3:
					var k = fmod(tt * 0.4 + i / 3.0, 1.0)
					x.fillStyle = rgba(80, 70, 70, 0.4 * (1 - k))
					x.beginPath(); x.arc(bx + sin(i * 2.0 + tt) * 4, fy - 10 - k * 40, 4 + k * 10, 0, TAU); x.fill()
		else:
			tankSprite(x, "box", 0, bx, fy + 1)
			if absf(P.x - 560) < 120 and not meteorDone():
				x.font = F6; x.textAlign = "center"
				textOutline(x, "A cardboard box...", roundf(bx), roundf(fy - 34), "#ffffff")
	for f in tfx:
		if f.type == "fire":
			var a = minf(1, (f.life - f.t) / 0.5)
			x.globalAlpha = a
			var n = maxi(1, int(f.w / 20))
			for i in n:
				var X = f.x - f.w / 2 + (i + 0.5) * f.w / n - sx
				tankSprite(x, "napalm", int(tt * 10 + i), X, f.y - sy + 1)
			x.globalAlpha = 1
	for T2 in TK.turrets:
		_drawTurret(x, T2, T2.x - sx, T2.y - sy)
	var B2 = TK.bot
	if B2 != null:
		var anim: String = B2.anim
		var k = "bot_%d_%s" % [botTier(), anim]
		var fr = int(B2.t * (12 if anim == "attack" else 8))
		if anim == "attack":
			fr = clampi(int((0.35 - B2.at) / 0.35 * 4), 0, 3)
		tankSprite(x, k, fr, B2.x - sx, B2.y - sy + 1, B2.face)


func _drawTurret(x: Ctx, T2: Dictionary, X: float, Y: float) -> void:
	var a = minf(1, (T2.life - T2.t) / 0.4)
	x.globalAlpha = a
	x.strokeStyle = "#3a3f4a"; x.lineWidth = 1.5
	x.beginPath(); x.moveTo(X - 6, Y); x.lineTo(X, Y - 8); x.lineTo(X + 6, Y); x.moveTo(X, Y); x.lineTo(X, Y - 8); x.stroke()
	x.fillStyle = "#5a6474"; x.fillRect(X - 6, Y - 15, 12, 7)
	x.fillStyle = "#8a96a8"; x.fillRect(X - 6, Y - 15, 12, 2)
	var f: int = T2.get("face", 1)
	x.fillStyle = "#2a2e36"; x.fillRect(X + (5 if f > 0 else -11), Y - 13, 6, 2)
	x.fillStyle = "#ff3a3a" if int(realTime * 4) % 2 else "#6a1a1a"; x.fillRect(X - 1, Y - 14, 2, 2)
	if T2.get("flash", 0.0) > 0:
		x.fillStyle = "#fff3b0"; x.fillRect(X + (11 if f > 0 else -14), Y - 14, 3, 3)
	x.globalAlpha = 1


func drawTankFront(x: Ctx, sx: float, sy: float) -> void:
	var tt = realTime
	# the falling meteor and the red scan
	var Mt = TK.meteor
	if Mt != null and mapId == "home":
		if not Mt.hit:
			var k = clampf(Mt.t / 1.5, 0, 1)
			var mx = lerpf(560 + 220, 560, k) - sx
			var my = lerpf(cam.y - 40, M.floorY - 10, k) - sy
			for i in 10:
				var q = i / 10.0
				x.fillStyle = rgba(255, 140 - i * 10, 40, 0.5 * (1 - q))
				x.beginPath(); x.arc(mx + q * 60, my - q * 40 * (1 - k * 0.3), 8 - i * 0.6, 0, TAU); x.fill()
			tankSprite(x, "meteor", int(tt * 12), mx, my, 1, true, 0.8 + k * 0.6)
		elif Mt.scan and Mt.t < 6.4:
			var hx = heroHead.x - sx + P.face * 2
			var hy = heroHead.y - sy
			var sweep = sin((Mt.t - 2.6) * 2.4) * 10
			x.fillStyle = rgba(255, 40, 40, 0.18 + 0.06 * sin(tt * 20))
			x.beginPath(); x.moveTo(hx, hy); x.lineTo(560 - sx - 30 + sweep, M.floorY - sy); x.lineTo(560 - sx + 30 + sweep, M.floorY - sy); x.closePath(); x.fill()
			x.fillStyle = rgba(255, 90, 90, 0.9)
			x.fillRect(560 - sx - 30 + sweep, M.floorY - sy - 1 - fmod(Mt.t * 30, 10.0), 60, 1)
			x.fillStyle = "#ff2a2a"; x.fillRect(hx - 1, hy - 1, 2, 2)
	if not isTank():
		return
	# weak points, through the Diagnostic Helmet
	for e in TK.weak:
		var w = TK.weak[e]
		if w.cd > 0 or e.state == "dead":
			continue
		var X = roundf(e.x + w.ox * e.w - sx)
		var Y = roundf(e.y - e.h * w.oy - sy)
		var p = 1 + 0.25 * sin(tt * 10)
		x.strokeStyle = rgba(255, 50, 50, 0.95); x.lineWidth = 1
		x.beginPath(); x.arc(X, Y, 3.5 * p, 0, TAU); x.stroke()
		x.fillStyle = "#ff3a3a"
		x.fillRect(X - 6 * p, Y, 2, 1); x.fillRect(X + 4 * p, Y, 2, 1); x.fillRect(X, Y - 6 * p, 1, 2); x.fillRect(X, Y + 4 * p, 1, 2)
		x.fillRect(X, Y, 1, 1)
	# thruster flames while gliding or flying
	if TK.glide or TK.fly or (TK.slam and P.state == "dash"):
		var fx0 = P.x - sx
		var fy0 = P.y - sy
		for i in 2:
			var ox = (-3 + i * 6) if not TK.slam else -P.face * 8
			var len = (6 if TK.glide else 10) + sin(tt * 40 + i) * 2
			x.fillStyle = rgba(255, 176, 58, 0.85)
			if TK.slam:
				x.fillRect(fx0 + ox - (len if P.face > 0 else 0), fy0 - 22 + i * 4, len, 2)
			else:
				x.fillRect(fx0 + ox - 1, fy0, 2, len)
				x.fillStyle = rgba(255, 243, 176, 0.9); x.fillRect(fx0 + ox - 0.5, fy0, 1, len * 0.5)
	# projectiles
	for a in tshots:
		var X = a.x - sx
		var Y = a.y - sy
		var ang = atan2(a.vy, a.vx)
		match a.kind:
			"bullet", "dbullet", "shard":
				x.save(); x.translate(X, Y); x.rotate(ang)
				x.fillStyle = rgba(255, 230, 140, 0.5); x.fillRect(-7, -0.5, 6, 1)
				if a.kind == "bullet":
					x.drawImage(Assets.tex("tank/bullet.png"), -2, -1, 4, 2)
				else:
					x.fillStyle = "#bfe8ff" if a.kind == "dbullet" else "#d8d8d8"; x.fillRect(-1.5, -0.5, 3, 1)
				x.restore()
			"energy":
				x.save(); x.translate(X, Y); x.rotate(ang)
				x.drawFrame(Assets.tex("tank/energy_bolt.png"), 3, int(tt * 18) % 3, -5, -3, 10, 6)
				x.restore()
			"missile":
				x.save(); x.translate(X, Y); x.rotate(ang)
				if a.small:
					x.drawImage(Assets.tex("tank/missile.png"), -5, -2, 10, 4)
				else:
					x.drawImage(Assets.tex("tank/missile.png"), -7, -3, 14, 6)
				x.fillStyle = rgba(255, 200, 80, 0.8 + 0.2 * sin(tt * 40)); x.fillRect(-10, -1, 3, 2)
				x.restore()
			"shell":
				x.fillStyle = "#3a3f4a"; x.fillRect(X - 2, Y - 2, 4, 4)
				x.fillStyle = "#ffb03a"; x.fillRect(X - 1, Y - 1, 2, 2)
			_:
				x.save(); x.translate(X, Y); x.rotate(a.spin)
				x.drawImage(Assets.tex("tank/nade_%s.png" % a.nt), -3.5 if a.small else -4.5, -3.5 if a.small else -4.5, 7 if a.small else 9, 7 if a.small else 9)
				x.restore()
				if a.t > a.life - 0.3 and int(tt * 20) % 2 == 0:
					x.fillStyle = "#ff3a3a"; x.fillRect(X - 1, Y - 6, 2, 2)
	# blasts, beams, zaps and fly-bys
	for f in tfx:
		var k: float = f.t / f.life
		match f.type:
			"boom":
				var big = f.r / 20.0
				var nm = "energy_burst" if f.nt in ["energy", "emp", "cryo"] else "explosion"
				var n = 6 if nm == "energy_burst" else 7
				var col = Color.WHITE
				if f.nt == "cryo":
					col = Color("#c8f4ff")
				elif f.nt == "emp":
					col = Color("#fff36a")
				var tex = Assets.tex("tank/%s.png" % nm)
				var s = 40 * big
				x.drawFrame(tex, n, int(k * n), f.x - sx - s / 2, f.y - sy - s / 2, s, s, col)
			"flash":
				x.fillStyle = "#9fe6ff" if f.energy else "#fff3b0"
				x.beginPath(); x.arc(f.x - sx, f.y - sy, 3 - k * 2, 0, TAU); x.fill()
			"zap":
				x.strokeStyle = rgba(190, 235, 255, 1 - k); x.lineWidth = 1
				x.beginPath(); x.moveTo(f.x - sx, f.y - sy)
				for i in range(1, 6):
					var q = i / 6.0
					x.lineTo(lerpf(f.x, f.x2, q) - sx + (hsh(f.seed + i + floorf(f.t * 30)) - 0.5) * 8, lerpf(f.y, f.y2, q) - sy + (hsh(f.seed + i * 3 + floorf(f.t * 30)) - 0.5) * 8)
				x.lineTo(f.x2 - sx, f.y2 - sy); x.stroke()
			"laser":
				var w = 10 * (1 - k) + 2
				var X = f.x - sx
				x.fillStyle = rgba(255, 80, 120, 0.35 * (1 - k)); x.fillRect(X - w, 0, w * 2, f.y - sy)
				x.fillStyle = rgba(255, 220, 240, 0.9 * (1 - k)); x.fillRect(X - w * 0.3, 0, w * 0.6, f.y - sy)
				x.fillStyle = rgba(255, 255, 255, 0.8 * (1 - k)); x.beginPath(); x.ellipse(X, f.y - sy, w * 1.6, 3, 0, 0, TAU); x.fill()
			"strafer":
				for i in f.n:
					var X = f.x - sx - sgn(f.vx) * i * 22
					var Y = f.y - sy + i * 9 + sin(tt * 8 + i) * 2
					tankSprite(x, "drone_%d" % (2 if f.napalm else 1), int(tt * 16 + i), X, Y, int(sgn(f.vx)), true, 1.1)
	# the drone (and its wingmen under Swarm Protocol)
	var tier = droneTier()
	if tier > 0:
		var D2 = TK.drone
		tankSprite(x, "drone_%d" % (tier - 1), int(tt * 16), D2.x - sx, D2.y - sy, P.face, true)
		if buffOn("swarmProtocol"):
			for i in 2:
				var a = tt * 2 + i * PI
				tankSprite(x, "drone_%d" % (tier - 1), int(tt * 16 + i), D2.x - sx + cos(a) * 18, D2.y - sy + sin(a) * 6 - 4, P.face, true, 0.75)
		if D2.flash > 0:
			x.fillStyle = "#fff3b0"; x.fillRect(D2.x - sx + P.face * 8 - 1, D2.y - sy, 3, 2)
	if buffOn("titanProtocol"):
		x.strokeStyle = rgba(179, 136, 255, 0.4 + 0.2 * sin(tt * 6)); x.lineWidth = 1
		x.beginPath(); x.ellipse(P.x - sx, P.y - sy - 24, 20, 30, 0, 0, TAU); x.stroke()


func drawPartDrop(x: Ctx, d, X: float, Y: float, tt: float) -> void:
	var gl = 0.5 + 0.5 * sin(tt * 5 + d.x)
	var col = css(PART_INFO.get(d.type, PART_INFO.scrap).col)
	x.fillStyle = Color(col, 0.25 * gl)
	x.fillRect(X - 6, Y - 11, 12, 12)
	x.drawImage(Assets.tex("tank/part_%s.png" % d.type), X - 4.5, Y - 10 + (roundf(sin(tt * 4 + d.spin)) if d.vy == 0 else 0.0), 9, 9)


# ================================================================ cutscenes

func tankCutscene(scenes: Array, done: Callable) -> void:
	intro = {"cls": "tank", "kin": "dream", "scenes": scenes, "i": 0, "shown": 0, "t": 0.0, "done": done, "fallen": null, "run": null,
		"btn": "Begin" if scenes.size() == 1 and scenes[0].title else "Next"}
	Sfx.music("hollow")
	Sfx.tone(110, 2, "sine", 0.08, 70)


func _tankFrame(x: Ctx, anim: String, f: int, X: float, Y: float, k: float, face := 1, stage := 0) -> void:
	var look = "tank_m_%d" % stage
	var A = Assets.hero_anim(look, anim)
	var tex = Assets.hero_strip(look, anim, 1)
	if tex == null:
		return
	x.save(); x.translate(X, Y)
	if face < 0:
		x.scale(-1, 1)
	x.drawFrame(tex, int(A.frames), posmod(f, int(A.frames)), -RX * k, -GROUND * k, SW * k, SH * k)
	x.restore()


func drawTankScene(x: Ctx, t: float, kind: String) -> void:
	match kind:
		"t_fall": _sceneFall(x, t)
		"t_escape": _sceneEscape(x, t)
		"t_surface": _sceneSurface(x, t)
		"t_shore": _sceneShore(x, t)
		"t_glamrax": _sceneGlamrax(x, t)


## the Dreamer sinks through the black water, its eye going dark, and one small red light wakes inside it
func _sceneFall(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#0a0a1e"); g.addColorStop(1, "#02020a"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 50:
		var k = fmod(_irnd(i) + t * 0.05 * (0.5 + _irnd(i + 7)), 1.0)
		x.fillStyle = rgba(160, 140, 220, 0.3); x.fillRect(_irnd(i + 3) * SW2, SH2 - k * SH2, 1, 1)
	var sink = minf(t * 5, 22)
	var cx = 192.0
	var cy = 110.0 + sink
	x.fillStyle = "#1a0f2e"; x.beginPath(); x.ellipse(cx, cy + 40, 150, 110, 0, PI, TAU); x.fill()
	x.fillStyle = "#24163e"; x.beginPath(); x.ellipse(cx, cy + 40, 130, 92, 0, PI, TAU); x.fill()
	for i in 6:
		x.strokeStyle = "#1a0f2e"; x.lineWidth = 7 - i
		x.beginPath(); x.moveTo(cx - 120 + i * 48, cy + 40)
		x.quadraticCurveTo(cx - 130 + i * 48 + sin(t + i) * 14, cy + 90, cx - 110 + i * 48, SH2 + 10); x.stroke()
	var open = maxf(0, 1 - t / 3.0)
	x.fillStyle = "#06030c"; x.beginPath(); x.ellipse(cx, cy, 38, 20, 0, 0, TAU); x.fill()
	if open > 0:
		x.fillStyle = rgba(255, 210, 120, open); x.beginPath(); x.ellipse(cx, cy, 30, 16 * open, 0, 0, TAU); x.fill()
		x.fillStyle = rgba(30, 10, 10, open); x.beginPath(); x.ellipse(cx, cy, 6, 12 * open, 0, 0, TAU); x.fill()
	if t > 2.4:
		var a = minf(1, (t - 2.4) / 1.2) * (0.75 + 0.25 * sin(t * 5))
		x.fillStyle = rgba(255, 40, 40, a * 0.3); x.beginPath(); x.arc(cx, cy, 10, 0, TAU); x.fill()
		x.fillStyle = rgba(255, 60, 60, a); x.beginPath(); x.arc(cx, cy, 2.5, 0, TAU); x.fill()


## running through the collapsing dream toward a tear of white light
func _sceneEscape(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, SW2, 0); g.addColorStop(0, "#1a0628"); g.addColorStop(1, "#4a1a6a"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 7:
		var r = fmod(i * 40 + t * 60, 280.0)
		x.strokeStyle = rgba(255, 120, 230, 0.25 * (1 - r / 280)); x.lineWidth = 2
		x.beginPath(); x.ellipse(330, 100, r, r * 0.6, 0, 0, TAU); x.stroke()
	for i in 24:
		var X = fposmod(_irnd(i) * 500 - t * (80 + _irnd(i + 2) * 120), 500.0) - 60
		x.fillStyle = rgba(120 + i * 4, 60, 160, 0.6); x.fillRect(X, 30 + _irnd(i + 9) * 150, 30 + _irnd(i + 4) * 40, 2)
	# pieces of the dream fall away
	for i in 10:
		var k = fmod(t * 0.4 + _irnd(i + 20), 1.0)
		_ipoly(x, [[40 + i * 34, k * 240 - 20], [52 + i * 34, k * 240 - 14], [44 + i * 34, k * 240 - 4]], rgba(200, 160, 255, 0.5))
	var tear = minf(1, t / 4.0)
	x.fillStyle = rgba(255, 255, 255, 0.25 * tear); x.beginPath(); x.ellipse(330, 100, 30 + tear * 30, 70 * tear + 5, 0, 0, TAU); x.fill()
	x.fillStyle = rgba(255, 255, 255, 0.9 * tear); x.beginPath(); x.ellipse(330, 100, 6 + tear * 10, 50 * tear + 3, 0, 0, TAU); x.fill()
	x.fillStyle = "#2a0a3a"; x.fillRect(0, 140, SW2, 76)
	x.fillStyle = "#6a2a8a"; x.fillRect(0, 140, SW2, 2)
	var hx = 90 + minf(t * 25, 120)
	_tankFrame(x, "run", int(t * 16), hx, 140, 1.0)


## surfacing in the black sea, the shore a thin line in the distance
func _sceneSurface(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#06081a"); g.addColorStop(0.55, "#1a2040"); g.addColorStop(1, "#0a1020"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 60:
		x.fillStyle = rgba(255, 255, 255, 0.2 + 0.6 * absf(sin(t + i))); x.fillRect(_irnd(i + 1) * SW2, _irnd(i + 40) * 100, 1, 1)
	x.fillStyle = "#e8e8ff"; x.beginPath(); x.arc(70, 40, 12, 0, TAU); x.fill()
	x.fillStyle = "#1a2a2a"; x.fillRect(250, 116, 140, 3)   # the far shore
	x.fillStyle = "#2a3a30"; x.fillRect(270, 112, 120, 4)
	x.fillStyle = "#0c1830"; x.fillRect(0, 120, SW2, 96)
	for i in 9:
		x.fillStyle = rgba(120, 150, 220, 0.25)
		x.fillRect(fposmod(i * 50 + sin(t + i) * 10, SW2), 124 + i * 9, 30, 1)
	x.fillStyle = rgba(230, 230, 255, 0.35); x.fillRect(50, 124, 40, 1)
	var rise = minf(1, t / 1.6)
	var hx = 140 + maxf(0, t - 1.6) * 14
	var hy = 166 - rise * 12
	_tankFrame(x, "swim", int(t * 9), hx, hy, 0.95)
	x.fillStyle = "#0c1830"; x.fillRect(0, 142, SW2, 74)
	for i in 5:
		var k = fmod(t * 1.3 + i * 0.2, 1.0)
		x.strokeStyle = rgba(200, 220, 255, 0.5 * (1 - k)); x.lineWidth = 1
		x.beginPath(); x.ellipse(hx, 140, 6 + k * 20, 1 + k * 2, 0, 0, TAU); x.stroke()


## walking up out of the surf at dawn: an empty field, and a cardboard box
func _sceneShore(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#5a6aa8"); g.addColorStop(0.6, "#f0a080"); g.addColorStop(1, "#ffd0a0"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	x.fillStyle = "#ffe8b0"; x.beginPath(); x.arc(300, 112, 22, 0, TAU); x.fill()
	x.fillStyle = "#3a5a8a"; x.fillRect(0, 112, 150, 104)
	for i in 6:
		x.fillStyle = rgba(255, 255, 255, 0.4); x.fillRect(fposmod(i * 30 + t * 10, 150.0), 118 + i * 9, 14, 1)
	x.fillStyle = "#e8d098"; x.beginPath(); x.moveTo(100, SH2); x.lineTo(150, 130); x.lineTo(SW2, 130); x.lineTo(SW2, SH2); x.closePath(); x.fill()
	x.fillStyle = "#5aa040"; x.fillRect(190, 128, SW2 - 190, 88); x.fillStyle = "#7fd35a"; x.fillRect(190, 128, SW2 - 190, 2)
	tankSprite(x, "box", 0, 320, 130)
	var hx = 100 + minf(t * 22, 110)
	var hy = 130.0 if hx > 140 else 140 - (hx - 100) / 4.0
	_tankFrame(x, "walk", int(t * 10), hx, hy, 0.95)
	if hx < 150:
		x.fillStyle = "#3a5a8a"; x.fillRect(hx - 20, 138, 40, 40)


## Glamrax, displeased, watching the wreck in his scrying glass
func _sceneGlamrax(x: Ctx, t: float) -> void:
	drawCaptiveScene(x, t, "none")
	x.fillStyle = rgba(120, 10, 30, 0.25 + 0.05 * sin(t * 3)); x.fillRect(0, 0, SW2, SH2)
	# the scrying glass, held up beside him, showing the wreck in the field and Tank standing in it
	var ox = 78.0
	var oy = 92.0
	var R = 40.0
	x.strokeStyle = "#5a2a6a"; x.lineWidth = 3; x.beginPath(); x.moveTo(ox, oy + R); x.lineTo(ox + 4, oy + R + 40); x.stroke()
	x.fillStyle = rgba(255, 58, 216, 0.25 + 0.1 * sin(t * 3)); x.beginPath(); x.arc(ox, oy, R + 6, 0, TAU); x.fill()
	x.fillStyle = "#8ac8ff"; x.beginPath(); x.arc(ox, oy, R, 0, TAU); x.fill()
	x.fillStyle = "#b8e0ff"; x.beginPath(); x.arc(ox, oy - 10, R * 0.8, PI, TAU); x.fill()
	x.fillStyle = "#5aa040"; x.beginPath(); x.moveTo(ox - R, oy + 12); x.lineTo(ox + R, oy + 12); x.arc(ox, oy, R, 0.3, PI - 0.3); x.closePath(); x.fill()
	tankSprite(x, "box_wreck", 0, ox + 8, oy + 16, 1, false, 0.5)
	_tankFrame(x, "idle", 0, ox - 16, oy + 15, 0.5)
	x.fillStyle = rgba(255, 40, 40, 0.6 + 0.4 * sin(t * 6)); x.beginPath(); x.arc(ox - 13, oy - 4, 1.6, 0, TAU); x.fill()
	x.strokeStyle = rgba(255, 180, 250, 0.9); x.lineWidth = 2; x.beginPath(); x.arc(ox, oy, R, 0, TAU); x.stroke()
	x.fillStyle = rgba(255, 255, 255, 0.35); x.beginPath(); x.ellipse(ox - 14, oy - 20, 10, 5, -0.5, 0, TAU); x.fill()
	# the scowl: heavy brows over the glowing eyes
	var top = 2 + sin(t * 1.2) * 2
	_ipoly(x, [[192 - 14, 46 + top], [192 - 2, 51 + top], [192 - 3, 53 + top], [192 - 14, 49 + top]], "#0e0616")
	_ipoly(x, [[192 + 14, 46 + top], [192 + 2, 51 + top], [192 + 3, 53 + top], [192 + 14, 49 + top]], "#0e0616")
