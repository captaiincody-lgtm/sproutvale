extends "res://scripts/mecha.gd"
## Sproutvale, part 6⅞ (the end of it): Glamrax. His sanctum at the heart of the volcano, the five
## crystals that hold the heroes' loved ones, the piano, the meeting (each hero answers him in their
## own way), and the fight: a wizard who never comes close and fills the room with spells, an energy
## ball that only Rock's sword can send back, an abyssal demon at 75%, a mana shield at 50%, his robes
## off at 25% and horns at 10%, and the ending at 1% that isn't one.
##
## He's drawn in code (below), like the Mk II. The loved ones are placeholder pictures in
## art/volcano/kin/<hero>.png: swap in your own at the same size.

const GLAMRAX_T := {"name": "Glamrax", "lv": 110, "hp": 600000, "atk": 430, "def": 110, "exp": 400000, "coins": [9000, 14000],
	"color": 0x3a1450, "critter": false, "matName": "Wizard's Thread"}
const DEMON_T := {"name": "Abyssal Demon", "lv": 108, "hp": 90000, "atk": 400, "def": 90, "exp": 60000, "coins": [900, 1500],
	"color": 0x5a0a1a, "critter": false, "matName": "Demon Horn", "speed": 1.0, "kb": 0.15}
## whose loved one hangs in which crystal (left to right), and what they are to them
const GX_PODS := ["rock", "archer", "mage", "summoner", "tank"]
const GX_KIN := {"rock": "son", "archer": "little sister", "mage": "grandmother", "summoner": "little brother", "tank": "mother"}
## each hero's answer, when they see who's in the crystal
const GX_REPLY := {
	"rock": ["Let my son go, Glamrax.", "I came here for him, not for you. But if you stand between us, I'll go through you. That's a promise."],
	"archer": ["I never wanted to hurt anybody. Not the slimes, not the knights, not even you.", "But that's my little sister. Let her go... please. Don't make me do this."],
	"mage": ["You left me in the rain and didn't even look back. You should have made sure.", "And now my grandmother? Oh, Glamrax... I'm going to enjoy this. I'm going to take my time."],
	"summoner": ["Wow. A piano. Real classy, you creep.", "You stuck me in a jar and you grabbed my little brother. Get down here so I can knock that stupid hat off your head."],
	"tank": ["That's my mother.", "You dropped a rock on my house. Now I'm going to take you apart, one bone at a time, and I'm going to listen to every single one of them snap."],
}
const GX_SPELLS := {"orb": 3, "chain": 2, "fire": 2, "meteor": 2, "wave": 2, "tornado": 1, "firenado": 1, "ice": 2, "pillars": 2, "sky": 2}
const GX_COL := {"orb": "#ff4ad8", "chain": "#9ad8ff", "fire": "#ff7a2a", "meteor": "#ff5a1a", "wave": "#4ab0ff", "tornado": "#d8e8f0",
	"firenado": "#ff8a2a", "ice": "#bff4ff", "pillars": "#c8a070", "sky": "#e8b8ff", "summon": "#ff2a4a", "shield": "#7af0ff"}
const GX_ELEMS := ["fire", "lightning", "ice", "earth", "water"]
const GX_ELEM_COL := {"fire": "#ff7a2a", "lightning": "#bfe8ff", "ice": "#bff4ff", "earth": "#c8a070", "water": "#4ab0ff"}

var GX := {}             # the sanctum's cutscene beats and camera
var gSpells: Array = []  # his spells while they play out
var camZoom := 1.0       # the cutscenes zoom in on a crystal or a face (render.gd scales the world by this)
var camZoomAt := Vector2(192, 108)


# ================================================================ data

func initVolcanoData() -> void:
	super.initVolcanoData()
	MORE_BOSSES.glamrax = {"T": GLAMRAX_T, "name": "Glamrax", "short": "Glamrax", "col": "#ff4ad8", "ui": "#7a2a9a", "music": "glamrax",
		"coins": 0, "mul": 0, "map": "volcano4", "noPedestal": true,
		"info": {"title": "⚠ Boss: Glamrax", "stats": [["Level", "110"], ["HP", "600,000"], ["Attack", "430"], ["Defense", "110"]],
			"paras": ["**Spells:** he floats out of reach and fills the room: chain lightning that jumps from platform to platform, fireballs, meteors, a tidal wave (get up on a platform), tornadoes and fire tornadoes, an ice wave along the floor (jump it), earth pillars, and beams of abyssal light from above · **Energy ball:** Rock can knock it back with his sword; keep the rally going and it will knock Glamrax out of the air · **75%:** he calls up an abyssal demon · **50%:** a mana shield (he takes 25% less damage and hits harder) · **25%:** the robes come off · **10%:** he stops casting and his fists carry the magic instead.",
				"**Reward:** your loved one, out of that crystal."],
			"rec": "Recommended: Lv 110+, every upgrade you can afford. Walk right into the portal to enter."}}
	BOSS_LIST[5] = {"id": "glamrax", "name": "Glamrax", "where": "Glamrax's Sanctum"}
	BEST_ORDER.append("glamrax")
	BEST_TEXT.glamrax = "The wizard behind all of it. He sealed your loved ones in crystal and wired them to his machine, then waited at his piano for you to come and get them. He never fights fair and he never fights close."
	MAPS.volcano3.bossSign = 2280
	MAPS.volcano3.signBoss = "glamrax"
	var T: Dictionary = DEMON_T.duplicate()
	T.merge({"aggro": 99, "size": 1, "w": 0, "unlock": T.lv, "ai": "climb", "habitat": "climb", "residue": T.matName}, false)
	SLIME_TYPES.gdemon = T


# ================================================================ the sanctum: crystals, cables, the piano

func _podXY(i: int) -> Vector2:
	var S: Dictionary = vSpots("volcano4")
	var pods: Array = S.get("pod", [])
	if i < pods.size():
		return Vector2(pods[i][0], pods[i][1])
	return Vector2(150 + i * 105, 100 + (i % 2) * 26)


# ================================================================ spawning and the meeting

func spawnBossKind(kind: String, fromPedestal := false) -> bool:
	if kind != "glamrax":
		return super.spawnBossKind(kind, fromPedestal)
	spawnGlamrax()
	return true


func _glamrax():
	for e in slimes:
		if e.bossKind == "glamrax":
			return e
	return null


func spawnGlamrax() -> void:
	gSpells.clear()
	var px: float = 520.0
	var e = _newMob("glamrax", GLAMRAX_T, px, M.floorY - 8, floorSurfAt(px))
	e.boss = true; e.bossKind = "glamrax"; e.aggro = true
	e.face = 1
	e.w = 26; e.h = 70; e.showBar = 99
	e.state = "intro"
	e.data = {"phase": "piano", "form": "robe", "horns": 0.0, "shield": false, "demon": false, "hover": 84.0, "cd": 1.4, "spell": "", "castT": 0.0,
		"anim": "sit", "robe": 0.0, "stunT": 0.0, "combo": 0, "elem": "", "tx": 400.0, "moveT": 0.0, "flash": 0.0, "last": "", "act": "",
		"elemI": 0, "lift": 0.0, "hurtT": 0.0}
	slimes.append(e)
	var full: bool = not CH().get("glamraxMet", false)
	GX = {"t": 0.0, "beat": "pan" if full else "short", "full": full, "camX": 0.0 if full else 330.0, "camY": M.h - VH, "zoom": 1.0, "zoomAt": Vector2(VW / 2.0, VH / 2.0), "frown": 0.0}
	P.frozen = true
	P.face = 1
	Sfx.music_stop(true)
	later(0.3, func(): if mapId == "volcano4": Sfx.music("piano"))


func _gxLines(lines: Array, who: String) -> Array:
	return lines.map(func(l): return {"who": who, "text": l})


func _updateMeeting(e, dt: float) -> void:
	var D: Dictionary = e.data
	GX.t += dt
	var t: float = GX.t
	var pod = _podXY(GX_PODS.find(classId))
	match GX.beat:
		"pan", "short":
			# the camera drifts along the sanctum, past the crystals, to the piano
			var to = clampf(e.x - VW * 0.55, 0, M.w - VW)
			var dur = 8.0 if GX.beat == "pan" else 2.0
			GX.camX = lerpf(0.0 if GX.beat == "pan" else 330.0, to, smoothstep(0.0, 1.0, minf(1, t / dur)))
			D.anim = "sit"
			if t > dur + 0.6:
				GX.beat = "stop"
				GX.t = 0.0
				# he stops, mid-phrase
				Sfx.music_stop(true)
				D.anim = "slam"
				Sfx.tone(55, 1.6, "sawtooth", 0.1, 52)
				Sfx.tone(58, 1.6, "triangle", 0.1, 55)
				Sfx.tone(82, 1.4, "sawtooth", 0.06, 80)
				Sfx.tone(87, 1.4, "triangle", 0.06, 85)
				shake = 3
		"stop":
			if t > 0.9 and D.anim != "stand":
				D.anim = "stand"
				e.face = -1
			if t > 1.6:
				GX.beat = "talk"
				var lines = ["According to plan.", "The real prize arrives.", "I hope you've prepared well."] if GX.full else ["Back again? Good.", "I hope you've prepared better this time."]
				startScene(_gxLines(lines, "Glamrax"), func():
					GX.beat = "rise"
					GX.t = 0.0)
		"rise":
			# he floats up into the air, as if it were nothing
			D.anim = "float"
			e.y = lerpf(M.floorY - 8, M.floorY - D.hover, smoothstep(0.0, 1.0, minf(1, t / 2.0)))
			GX.camX = lerpf(GX.camX, clampf(e.x - VW * 0.62, 0, M.w - VW), minf(1, dt * 1.5))
			if t > 2.3:
				GX.beat = "kin" if GX.full else "go"
				GX.t = 0.0
		"kin":
			# the hero sees who's in the crystal
			var k = smoothstep(0.0, 1.0, minf(1, t / 1.4))
			GX.camX = lerpf(GX.camX, clampf(pod.x - VW / 2, 0, M.w - VW), minf(1, dt * 3))
			GX.camY = lerpf(GX.camY, clampf(pod.y - VH / 2, 0, M.h - VH), minf(1, dt * 3))
			GX.zoom = lerpf(1.0, 2.6, k)
			GX.zoomAt = Vector2(pod.x - GX.camX, pod.y - GX.camY)
			if t > 3.0:
				GX.beat = "hero"
				GX.t = 0.0
		"hero":
			# … and frowns
			var hx = P.x
			var hy = P.y - 30
			GX.camX = lerpf(GX.camX, clampf(hx - VW / 2, 0, M.w - VW), minf(1, dt * 5))
			GX.camY = lerpf(GX.camY, clampf(hy - VH / 2, 0, M.h - VH), minf(1, dt * 5))
			GX.zoom = lerpf(GX.zoom, 2.2, minf(1, dt * 5))
			GX.zoomAt = Vector2(hx - GX.camX, hy - GX.camY)
			GX.frown = minf(1, t / 0.5)
			if t > 1.1 and not GX.get("said", false):
				GX.said = true
				startScene(_gxLines(GX_REPLY.get(classId, ["Let them go."]), CLASSES[classId].name), func():
					GX.beat = "go"
					GX.t = 0.0)
		"go":
			GX.zoom = lerpf(GX.zoom, 1.0, minf(1, dt * 6))
			GX.camX = lerpf(GX.camX, clampf((P.x + e.x) / 2 - VW / 2, 0, M.w - VW), minf(1, dt * 4))
			GX.camY = lerpf(GX.camY, M.h - VH, minf(1, dt * 4))
			GX.frown = maxf(0, GX.frown - dt * 2)
			if t > 0.6:
				GX.beat = ""
				GX.zoom = 1.0
				P.frozen = false
				e.state = "fight"
				e.t = 0.0
				D.anim = "float"
				D.cd = 1.0
				CH().glamraxMet = true
				saveDirty = true
				Sfx.music("glamrax")
				banner("GLAMRAX", "He never comes close · his spells cover the room")
				Sfx.thunder()
	camZoom = GX.zoom
	camZoomAt = GX.zoomAt


## the sanctum's meeting is playing: the HUD steps aside for black bars
func cinematic() -> bool:
	return mapId == "volcano4" and not GX.is_empty() and GX.get("beat", "") != ""


func updateCamera(dt: float) -> void:
	if cinematic():
		cam.x = GX.camX
		cam.y = GX.camY
		camZoom = GX.zoom
		camZoomAt = GX.zoomAt
		return
	camZoom = 1.0
	super.updateCamera(dt)


func loadMap(id: String, px0 = null, py0 = null) -> void:
	gSpells.clear()
	GX = {}
	camZoom = 1.0
	super.loadMap(id, px0, py0)


# ================================================================ the fight

func updateBossKind(e, dt: float) -> bool:
	if e.bossKind != "glamrax":
		return super.updateBossKind(e, dt)
	updateGlamrax(e, dt)
	return true


func updateGlamrax(e, dt: float) -> void:
	var D: Dictionary = e.data
	e.hurtFlash -= dt
	e.showBar = 99
	D.flash = maxf(0, D.flash - dt)
	if e.state == "dead":
		return
	if e.state == "intro":
		_updateMeeting(e, dt)
		return
	if e.state == "fallen":
		_updateFakeEnd(e, dt)
		return
	var hpK: float = e.hp / e.maxHp
	if hpK <= 0.01:
		_startFakeEnd(e)
		return
	var g = groundAt(e.x)
	# the phases: each one waits until he isn't in the middle of something
	var free: bool = D.spell == "" and D.act == "" and D.stunT <= 0
	if free:
		if not D.demon and hpK <= 0.75:
			D.demon = true
			_gxBegin(e, "summon")
		elif not D.shield and hpK <= 0.5:
			D.shield = true
			_gxBegin(e, "shield")
		elif D.form == "robe" and hpK <= 0.25:
			D.act = "shed"
			e.t = 0.0
			gSpells = gSpells.filter(func(s): return s.kind in ["flames"])
			_gxClearOrbs()
		elif D.form == "muscle" and D.horns <= 0 and hpK <= 0.1 and D.act == "":
			D.act = "horns"
			e.t = 0.0
	# stunned: knocked out of the air by his own energy ball
	if D.stunT > 0:
		D.stunT -= dt
		D.spell = ""
		e.vy = minf(e.vy + 900 * dt, 600)
		e.y = minf(g, e.y + e.vy * dt)
		D.anim = "dazed"
		if D.stunT <= 0:
			D.anim = "float"
			e.vy = 0
		return
	if D.act == "shed":
		_gxShed(e, dt)
		return
	if D.act == "horns":
		_gxHorns(e, dt)
		return
	if D.form == "robe":
		_gxFloat(e, dt)
	else:
		_gxBrawl(e, dt)
	# casting
	if D.spell != "":
		D.castT += dt
		var tell = 0.55 if not D.shield else 0.42
		if D.spell in ["summon", "shield"]:
			tell = 1.1
		if D.form == "muscle":
			tell = 0.4
		if D.castT >= tell:
			var s: String = D.spell
			D.spell = ""
			_gxCast(e, s)
			var demonUp = slimes.any(func(q): return q.type == "gdemon" and q.state != "dead")
			D.cd = rand(1.0, 1.5) * (0.78 if D.shield else 1.0) * (1.7 if demonUp else 1.0) * (3.2 if D.form == "muscle" else 1.0)
	elif D.horns <= 0 and D.cd > 0:
		D.cd -= dt
	elif D.horns <= 0 and D.act == "" and P.state != "dead" and (D.form == "robe" or absf(P.x - e.x) > 60):
		_gxBegin(e, _gxPick(e))


func _gxBegin(e, s: String) -> void:
	var D: Dictionary = e.data
	D.spell = s
	D.castT = 0.0
	D.last = s
	Sfx.tone(300 if s != "summon" else 90, 0.5, "sine", 0.05, 900 if s != "summon" else 50)


func _gxPick(e) -> String:
	var bag: Array = []
	for k in GX_SPELLS:
		if k == e.data.last:
			continue
		var w: int = GX_SPELLS[k]
		if k == "orb" and (classId != "rock" or e.data.form != "robe"):
			w = 1 if e.data.form == "robe" else 0
		if k == "orb" and classId == "rock":
			w = 4
		for i in w:
			bag.append(k)
	return bag[rint(0, bag.size() - 1)]


## floating, staying out of reach
func _gxFloat(e, dt: float) -> void:
	var D: Dictionary = e.data
	D.moveT -= dt
	if D.moveT <= 0:
		D.moveT = rand(2.2, 3.6)
		D.hover = rand(50, 96)
		var away = clampf(P.x + (-1 if randf() < 0.5 else 1) * rand(150, 260), 60, M.w - 170)
		D.tx = away
	if absf(P.x - D.tx) < 120:   # never close: if you get near, he moves off
		D.tx = clampf(P.x + (180.0 if P.x < M.w / 2 else -180.0), 60, M.w - 170)
	var g = groundAt(e.x)
	e.x = move_toward(e.x, D.tx, 120 * dt)
	var ty = minf(g - 30, M.floorY - D.hover) + sin(e.t * 1.7) * 4
	e.y = lerpf(e.y, ty, minf(1, dt * 2))
	if absf(P.x - e.x) > 6:
		e.face = int(sgn(P.x - e.x))
	D.anim = "cast" if D.spell != "" else "float"


# ---------------- the spells

func _staff(e) -> Vector2:
	return Vector2(e.x + e.face * 15, e.y - 66)


## his spells and fists, tuned so a geared hero near his level survives two or three mistakes, not four
func _gxSrc(e, x: float, extra := {}) -> Dictionary:
	var s = _src(e, x, extra)
	s.atk = e.atk * 0.72
	return s


func _surfUnder(x: float, y: float):
	var best = null
	for s in surfaces:
		if x >= s.x0 - 2 and x <= s.x1 + 2 and s.y >= y - 3 and (best == null or s.y < best.y):
			best = s
	return best


func _gxCast(e, s: String) -> void:
	var D: Dictionary = e.data
	var st = _staff(e)
	var src = _gxSrc(e, e.x)
	D.flash = 0.25
	var fy: float = M.floorY
	match s:
		"orb":
			_gxOrb(e)
		"chain":
			# lightning lands where you stand, then jumps from platform to platform
			var first = _surfUnder(P.x, P.y)
			var order: Array = []
			var pool: Array = surfaces.duplicate()
			var cur = first if first != null else surfaces[0]
			for i in 5:
				if cur == null:
					break
				order.append(cur)
				pool.erase(cur)
				var cx = (cur.x0 + cur.x1) / 2.0
				var nxt = null
				for q in pool:
					if q.x1 - q.x0 > 300:
						continue   # the floor itself only takes the first strike
					if nxt == null or absf((q.x0 + q.x1) / 2.0 - cx) + absf(q.y - cur.y) < absf((nxt.x0 + nxt.x1) / 2.0 - cx) + absf(nxt.y - cur.y):
						nxt = q
				cur = nxt
			for i in order.size():
				var q = order[i]
				var x0: float = q.x0
				var x1: float = q.x1
				if x1 - x0 > 300:
					x0 = maxf(q.x0, P.x - 70)
					x1 = minf(q.x1, P.x + 70)
				gSpells.append({"kind": "bolt", "x0": x0, "x1": x1, "y": q.y, "t": -i * 0.3, "warn": 0.5, "hit": false, "src": src})
			Sfx.tone(1800, 0.4, "square", 0.04, 300)
		"fire":
			var a0 = atan2((P.y - 22) - st.y, P.x - st.x)
			for i in 5:
				var a = a0 + (i - 2) * 0.22
				gSpells.append({"kind": "fireball", "x": st.x, "y": st.y, "vx": cos(a) * 210, "vy": sin(a) * 210, "t": 0.0, "src": src})
			Sfx.burst(0.5, "lowpass", 1800, 400, 0.3)
		"meteor":
			var xs = [P.x, P.x - rand(50, 90), P.x + rand(50, 90), P.x - rand(130, 200), P.x + rand(130, 200), rand(40, M.w - 40)]
			for i in xs.size():
				var mx = clampf(xs[i], 30, M.w - 30)
				var su = _surfUnder(mx, M.get("ceilY", 30))
				gSpells.append({"kind": "meteor", "x": mx, "gy": su.y if su != null else fy, "t": -i * 0.22, "warn": 1.0, "src": src})
			Sfx.tone(120, 1.2, "sawtooth", 0.06, 60)
		"wave":
			var d = 1 if e.x < P.x else -1
			gSpells.append({"kind": "wave", "dir": d, "x": 0.0 if d > 0 else float(M.w), "t": 0.0, "h": 58.0, "hit": false, "src": src})
			Sfx.burst(2.4, "lowpass", 600, 1400, 0.35)
		"tornado", "firenado":
			var fire = s == "firenado"
			for side in ([-1, 1] if not fire else [1 if P.x < M.w / 2 else -1]):
				gSpells.append({"kind": "tornado", "x": P.x + side * 240.0, "t": 0.0, "life": 4.6, "fire": fire, "tick": 0.0, "src": src, "w": 26.0 if fire else 18.0})
			Sfx.burst(1.6, "bandpass", 400, 1200, 0.3)
		"ice":
			var d = 1 if e.x < P.x else -1
			gSpells.append({"kind": "icewave", "x0": clampf(e.x, 20, M.w - 20), "dir": d, "t": 0.0, "hit": false, "spikes": [], "src": src})
			Sfx.tone(2400, 0.6, "sine", 0.04, 1200)
		"pillars":
			var xs = [P.x, P.x - 66, P.x + 66, P.x - 140, P.x + 140]
			for i in xs.size():
				gSpells.append({"kind": "pillar", "x": clampf(xs[i], 24, M.w - 24), "t": -i * 0.1, "warn": 0.7, "hit": false, "src": src})
			Sfx.burst(0.8, "lowpass", 300, 120, 0.4)
		"sky":
			var xs = [P.x, P.x + rand(-140, -60), P.x + rand(60, 140), rand(30, M.w - 30), rand(30, M.w - 30)]
			for i in xs.size():
				gSpells.append({"kind": "skybeam", "x": clampf(xs[i], 20, M.w - 20), "t": -i * 0.16, "warn": 0.85, "w": 20.0, "hit": false, "src": src})
			Sfx.tone(900, 1.0, "sine", 0.05, 1400)
		"summon":
			var dx = clampf(P.x + (150.0 if P.x < M.w / 2 else -150.0), 60, M.w - 60)
			gSpells.append({"kind": "circle", "x": dx, "t": 0.0})
			floatText(e.x, e.y - 84, "RISE.", "call")
			Sfx.tone(60, 2.0, "sawtooth", 0.1, 40)
		"shield":
			e.atk = roundi(GLAMRAX_T.atk * 1.25)
			floatText(e.x, e.y - 86, "MANA SHIELD", "call")
			Sfx.tone(600, 0.8, "sine", 0.06, 1200)
			Sfx.burst(0.5, "highpass", 2000, 6000, 0.2)
			for k in 24:
				var a = randf() * TAU
				part(e.x + cos(a) * 30, e.y - 36 + sin(a) * 40, cos(a) * 40, sin(a) * 40, 0.6, "#7af0ff" if k % 2 else "#ffffff", 0, 1)


func updateClimb(dt: float) -> void:
	super.updateClimb(dt)
	_updateGSpells(dt)


func _updateGSpells(dt: float) -> void:
	if gSpells.is_empty():
		return
	var pb = pBox()
	var alive = P.state != "dead"
	for i in range(gSpells.size() - 1, -1, -1):
		var s: Dictionary = gSpells[i]
		s.t += dt
		var gone = false
		match s.kind:
			"bolt":
				if s.t >= s.warn and not s.hit:
					s.hit = true
					Sfx.thunder()
					shake = maxf(shake, 4)
					var cx = (s.x0 + s.x1) / 2.0
					var on: bool = P.grounded and absf(P.y - s.y) < 3 and P.x >= s.x0 - 4 and P.x <= s.x1 + 4
					if alive and (on or (absf(P.x - cx) < 10 and P.y <= s.y + 2)):
						if abyssChip(s.src, 1.0, 0.0, true) and P.state != "dead":
							shockStun(0.6)
				gone = s.t > s.warn + 0.35
			"fireball":
				s.vy += 60 * dt
				s.x += s.vx * dt
				s.y += s.vy * dt
				if alive and s.x > pb.x0 - 3 and s.x < pb.x1 + 3 and s.y > pb.y0 - 3 and s.y < pb.y1 + 3:
					var n0 = P.hurtN
					hurtPlayer(s.src, s.src.atk * 0.9)
					if P.hurtN != n0 and randf() < 0.35:
						ignite(s.src)
					gone = true
				var su = _surfUnder(s.x, s.y - 4)
				if (su != null and s.y >= su.y and s.y - s.vy * dt <= su.y + 1) or s.y >= groundAt(s.x) or s.x < 0 or s.x > M.w or s.t > 4:
					gone = true
				if gone:
					for k in 6:
						part(s.x, s.y, rand(-60, 60), rand(-90, -20), 0.35, "#ff8a2a" if k % 2 else "#ffd27a", 200, 1)
			"meteor":
				if s.t >= s.warn and not s.get("hit", false):
					s.hit = true
					_boom(s.x, s.gy - 6, 32, s.src, 1.5)
					gSpells.append({"kind": "flames", "x": s.x, "y": s.gy, "t": 0.0, "tick": 0.0, "src": s.src})
				gone = s.t > s.warn + 0.05
			"flames":
				if alive and P.grounded and absf(P.y - s.y) < 3 and absf(P.x - s.x) < 20 and Burn.t <= 0:
					ignite(s.src)
				if randf() < dt * 20:
					part(s.x + rand(-18, 18), s.y - 2, rand(-10, 10), -rand(30, 70), 0.4, "#ff7a2a" if randf() < 0.6 else "#ffd27a", -30, 1)
				gone = s.t > 1.6
			"wave":
				s.x += s.dir * 270 * dt
				if alive and not s.hit and absf(P.x - s.x) < 18 and P.y > M.floorY - s.h:
					s.hit = true
					if launchHit(s.src, 1.3):
						P.vx = s.dir * 380
				if randf() < dt * 40:
					part(s.x + rand(-6, 6), M.floorY - rand(0, s.h), s.dir * rand(40, 140), -rand(40, 160), 0.5, "#9ad8ff" if randf() < 0.5 else "#ffffff", 400, 1)
				gone = s.x < -40 or s.x > M.w + 40
			"tornado":
				s.x = move_toward(s.x, P.x, (70.0 if not s.fire else 60.0) * dt)
				s.tick -= dt
				var dx = P.x - s.x
				if alive and P.held == null and P.y > M.floorY - 150:
					if absf(dx) < 80:
						P.x -= sgn(dx) * (55.0 if absf(dx) > 8 else 0.0) * dt   # pulled in
					if absf(dx) < s.w * 0.6 and s.tick <= 0:
						s.tick = 0.3
						var n0 = P.hurtN
						abyssChip(s.src, 0.35 if not s.fire else 0.45, 0.0, true)
						if P.state != "dead":
							P.vy = minf(P.vy, -260)
							P.grounded = false
							if s.fire:
								ignite(s.src)
				gone = s.t > s.life
			"icewave":
				var front = s.x0 + s.dir * 330 * s.t
				var last = s.spikes[-1] if s.spikes.size() else s.x0 - s.dir * 18
				if absf(front - last) >= 18 and front > 0 and front < M.w:
					s.spikes.append(last + s.dir * 18)
					Sfx.tone(rand(1800, 2600), 0.08, "triangle", 0.03, 900)
				if alive and not s.hit and absf(P.x - front) < 14 and P.y > M.floorY - 26:
					s.hit = true
					if abyssChip(s.src, 1.2, 0.0, true) and P.state != "dead":
						freezeStun(0.9)
				gone = front < -40 or front > M.w + 40
				if gone and s.t < 4:
					gone = false   # (the spikes linger a moment after the front leaves)
					s.t = maxf(s.t, 4.0)
				if s.t > 4.6:
					gone = true
			"pillar":
				if s.t >= s.warn and not s.hit:
					s.hit = true
					dust(s.x, M.floorY, 8)
					Sfx.slam()
					if alive and absf(P.x - s.x) < 14 and P.y > M.floorY - 88:
						if launchHit(s.src, 1.4):
							P.vy = -520
				gone = s.t > s.warn + 1.6
			"skybeam":
				if s.t >= s.warn and s.t < s.warn + 0.45 and not s.hit and alive and absf(P.x - s.x) < s.w / 2 + 5:
					s.hit = true
					abyssChip(s.src, 1.5, 0.0, true)
				if s.t >= s.warn and not s.get("snd", false):
					s.snd = true
					Sfx.tone(1400, 0.4, "sine", 0.05, 500)
				gone = s.t > s.warn + 0.5
			"circle":
				if s.t > 1.2 and not s.get("done", false):
					s.done = true
					_spawnDemon(s.x)
				gone = s.t > 1.8
			"swat":
				gone = s.t > 0.25
		if gone:
			gSpells.remove_at(i)


func frontBusy() -> bool:
	return super.frontBusy() or not gSpells.is_empty()


# ---------------- frozen solid (the ice wave, his ice punches)

func freezeStun(dur: float) -> void:
	if P.state == "dead" or P.hp <= 0 or save.settings.god:
		return
	P.held = {"kind": "frozen", "t": 0.0, "dur": dur, "e": null}
	P.state = "held"
	P.vx = 0
	floatText(P.x, P.y - 60, "Frozen!", "call")
	Sfx.tone(2600, 0.3, "triangle", 0.06, 1400)


func abyssHold(dt: float) -> bool:
	var H = P.held
	if H == null or H.get("kind") != "frozen":
		return super.abyssHold(dt)
	H.t += dt
	P.state = "held"
	P.vx = 0
	setAnim("hurt")
	var g = _surfBelow(P.x, P.y)
	if P.y < g - 0.5:
		P.vy = minf(MAXFALL, P.vy + GRAV * dt)
		P.y = minf(g, P.y + P.vy * dt)
	else:
		P.y = g
		P.vy = 0
		P.grounded = true
	if pressed.get("c"):
		H.t += 0.2   # struggle out faster
	if H.t >= H.dur:
		_releasePlayer()
		for k in 10:
			part(P.x + rand(-8, 8), P.y - rand(4, 36), rand(-60, 60), rand(-90, -10), 0.4, "#bff4ff" if k % 2 else "#ffffff", 300, 1)
		Sfx.tone(3000, 0.15, "triangle", 0.05, 2000)
		return false
	return true


func statusExtra() -> Array:
	var out = super.statusExtra()
	if P.held != null and P.held.get("kind") == "frozen":
		out.append("❄ Frozen · press C to break free")
	return out


# ---------------- the energy ball: only Rock's sword can send it back

func _gxOrb(e) -> void:
	var st = _staff(e)
	var o = _newMob("glamrax", GLAMRAX_T, st.x, st.y + 6, e.surf)
	o.bossPart = true; o.owner = e; o.partMul = 0.0; o.w = 12; o.h = 12
	o.state = "idle"; o.aggro = true
	o.data = {"kind": "orb", "to": "you", "speed": 170.0, "n": 0, "vx": 0.0, "vy": 0.0, "life": 0.0}
	slimes.append(o)
	Sfx.tone(700, 0.5, "sine", 0.06, 300)


func _gxClearOrbs() -> void:
	for q in slimes.duplicate():
		if q.bossPart and q.data.get("kind") == "orb":
			slimes.erase(q)


func updatePart(p, dt: float) -> void:
	if p.data.get("kind") != "orb":
		super.updatePart(p, dt)
		return
	var e = p.owner
	p.flash -= dt
	p.showBar = 0
	var D: Dictionary = p.data
	D.life += dt
	if e == null or not slimes.has(e) or e.state == "dead" or e.state == "fallen" or D.life > 9:
		slimes.erase(p)
		return
	var c = Vector2(p.x, p.y - 6)
	var to = Vector2(P.x, P.y - 22) if D.to == "you" else Vector2(e.x, e.y - 40)
	var dir = (to - c).normalized()
	var v = Vector2(D.vx, D.vy)
	v = v.lerp(dir * D.speed, minf(1, dt * (3.0 if D.to == "you" else 8.0)))
	D.vx = v.x; D.vy = v.y
	p.x += v.x * dt
	p.y += v.y * dt
	if D.to == "you":
		if P.state != "dead" and overlap(sBox(p), pBox()):
			hurtPlayer(_gxSrc(e, p.x), e.atk * 1.0)
			sparks(p.x, p.y - 6, "#ff4ad8", 10)
			slimes.erase(p)
	elif c.distance_to(to) < 18:
		var ED: Dictionary = e.data
		var keep = 1.0 - D.n * 0.22
		if ED.stunT <= 0 and ED.form == "robe" and randf() < keep:
			# he swats it back at you, faster every time
			D.n += 1
			D.to = "you"
			D.speed += 55
			ED.flash = 0.2
			ED.anim = "swat"
			gSpells.append({"kind": "swat", "x": e.x, "y": e.y - 44, "t": 0.0})
			Sfx.tone(900 + D.n * 120, 0.15, "square", 0.06, 1400)
			floatText(e.x, e.y - 84, "Ha!" if D.n < 3 else "...!", "call")
		else:
			# it gets through: down he comes
			slimes.erase(p)
			ED.stunT = 3.0
			ED.spell = ""
			e.vy = 0
			e.hp = maxf(e.maxHp * 0.011, e.hp - e.maxHp * 0.02)
			floatText(e.x, e.y - 90, "STUNNED!", "crit")
			hitstop = 0.15
			shake = 10
			Sfx.burst(0.6, "lowpass", 1600, 200, 0.4)
			for k in 20:
				var a = randf() * TAU
				part(e.x, e.y - 40, cos(a) * 120, sin(a) * 120, 0.5, "#ff4ad8" if k % 2 else "#ffffff", 0, 2)


func damagePart(p, mv: Dictionary) -> void:
	if p.data.get("kind") != "orb":
		super.damagePart(p, mv)
		return
	if p.data.to != "you" or classId != "rock":
		return
	# Rock's sword sends it back
	p.data.to = "him"
	p.data.speed += 50
	var e = p.owner
	if e != null:
		var dir = (Vector2(e.x, e.y - 40) - Vector2(p.x, p.y - 6)).normalized()
		p.data.vx = dir.x * p.data.speed
		p.data.vy = dir.y * p.data.speed
	floatText(p.x, p.y - 16, "Reflected!", "call")
	Sfx.parry()
	hitstop = 0.06
	sparks(p.x, p.y - 6, "#ffffff", 12)
	styleAdd(30, "parry")


## a stunned wizard takes extra; a shielded one takes less
func bossDmgMul(e, mv: Dictionary) -> float:
	if e.bossKind != "glamrax":
		return super.bossDmgMul(e, mv)
	var m = 1.0
	if e.data.get("stunT", 0.0) > 0:
		m *= 1.3
	if e.data.get("shield", false):
		m *= 0.75
		e.data.flash = 0.12
	if e.state == "intro" or e.state == "fallen":
		m = 0.0
	return m


func bossBoxKind(e) -> Dictionary:
	if e.bossKind != "glamrax":
		return super.bossBoxKind(e)
	if e.data.get("anim") == "dazed":
		return hbox(e.x - 22, e.x + 22, e.y - 30, e.y)
	return hbox(e.x - 14, e.x + 14, e.y - 70, e.y)


# ---------------- 25%: the robes come off; 10%: the horns

func _gxShed(e, dt: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	D.robe = minf(1, e.t / 1.2)
	D.anim = "shed"
	if e.t < 0.05 and not D.get("shedSaid", false):
		D.shedSaid = true
		floatText(e.x, e.y - 90, "ENOUGH.", "call")
		Sfx.tone(70, 1.4, "sawtooth", 0.1, 50)
	if e.t > 0.5 and randf() < dt * 40:
		part(e.x + rand(-14, 14), e.y - rand(10, 70), rand(-140, 140), rand(-160, -20), rand(0.6, 1.2), "#24102e" if randf() < 0.6 else "#7a2a8a", 200, 2)
	if e.t > 1.2:
		# he drops to the floor
		e.vy = minf(e.vy + 1200 * dt, 900)
		e.y = minf(g, e.y + e.vy * dt)
		if e.y >= g - 0.5:
			e.y = g
			if D.form != "muscle":
				D.form = "muscle"
				shake = 12
				dust(e.x, g, 20)
				Sfx.slam()
				e.h = 72
				banner("GLAMRAX", "The robes come off")
			if e.t > 2.2:
				D.act = ""
				D.anim = "idle"
				D.cd = 3.0


func _gxHorns(e, dt: float) -> void:
	var D: Dictionary = e.data
	D.anim = "roar"
	e.vx = 0
	D.horns = minf(1, e.t / 1.4)
	if e.t < 0.05 and not D.get("hornSaid", false):
		D.hornSaid = true
		Sfx.tone(50, 2.0, "sawtooth", 0.12, 40)
		Sfx.burst(1.5, "lowpass", 400, 100, 0.4)
		floatText(e.x, e.y - 96, "NO MORE SPELLS.", "call")
	shake = maxf(shake, 3)
	if randf() < dt * 30:
		part(e.x + rand(-20, 20), e.y - rand(0, 80), rand(-30, 30), -rand(40, 120), 0.6, "#ff2a4a" if randf() < 0.5 else "#2a0a14", -40, 2)
	if e.t > 1.6:
		D.act = ""
		D.anim = "idle"
		D.spell = ""
		banner("GLAMRAX", "His fists carry the magic now")


# ---------------- the brawler: fast, close, combos

func _gxBrawl(e, dt: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	var fast: float = 2.0 if D.horns > 0 else 1.0
	e.vy = minf(e.vy + 1100 * dt, 900)
	e.y = minf(g, e.y + e.vy * dt)
	var dx = P.x - e.x
	if D.act == "":
		if absf(dx) > 8:
			e.face = int(sgn(dx))
		if D.spell != "":
			e.vx = 0
			D.anim = "cast"
		elif absf(dx) > 34:
			e.vx = e.face * 190 * fast
			D.anim = "run"
			if absf(dx) > 110 and absf(dx) < 220 and randf() < dt * 1.2 * fast:
				_gxMelee(e, "dash")
		else:
			e.vx = 0
			if P.state != "dead":
				_gxMelee(e, "combo" if randf() < 0.7 else "upper")
	else:
		_gxMeleeStep(e, dt, fast)
	e.x = clampf(e.x + e.vx * dt, 24, M.w - 24)
	if D.anim == "run":
		D.walkT = D.get("walkT", 0.0) + dt * 14 * fast


func _gxMelee(e, kind: String) -> void:
	var D: Dictionary = e.data
	D.act = kind
	D.n = 0
	e.t = 0.0
	e.hitDone = false
	if D.horns > 0:
		D.elem = GX_ELEMS[D.elemI % GX_ELEMS.size()]
		D.elemI += 1
	else:
		D.elem = ""
	Sfx.whoosh(1.0, true)


func _gxHit(e, mul: float, finisher: bool) -> bool:
	var D: Dictionary = e.data
	var src = _gxSrc(e, e.x, {"crit": finisher})
	var ok = launchHit(src, mul) if finisher else critChip(src, mul, false)
	if not ok or P.state == "dead":
		return ok
	shake = maxf(shake, 6 if finisher else 3)
	Sfx.slam() if finisher else Sfx.tone(160, 0.08, "square", 0.08, 90)
	match D.elem:
		"fire":
			ignite(src)
		"lightning":
			if not finisher:
				shockStun(0.5)
		"ice":
			if not finisher:
				freezeStun(0.6)
		"earth":
			if finisher:
				gSpells.append({"kind": "pillar", "x": P.x, "t": 0.45, "warn": 0.7, "hit": false, "src": src})
		"water":
			P.vx = e.face * 520
			for k in 14:
				part(P.x, P.y - 20, e.face * rand(60, 200), rand(-160, 0), 0.5, "#9ad8ff" if k % 2 else "#ffffff", 400, 1)
	if D.elem != "":
		for k in 8:
			part(P.x, P.y - 24, rand(-80, 80), rand(-80, 40), 0.35, GX_ELEM_COL[D.elem], 0, 2)
	return ok


func _gxMeleeStep(e, dt: float, fast: float) -> void:
	var D: Dictionary = e.data
	var reach = func(w: float) -> bool: return overlap(hbox(e.x - 6, e.x + w, e.y - 64, e.y - 8) if e.face > 0 else hbox(e.x - w, e.x + 6, e.y - 64, e.y - 8), pBox())
	match D.act:
		"combo":
			# jab, jab, hook
			var cyc = 0.26 / fast
			var n = int(e.t / cyc)
			D.anim = ["jab", "jab2", "hook"][mini(n, 2)]
			e.vx = e.face * 60 * fast
			if n > D.n and n <= 3:
				D.n = n
				e.hitDone = false
			if not e.hitDone and fmod(e.t, cyc) > cyc * 0.4 and n < 3 and reach.call(42.0):
				e.hitDone = true
				_gxHit(e, 0.55 if n < 2 else 1.1, n == 2)
			if e.t > cyc * 3 + 0.3 / fast:
				D.act = ""
				e.vx = -e.face * 120   # a hop back
		"upper":
			D.anim = "crouch" if e.t < 0.25 / fast else "upper"
			e.vx = 0
			if e.t > 0.25 / fast and not e.hitDone and reach.call(38.0):
				e.hitDone = true
				if _gxHit(e, 1.25, true):
					P.vy = -560
			if e.t > 0.7 / fast:
				D.act = ""
		"dash":
			D.anim = "crouch" if e.t < 0.3 / fast else "dashpunch"
			if e.t > 0.3 / fast:
				e.vx = e.face * 480 * fast
				if randf() < dt * 40:
					part(e.x - e.face * 10, e.y - 30, -e.face * rand(60, 160), rand(-20, 20), 0.3, "#ff4ad8", 0, 2)
				if not e.hitDone and reach.call(36.0):
					e.hitDone = true
					if _gxHit(e, 1.35, true):
						P.vx = e.face * 460
			if e.t > 0.3 / fast + 0.45 or e.x <= 25 or e.x >= M.w - 25:
				D.act = ""
				e.vx = 0


# ---------------- the abyssal demon (75%)

func _spawnDemon(x: float) -> void:
	var T: Dictionary = SLIME_TYPES.gdemon
	var e = _newMob("gdemon", T, x, groundAt(x), floorSurfAt(x))
	e.w = 36; e.h = 66
	e.aggro = true
	e.state = "chase"
	e.face = int(sgn(P.x - x)) if P.x != x else -1
	e.homeX = x; e.homeY = e.y
	e.data = {"rise": 0.0}
	e.atkCd = 1.2
	slimes.append(e)
	shake = 10
	Sfx.tone(45, 2.0, "sawtooth", 0.12, 35)
	Sfx.burst(1.0, "lowpass", 600, 100, 0.4)
	banner("ABYSSAL DEMON", "Glamrax keeps casting while it lives")
	for k in 30:
		part(x + rand(-30, 30), e.y - rand(0, 20), rand(-40, 40), -rand(80, 220), rand(0.6, 1.2), "#ff2a4a" if k % 2 else "#1a0410", -20, 2)


func climbAI(e, T: Dictionary, dt: float, _dx: float, _dy: float, pb: Dictionary) -> bool:
	if e.type != "gdemon":
		return super.climbAI(e, T, dt, _dx, _dy, pb)
	var D: Dictionary = e.data
	D.rise = minf(1, D.rise + dt * 1.2)
	var tx: float = P.x - e.x
	var ty: float = (P.y - 20) - (e.y - e.h / 2)
	var gr = _grounded(e)
	var alive = P.state != "dead"
	if e.state == "hurt":
		e.stun -= dt
		if e.stun <= 0:
			_setState(e, "chase")
			e.atkCd = maxf(e.atkCd, 0.4)
	else:
		match e.state:
			"idle", "chase":
				e.face = int(sgn(tx)) if absf(tx) > 6 else e.face
				e.walk = e.face * 120 if absf(tx) > 34 else 0.0
				if gr and e.atkCd <= 0 and alive and D.rise >= 1:
					if absf(tx) < 46 and absf(ty) < 50:
						e.move = "claw"
					elif absf(tx) < 220 and randf() < 0.5:
						e.move = "leap"
					else:
						e.move = "breath"
					_setState(e, "wind")
					e.walk = 0
					D.n = 0
					Sfx.tone(80, 0.5, "sawtooth", 0.08, 50)
			"wind":
				e.walk = 0
				var tell = {"claw": 0.32, "leap": 0.45, "breath": 0.5}.get(e.move, 0.4)
				if e.t > tell:
					_setState(e, "act")
					e.hitDone = false
					if e.move == "leap":
						e.vy = -380
						e.vx = clampf(tx / 0.7, -320, 320)
						Sfx.whoosh(0.8, true)
					elif e.move == "claw":
						e.vx = e.face * 140
						Sfx.whoosh(1.2, true)
			"act":
				match e.move:
					"claw":
						e.vx *= exp(-dt * 6)
						var hb = hbox(e.x, e.x + 48, e.y - 60, e.y) if e.face > 0 else hbox(e.x - 48, e.x, e.y - 60, e.y)
						if not e.hitDone and overlap(hb, pb):
							e.hitDone = true
							if D.n < 1:
								critChip(_src(e, e.x), 0.9, false)
							else:
								launchHit(_src(e, e.x), 1.6)
						if e.t > 0.3:
							if D.n < 1:
								D.n += 1
								e.t = 0.0
								e.hitDone = false
								e.face = int(sgn(tx)) if absf(tx) > 4 else e.face
								e.vx = e.face * 140
								Sfx.whoosh(1.1, true)
							else:
								_setState(e, "recover")
					"leap":
						if not e.hitDone and e.vy > 0 and overlap(sBox(e), pb):
							e.hitDone = true
							launchHit(_src(e, e.x), 1.6)
						if gr and e.t > 0.15:
							shake = 8
							dust(e.x, e.y, 14)
							Sfx.slam()
							if alive and P.grounded and absf(P.x - e.x) < 60 and not e.hitDone:
								e.hitDone = true
								launchHit(_src(e, e.x), 1.4)
							_setState(e, "recover")
					"breath":
						# a cone of hellfire in front of it
						e.vx = 0
						if randf() < dt * 60:
							var a = rand(-0.35, 0.35)
							part(e.x + e.face * 18, e.y - 50, e.face * cos(a) * rand(140, 220), sin(a) * 120 + 20, 0.45, ["#ff4a1a", "#ffb03a", "#ff2a4a"][rint(0, 2)], 0, 2)
						D.tick = D.get("tick", 0.0) - dt
						var dxp = (P.x - e.x) * e.face
						if alive and dxp > 0 and dxp < 110 and absf((P.y - 20) - (e.y - 45)) < 12 + dxp * 0.35 and D.tick <= 0:
							D.tick = 0.35
							if abyssChip(_src(e, e.x), 0.45, 0.0, true):
								ignite(_src(e, e.x))
						if e.t > 1.0:
							_setState(e, "recover")
			"recover":
				e.walk = 0
				e.vx *= exp(-dt * 6)
				if e.t > 0.55:
					_setState(e, "chase")
					e.atkCd = rand(0.7, 1.3)
	_climbPhysics(e, T, dt)
	return true


func killSlime(e) -> void:
	if e.type != "gdemon":
		super.killSlime(e)
		return
	# no residue or cards: it goes back where it came from
	e.state = "dead"; e.deadT = 0; e.hp = 0
	Sfx.tone(60, 1.0, "sawtooth", 0.1, 30)
	shake = 8
	for k in 30:
		part(e.x + rand(-20, 20), e.y - rand(0, 60), rand(-60, 60), -rand(40, 160), rand(0.5, 1.0), "#ff2a4a" if k % 2 else "#1a0410", -20, 2)
	var total = rint(int(e.T.coins[0]), int(e.T.coins[1]))
	for k in 8:
		_drop("coin", e, rand(-70, 70), rand(-260, -160), maxi(1, total / 8))
	var gained = roundi(mobExp(e) * (1 + cardBonus()))
	gainExp(gained)
	floatText(e.x, e.y - e.h - 16, "+%d EXP" % gained, "exp")
	banner("DEMON BANISHED", "")
	styleAdd(60, "kill")


# ================================================================ 1%: the end (it isn't)

func killBoss(e) -> void:
	if e.bossKind == "glamrax":
		e.hp = maxf(1, e.maxHp * 0.01)
		_startFakeEnd(e)
		return
	super.killBoss(e)


func _startFakeEnd(e) -> void:
	if e.state == "fallen":
		return
	e.hp = maxf(1, ceilf(e.maxHp * 0.01))
	e.state = "fallen"
	e.t = 0.0
	e.vx = 0
	e.vy = 0
	e.data.spell = ""
	e.data.act = ""
	e.data.anim = "fall"
	gSpells.clear()
	_gxClearOrbs()
	for q in slimes:
		if q.type == "gdemon" and q.state != "dead":
			q.state = "dead"
	Burn.t = 0
	if P.held != null:
		_releasePlayer()
	P.frozen = true
	P.vx = 0
	slowmo = 1.6
	hitstop = 0.3
	shake = 14
	Sfx.music_stop()
	Sfx.tone(90, 2.4, "sawtooth", 0.1, 40)
	advanceMain("", "glamrax")


func _updateFakeEnd(e, dt: float) -> void:
	var D: Dictionary = e.data
	var g = groundAt(e.x)
	e.vy = minf(e.vy + 900 * dt, 600)
	e.y = minf(g, e.y + e.vy * dt)
	if e.y >= g - 0.5:
		if D.anim != "lying":
			D.anim = "lying"
			dust(e.x, g, 16)
			Sfx.slam()
	P.vx = 0
	P.iframes = maxf(P.iframes, 0.5)
	if e.t > 2.6 and not D.get("ended", false):
		D.ended = true
		_endingScreens()


## the ending that isn't one: the "happy ending", a fade to black, a laugh, and back to the menu
func _endingScreens() -> void:
	var cls: String = classId
	var name: String = CLASSES[cls].name
	var kin: String = GX_KIN.get(cls, "family")
	var scenes = [
		{"kind": "g_end", "title": false, "text": "Glamrax lies still. The crystal cracks, and %s's %s tumbles out into %s's arms." % [name, kin, name]},
		{"kind": "g_end2", "title": true, "text": "THE END"},
		{"kind": "g_laugh", "title": false, "text": "..."},
	]
	glamraxCutscene(cls, scenes, func(): _captureHero(cls))
	Sfx.music("trophy")


## the hero who beat him is in the crystal now
func _captureHero(cls: String) -> void:
	if not (save.get("captured") is Dictionary):
		save.captured = {}
	save.captured[cls] = {"level": CH().level, "t": Time.get_unix_time_from_system()}
	var c: Dictionary = save.chars[cls]
	c.pos = {"map": "home" if cls != "summoner" else "house", "x": null, "y": null}
	c.erase("pos")
	P.frozen = false
	GX = {}
	camZoom = 1.0
	saveDirty = true
	persist()
	toCharSelect()
	later(0.6, func(): toast("%s is sealed in Glamrax's crystal." % CLASSES[cls].name))


func heroCaptured(cls: String) -> bool:
	var c = save.get("captured")
	return c is Dictionary and c.has(cls)

