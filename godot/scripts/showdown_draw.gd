extends "res://scripts/glamrax_draw.gd"
## Sproutvale, the showdown drawn: Glamrax as the player, the five heroes as AI fighters with their own
## sprites, their shots and his spells, and the story cards of how he set his trap.

func introBusy() -> bool:
	return intro != null


func laughNow() -> void:
	_maniacalLaugh()


# ================================================================ Glamrax, played

func drawPlayer(x: Ctx, sx: float, sy: float, dt: float) -> void:
	if not GM.get("on", false):
		super.drawPlayer(x, sx, sy, dt)
		return
	var X = roundf(P.x - sx)
	var Y = roundf(P.y - sy)
	var unleashed: bool = GM.get("hornsT", 0.0) > 0
	var moving = absf(P.vx) > 20
	var D = {"anim": GM.anim, "form": "muscle" if unleashed else "robe", "horns": 1.0 if unleashed else 0.0,
		"spell": "orb" if GM.get("castT", 0.0) > 0 else "", "walkT": P.x * 0.12}
	if unleashed and D.anim in ["float", "cast"]:
		D.anim = "run" if moving else ("jab" if GM.get("castT", 0.0) > 0 else "idle")
	var hover = 0.0 if P.state == "dead" or unleashed else 5.0 + sin(realTime * 1.6) * 2
	x.fillStyle = rgba(20, 0, 30, 0.35)
	x.fillRect(X - 10, Y - 1, 20, 2)
	var blink: bool = P.iframes > 0 and P.state != "dead" and int(gameTime * 18) % 2 == 0
	if not blink:
		_drawGlamrax(x, X, Y - hover, P.face, D, GM.get("t", 0.0), P.flash > 0)
	if GM.get("shieldT", 0.0) > 0:
		var a = 0.3 + 0.15 * sin(realTime * 5)
		x.strokeStyle = rgba(122, 240, 255, a + 0.3); x.lineWidth = 1.2
		x.beginPath(); x.ellipse(X, Y - hover - 38, 30, 46, 0, 0, TAU); x.stroke()
		x.fillStyle = rgba(122, 240, 255, a * 0.3)
		x.beginPath(); x.ellipse(X, Y - hover - 38, 30, 46, 0, 0, TAU); x.fill()
	x.font = FONT
	x.textAlign = "center"
	x.fillStyle = rgba(30, 6, 40, 0.75)
	x.fillRect(X - 22, Y + 3, 44, 10)
	x.fillStyle = "#ff8ae8"
	x.fillText("Glamrax", X, Y + 11)


# ================================================================ the heroes, their shots, his spells

func drawSanctumFront(x: Ctx, sx: float, sy: float) -> void:
	super.drawSanctumFront(x, sx, sy)
	for s in gSpells:
		match s.kind:
			"mbolt":
				var X = s.x - sx
				var Y = s.y - sy
				var g = x.createRadialGradient(X, Y, 1, X, Y, 9)
				g.addColorStop(0, rgba(255, 220, 250, 1)); g.addColorStop(0.4, rgba(255, 74, 216, 0.9)); g.addColorStop(1, rgba(255, 74, 216, 0))
				x.fillStyle = g; x.beginPath(); x.arc(X, Y, 9, 0, TAU); x.fill()
				if randf() < 0.5:
					part(s.x, s.y, rand(-20, 20), rand(-20, 20), 0.3, "#ff4ad8", 0, 1)
			"mzap":
				var k = 1.0 - s.t / 0.3
				var pts: Array = s.pts
				for w in [4.0, 1.5]:
					x.strokeStyle = rgba(120, 200, 255, 0.5 * k) if w > 2 else rgba(240, 250, 255, k)
					x.lineWidth = w
					x.beginPath(); x.moveTo(pts[0].x - sx, pts[0].y - sy)
					for i in range(1, pts.size()):
						var a: Vector2 = pts[i - 1]
						var b: Vector2 = pts[i]
						for j in range(1, 6):
							var q = a.lerp(b, j / 6.0)
							x.lineTo(q.x - sx + (rand(-5, 5) if j < 5 else 0.0), q.y - sy + (rand(-5, 5) if j < 5 else 0.0))
					x.stroke()
	for s in hShots:
		_drawHShot(x, s, sx, sy)
	for f in fighters:
		_drawFighter(x, f, sx, sy)


func _drawHShot(x: Ctx, s: Dictionary, sx: float, sy: float) -> void:
	var X = s.x - sx
	var Y = s.y - sy
	match s.kind:
		"arrow":
			var d = Vector2(s.vx, s.vy).normalized()
			x.strokeStyle = "#e8d8b0"; x.lineWidth = 1.2
			x.beginPath(); x.moveTo(X - d.x * 9, Y - d.y * 9); x.lineTo(X, Y); x.stroke()
			x.fillStyle = "#ffffff"; x.fillRect(X - 1, Y - 1, 2, 2)
			x.fillStyle = "#c84a4a"; x.fillRect(X - d.x * 9 - 1, Y - d.y * 9 - 1, 2, 2)
		"bullet":
			x.fillStyle = "#ffe14d"; x.fillRect(X - 2, Y - 1, 4, 2)
			x.fillStyle = rgba(255, 225, 77, 0.4); x.fillRect(X - 6 * sgn(s.vx), Y - 0.5, 6 * sgn(s.vx), 1)
		"bolt":
			var g = x.createRadialGradient(X, Y, 1, X, Y, 7)
			g.addColorStop(0, rgba(220, 255, 240, 1)); g.addColorStop(1, rgba(80, 220, 160, 0))
			x.fillStyle = g; x.beginPath(); x.arc(X, Y, 7, 0, TAU); x.fill()
		"spirit":
			x.fillStyle = rgba(190, 150, 255, 0.85)
			x.beginPath(); x.arc(X, Y, 5, 0, TAU); x.fill()
			x.fillStyle = rgba(190, 150, 255, 0.4)
			x.fillRect(X - sgn(s.vx) * 10, Y - 2, sgn(s.vx) * 6, 4)
			x.fillStyle = "#ffffff"; x.fillRect(X + sgn(s.vx) * 1, Y - 2, 1, 1)
		"nade":
			x.fillStyle = "#3a4a3a"; x.beginPath(); x.arc(X, Y, 3, 0, TAU); x.fill()
			x.fillStyle = "#ff4a3a" if int(s.t * 12) % 2 else "#ffd27a"; x.fillRect(X - 0.5, Y - 4, 1, 1)
		"erupt":
			if s.t < s.warn:
				x.strokeStyle = rgba(120, 255, 200, 0.4 + 0.4 * absf(sin(s.t * 20))); x.lineWidth = 1
				x.beginPath(); x.ellipse(X, Y, 22, 4, 0, 0, TAU); x.stroke()
			else:
				var k = 1 - (s.t - s.warn) / 0.4
				var g = x.createLinearGradient(0, Y - 60, 0, Y)
				g.addColorStop(0, rgba(120, 255, 200, 0)); g.addColorStop(1, rgba(160, 255, 220, 0.8 * k))
				x.fillStyle = g; x.fillRect(X - 20, Y - 60, 40, 60)
		"beam":
			var top = M.get("ceilY", 30) - sy
			if s.t < s.warn:
				x.fillStyle = rgba(255, 60, 60, 0.25 + 0.3 * absf(sin(s.t * 24))); x.fillRect(X - 0.5, top, 1, Y - top)
				x.fillStyle = "#ff3a3a"; x.fillRect(X - 3, top + 4, 6, 3)
			else:
				var k = 1 - (s.t - s.warn) / 0.4
				x.fillStyle = rgba(255, 80, 80, 0.5 * k); x.fillRect(X - 8, top, 16, Y - top)
				x.fillStyle = rgba(255, 230, 230, k); x.fillRect(X - 3, top, 6, Y - top)
		"boom":
			var k = s.t / 0.4
			x.fillStyle = rgba(255, 180, 80, 0.6 * (1 - k)); x.beginPath(); x.arc(X, Y, 8 + 24 * k, 0, TAU); x.fill()


const _LOOP_ANIMS := ["idle", "run", "walk", "whirl", "a_rapid"]


func _drawFighter(x: Ctx, f: Dictionary, sx: float, sy: float) -> void:
	var X = roundf(f.x - sx)
	var Y = roundf(f.y - sy)
	if X < -60 or X > VW + 60:
		return
	var anim: String = f.anim
	var anims: Dictionary = Assets.hero_look(f.look).get("anims", {})
	if not anims.has(anim):
		anim = {"a_shoot": "slash", "j_throw": "slash", "j_push": "thrust", "m_staff": "heavy"}.get(anim, "idle")
		if not anims.has(anim):
			anim = "idle"
	var A = Assets.hero_anim(f.look, anim)
	var nf = maxi(1, int(A.frames))
	var fi: int
	if anim in _LOOP_ANIMS:
		fi = int(f.animT * float(A.fps)) % nf
	else:
		fi = mini(nf - 1, int(f.animT * float(A.fps)))
	if f.state == "frozen":
		fi = 0
	var tex = Assets.hero_strip(f.look, anim, 1)
	x.fillStyle = rgba(10, 0, 20, 0.3)
	x.fillRect(X - 8, Y - 1, 16, 2)
	if tex != null:
		x.save()
		x.translate(X, Y)
		if f.face < 0:
			x.scale(-1, 1)
		if f.flash > 0:
			x.globalAlpha = 0.6
		x.drawFrame(tex, nf, fi, -RX, -GROUND, SW, SH)
		x.globalAlpha = 1
		x.restore()
	if f.state == "frozen":
		x.fillStyle = rgba(190, 240, 255, 0.45); x.fillRect(X - 11, Y - 38, 22, 38)
		x.strokeStyle = rgba(240, 255, 255, 0.9); x.lineWidth = 1; x.strokeRect(X - 11, Y - 38, 22, 38)
	# name and health
	x.font = F6
	x.textAlign = "center"
	var ally: bool = f.team == "ally"
	if ally and f.state != "down":   # foes are named in the roster instead, their tags overlapped
		x.fillStyle = rgba(20, 10, 30, 0.7); x.fillRect(X - 16, Y + 3, 32, 8)
		x.fillStyle = "#9affb0" if ally else "#ffffff"
		x.fillText(f.name, X, Y + 9)
	if not ally and f.state != "down":
		var k = clampf(f.hp / f.maxHp, 0, 1)
		x.fillStyle = "#1a0410"; x.fillRect(X - 14, Y - 48, 28, 3)
		x.fillStyle = "#ff4a5a"; x.fillRect(X - 14, Y - 48, 28 * k, 3)
	# what they say
	if f.barkT > 0 and f.bark != "":
		x.font = F6
		var w = x.measureText(f.bark).width + 10
		var bx = clampf(X, w / 2 + 2, VW - w / 2 - 2)   # keep the bubble on screen
		var a = clampf(f.barkT / 0.4, 0, 1)
		x.globalAlpha = a
		x.fillStyle = rgba(255, 255, 255, 0.92); x.fillRect(bx - w / 2, Y - 70, w, 11)
		x.fillRect(X - 2, Y - 59, 4, 3)
		x.fillStyle = "#1a1030"; x.fillText(f.bark, bx, Y - 62)
		x.globalAlpha = 1


# ================================================================ how he set the trap

func drawVolcanoStory(x: Ctx, t: float, kind: String) -> void:
	match kind:
		"gb_tome":
			_gbRoom(x, t)
			# the lectern and the open book, glowing
			x.fillStyle = "#1a0e14"; x.fillRect(222, 130, 8, 34); x.fillRect(210, 160, 32, 6)
			x.fillStyle = "#2a1820"; x.beginPath(); x.moveTo(206, 130); x.lineTo(246, 130); x.lineTo(240, 122); x.lineTo(212, 122); x.closePath(); x.fill()
			x.fillStyle = "#e8d8b0"; x.fillRect(212, 119, 13, 5); x.fillRect(227, 119, 13, 5)
			var g = x.createRadialGradient(226, 118, 2, 226, 118, 60)
			g.addColorStop(0, rgba(255, 74, 216, 0.5 + 0.15 * sin(t * 3))); g.addColorStop(1, rgba(255, 74, 216, 0))
			x.fillStyle = g; x.beginPath(); x.arc(226, 118, 60, 0, TAU); x.fill()
			for i in 6:
				var k = fmod(t * 0.4 + i / 6.0, 1.0)
				x.fillStyle = rgba(255, 140, 240, 1 - k); x.fillRect(214 + _irnd2(i) * 24, 116 - k * 40, 1, 1)
			_gbGlamrax(x, 178, 166, 1, "cast", t, 1.3)
			for cx in [120, 300]:
				_candle(x, cx, 160, t)
		"gb_page":
			x.fillStyle = "#0a0408"; x.fillRect(0, 0, 384, 216)
			x.fillStyle = "#d8c8a0"; x.fillRect(40, 20, 150, 176); x.fillRect(194, 20, 150, 176)
			x.fillStyle = "#b8a880"; x.fillRect(188, 20, 8, 176)
			x.fillStyle = "#3a1020"
			for r in 14:   # lines of an unreadable script
				var n = 10 + int(_irnd2(r) * 8)
				for c in n:
					if _irnd2(r * 31 + c) < 0.85:
						x.fillRect(52 + c * 9, 30 + r * 11, 2 + int(_irnd2(r * 7 + c) * 5), 3)
			# the diagram: a crystal, the engine, someone else
			var k = clampf(t / 2.0, 0, 1)
			var cy = 90.0
			x.strokeStyle = rgba(120, 10, 40, 0.9); x.lineWidth = 1.2
			x.beginPath(); x.moveTo(230, cy - 24); x.lineTo(242, cy - 12); x.lineTo(242, cy + 12); x.lineTo(230, cy + 24); x.lineTo(218, cy + 12); x.lineTo(218, cy - 12); x.closePath(); x.stroke()
			x.fillStyle = rgba(120, 10, 40, 0.9); x.fillRect(227, cy - 8, 6, 14)
			x.strokeRect(266, cy - 12, 24, 22); x.fillRect(272, cy - 6, 12, 2); x.fillRect(272, cy - 1, 8, 2)
			x.beginPath(); x.arc(320, cy - 14, 5, 0, TAU); x.stroke(); x.fillRect(317, cy - 8, 6, 22)
			x.strokeStyle = rgba(255, 74, 216, 0.4 + 0.6 * k); x.lineWidth = 1.6
			x.beginPath(); x.moveTo(244, cy); x.lineTo(lerpf(244, 264, k), cy); x.stroke()
			if k > 0.5:
				x.beginPath(); x.moveTo(292, cy); x.lineTo(lerpf(292, 312, (k - 0.5) * 2), cy); x.stroke()
			for i in 3:
				var q = fmod(t * 0.7 + i / 3.0, 1.0)
				x.fillStyle = rgba(255, 74, 216, 0.8); x.fillRect(lerpf(244, 312, q), cy - 1, 2, 2)
		"gb_take":
			x.fillStyle = "#0c0612"; x.fillRect(0, 0, 384, 216)
			for i in GX_PODS.size():
				var appear = clampf((t - i * 0.7) / 0.6, 0, 1)
				if appear <= 0:
					continue
				var X = 52.0 + i * 70
				var Y = 104.0 + (i % 2) * 10
				if appear < 1:
					for n in 6:
						var a = randf() * TAU
						x.fillStyle = "#ff4ad8"; x.fillRect(X + cos(a) * 30 * (1 - appear), Y + sin(a) * 40 * (1 - appear), 2, 2)
				x.globalAlpha = appear
				_crystal(x, X, Y, GX_PODS[i], t + i)
				x.globalAlpha = 1
		"gb_wait":
			_gbRoom(x, t)
			_piano(x, 222, 176)
			_gbGlamrax(x, 210, 176, 1, "sit", t, 1.25)
			# his eyes find the camera
			if t > 1.6:
				var a = clampf((t - 1.6) / 0.8, 0, 1)
				x.fillStyle = rgba(255, 58, 216, 0.25 * a); x.fillRect(0, 0, 384, 216)
		"gb_title":
			x.fillStyle = "#0a0410"; x.fillRect(0, 0, 384, 216)
			var g = x.createRadialGradient(270, 150, 4, 270, 150, 140)
			g.addColorStop(0, rgba(160, 30, 140, 0.45)); g.addColorStop(1, rgba(160, 30, 140, 0))
			x.fillStyle = g; x.fillRect(0, 0, 384, 216)
			x.fillStyle = "#1a0e20"; x.fillRect(0, 168, 384, 48)
			for i in GX_PODS.size():
				heroPic2(x, GX_PODS[i], 40.0 + i * 30, 170, 1.0)
			_gbGlamrax(x, 300, 166, -1, "float", t, 1.4)
		_:
			super.drawVolcanoStory(x, t, kind)


func _gbRoom(x: Ctx, t: float) -> void:
	var g = x.createLinearGradient(0, 0, 0, 216)
	g.addColorStop(0, "#12060e"); g.addColorStop(1, "#2a0e1e")
	x.fillStyle = g; x.fillRect(0, 0, 384, 216)
	for i in 14:   # lava cracks glowing in the rock
		var X = _irnd2(i) * 384
		var Y = 20 + _irnd2(i + 40) * 130
		x.strokeStyle = rgba(255, 90, 30, 0.35 + 0.2 * sin(t * 2 + i)); x.lineWidth = 1
		x.beginPath(); x.moveTo(X, Y); x.lineTo(X + 6, Y + 8); x.lineTo(X + 2, Y + 16); x.stroke()
	x.fillStyle = "#1a0a12"; x.fillRect(0, 166, 384, 50)


func _candle(x: Ctx, X: float, Y: float, t: float) -> void:
	x.fillStyle = "#d8c8a0"; x.fillRect(X - 2, Y - 10, 4, 10)
	var fl = sin(t * 13 + X) * 0.8
	x.fillStyle = "#ffd27a"; x.fillRect(X - 1 + fl, Y - 14, 2, 4)
	var g = x.createRadialGradient(X, Y - 12, 1, X, Y - 12, 24)
	g.addColorStop(0, rgba(255, 200, 120, 0.35)); g.addColorStop(1, rgba(255, 200, 120, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y - 12, 24, 0, TAU); x.fill()


func _gbGlamrax(x: Ctx, X: float, Y: float, face: int, anim: String, t: float, k: float) -> void:
	x.save()
	x.translate(X, Y)
	x.scale(k, k)
	_drawGlamrax(x, 0, 0, face, {"anim": anim, "form": "robe"}, t, false)
	x.restore()
