extends "res://scripts/volcano_draw.gd"
## Sproutvale, the volcano's last room, drawn: the crystals holding each hero's loved one, the piano,
## Glamrax in his robes and out of them, every spell he throws, his abyssal demon, and the false ending.
## The fight itself lives in glamrax.gd, before render.gd in the chain.

## story cards for the volcano (drawn by drawVolcanoStory below)
func glamraxCutscene(cls: String, scenes: Array, done: Callable) -> void:
	intro = {"cls": cls, "kin": "none", "scenes": scenes, "i": 0, "shown": 0, "t": 0.0, "done": done, "fallen": null, "run": null, "btn": "Next"}


# ================================================================ the sanctum: crystals, cables, the piano

func drawSanctumMid(x: Ctx, sx: float, sy: float) -> void:
	if not M.get("sanctum"):
		return
	var t = realTime
	var S: Dictionary = vSpots()
	var mx = 652.0   # the machine's intake on the right wall
	for i in GX_PODS.size():
		var p = _podXY(i)
		var X = p.x - sx
		var Y = p.y - sy + sin(t * 1.3 + i) * 2
		# the chain it hangs from
		x.strokeStyle = "#2a2430"; x.lineWidth = 1.2
		x.beginPath(); x.moveTo(X, M.get("ceilY", 30) - sy); x.lineTo(X, Y - 30); x.stroke()
		# a cable down from the crystal to the machine, power flowing along it
		var a = Vector2(X, Y + 30)
		var b = Vector2(mx - sx, 150 + i * 22 - sy)
		var c = Vector2((a.x + b.x) / 2, maxf(a.y, b.y) + 50)
		x.strokeStyle = "#1a0e20"; x.lineWidth = 2.6
		x.beginPath(); x.moveTo(a.x, a.y); x.quadraticCurveTo(c.x, c.y, b.x, b.y); x.stroke()
		x.strokeStyle = "#5a1a6a"; x.lineWidth = 1
		x.beginPath(); x.moveTo(a.x, a.y); x.quadraticCurveTo(c.x, c.y, b.x, b.y); x.stroke()
		for k in 3:
			var u = fmod(t * 0.35 + k / 3.0 + i * 0.13, 1.0)
			var q = a.lerp(c, u).lerp(c.lerp(b, u), u)
			x.fillStyle = rgba(255, 90, 230, 0.9); x.fillRect(q.x - 1, q.y - 1, 2, 2)
		var who = podWho(i)
		if who != "":
			_crystal(x, X, Y, who, t + i)
	for p in S.get("piano", []):
		_piano(x, p[0] - sx, p[1] - sy)


## who hangs in crystal i: a loved one (by hero id), "hero:<id>" for the hero, "" for a broken crystal
func podWho(i: int) -> String:
	return GX_PODS[i]


## a big hexagonal crystal with somebody inside it
func _crystal(x: Ctx, X: float, Y: float, who: String, t: float, scale := 1.0) -> void:
	if X < -50 or X > VW + 50:
		return
	var w = 20.0 * scale
	var h = 30.0 * scale
	var g = x.createRadialGradient(X, Y, 2, X, Y, 46 * scale)
	g.addColorStop(0, rgba(200, 140, 255, 0.25 + 0.08 * sin(t * 2))); g.addColorStop(1, rgba(200, 140, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y, 46 * scale, 0, TAU); x.fill()
	x.fillStyle = rgba(40, 10, 60, 0.55)
	x.beginPath(); x.moveTo(X, Y - h - 10 * scale); x.lineTo(X + w, Y - h + 6 * scale); x.lineTo(X + w, Y + h - 6 * scale); x.lineTo(X, Y + h + 10 * scale); x.lineTo(X - w, Y + h - 6 * scale); x.lineTo(X - w, Y - h + 6 * scale); x.closePath(); x.fill()
	var tex = Assets.tex("kin/%s.png" % who) if not who.begins_with("hero:") else null
	if who.begins_with("hero:"):
		heroPic2(x, who.substr(5), X, Y + 20 * scale + sin(t * 1.6) * 0.8, 0.62 * scale)
	elif tex != null:
		x.globalAlpha = 0.9
		x.drawImage(tex, X - 12 * scale, Y - 18 * scale + sin(t * 1.6) * 0.8, 24 * scale, 36 * scale)
		x.globalAlpha = 1
	x.fillStyle = rgba(170, 220, 255, 0.28)
	x.beginPath(); x.moveTo(X, Y - h - 10 * scale); x.lineTo(X + w, Y - h + 6 * scale); x.lineTo(X + w, Y + h - 6 * scale); x.lineTo(X, Y + h + 10 * scale); x.lineTo(X - w, Y + h - 6 * scale); x.lineTo(X - w, Y - h + 6 * scale); x.closePath(); x.fill()
	x.fillStyle = rgba(240, 250, 255, 0.3)
	x.beginPath(); x.moveTo(X, Y - h - 10 * scale); x.lineTo(X + w, Y - h + 6 * scale); x.lineTo(X + 4 * scale, Y - h + 12 * scale); x.lineTo(X - 4 * scale, Y - h + 2 * scale); x.closePath(); x.fill()
	x.strokeStyle = rgba(230, 245, 255, 0.85); x.lineWidth = 1
	x.beginPath(); x.moveTo(X, Y - h - 10 * scale); x.lineTo(X + w, Y - h + 6 * scale); x.lineTo(X + w, Y + h - 6 * scale); x.lineTo(X, Y + h + 10 * scale); x.lineTo(X - w, Y + h - 6 * scale); x.lineTo(X - w, Y - h + 6 * scale); x.closePath(); x.stroke()
	x.strokeStyle = rgba(220, 160, 255, 0.5)
	x.beginPath(); x.moveTo(X - w, Y - h + 6 * scale); x.lineTo(X + 4 * scale, Y - h + 12 * scale); x.lineTo(X + w, Y - h + 6 * scale); x.moveTo(X + 4 * scale, Y - h + 12 * scale); x.lineTo(X + 2 * scale, Y + h + 4 * scale); x.stroke()
	for i in 4:
		var a = t * 1.7 + i * 1.6
		x.fillStyle = "#f4e8ff"; x.fillRect(roundf(X + cos(a) * (w + 6)), roundf(Y + sin(a * 1.3) * h), 1, 1)


## Glamrax's piano: a black grand with violet trim, the lid propped open
func _piano(x: Ctx, X: float, Y: float) -> void:
	if X < -80 or X > VW + 80:
		return
	# legs
	x.fillStyle = "#0a060c"
	x.fillRect(X - 30, Y - 16, 3, 16); x.fillRect(X + 22, Y - 16, 3, 16); x.fillRect(X + 2, Y - 14, 3, 14)
	# the body, curved at the back
	x.fillStyle = "#120a16"
	x.beginPath(); x.moveTo(X - 32, Y - 24); x.lineTo(X + 10, Y - 24); x.quadraticCurveTo(X + 34, Y - 26, X + 30, Y - 15); x.lineTo(X - 32, Y - 15); x.closePath(); x.fill()
	x.fillStyle = "#3a1450"; x.fillRect(X - 32, Y - 17, 62, 1.5)
	# the lid, propped open on its stick
	x.fillStyle = "#1c1022"
	x.beginPath(); x.moveTo(X - 28, Y - 25); x.lineTo(X + 28, Y - 25); x.lineTo(X + 16, Y - 52); x.closePath(); x.fill()
	x.strokeStyle = "#5a2a6a"; x.lineWidth = 0.8; x.beginPath(); x.moveTo(X - 28, Y - 25); x.lineTo(X + 16, Y - 52); x.stroke()
	x.strokeStyle = "#2a1a30"; x.lineWidth = 1; x.beginPath(); x.moveTo(X + 6, Y - 25); x.lineTo(X + 8, Y - 40); x.stroke()
	# keys and the music stand
	x.fillStyle = "#e8e4ec"; x.fillRect(X - 36, Y - 24, 7, 3)
	x.fillStyle = "#0a060c"
	for i in 3:
		x.fillRect(X - 35 + i * 2, Y - 24, 1, 1.5)
	x.fillStyle = "#2a1a30"; x.fillRect(X - 31, Y - 31, 2, 7)
	# a candelabra on top
	x.fillStyle = "#c8a040"; x.fillRect(X - 6, Y - 30, 1, 5)
	for k in 3:
		x.fillRect(X - 9 + k * 3, Y - 31, 1, 2)
		var fl = 0.7 + 0.3 * sin(realTime * 9 + k * 2)
		x.fillStyle = rgba(255, 200, 90, fl); x.fillRect(X - 9 + k * 3, Y - 33, 1, 2)
		x.fillStyle = "#c8a040"
	# the bench
	x.fillStyle = "#120a16"; x.fillRect(X - 50, Y - 9, 12, 3)
	x.fillRect(X - 49, Y - 6, 1.5, 6); x.fillRect(X - 40, Y - 6, 1.5, 6)


# ================================================================ drawing Glamrax

func drawBossKind(x: Ctx, e, X: float, Y: float) -> bool:
	if e.bossKind != "glamrax":
		return super.drawBossKind(x, e, X, Y)
	_drawGlamrax(x, X, Y, e.face, e.data, e.t, e.hurtFlash > 0)
	# the mana shield
	if e.data.get("shield", false) and e.state == "fight":
		var a = 0.25 + 0.15 * sin(realTime * 5) + e.data.get("flash", 0.0) * 2
		x.strokeStyle = rgba(122, 240, 255, minf(0.9, a + 0.2)); x.lineWidth = 1.2
		x.beginPath(); x.ellipse(X, Y - 38, 30, 46, 0, 0, TAU); x.stroke()
		x.fillStyle = rgba(122, 240, 255, minf(0.14, a * 0.3))
		x.beginPath(); x.ellipse(X, Y - 38, 30, 46, 0, 0, TAU); x.fill()
		for i in 6:
			var an = realTime * 0.8 + i * TAU / 6
			x.fillStyle = rgba(220, 255, 255, a)
			x.fillRect(X + cos(an) * 30 - 1, Y - 38 + sin(an) * 46 - 1, 2, 2)
	# the hero's frown in the meeting
	if GX.get("frown", 0.0) > 0:
		var k: float = GX.frown
		var hx = P.x - (e.x - X)
		var hy = P.y - (e.y - Y) - 48
		x.strokeStyle = rgba(255, 60, 70, k); x.lineWidth = 1.2
		for s in [-1, 1]:
			x.beginPath(); x.moveTo(hx + 8 + s * 2.5, hy - 2.5); x.lineTo(hx + 8 + s * 0.8, hy - 0.8); x.stroke()
			x.beginPath(); x.moveTo(hx + 8 + s * 2.5, hy + 2.5); x.lineTo(hx + 8 + s * 0.8, hy + 0.8); x.stroke()
	return true


## Glamrax, any form: robed and floating, sitting at the piano, stripped to the waist, horned, dazed or down
func _drawGlamrax(x: Ctx, X: float, Y: float, face: int, D: Dictionary, t: float, flash: bool) -> void:
	var anim: String = D.get("anim", "float")
	var rt = realTime
	var robe: bool = D.get("form", "robe") == "robe"
	var shed: float = D.get("robe", 0.0) if anim == "shed" else 0.0
	x.save()
	x.translate(X, Y)
	x.scale(face, 1)
	if anim == "lying":
		x.rotate(-PI / 2 * 0.98)
		x.translate(30, 0)
	elif anim == "fall":
		x.rotate(-minf(1, t / 0.6) * 0.6)
	elif anim == "dazed":
		x.translate(0, 18)
	var glow = 0.7 + 0.3 * sin(rt * 4)
	var spellCol = css(GX_COL.get(D.get("spell", ""), "#ff4ad8"))
	var skin = "#9a8aa8" if not flash else "#ffffff"
	var skinD = "#6a5a7a"
	if robe or shed > 0:
		var bob = 0.0 if anim in ["sit", "slam", "stand", "lying", "fall", "dazed"] else sin(rt * 1.6) * 1.5
		x.translate(0, bob)
		var sitting = anim in ["sit", "slam"]
		var a = 1.0 - shed
		x.globalAlpha = a
		# cape behind
		var sway = sin(rt * 2.2) * 3
		x.fillStyle = "#1a0a24"
		x.beginPath(); x.moveTo(-6, -58); x.lineTo(-30 + sway, -2); x.lineTo(-10, -4); x.lineTo(6, -58); x.closePath(); x.fill()
		x.fillStyle = "#3a0f4a"
		x.beginPath(); x.moveTo(-5, -56); x.lineTo(-26 + sway, -4); x.lineTo(-12, -6); x.lineTo(4, -56); x.closePath(); x.fill()
		# the robe
		var hem = -22.0 if sitting else 0.0
		x.fillStyle = "#24102e" if not flash else "#8a6aa0"
		x.beginPath(); x.moveTo(-9, -58); x.lineTo(9, -58); x.lineTo(13 + (8 if sitting else 0), hem); x.lineTo(-13, hem); x.closePath(); x.fill()
		if sitting:
			x.fillRect(-8, -24, 24, 8)   # the lap, over the bench
			x.fillStyle = "#1a0a24"; x.fillRect(12, -18, 5, 18)   # shins
		else:
			x.fillStyle = "#07030f"
			for i in 5:
				var hx0 = -13 + i * 5.2
				x.beginPath(); x.moveTo(hx0, 0); x.lineTo(hx0 + 2.6, -4 - (i % 2) * 2 + sin(rt * 3 + i) * 1.5); x.lineTo(hx0 + 5.2, 0); x.closePath(); x.fill()
		x.fillStyle = "#7a2a8a"; x.fillRect(-1.2, -50, 2.4, 50 + hem)
		# the arm with the staff (or both hands on the keys)
		if sitting:
			var hb = (sin(rt * 9) * 1.5 if anim == "sit" else 0.0)
			x.fillStyle = "#3a1450"
			x.beginPath(); x.moveTo(-2, -50); x.lineTo(14, -32 + hb); x.lineTo(18, -34 + hb); x.lineTo(4, -52); x.closePath(); x.fill()
			x.fillStyle = "#8a7a96"; x.beginPath(); x.arc(18, -33 + hb, 2.6, 0, TAU); x.fill()
		else:
			var raise = 1.0 if anim in ["cast", "swat", "shed"] else 0.0
			var hx = 15.0
			var hy = lerpf(-34, -54, raise)
			x.fillStyle = "#3a1450"
			x.beginPath(); x.moveTo(3, -52); x.lineTo(hx - 2, hy); x.lineTo(hx + 2, hy - 2); x.lineTo(7, -55); x.closePath(); x.fill()
			# staff
			x.strokeStyle = "#3a2a1a"; x.lineWidth = 2.2
			x.beginPath(); x.moveTo(hx + 2, hy + 28); x.lineTo(hx, hy - 14); x.stroke()
			var oc = spellCol if D.get("spell", "") != "" else css("#ff4ad8")
			var og = x.createRadialGradient(hx, hy - 16, 1, hx, hy - 16, 10)
			og.addColorStop(0, Color(oc, glow)); og.addColorStop(1, Color(oc, 0))
			x.fillStyle = og; x.beginPath(); x.arc(hx, hy - 16, 10, 0, TAU); x.fill()
			x.fillStyle = Color(oc, glow); x.beginPath(); x.arc(hx, hy - 16, 3, 0, TAU); x.fill()
			x.fillStyle = "#ffffff"; x.fillRect(hx - 1, hy - 17, 1, 1)
			x.fillStyle = "#8a7a96"; x.beginPath(); x.arc(hx, hy, 2.6, 0, TAU); x.fill()
			# the other hand, crackling
			x.fillStyle = "#3a1450"
			x.beginPath(); x.moveTo(-3, -52); x.lineTo(-14, -40 - raise * 10); x.lineTo(-10, -38 - raise * 10); x.lineTo(-1, -50); x.closePath(); x.fill()
			x.fillStyle = "#8a7a96"; x.beginPath(); x.arc(-13, -40 - raise * 10, 2.4, 0, TAU); x.fill()
			if raise > 0:
				x.strokeStyle = Color(oc, 0.7); x.lineWidth = 0.8
				x.beginPath(); x.moveTo(-13, -40 - raise * 10)
				for k in 4:
					x.lineTo(-13 + rand(-5, 5), -44 - raise * 10 - k * 3)
				x.stroke()
		# face, beard, hat
		x.fillStyle = "#0e0616"; x.beginPath(); x.ellipse(1, -62, 6, 5.5, 0, 0, TAU); x.fill()
		for ex in [-1.5, 3.5]:
			x.fillStyle = rgba(255, 58, 216, glow); x.fillRect(ex - 1, -63.5, 2.4, 1)
			x.fillStyle = rgba(255, 140, 240, glow * 0.35); x.fillRect(ex - 2, -64.5, 4.4, 3)
		x.fillStyle = "#b8b0c0"
		x.beginPath(); x.moveTo(-4, -59); x.lineTo(6, -59); x.lineTo(3, -46); x.lineTo(1, -42); x.lineTo(-1, -46); x.closePath(); x.fill()
		x.fillStyle = "#d8d0e0"; x.beginPath(); x.moveTo(-2, -58); x.lineTo(2, -58); x.lineTo(0, -45); x.closePath(); x.fill()
		x.fillStyle = "#2a0f3a"; x.fillRect(-13, -68, 27, 3)
		x.fillStyle = "#3a1450"
		x.beginPath(); x.moveTo(-8, -68); x.lineTo(9, -68); x.lineTo(4, -84); x.lineTo(12, -90 + sin(rt * 1.2)); x.lineTo(1, -84); x.closePath(); x.fill()
		x.fillStyle = "#9a3ad8"; x.fillRect(-8, -70, 17, 2)
		x.globalAlpha = 1
	if not robe or shed > 0:
		x.globalAlpha = 1.0 if not robe else shed
		_drawGlamraxBare(x, D, t, flash, anim, rt)
		x.globalAlpha = 1
	if anim == "dazed":
		for i in 3:
			var a2 = rt * 4 + i * TAU / 3
			x.fillStyle = "#ffe14d"
			x.fillRect(cos(a2) * 12 - 1, -62 + sin(a2) * 3 - 1, 2, 2)
	x.restore()


## stripped to the waist: grey-violet and corded with muscle, glowing runes, the long beard, and (at the end) horns
func _drawGlamraxBare(x: Ctx, D: Dictionary, t: float, flash: bool, anim: String, rt: float) -> void:
	var skin = "#7a5a8e" if not flash else "#ffffff"
	var skinD = "#3e2a50"
	var horns: float = D.get("horns", 0.0)
	var rune = rgba(255, 58, 216, 0.6 + 0.3 * sin(rt * 5)) if horns <= 0 else rgba(255, 50, 60, 0.8 + 0.2 * sin(rt * 9))
	var w: float = D.get("walkT", 0.0)
	var run = anim == "run"
	var crouch = 6.0 if anim in ["crouch", "roar"] else 0.0
	var lean = 0.25 if run or anim == "dashpunch" else 0.0
	# legs: dark trousers, bare feet
	var hip = Vector2(0, -30 + crouch)
	var fF = Vector2(6 + (sin(w) * 12 if run else 0.0), -maxf(0, cos(w)) * 6 if run else 0.0)
	var fB = Vector2(-6 - (sin(w) * 12 if run else 0.0), -maxf(0, -cos(w)) * 6 if run else 0.0)
	for f in [fB, fF]:
		var k = _ik(hip + Vector2(f.x * 0.2, 0), f + Vector2(0, -3), 16, 16, -1.0)
		_seg(x, hip + Vector2(f.x * 0.2, 0), k[0], 5, 4.5, "#1a1020" if f == fB else "#24162c", null)
		_seg(x, k[0], k[1], 4.5, 4, "#1a1020" if f == fB else "#24162c", null)
		x.fillStyle = skinD; x.fillRect(k[1].x - 3, k[1].y, 8, 3)
	# the torso: broad shoulders, narrow waist
	x.save()
	x.translate(hip.x, hip.y); x.rotate(lean); x.translate(-hip.x, -hip.y)
	x.fillStyle = "#3a1450"; x.fillRect(-8, -34 + crouch, 16, 5)   # belt
	x.fillStyle = "#c8a040"; x.fillRect(-2, -34 + crouch, 4, 5)
	x.fillStyle = skin
	x.beginPath(); x.moveTo(-8, -32 + crouch); x.lineTo(8, -32 + crouch); x.lineTo(14, -54 + crouch); x.lineTo(10, -60 + crouch); x.lineTo(-10, -60 + crouch); x.lineTo(-14, -54 + crouch); x.closePath(); x.fill()
	x.strokeStyle = skinD; x.lineWidth = 0.7
	x.beginPath(); x.moveTo(0, -56 + crouch); x.lineTo(0, -34 + crouch)
	x.moveTo(-8, -50 + crouch); x.quadraticCurveTo(-3, -46 + crouch, 0, -50 + crouch); x.quadraticCurveTo(3, -46 + crouch, 8, -50 + crouch)
	for r in 3:
		x.moveTo(-5, -43 + r * 3.5 + crouch); x.lineTo(5, -43 + r * 3.5 + crouch)
	x.stroke()
	# glowing runes along the arms and chest
	x.strokeStyle = rune; x.lineWidth = 0.8
	x.beginPath(); x.moveTo(-10, -55 + crouch); x.lineTo(-6, -52 + crouch); x.lineTo(-8, -48 + crouch); x.moveTo(10, -55 + crouch); x.lineTo(6, -52 + crouch); x.lineTo(8, -48 + crouch); x.stroke()
	# arms, posed by the move
	var shF = Vector2(11, -56 + crouch)
	var shB = Vector2(-11, -56 + crouch)
	var hF = Vector2(14, -38 + crouch)
	var hB = Vector2(-12, -38 + crouch)
	match anim:
		"run":
			hF = Vector2(10 - sin(w) * 10, -40 + crouch); hB = Vector2(-8 + sin(w) * 10, -40 + crouch)
		"jab", "jab2":
			hF = Vector2(34, -52) if anim == "jab" else Vector2(14, -50)
			hB = Vector2(6, -50) if anim == "jab" else Vector2(32, -52)
		"hook":
			hF = Vector2(30, -58); hB = Vector2(0, -46)
		"upper":
			hF = Vector2(22, -78); hB = Vector2(-6, -44)
		"dashpunch":
			hF = Vector2(36, -50); hB = Vector2(-16, -44)
		"crouch":
			hF = Vector2(10, -44 + crouch); hB = Vector2(-4, -44 + crouch)
		"roar", "cast":
			hF = Vector2(24, -70); hB = Vector2(-24, -70)
		"fall", "lying", "dazed":
			hF = Vector2(18, -30); hB = Vector2(-18, -30)
	var elem: String = D.get("elem", "")
	for side in [[shB, hB, true], [shF, hF, false]]:
		var k = _ik(side[0], side[1], 14, 14, 1.0)
		_seg(x, side[0], k[0], 4.5, 4, skin if not side[2] else skinD, null)
		_seg(x, k[0], k[1], 4, 4.5, skin if not side[2] else skinD, null)
		x.fillStyle = "#3a1450"; x.beginPath(); x.arc(k[1].x, k[1].y, 3.4, 0, TAU); x.fill()   # wrapped fists
		if elem != "" and D.get("act", "") != "":
			var ec = css(GX_ELEM_COL[elem])
			var gg = x.createRadialGradient(k[1].x, k[1].y, 1, k[1].x, k[1].y, 9)
			gg.addColorStop(0, Color(ec, 0.9)); gg.addColorStop(1, Color(ec, 0))
			x.fillStyle = gg; x.beginPath(); x.arc(k[1].x, k[1].y, 9, 0, TAU); x.fill()
	# the head: long white hair, the beard, burning eyes
	var hy = -66 + crouch
	x.fillStyle = "#d8d0e0"
	x.beginPath(); x.moveTo(-7, hy - 3); x.lineTo(-12, hy + 14); x.lineTo(-4, hy + 6); x.closePath(); x.fill()
	x.fillStyle = skin; x.beginPath(); x.ellipse(1, hy, 6, 6.5, 0, 0, TAU); x.fill()
	x.fillStyle = "#e8e0ee"; x.beginPath(); x.ellipse(0, hy - 4, 6.5, 3, 0, PI, TAU); x.fill()
	x.fillStyle = "#b8b0c0"
	x.beginPath(); x.moveTo(-4, hy + 3); x.lineTo(7, hy + 3); x.lineTo(4, hy + 18); x.lineTo(1, hy + 22); x.lineTo(-2, hy + 16); x.closePath(); x.fill()
	var ec2 = rgba(255, 58, 216, 0.9) if horns <= 0 else rgba(255, 40, 40, 1.0)
	x.fillStyle = ec2; x.fillRect(0, hy - 1, 2.4, 1.2); x.fillRect(4, hy - 1, 2.4, 1.2)
	if horns > 0:
		# horns curl up out of his brow as they grow
		x.fillStyle = "#1a0a10"
		for s in [-1, 1]:
			var bx = 1 + s * 4
			x.beginPath(); x.moveTo(bx - 1.5, hy - 5); x.quadraticCurveTo(bx + s * 8 * horns, hy - 10 * horns, bx + s * 5 * horns, hy - 18 * horns); x.lineTo(bx + 1.5, hy - 5); x.closePath(); x.fill()
		var hg = x.createRadialGradient(3, hy, 1, 3, hy, 16)
		hg.addColorStop(0, rgba(255, 40, 40, 0.35 * horns)); hg.addColorStop(1, rgba(255, 40, 40, 0))
		x.fillStyle = hg; x.beginPath(); x.arc(3, hy, 16, 0, TAU); x.fill()
	x.restore()


## his spells, in front of everyone
func drawSanctumFront(x: Ctx, sx: float, sy: float) -> void:
	var rt = realTime
	for s in gSpells:
		match s.kind:
			"bolt":
				var X0 = s.x0 - sx
				var X1 = s.x1 - sx
				var Y = s.y - sy
				if s.t < s.warn:
					if s.t > 0:
						x.fillStyle = rgba(160, 220, 255, 0.25 + 0.35 * absf(sin(s.t * 30)))
						x.fillRect(X0, Y - 2, X1 - X0, 2)
						if randf() < 0.5:
							x.fillStyle = "#ffffff"; x.fillRect(rand(X0, X1), Y - rand(2, 8), 1, 1)
				else:
					var k = 1 - (s.t - s.warn) / 0.35
					var cx = (X0 + X1) / 2
					x.strokeStyle = rgba(200, 235, 255, k); x.lineWidth = 2
					x.beginPath(); x.moveTo(cx + rand(-6, 6), M.get("ceilY", 30) - sy)
					var yy = M.get("ceilY", 30) - sy
					while yy < Y:
						yy += rand(10, 22)
						x.lineTo(cx + rand(-9, 9), minf(yy, Y))
					x.stroke()
					x.strokeStyle = rgba(120, 200, 255, 0.5 * k); x.lineWidth = 5; x.stroke()
					x.fillStyle = rgba(200, 235, 255, 0.6 * k); x.fillRect(X0, Y - 4, X1 - X0, 4)
					for i in 4:
						x.strokeStyle = rgba(255, 255, 255, k); x.lineWidth = 0.8
						var px0 = rand(X0, X1)
						x.beginPath(); x.moveTo(px0, Y); x.lineTo(px0 + rand(-6, 6), Y - rand(4, 12)); x.stroke()
			"fireball":
				var X = s.x - sx
				var Y = s.y - sy
				var g = x.createRadialGradient(X, Y, 1, X, Y, 8)
				g.addColorStop(0, rgba(255, 240, 180, 1)); g.addColorStop(0.4, rgba(255, 140, 40, 0.9)); g.addColorStop(1, rgba(255, 60, 20, 0))
				x.fillStyle = g; x.beginPath(); x.arc(X, Y, 8, 0, TAU); x.fill()
				if randf() < 0.6:
					part(s.x - s.vx * 0.02, s.y - s.vy * 0.02, rand(-10, 10), rand(-10, 10), 0.25, "#ff8a2a", 0, 1)
			"meteor":
				var X = s.x - sx
				var Y = s.gy - sy
				if s.t > 0:
					var k = minf(1, s.t / s.warn)
					x.strokeStyle = rgba(255, 90, 40, 0.4 + 0.4 * k); x.lineWidth = 1
					x.beginPath(); x.ellipse(X, Y - 1, 30 * k, 6 * k, 0, 0, TAU); x.stroke()
					x.fillStyle = rgba(255, 60, 20, 0.12 * k); x.beginPath(); x.ellipse(X, Y - 1, 30 * k, 6 * k, 0, 0, TAU); x.fill()
					var fk = clampf((s.t - (s.warn - 0.4)) / 0.4, 0, 1)
					if fk > 0:
						var mx = lerpf(X + 80, X, fk)
						var my = lerpf(-20, Y - 6, fk)
						x.strokeStyle = rgba(255, 140, 60, 0.6); x.lineWidth = 4
						x.beginPath(); x.moveTo(mx + 26, my - 34); x.lineTo(mx, my); x.stroke()
						x.fillStyle = "#3a1a10"; x.beginPath(); x.arc(mx, my, 7, 0, TAU); x.fill()
						x.fillStyle = "#ff6a1a"; x.beginPath(); x.arc(mx - 1, my + 1, 4, 0, TAU); x.fill()
			"flames":
				var X = s.x - sx
				var Y = s.y - sy
				var k = 1 - s.t / 1.6
				for i in 5:
					var fx = X - 16 + i * 8
					var fh = (6 + sin(rt * 12 + i * 2) * 3) * k
					x.fillStyle = rgba(255, 120, 30, 0.8 * k)
					x.beginPath(); x.moveTo(fx - 3, Y); x.lineTo(fx, Y - fh); x.lineTo(fx + 3, Y); x.closePath(); x.fill()
			"wave":
				var X = s.x - sx
				var Y = M.floorY - sy
				var d: int = s.dir
				var h: float = s.h
				x.fillStyle = rgba(40, 110, 200, 0.75)
				x.beginPath(); x.moveTo(X - d * 120, Y); x.lineTo(X - d * 100, Y - h * 0.5); x.quadraticCurveTo(X - d * 20, Y - h * 1.1, X + d * 6, Y - h * 0.8)
				x.quadraticCurveTo(X + d * 14, Y - h * 0.5, X + d * 4, Y); x.closePath(); x.fill()
				x.fillStyle = rgba(150, 210, 255, 0.85)
				x.beginPath(); x.moveTo(X - d * 30, Y - h * 1.0); x.quadraticCurveTo(X, Y - h * 1.15, X + d * 8, Y - h * 0.8); x.lineTo(X - d * 6, Y - h * 0.86); x.closePath(); x.fill()
				for i in 6:
					x.fillStyle = "#ffffff"
					x.fillRect(X - d * (i * 8) + rand(-2, 2), Y - h * (0.95 - i * 0.02) + rand(-2, 2), 2, 2)
			"tornado":
				var X = s.x - sx
				var Y = M.floorY - sy
				var w: float = s.w
				var k = minf(1, s.t / 0.4) * minf(1, (s.life - s.t) / 0.4)
				for i in 14:
					var yy = Y - i * 9
					var r = w * (0.35 + i * 0.07)
					var a = rt * 10 + i * 0.7
					var col = rgba(255, 140, 40, 0.5 * k) if s.fire else rgba(220, 235, 245, 0.45 * k)
					x.strokeStyle = col; x.lineWidth = 2
					x.beginPath(); x.ellipse(X + sin(rt * 3 + i * 0.4) * 3, yy, r, 3, 0, a, a + 4.2); x.stroke()
				if s.fire and randf() < 0.6:
					part(s.x + rand(-w, w), M.floorY - rand(0, 120), rand(-30, 30), -rand(40, 120), 0.4, "#ff6a1a", -40, 1)
			"icewave":
				var Y = M.floorY - sy
				var n: int = s.spikes.size()
				for i in n:
					var X = s.spikes[i] - sx
					var age = float(n - 1 - i) * 18.0 / 330.0
					var hk = minf(1, (s.t - (s.t - age)) * 6 + 0.4) * (1.0 - clampf((s.t - 3.6) / 1.0, 0, 1))
					x.fillStyle = rgba(190, 240, 255, 0.9 * hk)
					x.beginPath(); x.moveTo(X - 7, Y); x.lineTo(X - 2, Y - 26 * hk); x.lineTo(X + 1, Y - 14 * hk); x.lineTo(X + 4, Y - 22 * hk); x.lineTo(X + 7, Y); x.closePath(); x.fill()
					x.fillStyle = rgba(255, 255, 255, 0.7 * hk); x.fillRect(X - 3, Y - 18 * hk, 1, 10 * hk)
			"pillar":
				var X = s.x - sx
				var Y = M.floorY - sy
				if s.t > 0 and s.t < s.warn:
					x.strokeStyle = rgba(200, 160, 100, 0.5 + 0.4 * absf(sin(s.t * 20))); x.lineWidth = 1
					x.beginPath(); x.moveTo(X - 10, Y - 1); x.lineTo(X - 3, Y - 3); x.lineTo(X + 2, Y - 1); x.lineTo(X + 10, Y - 2); x.stroke()
				elif s.t >= s.warn:
					var up = minf(1, (s.t - s.warn) / 0.12)
					var down = clampf((s.t - s.warn - 1.2) / 0.4, 0, 1)
					var h = 84 * up * (1 - down)
					x.fillStyle = "#5a4a3a"; x.fillRect(X - 11, Y - h, 22, h)
					x.fillStyle = "#7a6a52"; x.fillRect(X - 11, Y - h, 22, 3); x.fillRect(X - 11, Y - h, 3, h)
					x.fillStyle = "#3a2e24"; x.fillRect(X + 6, Y - h, 5, h)
			"skybeam":
				var X = s.x - sx
				var top = M.get("ceilY", 30) - sy
				var Y = M.floorY - sy
				if s.t > 0 and s.t < s.warn:
					x.strokeStyle = rgba(230, 180, 255, 0.3 + 0.3 * absf(sin(s.t * 18))); x.lineWidth = 0.8
					x.beginPath(); x.moveTo(X, top); x.lineTo(X, Y); x.stroke()
					x.beginPath(); x.ellipse(X, Y - 1, 12, 3, 0, 0, TAU); x.stroke()
				elif s.t >= s.warn:
					var k = 1 - (s.t - s.warn) / 0.5
					var w: float = s.w * (0.6 + 0.4 * k)
					var g = x.createLinearGradient(X - w, 0, X + w, 0)
					g.addColorStop(0, rgba(160, 60, 255, 0)); g.addColorStop(0.5, rgba(250, 230, 255, 0.95 * k)); g.addColorStop(1, rgba(160, 60, 255, 0))
					x.fillStyle = g; x.fillRect(X - w, top, w * 2, Y - top)
			"circle":
				var X = s.x - sx
				var Y = M.floorY - sy
				var k = minf(1, s.t / 0.6)
				x.strokeStyle = rgba(255, 40, 70, 0.8 * k); x.lineWidth = 1.2
				x.beginPath(); x.ellipse(X, Y - 1, 30 * k, 7 * k, 0, 0, TAU); x.stroke()
				x.beginPath(); x.ellipse(X, Y - 1, 20 * k, 4.5 * k, 0, 0, TAU); x.stroke()
				for i in 5:
					var a = rt * 1.5 + i * TAU / 5
					x.fillStyle = rgba(255, 60, 90, k); x.fillRect(X + cos(a) * 25 * k - 1, Y - 1 + sin(a) * 6 * k - 1, 2, 2)
			"swat":
				var X = s.x - sx
				var Y = s.y - sy
				var k = 1 - s.t / 0.25
				x.strokeStyle = rgba(255, 120, 230, k); x.lineWidth = 2
				x.beginPath(); x.arc(X, Y, 14 + (1 - k) * 8, -1.2, 1.2); x.stroke()
	# the energy balls (they live in the monster list so Rock's sword can find them)
	for q in slimes:
		if q.bossPart and q.data.get("kind") == "orb":
			var X = q.x - sx
			var Y = q.y - 6 - sy
			var c = css("#ff4ad8") if q.data.to == "you" else css("#ffffff")
			var g = x.createRadialGradient(X, Y, 1, X, Y, 13)
			g.addColorStop(0, Color(1, 1, 1, 1)); g.addColorStop(0.35, Color(c, 0.9)); g.addColorStop(1, Color(c, 0))
			x.fillStyle = g; x.beginPath(); x.arc(X, Y, 13, 0, TAU); x.fill()
			x.strokeStyle = Color(c, 0.8); x.lineWidth = 0.8
			x.beginPath()
			for k in 5:
				var a = realTime * 12 + k * 1.3
				x.moveTo(X, Y); x.lineTo(X + cos(a) * rand(6, 11), Y + sin(a) * rand(6, 11))
			x.stroke()
	# frozen: a block of ice around the hero
	if P.held != null and P.held.get("kind") == "frozen":
		var X = P.x - sx
		var Y = P.y - sy
		x.fillStyle = rgba(190, 240, 255, 0.45)
		x.fillRect(X - 12, Y - 40, 24, 40)
		x.strokeStyle = rgba(240, 255, 255, 0.9); x.lineWidth = 1
		x.strokeRect(X - 12, Y - 40, 24, 40)
		x.fillStyle = rgba(255, 255, 255, 0.6); x.fillRect(X - 9, Y - 37, 2, 14); x.fillRect(X - 5, Y - 37, 6, 2)


## the abyssal demon (drawn in code): hulking, horned, burning
func drawSpecialMob(x: Ctx, e, sx: float, sy: float) -> bool:
	if e.type != "gdemon":
		return super.drawSpecialMob(x, e, sx, sy)
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy)
	var D: Dictionary = e.data
	var rise: float = D.get("rise", 1.0)
	var a = 1.0
	if e.state == "dead":
		a = clampf(1 - e.deadT / 0.45, 0, 1)
	var flash = e.flash > 0
	var rt = realTime
	x.save()
	x.globalAlpha = a
	x.translate(X, Y + (1 - rise) * 50)
	x.scale(e.face, 1)
	var body = "#3a0a18" if not flash else "#ffffff"
	var bodyL = "#6a1428" if not flash else "#ffffff"
	var crouch = 5.0 if e.state == "wind" else 0.0
	var w: float = e.t * 8 if absf(e.vx) > 5 else 0.0
	# legs (goat-like)
	for s in [-1, 1]:
		var hipp = Vector2(s * 7, -26 + crouch)
		var foot = Vector2(s * 8 + sin(w + (0.0 if s > 0 else PI)) * 8, 0)
		var k = _ik(hipp, foot, 15, 15, -1.0)
		_seg(x, hipp, k[0], 5.5, 4.5, body, null)
		_seg(x, k[0], k[1], 4.5, 3, body, null)
		x.fillStyle = "#14040a"; x.fillRect(k[1].x - 4, k[1].y - 2, 7, 3)
	# the torso: hunched, broad
	x.fillStyle = body
	x.beginPath(); x.moveTo(-10, -26 + crouch); x.lineTo(10, -26 + crouch); x.lineTo(18, -50 + crouch); x.lineTo(8, -60 + crouch); x.lineTo(-12, -58 + crouch); x.lineTo(-18, -46 + crouch); x.closePath(); x.fill()
	x.fillStyle = bodyL
	x.beginPath(); x.moveTo(-6, -30 + crouch); x.lineTo(8, -30 + crouch); x.lineTo(12, -48 + crouch); x.lineTo(-4, -50 + crouch); x.closePath(); x.fill()
	# cracks of fire in its hide
	x.strokeStyle = rgba(255, 120, 40, 0.7 + 0.3 * sin(rt * 6)); x.lineWidth = 0.8
	x.beginPath(); x.moveTo(-8, -44 + crouch); x.lineTo(-2, -40 + crouch); x.lineTo(2, -46 + crouch); x.moveTo(4, -34 + crouch); x.lineTo(9, -38 + crouch); x.stroke()
	# wings, small and ragged
	x.fillStyle = "#1a0410"
	x.beginPath(); x.moveTo(-10, -56 + crouch); x.lineTo(-30, -74 + sin(rt * 3) * 3); x.lineTo(-26, -58); x.lineTo(-34, -52); x.lineTo(-14, -48 + crouch); x.closePath(); x.fill()
	# arms with claws
	var hand = Vector2(18, -34 + crouch)
	if e.state == "act" and e.move == "claw":
		hand = Vector2(30, -50) if D.get("n", 0) == 0 else Vector2(28, -20)
	elif e.state == "wind" and e.move == "claw":
		hand = Vector2(-6, -62)
	var shp = Vector2(10, -54 + crouch)
	var ak = _ik(shp, hand, 14, 14, 1.0)
	_seg(x, shp, ak[0], 5, 4.5, bodyL, null)
	_seg(x, ak[0], ak[1], 4.5, 4, bodyL, null)
	x.fillStyle = "#e8d8c0"
	for c in 3:
		x.beginPath(); x.moveTo(ak[1].x, ak[1].y - 2 + c * 2); x.lineTo(ak[1].x + 7, ak[1].y - 3 + c * 3); x.lineTo(ak[1].x, ak[1].y + c * 2); x.closePath(); x.fill()
	# the head: horned, burning eyes, a mouth full of light
	var hy = -62 + crouch
	x.fillStyle = body; x.beginPath(); x.ellipse(10, hy, 8, 7, 0, 0, TAU); x.fill()
	x.fillStyle = "#e8d8c0"
	x.beginPath(); x.moveTo(6, hy - 5); x.quadraticCurveTo(0, hy - 16, -8, hy - 14); x.lineTo(4, hy - 3); x.closePath(); x.fill()
	x.beginPath(); x.moveTo(12, hy - 6); x.quadraticCurveTo(16, hy - 18, 10, hy - 22); x.lineTo(15, hy - 5); x.closePath(); x.fill()
	x.fillStyle = "#ffd23a"; x.fillRect(12, hy - 2, 3, 1.5); x.fillRect(16, hy - 2, 2, 1.5)
	var mouth = 1.0 if (e.state == "act" and e.move == "breath") else 0.0
	x.fillStyle = rgba(255, 160, 40, 0.6 + 0.4 * mouth); x.fillRect(12, hy + 3, 6, 1.5 + mouth * 2)
	x.restore()
	# its name over its head
	if e.state != "dead":
		x.font = FONT
		x.textAlign = "center"
		var hp = clampf(e.hp / e.maxHp, 0, 1)
		x.fillStyle = "#1a0410"; x.fillRect(X - 20, Y - 84, 40, 4)
		x.fillStyle = "#ff3a5a"; x.fillRect(X - 19, Y - 83, 38 * hp, 2)
	return true


## the stories told in the cutscene screens (the ending, and later the others)
func drawVolcanoStory(x: Ctx, t: float, kind: String) -> void:
	match kind:
		"g_end", "g_end2":
			# a "happy ending": the crystal shattered, the hero and their loved one together, a sunrise
			var g = x.createLinearGradient(0, 0, 0, 216)
			g.addColorStop(0, "#ffb878"); g.addColorStop(0.55, "#ff7a8a"); g.addColorStop(1, "#5a2a6a")
			x.fillStyle = g; x.fillRect(0, 0, 384, 216)
			x.fillStyle = rgba(255, 240, 200, 0.9); x.beginPath(); x.arc(192, 150, 34, 0, TAU); x.fill()
			x.fillStyle = "#2a1430"; x.fillRect(0, 160, 384, 56)
			x.fillStyle = "#3a1a40"
			x.beginPath(); x.moveTo(0, 160); x.lineTo(60, 128); x.lineTo(110, 160); x.lineTo(170, 120); x.lineTo(230, 160); x.lineTo(300, 130); x.lineTo(384, 160); x.closePath(); x.fill()
			var tex = Assets.tex("kin/%s.png" % classId)
			heroPic2(x, classId, 170, 172, 1.4)
			if tex != null:
				x.drawImage(tex, 196, 128, 30, 45)
			for i in 30:
				var k = fmod(_irnd2(i) + t * 0.08, 1.0)
				x.fillStyle = rgba(255, 255, 255, 0.5 * (1 - k)); x.fillRect(_irnd2(i + 9) * 384, 216 - k * 200, 1, 1)
			if kind == "g_end2":
				# THE END ... and then the picture slowly goes black on its own
				intro.btn = "Next"
				x.fillStyle = rgba(0, 0, 0, clampf((t - 2.5) / 2.5, 0, 1)); x.fillRect(0, 0, 384, 216)
				if t > 5.2 and not intro.get("auto2", false):
					intro.auto2 = true
					call_deferred("introNext")
		"g_laugh":
			# the picture fades to black, and somebody laughs
			x.fillStyle = Color(0, 0, 0, 1); x.fillRect(0, 0, 384, 216)
			if t > 1.8:
				var a = clampf((t - 1.8) / 0.8, 0, 1) * (0.6 + 0.4 * sin(t * 7))
				for ex in [176, 204]:
					x.fillStyle = rgba(255, 58, 216, a); x.fillRect(ex - 4, 104, 8, 2)
					x.fillStyle = rgba(255, 140, 240, a * 0.3); x.fillRect(ex - 7, 101, 14, 8)
			if not intro.get("laughed", false):
				intro.laughed = true
				_maniacalLaugh()
			if t > 6.0 and not intro.get("auto", false):
				intro.auto = true
				call_deferred("introNext")
		_:
			super.drawVolcanoStory(x, t, kind)


func _irnd2(i: int) -> float:
	return fposmod(sin(i * 127.1 + 311.7) * 43758.5453, 1.0)


## a laugh, built out of short falling tones: "ha… ha ha… HA HA HA HA"
func _maniacalLaugh() -> void:
	var at = 1.2
	var p = 220.0
	for i in 11:
		var loud = 0.05 + i * 0.008
		Sfx.tone(p * (1.0 + 0.04 * (i % 3)), 0.16, "sawtooth", loud, p * 0.7, at)
		Sfx.tone(p * 2.01, 0.14, "triangle", loud * 0.5, p * 1.4, at)
		Sfx.burst(0.12, "bandpass", 900, 1600, loud * 0.8, at)
		at += 0.42 if i < 2 else (0.26 if i < 6 else 0.2)
		p *= 1.03 if i < 6 else 0.97
	Sfx.tone(60, 3.0, "sawtooth", 0.06, 40, 0.8)


## a hero's standing picture at (X, Y) feet, scale k, for the story screens
func heroPic2(x: Ctx, cls: String, X: float, Y: float, k: float) -> void:
	var look = lookOf(cls)
	var A = Assets.hero_anim(look, "idle")
	var tex = Assets.hero_strip(look, "idle", 1)
	if tex == null:
		return
	x.drawFrame(tex, int(A.frames), 0, X - RX * k, Y - GROUND * k, SW * k, SH * k)
