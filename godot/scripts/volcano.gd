extends "res://scripts/climb.gd"
## Sproutvale, part 6⅞: inside Glamrax's volcano (made for the Godot version). Four maps behind
## Glamrax's Gate (the Laboratory, the Containment Bay, the Cell Block and the Sanctum), the five
## security monsters that guard them, and what they do to you: critical hits, shocks, pins and fire.
## The Mk II (the Containment Bay's miniboss) lives in mecha.gd; Glamrax in glamrax.gd.
##
## Maps and monster stats live in res://data/volcano.json; art in res://art/volcano (baked by
## tools/bake/volcano.mjs, same layout as art/climb).

const VOLCANO_MOBS := ["sentinel", "secgolem", "sentgolem", "dog", "ferro"]
const BURN_TIME := 10.0        # seconds a Ferro-Slime's fire burns
const BURN_DASH := 2.5         # each dash pats out this much of it
const SHOCK_TIME := 1.0        # the shock recovery after a jolt

var volcShots: Array = []      # lasers, rifle rounds, shock rings
var Burn := {"t": 0.0, "tick": 0.0, "atk": 0.0, "lv": 1}
var _vSpots := {}              # map id → the spots the art left for moving things (scientists, cells…)


# ================================================================ data

func initVolcanoData() -> void:
	var A: Dictionary = normalize(Assets._json("res://data/volcano.json"))
	for id in A.maps:
		MAPS[id] = A.maps[id]
	for k in A.mobs:
		var T: Dictionary = A.mobs[k]
		T.merge({"aggro": 14, "size": 1, "w": 0, "unlock": T.lv, "critter": true, "ai": "climb", "habitat": "climb", "residue": T.matName}, false)
		SLIME_TYPES[k] = T
	SLIME_TYPES.secgolem.kb = 0.15
	SLIME_TYPES.sentgolem.kb = 0.1
	SLIME_TYPES.dog.kb = 0.7
	SLIME_KEYS = SLIME_TYPES.keys()
	for k in VOLCANO_MOBS:
		CLIMB_MOBS.append(k)   # they share the climb's sprite handling (cards, the bestiary)
	# Glamrax's Gate opens: through it, the laboratory
	for p in MAPS.peak.portals:
		if p.to == "glamrax":
			p.to = "volcano1"
			p.tx = 70
			p.erase("sealed")
	MAINQS.append({"title": "The Security System", "exp": 120000, "coins": 60000,
		"steps": ["Go through Glamrax's Gate into the volcano", "Reach the Containment Bay", "Destroy the Anti-Personnel Mecha Mk II"], "on": ["volcano1", "volcano2", "mk2"],
		"blurb": "The gate on the summit opens onto a laboratory. Glamrax's scientists work at their screens as if you weren't there. They don't need to look: the security system will deal with you."})
	MAINQS.append({"title": "Glamrax", "exp": 200000, "coins": 100000,
		"steps": ["Walk the Cell Block", "Enter Glamrax's Sanctum", "Defeat Glamrax"], "on": ["volcano3", "volcano4", "glamrax"],
		"blurb": "Past the cells, where things watch you go by, is the sanctum. Somebody is playing the piano in there."})
	for k in VOLCANO_MOBS:
		BEST_ORDER.append(k)
	BEST_TEXT.sentinel = "A floating armoured sphere with one red eye that sweeps the room. It never misses a weak spot: every hit it lands is critical. It dodges some of your attacks, fires lasers, and slams into you from one side, then the other, then the first again."
	BEST_TEXT.secgolem = "Two and a half times your height and full of mana. Its shoulder rifles never stop firing (each round stings a little and doesn't push you back), and its fists knock you flat."
	BEST_TEXT.sentgolem = "A Security Golem with a Sentinel for a head, trimmed in gold. Rare. It has every trick both of them have, and a thruster-powered dash punch that sends you flying across the room."
	BEST_TEXT.dog = "A robot hound with a steel jaw and a shock collar. It pounces, pins you to the floor and shocks you until you can barely move. Dash out of the way when it crouches."
	BEST_TEXT.ferro = "A blob of living ferrofluid. It bristles with spikes and discharges a shock, or heats up red-hot and sets you on fire. Dash again and again to put the flames out faster."
	MAT_TIPS.sentinel = "A Sentinel's lens, cracked down the middle. Still faintly red."
	MAT_TIPS.secgolem = "A length of glowing tube. The mana inside sloshes when you shake it."
	MAT_TIPS.sentgolem = "A gold-plated core. Somebody in that lab is very proud of it."
	MAT_TIPS.dog = "A steel fang. It sparks when it touches anything metal."
	MAT_TIPS.ferro = "A drop of ferrofluid that stands up in little spikes near a magnet."
	# inside the volcano on the world map
	WM_NODES.volcano1 = {"x": 800, "y": -118}
	WM_NODES.volcano2 = {"x": 905, "y": -92}
	WM_NODES.volcano3 = {"x": 790, "y": -52}
	WM_NODES.volcano4 = {"x": 895, "y": -18}
	MAPS.trophy.w = maxi(int(MAPS.trophy.w), 2400)


func volcanoMap() -> bool:
	return not M.is_empty() and M.get("theme") == "volcano"


func climbMap() -> bool:
	return super.climbMap() or volcanoMap()


## the spots the map's art left for things the game draws on top (scientists, monitors, cells…)
func vSpots(id := "") -> Dictionary:
	if id == "":
		id = mapId
	if not _vSpots.has(id):
		var path = "res://art/volcano/maps/%s.json" % id
		_vSpots[id] = Assets._json(path) if FileAccess.file_exists(path) else {}
	return _vSpots[id].get("spots", {})


func vGlows(id: String) -> Array:
	vSpots(id)
	return _vSpots[id].get("glows", []) if _vSpots.has(id) else []


## the Containment Bay's way on stays shut until the Mk II is scrap
func travel(portal: Dictionary) -> void:
	var lk = portal.get("lockedBy")
	if lk != null and not heroBeat(lk) and fadeTo == null:
		toast("The blast door is sealed. A red light over it reads: CONTAINMENT ACTIVE.")
		Sfx.tone(160, 0.25, "square", 0.08, 110)
		Sfx.tone(160, 0.25, "square", 0.08, 110, 0.3)
		return
	super.travel(portal)


func loadMap(id: String, px0 = null, py0 = null) -> void:
	volcShots.clear()
	super.loadMap(id, px0, py0)
	if volcanoMap() and inGame:
		if id == "volcano1" and not save.get("seenLab", false):
			save.seenLab = true
			later(1.2, func(): if mapId == "volcano1": toast("The scientists don't even look up. Something whirs to life near the ceiling."))


# ================================================================ statuses: burning and shocked

func statusExtra() -> Array:
	var out = []
	if Burn.t > 0:
		out.append("🔥 Burning %ds · dash to put it out" % ceili(Burn.t))
	if P.held != null and P.held.get("kind") == "shock":
		out.append("⚡ Shocked")
	return out


## set the hero on fire (a red-hot Ferro-Slime); dashing puts it out faster
func ignite(src) -> void:
	if P.state == "dead" or save.settings.god:
		return
	if Burn.t <= 0:
		floatText(P.x, P.y - 62, "On fire!", "call")
		Sfx.burst(0.5, "lowpass", 2400, 600, 0.25)
	Burn.t = BURN_TIME
	Burn.tick = 0.5
	Burn.atk = float(src.get("atk"))
	Burn.lv = int(src.get("lv"))


## a jolt that leaves you stunned for a moment (the dogs' collars, the Ferro-Slimes' sparks)
func shockStun(dur := SHOCK_TIME) -> void:
	if P.state == "dead" or P.hp <= 0 or save.settings.god:
		return
	P.held = {"kind": "shock", "t": 0.0, "dur": dur, "e": null}
	P.state = "held"
	P.vx = 0
	floatText(P.x, P.y - 60, "Shocked!", "call")
	Sfx.tone(1400, 0.4, "square", 0.06, 300)
	Sfx.burst(0.3, "highpass", 3000, 6000, 0.2)


## a hit that ignores the moment of safety after the last one (combos, pins) and lands critical
func critChip(src, mul: float, crit := true) -> bool:
	if save.settings.god or P.state == "dead":
		return false
	if P.state == "dash":
		if not P.dodged.has(src):
			P.dodged[src] = true
			perfectDodge()
		return false
	var sx: float = src.get("x")
	if P.state == "block" and (sgn(sx - P.x) == P.face or absf(sx - P.x) < 4):
		Sfx.block()
		var chip = maxi(1, roundi(src.atk * mul * 0.15))
		P.hp -= chip
		floatText(P.x, P.y - 48, str(chip), "hurt")
		if P.hp <= 0:
			killPlayer()
		return false
	var d = maxi(1, roundi(src.atk * mul * (1.5 if crit else 1.0) * defMul(src.lv) * rand(0.9, 1.1)))
	P.hp -= d
	P.lastHurt = gameTime
	P.hurtN += 1
	P.flash = 0.1
	floatText(P.x + rand(-6, 6), P.y - 48, ("%d!" % d) if crit else str(d), "hurt")
	Sfx.hurt()
	flashVig()
	shake = maxf(shake, 4 if crit else 2)
	if P.hp <= 0:
		P.held = null
		killPlayer()
	return true


func _surfBelow(x: float, y: float) -> float:
	var best = INF
	for s in surfaces:
		if x >= s.x0 and x <= s.x1 and s.y >= y - 1 and s.y < best:
			best = s.y
	return best if best < INF else groundAt(x)


func abyssHold(dt: float) -> bool:
	var H = P.held
	if H == null or not (H.get("kind") in ["shock", "dogpin"]):
		return super.abyssHold(dt)
	H.t += dt
	P.state = "held"
	P.vx = 0
	P.animT += dt
	setAnim("hurt")
	# fall to whatever is underneath (shocked in mid-air)
	var g = _surfBelow(P.x, P.y)
	if P.y < g - 0.5:
		P.vy = minf(MAXFALL, P.vy + GRAV * dt)
		P.y = minf(g, P.y + P.vy * dt)
		P.grounded = false
	else:
		P.y = g
		P.vy = 0
		P.grounded = true
	if randf() < dt * 30:
		part(P.x + rand(-8, 8), P.y - rand(4, 36), rand(-40, 40), rand(-40, 40), 0.15, "#7af0ff" if randf() < 0.6 else "#ffffff", 0, 1)
	if H.kind == "shock":
		P.x += sin(H.t * 70) * 0.4   # twitching
		if H.t >= H.dur:
			_releasePlayer()
			P.iframes = maxf(P.iframes, 0.4)
			return false
		return true
	# pinned under a Security Dog: it shocks you three times, then you're left twitching
	var e = H.e
	if e == null or e.state == "dead" or not slimes.has(e):
		_releasePlayer()
		return false
	P.spin = -P.face * PI * 0.5 * minf(1, H.t * 6)   # knocked flat on your back
	P.spinY = 0.0
	e.x = P.x + e.face * -2
	e.y = P.y - 10
	e.vx = 0; e.vy = 0
	var n = int(H.t / 0.42)
	if n > H.n and H.n < 3:
		H.n = n
		var src = {"x": e.x, "lv": e.lv, "atk": e.atk}
		abyssChip(src, 0.85, 0.0, false)
		Sfx.tone(1200, 0.25, "square", 0.08, 200)
		Sfx.burst(0.2, "highpass", 2500, 7000, 0.25)
		shake = maxf(shake, 4)
		for k in 10:
			part(P.x + rand(-10, 10), P.y - rand(0, 14), rand(-90, 90), rand(-120, 10), 0.25, "#7af0ff" if k % 2 else "#ffffff", 0, 1)
		if P.state == "dead":
			_releasePlayer()
			return false
	if H.t > 1.4:
		# it jumps off you; the shock lingers
		P.spin = 0.0
		P.spinY = 20.0
		_setState(e, "recover")
		e.vy = -200
		e.vx = e.face * -140
		e.y = groundAt(e.x) - 2
		e.atkCd = rand(2.5, 3.5)
		P.held = null
		shockStun()
		return true
	return true


# ================================================================ every frame

func updateClimb(dt: float) -> void:
	super.updateClimb(dt)
	updateVolcShots(dt)
	_updateBurn(dt)
	if not volcanoMap():
		return
	# the lab's security keeps sending more
	if M.get("lab") and spawnTimer > 1.1:
		spawnTimer = 1.1


func _updateBurn(dt: float) -> void:
	if Burn.t <= 0:
		return
	if P.state == "dead":
		Burn.t = 0
		return
	if pressed.get("c"):
		Burn.t -= BURN_DASH
		for k in 10:
			part(P.x + rand(-8, 8), P.y - rand(6, 34), rand(-60, 60), rand(-60, 0), 0.4, "#c8c0c8" if k % 2 else "#8a8290", -30, 2)
		if Burn.t <= 0:
			floatText(P.x, P.y - 58, "Flames out!", "call")
	Burn.t -= dt
	Burn.tick -= dt
	if randf() < dt * 40:
		part(P.x + rand(-7, 7), P.y - rand(4, 38), rand(-16, 16), -rand(40, 90), rand(0.25, 0.5), ["#ff6a1a", "#ffd27a", "#ff3a1a"][rint(0, 2)], -60, 1 if randf() < 0.6 else 2)
	if Burn.tick <= 0 and Burn.t > 0:
		Burn.tick = 0.5
		var d = maxi(1, roundi(Burn.atk * 0.22 * defMul(Burn.lv) * rand(0.9, 1.1)))
		if not save.settings.god:
			P.hp -= d
			floatText(P.x + rand(-6, 6), P.y - 44, str(d), "hurt")
			if P.hp <= 0:
				Burn.t = 0
				killPlayer()


# ================================================================ monsters: behaviour

func climbAI(e, T: Dictionary, dt: float, _dx: float, _dy: float, pb: Dictionary) -> bool:
	if not (e.type in VOLCANO_MOBS):
		return super.climbAI(e, T, dt, _dx, _dy, pb)
	var cx: float = e.x
	var cy: float = e.y - e.h / 2
	var tx: float = P.x - cx
	var ty: float = (P.y - 20) - cy
	var dist = sqrt(tx * tx + ty * ty)
	var sight: float = {"sentinel": 230.0, "secgolem": 240.0, "sentgolem": 260.0, "dog": 220.0, "ferro": 170.0}.get(e.type, 180.0)
	var alive: bool = P.state != "dead"
	if e.state == "idle" and alive and dist < sight and e.spawnT <= 0:
		e.aggro = true; e.bang = 0.8
		_setState(e, "chase")
		if absf(tx) < 160:
			Sfx.bang()
			if e.type in ["sentinel", "sentgolem"]:
				Sfx.tone(880, 0.12, "square", 0.05, 880)
				Sfx.tone(660, 0.12, "square", 0.05, 660, 0.14)
	if e.state == "chase" and (not alive or dist > sight * 1.8):
		e.aggro = false
		_setState(e, "idle")
	e.data.cd2 = e.data.get("cd2", 5.0) - dt
	if e.state == "hurt":
		e.stun -= dt
		if T.get("fly"):
			e.vx *= exp(-dt * 3.5)
			e.vy *= exp(-dt * 3.5)
		if e.stun <= 0:
			_setState(e, "chase")
			e.aggro = true
			e.atkCd = maxf(e.atkCd, 0.5)
	else:
		match e.type:
			"sentinel": _sentinel(e, T, dt, tx, ty, dist)
			"secgolem", "sentgolem": _secGolem(e, T, dt, tx, ty, dist)
			"dog": _dog(e, T, dt, tx, ty, dist)
			"ferro": _ferro(e, T, dt, tx, ty, dist)
	# bumping into an awake monster still hurts a little (a red-hot Ferro-Slime burns)
	if e.aggro and alive and not (e.state in ["hurt", "act"]) and P.held == null and overlap(sBox(e), pb) and P.touchCd <= 0:
		P.touchCd = 0.9
		var n0 = P.hurtN
		hurtPlayer(_src(e, e.x, {"crit": e.type == "sentinel"}), roundf(e.atk * 0.5))
		if e.type == "ferro" and e.data.get("hot", 0.0) > 0 and P.hurtN != n0:
			ignite(e)
	_climbPhysics(e, T, dt)
	return true


## the Sentinels dodge (they see every swing coming)
func damageSlime(e, mv: Dictionary, _from = null) -> void:
	if e.type == "sentinel" and e.state != "dead" and not e.boss and randf() < 0.15:
		floatText(e.x, e.y - e.h - 6, "Dodged", "call")
		Sfx.whoosh(1.4, false)
		var side = -1.0 if randf() < 0.5 else 1.0
		for k in 8:
			part(e.x + rand(-8, 8), e.y - rand(0, e.h), rand(-30, 30), rand(-30, 30), 0.3, "#ff2a3a" if k % 2 else "#c4ccd8", 0, 1)
		e.x = clampf(e.x + side * 26, 30, M.w - 30)
		e.vx = side * 120
		return
	super.damageSlime(e, mv, _from)


# ---------------- Security Sentinel: hovers, sweeps the room, lasers, and a left-right-left slam combo

func _sentinel(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var sp: float = T.speed
	match e.state:
		"idle":
			_swimTo(e, e.homeX + sin(e.t * 0.5 + e.id) * 60, e.homeY + sin(e.t * 1.9 + e.id) * 8, 50, 2, dt)
			e.face = 1 if e.vx >= 0 else -1
		"chase":
			var a = e.t * 1.3 + e.id
			_swimTo(e, P.x + cos(a) * 70, P.y - 46 + sin(a * 1.7) * 14, 140 * sp, 2.5, dt)
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			if e.atkCd <= 0:
				if dist < 90 and randf() < 0.55:
					e.move = "slam"
					D.n = 0
					_setState(e, "act")
					Sfx.tone(300, 0.3, "square", 0.05, 900)
				else:
					e.move = "laser"
					_setState(e, "wind")
					D.aim = Vector2(P.x, P.y - 22)
					Sfx.tone(500, 0.6, "sawtooth", 0.04, 1600)
		"wind":
			# charging the laser: a thin aiming line that follows you, then locks
			e.vx *= exp(-dt * 6)
			e.vy *= exp(-dt * 6)
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			if e.t < 0.45:
				D.aim = D.aim.lerp(Vector2(P.x, P.y - 22), minf(1, dt * 10))
			if e.t > 0.62:
				var o = Vector2(e.x + e.face * 5, e.y - e.h / 2)
				var dir = (D.aim - o).normalized()
				volcShots.append({"kind": "beam", "x": o.x, "y": o.y, "dx": dir.x, "dy": dir.y, "len": 280.0, "t": 0.0, "life": 0.16, "w": 3.0,
					"src": _src(e, e.x, {"crit": true, "noCrit": false}), "mul": 1.3, "hit": false, "col": "#ff2a3a"})
				Sfx.tone(1800, 0.2, "sawtooth", 0.07, 400)
				_setState(e, "recover")
		"act":
			# left, right, left: it swings round you and rams you from each side
			var side = [-1.0, 1.0, -1.0][D.n]
			var gx = P.x + side * 16
			var gy = P.y - 22
			_swimTo(e, gx, gy, 380 * sp, 9, dt)
			e.face = int(-side)
			if not e.hitDone and e.t > 0.16 and absf(e.x - gx) < 12 and absf(e.y - gy) < 14:
				e.hitDone = true
				if critChip(_src(e, e.x), 0.9):
					P.vx = -side * 140
					Sfx.slam()
					sparks(P.x, P.y - 24, "#ff2a3a", 8)
			if e.t > 0.3:
				D.n += 1
				e.t = 0.0
				e.hitDone = false
				Sfx.whoosh(1.2, true)
				if D.n >= 3:
					D.n = 0
					_setState(e, "recover")
					e.vx = side * 150
					e.vy = -120
		"recover":
			e.vx *= exp(-dt * 3)
			e.vy *= exp(-dt * 3)
			if e.t > 0.6:
				_setState(e, "chase")
				e.atkCd = rand(1.3, 2.1)


# ---------------- Security Golem: rifles that never stop, heavy punches that knock you down
# (the Sentinel-Golem uses the same body, plus a laser eye, the slam combo and a dash punch)

func _shoulder(e, which: int) -> Vector2:
	var sc: float = e.data.get("scale", 1.0) if e.elite else 1.0
	return Vector2(e.x + e.face * (34 if which else 20) * sc, e.y - (104 if which else 106) * sc)


func _secGolem(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var gold: bool = e.type == "sentgolem"
	var sp: float = T.speed
	D.fireCd = D.get("fireCd", 0.0) - dt
	D.dashCd = D.get("dashCd", 4.0) - dt
	D.laserCd = D.get("laserCd", 3.0) - dt
	var alive = P.state != "dead"
	# the rifles: a stream of rounds whenever it can see you (low damage, no push)
	if e.state in ["chase", "recover"] and alive and dist < 240 and D.fireCd <= 0:
		D.fireCd = 0.13 if gold else 0.16
		D.which = 1 - int(D.get("which", 0))
		var o = _shoulder(e, D.which)
		var a = atan2((P.y - 24) - o.y, P.x - o.x) + rand(-0.06, 0.06)
		if sgn(cos(a)) == e.face:
			volcShots.append({"kind": "round", "x": o.x + e.face * 14, "y": o.y, "vx": cos(a) * 430, "vy": sin(a) * 430, "t": 0.0, "src": _src(e, e.x), "mul": 0.1})
			D.flash = 0.06
			if randf() < 0.5:
				Sfx.tone(rand(180, 240), 0.05, "square", 0.025, 90)
	D.flash = D.get("flash", 0.0) - dt
	match e.state:
		"idle":
			_wander(e, 16 * sp, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 6 else e.face
			e.walk = e.face * 48 * sp if absf(tx) > 66 else 0.0
			var gr = _grounded(e)
			if gold and gr and D.dashCd <= 0 and absf(tx) > 90 and absf(tx) < 260 and absf(ty) < 70:
				e.move = "dash"
				_setState(e, "wind")
				e.walk = 0
				D.dashCd = rand(5, 8)
				Sfx.tone(200, 0.8, "sawtooth", 0.06, 900)
			elif gold and D.laserCd <= 0 and dist < 230:
				e.move = "laser"
				_setState(e, "wind")
				e.walk = 0
				D.laserCd = rand(4, 6)
				D.aim = Vector2(P.x, P.y - 22)
				Sfx.tone(500, 0.6, "sawtooth", 0.04, 1600)
			elif gr and e.atkCd <= 0 and absf(tx) < 86 and absf(ty) < 60:
				e.move = "combo" if gold and randf() < 0.45 else "punch"
				D.n = 0
				_setState(e, "wind")
				e.walk = 0
				Sfx.tone(90, 0.7, "sawtooth", 0.06, 60)
		"wind":
			e.walk = 0
			match e.move:
				"punch", "combo":
					if e.t > (0.55 if e.move == "punch" else 0.4):
						_setState(e, "act")
						e.vx = e.face * 140
						Sfx.whoosh(0.7, true)
				"dash":
					# thrusters spool up, then it rockets at you fist first
					if randf() < dt * 30:
						part(e.x - e.face * 30, e.y - 70, -e.face * rand(60, 160), rand(-20, 20), 0.3, "#ff8a2a" if randf() < 0.5 else "#fff0c0", 0, 2)
					if e.t > 0.6:
						_setState(e, "act")
						e.vx = e.face * 520
						Sfx.whoosh(0.5, true)
						Sfx.burst(0.6, "lowpass", 1200, 300, 0.3)
				"laser":
					if e.t < 0.5:
						D.aim = D.aim.lerp(Vector2(P.x, P.y - 22), minf(1, dt * 9))
					if e.t > 0.7:
						var o = Vector2(e.x + e.face * 8, e.y - 96)
						var dir = (D.aim - o).normalized()
						volcShots.append({"kind": "beam", "x": o.x, "y": o.y, "dx": dir.x, "dy": dir.y, "len": 320.0, "t": 0.0, "life": 0.22, "w": 5.0,
							"src": _src(e, e.x, {"crit": true}), "mul": 1.6, "hit": false, "col": "#ff2a3a"})
						Sfx.tone(1600, 0.3, "sawtooth", 0.08, 300)
						_setState(e, "recover")
		"act":
			match e.move:
				"punch", "combo":
					e.vx *= exp(-dt * 6)
					var hb = hbox(e.x, e.x + 74, e.y - 90, e.y - 10) if e.face > 0 else hbox(e.x - 74, e.x, e.y - 90, e.y - 10)
					if not e.hitDone and e.t > 0.05 and overlap(hb, pBox()):
						e.hitDone = true
						if e.move == "punch" or D.n == 2:
							if launchHit(_src(e, e.x, {"crit": gold}), 2.0):
								Sfx.tone(70, 0.3, "square", 0.1, 40)
						else:
							critChip(_src(e, e.x), 1.0, gold)
						shake = maxf(shake, 6)
						Sfx.slam()
					if e.t > 0.32:
						if e.move == "combo" and D.n < 2:
							# left, right, left: it swings again from the other side
							D.n += 1
							e.face = int(sgn(P.x - e.x)) if absf(P.x - e.x) > 4 else -e.face
							e.t = 0.0
							e.hitDone = false
							e.vx = e.face * 160
							Sfx.whoosh(0.8, true)
						else:
							_setState(e, "recover")
				"dash":
					var hb = hbox(e.x - 30, e.x + 30, e.y - 100, e.y)
					if not e.hitDone and overlap(hb, pBox()):
						e.hitDone = true
						var n0 = P.hurtN
						launchHit(_src(e, e.x, {"crit": true, "boss": true}), 3.6)
						if P.hurtN != n0:
							# sent flying across the room
							P.vx = e.face * 560
							P.vy = -420
							floatText(P.x, P.y - 64, "LAUNCHED!", "call")
							hitstop = 0.12
							shake = 12
							Sfx.burst(0.5, "lowpass", 1600, 200, 0.4)
					if randf() < dt * 40:
						part(e.x - e.face * 30, e.y - 70, -e.face * rand(80, 200), rand(-30, 30), 0.3, "#ff8a2a" if randf() < 0.5 else "#fff0c0", 0, 2)
					if e.t > 0.55 or (e.x <= 26 + e.w / 2 + 1 or e.x >= M.w - 26 - e.w / 2 - 1):
						e.vx = e.face * 60
						_setState(e, "recover")
		"recover":
			e.walk = 0
			e.vx *= exp(-dt * 5)
			if e.t > 0.9:
				_setState(e, "chase")
				e.atkCd = rand(1.6, 2.6)


# ---------------- Security Dog: runs you down, pounces, pins you and shocks you; a snapping steel jaw up close

func _dog(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var gr = _grounded(e)
	match e.state:
		"idle":
			_wander(e, 40 * T.speed, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 6 else e.face
			e.walk = e.face * 105 * T.speed if absf(tx) > 26 else 0.0
			if gr and e.atkCd <= 0 and P.held == null:
				if absf(tx) < 130 and absf(tx) > 40 and absf(ty) < 60:
					e.move = "pounce"
					_setState(e, "wind")
					e.walk = 0
					Sfx.tone(140, 0.4, "sawtooth", 0.06, 260)
				elif absf(tx) <= 40 and absf(ty) < 40:
					e.move = "bite"
					_setState(e, "wind")
					e.walk = 0
		"wind":
			e.walk = 0
			if e.move == "pounce" and e.t > 0.42:
				_setState(e, "act")
				e.vy = -300
				e.vx = clampf((P.x - e.x) / 0.55, -340, 340)
				Sfx.whoosh(1.0, true)
			elif e.move == "bite" and e.t > 0.22:
				_setState(e, "act")
				e.vx = e.face * 120
		"act":
			if e.move == "pounce":
				if not e.hitDone and overlap(sBox(e), pBox()) and P.held == null:
					e.hitDone = true
					if P.state == "dash" or P.iframes > 0:
						if P.state == "dash" and not P.dodged.has(e):
							P.dodged[e] = true
							perfectDodge()
					elif P.state == "block" and sgn(e.x - P.x) == P.face:
						hurtPlayer(e, e.atk * 1.0)   # a guard stops the pin
					elif not save.settings.god:
						# pinned!
						P.held = {"kind": "dogpin", "e": e, "t": 0.0, "n": 0}
						P.state = "held"
						P.vx = 0
						P.rope = null
						_setState(e, "pin")
						floatText(P.x, P.y - 60, "Pinned!", "call")
						Sfx.slam()
						shake = 6
						return
				if e.t > 0.15 and gr:
					_setState(e, "recover")
			else:
				e.vx *= exp(-dt * 6)
				var hb = hbox(e.x, e.x + 34, e.y - 26, e.y) if e.face > 0 else hbox(e.x - 34, e.x, e.y - 26, e.y)
				if not e.hitDone and e.t > 0.04 and overlap(hb, pBox()):
					e.hitDone = true
					mobHit(e, 1.3)
					Sfx.tone(900, 0.06, "square", 0.08, 1400)
					Sfx.tone(700, 0.06, "square", 0.08, 1100, 0.07)
				if e.t > 0.3:
					_setState(e, "recover")
		"pin":
			e.walk = 0
			if P.held == null or P.held.get("e") != e:
				_setState(e, "recover")
		"recover":
			e.walk = 0
			if e.t > 0.6:
				_setState(e, "chase")
				e.atkCd = maxf(e.atkCd, rand(1.4, 2.2))


# ---------------- Ferro-Slime: hops at you; discharges a shock, or heats up red-hot and sets you alight

func _ferro(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var gr = _grounded(e)
	D.hot = maxf(0.0, D.get("hot", 0.0) - dt)
	D.heatCd = D.get("heatCd", rand(2, 5)) - dt
	if D.hot > 0 and randf() < dt * 16:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(4, e.h), rand(-10, 10), -rand(30, 70), 0.5, "#ff6a1a" if randf() < 0.6 else "#ffd27a", -40, 1)
	match e.state:
		"idle":
			e.walk = 0
			if gr and e.hopCd <= 0:
				e.hopCd = rand(1.0, 2.2)
				e.face = -1 if randf() < 0.5 else 1
				if absf(e.x - e.homeX) > 120:
					e.face = int(sgn(e.homeX - e.x))
				e.vy = -150
				e.vx = e.face * 50
		"chase":
			e.walk = 0
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			if gr:
				e.vx *= exp(-dt * 8)
			if gr and D.heatCd <= 0 and D.hot <= 0:
				e.move = "heat"
				_setState(e, "wind")
				D.heatCd = rand(7, 10)
				Sfx.burst(0.8, "lowpass", 400, 2400, 0.2)
			elif gr and e.atkCd <= 0 and dist < 50:
				e.move = "spark"
				_setState(e, "wind")
				Sfx.tone(300, 0.5, "square", 0.04, 1600)
			elif gr and e.hopCd <= 0:
				# hops toward you; a hop that lands on you is a body slam
				e.hopCd = rand(0.6, 1.1)
				e.move = "hop"
				e.vy = -230
				e.vx = clampf(tx / 0.5, -150, 150) * T.speed
				e.hitDone = false
		"wind":
			e.vx *= exp(-dt * 8)
			if e.move == "heat" and e.t > 0.7:
				D.hot = 5.0
				floatText(e.x, e.y - e.h - 10, "Red-hot!", "call")
				Sfx.burst(0.5, "lowpass", 3000, 800, 0.25)
				_setState(e, "chase")
				e.atkCd = 0.2
			elif e.move == "spark" and e.t > 0.45:
				_setState(e, "act")
				volcShots.append({"kind": "ring", "x": e.x, "y": e.y - 8, "t": 0.0, "r": 46.0, "src": _src(e, e.x), "hit": false})
				Sfx.tone(1600, 0.3, "square", 0.08, 200)
				Sfx.burst(0.3, "highpass", 2500, 7000, 0.3)
		"act":
			if e.t > 0.4:
				_setState(e, "recover")
		"recover":
			if e.t > 0.6:
				_setState(e, "chase")
				e.atkCd = rand(1.5, 2.5)
	# a hop that lands on you
	if e.state == "chase" and e.move == "hop" and not gr and not e.hitDone and e.vy > 0 and overlap(sBox(e), pBox()):
		e.hitDone = true
		var n0 = P.hurtN
		hurtPlayer(e, e.atk * (1.7 if D.hot > 0 else 1.1))
		if D.hot > 0 and P.hurtN != n0:
			ignite(e)


# ================================================================ shots: lasers, rifle rounds, shock rings

func _segDist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var t = clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), 0, 1)
	return p.distance_to(a + ab * t)


func updateVolcShots(dt: float) -> void:
	var pb = pBox()
	for i in range(volcShots.size() - 1, -1, -1):
		var s: Dictionary = volcShots[i]
		s.t += dt
		var gone = false
		match s.kind:
			"beam":
				# a laser: instant, along a line; hits if you're on it when it fires
				if not s.hit and P.state != "dead":
					s.hit = true
					var a = Vector2(s.x, s.y)
					var b = a + Vector2(s.dx, s.dy) * s.len
					var c = Vector2(P.x, (pb.y0 + pb.y1) / 2)
					if _segDist(c, a, b) < s.w + 8:
						if s.get("chip"):
							critChip(s.src, s.mul, s.src.get("crit", false))
						else:
							hurtPlayer(s.src, s.src.atk * s.mul)
				gone = s.t > s.life
			"round":
				s.x += s.vx * dt
				s.y += s.vy * dt
				if s.x > pb.x0 - 2 and s.x < pb.x1 + 2 and s.y > pb.y0 - 2 and s.y < pb.y1 + 2 and P.state != "dead":
					abyssChip(s.src, s.mul, 0.0, true)
					gone = true
				if s.t > 1.0 or s.y > groundAt(s.x) or s.x < 0 or s.x > M.w or s.y < ceilAt(s.x):
					gone = true
					if s.y > groundAt(s.x) - 2:
						part(s.x, groundAt(s.x) - 1, rand(-30, 30), rand(-60, -20), 0.2, "#ffe07a", 300, 1)
			"ring":
				# a ring of sparks that bursts out from a Ferro-Slime
				var r: float = s.r * minf(1, s.t / 0.18)
				if not s.hit and absf(P.x - s.x) < r + 6 and absf((P.y - 18) - s.y) < r * 0.8 and P.state != "dead":
					s.hit = true
					if abyssChip(s.src, 1.3, 0.0, true) and P.state != "dead":
						shockStun()
				gone = s.t > 0.35
		if gone:
			volcShots.remove_at(i)


# forward declarations for the drawing (volcano_draw.gd, further down the chain)
func drawVolcanoBack(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawVolcanoMid(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawVolcanoFront(_x: Ctx, _sx: float, _sy: float) -> void: pass
# and for the sanctum (glamrax.gd, between here and the drawing)
func drawSanctumMid(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawSanctumFront(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawSpecialMob(_x: Ctx, _e, _sx: float, _sy: float) -> bool: return false
func drawVolcanoStory(_x: Ctx, _t: float, _kind: String) -> void: pass
func glamraxCutscene(_cls: String, _scenes: Array, _done: Callable) -> void: pass
