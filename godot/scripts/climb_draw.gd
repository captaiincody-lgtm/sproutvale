extends "res://scripts/tank_draw.gd"
## Sproutvale, part 7¾: drawing the climb to the volcano. Cold skies over the foothills, the
## blizzard on Whiteout Ridge, the dark of the ice cave, the burning sky over Glamrax's Gate; the six
## climb monsters, King Yeti on his throne with his sword and glowing pendant, and the hazards.

var _cGlows := {}   # map id → [[x, y, r, colour]…] (from art/climb/maps/<id>.json)


func climbGlows(id: String) -> Array:
	if not _cGlows.has(id):
		var path = "res://art/climb/maps/%s.json" % id
		_cGlows[id] = Assets._json(path).get("glows", []) if FileAccess.file_exists(path) else []
	return _cGlows[id]


# ================================================================ backgrounds

func drawClimbBack(x: Ctx, sx: float, sy: float, dt: float, D: Dictionary) -> void:
	var theme: String = M.get("theme")
	var t = realTime
	match theme:
		"cave":
			var g = x.createLinearGradient(0, 0, 0, VH)
			g.addColorStop(0, "#05070e"); g.addColorStop(1, "#0e1424")
			x.fillStyle = g
			x.fillRect(0, 0, VW, VH)
		"peak":
			# an abyssal sky over the volcano, purple like the opening cutscene: black above, magenta at the horizon
			var g = x.createLinearGradient(0, 0, 0, VH)
			g.addColorStop(0, "#0a0418"); g.addColorStop(0.45, "#3a0f4a"); g.addColorStop(0.8, "#8a2a6a"); g.addColorStop(1, "#d84ab0")
			x.fillStyle = g
			x.fillRect(0, 0, VW, VH)
			var mx = VW * 0.7 - sx * 0.02
			x.fillStyle = rgba(232, 216, 255, 0.16); x.beginPath(); x.arc(mx, 62, 34, 0, TAU); x.fill()
			x.fillStyle = rgba(232, 216, 255, 0.45); x.beginPath(); x.arc(mx, 62, 16, 0, TAU); x.fill()
			# storm clouds racing past
			for i in 9:
				var cx = fmod(hsh(i * 3.3) * (VW + 200) - t * (30 + hsh(i) * 40) - sx * 0.1, VW + 200)
				if cx < 0:
					cx += VW + 200
				cx -= 100
				var cy = 20 + hsh(i * 7.1) * 70
				x.fillStyle = rgba(26, 8, 34, 0.5)
				x.beginPath(); x.ellipse(cx, cy, 60 + hsh(i) * 40, 9 + hsh(i * 2) * 6, 0, 0, TAU); x.fill()
		_:
			drawSky(x, D)
			drawClouds(x, D, dt)
			# the cold: a pale wash over the sky (thick and white in the blizzard)
			x.fillStyle = rgba(214, 226, 244, 0.55 if theme == "snow" else 0.22)
			x.fillRect(0, 0, VW, VH)
	var floorScr = groundAt(sx + VW / 2.0) - sy
	var farY = roundf(floorScr * 0.35 + VH * 0.42 - 120)
	var midY = roundf(floorScr * 0.6 + VH * 0.4 - 90)
	if theme == "cave":
		farY = roundf(floorScr * 0.4 + VH * 0.3 - 150)
		midY = roundf(floorScr * 0.65 + VH * 0.35 - 110)
	var fo = -fmod(roundf(sx * 0.15), VW * 2.0)
	var mo = -fmod(roundf(sx * 0.4), VW * 2.0)
	var under = {"climb": "#3a4458", "snow": "#c8d4e4", "cave": "#06080e", "peak": "#140820"}[theme]
	for L in [[theme + "_far", fo, farY, 0.9], [theme + "_mid", mo, midY, 1.0]]:
		var tex = Assets.tex("sky/%s.png" % L[0])
		if tex == null:
			continue
		x.globalAlpha = L[3]
		var w = tex.get_width() / 2.0
		var h = tex.get_height() / 2.0
		x.drawImage(tex, L[1], L[2], w, h)
		x.drawImage(tex, L[1] + w, L[2], w, h)
		x.globalAlpha = 1
	if midY + 90 < VH:
		x.fillStyle = under
		x.fillRect(0, midY + 89, VW, VH - midY - 89)


## between the painted map and the monsters: the bone throne, and the sword stuck in the floor
func drawClimbMid(x: Ctx, sx: float, sy: float) -> void:
	if mapId != "climb4":
		return
	if not M.get("collapsed"):
		var tx: float = M.get("throneX", 566)
		var th = Assets.tex("boss/throne.png")
		if th != null:
			x.drawImage(th, roundf(tx - 50 - sx), roundf(groundAt(tx) - 110 - sy), 100, 110)
	# the big stalactites he throws you into
	var st = Assets.tex("boss/stalactite.png")
	if st != null:
		for cx in YT_STALS:
			x.drawImage(st, roundf(cx - YT_STAL_W / 2 - sx), roundf(ceilAt(cx) - 6 - sy), YT_STAL_W, YT_STAL_LEN + 6)
	if YS.get("state", "") == "ground":
		_swordInFloor(x, YS.x, YS.y, sx, sy)
	if not escapeGate.is_empty():
		_portalSwirl(x, escapeGate.x - sx, escapeGate.y - sy, minf(1, escapeGate.t * 2))
		escapeGate.t += _rdt


## the King's sword standing point-down in the floor: only the part above the ground shows
func _swordInFloor(x: Ctx, gx: float, gripY: float, sx: float, sy: float) -> void:
	var tex = Assets.tex("boss/yeti_sword.png")
	if tex == null:
		return
	var A = yetiArt()
	var grip: Array = A.get("swordGrip", [34, 28])
	var vis = clampf(groundAt(gx) - gripY, 0, 130)   # how much blade is above the floor
	var srcW = minf(tex.get_width(), grip[0] + vis * 2 + 0.0)
	x.save()
	x.translate(roundf(gx - sx), roundf(gripY - sy))
	x.rotate(PI / 2)
	x.drawImageRegion(tex, 0, 0, srcW, tex.get_height(), -grip[0] / 2.0, -grip[1] / 2.0, srcW / 2.0, tex.get_height() / 2.0)
	x.restore()
	var a = 0.25 + 0.15 * sin(realTime * 3)
	var g = x.createRadialGradient(gx - sx, gripY - sy, 1, gx - sx, gripY - sy, 26)
	g.addColorStop(0, rgba(122, 240, 255, a)); g.addColorStop(1, rgba(122, 240, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(gx - sx, gripY - sy, 26, 0, TAU); x.fill()


func _portalSwirl(x: Ctx, X: float, Y: float, k: float) -> void:
	var t = realTime
	var gl = x.createRadialGradient(X, Y - 22, 2, X, Y - 22, 40 * k)
	gl.addColorStop(0, rgba(220, 255, 255, 0.9)); gl.addColorStop(0.4, rgba(122, 240, 255, 0.5)); gl.addColorStop(1, rgba(122, 240, 255, 0))
	x.fillStyle = gl; x.beginPath(); x.arc(X, Y - 22, 40 * k, 0, TAU); x.fill()
	for i in 28:
		var a = t * 4 + i / 28.0 * TAU
		var r = (18 + sin(t * 6 + i) * 2) * k
		x.fillStyle = "#7af0ff" if i % 3 else "#ffffff"
		x.fillRect(roundf(X + cos(a) * r * 0.7), roundf(Y - 22 + sin(a) * r * 1.3), 2, 2)


# ================================================================ the climb's monsters

func _climbKey(e) -> Array:
	var tt: float = e.t
	var D: Dictionary = e.data
	if e.state == "dead":
		return ["dead", 0]
	if e.flash > 0:
		return ["white", 0]
	if e.state == "hurt":
		return ["hurt", 0]
	match e.type:
		"boulder":
			if e.state == "wind":
				return ["float", int(tt * 6) % 2]
			if e.state == "act":
				return ["launch", 0]
			if absf(e.vx) > 5:
				return ["roll", int(fposmod(D.get("spin", 0.0), TAU) / TAU * 4) % 4]
			return ["idle", 1 if fmod(tt, 3.0) > 2.8 else 0]
		"lizard":
			if e.move == "whip" and e.state == "wind":
				return ["whip", 0]
			if e.move == "whip" and e.state == "act":
				return ["whip", 1]
			if e.move == "leap" and e.state == "act":
				return ["leap", 0]
			if absf(e.vx) > 5:
				return ["walk", int(tt * 9) % 4]
			return ["idle", int(tt * 2.5) % 2]
		"golem":
			if e.state == "wind":
				return ["wind", 0]
			if e.state == "act" or (e.state == "recover" and tt < 0.3):
				return ["smash", 0]
			if absf(e.vx) > 3:
				return ["walk", int(tt * 5) % 4]
			return ["idle", int(tt * 1.5) % 2]
		"warlock":
			if e.state == "blink":
				return ["blink", 0]
			if e.state in ["wind", "act"]:
				return ["cast", int(tt * 6) % 2]
			return ["idle", int(tt * 2) % 2]
		"yeti":
			if e.move == "swipe" and e.state == "wind":
				return ["swipe", 0]
			if e.move == "swipe" and e.state == "act":
				return ["swipe", 1]
			if e.move == "slam" and (e.state == "act" or e.state == "wind"):
				return ["leap", 0]
			if e.state == "recover" and e.move == "slam" and tt < 0.35:
				return ["slam", 0]
			if absf(e.vx) > 5:
				return ["run", int(tt * 12) % 4]
			return ["idle", int(tt * 2) % 2]
		"sword":
			return ["fly", int(tt * 4) % 2]
	return ["idle", 0]


func drawAbyssMob(x: Ctx, e, sx: float, sy: float) -> void:
	if e.T.get("ai") != "climb":
		super.drawAbyssMob(x, e, sx, sy)
		return
	var T: Dictionary = e.T
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	if X < -140 or X > VW + 140 or Y < -140 or Y > VH + 160:
		return
	var setName = _mobSet(e)
	var Sset = Assets.mob_set(setName)
	if Sset.is_empty():
		x.fillStyle = "#c8d0e0"; x.fillRect(X - e.w / 2, Y - e.h, e.w, e.h)   # art not baked yet
		return
	if e.elite and e.state != "dead" and randf() < 0.5:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h), 0, -20, 0.6, "#2a0838" if randf() < 0.5 else "#9a3ad8", 0, 2)
	if e.shiny and e.state != "dead" and randf() < 0.25:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h + 6), 0, -14, 0.5, ["#ffffff", "#fff6b0", "#ff9ecf"][rint(0, 2)], 0, 1)
	var kf = _climbKey(e)
	var k: String = kf[0] if Sset.keys.has(kf[0]) else Sset.keys.keys()[0]
	var nf: int = maxi(1, int(Sset.keys.get(k, 1)))
	var f: int = kf[1] % nf
	var dim: Dictionary = Sset.dim
	var sc: float = e.data.get("scale", 1.0) if e.elite else 1.0
	var D: Dictionary = e.data
	# a lizardman's whip: a lash from its hand
	if e.type == "lizard" and D.get("whip", 0.0) > 0 and e.state != "dead":
		_lash(x, e, X, Y, sc)
	x.save()
	x.translate(X, Y)
	if e.state == "dead":
		var kk = maxf(0, 1 - e.deadT / 0.45)
		x.globalAlpha = kk
		x.scale(1 + (1 - kk) * 0.3, maxf(0.001, kk))
	if e.state == "wind" and e.type != "sword":
		x.translate(roundf(sin(e.t * 60) * 0.8), 0)
	if e.spawnT > 0:
		var kk = maxf(0.001, 1 - e.spawnT / 0.5)
		x.scale(kk, kk)
	if e.type == "warlock" and e.state == "blink":
		x.globalAlpha = 0.35 + 0.65 * absf(cos(e.t * 9))
	if e.type == "sword":
		x.translate(0, -e.h / 2 * sc)
		x.rotate(D.get("ang", 0.0) * (1 if e.face > 0 else -1))
		x.translate(0, e.h / 2 * sc)
	if e.type == "lizard" and k == "leap":
		x.translate(0, -e.h / 2 * sc)
		x.rotate(D.get("spin", 0.0))
		x.translate(0, e.h / 2 * sc)
	if e.face < 0:
		x.scale(-1, 1)
	if sc != 1.0:
		x.scale(sc, sc)
	if e.type == "sword":
		x.drawFrame(Assets.mob_strip(setName, k), nf, f, -dim.ax, -dim.ay - e.T.bh / 2.0, dim.w, dim.h)
	else:
		x.drawFrame(Assets.mob_strip(setName, k), nf, f, -dim.ax, -dim.ay, dim.w, dim.h)
	x.restore()
	if e.type == "golem" and e.state != "dead":
		# its gemstone eyes glow in the snow
		var g = x.createRadialGradient(X + e.face * 6 * sc, Y - 48 * sc, 1, X + e.face * 6 * sc, Y - 48 * sc, 12 * sc)
		g.addColorStop(0, rgba(122, 240, 255, 0.35)); g.addColorStop(1, rgba(122, 240, 255, 0))
		x.fillStyle = g; x.beginPath(); x.arc(X + e.face * 6 * sc, Y - 48 * sc, 12 * sc, 0, TAU); x.fill()
	if e.type == "warlock" and e.state in ["wind", "act"]:
		var g = x.createRadialGradient(X + e.face * 10, Y - 40, 1, X + e.face * 10, Y - 40, 20)
		g.addColorStop(0, rgba(194, 92, 255, 0.55)); g.addColorStop(1, rgba(194, 92, 255, 0))
		x.fillStyle = g; x.beginPath(); x.arc(X + e.face * 10, Y - 40, 20, 0, TAU); x.fill()
	# health bar, level, alerts (as for every monster)
	if e.state != "dead" and (e.showBar > 0 or e.aggro):
		var bw = 22.0 if e.w < 36 else 34.0
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


func _lash(x: Ctx, e, X: float, Y: float, sc: float) -> void:
	var D: Dictionary = e.data
	var len_: float = (82.0 if e.move == "whip" else 70.0) * D.whip
	var ang: float = D.get("whipAng", 0.0)
	var hx = X + e.face * 8 * sc
	var hy = Y - 22 * sc
	var ex = hx + e.face * cos(ang) * len_
	var ey = hy + sin(ang) * len_
	var mx = (hx + ex) / 2
	var my = (hy + ey) / 2 + 6 * (1 - D.whip)
	x.strokeStyle = "#5a3418"; x.lineWidth = 1.6
	x.beginPath(); x.moveTo(hx, hy); x.quadraticCurveTo(mx, my, ex, ey); x.stroke()
	x.strokeStyle = "#8a5a2a"; x.lineWidth = 0.7
	x.beginPath(); x.moveTo(hx, hy - 0.5); x.quadraticCurveTo(mx, my - 0.5, ex, ey - 0.5); x.stroke()
	if D.whip > 0.95:
		x.fillStyle = "#fff6c0"
		x.fillRect(roundf(ex) - 1, roundf(ey) - 1, 2, 2)


# ================================================================ King Yeti

func drawYeti(x: Ctx, e, X: float, Y: float) -> void:
	var A = yetiArt()
	var D: Dictionary = e.data
	var k: String = D.get("anim", "idle")
	var nk: int = int(A.get("keys", {}).get(k, 0))
	if nk == 0:
		k = "idle"
		nk = maxi(1, int(A.get("keys", {}).get("idle", 1)))
	var f: int = clampi(int(D.get("f", 0)), 0, nk - 1)
	var tex = Assets.tex("boss/yeti_%s.png" % k)
	var fw: float = A.w / 2.0
	var fh: float = A.h / 2.0
	var mod = Color.WHITE
	if e.hurtFlash > 0:
		mod = Color(1.8, 1.8, 1.8)
	if e.enraged and e.state != "dead":
		mod = mod * Color(1.0, 0.85, 0.85)
	var alpha = 1.0
	if e.state == "dead" and not e.dying and k == "fallen":
		alpha = clampf(1.0 - (e.deadT - 1.6) / 0.8, 0, 1)
	x.save()
	x.globalAlpha = alpha
	x.translate(X, Y)
	if e.face < 0:
		x.scale(-1, 1)
	if tex != null:
		x.drawFrame(tex, nk, f, -A.ax / 2.0, -A.ay / 2.0, fw, fh, mod)
	else:
		x.fillStyle = "#e8eef6"; x.fillRect(-30, -108, 60, 108)
	x.restore()
	# the sword in his hand
	if D.get("sword", false) and e.state != "dead":
		var h = yetiHand(e)
		_bigSword(x, h.x - cam.x, h.y - cam.y, h.ang, 1.0, alpha)
	# the pendant glows at his throat
	var n = yetiNeck(e) - Vector2(cam.x, cam.y)
	if e.state != "dead" or e.dying:
		var a = 0.35 + 0.2 * sin(realTime * 4)
		var g = x.createRadialGradient(n.x, n.y, 1, n.x, n.y, 14)
		g.addColorStop(0, rgba(160, 250, 255, a + 0.3)); g.addColorStop(1, rgba(122, 240, 255, 0))
		x.fillStyle = g; x.beginPath(); x.arc(n.x, n.y, 14, 0, TAU); x.fill()
	x.globalAlpha = 1


## the King's sword: grip at (X, Y), pointing along `ang`
func _bigSword(x: Ctx, X: float, Y: float, ang: float, sc := 1.0, alpha := 1.0) -> void:
	var tex = Assets.tex("boss/yeti_sword.png")
	var A = yetiArt()
	var grip: Array = A.get("swordGrip", [34, 28])
	x.save()
	x.globalAlpha = alpha
	x.translate(roundf(X), roundf(Y))
	x.rotate(ang)
	x.scale(sc, sc)
	if tex != null:
		x.drawImage(tex, -grip[0] / 2.0, -grip[1] / 2.0, tex.get_width() / 2.0, tex.get_height() / 2.0)
	else:
		x.fillStyle = "#cfe8ff"; x.fillRect(0, -3, YT_SWORD_LEN, 6)
	x.restore()
	x.globalAlpha = 1


# ================================================================ in front of everyone

func drawClimbFront(x: Ctx, sx: float, sy: float, dt: float) -> void:
	var t = realTime
	# the King's sword when it's out of his hand
	if not YS.is_empty() and YS.get("state", "") in ["thrown", "stuck", "impaled", "free"]:
		if YS.state == "thrown":
			# a streak behind it at lightning speed
			x.strokeStyle = rgba(190, 250, 255, 0.5); x.lineWidth = 3
			x.beginPath(); x.moveTo(YS.x - sx - YS.vx * 0.05, YS.y - sy - YS.vy * 0.05); x.lineTo(YS.x - sx, YS.y - sy); x.stroke()
		if YS.state == "free":
			var a = 0.25 + 0.15 * sin(t * 6)
			var mx = YS.x + cos(YS.ang) * YT_SWORD_LEN * 0.5 - sx
			var my = YS.y + sin(YS.ang) * YT_SWORD_LEN * 0.5 - sy
			var g = x.createRadialGradient(mx, my, 2, mx, my, 70)
			g.addColorStop(0, rgba(122, 240, 255, a)); g.addColorStop(1, rgba(122, 240, 255, 0))
			x.fillStyle = g; x.beginPath(); x.arc(mx, my, 70, 0, TAU); x.fill()
		_bigSword(x, YS.x - sx, YS.y - sy, YS.ang)
	# the point of the stalactite, through the hero
	if P.held != null and P.held.get("kind") == "yeti" and P.held.get("phase") == "stuck":
		var st = Assets.tex("boss/stalactite.png")
		if st != null:
			var cx: float = P.held.sx
			var top = ceilAt(cx) - 6
			var full = YT_STAL_LEN + 6
			var cut = full * 0.5
			var tw = st.get_width()
			var th = st.get_height()
			x.drawImageRegion(st, 0, th * 0.5, tw, th * 0.5, roundf(cx - YT_STAL_W / 2 - sx), roundf(top + cut - sy), YT_STAL_W, full - cut)
			x.fillStyle = "#c81e2e"
			x.fillRect(roundf(cx - 1 - sx), roundf(top + full - 4 - sy), 2, 4)
	# King Yeti's pendant held high while it tears the portal open, its beam reaching for the spot
	if not escapeGate.is_empty() and not escapeGate.has("leap"):
		var k = minf(1, escapeGate.t * 1.5)
		var hx = heroHead.x - sx + P.face * 3
		var hy = heroHead.y - sy - 16 - 4 * k
		var tt = realTime
		var gr = x.createRadialGradient(hx, hy, 1, hx, hy, 34 * k + 2)
		gr.addColorStop(0, rgba(220, 255, 255, 0.8)); gr.addColorStop(1, rgba(122, 240, 255, 0))
		x.fillStyle = gr; x.beginPath(); x.arc(hx, hy, 34 * k + 2, 0, TAU); x.fill()
		# light rays turning around it
		for i in 8:
			var a = tt * 1.5 + i * TAU / 8
			x.strokeStyle = rgba(190, 250, 255, 0.35 * k); x.lineWidth = 1
			x.beginPath(); x.moveTo(hx + cos(a) * 8, hy + sin(a) * 8); x.lineTo(hx + cos(a) * (22 + 10 * k), hy + sin(a) * (22 + 10 * k)); x.stroke()
		# the chain down to the raised hand
		x.strokeStyle = rgba(230, 240, 255, 0.9); x.lineWidth = 1
		x.beginPath(); x.moveTo(hx, hy + 6); x.lineTo(hx - P.face * 2, hy + 14); x.stroke()
		var tex = Assets.tex("items/yeti_pendant.png")
		if tex != null:
			x.drawImage(tex, roundf(hx - 7), roundf(hy - 7), 14, 14)
		# the beam to where the portal opens
		if escapeGate.t > 0.4:
			var bk = minf(1, (escapeGate.t - 0.4) * 2.5)
			var gx = escapeGate.x - sx
			var gy = escapeGate.y - sy - 22
			x.strokeStyle = rgba(122, 240, 255, 0.5 * bk); x.lineWidth = 5
			x.beginPath(); x.moveTo(hx, hy); x.lineTo(lerpf(hx, gx, bk), lerpf(hy, gy, bk)); x.stroke()
			x.strokeStyle = rgba(255, 255, 255, 0.9 * bk); x.lineWidth = 1.5
			x.beginPath(); x.moveTo(hx, hy); x.lineTo(lerpf(hx, gx, bk), lerpf(hy, gy, bk)); x.stroke()
	# the hero's Impaling Blade
	if not pBlade.is_empty():
		_bigSword(x, pBlade.x - sx - pBlade.face * 20, pBlade.y - sy, 0.0 if pBlade.face > 0 else PI, 0.55)
	# falling stalactites (and their shadows)
	var stal = Assets.tex("boss/stalactite.png")
	for s in stalFalls:
		if s.t < 0:
			continue
		var X = s.x - sx
		var g = groundAt(s.x) - sy
		var len_ = 32.0 if s.big else 22.0
		if s.t < s.warn:
			var a = 0.3 + 0.3 * sin(t * 30)
			x.fillStyle = rgba(10, 14, 30, a)
			x.beginPath(); x.ellipse(X, g, 8 if s.big else 6, 2, 0, 0, TAU); x.fill()
		var Y = s.y - sy
		var w = len_ * 0.4
		if stal != null:
			x.drawImage(stal, roundf(X - w / 2), roundf(Y - len_), w, len_)
		else:
			x.fillStyle = "#a8b8d0"
			x.beginPath(); x.moveTo(X - w / 2, Y - len_); x.lineTo(X + w / 2, Y - len_); x.lineTo(X, Y); x.closePath(); x.fill()
	# spells and boulders
	var bt = Assets.tex("boss/boulder.png")
	for s in climbShots:
		var X = s.x - sx
		var Y = s.y - sy
		match s.kind:
			"nova":
				var k = clampf(s.t / 0.95, 0, 1)
				if s.t < 0.95:
					x.strokeStyle = rgba(194, 92, 255, 0.4 + 0.4 * sin(t * 24)); x.lineWidth = 1.2
					x.beginPath(); x.ellipse(X, Y, s.r * k, s.r * k * 0.22, 0, 0, TAU); x.stroke()
					x.fillStyle = rgba(194, 92, 255, 0.12 + k * 0.15)
					x.beginPath(); x.ellipse(X, Y, s.r, s.r * 0.22, 0, 0, TAU); x.fill()
				else:
					var kk = 1 - (s.t - 0.95) / 0.4
					x.fillStyle = rgba(230, 180, 255, 0.55 * kk)
					x.fillRect(X - s.r * 0.8, Y - 70 * kk, s.r * 1.6, 70 * kk)
					x.fillStyle = rgba(255, 255, 255, 0.6 * kk)
					x.fillRect(X - s.r * 0.3, Y - 80 * kk, s.r * 0.6, 80 * kk)
			"bolt":
				var g = x.createRadialGradient(X, Y, 1, X, Y, 7)
				g.addColorStop(0, rgba(255, 230, 255, 0.95)); g.addColorStop(1, rgba(194, 92, 255, 0))
				x.fillStyle = g; x.beginPath(); x.arc(X, Y, 7, 0, TAU); x.fill()
			"boulder":
				x.save()
				x.translate(roundf(X), roundf(Y))
				x.rotate(s.rot)
				if bt != null:
					x.drawImage(bt, -12, -11, 24, 22)
				else:
					x.fillStyle = "#6a6878"; x.beginPath(); x.arc(0, 0, 11, 0, TAU); x.fill()
				x.restore()
				if s.state == "rise":
					x.fillStyle = rgba(122, 240, 255, 0.25 + 0.15 * sin(t * 8 + s.go))
					x.beginPath(); x.arc(X, Y, 15, 0, TAU); x.fill()
	# held up by King Yeti, or the sword through you: nothing extra to draw (the hero shows it)
	var theme: String = M.get("theme", "")
	# the blizzard on Whiteout Ridge: snow streaming sideways, thick and fast
	if theme == "snow" or (theme == "climb" and true):
		var n = 280 if theme == "snow" else 40
		var spd = 320.0 if theme == "snow" else 60.0
		for i in n:
			var k = i * 1.37
			var par = 0.6 + hsh(k) * 0.8
			var px = fmod(hsh(k * 3.1) * (VW + 80) - t * spd * par - sx * par, VW + 80)
			if px < 0:
				px += VW + 80
			var py = fmod(hsh(k * 5.3) * (VH + 40) + t * (40 + hsh(k * 2.2) * 40) * par - sy * par * 0.6, VH + 40)
			if py < 0:
				py += VH + 40
			px -= 40
			py -= 20
			var a = 0.5 + hsh(k * 7) * 0.5
			x.fillStyle = rgba(250, 252, 255, a)
			if theme == "snow" and i % 3 == 0:
				x.fillRect(roundf(px), roundf(py), 4 * par, 1)
			else:
				x.fillRect(roundf(px), roundf(py), 1 if par < 1 else 2, 1 if par < 1 else 2)
	# the summit: magenta embers and ash on a roaring wind
	if theme == "peak":
		for i in 70:
			var k = i * 2.11
			var par = 0.5 + hsh(k) * 0.9
			var px = fmod(hsh(k * 3.7) * (VW + 80) - t * 160 * par - sx * par, VW + 80)
			if px < 0:
				px += VW + 80
			var py = fmod(hsh(k * 4.9) * (VH + 40) - t * (10 + hsh(k) * 20) - sy * par * 0.6 + sin(t * 2 + k) * 6, VH + 40)
			if py < 0:
				py += VH + 40
			px -= 40
			py -= 20
			if i % 4 == 0:
				x.fillStyle = rgba(255, 80 + hsh(k * 9) * 80, 230, 0.7 + 0.3 * sin(t * 8 + k))
				x.fillRect(roundf(px), roundf(py), 1, 1)
			else:
				x.fillStyle = rgba(60, 40, 70, 0.5)
				x.fillRect(roundf(px), roundf(py), 2 if par > 1 else 1, 1)
		# wind streaks
		for i in 10:
			var k = i * 5.3
			var px = fmod(hsh(k) * (VW + 200) - t * 420 - sx, VW + 200) - 100
			if px < -100:
				px += VW + 200
			var py = hsh(k * 2) * VH
			x.fillStyle = rgba(240, 210, 255, 0.12)
			x.fillRect(roundf(px), roundf(py), 40 + hsh(k * 3) * 50, 1)


func drawPendantDrop(x: Ctx, X: float, Y: float, tt: float) -> void:
	var bob = roundf(sin(tt * 2.5) * 2)
	var g = x.createRadialGradient(X, Y - 10 + bob, 1, X, Y - 10 + bob, 18)
	g.addColorStop(0, rgba(122, 240, 255, 0.55 + 0.2 * sin(tt * 4))); g.addColorStop(1, rgba(122, 240, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y - 10 + bob, 18, 0, TAU); x.fill()
	var tex = Assets.tex("items/yeti_pendant.png")
	if tex != null:
		x.drawImage(tex, X - 8, Y - 18 + bob, 16, 16)
	if randf() < 0.2:
		part(X + cam.x + rand(-8, 8), Y + cam.y - rand(4, 20), 0, -16, 0.7, "#7af0ff" if randf() < 0.5 else "#ffffff", 0, 1)


## the Yetibox: frosted white fur over ice-blue iron, a cyan gem for a clasp
func drawYetibox(x: Ctx, X: float, Y: float, tt: float) -> void:
	var g2 = 0.5 + 0.5 * sin(tt * 3)
	x.fillStyle = rgba(122, 240, 255, 0.28 * g2); x.fillRect(X - 13, Y - 21, 26, 22)
	x.fillStyle = "#0c1626"; x.fillRect(X - 10, Y - 16, 20, 16)
	x.fillStyle = "#dfe8f4"; x.fillRect(X - 9, Y - 15, 18, 14)
	x.fillStyle = "#ffffff"; x.fillRect(X - 9, Y - 15, 18, 3)
	x.fillStyle = "#0c1626"; x.fillRect(X - 9, Y - 10, 18, 1)
	x.fillStyle = "#4a7aa8"; x.fillRect(X - 6, Y - 15, 2, 14); x.fillRect(X + 4, Y - 15, 2, 14)
	x.fillStyle = rgba(122, 240, 255, 0.7 + 0.3 * g2); x.fillRect(X - 2, Y - 11, 4, 4)
	if randf() < 0.15:
		part(X + cam.x + rand(-10, 10), Y + cam.y - rand(4, 20), 0, -20, 0.6, "#7af0ff" if randf() < 0.6 else "#ffffff", 0, 1)


# ================================================================ light and cold

## multiplied over the world: cold blue on the mountain, deep blue-black in the cave, abyssal violet on the summit
func climbTint(x: Ctx, D: Dictionary) -> void:
	var theme: String = M.get("theme")
	var col: Color
	match theme:
		"cave":
			col = css("#98a4cc")
		"peak":
			col = css("#e8d0ff")
		_:
			var night: float = 1 - D.day
			col = mixc("#ffffff", "#5a6cb8", night * 0.62) * (css("#dfe8f8") if theme == "snow" else css("#e4eaf6"))
	x.fillStyle = col
	x.fillRect(0, 0, VW, VH)


func climbOverlay(x: Ctx) -> void:
	if yetiFlash > 0:
		x.fillStyle = rgba(255, 255, 255, minf(0.85, yetiFlash * 2.2))
		x.fillRect(0, 0, VW, VH)
	if not climbMap():
		return
	var sx = cam.x
	var sy = cam.y
	var t = realTime
	var theme: String = M.get("theme")
	for g in climbGlows(mapId if not M.get("collapsed") else "climb4_ruin"):
		var X: float = g[0] - sx
		var Y: float = g[1] - sy
		if X < -60 or X > VW + 60 or Y < -60 or Y > VH + 60:
			continue
		var r: float = g[2] * (1.6 if theme == "cave" else 1.2)
		var c = css(g[3])
		var a = (0.3 if theme == "cave" else 0.18) * (0.75 + 0.25 * sin(t * 1.7 + g[0] * 0.13))
		var gr = x.createRadialGradient(X, Y, 0, X, Y, r)
		gr.addColorStop(0, Color(c, a)); gr.addColorStop(1, Color(c, 0))
		x.fillStyle = gr
		x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()
	if not escapeGate.is_empty():
		# the pendant's portal lights up the whole collapsing room
		var X = escapeGate.x - sx
		var Y = escapeGate.y - sy - 22
		var k = minf(1, escapeGate.t * 2)
		var gg = x.createRadialGradient(X, Y, 4, X, Y, 120 * k + 1)
		gg.addColorStop(0, rgba(200, 255, 255, 0.55)); gg.addColorStop(1, rgba(122, 240, 255, 0))
		x.fillStyle = gg
		x.beginPath(); x.arc(X, Y, 120 * k + 1, 0, TAU); x.fill()
	if theme == "cave":
		var vg = x.createRadialGradient(VW * 0.5, VH * 0.52, VH * 0.36, VW * 0.5, VH * 0.52, VH * 0.95)
		vg.addColorStop(0, rgba(2, 3, 8, 0)); vg.addColorStop(1, rgba(2, 3, 8, 0.38))
		x.fillStyle = vg
		x.fillRect(0, 0, VW, VH)
		var px = P.x - sx
		var py = P.y - sy - 22
		var pg = x.createRadialGradient(px, py, 6, px, py, 90)
		pg.addColorStop(0, rgba(190, 220, 255, 0.3)); pg.addColorStop(1, rgba(190, 220, 255, 0))
		x.fillStyle = pg
		x.beginPath(); x.arc(px, py, 90, 0, TAU); x.fill()
		var e = _kingYeti()
		if e != null:
			var n = yetiNeck(e) - Vector2(sx, sy)
			var ng = x.createRadialGradient(n.x, n.y, 4, n.x, n.y, 80)
			ng.addColorStop(0, rgba(122, 240, 255, 0.22)); ng.addColorStop(1, rgba(122, 240, 255, 0))
			x.fillStyle = ng
			x.beginPath(); x.arc(n.x, n.y, 80, 0, TAU); x.fill()
		if not escapeGate.is_empty():
			var gx = escapeGate.x - sx
			var gy = escapeGate.y - sy - 22
			var eg = x.createRadialGradient(gx, gy, 4, gx, gy, 150)
			eg.addColorStop(0, rgba(160, 250, 255, 0.5)); eg.addColorStop(1, rgba(122, 240, 255, 0))
			x.fillStyle = eg
			x.beginPath(); x.arc(gx, gy, 150, 0, TAU); x.fill()
	elif theme == "snow":
		# the whiteout: the far distance disappears into the blizzard
		x.fillStyle = rgba(236, 242, 252, 0.2 + 0.08 * maxf(0, sin(t * 0.7)) + 0.06 * maxf(0, sin(t * 2.3)))
		x.fillRect(0, 0, VW, VH)
	elif theme == "peak":
		var vg = x.createRadialGradient(VW * 0.5, VH * 0.5, VH * 0.4, VW * 0.5, VH * 0.5, VH)
		vg.addColorStop(0, rgba(20, 2, 4, 0)); vg.addColorStop(1, rgba(20, 2, 4, 0.45))
		x.fillStyle = vg
		x.fillRect(0, 0, VW, VH)
