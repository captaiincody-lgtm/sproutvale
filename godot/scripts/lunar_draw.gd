extends "res://scripts/finale_draw.gd"
## Sproutvale, after the end, drawn: Lunar monsters (a cold cyan glow and a crescent over their heads),
## Luna Coins, the blood moon over a night that won't end, the rocket and its pad, the heroes and their
## loved ones standing around the neighborhood, the Moon's sky, its drifting dust and the air bubbles,
## and the story cards: the voice in the dark, the launch, space, the landing.

const LUNAR_TINT := Color(0.55, 1.0, 1.6)


# ================================================================ Lunar monsters

func drawMob(x: Ctx, e, sx: float, sy: float) -> void:
	if not isLunar(e):
		super.drawMob(x, e, sx, sy)
		return
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	var t = realTime
	var mid = Y - e.h * 0.5 + (10.0 if e.T.get("fly") else 0.0)
	if e.state != "dead":
		var r = 16.0 + e.w * 0.6 + sin(t * 3) * 2
		var g = x.createRadialGradient(X, mid, 2, X, mid, r)
		g.addColorStop(0, rgba(150, 240, 255, 0.75)); g.addColorStop(0.6, rgba(110, 210, 255, 0.3)); g.addColorStop(1, rgba(120, 220, 255, 0))
		x.fillStyle = g; x.beginPath(); x.arc(X, mid, r, 0, TAU); x.fill()
		x.strokeStyle = rgba(190, 250, 255, 0.5 + 0.3 * sin(t * 4)); x.lineWidth = 1
		x.beginPath(); x.ellipse(X, Y, e.w * 0.7 + 6, 3, 0, 0, TAU); x.stroke()
		if randf() < 0.35:
			part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h + 4), rand(-6, 6), -rand(10, 30), rand(0.5, 1.0), ["#bff8ff", "#7fe6ff", "#ffffff"][rint(0, 2)], -10, 1)
	x.tint = LUNAR_TINT
	super.drawMob(x, e, sx, sy)
	x.tint = Color.WHITE
	if e.state != "dead":
		# a crescent over its head, and its name
		var cy = Y - e.h - 31 + roundf(sin(t * 2) * 1.0)
		x.font = F6
		x.textAlign = "center"
		textOutline(x, "LUNAR", X + 5, cy, "#7ff4ff", "#06202c")
		var mx = X - 15
		crescent(x, mx, cy - 3, 4.0, "#bff8ff")


## a crescent moon, horns to the right
func crescent(x: Ctx, X: float, Y: float, r: float, col) -> void:
	x.beginPath()
	for i in 13:
		var a = PI * 0.5 + PI * i / 12.0
		var p = Vector2(cos(a) * r, sin(a) * r)
		if i == 0:
			x.moveTo(X + p.x, Y + p.y)
		else:
			x.lineTo(X + p.x, Y + p.y)
	for i in range(12, -1, -1):
		var a = PI * 0.5 + PI * i / 12.0
		x.lineTo(X + cos(a) * r * 0.35, Y + sin(a) * r)
	x.closePath()
	x.fillStyle = col
	x.fill()


func drawPartDrop(x: Ctx, d, X: float, Y: float, tt: float) -> void:
	if d.type != "luna":
		super.drawPartDrop(x, d, X, Y, tt)
		return
	var gl = 0.5 + 0.5 * sin(tt * 5 + d.x)
	var bob = roundf(sin(tt * 4 + d.spin)) if d.vy == 0 else 0.0
	var g = x.createRadialGradient(X, Y - 5 + bob, 1, X, Y - 5 + bob, 9)
	g.addColorStop(0, rgba(140, 240, 255, 0.55 * gl)); g.addColorStop(1, rgba(140, 240, 255, 0))
	x.fillStyle = g; x.fillRect(X - 9, Y - 14 + bob, 18, 18)
	x.drawImage(Assets.tex("items/luna_coin.png"), X - 4.5, Y - 9.5 + bob, 9, 9)


# ================================================================ the sky

func drawSky(x: Ctx, D: Dictionary) -> void:
	if not M.is_empty() and M.get("theme") == "moon":
		_spaceSky(x, realTime)
		return
	super.drawSky(x, D)
	if lunarNight():
		x.fillStyle = rgba(110, 8, 28, 0.22); x.fillRect(0, 0, VW, VH)
		bloodMoon(x, VW / 2.0, 40, 20, realTime)


## the blood moon: big, red, and never moving
func bloodMoon(x: Ctx, X: float, Y: float, r: float, t: float) -> void:
	for i in 3:
		var g = x.createRadialGradient(X, Y, r * 0.8, X, Y, r * (2.2 + i * 0.9))
		g.addColorStop(0, rgba(255, 40, 50, 0.22 - i * 0.05 + sin(t * 0.8) * 0.02)); g.addColorStop(1, rgba(200, 20, 40, 0))
		x.fillStyle = g; x.beginPath(); x.arc(X, Y, r * (2.2 + i * 0.9), 0, TAU); x.fill()
	x.fillStyle = "#9a1424"; x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()
	x.fillStyle = "#c42a34"; x.beginPath(); x.arc(X - r * 0.12, Y - r * 0.12, r * 0.86, 0, TAU); x.fill()
	x.fillStyle = "#7a0e1c"
	for m in [[-0.35, -0.2, 0.28], [0.25, 0.15, 0.22], [-0.05, 0.42, 0.16], [0.4, -0.35, 0.12]]:
		x.beginPath(); x.arc(X + m[0] * r, Y + m[1] * r, m[2] * r, 0, TAU); x.fill()
	x.fillStyle = rgba(255, 170, 170, 0.35); x.beginPath(); x.arc(X - r * 0.4, Y - r * 0.45, r * 0.22, 0, TAU); x.fill()


## black space over the Moon: the stars, and Sproutvale hanging in the sky
func _spaceSky(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, VH)
	g.addColorStop(0, "#020208"); g.addColorStop(1, "#0c0a1a")
	x.fillStyle = g; x.fillRect(0, 0, VW, VH)
	drawNightSky(x, 1.0)
	homeWorld(x, VW * 0.26, 46, 22, t)


## Sproutvale from space: blue seas, green land, white cloud, the night side in shadow
func homeWorld(x: Ctx, X: float, Y: float, r: float, t: float) -> void:
	var g = x.createRadialGradient(X, Y, r * 0.9, X, Y, r * 1.6)
	g.addColorStop(0, rgba(140, 200, 255, 0.35)); g.addColorStop(1, rgba(140, 200, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y, r * 1.6, 0, TAU); x.fill()
	x.fillStyle = "#2a6ad8"; x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()
	x.fillStyle = "#4aa83a"
	for m in [[-0.3, -0.25, 0.35], [0.2, 0.2, 0.3], [0.35, -0.4, 0.18], [-0.45, 0.35, 0.2]]:
		x.beginPath(); x.arc(X + m[0] * r, Y + m[1] * r, m[2] * r, 0, TAU); x.fill()
	x.fillStyle = rgba(255, 255, 255, 0.75)
	for i in 4:
		var cy = -r * 0.6 + i * r * 0.35
		var half = sqrt(maxf(0.0, r * r - cy * cy)) - 1
		var u = fmod(t * 0.01 + i * 0.27, 1.0)
		var cx0 = maxf(X - half, X - r + u * r * 2)
		var cx1 = minf(X + half, X - r + u * r * 2 + r * 0.5)
		if cx1 > cx0:
			x.fillRect(cx0, Y + cy, cx1 - cx0, 1.5)
	# the night side: a lune inside the disc, from the lit edge's terminator round to the far rim
	x.fillStyle = rgba(2, 4, 16, 0.72)
	x.beginPath()
	var tilt = 0.45
	for i in 25:
		var a = -PI / 2 + PI * i / 24.0
		x.lineTo(X + r * (cos(a) * cos(tilt) - sin(a) * sin(tilt)), Y + r * (cos(a) * sin(tilt) + sin(a) * cos(tilt)))
	for i in range(1, 24):
		var a = PI / 2 - PI * i / 24.0
		var cx = cos(a) * 0.15
		x.lineTo(X + r * (cx * cos(tilt) - sin(a) * sin(tilt)), Y + r * (cx * sin(tilt) + sin(a) * cos(tilt)))
	x.fill()
	x.strokeStyle = rgba(180, 220, 255, 0.5); x.lineWidth = 1
	x.beginPath(); x.arc(X, Y, r, PI * 0.55, PI * 1.6); x.stroke()


func drawClouds(x: Ctx, D: Dictionary, dt: float) -> void:
	if M.get("theme") != "moon":
		super.drawClouds(x, D, dt)


func drawDragon(x: Ctx, D: Dictionary, dt: float) -> void:
	if M.get("theme") != "moon" and not lunarNight():
		super.drawDragon(x, D, dt)


func drawWeatherClouds(x: Ctx, D: Dictionary, dt: float) -> void:
	if M.get("theme") != "moon":
		super.drawWeatherClouds(x, D, dt)


func drawAmbientLife(x: Ctx, sx: float, sy: float, D: Dictionary, dt: float) -> void:
	if M.get("theme") != "moon":
		super.drawAmbientLife(x, sx, sy, D, dt)


func renderTint(ci: CanvasItem) -> void:
	if M.is_empty():
		super.renderTint(ci)
		return
	var x = ctx
	if M.get("theme") == "moon":
		x.begin(ci)
		x.fillStyle = "#dcdcff"; x.fillRect(0, 0, VW, VH)   # cold, airless light
		return
	if lunarNight():
		x.begin(ci)
		if M.get("indoor"):
			x.fillStyle = "#8c7896" if mapId != "trophy" else "#c8b8d0"   # the lamps are on, but it's the middle of the night
			x.fillRect(0, 0, VW, VH)
			return
		if not (M.get("theme") in ["crimson", "abyss", "bubble"]) and not climbMap():
			x.fillStyle = mixc("#ffffff", "#9a3a5a", 0.62)
			x.fillRect(0, 0, VW, VH)
			return
	super.renderTint(ci)


# ================================================================ in the world

func drawTankBack(x: Ctx, sx: float, sy: float) -> void:
	super.drawTankBack(x, sx, sy)
	if not finaleBeaten():
		return
	if isVillage() and lunarNight():
		rocketPad(x, ROCKET_X - sx, M.floorY - sy)
		rocket(x, ROCKET_X - sx, M.floorY - sy - 6, 1.0, 0.0, realTime, true)
	elif mapId == "moon1":
		rocket(x, MOON_ROCKET_X - sx, M.floorY - sy + 2, 1.0, 0.0, realTime, false)
	for n in npcsHere():
		_drawNpc(x, n, sx, sy)


func drawTankFront(x: Ctx, sx: float, sy: float) -> void:
	super.drawTankFront(x, sx, sy)
	# the Moon's dust, drifting
	for d in moonDust:
		var a = 1.0 - d.t / d.life
		x.fillStyle = rgba(190, 188, 200, 0.55 * a)
		x.beginPath(); x.arc(d.x - sx, d.y - sy - d.r * 0.5, d.r * (0.6 + d.t / d.life * 0.8), 0, TAU); x.fill()
	if not finaleBeaten():
		return
	var t = realTime
	var near = npcAt() if scene == null else null
	for n in npcsHere():
		if n.get("bubble", false):
			var h = _npcHead(n)
			_airBubble(x, h.x - sx, h.y - sy, t + n.x)
		if n == near or (near != null and n.key == near.key):
			x.font = F6
			x.textAlign = "center"
			textOutline(x, "↑ Talk to " + npcName(n), roundf(n.x - sx), roundf(n.y - sy - (36 if n.kin else 52)), "#ffffff")
	if mapId == "moon1" and P.state != "dead":
		_airBubble(x, heroHead.x - sx, heroHead.y - sy, t)
	if scene == null and rocketAt():
		x.font = F6
		x.textAlign = "center"
		var rx = (ROCKET_X if isVillage() else MOON_ROCKET_X) - sx
		textOutline(x, "↑ Fly home" if mapId == "moon1" else "↑ Board the rocket", roundf(rx), roundf(M.floorY - sy - 132), "#ffffff")


func _airBubble(x: Ctx, hx: float, hy: float, t: float) -> void:
	var r = 9.5 + sin(t * 3) * 0.4
	x.fillStyle = rgba(190, 225, 255, 0.13)
	x.beginPath(); x.arc(hx, hy, r, 0, TAU); x.fill()
	x.strokeStyle = rgba(225, 240, 255, 0.6); x.lineWidth = 0.7
	x.beginPath(); x.arc(hx, hy, r, 0, TAU); x.stroke()
	x.strokeStyle = rgba(255, 255, 255, 0.85); x.lineWidth = 0.8
	x.beginPath(); x.arc(hx, hy, r - 2.5, PI * 1.1, PI * 1.45); x.stroke()
	x.fillStyle = rgba(255, 255, 255, 0.9); x.fillRect(hx + 4, hy - 5, 1, 1)


## which way an NPC looks: at you when you're close, otherwise their own way
func _npcFace(n: Dictionary) -> int:
	if absf(P.x - n.x) < 90 and absf(P.y - n.y) < 40 and P.x != n.x:
		return 1 if P.x > n.x else -1
	return int(n.face)


func _npcFrame(n: Dictionary) -> Array:
	var look = lookOf(n.cls)
	var A = Assets.hero_anim(look, "idle")
	var nf = maxi(1, int(A.frames))
	return [look, nf, int((realTime + n.x * 0.37) * float(A.fps)) % nf]


func _npcHead(n: Dictionary) -> Vector2:
	var fr = _npcFrame(n)
	var hd = Assets.hero_head(fr[0], "idle", fr[2])
	if hd == null:
		hd = Vector2(RX - 6, GROUND - 39)
	return Vector2(n.x + _npcFace(n) * (hd.x - RX), n.y + hd.y - GROUND)


func _drawNpc(x: Ctx, n: Dictionary, sx: float, sy: float) -> void:
	var X = roundf(n.x - sx)
	var Y = roundf(n.y - sy)
	if X < -40 or X > VW + 40:
		return
	var face = _npcFace(n)
	x.fillStyle = rgba(20, 30, 10, 0.25)
	x.fillRect(X - (5 if n.kin else 8), Y - 1, 10 if n.kin else 16, 2)
	if n.kin:
		var tex = Assets.tex("kin/%s.png" % n.cls)
		if tex != null:
			var hop = 0.0 if lunarNight() else roundf(absf(sin(realTime * 2.5 + n.x)) * 1.5)
			x.save()
			x.translate(X, Y - hop)
			if face < 0:
				x.scale(-1, 1)
			x.drawImage(tex, -8, -24, 16, 24)
			x.restore()
	else:
		var fr = _npcFrame(n)
		var tex = Assets.hero_strip(fr[0], "idle", 1)
		if tex != null:
			x.save()
			x.translate(X, Y)
			if face < 0:
				x.scale(-1, 1)
			x.drawFrame(tex, fr[1], fr[2], -RX, -GROUND, SW, SH)
			x.restore()
	x.font = F5
	x.textAlign = "center"
	var name = npcName(n)
	var w = x.measureText(name).width + 6
	x.fillStyle = rgba(20, 20, 40, 0.6); x.fillRect(X - w / 2, Y + 3, w, 7)
	x.fillStyle = "#ffe8b0" if n.kin else "#d8f0ff"
	x.fillText(name, X, Y + 9)


## the launch pad: a steel deck and a gantry tower with a walkway to the hatch
func rocketPad(x: Ctx, X: float, Y: float) -> void:
	x.fillStyle = "#2a2e38"; x.fillRect(X - 44, Y - 6, 88, 6)
	x.fillStyle = "#4a5060"; x.fillRect(X - 44, Y - 7, 88, 2)
	x.fillStyle = "#ffcc3a"
	for i in 8:
		x.fillRect(X - 42 + i * 11, Y - 4, 5, 2)
	# the gantry: a lattice tower to the right, and a walkway arm to the hatch
	var gx = X + 30
	x.strokeStyle = "#5a6070"; x.lineWidth = 1
	x.fillStyle = "#3a404c"
	x.fillRect(gx, Y - 112, 2, 106); x.fillRect(gx + 12, Y - 112, 2, 106)
	var yy = Y - 6.0
	while yy > Y - 110:
		x.beginPath(); x.moveTo(gx, yy); x.lineTo(gx + 13, yy - 10); x.moveTo(gx + 13, yy); x.lineTo(gx, yy - 10); x.stroke()
		x.fillRect(gx, yy - 1, 14, 1)
		yy -= 10
	x.fillStyle = "#ff3a3a" if int(realTime * 2) % 2 else "#5a1a1a"
	x.fillRect(gx + 5, Y - 116, 4, 3)
	x.fillStyle = "#4a5060"; x.fillRect(X + 12, Y - 34, 18, 3)


## the rocket Tank built: X is its middle, Y the bottom of its legs; k its size; flame 0–1
func rocket(x: Ctx, X: float, Y: float, k: float, flame: float, t: float, redMoon: bool) -> void:
	x.save()
	x.translate(X, Y)
	x.scale(k, k)
	if flame > 0:
		var fl = flame * (26 + sin(t * 40) * 4)
		for i in 3:
			var w = (10 - i * 3) * (0.8 + 0.2 * sin(t * 33 + i))
			x.fillStyle = ["#ff6a2a", "#ffb03a", "#fff6c0"][i]
			x.beginPath(); x.moveTo(-w, -8); x.lineTo(w, -8); x.lineTo(0, -8 + fl * (1 - i * 0.25)); x.closePath(); x.fill()
	# landing legs
	x.strokeStyle = "#3a404c"; x.lineWidth = 2
	x.beginPath(); x.moveTo(-10, -20); x.lineTo(-20, 0); x.moveTo(10, -20); x.lineTo(20, 0); x.stroke()
	x.fillStyle = "#2a2e38"; x.fillRect(-23, -2, 7, 2); x.fillRect(16, -2, 7, 2)
	# engine bell
	x.fillStyle = "#3a3f4a"
	x.beginPath(); x.moveTo(-7, -16); x.lineTo(7, -16); x.lineTo(10, -7); x.lineTo(-10, -7); x.closePath(); x.fill()
	x.fillStyle = "#5a606c"; x.fillRect(-7, -16, 14, 2)
	# fins
	for s in [-1, 1]:
		x.fillStyle = "#a82030"
		x.beginPath(); x.moveTo(s * 12, -46); x.lineTo(s * 24, -18); x.lineTo(s * 24, -10); x.lineTo(s * 12, -18); x.closePath(); x.fill()
		x.fillStyle = "#e04050"
		x.beginPath(); x.moveTo(s * 12, -46); x.lineTo(s * 16, -36); x.lineTo(s * 16, -20); x.lineTo(s * 12, -18); x.closePath(); x.fill()
	# the body: brushed steel, darker at the edges
	var bands = [["#6a7284", -13, 3], ["#a8b0c0", -10, 4], ["#dfe4ee", -6, 6], ["#c8ced8", 0, 5], ["#9aa2b4", 5, 4], ["#6a7284", 9, 4]]
	for b in bands:
		x.fillStyle = b[0]; x.fillRect(b[1], -96, b[2], 80)
	x.fillStyle = "#8a92a4"
	for i in 5:
		x.fillRect(-13, -92 + i * 17, 26, 1)   # the plate seams
	x.fillStyle = "#5a606c"
	for i in 5:
		for j in 4:
			x.fillRect(-11 + j * 7, -89 + i * 17, 1, 1)   # rivets
	# Tank's cyan stripe and the name
	x.fillStyle = "#1a8ab0"; x.fillRect(-13, -44, 26, 4)
	x.fillStyle = "#7fe6ff"; x.fillRect(-13, -44, 26, 1)
	x.font = F5
	x.textAlign = "center"
	x.fillStyle = "#2a3040"
	x.fillText("SV-1", 0, -50)
	# portholes
	for py in [-78, -62]:
		x.fillStyle = "#2a3040"; x.beginPath(); x.arc(0, py, 5, 0, TAU); x.fill()
		x.fillStyle = "#3aa8d8"; x.beginPath(); x.arc(0, py, 3.6, 0, TAU); x.fill()
		x.fillStyle = "#bff4ff"; x.fillRect(-2, py - 2, 2, 1)
	# the hatch
	x.fillStyle = "#4a5060"; x.fillRect(-6, -34, 12, 16)
	x.fillStyle = "#2a2e38"; x.fillRect(-5, -33, 10, 14)
	x.fillStyle = "#ffcc3a"; x.fillRect(3, -27, 1, 2)
	# the nose cone
	x.fillStyle = "#a82030"
	x.beginPath(); x.moveTo(-13, -96); x.quadraticCurveTo(-10, -118, 0, -128); x.quadraticCurveTo(10, -118, 13, -96); x.closePath(); x.fill()
	x.fillStyle = "#e04050"
	x.beginPath(); x.moveTo(-8, -96); x.quadraticCurveTo(-6, -114, 0, -126); x.lineTo(-1, -96); x.closePath(); x.fill()
	x.fillStyle = "#3a404c"; x.fillRect(-1, -134, 2, 7)
	if redMoon:   # the blood moon's light along one side
		x.fillStyle = rgba(255, 60, 70, 0.45)
		x.fillRect(11, -96, 2, 80)
	x.restore()


# ================================================================ the story cards

func drawVolcanoStory(x: Ctx, t: float, kind: String) -> void:
	match kind:
		"l_dark": _storyDark(x, t)
		"l_launch": _storyLaunch(x, t)
		"l_space": _storySpace(x, t)
		"l_land": _storyLand(x, t)
		"l_home": _storyHome(x, t)
		_: super.drawVolcanoStory(x, t, kind)


## the game goes dark, and a shape that might be a person says nothing much
func _storyDark(x: Ctx, t: float) -> void:
	x.fillStyle = "#000000"; x.fillRect(0, 0, 384, 216)
	if not intro.get("drone", false):
		intro.drone = true
		Sfx.tone(55, 5.0, "sine", 0.09, 50)
		Sfx.tone(82, 5.0, "triangle", 0.03, 80, 1.0)
	var a = clampf((t - 1.2) / 2.5, 0, 1)
	if a <= 0:
		return
	var X = 192.0
	var sway = sin(t * 0.7) * 1.5
	# a tall, hooded outline: only its edge catches a little light from somewhere
	var pts = [[X - 6, 46], [X + 6, 46], [X + 16, 62], [X + 18, 84], [X + 30, 100], [X + 38, 216], [X - 38, 216], [X - 30, 100], [X - 18, 84], [X - 16, 62]]
	x.beginPath()
	x.moveTo(pts[0][0] + sway, pts[0][1])
	for i in range(1, pts.size()):
		x.lineTo(pts[i][0] + sway * (1.0 - pts[i][1] / 216.0), pts[i][1])
	x.closePath()
	x.fillStyle = rgba(10, 10, 16, a)
	x.fill()
	x.strokeStyle = rgba(140, 200, 255, 0.22 * a); x.lineWidth = 1
	x.stroke()
	# under the hood: just a glint, once in a while
	var glint = clampf(sin(t * 0.9 - 2.0) * 3 - 2, 0, 1) * a
	if glint > 0:
		x.fillStyle = rgba(200, 240, 255, glint * 0.8)
		x.fillRect(X - 5 + sway, 64, 2, 1); x.fillRect(X + 3 + sway, 64, 2, 1)
	x.font = FONT
	x.textAlign = "center"
	x.fillStyle = rgba(190, 210, 255, a * 0.9)
	x.fillText("???", X, 32)


func _storyNight(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, 216)
	g.addColorStop(0, "#08020a"); g.addColorStop(1, "#3a0a1c")
	x.fillStyle = g; x.fillRect(0, 0, 384, 216)
	for i in 50:
		x.fillStyle = rgba(255, 220, 230, 0.3 + 0.4 * absf(sin(t + i))); x.fillRect(_irnd2(i) * 384, _irnd2(i + 70) * 120, 1, 1)
	bloodMoon(x, 300, 48, 22, t)


## lift-off from behind the houses
func _storyLaunch(x: Ctx, t: float) -> void:
	_storyNight(x, t)
	# the neighborhood in silhouette
	x.fillStyle = "#14060c"
	for i in 5:
		var hx = 20.0 + i * 50
		x.fillRect(hx, 150, 34, 22)
		x.beginPath(); x.moveTo(hx - 4, 150); x.lineTo(hx + 17, 136); x.lineTo(hx + 38, 150); x.closePath(); x.fill()
		x.fillStyle = rgba(255, 200, 120, 0.7); x.fillRect(hx + 8, 158, 4, 4); x.fillStyle = "#14060c"
	x.fillStyle = "#0e0408"; x.fillRect(0, 170, 384, 46)
	var lift = maxf(0, t - 1.6)
	var y = 170 - lift * lift * 40
	var flame = clampf((t - 0.6) / 0.6, 0, 1)
	var sh = (sin(t * 50) * 1.2) if t > 0.6 and lift < 1.5 else 0.0
	rocketPad(x, 300, 170)
	rocket(x, 300 + sh, y - 6, 1.0, flame, t, true)
	if t > 0.6:   # smoke billowing out from under it
		for i in 14:
			var k = fmod(t * 0.5 + i / 14.0, 1.0)
			var s = 1 if i % 2 else -1
			x.fillStyle = rgba(200, 170, 180, 0.4 * (1 - k))
			x.beginPath(); x.arc(300 + s * k * 90, 166 - k * 20 + _irnd2(i) * 6, 6 + k * 18, 0, TAU); x.fill()
		if not intro.get("rumble", false):
			intro.rumble = true
			Sfx.tone(45, 4.0, "sawtooth", 0.08, 30)
			Sfx.burst(3.5, "lowpass", 500, 120, 0.25)


## through the dark between
func _storySpace(x: Ctx, t: float) -> void:
	x.fillStyle = "#020208"; x.fillRect(0, 0, 384, 216)
	for i in 120:
		var tw = 0.4 + 0.6 * absf(sin(t * (0.5 + _irnd2(i)) + i))
		x.fillStyle = rgba(255, 255, 255, 0.6 * tw); x.fillRect(fposmod(_irnd2(i) * 384 - t * 8 * (0.3 + _irnd2(i + 5)), 384), _irnd2(i + 40) * 216, 1, 1)
	var k = clampf(t / 5.0, 0, 1)
	homeWorld(x, 70 - k * 30, 190 + k * 30, 70 - k * 30, t)
	var mr = 18 + k * 34
	bloodMoon(x, 310 + k * 10, 50 - k * 6, mr, t)
	# the rocket, small, crossing between them
	var rx = lerpf(110, 250, k)
	var ry = lerpf(150, 82, k)
	x.save()
	x.translate(rx, ry)
	x.rotate(atan2(-68, 140) + PI / 2)
	rocket(x, 0, 0, 0.32, 1.0, t, false)
	x.restore()


## coming down on the Moon
func _storyLand(x: Ctx, t: float) -> void:
	_spaceSky(x, t)
	x.fillStyle = "#4a4858"
	x.beginPath(); x.moveTo(0, 150); x.lineTo(60, 140); x.lineTo(130, 146); x.lineTo(220, 136); x.lineTo(300, 144); x.lineTo(384, 138); x.lineTo(384, 216); x.lineTo(0, 216); x.closePath(); x.fill()
	x.fillStyle = "#8a8898"; x.fillRect(0, 160, 384, 56)
	x.fillStyle = "#b8b6c4"; x.fillRect(0, 160, 384, 2)
	for i in 10:
		x.fillStyle = "#6e6c7c"; x.beginPath(); x.ellipse(_irnd2(i) * 384, 172 + _irnd2(i + 9) * 34, 8 + _irnd2(i + 3) * 12, 3, 0, 0, TAU); x.fill()
	var k = clampf(t / 3.0, 0, 1)
	var e = 1 - (1 - k) * (1 - k)
	var y = lerpf(-20, 162, e)
	rocket(x, 200, y, 0.9, 1.0 if k < 1 else maxf(0, 1 - (t - 3.0) * 2), t, false)
	if k > 0.6:   # the dust it blows out
		var d = clampf((k - 0.6) / 0.4, 0, 1) + maxf(0, t - 3.0) * 0.4
		for i in 16:
			var s = 1 if i % 2 else -1
			var u = fmod(d * 0.6 + i / 16.0, 1.0)
			x.fillStyle = rgba(200, 198, 210, 0.45 * (1 - u) * minf(1, d))
			x.beginPath(); x.arc(200 + s * u * 120 * minf(1, d + 0.2), 160 - u * 12, 4 + u * 14, 0, TAU); x.fill()
	if k >= 1 and not intro.get("thud", false):
		intro.thud = true
		Sfx.slam()


## and back home again
func _storyHome(x: Ctx, t: float) -> void:
	_storyNight(x, t)
	x.fillStyle = "#0e0408"; x.fillRect(0, 170, 384, 46)
	var k = clampf(t / 3.0, 0, 1)
	var e = 1 - (1 - k) * (1 - k)
	rocketPad(x, 200, 170)
	rocket(x, 200, lerpf(-30, 164, e), 1.0, 1.0 if k < 1 else 0.0, t, true)
