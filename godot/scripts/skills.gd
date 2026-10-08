extends "res://scripts/mobs.gd"
## Sproutvale, part 5: skills and buffs, and each class's own way of fighting.
## Archer: aimed arrows, bow melee, Arrow Dive, the Air Spirit.
## Remy (mage): six elements, wand bolts, staff area spells, Blink, the Elemental Spirit.
## Jojo (summoner): the dragon and the other summons.

const BATTLE_CRIES := ["Hyaaah!", "Take that!", "Elements, obey!", "Here I gooo!", "Kaboom!"]


# ================================================================ skills

func jobById(id: String) -> Dictionary:
	for cls in JOBS_BY:
		for J in JOBS_BY[cls]:
			if J.id == id:
				return J
	return {"targets": 1}


func useSkill(id: String) -> bool:
	var s: Dictionary = SKILL.get(id, {})
	if s.is_empty() or s.type == "utility" or not skillRank(id) or not skillUnlocked(s) or Cool.get(id, 0.0) > 0:
		return false
	if P.state == "attack" and not (P.move != null and (P.move.get("skill") or frameOf(P.anim, P.moveT * PS.aspd, false) >= P.move.cancel)):
		if P.move == null or not P.move.get("skill"):
			return false
	if P.en < s.get("cost", 0):
		floatText(P.x, P.y - 58, "Not enough energy", "call")
		Sfx.tone(160, 0.12, "square", 0.05, 120)
		flashEnergy()
		return false
	if P.state in ["dead", "climb", "hurt", "tumble", "held"] or (inWater() and M.get("sea") == null):
		return false
	var r = skillRank(id)
	P.en -= s.get("cost", 0)
	P.lastSkillT = gameTime
	if s.get("boss"):
		Cool[id] = float(s.cd)
		castBossSkill(s)
		return true
	if s.type == "buff":
		Buffs[id] = float(sv(s, "dur", r))
		Cool[id] = float(s.cd)
		PS = calcStats()
		fx.append({"type": "ring", "x": P.x, "y": P.y - 20, "t": 0.0, "life": 0.6, "r": 40, "col": s.fx})
		fx.append({"type": "ring", "x": P.x, "y": P.y - 20, "t": -0.12, "life": 0.6, "r": 26, "col": "#ffffff"})
		Sfx.buff()
		return true
	# active attack: plays an existing combat animation, with the skill's effects layered on top
	var J = jobById(s.job)
	Cool[id] = float(s.cd)
	P.state = "attack"; P.moveId = id; P.moveT = 0; P.lastFrame = -1; P.hitSet.clear(); P.queued = false; P.queuedHeavy = false
	var sfx: String = s.get("fx", "")
	P.move = {"anim": s.anim, "hits": s.hitF, "box": [0, 0, 0, 0], "dmg": float(sv(s, "dmgR", r)) * (1.0 + 0.04 * ascBonus(id)), "kb": 90, "up": -140, "style": 20, "cancel": 99,
		"skill": s, "targets": J.targets, "heavy": true, "both": sfx == "blades" or sfx == "twin"}
	setAnim(s.anim)
	Sfx.whoosh(0.8, true)
	if s.get("cls", "rock") == "rock":
		P.skillTargets = pickTargets(s.range * 1.1, J.targets, sfx == "blades", 42.0 if (sfx == "wave" or sfx == "twin") else 70.0)
	else:
		P.skillTargets = pickTargets(s.range, J.targets)
	if sfx == "skysword":
		fx.append({"type": "skysword", "x": P.x + P.face * s.range * 0.45, "y": P.y, "t": 0.0, "life": 0.9, "w": s.range})
	if sfx == "blades":
		fx.append({"type": "blades", "x": P.x, "y": P.y - 22, "t": 0.0, "life": 1.1, "r": s.range * 0.6})
	return true


func pickTargets(range_: float, n: int, around := false, vert := 70.0) -> Array:
	var l = slimes.filter(func(e): return e.state != "dead" and not e.bossEye and absf(e.y - P.y) < vert and (around or (e.x - P.x) * P.face > -24) and absf(e.x - P.x) < range_)
	l.sort_custom(func(a, b): return absf(a.x - P.x) < absf(b.x - P.x))
	return l.slice(0, n)


func _alive(l) -> Array:
	return (l if l != null else []).filter(func(e): return e.state != "dead")


func skillHit(mv: Dictionary, f: int) -> void:
	var s: Dictionary = mv.skill
	var list = _alive(P.skillTargets)   # locked in when the skill starts, so the cap is exact
	var cls: String = s.get("cls", "rock")
	var sfx: String = s.get("fx", "")
	if cls == "mage" and mageSkillHit(mv, s, list):
		return
	if cls == "summoner" and summonerSkillHit(mv, s, list):
		return
	if cls == "archer" and sfx in ["arrows", "rain", "pierce"]:
		var amv = {"dmg": 0, "skillDmg": mv.dmg, "skillId": s.id, "kb": 60}
		if sfx == "pierce":
			var pm = amv.duplicate()
			pm.big = true
			pm.pierce = mv.targets - 1
			spawnArrow(P.x + P.face * 10, P.y - 26, null, "fwd", pm)
			arrows[-1].pierce = mv.targets - 1
			Sfx.bowShot(true)
			shake = 4
			return
		for e in list:
			for k in s.get("shots", 1):
				if sfx == "rain":
					spawnArrow(e.x + rand(-10, 10), e.y - 170 - k * 30, e, "down", amv, 0, "rain")
				else:
					spawnArrow(P.x + P.face * 10, P.y - 26 + k * 3, e, "fwd", amv, (k - 0.5) * 0.08)
		Sfx.bowShot(false)
		return
	if sfx == "wave" or sfx == "twin":
		# Rock's sword waves: each enemy is struck when the wave actually reaches it
		fx.append({"type": "wave", "big": true, "x": P.x + P.face * 10, "y": P.y - 22, "vx": P.face * 380.0, "t": 0.0, "life": (s.range * 1.15 + 30) / 380.0,
			"col": "#9fd4ff" if sfx == "twin" else "#c8ffb0", "flip": f % 2, "hits": list.duplicate(),
			"mv": {"dmg": mv.dmg, "kb": mv.kb, "up": mv.up, "style": 8, "anim": s.id, "both": true, "heavy": true}})
		Sfx.whoosh(0.8, true)
		shake = maxf(shake, 3)
		return
	if sfx == "blades":
		# the blades sweep the whole circle that can be hit
		fx.append({"type": "whirlRing", "x": P.x, "y": P.y - 20, "t": 0.0, "life": 0.3, "r": maxf(60, s.range * 1.05), "a0": randf() * 6})
	if sfx == "beam":
		shake = 8
		World.flash = maxf(World.flash, 0.5)
	for e in list:
		if sfx == "bolt":
			fx.append({"type": "bolt", "x": e.x, "y": e.y, "t": 0.0, "life": 0.25, "seed": randf() * 100})
		if sfx == "beam":
			fx.append({"type": "beam", "x": e.x, "y": e.y, "t": 0.0, "life": 0.5})
		fx.append({"type": "slashmark", "x": e.x, "y": e.y - e.h * 0.6, "t": 0.0, "life": 0.2, "a": randf() * 3})
		damageSlime(e, {"dmg": mv.dmg, "kb": mv.kb, "up": mv.up, "style": 8, "anim": s.id, "both": true, "heavy": true})
	shake = maxf(shake, 3 + mv.targets * 0.2)
	hitstop = maxf(hitstop, 0.05)
	if sfx in ["bolt", "skysword", "beam"]:
		Sfx.slam()


func skillFrameFX(mv: Dictionary, _f: int) -> void:
	if mv.skill.get("fx") == "blades" and randf() < 0.5:
		sparks(P.x + rand(-30, 30), P.y - rand(10, 40), "#ffc4e6", 2)


## Mirror Stance: plain hits echo a moment later
func echoHit(e, mv: Dictionary) -> void:
	if not buffOn("mirrorStance") or e.state == "dead":
		return
	var k = 0.3 + skillRank("mirrorStance") * 0.03
	later(0.12, func():
		if e.state != "dead":
			var m = mv.duplicate()
			m.dmg = mv.get("dmg", 1.0) * k
			m.kb = 0; m.up = 0; m.style = 2
			damageSlime(e, m)
			sparks(e.x, e.y - e.h * 0.5, "#ff9ecf", 6))


func updateBuffs(dt: float) -> void:
	var changed = false
	for id in Buffs:
		if Buffs[id] > 0:
			Buffs[id] -= dt
			if Buffs[id] <= 0:
				Buffs[id] = 0.0
				changed = true
				var nm: String = SKILL[id].name if SKILL.has(id) else ("Shocked" if id == "shocked" else id)
				toast("%s wore off." % nm)
	for id in Cool:
		if Cool[id] > 0:
			Cool[id] = maxf(0, Cool[id] - dt)
	if changed:
		PS = calcStats()
	# aura sparkles while buffs are up
	for id in Buffs:
		if Buffs[id] > 0 and randf() < dt * 10:
			part(P.x + rand(-9, 9), P.y - rand(4, 40), 0, rand(-30, -12), 0.6, SKILL[id].fx if SKILL.has(id) else "#fff6a8", 0, 1)


func updateFX(dt: float) -> void:
	for i in range(fx.size() - 1, -1, -1):
		if i >= fx.size():
			continue
		var f: Dictionary = fx[i]
		f.t += dt
		if f.get("x") != null and f.get("vx"):
			f.x += f.vx * dt
		if f.has("hits"):
			var hits: Array = f.hits
			for h in range(hits.size() - 1, -1, -1):
				var e = hits[h]
				if e.state == "dead":
					hits.remove_at(h)
					continue
				if (e.x - f.x) * sgn(f.vx) <= 26:
					hits.remove_at(h)
					fx.append({"type": "slashmark", "x": e.x, "y": e.y - e.h * 0.6, "t": 0.0, "life": 0.2, "a": randf() * 3})
					damageSlime(e, f.mv)
					hitstop = maxf(hitstop, 0.04)
		if f.type == "aoe":
			aoeEmit(f, dt)
		if f.t > f.life:
			fx.erase(f)


# ================================================================ the archer

func arrowRange() -> float:
	return 200.0 * (1.2 if buffOn("keenEye") else 1.0)


## auto-target: the closest enemy in the direction you're pointing (or the juggled one)
func aimTarget(aim: String, range_: float):
	if P.juggle != null and P.juggle.state != "dead" and gameTime - P.juggleT < 1.4 and absf(P.juggle.x - P.x) < range_:
		return P.juggle
	var best = null
	var bd = 1e9
	for e in slimes:
		if e.state == "dead" or e.spawnT > 0:
			continue
		var dx: float = e.x - P.x
		var dy: float = (e.y - e.h / 2) - (P.y - 22)
		var d = Vector2(dx, dy).length()
		if d > range_:
			continue
		var ok = false
		if aim == "up":
			ok = dy < -14 and absf(dx) < absf(dy) * 1.6 + 24
		elif aim == "down":
			ok = dy > 8 and absf(dx) < dy * 1.6 + 30
		elif aim == "low":
			ok = dx * P.face > -6 and absf(e.y - P.y) < 18
		else:
			ok = dx * P.face > -6 and absf(dy) < 46 + absf(dx) * 0.25
		if ok and d < bd:
			bd = d
			best = e
	return best


func closeEnemy(reach: float):
	var best = null
	var bd = reach
	for e in slimes:
		if e.state == "dead":
			continue
		var dx: float = (e.x - P.x) * P.face
		var d: float = absf(e.x - P.x) - e.w / 2
		if dx > -8 and absf(e.y - P.y) < 30 and d < bd:
			bd = d
			best = e
	return best


func startArcherMove(key: String) -> bool:
	var now = gameTime
	if now < P.shotCd:
		return false
	startMove("a_" + key)
	P.shotCd = now + (0.2 / PS.aspd if AMOVES[key].get("arrow") else 0.12)   # a short gap between shots: fast, not a fire-hose
	if AMOVES[key].get("air") and airLift():
		P.vy = minf(P.vy, -40)
	return true


func _cancelable() -> bool:
	return P.state != "attack" or P.move == null or frameOf(P.anim, P.moveT * PS.aspd, false) >= P.move.cancel


func archerInput(has: Callable, use: Callable, dirIn: int, _up: bool, down: bool, wet: bool, canAct: bool, risingIntent: bool) -> void:
	var busy = P.state in ["climb", "hurt", "plunge", "knocked"] or (P.state == "dash" and P.dashT < 0.14)
	if has.call("atk", 0.22) and not busy:
		if dirIn and P.state != "attack":
			P.face = dirIn
		if not _cancelable():
			return
		if P.state == "prone":
			if startArcherMove("low"):
				use.call("atk")
			return
		if not P.grounded and not wet:
			# aerial chain: shot → shot → Spiral Shot (a backflip fan of arrows); ↑/↓ aim the shot instead
			var k = "airUp" if risingIntent else ("airDown" if down else "air")
			var chained = gameTime - P.lastAirShotT < 0.5   # keep firing in the air to build the chain
			if k == "air" and chained and P.airChain >= 2:
				k = "spiral"
			if startArcherMove(k):
				use.call("atk")
				P.airChain = 0 if k == "spiral" else (P.airChain + 1 if chained else 1)
				P.lastAirShotT = gameTime + 0.18
			return
		if not canAct and P.state != "attack":
			return
		var near = closeEnemy(22)
		if risingIntent and closeEnemy(30) != null:
			if startArcherMove("launch"):
				use.call("atk")   # ↑ up close: pop it into the air
			return
		if near != null and not risingIntent:
			if startArcherMove("swing"):
				use.call("atk")   # too close to shoot: bow swing shove
			return
		if startArcherMove("shootUp" if risingIntent else "shoot"):
			use.call("atk")
	if has.call("heavy", 0.2) and not busy:
		if not P.grounded and not wet:
			use.call("heavy")
			if P.diveN < 3:
				P.diveN += 1
				arrowDive()
			else:
				floatText(P.x, P.y - 58, "Land to dive again", "call")
				Sfx.tone(160, 0.1, "square", 0.05, 120)
		elif P.grounded and (canAct or (P.state == "attack" and _cancelable())):
			use.call("heavy")
			if dirIn:
				P.face = dirIn
			startArcherMove("charged")


func fireArrows(mv: Dictionary, _f: int) -> void:
	var aim: String = mv.get("aim", "fwd")
	var range_ = arrowRange() * (1.3 if mv.get("big") else 1.0)
	var fan: int = mv.get("fan", 1)
	var split = 2 if buffOn("transcendentAim") else 1
	var ox = P.x + P.face * 10
	var oy = P.y - (6.0 if aim == "low" else (34.0 if aim == "up" else (18.0 if aim == "down" else 26.0)))
	var used = {}
	for i in fan:
		var tgt = aimTarget(aim, range_)
		if fan > 1:
			var pool = slimes.filter(func(e): return e.state != "dead" and not used.has(e) and Vector2(e.x - P.x, e.y - P.y).length() < range_ * 0.8 and e.y > P.y - 10)
			pool.sort_custom(func(a, b): return absf(a.x - P.x) < absf(b.x - P.x))
			tgt = pool[0] if pool.size() else null
		if tgt != null:
			used[tgt] = true
		for s in split:
			spawnArrow(ox, oy, tgt, aim, mv, (i - (fan - 1) / 2.0) * 0.45 + s * 0.12)
	Sfx.bowShot(mv.get("big", false))


func spawnArrow(x: float, y: float, tgt, aim: String, mv: Dictionary, spread := 0.0, kind := "arrow") -> Dictionary:
	var sp = 520.0 if mv.get("big") else 430.0
	var ang: float   # radians in screen space, 0 = right
	if tgt != null:
		ang = atan2((tgt.y - tgt.h * 0.5) - y, tgt.x - x)
	elif aim == "up":
		ang = -1.05 if P.face > 0 else PI + 1.05
	elif aim == "down":
		ang = 1.0 if P.face > 0 else PI - 1.0
	else:
		ang = 0.0 if P.face > 0 else PI
	ang += spread
	var a = {"x": x, "y": y, "vx": cos(ang) * sp, "vy": sin(ang) * sp, "tgt": tgt, "mv": mv.duplicate(), "t": 0.0,
		"life": (arrowRange() * (1.3 if mv.get("big") else 1.0)) / sp + 0.15, "kind": kind, "hit": {}, "pierce": mv.get("pierce", 0),
		"elem": "", "homing": 1.0, "grav": 0.0}
	arrows.append(a)
	return a


func updateArrows(dt: float) -> void:
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		a.t += dt
		var tg = a.tgt
		if tg != null and tg.state != "dead":
			# gentle homing so aimed shots land
			var ang = atan2((tg.y - tg.h * 0.5) - a.y, tg.x - a.x)
			var cur = atan2(a.vy, a.vx)
			var sp = Vector2(a.vx, a.vy).length()
			var d = angDiff(cur, ang)
			var hm: float = 9 * a.homing
			var na = cur + clampf(d, -dt * hm, dt * hm)
			a.vx = cos(na) * sp
			a.vy = sin(na) * sp
		a.x += a.vx * dt
		a.y += a.vy * dt
		if a.kind == "rain":
			a.vy += 300 * dt
		if a.grav:
			a.vy += a.grav * dt
		if a.kind == "spell" and randf() < 0.7:
			var E2 = _elem(a.elem)
			part(a.x + rand(-1.5, 1.5), a.y + rand(-1.5, 1.5), -a.vx * 0.05, -a.vy * 0.05 - (20.0 if a.elem == "fire" else 0.0), 0.3,
				E2.col if randf() < 0.5 else E2.glow, 0, 2 if a.elem == "earth" else 1)
		if parts.size() < 500 and randf() < 0.5:
			part(a.x, a.y, 0, 0, 0.12, "#bfffe8" if a.kind == "wind" else ("#fff6b0" if a.mv.get("big") else "rgba(255,255,255,0.7)"), 0, 1)
		var done: bool = a.t > a.life or a.x < 0 or a.x > M.w or a.y > M.h
		for s in surfaces:
			if not s.water and a.vy > 0 and a.x > s.x0 and a.x < s.x1 and a.y > s.y and a.y < s.y + 6 and a.tgt == null:
				done = true
				for k in 3:
					part(a.x, s.y - 1, rand(-30, 30), rand(-60, -20), 0.3, "#efe6cf", 300, 1)
		if not done:
			for e in slimes:
				if e.state == "dead" or a.hit.has(e):
					continue
				var b = sBox(e)
				if a.x > b.x0 - 3 and a.x < b.x1 + 3 and a.y > b.y0 - 3 and a.y < b.y1 + 3:
					a.hit[e] = true
					var mv: Dictionary = a.mv.duplicate()
					mv.both = true
					if mv.get("skillDmg"):
						damageSlime(e, {"dmg": mv.skillDmg, "kb": 60, "up": -60, "style": 6, "anim": mv.get("skillId", ""), "both": true})
					else:
						damageSlime(e, mv)
						if a.kind == "arrow" or a.kind == "spell":
							echoHit(e, mv)
							P.en = minf(PS.enMax, P.en + PS.enHit)
						if a.kind == "spell":
							spellHitFx(e, a.elem)
					if a.mv.get("launcherTarget"):
						P.juggle = e
					a.pierce -= 1
					if a.pierce < 0:
						done = true
						break
		if done:
			arrows.erase(a)


## Arrow Dive (heavy in the air): a short hop, then a downward volley; like the downward slash, it can hit two enemies
func arrowDive() -> void:
	if P.state == "plunge":
		return
	P.vy = -160
	startMove("a_airDown")
	var m: Dictionary = AMOVES.airDown.duplicate()
	m.fan = 3; m.dmg = 0.85; m.erase("name"); m.style = 18
	P.move = m
	var pool = slimes.filter(func(e): return e.state != "dead" and e.y > P.y - 10 and absf(e.x - P.x) < 150)
	pool.sort_custom(func(a, b): return Vector2(a.x - P.x, a.y - P.y).length() < Vector2(b.x - P.x, b.y - P.y).length())
	pool = pool.slice(0, 2)
	later(0.09, func():
		for i in 3:
			var am: Dictionary = AMOVES.airDown.duplicate()
			am.dmg = 0.85
			spawnArrow(P.x, P.y - 18, pool[i % pool.size()] if pool.size() else null, "down", am, (i - 1) * 0.35)
		Sfx.bowShot(true))


## the Marksman's Air Spirit summon
func updateSpirit(dt: float) -> void:
	if not buffOn("airSpirit"):
		return
	Spirit.t += dt
	Spirit.cd -= dt
	var tx = P.x - P.face * 16 + sin(Spirit.t * 2) * 6
	var ty = P.y - 52 + sin(Spirit.t * 3.1) * 4
	Spirit.x = damp(Spirit.x if Spirit.x else tx, tx, 5, dt)
	Spirit.y = damp(Spirit.y if Spirit.y else ty, ty, 5, dt)
	if randf() < dt * 12:
		part(Spirit.x + rand(-3, 3), Spirit.y + rand(-3, 3), -P.face * rand(10, 30), rand(-8, 8), 0.5, "#bfffe8", 0, 1)
	if Spirit.cd <= 0:
		var r = skillRank("airSpirit")
		var list = _nearList(Spirit.x, Spirit.y, 170, 3)
		if list.size():
			Spirit.cd = 1.3
			for e in list:
				spawnArrow(Spirit.x, Spirit.y, e, "fwd", {"dmg": 0, "skillDmg": 0.7 + 0.06 * r, "skillId": "airSpirit", "kb": 40}, 0, "wind")
			Sfx.whoosh(1.6, false)


func _nearList(x: float, y: float, r: float, n: int) -> Array:
	var l = slimes.filter(func(e): return e.state != "dead" and Vector2(e.x - x, e.y - y).length() < r)
	l.sort_custom(func(a, b): return Vector2(a.x - x, a.y - y).length() < Vector2(b.x - x, b.y - y).length())
	return l.slice(0, n)


# ================================================================ Remy, the mage

func _elem(id: String) -> Dictionary:
	for E2 in ELEMENTS:
		if E2.id == id:
			return E2
	return ELEMENTS[0]


func elemsUnlocked() -> Array:
	return ELEMENTS.filter(func(e): return CH().level >= e.lv)


func setElement(i: int) -> void:
	if i < 0 or i >= ELEMENTS.size():
		return
	var E2: Dictionary = ELEMENTS[i]
	if CH().level < E2.lv:
		floatText(P.x, P.y - 56, "%s unlocks at Lv %d" % [E2.name, E2.lv], "call")
		return
	elemIdx = i
	Sfx.tone(520 + i * 60, 0.12, "triangle", 0.06, 700 + i * 60)
	for k in 10:
		var a = k / 10.0 * TAU
		part(P.x + cos(a) * 10, P.y - 22 + sin(a) * 10, cos(a) * 20, sin(a) * 20, 0.35, E2.col, 0, 1)


func cycleElement() -> void:
	var U = elemsUnlocked()
	var cur = U.find(ELEM())
	setElement(ELEMENTS.find(U[(cur + 1) % U.size()]))


func startMageMove(key: String) -> bool:
	if gameTime < P.shotCd:
		return false
	startMove("m_" + key)
	var mv: Dictionary = MMOVES[key]
	var spell: String = mv.get("spell", "")
	P.shotCd = gameTime + (0.24 / PS.aspd if spell == "wand" else (0.3 if spell == "staff" else 0.12))
	if mv.get("air") and airLift():
		P.vy = minf(P.vy, -30)
	if spell != "" and randf() < 0.001:
		# a very rare battle cry
		thought = {"text": BATTLE_CRIES[rint(0, BATTLE_CRIES.size() - 1)], "t": 3.4}
		Sfx.tone(880, 0.12, "square", 0.06, 1100)
		Sfx.tone(1100, 0.15, "square", 0.05, 1320, 0.1)
	return true


func mageInput(has: Callable, use: Callable, dirIn: int, _up: bool, down: bool, wet: bool, _canAct: bool, risingIntent: bool) -> void:
	for i in 6:
		if pressed.get(str(i + 1)):
			setElement(i)
	if pressed.get("v"):
		cycleElement()
	var busy = P.state in ["climb", "hurt", "knocked"]
	var cancelable = _cancelable()
	if has.call("atk", 0.22) and not busy and cancelable:
		if dirIn and P.state != "attack":
			P.face = dirIn
		var air = not P.grounded and not wet
		if P.state == "prone" or (P.state == "attack" and P.move != null and P.move.get("prone")):
			if startMageMove("prone"):
				use.call("atk")   # stay down: a sonic pulse from the wand
			return
		if not air and risingIntent and closeEnemy(30) != null:
			if startMageMove("launch"):
				use.call("atk")   # ↑ up close: pop it into the air with the staff
			return
		if not air and not risingIntent and closeEnemy(22) != null:
			if startMageMove("thwack"):
				use.call("atk")   # too close: thwack it away
			return
		var k = ("wandAir" if air else "wand") + ("Up" if risingIntent else ("Down" if down else ""))
		if startMageMove(k):
			use.call("atk")
	if has.call("heavy", 0.2) and not busy and cancelable and P.state != "prone":
		if dirIn and P.state != "attack":
			P.face = dirIn
		if startMageMove("staff" + ("Up" if risingIntent else ("Down" if down else ""))):
			use.call("heavy")
			P.castAim = "up" if risingIntent else ("down" if down else "fwd")


func castSpell(mv: Dictionary, _f: int) -> void:
	if mv.spell == "sonic":
		# a ring of sound rolling along the floor that shoves enemies back
		fx.append({"type": "sonic", "x": P.x + P.face * 10, "y": P.y - 5, "dir": P.face, "t": 0.0, "life": 0.45})
		var hit = slimes.filter(func(e): return e.state != "dead" and (e.x - P.x) * P.face > -6 and absf(e.x - P.x) < 84 and absf(e.y - P.y) < 22)
		hit.sort_custom(func(a, b): return absf(a.x - P.x) < absf(b.x - P.x))
		for e in hit.slice(0, 3):
			damageSlime(e, {"dmg": mv.dmg, "kb": mv.kb, "up": mv.up, "style": mv.style, "anim": "sonic", "both": true})
			for k in 6:
				part(e.x, e.y - e.h / 2, P.face * rand(40, 120), rand(-40, 20), 0.35, "#e8f0ff", 0, 1)
		Sfx.tone(240, 0.25, "sine", 0.08, 900)
		Sfx.burst(0.15, "bandpass", 1800, 400, 0.2)
		return
	var E2 = ELEM()
	var range_ = 260.0 if mv.spell == "staff" else 240.0
	if mv.spell == "wand":
		# quick, single target
		var aim: String = mv.aim
		var tgt = aimTarget("down" if aim == "down" and P.grounded else aim, range_)
		var sm = {"dmg": mv.dmg * elemMul(E2.id), "kb": mv.kb, "up": mv.up, "style": mv.style, "anim": "wand", "both": true}
		if E2.id == "light":
			# light is instant: a ray straight to the target
			if tgt != null:
				fx.append({"type": "ray", "x": P.x + P.face * 12, "y": P.y - 26, "tx": tgt.x, "ty": tgt.y - tgt.h / 2, "t": 0.0, "life": 0.18})
				damageSlime(tgt, sm)
				P.en = minf(PS.enMax, P.en + PS.enHit)
			else:
				fx.append({"type": "ray", "x": P.x + P.face * 12, "y": P.y - 26, "tx": P.x + P.face * (200 if aim == "fwd" else 0),
					"ty": P.y - 26 + (-200 if aim == "up" else (200 if aim == "down" else 0)), "t": 0.0, "life": 0.18})
			Sfx.tone(1400, 0.1, "sine", 0.06, 2200)
			return
		var a = spawnArrow(P.x + P.face * 12, P.y - 26, tgt, "up" if aim == "up" and tgt == null else aim, sm, 0, "spell")
		a.elem = E2.id
		# Remy can aim straight up or down
		if tgt == null and aim == "up":
			a.vx = 0.0; a.vy = -430.0
		if tgt == null and aim == "down":
			a.vx = 0.0; a.vy = 430.0
		if E2.id == "earth":
			a.grav = 380.0; a.vy -= 60; a.mv.dmg *= 1.15
		if E2.id == "water":
			a.vx *= 0.85; a.vy *= 0.85
		if E2.id == "air":
			a.vx *= 1.25; a.vy *= 1.25
		if E2.id == "dark":
			a.homing = 2.0
		Sfx.tone({"air": 1200, "water": 500, "earth": 180, "fire": 320, "dark": 220}[E2.id], 0.12, "triangle", 0.06, {"air": 1800, "water": 300, "earth": 120, "fire": 520, "dark": 120}[E2.id])
		return
	# staff: an area spell on up to three enemies in the direction you aimed
	var ca = P.castAim if P.castAim != "" else "fwd"
	var list = slimes.filter(func(e): return e.state != "dead" and aimOk(e, ca, range_))
	list.sort_custom(func(a, b): return Vector2(a.x - P.x, a.y - P.y).length() < Vector2(b.x - P.x, b.y - P.y).length())
	list = list.slice(0, 3)
	var spots = []
	for e in list:
		spots.append([e.x, e.y])
	if spots.is_empty():
		spots.append([P.x + P.face * 70, P.y])
	for sp in spots:
		fx.append({"type": "aoe", "elem": E2.id, "x": sp[0], "y": sp[1], "dir": P.face, "t": 0.0,
			"life": {"air": 1.1, "water": 1.0, "earth": 0.9, "fire": 1.3, "light": 0.9, "dark": 1.1}[E2.id], "seed": randf() * 100, "boom": 0})
	var sm = {"dmg": mv.dmg * elemMul(E2.id), "kb": mv.kb, "up": mv.up, "style": mv.style, "anim": "staff", "both": true, "heavy": true}
	for e in list:
		aoeHit(e, E2.id, sm)
	shake = maxf(shake, 4)
	Sfx.slam()
	Sfx.tone({"air": 900, "water": 300, "earth": 90, "fire": 140, "light": 1200, "dark": 80}[E2.id], 0.5, "sawtooth", 0.06, 60)


func aimOk(e, aim: String, range_: float) -> bool:
	var dx: float = e.x - P.x
	var dy: float = (e.y - e.h / 2) - (P.y - 22)
	if Vector2(dx, dy).length() > range_:
		return false
	if aim == "up":
		return dy < -10 and absf(dx) < absf(dy) * 1.8 + 30
	if aim == "down":
		return dy > 6 and absf(dx) < dy * 1.8 + 30
	return dx * P.face > -10 and absf(dy) < 60 + absf(dx) * 0.3


func elemMul(id: String) -> float:
	return 1 + (skillRank("lightAffinity") * 0.04 if id == "light" else 0.0) + (0.25 + skillRank("darkPact") * 0.02 if buffOn("darkPact") else 0.0)


## each element moves enemies its own way
func aoeHit(e, el: String, sm: Dictionary) -> void:
	var m = sm.duplicate()
	if el == "air":
		m.up = -300; m.kb = 30
	if el == "water":
		m.up = 140; m.kb = 160; e.slowT = 2
	if el == "earth":
		m.up = -230; m.kb = 20; m.dmg *= 1.15
	if el == "fire":
		e.burnT = 3
	if el == "dark":
		m.kb = 0
		e.vx = (P.x + P.face * 40 - e.x) * 2
	damageSlime(e, m)
	spellHitFx(e, el)


func spellHitFx(e, el: String) -> void:
	var E2 = _elem(el)
	fx.append({"type": "ring", "x": e.x, "y": e.y - e.h / 2, "t": 0.0, "life": 0.25, "col": E2.glow, "r": 10})
	for k in 16:
		part(e.x, e.y - e.h / 2, rand(-90, 90), rand(-100, 20), rand(0.25, 0.5), E2.col if randf() < 0.5 else E2.glow, 500 if el == "earth" else 0, 1)
	if el == "water":
		e.slowT = maxf(e.slowT, 1.2)
	if el == "fire":
		e.burnT = maxf(e.burnT, 2)
	if el == "dark" and P.hp > 0:
		P.hp = minf(PS.hp, P.hp + PS.atk * 0.02 * (1 + skillRank("darkAffinity")))


func P2(x: float, y: float, vx: float, vy: float, life: float, col, g := 0.0, sz := 1.0, floorY := INF) -> void:
	if parts.size() < 900:
		part(x, y, vx, vy, life, col, g, sz, floorY)


## particles each element sheds while it plays out
func aoeEmit(f: Dictionary, dt: float) -> void:
	var k: float = f.t / f.life
	match f.elem:
		"air":
			# a tornado that drifts forward, kicking up dust and leaves
			f.x += f.dir * 45 * dt
			var cols = ["#ffffff", "#d8f4ff", "#bfe0c0", "#c8b48a"]
			for i in 3:
				var h = rand(0, 46)
				var a = rand(0, TAU)
				var w = 4 + h * 0.35
				P2(f.x + cos(a) * w, f.y - h, -sin(a) * 70 + f.dir * 30, -rand(20, 60), rand(0.25, 0.45), cols[i], 0, 2 if i == 3 else 1)
			if randf() < 0.5:
				P2(f.x + rand(-10, 10), f.y - 1, rand(-60, 60), rand(-30, -5), 0.5, "#c8b48a", 200, 2)
		"water":
			# a wave rolling across; spray off the crest, foam on the ground
			var cx: float = f.x - f.dir * 45 + f.dir * 90 * minf(1, k * 1.3)
			for i in 4:
				P2(cx + rand(-4, 4), f.y - 30 * sin(minf(1, k * 1.3) * PI) - rand(0, 6), f.dir * rand(40, 120), -rand(30, 120), rand(0.3, 0.6), "#e0f4ff" if i % 2 else "#6fb4ff", 600, 1, f.y)
			if randf() < 0.6:
				P2(cx + rand(-20, 0) * f.dir, f.y - 1, f.dir * rand(10, 40), 0, 0.5, "#ffffff", 0, 1)
		"earth":
			# dust while the pillars grind up, a burst of rubble when they slam together
			if randf() < 0.7 and k < 0.4:
				P2(f.x + (-1 if randf() < 0.5 else 1) * rand(14, 30), f.y - 1, rand(-30, 30), -rand(20, 50), 0.5, "#b8a07a", 100, 2)
			if not f.boom and k > 0.38:
				f.boom = 1
				shake = maxf(shake, 5)
				Sfx.slam()
				var cols = ["#7a5a3a", "#a07a4a", "#c89a5a", "#5a4430"]
				for i in 26:
					P2(f.x + rand(-4, 4), f.y - rand(10, 34), rand(-160, 160), -rand(60, 260), rand(0.5, 0.9), cols[i % 4], 700, 2 if i % 3 else 3, f.y)
		"fire":
			# a little volcano rises, then erupts magma
			if k > 0.3:
				var cols = ["#ffd35a", "#ff8a3a", "#ff4a2a"]
				for i in 3:
					P2(f.x + rand(-3, 3), f.y - 14, rand(-90, 90), -rand(160, 300), rand(0.5, 0.9), cols[i], 650, 2 if i else 3, f.y)
				if randf() < 0.4:
					P2(f.x + rand(-4, 4), f.y - 18, rand(-10, 10), -rand(30, 50), 0.9, "rgba(70,60,60,0.7)", -20, 3)
			if not f.boom and k > 0.3:
				f.boom = 1
				shake = maxf(shake, 4)
				Sfx.burst(0.35, "lowpass", 500, 120, 0.35)
		"light":
			for i in 3:
				P2(f.x + rand(-10, 10), f.y - rand(0, 120), rand(-10, 10), -rand(30, 90), rand(0.4, 0.8), "#ffffff" if i % 2 else "#fff1a8", 0, 1)
		"dark":
			# motes spiral inward to the core
			for i in 3:
				var a = rand(0, TAU)
				var r = rand(24, 40)
				P2(f.x + cos(a) * r, f.y - 16 + sin(a) * r * 0.45, -cos(a) * r * 2.4 - sin(a) * 60, -sin(a) * r * 1.1 + cos(a) * 25, 0.4, "#c28aff" if i % 2 else "#3a1a6a", 0, 1)


func blink(dirIn: int, up: bool, down: bool) -> void:
	var s: Dictionary = SKILL.get("blink", {})
	var cost: float = s.get("cost", 6)
	if gameTime < P.blinkCd:
		return
	if P.en < cost:
		floatText(P.x, P.y - 56, "Not enough mana", "call")
		flashEnergy()
		return
	var dist = 70.0 + skillRank("blink") * 6
	var ox = P.x
	var oy = P.y
	var nx = P.x
	var ny = P.y
	if up and not dirIn:
		ny = P.y - dist
	elif down and not dirIn:
		ny = minf(P.y + dist, groundAt(P.x))
	else:
		nx = P.x + (dirIn if dirIn else P.face) * dist
	nx = clampf(nx, 24, M.w - 24)
	ny = clampf(ny, 30, groundAt(nx))
	if M.get("pond") and ny > M.floorY + 1 and nx > M.pond.x0 - 8 and nx < M.pond.x1 + 8:
		nx = clampf(nx, M.pond.x0 + 7, M.pond.x1 - 7)
	P.en -= cost
	P.blinkCd = gameTime + 0.3
	P.x = nx; P.y = ny
	P.iframes = maxf(P.iframes, 0.2)
	P.state = "move"; P.rope = null; P.grounded = false; P.surf = null
	P.vy = -60.0 if up and not dirIn else 0.0
	if down and not dirIn:
		P.dropT = 0.2
	if dirIn:
		P.face = dirIn
	for c in [[ox, oy], [nx, ny]]:
		for k in 14:
			var a = k / 14.0 * TAU
			part(c[0] + cos(a) * 6, c[1] - 22 + sin(a) * 14, cos(a) * 40, sin(a) * 40, 0.35, "#e8d8ff" if k % 2 else "#b88aff", 0, 1)
	Sfx.tone(1600, 0.12, "sine", 0.07, 600)


func mageSkillHit(mv: Dictionary, s: Dictionary, list: Array) -> bool:
	var el: String = ELEM().id
	var sfx: String = s.get("fx", "")
	if sfx == "spells":
		for e in list:
			for k in s.get("shots", 1):
				var a = spawnArrow(P.x + P.face * 12, P.y - 26 + k * 4, e, "fwd", {"dmg": 0, "skillDmg": mv.dmg, "skillId": s.id, "kb": 60}, (k - 0.5) * 0.1, "spell")
				a.elem = el
		Sfx.tone(800, 0.15, "triangle", 0.06, 1200)
		return true
	if sfx == "meteors":
		for e in list:
			for k in 3:
				var a = spawnArrow(e.x + rand(-12, 12), e.y - 180 - k * 40, e, "down", {"dmg": 0, "skillDmg": mv.dmg, "skillId": s.id, "kb": 60}, 0, "spell")
				a.elem = "fire"
				a.life = 2.0
		Sfx.slam()
		return true
	if sfx == "vortex":
		var cx = P.x + P.face * 70
		fx.append({"type": "aoe", "elem": "dark", "x": cx, "y": P.y, "dir": P.face, "t": 0.0, "life": 1.1, "boom": 0})
		for e in list:
			e.x = e.x + (cx - e.x) * 0.75
			damageSlime(e, {"dmg": mv.dmg, "kb": 0, "up": -60, "style": 8, "anim": s.id, "both": true, "heavy": true})
		shake = 6
		Sfx.tone(60, 0.8, "sawtooth", 0.1, 30)
		return true
	if s.get("heal"):
		var h: float = PS.hp * (0.1 + skillRank(s.id) * 0.01)
		P.hp = minf(PS.hp, P.hp + h)
		floatText(P.x, P.y - 50, "+%d" % roundi(h), "exp")
		for k in 16:
			part(P.x + rand(-10, 10), P.y - rand(0, 40), 0, -40, 0.8, "#fff6c0", 0, 2)
	return false


## the Caster's Elemental Spirit: like the Air Spirit, but it cycles through the elements
func updateElemSpirit(dt: float) -> void:
	if not buffOn("elemSpirit"):
		return
	var Sp = ESpirit
	Sp.t += dt
	Sp.cd -= dt
	var tx = P.x - P.face * 16 + sin(Sp.t * 2.2) * 6
	var ty = P.y - 50 + sin(Sp.t * 3) * 4
	Sp.x = damp(Sp.x if Sp.x else tx, tx, 5, dt)
	Sp.y = damp(Sp.y if Sp.y else ty, ty, 5, dt)
	var E2: Dictionary = ELEMENTS[Sp.i % 4]
	if randf() < dt * 12:
		part(Sp.x + rand(-3, 3), Sp.y + rand(-3, 3), 0, -10, 0.5, E2.col, 0, 1)
	if Sp.cd <= 0:
		var r = skillRank("elemSpirit")
		var list = _nearList(Sp.x, Sp.y, 170, 3)
		if list.size():
			Sp.cd = 1.2
			for e in list:
				var a = spawnArrow(Sp.x, Sp.y, e, "fwd", {"dmg": 0, "skillDmg": 0.75 + 0.06 * r, "skillId": "elemSpirit", "kb": 40}, 0, "spell")
				a.elem = E2.id
			Sp.i += 1
			Sfx.tone(900, 0.1, "sine", 0.05, 1300)


# ================================================================ Jojo, the summoner

func dragonForm() -> String:
	var lv: int = CH().level
	return "dragon" if lv >= 200 else ("drake" if lv >= 75 else "baby")


func petMul() -> float:
	return 1 + skillRank("kinship") * 0.05 + skillRank("avatarBond") * 0.04 + (0.15 + skillRank("warBanner") * 0.01 if buffOn("warBanner") else 0.0) + (0.6 + skillRank("ancientRoar") * 0.03 if buffOn("ancientRoar") else 0.0)


func petRate() -> float:
	return 1 / (1.15 + skillRank("rally") * 0.02) if buffOn("rally") else 1.0


func summonOn(id: String) -> bool:
	var Sm = null
	for q in SUMMONS:
		if q.id == id:
			Sm = q
	var c = CH()
	if not c.has("summonsOn") or not (c.summonsOn is Dictionary):
		c.summonsOn = {}
	return Sm != null and c.level >= Sm.lv and c.summonsOn.get(id) != false


func toggleSummon(i: int) -> void:
	if i < 0 or i >= SUMMONS.size():
		return
	var Sm: Dictionary = SUMMONS[i]
	var c = CH()
	if not c.has("summonsOn") or not (c.summonsOn is Dictionary):
		c.summonsOn = {}
	if c.level < Sm.lv:
		floatText(P.x, P.y - 60, "%s joins at Lv %d" % [Sm.name, Sm.lv], "call")
		return
	var on: bool = c.summonsOn.get(Sm.id) == false
	c.summonsOn[Sm.id] = on
	if on and Pets.list.has(Sm.id):
		var p: Dictionary = Pets.list[Sm.id]
		p.x = P.x; p.y = P.y - 30
	floatText(P.x, P.y - 60, "%s %s" % [Sm.name, "summoned" if on else "dismissed"], "call")
	Sfx.tone(660 if on else 330, 0.15, "triangle", 0.06, 990 if on else 220)
	for k in 14:
		part(P.x + rand(-20, 20), P.y - rand(0, 50), 0, -30, 0.6, "#d8c8ff", 0, 1)
	saveDirty = true


func resetPets() -> void:
	Pets.list = {}
	for id in ["dragon", "slime", "croc", "phoenix", "angel"]:
		Pets.list[id] = {"id": id, "x": P.x - 20, "y": P.y - (50.0 if id in ["phoenix", "angel", "dragon"] else 0.0), "vx": 0.0, "vy": 0.0,
			"t": rand(0, 3), "state": "follow", "cd": rand(0.3, 1), "face": P.face, "tgt": null, "mv": {}, "done": false, "auto": false,
			"dest": null, "claw": false, "tick": 0.0, "aim": "", "sx": 0.0, "sy": 0.0, "heal": 3.0, "thr": 0.0}


func petHit(e, mult: float, extra := {}) -> void:
	var m = {"dmg": mult * petMul(), "kb": 60, "up": -60, "style": 5, "anim": "pet", "both": true}
	m.merge(extra, true)
	if e.juggle > 0 or P.juggle == e:
		m.dmg *= 1 + skillRank("tactics") * 0.03
	damageSlime(e, m)
	P.en = minf(PS.enMax, P.en + PS.enHit * 0.4 * (1 + skillRank("skyBond") * 0.05))
	if buffOn("blazingWings"):
		e.burnT = maxf(e.burnT, 2)


func nearestFoe(x: float, y: float, r: float, pred = null):
	var best = null
	var bd = r
	for e in slimes:
		if e.state == "dead" or e.spawnT > 0 or e.bossEye:
			continue
		if pred != null and not pred.call(e):
			continue
		var d = Vector2(e.x - x, (e.y - e.h / 2) - y).length()
		if d < bd:
			bd = d
			best = e
	return best


func startJojoMove(key: String) -> bool:
	if gameTime < P.shotCd:
		return false
	startMove("j_" + key)
	var mv: Dictionary = JMOVES[key]
	var cmd: String = mv.get("cmd", "")
	P.shotCd = gameTime + (0.27 / PS.aspd if cmd == "bite" else (0.5 if cmd == "breath" else 0.14))
	if mv.get("air") and airLift():
		P.vy = minf(P.vy, -30)
	return true


func summonerInput(has: Callable, use: Callable, dirIn: int, _up: bool, down: bool, wet: bool, _canAct: bool, risingIntent: bool) -> void:
	for i in 4:
		if pressed.get(str(i + 1)):
			toggleSummon(i)
	var busy = P.state in ["climb", "hurt", "knocked"]
	var cancelable = _cancelable()
	if has.call("atk", 0.22) and not busy and cancelable:
		if dirIn and P.state != "attack":
			P.face = dirIn
		if P.state == "prone":
			# stay down: the dragon still answers
			if gameTime >= P.shotCd:
				use.call("atk")
				P.shotCd = gameTime + 0.3 / PS.aspd
				var m: Dictionary = JMOVES.cmd.duplicate()
				m.aim = "low"
				dragonCommand(m)
			return
		var air = not P.grounded and not wet
		if not air and risingIntent and closeEnemy(30) != null:
			if startJojoMove("throw"):
				use.call("atk")   # grab it and heave it skyward
			return
		if not air and not risingIntent and closeEnemy(22) != null:
			if startJojoMove("push"):
				use.call("atk")   # too close: shove it away
			return
		if startJojoMove(("cmdAir" if air else "cmd") + ("Up" if risingIntent else ("Down" if down else ""))):
			use.call("atk")
	if has.call("heavy", 0.2) and not busy and cancelable and P.state != "prone":
		if dirIn and P.state != "attack":
			P.face = dirIn
		if startJojoMove("fire"):
			use.call("heavy")


## the hand gesture lands: send the dragon in
func dragonCommand(mv: Dictionary) -> void:
	if not Pets.list.has("dragon"):
		return
	var Dg: Dictionary = Pets.list.dragon
	var form = dragonForm()
	var range_ = 200.0 if form == "baby" else (220.0 if form == "drake" else 260.0)
	if mv.get("cmd") == "breath":
		Dg.state = "breath"; Dg.t = 0.0; Dg.face = P.face; Dg.ticks = 0; Dg.aim = mv.aim; Dg.mv = mv; Dg.hitSet = {}
		Sfx.burst(0.6, "lowpass", 900, 300, 0.25)
		Sfx.tone(120, 0.5, "sawtooth", 0.06, 70)
		return
	var aim: String = mv.get("aim", "fwd")
	var tgt = aimTarget("low" if aim == "low" else aim, range_)
	Dg.state = "dash"; Dg.t = 0.0; Dg.tgt = tgt; Dg.mv = mv; Dg.done = false
	Dg.dest = null if tgt != null else [P.x + P.face * (90 if aim == "fwd" or aim == "low" else 0), P.y - 24 + (-90 if aim == "up" else (70 if aim == "down" else 0))]
	Sfx.tone(900, 0.08, "triangle", 0.05, 1300)


func updatePets(dt: float) -> void:
	if classId != "summoner" or not inGame:
		return
	if not Pets.list.has("dragon"):
		resetPets()
	var form = dragonForm()
	var rate = petRate()
	# ---------- the dragon
	var Dg: Dictionary = Pets.list.dragon
	Dg.t += dt
	Dg.cd -= dt
	var big = form != "baby"
	var home: Array
	if big:
		home = [P.x - P.face * (40 if form == "dragon" else 26), P.y - 70 if form == "dragon" else P.y]
	else:
		home = [P.x - P.face * 14 + sin(Dg.t * 2) * 3, P.y - 58 + sin(Dg.t * 3) * 3]
	var spd = 560.0 if form == "baby" else (380.0 if form == "drake" else 480.0)
	match Dg.state:
		"follow":
			Dg.x = damp(Dg.x, home[0], 8, dt)
			Dg.y = damp(Dg.y, home[1], 8, dt)
			Dg.face = P.face
			if (form != "baby" or skillRank("instinct")) and Dg.cd <= 0 and P.state != "dead":
				# later on, it fights by itself
				var e = nearestFoe(Dg.x, Dg.y - 10, 140.0 if form == "baby" else 180.0)
				if e != null:
					Dg.state = "dash"; Dg.t = 0.0; Dg.tgt = e; Dg.mv = {"dmg": 0.6, "kb": 60, "up": -60}; Dg.done = false; Dg.auto = true
					Dg.cd = (2 - skillRank("instinct") * 0.08) * rate
		"dash":
			var T: Array
			var tg = Dg.tgt
			if tg != null and tg.state != "dead":
				var sd: float = sgn(tg.x - P.x) if tg.x != P.x else 1.0
				T = [tg.x - sd * (14 if big else 4), tg.y - tg.h / 2 + (tg.h / 2 if form == "drake" else 0.0)]
			else:
				T = Dg.dest if Dg.dest != null else home
			var dx: float = T[0] - Dg.x
			var dy: float = T[1] - Dg.y
			var d = Vector2(dx, dy).length()
			if dx != 0:
				Dg.face = int(sgn(dx))
			if d < 10 or Dg.t > 0.7:
				if tg != null and tg.state != "dead" and not Dg.done:
					Dg.done = true
					petHit(tg, Dg.mv.dmg * (1.4 if big else 1.0) * (1.6 if form == "dragon" else 1.0), {"kb": Dg.mv.get("kb", 60), "up": Dg.mv.get("up", -60), "style": 4 if Dg.auto else 9})
					if big and not Dg.auto:
						# the drake's claws sweep everything close
						for e in slimes.duplicate():
							if e != tg and e.state != "dead" and absf(e.x - Dg.x) < (50 if form == "dragon" else 30) and absf(e.y - Dg.y) < 40:
								petHit(e, Dg.mv.dmg * 0.8, {"kb": 120, "up": -100})
					Sfx.tone(240, 0.08, "square", 0.06, 120)
					for k in 6:
						part(Dg.x + Dg.face * 6, Dg.y - 6, Dg.face * rand(20, 80), rand(-60, 20), 0.3, "#ffffff", 0, 1)
					Dg.state = "chomp"; Dg.t = 0.0
					Dg.claw = big and randf() < 0.5
				else:
					Dg.state = "return"; Dg.t = 0.0
				Dg.auto = false
			else:
				Dg.x += dx / d * minf(d, spd * dt)
				Dg.y += dy / d * minf(d, spd * dt)
		"chomp":
			if Dg.t > 0.16:
				Dg.state = "return"; Dg.t = 0.0
		"return":
			Dg.x = damp(Dg.x, home[0], 10, dt)
			Dg.y = damp(Dg.y, home[1], 10, dt)
			if Vector2(Dg.x - home[0], Dg.y - home[1]).length() < 6 or Dg.t > 0.6:
				Dg.state = "follow"
		"breath":
			# a cone of fire along the aim
			Dg.x = damp(Dg.x, P.x + P.face * (10 if big else 8), 10, dt)
			Dg.y = damp(Dg.y, (P.y - 70 if form == "dragon" else P.y) if big else P.y - 40, 10, dt)
			Dg.face = P.face
			var len = 80.0 if form == "baby" else (120.0 if form == "drake" else 170.0)
			var mouth = [Dg.x + Dg.face * ((60 if form == "dragon" else 30) if big else 10), Dg.y - ((40 if form == "dragon" else 34) if big else 6)]
			var cols = ["#ffd35a", "#ff8a2a", "#ff4a1a", "#fff1a8"]
			for k in 6:
				var s = rand(0, 1)
				part(mouth[0], mouth[1], Dg.face * rand(160, 300) * (0.6 + s), rand(-30, 40) + (30.0 if big else 0.0), rand(0.3, 0.5) * (len / 100), cols[k % 4], -40, 3 if big else 2)
			Dg.tick -= dt
			if Dg.tick <= 0:
				Dg.tick = 0.15
				var cap = 3 if form == "baby" else 99
				var n = 0
				for e in slimes.duplicate():
					if e.state == "dead" or n >= cap:
						continue
					var ex: float = (e.x - mouth[0]) * Dg.face
					var ey: float = (e.y - e.h / 2) - mouth[1]
					if ex > -6 and ex < len and absf(ey) < 14 + ex * 0.35 + (30 if big else 0):
						petHit(e, Dg.mv.get("dmg", 0.0) * (1.8 if form == "dragon" else (1.3 if big else 1.0)), {"kb": 30, "up": -30, "style": 3})
						e.burnT = maxf(e.burnT, 1.5)
						n += 1
			if Dg.t > 0.6:
				Dg.state = "follow"
				Dg.cd = maxf(Dg.cd, 0.4)
	# ---------- the blue slime: hops along and tackles whatever comes near
	var Sl: Dictionary = Pets.list.slime
	if summonOn("slime"):
		Sl.t += dt
		Sl.cd -= dt
		var g0: float = P.y if P.grounded else groundAt(P.x)
		if Sl.state == "follow":
			var tx = P.x - P.face * 26
			Sl.x = damp(Sl.x, tx, 4, dt)
			Sl.y = damp(Sl.y, g0, 10, dt)
			Sl.face = int(sgn(tx - Sl.x)) if tx != Sl.x else P.face
			var e = nearestFoe(Sl.x, Sl.y - 8, 120, func(q): return not q.T.get("fly") or q.y > P.y - 50) if Sl.cd <= 0 else null
			if e != null:
				Sl.state = "jump"; Sl.t = 0.0; Sl.tgt = e; Sl.sx = Sl.x; Sl.sy = Sl.y; Sl.cd = 1.4 * rate
				Sfx.squish()
		elif Sl.state == "jump":
			var k = minf(1, Sl.t / 0.35)
			var T = Sl.tgt
			Sl.x = Sl.sx + (T.x - Sl.sx) * k
			Sl.y = Sl.sy + (T.y - Sl.sy) * k - sin(k * PI) * 30
			Sl.face = int(sgn(T.x - Sl.sx)) if T.x != Sl.sx else 1
			if k >= 1:
				if T.state != "dead":
					petHit(T, 0.5, {"kb": 90, "up": -90})
				Sl.state = "follow"
	# ---------- the crocodile (with its mysterious spectacles): crawls along and chomps
	var C: Dictionary = Pets.list.croc
	if summonOn("croc"):
		C.t += dt
		C.cd -= dt
		var g0: float = P.y if P.grounded else groundAt(P.x)
		if C.state == "follow":
			var tx = P.x + P.face * 22
			C.vx = (tx - C.x) * 3
			C.x += C.vx * dt
			C.y = damp(C.y, g0, 10, dt)
			C.face = int(sgn(C.vx)) if absf(C.vx) > 5 else P.face
			var e = nearestFoe(C.x, C.y - 6, 90, func(q): return not q.T.get("fly") and absf(q.y - C.y) < 20) if C.cd <= 0 else null
			if e != null:
				C.state = "lunge"; C.t = 0.0; C.tgt = e; C.cd = 1.6 * rate
		elif C.state == "lunge":
			var T = C.tgt
			if T.x != C.x:
				C.face = int(sgn(T.x - C.x))
			C.x += C.face * 260 * dt
			if absf(T.x - C.x) < 18 or C.t > 0.35:
				if T.state != "dead" and absf(T.x - C.x) < 26:
					petHit(T, 0.9, {"kb": 120, "up": -60})
					Sfx.tone(260, 0.1, "square", 0.07, 110)
				C.state = "bite"; C.t = 0.0
		elif C.state == "bite":
			if C.t > 0.25:
				C.state = "follow"
	# ---------- the phoenix: circles overhead, then dives and sets enemies alight
	var Ph: Dictionary = Pets.list.phoenix
	if summonOn("phoenix"):
		Ph.t += dt
		Ph.cd -= dt
		if Ph.state == "follow":
			var tx = P.x + cos(Ph.t * 1.6) * 40
			var ty = P.y - 78 + sin(Ph.t * 3.2) * 8
			Ph.face = int(sgn(tx - Ph.x)) if tx != Ph.x else 1
			Ph.x = damp(Ph.x, tx, 3, dt)
			Ph.y = damp(Ph.y, ty, 3, dt)
			var e = nearestFoe(Ph.x, Ph.y, 200) if Ph.cd <= 0 else null
			if e != null:
				Ph.state = "dive"; Ph.t = 0.0; Ph.tgt = e; Ph.cd = 1.5 * rate
		elif Ph.state == "dive":
			var T = Ph.tgt
			var dx: float = T.x - Ph.x
			var dy: float = (T.y - T.h / 2) - Ph.y
			var d = Vector2(dx, dy).length()
			if d == 0:
				d = 1
			Ph.face = int(sgn(dx)) if dx != 0 else 1
			Ph.x += dx / d * minf(d, 420 * dt)
			Ph.y += dy / d * minf(d, 420 * dt)
			if randf() < 0.8:
				part(Ph.x, Ph.y, 0, -10, 0.4, "#ffd35a" if randf() < 0.5 else "#ff6a1a", 0, 2)
			if d < 8 or Ph.t > 0.7:
				if T.state != "dead" and d < 20:
					petHit(T, 0.8, {"kb": 40, "up": -120})
					T.burnT = maxf(T.burnT, 3)
				Ph.state = "follow"
	# ---------- the angel: hurls spears of light, and heals you
	var A: Dictionary = Pets.list.angel
	if summonOn("angel"):
		A.t += dt
		A.cd -= dt
		A.heal -= dt
		var tx = P.x - P.face * 34
		var ty = P.y - 70 + sin(A.t * 2) * 5
		A.x = damp(A.x, tx, 3, dt)
		A.y = damp(A.y, ty, 3, dt)
		var e = nearestFoe(A.x, A.y, 230) if A.cd <= 0 else null
		A.face = (int(sgn(e.x - A.x)) if e.x != A.x else 1) if e != null else P.face
		if e != null:
			A.cd = 2 * rate
			A.thr = 0.25
			fx.append({"type": "ray", "x": A.x, "y": A.y, "tx": e.x, "ty": e.y - e.h / 2, "t": 0.0, "life": 0.2})
			petHit(e, 1.2, {"kb": 80, "up": -80})
			Sfx.tone(1300, 0.12, "sine", 0.05, 1900)
		if A.thr > 0:
			A.thr -= dt
		if A.heal <= 0:
			A.heal = maxf(2.5, 5 - skillRank("grace") * 0.2)
			if P.hp < PS.hp and P.state != "dead":
				var h = roundi(PS.hp * (0.03 + skillRank("grace") * 0.002))
				P.hp = minf(PS.hp, P.hp + h)
				floatText(P.x, P.y - 52, "+%d" % h, "exp")
				for k in 10:
					part(P.x + rand(-10, 10), P.y - rand(0, 44), 0, -30, 0.7, "#fff6c0", 0, 1)
	if buffOn("sanctuary") and P.hp > 0:
		P.hp = minf(PS.hp, P.hp + PS.hp * 0.01 * dt)


func summonerSkillHit(mv: Dictionary, s: Dictionary, list: Array) -> bool:
	if s.get("fx") == "breath":
		if Pets.list.has("dragon"):
			var Dg: Dictionary = Pets.list.dragon
			Dg.state = "breath"; Dg.t = 0.0; Dg.face = P.face; Dg.mv = {"dmg": 0}
		for e in list:
			damageSlime(e, {"dmg": mv.dmg, "kb": 40, "up": -40, "style": 6, "anim": s.id, "both": true})
			e.burnT = maxf(e.burnT, 2)
		return true
	if s.id == "phoenixStrike":
		for e in list:
			e.burnT = maxf(e.burnT, 3)
	return false
