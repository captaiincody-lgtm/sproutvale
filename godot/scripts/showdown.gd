extends "res://scripts/glamrax.gd"
## Sproutvale, after the false ending: every hero Glamrax beats ends up in his crystal. Once all five
## are there, Glamrax himself is playable. He is Level 200, fully upgraded, with every spell he used on
## you. His story plays (the ancient text, the five loved ones, the trap), then you hold his sanctum
## against all five heroes at once, each at the level they beat him at.
##
## The heroes here are AI fighters drawn with their own sprites (showdown_draw.gd). The finale reuses
## them as allies (finale.gd).

const GM_HP := 46000.0      # Glamrax, played: Level 200 and fully upgraded
const GM_ATK := 1100.0
const GM_DEF := 1400.0
const GM_KEYS := ["z", "x", "c", "a", "s", "d", "f", "q", "w", "e", "r"]
const GM_KIT := {
	"z": {"name": "Energy Bolt", "cd": 0.35, "col": "#ff4ad8", "tip": "A homing ball of abyssal energy"},
	"x": {"name": "Chain Lightning", "cd": 1.6, "col": "#9ad8ff", "tip": "Strikes the nearest hero and jumps to the next ones"},
	"c": {"name": "Blink", "cd": 0.9, "col": "#e8b8ff", "tip": "Step through space, untouchable for a moment"},
	"a": {"name": "Meteor Rain", "cd": 6.0, "col": "#ff5a1a", "tip": "A meteor on every hero, and fire where it lands"},
	"s": {"name": "Fire Tornado", "cd": 8.0, "col": "#ff8a2a", "tip": "A burning tornado that hunts them down"},
	"d": {"name": "Ice Wave", "cd": 9.0, "col": "#bff4ff", "tip": "Ice along the floor that freezes whoever it touches"},
	"f": {"name": "Earth Pillars", "cd": 7.0, "col": "#c8a070", "tip": "Stone bursts up under every hero"},
	"q": {"name": "Tidal Wave", "cd": 14.0, "col": "#4ab0ff", "tip": "Sweeps the whole sanctum"},
	"w": {"name": "Abyssal Light", "cd": 12.0, "col": "#e8b8ff", "tip": "Beams from above on every hero"},
	"e": {"name": "Mana Shield", "cd": 24.0, "col": "#7af0ff", "tip": "40% less damage for 8 seconds"},
	"r": {"name": "Unleash", "cd": 45.0, "col": "#ff2a4a", "tip": "Robes off, horns out: harder spells, faster cooldowns for 10 seconds"},
}
## the heroes' fighting styles: how far they like to stand, how fast they move, what they do
const HERO_KIT := {
	"rock": {"band": [22, 36], "spd": 155.0, "moves": [
			{"id": "slash", "anim": "slash", "kind": "melee", "range": 44, "dur": 0.42, "hit": 0.16, "mul": 1.0, "reach": 40},
			{"id": "thrust", "anim": "thrust", "kind": "melee", "range": 70, "dur": 0.5, "hit": 0.22, "mul": 1.3, "reach": 46, "lunge": 260},
			{"id": "heavy", "anim": "heavy", "kind": "melee", "range": 44, "dur": 0.72, "hit": 0.42, "mul": 2.0, "reach": 46, "armor": true}],
		"skill": {"id": "whirl", "anim": "whirl", "kind": "spin", "range": 70, "dur": 0.9, "hit": 0.1, "mul": 0.6, "reach": 42, "cd": 8.0, "armor": true}},
	"archer": {"band": [130, 200], "spd": 150.0, "moves": [
			{"id": "shoot", "anim": "a_shoot", "kind": "shot", "range": 320, "dur": 0.36, "hit": 0.14, "mul": 0.8, "proj": "arrow", "speed": 430.0},
			{"id": "swing", "anim": "a_swing", "kind": "melee", "range": 40, "dur": 0.36, "hit": 0.14, "mul": 0.9, "reach": 38, "kb": 260}],
		"skill": {"id": "rapid", "anim": "a_rapid", "kind": "volley", "range": 320, "dur": 1.0, "hit": 0.12, "mul": 0.55, "n": 6, "proj": "arrow", "speed": 470.0, "cd": 7.0}},
	"mage": {"band": [110, 170], "spd": 125.0, "moves": [
			{"id": "wand", "anim": "m_wand", "kind": "shot", "range": 300, "dur": 0.42, "hit": 0.18, "mul": 1.05, "proj": "bolt", "speed": 300.0},
			{"id": "thwack", "anim": "m_thwack", "kind": "melee", "range": 40, "dur": 0.4, "hit": 0.18, "mul": 1.0, "reach": 38, "kb": 220}],
		"skill": {"id": "erupt", "anim": "m_staff", "kind": "erupt", "range": 320, "dur": 0.9, "hit": 0.3, "mul": 2.4, "cd": 6.5}},
	"summoner": {"band": [80, 140], "spd": 135.0, "moves": [
			{"id": "cmd", "anim": "j_cmd", "kind": "shot", "range": 300, "dur": 0.42, "hit": 0.16, "mul": 1.1, "proj": "spirit", "speed": 210.0},
			{"id": "push", "anim": "j_push", "kind": "melee", "range": 42, "dur": 0.4, "hit": 0.16, "mul": 0.9, "reach": 40, "kb": 320}],
		"skill": {"id": "fire", "anim": "j_fire", "kind": "cone", "range": 110, "dur": 1.1, "hit": 0.2, "mul": 0.5, "reach": 100, "cd": 7.0}},
	"tank": {"band": [110, 180], "spd": 125.0, "moves": [
			{"id": "pistol", "anim": "a_shoot", "kind": "volley", "range": 320, "dur": 0.5, "hit": 0.1, "mul": 0.45, "n": 3, "proj": "bullet", "speed": 560.0},
			{"id": "nade", "anim": "j_throw", "kind": "shot", "range": 260, "dur": 0.5, "hit": 0.2, "mul": 1.8, "proj": "nade", "speed": 240.0}],
		"skill": {"id": "drone", "anim": "j_push", "kind": "beam", "range": 400, "dur": 0.6, "hit": 0.2, "mul": 2.2, "cd": 10.0}},
}
const HERO_BARK := {"rock": "It ends here, Glamrax!", "archer": "I'm sorry... I have to.", "mage": "My turn to take my time.",
	"summoner": "Get him, everybody!", "tank": "Target acquired. Dismantling."}
const HERO_DOWN := {"rock": "Not... yet...", "archer": "I'm... sorry...", "mage": "Tch...", "summoner": "No fair...", "tank": "System... failure..."}

var GM := {}              # playing as Glamrax: {on, phase, t, cds, shieldT, hornsT, castT, hurtT, deadT, anim}
var fighters: Array = []  # the heroes in the showdown (foes) and in the finale (allies)
var hShots: Array = []    # their arrows, bolts, spirits, bullets, grenades, eruptions and drone beams
var _rawStats := false
var _fid := 0


# ================================================================ unlocking him

func capturedAll() -> bool:
	var c = save.get("captured")
	if not (c is Dictionary):
		return false
	for h in GX_PODS:
		if not c.has(h):
			return false
	return true


func glamraxUnlocked() -> bool:
	return capturedAll() or save.get("showdownWon", false)


## a hero's real numbers (level, gear, skills, treasures), as if you were playing them
func heroStats(cls: String) -> Dictionary:
	var old = classId
	classId = cls
	_rawStats = true
	var s = calcStats()
	_rawStats = false
	classId = old
	return s


func calcStats() -> Dictionary:
	var s = super.calcStats()
	if GM.get("on", false) and not _rawStats:
		s.hp = GM_HP
		s.atk = GM_ATK
		s.def = GM_DEF
		s.crit = 15.0
		s.critDmg = 1.8
		for k in TREE.PS_KEYS:   # Glamrax has no Attribute Tree
			s.erase(k)
	return s


# ================================================================ starting the showdown

func startShowdown() -> void:
	if inGame or introBusy():
		return
	var body = pickedClass()
	if not save.get("glamraxStory", false):
		glamraxCutscene(body, [
			{"kind": "gb_tome", "title": false, "text": "Long before any of this, deep in the heart of the volcano, Glamrax found a book older than the mountain itself."},
			{"kind": "gb_page", "title": false, "text": "It told of a way to seal the living in crystal, pour their strength into an engine, and pour the engine into somebody else."},
			{"kind": "gb_take", "title": false, "text": "So he took them, one by one: a son, a little sister, a grandmother, a little brother, a mother. Each of them precious to somebody strong."},
			{"kind": "gb_wait", "title": false, "text": "\"Set the traps, and wait for them to grow more powerful... Then, they'll come straight to me.\""},
			{"kind": "gb_title", "title": true, "text": "The Showdown"},
		], func():
			save.glamraxStory = true
			saveDirty = true
			startShowdown())
		Sfx.music("piano")
		return
	setClass(body)
	inGame = true
	menuOpen = false
	GM = {"on": true, "phase": "intro", "t": 0.0, "cds": {}, "shieldT": 0.0, "hornsT": 0.0, "castT": 0.0, "hurtT": 0.0, "deadT": 0.0,
		"anim": "float", "entered": 0, "spell": ""}
	for k in GM_KEYS:
		GM.cds[k] = 0.0
	PS = calcStats()
	P.hp = PS.hp
	P.en = PS.enMax
	P.state = "move"
	P.held = null
	P.frozen = false
	P.iframes = 0.0
	P.face = -1
	fighters.clear()
	hShots.clear()
	loadMap("volcano4", 520, null)
	P.face = -1
	Sfx.music("glamrax")
	banner("GLAMRAX · Level 200", "They're coming. Every one of them.")


func spawnBossKind(kind: String, fromPedestal := false) -> bool:
	if kind == "glamrax" and GM.get("on", false):
		return true   # you are Glamrax: nobody else sits at the piano
	return super.spawnBossKind(kind, fromPedestal)


func loadMap(id: String, px0 = null, py0 = null) -> void:
	hShots.clear()
	if GM.get("on", false) and id != "volcano4":
		_gmEnd()
	super.loadMap(id, px0, py0)


func _gmEnd() -> void:
	GM = {}
	fighters.clear()
	hShots.clear()
	gSpells.clear()


## Esc in the showdown leaves it, back to the select screen (game.gd routes the key here)
func _gmLeave() -> void:
	_gmEnd()
	P.hp = 1
	toCharSelect()


func pBox() -> Dictionary:
	if GM.get("on", false):
		return hbox(P.x - 9, P.x + 9, P.y - 66, P.y)
	return super.pBox()


func hurtPlayer(src, dmg: float) -> void:
	if not GM.get("on", false):
		super.hurtPlayer(src, dmg)
		return
	if GM.phase != "fight" or P.state == "dead":
		return
	if GM.shieldT > 0:
		dmg *= 0.6
	var st0 = P.state
	super.hurtPlayer(src, dmg)
	# a wizard doesn't get thrown around like a hero: a short stagger, and he's back
	if P.state in ["hurt", "knocked", "flinch"]:
		P.state = "hurt"
		P.vx *= 0.25
		P.vy = maxf(P.vy, -40)
		P.iframes = minf(P.iframes, 0.45)
		GM.hurtT = 0.0
	elif st0 == "dead":
		P.state = "dead"


func killPlayer() -> void:
	if not GM.get("on", false):
		super.killPlayer()
		return
	P.hp = 0
	P.state = "dead"
	P.vx = 0
	GM.deadT = 0.0
	GM.phase = "lost"
	slowmo = 1.2
	Sfx.music_stop()
	Sfx.tone(90, 2.4, "sawtooth", 0.1, 40)
	banner("GLAMRAX FALLS", "The heroes stand over you. Try again from the select screen.")


# ================================================================ playing Glamrax

func updatePlayer(dt: float) -> void:
	if not GM.get("on", false):
		super.updatePlayer(dt)
		return
	_gmUpdate(dt)


func _gmUpdate(dt: float) -> void:
	GM.t += dt
	P.iframes -= dt
	P.flash -= dt
	P.animT += dt
	var fast = 2.0 if GM.hornsT > 0 else 1.0
	for k in GM.cds:
		GM.cds[k] -= dt * fast
	GM.shieldT -= dt
	GM.hornsT -= dt
	GM.castT -= dt
	P.held = null
	match GM.phase:
		"intro":
			_gmIntro(dt)
		"won":
			GM.wonT = GM.get("wonT", 0.0) + dt
			if GM.wonT > 4.0 and not GM.get("left", false):
				GM.left = true
				_showdownWon()
		"lost":
			GM.deadT += dt
			if GM.deadT > 3.8 and not GM.get("left", false):
				GM.left = true
				_gmLeave()
	if not GM.get("on", false):
		return
	var canAct: bool = GM.phase == "fight" and P.state == "move"
	if P.state in ["hurt", "knocked", "flinch", "held"]:
		GM.hurtT += dt
		if GM.hurtT > 0.3:
			P.state = "move"
	var down: bool = K.get("arrowdown", false)
	if canAct:
		var dir = (1 if K.get("arrowright", false) else 0) - (1 if K.get("arrowleft", false) else 0)
		var spd = 140.0 * (1.35 if GM.hornsT > 0 else 1.0)
		P.vx = move_toward(P.vx, dir * spd, 1400 * dt)
		if dir != 0:
			P.face = dir
		if K.get(" ", false):   # Space: he rises, as if it were nothing
			P.vy = move_toward(P.vy, -170, 900 * dt)
		else:
			P.vy = move_toward(P.vy, 380.0 if down else 140.0, 700 * dt)
		for k in GM_KEYS:
			if pressed.get(k, false) and GM.cds[k] <= 0:
				_gmCast(k)
	else:
		P.vx *= exp(-dt * 6)
		P.vy = minf(P.vy + 900 * dt, 420)
	var prevY = P.y
	P.x = clampf(P.x + P.vx * dt, 16, M.w - 16)
	P.y += P.vy * dt
	var top = M.get("ceilY", 30) + 84.0
	if P.y < top:
		P.y = top
		P.vy = maxf(P.vy, 0)
	P.grounded = false
	if P.vy >= 0 and not (down and canAct):
		for s in surfaces:
			if P.x >= s.x0 and P.x <= s.x1 and s.y >= prevY - 0.5 and s.y <= P.y:
				P.y = s.y
				P.vy = 0
				P.grounded = true
				break
	var g = groundAt(P.x)
	if P.y >= g:
		P.y = g
		P.vy = 0
		P.grounded = true
	GM.anim = "lying" if P.state == "dead" else ("cast" if GM.castT > 0 else ("dazed" if P.state == "hurt" else "float"))
	_updateFighters(dt)


## the heroes come in through the portal one at a time, and each says their piece
func _gmIntro(_dt: float) -> void:
	var order = GX_PODS
	var i: int = GM.entered
	if i < order.size() and GM.t > 0.8 + i * 0.9:
		var f = _newFighter(order[i], "foe", 40.0)
		f.enterX = P.x - 175.0 + i * 30
		f.bark = HERO_BARK[order[i]]
		f.barkT = 3.2
		fighters.append(f)
		GM.entered = i + 1
		Sfx.tone(300 + i * 60, 0.3, "sine", 0.05, 600)
	if GM.t > 0.8 + order.size() * 0.9 + 2.6:
		GM.phase = "fight"
		banner("THE SHOWDOWN", "Arrows move · Space floats · Z X C A S D F Q W E R cast")
		Sfx.thunder()
		for f in fighters:
			if f.state in ["enter", "wait"]:
				f.state = "idle"


func _showdownWon() -> void:
	save.showdownWon = true
	saveDirty = true
	persist()
	startFinale()


## the finale (finale.gd): rescue and revenge
func startFinale() -> void:
	_gmEnd()
	toCharSelect()


# ---------------- his spells

func _gmCast(k: String) -> void:
	var K2: Dictionary = GM_KIT[k]
	GM.cds[k] = K2.cd
	GM.castT = 0.3
	GM.spell = k
	var st = Vector2(P.x + P.face * 15, P.y - 66)
	var src = {"x": P.x, "lv": 200, "boss": true, "atk": GM_ATK}
	var foes = _liveFoes()
	match k:
		"z":
			var tgt = _nearestFoe(P.x, P.face)
			gSpells.append({"kind": "mbolt", "x": st.x, "y": st.y, "vx": P.face * 260.0, "vy": 0.0, "t": 0.0, "mine": true, "tgt": tgt.id if tgt != null else -1, "src": src})
			Sfx.tone(700, 0.25, "sine", 0.05, 300)
		"x":
			var first = _nearestFoe(P.x, 0)
			if first == null or absf(first.x - P.x) > 320:
				GM.cds[k] = 0.3
				return
			var chain = [first]
			var cur = first
			for n in 3:
				var best = null
				for f in foes:
					if f in chain:
						continue
					var d = Vector2(f.x - cur.x, f.y - cur.y).length()
					if d < 170 and (best == null or d < Vector2(best.x - cur.x, best.y - cur.y).length()):
						best = f
				if best == null:
					break
				chain.append(best)
				cur = best
			var pts = [st]
			for f in chain:
				pts.append(Vector2(f.x, f.y - 22))
				_gmHitFoe(f, 1.3, {"shock": 0.5})
			gSpells.append({"kind": "mzap", "pts": pts, "t": 0.0, "mine": true})
			Sfx.thunder()
		"c":
			var nx = clampf(P.x + P.face * 110, 20, M.w - 20)
			for n in 12:
				part(P.x + rand(-8, 8), P.y - rand(0, 66), rand(-30, 30), rand(-30, 30), 0.4, "#e8b8ff" if n % 2 else "#ff4ad8", 0, 1)
			P.x = nx
			P.iframes = maxf(P.iframes, 0.35)
			GM.castT = 0.0
			Sfx.tone(1200, 0.2, "sine", 0.05, 2400)
		"a":
			var xs: Array = foes.map(func(f): return f.x)
			xs.append(P.x + P.face * rand(60, 140))
			for i in xs.size():
				var mx = clampf(xs[i], 30, M.w - 30)
				var su = _surfUnder(mx, M.get("ceilY", 30))
				gSpells.append({"kind": "meteor", "x": mx, "gy": su.y if su != null else M.floorY, "t": -i * 0.15, "warn": 0.7, "src": src, "mine": true})
			Sfx.tone(120, 1.0, "sawtooth", 0.06, 60)
		"s":
			gSpells.append({"kind": "tornado", "x": P.x + P.face * 30, "t": 0.0, "life": 3.6, "fire": true, "tick": 0.0, "src": src, "w": 26.0, "mine": true})
			Sfx.burst(1.6, "bandpass", 400, 1200, 0.3)
		"d":
			gSpells.append({"kind": "icewave", "x0": P.x, "dir": P.face, "t": 0.0, "hit": false, "spikes": [], "src": src, "mine": true})
			Sfx.tone(2400, 0.6, "sine", 0.04, 1200)
		"f":
			for i in foes.size():
				gSpells.append({"kind": "pillar", "x": clampf(foes[i].x, 24, M.w - 24), "t": -i * 0.08, "warn": 0.55, "hit": false, "src": src, "mine": true})
			Sfx.burst(0.8, "lowpass", 300, 120, 0.4)
		"q":
			gSpells.append({"kind": "wave", "dir": P.face, "x": 0.0 if P.face > 0 else float(M.w), "t": 0.0, "h": 58.0, "hit": false, "src": src, "mine": true})
			Sfx.burst(2.4, "lowpass", 600, 1400, 0.35)
		"w":
			for i in foes.size():
				gSpells.append({"kind": "skybeam", "x": clampf(foes[i].x, 20, M.w - 20), "t": -i * 0.12, "warn": 0.7, "w": 20.0, "hit": false, "src": src, "mine": true})
			Sfx.tone(900, 1.0, "sine", 0.05, 1400)
		"e":
			GM.shieldT = 8.0
			floatText(P.x, P.y - 86, "MANA SHIELD", "call")
			Sfx.tone(600, 0.8, "sine", 0.06, 1200)
		"r":
			GM.hornsT = 10.0
			shake = 10
			floatText(P.x, P.y - 90, "UNLEASHED", "call")
			Sfx.tone(50, 2.0, "sawtooth", 0.12, 40)
			Sfx.burst(1.2, "lowpass", 400, 100, 0.4)
			for n in 30:
				part(P.x + rand(-16, 16), P.y - rand(0, 70), rand(-140, 140), rand(-160, -20), rand(0.5, 1.0), "#24102e" if n % 2 else "#ff2a4a", 200, 2)


func _liveFoes() -> Array:
	return fighters.filter(func(f): return f.team == "foe" and not (f.state in ["down", "enter"]))


func _nearestFoe(x0: float, face: int):
	var best = null
	for f in _liveFoes():
		if face != 0 and sgn(f.x - x0) != face and absf(f.x - x0) > 20:
			continue
		if best == null or absf(f.x - x0) < absf(best.x - x0):
			best = f
	if best == null and face != 0:
		return _nearestFoe(x0, 0)
	return best


func _foeById(id: int):
	for f in fighters:
		if f.id == id:
			return f
	return null


## his spells meet the heroes (called for each of his spells every frame, from glamrax.gd)
func mineSpell(s: Dictionary, dt: float) -> bool:
	var foes = _liveFoes()
	if not s.has("hitIds"):
		s.hitIds = []
	match s.kind:
		"mbolt":
			var f = _foeById(s.tgt)
			if f == null or f.state in ["down", "enter"]:
				f = _nearestFoe(s.x, int(sgn(s.vx)))
				s.tgt = f.id if f != null else -1
			if f != null:
				var to = (Vector2(f.x, f.y - 22) - Vector2(s.x, s.y)).normalized() * 330
				var v = Vector2(s.vx, s.vy).lerp(to, minf(1, dt * 5))
				s.vx = v.x; s.vy = v.y
			s.x += s.vx * dt
			s.y += s.vy * dt
			for q in foes:
				if absf(q.x - s.x) < 12 and s.y > q.y - 44 and s.y < q.y + 2:
					_gmHitFoe(q, 1.0, {})
					sparks(s.x, s.y, "#ff4ad8", 8)
					return true
			return s.t > 2.6 or s.x < 0 or s.x > M.w
		"mzap":
			return s.t > 0.3
		"meteor":
			if s.get("hit", false) and not s.get("mhit", false):
				s.mhit = true
				for q in foes:
					if absf(q.x - s.x) < 36 and absf(q.y - s.gy) < 50:
						_gmHitFoe(q, 2.4, {"burn": 4.0, "launch": -260.0})
		"flames":
			for q in foes:
				if q.grounded and absf(q.y - s.y) < 4 and absf(q.x - s.x) < 20 and q.burnT <= 0:
					q.burnT = 4.0
		"tornado":
			var n = _nearestFoe(s.x, 0)
			if n != null:
				s.tx = n.x
			s.mtick = s.get("mtick", 0.0) - dt
			if s.mtick <= 0:
				for q in foes:
					if absf(q.x - s.x) < s.w * 0.7:
						s.mtick = 0.3
						_gmHitFoe(q, 0.5, {"burn": 3.0, "launch": -300.0})
		"icewave":
			var front = s.x0 + s.dir * 330 * s.t
			for q in foes:
				if not (q.id in s.hitIds) and absf(q.x - front) < 16 and q.grounded:
					s.hitIds.append(q.id)
					_gmHitFoe(q, 1.2, {"freeze": 2.0})
		"pillar":
			if s.t >= s.warn and not s.get("mhit", false):
				s.mhit = true
				for q in foes:
					if absf(q.x - s.x) < 18:
						_gmHitFoe(q, 2.0, {"launch": -480.0})
		"wave":
			for q in foes:
				if not (q.id in s.hitIds) and absf(q.x - s.x) < 22 and q.y > M.floorY - s.h:
					s.hitIds.append(q.id)
					_gmHitFoe(q, 1.6, {"push": s.dir * 420.0})
		"skybeam":
			if s.t >= s.warn and s.t < s.warn + 0.45:
				for q in foes:
					if not (q.id in s.hitIds) and absf(q.x - s.x) < s.w / 2 + 6:
						s.hitIds.append(q.id)
						_gmHitFoe(q, 2.6, {})
	return false


func _gmHitFoe(f, mul: float, fx: Dictionary) -> void:
	if f.state in ["down", "enter"]:
		return
	var dmg = GM_ATK * 0.07 * mul * (1.5 if GM.get("hornsT", 0.0) > 0 else 1.0) * rand(0.9, 1.1) * 100.0 / (100.0 + f.def * 1.5)
	var crit = randf() < 0.15
	if crit:
		dmg *= 1.8
	dmg = maxf(1, roundf(dmg))
	f.hp -= dmg
	f.flash = 0.1
	floatText(f.x, f.y - 50, ("%d!" % dmg) if crit else str(int(dmg)), "crit" if crit else "dmg")
	Sfx.hit(crit)
	sparks(f.x, f.y - 24, "#ff4ad8" if not crit else "#ffe14d", 6)
	if f.hp <= 0:
		_downFighter(f)
		return
	if fx.has("burn"):
		f.burnT = maxf(f.burnT, fx.burn)
	if fx.has("freeze"):
		f.state = "frozen"
		f.frozenT = fx.freeze
		f.vx = 0
		f.mv = null
		return
	if fx.has("launch"):
		f.vy = fx.launch
		f.grounded = false
	if fx.has("push"):
		f.vx = fx.push
	var armored: bool = (f.state == "atk" and f.mv != null and f.mv.get("armor", false)) or f.t < f.poiseT
	if not armored and (mul >= 1.2 or fx.has("shock") or fx.has("launch")):
		f.poiseT = f.t + 1.6   # staggered: they can't be staggered again for a moment
		f.state = "hurt"
		f.hurtT = fx.get("shock", 0.35)
		f.mv = null


func _downFighter(f) -> void:
	f.hp = 0
	f.state = "down"
	f.mv = null
	f.vy = -220
	f.vx = sgn(f.x - P.x) * 120
	f.grounded = false
	f.bark = HERO_DOWN.get(f.cls, "...")
	f.barkT = 2.4
	shake = 6
	hitstop = 0.12
	Sfx.tone(220, 0.8, "triangle", 0.08, 90)
	floatText(f.x, f.y - 64, "DOWN!", "crit")
	if GM.get("on", false) and _liveFoes().is_empty() and fighters.all(func(q): return q.team != "foe" or q.state == "down"):
		GM.phase = "won"
		GM.wonT = 0.0
		slowmo = 1.6
		Sfx.music_stop()
		banner("THE HEROES FALL", "")
		later(1.6, func(): laughNow())


# ================================================================ the heroes, fighting on their own

func _newFighter(cls: String, team: String, x0: float) -> Dictionary:
	var st = heroStats(cls)
	var cap = save.get("captured", {})
	var lv: int = int(cap[cls].level) if cap is Dictionary and cap.has(cls) else int(save.chars[cls].level)
	var mul = 24.0 if team == "foe" else 1.0   # each of them has to take a real beating: he is Level 200
	_fid += 1
	return {"id": _fid, "cls": cls, "team": team, "look": lookOf(cls), "name": CLASSES[cls].name,
		"x": x0, "y": groundAt(x0), "vx": 0.0, "vy": 0.0, "face": 1, "grounded": true,
		"hp": st.hp * mul, "maxHp": st.hp * mul, "atk": st.atk * (4.5 if team == "foe" else 1.0), "def": st.def, "lv": lv,
		"state": "enter", "enterX": x0 + 60, "t": 0.0, "anim": "run", "animT": 0.0, "mt": 0.0,
		"cd": rand(0.6, 1.6), "skillCd": rand(3.0, 6.0), "mv": null, "hitDone": false, "n": 0, "tick": 0.0,
		"aim": null, "poiseT": 0.0, "frozenT": 0.0, "burnT": 0.0, "burnTick": 0.0, "hurtT": 0.0, "flash": 0.0, "bark": "", "barkT": 0.0, "drop": 0.0}


func _updateFighters(dt: float) -> void:
	for f in fighters:
		_fUpdate(f, dt)
	_updateHShots(dt)


func _fTarget(f):
	if f.team == "foe":
		return Vector2(P.x, P.y) if P.state != "dead" and GM.get("phase", "") == "fight" else null
	var e = _glamrax()
	return Vector2(e.x, e.y) if e != null and e.state == "fight" else null


func _attackers() -> int:
	return fighters.filter(func(q): return q.team == "foe" and q.state == "atk").size()


func _fUpdate(f, dt: float) -> void:
	f.t += dt
	f.animT += dt
	f.cd -= dt
	f.skillCd -= dt
	f.barkT -= dt
	f.flash -= dt
	f.drop -= dt
	if f.burnT > 0 and f.state != "down":
		f.burnT -= dt
		f.burnTick -= dt
		if f.burnTick <= 0:
			f.burnTick = 0.5
			if f.team == "foe":
				f.hp -= maxf(1, roundf(f.maxHp * 0.004))
				if f.hp <= 0:
					_downFighter(f)
		if randf() < dt * 16:
			part(f.x + rand(-6, 6), f.y - rand(4, 36), rand(-10, 10), -rand(20, 60), 0.4, "#ff8a2a" if randf() < 0.6 else "#ffd27a", -30, 1)
	match f.state:
		"down":
			f.vx *= exp(-dt * 4)
			_fAnim(f, "down")
		"enter":
			f.face = 1
			f.vx = 150.0
			_fAnim(f, "run")
			if f.x >= f.enterX:
				f.vx = 0
				f.state = "wait" if f.team == "foe" else "idle"
				_fAnim(f, "idle")
		"wait":
			f.vx = 0
			f.face = int(sgn(P.x - f.x)) if P.x != f.x else f.face
			_fAnim(f, "idle")
		"frozen":
			f.frozenT -= dt
			f.vx = 0
			if f.frozenT <= 0:
				f.state = "idle"
				for k in 8:
					part(f.x + rand(-8, 8), f.y - rand(4, 36), rand(-60, 60), rand(-90, -10), 0.4, "#bff4ff", 300, 1)
		"hurt":
			f.hurtT -= dt
			f.vx *= exp(-dt * 5)
			_fAnim(f, "hurt")
			if f.hurtT <= 0:
				f.state = "idle"
				f.cd = minf(f.cd, 0.4)
		"atk":
			_fMove(f, dt)
		"idle", "run":
			_fThink(f, dt)
	# physics: gravity, platforms, the floor
	f.vy = minf(f.vy + 1100 * dt, 720)
	var prevY: float = f.y
	f.x = clampf(f.x + f.vx * dt, 16, M.w - 16)
	f.y += f.vy * dt
	f.grounded = false
	if f.vy >= 0 and f.drop <= 0:
		for s in surfaces:
			if f.x >= s.x0 and f.x <= s.x1 and s.y >= prevY - 0.5 and s.y <= f.y:
				f.y = s.y
				f.vy = 0
				f.grounded = true
				break
	var g = groundAt(f.x)
	if f.y >= g:
		f.y = g
		f.vy = 0
		f.grounded = true


func _fAnim(f, a: String) -> void:
	if f.anim != a:
		f.anim = a
		f.animT = 0.0


func _fThink(f, dt: float) -> void:
	var tp = _fTarget(f)
	if tp == null:
		f.vx = move_toward(f.vx, 0, 900 * dt)
		_fAnim(f, "idle")
		return
	var Kt: Dictionary = HERO_KIT[f.cls]
	var dx: float = tp.x - f.x
	var adx = absf(dx)
	if adx > 4:
		f.face = int(sgn(dx))
	# keep their favourite distance
	var want = 0.0
	if adx > Kt.band[1]:
		want = sgn(dx)
	elif adx < Kt.band[0]:
		want = -sgn(dx)
		if (f.x < 40 and want < 0) or (f.x > M.w - 40 and want > 0):
			want = 0.0
	f.vx = move_toward(f.vx, want * Kt.spd, 1200 * dt)
	_fAnim(f, "run" if absf(f.vx) > 12 else "idle")
	# climb up to him, or drop down
	if f.grounded:
		if tp.y < f.y - 60 and randf() < dt * 2.2:
			f.vy = -560
			f.grounded = false
			_fAnim(f, "jump")
		elif tp.y > f.y + 40 and f.y < M.floorY - 4 and randf() < dt * 2.0:
			f.drop = 0.3
	# attack
	if f.cd > 0 or not f.grounded:
		return
	if f.team == "foe" and _attackers() >= 4:
		f.cd = 0.25
		return
	var vy = absf(tp.y - f.y)
	var pick = null
	if f.skillCd <= 0 and adx <= Kt.skill.range:
		pick = Kt.skill
	else:
		var opts: Array = Kt.moves.filter(func(m): return adx <= m.range and (m.kind != "melee" or vy < 56))
		if opts.size():
			pick = opts[rint(0, opts.size() - 1)]
	if pick == null:
		return
	f.mv = pick
	f.mt = 0.0
	f.n = 0
	f.tick = 0.0
	f.hitDone = false
	f.state = "atk"
	f.vx = 0
	f.aim = tp
	_fAnim(f, pick.anim)


func _fMove(f, dt: float) -> void:
	var m: Dictionary = f.mv
	if m == null:
		f.state = "idle"
		return
	f.mt += dt
	var tp = _fTarget(f)
	if tp != null and m.kind != "melee":
		f.aim = tp
	var t: float = f.mt
	match m.kind:
		"melee":
			if t < m.hit:
				f.vx = f.face * m.get("lunge", 0.0) * (t / m.hit)
			else:
				f.vx *= exp(-dt * 8)
			if t >= m.hit and not f.hitDone:
				f.hitDone = true
				var w: float = m.reach
				var box = hbox(f.x, f.x + w, f.y - 48, f.y) if f.face > 0 else hbox(f.x - w, f.x, f.y - 48, f.y)
				_fStrike(f, box, m.mul, m.get("kb", 120.0))
				Sfx.swing(m.mul >= 1.8)
		"spin":
			f.vx = f.face * 70
			f.tick -= dt
			if t >= m.hit and t < m.dur - 0.1 and f.tick <= 0:
				f.tick = 0.15
				_fStrike(f, hbox(f.x - m.reach, f.x + m.reach, f.y - 46, f.y), m.mul, 80.0)
				Sfx.swing(false)
		"shot":
			if t >= m.hit and not f.hitDone:
				f.hitDone = true
				_fShoot(f, m)
		"volley":
			if t >= m.hit and f.n < m.n and t >= m.hit + f.n * ((m.dur - m.hit - 0.1) / m.n):
				f.n += 1
				_fShoot(f, m)
		"erupt", "beam":
			if t >= m.hit and not f.hitDone and f.aim != null:
				f.hitDone = true
				var su = _surfUnder(f.aim.x, f.aim.y - 4)
				hShots.append({"kind": m.kind, "x": f.aim.x, "y": su.y if su != null else M.floorY, "t": 0.0, "warn": 0.55 if m.kind == "erupt" else 0.75,
					"team": f.team, "f": f, "mul": m.mul, "hit": false})
				Sfx.tone(500 if m.kind == "erupt" else 1400, 0.4, "sine", 0.04, 900)
		"cone":
			f.tick -= dt
			if t >= m.hit and f.tick <= 0:
				f.tick = 0.2
				var w: float = m.reach
				_fStrike(f, hbox(f.x, f.x + w, f.y - 46, f.y - 4) if f.face > 0 else hbox(f.x - w, f.x, f.y - 46, f.y - 4), m.mul, 60.0)
			if randf() < dt * 50 and t >= m.hit:
				var a = rand(-0.3, 0.3)
				part(f.x + f.face * 14, f.y - 26, f.face * cos(a) * rand(140, 220), sin(a) * 100, 0.4, ["#ff4a1a", "#ffb03a", "#ffe14d"][rint(0, 2)], 0, 2)
	if t >= m.dur:
		f.state = "idle"
		f.mv = null
		if m == HERO_KIT[f.cls].skill:
			f.skillCd = m.cd * (1.0 if f.team == "foe" else 0.8)
		f.cd = rand(0.7, 1.5) if f.team == "foe" else rand(0.35, 0.8)


func _fShoot(f, m: Dictionary) -> void:
	var sx0 = f.x + f.face * 12
	var sy0 = f.y - 26
	var aim: Vector2 = f.aim if f.aim != null else Vector2(f.x + f.face * 100, sy0)
	var to = Vector2(aim.x, aim.y - (34 if f.team == "foe" else 40))
	var v = (to - Vector2(sx0, sy0)).normalized() * m.speed
	if m.proj == "nade":
		var dx = to.x - sx0
		var tt = clampf(absf(dx) / 220.0, 0.5, 1.2)
		v = Vector2(dx / tt, -0.5 * 700 * tt + (to.y - sy0) / tt)
	hShots.append({"kind": m.proj, "x": sx0, "y": sy0, "vx": v.x, "vy": v.y, "t": 0.0, "team": f.team, "f": f, "mul": m.mul})
	match m.proj:
		"arrow": Sfx.tone(900, 0.08, "triangle", 0.04, 500)
		"bullet": Sfx.tone(300, 0.06, "square", 0.05, 120)
		"bolt": Sfx.tone(800, 0.15, "sine", 0.04, 1200)
		"spirit": Sfx.tone(500, 0.3, "sine", 0.04, 800)
		"nade": Sfx.tone(200, 0.15, "triangle", 0.04, 300)


func _fSrc(f) -> Dictionary:
	return {"x": f.x, "lv": f.lv, "boss": false}


func _fStrike(f, box: Dictionary, mul: float, kb: float) -> bool:
	if f.team == "foe":
		if P.state != "dead" and overlap(box, pBox()):
			hurtPlayer(_fSrc(f), f.atk * mul)
			return true
		return false
	var e = _glamrax()
	if e != null and e.state == "fight" and overlap(box, bossBoxKind(e)):
		allyHitBoss(e, f, mul)
		return true
	return false


## an ally's blow on Glamrax (the finale)
func allyHitBoss(e, f, mul: float) -> void:
	var dmg = f.atk * mul * rand(0.9, 1.1) * 100.0 / (100.0 + e.def * 4) * bossDmgMul(e, {})
	if dmg <= 0:
		return
	dmg = maxf(1, roundf(dmg))
	e.hp -= dmg
	e.hurtFlash = 0.07
	floatText(e.x + rand(-10, 10), e.y - 70, str(int(dmg)), "dmg")
	sparks(e.x, e.y - 40, "#ffffff", 4)


func _updateHShots(dt: float) -> void:
	for i in range(hShots.size() - 1, -1, -1):
		var s: Dictionary = hShots[i]
		s.t += dt
		var gone = false
		match s.kind:
			"arrow", "bullet", "bolt", "spirit", "nade":
				if s.kind == "nade":
					s.vy += 700 * dt
				elif s.kind == "spirit":
					var tp = _fTarget(s.f)
					if tp != null:
						var to = (Vector2(tp.x, tp.y - 30) - Vector2(s.x, s.y)).normalized() * 210
						var v = Vector2(s.vx, s.vy).lerp(to, minf(1, dt * 2.5))
						s.vx = v.x; s.vy = v.y
				s.x += s.vx * dt
				s.y += s.vy * dt
				var r = 6.0 if s.kind != "nade" else 4.0
				if _shotHits(s, hbox(s.x - r, s.x + r, s.y - r, s.y + r)):
					gone = true
					if s.kind == "nade":
						_heroBoom(s)
				elif s.x < -20 or s.x > M.w + 20 or s.t > 3.0 or s.y >= groundAt(s.x):
					gone = true
					if s.kind == "nade":
						_heroBoom(s)
			"erupt", "beam":
				if s.t >= s.warn and not s.hit:
					s.hit = true
					var w = 22.0 if s.kind == "erupt" else 10.0
					_shotHits(s, hbox(s.x - w, s.x + w, s.y - (60 if s.kind == "erupt" else 400), s.y))
					shake = maxf(shake, 4)
					if s.kind == "erupt":
						Sfx.burst(0.5, "lowpass", 1600, 200, 0.3)
					else:
						Sfx.tone(1600, 0.3, "square", 0.05, 600)
				gone = s.t > s.warn + 0.4
			"boom":
				gone = s.t > 0.4
		if gone:
			hShots.remove_at(i)


func _shotHits(s: Dictionary, box: Dictionary) -> bool:
	var f = s.f
	if s.team == "foe":
		if P.state != "dead" and overlap(box, pBox()):
			hurtPlayer(_fSrc(f), f.atk * s.mul)
			return true
		return false
	var e = _glamrax()
	if e != null and e.state == "fight" and overlap(box, bossBoxKind(e)):
		allyHitBoss(e, f, s.mul)
		return true
	return false


func _heroBoom(s: Dictionary) -> void:
	hShots.append({"kind": "boom", "x": s.x, "y": s.y, "t": 0.0, "team": s.team, "f": s.f, "mul": 0.0})
	_shotHits(s, hbox(s.x - 30, s.x + 30, s.y - 40, s.y + 10))
	shake = maxf(shake, 5)
	Sfx.burst(0.5, "lowpass", 900, 120, 0.35)
	for k in 12:
		var a = randf() * TAU
		part(s.x, s.y - 4, cos(a) * rand(40, 140), sin(a) * rand(40, 140) - 50, rand(0.3, 0.5), ["#ff8a2a", "#ffd27a", "#5a5058"][rint(0, 2)], 200, 2)


func frontBusy() -> bool:
	return super.frontBusy() or not fighters.is_empty() or not hShots.is_empty()
