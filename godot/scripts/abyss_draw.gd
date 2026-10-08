extends "res://scripts/render.gd"
## Sproutvale, part 7½: drawing the Abyss. The sky and sea of the Drowned Shore, the water deepening
## from blue to black, the glowing runes and seaweed of the deep, the eight Abyss monsters, The
## Dreamer (its head behind the floor, its tentacles in front), and the colours racing round the bubble.

const DR_COL := {"skin": "#2a1040", "dark": "#120620", "mid": "#3e1858", "hi": "#5a2878", "sucker": "#d0406a", "tip": "#7a2a8a"}

var _glows := {}        # map id → [[x, y, r, colour]…] (from art/abyss/maps/<id>.json)
var _abGround := -1.0   # the ground height the background follows, smoothed


func mapGlows(id: String) -> Array:
	if not _glows.has(id):
		var path = "res://art/abyss/maps/%s.json" % id
		_glows[id] = Assets._json(path).get("glows", []) if FileAccess.file_exists(path) else []
	return _glows[id]


# ================================================================ backgrounds

## everything behind the painted map: sky, water, far silhouettes, light, and the Dreamer's head
func drawAbyssBack(x: Ctx, sx: float, sy: float, dt: float) -> void:
	if M.get("theme") == "bubble":
		drawBubbleBack(x, sx, sy, dt)
		return
	var d: float = M.get("depth", 0.0)
	var top = seaTop()
	var t = realTime
	# the water (and above the Drowned Shore, a bruised crimson sky)
	var surfScr = top - sy
	if top > -1e8:
		var g = x.createLinearGradient(0, surfScr - 220, 0, surfScr)
		g.addColorStop(0, "#0c0208"); g.addColorStop(0.55, "#2a0814"); g.addColorStop(0.85, "#4a1030"); g.addColorStop(1, "#5a1a48")
		x.fillStyle = g
		x.fillRect(0, 0, VW, maxf(0, surfScr))
		# a sick moon behind the haze
		x.fillStyle = rgba(255, 120, 140, 0.18); x.beginPath(); x.arc(VW * 0.72 - sx * 0.02, surfScr - 150, 22, 0, TAU); x.fill()
		x.fillStyle = rgba(255, 160, 170, 0.35); x.beginPath(); x.arc(VW * 0.72 - sx * 0.02, surfScr - 150, 12, 0, TAU); x.fill()
	var wTop = maxf(0, surfScr) if top > -1e8 else 0.0
	var cTop = mixc("#2a1a50", "#07040e", d)
	var cBot = mixc("#0e0820", "#020104", minf(1, d + 0.3))
	var yk0 = clampf(sy / M.h, 0, 1)
	var yk1 = clampf((sy + VH) / M.h, 0, 1)
	var wg = x.createLinearGradient(0, wTop, 0, VH)
	wg.addColorStop(0, cTop.lerp(cBot, yk0)); wg.addColorStop(1, cTop.lerp(cBot, yk1))
	x.fillStyle = wg
	x.fillRect(0, wTop, VW, VH - wTop + 1)
	# parallax: shore stacks above the sea; rock spires, kelp and old ruins below
	var gNow = groundAt(sx + VW / 2.0)
	_abGround = gNow if _abGround < 0 else damp(_abGround, gNow, 2.5, dt)
	var floorScr = _abGround - sy
	var fo = -fmod(roundf(sx * 0.15), VW * 2.0)
	var mo = -fmod(roundf(sx * 0.4), VW * 2.0)
	var layers: Array
	if top > -1e8:
		layers = [["abyss_far", fo, surfScr - 120, 0.9], ["abyss_mid", mo, surfScr - 90, 1.0]]
	else:
		var th = "abyssdeep" if d < 0.5 else "abyssruin"
		layers = [[th + "_far", fo, roundf(floorScr * 0.35 + VH * 0.42 - 120), 0.55 + d * 0.3], [th + "_mid", mo, roundf(floorScr * 0.6 + VH * 0.4 - 90), 0.85]]
	for L in layers:
		var tex = Assets.tex("sky/%s.png" % L[0])
		if tex == null:
			continue
		x.globalAlpha = L[3]
		var w = tex.get_width() / 2.0
		var h = tex.get_height() / 2.0
		x.drawImage(tex, L[1], L[2], w, h)
		x.drawImage(tex, L[1] + w, L[2], w, h)
		if top < -1e8 and L[2] + h < VH:
			# carry the layer's dark base on down (same colour and see-through-ness, so there's no seam)
			x.fillStyle = "#0a0818" if L[0].ends_with("far") else "#070512"
			x.fillRect(0, L[2] + h - 1, VW, VH - L[2] - h + 1)
		x.globalAlpha = 1
	# god rays from far above (only where light still reaches)
	if d < 0.8:
		var a0 = (0.07 if top > -1e8 else 0.05) * (1 - d)
		for i in 5:
			var rx = fmod(i * 97.0 - sx * 0.25 + sin(t * 0.3 + i) * 14, VW + 120) - 60
			x.fillStyle = rgba(200, 170, 255, a0 * (0.6 + 0.4 * sin(t * 0.7 + i * 2)))
			x.beginPath()
			x.moveTo(rx, wTop); x.lineTo(rx + 18, wTop); x.lineTo(rx - 40, VH); x.lineTo(rx - 80, VH)
			x.closePath(); x.fill()
	# marine snow drifting down
	for i in 46:
		var px = fmod(hsh(i * 3.1) * (VW + 40) - sx * (0.3 + hsh(i) * 0.4) + sin(t * 0.4 + i) * 6, VW + 40)
		if px < 0:
			px += VW + 40
		var py = fmod(hsh(i * 5.7) * (VH + 20) + t * (4 + hsh(i * 2) * 6) - sy * 0.3, VH + 20)
		if py < 0:
			py += VH + 20
		if py < wTop:
			continue
		x.fillStyle = rgba(220, 200, 255, 0.25 + hsh(i * 9) * 0.3)
		x.fillRect(roundf(px - 20), roundf(py - 10), 1, 1)
	drawDreamerHead(x, sx, sy)


## inside the bubble: thin-film colours racing round a dark, glassy sphere
func drawBubbleBack(x: Ctx, sx: float, sy: float, _dt: float) -> void:
	var t = realTime
	var g = x.createLinearGradient(0, 0, 0, VH)
	g.addColorStop(0, "#160c30"); g.addColorStop(0.6, "#1e1440"); g.addColorStop(1, "#2a1a50")
	x.fillStyle = g
	x.fillRect(0, 0, VW, VH)
	var films = [[0, 46.0, 0.55, 0.0], [1, -74.0, 0.45, 2.1], [2, 112.0, 0.35, 4.2]]
	for F in films:
		var tex = Assets.tex("sky/bubble_%d.png" % F[0])
		if tex == null:
			continue
		var off = -fmod(t * F[1] + sx * (0.2 + F[0] * 0.15), VW)
		if off > 0:
			off -= VW
		var oy = sin(t * 0.35 + F[3]) * 14 - 10
		var hue = fmod(t * 0.06 + F[0] * 0.33, 1.0)
		var mod = Color.from_hsv(hue, 0.25, 1.0)
		x.globalAlpha = F[2] * (0.8 + 0.2 * sin(t * 0.9 + F[3]))
		for k in 3:
			x.drawFrame(tex, 1, 0, off + k * VW, oy, VW, VH + 20, mod)
	x.globalAlpha = 1
	# the light shining on the bubble: a soft hot spot and a bright curved rim
	var lx = VW * 0.28 + sin(t * 0.2) * 30
	var ly = 44 + cos(t * 0.17) * 10
	var lg = x.createRadialGradient(lx, ly, 2, lx, ly, 90)
	lg.addColorStop(0, rgba(255, 255, 255, 0.5)); lg.addColorStop(0.3, rgba(255, 240, 255, 0.16)); lg.addColorStop(1, rgba(255, 255, 255, 0))
	x.fillStyle = lg
	x.beginPath(); x.arc(lx, ly, 90, 0, TAU); x.fill()
	x.strokeStyle = rgba(255, 255, 255, 0.22)
	x.lineWidth = 3
	x.beginPath(); x.arc(VW / 2.0, VH * 2.2, VH * 2.15, PI * 1.22, PI * 1.78); x.stroke()
	x.strokeStyle = rgba(255, 255, 255, 0.4)
	x.lineWidth = 1
	x.beginPath(); x.arc(VW / 2.0, VH * 2.2, VH * 2.12, PI * 1.3, PI * 1.45); x.stroke()
	# tiny motes of light
	for i in 30:
		var px = fmod(hsh(i * 2.3) * VW + t * (6 + hsh(i) * 10), VW)
		var py = fmod(hsh(i * 4.1) * VH - t * (3 + hsh(i * 3) * 4) + VH * 4, VH)
		var a = 0.3 + 0.3 * sin(t * 2 + i)
		x.fillStyle = Color.from_hsv(fmod(hsh(i) + t * 0.1, 1.0), 0.4, 1.0, a)
		x.fillRect(roundf(px), roundf(py), 1, 1)


## the painted map; the trophy hall's wall repeats past the end of its picture (it grew for the Abyss's cards)
func drawTerrain(x: Ctx, mt: Texture2D, sx: float, sy: float) -> void:
	var tw = mt.get_width() / float(RES)
	if sx + VW <= tw or not M.get("trophy"):
		x.drawImageRegion(mt, sx * RES, sy * RES, VW * RES, VH * RES, 0, 0, VW, VH)
		return
	const PER := 132.0   # the wall's panels and lamps repeat every 132 units
	var X = 0.0
	while X < VW:
		var wx = sx + X
		var src: float
		var w: float
		if wx < tw - PER:
			src = wx
			w = minf(VW - X, tw - PER - wx)
		else:
			var k = fmod(wx - (tw - PER), PER)
			src = tw - PER + k
			w = minf(VW - X, PER - k)
		x.drawImageRegion(mt, src * RES, sy * RES, w * RES, VH * RES, X, 0, w, VH)
		X += w


# ================================================================ in front of everyone

func drawAbyssFront(x: Ctx, sx: float, sy: float, _dt: float) -> void:
	var t = realTime
	# toad tongues
	for e in slimes:
		if e.type == "toad" and e.data.get("tongue", 0.0) > 0 and e.state != "dead":
			var X0 = e.x + e.face * 10 - sx
			var Y0 = e.y - 9 - sy
			var X1 = e.x + e.face * (10 + 86 * e.data.tongue) - sx
			x.strokeStyle = "#a0203a"; x.lineWidth = 2.5
			x.beginPath(); x.moveTo(X0, Y0); x.lineTo(X1, Y0 + sin(t * 30) * 0.5); x.stroke()
			x.fillStyle = "#e04060"; x.beginPath(); x.arc(X1, Y0, 2.5, 0, TAU); x.fill()
	# the Dreamer's tentacles
	var dr = _dreamer()
	if dr != null:
		drawDreamerTents(x, dr, sx, sy)
	# droppings, bubbles and ink
	for s in abyssShots:
		var X = roundf(s.x - sx)
		var Y = roundf(s.y - sy)
		match s.kind:
			"poop":
				x.fillStyle = "#2a0a30"; x.fillRect(X - 2, Y - 2, 4, 4)
				x.fillStyle = "#8a3ac8"; x.fillRect(X - 1, Y - 2, 2, 1)
				x.fillStyle = "#c8b8d8"; x.fillRect(X - 1, Y - 1, 1, 1)
			"bubble":
				x.strokeStyle = rgba(230, 245, 255, 0.85); x.lineWidth = 0.8
				x.beginPath(); x.arc(X, Y, 3, 0, TAU); x.stroke()
				x.fillStyle = rgba(255, 255, 255, 0.9); x.fillRect(X - 1, Y - 2, 1, 1)
			"ink":
				x.fillStyle = rgba(10, 4, 16, 0.85); x.beginPath(); x.arc(X, Y, 5, 0, TAU); x.fill()
				x.fillStyle = rgba(58, 14, 58, 0.9); x.beginPath(); x.arc(X - 1, Y - 1, 2.5, 0, TAU); x.fill()
	# Abyssal Devour: the Dreamer's maw opens in front of the hero
	if pDevour != null:
		var Dv: Dictionary = pDevour
		var mtex = Assets.tex("boss/dreamer_mouth.png")
		var open = 1 if (Dv.t < 0.55 or fmod(Dv.t - 0.55, 0.45) < 0.2) else 0
		var a = minf(1, Dv.t / 0.2) * minf(1, (1.8 - Dv.t) / 0.25)
		x.globalAlpha = clampf(a, 0, 1) * 0.9
		var mx = P.x + Dv.face * 30 - sx
		var my = P.y - 18 - sy
		var gl = x.createRadialGradient(mx, my, 2, mx, my, 34)
		gl.addColorStop(0, rgba(194, 92, 255, 0.4)); gl.addColorStop(1, rgba(194, 92, 255, 0))
		x.fillStyle = gl; x.beginPath(); x.arc(mx, my, 34, 0, TAU); x.fill()
		x.drawFrame(mtex, 2, open, mx - 24, my - 19, 48, 38)
		x.globalAlpha = 1
	# the air bubble around the hero's head underwater
	if M.get("theme") == "abyss" and underSea(P.x, P.y - 36) and not (P.held != null and P.held.kind == "eaten") and P.state != "dead":
		var hx = roundf(P.x - sx) + P.face
		var hy = roundf(P.y - sy) - 35
		if P.state == "tumble":
			hx = roundf(P.x - sx - sin(P.spin) * 15)
			hy = roundf(P.y - sy - 20 - cos(P.spin) * 15)
		x.fillStyle = rgba(190, 225, 255, 0.13)
		x.beginPath(); x.arc(hx, hy, 9.5 + sin(t * 3) * 0.4, 0, TAU); x.fill()
		x.strokeStyle = rgba(225, 240, 255, 0.6); x.lineWidth = 0.7
		x.beginPath(); x.arc(hx, hy, 9.5 + sin(t * 3) * 0.4, 0, TAU); x.stroke()
		x.strokeStyle = rgba(255, 255, 255, 0.85); x.lineWidth = 0.8
		x.beginPath(); x.arc(hx, hy, 7, PI * 1.1, PI * 1.45); x.stroke()
		x.fillStyle = rgba(255, 255, 255, 0.9); x.fillRect(hx + 4, hy - 5, 1, 1)
	# the sea at the Drowned Shore, laid over everything under it
	var top = seaTop()
	if top > -1e8 and top < 1e8:
		var sea: Dictionary = M.sea
		var c: Array = Water.cols
		var st: float = Water.step
		x.fillStyle = rgba(26, 8, 40, 0.5)
		x.beginPath()
		x.moveTo(sea.x0 - sx, M.h - sy + 10)
		var i0 = maxi(0, floori((sx - sea.x0) / st) - 1)
		var i1 = mini(c.size() - 1, ceili((sx + VW - sea.x0) / st) + 1)
		x.lineTo(maxf(sea.x0, sea.x0 + i0 * st) - sx, M.h - sy + 10)
		for i in range(i0, i1 + 1):
			x.lineTo(sea.x0 + i * st - sx, top + c[i] - sy)
		x.lineTo(minf(sea.x1, sea.x0 + i1 * st) - sx, M.h - sy + 10)
		x.closePath()
		x.fill()
		for i in range(i0, i1 + 1):
			var X = roundf(sea.x0 + i * st - sx)
			var Y = roundf(top + c[i] - sy)
			x.fillStyle = rgba(150, 70, 140, 0.8)
			x.fillRect(X, Y, st, 1)
			if (i + int(t * 2)) % 11 == 0:
				x.fillStyle = rgba(255, 140, 180, 0.6)
				x.fillRect(X + 1, Y + 2, 2, 1)


# ================================================================ the Abyss's monsters

func _abyssKey(e) -> Array:
	var tt: float = e.t
	if e.state == "dead":
		return ["dead", 0]
	if e.flash > 0:
		return ["white", 0]
	if e.state == "hurt":
		return ["hurt", 0]
	match e.type:
		"toad":
			if e.move == "tongue" and e.state in ["wind", "act"]:
				return ["tongue", 0]
			if e.y < e.surf.y - 1:
				return ["hop" if e.vy < 0 else "slam", 0]
			if e.state == "wind":
				return ["slam", 0]
			return ["idle", int(tt * 2.5) % 2]
		"seagull":
			if e.state in ["wind", "act"]:
				return ["dive", 0]
			if e.data.get("dropT", 0.0) > 0:
				return ["drop", 0]
			return ["fly", int(tt * 10) % 4]
		"bass":
			if e.move == "charge" and (e.state == "act" or (e.state == "wind" and e.data.get("q", 0.0) > 0)):
				return ["charge", 0]
			if e.move == "bite" and e.state == "act":
				return ["bite", mini(1, int(tt / 0.12))]
			return ["swim", int(tt * 8) % 4]
		"crab":
			if e.move == "pinch" and e.state in ["wind", "act"]:
				return ["pinch", 0 if e.state == "wind" else 1]
			if e.move == "beam" and e.state in ["wind", "act"]:
				return ["beam", 0]
			if absf(e.vx) > 5:
				return ["walk", int(tt * 10) % 4]
			return ["idle", int(tt * 2.5) % 2]
		"shark":
			if e.state == "wind":
				return ["bite", 0]
			if e.state == "act":
				return ["bite", 1]
			return ["swim", int(tt * 8) % 4]
		"squid":
			if e.move == "gaze" and e.state == "wind":
				return ["gaze", 0]
			if e.move == "ink" and e.state in ["wind", "act"]:
				return ["ink", 0]
			return ["swim", int(tt * 5) % 4]
		"orca":
			if e.state in ["wind", "act"]:
				return [e.move, 0 if e.state == "wind" else 1]
			return ["swim", int(tt * 5) % 4]
		"octopus":
			if e.state == "act":
				return ["flurry", int(tt * 12) % 2]
			if e.state == "grab" or e.state == "wind":
				return ["grab", 0]
			if absf(e.vx) > 5:
				return ["scurry", int(tt * 14) % 4]
			return ["idle", int(tt * 2.5) % 2]
	return ["idle", 0]


func drawAbyssMob(x: Ctx, e, sx: float, sy: float) -> void:
	var T: Dictionary = e.T
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	if X < -140 or X > VW + 140 or Y < -100 or Y > VH + 140:
		return
	var setName = _mobSet(e)
	var Sset = Assets.mob_set(setName)
	if Sset.is_empty():
		return
	if e.elite and e.state != "dead" and randf() < 0.5:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h), 0, -20, 0.6, "#2a0838" if randf() < 0.5 else "#9a3ad8", 0, 2)
	if e.shiny and e.state != "dead" and randf() < 0.25:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h + 6), 0, -14, 0.5, ["#ffffff", "#fff6b0", "#ff9ecf"][rint(0, 2)], 0, 1)
	var kf = _abyssKey(e)
	var k: String = kf[0] if Sset.keys.has(kf[0]) else Sset.keys.keys()[0]
	var nf: int = maxi(1, int(Sset.keys.get(k, 1)))
	var f: int = kf[1] % nf
	var dim: Dictionary = Sset.dim
	var sc: float = e.data.get("scale", 1.0) if e.elite else 1.0
	x.save()
	x.translate(X, Y)
	if e.state == "dead":
		var kk = maxf(0, 1 - e.deadT / 0.45)
		x.globalAlpha = kk
		x.scale(1 + (1 - kk) * 0.6, maxf(0.001, kk))
	if e.state == "wind":
		x.translate(roundf(sin(e.t * 60)), 0)
	if e.spawnT > 0:
		var kk = maxf(0.001, 1 - e.spawnT / 0.5)
		x.scale(kk, kk)
	if T.habitat == "swim" and e.type != "squid" and e.state != "dead":
		# fish tilt with the way they swim
		var tilt = clampf(e.vy / (absf(e.vx) + 60), -0.6, 0.6) * 0.5
		x.translate(0, -e.h / 2)
		x.rotate(tilt * (1 if e.face > 0 else -1))
		x.translate(0, e.h / 2)
	if e.face < 0:
		x.scale(-1, 1)
	if sc != 1.0:
		x.scale(sc, sc)
	x.drawFrame(Assets.mob_strip(setName, k), nf, f, -dim.ax, -dim.ay, dim.w, dim.h)
	x.restore()
	# health bar, level, alerts (as for every monster)
	if e.state != "dead" and (e.showBar > 0 or e.aggro):
		var bw = 22.0 if e.w < 60 else 34.0
		var bx = X - bw / 2
		var by: float = Y - e.h - 12
		x.fillStyle = "#1a1030"; x.fillRect(bx - 1, by - 1, bw + 2, 4)
		x.fillStyle = "#5b2335"; x.fillRect(bx, by, bw, 2)
		x.fillStyle = "#ff5d73"; x.fillRect(bx, by, maxf(0, roundf(bw * e.hp / e.maxHp)), 2)
		var dl: int = e.lv - CH().level
		x.font = FONT
		textOutline(x, "Lv %d" % e.lv, X, by - 3, "#ff8a9a" if dl >= 3 else ("#b8c0d0" if dl <= -3 else "#ffffff"))
	if e.bang > 0 and e.state != "dead":
		textOutline(x, "!", X, Y - e.h - 16, "#ffd23a")
	if e.shiny and e.state != "dead":
		textOutline(x, "*", X + e.w / 2 + 4, Y - e.h - 8, "#fff6b0")
	if e.elite and e.state != "dead":
		x.font = FONT
		textOutline(x, "ELITE %s" % T.name, X, Y - e.h - 26, "#e8b8ff")
	# a squid's eyes glowing before its gaze
	if e.type == "squid" and e.move == "gaze" and e.state == "wind":
		var gk = clampf(e.t / 1.05, 0, 1)
		var gx = X
		var gy = Y - 28 * sc
		var g = x.createRadialGradient(gx, gy, 1, gx, gy, 26)
		g.addColorStop(0, rgba(255, 106, 240, 0.5 * gk)); g.addColorStop(1, rgba(255, 106, 240, 0))
		x.fillStyle = g; x.beginPath(); x.arc(gx, gy, 26, 0, TAU); x.fill()


# ================================================================ The Dreamer

func drawDreamerHead(x: Ctx, sx: float, sy: float) -> void:
	var e = _dreamer()
	if e == null:
		return
	var D: Dictionary = e.data
	var off: float = D.sink
	var X = e.x - sx
	var FY = M.floorY - sy + off
	var t = realTime
	var bob = sin(t * 0.8) * 1.5
	var head = Assets.tex("boss/dreamer_head.png")
	if e.hurtFlash > 0:
		x.globalAlpha = 1
	x.drawImage(head, roundf(X - 140), roundf(FY - 170 + bob), 280, 170)
	# the eyes
	var eye = Assets.tex("boss/dreamer_eye.png")
	for i in 2:
		var s = -1 if i == 0 else 1
		var ex = X + s * DR_EYE_DX
		var ey = FY - DR_EYE_Y - 11 + bob
		var fr = 0
		if e.state == "dead":
			fr = 3 if e.dying else 2
		elif D.gaze > 0.15:
			fr = 1
		elif D.eyeHurt[i] > 0:
			fr = 3
		elif D.blink < 0:
			fr = 2
		if D.gaze > 0:
			var g = x.createRadialGradient(ex, ey, 2, ex, ey, 20 + 30 * D.gaze)
			g.addColorStop(0, rgba(255, 106, 240, 0.7 * D.gaze)); g.addColorStop(1, rgba(255, 106, 240, 0))
			x.fillStyle = g; x.beginPath(); x.arc(ex, ey, 20 + 30 * D.gaze, 0, TAU); x.fill()
		x.drawFrame(eye, 4, fr, roundf(ex - 16), roundf(ey - 11), 32, 22)
		# the pupil follows you
		if fr == 0 and e.state != "dead":
			var a = atan2((P.y - 20 - sy) - ey, (P.x - sx) - ex)
			x.fillStyle = "#12040a"
			x.fillRect(roundf(ex + cos(a) * 3) - 1, roundf(ey + sin(a) * 2) - 3, 2, 6)
	# the mouth: closed, gaping while it inhales, chewing
	var mouth = Assets.tex("boss/dreamer_mouth.png")
	var mo = 1 if (D.mouth > 0.5 or (D.chew > 0 and fmod(D.chew, 0.12) < 0.06)) else 0
	var ms = 1.0 + (0.15 * D.mouth if D.mouth > 0 else 0.0)
	x.drawFrame(mouth, 2, mo, roundf(X - 30 * ms), roundf(FY - DR_MOUTH_Y - 24 * ms + bob), 60 * ms, 48 * ms)


## a tentacle: a tapered curve of suckered flesh from behind the floor to its tip
func _tentacle(x: Ctx, a: Vector2, c: Vector2, b: Vector2, w0: float, flash: bool) -> void:
	var n = 18
	var pts = []
	for i in n + 1:
		var u = i / float(n)
		pts.append(a * (1 - u) * (1 - u) + c * 2 * u * (1 - u) + b * u * u)
	for i in n + 1:
		var u = i / float(n)
		var r = lerpf(w0, 1.2, u)
		var col = css(DR_COL.skin).lerp(css(DR_COL.tip), u * u)
		if flash:
			col = col.lerp(Color.WHITE, 0.6)
		x.fillStyle = col
		x.beginPath(); x.arc(pts[i].x, pts[i].y, r, 0, TAU); x.fill()
	for i in range(2, n - 1, 2):
		var u = i / float(n)
		var dvec: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		var nrm = Vector2(-dvec.y, dvec.x)
		var r = lerpf(w0, 1.2, u)
		x.fillStyle = DR_COL.sucker
		x.fillRect(roundf(pts[i].x + nrm.x * r * 0.6), roundf(pts[i].y + nrm.y * r * 0.6), 1, 1)
		x.fillStyle = DR_COL.hi
		x.fillRect(roundf(pts[i].x - nrm.x * r * 0.5), roundf(pts[i].y - nrm.y * r * 0.5), 1, 1)


func drawDreamerTents(x: Ctx, e, sx: float, sy: float) -> void:
	var D: Dictionary = e.data
	var t = realTime
	var off: float = D.sink
	for T in D.tents:
		if T.h <= 1 and T.state in ["peek", "sink"]:
			continue
		var base = Vector2(T.bx - sx, M.floorY + 24 - sy + off)
		var tip = _tentTip(e, T) - Vector2(sx, sy)
		var ctrl: Vector2
		match T.state:
			"whip":
				var k = clampf(T.t / 0.1, 0, 1)
				ctrl = Vector2(lerpf(base.x, tip.x, 0.5), minf(base.y, tip.y) - 140 * (1 - k) - 20)
			"lie":
				ctrl = Vector2(lerpf(base.x, tip.x, 0.5), minf(base.y, tip.y) - 20)
			"grab":
				ctrl = Vector2(lerpf(base.x, tip.x, 0.3), tip.y - 40)
			_:
				ctrl = Vector2(base.x + sin(t * 1.1 + T.bx) * 14, lerpf(base.y, tip.y, 0.5))
		_tentacle(x, base, ctrl, tip, 7.0 if T.state in ["whip", "lie", "grab"] else 5.5, T.part.flash > 0)
		# the warning: where it's about to strike
		if T.state == "rise":
			var a = 0.35 + 0.3 * sin(t * 30)
			x.fillStyle = rgba(255, 58, 106, a)
			x.beginPath(); x.ellipse(T.tx - sx, T.ty - sy, 16, 3, 0, 0, TAU); x.fill()
			x.fillStyle = rgba(255, 58, 106, a * 0.25)
			x.fillRect(T.tx - sx - 12, T.ty - sy - 60, 24, 60)
		if T.state == "grab" and D.get("t", 0.0) < 0.65:
			x.strokeStyle = rgba(194, 92, 255, 0.6 + 0.3 * sin(t * 25))
			x.lineWidth = 1
			x.beginPath(); x.ellipse(T.tx - sx, T.ty - sy, 18, 4, 0, 0, TAU); x.stroke()


func drawKeyDrop(x: Ctx, X: float, Y: float, tt: float) -> void:
	var bob = roundf(sin(tt * 2.5) * 2)
	var g = x.createRadialGradient(X, Y - 10 + bob, 1, X, Y - 10 + bob, 18)
	g.addColorStop(0, rgba(194, 92, 255, 0.55 + 0.2 * sin(tt * 4))); g.addColorStop(1, rgba(194, 92, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y - 10 + bob, 18, 0, TAU); x.fill()
	x.drawImage(Assets.tex("items/dream_key.png"), X - 8, Y - 18 + bob, 16, 16)
	if randf() < 0.2:
		part(X + cam.x + rand(-8, 8), Y + cam.y - rand(4, 20), 0, -16, 0.7, "#ff6af0" if randf() < 0.5 else "#ffffff", 0, 1)


# ================================================================ light and dark

## multiplied over the world: the water darkens and cools the deeper you go
func abyssTint(x: Ctx) -> void:
	if M.get("theme") != "abyss":
		return
	var d: float = M.get("depth", 0.0)
	var col: Color
	if seaTop() > -1e8:
		col = css("#f0dcea")
	elif M.get("boss"):
		col = css("#7a6a9a")
	elif M.get("dark"):
		col = css("#4a4468")
	else:
		col = css("#a8a8e0").lerp(css("#6c74b4"), (d - 0.35) / 0.35)
	x.fillStyle = col
	x.fillRect(0, 0, VW, VH)


## drawn over the world: rune and seaweed light in the dark, the gaze's flash, a glow round the hero
func abyssOverlay(x: Ctx) -> void:
	var sx = cam.x
	var sy = cam.y
	var t = realTime
	if M.get("theme") == "abyss":
		var dark: bool = M.get("dark", false) or M.get("depth", 0.0) >= 0.7
		for g in mapGlows(mapId):
			var X: float = g[0] - sx
			var Y: float = g[1] - sy
			if X < -30 or X > VW + 30 or Y < -30 or Y > VH + 30:
				continue
			var r: float = g[2] * (1.8 if dark else 1.2)
			var c = css(g[3])
			var a = (0.32 if dark else 0.16) * (0.75 + 0.25 * sin(t * 1.7 + g[0] * 0.13))
			var gr = x.createRadialGradient(X, Y, 0, X, Y, r)
			gr.addColorStop(0, Color(c, a)); gr.addColorStop(1, Color(c, 0))
			x.fillStyle = gr
			x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()
		if dark:
			var px = P.x - sx
			var py = P.y - sy - 22
			var pg = x.createRadialGradient(px, py, 4, px, py, 46)
			pg.addColorStop(0, rgba(170, 140, 230, 0.13)); pg.addColorStop(1, rgba(170, 140, 230, 0))
			x.fillStyle = pg
			x.beginPath(); x.arc(px, py, 46, 0, TAU); x.fill()
			# monsters' eyes catch the rune light: a faint red glow so you can see what's coming
			for e in slimes:
				if e.state == "dead" or e.bossPart or e.boss:
					continue
				var mx = e.x - sx
				var my = e.y - sy - e.h * 0.55
				if mx < -60 or mx > VW + 60 or my < -60 or my > VH + 60:
					continue
				var mr = maxf(e.w, e.h) * 0.9 + 8
				var mg = x.createRadialGradient(mx, my, 2, mx, my, mr)
				mg.addColorStop(0, rgba(255, 70, 120, 0.14)); mg.addColorStop(1, rgba(255, 70, 120, 0))
				x.fillStyle = mg
				x.beginPath(); x.arc(mx, my, mr, 0, TAU); x.fill()
	if gazeFlash > 0:
		x.fillStyle = rgba(255, 106, 240, gazeFlash * 0.45)
		x.fillRect(0, 0, VW, VH)
	if P.confuseT > 0:
		var k = minf(1, P.confuseT / 1.0)
		x.fillStyle = rgba(255, 150, 255, 0.05 * k + 0.03 * k * sin(t * 4))
		x.fillRect(0, 0, VW, VH)
	if P.blindT > 0:
		var k = minf(1, P.blindT / 0.8)
		var px = P.x - sx
		var py = P.y - sy - 20
		var g = x.createRadialGradient(px, py, 30, px, py, 220)
		g.addColorStop(0, rgba(6, 2, 10, 0)); g.addColorStop(1, rgba(6, 2, 10, 0.7 * k))
		x.fillStyle = g
		x.fillRect(0, 0, VW, VH)
