extends "res://scripts/player.gd"
## Sproutvale, part 4: the monsters. Spawning (pairs of feet, flyers, shinies), the meadow AI,
## the Crimson Wastes AI, taking damage and dying (coins, materials, cards, EXP).


func makeShiny(e) -> void:
	e.shiny = true
	e.maxHp = e.maxHp * 3
	e.hp = e.maxHp
	e.atk *= 3
	e.def *= 1.5


func spawnSlime(initial := false) -> void:
	var spawn: Dictionary = M.get("spawn", {})
	if spawn.is_empty():
		return   # safe maps have nothing to spawn
	var pool = []
	for k in spawn:
		if M.get("ignoreUnlock") or SLIME_TYPES[k].unlock <= CH().level:
			pool.append([k, float(spawn[k])])
	if pool.is_empty():
		return
	var tot = 0.0
	for pw in pool:
		tot += pw[1]
	var r = randf() * tot
	var type: String = pool[0][0]
	for pw in pool:
		r -= pw[1]
		if r <= 0:
			type = pw[0]
			break
	var T: Dictionary = SLIME_TYPES[type]
	var s: Dictionary
	var x = 0.0
	var guard = 0
	var shiny = randf() < 0.03
	if T.get("habitat"):   # the Abyss's monsters live on land, in the air, in open water or on the sea floor
		spawnAbyssMob(type, T, initial, shiny)
		return
	var dry = surfaces.filter(func(q): return not q.water)
	while true:
		var wt = 0.0
		for q in dry:
			wt += q.x1 - q.x0
		var pk = randf() * wt
		s = dry[0]
		for q in dry:
			pk -= q.x1 - q.x0
			if pk <= 0:
				s = q
				break
		x = rand(s.x0 + 14, s.x1 - 14)
		guard += 1
		if not (absf(x - P.x) < 110 and absf(s.y - P.y) < 60 and guard <= 20):
			break
	var e = S.Mob.new()
	slimeUid += 1
	e.id = slimeUid
	e.type = type; e.T = T; e.lv = T.lv   # strict levels: every monster type always has the same level and stats
	e.x = x; e.y = s.y; e.surf = s
	e.face = -1 if randf() < 0.5 else 1
	e.t = rand(0, 2)
	e.hp = T.hp; e.maxHp = T.hp; e.atk = T.atk; e.def = T.def; e.exp = T.exp
	e.hopCd = rand(0.5, 2)
	e.spawnT = 0.0 if initial else 0.5
	var critter: bool = T.get("critter", false)
	e.w = float(T.bw) if T.get("bw") else ((16.0 if type == "rat" else 22.0) if critter else 18.0 * T.size)
	e.h = float(T.bh) if T.get("bh") else (10.0 if critter else 16.0 * T.size)
	slimes.append(e)
	if T.get("fly"):
		# flyers hover above their patch of ground
		e.homeY = s.y - rand(30, 70)
		e.y = e.homeY
		e.homeX = x
	if shiny:
		makeShiny(e)
	if type == "feet" and e.partner == null:
		# Travelers walk in pairs
		var e2: S.Mob = e.clone()
		slimeUid += 1
		e2.id = slimeUid
		e2.x = clampf(x + 14, s.x0 + 8, s.x1 - 8)
		e2.partner = e
		e2.t = e.t + 0.5
		e2.shiny = false
		e2.hp = T.hp; e2.maxHp = T.hp; e2.atk = T.atk; e2.def = T.def; e2.exp = T.exp
		slimes.append(e2)
		e.partner = e2


func _dustPart(e, vx: float, vy: float) -> void:
	part(e.x - e.face * 10, e.y - 1, vx, vy, 0.3, "#d8c8a8", 0, 2)


func updateSlimes(dt: float) -> void:
	var pb = pBox()
	var i = slimes.size() - 1
	while i >= 0:
		if i >= slimes.size():
			i = slimes.size() - 1
			if i < 0:
				break
		var e: S.Mob = slimes[i]
		var T: Dictionary = e.T
		e.t += dt; e.flash -= dt; e.bang -= dt; e.atkCd -= dt; e.hopCd -= dt; e.showBar -= dt
		if e.spawnT > 0:
			e.spawnT -= dt
		if e.boss:
			if e.bossKind == "warlord":
				updateWarlord(e, dt)
			elif e.bossKind == "dreamer":
				updateDreamer(e, dt)
			elif e.bossKind == "kingYeti":
				updateYeti(e, dt)
			elif updateBossKind(e, dt):
				pass
			else:
				updateBoss(e, dt)
			if e.state == "dead" and e.deadT > 2.4 and scene == null:
				slimes.erase(e)
			i -= 1
			continue
		if e.bossEye:
			updateBossEye(e, dt)
			i -= 1
			continue
		if e.bossPart:
			updatePart(e, dt)
			i -= 1
			continue
		if e.state == "dead":
			e.deadT += dt
			if e.deadT > 0.45:
				slimes.remove_at(i)
			i -= 1
			continue
		var dx = P.x - e.x
		var dy = P.y - e.y
		var near = absf(dx) < 120 and absf(dy) < 54 and P.state != "dead"
		var grounded: bool = e.y >= e.surf.y - 0.01 and e.vy >= 0
		var critter: bool = T.get("critter", false)
		if T.get("ai"):
			if crimsonAI(e, T, dt, dx, dy, pb, grounded):
				i -= 1
				continue
		elif critter and e.state in ["idle", "chase", "retreat"]:
			if e.state == "idle":
				if near and e.spawnT <= 0:
					e.aggro = true; e.bang = 0.8; e.state = "chase"
					if absf(dx) < 90:
						Sfx.tone(1500, 0.06, "square", 0.05, 2100)
				else:
					if e.hopCd <= 0:
						e.hopCd = rand(0.8, 2.4)
						e.pause = 1.0 if randf() < 0.35 else 0.0
						if randf() < 0.4:
							e.face *= -1
					e.walk = 0.0 if e.pause > 0 else e.face * 26 * T.speed
			elif e.state == "chase":
				if not near and absf(dx) > 190:
					e.state = "idle"; e.aggro = false
				e.face = int(sgn(dx)) if dx != 0 else e.face
				e.walk = e.face * 62 * T.speed if absf(dx) > 20 else 0.0
				var reach = 120.0 if e.type == "boar" else (70.0 if e.type == "tortoise" else 40.0)
				if grounded and absf(dx) < reach and absf(dy) < 22 and e.atkCd <= 0:
					e.state = "wind"; e.t = 0; e.walk = 0; e.vx = 0
			elif e.state == "retreat":
				e.walk = -e.face * 95
				if e.t > 0.35:
					e.state = "chase"; e.t = 0
		else:
			match e.state:
				"idle":
					if near and e.spawnT <= 0:
						e.aggro = true; e.bang = 0.8
						e.state = "flee" if T.get("flees") else "chase"
						if absf(dx) < 90:
							Sfx.bang()
					elif grounded and e.hopCd <= 0:
						if randf() < 0.35:
							e.face *= -1
						e.vy = -110; e.vx = e.face * 38 * T.speed; e.hopCd = rand(0.8, 2.2); e.sq = -0.3
				"chase":
					if not near and absf(dx) > 190:
						e.state = "idle"; e.aggro = false
					else:
						e.face = int(sgn(dx)) if dx != 0 else e.face
						if grounded and absf(dx) < 42 and absf(dy) < 26 and e.atkCd <= 0:
							e.state = "wind"; e.t = 0; e.vx = 0
						elif grounded and e.hopCd <= 0 and absf(dx) > 16:
							e.vy = -150; e.vx = e.face * 70 * T.speed; e.hopCd = rand(0.25, 0.5); e.sq = -0.3
				"flee":
					e.face = int(-sgn(dx)) if dx != 0 else 1
					if not near and absf(dx) > 200:
						e.state = "idle"; e.aggro = false
					if grounded and e.hopCd <= 0:
						e.vy = -170; e.vx = e.face * 110 * T.speed; e.hopCd = rand(0.1, 0.3)
				"wind":
					if e.type == "boar" and e.t > 0.45:
						e.state = "charge"; e.t = 0; e.hitDone = false
						Sfx.tone(140, 0.25, "sawtooth", 0.08, 90)
					elif e.type == "tortoise" and e.t > 0.5:
						e.state = "spin"; e.t = 0; e.hitT = 0
						Sfx.tone(600, 0.2, "triangle", 0.06, 1200)
					else:
						if e.type == "boar" and randf() < dt * 20:
							_dustPart(e, -e.face * rand(20, 50), rand(-30, -10))
						var wt = (9.0 if e.type == "boar" or e.type == "tortoise" else 0.3) if critter else 0.45
						if e.t > wt:
							e.state = "lunge"; e.t = 0
							e.vx = e.face * (240.0 if critter else 190.0 * minf(1.3, T.speed))
							e.vy = -110.0 if critter else -190.0
							e.hitDone = false
							if critter:
								Sfx.tone(1300, 0.08, "square", 0.06, 700)
							else:
								Sfx.tone(300, 0.12, "sine", 0.1, 520)
				"charge":
					e.vx = e.face * 320
					if randf() < dt * 30:
						part(e.x - e.face * 12, e.y - 1, -e.face * 40, -10, 0.3, "#d8c8a8", 0, 2)
					if not e.hitDone and overlap(sBox(e), pb):
						e.hitDone = true
						hurtPlayer(e, e.atk * 1.2)
					if e.t > 0.75 or e.x <= e.surf.x0 + e.w / 2 + 1 or e.x >= e.surf.x1 - e.w / 2 - 1:
						e.state = "recover"; e.t = 0; e.vx *= 0.3
				"spin":
					e.vx = e.face * 200
					if e.x <= e.surf.x0 + e.w / 2 + 1: e.face = 1
					if e.x >= e.surf.x1 - e.w / 2 - 1: e.face = -1
					e.hitT -= dt
					if e.hitT <= 0 and overlap(sBox(e), pb):
						e.hitT = 0.5
						hurtPlayer(e, e.atk)
					if e.t > 1.2:
						e.state = "recover"; e.t = 0
				"shell":
					e.vx *= exp(-dt * 6)
					if e.t > 1.3:
						e.state = "chase"; e.t = 0
				"lunge":
					if not e.hitDone and overlap(sBox(e), pb):
						e.hitDone = true
						hurtPlayer(e, e.atk)
					if P.state == "dash" and not P.dodged.has(e) and absf(dx) < 34 and absf(dy) < 30:
						P.dodged[e] = true
						perfectDodge()
					if grounded and e.t > 0.15:
						e.state = "recover"; e.t = 0
				"recover":
					if e.t > (0.25 if critter else 0.6):
						e.state = "flee" if T.get("flees") else ("retreat" if e.type == "ferret" else "chase")
						e.t = 0
						e.atkCd = rand(0.9 if critter else 1.2, 1.7 if critter else 2.4)
				"hurt":
					e.stun -= dt
					if e.stun <= 0 and grounded:
						e.state = "flee" if T.get("flees") else "chase"
						e.aggro = true; e.hopCd = 0.3; e.atkCd = maxf(e.atkCd, 0.6)
		# touch damage from awake slimes (classic side-scroller rule)
		if e.aggro and e.state != "hurt" and e.state != "lunge" and overlap(sBox(e), pb) and P.touchCd <= 0:
			P.touchCd = 0.9
			hurtPlayer(e, roundf(e.atk * 0.6))
		# physics on its own surface
		var juggled = e.state == "hurt" and e.juggle > 0
		if e.juggle > 0:
			e.juggle -= dt
		if e.slowT > 0:
			e.slowT -= dt
			e.vx *= exp(-dt * 4)
		if e.burnT > 0:
			e.burnT -= dt
			e.burnTick -= dt
			if e.burnTick <= 0 and e.state != "dead":
				e.burnTick = 0.5
				var d = maxf(1, roundf(PS.atk * 0.08))
				e.hp -= d
				floatText(e.x, e.y - e.h - 6, str(int(d)), "dmg")
				if e.hp <= 0:
					killSlime(e)
			if randf() < dt * 8:
				part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h), 0, -30, 0.4, "#ff8a3a", 0, 1)
		e.vy = minf(MAXFALL, e.vy + GRAV * (0.5 if juggled else 0.75) * dt)
		e.x += e.vx * dt
		e.y += e.vy * dt
		if e.y >= e.surf.y:
			if e.vy > 120 and e.state == "hurt":
				e.vy *= -0.3; e.sq = 0.4
			else:
				if e.vy > 60:
					e.sq = 0.35
				e.vy = 0
			e.y = e.surf.y
			e.vx *= exp(-dt * (5 if e.state == "hurt" else 14))
		if critter and e.y >= e.surf.y - 0.01 and e.state in ["idle", "chase", "retreat"]:
			e.vx = damp(e.vx, e.walk, 12, dt)
		var lo: float = e.surf.x0 + e.w / 2
		var hi: float = e.surf.x1 - e.w / 2
		if e.x < lo:
			e.x = lo; e.vx = absf(e.vx) * 0.3
			if e.state == "idle": e.face = 1
		if e.x > hi:
			e.x = hi; e.vx = -absf(e.vx) * 0.3
			if e.state == "idle": e.face = -1
		e.sq += (0 - e.sq) * minf(1, dt * 10)
		i -= 1
	updateRocks(dt)
	updateVials(dt)
	if inGame and M.get("target", 0) > 0:
		spawnTimer -= dt
		var alive = slimes.filter(func(q): return q.state != "dead").size()
		if alive < M.target and spawnTimer <= 0:
			spawnSlime(false)
			spawnTimer = 2.2


func damageSlime(e, mv: Dictionary, _from = null) -> void:
	if e.bossEye:
		if not e.returning:
			e.returning = true
			Sfx.tone(1200, 0.1, "square", 0.06, 600)
			floatText(e.x, e.y - 14, "Bounced!", "call")
		return
	if e.bossPart:   # the Dreamer's eyes, mouth and tentacles pass the hit on to the Dreamer
		damagePart(e, mv)
		return
	if e.state != "dead" and P.blindT > 0 and randf() < 0.4:   # Inked: a blind swing
		floatText(e.x, e.y - e.h - 6, "Miss", "call")
		return
	if e.bossKind == "dreamer" and not dreamerHitOk(e, mv):
		return
	if mv.get("launcher"):
		P.juggle = e
		P.juggleT = gameTime
	elif P.juggle == e:
		P.juggleT = gameTime   # every hit on the juggled enemy extends the window
	if e.state == "dead":
		return
	var crit = randf() * 100 < PS.crit
	var dmg: float = PS.atk * mv.get("dmg", 1.0) * rand(0.9, 1.1) * 100 / (100 + e.def * 4)
	if crit:
		dmg *= PS.critDmg
	if classId == "tank" and tankWeakHit(e):   # the Diagnostic Helmet: a weak point is a super crit, twice a crit
		dmg *= (1.0 if crit else PS.critDmg) * 2.0
		crit = true
	if save.settings.get("god"):
		dmg *= 40
	if e.state == "shell" or (e.state == "spin" and e.type == "tortoise"):
		dmg *= 0.3
		Sfx.tone(900, 0.06, "square", 0.05, 700)
	if buffOn("enrage"):
		dmg *= 1.25 + skillRank("enrage") * 0.02
	if (e.boss or e.elite) and PS.get("hunt"):
		dmg *= 1 + PS.hunt
	if e.boss:
		dmg *= bossDmgMul(e, mv)   # (Glamrax's mana shield)
	if PS.get("leech") and P.hp > 0:
		P.hp = minf(PS.hp, P.hp + PS.hp * PS.leech)
	dmg = maxf(1, roundf(dmg))
	e.hp -= dmg
	e.flash = 0.1; e.showBar = 3; e.aggro = true
	floatText(e.x, e.y - e.h - 6, str(int(dmg)), "crit" if crit else "dmg")
	var dir: int = (int(sgn(e.x - P.x)) if e.x != P.x else P.face) if mv.get("both") else P.face
	var heavy: float = e.T.get("kb", 0.6 if e.T.get("metal") else 1.0)
	sparks(e.x - dir * 4, e.y - e.h * 0.6, "#ffe14d" if crit else "#ffffff", 10 if crit else 6)
	goo(e.x, e.y - e.h * 0.5, e.T.color, 3)
	hitstop = maxf(hitstop, 0.09 if mv.get("heavy") else 0.045)
	shake = maxf(shake, 5.0 if mv.get("heavy") else (3.0 if crit else 1.5))
	Sfx.hit(crit)
	styleAdd(mv.get("style", 10) * (1.3 if crit else 1.0), mv.get("anim", ""))
	comboHit()
	if e.hp <= 0:
		killSlime(e)
		return
	if e.boss:
		e.hurtFlash = 0.07   # bosses don't flinch or fly
		return
	if e.type == "tortoise" and e.state != "shell" and e.state != "spin" and randf() < 0.4:
		e.state = "shell"; e.t = 0; e.vx = P.face * 60
		return
	e.state = "hurt"
	e.stun = 0.7 if mv.get("heavy") else 0.45
	e.sq = 0.3
	e.vx = dir * mv.get("kb", 0) * heavy
	var airborne: bool = e.y < e.surf.y - 2
	var up: float = mv.get("up", 0)
	if mv.get("air") or (airborne and not up):
		e.vy = up if up else -150.0
		e.juggle = 0.5; e.stun = 0.8
	elif up:
		e.vy = up * heavy
		if up < -250:
			e.juggle = 0.7; e.stun = 1.1


func _drop(kind: String, e, vx: float, vy: float, val := 1, type := "") -> S.Drop:
	var d = S.Drop.new()
	d.kind = kind; d.type = type
	d.x = e.x; d.y = e.y - 8; d.vx = vx; d.vy = vy; d.val = val
	d.surfY = e.surf.y; d.x0 = e.surf.x0 + 4; d.x1 = e.surf.x1 - 4
	d.spin = randf() * 4
	drops.append(d)
	return d


func killSlime(e) -> void:
	if e.boss:
		killBoss(e)
		return
	e.state = "dead"; e.deadT = 0; e.hp = 0
	if e.T.get("ai") == "climb":   # the mountain's monsters: a heavy crunch
		Sfx.slam()
		Sfx.tone(140, 0.3, "triangle", 0.08, 60)
	elif e.T.get("habitat"):   # Abyss monsters: a deep, wet thud
		Sfx.squish()
		Sfx.tone(110, 0.35, "sine", 0.1, 45)
	elif e.T.get("critter"):
		Sfx.tone(1700, 0.1, "square", 0.07, 900)
		Sfx.tone(1200, 0.15, "square", 0.05, 600, 0.08)
	else:
		Sfx.squish()
	goo(e.x, e.y - 6, e.T.color, 16)
	var total = roundi(rint(e.T.coins[0], e.T.coins[1]) * e.coinMul * (5 if e.shiny else 1) * (1 + cardBonus()))
	var pieces = clampi(ceili(total / 5.0), 3, 18 if (e.type == "gold" or e.shiny or e.elite) else 8)
	for k in pieces:
		if total <= 0:
			break
		var v = total if k == pieces - 1 else maxi(1, floori(float(total) / (pieces - k)))
		total -= v
		_drop("coin", e, rand(-70, 70), rand(-260, -160), v)
	var nRes = 0 if e.type == "abyss" else (2 if (randf() < 0.25 or e.T.get("metal")) else 1) * (5 if e.shiny else 1) * (5 if e.elite else 1)
	for k in nRes:
		var d = _drop("res", e, rand(-50, 50), rand(-220, -150), 1, e.type)
		d.spin = 0
	var xm = expScale(e.lv)
	var gained = roundi(mobExp(e) * (5 if e.shiny else 1) * (1 + cardBonus()))
	if e.elite:
		cheer()
		banner("Elite defeated!", "%s · huge rewards" % e.T.name)
		shake = 6
	if e.type == "abyss":
		var n = rint(1, 3) if randf() < 0.6 else 0   # they're five levels above you now: more coins
		for k in n:
			_drop("abyss", e, rand(-60, 60), rand(-240, -160))
	rollCards(e)
	gainExp(gained)
	var xs = ""
	if xm != 1:
		xs = " ×" + String.num(xm, 2).rstrip("0").rstrip(".")
	floatText(e.x, e.y - e.h - 16, "+%d EXP%s" % [gained, xs], "exp")
	CH().kills += 1
	recordKill(e)
	if e.shiny:
		cheer()
		banner("Shiny defeated!", "%s · 5× rewards" % e.T.name)
		var cols = ["#fff6b0", "#ffffff", "#ff9ecf", "#9fe6ff"]
		for k in 24:
			part(e.x, e.y - 10, rand(-120, 120), rand(-220, -60), rand(0.5, 1), cols[k % 4], 300, 2)
	for q in save.quests:
		if q.type == "kill" and not q.done and (q.target == "any" or q.target == e.type):
			q.have += 1
			if q.have >= q.need:
				q.done = true
				toast("Quest complete: %s. Claim it in the menu." % q.title)
				Sfx.buy()
	styleAdd(40.0 if e.T.get("metal") else 16.0, "kill")
	saveDirty = true


# ================================================================ the Crimson Wastes

func crimsonAI(e, T: Dictionary, dt: float, dx: float, dy: float, pb: Dictionary, grounded: bool) -> bool:
	var ai: String = T.ai
	if ai == "abyss":
		return abyssAI(e, T, dt, dx, dy, pb)
	if ai == "climb":
		return climbAI(e, T, dt, dx, dy, pb)
	var near = absf(dx) < 150 and absf(dy) < 90 and P.state != "dead"
	var sp: float = T.speed
	var hit = func(mul: float, knock := false):
		if not e.hitDone and overlap(sBox(e), pb):
			e.hitDone = true
			if knock and P.state != "knocked":
				var r: S.Mob = e.clone()
				r.raid = true
				hurtPlayer(r, e.atk * mul)
			else:
				hurtPlayer(e, e.atk * mul)
	if e.state == "idle" and near and e.spawnT <= 0:
		e.aggro = true; e.bang = 0.8; e.state = "chase"
	if e.state == "chase" and not near and absf(dx) > 260:
		e.state = "idle"; e.aggro = false
	# ---------------- flyers: eyes and heads drift, wind up, then dive at you
	if T.get("fly"):
		if e.state == "idle":
			var tx: float = e.homeX + sin(e.t * 0.6 + e.id) * 40
			var ty: float = e.homeY + sin(e.t * 1.3 + e.id) * 8
			e.vx = damp(e.vx, (tx - e.x) * 1.2, 3, dt)
			e.vy = damp(e.vy, (ty - e.y) * 1.2, 3, dt)
			e.face = 1 if e.vx >= 0 else -1
		elif e.state == "chase":
			e.face = int(sgn(dx)) if dx != 0 else 1
			var tx = P.x - e.face * 46
			var ty = P.y - 34 + sin(e.t * 2) * 8
			e.vx = damp(e.vx, clampf((tx - e.x) * 2, -90 * sp, 90 * sp), 3, dt)
			e.vy = damp(e.vy, clampf((ty - e.y) * 2, -80, 80), 3, dt)
			if e.atkCd <= 0 and absf(dx) < 110 and absf(dy) < 80:
				e.state = "wind"; e.t = 0
		elif e.state == "wind":
			e.vx *= exp(-dt * 8); e.vy *= exp(-dt * 8)
			e.x += sin(e.t * 60) * 0.4
			if e.t > 0.45:
				var a = atan2((P.y - 20) - (e.y - e.h / 2), P.x - e.x)
				e.vx = cos(a) * 250; e.vy = sin(a) * 250
				e.state = "lunge"; e.t = 0; e.hitDone = false
				var head = e.type == "head"
				Sfx.tone(160 if head else 900, 0.15, "sawtooth", 0.05, 90 if head else 500)
		elif e.state == "lunge":
			hit.call(1.0)
			if e.t > 0.5:
				e.state = "recover"; e.t = 0
		elif e.state == "recover":
			e.vx *= exp(-dt * 4)
			e.vy = damp(e.vy, -40, 3, dt)
			if e.t > 0.6:
				e.state = "chase"; e.t = 0; e.atkCd = rand(1.2, 2.2)
		elif e.state == "hurt":
			e.vx *= exp(-dt * 3); e.vy *= exp(-dt * 3)
			e.stun -= dt
			if e.stun <= 0:
				e.state = "chase"; e.aggro = true
		if e.aggro and e.state != "lunge" and e.state != "hurt" and overlap(sBox(e), pb) and P.touchCd <= 0:
			P.touchCd = 0.9
			hurtPlayer(e, roundf(e.atk * 0.5))
		e.x = clampf(e.x + e.vx * dt, 20, M.w - 20)
		e.y = clampf(e.y + e.vy * dt, 40, M.floorY - 4)
		if e.slowT > 0:
			e.slowT -= dt
			e.vx *= exp(-dt * 4)
		var fl = findSurf(func(s): return s.floor)
		if fl != null:
			e.surf = fl
		return true
	# ---------------- ground walkers
	if e.state == "idle":
		if e.hopCd <= 0:
			e.hopCd = rand(1, 2.5)
			e.face = -1 if randf() < 0.5 else 1
			e.pause = 1.0 if randf() < 0.3 else 0.0
		e.walk = 0.0 if e.pause > 0 else e.face * 22 * sp
	if e.state == "chase":
		e.face = int(sgn(dx)) if dx != 0 else e.face
		e.walk = e.face * 58 * sp if absf(dx) > 18 else 0.0
		if e.partner != null and e.partner.state != "dead":
			# step, step: a pair of feet keeping pace
			var first = null
			for q in slimes:
				if q.partner == e:
					first = q
					break
			e.walk *= 1 + sin(e.t * 9 + (PI if e.partner == first else 0.0)) * 0.6
		var reach = 70.0
		match ai:
			"knight": reach = 44.0 if absf(dx) < 44 else 150.0
			"crusader": reach = 170.0
			"roller": reach = 120.0
			"feet": reach = 110.0
		if grounded and absf(dx) < reach and absf(dy) < 30 and e.atkCd <= 0:
			e.state = "wind"; e.t = 0; e.walk = 0; e.vx = 0
			if ai == "knight":
				e.move = "swing" if absf(dx) < 50 else "bash"
			elif ai == "crusader":
				e.move = "cleave" if absf(dx) < 64 else "leap"
			else:
				e.move = ai
	var windT: float = {"swing": 0.35, "bash": 0.45, "cleave": 0.6, "leap": 0.4, "crawler": 0.35, "feet": 0.3, "roller": 0.45}.get(e.move, 0.4)
	match e.state:
		"wind":
			e.vx *= exp(-dt * 10)
			if e.t > windT:
				e.state = "act"; e.t = 0; e.hitDone = false
				e.face = int(sgn(dx)) if dx != 0 else e.face
				match e.move:
					"crawler":
						# leap onto you, not past you
						if e.type == "hand":
							e.vy = -220; e.vx = clampf(dx * 2.6, -200, 200)
						else:
							e.vx = e.face * 150
						Sfx.tone(300, 0.1, "square", 0.04, 180)
					"feet":
						e.vy = -340; e.vx = clampf(dx * 1.6, -200, 200)
						Sfx.tone(200, 0.15, "triangle", 0.05, 400)
					"roller":
						e.vx = e.face * 260
						Sfx.tone(500, 0.2, "sawtooth", 0.04, 300)
					"bash":
						e.vx = e.face * 320
						Sfx.tone(140, 0.2, "sawtooth", 0.07, 90)
					"leap":
						e.vy = -380; e.vx = clampf(dx * 1.5, -230, 230)
						Sfx.whoosh(1, true)
					"swing", "cleave":
						Sfx.whoosh(0.6 if e.move == "cleave" else 1.1, true)
		"act":
			var m: String = e.move
			if m == "crawler":
				if e.type == "hand" and e.shiny and not e.hitDone and overlap(sBox(e), pb) and P.grabbed == null and P.state != "dead":
					e.hitDone = true
					grabPlayer(e)
				else:
					hit.call(1.1 if e.type == "torso" else 1.0)
				if (grounded and e.t > 0.2) if e.type == "hand" else e.t > 0.3:
					if e.state != "grab":
						e.state = "recover"; e.t = 0
			if m == "feet":
				if grounded and e.t > 0.15:
					if absf(P.x - e.x) < 22 and absf(P.y - e.y) < 20:
						hurtPlayer(e, e.atk * 1.2)
					dust(e.x, e.y, 6)
					shake = maxf(shake, 2)
					Sfx.land()
					e.state = "recover"; e.t = 0
			if m == "roller":
				e.vx = e.face * 260
				if e.x <= e.surf.x0 + e.w / 2 + 1: e.face = 1
				if e.x >= e.surf.x1 - e.w / 2 - 1: e.face = -1
				e.hitT -= dt
				if e.hitT <= 0 and overlap(sBox(e), pb):
					e.hitT = 0.5
					hurtPlayer(e, e.atk)
				if e.t > 1.1:
					e.state = "recover"; e.t = 0
			if m == "swing" or m == "cleave":
				var reach = 70.0 if m == "cleave" else 42.0
				var hb = hbox(e.x, e.x + reach, e.y - 44, e.y) if e.face > 0 else hbox(e.x - reach, e.x, e.y - 44, e.y)
				if e.t > 0.06 and e.t < 0.3 and not e.hitDone and overlap(hb, pb):
					e.hitDone = true
					hurtPlayer(e, e.atk * (1.6 if m == "cleave" else 1.0))
				if e.t > (0.6 if m == "cleave" else 0.4):
					e.state = "recover"; e.t = 0
			if m == "bash":
				e.vx = e.face * 320
				hit.call(0.9, true)
				if e.t > 0.4 or e.hitDone:
					e.state = "recover"; e.t = 0; e.vx *= 0.3
			if m == "leap":
				if grounded and e.t > 0.15:
					var hb = hbox(e.x - 40, e.x + 40, e.y - 30, e.y + 2)
					if overlap(hb, pb):
						hurtPlayer(e, e.atk * 1.4)
					dust(e.x, e.y, 14)
					shake = maxf(shake, 5)
					Sfx.slam()
					e.state = "recover"; e.t = 0
		"recover":
			e.vx *= exp(-dt * 6)
			if e.t > 0.5:
				e.state = "chase"; e.t = 0; e.atkCd = rand(0.9, 1.8)
		"grab":
			e.x = P.x + e.face * 6
			e.y = P.y - 10
			e.vx = 0; e.vy = 0
		"hurt":
			e.stun -= dt
			if e.stun <= 0 and grounded:
				e.state = "chase"; e.aggro = true; e.atkCd = maxf(e.atkCd, 0.5)
	if e.state == "grab":
		return true
	if e.aggro and not (e.state in ["hurt", "act"]) and overlap(sBox(e), pb) and P.touchCd <= 0:
		P.touchCd = 0.9
		hurtPlayer(e, roundf(e.atk * 0.6))
	return false
