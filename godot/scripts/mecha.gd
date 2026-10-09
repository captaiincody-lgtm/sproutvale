extends "res://scripts/volcano.gd"
## Sproutvale, part 6⅞ (continued): the Anti-Personnel Mecha Mk II, the Containment Bay's miniboss.
## Four times your height, a shoulder rifle that never stops, a grenade launcher every five seconds,
## rocket boots, a ground slam that throws you up for a punch, a shoulder bash, and a kick into the
## wall that it follows up by catching you, shooting you, grenading you and slamming you into the floor.
## At half health its arms open into blades; at a fifth it launches a laser drone. Its loot is the Mechabox.
##
## It's drawn in code (an articulated rig, below), so there's no art file to replace: change the
## colours in MK2_COL or the shapes in _mk2Rig.

const MK2_T := {"name": "Anti-Personnel Mecha Mk II", "lv": 100, "hp": 320000, "atk": 360, "def": 95, "exp": 220000, "coins": [5000, 8000],
	"color": 0x59616f, "critter": false, "matName": "Scrap Plating", "metal": true}
const MK2_COL := {"dark": "#101319", "base": "#3c4758", "mid": "#5e6b80", "light": "#9eabbf", "hi": "#d6dee9",
	"hazard": "#e8b830", "red": "#ff2a3a", "mana": "#c25cff", "pipe": "#24272f", "steel": "#dfe5ee"}
const MK2_HIP_F := Vector2(9, -64)      # the rig, in its own space: facing right, feet at (0, 0), up is negative
const MK2_HIP_B := Vector2(-9, -64)
const MK2_SH_F := Vector2(28, -116)
const MK2_SH_B := Vector2(-24, -118)
const MK2_LEG := 34.0                    # thigh and shin
const MK2_ARM := 33.0                    # upper arm and forearm
const MK2_GUN := Vector2(26, -137)       # the rifle's pivot on the front shoulder
const MK2_POD := Vector2(-30, -150)      # the grenade launcher's mouth on the back shoulder

var droneP := {}   # the hero's own laser drone (the boss skill)


# ================================================================ data

func initVolcanoData() -> void:
	super.initVolcanoData()
	MORE_BOSSES.mk2 = {"T": MK2_T, "name": "Anti-Personnel Mecha Mk II", "short": "the Mk II", "box": "Mechabox", "col": "#ff9a3a", "ui": "#b8561a",
		"music": "mecha", "coins": 80, "mul": 8, "map": "volcano2",
		"loot": ["#ffb03a", "#1a1410", "#4a505e", "#7a8494", "#e8b830"],
		"info": {"title": "⚠ Boss: Anti-Personnel Mecha Mk II", "stats": [["Level", "100"], ["HP", "320,000"], ["Attack", "360"], ["Defense", "95"]],
			"paras": ["**Attacks:** its shoulder rifle never stops firing, and the launcher on its other shoulder lobs a grenade every five seconds · flies on rocket boots · **Ground slam:** if you're on the floor when it lands, you're thrown into the air and punched (jump or dodge with C) · dash shoulder bash · **Kick:** it kicks you into the wall, catches you on the bounce, shoots you, grenades you and slams you into the floor; dodge the kick with C · **50%:** its arms open into blades · **20%:** it launches a laser drone.",
				"**Reward:** 220,000 EXP · a hoard of coins · a trophy · the blast door opens · a **Mechabox** (500–2,500 coins, 1–5 Boss Coins, maybe a rare treasure, and very rarely its Laser Drone skill)"],
			"rec": "Recommended: Lv 100+. Walk right into the portal to enter."}}
	BOSS_LIST[4] = {"id": "mk2", "name": "Anti-Personnel Mecha Mk II", "where": "Containment Bay"}
	TROPHIES[4] = {"id": "mk2", "name": "Mk II Trophy"}
	BEST_ORDER.append("mk2")
	BEST_TEXT.mk2 = "Glamrax's answer to intruders: a walking weapons platform four times your height. It never stops shooting, it flies, and anything it kicks into a wall it catches again. Its arms hide blades, and its back hides a drone."
	MAPS.volcano1.bossSign = 2070
	MAPS.volcano1.signBoss = "mk2"


# ================================================================ spawning

func spawnBossKind(kind: String, fromPedestal := false) -> bool:
	if kind != "mk2":
		return super.spawnBossKind(kind, fromPedestal)
	spawnMk2(fromPedestal)
	return true


func spawnMk2(fromPedestal := false) -> void:
	volcShots = volcShots.filter(func(s): return not (s.kind in ["nade", "boom", "arc", "wave"]))
	var x: float = 330.0
	if fromPedestal:
		x = clampf(P.x + (210.0 if P.x < M.w / 2 else -210.0), 90, M.w - 90)
	var e = _newMob("mk2", MK2_T, x, groundAt(x), floorSurfAt(x))
	e.boss = true; e.bossKind = "mk2"; e.aggro = true
	e.face = -1 if P.x < x else 1
	e.w = 76; e.h = 156; e.showBar = 99
	e.state = "intro"
	e.data = {"act": "", "ph": "", "fireCd": 1.2, "nadeT": 3.5, "actCd": 1.0, "kickCd": 3.0, "slamCd": 4.0, "bashCd": 6.0, "flyCd": 8.0,
		"blade": 0.0, "blades": false, "drone": {}, "boots": 0.0, "visor": 0.0, "walkT": 0.0, "n": 0, "hang": not fromPedestal,
		"gunAng": 0.0, "flash": 0.0, "hatch": 0.0, "lean": 0.0, "crouch": 0.0, "hand": {}, "foot": {}, "deathT": 0.0, "fall": 0.0}
	e.y = groundAt(x) - (72.0 if not fromPedestal else 210.0)
	slimes.append(e)
	if fromPedestal:
		e.data.boots = 1.0
		Sfx.burst(0.8, "lowpass", 900, 200, 0.3)


# ================================================================ the fight

func _mk2Act(e, a: String, ph := "") -> void:
	e.data.act = a
	e.data.ph = ph
	e.data.n = 0
	e.data.fired = false
	e.t = 0.0
	e.hitDone = false


func _mk2End(e) -> void:
	_mk2Act(e, "")
	e.data.actCd = rand(0.5, 1.0) * (0.7 if e.data.blades else 1.0)


## a point on the rig (its own space) out in the world
func _mk2W(e, p: Vector2) -> Vector2:
	return Vector2(e.x + p.x * e.face, e.y + p.y)


## the rifle's muzzle, turned toward where it's aiming
func _mk2Muzzle(e) -> Vector2:
	var a: float = e.data.gunAng
	return _mk2W(e, MK2_GUN + Vector2(cos(a), sin(a)) * 46)


func _mk2Holding(e) -> bool:
	return P.held != null and P.held.get("e") == e and P.held.get("kind", "").begins_with("mk2")


func updateBossKind(e, dt: float) -> bool:
	if e.bossKind != "mk2":
		return super.updateBossKind(e, dt)
	updateMk2(e, dt)
	return true


func updateMk2(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.hurtFlash -= dt
	e.showBar = 99
	D.flash = maxf(0.0, D.flash - dt)
	var g = groundAt(e.x)
	if e.state == "dead":
		_mk2Dying(e, dt)
		return
	if e.state == "intro":
		D.visor = maxf(0.0, D.visor - dt)
		if D.hang:
			# hanging dark in the docking clamp until you step into the room
			if e.t > 0.8 and (P.x > 140 or e.t > 3.0):
				D.hang = false
				e.vy = 0.0
				Sfx.tone(120, 0.5, "square", 0.08, 60)
				Sfx.burst(0.3, "highpass", 1500, 4000, 0.25)
				for k in 12:
					part(e.x + rand(-30, 30), e.y - 150, rand(-60, 60), rand(-40, 30), 0.5, "#ffe07a" if k % 2 else "#ffffff", 300, 1)
			return
		e.vy = minf(e.vy + 900 * dt, 260.0 if D.boots > 0 else 600.0)
		e.y += e.vy * dt
		if e.y >= g:
			e.y = g
			e.vy = 0
			e.state = "fight"
			e.t = 0.0
			D.boots = 0.0
			shake = 12
			dust(e.x, g, 22)
			Sfx.slam()
			Sfx.tone(60, 0.8, "sawtooth", 0.1, 40)
			later(0.35, func():
				Sfx.tone(880, 0.25, "square", 0.05, 880)
				Sfx.tone(660, 0.25, "square", 0.05, 660, 0.3))
			banner("Anti-Personnel Mecha Mk II", "It never stops shooting · dodge its kick with C")
		return
	# ---- fighting
	D.visor = minf(1.0, D.visor + dt * 2)
	D.fireCd -= dt; D.nadeT -= dt; D.actCd -= dt
	D.kickCd -= dt; D.slamCd -= dt; D.bashCd -= dt; D.flyCd -= dt
	var hpK: float = e.hp / e.maxHp
	if D.act == "":
		if not D.blades and hpK <= 0.5:
			_mk2Act(e, "transform")
		elif D.drone.is_empty() and hpK <= 0.2:
			_mk2Act(e, "deploy")
	var alive = P.state != "dead"
	var busy: bool = D.act in ["transform", "deploy", "kickhold", "air"] or _mk2Holding(e)
	# the rifle: a stream of rounds whenever it can see you
	var mz = _mk2W(e, MK2_GUN)
	var want = atan2((P.y - 22) - mz.y, (P.x - mz.x) * e.face)
	D.gunAng = lerp_angle(D.gunAng, clampf(want, -0.9, 0.9), minf(1, dt * 10))
	if alive and not busy and D.fireCd <= 0 and absf(want) < 0.95 and P.held == null:
		D.fireCd = 0.14
		var m = _mk2Muzzle(e)
		var a = D.gunAng + rand(-0.05, 0.05)
		volcShots.append({"kind": "round", "x": m.x, "y": m.y, "vx": cos(a) * e.face * 460, "vy": sin(a) * 460, "t": 0.0, "src": _src(e, e.x), "mul": 0.06})
		D.flash = 0.05
		if randf() < 0.6:
			Sfx.tone(rand(170, 230), 0.05, "square", 0.025, 80)
	# the grenade launcher: every five seconds, whatever else it's doing
	if D.nadeT <= 0 and alive and not busy:
		D.nadeT = 5.0
		_mk2Nade(e, P.x + P.vx * 0.4)
	# ---- what it's doing
	match D.act:
		"":
			_mk2Choose(e, dt)
		"punch":
			_mk2Punch(e, dt)
		"slash":
			_mk2Slash(e, dt)
		"kick":
			_mk2Kick(e, dt)
		"kickhold", "air":
			# the hold itself (abyssHold) moves both of you; this waits for it to end
			if not _mk2Holding(e):
				if e.t > 0.05 and D.ph != "after":
					D.ph = "after"
					e.t = 0.0
				if D.ph == "after":
					e.vx *= exp(-dt * 6)
					D.boots = maxf(0.0, D.boots - dt * 2)
					if e.t > 0.7 and e.y >= g - 0.5:
						_mk2End(e)
		"slam":
			_mk2Slam(e, dt)
		"bash":
			_mk2Bash(e, dt)
		"fly":
			_mk2Fly(e, dt)
		"transform":
			e.vx = 0
			D.blade = clampf((e.t - 0.35) / 0.9, 0, 1)
			if e.t < 0.05 and not D.fired:
				D.fired = true
				floatText(e.x, e.y - 170, "BLADES ENGAGED", "call")
				Sfx.tone(300, 1.0, "sawtooth", 0.06, 1400)
			if e.t > 0.35 and randf() < dt * 30:
				var hf = _mk2W(e, D.hand.get("f", Vector2(40, -62)))
				part(hf.x, hf.y, rand(-80, 80), rand(-120, 0), 0.4, "#ffd27a" if randf() < 0.5 else "#ffffff", 400, 1)
			if e.t > 0.9 and D.n == 0:
				D.n = 1
				Sfx.burst(0.4, "highpass", 3000, 8000, 0.3)
				Sfx.tone(1800, 0.3, "triangle", 0.05, 2400)
			if e.t > 1.6:
				D.blades = true
				D.blade = 1.0
				_mk2End(e)
		"deploy":
			e.vx = 0
			D.hatch = minf(1, e.t / 0.4) if e.t < 1.0 else maxf(0, 1 - (e.t - 1.0) / 0.3)
			if e.t > 0.55 and D.drone.is_empty():
				var b = _mk2W(e, Vector2(-28, -140))
				D.drone = {"x": b.x, "y": b.y, "vy": -220.0, "t": 0.0, "cd": 1.4, "aimT": -1.0, "aim": Vector2(P.x, P.y - 22)}
				floatText(e.x, e.y - 175, "LASER DRONE ONLINE", "call")
				Sfx.tone(600, 0.6, "square", 0.05, 1600)
			if e.t > 1.3:
				_mk2End(e)
	# ---- moving: walking, or the boots keep it up
	var flying: bool = D.act == "fly" or (D.act == "air" and D.ph != "after") or (D.act == "slam" and D.ph in ["rise", "hang", "dive"]) or (D.act == "kickhold" and D.ph != "after")
	if not flying:
		e.vy = minf(e.vy + 1100 * dt, 900)
		e.y += e.vy * dt
		if e.y >= g:
			if e.vy > 300:
				dust(e.x, g, 10)
				Sfx.slam()
				shake = maxf(shake, 5)
			e.y = g
			e.vy = 0
	e.x = clampf(e.x + e.vx * dt, 50, M.w - 50)
	if absf(e.vx) > 5 and e.y >= g - 0.5:
		var w0: float = D.walkT
		D.walkT += dt * absf(e.vx) / 13.0
		if int(w0 / PI) != int(D.walkT / PI):
			Sfx.tone(70, 0.15, "square", 0.06, 50)
			shake = maxf(shake, 1.5)
	if flying or D.boots > 0.5:
		if randf() < dt * 50:
			for f in [MK2_HIP_F, MK2_HIP_B]:
				var ft = _mk2W(e, D.foot.get("f" if f == MK2_HIP_F else "b", Vector2(f.x, 0)))
				part(ft.x + rand(-3, 3), ft.y + 2, rand(-20, 20), rand(120, 220), rand(0.15, 0.3), ["#ff8a2a", "#ffd27a", "#ff4a1a"][rint(0, 2)], 0, 2)
	_mk2Drone(e, dt)
	# bumping into it hurts
	if alive and not busy and D.act != "bash" and P.held == null and P.touchCd <= 0 and overlap(bossBoxKind(e), pBox()):
		P.touchCd = 0.9
		hurtPlayer(_src(e, e.x), e.atk * 0.5)


## between attacks: turn to face you, walk in, and pick the next move
func _mk2Choose(e, dt: float) -> void:
	var D: Dictionary = e.data
	var dx = P.x - e.x
	var adx = absf(dx)
	if adx > 12:
		e.face = int(sgn(dx))
	D.boots = maxf(0.0, D.boots - dt * 3)
	var sp = 64.0 * (1.3 if D.blades else 1.0)
	e.vx = e.face * sp if adx > 74 else 0.0
	if D.actCd > 0 or P.state == "dead" or P.held != null:
		return
	var pg: bool = P.grounded
	var r = randf()
	if adx < 84 and D.kickCd <= 0 and r < 0.45:
		D.kickCd = rand(6.5, 9.5)
		_mk2Act(e, "kick")
		e.vx = 0
		Sfx.tone(400, 0.5, "sawtooth", 0.05, 1400)
	elif adx < 96:
		_mk2Act(e, "slash" if D.blades else "punch")
		e.vx = 0
		Sfx.tone(90, 0.5, "sawtooth", 0.06, 60)
	elif pg and D.slamCd <= 0 and adx < 300 and r < 0.55:
		D.slamCd = rand(6.0, 9.0)
		_mk2Act(e, "slam", "crouch")
		e.vx = 0
	elif D.bashCd <= 0 and adx > 110 and absf(P.y - e.y) < 70:
		D.bashCd = rand(5.0, 8.0)
		_mk2Act(e, "bash")
		e.vx = 0
		Sfx.tone(200, 0.6, "sawtooth", 0.06, 900)
	elif D.flyCd <= 0:
		D.flyCd = rand(10.0, 14.0)
		_mk2Act(e, "fly", "up")
		Sfx.burst(0.6, "lowpass", 1200, 300, 0.3)
	else:
		D.actCd = 0.3


func _mk2Front(e, reach: float, y0: float, y1: float, back := 10.0) -> Dictionary:
	if e.face > 0:
		return hbox(e.x - back, e.x + reach, e.y - y1, e.y - y0)
	return hbox(e.x - reach, e.x + back, e.y - y1, e.y - y0)


func _mk2Punch(e, dt: float) -> void:
	if e.t < 0.45:
		e.vx = 0
		return
	if e.t < 0.62:
		if not e.data.fired:
			e.data.fired = true
			e.vx = e.face * 240
			Sfx.whoosh(0.6, true)
		if not e.hitDone and overlap(_mk2Front(e, 96, 30, 140), pBox()):
			e.hitDone = true
			if launchHit(_src(e, e.x), 2.3):
				Sfx.tone(70, 0.3, "square", 0.1, 40)
			shake = maxf(shake, 8)
			Sfx.slam()
	e.vx *= exp(-dt * 7)
	if e.t > 1.05:
		_mk2End(e)


## with its blades out: three slashes, the last one sends you flying
func _mk2Slash(e, dt: float) -> void:
	var D: Dictionary = e.data
	var cyc = 0.42
	var n = int(e.t / cyc)
	var ct = fmod(e.t, cyc)
	if n >= 3:
		e.vx *= exp(-dt * 7)
		if e.t > 3 * cyc + 0.45:
			_mk2End(e)
		return
	if ct < 0.24:
		e.vx *= exp(-dt * 8)
		if absf(P.x - e.x) > 10 and ct < 0.1:
			e.face = int(sgn(P.x - e.x))
		return
	if D.n <= n:
		D.n = n + 1
		e.hitDone = false
		e.vx = e.face * 200
		var hf = _mk2W(e, Vector2(40, -90))
		volcShots.append({"kind": "arc", "x": hf.x, "y": hf.y, "face": e.face, "t": 0.0, "up": n % 2 == 1, "big": n == 2})
		Sfx.whoosh(1.3, true)
		Sfx.tone(2200, 0.12, "sawtooth", 0.04, 900)
	if not e.hitDone and overlap(_mk2Front(e, 108, 0, 165), pBox()):
		e.hitDone = true
		if n < 2:
			critChip(_src(e, e.x), 1.4, false)
		else:
			if launchHit(_src(e, e.x, {"crit": true}), 2.4):
				P.vx = e.face * 380
				P.vy = -340
		sparks(P.x, P.y - 24, "#ffffff", 10)
		shake = maxf(shake, 6)
	e.vx *= exp(-dt * 5)


## the kick: dodge it, or you're in for the whole combo
func _mk2Kick(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.vx = 0
	if e.t < 0.5:
		if randf() < dt * 20:
			var ft = _mk2W(e, D.foot.get("f", Vector2(10, 0)))
			part(ft.x, ft.y - 4, rand(-30, 30), rand(-30, 10), 0.3, "#ffb03a", 0, 1)
		return
	if e.t < 0.66 and not e.hitDone and overlap(_mk2Front(e, 92, 8, 90), pBox()):
		e.hitDone = true
		if P.iframes > 0 or P.held != null or save.settings.god:
			return
		if critChip(_src(e, e.x), 0.6, false) and P.state != "dead":
			# into the wall behind you
			P.held = {"kind": "mk2kick", "e": e, "t": 0.0, "phase": "fly", "dir": e.face, "n": 0}
			P.state = "held"
			P.vx = 0; P.vy = 0
			P.rope = null
			P.grounded = false
			P.surf = null
			hitstop = 0.1
			shake = 10
			Sfx.slam()
			Sfx.burst(0.4, "lowpass", 1400, 200, 0.35)
			floatText(P.x, P.y - 60, "KICKED!", "call")
			_mk2Act(e, "kickhold", "fly")
			D.boots = 1.0
			return
	if e.t > 1.1:
		_mk2End(e)


## the ground slam: up on its boots, down on the floor; standing on the floor throws you up for a punch
func _mk2Slam(e, dt: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	match D.ph:
		"crouch":
			e.vx = 0
			D.crouch = minf(1, e.t / 0.3)
			if e.t > 0.35:
				D.ph = "rise"
				e.t = 0.0
				e.vy = -430   # (the bay's roof is low: about a hundred up is all the room it has)
				D.boots = 1.0
				D.crouch = 0.0
				Sfx.burst(0.6, "lowpass", 1400, 300, 0.35)
				Sfx.whoosh(0.5, true)
		"rise":
			e.vy += 900 * dt
			e.y += e.vy * dt
			e.x = move_toward(e.x, P.x, 220 * dt)
			e.x = clampf(e.x, 50, M.w - 50)
			if e.vy >= -40 or e.t > 0.9:
				D.ph = "hang"
				e.t = 0.0
				e.vy = 0
		"hang":
			e.x = clampf(move_toward(e.x, P.x, 160 * dt), 50, M.w - 50)
			if e.t > 0.22:
				D.ph = "dive"
				e.t = 0.0
				e.vy = 980
				Sfx.whoosh(0.4, true)
		"dive":
			e.y += e.vy * dt
			if e.y >= g:
				e.y = g
				e.vy = 0
				D.ph = "land"
				e.t = 0.0
				D.boots = 0.0
				D.crouch = 1.0
				shake = 16
				hitstop = 0.08
				dust(e.x, g, 26)
				Sfx.slam()
				Sfx.burst(0.7, "lowpass", 900, 120, 0.45)
				for s in [-1, 1]:
					volcShots.append({"kind": "wave", "x": e.x, "y": g, "dir": s, "t": 0.0})
				_mk2Quake(e)
		"land":
			D.crouch = maxf(0, 1 - e.t / 0.5)
			if e.t > 0.75:
				_mk2End(e)


## the landing: anyone on the floor nearby is thrown up into the air, and it follows to punch them
func _mk2Quake(e) -> void:
	if P.state == "dead" or P.held != null or save.settings.god:
		return
	var near: bool = absf(P.x - e.x) < 60 and P.y > e.y - 150
	if not near and not (P.grounded and absf(P.x - e.x) < 320):
		return
	if P.state == "dash":
		if not P.dodged.has(e):
			P.dodged[e] = true
			perfectDodge()
		return
	if P.iframes > 0 or P.state == "knocked":
		return
	abyssChip(_src(e, e.x), 0.6, 0.0, false)
	if P.state == "dead":
		return
	P.held = {"kind": "mk2air", "e": e, "t": 0.0, "phase": "up", "y0": P.y, "x0": P.x}
	P.state = "held"
	P.vx = 0; P.vy = 0
	P.rope = null
	P.grounded = false
	P.surf = null
	floatText(P.x, P.y - 60, "LAUNCHED!", "call")
	_mk2Act(e, "air", "up")
	e.data.boots = 1.0


func _mk2Bash(e, dt: float) -> void:
	var D: Dictionary = e.data
	if e.t < 0.55:
		e.vx = 0
		D.lean = -0.12 * minf(1, e.t / 0.3)
		if randf() < dt * 40:
			var b = _mk2W(e, Vector2(-36, -110))
			part(b.x, b.y, -e.face * rand(80, 200), rand(-30, 30), 0.3, "#ff8a2a" if randf() < 0.5 else "#fff0c0", 0, 2)
		return
	if not D.fired:
		D.fired = true
		e.vx = e.face * 640
		Sfx.whoosh(0.4, true)
		Sfx.burst(0.6, "lowpass", 1400, 300, 0.35)
	D.lean = 0.28
	if randf() < dt * 60:
		var b = _mk2W(e, Vector2(-36, -110))
		part(b.x, b.y, -e.face * rand(120, 260), rand(-30, 30), 0.25, "#ff8a2a" if randf() < 0.5 else "#fff0c0", 0, 2)
	if not e.hitDone and e.t < 1.2 and overlap(_mk2Front(e, 60, 0, 150, 30), pBox()):
		e.hitDone = true
		var n0 = P.hurtN
		launchHit(_src(e, e.x, {"crit": true}), 2.4)
		if P.hurtN != n0:
			P.vx = e.face * 500
			P.vy = -320
			floatText(P.x, P.y - 64, "BASHED!", "call")
			hitstop = 0.1
			shake = 12
			Sfx.burst(0.5, "lowpass", 1600, 200, 0.4)
	var atWall: bool = e.x <= 51 or e.x >= M.w - 51
	if e.t > 1.15 or atWall:
		if atWall and absf(e.vx) > 200:
			shake = 10
			Sfx.slam()
			sparks(e.x + e.face * 40, e.y - 100, "#ffe07a", 14)
		e.vx = -e.face * 40.0 if atWall else e.face * 60.0
		D.lean = 0.0
		D.ph = "stop"
		_mk2Act(e, "")
		D.actCd = 0.8


## up on its rocket boots: it hovers over you, rifle going, then dives or drops back down
func _mk2Fly(e, dt: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	var hy = maxf(g - 96, ceilAt(e.x) + 162)
	D.boots = 1.0
	if absf(P.x - e.x) > 10:
		e.face = int(sgn(P.x - e.x))
	match D.ph:
		"up":
			e.y = lerpf(e.y, hy, minf(1, dt * 4))
			e.vx = 0
			if e.t > 0.6:
				D.ph = "hover"
				e.t = 0.0
		"hover":
			var tx = P.x + (-90.0 if e.x < P.x else 90.0)
			e.vx = clampf((tx - e.x) * 2.0, -150, 150)
			e.y = lerpf(e.y, hy + sin(e.t * 3) * 6, minf(1, dt * 4))
			if e.t > 3.2:
				if P.grounded and P.state != "dead" and randf() < 0.65:
					_mk2Act(e, "slam", "hang")
					e.vx = 0
				else:
					D.ph = "down"
					e.t = 0.0
		"down":
			e.vx *= exp(-dt * 4)
			e.y = minf(g, e.y + 260 * dt)
			if e.y >= g:
				D.boots = 0.0
				_mk2End(e)


## the grenade launcher: a lobbed shell that lands where you're heading
func _mk2Nade(e, tx: float) -> void:
	var o = _mk2W(e, MK2_POD)
	tx = clampf(tx, 30, M.w - 30)
	var ty = groundAt(tx) - 2
	var T = 0.9
	volcShots.append({"kind": "nade", "x": o.x, "y": o.y, "vx": (tx - o.x) / T, "vy": (ty - o.y - 0.5 * 600 * T * T) / T, "t": 0.0, "spin": 0.0, "src": _src(e, e.x)})
	e.data.hatch = 0.0
	Sfx.tone(140, 0.2, "square", 0.08, 60)
	Sfx.burst(0.25, "lowpass", 800, 300, 0.3)
	for k in 6:
		part(o.x, o.y, rand(-30, 30), rand(-80, -20), 0.5, "#8a8290", -20, 2)


func _boom(x: float, y: float, r: float, src, mul: float) -> void:
	volcShots.append({"kind": "boom", "x": x, "y": y, "t": 0.0, "r": r})
	shake = maxf(shake, 7)
	Sfx.burst(0.6, "lowpass", 900, 120, 0.4)
	Sfx.tone(80, 0.4, "sawtooth", 0.08, 40)
	for k in 16:
		var a = randf() * TAU
		part(x, y - 4, cos(a) * rand(40, 160), sin(a) * rand(40, 160) - 60, rand(0.3, 0.6), ["#ff8a2a", "#ffd27a", "#ff3a1a", "#5a5058"][rint(0, 3)], 200, 2)
	if src != null and P.state != "dead" and Vector2(P.x - x, (P.y - 20) - y).length() < r + 8:
		launchHit(src, mul)


## the Mk II's laser drone: it floats above you, aims for a moment, and fires
func _mk2Drone(e, dt: float) -> void:
	var R: Dictionary = e.data.drone
	if R.is_empty():
		return
	R.t += dt
	var ty = maxf(ceilAt(P.x) + 18, P.y - 96)
	var tx = P.x + sin(R.t * 0.9) * 80
	if R.vy < 0:
		R.y += R.vy * dt
		R.vy = minf(0.0, R.vy + 400 * dt)
	else:
		R.x = lerpf(R.x, tx, minf(1, dt * 1.8))
		R.y = lerpf(R.y, ty + sin(R.t * 2.3) * 5, minf(1, dt * 1.8))
	if P.state == "dead":
		return
	R.cd -= dt
	if R.aimT < 0 and R.cd <= 0:
		R.aimT = 0.0
		R.aim = Vector2(P.x, P.y - 22)
		Sfx.tone(500, 0.6, "sawtooth", 0.04, 1600)
	if R.aimT >= 0:
		R.aimT += dt
		if R.aimT < 0.5:
			R.aim = R.aim.lerp(Vector2(P.x, P.y - 22), minf(1, dt * 9))
		if R.aimT > 0.75:
			var dir = (R.aim - Vector2(R.x, R.y)).normalized()
			volcShots.append({"kind": "beam", "x": R.x, "y": R.y, "dx": dir.x, "dy": dir.y, "len": 420.0, "t": 0.0, "life": 0.2, "w": 3.5,
				"src": _src(e, R.x), "mul": 1.25, "hit": false, "col": "#ff2a3a"})
			Sfx.tone(1700, 0.25, "sawtooth", 0.07, 400)
			R.aimT = -1.0
			R.cd = 2.1


func updateVolcShots(dt: float) -> void:
	super.updateVolcShots(dt)
	for i in range(volcShots.size() - 1, -1, -1):
		var s: Dictionary = volcShots[i]
		var gone = false
		match s.kind:
			"nade":
				s.vy += 600 * dt
				s.x += s.vx * dt
				s.y += s.vy * dt
				s.spin += dt * 14
				var pb = pBox()
				var touch = s.x > pb.x0 - 3 and s.x < pb.x1 + 3 and s.y > pb.y0 - 3 and s.y < pb.y1 + 3 and P.state != "dead"
				if touch or s.y >= groundAt(s.x) - 1 or s.t > 3:
					_boom(s.x, minf(s.y, groundAt(s.x) - 2), 40, s.src, 1.5)
					gone = true
			"boom":
				gone = s.t > 0.45
			"arc":
				gone = s.t > 0.2
			"wave":
				s.x += s.dir * 520 * dt
				gone = s.t > 0.55
		if gone:
			volcShots.remove_at(i)


# ================================================================ the holds: launched and punched; kicked, caught and slammed

func abyssHold(dt: float) -> bool:
	var H = P.held
	if H == null or not (H.get("kind") in ["mk2kick", "mk2air"]):
		return super.abyssHold(dt)
	var e = H.e
	H.t += dt
	P.state = "held"
	P.vx = 0
	P.animT += dt
	setAnim("hurt")
	P.iframes = maxf(P.iframes, 0.2)
	if e == null or e.state == "dead" or not slimes.has(e):
		_releasePlayer()
		return false
	var D: Dictionary = e.data
	var src = {"x": e.x, "lv": e.lv, "atk": e.atk}
	if H.kind == "mk2air":
		# thrown up off the floor; it rockets up after you and punches you away
		var top = maxf(ceilAt(H.x0) + 46, H.y0 - 150)
		match H.phase:
			"up":
				var k = minf(1, H.t / 0.45)
				P.y = lerpf(H.y0, top, easeOut(k))
				P.spin = sin(H.t * 9) * 0.4
				e.x = lerpf(e.x, P.x - e.face * 74, minf(1, dt * 7))
				e.y = minf(groundAt(e.x), lerpf(e.y, P.y + 96, minf(1, dt * 7)))
				D.hand.f = Vector2(-4, -104)   # cocked back
				if k >= 1:
					H.phase = "punch"
					H.t = 0.0
					Sfx.whoosh(0.5, true)
			"punch":
				P.y = top + sin(H.t * 40) * 0.6
				D.hand.f = Vector2(-4, -104).lerp(Vector2(62, -98), minf(1, H.t / 0.1))
				if H.t > 0.12:
					abyssChip(src, 2.4, 0.0, false)
					floatText(P.x, P.y - 64, "PUNCHED!", "call")
					hitstop = 0.14
					shake = 14
					Sfx.slam()
					Sfx.burst(0.5, "lowpass", 1600, 200, 0.4)
					sparks(P.x, P.y - 24, "#ffe07a", 16)
					_releasePlayer()
					if P.state != "dead":
						knockDown(src)
						P.vx = e.face * 460
						P.vy = -140
					return false
		return true
	# kicked into the wall …
	var dir: int = H.dir
	var g = groundAt(P.x)
	match H.phase:
		"fly":
			P.x += dir * 760 * dt
			P.y = lerpf(P.y, g - 34, minf(1, dt * 6))
			P.spin += dir * dt * 22
			e.x = move_toward(e.x, P.x - dir * 120, 260 * dt)
			var wall = 26.0 if dir < 0 else M.w - 26.0
			if (dir < 0 and P.x <= wall) or (dir > 0 and P.x >= wall):
				P.x = wall
				H.phase = "bounce"
				H.t = 0.0
				H.vx = -dir * 230.0
				H.vy = -320.0
				abyssChip(src, 0.5, 0.0, false)
				floatText(P.x, P.y - 60, "WALL!", "call")
				shake = 12
				hitstop = 0.08
				Sfx.slam()
				sparks(P.x + dir * 8, P.y - 20, "#ffe07a", 12)
				dust(P.x, P.y - 10, 10)
				if P.state == "dead":
					_releasePlayer()
					return false
		"bounce":
			# … bounce off it, and it rockets in to catch you
			H.vy += GRAV * dt
			P.x += H.vx * dt
			P.y = minf(g - 4, P.y + H.vy * dt)
			P.spin += -dir * dt * 14
			var hx = P.x - dir * 56
			e.x = move_toward(e.x, hx, 900 * dt)
			D.boots = 1.0
			D.hand.f = Vector2(56, -100)
			if H.t > 0.36:
				H.phase = "catch"
				H.t = 0.0
				e.face = dir
				P.spin = 0.0
				Sfx.tone(140, 0.2, "square", 0.08, 90)
				floatText(P.x, P.y - 60, "CAUGHT!", "call")
		"catch", "shoot", "nade", "lift", "smash":
			e.face = dir
			var hand: Vector2
			match H.phase:
				"catch":
					hand = Vector2(56, -100)
					if H.t > 0.2:
						H.phase = "shoot"; H.t = 0.0
				"shoot":
					# five rounds, point blank
					hand = Vector2(58, -100)
					var n = int(H.t / 0.2)
					if n > H.n and H.n < 5:
						H.n = n
						D.flash = 0.06
						D.gunAng = 0.35
						critChip(src, 0.25)
						Sfx.tone(rand(150, 200), 0.08, "square", 0.08, 70)
						sparks(P.x, P.y - 26, "#ffe07a", 6)
					if H.t > 1.15:
						H.phase = "nade"; H.t = 0.0
						var o = _mk2W(e, MK2_POD)
						volcShots.append({"kind": "nade", "x": o.x, "y": o.y, "vx": (P.x - o.x) / 0.3, "vy": ((P.y - 26) - o.y - 0.5 * 600 * 0.09) / 0.3, "t": 0.0, "spin": 0.0, "src": null})
						Sfx.tone(140, 0.2, "square", 0.08, 60)
				"nade":
					hand = Vector2(58, -100)
					if H.t > 0.3 and H.n < 6:
						H.n = 6
						volcShots = volcShots.filter(func(s): return not (s.kind == "nade" and s.src == null))
						_boom(P.x, P.y - 26, 30, null, 0)
						abyssChip(src, 0.7, 0.0, false)
						floatText(P.x, P.y - 60, "BOOM!", "call")
					if H.t > 0.65:
						H.phase = "lift"; H.t = 0.0
						Sfx.tone(90, 0.5, "sawtooth", 0.08, 60)
				"lift":
					hand = Vector2(58, -100).lerp(Vector2(18, -184), easeOut(minf(1, H.t / 0.4)))
					if H.t > 0.5:
						H.phase = "smash"; H.t = 0.0
						Sfx.whoosh(0.4, true)
				"smash":
					var k = minf(1, H.t / 0.13)
					hand = Vector2(18, -184).lerp(Vector2(66, -10), easeIn(k))
					P.spin = dir * lerpf(0, PI * 0.5, k)
					if k >= 1:
						var fy = groundAt(P.x)
						P.y = fy
						abyssChip(src, 1.8, 0.0, false)
						floatText(P.x, P.y - 70, "COLOSSAL!", "crit")
						hitstop = 0.16
						shake = 20
						dust(P.x, fy, 26)
						Sfx.slam()
						Sfx.burst(0.8, "lowpass", 700, 100, 0.5)
						volcShots.append({"kind": "wave", "x": P.x, "y": fy, "dir": -1, "t": 0.0})
						volcShots.append({"kind": "wave", "x": P.x, "y": fy, "dir": 1, "t": 0.0})
						_releasePlayer()
						if P.state != "dead":
							knockDown(src)
							P.vx = dir * 60
							P.vy = -120
						return false
			D.hand.f = hand
			# it lands, holding you out by the collar
			e.y = minf(groundAt(e.x), e.y + 400 * dt)
			D.boots = 1.0 if e.y < groundAt(e.x) - 1 else 0.0
			var hw = _mk2W(e, hand)
			P.x = hw.x
			P.y = hw.y + 32
			if H.phase != "smash":
				P.spin = sin(H.t * 7) * 0.12
	return true


# ================================================================ its end

func bossBoxKind(e) -> Dictionary:
	if e.bossKind != "mk2":
		return super.bossBoxKind(e)
	return hbox(e.x - 36, e.x + 36, e.y - 152, e.y)


func bossFallsKind(e, firstKill: bool) -> bool:
	if e.bossKind != "mk2":
		return super.bossFallsKind(e, firstKill)
	e.dying = true
	var D: Dictionary = e.data
	D.act = ""
	D.deathT = 0.0
	if _mk2Holding(e):
		_releasePlayer()
	volcShots = volcShots.filter(func(s): return not (s.kind in ["nade", "beam", "round"]))
	if not D.drone.is_empty():
		_boom(D.drone.x, D.drone.y, 20, null, 0)
		D.drone = {}
	later(1.9, func():
		if firstKill:
			banner("CONTAINMENT LIFTED", "The blast door grinds open · grab the Mechabox")
			Sfx.tone(440, 0.3, "square", 0.05, 440)
			Sfx.tone(660, 0.4, "square", 0.05, 660, 0.3)
		else:
			banner("MK II DESTROYED", "Grab the Mechabox · the pedestal can call it back")
		Sfx.rankUp(9))
	return true


func _mk2Dying(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.vx = 0
	D.boots = 0.0
	e.y = minf(groundAt(e.x), e.y + 300 * dt)
	if not e.dying:
		e.deadT += dt
		return
	e.deadT = 0
	D.deathT += dt
	D.visor = 0.4 + 0.6 * float(randf() < 0.5)
	D.fall = clampf((D.deathT - 0.9) / 0.7, 0, 1)
	if randf() < dt * 9:
		var p = _mk2W(e, Vector2(rand(-34, 34), rand(-150, -40)))
		_boom(p.x, p.y, 14, null, 0)
	if D.deathT > 1.7:
		e.dying = false
		shake = 16
		_boom(e.x, e.y - 40, 50, null, 0)
		dust(e.x, e.y, 24)
		Sfx.slam()


# ================================================================ the Laser Drone (its boss skill)

func castBossSkill(s: Dictionary) -> void:
	if s.id != "laserDrone":
		super.castBossSkill(s)
		return
	droneP = {"x": P.x - P.face * 10, "y": P.y - 40, "t": 0.0, "life": 10.0, "cd": 0.3, "beam": {}}
	floatText(P.x, P.y - 58, "Laser Drone!", "call")
	Sfx.tone(600, 0.5, "square", 0.05, 1600)


func updateClimb(dt: float) -> void:
	super.updateClimb(dt)
	_updateDroneP(dt)


func _updateDroneP(dt: float) -> void:
	if droneP.is_empty():
		return
	var R: Dictionary = droneP
	R.t += dt
	R.x = lerpf(R.x, P.x - P.face * 22, minf(1, dt * 5))
	R.y = lerpf(R.y, P.y - 58 + sin(R.t * 3) * 3, minf(1, dt * 5))
	if not R.beam.is_empty():
		R.beam.t += dt
		if R.beam.t > 0.15:
			R.beam = {}
	R.cd -= dt
	if R.cd <= 0:
		R.cd = 0.7
		var best = null
		var bd = 300.0
		for q in slimes:
			if q.state == "dead" or q.bossEye:
				continue
			var d = Vector2(q.x - R.x, (q.y - q.h / 2) - R.y).length()
			if d < bd:
				bd = d
				best = q
		if best != null:
			R.beam = {"x": best.x, "y": best.y - best.h / 2, "t": 0.0}
			damageSlime(best, {"dmg": 2.2, "kb": 30, "up": 0, "style": 12, "anim": "laserDrone", "both": true})
			Sfx.tone(1700, 0.12, "sawtooth", 0.04, 500)
	if R.t > R.life:
		droneP = {}


func frontBusy() -> bool:
	return volcShots.size() > 0 or not droneP.is_empty()


func loadMap(id: String, px0 = null, py0 = null) -> void:
	droneP = {}
	super.loadMap(id, px0, py0)


# ================================================================ drawing

## the pose for this frame: where the feet and hands go (rig space), the lean and crouch
func _mk2Pose(e) -> Dictionary:
	var D: Dictionary = e.data
	var t: float = e.t
	var rt = realTime
	var w: float = D.walkT
	var walking: bool = absf(e.vx) > 5 and D.act in ["", "punch", "slash"]
	var p = {"lean": D.lean, "crouch": D.crouch * 12, "ff": Vector2(12, 0), "fb": Vector2(-12, 0), "hf": Vector2(42, -60 + sin(rt * 2) * 2), "hb": Vector2(-34, -58 + sin(rt * 2 + 1) * 2)}
	if walking:
		p.ff = Vector2(10 + sin(w) * 16, -maxf(0, cos(w)) * 9)
		p.fb = Vector2(-10 - sin(w) * 16, -maxf(0, -cos(w)) * 9)
		p.crouch = absf(sin(w)) * 3
		p.hf = Vector2(42 - sin(w) * 10, -62)
		p.hb = Vector2(-34 + sin(w) * 10, -60)
	var flying: bool = D.boots > 0.5 and e.y < groundAt(e.x) - 2
	if flying:
		p.ff = Vector2(14, -6 + sin(rt * 5) * 2)
		p.fb = Vector2(-10, -2 + sin(rt * 5 + 1) * 2)
		p.crouch = 6
	match D.act:
		"punch":
			if t < 0.45:
				p.hf = Vector2(42, -60).lerp(Vector2(-8, -104), easeOut(minf(1, t / 0.3)))
				p.lean = -0.08
			elif t < 0.75:
				p.hf = Vector2(-8, -104).lerp(Vector2(84, -96), easeOut(minf(1, (t - 0.45) / 0.08)))
				p.lean = 0.14
			else:
				p.hf = Vector2(84, -96).lerp(Vector2(42, -60), minf(1, (t - 0.75) / 0.3))
		"slash":
			var n = int(t / 0.42)
			var ct = fmod(t, 0.42)
			var up = n % 2 == 1
			var hi = Vector2(14, -180)
			var lo = Vector2(80, -30)
			var a0 = lo if up else hi
			var a1 = hi if up else lo
			if n >= 3:
				p.hf = Vector2(80, -30).lerp(Vector2(42, -60), minf(1, (t - 1.26) / 0.3))
			elif ct < 0.24:
				p.hf = p.hf.lerp(a0, easeOut(minf(1, ct / 0.2)))
				p.lean = -0.06
			else:
				p.hf = a0.lerp(a1, easeOut(minf(1, (ct - 0.24) / 0.08)))
				p.lean = 0.12
			p.hb = Vector2(-20, -100) if n != 2 else Vector2(60, -60)
		"kick":
			if t < 0.5:
				p.ff = Vector2(12, 0).lerp(Vector2(-4, -50), easeOut(minf(1, t / 0.35)))
				p.lean = -0.1
				p.hf = Vector2(30, -96)
				p.hb = Vector2(-44, -84)
			elif t < 0.8:
				p.ff = Vector2(-4, -50).lerp(Vector2(76, -58), easeOut(minf(1, (t - 0.5) / 0.08)))
				p.lean = -0.2
				p.hf = Vector2(14, -110)
				p.hb = Vector2(-50, -96)
			else:
				p.ff = Vector2(76, -58).lerp(Vector2(12, 0), minf(1, (t - 0.8) / 0.25))
		"slam":
			match D.ph:
				"crouch", "land":
					p.crouch = D.crouch * 14
					p.hf = Vector2(52, -14 + (1 - D.crouch) * -30)
					p.hb = Vector2(-30, -16 + (1 - D.crouch) * -30)
				"rise", "hang":
					p.hf = Vector2(30, -184)
					p.hb = Vector2(-20, -182)
				"dive":
					p.hf = Vector2(46, -20)
					p.hb = Vector2(-24, -22)
					p.ff = Vector2(14, -12)
		"bash":
			p.hf = Vector2(18, -86)
			p.hb = Vector2(-10, -80)
			if t > 0.55:
				p.ff = Vector2(30 + sin(rt * 30) * 6, -4)
				p.fb = Vector2(-26 - sin(rt * 30) * 6, -6)
		"transform":
			p.hf = Vector2(66, -96)
			p.hb = Vector2(-60, -96)
			p.crouch = 4
		"deploy":
			p.hf = Vector2(46, -70)
			p.hb = Vector2(-44, -70)
			p.lean = 0.12 * D.hatch
		"kickhold", "air":
			if D.hand.has("f") and _mk2Holding(e):
				p.hf = D.hand.f
			p.hb = Vector2(-36, -80)
	D.hand.f = p.hf
	D.foot.f = p.ff
	D.foot.b = p.fb
	return p


func drawBossKind(x: Ctx, e, X: float, Y: float) -> bool:
	if e.bossKind != "mk2":
		return super.drawBossKind(x, e, X, Y)
	var D: Dictionary = e.data
	var p = _mk2Pose(e)
	var a = 1.0
	if e.state == "dead" and not e.dying:
		a = clampf(1 - (e.deadT - 1.2) / 1.0, 0, 1)
	var sx: float = e.x - X
	var sy: float = e.y - Y
	if e.state == "intro" and D.hang:
		# the docking clamp's arms hold it by the shoulders
		x.fillStyle = "#2a2e38"
		x.fillRect(X - 52, Y - 150, 10, 30)
		x.fillRect(X + 42, Y - 150, 10, 30)
	x.save()
	x.globalAlpha = a
	_mk2Rig(x, X, Y, e.face, p, D, e.hurtFlash > 0)
	x.restore()
	# the drone
	if not D.drone.is_empty():
		_drawDrone(x, D.drone.x - sx, D.drone.y - sy, D.drone.t, D.drone.aimT >= 0)
		if D.drone.aimT >= 0:
			var o = Vector2(D.drone.x - sx, D.drone.y - sy)
			var dir = (D.drone.aim - Vector2(D.drone.x, D.drone.y)).normalized()
			x.strokeStyle = rgba(255, 40, 58, 0.25 + 0.5 * minf(1, D.drone.aimT / 0.6) * absf(sin(D.drone.aimT * 30)))
			x.lineWidth = 0.7
			x.beginPath(); x.moveTo(o.x, o.y); x.lineTo(o.x + dir.x * 400, o.y + dir.y * 400); x.stroke()
	# the kick's tell: the foot glows
	if D.act == "kick" and e.t < 0.5:
		var ft = Vector2(X + p.ff.x * e.face, Y + p.ff.y - p.crouch * 0)
		var g = x.createRadialGradient(ft.x, ft.y - 4, 1, ft.x, ft.y - 4, 18)
		g.addColorStop(0, rgba(255, 170, 50, 0.6 * minf(1, e.t / 0.3))); g.addColorStop(1, rgba(255, 170, 50, 0))
		x.fillStyle = g; x.beginPath(); x.arc(ft.x, ft.y - 4, 18, 0, TAU); x.fill()
	return true


func _seg(x: Ctx, a: Vector2, b: Vector2, w1: float, w2: float, fill, edge) -> void:
	var d = (b - a).normalized()
	var n = Vector2(-d.y, d.x)
	x.fillStyle = fill
	x.beginPath()
	x.moveTo(a.x + n.x * w1, a.y + n.y * w1)
	x.lineTo(b.x + n.x * w2, b.y + n.y * w2)
	x.lineTo(b.x - n.x * w2, b.y - n.y * w2)
	x.lineTo(a.x - n.x * w1, a.y - n.y * w1)
	x.closePath()
	x.fill()
	if edge != null:
		x.strokeStyle = edge
		x.lineWidth = 0.8
		x.stroke()


## two-bone reach: from `a` toward `t`, bending to `side`; returns [joint, end]
func _ik(a: Vector2, t: Vector2, l1: float, l2: float, side: float) -> Array:
	var v = t - a
	var d = clampf(v.length(), 4.0, l1 + l2 - 0.5)
	var dir = v.normalized() if v.length() > 0.01 else Vector2(0, 1)
	var end = a + dir * d
	var c = clampf((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
	var ang = atan2(dir.y, dir.x) + side * acos(c)
	return [a + Vector2(cos(ang), sin(ang)) * l1, end]


## the whole machine, facing right in its own space, then flipped to `face`
func _mk2Rig(x: Ctx, X: float, Y: float, face: int, p: Dictionary, D: Dictionary, flash: bool) -> void:
	var C = MK2_COL
	var rt = realTime
	x.translate(X, Y)
	var fall: float = D.get("fall", 0.0)
	if fall > 0:
		# it topples forward onto its knees, then flat
		x.translate(face * 30 * fall, 0)
		x.rotate(face * fall * 1.2)
	x.scale(face, 1)
	var cy: float = p.crouch
	var lean: float = p.lean
	# the upper body leans around the hips
	var hipF = MK2_HIP_F + Vector2(0, cy)
	var hipB = MK2_HIP_B + Vector2(0, cy)
	var pivot = Vector2(0, -64 + cy)
	var up = func(v: Vector2) -> Vector2: return pivot + (v + Vector2(0, cy) - pivot).rotated(lean)
	var shF: Vector2 = up.call(MK2_SH_F)
	var shB: Vector2 = up.call(MK2_SH_B)
	var dark = C.dark
	var base = C.base if not flash else "#9aa2b2"
	var mid = C.mid if not flash else "#c8d0dc"
	var light = C.light if not flash else "#ffffff"
	# ---- the far side: back leg, back arm, the launcher
	_mk2Leg(x, hipB, p.fb, "#2a2f3a", "#3a404e", D.boots, rt)
	var ab = _ik(shB, p.hb, MK2_ARM, MK2_ARM, 1.0)
	_seg(x, shB, ab[0], 9, 8, "#2a2f3a", dark)
	_seg(x, ab[0], ab[1], 8, 9, "#323846", dark)
	x.fillStyle = "#2a2f3a"; x.beginPath(); x.arc(ab[1].x, ab[1].y, 10, 0, TAU); x.fill()
	x.strokeStyle = dark; x.lineWidth = 0.8; x.stroke()
	if D.get("blade", 0.0) > 0:
		_mk2Blade(x, ab[0], ab[1], D.blade * 0.8, true)
	# grenade launcher pod on the back shoulder
	var pod: Vector2 = up.call(Vector2(-30, -142))
	x.save(); x.translate(pod.x, pod.y); x.rotate(lean - 0.35)
	x.fillStyle = "#2a2e38"; x.fillRect(-16, -8, 28, 18)
	x.fillStyle = base; x.fillRect(-14, -10, 26, 16)
	x.fillStyle = light; x.fillRect(-14, -10, 26, 2)
	for i in 3:
		x.fillStyle = dark; x.beginPath(); x.arc(-8 + i * 8, -10, 3, 0, TAU); x.fill()
		x.fillStyle = "#ff8a2a" if D.get("nadeT", 5.0) < 0.6 and i == 1 else "#3a2a20"; x.beginPath(); x.arc(-8 + i * 8, -10, 1.6, 0, TAU); x.fill()
	x.fillStyle = C.hazard; x.fillRect(-14, 2, 26, 3)
	x.fillStyle = dark
	for i in 4:
		x.beginPath(); x.moveTo(-12 + i * 7, 2); x.lineTo(-9 + i * 7, 2); x.lineTo(-11 + i * 7, 5); x.lineTo(-14 + i * 7, 5); x.closePath(); x.fill()
	x.restore()
	# ---- the hips and the back hatch (the drone lives in there)
	x.fillStyle = dark; x.fillRect(-20, -72 + cy, 40, 14)
	x.fillStyle = base; x.fillRect(-18, -71 + cy, 36, 11)
	x.fillStyle = mid; x.fillRect(-18, -71 + cy, 36, 2)
	# ---- the near leg
	_mk2Leg(x, hipF, p.ff, base, mid, D.boots, rt)
	# ---- the torso
	x.save()
	x.translate(pivot.x, pivot.y); x.rotate(lean); x.translate(-pivot.x, -pivot.y)
	x.translate(0, cy)
	if D.get("hatch", 0.0) > 0:
		var hk: float = D.hatch
		x.fillStyle = "#0a0a0e"; x.fillRect(-40, -132, 10, 26)
		x.fillStyle = mid; x.fillRect(-40 - 10 * hk, -134 - 6 * hk, 10, 28)
	# the chest: a heavy wedge of plate
	x.fillStyle = dark
	x.beginPath(); x.moveTo(-32, -64); x.lineTo(30, -64); x.lineTo(40, -100); x.lineTo(36, -132); x.lineTo(-34, -134); x.lineTo(-40, -100); x.closePath(); x.fill()
	var cg = x.createLinearGradient(0, -134, 0, -64)
	cg.addColorStop(0, light); cg.addColorStop(0.35, mid); cg.addColorStop(1, base)
	x.fillStyle = cg
	x.beginPath(); x.moveTo(-30, -66); x.lineTo(28, -66); x.lineTo(37, -100); x.lineTo(34, -130); x.lineTo(-32, -132); x.lineTo(-37, -100); x.closePath(); x.fill()
	# plate seams, rivets and a hazard stripe across the belly
	x.strokeStyle = dark; x.lineWidth = 0.8
	x.beginPath(); x.moveTo(-36, -100); x.lineTo(36, -100); x.moveTo(2, -130); x.lineTo(2, -100); x.stroke()
	x.fillStyle = C.hazard; x.fillRect(-28, -78, 54, 6)
	x.fillStyle = dark
	for i in 8:
		x.beginPath(); x.moveTo(-28 + i * 7, -72); x.lineTo(-24 + i * 7, -78); x.lineTo(-21 + i * 7, -78); x.lineTo(-25 + i * 7, -72); x.closePath(); x.fill()
	x.fillStyle = light
	for i in 5:
		x.fillRect(-28 + i * 13, -126, 1.5, 1.5)
	# the mana core: Glamrax's magic in a glass heart
	var pulse = 0.6 + 0.4 * sin(rt * 5)
	x.fillStyle = "#0e0814"; x.beginPath(); x.arc(-6, -114, 9, 0, TAU); x.fill()
	var mg = x.createRadialGradient(-6, -114, 1, -6, -114, 9)
	mg.addColorStop(0, rgba(255, 220, 255, pulse)); mg.addColorStop(0.5, Color(css(C.mana), 0.9 * pulse)); mg.addColorStop(1, Color(css(C.mana), 0.1))
	x.fillStyle = mg; x.beginPath(); x.arc(-6, -114, 8, 0, TAU); x.fill()
	x.strokeStyle = light; x.lineWidth = 1.2; x.beginPath(); x.arc(-6, -114, 9, 0, TAU); x.stroke()
	# vents
	x.fillStyle = dark
	for i in 3:
		x.fillRect(12, -122 + i * 5, 16, 2)
	# the head: a squat armoured cockpit with one long red visor
	x.fillStyle = dark
	x.beginPath(); x.moveTo(-14, -132); x.lineTo(20, -132); x.lineTo(24, -146); x.lineTo(14, -154); x.lineTo(-10, -154); x.lineTo(-16, -146); x.closePath(); x.fill()
	x.fillStyle = mid
	x.beginPath(); x.moveTo(-12, -133); x.lineTo(19, -133); x.lineTo(22, -146); x.lineTo(13, -152); x.lineTo(-9, -152); x.lineTo(-14, -146); x.closePath(); x.fill()
	x.fillStyle = light; x.fillRect(-8, -152, 20, 2)
	var vis: float = D.get("visor", 1.0)
	x.fillStyle = "#1a0408"; x.fillRect(-2, -145, 25, 5)
	if vis > 0:
		var vg = x.createRadialGradient(16, -142, 1, 16, -142, 22)
		vg.addColorStop(0, rgba(255, 40, 58, 0.55 * vis)); vg.addColorStop(1, rgba(255, 40, 58, 0))
		x.fillStyle = vg; x.beginPath(); x.arc(16, -142, 22, 0, TAU); x.fill()
		x.fillStyle = Color(css(C.red), vis); x.fillRect(0, -144, 23, 3)
		var sc = fmod(rt * 1.6, 1.0)
		x.fillStyle = rgba(255, 220, 220, vis); x.fillRect(1 + sc * 19, -144, 3, 3)
	# antenna
	x.strokeStyle = dark; x.lineWidth = 1
	x.beginPath(); x.moveTo(-6, -154); x.lineTo(-10, -166); x.stroke()
	x.fillStyle = C.red if fmod(rt, 1.0) < 0.5 else "#5a1018"; x.fillRect(-11, -168, 3, 3)
	x.restore()
	# ---- the near arm and its pauldron with the rifle
	var af = _ik(shF, p.hf, MK2_ARM, MK2_ARM, 1.0)
	_seg(x, shF, af[0], 10, 9, base, dark)
	x.fillStyle = mid; x.beginPath(); x.arc(af[0].x, af[0].y, 7, 0, TAU); x.fill()
	x.strokeStyle = dark; x.lineWidth = 0.8; x.stroke()
	_seg(x, af[0], af[1], 9, 11, mid, dark)
	# a hazard band on the forearm
	var fm = af[0].lerp(af[1], 0.55)
	x.fillStyle = C.hazard; x.beginPath(); x.arc(fm.x, fm.y, 4, 0, TAU); x.fill()
	if D.get("blade", 0.0) > 0:
		_mk2Blade(x, af[0], af[1], D.blade, false)
	# the fist
	x.fillStyle = dark; x.beginPath(); x.arc(af[1].x, af[1].y, 11.5, 0, TAU); x.fill()
	x.fillStyle = base; x.beginPath(); x.arc(af[1].x, af[1].y, 10, 0, TAU); x.fill()
	x.fillStyle = light; x.beginPath(); x.arc(af[1].x - 2, af[1].y - 3, 4, 0, TAU); x.fill()
	x.fillStyle = dark
	var kd = (af[1] - af[0]).normalized()
	for i in 3:
		var kp = af[1] + kd * 6 + Vector2(-kd.y, kd.x) * (i - 1) * 5
		x.fillRect(kp.x - 1, kp.y - 1, 2, 2)
	# the pauldron
	var pd = shF + Vector2(2, -2)
	x.fillStyle = dark; x.beginPath(); x.ellipse(pd.x, pd.y, 19, 15, lean, 0, TAU); x.fill()
	var pg = x.createLinearGradient(pd.x, pd.y - 15, pd.x, pd.y + 15)
	pg.addColorStop(0, light); pg.addColorStop(1, base)
	x.fillStyle = pg; x.beginPath(); x.ellipse(pd.x, pd.y, 17.5, 13.5, lean, 0, TAU); x.fill()
	x.fillStyle = C.hazard; x.fillRect(pd.x - 12, pd.y + 4, 24, 3)
	# the shoulder rifle, turned toward you
	var gp: Vector2 = up.call(MK2_GUN)
	x.save(); x.translate(gp.x, gp.y); x.rotate(D.get("gunAng", 0.0))
	x.fillStyle = dark; x.fillRect(-10, -6, 36, 11)
	x.fillStyle = mid; x.fillRect(-9, -5, 34, 9)
	x.fillStyle = light; x.fillRect(-9, -5, 34, 2)
	x.fillStyle = dark; x.fillRect(24, -3, 22, 4); x.fillRect(42, -4, 4, 6)
	x.fillStyle = "#b8862a"
	for i in 4:
		x.fillRect(-6 + i * 4, 4, 2, 4 + (i % 2))   # the ammo belt
	if D.get("flash", 0.0) > 0:
		x.fillStyle = "#fff6c0"; x.beginPath(); x.moveTo(46, -1); x.lineTo(58, -5); x.lineTo(54, -1); x.lineTo(60, 3); x.lineTo(46, 2); x.closePath(); x.fill()
		x.fillStyle = rgba(255, 210, 120, 0.5); x.beginPath(); x.arc(50, 0, 8, 0, TAU); x.fill()
	x.restore()


func _mk2Leg(x: Ctx, hip: Vector2, foot: Vector2, col, edge, boots: float, rt: float) -> void:
	var k = _ik(hip, foot + Vector2(0, -7), MK2_LEG, MK2_LEG, -1.0)
	_seg(x, hip, k[0], 10, 8, col, MK2_COL.dark)
	x.fillStyle = edge; x.beginPath(); x.arc(k[0].x, k[0].y, 7, 0, TAU); x.fill()
	x.strokeStyle = MK2_COL.dark; x.lineWidth = 0.8; x.stroke()
	_seg(x, k[0], k[1], 8, 7, col, MK2_COL.dark)
	# the boot: a heavy wedge with a rocket under the heel
	var f: Vector2 = k[1]
	x.fillStyle = MK2_COL.dark
	x.beginPath(); x.moveTo(f.x - 12, f.y - 4); x.lineTo(f.x + 6, f.y - 6); x.lineTo(f.x + 18, f.y + 5); x.lineTo(f.x + 18, f.y + 8); x.lineTo(f.x - 13, f.y + 8); x.closePath(); x.fill()
	x.fillStyle = col
	x.beginPath(); x.moveTo(f.x - 11, f.y - 3); x.lineTo(f.x + 5, f.y - 5); x.lineTo(f.x + 16, f.y + 5); x.lineTo(f.x - 11, f.y + 6); x.closePath(); x.fill()
	x.fillStyle = MK2_COL.hazard; x.fillRect(f.x + 2, f.y + 3, 12, 2)
	x.fillStyle = "#1a1c22"; x.fillRect(f.x - 10, f.y + 7, 8, 3)
	if boots > 0:
		var fl = (10 + sin(rt * 40) * 3) * boots
		var gr = x.createLinearGradient(f.x - 6, f.y + 9, f.x - 6, f.y + 9 + fl)
		gr.addColorStop(0, rgba(255, 255, 220, 0.95)); gr.addColorStop(0.4, rgba(255, 160, 50, 0.85)); gr.addColorStop(1, rgba(255, 60, 20, 0))
		x.fillStyle = gr
		x.beginPath(); x.moveTo(f.x - 10, f.y + 9); x.lineTo(f.x - 2, f.y + 9); x.lineTo(f.x - 6, f.y + 9 + fl); x.closePath(); x.fill()


## the arm blades: they slide out of the forearm past the fist
func _mk2Blade(x: Ctx, elbow: Vector2, hand: Vector2, k: float, far: bool) -> void:
	var d = (hand - elbow).normalized()
	var n = Vector2(-d.y, d.x)
	var root = elbow.lerp(hand, 0.3)
	var tip = hand + d * (8 + 52 * k)
	x.fillStyle = "#8a92a2" if far else MK2_COL.steel
	x.beginPath()
	x.moveTo(root.x + n.x * 3, root.y + n.y * 3)
	x.lineTo(tip.x + n.x * 1, tip.y + n.y * 1)
	x.lineTo(tip.x + d.x * 6, tip.y + d.y * 6)
	x.lineTo(root.x - n.x * 5, root.y - n.y * 5)
	x.closePath()
	x.fill()
	x.strokeStyle = rgba(255, 60, 70, 0.8 * k) if not far else rgba(255, 60, 70, 0.4 * k)
	x.lineWidth = 1
	x.beginPath(); x.moveTo(root.x + n.x * 3, root.y + n.y * 3); x.lineTo(tip.x + n.x, tip.y + n.y); x.lineTo(tip.x + d.x * 6, tip.y + d.y * 6); x.stroke()


func _drawDrone(x: Ctx, X: float, Y: float, t: float, aiming: bool) -> void:
	x.save()
	x.translate(X, Y + sin(t * 6) * 1)
	# rotors
	x.fillStyle = rgba(200, 210, 220, 0.4)
	for s in [-1, 1]:
		x.beginPath(); x.ellipse(s * 10, -6, 7 * absf(sin(t * 40 + s)), 1.4, 0, 0, TAU); x.fill()
	x.fillStyle = MK2_COL.dark; x.fillRect(-11, -7, 22, 2)
	x.fillStyle = MK2_COL.dark; x.beginPath(); x.ellipse(0, 0, 9, 6, 0, 0, TAU); x.fill()
	x.fillStyle = MK2_COL.mid; x.beginPath(); x.ellipse(0, -1, 8, 4.5, 0, 0, TAU); x.fill()
	x.fillStyle = MK2_COL.hazard; x.fillRect(-6, 2, 12, 1.5)
	var c = rgba(255, 40, 58, 1.0 if aiming else 0.7)
	x.fillStyle = c; x.beginPath(); x.arc(0, 2, 2.4, 0, TAU); x.fill()
	if aiming:
		var g = x.createRadialGradient(0, 2, 1, 0, 2, 10)
		g.addColorStop(0, rgba(255, 40, 58, 0.6)); g.addColorStop(1, rgba(255, 40, 58, 0))
		x.fillStyle = g; x.beginPath(); x.arc(0, 2, 10, 0, TAU); x.fill()
	x.restore()


## the Mk II for a card, a portrait or the bestiary: standing tall, rifle up
func drawBossPortrait(x: Ctx, kind: String, X: float, Y: float, w: float, h: float, angry: bool) -> bool:
	if kind != "mk2":
		return super.drawBossPortrait(x, kind, X, Y, w, h, angry)
	var sc = minf(w / 120.0, h / 176.0)
	var D = {"visor": 1.0, "gunAng": -0.12 if not angry else 0.0, "flash": 0.05 if angry and fmod(realTime, 0.14) < 0.07 else 0.0, "blade": 1.0 if angry else 0.0, "boots": 0.0, "nadeT": 5.0}
	var p = {"lean": 0.04 if angry else 0.0, "crouch": 2.0 if angry else 0.0, "ff": Vector2(14, 0), "fb": Vector2(-14, 0), "hf": Vector2(66, -96) if angry else Vector2(42, -60), "hb": Vector2(-50, -92) if angry else Vector2(-34, -58)}
	x.save()
	x.translate(X + w / 2 - 4 * sc, Y + h - 4 * sc)
	x.scale(sc, sc)
	_mk2Rig(x, 0, 0, 1, p, D, false)
	x.restore()
	return true


## the Mechabox: gunmetal and hazard stripes, a red light blinking on the lid
func drawBossBoxKind(x: Ctx, kind: String, X: float, Y: float, tt: float) -> bool:
	if kind != "mk2":
		return super.drawBossBoxKind(x, kind, X, Y, tt)
	var g2 = 0.5 + 0.5 * sin(tt * 3)
	x.fillStyle = rgba(255, 160, 60, 0.25 * g2); x.fillRect(X - 13, Y - 21, 26, 22)
	x.fillStyle = "#14161d"; x.fillRect(X - 10, Y - 16, 20, 16)
	x.fillStyle = "#575f6e"; x.fillRect(X - 9, Y - 15, 18, 14)
	x.fillStyle = "#8a93a3"; x.fillRect(X - 9, Y - 15, 18, 2)
	x.fillStyle = "#14161d"; x.fillRect(X - 9, Y - 10, 18, 1)
	x.fillStyle = "#e8b830"; x.fillRect(X - 9, Y - 5, 18, 3)
	x.fillStyle = "#14161d"
	for i in 4:
		x.fillRect(X - 8 + i * 5, Y - 5, 2, 3)
	x.fillStyle = "#ff2a3a" if fmod(tt, 1.0) < 0.5 else "#5a1018"; x.fillRect(X - 1, Y - 14, 3, 2)
	if randf() < 0.1:
		part(X + cam.x + rand(-10, 10), Y + cam.y - rand(4, 18), rand(-20, 20), -rand(10, 40), 0.4, "#ffd27a", 200, 1)
	return true


func drawTrophyKind(x: Ctx, id: String, X: float, Y: float) -> bool:
	if id != "mk2":
		return super.drawTrophyKind(x, id, X, Y)
	# a golden mecha head with a ruby visor
	x.fillStyle = "#ffd35a"; x.fillRect(X - 6, Y - 33, 12, 10); x.fillRect(X - 7, Y - 28, 14, 5)
	x.fillStyle = "#c89418"; x.fillRect(X - 6, Y - 25, 12, 2); x.fillRect(X - 3, Y - 37, 1, 4)
	x.fillStyle = "#ff2a3a"; x.fillRect(X - 4, Y - 30, 9, 2)
	return true


## in front of everything: grenades and their blasts, blade arcs, the slam's shockwave, the hero's own drone
func drawMk2Front(x: Ctx, sx: float, sy: float) -> void:
	for s in volcShots:
		var X = s.x - sx
		var Y = s.y - sy
		match s.kind:
			"nade":
				x.save(); x.translate(X, Y); x.rotate(s.spin)
				x.fillStyle = "#2a2e38"; x.fillRect(-3, -2, 6, 4)
				x.fillStyle = "#e8b830"; x.fillRect(-1, -2, 1.5, 4)
				x.restore()
				x.fillStyle = "#ff2a3a" if fmod(s.t, 0.2) < 0.1 else "#5a1018"; x.fillRect(X - 0.5, Y - 3, 1, 1)
			"boom":
				var k = s.t / 0.45
				var r = s.r * (0.4 + 0.8 * easeOut(minf(1, k * 2)))
				var g = x.createRadialGradient(X, Y, 1, X, Y, r)
				g.addColorStop(0, rgba(255, 250, 210, 0.95 * (1 - k))); g.addColorStop(0.35, rgba(255, 150, 40, 0.8 * (1 - k))); g.addColorStop(1, rgba(120, 30, 20, 0))
				x.fillStyle = g; x.beginPath(); x.arc(X, Y, r, 0, TAU); x.fill()
			"arc":
				var k = s.t / 0.2
				var f: int = s.face
				x.strokeStyle = rgba(255, 240, 240, 0.9 * (1 - k)); x.lineWidth = 4 if s.big else 2.5
				x.beginPath()
				var a0 = -1.6 if not s.up else 1.2
				var a1 = 1.2 if not s.up else -1.6
				for i in 9:
					var a = lerpf(a0, a1, i / 8.0 * minf(1, k * 3))
					var px = X + f * cos(a) * 62
					var py = Y + sin(a) * 62
					if i == 0:
						x.moveTo(px, py)
					else:
						x.lineTo(px, py)
				x.stroke()
				x.strokeStyle = rgba(255, 60, 70, 0.5 * (1 - k)); x.lineWidth = 8 if s.big else 5
				x.stroke()
			"wave":
				var k = s.t / 0.55
				x.fillStyle = rgba(255, 220, 160, 0.6 * (1 - k))
				x.beginPath(); x.ellipse(X, Y - 3, 16, 6 * (1 - k) + 2, 0, 0, TAU); x.fill()
				for i in 3:
					x.fillStyle = rgba(200, 190, 200, 0.7 * (1 - k))
					x.fillRect(X - s.dir * i * 6, Y - 4 - hsh(i + floorf(s.t * 20)) * 8, 2, 2)
	if not droneP.is_empty():
		_drawDrone(x, droneP.x - sx, droneP.y - sy, droneP.t, not droneP.beam.is_empty())
		if not droneP.beam.is_empty():
			var k = 1 - droneP.beam.t / 0.15
			x.strokeStyle = rgba(255, 60, 70, 0.9 * k); x.lineWidth = 2.5
			x.beginPath(); x.moveTo(droneP.x - sx, droneP.y - sy + 2); x.lineTo(droneP.beam.x - sx, droneP.beam.y - sy); x.stroke()
			x.strokeStyle = rgba(255, 255, 255, k); x.lineWidth = 0.8
			x.stroke()
