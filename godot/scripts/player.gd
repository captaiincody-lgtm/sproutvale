extends "res://scripts/world.gd"
## Sproutvale, part 3: the hero. Input buffering, movement, jumps, ropes, swimming, dodges,
## blocking, Rock's sword combos, getting hurt, knockdowns, grabs, bleeding, potions and lightning.
## The archer's, Remy's and Jojo's attack inputs live in skills.gd (archerInput, mageInput, summonerInput).

const AIR_LIFT_MAX := 9


func nFrames(anim: String) -> int:
	return int(ANIM_BY_ID.get(anim, ANIM_BY_ID.idle).frames)


func setAnim(a: String) -> void:
	if P.anim != a:
		P.anim = a
		P.animT = 0.0


func frameOf(anim: String, t: float, loop: bool) -> int:
	var A: Dictionary = ANIM_BY_ID.get(anim, ANIM_BY_ID.idle)
	var n: int = A.frames
	var f = floori(t * A.fps)
	return f % n if loop else mini(f, n - 1)


func startMove(id: String) -> void:
	var mv: Dictionary = MOVES[id]
	P.state = "attack"
	P.move = mv
	P.moveId = id
	P.moveT = 0.0
	P.lastFrame = -1
	P.hitSet.clear()
	P.queued = false
	P.queuedHeavy = false
	setAnim(mv.anim)
	var pitch: float = 0.7 if mv.get("heavy") else {"slash": 1.0, "rising": 1.2, "thrust": 1.35, "spin": 0.9, "whirl": 0.85, "aegis": 0.8, "air": 1.1, "air2": 1.25, "air3": 1.0}.get(P.moveId, 1.0)
	Sfx.whoosh(pitch, mv.get("heavy", false))
	if not mv.get("air"):
		P.vx = P.face * mv.get("lunge", 0)


func sBox(e) -> Dictionary:
	if e.boss:
		return bossBox(e)
	return hbox(e.x - e.w / 2, e.x + e.w / 2, e.y - e.h, e.y)


func findSurf(f: Callable):
	for s in surfaces:
		if f.call(s):
			return s
	return null


# ---------------- potions: two recharging flasks on H and J

func potState() -> Dictionary:
	if P.pots == null:
		P.pots = {"hp": {"n": POT.max, "t": 0.0}, "sp": {"n": POT.max, "t": 0.0}}
	return P.pots


func updatePotions(dt: float) -> void:
	var St = potState()
	for k in ["hp", "sp"]:
		var p: Dictionary = St[k]
		if p.n < POT.max:
			p.t += dt
			if p.t >= POT.recharge:
				p.t = 0.0
				p.n += 1
		else:
			p.t = 0.0


func usePotion(k: String) -> void:
	var p: Dictionary = potState()[k]
	if P.state == "dead":
		return
	if p.n <= 0:
		floatText(P.x, P.y - 56, "Empty — recharging", "call")
		return
	if k == "hp":
		if P.hp >= PS.hp:
			floatText(P.x, P.y - 56, "Already at full health", "call")
			return
		var h = roundi(PS.hp * 0.4)
		P.hp = minf(PS.hp, P.hp + h)
		floatText(P.x, P.y - 52, "+%d" % h, "exp")
		P.regenBoost = 3.0
	else:
		if P.en >= PS.enMax:
			floatText(P.x, P.y - 56, "%s is full" % CLASSES[classId].resource, "call")
			return
		var r = roundi(PS.enMax * 0.6)
		P.en = minf(PS.enMax, P.en + r)
		floatText(P.x, P.y - 52, "+%d %s" % [r, CLASSES[classId].res], "call")
	p.n -= 1
	Sfx.play("potion")
	for i in 14:
		part(P.x + rand(-10, 10), P.y - rand(0, 40), 0, -rand(20, 60), 0.6, "#ff6a7a" if k == "hp" else "#7ad8ff")


# ---------------- storms: a rare lightning strike leaves you Shocked (faster everything for a minute)

func updateLightning(dt: float) -> void:
	if M.get("indoor") or M.theme == "crimson" or World.storm < 0.5 or P.state == "dead" or not P.grounded:
		return
	P.boltCd -= dt
	if P.boltCd > 0:
		return
	if randf() < dt / 120:   # about once every couple of minutes in a storm
		P.boltCd = 30.0
		fx.append({"type": "strike", "x": P.x, "y": P.y, "t": 0.0, "life": 0.45})
		shake = 12
		Sfx.thunder()
		if not save.settings.god:
			var d = mini(int(P.hp) - 1, roundi(PS.hp * 0.08))
			if d > 0:
				P.hp -= d
				floatText(P.x, P.y - 46, str(d), "hurt")
		Buffs.shocked = 60.0
		PS = calcStats()
		banner("SHOCKED!", "Struck by lightning: +100% attack and movement speed for 60s")
		Sfx.rankUp(8)


# ================================================================ getting hurt

func defMul(lv = null) -> float:
	var Kd = 30 + 4.5 * (lv if lv else CH().level)
	return 1 - minf(0.75, PS.def / (PS.def + Kd)) - ((0.15 + skillRank("scales") * 0.01) if buffOn("scales") else 0.0)


## `src` is a monster, or a Dictionary like {x, lv, boss, raid, noCrit} for hazards (rocks, rain, puddles…)
func hurtPlayer(src, dmg: float) -> void:
	if save.settings.god:   # god mode (testing)
		P.iframes = maxf(P.iframes, 0.3)
		return
	if P.state == "dead":
		return
	if P.state == "dash" or P.iframes > 0:
		if P.state == "dash" and not P.dodged.has(src):
			P.dodged[src] = true
			perfectDodge()
		return
	var sx: float = src.get("x")
	var fromFront = sgn(sx - P.x) == P.face or absf(sx - P.x) < 4
	if P.state == "block" and fromFront:
		if gameTime - P.blockT < 0.2 + skillRank("shieldMastery") * 0.01:
			Sfx.parry()
			slowmo = 0.4; hitstop = 0.08; shake = 4
			styleAdd(45, "parry")
			comboHit()
			if src is S.Mob:
				src.state = "hurt"; src.stun = 1.4; src.vx = P.face * 200; src.vy = -200; src.juggle = 0.4; src.flash = 0.15
			floatText(P.x, P.y - 52, "Parry!", "call")
			sparks(P.x + P.face * 12, P.y - 26, "#8ff0ff", 14)
			return
		var chip = maxi(1, roundi(dmg * 0.15 * (1 - skillRank("shieldMastery") * 0.05)))
		P.hp -= chip
		Sfx.block()
		floatText(P.x, P.y - 48, str(chip), "hurt")
		P.vx = -P.face * 90
		sparks(P.x + P.face * 10, P.y - 24, "#ffffff", 6)
		if P.hp <= 0:
			killPlayer()
		return
	var dr = (1 - (0.1 + skillRank("guardian") * 0.01)) if buffOn("guardian") else 1.0
	var ecrit = false if src.get("noCrit") else randf() < (0.2 if src.get("boss") else 0.12)
	var d = maxi(1, roundi(dmg * dr * (1.5 if ecrit else 1.0) * defMul(src.get("lv")) * rand(0.9, 1.1)))
	if buffOn("manaShield") and P.en > 0:
		var pt = minf(P.en, roundi(d * (0.25 + skillRank("manaShield") * 0.02)))
		P.en -= pt
		d -= int(pt)
	P.hp -= d
	P.lastHurt = gameTime
	floatText(P.x, P.y - 48, ("%d!" % d) if ecrit else str(d), "hurt")
	Sfx.hurt()
	flashVig()
	shake = 4 if ecrit else 2
	if P.state == "climb" and not ecrit and not src.get("raid"):   # ordinary hits don't shake you off a rope — only critical ones do
		P.iframes = 0.8
		P.flash = 0.1
		if P.hp <= 0:
			killPlayer()
		return
	if ecrit and P.state == "climb":
		floatText(P.x, P.y - 58, "Knocked off!", "call")
	if Style.hits:
		endCombo(true)
	Style.pts *= 0.4
	Style.rank = rankOf(Style.pts)
	if src.get("raid") and P.hp > 0:   # raid attacks throw you off your feet
		knockDown(src)
		return
	if buffOn("guardian"):   # no knockback while guarded
		P.iframes = 0.8
		P.flash = 0.1
		flinch()
		if P.hp <= 0:
			killPlayer()
		return
	P.state = "hurt"
	P.hurtT = 0.0
	P.iframes = 1.1
	P.vx = (sgn(P.x - sx) if P.x != sx else float(-P.face)) * 130
	P.vy = -150
	P.grounded = false
	P.surf = null
	P.rope = null
	if P.hp <= 0:
		killPlayer()


func killPlayer() -> void:
	P.hp = 0
	P.poison = null
	P.state = "dead"
	P.deadT = 0.0
	setAnim("down")
	var lost = floori(CH().exp * 0.1)
	CH().exp -= lost
	banner("Knocked out!", ("Lost %d EXP. Back to the start in a moment." % lost) if lost else "Back to the start in a moment.")


func perfectDodge() -> void:
	slowmo = 0.45
	styleAdd(40, "dodge")
	comboHit()
	floatText(P.x, P.y - 52, "Perfect dodge!", "call")
	Sfx.play("dodge_perfect")


func cheer() -> void:
	P.cheerQ = true


func flinch() -> void:
	if P.state in ["move", "block", "prone"] and P.grounded:
		P.state = "flinch"
		P.hurtT = 0.0
		setAnim("hurt")


func knockDown(src) -> void:
	P.state = "knocked"
	P.kdPhase = "air"
	P.kdT = 0.0
	P.iframes = 1.6
	P.rope = null
	P.grounded = false
	P.surf = null
	var sx: float = src.get("x")
	var dir: int = int(sgn(P.x - sx)) if P.x != sx else -P.face
	P.face = -dir
	P.vx = dir * 170
	P.vy = -290
	P.kdBack = randf() < 0.6
	setAnim("down" if P.kdBack else "prone")
	shake = 6
	Sfx.slam()
	if P.hp <= 0:
		killPlayer()


## each air attack used to hold you up; now only the first three combos' worth (9) per jump do
func airLift() -> bool:
	P.airAtk += 1
	return P.airAtk <= AIR_LIFT_MAX


func startClimb(r: Dictionary, fromTop: bool) -> void:
	P.state = "climb"
	P.rope = r
	P.x = r.x
	P.vx = 0; P.vy = 0
	P.grounded = false
	P.surf = null
	P.jumps = 0
	if fromTop:
		P.y += 4
	setAnim("climb")
	Sfx.rope()


func climbOff(dir: int) -> void:
	P.lastJumpT = gameTime
	P.state = "move"
	P.rope = null
	P.vy = -240
	P.vx = dir * 120
	P.face = dir
	P.jumps = 1
	Sfx.jump()


# ---------------- grabs (a shiny Crawling Hand) and bleeding (the Crimson Rain)

func grabPlayer(e) -> void:
	P.grabbed = {"e": e, "need": rint(4, 6), "tick": 0.6}
	e.state = "grab"
	e.face = int(sgn(e.x - P.x)) if e.x != P.x else 1
	P.state = "move"
	P.vx = 0
	floatText(P.x, P.y - 60, "Grabbed! Mash Z (%d)" % P.grabbed.need, "call")
	Sfx.tone(120, 0.3, "sawtooth", 0.08, 80)


func updateGrab(dt: float, pressedAtk: bool) -> bool:
	var G = P.grabbed
	if G == null:
		return false
	if G.e.state == "dead" or P.state == "dead":
		P.grabbed = null
		return false
	P.vx = 0
	P.vy = minf(P.vy, 0)
	G.tick -= dt
	if G.tick <= 0:
		G.tick = 0.7
		var d = maxi(1, roundi(G.e.atk * 0.35 * defMul(G.e.lv)))
		P.hp -= d
		floatText(P.x, P.y - 46, str(d), "hurt")
		flashVig()
		Sfx.tone(90, 0.15, "square", 0.06, 60)
		if P.hp <= 0:
			P.grabbed = null
			killPlayer()
			return true
	if pressedAtk:
		G.need -= 1
		shake = 2
		Sfx.hit()
		for k in 5:
			part(P.x + rand(-8, 8), P.y - rand(10, 30), rand(-60, 60), rand(-80, -20), 0.3, "#ffffff", 200, 1)
		if G.need <= 0:
			var e = G.e
			e.state = "hurt"
			e.stun = 0.8
			e.vx = (sgn(e.x - P.x) if e.x != P.x else 1.0) * 220
			e.vy = -160
			e.atkCd = 2.5
			P.grabbed = null
			P.iframes = 1.0
			floatText(P.x, P.y - 60, "Broke free!", "call")
			return true
		floatText(P.x, P.y - 60, "Mash Z (%d)" % G.need, "call")
	return true


func bleedPlayer(dps: float, dur: float) -> void:
	var fresh: bool = not (P.bleed != null and P.bleed.t > 0)
	var old_t: float = P.bleed.t if P.bleed != null else 0.0
	var old_dps: float = P.bleed.dps if P.bleed != null and P.bleed.t > 0 else 0.0
	var old_tick: float = P.bleed.tick if P.bleed != null else 0.5
	P.bleed = {"t": maxf(dur, old_t), "dps": minf(dps * 3, old_dps + dps * (1.0 if fresh else 0.15)), "tick": old_tick if old_tick else 0.5}
	if fresh:
		floatText(P.x, P.y - 58, "Bleeding!", "call")


func updateBleed(dt: float) -> void:
	if P.bleed == null or P.bleed.t <= 0 or P.state == "dead":
		return
	P.bleed.t -= dt
	P.bleed.tick -= dt
	if P.bleed.tick <= 0:
		P.bleed.tick = 0.5
		var d = maxi(1, roundi(P.bleed.dps * 0.5))
		P.hp -= d
		floatText(P.x + rand(-6, 6), P.y - 44, str(d), "hurt")
		if P.hp <= 0:
			killPlayer()
	if randf() < dt * 12:
		part(P.x + rand(-6, 6), P.y - rand(6, 34), 0, rand(20, 60), 0.5, "#c0102a", 300, 1, P.y)


func poisonPlayer(atk: float, dur := 4.0) -> void:
	if save.settings.god:   # god mode clears poison every frame, so skip it (the prototype re-announced it each frame)
		return
	var fresh: bool = not (P.poison != null and P.poison.t > 0)
	P.poison = {"t": maxf(dur, P.poison.t if P.poison != null else 0.0), "dps": atk * 0.12, "tick": 0.5 if fresh else P.poison.get("tick", 0.5)}
	if fresh:
		floatText(P.x, P.y - 58, "Poisoned!", "call")


# ================================================================ the main player update

func updatePlayer(dt: float) -> void:
	updateBleed(dt)
	updatePotions(dt)
	updateLightning(dt)
	if pressed.get("h"):
		usePotion("hp")
	if pressed.get("j"):
		usePotion("sp")
	if P.regenBoost > 0:
		P.regenBoost -= dt
		P.hp = minf(PS.hp, P.hp + PS.hp * 0.035 * dt)
	if buffOn("shocked") and randf() < dt * 14:
		part(P.x + rand(-9, 9), P.y - rand(4, 44), rand(-20, 20), rand(-20, 20), 0.18, "#fff6a8" if randf() < 0.5 else "#9fe6ff")
	if P.grabbed != null:
		var pa: bool = pressed.get("z", false) or pressed.get("x", false)
		pressed.clear()
		if updateGrab(dt, pa):
			if P.grounded:
				P.vx = 0
	var aspd: float = PS.aspd
	P.iframes -= dt; P.touchCd -= dt; P.dropT -= dt; P.flash -= dt; P.landT -= dt
	var left: bool = K.get("arrowleft", false)
	var right: bool = K.get("arrowright", false)
	var up: bool = K.get("arrowup", false)
	var down: bool = K.get("arrowdown", false)
	var dirIn: int = (1 if right else 0) - (1 if left else 0)
	if dirIn and P.grounded:
		P.runT += dt
	elif not dirIn:
		P.runT = 0.0
	for i in range(speedLines.size() - 1, -1, -1):
		var l = speedLines[i]
		l.t += dt
		l.x += l.vx * dt
		if l.t > l.life:
			speedLines.remove_at(i)
	if P.state == "dead":
		P.deadT += dt
		P.animT += dt
		if P.deadT > 2.6:
			PS = calcStats()
			P.hp = PS.hp
			P.iframes = 1.5
			loadMap(save.settings.map)
		return
	# --- input buffering & timing windows ---
	# presses are remembered briefly so slightly-early inputs still land (jump 0.14s, attacks 0.22s),
	# and a short coyote window lets you jump just after running off a ledge
	var now = gameTime
	var B: Dictionary = P.buf
	for k in SLOT_KEYS:
		if pressed.get(k) and CH().binds.get(k) and P.state != "knocked":
			useSkill(CH().binds[k])
	if pressed.get(" "):
		B.jump = now
	if pressed.get("z"):
		B.atk = now
	if pressed.get("x"):
		B.heavy = now
	if pressed.get("c"):
		B.dash = now
	if P.grounded or P.state == "climb" or inWater():   # Arrow Dive charges and air-attack lift refill on landing
		P.coyote = now
		P.diveN = 0
		P.airAtk = 0
	var locked = P.state == "knocked"   # no inputs while flying/lying after a raid hit
	var has = func(k: String, w: float) -> bool: return not locked and B.get(k) != null and now - B[k] <= w
	var use = func(k: String) -> void: B[k] = null
	if dblTap != "":
		if dirIn:
			P.runT = 1.0
		dblTap = ""
	var wet = inWater()
	var rNear = ropeAt()
	var atRopeTop: bool = rNear != null and P.grounded and absf(P.y - rNear.y0) < 2
	var climbable: bool = rNear != null and not atRopeTop
	# ↑ is contextual: pedestal > note > obelisk > portal > rope > climb-off > jump (a jump from ↑ waits 60ms in case Z follows for a rising slash)
	if pressed.get("arrowup") and not locked:
		var pt = portalAt() if P.grounded else null
		var ob = obeliskAt() if P.grounded else null
		var nt = noteAt() if P.grounded else null
		var pd = pedestalAt() if P.grounded else null
		if pd != null:
			summonFromPedestal()
		elif nt != null:
			thought = {"text": nt.text, "t": 0.0}
			Sfx.play("note")
		elif ob != null:
			activateObelisk(ob)
		elif pt != null:
			travel(pt)
		elif P.state == "climb":
			if dirIn:
				climbOff(dirIn)
		elif climbable and P.state in ["move", "dash", "crouch"]:
			startClimb(rNear, false)
		else:
			B.upJump = now
	if P.state == "climb" and up and dirIn and (pressed.get("arrowleft") or pressed.get("arrowright")):
		climbOff(dirIn)
	if up and climbable and P.state == "move" and not P.grounded and now - P.lastJumpT > 0.25:   # grab ropes mid-air by holding ↑
		startClimb(rNear, false)
	var risingIntent = up
	if B.get("upJump") != null:
		if has.call("atk", 0.1):   # ↑ + Z together → rising slash (handled below)
			B.upJump = null
			risingIntent = true
		elif now - B.upJump >= 0.06:
			B.jump = B.upJump
			B.upJump = null
	var canAct: bool = P.state == "move" or P.state == "block" or P.state == "crouch" or (P.state == "dash" and P.dashT > 0.16) or (P.state == "attack" and frameOf(P.anim, P.moveT * aspd, false) >= P.move.cancel)
	var canCancel = P.state != "hurt" and P.state != "dead"
	if down and P.grounded and (P.state == "move" or P.state == "crouch") and atRopeTop and not has.call("jump", 0.14):
		startClimb(rNear, true)
	# jumping / swimming
	if has.call("jump", 0.14) and canCancel:
		if wet and P.state != "climb":
			use.call("jump")
			var Wp: Dictionary = M.pond
			var headOut: bool = P.y - 36 < Wp.surface + 2
			var nearBank: bool = P.x < Wp.x0 + 24 or P.x > Wp.x1 - 24
			if headOut and (nearBank or P.y < Wp.surface + 16):
				P.vy = -340; P.grounded = false; P.surf = null; P.state = "move"
				splash(P.x, 0.8)
				Sfx.jump()
			else:
				P.vy = -235; P.grounded = false; P.surf = null; P.state = "move"
				Sfx.swim()
				for i in 3:
					part(P.x + P.face * 8, P.y - 30, rand(-10, 10), rand(-40, -20), 0.6, "rgba(220,240,255,0.8)", -20, 1)
		elif P.state == "climb":
			if dirIn:
				use.call("jump")
				climbOff(dirIn)
		elif (P.grounded or P.state == "crouch") and down and P.surf != null and not P.surf.floor:
			use.call("jump")
			P.dropT = 0.28; P.grounded = false; P.surf = null; P.vy = 40; P.state = "move"
		elif P.grounded or (now - P.coyote < 0.1 and P.jumps == 0 and P.vy >= 0):
			use.call("jump")
			var fromSlide = P.state == "slide"
			P.vy = -335; P.lastJumpT = now; P.grounded = false; P.surf = null; P.jumps = 1; P.state = "move"
			if fromSlide:
				P.vx *= 1.15
			Sfx.jump()
			dust(P.x, P.y, 4)
		elif classId == "archer" and P.jumps == 2 and P.state != "plunge":
			use.call("jump")
			P.jumps = 3; P.vy = -250; P.vx = (dirIn if dirIn else P.face) * 230; P.face = dirIn if dirIn else P.face; P.state = "move"; P.flipT = 0
			setAnim("flip")
			Sfx.djump()
			styleAdd(5, "triple")
			for i in 8:
				part(P.x, P.y - 4, rand(-60, 60), rand(20, 60), 0.4, "#e2ffd8")
		elif P.jumps == 2 and skillRank("airLeap") and (dirIn or up) and P.state != "plunge" and P.en >= SKILL.airLeap.cost:
			use.call("jump")
			var r = skillRank("airLeap")
			P.jumps = 3; P.en -= SKILL.airLeap.cost; P.state = "move"; P.flipT = 0
			setAnim("flip")
			if up and not dirIn:
				P.vy = -(430 + r * 14)
				P.vx *= 0.5
			else:
				P.face = dirIn if dirIn else P.face
				P.vx = P.face * (390 + r * 16)
				P.vy = -165
			for i in 16:
				part(P.x + rand(-6, 6), P.y - rand(6, 34), -P.vx * rand(0.1, 0.3), -P.vy * rand(0.05, 0.2), rand(0.3, 0.55), "#bff3ff" if i % 2 else "#ffffff", 0, 2)
			Sfx.whoosh(1.4, false)
			Sfx.djump()
			styleAdd(10, "leap")
		elif P.jumps < 2 and P.state != "plunge":
			use.call("jump")
			P.jumps = 2; P.vy = -240; P.vx = (dirIn if dirIn else P.face) * 215; P.face = dirIn if dirIn else P.face; P.state = "move"; P.flipT = 0
			setAnim("flip")
			Sfx.djump()
			styleAdd(4, "flash")
	# dodge
	if classId == "mage" and has.call("dash", 0.12) and canCancel and P.state != "climb":
		use.call("dash")
		blink(dirIn, up, down)
	elif has.call("dash", 0.12) and canCancel and P.state != "climb" and P.state != "plunge" and (P.grounded or P.airDash == 0):
		use.call("dash")
		if not P.grounded:
			P.airDash = 1
		P.state = "dash"; P.dashT = 0.0; P.face = dirIn if dirIn else P.face; P.vx = P.face * 320
		if not P.grounded:
			P.vy = minf(P.vy, -40)
		P.iframes = 0.26
		P.dodged.clear()
		setAnim("dash")
		Sfx.dodge()
	# attacks (↑ held turns the opener into a rising slash / rising cut)
	if classId == "summoner":
		summonerInput(has, use, dirIn, up, down, wet, canAct, risingIntent)
	elif classId == "mage":
		mageInput(has, use, dirIn, up, down, wet, canAct, risingIntent)
	elif classId == "archer":
		archerInput(has, use, dirIn, up, down, wet, canAct, risingIntent)
	else:
		if has.call("atk", 0.22) and (P.state == "prone" or (P.state == "attack" and P.moveId == "stab" and frameOf(P.anim, P.moveT * aspd, false) >= 2)):
			use.call("atk")
			if dirIn:
				P.face = dirIn
			startMove("stab")
		if has.call("atk", 0.22) and P.state != "climb" and P.state != "hurt" and P.state != "plunge" and (P.state != "dash" or P.dashT > 0.16):
			if not P.grounded and not wet:
				if P.state == "attack" and AIR_CHAIN.has(P.moveId):
					P.queued = true
					use.call("atk")
				elif P.state != "attack":
					use.call("atk")
					if dirIn:
						P.face = dirIn
					startMove("air2" if risingIntent else "air")
					if airLift():
						P.vy = minf(P.vy, -60)
			elif P.state == "attack" and CHAIN.has(P.moveId):
				P.queued = true
				use.call("atk")
			elif canAct and (P.grounded or wet):
				use.call("atk")
				B.upJump = null
				if dirIn:
					P.face = dirIn
				var pause = now - P.chainEndT
				if risingIntent:
					startMove("rising")
				elif P.lastChain == 1 and pause > 0.25 and pause < 1.0:
					startMove("whirl")
					styleAdd(18, "pause")
				else:
					startMove("slash")
		if has.call("heavy", 0.2) and P.state != "climb" and P.state != "hurt" and P.state != "plunge":
			if not P.grounded and not wet and P.state != "dash":
				use.call("heavy")
				startPlunge()
			elif P.grounded and P.state == "attack" and CHAIN.has(P.moveId) and CHAIN.find(P.moveId) <= 2:
				use.call("heavy")
				P.queuedHeavy = true
			elif P.grounded and canAct:
				use.call("heavy")
				if dirIn:
					P.face = dirIn
				startMove("heavy")
	# ↓: slide out of a run, otherwise crouch into a low guard; Shift is a standing guard
	if down and P.grounded and not wet and not atRopeTop and P.state == "move":
		if absf(P.vx) > 95:
			P.state = "slide"; P.slideT = 0.0
			P.vx = P.face * maxf(330 if classId == "archer" else 250, absf(P.vx) + (140 if classId == "archer" else 90))
			P.hitSet.clear()
			setAnim("slide")
			Sfx.slide()
		else:
			P.state = "prone"
			setAnim("prone")
			Sfx.guard()
	if P.state == "prone" and not down:
		P.state = "move"
		setAnim("idle")
	if K.get("shift") and P.grounded and P.state == "move" and not wet:
		P.state = "block"
		P.blockT = now
		setAnim("block")
		Sfx.guard()
	if not K.get("shift") and P.state == "block":
		P.state = "move"
	pressed.clear()

	# --- state updates ---
	var run = P.runT > 0.28
	match P.state:
		"move":
			if inWater():
				P.vx = damp(P.vx, dirIn * 115 * PS.spd, 7, dt)
				if dirIn:
					P.face = dirIn
			elif P.grounded:
				var tgt: float = dirIn * (125 if run else 72) * PS.spd
				P.vx = damp(P.vx, tgt, 18, dt)
				if dirIn:
					P.face = dirIn
			elif dirIn:
				P.vx = damp(P.vx, dirIn * maxf(absf(P.vx), 90), 4, dt)
		"block":
			P.vx = damp(P.vx, 0, 16, dt)
		"prone":
			if dirIn:
				P.face = dirIn
			P.vx = damp(P.vx, dirIn * 34 * PS.spd, 12, dt)
			setAnim("crawl" if dirIn else "prone")
			if dirIn:
				var ph = floori(frameOf("crawl", P.animT, true) / 4.0)
				if ph != P.crawlPh:
					P.crawlPh = ph
					Sfx.step(false, "grass")
		"slide":
			P.slideT += dt
			P.vx *= exp(-dt * (1.6 if classId == "archer" else 2.6))
			if floori(P.slideT * 30) % 2 == 0:
				part(P.x - P.face * 6, P.y - 1, -P.face * rand(10, 30), rand(-20, -5), 0.3, "#f4f8ff" if World.snowCover > 0.3 else "#efe6cf", 0, 2)
			var box = hbox(P.x - 10 + P.face * 6, P.x + 10 + P.face * 6, P.y - 14, P.y)
			if not P.hitSet.has("slide"):
				for e in slimes:
					if e.state != "dead" and overlap(box, sBox(e)):
						P.hitSet["slide"] = true
						damageSlime(e, {"dmg": 0.6, "kb": 60, "up": -200, "style": 16, "anim": "slide"})
						break
			if P.slideT > (0.62 if classId == "archer" else 0.46) or absf(P.vx) < 60:
				P.state = "prone" if down else "move"
				if P.state == "prone":
					setAnim("prone")
		"dash":
			P.dashT += dt
			P.vx *= exp(-dt * 4)
			if not P.grounded:
				P.vy = minf(P.vy, 60)
			if P.dashT > 0.3:
				P.state = "move"
		"cheer":
			P.vx = damp(P.vx, 0, 12, dt)
			P.cheerT += dt
			if P.cheerT > 1.1 or dirIn or K.get(" ") or K.get("z") or K.get("x") or K.get("c"):
				P.state = "move"
		"flinch":
			P.hurtT += dt
			if P.hurtT > 0.22:
				P.state = "move"
		"knocked":
			P.kdT += dt
			if P.kdPhase == "air":
				P.vx = damp(P.vx, 0, 1.2, dt)
				if P.grounded and P.kdT > 0.1:
					P.kdPhase = "floor"; P.kdT = 0.0; P.vx *= 0.3
					dust(P.x, P.y, 10)
					Sfx.land()
			else:
				P.vx = damp(P.vx, 0, 10, dt)
				if P.kdT > 0.3:   # 0.3s on the ground, then back up
					P.state = "move"
					setAnim("land")
					P.landT = 0.18
		"hurt":
			P.hurtT += dt
			P.vx = damp(P.vx, 0, 3, dt)
			if P.hurtT > 0.4 and P.grounded:
				P.state = "move"
		"climb":
			var r: Dictionary = P.rope
			P.x = r.x
			P.vx = 0
			var v: int = (-1 if up else 0) + (1 if down else 0)
			P.y += v * 80 * dt
			P.animT += dt if v else 0.0
			if v:
				var ph = floori(frameOf("climb", P.animT, true) / 2.0)
				if ph != P.climbPh:
					P.climbPh = ph
					Sfx.rope()
			if P.y <= r.y0:
				var s = findSurf(func(q): return absf(q.y - r.y0) < 2 and P.x >= q.x0 and P.x <= q.x1)
				if s != null:
					P.y = s.y; P.state = "move"; P.grounded = true; P.surf = s; P.rope = null; P.jumps = 0
				else:
					P.y = r.y0
			if P.y >= r.y1:
				P.y = r.y1
				var s = findSurf(func(q): return absf(q.y - r.y1) < 2 and P.x >= q.x0 and P.x <= q.x1)
				P.state = "move"
				P.rope = null
				if s != null:
					P.grounded = true
					P.surf = s
		"plunge":
			P.plungeT += dt
			P.vx = damp(P.vx, 0, 10, dt)
			if P.plungePhase == "start" and P.plungeT > 0.14:
				P.plungePhase = "dive"
				setAnim("plunge")
				P.vy = 580
				Sfx.swing(true)
			if P.plungePhase == "dive":
				P.vy = 580
				var box = hbox(P.x - 11, P.x + 11, P.y - 26, P.y + 10)
				for e in slimes:
					if P.plungeHits < 2 and e.state != "dead" and not P.hitSet.has("p%d" % e.id) and overlap(box, sBox(e)):
						P.hitSet["p%d" % e.id] = true
						P.plungeHits += 1
						damageSlime(e, {"dmg": 0.8, "kb": 40, "up": 160, "style": 12, "anim": "plunge", "both": true})
				if parts.size() < 400:
					part(P.x + rand(-3, 3), P.y - 30, 0, -60, 0.18, "#bff3ff")
			if P.plungePhase == "land" and P.plungeT > 0.42:
				P.state = "move"
		"attack":
			_updateAttack(dt, aspd, dirIn, down)

	# --- physics ---
	if P.state != "climb":
		var wetNow = inWater()
		if P.state == "plunge" and P.plungePhase == "dive":
			pass
		elif wetNow:
			P.vy = minf(80, P.vy + GRAV * 0.22 * dt)
			P.vy *= exp(-dt * 1.8)
		else:
			P.vy = minf(MAXFALL, P.vy + GRAV * dt * (0.35 if P.state == "attack" and P.move.get("air") else (0.2 if P.state == "plunge" else 1.0)))
		var prevY = P.y
		P.x += P.vx * dt
		P.y += P.vy * dt
		P.x = clampf(P.x, 24, M.w - 24)   # the floor ends at 20px from each edge: stop at the border instead of walking off
		if M.get("pond"):
			var Wp: Dictionary = M.pond
			if P.y > M.floorY + 1 and P.x > Wp.x0 - 8 and P.x < Wp.x1 + 8:
				P.x = clampf(P.x, Wp.x0 + 7, Wp.x1 - 7)   # pond banks are walls below ground level
			if (prevY - 4 < Wp.surface) != (P.y - 4 < Wp.surface) and P.x > Wp.x0 and P.x < Wp.x1:
				var into: bool = P.y - 4 >= Wp.surface
				var force = minf(1.6, absf(P.vy) / 180 + 0.3)
				splash(P.x, force * (2.0 if P.state == "plunge" else 1.0))
				if into and P.state == "plunge":
					P.state = "move"
					P.vy = 90
				if into:
					P.vy *= 0.35
					P.jumps = 1
					P.airDash = 0
		if P.grounded:
			var s = onSurface()
			if s == null or P.surf == null or (P.x < P.surf.x0 - 2 or P.x > P.surf.x1 + 2):
				var s2 = findSurf(func(q): return P.x >= q.x0 and P.x <= q.x1 and absf(P.y - q.y) < 1)
				if s2 != null:
					P.surf = s2
				else:
					P.grounded = false
					P.surf = null
			else:
				P.y = P.surf.y
				P.vy = 0
		if not P.grounded and P.vy >= 0:
			for s in surfaces:
				if P.x < s.x0 - 2 or P.x > s.x1 + 2:
					continue
				if prevY <= s.y + 0.5 and P.y >= s.y and (s.floor or P.dropT <= 0):
					if P.state == "plunge":
						P.y = s.y; P.grounded = true; P.surf = s; P.vy = 0
						plungeImpact()
						break
					P.y = s.y; P.grounded = true; P.surf = s
					if P.state == "knocked":
						P.vy = 0
						P.jumps = 0
						break
					if P.vy > 140:
						landFx(minf(1.5, P.vy / 300))
					if P.vy > 260:
						P.landT = 0.22
						dust(P.x, P.y, 5)
						Sfx.land()
						if P.state == "move":
							setAnim("land")
					else:
						step(true)
					P.vy = 0; P.jumps = 0; P.airDash = 0
					if P.state == "attack" and P.move.get("air"):
						P.state = "move"
					break
		if P.y > M.h + 50:
			P.x = M.start; P.y = M.floorY; P.vy = 0
	# --- choose animation ---
	var rate = 1.0
	if P.state == "move":
		var sp = absf(P.vx)
		if inWater() and (not P.grounded or (P.surf != null and P.surf.water)):
			setAnim("swim")
			P.idleT = 0.0
		elif not P.grounded:
			if not (P.anim == "flip" and P.animT < 0.37):
				setAnim("jump")
			P.idleT = 0.0
		elif P.anim == "land" and P.landT > 0 and sp < 60:
			pass
		elif sp > 95:
			setAnim("run")
			rate = sp / 125
			P.idleT = 0.0
		elif sp > 12:
			setAnim("walk")
			rate = maxf(0.6, sp / 70)
			P.idleT = 0.0
		else:
			P.idleT += dt
			if P.idleT > 7 and P.anim != "rest":
				setAnim("rest")
			elif P.anim != "rest":
				setAnim("idle")
		if P.grounded and (P.anim == "walk" or P.anim == "run"):
			var n = nFrames(P.anim)
			var ph = floori(frameOf(P.anim, P.animT, true) / (n / 2.0))
			if ph != P.stepPh:
				P.stepPh = ph
				step(P.anim == "run")
	else:
		P.idleT = 0.0
		if P.state == "hurt":
			setAnim("hurt")
	if P.cheerQ and P.grounded and P.state == "move" and not inWater():
		P.cheerQ = false
		P.state = "cheer"
		P.cheerT = 0.0
		setAnim("cheer")
		Sfx.play("cheer")
	if P.state != "climb":
		P.animT += dt * rate
	# hair and hem stream with the wind (baked variants), plus a gentle sway
	var sprinting: bool = P.grounded and P.anim == "run" and absf(P.vx) > 110
	var windTarget: float = (1.0 if P.face > 0 else -1.0) * World.wind * 1.5 + sin(gameTime * 2.1) * 0.45 * (0.4 + World.wind) + sin(gameTime * 5.3) * 0.15 \
		+ ((1.5 + sin(gameTime * 17) * 0.9 + sin(gameTime * 29) * 0.4) if sprinting else 0.0)   # hair whips back and flutters at full speed
	if sprinting and randf() < dt * 34:
		speedLines.append({"x": P.x - P.face * rand(10, 22), "y": P.y - rand(6, 44), "len": rand(10, 26), "vx": -P.face * rand(40, 90), "t": 0.0, "life": rand(0.18, 0.32)})
	P.windV = damp(P.windV, windTarget, 4, dt)
	# breath clouds in the cold
	if (World.snow > 0.3 or World.snowCover > 0.5) and P.state != "dead":
		P.breathT -= dt
		if P.breathT <= 0:
			P.breathT = rand(2.2, 3.4)
			for i in 4:
				var p = part(P.x + P.face * 9, P.y - 34, P.face * rand(8, 18), rand(-10, -3), 0.8, "rgba(255,255,255,0.8)", 0, 2)
				p.t = i * -0.05
	# regen out of combat
	if gameTime - P.lastHurt > 4 and P.hp < PS.hp:
		P.hp = minf(PS.hp, P.hp + PS.hp * 0.02 * dt)
	var regen: float = skillRank("tranquilHeart") * 0.002 + (0.015 if buffOn("saintsAura") else 0.0) + PS.get("hpRegen", 0)
	if regen and P.hp > 0:
		P.hp = minf(PS.hp, P.hp + PS.hp * regen * dt)
	updateBuffs(dt)
	if save.settings.god:
		P.en = PS.enMax
		for k in Cool:
			Cool[k] = minf(Cool[k], 0.2)
		if P.poison != null:
			P.poison.t = 0
		if P.bleed != null:
			P.bleed.t = 0
	# wetness: rises in rain (unless swimming/indoors), drains slowly once it stops
	var raining: bool = World.rain > 0.3 and not M.get("boss") and not M.get("indoor") and M.theme != "crimson"
	P.wet = clampf(P.wet + (1.0 if inWater() else (dt * 0.5 if raining else -dt / 25)), 0, 1)
	if P.wet > 0.15 and randf() < dt * 14 * P.wet:
		var noTip = P.state == "climb" or P.anim == "swim"
		var tipX = P.x + P.face * (-16 if P.anim == "run" else 20)
		var tipY = P.y - (30 if P.anim == "run" else 20)
		var spots = [[P.x + rand(-8, 8), P.y - 44 + rand(0, 6)], [P.x + P.face * rand(-4, 4), P.y - rand(8, 14)], [P.x - P.face * 7, P.y - rand(18, 30)]]
		if not noTip:
			spots.append([tipX, tipY])
			spots.append([tipX, tipY])
		var sp0: Array = spots[rint(0, spots.size() - 1)]
		part(sp0[0], sp0[1], P.vx * 0.2, rand(10, 30), 0.45, "rgba(170,215,255,0.9)", 500, 1)
	P.en = minf(PS.enMax, P.en + PS.enRegen * dt * (1.0 if gameTime - P.lastSkillT > 0.6 else 0.25))


func _updateAttack(dt: float, aspd: float, dirIn: int, down: bool) -> void:
	var mv: Dictionary = P.move
	P.moveT += dt
	var f = frameOf(mv.anim, P.moveT * aspd, false)
	var n = nFrames(mv.anim)
	if P.grounded:
		P.vx = damp(P.vx, 0, 9, dt)
	if mv.get("rooted"):
		P.vx = 0
		if not P.grounded:
			P.vy = minf(P.vy, 20)
	if mv.get("staffCast") and randf() < 0.6:
		var el = ELEM()
		part(P.x + rand(-14, 14), P.y - rand(0, 4), 0, -rand(20, 50), 0.5, el.col)
	if mv.get("skill"):
		skillFrameFX(mv, f)
	if mv.get("air") and not P.grounded and P.airAtk <= AIR_LIFT_MAX:
		P.vy = minf(P.vy, 40)
	if f != P.lastFrame:
		P.lastFrame = f
		if mv.hits.has(f):
			var bx: Array = mv.get("box", [0, 0, 0, 0])
			var box = hbox(P.x + bx[0], P.x + bx[1], P.y + bx[2], P.y + bx[3]) if P.face > 0 else hbox(P.x - bx[1], P.x - bx[0], P.y + bx[2], P.y + bx[3])
			if mv.get("cmd"):
				dragonCommand(mv)
			elif mv.get("spell"):
				castSpell(mv, f)
			elif mv.get("arrow"):
				fireArrows(mv, f)
			elif mv.get("skill"):
				skillHit(mv, f)
			else:
				var best = null
				var bd = 1e9
				for e in slimes:
					if e.state == "dead" or not overlap(box, sBox(e)):
						continue
					var d = absf(e.x - P.x) + absf(e.y - P.y) * 0.5
					if d < bd:
						bd = d
						best = e
				if best != null:   # plain hits refuel energy
					damageSlime(best, mv)
					echoHit(best, mv)
					P.en = minf(PS.enMax, P.en + PS.enHit)
			if mv.get("heavy"):
				dust(P.x + P.face * 26, P.y, 10)
				Sfx.slam()
				shake = maxf(shake, 4)
	if f >= mv.cancel and P.queuedHeavy:
		if dirIn:
			P.face = dirIn
		startMove("aegis")
		return
	if f >= mv.cancel and P.queued:
		var isAir = AIR_CHAIN.has(P.moveId)
		var list: Array = AIR_CHAIN if isAir else CHAIN
		var i = list.find(P.moveId)
		if (i >= 0 and i < list.size() - 1) or not isAir:
			if dirIn:
				P.face = dirIn
			startMove(list[(i + 1) % list.size()])
			if isAir:
				P.vy = minf(P.vy, -90)
			return
		P.queued = false
	if P.moveT * aspd * ANIM_BY_ID[mv.anim].fps >= n:
		P.state = "prone" if mv.get("prone") and down else "move"
		if P.state == "prone":
			setAnim("prone")
		P.lastChain = CHAIN.find(P.moveId)
		P.chainEndT = gameTime
		if mv.get("skill"):
			P.skillLock = 0


func playerFrame() -> int:
	var a = P.anim
	if P.state == "knocked":
		if not P.kdBack:
			return 0
		return (1 if P.vy < 0 else 2) if P.kdPhase == "air" else 4
	if P.state == "flinch":
		return 0
	if a == "jump":
		return 1 if P.vy < -120 else (2 if P.vy < 80 else 3)
	if a == "climb":
		return frameOf("climb", P.animT, true)
	if P.state == "attack":
		return frameOf(a, P.moveT * PS.aspd, false)
	return frameOf(a, P.animT, ANIM_BY_ID.get(a, ANIM_BY_ID.idle).loop)


# ---------------- Rock's Meteor Drop

func startPlunge() -> void:
	P.plungeHits = 0
	P.state = "plunge"
	P.plungePhase = "start"
	P.plungeT = 0.0
	P.plungeY = P.y
	P.hitSet.clear()
	setAnim("plungeStart")
	P.vx *= 0.3
	P.vy = -90
	Sfx.play("plunge_start")


func plungeImpact() -> void:
	var fall = maxf(0, P.y - P.plungeY)
	var R = 34 + fall * 0.14
	var mult = 1.3 + fall * 0.0045
	P.plungePhase = "land"
	P.plungeT = 0.0
	setAnim("plungeLand")
	shake = minf(9, 4 + fall * 0.02)
	hitstop = 0.07
	Sfx.slam()
	dust(P.x, P.y, 14)
	for i in 24:
		var a = i / 24.0 * PI
		part(P.x, P.y - 2, cos(a) * R * 3, -sin(a) * 60, 0.35, "#fff4c8" if i % 2 else "#ffffff", 0, 2)
	var hit = slimes.filter(func(e): return e.state != "dead" and absf(e.y - P.y) < 24 and absf(e.x - P.x) < R)
	hit.sort_custom(func(a, b): return absf(a.x - P.x) < absf(b.x - P.x))
	for e in hit.slice(0, 2):
		damageSlime(e, {"dmg": mult, "kb": 160, "up": -240, "style": 24, "anim": "plunge", "both": true, "heavy": true})


## landing: snow puffs in snow, a puddle splash in the rain
func landFx(k: float) -> void:
	if World.snowCover > 0.3 and not M.get("indoor"):
		for i in int(10 + k * 10):
			var s = 1 if i % 2 else -1
			part(P.x + s * rand(2, 8), P.y - 1, s * rand(30, 90) * k, -rand(40, 120) * k, rand(0.4, 0.8), "#f4f8ff" if i % 3 else "#dde8f8", 260, 1 if i % 4 else 2)
		Sfx.burst(0.12, "bandpass", 2600, 900, 0.18)
	elif World.rain > 0.4 and not M.get("indoor"):
		for i in int(8 + k * 8):
			var s = 1 if i % 2 else -1
			part(P.x + s * rand(1, 6), P.y - 1, s * rand(20, 70), -rand(80, 170) * k, rand(0.3, 0.55), "#bfe0ff" if i % 3 else "#ffffff", 700, 1, P.y)
		fx.append({"type": "puddle", "x": P.x, "y": P.y, "t": 0.0, "life": 0.6, "r": 6 + k * 6})
		Sfx.burst(0.15, "bandpass", 1600, 500, 0.2)


func step(heavy: bool) -> void:
	var x = P.x - P.face * 3
	var y = P.y
	if World.snowCover > 0.3:
		footprints.append({"x": roundf(x), "y": y, "t": 0.0})
		if footprints.size() > 80:
			footprints.pop_front()
		for i in 3:
			part(x, y - 1, rand(-25, 25), rand(-40, -15), 0.4, "#f4f8ff", 200, 1)
	elif World.rain > 0.4:
		for i in 4:
			part(x, y - 1, rand(-40, 40), rand(-70, -30), 0.3, "#bfe0ff", 400, 1)
	elif heavy:
		part(x, y - 1, -P.face * rand(10, 25), rand(-12, -4), 0.35, "#efe6cf", 0, 2)
	var surf = "grass"
	if World.snowCover > 0.3:
		surf = "snow"
	elif World.rain > 0.4:
		surf = "wet"
	elif M.get("indoor"):
		surf = "wood"
	elif P.surf != null and M.get("pond") and P.surf.y == M.floorY and P.x > M.pond.x0 - 60 and P.x < M.pond.x0 + 12:
		surf = "wood"
	Sfx.step(heavy, surf)


# forward declarations for the class files further down the chain
func ELEM() -> Dictionary: return ELEMENTS[elemIdx]
func skillFrameFX(_mv: Dictionary, _f: int) -> void: pass
func updateBuffs(_dt: float) -> void: pass
