extends "res://scripts/showdown.gd"
## Sproutvale, the finale. Glamrax has beaten all five heroes and drunk their strength. He laughs while
## they hang in his crystals, and meteors fall on their homes. One crystal still answers: you choose
## which hero breaks out. They land bloody and bruised in front of a Glamrax twice as strong as before,
## and every 15% of his health you take away frees another hero to fight beside you. Then Rock's sword,
## Tank's pistol, and a neighborhood where everyone lives happily ever after.
##
## The cutscenes and the crystal choice are drawn in finale_draw.gd.

const FIN_ALLY_AT := [0.85, 0.70, 0.55, 0.40]   # his health when the next hero breaks free
const FIN_HOME := {"rock": "the cottage", "archer": "the treehouse", "mage": "the house under the hill",
	"summoner": "the house by the trees", "tank": "the workshop"}
const FIN_IMPACT := {
	"rock": "The cottage where Rock raised a son is gone in a flash of fire.",
	"archer": "The great tree burns from the roots up. The treehouse falls with it.",
	"mage": "The hill caves in on the round green door. Nothing is left but smoke.",
	"summoner": "The glass and the timber go up together. Jojo's home is a crater.",
	"tank": "The workshop, the tools, the half-built drones: all of it, gone.",
}
const ALLY_BARK := {"rock": "I've got your back!", "archer": "Together, then.", "mage": "Took you long enough.",
	"summoner": "My turn! Get him!", "tank": "Reboot complete. Target: Glamrax."}

var FIN := {}             # the last fight: {on, cls, stage, t, freed, deadT}
var heroAfter := ""       # the hero the select screen lands on once it's all over
var ptr := Vector2(-999, -999)   # the mouse, in story-screen pixels (game.gd keeps it up to date)


# ================================================================ after the showdown: the cutscene

func startShowdown() -> void:
	# he already won the showdown: what's left is the heroes' turn
	if save.get("showdownWon", false) and capturedAll() and not introBusy():
		startFinale()
		return
	super.startShowdown()


func _showdownWon() -> void:
	if save.get("finaleDone", false):
		# a rematch for old times' sake: the heroes are free now, and nobody gets sealed
		save.showdownWon = true
		saveDirty = true
		_gmEnd()
		toCharSelect()
		later(0.6, func(): toast("Glamrax holds the sanctum. Just like old times."))
		return
	super._showdownWon()


func startFinale() -> void:
	_gmEnd()
	FIN = {}
	inGame = false
	menuOpen = false
	P.frozen = false
	var scenes: Array = [
		{"kind": "f_lair", "title": false, "text": "Glamrax laughs. Five heroes hang in his crystals now, wired into the machine, and every one of them is still fighting it."},
	]
	for h in GX_PODS:
		scenes.append({"kind": "f_sky_" + h, "title": false, "text": "Far away, the sky over %s splits open." % FIN_HOME[h]})
		scenes.append({"kind": "f_hit_" + h, "title": false, "text": FIN_IMPACT[h]})
	scenes.append({"kind": "f_absorb", "title": false, "text": "The machine roars. Their strength pours out of the crystals and into Glamrax, until his eyes burn white."})
	scenes.append({"kind": "f_choose", "title": false, "text": "But one of the crystals is cracking. Somebody in there isn't finished. Choose your character."})
	glamraxCutscene(pickedClass(), scenes, func(): startFinalFight(intro_choice()))
	Sfx.music("piano")


## the hero picked on the crystal screen (finale_draw.gd keeps it)
func intro_choice() -> String:
	return FIN.get("pick", "rock")


# ================================================================ the last fight

func startFinalFight(cls: String) -> void:
	if not GX_PODS.has(cls):
		cls = "rock"
	setClass(cls)
	buildQuickslots()
	FIN = {"on": true, "cls": cls, "stage": "fall", "t": 0.0, "freed": [], "deadT": 0.0, "pick": cls}
	inGame = true
	menuOpen = false
	PS = calcStats()
	P.hp = roundf(PS.hp * 0.55)   # bloody and bruised
	P.en = PS.enMax
	P.state = "move"
	P.held = null
	P.frozen = false
	P.iframes = 1.0
	fighters.clear()
	hShots.clear()
	var pod = _podXY(GX_PODS.find(cls))
	loadMap("volcano4", pod.x, null)
	P.x = pod.x
	P.y = pod.y + 20
	P.vx = 0
	P.vy = -60
	P.grounded = false
	P.face = 1
	for k in 26:
		var a = randf() * TAU
		part(pod.x + cos(a) * 10, pod.y + sin(a) * 18, cos(a) * rand(60, 200), sin(a) * rand(60, 200) - 60, rand(0.5, 1.1), ["#e8d0ff", "#bff4ff", "#c88aff"][rint(0, 2)], 400, 2)
	Sfx.burst(0.6, "highpass", 2400, 900, 0.3)
	shake = 6


func loadMap(id: String, px0 = null, py0 = null) -> void:
	if FIN.get("on", false) and id != "volcano4":
		# walked out on the last fight: back to the select screen, and it's waiting for you
		FIN = {}
		fighters.clear()
		super.loadMap(id, px0, py0)
		toCharSelect.call_deferred()
		return
	super.loadMap(id, px0, py0)
	if FIN.get("on", false) and id == "volcano4":
		M.pedestal = null
		for e in slimes:
			if e.bossKind == "glamrax":
				e.state = "dead"
		slimes = slimes.filter(func(e): return e.bossKind != "glamrax")
		_spawnFinalGlamrax()


func spawnGlamrax() -> void:
	super.spawnGlamrax()
	if save.get("finaleDone", false) and not FIN.get("on", false) and GX.get("full", false):
		# the crystals are empty now: no loved one to zoom in on, just the short meeting
		GX.full = false
		GX.beat = "short"
		GX.camX = 330.0


## Glamrax, full of their strength: twice the health, harder spells, and no piano this time
func _spawnFinalGlamrax() -> void:
	spawnGlamrax()
	var e = _glamrax()
	GX = {}
	camZoom = 1.0
	P.frozen = false
	e.maxHp = GLAMRAX_T.hp * 2.0
	e.hp = e.maxHp
	e.atk = e.atk * 1.6
	e.state = "finwait"
	e.x = 600.0
	e.face = -1
	e.data.anim = "float"
	e.data.hover = 96.0
	e.y = M.floorY - 96.0
	e.data.amped = true
	Sfx.music_stop(true)
	later(0.5, func(): if FIN.get("on", false): Sfx.music("finale"))


func updateBossKind(e, dt: float) -> bool:
	if e.bossKind != "glamrax" or not FIN.get("on", false):
		return super.updateBossKind(e, dt)
	FIN.t += dt
	if e.state == "finwait":
		e.hurtFlash -= dt
		e.showBar = 99
		e.data.anim = "float"
		e.y = M.floorY - 96.0 + sin(gameTime * 1.6) * 4
		e.face = int(sgn(P.x - e.x)) if P.x != e.x else -1
		if FIN.stage == "fall" and P.grounded:
			FIN.stage = "talk"
			dust(P.x, P.y, 14)
			Sfx.slam()
			shake = 5
			later(0.7, func(): _finalWords())
		_updateFighters(dt)
		return true
	super.updateBossKind(e, dt)
	if e.state == "fight":
		var hpK: float = e.hp / e.maxHp
		var n: int = FIN.freed.size()
		if n < FIN_ALLY_AT.size() and hpK <= FIN_ALLY_AT[n]:
			_freeAlly()
	_updateFighters(dt)
	return true


func _finalWords() -> void:
	if not FIN.get("on", false) or FIN.stage != "talk":
		return
	var me: String = CLASSES[classId].name
	var lines = [
		{"who": "Glamrax", "text": "Still standing? I took everything you had. It's in here now."},
		{"who": me, "text": FINAL_WORDS.get(classId, "Then I'll take it back.")},
		{"who": "Glamrax", "text": "Then come and take it."},
	]
	startScene(lines, func():
		FIN.stage = "fight"
		var e = _glamrax()
		if e != null:
			e.state = "fight"
			e.t = 0.0
			e.data.cd = 1.0
		banner("GLAMRAX, UNBOUND", "Break the crystals: every blow you land loosens them")
		Sfx.thunder())


const FINAL_WORDS := {
	"rock": "Then I'll take it back. All of it. For all of them.",
	"archer": "I don't like hurting anyone. You're making it easy.",
	"mage": "You should have kept me in that crystal. I'm in a mood.",
	"summoner": "You smashed my house, wizard. Big mistake.",
	"tank": "Good. More of you to take apart.",
}


## the next crystal gives way, and its hero joins you
func _freeAlly() -> void:
	var left: Array = GX_PODS.filter(func(h): return h != FIN.cls and not FIN.freed.has(h))
	if left.is_empty():
		return
	var h: String = left[0]
	FIN.freed.append(h)
	var pod = _podXY(GX_PODS.find(h))
	var f = _newFighter(h, "ally", pod.x)
	f.y = pod.y + 20
	f.vy = -80
	f.grounded = false
	f.state = "idle"
	f.atk *= 3.0
	f.bark = ALLY_BARK[h]
	f.barkT = 3.0
	fighters.append(f)
	for k in 30:
		var a = randf() * TAU
		part(pod.x + cos(a) * 10, pod.y + sin(a) * 18, cos(a) * rand(60, 220), sin(a) * rand(60, 220) - 60, rand(0.5, 1.1), ["#e8d0ff", "#bff4ff", "#c88aff"][rint(0, 2)], 400, 2)
	Sfx.burst(0.6, "highpass", 2400, 900, 0.3)
	Sfx.tone(520, 0.6, "sine", 0.06, 1040)
	shake = 6
	banner("%s BREAKS FREE" % CLASSES[h].name.to_upper(), "")


func _fThink(f, dt: float) -> void:
	super._fThink(f, dt)
	# allies jump at him to land their blows: he floats out of reach
	if f.team == "ally" and f.state == "atk" and f.grounded and f.mv != null and f.mv.kind in ["melee", "spin"]:
		var tp = _fTarget(f)
		if tp != null and tp.y < f.y - 40:
			f.vy = -500
			f.grounded = false


func _fStrike(f, box: Dictionary, mul: float, kb: float) -> bool:
	if f.team == "ally":
		box.y0 -= 30   # a jumping blow reaches up
	return super._fStrike(f, box, mul, kb)


# ---------------- falling, and getting back up

func killPlayer() -> void:
	if not FIN.get("on", false):
		super.killPlayer()
		return
	P.hp = 0
	P.state = "dead"
	P.vx = 0
	P.deadT = 0.0
	setAnim("down")
	FIN.deadT = 0.0
	banner("Not like this...", "The others won't let you stay down. Again!")


func updatePlayer(dt: float) -> void:
	if FIN.get("on", false) and P.state == "dead":
		FIN.deadT += dt
		P.vx = 0
		if FIN.deadT > 3.5 and not FIN.get("again", false):
			FIN.again = true
			startFinalFight(FIN.cls)
		return
	super.updatePlayer(dt)


# ---------------- the end, for real this time

func _startFakeEnd(e) -> void:
	if save.get("finaleDone", false) and not FIN.get("on", false):
		_realKill(e)
		return
	super._startFakeEnd(e)


## after the finale: he falls like any other boss (boxes, EXP, the pedestal)
func _realKill(e) -> void:
	if e.state == "dead":
		return
	gSpells.clear()
	_gxClearOrbs()
	for q in slimes:
		if q.type == "gdemon" and q.state != "dead":
			q.state = "dead"
	e.state = "dead"
	e.deadT = 0
	e.hp = 0
	shake = 12
	slowmo = 1.0
	var total = rint(int(GLAMRAX_T.coins[0]), int(GLAMRAX_T.coins[1]))
	for k in 12:
		_drop("coin", e, rand(-90, 90), rand(-280, -160), maxi(1, total / 12))
	var gained = roundi(mobExp(e))
	gainExp(gained)
	floatText(e.x, e.y - e.h - 16, "+%d EXP" % gained, "exp")
	var c = CH()
	if not c.has("bossKills"):
		c.bossKills = {}
	c.bossKills.glamrax = int(c.bossKills.get("glamrax", 0)) + 1
	banner("GLAMRAX DEFEATED", "Again. He'll be back on the pedestal.")
	Sfx.music("trophy")


func _endingScreens() -> void:
	if not FIN.get("on", false):
		super._endingScreens()
		return
	var me: String = classId
	FIN.stage = "end"
	fighters.clear()
	hShots.clear()
	var scenes = [
		{"kind": "f_stab", "title": false, "text": "Glamrax gets up one last time. He doesn't get far: Rock's sword goes through his chest."},
		{"kind": "f_shot", "title": false, "text": "Tank walks up, puts the pistol to Glamrax's head, and says nothing at all. One shot."},
		{"kind": "f_free", "title": false, "text": "The crystals crack all at once. A son, a little sister, a grandmother, a little brother and a mother fall into the arms of the people who came for them."},
		{"kind": "f_build", "title": false, "text": "Their homes are gone. So they build new ones, together, side by side, at the foot of the mountain."},
		{"kind": "f_happy", "title": false, "text": "And in the neighborhood they made, all of them lived happily ever after."},
		{"kind": "f_end", "title": true, "text": "THE END"},
	]
	glamraxCutscene(me, scenes, func(): _finishGame())
	Sfx.music("finale")


func _finishGame() -> void:
	var cls: String = FIN.get("cls", classId)
	FIN = {}
	fighters.clear()
	hShots.clear()
	gSpells.clear()
	GX = {}
	camZoom = 1.0
	save.captured = {}
	save.finaleDone = true
	if not (save.get("trophies") is Dictionary):
		save.trophies = {}
	save.trophies.glamrax = true
	for h in GX_PODS:
		if not save.chars.has(h):
			continue
		var c: Dictionary = save.chars[h]
		if not c.has("bossKills"):
			c.bossKills = {}
		c.bossKills.glamrax = maxi(1, int(c.bossKills.get("glamrax", 0)))
		c.erase("pos")   # everybody starts again at home
	heroAfter = cls
	P.frozen = false
	saveDirty = true
	persist()
	toCharSelect()
	later(0.8, func(): toast("Thank you for playing Sproutvale!"))


# ================================================================ the trophy

func initVolcanoData() -> void:
	super.initVolcanoData()
	TROPHIES[5] = {"id": "glamrax", "name": "Glamrax Trophy"}
