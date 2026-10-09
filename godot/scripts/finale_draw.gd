extends "res://scripts/showdown_draw.gd"
## Sproutvale, the finale drawn: the heroes in Glamrax's crystals, the meteors on their homes, the
## crystal you choose (it lights up under the mouse and shatters when you pick it), the bruised hero,
## Rock's sword and Tank's shot, and the neighborhood they build afterwards.

## each home's painted map: [left, right] of the house in the 2200×600 picture (the floor is at 520)
const FIN_SRC := {"rock": [760, 1120], "archer": [740, 1150], "mage": [640, 1250], "summoner": [740, 1130], "tank": [760, 1120]}
const FIN_FLOOR := 520.0


# ================================================================ in the sanctum

func podWho(i: int) -> String:
	if not FIN.get("on", false):
		return "" if save.get("finaleDone", false) else super.podWho(i)   # everyone went home
	var h: String = GX_PODS[i]
	if h == FIN.cls or FIN.freed.has(h) or FIN.get("stage", "") == "end":
		return ""   # broken open
	return "hero:" + h


func drawPlayer(x: Ctx, sx: float, sy: float, dt: float) -> void:
	super.drawPlayer(x, sx, sy, dt)
	if not FIN.get("on", false) or P.state == "dead":
		return
	# bloody and bruised, fresh out of the crystal
	var X = roundf(P.x - sx)
	var Y = roundf(P.y - sy)
	var f: int = P.face
	x.fillStyle = "#a0102a"
	x.fillRect(X + f * 2, Y - 37, 2, 1); x.fillRect(X + f * 3, Y - 36, 1, 3)
	x.fillRect(X - f * 3, Y - 24, 3, 1); x.fillRect(X - f * 2, Y - 23, 1, 2)
	x.fillStyle = "#6a3a8a"
	x.fillRect(X - f * 1, Y - 34, 2, 2)
	if randf() < dt * 0.8:
		part(P.x + f * 3, P.y - 33, 0, 10, 0.6, "#a0102a", 300, 1)


func drawTrophyKind(x: Ctx, id: String, X: float, Y: float) -> bool:
	if id != "glamrax":
		return super.drawTrophyKind(x, id, X, Y)
	# a violet crystal with a pair of little horns
	x.fillStyle = "#c88aff"
	x.beginPath(); x.moveTo(X, Y - 38); x.lineTo(X + 6, Y - 32); x.lineTo(X + 6, Y - 25); x.lineTo(X, Y - 21); x.lineTo(X - 6, Y - 25); x.lineTo(X - 6, Y - 32); x.closePath(); x.fill()
	x.fillStyle = "#f4e8ff"; x.fillRect(X - 3, Y - 34, 2, 5)
	x.fillStyle = "#2a0a1a"; x.fillRect(X - 7, Y - 39, 2, 3); x.fillRect(X + 5, Y - 39, 2, 3)
	x.fillStyle = "#ff4ad8"; x.fillRect(X - 1, Y - 30, 2, 2)
	return true


# ================================================================ choosing a crystal

func _chooseIndex() -> int:
	if intro == null:
		return -1
	for i in intro.scenes.size():
		if intro.scenes[i].kind == "f_choose":
			return i
	return -1


func _onChoose() -> bool:
	return intro != null and intro.scenes[intro.i].kind == "f_choose"


func _crystalAt(i: int) -> Vector2:
	return Vector2(52.0 + i * 70, 84.0 + (i % 2) * 8)


func introNext() -> void:
	if _onChoose():
		if intro.shown < intro.scenes[intro.i].text.length():
			intro.shown = intro.scenes[intro.i].text.length()
			return
		_pickCrystal(int(intro.get("sel", 0)))
		return
	super.introNext()


func introSkip() -> void:
	var ci = _chooseIndex()
	if ci >= 0 and not intro.has("chosen"):
		if intro.i < ci:   # the story can be skipped, the choice can't
			intro.i = ci
			intro.shown = 0
			intro.t = 0.0
			intro.btn = "Choose"
			return
		_pickCrystal(int(intro.get("sel", 0)))
		return
	super.introSkip()


## a click on the story screen (game.gd): did it land on a crystal?
func crystalClick(pos: Vector2) -> bool:
	if not _onChoose():
		return false
	for i in GX_PODS.size():
		var c = _crystalAt(i)
		if absf(pos.x - c.x) < 28 and absf(pos.y - c.y) < 44:
			intro.sel = i
			_pickCrystal(i)
			return true
	return false


func crystalStep(d: int) -> void:
	if not _onChoose() or intro.has("chosen"):
		return
	intro.sel = posmod(int(intro.get("sel", 0)) + d, GX_PODS.size())
	Sfx.tone(700 + intro.sel * 60, 0.12, "sine", 0.04, 900)


func _pickCrystal(i: int) -> void:
	if intro.has("chosen"):
		return
	var h: String = GX_PODS[clampi(i, 0, GX_PODS.size() - 1)]
	intro.chosen = h
	intro.chosenT = intro.t
	intro.btn = "..."
	FIN.pick = h
	Sfx.burst(0.8, "highpass", 3000, 900, 0.35)
	Sfx.tone(1200, 0.6, "triangle", 0.06, 300)
	Sfx.tone(90, 1.2, "sawtooth", 0.06, 50)


# ================================================================ the story cards

func drawVolcanoStory(x: Ctx, t: float, kind: String) -> void:
	if kind.begins_with("f_sky_") or kind.begins_with("f_hit_"):
		_finMeteor(x, t, kind.substr(6), kind.begins_with("f_hit_"))
		return
	match kind:
		"f_lair":
			_gbRoom(x, t)
			_finMachine(x, t)
			for i in GX_PODS.size():
				var c = Vector2(46.0 + i * 50, 74.0 + (i % 2) * 10)
				_finCable(x, c, Vector2(330, 70 + i * 12), t + i)
				_crystal(x, c.x, c.y + sin(t * 1.3 + i) * 2, "hero:" + GX_PODS[i], t + i, 0.95)
			# he laughs, shaking with it
			var sh = sin(t * 30) * (1.0 if t > 0.6 else 0.0)
			_gbGlamrax(x, 290 + sh, 168, -1, "float", t, 1.3)
			if not intro.get("laughed", false) and t > 0.4:
				intro.laughed = true
				_maniacalLaugh()
		"f_absorb":
			_gbRoom(x, t)
			_finMachine(x, t)
			var gx = 290.0
			var gy = 128.0
			for i in GX_PODS.size():
				var c = Vector2(46.0 + i * 50, 74.0 + (i % 2) * 10)
				_crystal(x, c.x, c.y, "hero:" + GX_PODS[i], t + i, 0.95)
				# their strength, pulled out in streams of light
				var k = clampf(t / 1.2, 0, 1)
				x.strokeStyle = rgba(255, 120, 240, 0.25 * k); x.lineWidth = 5
				x.beginPath(); x.moveTo(c.x, c.y); x.lineTo(gx, gy); x.stroke()
				x.strokeStyle = rgba(255, 230, 255, 0.8 * k); x.lineWidth = 1.2
				x.beginPath(); x.moveTo(c.x, c.y); x.lineTo(gx, gy); x.stroke()
				for n in 3:
					var u = fmod(t * 0.9 + n / 3.0 + i * 0.17, 1.0)
					x.fillStyle = "#ffffff"; x.fillRect(lerpf(c.x, gx, u) - 1, lerpf(c.y, gy, u) - 1, 2, 2)
			_gbGlamrax(x, gx, 168, -1, "cast", t, 1.3)
			var w = clampf((t - 1.5) / 2.5, 0, 0.75)
			var g = x.createRadialGradient(gx, gy, 2, gx, gy, 40 + w * 160)
			g.addColorStop(0, rgba(255, 255, 255, w)); g.addColorStop(1, rgba(255, 200, 255, 0))
			x.fillStyle = g; x.fillRect(0, 0, 384, 216)
			if t > 1.0 and not intro.get("hum", false):
				intro.hum = true
				Sfx.tone(70, 3.0, "sawtooth", 0.07, 140)
		"f_choose":
			_finChoose(x, t)
		"f_stab":
			_gbRoom(x, t)
			var hit = t > 0.7
			_finGlamrax(x, 236, 166, -1, "dazed" if not hit else "dazed", t, 1.25)
			_finHero(x, "rock", 196, 166, 1, "thrust", minf(t, 0.7) if not hit else 0.7, 1.25)
			if hit:
				# the blade, through and out the back
				x.fillStyle = "#e8eef4"; x.fillRect(214, 138, 40, 2)
				x.fillStyle = "#a0102a"; x.fillRect(236, 138, 18, 2)
				if not intro.get("stabbed", false):
					intro.stabbed = true
					Sfx.tone(160, 0.5, "sawtooth", 0.09, 60)
					Sfx.burst(0.3, "bandpass", 1200, 400, 0.3)
				var a = clampf(1.0 - (t - 0.7) / 0.5, 0, 1)
				x.fillStyle = rgba(255, 30, 60, 0.4 * a); x.fillRect(0, 0, 384, 216)
				for i in 8:
					var k = fmod(t * 0.6 + _irnd2(i), 1.0)
					x.fillStyle = "#a0102a"; x.fillRect(238 + _irnd2(i + 3) * 10, 142 + k * 24, 1, 2)
		"f_shot":
			_gbRoom(x, t)
			var fired = t > 1.4
			if not fired:
				_finGlamrax(x, 250, 166, -1, "dazed", t, 1.25)
			else:
				_finGlamrax(x, 254, 170, -1, "lying", t, 1.25)
			_finHero(x, "tank", 150, 166, 1, "a_shoot", minf(t, 0.3), 1.25)
			if fired:
				var a = clampf(1.0 - (t - 1.4) / 0.25, 0, 1)
				x.fillStyle = rgba(255, 250, 220, a); x.fillRect(0, 0, 384, 216)
				if t < 1.55:
					x.fillStyle = "#ffe14d"; x.fillRect(176, 132, 8, 4)
				if not intro.get("bang", false):
					intro.bang = true
					Sfx.tone(140, 0.3, "square", 0.12, 40)
					Sfx.burst(0.5, "lowpass", 1800, 200, 0.4)
				# then nothing but the machine winding down
				var dark = clampf((t - 2.4) / 1.5, 0, 0.6)
				x.fillStyle = rgba(0, 0, 0, dark); x.fillRect(0, 0, 384, 216)
		"f_free":
			_gbRoom(x, t)
			for i in GX_PODS.size():
				var h: String = GX_PODS[i]
				var X = 56.0 + i * 68
				var crack = clampf((t - 0.4 - i * 0.15) / 0.4, 0, 1)
				if crack < 1:
					x.globalAlpha = 1 - crack
					_crystal(x, X, 70, h, t + i, 0.9)
					x.globalAlpha = 1
					if crack > 0:
						for n in 6:
							var a = _irnd2(i * 7 + n) * TAU
							x.fillStyle = "#e8d0ff"; x.fillRect(X + cos(a) * crack * 40, 70 + sin(a) * crack * 40 + crack * crack * 30, 2, 2)
				heroPic2(x, h, X - 8, 168, 1.0)
				# they fall, and somebody catches them
				var fall = clampf((t - 0.8 - i * 0.15) / 0.5, 0, 1)
				var tex = Assets.tex("kin/%s.png" % h)
				if tex != null and crack >= 1:
					x.drawImage(tex, X + 2, lerpf(60, 138, fall), 20, 30)
				if not intro.get("crack", false) and t > 0.4:
					intro.crack = true
					Sfx.burst(0.9, "highpass", 3000, 900, 0.35)
		"f_build":
			_finDay(x, t, false)
			for i in GX_PODS.size():
				var h: String = GX_PODS[i]
				var k = clampf((t - i * 0.5) / 2.2, 0, 1)
				_finHouse(x, h, 44.0 + i * 74, 140, 0.17, k)
				if k < 1:
					# scaffolding while it goes up
					x.strokeStyle = "#8e5c36"; x.lineWidth = 1
					x.strokeRect(24.0 + i * 74, 140 - 50 * k - 4, 40, 50 * k + 4)
				heroPic2(x, h, 30.0 + i * 74 + (sin(t * 4 + i) * 2), 158, 0.7)
			for i in 6:
				x.fillStyle = "#c8a070"; x.fillRect(_irnd2(i) * 384, 144 + _irnd2(i + 5) * 10, 2, 2)
		"f_happy", "f_end":
			_finDay(x, t, true)
			for i in GX_PODS.size():
				var h: String = GX_PODS[i]
				_finHouse(x, h, 44.0 + i * 74, 140, 0.17, 1.0)
				heroPic2(x, h, 34.0 + i * 74, 160, 0.75)
				var tex = Assets.tex("kin/%s.png" % h)
				if tex != null:
					var hop = absf(sin(t * 3 + i)) * 3
					x.drawImage(tex, 46.0 + i * 74, 140 - hop, 14, 21)
			for i in 30:
				var k = fmod(_irnd2(i) + t * 0.08, 1.0)
				x.fillStyle = rgba(255, 255, 220, 0.6 * (1 - k)); x.fillRect(_irnd2(i + 9) * 384, 210 - k * 200, 1, 1)
			if kind == "f_end":
				intro.btn = "Back to the menu"
		_:
			super.drawVolcanoStory(x, t, kind)


## the crystals, side by side: the one under the mouse lights up; the one you pick shatters
func _finChoose(x: Ctx, t: float) -> void:
	x.fillStyle = "#0a0410"; x.fillRect(0, 0, 384, 216)
	var g0 = x.createRadialGradient(192, 90, 4, 192, 90, 200)
	g0.addColorStop(0, rgba(120, 30, 160, 0.35)); g0.addColorStop(1, rgba(120, 30, 160, 0))
	x.fillStyle = g0; x.fillRect(0, 0, 384, 216)
	intro.btn = "Choose" if not intro.has("chosen") else "..."
	if not intro.has("sel"):
		intro.sel = GX_PODS.find(classId) if GX_PODS.has(classId) else 0
	var chosen: String = intro.get("chosen", "")
	if chosen == "":
		for i in GX_PODS.size():
			var c = _crystalAt(i)
			if absf(ptr.x - c.x) < 28 and absf(ptr.y - c.y) < 44 and intro.sel != i:
				intro.sel = i
				Sfx.tone(700 + i * 60, 0.12, "sine", 0.04, 900)
	var ct: float = t - intro.get("chosenT", t)
	x.font = FONT
	x.textAlign = "center"
	for i in GX_PODS.size():
		var h: String = GX_PODS[i]
		var c = _crystalAt(i)
		var Y = c.y + sin(t * 1.3 + i) * 2
		var on: bool = i == intro.sel
		if chosen == h:
			if ct < 0.25:
				_finGlow(x, c.x, Y, 60, 1.0)
				_crystal(x, c.x + rand(-2, 2), Y, "hero:" + h, t + i, 1.3)
			else:
				# shards everywhere, and the hero drops out of it
				var k = ct - 0.25
				for n in 22:
					var a = _irnd2(i * 31 + n) * TAU
					var r = k * (80 + _irnd2(n) * 80)
					x.fillStyle = ["#e8d0ff", "#bff4ff", "#c88aff"][n % 3]
					x.fillRect(c.x + cos(a) * r, Y + sin(a) * r + k * k * 120, 3, 2)
				_finGlow(x, c.x, Y, 80, clampf(1.0 - k, 0, 1))
				heroPic2(x, h, c.x, minf(150, Y + 26 + k * k * 260), 0.8)
			continue
		if chosen != "":
			x.globalAlpha = 0.45
		if on and chosen == "":
			_finGlow(x, c.x, Y, 50 + sin(t * 4) * 4, 0.7)
		_crystal(x, c.x, Y, "hero:" + h, t + i, 1.3 if on and chosen == "" else 1.15)
		x.globalAlpha = 1
		x.fillStyle = "#ffffff" if on else "#a890c0"
		x.fillText(CLASSES[h].name, c.x, 146)
	if chosen == "":
		x.fillStyle = "#c8b0e0"
		x.fillText("Click a crystal  ·  ← → and Enter", 192, 14)
	elif ct > 1.7 and not intro.get("auto", false):
		intro.auto = true
		call_deferred("_introFinish")


func _finGlow(x: Ctx, X: float, Y: float, r: float, a: float) -> void:
	var g = x.createRadialGradient(X, Y, 2, X, Y, r)
	g.addColorStop(0, rgba(255, 220, 255, 0.55 * a)); g.addColorStop(0.5, rgba(200, 120, 255, 0.25 * a)); g.addColorStop(1, rgba(200, 120, 255, 0))
	x.fillStyle = g; x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()


## the meteors: one scene with it coming down, one after it lands
func _finMeteor(x: Ctx, t: float, h: String, hit: bool) -> void:
	var g = x.createLinearGradient(0, 0, 0, 216)
	if hit:
		g.addColorStop(0, "#1a0608"); g.addColorStop(1, "#5a1a10")
	else:
		g.addColorStop(0, "#1a1030"); g.addColorStop(0.6, "#6a2a5a"); g.addColorStop(1, "#ff8a5a")
	x.fillStyle = g; x.fillRect(0, 0, 384, 216)
	for i in 24:
		x.fillStyle = rgba(255, 255, 255, 0.5 if not hit else 0.15); x.fillRect(_irnd2(i) * 384, _irnd2(i + 50) * 100, 1, 1)
	var gy = 150.0   # above the text box
	var hx = 192.0
	if not hit:
		var k = clampf(t / 2.6, 0, 1)
		var m = Vector2(lerpf(420, hx + 30, k * 0.85), lerpf(-30, gy - 70, k * 0.85))
		# the light on the ground gets brighter the closer it comes
		var gl = x.createRadialGradient(hx, gy, 4, hx, gy, 160)
		gl.addColorStop(0, rgba(255, 140, 60, 0.35 * k)); gl.addColorStop(1, rgba(255, 140, 60, 0))
		x.fillStyle = gl; x.fillRect(0, 0, 384, 216)
		_finHouse(x, h, hx, gy, 0.34, 1.0, true)
		x.fillStyle = "#3a6a2a"; x.fillRect(0, gy, 384, 216 - gy)
		x.fillStyle = "#5a3a20"; x.fillRect(0, gy + 6, 384, 216 - gy)
		for n in 10:   # its tail
			var u = n / 10.0
			x.fillStyle = rgba(255, 180 - n * 12, 60, 0.7 * (1 - u))
			var r = 9.0 * (1 - u * 0.7)
			x.beginPath(); x.arc(m.x + u * 70, m.y - u * 50, r, 0, TAU); x.fill()
		x.fillStyle = "#3a1a10"; x.beginPath(); x.arc(m.x, m.y, 7, 0, TAU); x.fill()
		x.fillStyle = "#ffd27a"; x.beginPath(); x.arc(m.x - 2, m.y + 2, 3, 0, TAU); x.fill()
		if not intro.get("rumble", false):
			intro.rumble = true
			Sfx.tone(50, 3.5, "sawtooth", 0.07, 70)
	else:
		_finHouse(x, h, hx, gy, 0.34, 1.0, true)
		x.fillStyle = rgba(30, 6, 6, 0.62); x.fillRect(0, 0, 384, 216)
		x.fillStyle = "#2a1a10"; x.fillRect(0, gy, 384, 216 - gy)
		var cg = x.createRadialGradient(hx, gy, 4, hx, gy, 90)
		cg.addColorStop(0, rgba(255, 120, 40, 0.7)); cg.addColorStop(1, rgba(255, 60, 20, 0))
		x.fillStyle = cg; x.fillRect(0, 0, 384, 216)
		for i in 40:   # fire
			var k = fmod(t * (0.7 + _irnd2(i) * 0.6) + _irnd2(i + 7), 1.0)
			var fx = hx - 80 + _irnd2(i + 3) * 160
			x.fillStyle = rgba(255, 200 - int(k * 150), 40, 0.9 * (1 - k))
			x.fillRect(fx + sin(t * 3 + i) * 3, gy - k * 70, 3, 3)
		for i in 6:   # smoke
			var k = fmod(t * 0.2 + i / 6.0, 1.0)
			x.fillStyle = rgba(40, 30, 30, 0.5 * (1 - k))
			x.beginPath(); x.arc(hx - 40 + i * 16 + k * 20, gy - 40 - k * 120, 10 + k * 26, 0, TAU); x.fill()
		var a = clampf(1.0 - t / 0.7, 0, 1)
		x.fillStyle = rgba(255, 240, 200, a); x.fillRect(0, 0, 384, 216)
		if not intro.get("boom", false):
			intro.boom = true
			Sfx.burst(1.2, "lowpass", 900, 80, 0.5)
			Sfx.tone(45, 1.6, "sawtooth", 0.12, 30)


## a hero's home, cut out of its painted map: centre X, floor Y, scale k, built up to `built` (0..1)
func _finHouse(x: Ctx, h: String, X: float, Y: float, k: float, built: float, wide := false) -> void:
	if h == "tank":
		if wide:
			_finHouseImg(x, "maps/home_tank.png", 600, 1280, X, Y, k, 1.0)
		var H = 240.0 * k * built
		if H <= 0:
			return
		x.save()
		x.translate(X, Y)
		x.scale(k, k)
		var ht = Assets.tex("tank/house.png")
		if ht != null:
			x.drawImageRegion(ht, 0, 240 - 240 * built, 320, 240 * built, -160, -240 * built, 320, 240 * built)
		x.restore()
		return
	var src: Array = [600, 1280] if wide else FIN_SRC[h]
	_finHouseImg(x, "maps/home_%s.png" % h, src[0], src[1], X, Y, k, built)


func _finHouseImg(x: Ctx, path: String, x0: float, x1: float, X: float, Y: float, k: float, built: float) -> void:
	var tex = Assets.tex(path)
	if tex == null or built <= 0:
		return
	var w = x1 - x0
	var top = FIN_FLOOR * (1.0 - built)
	x.drawImageRegion(tex, x0, top, w, FIN_FLOOR - top, X - w / 2 * k, Y - (FIN_FLOOR - top) * k, w * k, (FIN_FLOOR - top) * k)


## a bright day (or a sunset) over the new neighborhood
func _finDay(x: Ctx, t: float, sunset: bool) -> void:
	var g = x.createLinearGradient(0, 0, 0, 216)
	if sunset:
		g.addColorStop(0, "#ffb878"); g.addColorStop(0.6, "#ff8a8a"); g.addColorStop(1, "#8a4a7a")
	else:
		g.addColorStop(0, "#7ac8ff"); g.addColorStop(1, "#d8f0ff")
	x.fillStyle = g; x.fillRect(0, 0, 384, 216)
	x.fillStyle = rgba(255, 240, 200, 0.9) if sunset else rgba(255, 255, 230, 0.95)
	x.beginPath(); x.arc(300 if sunset else 330, 70 if sunset else 34, 22, 0, TAU); x.fill()
	# the volcano, far away and quiet now
	x.fillStyle = "#6a4a7a" if sunset else "#8a7aa0"
	x.beginPath(); x.moveTo(60, 140); x.lineTo(130, 64); x.lineTo(150, 64); x.lineTo(230, 140); x.closePath(); x.fill()
	for i in 3:
		var k = fmod(t * 0.1 + i / 3.0, 1.0)
		x.fillStyle = rgba(255, 255, 255, 0.4 * (1 - k)); x.beginPath(); x.arc(140 + k * 20, 60 - k * 40, 4 + k * 8, 0, TAU); x.fill()
	x.fillStyle = "#4a8a3a"; x.fillRect(0, 140, 384, 76)
	x.fillStyle = "#6aa84a"; x.fillRect(0, 140, 384, 2)


## his computer: screens on the right wall, every cable runs into it
func _finMachine(x: Ctx, t: float) -> void:
	x.fillStyle = "#1a1420"; x.fillRect(326, 50, 54, 116)
	for i in 4:
		var Y = 58 + i * 26
		x.fillStyle = "#0a2a2a"; x.fillRect(332, Y, 42, 18)
		for n in 4:
			x.fillStyle = rgba(90, 255, 200, 0.5 + 0.4 * sin(t * 6 + i + n)); x.fillRect(335, Y + 3 + n * 4, 6 + int(_irnd2(i * 9 + n + int(t * 4)) * 30), 1)


func _finCable(x: Ctx, a: Vector2, b: Vector2, t: float) -> void:
	var c = Vector2((a.x + b.x) / 2, maxf(a.y, b.y) + 40)
	x.strokeStyle = "#1a0e20"; x.lineWidth = 2.4
	x.beginPath(); x.moveTo(a.x, a.y + 26); x.quadraticCurveTo(c.x, c.y, b.x, b.y); x.stroke()
	x.strokeStyle = "#5a1a6a"; x.lineWidth = 1
	x.beginPath(); x.moveTo(a.x, a.y + 26); x.quadraticCurveTo(c.x, c.y, b.x, b.y); x.stroke()
	var u = fmod(t * 0.4, 1.0)
	var q = Vector2(a.x, a.y + 26).lerp(c, u).lerp(c.lerp(b, u), u)
	x.fillStyle = "#ff5ae6"; x.fillRect(q.x - 1, q.y - 1, 2, 2)


## Glamrax at the very end: robes off, horns out
func _finGlamrax(x: Ctx, X: float, Y: float, face: int, anim: String, t: float, k: float) -> void:
	x.save()
	x.translate(X, Y)
	x.scale(k, k)
	_drawGlamrax(x, 0, 0, face, {"anim": anim, "form": "muscle", "horns": 1.0}, t, false)
	x.restore()


## a hero mid-move for the story cards (frame from the time t into the animation)
func _finHero(x: Ctx, cls: String, X: float, Y: float, face: int, anim: String, t: float, k: float) -> void:
	var look = lookOf(cls)
	var anims: Dictionary = Assets.hero.looks.get(look, {}).get("anims", {})
	if not anims.has(anim):
		anim = {"a_shoot": "thrust"}.get(anim, "idle")
		if not anims.has(anim):
			anim = "idle"
	var A = Assets.hero_anim(look, anim)
	var nf = maxi(1, int(A.frames))
	var fi = mini(nf - 1, int(t * float(A.fps)))
	var tex = Assets.hero_strip(look, anim, 1)
	if tex == null:
		return
	x.save()
	x.translate(X, Y)
	x.scale(k * face, k)
	x.drawFrame(tex, nf, fi, -RX, -GROUND, SW, SH)
	x.restore()
