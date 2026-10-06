extends "res://scripts/skills.gd"
## Sproutvale, part 6: the bosses (Doc Croc, the Crimson Warlord), boss wrap-up and the main quest,
## obelisks, the boss pedestal, cutscene dialogue and the archer's ponytail.

const WSPD := 1.5   # the Warlord is half again as quick as his knights


func _newMob(type: String, T: Dictionary, x: float, y: float, surf) -> S.Mob:
	var e = S.Mob.new()
	slimeUid += 1
	e.id = slimeUid
	e.type = type; e.T = T; e.lv = T.lv
	e.x = x; e.y = y; e.surf = surf
	e.hp = T.hp; e.maxHp = T.hp; e.atk = T.atk; e.def = T.def; e.exp = T.exp
	return e


## a copy of a mob with a few fields changed (the prototype's Object.assign({}, e, {...}))
func _as(e, fields: Dictionary):
	var c = e.clone()
	for k in fields:
		c.set(k, fields[k])
	return c


func _boss():
	for e in slimes:
		if e.boss:
			return e
	return null


# ================================================================ Doc Croc

func spawnBoss() -> void:
	var e = _newMob("croc", BOSS_T, M.w * 0.66, M.floorY, surfaces[0])
	e.boss = true; e.bossKind = "croc"
	e.face = -1; e.state = "intro"
	e.mode = "quad"; e.act = "roar"; e.cd = 1.5; e.aggro = true
	e.w = 130; e.h = 50; e.showBar = 99
	slimes.append(e)
	later(0.5, func():
		if M.get("boss"):
			banner("Doc Croc", "Duck its claw swipes · dodge the falling rocks")
			Sfx.thunder())


func bossBox(e) -> Dictionary:
	if e.bossKind == "warlord":
		return hbox(e.x - 22, e.x + 22, e.y - 118, e.y)
	if e.mode == "stand" or e.act in ["rise", "swipe", "stomp", "drop"]:
		return hbox(e.x - 30, e.x + 34, e.y - 118, e.y)
	return hbox(e.x - 58, e.x + 70, e.y - 50, e.y)   # four legs: long and low (tail excluded)


func bossAct(e, a: String) -> void:
	e.act = a
	e.t = 0
	e.hitDone = false


func updateBoss(e, dt: float) -> void:
	e.t += dt; e.flash -= dt; e.hurtFlash -= dt; e.cd -= dt
	if e.state == "dead":
		e.deadT += dt
		e.vx = 0
		return
	var dx: float = P.x - e.x
	var dist = absf(dx)
	var pb = pBox()
	var spd = 1.35 if e.enraged else 1.0
	if not e.enraged and e.hp < e.maxHp * 0.45:
		e.enraged = true
		bossAct(e, "roar")
		banner("The crocodile is enraged!", "Faster attacks · more rocks")
	var turn = func():
		if absf(dx) > 10:
			e.face = int(sgn(dx))
	match e.act:
		"roar":
			e.vx = 0
			if e.t < dt * 1.01:
				Sfx.tone(90, 1, "sawtooth", 0.14, 60)
				shake = 8
			if e.t > 1.3:
				bossAct(e, ""); e.cd = 0.6
		"rise":
			e.vx = 0
			if e.t > 0.55:
				e.mode = "stand"; bossAct(e, ""); e.cd = 0.3
		"drop":
			e.vx = 0
			if e.t > 0.5:
				e.mode = "quad"; bossAct(e, ""); e.cd = 0.3
				dust(e.x + e.face * 30, e.y, 8)
		"bite":
			if e.t < 0.55 / spd:
				e.vx = 0
				turn.call()
			elif e.t < 0.9 / spd:
				e.vx = e.face * 270 * spd
				var hb = hbox(e.x + 40, e.x + 118, e.y - 46, e.y - 4) if e.face > 0 else hbox(e.x - 118, e.x - 40, e.y - 46, e.y - 4)
				if not e.hitDone and overlap(hb, pb):
					e.hitDone = true
					hurtPlayer(e, e.atk * 1.4)
				if not e.snap:
					e.snap = 1
					Sfx.tone(300, 0.12, "square", 0.1, 120)
			else:
				e.vx *= exp(-dt * 8)
				e.snap = 0
				if e.t > 1.4 / spd:
					bossAct(e, ""); e.cd = 0.7
		"swipe":
			# mid-height claw: lying prone (↓) slips underneath it
			e.vx = 0
			if e.t < 0.5 / spd:
				turn.call()
			elif e.t < 0.72 / spd:
				var hb = hbox(e.x + 12, e.x + 108, e.y - 78, e.y - 16) if e.face > 0 else hbox(e.x - 108, e.x - 12, e.y - 78, e.y - 16)
				if not e.hitDone:
					if overlap(hb, pb):
						e.hitDone = true
						hurtPlayer(e, e.atk * 1.1)
					elif isLow() and absf(dx) < 110:
						e.hitDone = true
						styleAdd(30, "duck")
						floatText(P.x, P.y - 30, "Ducked!", "call")
				if not e.swished:
					e.swished = 1
					Sfx.whoosh(0.6, true)
			else:
				e.swished = 0
				if e.t > 1.15 / spd:
					bossAct(e, ""); e.cd = 0.5
		"vial":
			# pull out vials, mix them, then lob a poison bomb at the player
			e.vx = 0
			turn.call()
			if e.t > 1.45 / spd and not e.hitDone:
				e.hitDone = true
				var sx2: float = e.x + e.face * 30
				var sy2: float = e.y - 100
				var tt2 = 0.9
				var tx = P.x + P.vx * 0.3
				bossVials.append({"x": sx2, "y": sy2, "vx": (tx - sx2) / tt2, "vy": (P.y - 6 - sy2 - 0.5 * 700 * tt2 * tt2) / tt2, "spin": 0.0})
				Sfx.whoosh(0.9, false)
				floatText(e.x, e.y - 140, "Mix complete!", "call")
			if e.t > 1.1 / spd and e.t < 1.45 / spd and randf() < 0.5:
				part(e.x + e.face * 30 + rand(-6, 6), e.y - 110, rand(-20, 20), -40, 0.5, "#8fff6a", 0, 2)
			if e.t > 2 / spd:
				bossAct(e, ""); e.cd = 0.7
		"stomp":
			e.vx = 0
			if e.t > 0.7 / spd and not e.hitDone:
				e.hitDone = true
				shake = 10
				Sfx.slam(); Sfx.thunder()
				dust(e.x + e.face * 16, e.y, 16)
				var n = 9 if e.enraged else 6
				var xs = [clampf(P.x, 30, M.w - 30)]
				var guard = 0
				while xs.size() < n and guard < 200:
					guard += 1
					var cx = rand(30, M.w - 30)
					if xs.all(func(v): return absf(v - cx) > 34):
						xs.append(cx)
				for i in xs.size():
					bossRocks.append({"x": xs[i], "warn": 1.15 + i * 0.07, "y": -30.0, "vy": 0.0, "phase": "warn", "life": 0.0})
				if absf(dx) < 70 and P.grounded and not isLow():
					hurtPlayer(_as(e, {"noCrit": true}), e.atk * 0.5)   # shockwave right under its feet
			if e.t > 1.5 / spd:
				bossAct(e, ""); e.cd = 0.8
		_:
			# choose the next move
			e.walkT += dt
			if e.mode == "quad":
				turn.call()
				if dist > 120:
					e.vx = e.face * 70 * spd
				else:
					e.vx *= exp(-dt * 8)
				if e.cd <= 0:
					var r = randf()
					if dist < 130 and r < 0.62:
						bossAct(e, "bite")
					elif r < 0.9:
						bossAct(e, "rise")
					else:
						e.cd = 0.4
			else:
				turn.call()
				if dist > 95:
					e.vx = e.face * 38 * spd
				else:
					e.vx *= exp(-dt * 8)
				if e.cd <= 0:
					var r = randf()
					if dist < 110 and r < 0.42:
						bossAct(e, "swipe")
					elif dist > 90 and r < 0.72:
						bossAct(e, "vial")
					elif r < 0.86:
						bossAct(e, "stomp")
					else:
						bossAct(e, "drop")
	e.x = clampf(e.x + e.vx * dt, 70, M.w - 70)
	e.y = e.surf.y
	if e.act != "bite" or e.t > 1:
		e.walkT += absf(e.vx) * dt * 0.02
	# touching the body hurts, like any mob
	if overlap(bossBox(e), pb) and P.touchCd <= 0 and P.state != "dash":
		P.touchCd = 1
		hurtPlayer(_as(e, {"noCrit": true}), e.atk * 0.45)


# ---------------- poison vials, puddles and the poison status

func updateVials(dt: float) -> void:
	for i in range(bossVials.size() - 1, -1, -1):
		var v: Dictionary = bossVials[i]
		v.vy += 700 * dt
		v.x += v.vx * dt
		v.y += v.vy * dt
		v.spin += dt * 12
		var hitP: bool = absf(v.x - P.x) < 10 and v.y > P.y - (13 if isLow() else 40) and v.y < P.y
		if hitP or v.y >= M.floorY:
			bossVials.remove_at(i)
			var b = _boss()
			Sfx.burst(0.25, "highpass", 3000, 6000, 0.3)
			Sfx.tone(600, 0.15, "triangle", 0.06, 200)
			for k in 18:
				part(v.x, minf(v.y, M.floorY) - 2, rand(-90, 90), rand(-160, -40), rand(0.4, 0.8), "#8fff6a" if k % 3 else "#d8ffe0", 600, 1 if k % 2 else 2, M.floorY)
			puddles.append({"x": v.x, "w": 52.0, "t": 0.0, "life": 3.2})
			if hitP and b != null:
				hurtPlayer(_as(b, {"x": v.x, "noCrit": true}), b.atk * 0.7)
				poisonPlayer(b.atk)
	for i in range(puddles.size() - 1, -1, -1):
		var p: Dictionary = puddles[i]
		p.t += dt
		if p.t > p.life:
			puddles.remove_at(i)
			continue
		if randf() < dt * 8:
			part(p.x + rand(-p.w / 2, p.w / 2), M.floorY - 1, 0, -rand(10, 25), 0.6, "#a8ff8a", 0, 1)
		if absf(P.x - p.x) < p.w / 2 and P.grounded and absf(P.y - M.floorY) < 2:
			var b = _boss()
			if b != null:
				poisonPlayer(b.atk, 2.5)
	if P.poison != null and P.poison.t > 0 and P.state != "dead":
		P.poison.t -= dt
		P.poison.tick -= dt
		if P.poison.tick <= 0:
			P.poison.tick = 0.5
			var d = maxi(1, roundi(P.poison.dps * 0.5))
			P.hp -= d
			floatText(P.x + rand(-6, 6), P.y - 44, str(d), "poison")
			if P.hp <= 0:
				killPlayer()
		if randf() < dt * 10:
			part(P.x + rand(-7, 7), P.y - rand(4, 36), 0, -rand(10, 25), 0.5, "#8fff6a", 0, 1)


func updateRocks(dt: float) -> void:
	for i in range(bossRocks.size() - 1, -1, -1):
		var r: Dictionary = bossRocks[i]
		if r.phase == "warn":
			r.warn -= dt
			if r.warn <= 0:
				r.phase = "fall"
				r.y = cam.y - 20
				r.vy = 200.0
		elif r.phase == "fall":
			r.vy += 1400 * dt
			r.y += r.vy * dt
			if r.y >= M.floorY:
				r.y = float(M.floorY)
				r.phase = "land"
				r.life = 0.35
				shake = maxf(shake, 4)
				Sfx.burst(0.2, "lowpass", 600, 80, 0.3)
				for k in 8:
					part(r.x + rand(-8, 8), r.y - 4, rand(-90, 90), rand(-200, -60), 0.5, "#6e665e" if k % 2 else "#8f877e", 800, 2, r.y)
				if absf(P.x - r.x) < 16 and P.y > r.y - 60:
					var b = _boss()
					if b != null:
						hurtPlayer(_as(b, {"x": r.x, "noCrit": true, "raid": true}), b.atk * 0.9)
		else:
			r.life -= dt
			if r.life <= 0:
				bossRocks.remove_at(i)


# ================================================================ the main quest and beating a boss

func advanceMain(mapId_: String, bossKind := "") -> void:
	var mq = mainQ()
	if mq.q >= MAINQS.size():
		return
	var Q: Dictionary = MAINQS[mq.q]
	var before: int = mq.stage
	for i in Q.on.size():
		var trig: String = Q.on[i]
		if mq.stage == i and (trig == mapId_ or trig == bossKind):
			mq.stage = i + 1
	if mq.stage != before and inGame:
		saveDirty = true
		var st: int = mq.stage
		later(0.9, func(): toast("★ Main quest complete! Claim the reward in the Quests tab." if st >= Q.steps.size() else "★ Main quest: %s" % Q.steps[st]))


func killBoss(e) -> void:
	var kind: String = e.bossKind if e.bossKind != "" else "croc"
	var firstKill: bool = not save.trophies.get(kind)
	advanceMain("", kind)
	var c = CH()
	if not (c.get("bossKills") is Dictionary):
		c.bossKills = {}
	c.bossKills[kind] = c.bossKills.get(kind, 0) + 1   # which hero beat which boss, for the account record
	if firstKill:
		save.trophies[kind] = true
		PS = calcStats()
		later(2.6, func(): toast("🏆 New trophy for your Trophy Hall! (+10% EXP)"))
	later(1.5, func(): Sfx.music("trophy"))   # a calm, stately victory theme
	rollCards(_as(e, {"type": kind, "surf": surfaces[0]}))
	e.state = "dead"; e.deadT = 0; e.hp = 0
	bossRocks.clear(); bossVials.clear(); puddles.clear()
	if kind == "warlord":
		for q in slimes:
			if q.bossEye:
				q.state = "dead"
		Warlord.rain = 0.0
	Sfx.tone(80, 1.4, "sawtooth", 0.14, 40)
	shake = 10
	slowmo = 1.2
	var coinN = 50 if kind == "warlord" else 26
	for i in coinN:
		var d = S.Drop.new()
		d.kind = "coin"; d.x = e.x; d.y = e.y - 30; d.vx = rand(-160, 160); d.vy = rand(-340, -180)
		d.val = rint(14, 24) * (3 if kind == "warlord" else 1)
		d.surfY = M.floorY; d.x0 = 20; d.x1 = M.w - 20; d.spin = randf() * 4
		drops.append(d)
	var bx = roundi(mobExp(e) * (1 + cardBonus()))
	gainExp(bx)
	floatText(e.x, e.y - 130, "+%d EXP" % bx, "exp")
	save.bossCoins = save.get("bossCoins", 0) + 1
	saveDirty = true
	c.kills += 1
	recordKill(_as(e, {"type": kind}))
	cheer()
	if kind == "croc" and firstKill:
		# Doc Croc's last words (only the first time), then the way east opens
		later(1.8, func():
			startScene([{"who": "Doc Croc", "text": "Hrrk... you think... you've won something..."}, {"who": "Doc Croc", "text": "The wizard... is not who you think he is."}], func():
				if not MAPS.lair.portals.any(func(p): return p.to == "crimson1"):
					MAPS.lair.portals.append({"x": MAPS.lair.w - 40, "to": "crimson1", "tx": 70, "label": "The Crimson Wastes"})
				shake = 8
				Sfx.thunder()
				for i in 40:
					part(MAPS.lair.w - 40 + rand(-10, 10), M.floorY - rand(0, 50), rand(-60, 60), rand(-90, 10), 0.9, "#ff3a4a" if i % 2 else "#ffd0d6", 0, 2)
				banner("A portal tears open", "A blood-red light spills from the east side of the lair")
				Sfx.rankUp(9)))
	else:
		later(0.9, func():
			banner("THE WARLORD FALLS" if kind == "warlord" else "DOC CROC DEFEATED", "+1 Boss Coin · the pedestal can call him back")
			Sfx.rankUp(9))
	var arena = M
	later(2.6, func():
		if arena.get("boss") and arena.get("pedestal") == null:
			arena.pedestal = {"x": roundi(arena.w * (0.5 if kind == "warlord" else 0.55)), "kind": kind})
	styleAdd(120, "boss")


# ================================================================ the Crimson Warlord

func spawnWarlord() -> void:
	thrownSword = null
	Warlord.rain = 0.0
	Warlord.rainWarn = 0.0
	var s = findSurf(func(q): return q.floor)
	if s == null:
		s = surfaces[0]
	var e = _newMob("warlord", WARLORD_T, M.w - 70, M.floorY, s)
	e.boss = true; e.bossKind = "warlord"; e.face = -1; e.state = "intro"
	e.aggro = true; e.w = 44; e.h = 118
	e.mode = "ss"; e.act = "laugh"; e.cd = 1; e.eyesOut = 0; e.eyeCd = 9; e.throwCd = 6; e.rainCd = 14; e.showBar = 99
	slimes.append(e)
	if Warlord.introDone:
		# the intro only plays once
		e.act = ""
		e.x = M.w - 160
		e.cd = 1.2
	else:
		P.frozen = true


func updateWarlord(e, dt: float) -> void:
	e.t += dt; e.hurtFlash -= dt; e.cd -= dt / WSPD; e.eyeCd -= dt; e.throwCd -= dt; e.rainCd -= dt
	if e.state == "dead":
		e.deadT += dt
		return
	var dx: float = P.x - e.x
	var dist = absf(dx)
	var pb = hbox(-99, -98, 0, 0) if P.state == "dead" else pBox()
	var turn = func():
		if dist > 8:
			e.face = int(sgn(dx))
	var swingBox = func(reach: float, h: float) -> Dictionary:
		return hbox(e.x, e.x + reach, e.y - h, e.y) if e.face > 0 else hbox(e.x - reach, e.x, e.y - h, e.y)
	if not e.enraged and e.hp < e.maxHp * 0.4:
		e.enraged = true
		banner("The Warlord rages", "Faster, and the Crimson Rain comes more often")
	match e.act:
		"laugh":
			# a rattling, maniacal laugh before he leaps in
			if e.t < dt * 1.01:
				for i in 9:
					Sfx.tone(320 - i * 18 + (i % 2) * 60, 0.09, "square", 0.07, 260 - i * 14, i * 0.11)
			if e.t > 1.3:
				bossAct(e, "introJump")
				e.jx0 = e.x
				e.jx1 = clampf(P.x + 90, 120, M.w - 80)
		"introJump":
			var k = minf(1, e.t / 0.85)
			e.x = e.jx0 + (e.jx1 - e.jx0) * k
			e.y = M.floorY - sin(k * PI) * 120
			e.face = -1
			if k >= 1:
				e.y = M.floorY
				shake = 12
				Sfx.slam()
				dust(e.x, e.y, 24)
				bossAct(e, "talk")
				startScene([{"who": "Crimson Warlord", "text": "You will make a good addition to my army."}], func():
					P.frozen = false
					Warlord.introDone = true
					bossAct(e, "")
					e.cd = 0.6)
		"talk":
			pass
		"swing":
			# sword and shield: a quick cut
			e.vx = 0
			if e.t < 0.22 / WSPD:
				turn.call()
			elif e.t < 0.42 / WSPD:
				if not e.hitDone and overlap(swingBox.call(92, 120), pb):
					e.hitDone = true
					hurtPlayer(e, e.atk * 1.0)
				if not e.sw:
					e.sw = 1
					Sfx.whoosh(0.9, true)
			else:
				e.sw = 0
				if e.t > 0.75 / WSPD:
					bossAct(e, ""); e.cd = 0.4
		"bash":
			# a charging shield bash that knocks you flat
			if e.t < 0.28 / WSPD:
				e.vx = 0
				turn.call()
			elif e.t < 0.65 / WSPD:
				e.vx = e.face * 480
				if not e.hitDone and overlap(bossBox(e), pb):
					e.hitDone = true
					hurtPlayer(_as(e, {"raid": true}), e.atk * 0.9)
				if randf() < 0.5:
					dust(e.x - e.face * 20, e.y, 2)
			else:
				e.vx *= exp(-dt * 8)
				if e.t > 1 / WSPD:
					bossAct(e, ""); e.cd = 0.5
		"cleave":
			# greatsword: a broad, heavy arc
			e.vx = 0
			if e.t < 0.42 / WSPD:
				turn.call()
			elif e.t < 0.7 / WSPD:
				if not e.hitDone and overlap(swingBox.call(135, 130), pb):
					e.hitDone = true
					hurtPlayer(e, e.atk * 1.5)
				if not e.sw:
					e.sw = 1
					Sfx.whoosh(0.6, true)
					shake = 4
			else:
				e.sw = 0
				if e.t > 1.1 / WSPD:
					bossAct(e, ""); e.cd = 0.5
		"leap":
			# jump to you and slam the greatsword down
			if e.t < 0.25 / WSPD:
				e.vx = 0
				turn.call()
				e.jx0 = e.x
				e.jx1 = clampf(P.x, 80, M.w - 80)
			else:
				var k = minf(1, (e.t - 0.25 / WSPD) / (0.75 / WSPD))
				e.x = e.jx0 + (e.jx1 - e.jx0) * k
				e.y = M.floorY - sin(k * PI) * 110
				if k >= 1 and not e.hitDone:
					e.hitDone = true
					e.y = M.floorY
					shake = 10
					Sfx.slam()
					dust(e.x, e.y, 20)
					if overlap(hbox(e.x - 80, e.x + 80, e.y - 50, e.y + 2), pb):
						hurtPlayer(e, e.atk * 1.3)
				if k >= 1 and e.t > 1.4 / WSPD:
					bossAct(e, ""); e.cd = 0.6
		"switch":
			e.vx = 0
			if e.t > 0.5:
				e.mode = "gs" if e.mode == "ss" else "ss"
				Sfx.tone(300, 0.2, "square", 0.06, 160)
				bossAct(e, ""); e.cd = 0.3
		"eyes":
			# plucks out his eyes and sends them after you
			e.vx = 0
			if e.t > 0.5 and not e.hitDone:
				e.hitDone = true
				e.eyesOut = 2
				e.eyeCd = 16
				for s in [-1, 1]:
					var q = _newMob("evileye", SLIME_TYPES.evileye, e.x + s * 6, e.y - 100, e.surf)
					q.bossEye = true; q.owner = e; q.lv = e.lv
					q.vx = s * 120; q.vy = -120; q.face = s; q.state = "chase"; q.life = 9
					q.hp = 1; q.maxHp = 1; q.atk = e.atk * 0.45; q.def = 0; q.exp = 0; q.coinMul = 0; q.aggro = true; q.w = 14; q.h = 14
					slimes.append(q)
				Sfx.tone(700, 0.3, "sawtooth", 0.06, 200)
			if e.t > 1:
				bossAct(e, ""); e.cd = 0.4
		"throw":
			# hurls the greatsword at where you stand; it sticks in the ground and he has to go get it
			e.vx = 0
			if e.t < 0.45 / WSPD:
				turn.call()
			elif not e.hitDone:
				e.hitDone = true
				thrownSword = {"x": e.x + e.face * 30, "y": e.y - 90, "tx": clampf(P.x, 40, M.w - 40), "t": 0.0, "dur": 0.6, "stuck": false, "spin": 0.0, "cx": e.x, "cy": e.y - 90}
				e.mode = "un"
				Sfx.whoosh(0.7, true)
			if e.t > 0.9 / WSPD:
				bossAct(e, "fetch")
		"fetch":
			if thrownSword != null and thrownSword.stuck:
				var d2: float = thrownSword.x - e.x
				if d2 != 0:
					e.face = int(sgn(d2))
				e.vx = e.face * 150 if absf(d2) > 12 else 0.0
				e.walkT += dt * 2
				if absf(d2) <= 12:
					e.vx = 0
					bossAct(e, "pickup")
			else:
				e.vx = 0
		"pickup":
			if e.t > 0.45:
				thrownSword = null
				e.mode = "gs"
				Sfx.tone(220, 0.2, "square", 0.06, 330)
				bossAct(e, ""); e.cd = 0.3
		"rain":
			# Crimson Rain: blood falls everywhere except beneath the two ledges
			e.vx = 0
			if e.t < dt * 1.01:
				Warlord.rainWarn = 1.5
				banner("CRIMSON RAIN", "Take cover beneath a ledge!")
				Sfx.thunder()
			if e.t > 1.5 and not e.hitDone:
				e.hitDone = true
				Warlord.rain = 5.5
			if e.t > 2.2:
				bossAct(e, ""); e.cd = 0.4
				e.rainCd = 16 if e.enraged else 24
		_:
			# choose the next move
			if P.frozen or P.state == "dead":
				e.vx = 0
			else:
				turn.call()
				e.walkT += dt
				if e.cd > 0:
					e.vx = e.face * 85 * WSPD if dist > 60 else 0.0
				else:
					var r = randf()
					if e.rainCd <= 0 and e.hp < e.maxHp * 0.8:
						bossAct(e, "rain")
					elif e.eyeCd <= 0 and not e.eyesOut and r < 0.3:
						bossAct(e, "eyes")
					elif e.mode == "ss":
						if dist < 85:
							bossAct(e, "swing")
						elif dist < 240 and r < 0.55:
							bossAct(e, "bash")
						elif r < 0.75:
							bossAct(e, "switch")
						else:
							e.vx = e.face * 85 * WSPD
					elif e.mode == "gs":
						if dist < 120:
							bossAct(e, "cleave" if r < 0.85 else "switch")
						elif e.throwCd <= 0 and r < 0.35:
							bossAct(e, "throw")
							e.throwCd = 14
						elif dist < 300 and r < 0.7:
							bossAct(e, "leap")
						else:
							e.vx = e.face * 85 * WSPD
					else:
						bossAct(e, "fetch")
	if not (e.act in ["introJump", "leap"]):
		e.x = clampf(e.x + e.vx * dt, 40, M.w - 40)
		e.y = M.floorY
	e.walkT += absf(e.vx) * dt * 0.02
	if not (e.act in ["laugh", "introJump", "talk"]) and overlap(bossBox(e), pb) and P.touchCd <= 0 and P.state != "dash":
		P.touchCd = 1
		hurtPlayer(_as(e, {"noCrit": true}), e.atk * 0.4)
	# the thrown greatsword
	if thrownSword != null and not thrownSword.stuck:
		var Sw: Dictionary = thrownSword
		Sw.t += dt
		Sw.spin += dt * 20
		var k = minf(1, Sw.t / Sw.dur)
		Sw.cx = Sw.x + (Sw.tx - Sw.x) * k
		Sw.cy = Sw.y + (M.floorY - 10 - Sw.y) * k - sin(k * PI) * 60
		if k >= 1:
			Sw.stuck = true
			Sw.x = Sw.tx
			shake = 6
			Sfx.slam()
			dust(Sw.x, M.floorY, 10)
			if absf(P.x - Sw.x) < 18 and P.y > M.floorY - 50:
				hurtPlayer(_as(e, {"noCrit": true}), e.atk * 1.1)


## the Warlord's eyes: they hunt you until struck, then fly back home
func updateBossEye(e, dt: float) -> void:
	e.t += dt
	e.flash -= dt
	var o = e.owner
	if o == null or o.state == "dead":
		e.state = "dead"
		slimes.erase(e)
		return
	if e.returning or e.t > e.life:
		var tx: float = o.x + o.face * 8
		var ty: float = o.y - 100
		var a = atan2(ty - e.y, tx - e.x)
		e.x += cos(a) * 420 * dt
		e.y += sin(a) * 420 * dt
		if Vector2(tx - e.x, ty - e.y).length() < 10:
			o.eyesOut = maxi(0, o.eyesOut - 1)
			slimes.erase(e)
			Sfx.tone(900, 0.08, "sine", 0.05, 1200)
		return
	var dx: float = P.x - e.x
	var dy: float = (P.y - 24) - e.y
	var d = Vector2(dx, dy).length()
	if d == 0:
		d = 1
	e.face = int(sgn(dx)) if dx != 0 else 1
	e.vx = damp(e.vx, dx / d * 150, 2.5, dt)
	e.vy = damp(e.vy, dy / d * 150, 2.5, dt)
	e.x += e.vx * dt
	e.y += e.vy * dt
	if overlap(hbox(e.x - 7, e.x + 7, e.y - 7, e.y + 7), pBox()) and P.touchCd <= 0:
		P.touchCd = 0.8
		hurtPlayer(_as(e, {"noCrit": true}), e.atk)


func rainSafe() -> bool:
	return M.plats.any(func(pl): return P.x > pl[0] + 4 and P.x < pl[0] + pl[2] - 4 and P.y > pl[1] + 4)


func updateCrimsonRain(dt: float) -> void:
	if Warlord.rainWarn > 0:
		Warlord.rainWarn -= dt
	if Warlord.rain <= 0:
		return
	Warlord.rain -= dt
	Warlord.tick -= dt
	var b = null
	for e in slimes:
		if e.bossKind == "warlord" and e.state != "dead":
			b = e
	if b != null and Warlord.tick <= 0:
		Warlord.tick = 0.5
		if not rainSafe() and P.state != "dead":
			bleedPlayer(b.atk * 0.14, 3.5)


# ================================================================ obelisks
## appear at random; ↑ beside one triggers an elite, an abyssal swarm, or a coin shower

func resetObelisk() -> void:
	obelisk = null
	obeliskTimer = rand(35, 75)


func updateObelisk(dt: float) -> void:
	if M.get("boss") or M.get("safe") or not inGame:
		return
	if obelisk == null:
		obeliskTimer -= dt
		if obeliskTimer <= 0:
			var opts = surfaces.filter(func(s): return not s.water and s.x1 - s.x0 > 60)
			if opts.is_empty():
				obeliskTimer = 30
				return
			var s: Dictionary = opts[rint(0, opts.size() - 1)]
			var x = rand(s.x0 + 24, s.x1 - 24)
			var guard = 0
			while (M.portals.any(func(p): return absf(p.x - x) < 50) or (M.get("bossSign") and absf(M.bossSign - x) < 60)) and guard < 20:
				guard += 1
				x = rand(s.x0 + 24, s.x1 - 24)
			obelisk = {"x": x, "y": s.y, "surf": s, "t": 0.0, "life": 120.0, "used": false, "rise": 0.0, "fade": 0.0}
			toast("An Obelisk has risen somewhere on this map! Check the minimap.")
			Sfx.tone(70, 1.2, "sine", 0.12, 50)
			Sfx.tone(140, 1.2, "triangle", 0.05, 110)
		return
	var o: Dictionary = obelisk
	o.t += dt
	o.rise = minf(1, o.rise + dt * 1.2)
	if o.used:
		o.fade += dt
		if o.fade > 1:
			resetObelisk()
		return
	if randf() < dt * 6:
		part(o.x + rand(-6, 6), o.y - rand(5, 40), 0, -18, 0.9, ["#b88aff", "#ff3ad8", "#9fffe8"][rint(0, 2)], 0, 1)
	if o.t > o.life:
		o.used = true
		toast("The Obelisk crumbled away unused.")


func activateObelisk(o) -> void:
	o.used = true
	shake = 6
	Sfx.thunder()
	Sfx.tone(220, 0.6, "sawtooth", 0.08, 880)
	for i in 40:
		var a = randf() * TAU
		part(o.x, o.y - 24, cos(a) * rand(40, 160), sin(a) * rand(40, 160), rand(0.5, 1), ["#b88aff", "#ff3ad8", "#ffffff"][i % 3], 0, 2)
	var r = randf()
	if r < 0.4:
		obeliskElite(o)
	elif r < 0.7:
		obeliskAbyss(o)
	else:
		obeliskCoins(o)


func obeliskElite(o: Dictionary) -> void:
	# elites stand and fight
	var types: Array = M.get("spawn", {}).keys().filter(func(k): return not SLIME_TYPES[k].get("flees"))
	if types.is_empty():
		obeliskCoins(o)
		return
	var type: String = types[rint(0, types.size() - 1)]
	var floors = surfaces.filter(func(s): return s.floor and not s.water)
	floors.sort_custom(func(a, b): return absf((a.x0 + a.x1) / 2 - o.x) < absf((b.x0 + b.x1) / 2 - o.x))
	var fl: Dictionary = floors[0]
	var T: Dictionary = SLIME_TYPES[type]
	var e = _newMob(type, T, clampf(o.x + 60, fl.x0 + 60, fl.x1 - 60), fl.y, fl)
	e.face = -1
	e.hp = T.hp * 10; e.maxHp = e.hp; e.atk = T.atk * 3; e.def = T.def * 1.5; e.exp = T.exp * 15; e.coinMul = 10
	e.aggro = true; e.bang = 1; e.hopCd = 1; e.atkCd = 1.5; e.spawnT = 0.5; e.showBar = 99; e.elite = true
	var critter: bool = T.get("critter", false)
	e.w = ((16.0 if type == "rat" else 22.0) if critter else 18.0 * T.size) * 3
	e.h = (10.0 if critter else 16.0 * T.size) * 3
	slimes.append(e)
	banner("ELITE %s" % T.name.to_upper(), "10× health, 3× damage, and big rewards")
	Sfx.tone(60, 1.4, "sawtooth", 0.12, 40)


func obeliskAbyss(o: Dictionary) -> void:
	var sp: Dictionary = M.get("spawn", {})
	var keys: Array = sp.keys()
	if keys.is_empty():
		obeliskCoins(o)
		return
	# the map's main monster (most common spawn) sets the level: +5 above it
	keys.sort_custom(func(a, b): return sp[a] > sp[b] if sp[a] != sp[b] else SLIME_TYPES[a].lv > SLIME_TYPES[b].lv)
	var top: Dictionary = SLIME_TYPES[keys[0]]
	var lv: int = top.lv + 5
	var T = {"name": "Abyssal Tangle", "lv": lv, "hp": roundi(top.hp * 1.8 + lv * 14), "atk": roundi(top.atk * 1.4 + lv * 1.6), "def": top.def + lv * 0.5,
		"exp": roundi(top.exp * 4 + lv * 10), "coins": [8 + lv, 16 + lv * 2], "speed": 1.25, "size": 1, "critter": true, "color": 0x3a1850, "matName": null}
	var n = rint(10, 20)
	var near = surfaces.filter(func(s): return not s.water and s.x1 > o.x - 260 and s.x0 < o.x + 260 and s.x1 - s.x0 > 40)
	for i in n:
		var s: Dictionary = near[rint(0, near.size() - 1)] if near.size() else surfaces[0]
		var x = clampf(o.x + rand(-220, 220), s.x0 + 14, s.x1 - 14)
		var e = _newMob("abyss", T, x, s.y, s)
		e.face = int(sgn(P.x - x)) if P.x != x else 1
		e.t = rand(0, 2); e.hopCd = rand(0.2, 1); e.spawnT = 0.5 + i * 0.06; e.w = 20; e.h = 16
		slimes.append(e)
		for k in 6:
			part(x, s.y - 4, rand(-30, 30), rand(-90, -30), 0.7, "#2a0838" if k % 2 else "#ff3ad8", 0, 2)
	banner("THE ABYSS STIRS", "%d Abyssal Tangles (Lv %d) drop Abyssal Coins" % [n, lv])
	Sfx.tone(55, 1.6, "sawtooth", 0.12, 35)


func obeliskCoins(o: Dictionary) -> void:
	var amount = roundi(250 + 4750 * pow(randf(), 3.5))   # big showers are rare
	var pieces = clampi(roundi(amount / 70.0), 12, 70)
	var fl: Dictionary = o.surf
	var left = amount
	for i in pieces:
		var v = left if i == pieces - 1 else maxi(1, roundi(float(amount) / pieces * rand(0.6, 1.4)))
		left -= v
		if left < 0:
			break
		later(i * 0.06, func():
			var d = S.Drop.new()
			d.kind = "coin"; d.x = clampf(o.x + rand(-140, 140), fl.x0 + 4, fl.x1 - 4); d.y = cam.y - 10
			d.vx = rand(-15, 15); d.vy = rand(40, 120); d.val = v
			d.surfY = fl.y; d.x0 = fl.x0 + 4; d.x1 = fl.x1 - 4; d.spin = randf() * 4
			drops.append(d))
	banner("COIN SHOWER!", "%s coins are raining down" % fmt(amount))
	Sfx.rankUp(7)


# ================================================================ the boss pedestal

func summonFromPedestal() -> void:
	var pd: Dictionary = M.pedestal
	shake = 8
	Sfx.thunder()
	for i in 30:
		part(pd.x + rand(-12, 12), M.floorY - rand(0, 40), rand(-60, 60), rand(-140, -40), 0.8, "#ff3a4a" if pd.kind == "warlord" else "#8fff6a", 0, 2)
	if pd.kind == "warlord":
		Warlord.introDone = true
		spawnWarlord()
		var w = slimes[-1]
		w.x = minf(M.w - 80, P.x + 220)
	else:
		spawnBoss()
		var b = _boss()
		if b != null:
			b.x = minf(M.w - 60, P.x + 200)
	P.face = 1
	Sfx.music(M.get("music", "warlord" if pd.kind == "warlord" else "lair"))


# ================================================================ cutscenes
## a dialogue box; the world holds still while it plays

func startScene(lines: Array, onEnd = null) -> void:
	scene = {"lines": lines, "i": 0, "shown": 0.0, "t": 0.0, "onEnd": onEnd}
	P.vx = 0
	Sfx.tone(440, 0.12, "triangle", 0.05, 660)


func updateScene(dt: float) -> void:
	var Sc: Dictionary = scene
	Sc.t += dt
	var L: Dictionary = Sc.lines[Sc.i]
	Sc.shown = minf(L.text.length(), Sc.shown + dt * 32)
	var adv: bool = pressed.get("z", false) or pressed.get("x", false) or pressed.get(" ", false) or pressed.get("enter", false)
	pressed.clear()
	if adv and Sc.t > 0.25:
		if Sc.shown < L.text.length():
			Sc.shown = float(L.text.length())
		elif Sc.i < Sc.lines.size() - 1:
			Sc.i += 1
			Sc.shown = 0.0
			Sc.t = 0.0
			Sfx.tone(440, 0.08, "triangle", 0.04, 600)
		else:
			scene = null
			if Sc.onEnd is Callable:
				Sc.onEnd.call()


# ================================================================ the archer's ponytail
## a short verlet rope tied to the head of the current frame

func updateTail(dt: float, anchor: Vector2) -> void:
	var T = Tail
	var pts: Array = T.pts
	if pts.is_empty() or Vector2(pts[0].x - anchor.x, pts[0].y - anchor.y).length() > 40:
		pts = []
		for i in T.n:
			var x = anchor.x - P.face * i * 1.5
			var y: float = anchor.y + i * T.seg
			pts.append({"x": x, "y": y, "px": x, "py": y})
		T.pts = pts
	var g = 420.0
	var wind: float = -World.wind * 70 * (0.4 if P.wet > 0.5 else 1.0)
	var d2 = dt * dt
	pts[0].x = anchor.x
	pts[0].y = anchor.y
	for i in range(1, pts.size()):
		var p: Dictionary = pts[i]
		var vx: float = (p.x - p.px) * 0.94
		var vy: float = (p.y - p.py) * 0.94
		p.px = p.x
		p.py = p.y
		var flutter: float = sin(gameTime * 7 + i * 1.3) * World.wind * 18 * (float(i) / pts.size())
		p.x += vx + (wind + flutter) * d2
		p.y += vy + g * (1.25 if P.wet > 0.5 else 1.0) * d2
	for it in 4:
		for i in range(1, pts.size()):
			var a: Dictionary = pts[i - 1]
			var b: Dictionary = pts[i]
			var dx: float = b.x - a.x
			var dy: float = b.y - a.y
			var d = Vector2(dx, dy).length()
			if d == 0:
				d = 1e-6
			var diff: float = (d - T.seg) / d
			if i == 1:
				b.x -= dx * diff
				b.y -= dy * diff
			else:
				a.x += dx * diff * 0.5
				a.y += dy * diff * 0.5
				b.x -= dx * diff * 0.5
				b.y -= dy * diff * 0.5
		# keep the first couple of links behind the head so it reads as a ponytail, not a fringe
		var back: Dictionary = pts[1]
		if (back.x - pts[0].x) * P.face > -0.8:
			back.x = pts[0].x - P.face * 0.8
		pts[0].x = anchor.x
		pts[0].y = anchor.y
