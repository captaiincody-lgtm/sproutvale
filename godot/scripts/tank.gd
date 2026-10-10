extends "res://scripts/abyss.gd"
## Sproutvale, part 6c: Tank, the fifth hero. He escaped from the Dreamer's dream and builds himself
## into a walking war machine: a pistol on Z and grenades on X that chain together like Rock's combos,
## an exosuit grown one piece at a time (boots, legs, chest and arms, helmet, then Mk II of each and
## finally a full mecha suit), a drone that fights on its own, grenade types instead of a charm, and
## components only he can find, spent in his Workshop.
## His art and cutscenes are drawn in tank_draw.gd; his Workshop menu lives in tank_ui.gd.

const PART_KEYS := ["scrap", "wire", "circuit", "core"]
const PART_INFO := {
	"scrap": {"name": "Scrap Metal", "col": "#b8c2cc", "tip": "Bent plates and bolts. Nearly every monster Tank defeats leaves some."},
	"wire": {"name": "Copper Wire", "col": "#ff9a4a", "tip": "Tangles of wire. About one monster in three drops some."},
	"circuit": {"name": "Circuit Board", "col": "#5ad88a", "tip": "A green board, still blinking. Rare; tougher monsters drop more."},
	"core": {"name": "Power Core", "col": "#6fd8ff", "tip": "A humming blue core. Very rare from monsters, guaranteed from elites and bosses."},
}
const NADES := [
	{"id": "frag", "name": "Frag", "icon": "💥", "col": "#ffb03a", "lv": 1, "parts": {}, "desc": "A solid blast."},
	{"id": "shrapnel", "name": "Shrapnel", "icon": "✴️", "col": "#d8d8d8", "lv": 5, "parts": {"scrap": 30, "wire": 8}, "desc": "Bursts into eight flying shards."},
	{"id": "cryo", "name": "Cryo", "icon": "❄️", "col": "#9fe6ff", "lv": 12, "parts": {"scrap": 45, "wire": 20, "circuit": 4}, "desc": "Freezes and slows everything it catches."},
	{"id": "napalm", "name": "Napalm", "icon": "🔥", "col": "#ff6a2a", "lv": 18, "parts": {"scrap": 60, "wire": 25, "circuit": 8}, "desc": "Leaves the ground burning for a few seconds."},
	{"id": "energy", "name": "Energy", "icon": "🔷", "col": "#6fd8ff", "lv": 25, "parts": {"scrap": 80, "wire": 40, "circuit": 14, "core": 1}, "desc": "A bigger blast that arcs to one more enemy."},
	{"id": "emp", "name": "EMP", "icon": "⚡", "col": "#fff36a", "lv": 32, "parts": {"scrap": 100, "wire": 60, "circuit": 20, "core": 2}, "desc": "Stuns for 2s, wrecks metal monsters and gives back Electricity."},
	{"id": "cluster", "name": "Cluster", "icon": "🎆", "col": "#ff7eb6", "lv": 40, "parts": {"scrap": 140, "wire": 70, "circuit": 30, "core": 3}, "desc": "Splits into three bomblets."},
]
## the drone, tier 1–4 (0 = not built yet)
const DRONES := [
	{},
	{"name": "Scout Drone", "rate": 1.4, "dmg": 0.35, "lv": 8, "coins": 800, "parts": {"scrap": 60, "wire": 30, "circuit": 6}, "desc": "Hovers by your shoulder and shoots at anything close."},
	{"name": "Gunner Drone", "rate": 1.15, "dmg": 0.45, "rocket": true, "lv": 20, "coins": 3000, "parts": {"scrap": 120, "wire": 60, "circuit": 15, "core": 1}, "desc": "Fires faster, and launches a rocket every time you throw a grenade."},
	{"name": "Twin-Gun Drone", "rate": 0.95, "dmg": 0.55, "rocket": true, "twin": true, "lv": 35, "coins": 9000, "parts": {"scrap": 200, "wire": 100, "circuit": 30, "core": 3}, "desc": "Two guns. It joins in on your burst fire too."},
	{"name": "Lancer Drone", "rate": 0.75, "dmg": 0.75, "rocket": true, "twin": true, "energy": true, "lv": 50, "coins": 20000, "parts": {"scrap": 320, "wire": 160, "circuit": 50, "core": 6}, "desc": "Fires energy bolts that pierce."},
]
const HOUSE_COST := {"lv": 15, "coins": 5000, "mats": {}, "parts": {"scrap": 250, "wire": 120, "circuit": 30, "core": 4}}
const SPD_BY_ARMOR := [0.0, 0.0, 0.18, 0.18, 0.18, 0.18, 0.3, 0.3, 0.3, 0.38]
const CHAIN_NEXT := {"t_shoot": "t_shoot2", "t_shoot2": "t_shoot3", "t_shoot3": "t_burst"}
const NADE_NEXT := {"t_shoot": "t_nade", "t_shoot2": "t_cook", "t_shoot3": "t_barrage", "t_burst": "t_barrage"}
const MUZZLE := {"fwd": [19, -29], "up": [12, -42], "down": [15, -14], "low": [22, -5]}
const NADE_G := 620.0
const NADE_CD := 0.7   # seconds between grenades (about twice a throw), so they can't be spammed
const MAG := [6, 8, 10, 12, 14, 16, 18, 22]          # rounds per magazine, by pistol tier
const RELOAD := [0.75, 0.71, 0.67, 0.63, 0.59, 0.55, 0.51, 0.47]   # seconds to reload, by pistol tier
const WEAK_EVERY := [60.0, 55.0, 50.0]   # a weak point shows up this often: helmet, helmet Mk II, the mecha suit
const NEW_ANIMS := {"p_throw": [18, 5], "j_throwUp": [18, 5], "a_airThrow": [20, 4], "a_aim": [1, 9], "a_airAim": [1, 9]}

var tshots: Array = []   # Tank's bullets, grenades and missiles (and his drone's and turret's)
var tfx: Array = []      # his explosions, fire patches, beams and fly-by drones
var TK := {"q": "", "dashN": 0, "slam": false, "slamV": 0.0, "slamHit": {}, "glide": false, "fly": false,
	"drone": {"x": 0.0, "y": 0.0, "cd": 1.0, "t": 0.0, "flash": 0.0}, "turrets": [], "bot": null, "weak": {}, "meteor": null,
	"burstN": 0, "burstT": 0.0, "burstHit": {}, "glided": false, "airNadeN": 0, "nadeCd": 0.0, "mag": -1, "reload": 0.0, "idleT": 0.0,
	"aim": {"t": 0.0, "i": 4, "air": false}, "weakCd": 8.0, "weakOn": null}
var _tpts := {}   # tank_points.json: the pistol's muzzle and the throwing hand, per look, anim and frame


# ================================================================ data

func initTankData() -> void:
	CLASSES.tank = {"id": "tank", "name": "Tank", "role": "Mechanic", "initial": "T", "resource": "Electricity", "res": "EL", "unlock": "dreamer",
		"blurb": "Born from the Dreamer's dream. A build-it-yourself war machine: a pistol, grenades, and an exosuit built one piece at a time.",
		"armorLabel": "Exosuit", "weaponLabel": "Pistol", "nadeLabel": "Grenades"}
	JOBS_BY.tank = [
		{"id": "t_tinkerer", "name": "Tinkerer", "lv": 1, "targets": 1, "color": "#c9d3e6"},
		{"id": "t_mechanic", "name": "Mechanic", "lv": 10, "targets": 3, "color": "#7fd35a"},
		{"id": "t_engineer", "name": "Engineer", "lv": 30, "targets": 6, "color": "#6fd8ff"},
		{"id": "t_robotics", "name": "Mech Pilot", "lv": 75, "targets": 9, "color": "#ffc83d"},
		{"id": "t_mecha", "name": "Ace Pilot", "lv": 100, "targets": 12, "color": "#ff7eb6"},
		{"id": "t_sage", "name": "Titan Commander", "lv": 150, "targets": 15, "color": "#fff3b0"},
		{"id": "t_avatar", "name": "Machine God", "nameF": "Machine Goddess", "lv": 200, "targets": 18, "color": "#b388ff"},
	]
	DEFAULT_LOOK.tank = {"m": {"style": "buzz", "hair": "raven", "eye": "amber"}, "f": {"style": "buzz", "hair": "raven", "eye": "amber"}}   # Tank's looks are baked per exosuit stage, so these are placeholders
	PRIMARY.tank = ["ATK", "Attack Power"]
	GEAR.tank = {"armor": _exoTiers(), "weapon": _gunTiers(), "nade": _nadeTiers()}
	for k in NEW_ANIMS:
		if not ANIM_BY_ID.has(k):
			ANIM_BY_ID[k] = {"fps": NEW_ANIMS[k][0], "frames": NEW_ANIMS[k][1], "loop": false}
	_tankMoves()
	_tankSkills()
	STORY.tank = {"kin": "dream", "line": "The Dreamer falls.", "scenes": [
		{"kind": "t_fall", "title": false, "text": "The Dreamer falls. As its great eye goes dark, something deep inside its fading dream opens one of its own: a single red light."},
		{"kind": "t_escape", "title": false, "text": "You were never born. You were dreamed. Now the dream is ending around you, so you run, and you tear your way out."},
		{"kind": "t_surface", "title": false, "text": "Cold water. Then air. You surface in the black sea above the Abyss and swim for the far, quiet shore."},
		{"kind": "t_shore", "title": false, "text": "By morning you reach land: an empty field, a pistol, a wrench, and a cardboard box someone left behind. It will have to do for a home."},
	]}
	var house: Dictionary = HOME_VARIANTS.rock.house.duplicate(true)
	house.variant = "tank"
	house.name = "Tank's Workshop"
	house.sub = "Built from scrap, wire and spite"
	house.notes = [{"x": 264, "y": 196, "label": "Look at the empty frame", "text": "An empty picture frame. Nobody to put in it. Machines don't need anyone... right?"}]
	HOME_VARIANTS.tank = {"home": {"variant": "tank", "plats": [], "ropes": [], "house": null, "tree": null, "hill": null, "modern": null, "box": 560,
		"portals": [{"x": 1064, "to": "meadow", "tx": 70, "label": "Sproutvale Meadow"}]}, "house": house}
	for k in PART_KEYS:
		MAT_TIPS["p_" + k] = PART_INFO[k].tip


func _parts(i: int, k: float) -> Dictionary:
	var p = {"scrap": roundi((12 + i * 22) * k), "wire": roundi((4 + i * 9) * k)}
	if i >= 2:
		p.circuit = roundi((i - 1) * 4 * k)
	if i >= 4:
		p.core = maxi(1, roundi((i - 3) * k))
	return p


func _exoTiers() -> Array:
	var names = ["Work Clothes", "Rocket Boots", "Servo Legs", "Chest & Arms Rig", "Diagnostic Helmet", "Rocket Boots Mk II", "Servo Legs Mk II", "Chest Rig Mk II", "Helmet Mk II", "Full Mecha Suit"]
	var lvs = [1, 5, 10, 18, 25, 30, 35, 40, 45, 50]
	var hp = [0, 30, 70, 120, 180, 240, 300, 360, 420, 560]
	var df = [0, 5, 10, 18, 26, 34, 42, 50, 58, 80]
	var coins = [0, 300, 700, 1800, 3600, 6000, 9000, 13000, 18000, 32000]
	var ability = [
		"Just a work shirt. Every machine starts somewhere.",
		"Rocket boots: higher jumps, and hold Space while falling to glide.",
		"Servo legs: you run faster and slide faster and twice as far. Your dodge becomes a rocket burst that goes twice as far, and you get two bursts (forward twice, or forward and back). Bursting through monsters hurts them a little.",
		"Chest and arms: your second rocket burst becomes a shoulder slam. Unlocks twin pistols and the grenade launcher.",
		"Diagnostic helmet: about every 60 seconds a weak point shows up on a monster or boss nearby. Hitting it is a super crit, twice a normal crit.",
		"Boots Mk II: even higher jumps and a slower, longer glide.",
		"Legs Mk II: faster still, and your rocket bursts go farther.",
		"Chest Mk II: the shoulder slam hits half again as hard and sends out a shockwave.",
		"Helmet Mk II: a weak point shows up about every 55 seconds (every 50 with the full suit).",
		"The full mecha suit. Hold Space in the air to fly.",
	]
	var out = []
	for i in names.size():
		var t = {"lv": lvs[i], "name": names[i], "hp": hp[i], "def": df[i], "coins": coins[i], "mats": {} if i == 0 else matsForLevel(lvs[i]),
			"parts": {} if i == 0 else _parts(i, 1.0), "ability": ability[i]}
		if i == 9:
			t.parts = {"scrap": 400, "wire": 200, "circuit": 70, "core": 10}
		out.append(t)
	return out


func _gunTiers() -> Array:
	var names = ["Rusty Pistol", "Tuned Pistol", "Rifled Pistol", "Twin Arm-Pistols", "Twin Pistols Mk II", "Energy Twins", "Plasma Twins", "Arc Cannons"]
	var lvs = [1, 5, 12, 20, 28, 36, 44, 50]
	var atk = [0, 6, 16, 30, 48, 70, 96, 150]
	var coins = [0, 150, 500, 1700, 4000, 7500, 12000, 18000]
	var desc = ["Old, loud, and it works.", "Cleaned, oiled and sighted.", "Rifled barrel: straighter, harder shots.",
		"Built into the arm rig: two pistols, faster and harder hitting.", "Reinforced twin barrels.", "The twins now fire energy blasts that pierce.",
		"Hotter, brighter plasma blasts.", "Arm cannons. Every shot is a bolt of lightning."]
	var out = []
	for i in names.size():
		var t = {"lv": lvs[i], "name": names[i], "atk": atk[i], "def": 0, "coins": coins[i], "mats": {} if i == 0 else matsForLevel(lvs[i], true),
			"parts": {} if i == 0 else _parts(i, 0.8), "dual": i >= 3, "energy": i >= 5, "desc": desc[i]}
		if i == 3:
			t.needArmor = 3
		out.append(t)
	return out


func _nadeTiers() -> Array:
	var names = ["Tin-Can Grenade", "Pipe Grenade", "Shaped Charge", "Arm Grenade Launcher", "Launcher Mk II", "Micro-Missile Pod", "Swarm Missile Pod"]
	var lvs = [1, 8, 16, 24, 32, 40, 50]
	var mul = [1.0, 1.15, 1.3, 1.5, 1.7, 1.95, 2.3]
	var modes = ["hand", "hand", "hand", "launcher", "launcher", "missile", "missile"]
	var coins = [0, 250, 900, 2600, 5500, 10000, 17000]
	var desc = ["A tin can full of something that goes bang.", "A heavier pipe bomb.", "A shaped charge: a bigger, harder blast.",
		"Fired from the arm rig: fast, flat shots that blow up on contact.", "Faster reload, bigger blasts.", "Homing micro-missiles.", "Three homing missiles at once."]
	var out = []
	for i in names.size():
		var t = {"lv": lvs[i], "name": names[i], "atk": 0, "def": 0, "mul": mul[i], "mode": modes[i], "coins": coins[i], "mats": {} if i == 0 else matsForLevel(lvs[i], true),
			"parts": {} if i == 0 else _parts(i, 0.9), "desc": desc[i], "swarm": i == 6}
		if i == 3:
			t.needArmor = 3
		out.append(t)
	return out


func _tankMoves() -> void:
	var M2 = {
		"t_shoot": {"anim": "a_shoot", "hits": [1], "dmg": 0.5, "kb": 30, "up": -30, "style": 8, "cancel": 2, "gun": "pistol", "aim": "fwd"},
		"t_shoot2": {"anim": "a_shoot", "hits": [1], "dmg": 0.5, "kb": 30, "up": -30, "style": 9, "cancel": 2, "gun": "pistol", "aim": "fwd"},
		"t_shoot3": {"anim": "a_shoot", "hits": [1], "dmg": 0.56, "kb": 40, "up": -40, "style": 10, "cancel": 2, "gun": "pistol", "aim": "fwd"},
		"t_burst": {"anim": "a_rapid", "hits": [1, 2, 3, 4], "dmg": 0.38, "kb": 50, "up": -60, "style": 18, "cancel": 5, "gun": "burst", "aim": "fwd"},
		"t_up": {"anim": "a_shootUp", "hits": [1], "dmg": 0.55, "kb": 20, "up": -120, "style": 10, "cancel": 2, "gun": "pistol", "aim": "up"},
		"t_low": {"anim": "a_low", "hits": [1], "dmg": 0.55, "kb": 60, "up": -150, "style": 11, "cancel": 2, "gun": "pistol", "aim": "low", "prone": true},
		"t_air": {"anim": "a_air", "hits": [1], "dmg": 0.5, "kb": 30, "up": -140, "style": 10, "cancel": 2, "gun": "pistol", "aim": "fwd", "air": true},
		"t_air2": {"anim": "a_air", "hits": [1], "dmg": 0.5, "kb": 30, "up": -150, "style": 11, "cancel": 2, "gun": "pistol", "aim": "fwd", "air": true},
		"t_air3": {"anim": "a_rapid", "hits": [1, 2, 3], "dmg": 0.4, "kb": 60, "up": -160, "style": 18, "cancel": 4, "gun": "burst", "aim": "fwd", "air": true},
		"t_airUp": {"anim": "a_airUp", "hits": [1], "dmg": 0.5, "kb": 20, "up": -170, "style": 10, "cancel": 2, "gun": "pistol", "aim": "up", "air": true},
		"t_airDown": {"anim": "a_airDown", "hits": [1], "dmg": 0.52, "kb": 30, "up": 120, "style": 11, "cancel": 2, "gun": "pistol", "aim": "down", "air": true},
		"t_whip": {"anim": "j_push", "hits": [1, 2], "box": [-2, 30, -42, 0], "dmg": 0.75, "kb": 260, "up": -100, "style": 12, "lunge": 18, "cancel": 3},
		"t_upper": {"anim": "a_launch", "hits": [1, 2], "box": [-2, 34, -56, 2], "dmg": 0.75, "kb": 20, "up": -360, "style": 16, "lunge": 18, "cancel": 3, "launcher": true},
		"t_nade": {"anim": "j_throw", "hits": [2], "dmg": 1.5, "kb": 0, "up": 0, "style": 14, "cancel": 4, "nade": "throw"},
		"t_cook": {"anim": "j_throw", "hits": [1], "dmg": 2.0, "kb": 0, "up": 0, "style": 20, "cancel": 4, "nade": "cook"},
		"t_barrage": {"anim": "j_throw", "hits": [1, 2, 3], "dmg": 1.1, "kb": 0, "up": 0, "style": 26, "cancel": 5, "nade": "barrage"},
		"t_airNade": {"anim": "a_airThrow", "hits": [1], "dmg": 1.4, "kb": 0, "up": 0, "style": 14, "cancel": 3, "nade": "air", "air": true},
		"t_airNadeUp": {"anim": "a_airThrow", "hits": [1], "dmg": 1.4, "kb": 0, "up": 0, "style": 14, "cancel": 3, "nade": "airUp", "air": true},
		"t_airNadeDown": {"anim": "a_airDown", "hits": [1], "dmg": 1.4, "kb": 0, "up": 0, "style": 14, "cancel": 3, "nade": "down", "air": true},
		"t_nadeUp": {"anim": "j_throwUp", "hits": [2], "dmg": 1.5, "kb": 0, "up": 0, "style": 14, "cancel": 4, "nade": "up"},
		"t_proneNade": {"anim": "p_throw", "hits": [2], "dmg": 1.5, "kb": 0, "up": 0, "style": 16, "cancel": 4, "nade": "prone", "prone": true},
	}
	MOVES.merge(M2, true)


## a skill's description and damage for every rank (Ascendency can push past the max, so the arrays run long)
func _tsk(id: String, job: String, type: String, name: String, icon: String, max_: int, extra: Dictionary, descF: Callable, dmgF = null) -> void:
	var s = {"cls": "tank", "id": id, "job": job, "type": type, "name": name, "icon": icon, "max": max_, "desc": []}
	s.merge(extra, true)
	var n = max_ + ASC_NODE_MAX + 2
	if type == "buff":
		s.dur = []
	if dmgF != null:
		s.dmgR = []
	for r in n:
		s.desc.append(descF.call(r))
		if type == "buff":
			s.dur.append(extra.get("dur0", 40) + r * 2)
		if dmgF != null:
			s.dmgR.append(dmgF.call(r))
	s.erase("dur0")
	SKILLS.append(s)
	SKILL[id] = s


func _tankSkills() -> void:
	var pct = func(v: float) -> int: return roundi(v * 100)
	# Tinkerer
	_tsk("scrapSense", "t_tinkerer", "passive", "Scrap Sense", "🔩", 10, {"innate": 1},
		func(r): return "Components drop %d%% more often, Electricity recovers %d%% faster (starts at rank 1 for free)" % [r * 6, r * 3])
	_tsk("overclock", "t_tinkerer", "buff", "Overclock", "⏩", 10, {"cd": 60, "cost": 30, "fx": "#7fd8ff", "dur0": 30},
		func(r): return "For %ds: attack speed +%d%%, Electricity from hits +50%%" % [30 + r * 2, 8 + r])
	# Mechanic
	_tsk("sentry", "t_mechanic", "active", "Sentry Turret", "🛰️", 20, {"anim": "j_throw", "hitF": [2], "cd": 8, "cost": 16, "range": 180, "fx": "turret"},
		func(r): return "Throws down a turret for 8s that shoots the nearest enemy: %d%% damage per shot" % pct.call(0.45 + r * 0.03), func(r): return 0.45 + r * 0.03)
	_tsk("gunsmith", "t_mechanic", "passive", "Gunsmithing", "🔧", 10, {},
		func(r): return "Attack +%d%%, attack speed +%d%%" % [r * 3, r * 2])
	_tsk("staticShield", "t_mechanic", "buff", "Static Shield", "🛡️", 15, {"cd": 70, "cost": 30, "fx": "#9fe6ff", "dur0": 40},
		func(r): return "For %ds: defense +%d%%, and anything that hits you gets zapped for 80%% damage" % [40 + r * 2, 15 + r])
	# Engineer
	_tsk("strafe", "t_engineer", "active", "Strafing Run", "✈️", 20, {"anim": "a_shootUp", "hitF": [2], "cd": 0.6, "cost": 20, "range": 240, "fx": "strafe"},
		func(r): return "Two drones strafe up to 6 enemies, 3 shots each: %d%% damage per shot" % pct.call(0.7 + r * 0.05), func(r): return 0.7 + r * 0.05)
	_tsk("demolitions", "t_engineer", "passive", "Demolitions", "🧨", 10, {},
		func(r): return "Grenade and missile damage +%d%%, blast radius +%d%%" % [r * 5, r * 3])
	_tsk("teslaRounds", "t_engineer", "buff", "Tesla Rounds", "🌩️", 15, {"cd": 80, "cost": 30, "fx": "#bfe8ff", "dur0": 40},
		func(r): return "For %ds: every bullet arcs to a second enemy for %d%% of its damage" % [40 + r * 2, 40 + r * 2])
	# Mech Pilot
	_tsk("buildBot", "t_robotics", "buff", "Build-a-Bot", "🤖", 15, {"cd": 90, "cost": 30, "fx": "#ffc83d", "dur0": 50, "summon": true},
		func(r): return "Builds a fighting robot that follows you for %ds. Its punches deal %d%% damage" % [50 + r * 2, 120 + r * 8])
	_tsk("servoTuning", "t_robotics", "passive", "Servo Tuning", "⚙️", 10, {},
		func(r): return "Critical rate +%d%%, critical damage +%d%%" % [r, r * 4])
	_tsk("napalmDrones", "t_robotics", "active", "Napalm Drones", "🔥", 20, {"anim": "a_shootUp", "hitF": [2], "cd": 0.7, "cost": 24, "range": 260, "fx": "napalm"},
		func(r): return "Drones carpet up to 9 enemies with napalm: %d%% damage, and they keep burning" % pct.call(1.6 + r * 0.1), func(r): return 1.6 + r * 0.1)
	# Ace Pilot
	_tsk("missileStrike", "t_mecha", "active", "Missile Strike", "🚀", 20, {"anim": "a_shootUp", "hitF": [2, 4], "cd": 0.8, "cost": 28, "range": 280, "fx": "missiles"},
		func(r): return "Missiles rain on up to 12 enemies, twice: %d%% damage each" % pct.call(2.0 + r * 0.12), func(r): return 2.0 + r * 0.12)
	_tsk("reactorCore", "t_mecha", "passive", "Reactor Core", "☢️", 10, {},
		func(r): return "Max HP +%d%%, max Electricity +%d" % [r * 3, r * 5])
	_tsk("hardlight", "t_mecha", "buff", "Hardlight Plating", "🔰", 15, {"cd": 100, "cost": 30, "fx": "#ff7eb6", "dur0": 45},
		func(r): return "For %ds: attack +%d%%, defense +25%%" % [45 + r * 2, 25 + r * 2])
	# Titan Commander
	_tsk("orbitalLaser", "t_sage", "active", "Orbital Laser", "🛸", 20, {"anim": "a_shootUp", "hitF": [2, 3, 4], "cd": 0.9, "cost": 32, "range": 300, "fx": "laser"},
		func(r): return "A satellite beam scorches up to 15 enemies three times: %d%% damage each" % pct.call(2.6 + r * 0.15), func(r): return 2.6 + r * 0.15)
	_tsk("machineMind", "t_sage", "passive", "Machine Mind", "🧠", 10, {},
		func(r): return "Attack +%d%%, Electricity recovers %d%% faster" % [r * 2, r * 3])
	_tsk("swarmProtocol", "t_sage", "buff", "Swarm Protocol", "🐝", 15, {"cd": 110, "cost": 30, "fx": "#fff3b0", "dur0": 45},
		func(r): return "For %ds: two wingman drones join yours, and all of them fire twice as fast" % [45 + r * 2])
	# Machine God
	_tsk("armageddon", "t_avatar", "active", "Armageddon", "☄️", 20, {"anim": "a_shootUp", "hitF": [2, 3, 4, 5], "cd": 1.0, "cost": 38, "range": 320, "fx": "armageddon"},
		func(r): return "Missiles and orbital lasers sweep the field in four waves, on up to 18 enemies: %d%% damage each" % pct.call(3.6 + r * 0.28), func(r): return 3.6 + r * 0.28)
	_tsk("avatarEngine", "t_avatar", "passive", "Avatar Engine", "✨", 10, {},
		func(r): return "All attributes +%d, attack +%d%%" % [r * 5, r * 2])
	_tsk("titanProtocol", "t_avatar", "buff", "Titan Protocol", "🦾", 15, {"cd": 150, "cost": 30, "fx": "#b388ff", "dur0": 60},
		func(r): return "For %ds: go full mecha. Attack +%d%%, defense +30%%, and every shot is an energy blast" % [60 + r * 2, 55 + r * 3])


# ================================================================ helpers

func isTank() -> bool:
	return classId == "tank"


func armorT() -> int:
	return int(CH().get("armor", 0)) if isTank() else 0


func nadeType() -> String:
	return str(CH().get("nadeSel", "frag")) if isTank() else "frag"


func droneTier() -> int:
	return int(CH().get("drone", 0)) if isTank() else 0


func houseBuilt() -> bool:
	return tb2(save.get("tankHouse", false))


static func tb2(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return true


func partCount(k: String) -> int:
	return int(save.get("parts", {}).get(k, 0))


func hasParts(p: Dictionary) -> bool:
	for k in p:
		if partCount(k) < p[k]:
			return false
	return true


func spendParts(p: Dictionary) -> void:
	if not save.has("parts"):
		save.parts = {}
	for k in p:
		save.parts[k] = partCount(k) - p[k]


func tankJumpMul() -> float:
	if not isTank():
		return 1.0
	var a = armorT()
	return 1.28 if a >= 5 else (1.18 if a >= 1 else 1.0)


## which grenade types are unlocked, and picking one (1–7 or V, like Remy's elements)
func nadesOwned() -> Array:
	var c = CH()
	if not (c.get("nades") is Array):
		c.nades = ["frag"]
	return c.nades


func selNade(i: int) -> void:
	if i < 0 or i >= NADES.size():
		return
	var N: Dictionary = NADES[i]
	if not nadesOwned().has(N.id):
		floatText(P.x, P.y - 58, "Build %s grenades in the Workshop" % N.name, "call")
		Sfx.tone(160, 0.1, "square", 0.05, 120)
		return
	CH().nadeSel = N.id
	floatText(P.x, P.y - 58, "%s %s grenades" % [N.icon, N.name], "call")
	Sfx.tone(520, 0.06, "square", 0.04, 900)


func cycleNade() -> void:
	var own = nadesOwned()
	if own.size() < 2:
		selNade(0)
		return
	var ids = NADES.map(func(n): return n.id)
	var cur = ids.find(nadeType())
	for k in range(1, NADES.size() + 1):
		var j = (cur + k) % NADES.size()
		if own.has(ids[j]):
			selNade(j)
			return


func _nadeInfo(id: String) -> Dictionary:
	for n in NADES:
		if n.id == id:
			return n
	return NADES[0]


# ================================================================ stats

func calcStats() -> Dictionary:
	var o = super.calcStats()
	if isTank():
		tankStats(o)
	return o


func tankStats(o: Dictionary) -> void:
	var R = skillRank
	var a = armorT()
	var hpMul = 1.08 * (1 + 0.03 * R.call("reactorCore"))
	o.hpFull = roundi(o.hpFull * hpMul)
	o.hp = roundi(o.hpFull * (1 - P.abyssDrain))
	var atkMul = 1 + 0.03 * R.call("gunsmith") + 0.02 * R.call("machineMind") + 0.02 * R.call("avatarEngine")
	if buffOn("hardlight"):
		atkMul += 0.25 + 0.02 * R.call("hardlight")
	if buffOn("titanProtocol"):
		atkMul += 0.55 + 0.03 * R.call("titanProtocol")
	o.atk = roundi(o.atk * atkMul)
	var defMul = 1.1 + ((0.15 + 0.01 * R.call("staticShield")) if buffOn("staticShield") else 0.0) + (0.25 if buffOn("hardlight") else 0.0) + (0.3 if buffOn("titanProtocol") else 0.0)
	o.def = roundi(o.def * defMul)
	o.crit = minf(80, o.crit + R.call("servoTuning"))
	o.critDmg += 0.04 * R.call("servoTuning")
	o.spd += SPD_BY_ARMOR[clampi(a, 0, 9)]
	o.aspd += 0.02 * R.call("gunsmith") + ((0.08 + 0.01 * R.call("overclock")) if buffOn("overclock") else 0.0)
	o.enMax += 5 * R.call("reactorCore")
	o.enRegen *= (1 + 0.03 * R.call("scrapSense")) * (1 + 0.03 * R.call("machineMind"))
	if buffOn("overclock"):
		o.enHit *= 1.5


# ================================================================ input and moves

func tankInput(has: Callable, use: Callable, dirIn: int, _up: bool, down: bool, wet: bool, canAct: bool, risingIntent: bool) -> void:
	for i in NADES.size():
		if pressed.get(str(i + 1)):
			selNade(i)
	if pressed.get("v"):
		cycleNade()
	var busy = P.state in ["climb", "hurt", "plunge", "knocked", "tumble"] or (P.state == "dash" and P.dashT < 0.14)
	var attacking = P.state == "attack" and P.move != null and not P.move.get("skill")
	var air = not P.grounded and not wet
	var reloading: bool = TK.reload > 0
	if has.call("atk", 0.22) and not busy:
		var whip: bool = P.grounded and not air and P.state != "prone" and closeEnemy(12) != null and not risingIntent
		var rising: bool = P.grounded and not air and risingIntent and closeEnemy(26) != null
		if reloading and not (whip or rising):
			pass   # the magazine is empty: the shot waits in the buffer until the reload finishes
		elif attacking and CHAIN_NEXT.has(P.moveId) and not air:
			use.call("atk")
			TK.q = CHAIN_NEXT[P.moveId]
		elif attacking and air and P.moveId in ["t_air", "t_air2"]:
			use.call("atk")
			TK.q = "t_air2" if P.moveId == "t_air" else "t_air3"
		elif attacking and P.moveId == "t_low":
			use.call("atk")
			TK.q = "t_low"
		elif not attacking or _cancelable():
			if dirIn and not attacking:
				P.face = dirIn
			if P.state == "prone":
				use.call("atk")
				startMove("t_low")
			elif air:
				use.call("atk")
				startMove("t_airUp" if risingIntent else ("t_airDown" if down else "t_air"))
				if airLift():
					P.vy = minf(P.vy, -40)
			elif canAct or attacking:
				use.call("atk")
				B_clearUp()
				if rising:
					startMove("t_upper")
				elif risingIntent:
					startMove("t_up")
				elif whip:
					startMove("t_whip")
				else:
					startMove("t_shoot")
	# grenades: X throws forward, ↑ + X lobs one high (to the platform above), and he can throw lying down or
	# in mid-air too (↓ + X in the air drops one straight down). A short cooldown keeps them from being spammed.
	if has.call("heavy", 0.2) and not busy and TK.nadeCd <= 0:
		if attacking and NADE_NEXT.has(P.moveId) and not air and not risingIntent:
			use.call("heavy")
			TK.q = NADE_NEXT[P.moveId]
		elif air and P.state != "dash":
			if not attacking or _cancelable():
				use.call("heavy")
				if dirIn:
					P.face = dirIn
				startMove("t_airNadeUp" if risingIntent else ("t_airNadeDown" if down else "t_airNade"))
				TK.airNadeN += 1
				if TK.airNadeN <= 3 and not TK.glided:   # like the others: only the first three hold you up
					P.vy = minf(P.vy, -60)
		elif P.state == "prone" and (not attacking or _cancelable()):
			use.call("heavy")
			if dirIn:
				P.face = dirIn
			startMove("t_proneNade")
		elif P.grounded and (canAct or (attacking and _cancelable())):
			use.call("heavy")
			if dirIn:
				P.face = dirIn
			B_clearUp()
			startMove("t_nadeUp" if risingIntent else "t_nade")


func B_clearUp() -> void:
	P.buf.upJump = null


## Tank's attack update: like Rock's, but his chains run through TK.q and his hit frames fire bullets and grenades
func _updateAttack(dt: float, aspd: float, dirIn: int, down: bool) -> void:
	if not isTank():
		super._updateAttack(dt, aspd, dirIn, down)
		return
	var mv: Dictionary = P.move
	P.moveT += dt
	var f = frameOf(mv.anim, P.moveT * aspd, false)
	var n = nFrames(mv.anim)
	if P.grounded:
		P.vx = damp(P.vx, 0, 9, dt)
	if mv.get("skill"):
		skillFrameFX(mv, f)
	if mv.get("air") and not P.grounded and P.airAtk <= AIR_LIFT_MAX and not TK.glided and not (mv.get("nade") and TK.airNadeN > 3):
		P.vy = minf(P.vy, 40)
	if f != P.lastFrame:
		P.lastFrame = f
		if mv.hits.has(f):
			if mv.get("skill"):
				skillHit(mv, f)
			elif mv.get("gun") or mv.get("nade"):
				tankFire(mv, f)
			else:
				var bx: Array = mv.get("box", [0, 0, 0, 0])
				var box = hbox(P.x + bx[0], P.x + bx[1], P.y + bx[2], P.y + bx[3]) if P.face > 0 else hbox(P.x - bx[1], P.x - bx[0], P.y + bx[2], P.y + bx[3])
				var best = null
				var bd = 1e9
				for e in slimes:
					if e.state == "dead" or not overlap(box, sBox(e)):
						continue
					var d = absf(e.x - P.x) + absf(e.y - P.y) * 0.5
					if d < bd:
						bd = d
						best = e
				if best != null:
					damageSlime(best, mv)
					P.en = minf(PS.enMax, P.en + PS.enHit)
	if f >= mv.cancel and TK.q != "" and not (MOVES[TK.q].get("nade") and TK.nadeCd > 0) and not (MOVES[TK.q].get("gun") and TK.reload > 0):
		var nx: String = TK.q
		TK.q = ""
		if dirIn:
			P.face = dirIn
		startMove(nx)
		if MOVES[nx].get("air"):
			P.vy = minf(P.vy, -70)
		return
	if P.moveT * aspd * ANIM_BY_ID[mv.anim].fps >= n:
		P.state = "prone" if mv.get("prone") and down else "move"
		if P.state == "prone":
			setAnim("prone")
		P.chainEndT = gameTime
		if mv.get("skill"):
			P.skillLock = 0


# ================================================================ guns and grenades

func gunRange() -> float:
	return 215.0


func muzzleAt(aim: String) -> Vector2:
	var m: Array = MUZZLE.get(aim, MUZZLE.fwd)
	var big = 1.1 if lookOf("tank").ends_with("_5") else 1.0   # fallback when the art has no point for this frame
	return Vector2(P.x + P.face * m[0] * big, P.y + m[1] * big)


## a point baked with Tank's art (the pistol's muzzle, or the throwing hand), in the world, or null
func tankPoint(anim: String, f: int, key: String):
	if _tpts.is_empty() and FileAccess.file_exists("res://art/hero/tank_points.json"):
		_tpts = Assets._json("res://art/hero/tank_points.json")
	var L: Array = _tpts.get(lookOf("tank"), {}).get(anim, {}).get(key, [])
	if f < 0 or f >= L.size() or L[f] == null:
		return null
	return Vector2(P.x + P.face * (float(L[f][0]) - 40.0), P.y + (float(L[f][1]) - 66.0))


## the pistol: rounds per magazine and reload time grow with each upgrade
func magSize() -> int:
	return MAG[clampi(int(CH().weapon), 0, MAG.size() - 1)]


func reloadTime() -> float:
	return RELOAD[clampi(int(CH().weapon), 0, RELOAD.size() - 1)] * (0.85 if buffOn("overclock") else 1.0)


func startReload(quiet := false) -> void:
	if TK.reload > 0:
		return
	TK.reload = reloadTime()
	if not quiet:
		floatText(P.x, P.y - 58, "Reloading", "call")
		Sfx.tone(320, 0.06, "square", 0.04, 200)
		Sfx.tone(240, 0.08, "square", 0.04, 180, 0.12)


## Tank's pose while shooting at a monster: the pistol points at it (a_aim / a_airAim, frame by angle)
func heroPose():
	if not isTank() or P.state != "attack" or P.move == null or not P.move.get("gun") or P.move.get("aim", "") != "fwd" or TK.aim.t <= 0:
		return null
	return ["a_airAim" if TK.aim.air else "a_aim", TK.aim.i]


func animFallback(a: String) -> String:
	return {"p_throw": "a_low", "j_throwUp": "j_throw", "a_airThrow": "a_airDown", "a_aim": "a_shoot", "a_airAim": "a_air"}.get(a, a)


func tankFire(mv: Dictionary, f: int) -> void:
	if mv.get("nade"):
		throwNade(mv, f)
		return
	if TK.mag < 0:
		TK.mag = magSize()
	if TK.reload > 0:
		return
	if TK.mag <= 0:
		startReload()
		return
	var c = CH()
	var W: Dictionary = GEAR.tank.weapon[clampi(int(c.weapon), 0, GEAR.tank.weapon.size() - 1)]
	var aim: String = mv.get("aim", "fwd")
	var tgt = aimTarget(aim, gunRange())
	var mz = muzzleAt(aim)
	var air = not P.grounded
	if aim == "fwd" and tgt != null:
		# point the pistol at the monster: one of nine baked aim angles, 60° up to 60° down
		var dx: float = (tgt.x - P.x) * P.face
		var dy: float = (tgt.y - tgt.h * 0.5) - (P.y - 30)
		var ang = clampf(rad_to_deg(atan2(dy, maxf(dx, 4.0))), -60, 60)
		TK.aim = {"t": 0.4, "i": clampi(roundi((ang + 60) / 15.0), 0, 8), "air": air}
		var ap = tankPoint("a_airAim" if air else "a_aim", TK.aim.i, "muzzle")
		if ap != null:
			mz = ap
	else:
		var mp = tankPoint(mv.anim, f, "muzzle")
		if mp != null:
			mz = mp
	var energy = W.get("energy", false) or buffOn("titanProtocol")
	var shots = 2 if W.get("dual", false) else 1
	for i in shots:
		var sp = (i - (shots - 1) / 2.0) * 0.06 + (rand(-0.05, 0.05) if mv.gun == "burst" else 0.0)
		spawnBullet(mz.x, mz.y + (i - (shots - 1) / 2.0) * 3, tgt, aim, mv.dmg * (0.65 if shots == 2 else 1.0), "energy" if energy else "bullet", sp, true)
	tfx.append({"type": "flash", "x": mz.x, "y": mz.y, "t": 0.0, "life": 0.07, "energy": energy})
	if energy:
		Sfx.tone(rand(1100, 1300), 0.08, "sawtooth", 0.045, 300)
	else:
		Sfx.tone(rand(620, 760), 0.05, "square", 0.05, 160)
		Sfx.tone(140, 0.07, "sawtooth", 0.04, 60)
	if mv.gun == "burst" and f == 1 and droneTier() >= 3:
		droneFire(tgt, true)
	TK.mag -= 1
	TK.idleT = 0.0
	if TK.mag <= 0:
		startReload()


func spawnBullet(x: float, y: float, tgt, aim: String, dmg: float, kind := "bullet", spread := 0.0, own := false, homing := 1.0) -> Dictionary:
	var sp = 560.0 if kind == "energy" else 500.0
	var ang: float
	if tgt != null:
		ang = atan2((tgt.y - tgt.h * 0.5) - y, tgt.x - x)
	elif aim == "up":
		ang = -1.1 if P.face > 0 else PI + 1.1
	elif aim == "down":
		ang = 0.95 if P.face > 0 else PI - 0.95
	else:
		ang = 0.0 if P.face > 0 else PI
	ang += spread
	var b = {"kind": kind, "x": x, "y": y, "vx": cos(ang) * sp, "vy": sin(ang) * sp, "t": 0.0, "life": gunRange() / sp + 0.1, "tgt": tgt,
		"hit": {}, "pierce": 1 if kind == "energy" else 0, "dmg": dmg, "own": own, "homing": homing}
	tshots.append(b)
	return b


## a grenade (or launcher shell, or missile) from Tank's hand
func throwNade(mv: Dictionary, f: int) -> void:
	var c = CH()
	var NT: Dictionary = GEAR.tank.nade[clampi(int(c.get("nade", 0)), 0, GEAR.tank.nade.size() - 1)]
	var demo = skillRank("demolitions")
	var dmg: float = mv.dmg * NT.mul * (1 + 0.05 * demo)
	var R: float = 30.0 * (1 + 0.03 * demo) * (1.35 if mv.nade == "cook" else 1.0)
	var how: String = mv.nade
	var lob: bool = how in ["up", "airUp"]   # ↑ + X: high and short, for the platform above
	var tgt = null
	if lob:
		tgt = _lobTarget()
	elif how != "down":
		tgt = aimTarget("fwd", 190)
		if tgt == null:
			tgt = nearestFoe(P.x + P.face * 60, P.y - 20, 150)
	var ox = P.x + P.face * 10
	var oy = P.y - (8.0 if how == "prone" else 34.0)
	var hp = tankPoint(mv.anim, f, "hand")
	if hp != null:
		ox = hp.x
		oy = hp.y
	var mode: String = NT.mode
	var nt = nadeType()
	if how == "down":
		_nade(ox, P.y - 18, P.face * 40.0, 300.0, dmg, R, nt, 2.0)
	elif mode == "missile":
		var n = 3 if NT.get("swarm") else 1
		for i in n:
			var m = _nade(ox, oy, P.face * (60.0 if lob else 160.0), (-330.0 if lob else -120.0) - i * 60.0, dmg * (0.6 if n > 1 else 1.0), R, nt, 1.6, "missile")
			m.tgt = tgt
	elif mode == "launcher":
		if lob:
			_nade(ox, oy, P.face * 120.0, -330.0, dmg, R * 1.1, nt, 1.4, "shell")
		else:
			_nade(ox, oy + (0.0 if how == "prone" else 4.0), P.face * 380.0, -30.0 if how == "prone" else -70.0, dmg, R * 1.1, nt, 1.2, "shell")
	else:
		var vx: float
		var vy: float
		if lob:
			# a steep lob: about 150 high and never much more than 110 across
			vy = -430.0
			vx = P.face * 80.0
			if tgt != null:
				vx = clampf((tgt.x - ox) / 1.3, -115, 115)
		elif how == "prone":
			vx = P.face * 230.0
			vy = -150.0
		elif how == "air":
			vx = P.face * 210.0
			vy = -150.0
		else:
			var T = 0.42 if how == "cook" else 0.55
			if tgt != null:
				var dx: float = clampf(tgt.x - ox, -200, 200)
				var dy: float = (tgt.y - 6) - oy
				vx = dx / T
				vy = (dy - 0.5 * NADE_G * T * T) / T
			else:
				vx = P.face * 190.0
				vy = -210.0
			if how == "barrage":
				vx *= 0.75 + f * 0.18
		_nade(ox, oy, vx, vy, dmg, R, nt, (0.55 if how == "cook" else (1.4 if lob else 1.0)))
	if f == mv.hits[0]:
		TK.nadeCd = NADE_CD
	Sfx.whoosh(1.3 if mode == "hand" else 0.9, false)
	if mode != "hand":
		Sfx.tone(180, 0.12, "sawtooth", 0.06, 80)
	if f == mv.hits[0] and droneTier() >= 2 and DRONES[droneTier()].get("rocket"):
		var D2 = TK.drone
		var rk = _nade(D2.x, D2.y, P.face * 120.0, -40.0, dmg * 0.4, R * 0.7, "frag", 1.5, "missile")
		rk.tgt = tgt
		rk.small = true


## a monster above and ahead (on a platform overhead), for the high lob
func _lobTarget():
	var best = null
	var bd = 1e9
	for e in slimes:
		if e.state == "dead" or e.bossEye or e.spawnT > 0:
			continue
		var dx: float = (e.x - P.x) * P.face
		var dy: float = P.y - e.y
		if dx > -20 and dx < 150 and dy > 10 and dy < 150:
			var d = absf(dx) + absf(dy) * 0.5
			if d < bd:
				bd = d
				best = e
	return best


func _nade(x: float, y: float, vx: float, vy: float, dmg: float, R: float, nt: String, fuse: float, kind := "nade") -> Dictionary:
	var g = {"kind": kind, "x": x, "y": y, "vx": vx, "vy": vy, "t": 0.0, "life": fuse, "dmg": dmg, "R": R, "nt": nt, "bounce": 0, "spin": randf() * 6,
		"tgt": null, "small": false, "hit": {}}
	tshots.append(g)
	return g


func updateTShots(dt: float) -> void:
	for i in range(tshots.size() - 1, -1, -1):
		if i >= tshots.size():
			continue
		var a: Dictionary = tshots[i]
		a.t += dt
		var done = false
		if a.kind in ["bullet", "energy", "dbullet", "shard"]:
			var tg = a.tgt
			if tg != null and tg.state != "dead":
				var ang = atan2((tg.y - tg.h * 0.5) - a.y, tg.x - a.x)
				var cur = atan2(a.vy, a.vx)
				var sp = Vector2(a.vx, a.vy).length()
				var hm: float = 8 * a.homing
				var na = cur + clampf(angDiff(cur, ang), -dt * hm, dt * hm)
				a.vx = cos(na) * sp
				a.vy = sin(na) * sp
			a.x += a.vx * dt
			a.y += a.vy * dt
			if a.kind == "energy" and randf() < 0.6:
				part(a.x, a.y, 0, 0, 0.15, "#9fe6ff" if randf() < 0.5 else "#ffffff", 0, 1)
			done = a.t > a.life or a.x < 0 or a.x > M.w or a.y > M.h + 10
			if not done and a.vy > 0 and a.y > groundAt(a.x) + 1 and a.tgt == null:
				done = true
				for k in 3:
					part(a.x, a.y - 1, rand(-40, 40), rand(-70, -20), 0.25, "#ffe9a0", 300, 1)
			if not done:
				for e in slimes:
					if e.state == "dead" or e.spawnT > 0 or a.hit.has(e):
						continue
					var b = sBox(e)
					if a.x > b.x0 - 3 and a.x < b.x1 + 3 and a.y > b.y0 - 3 and a.y < b.y1 + 3:
						a.hit[e] = true
						var mv = {"dmg": a.dmg, "kb": 35 if a.kind != "shard" else 20, "up": -40, "style": 6 if a.own else 3, "anim": "t_gun", "both": true}
						damageSlime(e, mv)
						sparks(a.x, a.y, "#9fe6ff" if a.kind == "energy" else "#fff2a0", 4)
						if a.own:
							P.en = minf(PS.enMax, P.en + PS.enHit)
							if buffOn("teslaRounds"):
								_tesla(e, a.dmg * (0.4 + 0.02 * skillRank("teslaRounds")))
						a.pierce -= 1
						if a.pierce < 0:
							done = true
							break
		else:
			# grenades, shells and missiles
			if a.kind == "missile":
				var tg = a.tgt
				if tg == null or tg.state == "dead":
					tg = nearestFoe(a.x, a.y, 220)
					a.tgt = tg
				var sp = minf(430, Vector2(a.vx, a.vy).length() + 700 * dt)
				var cur = atan2(a.vy, a.vx)
				var want = cur
				if tg != null:
					want = atan2((tg.y - tg.h * 0.5) - a.y, tg.x - a.x)
				var na = cur + clampf(angDiff(cur, want), -dt * 7, dt * 7)
				a.vx = cos(na) * sp
				a.vy = sin(na) * sp
				if randf() < 0.8:
					part(a.x - a.vx * 0.02, a.y - a.vy * 0.02, rand(-10, 10), rand(-20, -5), rand(0.25, 0.5), "#c8c8d0" if randf() < 0.6 else "#ffb03a", -20, 2)
			else:
				a.vy += (380.0 if a.kind == "shell" else NADE_G) * dt
				a.spin += dt * 14 * sgn(a.vx)
			var py = a.y
			a.x += a.vx * dt
			a.y += a.vy * dt
			if a.kind == "shell" and randf() < 0.5:
				part(a.x, a.y, 0, -10, 0.25, "#d8d8e0", 0, 1)
			# bounce off the ground (a missile or shell goes off instead)
			for s in surfaces:
				if a.vy > 0 and a.x > s.x0 and a.x < s.x1 and py <= s.y and a.y >= s.y and (s.floor or a.vy > 0):
					if a.kind != "nade":
						done = true
					else:
						a.y = s.y - 1
						a.vy *= -0.35
						a.vx *= 0.55
						a.bounce += 1
						if absf(a.vy) < 40:
							a.vy = 0
						Sfx.tone(300, 0.04, "square", 0.03, 200)
					break
			if a.x < 0 or a.x > M.w or a.y > M.h + 20:
				done = true
			if a.t > a.life:
				done = true
			if not done:
				for e in slimes:
					if e.state == "dead" or e.spawnT > 0 or e.bossEye:
						continue
					var b = sBox(e)
					if a.x > b.x0 - 2 and a.x < b.x1 + 2 and a.y > b.y0 - 2 and a.y < b.y1 + 2:
						done = true
						break
			if done:
				tshots.erase(a)
				tankBoom(a.x, a.y, a.R, a.dmg, a.nt, a.small)
				continue
		if done:
			tshots.erase(a)


func _tesla(src, dmg: float) -> void:
	var best = null
	var bd = 90.0
	for e in slimes:
		if e == src or e.state == "dead" or e.bossEye:
			continue
		var d = Vector2(e.x - src.x, e.y - src.y).length()
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	tfx.append({"type": "zap", "x": src.x, "y": src.y - src.h * 0.5, "x2": best.x, "y2": best.y - best.h * 0.5, "t": 0.0, "life": 0.18, "seed": randf() * 50})
	damageSlime(best, {"dmg": dmg, "kb": 10, "up": -20, "style": 4, "anim": "t_tesla", "both": true})


## an explosion: everything in the blast takes the hit, plus what the grenade type adds
func tankBoom(x: float, y: float, R: float, dmg: float, nt := "frag", small := false) -> void:
	if nt == "energy":
		R *= 1.3
		dmg *= 1.15
	var hit = []
	for e in slimes.duplicate():
		if e.state == "dead" or e.spawnT > 0 or e.bossEye:
			continue
		var b = sBox(e)
		var cx = clampf(x, b.x0, b.x1)
		var cy = clampf(y, b.y0, b.y1)
		if Vector2(cx - x, cy - y).length() > R:
			continue
		hit.append(e)
		var m = dmg * (1.6 if nt == "emp" and e.T.get("metal") else 1.0)
		damageSlime(e, {"dmg": m, "kb": 60 if small else 150, "up": -120 if small else -220, "style": 6 if small else 12, "anim": "t_boom", "both": true, "heavy": not small})
		if e.state != "dead" and not e.boss:
			if nt == "cryo":
				e.slowT = maxf(e.slowT, 3.0)
				e.stun = maxf(e.stun, 1.5)
				e.vx = 0
			elif nt == "emp":
				e.stun = maxf(e.stun, 2.0)
			elif nt == "napalm":
				e.burnT = maxf(e.burnT, 3.0)
	tfx.append({"type": "boom", "x": x, "y": y, "r": R, "t": 0.0, "life": 0.45, "nt": nt, "small": small})
	match nt:
		"napalm":
			tfx.append({"type": "fire", "x": x, "y": groundAt(x), "w": R * 1.4, "t": 0.0, "life": 3.5, "tick": 0.0})
		"shrapnel":
			for k in 8:
				var ang = -PI * (k + 0.5) / 8.0
				var s = {"kind": "shard", "x": x, "y": y - 4, "vx": cos(ang) * 330, "vy": sin(ang) * 330, "t": 0.0, "life": 0.3, "tgt": null, "hit": {},
					"pierce": 0, "dmg": dmg * 0.25, "own": false, "homing": 0.0}
				tshots.append(s)
		"cluster":
			if not small:
				for k in 3:
					var g = _nade(x, y - 6, (k - 1) * 110.0 + rand(-20, 20), rand(-260, -200), dmg * 0.4, R * 0.6, "frag", rand(0.45, 0.6))
					g.small = true
		"energy":
			if hit.size():
				_tesla(hit[0], dmg * 0.5)
		"emp":
			if hit.size():
				P.en = minf(PS.enMax, P.en + 6)
	if not small:
		shake = maxf(shake, 1.5 + R * 0.02)   # a little rumble, not a quake
		hitstop = maxf(hitstop, 0.04)
		Sfx.slam()
	Sfx.tone(70 if not small else 110, 0.35 if not small else 0.2, "sawtooth", 0.09 if not small else 0.05, 30)
	var cols = {"cryo": ["#e8fbff", "#9fe6ff"], "emp": ["#fff36a", "#bfe8ff"], "energy": ["#6fd8ff", "#ffffff"], "napalm": ["#ff6a2a", "#ffd23a"]}.get(nt, ["#ffb03a", "#ffe9a0"])
	for k in (8 if small else 18):
		part(x, y - 4, rand(-160, 160), rand(-260, -40), rand(0.3, 0.6), cols[k % 2], 500, 2 if k % 3 else 1)
	for k in (2 if small else 6):
		part(x + rand(-R * 0.5, R * 0.5), y - rand(0, R * 0.6), rand(-20, 20), rand(-40, -15), rand(0.6, 1.1), "rgba(90,90,100,0.7)", -10, 3)


# ================================================================ the exosuit: dodges, the shoulder slam, gliding and flight

func tankDodge(dirIn: int) -> void:
	var a = armorT()
	if a < 2:
		# work clothes or just the boots: an ordinary dodge (the boots puff a little flame)
		if not P.grounded and P.airDash > 0:
			return
		if P.state == "dash" and P.dashT < 0.22:
			return
		if not P.grounded:
			P.airDash = 1
		P.state = "dash"; P.dashT = 0.0; P.face = dirIn if dirIn else P.face
		P.vx = P.face * 320.0
		if not P.grounded:
			P.vy = minf(P.vy, -40)
		P.iframes = 0.26
		P.dodged.clear()
		setAnim("dash")
		Sfx.dodge()
		if a >= 1:
			_thrust(6)
		return
	# Servo Legs: rocket bursts from the boots and legs, twice as far as a dodge, two in a row at most —
	# forward twice, or forward and back. Anything you blast through takes a light hit. With the Chest &
	# Arms rig the second burst is a shoulder slam.
	if TK.burstN >= 2 or (P.state == "dash" and P.dashT < 0.06):
		return
	var dir: int = dirIn if dirIn else P.face
	TK.burstN += 1
	TK.burstT = 0.0
	TK.burstHit = {}
	P.state = "dash"; P.dashT = 0.0; P.face = dir
	P.vx = dir * 640.0 * (1.1 if a >= 6 else 1.0)
	if not P.grounded:
		P.vy = minf(P.vy, -30)
	P.iframes = 0.3
	P.dodged.clear()
	setAnim("dash")
	TK.slam = a >= 3 and TK.burstN == 2
	if TK.slam:
		TK.slamHit = {}
		TK.slamV = 560.0
		Sfx.whoosh(0.7, true)
		Sfx.tone(90, 0.3, "sawtooth", 0.07, 50)
		floatText(P.x, P.y - 58, "Shoulder Slam!", "call")
	else:
		Sfx.dodge()
	Sfx.tone(140, 0.18, "sawtooth", 0.05, 60)
	_thrust(16)
	_legFlames(8)
	if TK.burstN == 2:
		styleAdd(6, "dash2")


## rocket flame from the boots and the leg servos
func _legFlames(n: int) -> void:
	for i in n:
		var hy = P.y - (rand(0, 3) if i % 2 == 0 else rand(10, 16))
		part(P.x - P.face * rand(2, 7), hy, -P.face * rand(60, 160) + P.vx * 0.1, rand(-25, 25), rand(0.12, 0.3), "#ffb03a" if i % 3 else ("#6fd8ff" if armorT() >= 6 else "#fff3b0"), 0, 2)


func _thrust(n: int) -> void:
	for i in n:
		part(P.x - P.face * rand(4, 10), P.y - rand(0, 4), -P.face * rand(40, 120), rand(-30, 30), rand(0.15, 0.35), "#ffb03a" if i % 3 else "#fff3b0", 0, 2)


## the suit's movement, run every frame before physics
func tankMove(dt: float, _dirIn: int, _up: bool, down: bool) -> void:
	if not isTank():
		return
	var a = armorT()
	if P.state != "attack":
		TK.q = ""
	if P.state != "dash":
		TK.slam = false
	TK.burstT += dt
	var wetNow = inWater()
	if P.grounded or wetNow:
		TK.glided = false
		TK.airNadeN = 0
		if P.state != "dash" and TK.burstT > 0.35:
			TK.burstN = 0   # both bursts recharge once you're back on your feet
	# a rocket burst: flames all the way, and a light hit on anything you pass through
	if P.state == "dash" and TK.burstN > 0 and a >= 2:
		if randf() < 0.9:
			_legFlames(2)
		if not TK.slam and P.dashT < 0.22:
			var bb = hbox(P.x - 10, P.x + 10, P.y - 34, P.y)
			for e in slimes:
				if e.state == "dead" or e.bossEye or e.spawnT > 0 or TK.burstHit.has(e) or not overlap(bb, sBox(e)):
					continue
				TK.burstHit[e] = true
				damageSlime(e, {"dmg": 0.45, "kb": 60, "up": -80, "style": 6, "anim": "t_burst", "both": true})
				sparks(e.x, e.y - e.h * 0.5, "#ffb03a", 4)
	# the rocket shoulder slam: carried by the boots, driven by the arms
	if TK.slam and P.state == "dash":
		P.vx = P.face * TK.slamV * maxf(0.3, 1 - P.dashT * 1.6)
		if randf() < 0.8:
			_thrust(2)
		var box = hbox(P.x - 6 + P.face * 10, P.x + 6 + P.face * 16, P.y - 40, P.y)
		for e in slimes:
			if e.state == "dead" or e.bossEye or TK.slamHit.has(e) or not overlap(box, sBox(e)):
				continue
			TK.slamHit[e] = true
			damageSlime(e, {"dmg": 3.3 if a >= 7 else 2.2, "kb": 340, "up": -220, "style": 24, "anim": "t_slam", "heavy": true})
			hitstop = maxf(hitstop, 0.08)
			shake = maxf(shake, 4)
			if a >= 7:
				tankBoom(e.x, e.y - 8, 46, 1.0, "frag", true)
	# the servo legs at work: flames from the legs while sprinting or sliding
	if a >= 2 and P.grounded and (P.state == "slide" or (P.state == "move" and absf(P.vx) > 120)) and randf() < (0.8 if P.state == "slide" else 0.35):
		_legFlames(1)
	TK.glide = false
	TK.fly = false
	if P.grounded or wetNow or P.state in ["climb", "dead", "knocked", "tumble", "plunge"]:
		return
	var holding: bool = K.get(" ", false)
	if a >= 9 and holding and P.jumps >= 1:
		# the mecha suit flies
		TK.fly = true
		P.vy = damp(P.vy, -150.0 if not down else 120.0, 5, dt) - GRAV * dt  # cancels the gravity physics adds next
		if randf() < dt * 30:
			part(P.x - P.face * 3, P.y + 1, rand(-15, 15), rand(60, 120), rand(0.2, 0.35), "#ffb03a" if randf() < 0.6 else "#6fd8ff", 0, 2)
	elif a >= 1 and holding and P.vy > 0 and P.state == "move":
		# gliding only while you're not attacking — and once you've glided, attacks stop holding you up
		TK.glide = true
		TK.glided = true
		P.vy = minf(P.vy, 32.0 if a >= 5 else 55.0)
		if randf() < dt * 22:
			part(P.x + rand(-3, 3), P.y + 1, rand(-10, 10), rand(40, 90), rand(0.15, 0.3), "#ffb03a" if randf() < 0.6 else "#fff3b0", 0, 1)


func airLift() -> bool:
	if isTank() and TK.glided:
		P.airAtk += 1
		return false
	return super.airLift()


## the servo legs: faster, longer slides
func slideSpeed() -> float:
	return 1.35 if isTank() and armorT() >= 2 else 1.0


func slideLength() -> float:
	return 1.5 if isTank() and armorT() >= 2 else 1.0   # with the faster start, about twice the distance


func hurtPlayer(src, dmg: float) -> void:
	var before = P.hurtN
	super.hurtPlayer(src, dmg)
	if isTank() and buffOn("staticShield") and P.hurtN > before and src is S.Mob and src.state != "dead" and not src.bossEye:
		tfx.append({"type": "zap", "x": P.x, "y": P.y - 24, "x2": src.x, "y2": src.y - src.h * 0.5, "t": 0.0, "life": 0.2, "seed": randf() * 50})
		damageSlime(src, {"dmg": 0.8, "kb": 120, "up": -80, "style": 4, "anim": "t_static", "both": true})


# ================================================================ weak points (the Diagnostic Helmet)

func weakEvery() -> float:
	var a = armorT()
	return WEAK_EVERY[2 if a >= 9 else (1 if a >= 8 else 0)]


## the Diagnostic Helmet finds one weak point at a time, on any monster or boss in view, about once a
## minute (less with each helmet upgrade). Hitting it is a super crit; then the helmet starts scanning again.
func tankWeakHit(e) -> bool:
	if not isTank() or armorT() < 4 or e != TK.weakOn:
		return false
	TK.weakOn = null
	TK.weak.clear()
	TK.weakCd = weakEvery()
	floatText(e.x, e.y - e.h - 18, "SUPER CRIT!", "crit")
	sparks(e.x, e.y - e.h * 0.5, "#ff3a3a", 14)
	Sfx.tone(1500, 0.08, "square", 0.06, 2200)
	return true


func updateWeak(dt: float) -> void:
	if armorT() < 4:
		TK.weak.clear()
		TK.weakOn = null
		return
	var on = TK.weakOn
	if on != null and (not is_instance_valid(on) or on.state == "dead" or not slimes.has(on)):
		TK.weakOn = null
		TK.weak.clear()
		TK.weakCd = minf(TK.weakCd, 3.0)   # it died before you found the spot: the helmet looks again shortly
		on = null
	if on != null:
		return
	TK.weakCd -= dt
	if TK.weakCd > 0:
		return
	var best = null
	var bd = 1e9
	for e in slimes:
		if e.state == "dead" or e.bossEye or e.bossPart or e.spawnT > 0 or absf(e.x - P.x) > VW * 0.55 or absf(e.y - P.y) > VH * 0.6:
			continue
		var d = absf(e.x - P.x) + absf(e.y - P.y) - (400.0 if e.boss else 0.0)   # bosses first
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	TK.weakOn = best
	TK.weak = {best: {"ox": rand(-0.25, 0.25), "oy": rand(0.35, 0.75), "cd": 0.0}}
	floatText(best.x, best.y - best.h - 14, "Weak point!", "call")
	Sfx.tone(1200, 0.1, "square", 0.04, 1800)


# ================================================================ the drone, turrets, the bot

func droneFire(tgt, burst := false) -> void:
	var tier = droneTier()
	if tier <= 0:
		return
	var Dt: Dictionary = DRONES[tier]
	var D2 = TK.drone
	if tgt == null:
		return
	var n = 2 if Dt.get("twin") else 1
	if buffOn("swarmProtocol"):
		n += 2
	for i in n:
		var b = spawnBullet(D2.x + (i - (n - 1) / 2.0) * 5, D2.y + 2, tgt, "fwd", Dt.dmg * (0.7 if burst else 1.0), "energy" if Dt.get("energy") else "dbullet", (i - (n - 1) / 2.0) * 0.06, false, 2.0)
		b.life = 0.7
	D2.flash = 0.08
	Sfx.tone(rand(1300, 1500), 0.04, "square", 0.025, 700)


func updateDrone(dt: float) -> void:
	var D2 = TK.drone
	var tier = droneTier()
	var tx = P.x - P.face * 14
	var ty = P.y - 52 + sin(gameTime * 3) * 3
	D2.x = damp(D2.x, tx, 6, dt) if absf(D2.x - tx) < 300 else tx
	D2.y = damp(D2.y, ty, 6, dt) if absf(D2.y - ty) < 300 else ty
	D2.t += dt
	D2.flash = maxf(0, D2.flash - dt)
	if tier <= 0 or P.state == "dead" or M.get("indoor") or M.get("safe"):
		return
	D2.cd -= dt * (2.0 if buffOn("swarmProtocol") else 1.0)
	if D2.cd <= 0:
		var tgt = nearestFoe(D2.x, D2.y + 30, 170)
		if tgt != null:
			droneFire(tgt)
			D2.cd = DRONES[tier].rate
		else:
			D2.cd = 0.3


func updateTurrets(dt: float) -> void:
	var L: Array = TK.turrets
	for i in range(L.size() - 1, -1, -1):
		var T2: Dictionary = L[i]
		T2.t += dt
		T2.cd -= dt
		if T2.t > T2.life:
			L.remove_at(i)
			sparks(T2.x, T2.y - 6, "#d8d8e0", 8)
			continue
		if T2.cd <= 0:
			var tgt = nearestFoe(T2.x, T2.y - 10, 180)
			if tgt != null:
				T2.face = 1 if tgt.x > T2.x else -1
				var b = spawnBullet(T2.x + T2.face * 8, T2.y - 11, tgt, "fwd", T2.dmg, "dbullet", 0, false, 2.0)
				b.life = 0.6
				T2.flash = 0.06
				T2.cd = 0.45
				Sfx.tone(rand(900, 1000), 0.04, "square", 0.025, 400)
			else:
				T2.cd = 0.25
		T2.flash = maxf(0, T2.get("flash", 0.0) - dt)


func updateBot(dt: float) -> void:
	if not (isTank() and buffOn("buildBot")):
		if TK.bot != null:
			for k in 12:
				part(TK.bot.x, TK.bot.y - rand(0, 24), rand(-60, 60), rand(-120, -40), 0.5, "#d8d8e0", 300, 2)
			TK.bot = null
		return
	if TK.bot == null:
		TK.bot = {"x": P.x - P.face * 20, "y": groundAt(P.x), "face": P.face, "state": "walk", "t": 0.0, "cd": 0.5, "anim": "idle", "at": 0.0}
		for k in 16:
			part(P.x - P.face * 20, P.y - rand(0, 24), rand(-60, 60), rand(-120, -40), 0.5, "#ffc83d", 300, 2)
		Sfx.tone(300, 0.2, "square", 0.05, 600)
	var B2 = TK.bot
	B2.t += dt
	B2.cd -= dt
	var tgt = nearestFoe(P.x, P.y - 10, 220)
	var gx: float = P.x - P.face * 26
	if tgt != null:
		gx = tgt.x - sgn(tgt.x - B2.x) * 16
	var dx = gx - B2.x
	if B2.at > 0:
		B2.at -= dt
		B2.anim = "attack"
	elif absf(dx) > 6:
		B2.x += sgn(dx) * minf(absf(dx), (130.0 if tgt != null else 110.0) * dt)
		B2.face = 1 if dx > 0 else -1
		B2.anim = "walk"
	else:
		B2.anim = "idle"
	B2.y = groundAt(B2.x)
	if tgt != null and absf(tgt.x - B2.x) < 30 and absf(tgt.y - B2.y) < 40 and B2.cd <= 0:
		B2.face = 1 if tgt.x > B2.x else -1
		B2.cd = 0.8
		B2.at = 0.35
		var r = skillRank("buildBot")
		later(0.12, func():
			if tgt.state != "dead":
				damageSlime(tgt, {"dmg": 1.2 + r * 0.08, "kb": 140, "up": -140, "style": 6, "anim": "t_bot", "both": true})
				sparks(tgt.x, tgt.y - tgt.h * 0.5, "#ffc83d", 6))


func botTier() -> int:
	var r = skillRank("buildBot")
	return 2 if r >= 12 else (1 if r >= 6 else 0)


# ================================================================ skills

func skillHit(mv: Dictionary, f: int) -> void:
	if mv.skill.get("cls", "") != "tank":
		super.skillHit(mv, f)
		return
	tankSkillHit(mv, mv.skill, _alive(P.skillTargets), f)


func tankSkillHit(mv: Dictionary, s: Dictionary, list: Array, f: int) -> void:
	var sfx: String = s.get("fx", "")
	var dmg: float = mv.dmg
	var face = P.face
	match sfx:
		"turret":
			TK.turrets = [{"x": P.x + face * 22, "y": groundAt(P.x + face * 22), "t": 0.0, "life": 8.0, "cd": 0.4, "dmg": dmg, "face": face, "flash": 0.0}]
			dust(P.x + face * 22, groundAt(P.x + face * 22), 6)
			Sfx.tone(220, 0.15, "square", 0.05, 440)
		"strafe":
			# a flight of drones sweeps past, raking the ground below them with gunfire
			tfx.append({"type": "strafer", "x": P.x - face * 240, "y": P.y - 80, "vx": face * 360.0, "t": 0.0, "life": 1.4, "n": 3, "napalm": false,
				"dmg": dmg, "tick": 0.0, "hit": {}})
			Sfx.tone(260, 0.5, "sawtooth", 0.04, 520)
		"napalm":
			tfx.append({"type": "strafer", "x": P.x - face * 220, "y": P.y - 90, "vx": face * 320.0, "t": 0.0, "life": 1.5, "n": 3, "napalm": true})
			var k = 0
			for e in list:
				var ex = e.x
				later(0.25 + k * 0.08, func():
					var g = _nade(ex + rand(-6, 6), P.y - 90, face * 20.0, 120.0, dmg, 30.0 * (1 + 0.03 * skillRank("demolitions")), "napalm", 2.0)
					g.small = false)
				k += 1
		"missiles":
			for e in list:
				var m = _nade(e.x + rand(-40, 40), e.y - 200 - randf() * 40, rand(-30, 30), 260.0, dmg, 28.0, "frag", 2.0, "missile")
				m.tgt = e
			Sfx.tone(160, 0.3, "sawtooth", 0.06, 90)
		"laser":
			_lasers(list, dmg)
		"armageddon":
			if f % 2 == 0:
				for e in list:
					var m = _nade(e.x + rand(-50, 50), e.y - 210 - randf() * 50, rand(-30, 30), 280.0, dmg, 32.0, "energy" if f == 4 else "frag", 2.0, "missile")
					m.tgt = e
			else:
				_lasers(list, dmg)
			shake = maxf(shake, 3)
	hitstop = maxf(hitstop, 0.03)


## the strafing run's guns: every few hundredths of a second each drone puts a round into the ground
## just ahead of it, and anything standing in the line of fire is hit
func _strafeFire(f: Dictionary, dt: float) -> void:
	f.tick -= dt
	if f.tick > 0:
		return
	f.tick = 0.045
	var dir = sgn(f.vx)
	for i in f.n:
		var dx: float = f.x - dir * i * 22
		var dy: float = f.y + i * 9
		var gx: float = dx + dir * rand(8, 36)
		var gy: float = _floorBelow(gx, dy)
		tfx.append({"type": "tracer", "x": dx, "y": dy + 3, "x2": gx, "y2": gy, "t": 0.0, "life": 0.07})
		part(gx, gy - 1, rand(-30, 30), rand(-90, -30), 0.25, "#ffe9a0" if randf() < 0.5 else "#a89880", 400, 1)
		for e in slimes:
			if e.state == "dead" or e.bossEye or e.spawnT > 0 or absf(e.x - gx) > e.w * 0.5 + 8 or e.y < dy or e.y - e.h > gy + 2:
				continue
			if float(f.hit.get(e, -1.0)) > f.t:
				continue
			f.hit[e] = f.t + 0.12
			damageSlime(e, {"dmg": f.dmg * 0.3, "kb": 20, "up": -40, "style": 3, "anim": "t_strafe", "both": true})
	if randf() < 0.5:
		Sfx.tone(rand(900, 1100), 0.03, "square", 0.025, 500)


## the first floor or platform under (x, y)
func _floorBelow(x: float, y: float) -> float:
	var best: float = groundAt(x)
	for q in surfaces:
		if not q.get("water", false) and x >= q.x0 and x <= q.x1 and q.y >= y and q.y < best:
			best = q.y
	return best


func _lasers(list: Array, dmg: float) -> void:
	for e in list:
		tfx.append({"type": "laser", "x": e.x, "y": e.y, "t": 0.0, "life": 0.35})
		damageSlime(e, {"dmg": dmg, "kb": 30, "up": -60, "style": 8, "anim": "t_laser", "both": true, "heavy": true})
	World.flash = maxf(World.flash, 0.25)
	shake = maxf(shake, 2)
	Sfx.tone(900, 0.3, "sawtooth", 0.06, 200)


# ================================================================ components

func killSlime(e) -> void:
	var alive = e.state != "dead"
	super.killSlime(e)
	if alive and isTank():
		tankDrops(e)


func tankDrops(e) -> void:
	var sense = 1 + 0.06 * skillRank("scrapSense")
	var mul = (3 if e.shiny else 1) * (3 if e.elite else 1)
	var got = {}
	if randf() < 0.75 * sense:
		got.scrap = rint(1, 2) + (2 if e.T.get("metal") else 0)
	if randf() < 0.35 * sense:
		got.wire = 1
	if randf() < (0.08 + e.lv * 0.002) * sense:
		got.circuit = 1
	if randf() < 0.012 * sense or e.elite:
		got.core = 1
	if e.boss:
		got = {"scrap": rint(20, 30), "wire": rint(10, 15), "circuit": rint(4, 8), "core": rint(2, 4)}
		mul = 1
	for k in got:
		var n = got[k] * mul
		var pieces = mini(n, 4)
		for p in pieces:
			var v = n / pieces + (1 if p < n % pieces else 0)
			var d = S.Drop.new()
			d.kind = "part"; d.type = k
			d.x = e.x; d.y = e.y - 8; d.vx = rand(-60, 60); d.vy = rand(-240, -150); d.val = v
			var sy = e.surf.y if e.surf != null else groundAt(e.x)
			d.surfY = sy
			d.x0 = (e.surf.x0 + 4) if e.surf != null else 24.0
			d.x1 = (e.surf.x1 - 4) if e.surf != null else M.w - 24.0
			d.spin = randf() * 4
			drops.append(d)


func tankPickup(d) -> void:
	if not save.has("parts"):
		save.parts = {}
	save.parts[d.type] = partCount(d.type) + d.val
	Sfx.tone(700, 0.05, "square", 0.04, 1100)
	pickupPop("p_" + d.type, PART_INFO[d.type].name, d.val, PART_INFO[d.type].col)


# ================================================================ home: the box, the meteor, the house

func configureHome(cls: String) -> void:
	super.configureHome(cls)
	if cls == "tank" and houseBuilt():
		MAPS.home.portals.append({"x": 560, "to": "house", "tx": 60, "label": "Enter the workshop", "door": true})
		MAPS.house.portals[0].tx = 560


func meteorDone() -> bool:
	return tb2(save.chars.get("tank", {}).get("meteorDone", false))


func updateMeteor(dt: float) -> void:
	if not isTank() or mapId != "home":
		return
	var Mt = TK.meteor
	if Mt == null:
		if not meteorDone() and absf(P.x - 560) < 70 and P.grounded:
			TK.meteor = {"t": 0.0, "hit": false, "scan": false, "cut": false}
			P.frozen = true
			P.vx = 0
			P.state = "move"
			setAnim("idle")
			P.face = 1 if P.x < 560 else -1
			Sfx.tone(60, 1.4, "sawtooth", 0.06, 120)
		return
	Mt.t += dt
	if Mt.t < 1.5:
		shake = maxf(shake, Mt.t * 2)
	if not Mt.hit and Mt.t >= 1.5:
		Mt.hit = true
		shake = 16
		World.flash = maxf(World.flash, 0.9)
		hitstop = 0.1
		Sfx.slam()
		Sfx.tone(40, 1.2, "sawtooth", 0.14, 20)
		for k in 50:
			part(560 + rand(-10, 10), M.floorY - 4, rand(-260, 260), rand(-380, -80), rand(0.6, 1.4), ["#ffb03a", "#ff6a2a", "#8a6a4a", "#c8a070"][k % 4], 600, 2 if k % 2 else 3)
		for k in 14:
			part(560 + rand(-30, 30), M.floorY - rand(0, 30), rand(-30, 30), rand(-50, -15), rand(1.2, 2.2), "rgba(80,70,70,0.7)", -8, 4)
		P.vx = -P.face * 160
		P.vy = -120
		P.grounded = false
	if Mt.t >= 2.6 and not Mt.scan:
		Mt.scan = true
		thought = {"text": "...", "t": 1.6}
		Sfx.tone(880, 0.6, "sine", 0.04, 440)
	if Mt.t >= 4.2 and Mt.scan and Mt.t < 4.3:
		thought = {"text": "Scanning debris. Tracing origin...", "t": 2.2}
	if Mt.t >= 6.6 and not Mt.cut:
		Mt.cut = true
		tankCutscene([
			{"kind": "t_glamrax", "title": false, "text": "The trail leads across the land, to the Abyss Volcano. There, Glamrax glares into his scrying glass, displeased. His assassination attempt has failed."},
			{"kind": "volcano", "title": true, "text": "The Abyss Volcano"},
		], func():
			save.chars.tank.meteorDone = true
			saveDirty = true
			TK.meteor = null
			P.frozen = false
			banner("Revenge", "Glamrax tried to kill you. Find him at the Abyss Volcano.")
			persist())


func tankCutscene(_scenes: Array, _done: Callable) -> void: pass


# ================================================================ the Dreamer's last secret

func dreamerFalls(e, firstKill: bool) -> void:
	super.dreamerFalls(e, firstKill)
	if firstKill:
		later(4.0, func(): banner("Something escaped its dream...", "A new hero waits on the character select screen."))


# ================================================================ every frame

func updateTank(dt: float) -> void:
	updateMeteor(dt)
	if not isTank():
		if tshots.size() or tfx.size():
			tshots.clear()
			tfx.clear()
		return
	TK.nadeCd = maxf(0, TK.nadeCd - dt)
	TK.aim.t = maxf(0, TK.aim.t - dt)
	if TK.mag < 0 or TK.mag > magSize():
		TK.mag = magSize()
	if TK.reload > 0:
		TK.reload -= dt
		if TK.reload <= 0:
			TK.reload = 0.0
			TK.mag = magSize()
			Sfx.tone(520, 0.05, "square", 0.05, 760)
	else:
		TK.idleT += dt
		if TK.idleT > 2.5 and TK.mag < magSize() and P.state != "attack":
			startReload(true)   # topped up quietly while you're not shooting
	updateTShots(dt)
	updateWeak(dt)
	updateDrone(dt)
	updateTurrets(dt)
	updateBot(dt)
	for i in range(tfx.size() - 1, -1, -1):
		var f: Dictionary = tfx[i]
		f.t += dt
		if f.has("vx"):
			f.x += f.vx * dt
		if f.type == "strafer" and not f.napalm and f.t > 0.1:
			_strafeFire(f, dt)
		if f.type == "fire":
			f.tick -= dt
			if f.tick <= 0:
				f.tick = 0.5
				for e in slimes:
					if e.state != "dead" and not e.bossEye and absf(e.x - f.x) < f.w / 2 and absf(e.y - f.y) < 20:
						e.burnT = maxf(e.burnT, 1.5)
			if randf() < dt * 30:
				part(f.x + rand(-f.w / 2, f.w / 2), f.y - 1, rand(-6, 6), rand(-60, -25), rand(0.3, 0.6), "#ff6a2a" if randf() < 0.5 else "#ffd23a", -30, 2)
		if f.t > f.life:
			tfx.remove_at(i)


func tankOnLoad() -> void:
	tshots.clear()
	tfx.clear()
	TK.weak.clear()
	TK.turrets.clear()
	TK.q = ""
	TK.slam = false
	TK.weakOn = null
	TK.burstN = 0
	TK.drone.x = P.x - P.face * 14
	TK.drone.y = P.y - 52
	if TK.bot != null:
		TK.bot.x = P.x - P.face * 20


func loadMap(id: String, px0 = null, py0 = null) -> void:
	super.loadMap(id, px0, py0)
	tankOnLoad()


# ---------------- drawn in tank_draw.gd
func drawTankBack(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawTankFront(_x: Ctx, _sx: float, _sy: float) -> void: pass
func drawPartDrop(_x: Ctx, _d, _X: float, _Y: float, _tt: float) -> void: pass
func drawTankScene(_x: Ctx, _t: float, _kind: String) -> void: pass
func tankGearCards(_x: float, _y: float, _w: float) -> float: return 0.0   # tank_ui.gd
func workshopCard(_x: float, _y: float, _w: float) -> float: return 0.0
