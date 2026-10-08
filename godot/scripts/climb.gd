extends "res://scripts/tank.gd"
## Sproutvale, part 6¾: the climb to the Abyssal Volcano (made for the Godot version). Four maps
## up the mountain (Coldstone Foothills, Whiteout Ridge, Icefang Cave, King Yeti's Throne), their
## six monsters, King Yeti's fight and cutscenes, the Yetibox, the glowing pendant, and Glamrax's
## Gate on the volcano's peak.
##
## Maps and monster stats live in res://data/climb.json; art in res://art/climb (same layout as art/).

## King Yeti: the boss of the throne room at the back of the cave
const YETI_T := {"name": "King Yeti", "lv": 95, "hp": 200000, "atk": 300, "def": 85, "exp": 140000, "coins": [4000, 6500],
	"color": 0xe8eef6, "critter": false, "matName": "King's Fur"}
const CLIMB_MOBS := ["boulder", "lizard", "golem", "warlock", "yeti", "sword"]
const YT_SWORD_LEN := 118.0      # the King's sword, grip to tip (world units)
const YT_STALS := [150.0, 262.0, 378.0, 486.0]   # where the big stalactites hang from the throne room's ceiling
const YT_STAL_W := 16.0
const YT_STAL_LEN := 52.0
const RUIN_FLOOR := [[20, 150, 270], [150, 210, 260], [210, 430, 270], [430, 500, 256], [500, 620, 270]]

var climbShots: Array = []   # the warlocks' spells, the King's boulders
var stalFalls: Array = []    # stalactites shaken loose from the cave roof
var Yeti := {"introDone": false}
var dripT := 0.0
var _yetiArt := {}


# ================================================================ data

func initClimbData() -> void:
	var A: Dictionary = normalize(Assets._json("res://data/climb.json"))
	for id in A.maps:
		MAPS[id] = A.maps[id]
	for k in A.mobs:
		var T: Dictionary = A.mobs[k]
		T.merge({"aggro": 14, "size": 1, "w": 0, "unlock": T.lv, "critter": true, "ai": "climb", "habitat": "climb", "residue": T.matName}, false)
		SLIME_TYPES[k] = T
	SLIME_TYPES.golem.kb = 0.2
	SLIME_TYPES.yeti.kb = 0.3
	SLIME_TYPES.boulder.kb = 0.5
	SLIME_KEYS = SLIME_TYPES.keys()
	MAPS.climb4.collapsed = false
	# out of the bubble: the way up the mountain
	var B: Dictionary = MAPS.bubble
	if not B.portals.any(func(p): return p.to == "climb1"):
		B.portals.append({"x": B.w - 40, "to": "climb1", "tx": 80, "ty": MAPS.climb1.floorY, "label": "Out of the Abyss"})
	BOSS_LIST[3] = {"id": "kingYeti", "name": "King Yeti", "where": "King Yeti's Throne"}
	TROPHIES[3] = {"id": "kingYeti", "name": "King Yeti Trophy"}
	MAINQS.append({"title": "King Yeti", "exp": 70000, "coins": 40000,
		"steps": ["Leave the bubble and climb the Coldstone Foothills", "Find the cave beyond Whiteout Ridge", "Defeat King Yeti"], "on": ["climb1", "climb3", "kingYeti"],
		"blurb": "Out of the Abyss at last, with the Dream Key in your pocket. The Abyssal Volcano looms over the mountain, and something big lives in the ice cave on the way up."})
	for k in CLIMB_MOBS:
		BEST_ORDER.append(k)
	BEST_ORDER.append("kingYeti")
	BEST_TEXT.boulder = "A small boulder with a pair of human eyes in it, rolling back and forth across the foothills. When it sees you, it floats up into the air and throws itself at you."
	BEST_TEXT.lizard = "A lizard on two legs with a long whip. It lashes from a distance, somersaults right over your head, and sometimes cracks the whip at you while it's upside down."
	BEST_TEXT.golem = "A golem of rocky snow with glowing gemstone eyes and a club made of bone. Slow, but its swings hit hard enough to send you flying, and it shrugs off a lot of punishment."
	BEST_TEXT.warlock = "A robed lizardman with a staff. It blinks around you and casts: violet circles that erupt under your feet, and bolts that chase you. Fragile, but its spells hit very hard."
	BEST_TEXT.yeti = "Twice your height and all muscle. Fast, hardy and vicious: it swipes, and leaps up to slam the ground, which shakes stalactites loose from the cave roof."
	BEST_TEXT.sword = "A two-handed sword that flies by itself, trailing glitter. It stabs straight at you or swings in a wide arc, and it moves very fast."
	BEST_TEXT.kingYeti = "The king of the ice cave, who sits on a throne of bones and wears a glowing pendant. He throws his enchanted sword faster than you can see, slams people into the ceiling, and fights even harder without it."
	MAT_TIPS.boulder = "A pebble chipped off a Cursed Boulder. It's still looking at you."
	MAT_TIPS.lizard = "A strip of whip leather, worn smooth by a lizardman's grip."
	MAT_TIPS.golem = "One of a Snow Golem's eyes. It never stops glowing."
	MAT_TIPS.warlock = "A violet scale that tingles with leftover magic."
	MAT_TIPS.yeti = "A tuft of cursed fur, white with violet roots. It's freezing to the touch."
	MAT_TIPS.sword = "A shard of an enchanted blade. It glitters even in the dark."
	# the climb sits above the Abyss on the world map (negative y: the map grows upward for it)
	WM_NODES.climb1 = {"x": 190, "y": -52}
	WM_NODES.climb2 = {"x": 320, "y": -94}
	WM_NODES.climb3 = {"x": 452, "y": -122}
	WM_NODES.climb4 = {"x": 590, "y": -146}
	WM_NODES.peak = {"x": 735, "y": -150}
	MAPS.trophy.w = maxi(int(MAPS.trophy.w), 2060)   # room for the climb's cards on the wall


func climbMap() -> bool:
	return not M.is_empty() and M.get("theme") in ["climb", "snow", "cave", "peak"]


func caveMap() -> bool:
	return not M.is_empty() and M.get("theme") == "cave"


## the cave roof above x (very high where there isn't one)
func ceilAt(x: float) -> float:
	if M.get("ceilY") != null:
		return float(M.ceilY)
	if M.get("ceil") != null:
		return groundAt(x) - float(M.ceil)
	return -1e9


func yetiArt() -> Dictionary:
	if _yetiArt.is_empty():
		var path = "res://art/climb/boss/yeti.json"
		_yetiArt = Assets._json(path) if FileAccess.file_exists(path) else {"w": 320, "h": 280, "ax": 160, "ay": 272, "keys": {}, "hand": {}, "neck": {}, "swordGrip": [34, 28]}
	return _yetiArt


# ================================================================ walking up the mountain

## small steps are walked up (the climb maps rise in little steps); bigger ledges are jumped
func seaCollide(prevX: float, prevY: float) -> void:
	var su = M.get("stepUp")
	if su != null and not M.get("sea"):
		var g = groundAt(P.x)
		var gp = groundAt(prevX)
		if P.y > g + 0.5 and P.y - g <= float(su) and P.vy >= -1 and (P.grounded or prevY <= gp + 0.5) and P.state != "held":
			P.y = g
			P.vy = 0
			var s = findSurf(func(q): return q.floor and P.x >= q.x0 - 0.5 and P.x <= q.x1 + 0.5 and absf(q.y - g) < 1)
			if s != null:
				P.surf = s
				P.grounded = true
			return
	super.seaCollide(prevX, prevY)


# ================================================================ monsters: spawning

func spawnAbyssMob(type: String, T: Dictionary, initial: bool, shiny: bool) -> void:
	if T.get("ai") != "climb":
		super.spawnAbyssMob(type, T, initial, shiny)
		return
	var e = _newMob(type, T, 0, 0, null)
	var floors = surfaces.filter(func(q): return q.floor and q.x1 - q.x0 > 30)
	var x = 0.0
	var s = null
	for guard in 24:
		var wt = 0.0
		for q in floors:
			wt += q.x1 - q.x0
		var pk = randf() * wt
		s = floors[0]
		for q in floors:
			pk -= q.x1 - q.x0
			if pk <= 0:
				s = q
				break
		x = rand(s.x0 + 10, s.x1 - 10)
		if (absf(x - P.x) > 150 or absf(s.y - P.y) > 90) and x > 140 and x < M.w - 100:
			break
	e.x = x
	e.y = s.y
	e.surf = s
	e.homeX = x
	e.homeY = s.y - (rand(40, 70) if T.get("fly") else 0.0)
	if T.get("fly"):
		e.y = e.homeY
	e.w = float(T.bw)
	e.h = float(T.bh)
	e.face = -1 if randf() < 0.5 else 1
	e.t = rand(0, 2)
	e.hopCd = rand(0.5, 2)
	e.atkCd = rand(1, 2.5)
	e.spawnT = 0.0 if initial else 0.5
	e.data = {"cd2": rand(3, 7), "ang": 0.0, "spin": 0.0}
	if shiny:
		makeShiny(e)
	slimes.append(e)


func abyssElite(e) -> void:
	if e.T.get("ai") != "climb":
		super.abyssElite(e)
		return
	var sc: float = e.T.get("eliteScale", 2.0)
	e.w = e.T.bw * sc
	e.h = e.T.bh * sc
	e.data = {"cd2": rand(3, 6), "ang": 0.0, "spin": 0.0, "scale": sc}
	if e.T.get("fly"):
		e.homeX = e.x
		e.homeY = e.y - 50
		e.y = e.homeY


# ================================================================ monsters: behaviour

## every climb monster runs through here (crimsonAI hands them over); returns true (it moves them itself)
func climbAI(e, T: Dictionary, dt: float, _dx: float, _dy: float, pb: Dictionary) -> bool:
	var cx: float = e.x
	var cy: float = e.y - e.h / 2
	var tx: float = P.x - cx
	var ty: float = (P.y - 20) - cy
	var dist = sqrt(tx * tx + ty * ty)
	var sight: float = {"yeti": 230.0, "warlock": 220.0, "sword": 220.0, "lizard": 190.0}.get(e.type, 170.0)
	var alive: bool = P.state != "dead"
	if e.state == "idle" and alive and dist < sight and e.spawnT <= 0:
		e.aggro = true; e.bang = 0.8
		_setState(e, "chase")
		if absf(tx) < 140:
			Sfx.bang()
	if e.state == "chase" and (not alive or dist > sight * 1.8):
		e.aggro = false
		_setState(e, "idle")
	e.data.cd2 = e.data.get("cd2", 5.0) - dt
	if e.state == "hurt":
		e.stun -= dt
		if T.get("fly"):
			e.vx *= exp(-dt * 3.5)
			e.vy *= exp(-dt * 3.5)
			e.data.ang = damp(e.data.ang, 0.0, 4, dt)
		if e.stun <= 0:
			_setState(e, "chase")
			e.aggro = true
			e.atkCd = maxf(e.atkCd, 0.5)
	else:
		match e.type:
			"boulder": _boulder(e, T, dt, tx, ty, dist)
			"lizard": _lizard(e, T, dt, tx, ty, dist)
			"golem": _golem(e, T, dt, tx, ty, dist)
			"warlock": _warlock(e, T, dt, tx, ty, dist)
			"yeti": _cyeti(e, T, dt, tx, ty, dist)
			"sword": _esword(e, T, dt, tx, ty, dist)
	# bumping into an awake monster still hurts a little
	if e.aggro and alive and not (e.state in ["hurt", "act"]) and overlap(sBox(e), pb) and P.touchCd <= 0:
		P.touchCd = 0.9
		hurtPlayer(e, roundf(e.atk * 0.5))
	_climbPhysics(e, T, dt)
	return true


## walkers follow the stepped ground: little steps are walked up, ledges turn them round,
## and anything thrown up in the air comes back down onto whatever ground is under it
func _climbPhysics(e, T: Dictionary, dt: float) -> void:
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
				return
	if T.get("fly"):
		e.x = clampf(e.x + e.vx * dt, 30, M.w - 30)
		var g = groundAt(e.x)
		e.y = clampf(e.y + e.vy * dt, maxf(30.0, ceilAt(e.x) + 20), g - 6)
		e.surf = floorSurfAt(e.x)
		e.sq += (0 - e.sq) * minf(1, dt * 10)
		return
	if e.data.get("free", false):   # a boulder flying through the air under its own power
		e.surf = floorSurfAt(e.x)
		return
	var g0 = groundAt(e.x)
	var grounded: bool = e.y >= g0 - 0.5 and e.vy >= 0
	if e.state in ["idle", "chase"] and grounded:
		e.vx = damp(e.vx, e.walk, 10, dt)
	e.vy = minf(MAXFALL, e.vy + GRAV * dt)
	var nx = clampf(e.x + e.vx * dt, 26 + e.w / 2, M.w - 26 - e.w / 2)
	var gn = groundAt(nx)
	if gn < e.y - 0.5:
		if e.y - gn <= 14 and grounded:
			e.y = gn   # a little step: walk up it
		elif e.y - gn > 14:
			nx = e.x   # a ledge: blocked
			e.vx = 0
			if e.state == "idle":
				e.face *= -1
	e.x = nx
	e.y += e.vy * dt
	var g = groundAt(e.x)
	if e.y >= g:
		if e.vy > 120:
			e.sq = 0.35
			if e.state == "hurt":
				e.vx *= 0.5
		e.y = g
		e.vy = 0
		if e.state == "hurt":
			e.vx *= exp(-dt * 6)
	e.surf = floorSurfAt(e.x)
	e.sq += (0 - e.sq) * minf(1, dt * 10)


func _grounded(e) -> bool:
	return e.y >= groundAt(e.x) - 0.5 and e.vy >= 0


## a wander: walk a bit, stop a bit, turn round now and then
func _wander(e, sp: float, dt := 1.0 / 60.0) -> void:
	if e.hopCd <= 0:
		e.hopCd = rand(1.2, 2.6)
		if randf() < 0.5:
			e.face *= -1
		e.pause = 1.0 if randf() < 0.35 else 0.0
	if absf(e.x - e.homeX) > 140:
		e.face = int(sgn(e.homeX - e.x))
	e.walk = 0.0 if e.pause > 0 else e.face * sp
	e.pause -= dt


## a source for a hit that isn't the monster's own body (a lash, a spell, a shockwave)
func _src(e, x: float, extra := {}) -> Dictionary:
	var s = {"x": x, "lv": e.lv, "atk": e.atk, "boss": e.boss}
	s.merge(extra, true)
	return s


## a heavy blow that launches you (the golem's club, the yeti's slam)
func launchHit(src, mul: float) -> bool:
	var n0 = P.hurtN
	var r = src.duplicate() if src is Dictionary else _src(src, src.x)
	r.raid = true
	hurtPlayer(r, float(r.atk) * mul)
	return P.hurtN != n0


# ---------------- Cursed Boulder: rolls back and forth, then floats up and throws itself at you

func _boulder(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	match e.state:
		"idle":
			_wander(e, 34 * T.speed, dt)
			D.spin += e.vx * dt / 11.0
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			e.walk = e.face * 70 * T.speed if absf(tx) > 20 else 0.0
			D.spin += e.vx * dt / 11.0
			if e.atkCd <= 0 and dist < 170 and absf(ty) < 80 and _grounded(e):
				_setState(e, "wind")
				D.free = true
				D.y0 = e.y
				e.vx = 0; e.vy = 0; e.walk = 0
				Sfx.tone(160, 0.6, "sine", 0.05, 420)
		"wind":
			# floats up, staring
			e.y = lerpf(e.y, D.y0 - 46, minf(1, dt * 4))
			e.x += sin(e.t * 30) * 0.3
			e.face = int(sgn(tx)) if absf(tx) > 2 else e.face
			if randf() < dt * 20:
				part(e.x + rand(-8, 8), e.y + 2, rand(-6, 6), rand(10, 30), 0.5, "#8a5ac8" if randf() < 0.5 else "#5a5468", 0, 1)
			if e.t > 0.75:
				var n = Vector2(P.x - e.x, (P.y - 18) - (e.y - e.h / 2)).normalized()
				e.vx = n.x * 330; e.vy = n.y * 330
				_setState(e, "act")
				Sfx.whoosh(0.8, true)
		"act":
			e.x = clampf(e.x + e.vx * dt, 26, M.w - 26)
			e.y += e.vy * dt
			e.vy += GRAV * 0.25 * dt
			D.spin += 20 * dt * e.face
			if randf() < dt * 30:
				part(e.x - e.vx * 0.04, e.y - e.h / 2, 0, 0, 0.3, "#9a94a8", 0, 2)
			if not e.hitDone and overlap(sBox(e), pBox()):
				e.hitDone = true
				if mobHit(e, 1.5):
					shake = maxf(shake, 4)
			if e.y >= groundAt(e.x) or e.t > 1.2:
				e.y = minf(e.y, groundAt(e.x))
				D.free = false
				e.vx = -e.vx * 0.25; e.vy = -140
				dust(e.x, e.y, 8)
				Sfx.slam()
				_setState(e, "recover")
		"recover":
			e.walk = 0
			D.spin += e.vx * dt / 11.0
			if e.t > 0.8:
				_setState(e, "chase")
				e.atkCd = rand(2.2, 3.6)
	if e.state != "wind" and e.state != "act":
		D.free = false


# ---------------- Lizardman: whip lashes, and a somersault over your head (whipping on the way)

func _lizard(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var D: Dictionary = e.data
	var gr = _grounded(e)
	match e.state:
		"idle":
			_wander(e, 30 * T.speed, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			var want = 60.0
			e.walk = e.face * 70 * T.speed if absf(tx) > want else (-e.face * 30.0 if absf(tx) < 30 else 0.0)
			if gr and e.data.cd2 <= 0 and absf(tx) < 110 and absf(ty) < 40:
				# a somersault right over you
				e.move = "leap"
				_setState(e, "act")
				var land = P.x + sgn(tx) * 56
				e.vy = -360
				e.vx = clampf((land - e.x) / 0.72, -260, 260)
				D.spin = 0.0
				D.airWhip = randf() < 0.55
				D.whip = 0.0
				Sfx.whoosh(1.1, false)
				e.data.cd2 = rand(4, 7)
			elif gr and e.atkCd <= 0 and absf(tx) < 96 and absf(ty) < 34:
				e.move = "whip"
				_setState(e, "wind")
				e.walk = 0
				Sfx.tone(500, 0.15, "triangle", 0.04, 300)
		"wind":
			e.walk = 0
			if e.t > 0.38:
				_setState(e, "act")
				D.whip = 0.0
				Sfx.tone(2400, 0.06, "square", 0.05, 900)
		"act":
			if e.move == "whip":
				e.walk = 0
				# out over 0.12s, a beat, back over 0.2s
				D.whip = clampf(e.t / 0.12, 0, 1) if e.t < 0.2 else clampf(1 - (e.t - 0.2) / 0.2, 0, 1)
				D.whipAng = 0.0
				if not e.hitDone and D.whip > 0.4 and _lashHits(e, 82.0 * D.whip, 0.0):
					e.hitDone = true
					mobHit(e, 1.1)
				if e.t > 0.42:
					D.whip = 0.0
					_setState(e, "recover")
			else:
				D.spin += dt * TAU / 0.7 * e.face
				if D.get("airWhip", false) and e.vy > -120 and e.t > 0.2 and D.get("whipDone", false) == false:
					# a crack of the whip from upside down
					D.whip = minf(1.0, D.whip + dt / 0.1)
					e.face = int(sgn(P.x - e.x)) if P.x != e.x else e.face
					D.whipAng = atan2((P.y - 20) - (e.y - 22), absf(P.x - e.x))
					if not e.hitDone and _lashHits(e, 70.0 * D.whip, D.whipAng):
						e.hitDone = true
						mobHit(e, 1.0)
					if D.whip >= 1.0:
						D.whipDone = true
				else:
					D.whip = maxf(0.0, D.whip - dt / 0.15)
				if e.t > 0.15 and gr:
					D.spin = 0.0
					D.whip = 0.0
					D.whipDone = false
					e.vx *= 0.3
					e.face = int(sgn(P.x - e.x)) if P.x != e.x else e.face
					dust(e.x, e.y, 6)
					_setState(e, "recover")
		"recover":
			e.walk = 0
			if e.t > 0.5:
				_setState(e, "chase")
				e.atkCd = rand(1.2, 2.0)


## does a whip of this length from the lizard's hand, at this angle (0 = straight ahead), touch you?
func _lashHits(e, len_: float, ang: float) -> bool:
	var hx: float = e.x + e.face * 8
	var hy: float = e.y - 22
	var pb = pBox()
	for i in 8:
		var k = (i + 1) / 8.0
		var px = hx + e.face * cos(ang) * len_ * k
		var py = hy + sin(ang) * len_ * k
		if px > pb.x0 - 2 and px < pb.x1 + 2 and py > pb.y0 - 2 and py < pb.y1 + 2:
			return true
	return false


# ---------------- Snow Golem: slow, very hardy; a club that sends you flying

func _golem(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	match e.state:
		"idle":
			_wander(e, 16 * T.speed, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 6 else e.face
			e.walk = e.face * 44 * T.speed if absf(tx) > 50 else 0.0
			if e.atkCd <= 0 and absf(tx) < 82 and absf(ty) < 50 and _grounded(e):
				_setState(e, "wind")
				e.walk = 0
				Sfx.tone(90, 0.8, "sawtooth", 0.06, 60)
		"wind":
			e.walk = 0
			if e.t > 0.85:
				_setState(e, "act")
				var ix: float = e.x + e.face * 46
				var hb = hbox(minf(e.x, ix + e.face * 30), maxf(e.x, ix + e.face * 30), e.y - 50, e.y + 4)
				if overlap(hb, pBox()):
					if launchHit(_src(e, e.x), 1.9):
						Sfx.tone(70, 0.3, "square", 0.1, 40)
				shake = maxf(shake, 7)
				Sfx.slam()
				dust(ix, groundAt(ix), 18)
				for k in 12:
					part(ix + rand(-16, 16), groundAt(ix) - 2, rand(-80, 80), rand(-160, -40), rand(0.4, 0.8), "#f4f8ff" if k % 2 else "#b8c8dc", 500, 2)
		"act":
			if e.t > 0.6:
				_setState(e, "recover")
		"recover":
			if e.t > 0.9:
				_setState(e, "chase")
				e.atkCd = rand(2.0, 3.0)


# ---------------- Lizard Warlock: blinks around you; eruptions under your feet and seeking bolts

func _warlock(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	match e.state:
		"idle":
			_wander(e, 20 * T.speed, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			# keeps its distance
			e.walk = (-e.face * 50.0 if absf(tx) < 90 else (e.face * 40.0 if absf(tx) > 160 else 0.0)) * T.speed
			if D.cd2 <= 0 and (absf(tx) < 46 or randf() < dt * 0.25):
				_setState(e, "blink")
				e.walk = 0
				D.cd2 = rand(4, 7)
				Sfx.tone(900, 0.25, "sine", 0.05, 1800)
			elif e.atkCd <= 0 and dist < 210:
				e.move = "nova" if randf() < 0.55 else "bolts"
				_setState(e, "wind")
				e.walk = 0
				if e.move == "nova":
					var gx = clampf(P.x + P.vx * 0.3, 30, M.w - 30)
					climbShots.append({"kind": "nova", "x": gx, "y": groundAt(gx), "t": 0.0, "lv": e.lv, "atk": e.atk, "ox": e.x, "r": 34.0, "hit": false})
					Sfx.tone(240, 0.9, "sawtooth", 0.04, 700)
				else:
					Sfx.tone(600, 0.5, "triangle", 0.05, 1200)
		"wind":
			e.walk = 0
			if e.t > (0.9 if e.move == "nova" else 0.55):
				_setState(e, "act")
				if e.move == "bolts":
					for i in 3:
						var a = atan2((P.y - 22) - (e.y - 30), P.x - e.x) + (i - 1) * 0.35
						climbShots.append({"kind": "bolt", "x": e.x + e.face * 10, "y": e.y - 32, "vx": cos(a) * 150, "vy": sin(a) * 150, "t": 0.0, "lv": e.lv, "atk": e.atk, "ox": e.x})
					Sfx.tone(1200, 0.2, "square", 0.04, 500)
		"act":
			if e.t > 0.5:
				_setState(e, "recover")
		"blink":
			# fades out, reappears beside you
			if e.t > 0.3 and not D.get("blinked", false):
				D.blinked = true
				var side = -1.0 if randf() < 0.5 else 1.0
				var nx = clampf(P.x + side * rand(70, 110), 40, M.w - 40)
				for k in 14:
					part(e.x + rand(-6, 6), e.y - rand(0, 36), rand(-30, 30), rand(-40, 10), 0.5, "#b88aff" if k % 2 else "#e8d8ff", 0, 1)
				e.x = nx
				e.y = groundAt(nx)
				e.vy = 0
				e.face = int(sgn(P.x - e.x)) if P.x != e.x else e.face
				for k in 14:
					part(e.x + rand(-6, 6), e.y - rand(0, 36), rand(-30, 30), rand(-40, 10), 0.5, "#b88aff" if k % 2 else "#e8d8ff", 0, 1)
			if e.t > 0.6:
				D.blinked = false
				_setState(e, "chase")
				e.atkCd = minf(e.atkCd, 0.4)
		"recover":
			if e.t > 0.5:
				_setState(e, "chase")
				e.atkCd = rand(1.8, 2.8)


# ---------------- Cursed Yeti: fast swipes, and a leaping ground-slam that brings the roof down

func _cyeti(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var D: Dictionary = e.data
	var gr = _grounded(e)
	match e.state:
		"idle":
			_wander(e, 34 * T.speed, dt)
		"chase":
			e.face = int(sgn(tx)) if absf(tx) > 6 else e.face
			e.walk = e.face * 92 * T.speed if absf(tx) > 34 else 0.0
			if gr and D.cd2 <= 0 and absf(tx) < 180 and absf(tx) > 50:
				e.move = "slam"
				_setState(e, "wind")
				e.walk = 0
				Sfx.tone(80, 0.5, "sawtooth", 0.07, 50)
			elif gr and e.atkCd <= 0 and absf(tx) < 52 and absf(ty) < 50:
				e.move = "swipe"
				_setState(e, "wind")
				e.walk = 0
		"wind":
			e.walk = 0
			if e.move == "swipe" and e.t > 0.28:
				_setState(e, "act")
				e.vx = e.face * 90
				Sfx.whoosh(0.8, true)
			elif e.move == "slam" and e.t > 0.4:
				_setState(e, "act")
				e.vy = -430
				e.vx = clampf((P.x - e.x) / 0.85, -260, 260)
				Sfx.whoosh(0.6, true)
				D.cd2 = rand(5, 8)
		"act":
			if e.move == "swipe":
				var hb = hbox(e.x, e.x + 56, e.y - 70, e.y) if e.face > 0 else hbox(e.x - 56, e.x, e.y - 70, e.y)
				if not e.hitDone and e.t > 0.04 and overlap(hb, pBox()):
					e.hitDone = true
					mobHit(e, 1.6)
				e.vx *= exp(-dt * 6)
				if e.t > 0.32:
					_setState(e, "recover")
			else:
				if e.t > 0.15 and gr:
					# the slam: a shockwave, and the cave roof shakes loose
					shake = maxf(shake, 9)
					Sfx.slam()
					Sfx.tone(60, 0.6, "sawtooth", 0.1, 35)
					dust(e.x, e.y, 22)
					var pb = pBox()
					if absf(P.x - e.x) < 74 and P.y > e.y - 40 and P.grounded:
						launchHit(_src(e, e.x), 1.7)
					elif overlap(hbox(e.x - 30, e.x + 30, e.y - 50, e.y + 2), pb):
						mobHit(e, 1.7)
					if caveMap():
						for k in rint(3, 5):
							dropStal(clampf(P.x + rand(-110, 110), 30, M.w - 30), e, rand(0.0, 0.5))
					e.vx = 0
					_setState(e, "recover")
		"recover":
			e.walk = 0
			if e.t > 0.7:
				_setState(e, "chase")
				e.atkCd = rand(1.0, 1.6)


# ---------------- Enchanted Sword: flies fast, stabs or swings, trailing glitter

func _esword(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var D: Dictionary = e.data
	var sp: float = T.speed
	if randf() < dt * 26:
		var tipX = e.x + cos(D.ang) * 14 * e.face
		part(tipX + rand(-6, 6), e.y - e.h / 2 + rand(-3, 3), rand(-10, 10), rand(-14, 4), rand(0.4, 0.8), ["#ffffff", "#bff4ff", "#ffe8a8", "#d8b8ff"][rint(0, 3)], 30, 1)
	match e.state:
		"idle":
			_swimTo(e, e.homeX + sin(e.t * 0.6 + e.id) * 70, e.homeY + sin(e.t * 1.7 + e.id) * 12, 60, 2, dt)
			e.face = 1 if e.vx >= 0 else -1
			D.ang = damp(D.ang, sin(e.t * 2) * 0.15, 4, dt)
		"chase":
			var a = e.t * 1.6 + e.id
			_swimTo(e, P.x + cos(a) * 80, P.y - 34 + sin(a * 1.3) * 22, 150 * sp, 2.5, dt)
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			D.ang = damp(D.ang, clampf(atan2(ty, absf(tx)), -0.9, 0.9), 5, dt)
			if e.atkCd <= 0 and dist < 150:
				e.move = "stab" if randf() < 0.55 else "swipe"
				_setState(e, "wind")
				Sfx.tone(1800, 0.3, "sine", 0.03, 2600)
		"wind":
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			if e.move == "stab":
				# draws back along the line to you, quivering
				var n = Vector2(tx, ty).normalized()
				e.vx = damp(e.vx, -n.x * 60, 6, dt)
				e.vy = damp(e.vy, -n.y * 60, 6, dt)
				D.ang = atan2(n.y, absf(n.x))
				if e.t > 0.4:
					e.vx = n.x * 380 * sp * 0.8
					e.vy = n.y * 380 * sp * 0.8
					_setState(e, "act")
					Sfx.whoosh(1.3, false)
			else:
				_swimTo(e, P.x - sgn(tx) * 26, P.y - 30, 200, 4, dt)
				D.ang = damp(D.ang, -1.3, 8, dt)
				if e.t > 0.4:
					_setState(e, "act")
					Sfx.whoosh(1.0, true)
		"act":
			if e.move == "stab":
				var tipX = e.x + e.face * cos(D.ang) * 26
				var tipY = e.y - e.h / 2 + sin(D.ang) * 26
				var pb = pBox()
				if not e.hitDone and tipX > pb.x0 - 4 and tipX < pb.x1 + 4 and tipY > pb.y0 - 4 and tipY < pb.y1 + 4:
					e.hitDone = true
					mobHit(e, 1.6)
				e.vx *= exp(-dt * 1.5)
				e.vy *= exp(-dt * 1.5)
				if e.t > 0.35:
					_setState(e, "recover")
			else:
				# a wide arc, top to bottom
				e.vx *= exp(-dt * 6)
				e.vy *= exp(-dt * 6)
				D.ang = lerpf(-1.3, 1.3, clampf(e.t / 0.22, 0, 1))
				var tipX = e.x + e.face * cos(D.ang) * 28
				var tipY = e.y - e.h / 2 + sin(D.ang) * 28
				var pb = pBox()
				if not e.hitDone and e.t > 0.05 and (overlap(hbox(minf(e.x, tipX), maxf(e.x, tipX), minf(e.y - e.h / 2, tipY) - 4, maxf(e.y - e.h / 2, tipY) + 4), pb)):
					e.hitDone = true
					mobHit(e, 1.5)
				if e.t > 0.3:
					_setState(e, "recover")
		"recover":
			e.vx *= exp(-dt * 3)
			e.vy *= exp(-dt * 3)
			D.ang = damp(D.ang, 0.0, 4, dt)
			if e.t > 0.5:
				_setState(e, "chase")
				e.atkCd = rand(1.2, 2.0)


# ================================================================ stalactites, spells and boulders

## a stalactite shaken loose from the cave roof above x (a warning shadow first)
func dropStal(x: float, src, delay := 0.0, big := false) -> void:
	var cy = ceilAt(x)
	if cy < -1e8:
		cy = cam.y - 20
	stalFalls.append({"x": x, "y": cy + 4, "vy": 0.0, "t": -delay, "warn": 0.6, "lv": src.lv if src != null else 90, "atk": src.atk if src != null else 280,
		"big": big, "hit": src == null, "sx": src.x if src != null else x})


func updateStals(dt: float) -> void:
	for i in range(stalFalls.size() - 1, -1, -1):
		var s: Dictionary = stalFalls[i]
		s.t += dt
		if s.t < 0:
			continue
		if s.t < s.warn:
			if randf() < dt * 10:
				part(s.x + rand(-4, 4), s.y, rand(-6, 6), rand(10, 40), 0.5, "#b8c4d8", 300, 1)
			continue
		s.vy = minf(700, s.vy + GRAV * 1.1 * dt)
		s.y += s.vy * dt
		var len_ = 30.0 if s.big else 20.0
		var pb = pBox()
		if not s.hit and s.x > pb.x0 - 5 and s.x < pb.x1 + 5 and s.y > pb.y0 and s.y - len_ < pb.y1:
			s.hit = true
			hurtPlayer({"x": s.sx, "lv": s.lv, "atk": s.atk, "noCrit": true}, s.atk * (1.6 if s.big else 1.2))
		var g = groundAt(s.x)
		if s.y >= g:
			for k in 10:
				part(s.x + rand(-4, 4), g - 2, rand(-90, 90), rand(-150, -40), rand(0.3, 0.6), "#cfe0f4" if k % 2 else "#7a8498", 500, 2)
			Sfx.tone(rand(1300, 1900), 0.12, "triangle", 0.05, 600)
			Sfx.burst(0.15, "highpass", 1500, 4000, 0.12)
			stalFalls.remove_at(i)


func updateClimbShots(dt: float) -> void:
	var pb = pBox()
	for i in range(climbShots.size() - 1, -1, -1):
		var s: Dictionary = climbShots[i]
		s.t += dt
		var gone = false
		match s.kind:
			"nova":
				# a violet ring under your feet, then it erupts
				if s.t > 0.95 and not s.hit:
					s.hit = true
					Sfx.burst(0.4, "lowpass", 1800, 300, 0.3)
					Sfx.tone(160, 0.4, "sawtooth", 0.08, 60)
					shake = maxf(shake, 4)
					for k in 26:
						var a = randf() * PI
						part(s.x + cos(a) * rand(0, s.r), s.y - 2, cos(a) * rand(10, 60), -rand(80, 220), rand(0.4, 0.9), ["#c25cff", "#ff6af0", "#ffffff"][k % 3], 200, 2)
					if absf(P.x - s.x) < s.r + 6 and absf(P.y - s.y) < 40 and P.state != "dead":
						hurtPlayer({"x": s.ox, "lv": s.lv, "atk": s.atk, "noCrit": true}, s.atk * 2.0)
				gone = s.t > 1.35
			"bolt":
				var tgt = Vector2(P.x - s.x, (P.y - 22) - s.y)
				if s.t > 0.25 and s.t < 1.4:   # bends towards you, a little
					var v = Vector2(s.vx, s.vy)
					var want = tgt.normalized() * v.length()
					v = v.lerp(want, minf(1, dt * 1.6))
					s.vx = v.x; s.vy = v.y
				s.x += s.vx * dt
				s.y += s.vy * dt
				if randf() < dt * 30:
					part(s.x, s.y, rand(-8, 8), rand(-8, 8), 0.3, "#d8a8ff", 0, 1)
				if s.x > pb.x0 - 3 and s.x < pb.x1 + 3 and s.y > pb.y0 - 3 and s.y < pb.y1 + 3 and P.state != "dead":
					hurtPlayer({"x": s.ox, "lv": s.lv, "atk": s.atk, "noCrit": true}, s.atk * 1.1)
					gone = true
				if s.t > 2.6 or s.y > groundAt(s.x) or s.x < 0 or s.x > M.w:
					gone = true
				if gone:
					for k in 6:
						part(s.x, s.y, rand(-50, 50), rand(-50, 50), 0.3, "#c25cff", 0, 1)
			"boulder":
				# the King's boulders: they rise out of the floor, hang there, then fly at you one after another
				if s.state == "rise":
					s.y = damp(s.y, s.hy, 5, dt)
					s.rot += dt * 0.5
					if s.t > s.go:
						s.state = "fly"
						var n = Vector2(P.x - s.x, (P.y - 20) - s.y).normalized()
						s.vx = n.x * 470; s.vy = n.y * 470
						Sfx.whoosh(0.7, true)
				else:
					s.x += s.vx * dt
					s.y += s.vy * dt
					s.vy += GRAV * 0.12 * dt
					s.rot += dt * 9 * sgn(s.vx)
					if not s.hit and absf(s.x - P.x) < 15 and s.y > pb.y0 - 10 and s.y < pb.y1 + 8 and P.state != "dead":
						s.hit = true
						hurtPlayer({"x": s.x - s.vx * 0.05, "lv": s.lv, "atk": s.atk, "boss": true}, s.atk * 1.3)
						gone = true
					if s.y >= groundAt(s.x) - 6 or s.x < 10 or s.x > M.w - 10 or s.t > s.go + 2.0:
						gone = true
				if gone:
					shake = maxf(shake, 4)
					Sfx.slam()
					for k in 12:
						part(s.x + rand(-8, 8), s.y + rand(-8, 8), rand(-120, 120), rand(-180, -30), rand(0.4, 0.8), "#6a6878" if k % 2 else "#9a98a8", 600, 2)
		if gone:
			climbShots.remove_at(i)


# ================================================================ every frame

func updateClimb(dt: float) -> void:
	updateBlade(dt)
	updateStals(dt)
	updateClimbShots(dt)
	updateYetiSword(dt)
	if not climbMap():
		return
	# dripping water in the cave
	if M.get("drip"):
		dripT -= dt
		if dripT <= 0:
			dripT = rand(0.5, 2.2)
			var dx = cam.x + rand(10, VW - 10)
			var cy = ceilAt(dx)
			if cy > -1e8:
				part(dx, cy + 3, 0, 40, 1.4, "#bfe4ff", 380, 1, groundAt(dx))
			var near = clampf(1.0 - absf(dx - P.x) / 260.0, 0.2, 1.0)
			Sfx.tone(rand(1500, 2600), 0.18, "sine", 0.05 * near, rand(700, 1100), rand(0.3, 0.8))
	_updateEscape(dt)
	# blizzard: you can feel it push at you
	if M.get("blizzard") and P.state == "move" and not P.grounded:
		P.vx -= 16 * dt


## the wind on the climb maps (-1 elsewhere): a cold breeze, the blizzard's roar, the summit's gale
func climbWind() -> float:
	if not climbMap():
		return -1.0
	return {"climb": 0.8, "snow": 1.5, "cave": 0.05, "peak": 1.5}.get(M.get("theme"), 0.0)


## the throne room after the cave-in: rubble on the floor, the broken throne, the pendant's portal
func loadMap(id: String, px0 = null, py0 = null) -> void:
	if id == "climb4":
		var T: Dictionary = MAPS.climb4
		T.collapsed = (not not save.trophies.get("kingYeti"))
		T.music = "cave" if T.collapsed else "yeti"
		if T.collapsed:
			T.floor = RUIN_FLOOR.duplicate(true)
		else:
			T.erase("floor")
	climbShots.clear()
	stalFalls.clear()
	YS.clear()
	pBlade = {}
	escapeGate = {}
	super.loadMap(id, px0, py0)
	climbOnLoad()


func mapArt() -> String:
	if mapId == "climb4" and M.get("collapsed"):
		return "maps/climb4_ruin.png"
	return super.mapArt()


func climbOnLoad() -> void:
	if M.get("theme") == "peak":
		later(0.6, func(): if mapId == "peak": toast("A hot wind roars over the summit. Glamrax's lair is right ahead."))
	if mapId == "climb4" and save.trophies.get("kingYeti"):
		openPendantGate(false)


## the footsteps of the climb: crunching snow, scraping rock, echoing in the cave
func climbStep(heavy: bool) -> void:
	match M.get("theme"):
		"snow":
			Sfx.step(heavy, "snow")
		"cave":
			var p = rand(0.85, 1.0)
			Sfx.play("step_wood", 0.7, p)
			later(0.22, func(): Sfx.play("step_wood", 0.25, p * 0.97))
		_:
			Sfx.play("step_wood", 0.8 if heavy else 0.6, rand(0.75, 0.9))


# ================================================================ King Yeti

var YS := {}   # the King's sword while it's out of his hand (thrown, stuck, or fighting on its own)


func _kingYeti():
	for e in slimes:
		if e.bossKind == "kingYeti":
			return e
	return null


## in the throne room the camera frames King Yeti: on him while he rises and speaks, then on both of you
func updateCamera(dt: float) -> void:
	var e = _kingYeti() if mapId == "climb4" else null
	if e == null:
		super.updateCamera(dt)
		return
	var tx: float
	if e.state == "intro":
		tx = e.x - VW * 0.62
	elif absf(P.x - e.x) < VW - 90:
		tx = (P.x + e.x) / 2.0 - VW / 2.0
	else:
		tx = P.x - VW / 2.0 + P.face * 36
	tx = clampf(tx, 0, M.w - VW)
	var ty = clampf(P.y - VH * 0.64, 0, M.h - VH)
	cam.x = damp(cam.x, tx, 3.0 if e.state == "intro" else 6.0, dt)
	cam.y = damp(cam.y, ty, 5, dt)


func collapsed() -> bool:
	return mapId == "climb4" and (not not save.trophies.get("kingYeti"))


func spawnYeti(fromPedestal := false) -> void:
	climbShots.clear()
	stalFalls.clear()
	YS.clear()
	var tx: float = M.get("throneX", 566)
	var x = tx if not fromPedestal else minf(M.w - 70, P.x + 200)
	var e = _newMob("kingYeti", YETI_T, x, groundAt(x), floorSurfAt(x))
	e.boss = true; e.bossKind = "kingYeti"; e.face = -1; e.aggro = true
	e.w = 60; e.h = 108; e.showBar = 99
	e.data = {"phase": "sit", "sword": true, "act": "", "cd": 1.6, "grabCd": 4.0, "throwCd": 3.0, "boulderCd": 3.0, "combo": 0, "anim": "sit", "f": 0, "at": 0.0}
	slimes.append(e)
	if fromPedestal:
		e.state = "fight"
		e.data.phase = "fight"
		e.data.anim = "idle"
		e.y = groundAt(x) - 160
		e.vy = 200
		e.data.drop = true
		Sfx.tone(60, 1.0, "sawtooth", 0.1, 40)
		return
	e.state = "intro"
	e.data.sword = false   # it's still stuck in the floor by the throne
	if Yeti.introDone:
		# he's met you before: no speech, he just stands, grabs his sword and comes at you
		e.data.phase = "rise"
		e.t = 0
	else:
		P.frozen = true
	YS = {"state": "ground", "x": tx - 52, "y": groundAt(tx - 52) + 40, "ang": -PI / 2, "vx": 0.0, "vy": 0.0, "t": 0.0}


## where his sword hand is this frame (from the art's per-frame hand points), and the angle it holds the sword
func yetiHand(e) -> Dictionary:
	var A = yetiArt()
	var k: String = e.data.get("anim", "idle")
	var f: int = e.data.get("f", 0)
	var hs: Array = A.get("hand", {}).get(k, [])
	var h = hs[clampi(f, 0, hs.size() - 1)] if hs.size() else [A.ax + 50, A.ay - 120, -0.6]
	var hx: float = (float(h[0]) - A.ax) / 2.0
	var hy: float = (float(h[1]) - A.ay) / 2.0
	var ang: float = float(h[2]) if h.size() > 2 else 0.0
	if e.face < 0:
		hx = -hx
		ang = PI - ang
	return {"x": e.x + hx, "y": e.y + hy, "ang": ang}


func yetiNeck(e) -> Vector2:
	var A = yetiArt()
	var k: String = e.data.get("anim", "idle")
	var ns: Array = A.get("neck", {}).get(k, [])
	var n = ns[clampi(e.data.get("f", 0), 0, ns.size() - 1)] if ns.size() else [A.ax + 10, A.ay - 170]
	var nx: float = (float(n[0]) - A.ax) / 2.0
	return Vector2(e.x + (nx if e.face > 0 else -nx), e.y + (float(n[1]) - A.ay) / 2.0)


func _yAnim(e, k: String, f := 0) -> void:
	e.data.anim = k
	e.data.f = f


func _yAct(e, a: String) -> void:
	e.data.act = a
	e.t = 0.0
	e.hitDone = false
	e.data.fired = false


func updateYeti(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.t += dt
	e.hurtFlash -= dt
	D.at += dt
	if e.state == "dead":
		e.vx = 0
		if e.dying:
			e.deadT = 0
		else:
			e.deadT += dt
		return
	# falling in (summoned from the pedestal)
	if D.get("drop", false):
		e.vy = minf(900, e.vy + GRAV * 1.4 * dt)
		e.y += e.vy * dt
		_yAnim(e, "slam", 0)
		if e.y >= groundAt(e.x):
			e.y = groundAt(e.x)
			e.vy = 0
			D.drop = false
			shake = 10
			Sfx.slam()
			dust(e.x, e.y, 26)
			banner("King Yeti", "Dodge the thrown sword (C) · don't let him grab you")
			_yAct(e, "roar")
		return
	if e.state == "intro":
		_yetiIntro(e, dt)
		return
	if P.state == "dead":
		_yAnim(e, "idle", int(D.at * 2) % 2)
		e.vx = 0
		return
	# below 30%: he lets go of the sword and gets violent
	if not e.enraged and e.hp < e.maxHp * 0.3:
		e.enraged = true
		D.act = ""
		if P.held != null and P.held.kind in ["impale", "yeti"]:
			_releasePlayer()
		if D.sword:
			D.sword = false
			var h = yetiHand(e)
			YS = {"state": "free", "x": h.x, "y": h.y, "ang": h.ang, "vx": 0.0, "vy": -60.0, "t": 0.0, "act": "", "cd": 1.2, "hitDone": false}
		elif YS.get("state", "") in ["stuck", "thrown", "impaled"]:
			YS.state = "free"; YS.t = 0.0; YS.act = ""; YS.cd = 1.2; YS.vx = 0.0; YS.vy = -80.0
		_yAct(e, "roar")
		banner("KING YETI LETS GO OF HIS SWORD", "The sword fights on its own · he's faster and angrier")
		Sfx.tone(55, 1.6, "sawtooth", 0.14, 35)
		shake = 10
	var sp = 1.45 if e.enraged else 1.0
	var dx = P.x - e.x
	var dist = absf(dx)
	var turn = func():
		if absf(dx) > 8:
			e.face = int(sgn(dx))
	D.grabCd -= dt * sp
	D.throwCd -= dt * sp
	D.boulderCd -= dt * sp
	match D.act:
		"":
			# close in; pick an attack
			turn.call()
			var want = 44.0
			if dist > want:
				e.vx = damp(e.vx, e.face * 120 * sp, 6, dt)
				_yAnim(e, "run", int(D.at * 9 * sp) % 4)
			else:
				e.vx = damp(e.vx, 0, 10, dt)
				_yAnim(e, "idle", int(D.at * 2) % 2)
			D.cd -= dt * sp
			if D.cd <= 0 and P.held == null:
				var opts = []
				if dist < 70:
					opts += ["swing", "swing"] if D.sword else ["punch", "punch", "punch"]
				if D.grabCd <= 0 and dist < 140:
					opts.append("grab")
				if D.sword and D.throwCd <= 0 and dist > 90:
					opts += ["throw", "throw"]
				if e.enraged and D.boulderCd <= 0:
					opts += ["boulders", "boulders"]
				if not e.enraged and dist > 160 and D.sword and D.throwCd <= 0:
					opts = ["throw"]
				if not opts.is_empty():
					var a: String = opts[rint(0, opts.size() - 1)]
					if a == D.get("prev", "") and opts.size() > 1 and randf() < 0.6:
						a = opts[rint(0, opts.size() - 1)]
					D.prev = a
					_yAct(e, a)
					D.combo = 0
		"roar":
			e.vx = 0
			_yAnim(e, "roar")
			if e.t < dt * 1.5:
				Sfx.tone(70, 1.1, "sawtooth", 0.14, 45)
				Sfx.burst(1.0, "lowpass", 900, 200, 0.3)
			shake = maxf(shake, 3)
			if e.t > 1.1:
				_yAct(e, "")
				D.cd = 0.5
		"swing":
			# a great sword cut
			if e.t < 0.2:
				turn.call()
			if e.t < 0.45 / sp:
				e.vx = damp(e.vx, 0, 10, dt)
				_yAnim(e, "punch", 0)
			elif e.t < 0.7 / sp:
				_yAnim(e, "punch", 1)
				e.vx = e.face * 160
				var h = yetiHand(e)
				var tip = Vector2(h.x, h.y) + Vector2(cos(h.ang), sin(h.ang)) * YT_SWORD_LEN
				var hb = hbox(minf(e.x, tip.x) - 6, maxf(e.x, tip.x) + 6, minf(h.y, tip.y) - 30, e.y + 2)
				if not e.hitDone and overlap(hb, pBox()):
					e.hitDone = true
					mobHit(e, 1.7)
				if not D.fired:
					D.fired = true
					Sfx.whoosh(0.5, true)
			else:
				e.vx *= exp(-dt * 8)
				_yAnim(e, "idle", 0)
				if e.t > 1.0 / sp:
					_yAct(e, "")
					D.cd = 0.6
		"punch":
			# fists: two or three quick ones
			if e.t < 0.05:
				turn.call()
			var wind = 0.26 / sp
			if e.t < wind:
				e.vx = damp(e.vx, 0, 10, dt)
				_yAnim(e, "punch", 0)
			elif e.t < wind + 0.18:
				_yAnim(e, "punch", 1)
				e.vx = e.face * 220
				var hb = hbox(e.x, e.x + 64, e.y - 90, e.y - 20) if e.face > 0 else hbox(e.x - 64, e.x, e.y - 90, e.y - 20)
				if not e.hitDone and overlap(hb, pBox()):
					e.hitDone = true
					mobHit(e, 1.4)
				if not D.fired:
					D.fired = true
					Sfx.whoosh(0.9, true)
			else:
				e.vx *= exp(-dt * 10)
				if e.t > wind + 0.32:
					D.combo += 1
					if D.combo < (3 if e.enraged else 2) and absf(P.x - e.x) < 90:
						_yAct(e, "punch")
					else:
						_yAct(e, "")
						D.cd = 0.4 if e.enraged else 0.7
		"throw":
			# winds up, then the sword flies at lightning speed
			e.vx = damp(e.vx, 0, 10, dt)
			if e.t < 0.1:
				turn.call()
			if e.t < 0.55:
				_yAnim(e, "throw", 0)
				if e.t < dt * 1.5:
					floatText(e.x, e.y - 130, "He winds up the sword...", "call")
					Sfx.tone(300, 0.5, "sawtooth", 0.05, 1600)
			elif not D.fired:
				D.fired = true
				_yAnim(e, "throw", 1)
				D.sword = false
				var h = yetiHand(e)
				var ty = P.y - 26
				var n = Vector2(P.x - h.x, ty - h.y).normalized()
				if n.x * e.face < 0.3:
					n = Vector2(e.face, n.y).normalized()
				YS = {"state": "thrown", "x": h.x, "y": h.y, "ang": atan2(n.y, n.x), "vx": n.x * 900, "vy": n.y * 900, "t": 0.0, "src": e}
				Sfx.whoosh(1.6, false)
				Sfx.tone(1400, 0.15, "sawtooth", 0.06, 300)
				D.throwCd = 6.0
			elif e.t > 0.9 and YS.get("state", "") != "thrown":
				if YS.get("state", "") == "impaled":
					_yAct(e, "rip")
				elif YS.get("state", "") == "stuck":
					_yAct(e, "fetch")
				else:
					_yAct(e, "")
		"rip":
			# he blinks across to you and tears the sword back out
			e.vx = 0
			if not D.fired:
				D.fired = true
				_yBlink(e, P.x - P.face * 26, P.face)
			_yAnim(e, "grab", 0)
			if e.t > 0.5 and YS.get("state", "") == "impaled":
				YS.state = "hand"
				D.sword = true
				Sfx.burst(0.3, "lowpass", 2000, 400, 0.4)
				Sfx.tone(120, 0.4, "square", 0.1, 50)
				for k in 30:
					part(P.x, P.y - 26, rand(-160, 160), rand(-200, 20), rand(0.4, 0.9), "#d82a3a" if k % 2 else "#ff8a9a", 400, 2)
				_releasePlayer()
				abyssChip({"x": e.x, "lv": e.lv, "atk": e.atk}, 2.4, 0.0, false)
				if P.state != "dead":
					knockDown({"x": e.x})
				floatText(P.x, P.y - 70, "Ripped out!", "call")
				shake = 9
			if e.t > 1.1:
				_yAct(e, "")
				D.cd = 0.8
		"fetch":
			# the sword missed: he teleports to it and pulls it out of the rock
			e.vx = 0
			if not D.fired:
				D.fired = true
				_yBlink(e, clampf(YS.x - sgn(YS.vx if YS.vx != 0 else 1.0) * 30, 40, M.w - 40), int(sgn(YS.x - e.x)) if YS.x != e.x else e.face)
			_yAnim(e, "grab", 0)
			if e.t > 0.55:
				YS.state = "hand"
				D.sword = true
				Sfx.tone(800, 0.2, "triangle", 0.05, 300)
				_yAct(e, "")
				D.cd = 0.5
		"grab":
			# lunges with an open hand; if he gets you: three slams, then up into the ceiling
			if e.t < 0.1:
				turn.call()
			if e.t < 0.35 / sp:
				e.vx = damp(e.vx, 0, 10, dt)
				_yAnim(e, "grab", 0)
			elif e.t < 0.85 / sp:
				_yAnim(e, "grab", 0)
				e.vx = e.face * 300 * sp
				var hb = hbox(e.x, e.x + 54, e.y - 90, e.y) if e.face > 0 else hbox(e.x - 54, e.x, e.y - 90, e.y)
				if not e.hitDone and overlap(hb, pBox()) and P.held == null and not (P.state in ["dash", "dead", "knocked"]) and P.iframes <= 0 and not save.settings.god:
					e.hitDone = true
					e.vx = 0
					P.held = {"kind": "yeti", "e": e, "phase": "lift", "t": 0.0, "n": 0}
					P.state = "held"
					floatText(P.x, P.y - 62, "Grabbed!", "call")
					Sfx.tone(110, 0.4, "sawtooth", 0.1, 70)
					_yAct(e, "holding")
					D.grabCd = 9.0
			else:
				e.vx *= exp(-dt * 8)
				if e.t > 1.2 / sp:
					_yAct(e, "")
					D.cd = 0.6
					D.grabCd = 5.0
		"holding":
			e.vx = 0
			if P.held == null or P.held.get("e") != e:
				_yAct(e, "")
				D.cd = 0.8
		"boulders":
			# he lifts boulders out of the cave floor, then hurls them one after another, moving fast
			e.vx = damp(e.vx, 0, 10, dt)
			if e.t < 0.9:
				_yAnim(e, "lift", 0)
				if not D.fired:
					D.fired = true
					D.boulderCd = 9.0
					floatText(e.x, e.y - 130, "The cave floor shakes...", "call")
					Sfx.tone(50, 1.2, "sawtooth", 0.1, 30)
					var n = rint(4, 6)
					for i in n:
						var bx = clampf(e.x + (i - (n - 1) / 2.0) * 34 + rand(-6, 6), 30, M.w - 30)
						climbShots.append({"kind": "boulder", "state": "rise", "x": bx, "y": groundAt(bx) + 10, "hy": e.y - rand(110, 150), "t": 0.0,
							"go": 1.0 + i * 0.32, "rot": randf() * TAU, "lv": e.lv, "atk": e.atk, "hit": false, "vx": 0.0, "vy": 0.0})
						dust(bx, groundAt(bx), 6)
				shake = maxf(shake, 2.5)
			else:
				_yAnim(e, "throw", int(e.t * 3) % 2)
				# hops sideways between throws
				if fmod(e.t, 0.32) < dt and randf() < 0.6:
					e.vx = (-1.0 if randf() < 0.5 else 1.0) * 260
				turn.call()
				if not climbShots.any(func(s): return s.kind == "boulder"):
					_yAct(e, "")
					D.cd = 0.5
	# walk the ground
	e.x = clampf(e.x + e.vx * dt, 40, M.w - 40)
	e.y = groundAt(e.x)
	e.surf = floorSurfAt(e.x)


func _yBlink(e, nx: float, face: int) -> void:
	for k in 24:
		part(e.x + rand(-20, 20), e.y - rand(0, 100), rand(-40, 40), rand(-60, 20), 0.6, "#7af0ff" if k % 2 else "#ffffff", 0, 2)
	e.x = clampf(nx, 40, M.w - 40)
	e.y = groundAt(e.x)
	e.face = face
	for k in 24:
		part(e.x + rand(-20, 20), e.y - rand(0, 100), rand(-40, 40), rand(-60, 20), 0.6, "#7af0ff" if k % 2 else "#ffffff", 0, 2)
	Sfx.tone(1600, 0.25, "sine", 0.06, 400)
	Sfx.burst(0.2, "highpass", 2000, 5000, 0.15)


## the throne room's first meeting: he stands, speaks, pulls the sword out of the floor, speaks again
func _yetiIntro(e, dt: float) -> void:
	var D: Dictionary = e.data
	match D.phase:
		"sit":
			_yAnim(e, "sit")
			if e.t > 1.2:
				D.phase = "rise"
				e.t = 0
				Sfx.tone(70, 0.8, "sawtooth", 0.08, 50)
		"rise":
			_yAnim(e, "rise" if e.t < 0.6 else "idle")
			shake = maxf(shake, 1.5 if e.t < 0.6 else 0.0)
			if e.t > 0.6 and e.t - dt <= 0.6:
				Sfx.slam()
				dust(e.x - 10, e.y, 10); dust(e.x + 10, e.y, 10)
			if e.t > 1.1:
				D.phase = "speak"
				e.t = 0
				if Yeti.introDone:
					D.phase = "sword"
				else:
					startScene([{"who": "King Yeti", "text": "Glamrax awaits. But you no pass."}], func():
						D.phase = "sword"
						e.t = 0)
		"speak":
			_yAnim(e, "idle", 0)
		"sword":
			# the sword tears itself out of the floor beside the throne and flies to his hand
			_yAnim(e, "idle", 0)
			var h = yetiHand(e)
			YS.t += dt
			var g = groundAt(YS.x)
			if YS.t < 1.0:
				YS.y = lerpf(g + 40, g - 70, easeOut(YS.t / 1.0))
				shake = maxf(shake, 2)
				if randf() < dt * 30:
					part(YS.x + rand(-5, 5), g - 1, rand(-40, 40), rand(-120, -30), 0.6, "#8a8898" if randf() < 0.5 else "#bff4ff", 400, 2)
				if YS.t - dt <= 0:
					Sfx.burst(1.0, "lowpass", 400, 1200, 0.35)
					Sfx.tone(200, 1.0, "sawtooth", 0.05, 900)
			elif YS.t < 1.4:
				var k = easeIn((YS.t - 1.0) / 0.4)
				YS.x = lerpf(YS.x, h.x, k)
				YS.y = lerpf(YS.y, h.y, k)
				YS.ang = lerp_angle(YS.ang, h.ang, k)
			else:
				YS.clear()
				D.sword = true
				_yAnim(e, "throw", 1)
				Sfx.tone(900, 0.4, "triangle", 0.08, 1400)
				Sfx.slam()
				shake = 5
				D.phase = "die"
				e.t = 0
				if Yeti.introDone:
					_yetiBegin(e)
				else:
					startScene([{"who": "King Yeti", "text": "Die."}], func(): _yetiBegin(e))
		"die":
			_yAnim(e, "throw", 1)


func _yetiBegin(e) -> void:
	e.state = "fight"
	e.data.phase = "fight"
	P.frozen = false
	_yAct(e, "roar")
	if not Yeti.introDone:
		Yeti.introDone = true
	banner("King Yeti", "Dodge the thrown sword (C) · don't let him grab you")
	Sfx.thunder()


## the thrown sword, and the sword fighting on its own once he lets it go
func updateYetiSword(dt: float) -> void:
	if YS.is_empty():
		return
	var e = _kingYeti()
	if e == null:
		YS.clear()
		return
	YS.t = YS.get("t", 0.0) + dt
	match YS.get("state", ""):
		"hand", "ground":
			if YS.state == "hand":
				YS.clear()
		"thrown":
			var px = YS.x
			var py = YS.y
			YS.x += YS.vx * dt
			YS.y += YS.vy * dt
			if randf() < dt * 60:
				part(YS.x, YS.y, 0, 0, 0.25, "#bff4ff", 0, 1)
			# the blade's tip sweeps between where it was and where it is now
			var pb = pBox()
			var hit = false
			for i in 4:
				var k = (i + 1) / 4.0
				var qx = lerpf(px, YS.x, k) + cos(YS.ang) * YT_SWORD_LEN * 0.8
				var qy = lerpf(py, YS.y, k) + sin(YS.ang) * YT_SWORD_LEN * 0.8
				if qx > pb.x0 - 3 and qx < pb.x1 + 3 and qy > pb.y0 and qy < pb.y1:
					hit = true
			if hit and P.state != "dead" and P.held == null:
				if P.state == "dash" or P.iframes > 0 or save.settings.god:
					if P.state == "dash" and not P.dodged.has(YS):
						P.dodged[YS] = true
						perfectDodge()
						floatText(P.x, P.y - 62, "Dodged the sword!", "call")
				else:
					# impaled through the chest
					YS.state = "impaled"
					YS.t = 0.0
					P.held = {"kind": "impale", "e": e, "t": 0.0, "x": P.x, "y": P.y if P.grounded else groundAt(P.x)}
					P.state = "held"
					P.face = -int(sgn(YS.vx)) if YS.vx != 0 else P.face
					abyssChip({"x": e.x, "lv": e.lv, "atk": e.atk}, 3.2, 0.0, false)
					floatText(P.x, P.y - 70, "IMPALED!", "call")
					shake = 12
					hitstop = 0.15
					Sfx.burst(0.4, "lowpass", 1800, 300, 0.45)
					Sfx.tone(90, 0.6, "square", 0.12, 40)
					for k in 30:
						part(P.x, P.y - 26, rand(-120, 120) + YS.vx * 0.1, rand(-160, 20), rand(0.4, 0.9), "#d82a3a" if k % 2 else "#ff8a9a", 400, 2)
					YS.vx = 0; YS.vy = 0
					return
			var tipX = YS.x + cos(YS.ang) * YT_SWORD_LEN
			var tipY = YS.y + sin(YS.ang) * YT_SWORD_LEN
			if tipX < 14 or tipX > M.w - 14 or tipY > groundAt(tipX) or YS.t > 1.2:
				YS.state = "stuck"
				YS.t = 0.0
				shake = maxf(shake, 5)
				Sfx.tone(140, 0.3, "square", 0.08, 80)
				Sfx.burst(0.2, "highpass", 1500, 3500, 0.2)
				for k in 14:
					part(tipX, tipY, rand(-90, 90), rand(-140, 0), rand(0.3, 0.7), "#9a98a8" if k % 2 else "#bff4ff", 500, 2)
		"impaled":
			# the sword stays in you until he pulls it out
			YS.x = P.x - cos(YS.ang) * YT_SWORD_LEN * 0.55
			YS.y = P.y - 24 - sin(YS.ang) * YT_SWORD_LEN * 0.55
			if P.held == null or P.held.kind != "impale":
				YS.state = "stuck" if e.enraged == false else "free"
		"stuck":
			pass
		"free":
			_freeSword(e, dt)


## once he's below 30%, the sword hunts you by itself: it circles, stabs, and cleaves
func _freeSword(e, dt: float) -> void:
	if e.state == "dead":
		YS.vy = minf(400, YS.get("vy", 0.0) + GRAV * dt)
		YS.y += YS.vy * dt
		YS.ang = damp(YS.ang, PI / 2, 3, dt)
		if YS.y > groundAt(YS.x) - 20:
			YS.y = groundAt(YS.x) - 20
		return
	YS.cd = YS.get("cd", 1.0) - dt
	if randf() < dt * 30:
		part(YS.x + cos(YS.ang) * rand(20, 100), YS.y + sin(YS.ang) * rand(20, 100), rand(-10, 10), rand(-14, 4), rand(0.4, 0.8), ["#ffffff", "#bff4ff", "#7af0ff"][rint(0, 2)], 30, 1)
	var mid = Vector2(YS.x, YS.y) + Vector2(cos(YS.ang), sin(YS.ang)) * YT_SWORD_LEN * 0.5
	var to = Vector2(P.x, P.y - 24) - mid
	var swing = func(mul: float):
		var pb = pBox()
		for i in 6:
			var k = 0.3 + i * 0.14
			var q = Vector2(YS.x, YS.y) + Vector2(cos(YS.ang), sin(YS.ang)) * YT_SWORD_LEN * k
			if q.x > pb.x0 - 4 and q.x < pb.x1 + 4 and q.y > pb.y0 - 4 and q.y < pb.y1 + 4:
				if not YS.get("hitDone", false):
					YS.hitDone = true
					if P.state == "dash":
						if not P.dodged.has(YS):
							P.dodged[YS] = true
							perfectDodge()
					else:
						hurtPlayer({"x": mid.x, "lv": e.lv, "atk": e.atk, "boss": true}, e.atk * mul)
				return
	match YS.get("act", ""):
		"":
			# hovers above and to the side of you
			var side = -1.0 if P.x > M.w / 2.0 else 1.0
			var want = Vector2(P.x + side * 70 + sin(YS.t * 1.3) * 20, P.y - 90 + sin(YS.t * 2.1) * 10)
			var v = Vector2(YS.vx, YS.vy).lerp((want - Vector2(YS.x, YS.y) - Vector2(cos(YS.ang), sin(YS.ang)) * YT_SWORD_LEN * 0.5) * 3, minf(1, dt * 3))
			YS.vx = v.x; YS.vy = v.y
			YS.ang = lerp_angle(YS.ang, atan2(to.y, to.x), minf(1, dt * 4))
			if YS.cd <= 0 and P.held == null:
				YS.act = "stab" if randf() < 0.55 else "cleave"
				YS.t = 0.0
				YS.hitDone = false
				Sfx.tone(1700, 0.4, "sine", 0.04, 2600)
		"stab":
			if YS.t < 0.45:
				YS.ang = lerp_angle(YS.ang, atan2(to.y, to.x), minf(1, dt * 10))
				YS.vx = -cos(YS.ang) * 50; YS.vy = -sin(YS.ang) * 50
				YS.x += sin(YS.t * 80) * 0.6
			elif YS.t < 0.75:
				if YS.t - dt < 0.45:
					Sfx.whoosh(1.5, false)
				YS.vx = cos(YS.ang) * 560; YS.vy = sin(YS.ang) * 560
				swing.call(1.7)
			else:
				YS.vx *= exp(-dt * 6); YS.vy *= exp(-dt * 6)
				if YS.t > 1.1:
					YS.act = ""; YS.cd = rand(1.0, 1.6)
		"cleave":
			# swoops to your side, then sweeps through a big arc
			if YS.t < 0.5:
				var s = -1.0 if P.x > YS.x else 1.0
				var want = Vector2(P.x + s * 40, P.y - 60)
				var v = (want - Vector2(YS.x, YS.y)) * 5
				YS.vx = v.x; YS.vy = v.y
				YS.ang = lerp_angle(YS.ang, -PI / 2, minf(1, dt * 8))
				YS.dir = -s
			elif YS.t < 0.85:
				if YS.t - dt < 0.5:
					Sfx.whoosh(1.0, true)
				YS.vx = 0; YS.vy = 0
				var k = (YS.t - 0.5) / 0.35
				var a0 = -PI / 2
				var a1 = 0.35 if YS.dir > 0 else PI - 0.35
				YS.ang = lerp_angle(a0, a1, k)
				swing.call(1.6)
			else:
				if YS.t > 1.2:
					YS.act = ""; YS.cd = rand(1.0, 1.8)
	YS.x = clampf(YS.x + YS.vx * dt, 20, M.w - 20)
	YS.y = clampf(YS.y + YS.vy * dt, ceilAt(YS.x) + 10 if ceilAt(YS.x) > -1e8 else 20.0, groundAt(YS.x) - 6)


# ================================================================ being grabbed or impaled by the King

func abyssHold(dt: float) -> bool:
	var H = P.held
	if H == null or not (H.kind in ["yeti", "impale"]):
		return super.abyssHold(dt)
	var e = H.e
	H.t += dt
	P.state = "held"
	P.iframes = maxf(P.iframes, 0.25)
	P.vx = 0; P.vy = 0
	P.grounded = false
	P.surf = null
	P.animT += dt
	setAnim("hurt")
	if e == null or e.state == "dead":
		_releasePlayer()
		return false
	if H.kind == "impale":
		# pinned in place, the sword through you, until he comes to pull it out
		P.x = H.x
		P.y = H.y
		if randf() < dt * 8:
			part(P.x + rand(-3, 3), P.y - 24, rand(-20, 20), rand(0, 40), 0.6, "#c81e2e", 400, 1)
		if H.t > 3.0:   # he never came (knocked out of it): it drops out of you
			_releasePlayer()
			YS.state = "stuck"
			return false
		return true
	# grabbed: three slams into the floor, then flung up into the stalactites on the ceiling
	var hand = yetiHand(e)
	match H.phase:
		"lift":
			_yAnim(e, "hold", 0)
			P.x = lerpf(P.x, e.x + e.face * 30, minf(1, dt * 12))
			P.y = lerpf(P.y, e.y - 120, minf(1, dt * 10))
			if H.t > 0.35:
				H.phase = "slam"; H.t = 0.0
		"slam":
			var k = H.t / 0.22
			_yAnim(e, "slam", 0 if k < 0.5 else 1)
			var gx = e.x + e.face * 44
			P.x = gx
			P.y = lerpf(e.y - 120, groundAt(gx), easeIn(minf(1, k)))
			if k >= 1:
				H.n += 1
				P.y = groundAt(gx)
				dust(P.x, P.y, 14)
				shake = maxf(shake, 8)
				Sfx.slam()
				abyssChip({"x": e.x, "lv": e.lv, "atk": e.atk}, 0.6, 0.0, false)
				if P.state == "dead":
					P.held = null
					return false
				H.phase = "slam" if H.n < 3 else "fling"
				H.t = -0.18   # a beat on the floor between slams
				if H.n < 3:
					H.phase = "up"
		"up":
			_yAnim(e, "hold", 0)
			if H.t > 0:
				var k = minf(1, H.t / 0.2)
				P.y = lerpf(groundAt(P.x), e.y - 120, easeOut(k))
				P.x = lerpf(P.x, e.x + e.face * 30, k)
				if k >= 1:
					H.phase = "slam"; H.t = 0.0
		"fling":
			_yAnim(e, "throw", 1)
			if H.t > 0:
				if not H.has("sx"):
					# straight up into the nearest stalactite
					var best = YT_STALS[0]
					for s in YT_STALS:
						if absf(s - P.x) < absf(best - P.x):
							best = s
					H.sx = best
					H.x0 = P.x
					H.y0 = P.y
					Sfx.whoosh(1.4, true)
					Sfx.tone(200, 0.4, "sawtooth", 0.08, 900)
				var k = minf(1, H.t / 0.32)
				var top = ceilAt(H.sx) + YT_STAL_LEN + 18   # the point goes through the chest
				P.x = lerpf(H.x0, H.sx, easeOut(k))
				P.y = lerpf(H.y0, top, easeOut(k))
				if k >= 1:
					H.phase = "stuck"; H.t = 0.0
					shake = 12
					hitstop = 0.12
					Sfx.burst(0.4, "lowpass", 1600, 300, 0.45)
					Sfx.tone(80, 0.5, "square", 0.12, 40)
					floatText(P.x, P.y - 40, "IMPALED ON THE CEILING!", "call")
					abyssChip({"x": e.x, "lv": e.lv, "atk": e.atk}, 2.6, 0.0, false)
					for q in 24:
						part(P.x, P.y - 24, rand(-80, 80), rand(-40, 80), rand(0.4, 0.9), "#d82a3a" if q % 2 else "#ff8a9a", 400, 2)
					if P.state == "dead":
						P.held = null
						return false
		"stuck":
			_yAnim(e, "roar")
			var top = ceilAt(H.sx) + YT_STAL_LEN + 18   # the point goes through the chest
			P.x = H.sx
			# hangs there, then slowly slides off the point
			P.y = top + maxf(0, H.t - 0.6) * 18
			if randf() < dt * 10:
				part(P.x + rand(-3, 3), P.y - 20, rand(-10, 10), rand(0, 30), 0.6, "#c81e2e", 500, 1)
			if H.t > 1.3:
				# falls to the floor; the landing hurts, and it takes a while to get up
				P.held = null
				P.state = "move"
				abyssChip({"x": e.x, "lv": e.lv, "atk": e.atk}, 1.6, 0.0, false)
				if P.state != "dead":
					knockDown({"x": P.x + P.face})
					P.vx = 0
					P.vy = 60
					P.kdLong = 1.4
				_yAct(e, "")
				e.data.cd = 1.0
				return false
	return true


func _releasePlayer() -> void:
	P.held = null
	if P.state == "held":
		P.state = "move"
	P.iframes = maxf(P.iframes, 0.6)


func yetiBox(e) -> Dictionary:
	return hbox(e.x - 30, e.x + 30, e.y - 108, e.y)


## his dying breath: an angry slam, and the cave comes down; the pendant tears a way out
func yetiFalls(e, firstKill: bool) -> void:
	e.dying = true
	var D: Dictionary = e.data
	D.act = ""
	if P.held != null and P.held.kind in ["yeti", "impale"]:
		_releasePlayer()
	if YS.get("state", "") in ["free", "thrown", "impaled"]:
		YS.state = "free"
	climbShots = climbShots.filter(func(s): return s.kind != "boulder")
	_yAnim(e, "kneel")
	Sfx.tone(60, 1.6, "sawtooth", 0.12, 35)
	Sfx.burst(1.2, "lowpass", 500, 120, 0.35)
	if firstKill:
		P.frozen = true
		later(1.3, func():
			# one last furious slam
			_yAnim(e, "slam", 0)
			later(0.45, func():
				_yAnim(e, "slam", 1)
				shake = 14
				Sfx.slam(); Sfx.thunder()
				dust(e.x + e.face * 40, e.y, 30)
				banner("CAVE-IN!", "The whole cave is coming down")
				_gatherLoot()
				for i in 26:
					dropStal(rand(40, M.w - 40), null, rand(0.0, 2.6), randf() < 0.4)
				later(1.4, func():
					_yAnim(e, "fallen")
					e.dying = false
					later(0.8, func(): _pendantEscape()))))
	else:
		later(1.2, func():
			_yAnim(e, "fallen")
			e.dying = false
			shake = 8
			Sfx.slam()
			dust(e.x, e.y, 18)
			if not (not not save.get("keyItems", {}).get("yetiPendant")):
				_dropPendant(e, false)
			banner("KING YETI FALLS", "Grab the Yetibox · the pedestal can call him back")
			Sfx.rankUp(9))


## everything he dropped flies to you (the cave's coming down, there's no time to pick it up)
func _gatherLoot() -> void:
	for d in drops:
		d.x = P.x
		d.y = P.y - 10
		d.t = 1.0
		d.x0 = P.x - 1; d.x1 = P.x + 1
		d.surfY = P.y


func _dropPendant(e, auto: bool) -> void:
	if (not not save.get("keyItems", {}).get("yetiPendant")):
		return
	if auto:
		pickupPendant()
		return
	if drops.any(func(d): return d.kind == "pendant"):
		return
	var d = S.Drop.new()
	d.kind = "pendant"
	d.x = e.x; d.y = e.y - 80; d.vx = -e.face * 40.0; d.vy = -180
	d.surfY = groundAt(e.x); d.x0 = 40; d.x1 = M.w - 40
	drops.append(d)


func pickupPendant() -> void:
	if not (save.get("keyItems") is Dictionary):
		save.keyItems = {}
	save.keyItems.yetiPendant = true
	saveDirty = true
	persist()
	keyItemGet("yetiPendant", "Glowing Pendant", "King Yeti's pendant. Its light can tear open a way through.")
	toast("💎 You got King Yeti's pendant! It's in your inventory, under Key items.")
	Sfx.rankUp(9)
	Sfx.buy()
	for k in 40:
		part(P.x, P.y - 30, rand(-120, 120), rand(-200, -40), rand(0.6, 1.1), ["#7af0ff", "#ffffff", "#bff4ff"][k % 3], 200, 2)


## the pendant blazes and rips open a portal; the hero dives through it as the roof comes down
func _pendantEscape() -> void:
	if mapId != "climb4":
		P.frozen = false
		return
	var side = 1.0 if P.x < M.w - 120 else -1.0
	var px = clampf(P.x + side * 60, 40, M.w - 40)
	# the pendant comes off his neck and into your hand, blazing
	if not (not not save.get("keyItems", {}).get("yetiPendant")):
		pickupPendant()
	escapeGate = {"x": px, "y": groundAt(px), "t": 0.0}
	Sfx.tone(600, 1.2, "sine", 0.08, 1800)
	Sfx.burst(1.0, "highpass", 800, 4000, 0.25)
	floatText(P.x, P.y - 66, "The pendant tears open a portal!", "call")
	for i in 14:
		dropStal(rand(40, M.w - 40), null, rand(0.2, 2.6), randf() < 0.4)
	later(2.8, func():
		# a running leap into it (scripted, so nothing can knock it off course)
		P.face = int(side)
		P.state = "move"
		P.grounded = false
		P.surf = null
		escapeGate.leap = {"t": 0.0, "x0": P.x, "y0": P.y}
		Sfx.jump())


## the hero's arc into the pendant's portal; through it, the summit
func _updateEscape(dt: float) -> void:
	if escapeGate.is_empty() or not escapeGate.has("leap"):
		return
	var L: Dictionary = escapeGate.leap
	L.t += dt
	var k = minf(1, L.t / 0.55)
	P.x = lerpf(L.x0, escapeGate.x, k)
	P.y = lerpf(L.y0, escapeGate.y - 20, k) - sin(k * PI) * 46
	P.vx = 0; P.vy = 0
	if k >= 1 and fadeTo == null:
		Sfx.tone(520, 0.4, "sine", 0.12, 1400)
		escapeGate = {}
		P.frozen = false
		fadeTo = {"map": "peak", "x": MAPS.peak.start}
		later(1.0, func():
			if mapId == "peak":
				banner("Glamrax's Gate", "The top of the Abyssal Volcano")
				Sfx.thunder())


var escapeGate := {}   # the pendant's portal while it's open in the collapsing cave


## the way on after the collapse: the pendant's portal stays open by the broken throne
func openPendantGate(fanfare := false) -> void:
	var T: Dictionary = MAPS.climb4
	if not T.portals.any(func(p): return p.to == "peak"):
		T.portals.append({"x": T.w - 44, "to": "peak", "tx": MAPS.peak.start, "label": "The pendant's portal"})
	if fanfare:
		banner("A portal of icy light", "The pendant tore it open")


func summonYeti() -> void:
	spawnYeti(true)


# ================================================================ Impaling Blade (the Yetibox's skill)

var pBlade := {}   # the hero's thrown sword


func castBossSkill(s: Dictionary) -> void:
	if s.id != "swordThrow":
		super.castBossSkill(s)
		return
	pBlade = {"x": P.x + P.face * 8, "y": P.y - 26, "vx": P.face * 820.0, "t": 0.0, "face": P.face, "e": null, "state": "fly"}
	floatText(P.x, P.y - 58, "Impaling Blade!", "call")
	Sfx.whoosh(1.6, false)
	Sfx.tone(1400, 0.15, "sawtooth", 0.06, 300)


func updateBlade(dt: float) -> void:
	if pBlade.is_empty():
		return
	var B: Dictionary = pBlade
	B.t += dt
	if B.state == "fly":
		B.x += B.vx * dt
		var tip = B.x + B.face * 30
		for e in slimes:
			if e.state == "dead" or e.bossEye:
				continue
			var b = sBox(e)
			if tip > b.x0 and tip < b.x1 and B.y > b.y0 - 4 and B.y < b.y1 + 4:
				B.state = "in"
				B.e = e
				B.t = 0.0
				B.dx = B.x - e.x
				B.dy = B.y - e.y
				damageSlime(e, {"dmg": 6.0, "kb": 0, "up": 0, "style": 40, "anim": "swordThrow", "both": true, "heavy": true})
				shake = maxf(shake, 7)
				Sfx.burst(0.3, "lowpass", 1800, 300, 0.35)
				break
		if B.state == "fly" and (B.t > 0.5 or B.x < 0 or B.x > M.w):
			pBlade = {}
	else:
		var e = B.e
		if e == null or not slimes.has(e):
			pBlade = {}
			return
		B.x = e.x + B.dx
		B.y = e.y + B.dy
		if e.state != "dead" and not e.boss:
			e.state = "hurt"; e.stun = 0.4; e.vx = 0
		if B.t > 0.7:
			if e.state != "dead":
				damageSlime(e, {"dmg": 4.0, "kb": 120, "up": -160, "style": 30, "anim": "swordThrow2", "both": true, "heavy": true})
			Sfx.tone(120, 0.3, "square", 0.08, 60)
			pBlade = {}


# forward declarations for the drawing (climb_draw.gd, further down the chain)
func drawClimbBack(_x: Ctx, _sx: float, _sy: float, _dt: float, _D: Dictionary) -> void: pass
func drawClimbMid(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawPendantDrop(_x: Ctx, _X: float, _Y: float, _tt: float) -> void: pass
func drawYetibox(_x: Ctx, _X: float, _Y: float, _tt: float) -> void: pass
func drawClimbFront(_x: Ctx, _sx: float, _sy: float, _dt: float) -> void: pass
func drawClimbMob(_x: Ctx, _e, _sx: float, _sy: float) -> void: pass
func drawYeti(_x: Ctx, _e, _sx: float, _sy: float) -> void: pass
func climbTint(_x: Ctx, _D: Dictionary) -> void: pass
func climbOverlay(_x: Ctx) -> void: pass
