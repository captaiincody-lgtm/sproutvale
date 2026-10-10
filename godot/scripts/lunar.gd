extends "res://scripts/finale.gd"
## Sproutvale, after the end. Lunar monsters (one spawn in a thousand: twenty times as strong, a hundred
## times the EXP and coins, and a few cyan Luna Coins), the Lunar Shop's meter that the coins are given to,
## and what answers once it's full: a voice in the dark, a night that never ends, a blood-red moon that
## won't move, a rocket, and the first steps on the Moon.
##
## Also the neighborhood the heroes built after the ending: the home map holds all five houses side by
## side, every hero can be visited at home, and their loved ones play outside.
##
## Drawn in lunar_draw.gd; the Lunar Shop's page is in lunar_ui.gd; the art is painted by
## tools/bake/lunar_art.py.

const LUNAR_RATE := 0.001     # one monster in a thousand spawns Lunar
const LUNAR_POWER := 20.0     # its health and attack
const LUNAR_REWARD := 100.0   # its EXP and coins
const LUNA_DROP := [15, 30]   # Luna Coins it drops
const LUNAR_GOAL := 1000      # Luna Coins that fill the Lunar Meter

## the neighborhood: where each hero's house stands (its middle), and the rocket (tools/bake/lunar_art.py
## paints the houses at the same places)
const VILLAGE := {"rock": 300.0, "archer": 650.0, "mage": 1030.0, "summoner": 1410.0, "tank": 1750.0}
const VILLAGE_ORDER := ["rock", "archer", "mage", "summoner", "tank"]
const VILLAGE_W := 2340
const ROCKET_X := 2090.0
const MOON_ROCKET_X := 150.0
const MOON_GRAV := 0.36      # the Moon's pull, against the world's
const HOUSE_NAME := {"rock": "the cottage", "archer": "the treehouse", "mage": "the burrow", "summoner": "the glass house", "tank": "the workshop"}
const KIN_NAME := {"rock": "%s's son", "archer": "Ari", "mage": "%s's grandmother", "summoner": "%s's little brother", "tank": "%s's mother"}

var visitHouse := ""          # whose house the "house" map is showing ("" = your own)
var lunarRateOverride := -1.0 # tests
var talkIdx := {}             # who → which of their lines comes next
var moonDust: Array = []      # slow, drifting dust kicked up on the Moon


# ================================================================ data

func initVolcanoData() -> void:
	super.initVolcanoData()
	MAPS.moon1 = {"name": "The Moon", "sub": "The landing site · low gravity", "theme": "moon", "w": 1400, "h": 440, "floorY": 400,
		"target": 0, "safe": true, "music": "moon", "start": 230, "spawn": {}, "ropes": [], "portals": [],
		"plats": [[520, 330, 70], [700, 290, 90], [900, 320, 60], [1060, 266, 80], [1240, 320, 70]],
		"notes": [{"x": 1356, "y": 400, "label": "Look into the crater",
			"text": "Past the ridge the ground drops into a crater too dark to see across. Something down there is waiting. Not yet."}]}
	CUR_TIPS.luna = "Luna Coins: cold, faintly glowing coins dropped by Lunar monsters (one in a thousand spawns). The Lunar Shop takes them."


func LU() -> Dictionary:
	if not (save.get("lunar") is Dictionary):
		save.lunar = {}
	var L: Dictionary = save.lunar
	for k in ["meter", "kills"]:
		if not L.has(k):
			L[k] = 0
	for k in ["rite", "night", "talked", "moon"]:
		if not L.has(k) or not (L[k] is bool):
			L[k] = L.get(k, false) == true
	return L


func lunaCoins() -> int:
	return int(save.get("lunaCoins", 0))


func finaleBeaten() -> bool:
	return save.get("finaleDone", false) == true


## the blood moon is up: night everywhere, and the rocket waits
func lunarNight() -> bool:
	return finaleBeaten() and LU().night


func isVillage() -> bool:
	return mapId == "home" and M.get("variant") == "village"


# ================================================================ Lunar monsters

func lunarRate() -> float:
	return lunarRateOverride if lunarRateOverride >= 0 else LUNAR_RATE


func isLunar(e) -> bool:
	return e != null and not e.boss and e.data.get("lunar", false) == true


func spawnSlime(initial := false) -> void:
	var n0 = slimes.size()
	super.spawnSlime(initial)
	for i in range(n0, slimes.size()):
		var e = slimes[i]
		if e.boss or e.bossPart or e.elite or e.shiny or e.raid or isLunar(e):
			continue
		if randf() < lunarRate():
			makeLunar(e)


func makeLunar(e) -> void:
	e.data = e.data.duplicate()   # (a pair of Travelers share one; only this one turns)
	e.data.lunar = true
	e.maxHp *= LUNAR_POWER
	e.hp = e.maxHp
	e.atk *= LUNAR_POWER
	e.exp *= LUNAR_REWARD
	e.coinMul *= LUNAR_REWARD
	toast("🌙 A Lunar %s has appeared!" % e.T.name)
	Sfx.tone(1320, 0.9, "sine", 0.05, 1760)
	Sfx.tone(660, 1.4, "triangle", 0.04, 990, 0.15)


func killSlime(e) -> void:
	var lunar = isLunar(e) and e.state != "dead"
	super.killSlime(e)
	if lunar:
		_lunarFalls(e)


func _lunarFalls(e) -> void:
	var total = rint(LUNA_DROP[0], LUNA_DROP[1])
	var pieces = clampi(ceili(total / 5.0), 3, 6)
	for k in pieces:
		var v = total if k == pieces - 1 else maxi(1, floori(float(total) / (pieces - k)))
		total -= v
		_drop("part", e, rand(-80, 80), rand(-300, -180), v, "luna")
	var L = LU()
	L.kills = int(L.kills) + 1
	cheer()
	banner("LUNAR %s DEFEATED!" % e.T.name.to_upper(), "100× EXP and coins · Luna Coins")
	shake = maxf(shake, 6)
	for k in 30:
		part(e.x, e.y - 10, rand(-140, 140), rand(-240, -60), rand(0.6, 1.2), ["#bff8ff", "#7fe6ff", "#ffffff"][k % 3], 260, 2)
	Sfx.tone(880, 0.8, "sine", 0.06, 1320)


## Luna Coins come down as "part" drops (the same pickup path as Tank's components)
func tankPickup(d) -> void:
	if d.type != "luna":
		super.tankPickup(d)
		return
	save.lunaCoins = lunaCoins() + d.val
	Sfx.tone(1200, 0.25, "sine", 0.07, 1800)
	pickupPop("luna", "Luna Coins", d.val, "#7ff4ff")


# ================================================================ the Lunar Shop: the meter

func lunarCard(_x: float, _y: float, _w: float) -> float: return 0.0   # lunar_ui.gd


func donateLuna(n: int) -> void:
	var L = LU()
	var k = mini(mini(n, lunaCoins()), LUNAR_GOAL - int(L.meter))
	if k <= 0:
		return
	save.lunaCoins = lunaCoins() - k
	L.meter = int(L.meter) + k
	saveDirty = true
	Sfx.tone(520 + float(L.meter) / LUNAR_GOAL * 900, 0.5, "sine", 0.06, 1400)
	if int(L.meter) >= LUNAR_GOAL:
		Sfx.tone(110, 2.5, "sine", 0.08, 55)
		toggleMenu(false)
		later(0.6, func(): startLunarRite())


## the meter is full: the game goes dark, and somebody is there
func startLunarRite() -> void:
	if introBusy():
		return
	P.frozen = true
	P.vx = 0
	P.iframes = 1e6
	Sfx.music_stop()
	glamraxCutscene(classId, [{"kind": "l_dark", "title": false, "text": "..."}], func(): _riteDone())


func _riteDone() -> void:
	var L = LU()
	L.rite = true
	P.iframes = 1.0
	P.frozen = false
	saveDirty = true
	if not finaleBeaten():
		Sfx.music(M.get("music", mapId))
		toast("You must beat the game to continue the hidden quest line.")
		persist()
		return
	L.night = true
	visitHouse = ""
	loadMap("house")
	P.face = 1
	persist()
	later(0.9, func():
		if mapId == "house" and scene == null:
			startScene([{"who": CLASSES[classId].name, "text": "...Huh? It was the middle of the day a second ago. Why is it so dark out?"}]))


# ================================================================ the night that never ends

func updateWorld(dt: float) -> void:
	super.updateWorld(dt)
	if lunarNight() or mapId == "moon1":
		World.t = 0.0   # midnight, frozen
		World.cloud = minf(World.cloud, 0.05)
		World.rain = 0.0
		World.snow = 0.0
		World.storm = 0.0
		World.snowCover = 0.0
		World.bolt = null


# ================================================================ the neighborhood

## the door of each house in the neighborhood {x, y}
func villageDoor(h: String) -> Dictionary:
	var cx: float = VILLAGE.get(h, 300.0)
	if h == "archer":
		return {"x": cx + 16, "y": 182.0}
	return {"x": cx}


func configureHome(cls: String) -> void:
	super.configureHome(cls)
	if not finaleBeaten():
		return
	_buildVillage(cls)
	var owner = visitHouse if VILLAGE.has(visitHouse) else cls
	if owner != cls:
		MAPS.house.merge(HOME_VARIANTS[owner].house.duplicate(true), true)
		MAPS.house.slots = []                          # their furniture isn't yours to arrange
		MAPS.house.portals = [MAPS.house.portals[0]]   # …and the Trophy Hall through the back is yours
		MAPS.house.name = HOME_VARIANTS[owner].house.name if owner != "tank" else "Tank's Workshop"
		MAPS.house.sub = "%s's home" % CLASSES[owner].name
	var D = villageDoor(owner)
	var out: Dictionary = MAPS.house.portals[0]
	out.tx = D.x
	if D.has("y"):
		out.ty = D.y
	else:
		out.erase("ty")
	var notes = []
	for n in MAPS.house.get("notes", []):
		var q: Dictionary = n.duplicate()
		q.text = POSTGAME_NOTE.get(owner, q.text) % CLASSES[owner].name if POSTGAME_NOTE.has(owner) else q.text
		notes.append(q)
	MAPS.house.notes = notes


const POSTGAME_NOTE := {
	"rock": "A new drawing from %s's son: everybody standing in front of their houses. The biggest sword is labeled DAD.",
	"archer": "Ari drew this one. All five houses, all of them smiling. %s is the one with the bow, twice as tall as everyone else.",
	"tank": "The frame isn't empty anymore. A crayon drawing of %s and a mother, holding hands. One of them is a robot.",
}


func _buildVillage(cls: String) -> void:
	var Hm: Dictionary = MAPS.home
	var dx: float = VILLAGE.archer - 470.0
	Hm.merge({"variant": "village", "w": VILLAGE_W, "house": null, "tree": null, "hill": null, "modern": null, "box": null,
		"name": "Home", "sub": "The neighborhood you built together",
		"plats": [[426 + dx, 182, 92]], "ropes": [[440 + dx, 182, 260]]}, true)
	var portals = [{"x": VILLAGE_W - 36, "to": "meadow", "tx": 70, "label": "Sproutvale Meadow"}]
	for h in VILLAGE_ORDER:
		var D = villageDoor(h)
		var p = {"x": D.x, "to": "house", "who": h, "tx": 60 if h in ["rock", "archer", "tank"] else 70, "door": true,
			"label": ("Go inside" if h != "archer" else "Enter the treehouse") if h == cls else "Visit %s" % HOUSE_NAME[h].replace("the ", "%s's " % CLASSES[h].name)}
		if D.has("y"):
			p.y = D.y
		portals.append(p)
	Hm.portals = portals
	Hm.start = villageDoor(cls).x if cls != "archer" else VILLAGE.archer - 40
	for p in MAPS.meadow.portals:
		if p.to == "home":
			p.tx = VILLAGE_W - 70


func travel(portal: Dictionary) -> void:
	if portal.get("to") == "house":
		visitHouse = portal.get("who", "")
	super.travel(portal)


func travelHome() -> void:
	visitHouse = ""
	super.travelHome()


func mapArt() -> String:
	if mapId == "house" and lunarNight():
		var night = "maps/house_%s_night.png" % M.get("variant", "rock")
		if ResourceLoader.exists("res://art/" + night):
			return night
	return super.mapArt()


func loadMap(id: String, px0 = null, py0 = null) -> void:
	if id != "house" and id != "trophy":
		visitHouse = ""
	super.loadMap(id, px0, py0)
	moonDust.clear()
	if id == "moon1":
		tufts.clear()
	if lunarNight() and id in ["home", "house", "trophy"]:
		Sfx.music("lunar")


# ================================================================ people to talk to

## everyone standing around on this map: {key, cls, kin (a loved one, not the hero), x, y, face, bubble}
func npcsHere() -> Array:
	var out = []
	if not finaleBeaten() or FIN.get("on", false):
		return out
	var night = lunarNight()
	var L = LU()
	if isVillage():
		if not night:
			for h in VILLAGE_ORDER:   # the loved ones play outside in the daytime
				out.append({"key": "kin_" + h, "cls": h, "kin": true, "x": VILLAGE[h] + (52.0 if h != "mage" else 96.0), "y": float(M.floorY), "face": -1})
		elif not L.moon:
			var spots = [-118.0, -86.0, 92.0, 124.0]
			var i = 0
			for h in VILLAGE_ORDER:
				if h == classId:
					continue
				var x0 = ROCKET_X + spots[i]
				out.append({"key": "hero_" + h, "cls": h, "kin": false, "x": x0, "y": float(M.floorY), "face": 1 if x0 < ROCKET_X else -1})
				i += 1
	elif mapId == "house":
		var owner = visitHouse if VILLAGE.has(visitHouse) else classId
		var fy = float(M.floorY)
		if not night and owner != classId:
			out.append({"key": "hero_" + owner, "cls": owner, "kin": false, "x": 186.0, "y": fy, "face": -1})
		out.append({"key": "kin_" + owner, "cls": owner, "kin": true, "x": 150.0 if owner != classId or night else 170.0, "y": fy, "face": 1})
	elif mapId == "moon1":
		var spots = [268.0, 332.0, 430.0, 470.0]
		var i = 0
		for h in VILLAGE_ORDER:
			if h == classId:
				continue
			out.append({"key": "hero_" + h, "cls": h, "kin": false, "x": spots[i], "y": float(M.floorY), "face": -1 if i % 2 else 1, "bubble": true})
			i += 1
	return out


func npcAt():
	for n in npcsHere():
		if absf(P.x - n.x) < 16 and absf(P.y - n.y) < 6:
			return n
	return null


func npcName(n: Dictionary) -> String:
	if n.kin:
		var f: String = KIN_NAME[n.cls]
		return f % CLASSES[n.cls].name if f.contains("%s") else f
	return CLASSES[n.cls].name


func talkTo(n: Dictionary) -> void:
	var sets: Array = _npcSets(n)
	if sets.is_empty():
		return
	var i = int(talkIdx.get(n.key, 0))
	talkIdx[n.key] = i + 1
	var lines = []
	for t in sets[i % sets.size()]:
		lines.append({"who": npcName(n), "text": t})
	startScene(lines)


## what they say: a list of conversations, each a list of lines (they take turns)
func _npcSets(n: Dictionary) -> Array:
	var h: String = n.cls
	var me: String = CLASSES[classId].name
	if mapId == "moon1":
		return [[MOON_LINES[h]], [MOON_LINES2[h]]]
	if n.kin:
		if lunarNight():
			return [[KIN_NIGHT[h]]]
		return KIN_LINES[h].map(func(t): return [t.replace("{me}", me)])
	if lunarNight():
		return [[ROCKET_LINES[h]]]
	return HOME_LINES[h].map(func(t): return [t.replace("{me}", me)])


const HOME_LINES := {
	"rock": ["Morning! My boy wants to be a swordsman now. I told him it starts with chores.",
		"Glamrax's pedestal is still up in that volcano. Some days I go and knock him down again, just to be sure.",
		"You ever think about how close it was? I do. Then I go and hug my kid."],
	"archer": ["Ari keeps leaving flowers on my doorstep. I think she's practicing her aim with them.",
		"It's quiet here. I like quiet. I didn't think I'd ever get to have it again.",
		"If you're heading out to hunt, take the long way through the meadow. The slimes there missed you."],
	"mage": ["Grandmother rearranged my entire burrow. I can't find anything. I've never been happier. Don't tell her.",
		"Yes, {me}, I'm fine. No, I don't want to talk about my feelings. ...Thank you for asking, though.",
		"I've started writing a book about everything that happened. Mostly about how I was right."],
	"summoner": ["My little brother says I'm his hero. I told him that's literally my job now!",
		"The dragon keeps trying to sleep on my roof. The roof is NOT dragon-rated.",
		"{me}! Wanna go fight Glamrax again? For fun? ...Okay, maybe later."],
	"tank": ["Mother insists I recharge eight hours a night. I have not disobeyed. Yet.",
		"I upgraded every house in the neighborhood while everyone slept. You are welcome.",
		"Status: content. This is a new reading. I am logging it."],
}
const KIN_LINES := {
	"rock": ["Dad says when I'm bigger he'll teach me the spinny sword thing!", "Are you one of Dad's friends? You look strong. Not as strong as Dad, though."],
	"archer": ["I'm gonna be an archer too. I already hit a tree. On purpose!", "{me}! Did you know my big sibling saved the whole world? Twice!"],
	"mage": ["Remy was always the clever one. Grumpy, but clever. Would you like a biscuit, dear?", "Do come by for tea. Remy pretends not to like visitors, but sets out extra cups."],
	"summoner": ["Jojo's dragon let me ride it! Don't tell anyone. It's a secret!", "When I grow up I'm gonna summon a dragon that summons dragons."],
	"tank": ["Tank fixes everything in this house. Even the things that weren't broken.", "I don't quite understand how I have a child made of metal. But I'm very proud of them."],
}
const KIN_NIGHT := {
	"rock": "Dad went outside a while ago... why won't the moon go down?",
	"archer": "The moon's all red. I don't like it. Everyone went to the field past the houses.",
	"mage": "Remy said to stay inside and keep the kettle warm. So that's what I'm doing, dear.",
	"summoner": "Jojo said there's a ROCKET outside! I'm not allowed to go. It's not fair!",
	"tank": "My child built something enormous out there tonight. I've asked them to be home by morning. If morning ever comes.",
}
## at the rocket, under the blood moon
const ROCKET_LINES := {
	"rock": "The moon's been red for hours, and it hasn't moved an inch. Whatever's up there, it's calling us. I'm not letting it near the kids.",
	"archer": "It's beautiful... and wrong. The birds have all gone quiet. Something up there is hurting.",
	"mage": "A frozen blood moon and a rocket in our front yard. I'd ask who built it, but I already know, and I'd rather not hear the explanation.",
	"summoner": "A ROCKET! An actual rocket! Dibs on the window seat! ...Okay, the moon is a little creepy.",
	"tank": "Lunar orbit has stopped. That is not possible. So I built a rocket. It took four hours. Do not ask where the parts came from.",
}
const ROCKET_ME := {
	"rock": "Then we go up there, and we bring the morning back.",
	"archer": "Whatever it is, we face it together. Like always.",
	"mage": "Fine. But I'm sitting by the window.",
	"summoner": "Moon trip! Moon trip! ...I mean. Let's go save everyone. Again.",
	"tank": "Boarding. Nobody touch the red button.",
}
const MOON_LINES := {
	"rock": "Keep your bubble on. I mean it. Nobody takes theirs off.",
	"archer": "It's so quiet up here. I can hear my own heartbeat in this bubble.",
	"mage": "No air, no trees, no tea. I hate it here already.",
	"summoner": "Look how high I can jump! WHOOOA... okay, I'm still going up.",
	"tank": "Gravity at thirty-six percent. Bubbles holding. The signal is coming from the crater, further in.",
}
const MOON_LINES2 := {
	"rock": "Somebody's been up here. Look at the ground. Footprints that aren't ours.",
	"archer": "Sproutvale looks so small from here. All of it. Everyone we love is on that little green dot.",
	"mage": "That voice in the dark. It was waiting for us to fill that meter. I don't like being expected.",
	"summoner": "If there's a moon monster, can I keep it? I'll feed it and everything.",
	"tank": "The rocket has enough fuel to go home. Press up at the hatch. I recommend we do not go home yet.",
}


## under the blood moon, the heroes say their piece when you reach the rocket (only once)
func _rocketTalk() -> void:
	var L = LU()
	L.talked = true
	saveDirty = true
	var lines = []
	for h in VILLAGE_ORDER:
		if h != classId:
			lines.append({"who": CLASSES[h].name, "text": ROCKET_LINES[h]})
	lines.append({"who": CLASSES[classId].name, "text": ROCKET_ME.get(classId, "Let's go.")})
	startScene(lines, func(): banner("Board the rocket", "Press ↑ at the hatch when you're ready"))


func rocketAt() -> bool:
	if not P.grounded:
		return false
	if isVillage() and lunarNight():
		return absf(P.x - ROCKET_X) < 22
	if mapId == "moon1":
		return absf(P.x - MOON_ROCKET_X) < 22
	return false


func boardRocket() -> void:
	if introBusy():
		return
	P.frozen = true
	P.vx = 0
	P.iframes = 1e6
	if mapId == "moon1":   # back down to Sproutvale
		glamraxCutscene(classId, [{"kind": "l_home", "title": false, "text": "The rocket drops back through the clouds and settles on its pad behind the houses. The moon watches it all the way down."}], func():
			P.frozen = false
			P.iframes = 1.0
			loadMap("home", ROCKET_X - 40))
		return
	var scenes = [
		{"kind": "l_launch", "title": false, "text": "Five heroes, one rocket, and a moon that won't move. Tank counts down from three and doesn't bother waiting for one."},
		{"kind": "l_space", "title": false, "text": "Sproutvale shrinks to a green marble behind them. Ahead, the moon fills the window, red as a wound."},
		{"kind": "l_land", "title": false, "text": "The rocket touches down in a cloud of silver dust. For a long moment, nobody says anything at all."},
	]
	if LU().moon:
		scenes = scenes.slice(1)
	glamraxCutscene(classId, scenes, func(): _landOnMoon())


func _landOnMoon() -> void:
	var L = LU()
	L.moon = true
	saveDirty = true
	P.frozen = false
	P.iframes = 1.0
	loadMap("moon1", MOON_ROCKET_X + 34, 300.0)
	P.vy = 20
	P.grounded = false
	P.surf = null
	P.face = 1
	persist()


# ================================================================ every frame

func updatePlayer(dt: float) -> void:
	if pressed.get("arrowup") and scene == null and P.grounded and P.state in ["move", "crouch", "block"]:
		var n = npcAt()
		if n != null:
			pressed.erase("arrowup")
			P.face = 1 if n.x > P.x else -1
			talkTo(n)
		elif rocketAt():
			pressed.erase("arrowup")
			boardRocket()
	var moon = mapId == "moon1"
	var wasGrounded = P.grounded
	var vy0 = P.vy
	if moon and not P.grounded and P.state != "climb":
		P.vy -= GRAV * (1.0 - MOON_GRAV) * dt   # physics adds the whole pull right after; this leaves the Moon's
		P.vy = minf(P.vy, 240.0)
	super.updatePlayer(dt)
	if moon:
		if not wasGrounded and P.grounded:
			_moonDust(P.x, P.y, clampf(vy0 / 160.0, 0.4, 2.0))
		elif P.grounded and absf(P.vx) > 60 and randf() < dt * 10:
			_moonDust(P.x - P.face * 4, P.y, 0.15)


## grey dust that hangs in the air and settles slowly (there's no wind up here)
func _moonDust(x: float, y: float, k: float) -> void:
	for i in int(6 + k * 16):
		var a = rand(-PI, 0)
		var sp = rand(20, 70) * k
		moonDust.append({"x": x + rand(-6, 6), "y": y - 1, "vx": cos(a) * sp * 1.6, "vy": sin(a) * sp * 0.7 - rand(0, 20) * k,
			"t": 0.0, "life": rand(1.2, 2.6), "r": rand(1.5, 4.5)})
	if k > 0.35:
		Sfx.burst(0.35, "lowpass", 600, 200, 0.12 * k)


func updateTank(dt: float) -> void:
	super.updateTank(dt)
	for i in range(moonDust.size() - 1, -1, -1):
		var d: Dictionary = moonDust[i]
		d.t += dt
		d.vy += GRAV * MOON_GRAV * 0.12 * dt
		d.vx *= exp(-dt * 1.2)
		d.x += d.vx * dt
		d.y = minf(d.y + d.vy * dt, float(M.get("floorY", d.y)))
		if d.t > d.life:
			moonDust.remove_at(i)
	if isVillage() and lunarNight() and not LU().talked and not LU().moon and scene == null and P.grounded and absf(P.x - ROCKET_X) < 170 and not introBusy():
		_rocketTalk()
