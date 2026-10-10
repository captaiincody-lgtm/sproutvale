extends "res://scripts/bosses.gd"
## Sproutvale, part 6½: the Abyss, the areas beyond the Warlord's Keep (made for the Godot version).
## The Drowned Shore and three underwater maps, their eight monsters, the Abyss debuff (and Inked,
## Confused and knocked off balance), The Dreamer's boss fight, the Dreambox, the Abyssal Devour
## skill, the Dream Key, and the quiet map inside the bubble.
##
## Maps and monster stats live in res://data/abyss.json; art in res://art/abyss (same layout as art/).

## The Dreamer: the boss of the Dreamer's Hollow
const DREAMER_T := {"name": "The Dreamer", "lv": 75, "hp": 120000, "atk": 210, "def": 60, "exp": 80000, "coins": [2500, 4000],
	"color": 0x3e1858, "critter": false, "matName": "Dream Ichor"}
const DR_EYE_DX := 52.0      # the eyes sit this far either side of the head's middle…
const DR_EYE_Y := 104.0      # …with their bottom edge this far above the floor
const DR_MOUTH_Y := 59.0     # the middle of the mouth, above the floor
const DR_TENTS := [70.0, 150.0, 228.0, 412.0, 490.0, 570.0]   # where the tentacles peer up from behind the floor
const ABYSS_MOBS := ["toad", "seagull", "bass", "crab", "shark", "squid", "orca", "octopus"]

var abyssShots: Array = []   # seagull droppings, crab bubbles, squid ink
var Dreamer := {"introDone": false}
var pDevour = null           # the hero's Abyssal Devour, while it chews
var gazeFlash := 0.0         # the purple flash of the Dreamer's (or a squid's) gaze


# ================================================================ data

func initAbyssData() -> void:
	var A: Dictionary = normalize(Assets._json("res://data/abyss.json"))
	for id in A.maps:
		MAPS[id] = A.maps[id]
	for k in A.mobs:
		var T: Dictionary = A.mobs[k]
		T.merge({"aggro": 14, "size": 1, "w": 0, "unlock": T.lv, "critter": true, "ai": "abyss", "residue": T.matName}, false)
		SLIME_TYPES[k] = T
	SLIME_TYPES.orca.kb = 0.25
	SLIME_TYPES.shark.kb = 0.5
	SLIME_TYPES.squid.kb = 0.6
	SLIME_KEYS = SLIME_TYPES.keys()
	BOSS_LIST[2] = {"id": "dreamer", "name": "The Dreamer", "where": "The Dreamer's Hollow"}
	TROPHIES[2] = {"id": "dreamer", "name": "The Dreamer Trophy"}
	MAINQS.append({"title": "The Dreamer", "exp": 40000, "coins": 20000,
		"steps": ["Step through the Dreamer's Gate into the Abyss", "Sink down to the Dreamer's Hollow", "Defeat The Dreamer"], "on": ["abyss1", "abyss5", "dreamer"],
		"blurb": "\"The Dreamer... holds the key to destroying the crystal...\" The Warlord's dying words, and a gate of black water behind his throne."})
	for k in ABYSS_MOBS:
		BEST_ORDER.append(k)
	BEST_ORDER.append("dreamer")
	BEST_TEXT.toad = "A bloated toad that lives where the black water meets the shore. Its tongue lashes out from far away, and it leaps high to land on you with its whole weight."
	BEST_TEXT.seagull = "A tar-black gull that wheels above the dark water. It dive-bombs anyone above the surface, and its droppings carry the Abyss: your max health drains away while it lasts."
	BEST_TEXT.bass = "A bass the size of a person's torso. Swims in circles and bites, and every so often charges from any angle. Each charge feeds the Abyss into you; take enough of them and it takes hold."
	BEST_TEXT.crab = "A crab as big as a tortoise, walking the sea floor. Its claws carry the Abyss, and it blows streams of bubbles that only sting."
	BEST_TEXT.shark = "Bigger than you and never still. It circles, then rushes in for a bite that hits hard and pours the Abyss into the wound."
	BEST_TEXT.squid = "A shark-sized squid. Its ink brings the Abyss and blinds you (you miss more), and when its eyes start to glow, dodge: its gaze leaves you Confused, walking the wrong way."
	BEST_TEXT.orca = "A huge, slow orca of the deep plateau. Its chomp and its tail whip send you spinning helplessly, and one or two of them are enough for the Abyss to take hold."
	BEST_TEXT.octopus = "Small and very fast. Scurries in for a flurry of tentacle slaps, and sometimes grabs you, slams you into the sea floor and flings you away."
	BEST_TEXT.dreamer = "Something vast that sleeps beneath the Abyss, only ever seen from the eyes up. It stares to confuse, whips the ground with its many tentacles, drags whole people into its mouth, and holds the key to Glamrax's crystal."
	MAT_TIPS.toad = "Lumpy warts from an Abyssal Toad. They glow faintly red in the dark."
	MAT_TIPS.seagull = "A feather black as tar. It leaves an oily purple smear on your fingers."
	MAT_TIPS.bass = "A scale from an Abyssal Bass, gone violet at the centre where the corruption sank in."
	MAT_TIPS.crab = "A cracked piece of crab shell with purple veins running through it."
	MAT_TIPS.shark = "A shark tooth, still sharp. The root is stained the colour of the deep."
	MAT_TIPS.squid = "A squid's ink sac. Don't squeeze it."
	MAT_TIPS.orca = "A slab of orca blubber, cold as the deep plateau."
	MAT_TIPS.octopus = "A sucker that still grips anything it touches."
	WM_NODES.abyss1 = {"x": 640, "y": 30}
	WM_NODES.abyss2 = {"x": 530, "y": 66}
	WM_NODES.abyss3 = {"x": 420, "y": 30}
	WM_NODES.abyss4 = {"x": 335, "y": 66}
	WM_NODES.abyss5 = {"x": 245, "y": 30}
	WM_NODES.bubble = {"x": 100, "y": 72}
	MAPS.trophy.w = 1720   # room for the Abyss's cards on the wall


# ================================================================ water helpers

## the sea's surface on this map (-1e9 when the whole map is underwater, +1e9 when there's no sea)
func seaTop() -> float:
	var sea = M.get("sea")
	if sea == null:
		return 1e9
	return float(sea.surface) if sea.surface != null else -1e9


func underSea(x: float, y: float) -> bool:
	var sea = M.get("sea")
	return sea != null and x > sea.x0 and x < sea.x1 and y > seaTop()


## the floor piece under x (for drops and walkers)
func floorSurfAt(x: float) -> Dictionary:
	var best = null
	for s in surfaces:
		if s.floor and x >= s.x0 - 0.5 and x <= s.x1 + 0.5 and (best == null or s.y < best.y):
			best = s
	if best == null:
		for s in surfaces:
			if s.floor and (best == null or absf((s.x0 + s.x1) / 2 - x) < absf((best.x0 + best.x1) / 2 - x)):
				best = s
	return best


## keeps the hero out of the rock steps of the Abyss maps (and below the ceiling underwater)
func seaCollide(prevX: float, prevY: float) -> void:
	var g = groundAt(P.x)
	if P.y > g + 0.5:
		var gp = groundAt(prevX)
		if prevY <= g + 0.5 or (P.grounded and P.y - g <= 6):
			pass   # landing on it from above: the surface code below handles it
		elif P.y <= gp + 0.5 and absf(prevX - P.x) > 0.001:
			P.x = prevX   # walked or swam into the side of a step
			P.vx = 0
		else:
			P.y = g   # stuck inside (after a blink or a fling): pop out on top
			P.vy = minf(P.vy, 0)
	if seaTop() < -1e8 and P.y < 46:   # fully underwater: the top of the map is a ceiling
		P.y = 46
		P.vy = maxf(P.vy, 0)


# ================================================================ the Abyss debuff and friends

## a hit that carries the Abyss: fills the buildup meter (or renews the debuff if it already has you)
func abyssBuild(n: float) -> void:
	if n <= 0 or P.state == "dead":
		return
	P.lastBuild = gameTime
	if P.abyssT > 0:
		P.abyssT = abyssDur()
		return
	P.abyssB += n * (1 - PS.get("abyssRes", 0.0))
	if P.abyssB >= 100:
		applyAbyss()


func applyAbyss() -> void:
	if P.state == "dead":
		return
	var fresh: bool = P.abyssT <= 0
	P.abyssT = abyssDur()
	P.abyssB = 0.0
	P.lastBuild = gameTime
	if fresh:
		floatText(P.x, P.y - 62, "The Abyss takes hold!", "call")
		Sfx.tone(70, 0.9, "sawtooth", 0.1, 40)
		Sfx.tone(140, 0.7, "sine", 0.06, 90)
		for i in 24:
			part(P.x + rand(-10, 10), P.y - rand(0, 40), rand(-40, 40), rand(-60, 10), rand(0.6, 1.1), "#2a0838" if i % 2 else "#c25cff", 0, 2)


## how long the Abyss debuff lasts (shorter with the Attribute Tree's Abyss Walker)
func abyssDur() -> float:
	return 30.0 * (1 - PS.get("abyssDur", 0.0))


func confusePlayer(t: float) -> void:
	if P.state == "dead":
		return
	if P.confuseT <= 0:
		floatText(P.x, P.y - 62, "Confused!", "call")
	P.confuseT = maxf(P.confuseT, t)
	Sfx.tone(600, 0.5, "sine", 0.06, 300)
	Sfx.tone(450, 0.5, "triangle", 0.05, 900, 0.1)


## knocked off balance: a floating spin, then upright again and a slow float down
func tumblePlayer(src, dur: float, power := 1.0) -> void:
	if P.state == "dead" or P.hp <= 0:
		return
	var sx: float = src.get("x")
	var dir: float = sgn(P.x - sx) if P.x != sx else float(-P.face)
	P.state = "tumble"
	P.tumbleT = dur
	P.tumbleDur = dur
	P.spin = 0.0
	P.held = null
	P.grabbed = null
	P.rope = null
	P.grounded = false
	P.surf = null
	P.vx = dir * 170 * power
	P.vy = -210 * power
	P.face = int(dir)
	P.iframes = maxf(P.iframes, 0.5)
	floatText(P.x, P.y - 58, "Off balance!", "call")


## a monster's hit; returns true if it really landed (not dodged, blocked or shrugged off)
func mobHit(e, mul: float, build := 0.0) -> bool:
	var n0 = P.hurtN
	hurtPlayer(e, e.atk * mul)
	if P.hurtN == n0:
		return false
	abyssBuild(build)
	return true


## rapid little hits (an octopus's flurry, the Dreamer's chewing): they ignore the usual
## invulnerability after a hit, but a dodge still slips them and a guard still blocks them
func abyssChip(src, mul: float, build := 0.0, dodgeable := true) -> bool:
	if save.settings.god or P.state == "dead":
		return false
	if dodgeable and P.state == "dash":
		if not P.dodged.has(src):
			P.dodged[src] = true
			perfectDodge()
		return false
	var sx: float = src.get("x")
	if dodgeable and P.state == "block" and (sgn(sx - P.x) == P.face or absf(sx - P.x) < 4):
		Sfx.block()
		var chip = maxi(1, roundi(src.atk * mul * 0.15))
		P.hp -= chip
		floatText(P.x, P.y - 48, str(chip), "hurt")
		if P.hp <= 0:
			killPlayer()
		return false
	var d = treeShield(maxi(1, roundi(src.atk * mul * defMul(src.lv) * rand(0.9, 1.1) * (1 - PS.get("dr", 0.0)))))
	P.hp -= d
	P.lastHurt = gameTime
	P.flash = 0.08
	floatText(P.x + rand(-6, 6), P.y - 46, str(d), "hurt")
	Sfx.play("hurt", 0.6, rand(1.0, 1.2))
	flashVig()
	shake = maxf(shake, 2)
	abyssBuild(build)
	if P.hp <= 0:
		P.held = null
		killPlayer()
	return true


func _shotSrc(x: float, lv: int, atk: float) -> Dictionary:
	return {"x": x, "lv": lv, "atk": atk, "noCrit": true}


func updateAbyss(dt: float) -> void:
	# timers
	P.blindT = maxf(0, P.blindT - dt)
	P.confuseT = maxf(0, P.confuseT - dt)
	gazeFlash = maxf(0, gazeFlash - dt * 1.5)
	if P.state == "dead":
		P.abyssT = 0.0; P.abyssB = 0.0; P.blindT = 0.0; P.confuseT = 0.0; P.held = null
	# the dark water itself works on you: a slow, steady buildup while you're under it
	if P.state != "dead" and P.abyssT <= 0 and M.get("sea") != null and underSea(P.x, P.y - 24):
		abyssBuild(dt * 2.0)
	if gameTime - P.lastBuild > 4 and P.abyssB > 0:
		P.abyssB = maxf(0, P.abyssB - 10 * dt)   # buildup fades if you stop getting hit
	var drain0 = P.abyssDrain
	if P.abyssT > 0:
		P.abyssT -= dt
		P.abyssDrain = minf(0.5 * (1 - PS.get("abyssRes", 0.0)), P.abyssDrain + dt * 0.025)   # half your max HP over 20s (less with Abyss resistance)
		if randf() < dt * 10:
			part(P.x + rand(-9, 9), P.y - rand(4, 42), rand(-8, 8), -rand(8, 26), rand(0.6, 1.0), "#1a0626" if randf() < 0.5 else "#8a3ac8", 0, 1 if randf() < 0.6 else 2)
	elif P.abyssDrain > 0:
		P.abyssDrain = maxf(0, P.abyssDrain - dt * 0.06)   # it lifts again once the debuff ends
	if P.state == "dead":
		P.abyssDrain = 0.0
	if P.abyssDrain != drain0 and PS.has("hpFull"):
		PS.hp = roundi(PS.hpFull * (1 - P.abyssDrain))
		P.hp = minf(P.hp, PS.hp)
	if P.blindT > 0 and randf() < dt * 8:
		part(P.x + P.face * 4 + rand(-4, 4), P.y - 36, rand(-6, 6), rand(4, 14), 0.7, "#0a0410", 0, 2)
	if P.confuseT > 0 and randf() < dt * 5:
		var a = gameTime * 6
		part(P.x + cos(a) * 9, P.y - 48 + sin(a) * 3, 0, -6, 0.5, "#ffb0ff" if randf() < 0.5 else "#fff6a8", 0, 1)
	updateShots(dt)
	updateDevour(dt)
	# the Abyss maps: marine snow and rising bubbles
	if M.get("theme") == "abyss" and randf() < dt * 4 and underSea(P.x, P.y - 40):
		part(P.x + P.face * 6, P.y - 38, rand(-4, 4), -rand(20, 34), rand(0.8, 1.4), "rgba(220,200,255,0.8)", -10, 1)


# ================================================================ projectiles

func addShot(kind: String, x: float, y: float, vx: float, vy: float, src) -> void:
	abyssShots.append({"kind": kind, "x": x, "y": y, "vx": vx, "vy": vy, "t": 0.0, "lv": src.lv, "atk": src.atk, "ox": src.x})


func updateShots(dt: float) -> void:
	var pb = pBox()
	var top = seaTop()
	for i in range(abyssShots.size() - 1, -1, -1):
		var s: Dictionary = abyssShots[i]
		s.t += dt
		var wet = underSea(s.x, s.y)
		match s.kind:
			"poop":
				if wet:
					s.vy = minf(s.vy + 60 * dt, 34)
					s.vx *= exp(-dt * 3)
					if randf() < dt * 10:
						part(s.x, s.y, rand(-6, 6), rand(-4, 4), 0.8, "#4a1460", 0, 1)
				else:
					s.vy += 420 * dt
				if not wet and underSea(s.x, s.y + s.vy * dt):
					splash(s.x, 0.2)
			"bubble":
				s.vx *= exp(-dt * 0.8)
				s.vy = s.vy * exp(-dt * 1.2) - 12 * dt
				s.y += sin(s.t * 14) * 0.2
			"ink":
				s.vx *= exp(-dt * 1.4)
				s.vy *= exp(-dt * 1.4)
				if randf() < dt * 30:
					part(s.x + rand(-3, 3), s.y + rand(-3, 3), rand(-10, 10), rand(-10, 10), rand(0.5, 1.0), "#0a0410" if randf() < 0.7 else "#3a0e3a", 0, 2)
		s.x += s.vx * dt
		s.y += s.vy * dt
		var life: float = {"poop": 4.0, "bubble": 1.6, "ink": 1.3}[s.kind]
		var r: float = {"poop": 2.0, "bubble": 3.0, "ink": 5.0}[s.kind]
		var hit = s.x > pb.x0 - r and s.x < pb.x1 + r and s.y > pb.y0 - r and s.y < pb.y1 + r and P.state != "dead"
		var gone = s.t > life or s.y > groundAt(s.x) or s.x < 0 or s.x > M.w or s.y < 0
		if not gone and s.kind == "poop" and not wet:
			for q in surfaces:
				if not q.floor and s.x > q.x0 and s.x < q.x1 and s.y >= q.y and s.y - s.vy * dt < q.y:
					gone = true
		if hit:
			var src = _shotSrc(s.ox, s.lv, s.atk)
			var n0 = P.hurtN
			match s.kind:
				"poop":
					hurtPlayer(src, s.atk * 0.45)
					if P.hurtN != n0:
						applyAbyss()
						floatText(P.x, P.y - 70, "Ew!", "call")
				"bubble":
					hurtPlayer(src, s.atk * 0.45)
				"ink":
					hurtPlayer(src, s.atk * 0.6)
					if P.hurtN != n0:
						applyAbyss()
						if P.blindT <= 0:
							floatText(P.x, P.y - 70, "Inked! You'll miss more", "call")
						P.blindT = 5.0
			gone = true
		if gone:
			var cols: Array = {"poop": ["#3a1048", "#6a2a88"], "bubble": ["#e8f0ff", "#9fd8ff"], "ink": ["#0a0410", "#3a0e3a"]}[s.kind]
			for k in 8:
				part(s.x, s.y, rand(-50, 50), rand(-60, 20), rand(0.3, 0.6), cols[k % 2], 0 if underSea(s.x, s.y) else 300, 1)
			if s.kind == "bubble":
				Sfx.tone(rand(900, 1300), 0.06, "sine", 0.03, 1800)
			abyssShots.remove_at(i)


# ================================================================ monsters: spawning

func spawnAbyssMob(type: String, T: Dictionary, initial: bool, shiny: bool) -> void:
	var sea = M.get("sea")
	var top = seaTop()
	var hab: String = T.habitat
	var e = _newMob(type, T, 0, 0, null)
	var cands = []
	match hab:
		"shore":
			cands = surfaces.filter(func(q): return not q.get("sea", false) and q.x1 - q.x0 > 50)
		"seabed":
			cands = surfaces.filter(func(q): return q.get("sea", false) and q.x1 - q.x0 > 40)
	var x = 0.0
	var y = 0.0
	var s = null
	for guard in 24:
		if cands.size():
			var wt = 0.0
			for q in cands:
				wt += q.x1 - q.x0
			var pk = randf() * wt
			s = cands[0]
			for q in cands:
				pk -= q.x1 - q.x0
				if pk <= 0:
					s = q
					break
			x = rand(s.x0 + 14, s.x1 - 14)
			y = s.y
		elif sea != null:
			x = rand(sea.x0 + 40, sea.x1 - 40)
			var g = groundAt(x)
			if hab == "air":
				y = top - rand(50, 100)
			else:
				var y0 = (top + e.T.bh + 16) if top > -1e8 else 70.0
				y = rand(minf(y0, g - 20), g - 14)
		if absf(x - P.x) > 140 or absf(y - P.y) > 90:
			break
	e.x = x
	e.y = y
	e.surf = s if s != null else floorSurfAt(x)
	e.homeX = x
	e.homeY = y
	e.w = float(T.bw)
	e.h = float(T.bh)
	e.face = -1 if randf() < 0.5 else 1
	e.t = rand(0, 2)
	e.hopCd = rand(0.5, 2)
	e.atkCd = rand(1, 2.5)
	e.spawnT = 0.0 if initial else 0.5
	e.data = {"cd2": rand(3, 8), "dropCd": rand(1, 3)}
	if shiny:
		makeShiny(e)
	slimes.append(e)


## an Obelisk's elite: the Abyss's monsters keep their own homes (and the big ones grow less)
func abyssElite(e) -> void:
	var T: Dictionary = e.T
	var sc: float = T.get("eliteScale", 2.0)
	e.w = T.bw * sc
	e.h = T.bh * sc
	e.data = {"cd2": rand(3, 6), "dropCd": 1.0, "scale": sc}
	if T.habitat in ["swim", "air"]:
		e.y = minf(e.y, groundAt(e.x) - 10) if T.habitat == "swim" else seaTop() - 70
		e.homeX = e.x
		e.homeY = e.y


# ================================================================ monsters: behaviour

func _setState(e, st: String) -> void:
	e.state = st
	e.t = 0.0
	e.hitDone = false


func _swimTo(e, tx: float, ty: float, sp: float, k: float, dt: float) -> void:
	e.vx = damp(e.vx, clampf((tx - e.x) * 2, -sp, sp), k, dt)
	e.vy = damp(e.vy, clampf((ty - e.y) * 2, -sp, sp), k, dt)


## every Abyss monster runs through here (crimsonAI hands them over); returns true (it moves them itself)
func abyssAI(e, T: Dictionary, dt: float, _dx: float, _dy: float, pb: Dictionary) -> bool:
	var hab: String = T.habitat
	var cx: float = e.x
	var cy: float = e.y - e.h / 2
	var tx: float = P.x - cx
	var ty: float = (P.y - 20) - cy
	var dist = sqrt(tx * tx + ty * ty)
	var sight: float = {"shark": 240.0, "orca": 200.0, "seagull": 210.0}.get(e.type, 170.0)
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
		var k = 3.5 if hab in ["swim", "air"] else 1.0
		e.vx *= exp(-dt * k)
		if hab in ["swim", "air"]:
			e.vy *= exp(-dt * k)
		if e.stun <= 0:
			_setState(e, "chase")
			e.aggro = true
			e.atkCd = maxf(e.atkCd, 0.5)
	else:
		match e.type:
			"toad": _toad(e, T, dt, tx, ty, dist)
			"seagull": _gull(e, T, dt, tx, ty, dist)
			"bass": _bass(e, T, dt, tx, ty, dist)
			"crab": _crab(e, T, dt, tx, ty, dist)
			"shark": _shark(e, T, dt, tx, ty, dist)
			"squid": _squid(e, T, dt, tx, ty, dist)
			"orca": _orca(e, T, dt, tx, ty, dist)
			"octopus": _octopus(e, T, dt, tx, ty, dist)
	# bumping into an awake monster still hurts a little
	if e.aggro and alive and not (e.state in ["hurt", "act", "grab"]) and overlap(sBox(e), pb) and P.touchCd <= 0:
		P.touchCd = 0.9
		hurtPlayer(e, roundf(e.atk * 0.5))
	_abyssPhysics(e, T, dt)
	return true


func _abyssPhysics(e, T: Dictionary, dt: float) -> void:
	var hab: String = T.habitat
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
	var sea = M.get("sea")
	var top = seaTop()
	match hab:
		"swim":
			e.x += e.vx * dt
			e.y += e.vy * dt
			var x0 = 24.0 + e.w / 2
			var x1 = M.w - 24.0 - e.w / 2
			if sea != null:
				x0 = maxf(x0, sea.x0 + e.w / 2)
				x1 = minf(x1, sea.x1 - e.w / 2)
			e.x = clampf(e.x, x0, x1)
			var yTop = (top + e.h + 4) if top > -1e8 else 48.0 + e.h
			var g = groundAt(e.x)
			e.y = clampf(e.y, yTop, maxf(yTop, g - 1))
			e.surf = floorSurfAt(e.x)
		"air":
			e.x = clampf(e.x + e.vx * dt, 24, M.w - 24)
			e.y = clampf(e.y + e.vy * dt, 30, (top - 6) if top < 1e8 else M.floorY - 30)
			e.surf = floorSurfAt(e.x)
		"seabed":
			e.vy = minf(140, e.vy + GRAV * 0.3 * dt)
			e.vy *= exp(-dt * 1.2)
			if e.state in ["idle", "chase"]:
				e.vx = damp(e.vx, e.walk, 10, dt)
			var nx = e.x + e.vx * dt
			if sea != null:
				nx = clampf(nx, sea.x0 + e.w / 2 + 2, sea.x1 - e.w / 2 - 2)
			nx = clampf(nx, 24 + e.w / 2, M.w - 24 - e.w / 2)
			if groundAt(nx) < e.y - 10:   # a rock step in the way
				nx = e.x
				e.vx = 0
				if e.state == "idle":
					e.face *= -1
			e.x = nx
			e.y += e.vy * dt
			var g = groundAt(e.x)
			if e.y >= g:
				e.y = g
				e.vy = 0
			e.surf = floorSurfAt(e.x)
		"shore":
			var wetM = underSea(e.x, e.y - 4)
			e.vy = minf(MAXFALL, e.vy + GRAV * (0.25 if wetM else 0.85) * dt)
			if e.state in ["idle", "chase"] and e.y >= e.surf.y - 0.01:
				e.vx = damp(e.vx, e.walk, 12, dt)
			e.x += e.vx * dt
			e.y += e.vy * dt
			if e.y >= e.surf.y:
				if e.vy > 60:
					e.sq = 0.35
				e.y = e.surf.y
				e.vy = 0
				e.vx *= exp(-dt * (5 if e.state == "hurt" else 14))
			var lo: float = e.surf.x0 + e.w / 2
			var hi: float = e.surf.x1 - e.w / 2
			if e.x < lo:
				e.x = lo; e.vx = absf(e.vx) * 0.3
				if e.state == "idle": e.face = 1
			if e.x > hi:
				e.x = hi; e.vx = -absf(e.vx) * 0.3
				if e.state == "idle": e.face = -1
	e.sq += (0 - e.sq) * minf(1, dt * 10)


# ---------------- Abyssal Toad: tongue lash, and a leap that comes down on you

func _toad(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var grounded: bool = e.y >= e.surf.y - 0.01 and e.vy >= 0
	match e.state:
		"idle":
			e.walk = 0
			if grounded and e.hopCd <= 0:
				e.hopCd = rand(1.2, 2.8)
				if randf() < 0.4:
					e.face *= -1
				e.vy = -150; e.vx = e.face * 40; e.sq = -0.3
		"chase":
			e.walk = 0
			e.face = int(sgn(tx)) if tx != 0 else e.face
			if grounded and e.atkCd <= 0 and absf(ty) < 40:
				if absf(tx) < 96 and absf(ty) < 26 and randf() < 0.55:
					e.move = "tongue"
					_setState(e, "wind")
				elif absf(tx) < 120:
					e.move = "slam"
					_setState(e, "wind")
					Sfx.tone(160, 0.3, "sine", 0.06, 90)
			elif grounded and e.hopCd <= 0 and absf(tx) > 34:
				e.vy = -170; e.vx = e.face * 70 * T.speed; e.hopCd = rand(0.6, 1.1); e.sq = -0.3
		"wind":
			e.vx *= exp(-dt * 10)
			if e.move == "tongue" and e.t > 0.4:
				_setState(e, "act")
				e.data.tongue = 0.0
				Sfx.tone(700, 0.12, "square", 0.05, 200)
			elif e.move == "slam" and e.t > 0.35:
				_setState(e, "act")
				e.vy = -440
				e.vx = clampf((P.x - e.x) * 1.7, -180, 180)
				e.data.air = true
				Sfx.whoosh(0.7, true)
		"act":
			if e.move == "tongue":
				# out over 0.15s, a beat, back over 0.2s
				var ext = clampf(e.t / 0.15, 0, 1) if e.t < 0.23 else clampf(1 - (e.t - 0.23) / 0.2, 0, 1)
				e.data.tongue = ext
				var tipX: float = e.x + e.face * (10 + 86 * ext)
				var tipY: float = e.y - 9
				var pb = pBox()
				var lo = minf(e.x + e.face * 10, tipX)
				var hi = maxf(e.x + e.face * 10, tipX)
				if not e.hitDone and ext > 0.3 and pb.x1 > lo and pb.x0 < hi and tipY > pb.y0 and tipY < pb.y1 + 2:
					e.hitDone = true
					mobHit(e, 1.0)
				if e.t > 0.45:
					e.data.tongue = 0.0
					_setState(e, "recover")
			else:
				if e.t > 0.15 and grounded:
					var hb = hbox(e.x - 28, e.x + 28, e.y - 32, e.y + 2)
					if overlap(hb, pBox()):
						mobHit(e, 1.5)
					dust(e.x, e.y, 12)
					shake = maxf(shake, 4)
					Sfx.slam()
					e.data.air = false
					_setState(e, "recover")
		"recover":
			e.vx *= exp(-dt * 8)
			if e.t > 0.6:
				_setState(e, "chase")
				e.atkCd = rand(1.4, 2.4)


# ---------------- Abyssal Seagull: dive-bombs, and droppings that carry the Abyss

func _gull(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var top = seaTop()
	var headUp: bool = P.y - 38 < top or not inWater()
	e.data.dropCd = e.data.get("dropCd", 2.0) - dt
	e.data.dropT = maxf(0, e.data.get("dropT", 0.0) - dt)
	var homeY: float = e.homeY
	match e.state:
		"idle":
			var gx: float = e.homeX + sin(e.t * 0.5 + e.id) * 70
			var gy: float = homeY + sin(e.t * 1.4 + e.id) * 8
			_swimTo(e, gx, gy, 70, 2, dt)
			e.face = 1 if e.vx >= 0 else -1
		"chase":
			var hy: float = minf(homeY, P.y - 80) if headUp else homeY
			_swimTo(e, P.x - sgn(tx) * 6 + sin(e.t * 1.7) * 18, hy + sin(e.t * 2.2) * 6, 110 * T.speed, 2.5, dt)
			e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
			if e.data.dropCd <= 0 and absf(tx) < 22 and ty > 20:
				e.data.dropCd = rand(2.6, 4.6)
				e.data.dropT = 0.35
				addShot("poop", e.x, e.y + 2, e.vx * 0.3, 30, e)
				Sfx.tone(300, 0.12, "sine", 0.05, 120)
			elif e.atkCd <= 0 and headUp and dist < 150 and ty > 10:
				_setState(e, "wind")
				Sfx.tone(1400, 0.18, "sawtooth", 0.04, 700)
		"wind":
			e.vx *= exp(-dt * 6); e.vy = damp(e.vy, -30, 4, dt)
			e.face = int(sgn(tx)) if tx != 0 else e.face
			if e.t > 0.4:
				var a = atan2((P.y - 20) - e.y, P.x - e.x)
				e.vx = cos(a) * 280; e.vy = sin(a) * 280
				_setState(e, "act")
				Sfx.whoosh(1.4, false)
		"act":
			if not e.hitDone and overlap(sBox(e), pBox()):
				e.hitDone = true
				mobHit(e, 1.1)
			if e.y >= top - 8 and e.vy > 0:   # pulls up at the water
				splash(e.x, 0.3)
				e.vy = -60
				_setState(e, "recover")
			if e.t > 0.6:
				_setState(e, "recover")
		"recover":
			e.vx *= exp(-dt * 2)
			e.vy = damp(e.vy, -90, 3, dt)
			if e.t > 0.8 or e.y < homeY:
				_setState(e, "chase")
				e.atkCd = rand(2.2, 3.8)


# ---------------- Abyssal Bass: circles and bites; sometimes charges from any angle (Abyss buildup)

func _bass(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var sp: float = T.speed
	match e.state:
		"idle":
			_swimTo(e, e.homeX + sin(e.t * 0.4 + e.id) * 80, e.homeY + sin(e.t * 0.9 + e.id) * 20, 40, 2, dt)
			e.face = 1 if e.vx >= 0 else -1
		"chase":
			var a = e.t * 1.3 + e.id
			_swimTo(e, P.x + cos(a) * 34, P.y - 20 + sin(a) * 20, 95 * sp, 2.5, dt)
			e.face = int(sgn(tx)) if tx != 0 else e.face
			if e.data.cd2 <= 0 and dist < 190:
				e.move = "charge"
				_setState(e, "wind")
				var ang = randf() * TAU
				e.data.cx = P.x + cos(ang) * 110
				e.data.cy = clampf(P.y - 20 + sin(ang) * 80, seaTop() + 30, groundAt(P.x) - 20)
			elif e.atkCd <= 0 and dist < 34:
				e.move = "bite"
				_setState(e, "act")
				var n = Vector2(tx, ty).normalized()
				e.vx = n.x * 150; e.vy = n.y * 150
				Sfx.tone(240, 0.08, "square", 0.05, 160)
		"wind":
			# swim off to a new angle, quiver, then charge
			if e.t < 1.0 and Vector2(e.data.cx - e.x, e.data.cy - e.y).length() > 12:
				_swimTo(e, e.data.cx, e.data.cy, 140 * sp, 3, dt)
				e.face = 1 if e.vx >= 0 else -1
				e.data.q = 0.0
			else:
				e.vx *= exp(-dt * 8); e.vy *= exp(-dt * 8)
				e.face = int(sgn(tx)) if tx != 0 else e.face
				e.data.q = e.data.get("q", 0.0) + dt
				if e.data.q > 0.45:
					var n = Vector2(P.x - e.x, (P.y - 20) - (e.y - e.h / 2)).normalized()
					e.vx = n.x * 320; e.vy = n.y * 320
					_setState(e, "act")
					Sfx.tone(180, 0.25, "sawtooth", 0.06, 90)
		"act":
			if e.move == "bite":
				if not e.hitDone and overlap(sBox(e), pBox()):
					e.hitDone = true
					mobHit(e, 1.0)
				if e.t > 0.3:
					_setState(e, "recover")
			else:
				if randf() < dt * 30:
					part(e.x - e.face * 12, e.y - e.h / 2, -e.vx * 0.1, -e.vy * 0.1, 0.4, "rgba(220,200,255,0.8)", 0, 1)
				if not e.hitDone and overlap(sBox(e), pBox()):
					e.hitDone = true
					mobHit(e, 1.2, 34)
				if e.t > 0.6:
					_setState(e, "recover")
					e.data.cd2 = rand(4, 7)
		"recover":
			e.vx *= exp(-dt * 3); e.vy *= exp(-dt * 3)
			if e.t > 0.5:
				_setState(e, "chase")
				e.atkCd = rand(1.0, 1.6)


# ---------------- Abyssal Crab: Abyss-laced claws, and streams of stinging bubbles

func _crab(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var sp: float = T.speed
	match e.state:
		"idle":
			if e.hopCd <= 0:
				e.hopCd = rand(1, 2.5)
				e.face = -1 if randf() < 0.5 else 1
				e.pause = 1.0 if randf() < 0.35 else 0.0
			e.walk = 0.0 if e.pause > 0 else e.face * 22 * sp
			e.pause -= dt
		"chase":
			e.face = int(sgn(tx)) if tx != 0 else e.face
			e.walk = e.face * 46 * sp if absf(tx) > 22 else 0.0
			if e.atkCd <= 0 and absf(tx) < 38 and absf(ty) < 30:
				e.move = "pinch"
				_setState(e, "wind")
				e.walk = 0
			elif e.data.cd2 <= 0 and absf(tx) > 50 and absf(tx) < 220 and absf(ty) < 90:
				e.move = "beam"
				_setState(e, "wind")
				e.walk = 0
		"wind":
			e.walk = 0
			if randf() < dt * 20 and e.move == "beam":
				part(e.x + e.face * 8, e.y - 12, rand(-6, 6), -rand(10, 30), 0.6, "rgba(230,240,255,0.9)", 0, 1)
			if e.t > (0.35 if e.move == "pinch" else 0.6):
				_setState(e, "act")
				e.data.shot = 0.0
				if e.move == "pinch":
					Sfx.tone(900, 0.06, "square", 0.05, 500)
		"act":
			e.walk = 0
			if e.move == "pinch":
				var hb = hbox(e.x, e.x + 36, e.y - 26, e.y) if e.face > 0 else hbox(e.x - 36, e.x, e.y - 26, e.y)
				if not e.hitDone and e.t > 0.05 and overlap(hb, pBox()):
					e.hitDone = true
					mobHit(e, 1.0, 25)
				if e.t > 0.3:
					_setState(e, "recover")
			else:
				e.data.shot -= dt
				e.face = int(sgn(tx)) if tx != 0 else e.face
				if e.data.shot <= 0:
					e.data.shot = 0.12
					var n = Vector2(P.x - (e.x + e.face * 10), (P.y - 22) - (e.y - 12)).normalized().rotated(rand(-0.12, 0.12))
					addShot("bubble", e.x + e.face * 10, e.y - 12, n.x * 160, n.y * 160, e)
					Sfx.tone(rand(500, 800), 0.05, "sine", 0.03, 1200)
				if e.t > 1.0:
					_setState(e, "recover")
					e.data.cd2 = rand(6, 9)
		"recover":
			e.walk = 0
			if e.t > 0.5:
				_setState(e, "chase")
				e.atkCd = rand(1.0, 1.8)


# ---------------- Abyssal Shark: never stops swimming; a heavy bite that pours in the Abyss

func _shark(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var sp: float = T.speed
	var minSpeed = 60.0
	match e.state:
		"idle":
			if (e.x - e.homeX) * e.face > 200:
				e.face *= -1
			e.vx = damp(e.vx, e.face * 70, 1.2, dt)
			e.vy = damp(e.vy, (e.homeY + sin(e.t * 0.7 + e.id) * 24 - e.y) * 1.5, 2, dt)
		"chase":
			# swim past, turn, come back around
			var ahead = (P.x - e.x) * e.face
			if ahead < -70:
				e.face *= -1
			e.vx = damp(e.vx, e.face * 110 * sp, 1.5, dt)
			e.vy = damp(e.vy, clampf(((P.y - 26) - e.y) * 1.4, -70, 70), 2, dt)
			if e.atkCd <= 0 and ahead > 20 and ahead < 130 and absf(ty) < 50:
				_setState(e, "wind")
				Sfx.tone(120, 0.3, "sawtooth", 0.05, 70)
		"wind":
			e.vx = damp(e.vx, e.face * minSpeed, 4, dt)
			e.vy *= exp(-dt * 4)
			if e.t > 0.35:
				var n = Vector2(P.x - e.x, (P.y - 20) - (e.y - e.h / 2)).normalized()
				if n.x * e.face < 0.2:
					n = Vector2(e.face, n.y).normalized()
				e.vx = n.x * 280; e.vy = n.y * 280
				_setState(e, "act")
				Sfx.whoosh(0.6, true)
		"act":
			var mouth = hbox(e.x + e.face * e.w * 0.25 - 14, e.x + e.face * e.w * 0.25 + 14 + e.face * 20, e.y - e.h, e.y)
			if mouth.x0 > mouth.x1:
				mouth = hbox(mouth.x1, mouth.x0, mouth.y0, mouth.y1)
			if not e.hitDone and overlap(mouth, pBox()):
				e.hitDone = true
				if mobHit(e, 1.6, 40):
					Sfx.tone(90, 0.2, "square", 0.08, 60)
			if e.t > 0.5:
				_setState(e, "recover")
		"recover":
			e.vx = damp(e.vx, e.face * 90, 1.0, dt)
			e.vy *= exp(-dt * 2)
			if e.t > 0.7:
				_setState(e, "chase")
				e.atkCd = rand(2.2, 3.4)
	if e.state != "hurt" and absf(e.vx) < minSpeed:
		e.vx = e.face * minSpeed
	if e.state != "act":
		e.face = 1 if e.vx >= 0 else -1


# ---------------- Abyssal Squid: blinding ink, and a gaze that turns you around

func _squid(e, T: Dictionary, dt: float, tx: float, ty: float, dist: float) -> void:
	var sp: float = T.speed
	match e.state:
		"idle":
			# drifts, then pulses
			if e.hopCd <= 0:
				e.hopCd = rand(1.0, 1.8)
				e.vy = -rand(50, 80); e.vx = rand(-30, 30)
			e.vx *= exp(-dt * 1.2); e.vy = damp(e.vy, 18, 1.0, dt)
			if e.y < e.homeY - 50:
				e.vy = absf(e.vy)
		"chase":
			var want = 110.0
			var gx = P.x - sgn(tx) * want
			_swimTo(e, gx, P.y - 10 + sin(e.t * 1.5) * 16, 80 * sp, 1.6, dt)
			e.face = int(sgn(tx)) if tx != 0 else e.face
			if e.data.cd2 <= 0 and dist < 210:
				e.move = "gaze"
				_setState(e, "wind")
				e.data.dodged = false
				floatText(e.x, e.y - e.h - 14, "Its eyes glow...", "call")
				Sfx.tone(300, 1.0, "sine", 0.05, 900)
			elif e.atkCd <= 0 and dist < 180:
				e.move = "ink"
				_setState(e, "wind")
		"wind":
			e.vx *= exp(-dt * 4); e.vy *= exp(-dt * 4)
			e.face = int(sgn(tx)) if tx != 0 else e.face
			if e.move == "gaze":
				if e.t > 0.7 and P.state == "dash":
					e.data.dodged = true
				if e.t > 1.05:
					gazeFlash = maxf(gazeFlash, 0.5)
					if e.data.dodged or P.state == "dash":
						floatText(P.x, P.y - 62, "Dodged the gaze!", "call")
						perfectDodge()
					elif dist < 240 and P.state != "dead" and not save.settings.god:
						confusePlayer(10.0)
					_setState(e, "recover")
					e.data.cd2 = rand(10, 14)
			elif e.t > 0.5:
				var n = Vector2(P.x - e.x, (P.y - 22) - (e.y - 34)).normalized()
				addShot("ink", e.x + n.x * 10, e.y - 34 + n.y * 10, n.x * 170, n.y * 170, e)
				e.vx = -n.x * 90; e.vy = -n.y * 90
				Sfx.burst(0.2, "lowpass", 600, 200, 0.2)
				_setState(e, "act")
		"act":
			e.vx *= exp(-dt * 2); e.vy *= exp(-dt * 2)
			if e.t > 0.4:
				_setState(e, "recover")
		"recover":
			e.vx *= exp(-dt * 2); e.vy *= exp(-dt * 2)
			if e.t > 0.6:
				_setState(e, "chase")
				e.atkCd = rand(2.4, 3.6)


# ---------------- Abyssal Orca: slow and huge; chomps and tail whips send you spinning

func _orca(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var sp: float = T.speed
	var orcaHit = func(mul: float):
		var heavy = rand(55, 70) if randf() < 0.7 else 100.0   # one or two of these, and the Abyss has you
		if mobHit(e, mul, heavy):
			tumblePlayer(e, 1.8)
			shake = maxf(shake, 7)
			Sfx.slam()
	match e.state:
		"idle":
			if (e.x - e.homeX) * e.face > 160:
				e.face *= -1
			e.vx = damp(e.vx, e.face * 35, 1, dt)
			e.vy = damp(e.vy, (e.homeY + sin(e.t * 0.5 + e.id) * 14 - e.y), 1, dt)
		"chase":
			var front = (P.x - e.x) * e.face
			if front < -90 and e.t > 1.0:
				e.face *= -1
				e.t = 0
			e.vx = damp(e.vx, sgn(tx) * 55 * sp if absf(tx) > 60 else 0.0, 1.0, dt)
			e.vy = damp(e.vy, clampf(((P.y - 14) - e.y) * 1.0, -40, 40), 1.2, dt)
			if e.atkCd <= 0 and front > 0 and front < 110 and absf(ty) < 50:
				e.move = "chomp"
				_setState(e, "wind")
				Sfx.tone(80, 0.6, "sawtooth", 0.07, 50)
			elif e.data.cd2 <= 0 and front < 0 and front > -120 and absf(ty) < 50:
				e.move = "tail"
				_setState(e, "wind")
				Sfx.tone(100, 0.4, "sine", 0.06, 60)
		"wind":
			e.vx *= exp(-dt * 4); e.vy *= exp(-dt * 4)
			if e.t > (0.7 if e.move == "chomp" else 0.45):
				_setState(e, "act")
				if e.move == "chomp":
					e.vx = e.face * 210
					Sfx.whoosh(0.5, true)
				else:
					Sfx.whoosh(0.7, true)
		"act":
			if e.move == "chomp":
				var hx: float = e.x + e.face * e.w * 0.45
				var hb = hbox(hx - 24, hx + 24, e.y - e.h - 6, e.y + 6)
				if not e.hitDone and overlap(hb, pBox()):
					e.hitDone = true
					orcaHit.call(2.0)
				e.vx *= exp(-dt * 3)
				if e.t > 0.45:
					_setState(e, "recover")
			else:
				var a = e.x - e.face * e.w * 0.25
				var b = e.x - e.face * (e.w * 0.5 + 26)
				var hb = hbox(minf(a, b), maxf(a, b), e.y - e.h - 16, e.y + 10)
				if not e.hitDone and e.t > 0.08 and overlap(hb, pBox()):
					e.hitDone = true
					orcaHit.call(1.6)
				if e.t > 0.35:
					_setState(e, "recover")
					e.data.cd2 = rand(3, 5)
		"recover":
			e.vx *= exp(-dt * 2); e.vy *= exp(-dt * 2)
			if e.t > 0.9:
				_setState(e, "chase")
				e.atkCd = rand(2.6, 3.8)


# ---------------- Abyssal Octopus: fast; tentacle flurries, and a grab, slam and fling

func _octopus(e, T: Dictionary, dt: float, tx: float, ty: float, _dist: float) -> void:
	var sp: float = T.speed
	match e.state:
		"idle":
			if e.hopCd <= 0:
				e.hopCd = rand(0.6, 1.8)
				e.face = -1 if randf() < 0.5 else 1
				e.pause = 0.8 if randf() < 0.4 else 0.0
			e.walk = 0.0 if e.pause > 0 else e.face * 60 * sp
			e.pause -= dt
		"chase":
			e.face = int(sgn(tx)) if tx != 0 else e.face
			e.walk = e.face * 62 * sp if absf(tx) > 16 else 0.0
			if e.data.cd2 <= 0 and absf(tx) < 26 and absf(ty) < 28 and P.held == null and not (P.state in ["dash", "tumble", "dead"]) and P.iframes <= 0:
				_setState(e, "grab")
				e.walk = 0
				P.held = {"kind": "octo", "e": e, "phase": "lift", "t": 0.0, "y0": P.y}
				P.state = "held"
				P.vx = 0; P.vy = 0
				floatText(P.x, P.y - 62, "Grabbed!", "call")
				Sfx.tone(140, 0.3, "sawtooth", 0.07, 90)
				e.data.cd2 = rand(8, 12)
			elif e.atkCd <= 0 and absf(tx) < 30 and absf(ty) < 26:
				_setState(e, "wind")
				e.walk = 0
		"wind":
			e.walk = 0
			if e.t > 0.25:
				_setState(e, "act")
				e.data.slap = 0.0
				e.data.n = 0
		"act":
			e.walk = 0
			e.data.slap -= dt
			if e.data.slap <= 0 and e.data.n < 5:
				e.data.slap = 0.16
				e.data.n += 1
				var hb = hbox(e.x - 6, e.x + 32, e.y - 28, e.y) if e.face > 0 else hbox(e.x - 32, e.x + 6, e.y - 28, e.y)
				Sfx.tone(rand(300, 420), 0.04, "square", 0.04, 200)
				if overlap(hb, pBox()):
					abyssChip(e, 0.35, rand(8, 12))
			if e.t > 0.85:
				_setState(e, "recover")
		"grab":
			e.walk = 0
			if P.held == null or P.held.get("e") != e:
				_setState(e, "recover")
		"recover":
			e.walk = 0
			if e.t > 0.45:
				_setState(e, "chase")
				e.atkCd = rand(1.4, 2.2)


# ================================================================ being held (tentacles) or eaten

## runs instead of the usual hero update while something holds you; false when nothing does
func abyssHold(dt: float) -> bool:
	var H = P.held
	if H == null:
		if P.state == "held":
			P.state = "move"
		return false
	var e = H.e
	H.t += dt
	P.state = "held"
	P.iframes = maxf(P.iframes, 0.25)
	P.vx = 0; P.vy = 0
	P.grounded = false
	P.surf = null
	P.animT += dt
	setAnim("hurt")
	match H.kind:
		"octo", "tent":
			var tent = H.kind == "tent"
			if e.state == "dead" or (not tent and e.state != "grab"):
				P.held = null
				P.state = "move"
				return false
			var hx: float = H.get("hx", e.x + e.face * 8)
			var lift = 70.0 if tent else 40.0
			var tLift = 0.6 if tent else 0.5
			var ground: float = H.y0
			if H.phase == "lift":
				var k = easeOut(H.t / tLift)
				P.x = hx
				P.y = ground - lift * k
				if H.t >= tLift:
					H.phase = "slam"; H.t = 0.0
					Sfx.whoosh(0.6, true)
			elif H.phase == "slam":
				var k = easeIn(H.t / 0.2)
				P.y = ground - lift * (1 - k)
				if H.t >= 0.2:
					P.y = ground
					dust(P.x, P.y, 14)
					shake = maxf(shake, 7)
					Sfx.slam()
					abyssChip(e, 1.4 if tent else 1.2, 15.0 if tent else 12.0, false)
					P.held = null
					if P.state != "dead":
						P.state = "move"
						tumblePlayer({"x": P.x - (e.face if not tent else sgn(M.w / 2.0 - P.x)) * 10}, 1.0 if tent else 0.9, 1.25)
						P.vy = -280
					if not tent:
						_setState(e, "recover")
			return true
		"eaten":
			# inside the Dreamer's mouth: three chews, then it spits you out
			if e.state == "dead":
				_spitOut(e)
				return false
			var my = M.floorY - DR_MOUTH_Y + e.data.get("sink", 0.0)
			P.x = e.x
			P.y = my + 20
			if H.t > 0.65:
				H.t = 0.0
				H.n += 1
				e.data.chew = 0.25
				shake = maxf(shake, 6)
				Sfx.tone(70, 0.18, "square", 0.1, 40)
				Sfx.burst(0.15, "lowpass", 900, 200, 0.3)
				for k in 10:
					part(e.x + rand(-14, 14), my + rand(-8, 8), rand(-80, 80), rand(-80, 20), 0.5, "#ff6a8a" if k % 2 else "#2a0a20", 0, 2)
				abyssChip(e, 0.9, 30.0, false)
				if P.state == "dead":
					P.held = null
					return false
				if H.n >= 3:
					_spitOut(e)
					return false
			return true
	return false


func _spitOut(e) -> void:
	P.held = null
	P.state = "move"
	var side = -1.0 if randf() < 0.5 else 1.0
	P.x = e.x + side * 10
	P.y = M.floorY - DR_MOUTH_Y + 20
	e.data.mouth = 0.0
	if e.state != "dead":
		e.data.act = ""
		e.data.cd = 1.8
	Sfx.burst(0.35, "lowpass", 1200, 300, 0.35)
	Sfx.tone(160, 0.3, "sawtooth", 0.08, 400)
	for k in 30:
		part(P.x, P.y - 20, side * rand(40, 200), rand(-140, 40), rand(0.4, 0.9), "#ff6a8a" if k % 3 else "#e8dcff", 0, 2)
	tumblePlayer({"x": e.x}, 2.0, 1.2)
	P.vx = side * 210
	P.vy = -220


# ================================================================ The Dreamer

func _dreamer():
	for e in slimes:
		if e.bossKind == "dreamer":
			return e
	return null


func spawnDreamer() -> void:
	abyssShots.clear()
	var fl = floorSurfAt(M.w / 2.0)
	var e = _newMob("dreamer", DREAMER_T, M.w / 2.0, M.floorY - DR_EYE_Y, fl)
	e.boss = true; e.bossKind = "dreamer"; e.face = -1; e.state = "intro"; e.aggro = true
	e.w = 136; e.h = 22; e.showBar = 99
	var tents = []
	for i in DR_TENTS.size():
		tents.append({"bx": DR_TENTS[i], "state": "peek", "t": rand(0, 6), "h": rand(26, 60), "tx": 0.0, "ty": 0.0, "part": null, "side": -1 if DR_TENTS[i] < M.w / 2.0 else 1})
	e.data = {"rise": 0.0, "sink": 170.0, "act": "", "cd": 2.5, "tents": tents, "gaze": 0.0, "mouth": 0.0, "chew": 0.0, "queue": [],
		"lastGaze": -99.0, "lastSuck": -99.0, "lastGrab": -99.0, "eyeHurt": [0.0, 0.0], "blink": 3.0, "parts": [],
		"lastLaser": -99.0, "laser": 0.0, "laserX": 0.0, "laserDir": 1, "laserHit": false}
	slimes.append(e)
	# the parts you can hit: two eyes, the mouth (only while it gapes), and the tentacles
	var eyes = []
	for s in [-1, 1]:
		var p = _part(e, "eye", 1.5, 30, 20)
		p.data.side = s
		eyes.append(p)
	var mouth = _part(e, "mouth", 2.0, 50, 40)
	mouth.state = "dead"
	for T in tents:
		T.part = _part(e, "tent", 1.0, 20, 20)
	if Dreamer.introDone:
		e.data.riseSpeed = 1 / 1.2
	else:
		e.data.riseSpeed = 1 / 3.2
		P.frozen = true
	Sfx.tone(40, 3.0, "sawtooth", 0.1, 30)


func _part(owner, kind: String, mul: float, w: float, h: float):
	var p = _newMob("dreamer", DREAMER_T, owner.x, owner.y, owner.surf)
	p.bossPart = true; p.owner = owner; p.partMul = mul; p.w = w; p.h = h
	p.state = "idle"; p.aggro = true
	p.data = {"kind": kind}
	owner.data.parts.append(p)
	slimes.append(p)
	return p


## the head's vertical offset (it rises from behind the floor, and sinks when it dies)
func _drOff(e) -> float:
	return e.data.sink


func updatePart(p, dt: float) -> void:
	var e = p.owner
	p.flash -= dt
	if e == null or not slimes.has(e):
		slimes.erase(p)
		return
	if e.state == "dead":
		p.state = "dead"
		return
	var off = _drOff(e)
	match p.data.kind:
		"eye":
			p.x = e.x + p.data.side * DR_EYE_DX
			p.y = M.floorY - DR_EYE_Y + off
			p.state = "idle" if off < 60 else "dead"
		"mouth":
			p.x = e.x
			p.y = M.floorY - DR_MOUTH_Y + 20 + off
			p.state = "idle" if e.data.mouth > 0.5 and off < 30 else "dead"


## one hit per swing: a sweep that catches an eye and a tentacle at once only counts once
func dreamerHitOk(e, mv: Dictionary) -> bool:
	if e.state == "intro":
		return false
	var key = "%s|%d" % [mv.get("anim", mv.get("skillId", "")), int(gameTime * 1000)]
	if e.data.get("lastKey") == key:
		return false
	e.data.lastKey = key
	return true


func damagePart(p, mv: Dictionary) -> void:
	var e = p.owner
	if e == null or e.state == "dead" or p.state == "dead" or e.state == "intro":
		return
	if P.blindT > 0 and randf() < 0.4:
		floatText(p.x, p.y - p.h - 6, "Miss", "call")
		return
	if not dreamerHitOk(e, mv):
		return
	var crit = treeCrit() or randf() * 100 < PS.crit
	var dmg: float = PS.atk * mv.get("dmg", 1.0) * rand(0.9, 1.1) * 100 / (100 + e.def * 4) * p.partMul * treeHitMul(e, crit)
	if crit:
		dmg *= PS.critDmg
	if save.settings.get("god"):
		dmg *= 40
	if buffOn("enrage"):
		dmg *= 1.25 + skillRank("enrage") * 0.02
	if PS.get("hunt"):
		dmg *= 1 + PS.hunt
	treeLeech(crit)
	dmg = treeAfterHit(e, crit, maxf(1, roundf(dmg)))
	e.hp -= dmg
	e.hurtFlash = 0.07
	p.flash = 0.12
	floatText(p.x, p.y - p.h - 6, str(int(dmg)), "crit" if crit else "dmg")
	if p.data.kind == "eye":
		e.data.eyeHurt[0 if p.data.side < 0 else 1] = 0.35
	elif p.data.kind == "tent":
		for T in e.data.tents:
			if T.part == p and T.state == "peek":
				T.h = maxf(14, T.h - 12)   # it flinches back down
	sparks(p.x, p.y - p.h * 0.5, "#ffe14d" if crit else "#ffffff", 10 if crit else 6)
	goo(p.x, p.y - p.h * 0.5, 0x8a2aa0, 3)
	hitstop = maxf(hitstop, 0.09 if mv.get("heavy") else 0.045)
	shake = maxf(shake, 5.0 if mv.get("heavy") else (3.0 if crit else 1.5))
	Sfx.hit(crit)
	styleAdd(mv.get("style", 10) * (1.3 if crit else 1.0), mv.get("anim", ""))
	comboHit()
	if e.hp <= 0:
		killSlime(e)


func _tentTip(e, T: Dictionary) -> Vector2:
	var off = _drOff(e)
	match T.state:
		"peek", "sink", "rise":
			return Vector2(T.bx + sin(T.t * 1.3) * 8, M.floorY - T.h + off)
		"whip", "lie":
			return Vector2(T.tx, T.ty)
		"grab":
			return Vector2(T.tx, T.ty - T.h)
	return Vector2(T.bx, M.floorY)


func updateDreamer(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.t += dt
	e.hurtFlash -= dt
	D.chew = maxf(0, D.chew - dt)
	D.eyeHurt[0] = maxf(0, D.eyeHurt[0] - dt)
	D.eyeHurt[1] = maxf(0, D.eyeHurt[1] - dt)
	D.blink -= dt
	if D.blink < -0.15:
		D.blink = rand(2.5, 5.5)
	# ---- dying: a gurgling cry, then it sinks back beneath the floor
	if e.state == "dead":
		D.mouth = damp(D.mouth, 0.3, 3, dt)
		for T in D.tents:
			T.state = "sink"
			T.h = maxf(0, T.h - dt * 30)
			T.part.state = "dead"
		if e.dying:
			e.deadT = 0
			if randf() < dt * 10:
				part(e.x + rand(-60, 60), M.floorY - rand(20, 150), rand(-10, 10), -rand(20, 50), 1.0, "rgba(220,200,255,0.8)", 0, 1)
			return
		D.sink = minf(170, D.sink + dt * 70)
		e.deadT = D.sink / 170 * 2.5   # gone (removed) once fully sunk (past 2.4)
		if randf() < dt * 20:
			part(e.x + rand(-100, 100), M.floorY - rand(0, 30), rand(-20, 20), -rand(20, 60), 1.0, "rgba(220,200,255,0.8)", 0, 1)
		return
	# ---- the rise
	if e.state == "intro":
		D.rise = minf(1, D.rise + dt * D.riseSpeed)
		D.sink = 170 * (1 - easeOut(D.rise))
		shake = maxf(shake, 2.5 * (1 - D.rise))
		if randf() < dt * 30:
			part(e.x + rand(-140, 140), M.floorY - rand(0, 10), rand(-10, 10), -rand(30, 80), rand(0.8, 1.6), "rgba(220,200,255,0.8)", 0, 1 if randf() < 0.7 else 2)
		if D.rise >= 1:
			e.state = "fight"
			D.sink = 0.0
			P.frozen = false
			D.cd = 1.5
			if not Dreamer.introDone:
				Dreamer.introDone = true
				banner("The Dreamer", "Strike its eyes and tentacles · dodge through its gaze")
				Sfx.thunder()
		_updateTents(e, dt)
		return
	if not e.enraged and e.hp < e.maxHp * 0.5:
		e.enraged = true
		banner("THE DREAMER STIRS", "It's waking up")
		Sfx.tone(50, 1.5, "sawtooth", 0.12, 35)
		shake = 8
	var sp = 1.3 if e.enraged else 1.0
	# ---- pick the next attack
	if D.act == "" and P.state != "dead":
		D.cd -= dt * sp
		if D.cd <= 0:
			var opts = ["whips", "whips"]
			if gameTime - D.lastGaze > 9:
				opts.append("gaze")
			if gameTime - D.lastSuck > 12:
				opts.append("suck")
			if gameTime - D.lastGrab > 6:
				opts.append("grab")
			if gameTime - D.lastLaser > 15:
				opts.append("laser")
			if D.get("prev", "") in opts and opts.size() > 2:
				opts.erase(D.prev)
			_startAct(e, opts[rint(0, opts.size() - 1)])
	match D.act:
		"whips":
			D.at -= dt * sp
			if D.at <= 0 and D.queue.size():
				D.at = 0.42
				var T = D.queue.pop_front()
				T.state = "rise"
				T.t = 0.0
				T.tx = clampf(P.x + P.vx * 0.15, 30, M.w - 30)
				T.ty = P.y if (P.grounded or not inWater()) else minf(groundAt(P.x), P.y + 10)
				Sfx.tone(200, 0.35, "sine", 0.05, 120)
			if D.queue.is_empty() and D.tents.all(func(T): return T.state in ["peek", "sink"]):
				D.act = ""
				D.cd = 1.4
		"laser":
			# laser vision: the eyes burn white, then a beam sweeps the floor and boils the sea off it
			var chg: float = 0.7 if e.enraged else 0.85
			var swp: float = 0.85 if e.enraged else 1.1
			D.t += dt
			if D.t < chg:
				D.gaze = clampf(D.t / chg, 0, 1)
				D.laser = 0.0
				if randf() < dt * 30:
					var s2 = -1 if randf() < 0.5 else 1
					part(e.x + s2 * DR_EYE_DX + rand(-6, 6), M.floorY - DR_EYE_Y - 11, rand(-20, 20), rand(-30, 10), 0.4, "#ffffff", 0, 1)
			elif D.t < chg + swp:
				D.gaze = 0.7
				D.laser = 1.0
				var u = (D.t - chg) / swp
				var x0: float = 30.0 if D.laserDir > 0 else M.w - 30.0
				var x1: float = M.w - 30.0 if D.laserDir > 0 else 30.0
				var prevX: float = D.laserX
				D.laserX = lerpf(x0, x1, u)
				var fy: float = groundAt(D.laserX)
				# the water boils off wherever the beam lands: steam climbing in fat bubbles
				for i in 7:
					var bx = lerpf(prevX, D.laserX, randf())
					part(bx + rand(-7, 7), fy - rand(0, 10), rand(-18, 18), -rand(70, 190), rand(1.2, 2.2), "rgba(255,255,255,0.9)" if i % 2 else "rgba(236,222,255,0.8)", -40, 3 if randf() < 0.4 else 2)
				if randf() < dt * 40:
					part(D.laserX + rand(-10, 10), fy - rand(10, 60), rand(-20, 20), -rand(20, 60), rand(0.5, 1.0), "#ffd0f4", -20, 1)
				if int(D.t * 30) % 3 == 0:
					Sfx.tone(rand(1400, 1900), 0.12, "sawtooth", 0.03, 700)
				if not save.settings.god and P.state != "dead" and absf(P.x - D.laserX) < 15 and P.y > fy - 44 and P.y <= fy + 30:
					if P.state == "dash":
						if not D.laserHit:
							D.laserHit = true
							floatText(P.x, P.y - 62, "Slipped the beam!", "call")
							perfectDodge()
					elif mobHit(e, 1.0, 20.0):
						D.laserHit = true
						shake = maxf(shake, 5)
						Sfx.burst(0.3, "highpass", 900, 2600, 0.3)
			else:
				D.laser = 0.0
				D.gaze = 0.0
				D.act = ""
				D.cd = 1.6
		"gaze":
			D.t += dt
			D.gaze = clampf(D.t / 1.1, 0, 1)
			if D.t > 0.8 and P.state == "dash":
				D.dodged = true
			if D.t > 1.1 and not D.get("fired", false):
				D.fired = true
				gazeFlash = 1.0
				Sfx.tone(900, 0.4, "sine", 0.08, 300)
				Sfx.tone(120, 0.6, "sawtooth", 0.06, 60)
				if D.dodged or P.state == "dash":
					floatText(P.x, P.y - 62, "Dodged the gaze!", "call")
					perfectDodge()
				elif P.state != "dead" and not save.settings.god:
					confusePlayer(10.0)
			if D.t > 1.6:
				D.gaze = 0.0
				D.act = ""
				D.cd = 1.2
		"suck":
			D.t += dt
			var my = M.floorY - DR_MOUTH_Y
			if D.t < 0.4:
				D.mouth = D.t / 0.4
			elif D.t < 2.8 and P.held == null:
				D.mouth = 1.0
				var k = (D.t - 0.4) / 2.4
				var pull = (60 + 110 * k) * (1.0 if P.state != "dead" else 0.0)
				if P.state != "dash" and P.state != "dead":
					P.x += sgn(e.x - P.x) * minf(absf(e.x - P.x), pull * dt)
					if not P.grounded:
						P.y += clampf((my + 20) - P.y, -1, 1) * pull * 0.5 * dt
				if randf() < dt * 40:
					var a = randf() * TAU
					var r = rand(60, 160)
					part(e.x + cos(a) * r, my + sin(a) * r * 0.5, -cos(a) * r * 1.6, -sin(a) * r * 0.8, 0.6, "rgba(220,200,255,0.8)", 0, 1)
				if absf(P.x - e.x) < 22 and absf((P.y - 20) - my) < 40 and P.state != "dead" and not save.settings.god:
					P.held = {"kind": "eaten", "e": e, "t": 0.0, "n": 0}
					P.state = "held"
					D.mouth = 0.0
					floatText(e.x, my - 40, "GULP", "call")
					Sfx.tone(60, 0.5, "sawtooth", 0.12, 30)
					Sfx.burst(0.4, "lowpass", 600, 100, 0.4)
			elif P.held == null or P.held.kind != "eaten":
				D.mouth = maxf(0, D.mouth - dt * 3)
				if D.mouth <= 0:
					D.act = ""
					D.cd = 1.4
			else:
				D.mouth = 0.0 if D.chew <= 0 else 0.35
		"grab":
			var T = D.grabT
			D.t += dt
			if T.state == "grab":
				if D.t < 0.65:
					T.tx = damp(T.tx, P.x, 3, dt)
					T.h = 30 + 40 * easeOut(D.t / 0.65)
				elif not D.get("snapped", false):
					D.snapped = true
					Sfx.whoosh(0.8, true)
					if absf(P.x - T.tx) < 30 and absf(P.y - T.ty) < 50 and P.held == null and not (P.state in ["dash", "dead", "tumble"]) and P.iframes <= 0 and not save.settings.god:
						P.held = {"kind": "tent", "e": e, "phase": "lift", "t": 0.0, "y0": P.y if P.grounded else minf(groundAt(P.x), P.y + 30), "hx": P.x}
						P.state = "held"
						floatText(P.x, P.y - 62, "Grabbed!", "call")
				if D.t > 0.9 and (P.held == null or P.held.kind != "tent"):
					T.state = "sink"
					T.t = 0.0
					D.act = ""
					D.cd = 1.2
				elif P.held != null and P.held.kind == "tent":
					T.tx = P.x
					T.ty = P.y + T.h - 10
	_updateTents(e, dt)


func _startAct(e, a: String) -> void:
	var D: Dictionary = e.data
	D.act = a
	D.prev = a
	D.t = 0.0
	D.fired = false
	D.dodged = false
	D.snapped = false
	match a:
		"whips":
			var n = rint(3, 5) + (2 if e.enraged else 0)
			var free = D.tents.filter(func(T): return T.state == "peek")
			free.sort_custom(func(a1, b1): return absf(a1.bx - P.x) < absf(b1.bx - P.x))
			D.queue = []
			for i in mini(n, free.size()):
				D.queue.append(free[i])
			D.at = 0.2
		"laser":
			D.lastLaser = gameTime
			D.laserHit = false
			D.laserDir = 1 if P.x > e.x else -1   # starts on the far side and sweeps towards you
			D.laserX = 30.0 if D.laserDir > 0 else M.w - 30.0
			D.laser = 0.0
			floatText(e.x, M.floorY - DR_EYE_Y - 30, "Its eyes burn white...", "call")
			Sfx.tone(300, 0.9, "sawtooth", 0.05, 2200)
			Sfx.burst(1.0, "highpass", 600, 2000, 0.18)
		"gaze":
			D.lastGaze = gameTime
			floatText(e.x, M.floorY - DR_EYE_Y - 30, "The Dreamer stares...", "call")
			Sfx.tone(220, 1.1, "sine", 0.06, 880)
		"suck":
			D.lastSuck = gameTime
			floatText(e.x, M.floorY - DR_MOUTH_Y - 40, "It inhales...", "call")
			Sfx.burst(2.6, "lowpass", 400, 1400, 0.25)
		"grab":
			D.lastGrab = gameTime
			var free = D.tents.filter(func(T): return T.state == "peek")
			if free.is_empty():
				D.act = ""
				D.cd = 0.5
				return
			free.sort_custom(func(a1, b1): return absf(a1.bx - P.x) < absf(b1.bx - P.x))
			var T = free[0]
			T.state = "grab"
			T.t = 0.0
			T.tx = P.x
			T.ty = P.y if P.grounded else minf(groundAt(P.x), P.y + 30)
			T.h = 30.0
			D.grabT = T
			Sfx.tone(160, 0.6, "sine", 0.05, 90)


func _updateTents(e, dt: float) -> void:
	var D: Dictionary = e.data
	for T in D.tents:
		T.t += dt
		var p = T.part
		match T.state:
			"peek":
				T.h = damp(T.h, 34 + sin(T.t * 0.6 + T.bx) * 22, 1.5, dt)
			"rise":
				T.h = damp(T.h, 150, 6, dt)
				if T.t > 0.45:
					T.state = "whip"
					T.t = 0.0
			"whip":
				if T.t > 0.1 and not T.get("hit", false):
					T.hit = true
					var hb = hbox(T.tx - 16, T.tx + 16, T.ty - 40, T.ty + 4)
					if overlap(hb, pBox()):
						mobHit(e, 1.1, 20)
					shake = maxf(shake, 4)
					Sfx.slam()
					dust(T.tx, T.ty, 10)
				if T.t > 0.12:
					T.state = "lie"
					T.t = 0.0
			"lie":
				if T.t > 0.9:
					T.state = "sink"
					T.t = 0.0
					T.hit = false
			"sink":
				T.h = maxf(0, T.h - dt * 160)
				if T.t > 0.5 and e.state != "dead":
					T.state = "peek"
					T.h = 10.0
		var tip = _tentTip(e, T)
		p.x = tip.x
		p.y = tip.y + 10
		var hittable = false
		if T.state == "peek":
			hittable = _drOff(e) < 30 and T.h > 12
		elif T.state == "lie" or T.state == "grab":
			hittable = true
		p.state = "idle" if hittable and e.state != "dead" and e.state != "intro" else "dead"
		if T.state == "lie":
			p.w = 40; p.h = 14
		else:
			p.w = 20; p.h = 22


func dreamerFalls(e, firstKill: bool) -> void:
	e.dying = true
	var D: Dictionary = e.data
	D.act = ""
	D.gaze = 0.0
	if P.held != null:
		if P.held.kind == "eaten":
			_spitOut(e)
		else:
			P.held = null
			P.state = "move"
	# a gurgled cry, muffled by the water
	Sfx.burst(1.6, "lowpass", 300, 120, 0.4)
	Sfx.tone(55, 1.8, "sawtooth", 0.12, 38)
	Sfx.tone(82, 1.4, "triangle", 0.08, 50, 0.3)
	for i in 40:
		part(e.x + rand(-40, 40), M.floorY - DR_MOUTH_Y + rand(-10, 10), rand(-60, 60), rand(-120, -20), rand(0.8, 1.6), "rgba(220,200,255,0.85)", -20, 1 if i % 3 else 2)
	if firstKill:
		later(1.6, func():
			startScene([{"who": "The Dreamer", "text": "Hhhrrgll... grlbbhh..."}, {"who": "The Dreamer", "text": "Just... Another nightmare..."}], func():
				e.dying = false
				_dropKey(e)
				later(2.4, func(): openBubbleGate(true))))
	else:
		later(1.4, func():
			e.dying = false
			if not save.get("keyItems", {}).get("dreamKey"):
				_dropKey(e)
			banner("THE DREAMER SINKS", "Grab the Dreambox · the pedestal can call it back")
			Sfx.rankUp(9))


func _dropKey(e) -> void:
	if drops.any(func(d): return d.kind == "key"):
		return
	var d = S.Drop.new()
	d.kind = "key"
	d.x = e.x; d.y = M.floorY - DR_MOUTH_Y; d.vx = 0; d.vy = -120
	d.surfY = M.floorY; d.x0 = 40; d.x1 = M.w - 40
	drops.append(d)
	Sfx.tone(1200, 0.5, "sine", 0.06, 1800)


func pickupKey() -> void:
	if not (save.get("keyItems") is Dictionary):
		save.keyItems = {}
	save.keyItems.dreamKey = true
	saveDirty = true
	persist()
	cheer()
	keyItemGet("dreamKey", "Dream Key", "It hums with the crystal's light. It can break the crystal Glamrax keeps people in.")
	toast("🔑 You got the Dream Key! It's in your inventory, under Key items.")
	Sfx.rankUp(9)
	Sfx.buy()
	for k in 40:
		part(P.x, P.y - 30, rand(-120, 120), rand(-200, -40), rand(0.6, 1.1), ["#c25cff", "#ff6af0", "#ffffff"][k % 3], 200, 2)


## the way on: a portal into the bubble, on the far side of the Dreamer's Hollow
func openBubbleGate(fanfare := false) -> void:
	var H: Dictionary = MAPS.abyss5
	if not H.portals.any(func(p): return p.to == "bubble"):
		H.portals.append({"x": H.w - 40, "to": "bubble", "tx": 80, "label": "A shimmering bubble"})
	if not fanfare or mapId != "abyss5":
		return
	shake = 6
	Sfx.rankUp(9)
	for i in 50:
		part(H.w - 40 + rand(-10, 10), M.floorY - rand(0, 50), rand(-60, 60), rand(-90, 10), 1.0, ["#ff7ac8", "#ffd27a", "#7affc8", "#7ad8ff", "#b88aff"][i % 5], 0, 2)
	banner("A bubble of light opens", "Something shimmers on the far side of the hollow")


## every time a map loads
func abyssOnLoad() -> void:
	abyssShots.clear()
	pDevour = null
	P.held = null
	P.spin = 0.0
	if mapId == "bubble":   # the bubble's light washes the Abyss out of you
		P.abyssT = 0.0; P.abyssB = 0.0; P.blindT = 0.0; P.confuseT = 0.0
	if mapId == "abyss5" and save.trophies.get("dreamer"):
		openBubbleGate(false)
	if mapId == "abyss5" and save.trophies.get("dreamer") and not save.get("keyItems", {}).get("dreamKey"):
		var d = S.Drop.new()   # the key is still lying where it fell
		d.kind = "key"; d.x = M.w / 2.0; d.y = M.floorY - 10; d.surfY = M.floorY; d.x0 = 40; d.x1 = M.w - 40
		later(0.1, func(): drops.append(d))


# ================================================================ Abyssal Devour (the Dreambox's skill)

func castDevour() -> void:
	var tg = pickTargets(240, 1, true, 90.0)
	if tg.is_empty():
		floatText(P.x, P.y - 58, "Nothing to devour...", "call")
		return
	var e = tg[0]
	var big: bool = e.boss or e.bossPart or e.elite or e.T.get("bw", 0) >= 60
	pDevour = {"e": e, "t": 0.0, "n": 0, "big": big, "face": P.face}
	floatText(P.x, P.y - 58, "Devour!", "call")
	Sfx.burst(0.6, "lowpass", 300, 1200, 0.3)
	Sfx.tone(80, 0.5, "sawtooth", 0.08, 50)


func updateDevour(dt: float) -> void:
	if pDevour == null:
		return
	var Dv: Dictionary = pDevour
	var e = Dv.e
	Dv.t += dt
	var mx: float = P.x + Dv.face * 30
	var my: float = P.y - 18
	if e.state == "dead" or not slimes.has(e):
		if Dv.t > 0.3:
			pDevour = null
			Sfx.tone(140, 0.3, "sine", 0.06, 90)   # a satisfied gulp
		return
	if not Dv.big:
		var k = minf(1, Dv.t / 0.45)
		e.x = lerpf(e.x, mx, k * 0.5)
		e.y = lerpf(e.y, my + e.h / 2, k * 0.5)
		e.vx = 0; e.vy = 0
		e.state = "hurt"; e.stun = 0.5
	var chews = [0.6, 1.05, 1.5]
	if Dv.n < 3 and Dv.t >= chews[Dv.n]:
		Dv.n += 1
		shake = maxf(shake, 5)
		Sfx.tone(70, 0.15, "square", 0.1, 40)
		Sfx.burst(0.12, "lowpass", 900, 200, 0.3)
		damageSlime(e, {"dmg": 4.0, "kb": 0, "up": 0, "style": 25, "anim": "devour%d" % Dv.n, "both": true, "heavy": true})
		for k in 8:
			part(mx + rand(-10, 10), my + rand(-8, 8), rand(-60, 60), rand(-60, 20), 0.4, "#ff6a8a" if k % 2 else "#2a0a20", 0, 2)
	if Dv.t >= 1.8:
		if e.state != "dead" and not Dv.big:
			e.state = "hurt"; e.stun = 0.8
			e.vx = Dv.face * 320; e.vy = -220
		Sfx.burst(0.25, "lowpass", 1200, 300, 0.3)
		pDevour = null


# ================================================================ sounds

## footsteps: muffled under the water; in the bubble they echo
func abyssStep(heavy: bool) -> void:
	if M.get("echo"):
		var p = rand(0.95, 1.08)
		Sfx.play("step_wood", 0.9, p)
		later(0.26, func(): Sfx.play("step_wood", 0.4, p * 0.98))
		later(0.55, func(): Sfx.play("step_wood", 0.18, p * 0.96))
		later(0.9, func(): Sfx.play("step_wood", 0.07, p * 0.94))
		return
	if inWater():
		Sfx.play("step_wet", 0.45 if heavy else 0.3, rand(0.55, 0.7))
	else:
		Sfx.step(heavy, "wet")


# forward declarations for the drawing (abyss_draw.gd, further down the chain)
func drawAbyssBack(_x: Ctx, _sx: float, _sy: float, _dt: float) -> void: pass
func drawAbyssFront(_x: Ctx, _sx: float, _sy: float, _dt: float) -> void: pass
func drawAbyssMob(_x: Ctx, _e, _sx: float, _sy: float) -> void: pass
func drawTerrain(_x: Ctx, _mt: Texture2D, _sx: float, _sy: float) -> void: pass
func drawKeyDrop(_x: Ctx, _X: float, _Y: float, _tt: float) -> void: pass
func abyssTint(_x: Ctx) -> void: pass
func abyssOverlay(_x: Ctx) -> void: pass
