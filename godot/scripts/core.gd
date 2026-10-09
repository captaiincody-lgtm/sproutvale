extends Node2D
## Sproutvale, part 1 of the game script: shared state, the data tables, saving, stats,
## progression (levels, jobs, skills, charms), quests, cards, drops, particles and messages.
##
## The game is one node whose script is split across files that extend each other:
##   core → world → player → mobs → skills → bosses → render → intro → hud → ui → screens → game
## so every function can call every other one directly, the way the HTML prototype did.
## Names follow the prototype (updatePlayer, damageSlime, P.moveT…) to keep the two easy to compare.

const S := preload("res://scripts/state.gd")
const Ctx := preload("res://scripts/ctx.gd")

const VW := 384
const VH := 216
const GRAV := 950.0
const MAXFALL := 520.0
const ASCEND_LV := 200     # there is no level cap; past this level skill points can go into Ascendency
const ASC_NODE_MAX := 10   # how many ranks one Ascendency node takes
const RES := 2
const SAVE_PATH := "user://sproutvale_save.json"
var SAVE_PATH_OVERRIDE := ""   # tests use a throwaway save

# ---------------------------------------------------------------- data (res://data/game_data.json)
var D: Dictionary
var MAPS: Dictionary
var HOME_VARIANTS: Dictionary
var SLIME_TYPES: Dictionary
var SLIME_KEYS: Array
var MOVES: Dictionary
var AMOVES: Dictionary
var MMOVES: Dictionary
var JMOVES: Dictionary
var ANIM_BY_ID: Dictionary
var CLASSES: Dictionary
var GEAR: Dictionary
var CHARM_TIERS: Array
var ARROW_TIERS: Array
var JOBS_BY: Dictionary
var JOBS: Array
var SKILLS: Array
var SKILL: Dictionary
var SLOT_KEYS: Array
var RANKS: Array
var RANK_MULT: Array
var RANK_CAP := 1800.0
var COSMETICS: Dictionary
var COS_PRICE: Dictionary
var COS_LABEL: Dictionary
var DEFAULT_LOOK: Dictionary
var ABYSS_SHOP: Dictionary
var FURNITURE: Dictionary
var FURN_ORDER: Array
var CURIOS: Array
var BOSS_SHOP: Array
var TROPHIES: Array
var ELEMENTS: Array
var SUMMONS: Array
var STORY: Dictionary
var BOSS_T: Dictionary
var WARLORD_T: Dictionary
var BOSS_LIST: Array
var MAINQS: Array
var BEST_ORDER: Array
var BEST_TEXT: Dictionary
var WM_NODES: Dictionary
var STAT_TIPS: Dictionary
var MAT_TIPS: Dictionary
var CUR_TIPS: Dictionary
var CARD_VAL: Dictionary
var CARD_RATE := 0.01
var GOLD_RATE := 0.0001
var WEATHERS: Dictionary
var W_PARAMS: Dictionary
var PRIMARY: Dictionary
var ATTRS: Dictionary
const CHAIN := ["slash", "rising", "thrust", "spin"]
const AIR_CHAIN := ["air", "air2", "air3"]
const POT := {"max": 3, "recharge": 25.0}
const UNLIMITED := 1000000000

# ---------------------------------------------------------------- world state
var inGame := false
var menuOpen := false
var gameTime := 0.0
var realTime := 0.0
var hitstop := 0.0
var slowmo := 0.0
var shake := 0.0
var fade := 0.0
var fadeTo = null
var M: Dictionary = {}
var mapId := ""
var surfaces: Array = []
var tufts: Array = []
var slimes: Array = []
var drops: Array = []
var parts: Array = []
var floaters: Array = []
var speedLines: Array = []
var footprints: Array = []
var fx: Array = []
var arrows: Array = []
var bossRocks: Array = []
var bossVials: Array = []
var puddles: Array = []
var cam := Vector2.ZERO
var thought = null
var scene = null
var obelisk = null
var obeliskTimer := 40.0
var thrownSword = null
var spawnTimer := 0.0
var slimeUid := 0
var dblTap := ""
var elemIdx := 0
var Buffs := {}          # skill id → seconds left
var Cool := {}           # skill id → seconds of cooldown left
var Water := {"cols": [], "vel": [], "x0": 0.0, "step": 3.0}
var World := {"t": 0.32, "weather": "sunny", "wTimer": 110.0, "cloud": 0.1, "rain": 0.0, "snow": 0.0, "wind": 0.4, "storm": 0.0,
	"snowCover": 0.0, "flash": 0.0, "nextBolt": 6.0, "bolt": null, "ambT": 0.0}
var Style := {"pts": 0.0, "rank": 0, "hits": 0, "timer": 0.0, "last": [], "peak": 0, "sinceHit": 9.0, "popped": 0.0}
var Spirit := {"x": 0.0, "y": 0.0, "t": 0.0, "cd": 0.0}
var ESpirit := {"x": 0.0, "y": 0.0, "t": 0.0, "cd": 0.0, "i": 0}
var Tail := {"pts": [], "seg": 2.9, "n": 8}
var Warlord := {"rain": 0.0, "rainWarn": 0.0, "introDone": false, "tick": 0.0}
var Pets := {"list": {}}
var POPS: Array = []
var loot = null          # an opened boss box being revealed (the world holds still, like a cutscene)
var pVials: Array = []   # Potion Throw: the hero's flying vials…
var pPuddles: Array = [] # …and the toxic puddles they leave
var PRain := {"t": 0.0, "tick": 0.0}   # the hero's own Crimson Rain

# ---------------------------------------------------------------- boss loot
## Crocbox / Crimsonbox: one drops every time its boss falls
const BOXES := {
	"croc": {"name": "Crocbox", "boss": "Doc Croc", "skill": "potionThrow", "items": ["kombucha", "whetstone", "hide", "eyedrops"]},
	"warlord": {"name": "Crimsonbox", "boss": "Crimson Warlord", "skill": "crimsonRain", "items": ["kombucha", "draught", "sigil", "rivet", "glassEye"]},
	"dreamer": {"name": "Dreambox", "boss": "The Dreamer", "skill": "devour", "items": ["draught", "inkDraught", "dreamFang", "barnacle", "pearl"]},
	"kingYeti": {"name": "Yetibox", "boss": "King Yeti", "skill": "swordThrow", "items": ["inkDraught", "yetiMilk", "kingFang", "frostHide", "iceEye"]},
}
const BOX_ITEM_RATE := 0.15   # chance a box holds a stat treasure
const BOX_SKILL_RATE := 0.02  # chance a box holds the boss's skill (until you have it)
## rare treasures that raise a stat for good (per hero, no limit)
const BOONS := {
	"kombucha": {"name": "Rainbow Kombucha", "icon": "🧃", "stat": "hp", "val": 25, "desc": "+25 max HP"},
	"whetstone": {"name": "Croc-Tooth Whetstone", "icon": "🦷", "stat": "atk", "val": 3, "desc": "+3 attack"},
	"hide": {"name": "Scaly Hide Patch", "icon": "🐊", "stat": "def", "val": 2, "desc": "+2 defense"},
	"eyedrops": {"name": "Doc's Eye Drops", "icon": "💧", "stat": "crit", "val": 0.5, "desc": "+0.5% critical rate"},
	"draught": {"name": "Crimson Draught", "icon": "🍷", "stat": "hp", "val": 60, "desc": "+60 max HP"},
	"sigil": {"name": "Warlord's Sigil Shard", "icon": "🔻", "stat": "atk", "val": 6, "desc": "+6 attack"},
	"rivet": {"name": "Bulwark Rivet", "icon": "🔩", "stat": "def", "val": 4, "desc": "+4 defense"},
	"glassEye": {"name": "Warlord's Glass Eye", "icon": "👁️", "stat": "crit", "val": 1.0, "desc": "+1% critical rate"},
	"inkDraught": {"name": "Abyssal Ink Draught", "icon": "🫙", "stat": "hp", "val": 100, "desc": "+100 max HP"},
	"dreamFang": {"name": "Dreamer's Fang", "icon": "🦷", "stat": "atk", "val": 9, "desc": "+9 attack"},
	"barnacle": {"name": "Abyssal Barnacle", "icon": "🐚", "stat": "def", "val": 6, "desc": "+6 defense"},
	"pearl": {"name": "Black Pearl", "icon": "🔮", "stat": "crit", "val": 1.5, "desc": "+1.5% critical rate"},
	"yetiMilk": {"name": "Frostbite Tonic", "icon": "🧊", "stat": "hp", "val": 160, "desc": "+160 max HP"},
	"kingFang": {"name": "King Yeti's Tusk", "icon": "🦣", "stat": "atk", "val": 13, "desc": "+13 attack"},
	"frostHide": {"name": "Frost-Bound Hide", "icon": "🧥", "stat": "def", "val": 9, "desc": "+9 defense"},
	"iceEye": {"name": "Pendant Shard", "icon": "💎", "stat": "crit", "val": 2.0, "desc": "+2% critical rate"},
}
const BOON_ORDER := ["kombucha", "whetstone", "hide", "eyedrops", "draught", "sigil", "rivet", "glassEye", "inkDraught", "dreamFang", "barnacle", "pearl", "yetiMilk", "kingFang", "frostHide", "iceEye"]
## skills learned from a boss: any class can use them once one drops
const BOSS_SKILLS := [
	{"id": "potionThrow", "boss": "croc", "name": "Potion Throw", "icon": "🧪", "type": "active", "max": 1, "cd": 4, "cost": 22,
		"desc": ["Lob one of Doc Croc's poison vials: 250% damage in a splash, then a toxic puddle that hurts enemies standing in it (40% every half second for 3s)"]},
	{"id": "crimsonRain", "boss": "warlord", "name": "Crimson Rain", "icon": "🩸", "type": "active", "max": 1, "cd": 35, "cost": 55,
		"desc": ["Call down the Warlord's blood rain for 5s: every enemy on screen takes 80% damage every half second"]},
	{"id": "devour", "boss": "dreamer", "name": "Abyssal Devour", "icon": "🐙", "type": "active", "max": 1, "cd": 25, "cost": 50,
		"desc": ["Open the Dreamer's maw: suck in the nearest monster, chew it three times for 400% damage each, then spit it out"]},
	{"id": "swordThrow", "boss": "kingYeti", "name": "Impaling Blade", "icon": "🗡️", "type": "active", "max": 1, "cd": 20, "cost": 45,
		"desc": ["Hurl King Yeti's enchanted sword at lightning speed: it impales the first monster in its path for 600% damage, then tears back out for another 400%"]},
]

# ---------------------------------------------------------------- player + save
var P: S.Player = S.Player.new()
var PS: Dictionary = {}          # computed stats
var save: Dictionary = {}
var saveDirty := false
var saveTimer := 0.0
var classId := "rock"

# ---------------------------------------------------------------- input
var K := {}          # held keys, by prototype name ("arrowleft", "z", " "…)
var pressed := {}    # pressed this frame
var lastTap := {}

# ---------------------------------------------------------------- messages shown by the HUD
var bannerMsg := {"big": "", "sub": "", "t": 99.0}
var keyGet := {"item": "", "name": "", "sub": "", "t": 99.0}   # a key item just picked up: shown big and lit
var comboMsg := {"html": "", "big": "", "sub": "", "t": 99.0}
var toasts: Array = []
var vignette := 0.0
var enShake := 0.0
var _timers: Array = []          # [time left, Callable] — the prototype's setTimeout


# ================================================================ data

func init_data() -> void:
	D = normalize(Assets.data)
	MAPS = D.maps.duplicate(true)
	HOME_VARIANTS = D.homeVariants
	SLIME_TYPES = D.mobs
	SLIME_KEYS = SLIME_TYPES.keys()
	MOVES = D.moves
	AMOVES = D.amoves
	MMOVES = D.mmoves
	JMOVES = D.jmoves
	ANIM_BY_ID = D.anims
	CLASSES = D.classes
	GEAR = D.gear
	CHARM_TIERS = D.charms
	ARROW_TIERS = GEAR.archer.arrows
	JOBS_BY = D.jobs
	JOBS = JOBS_BY.rock
	SKILLS = D.skills
	SKILL = {}
	for s in SKILLS:
		SKILL[s.id] = s
	for s in BOSS_SKILLS:
		SKILL[s.id] = s
	SLOT_KEYS = D.slotKeys
	RANKS = D.ranks
	RANK_MULT = D.rankMult
	RANK_CAP = D.rankCap
	COSMETICS = D.cosmetics
	COS_PRICE = D.cosPrice
	COS_LABEL = D.cosLabel
	DEFAULT_LOOK = D.defaultLook
	ABYSS_SHOP = D.abyssShop
	FURNITURE = D.furniture
	FURN_ORDER = D.furnOrder
	CURIOS = D.curios
	BOSS_SHOP = D.bossShop
	# the Boss and Abyssal shops have no cap: every boost can be bought again and again (each costs a little more)
	for it in BOSS_SHOP:
		it.max = UNLIMITED
	for kind in ABYSS_SHOP:
		for it in ABYSS_SHOP[kind]:
			it.max = UNLIMITED
	TROPHIES = D.trophies
	ELEMENTS = D.elements
	SUMMONS = D.summons
	STORY = D.story
	BOSS_T = D.bossT
	WARLORD_T = D.warlordT
	BOSS_LIST = D.bossList
	MAINQS = D.mainQuests
	BEST_ORDER = D.bestOrder
	BEST_TEXT = D.bestText
	WM_NODES = D.wmNodes
	STAT_TIPS = D.statTips
	MAT_TIPS = D.matTips
	CUR_TIPS = D.curTips
	CARD_VAL = D.cardVal
	CARD_RATE = D.cardRate
	GOLD_RATE = D.goldRate
	WEATHERS = D.weathers
	W_PARAMS = D.wParams
	PRIMARY = D.primary
	ATTRS = D.attrs
	CUR_TIPS.boss = "Boss Coins: 1–5 in every Crocbox, Crimsonbox, Dreambox and Yetibox. Spend them in the Boss Shop."
	initAbyssData()
	initTankData()
	initClimbData()
	initVolcanoData()
	STAT_TIPS["Boss Coins"] = "Found in the boxes bosses drop (1–5 each). Spend them in the Boss Shop."


## JSON numbers arrive as floats; whole numbers become ints so they index arrays and print cleanly.
static func normalize(v):
	if v is Dictionary:
		var o = {}
		for k in v:
			o[k] = normalize(v[k])
		return o
	if v is Array:
		var a = []
		for x in v:
			a.append(normalize(x))
		return a
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	return v


# ================================================================ small helpers (the prototype's core)

static func rand(a: float, b: float) -> float:
	return a + randf() * (b - a)


static func rint(a: int, b: int) -> int:
	return floori(rand(a, b + 1))


static func damp(a: float, b: float, k: float, dt: float) -> float:
	return lerpf(a, b, 1 - exp(-k * dt))


static func easeS(t: float) -> float:
	t = clampf(t, 0, 1)
	return t * t * (3 - 2 * t)


static func easeOut(t: float) -> float:
	t = clampf(t, 0, 1)
	return 1 - (1 - t) * (1 - t) * (1 - t)


static func easeIn(t: float) -> float:
	t = clampf(t, 0, 1)
	return t * t * t


static func angDiff(a: float, b: float) -> float:
	var d = fmod(b - a, TAU)
	if d > PI:
		d -= TAU
	if d < -PI:
		d += TAU
	return d


static func hsh(n: float) -> float:
	var s = sin(n * 127.1) * 43758.5453
	return s - floorf(s)


static func sgn(v: float) -> float:
	return 1.0 if v > 0 else (-1.0 if v < 0 else 0.0)


## the prototype's colours are 0xRRGGBB numbers
static func hexc(h: int) -> Color:
	return Color.hex((h << 8) | 0xff)


static func css(s) -> Color:
	return Ctx.css(s) if s is String else s


static func rgba(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, clampf(a, 0, 1))


static func hbox(x0: float, x1: float, y0: float, y1: float) -> Dictionary:
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1}


static func overlap(a: Dictionary, b: Dictionary) -> bool:
	return a.x0 < b.x1 and a.x1 > b.x0 and a.y0 < b.y1 and a.y1 > b.y0


static func pick(arr: Array):
	return arr[randi() % arr.size()] if arr.size() else null


static func fmt(n: float) -> String:
	var neg = n < 0
	var s = str(absi(roundi(n)))
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


## run `f` after `sec` seconds of real time (the prototype's setTimeout)
func later(sec: float, f: Callable) -> void:
	_timers.append([sec, f])


func update_timers(rdt: float) -> void:
	var due = []
	for i in range(_timers.size() - 1, -1, -1):
		_timers[i][0] -= rdt
		if _timers[i][0] <= 0:
			due.append(_timers[i][1])
			_timers.remove_at(i)
	for f in due:
		if f.is_valid():
			f.call()


# ================================================================ save

func newChar() -> Dictionary:
	return {"level": 1, "exp": 0, "ap": 0, "sp": 0, "attrs": {"STR": 1, "WIL": 1, "VIT": 1, "AGI": 1, "DEX": 1}, "skills": {}, "asc": {}, "binds": {}, "introSeen": false,
		"charm": -1, "armor": 0, "weapon": 0, "arrows": 0, "staff": 0, "kills": 0, "nade": 0, "drone": 0, "nades": ["frag"], "nadeSel": "frag"}


func newSave() -> Dictionary:
	var s = {"coins": 0, "bossCoins": 0, "abyssCoins": 0, "boxes": {}, "parts": {}, "tankHouse": false, "house": {"owned": [], "placed": {}, "curios": [], "shelfItems": []}, "trophies": {}, "boons": {}, "mats": {}, "chars": {},
		"quests": [], "qid": 0, "settings": {"vol": 0.5, "music": 0.5, "sfx": 0.8, "shake": 1.0, "timeSpeed": 1, "weather": "auto", "help": true, "map": "home", "mute": false, "god": false},
		"bestRank": -1, "cards": {}, "bestiary": {}, "main": {"q": 0, "stage": 0, "claimed": false}}
	for k in SLIME_KEYS:
		s.mats[k] = 0
	for k in CLASSES:
		s.chars[k] = newChar()
	return s


func cosCats(cls: String) -> Array:
	return ["style", "hair", "eye", "hatShape", "hatColor"] if cls == "mage" else ["style", "hair", "eye"]


## every hero has a gender and a look (hair style, hair color, eye color) plus the cosmetics they own
func ensureLook(cls: String, c: Dictionary) -> void:
	if not c.get("abyss"):
		c.abyss = {"pot": {}, "eng": {}}
	if not c.get("bshop"):
		c.bshop = {}
	if not c.get("look"):
		var g = "m" if cls in ["rock", "summoner", "tank"] else "f"
		c.look = {"gender": g}
		c.look.merge(DEFAULT_LOOK[cls][g])
	if not c.get("cos"):
		c.cos = {"style": [], "hair": [], "eye": []}
	var Dl: Dictionary = DEFAULT_LOOK[cls][c.look.gender]
	for k in cosCats(cls):
		if not c.cos.get(k):
			c.cos[k] = []
		if not c.look.get(k):
			c.look[k] = Dl[k]
	for k in cosCats(cls):
		if not c.cos[k].has(Dl[k]):
			c.cos[k].append(Dl[k])
		if not c.cos[k].has(c.look[k]):
			c.cos[k].append(c.look[k])


func _save_path() -> String:
	return SAVE_PATH_OVERRIDE if SAVE_PATH_OVERRIDE != "" else SAVE_PATH


func loadSave() -> Dictionary:
	var base = newSave()
	var d = null
	if FileAccess.file_exists(_save_path()):
		d = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	if not (d is Dictionary):
		for k in CLASSES:
			ensureLook(k, base.chars[k])
		return base
	d = normalize(d)
	if d.get("char") is Dictionary and not d.has("chars"):   # the first Godot build saved one hero (Rock)
		d.chars = {"rock": d.char}
		d.erase("char")
	var s: Dictionary = base.duplicate(true)
	s.merge(d, true)
	s.mats = newSave().mats
	s.mats.merge(d.get("mats", {}), true)
	s.house = newSave().house
	s.house.merge(d.get("house", {}), true)
	s.trophies = d.get("trophies", {})
	s.settings = newSave().settings
	s.settings.merge(d.get("settings", {}), true)
	for k in CLASSES:
		var c = newChar()
		c.merge(d.get("chars", {}).get(k, {}), true)
		var a: Dictionary = newChar().attrs
		a.merge(c.attrs, true)
		c.attrs = a
		s.chars[k] = c
		ensureLook(k, c)
	for k in ["cards", "bestiary"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	_migrateBossRecords(s)
	return s


## older saves kept boss trophies and boss treasures per account and per hero the other way round:
## trophies become per hero (a boss beaten before kills were counted per hero is credited to every hero
## that had been played, except Tank, who arrived after them), treasures become account-wide
func _migrateBossRecords(s: Dictionary) -> void:
	for kind in s.get("trophies", {}):
		var anyone = false
		for k in s.chars:
			if int(s.chars[k].get("bossKills", {}).get(kind, 0)) > 0:
				anyone = true
		if anyone:
			continue
		for k in s.chars:
			var c: Dictionary = s.chars[k]
			if k != "tank" and int(c.get("level", 1)) > 1:
				if not (c.get("bossKills") is Dictionary):
					c.bossKills = {}
				c.bossKills[kind] = 1
	if not (s.get("boons") is Dictionary):
		s.boons = {}
	for k in s.chars:
		var c: Dictionary = s.chars[k]
		if c.get("boons") is Dictionary:
			for id in c.boons:
				s.boons[id] = int(s.boons.get(id, 0)) + int(c.boons[id])
			c.erase("boons")


func persist() -> void:
	save.worldT = World.t
	var f = FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))
	saveDirty = false


func CH() -> Dictionary:
	return save.chars[classId]


## the rank you paid for, before Ascendency
func baseRank(id: String) -> int:
	return int(CH().skills.get(id, 0))


## the Ascendency ranks stacked on one skill (its own tier's node, plus the capstone)
func ascBonus(id: String) -> int:
	var c = CH()
	if not (c.get("asc") is Dictionary):
		return 0
	var A: Dictionary = c.asc
	if A.is_empty() or not SKILL.has(id):
		return 0
	return int(A.get(str(SKILL[id].get("job", "")), 0)) + int(A.get("all", 0))


## how many Ascendency ranks you may hold: one per level past the Ascendency line
func ascCap() -> int:
	return maxi(0, CH().level - ASCEND_LV)


func ascSpent() -> int:
	var n = 0
	for k in CH().get("asc", {}).values():
		n += int(k)
	return n


## what a skill is actually worth: paid ranks plus Ascendency (which only lifts skills you know)
func skillRank(id: String) -> int:
	var base := int(CH().skills.get(id, 0))
	return base + (ascBonus(id) if base > 0 else 0)


static func expNeed(lv: int) -> int:
	return floori(28 * pow(lv, 1.6))


# ================================================================ jobs, skills, buffs

## Sorcerer / Sorceress follows the hero's chosen gender
func refreshJobNames() -> void:
	for J in JOBS_BY.mage:
		if J.has("nameF"):
			if not J.has("nameM"):
				J.nameM = J.name
			J.name = J.nameF if save.chars.mage.look.gender == "f" else J.nameM


func jobIndex(lv: int) -> int:
	var j = 0
	for i in JOBS.size():
		if lv >= JOBS[i].lv:
			j = i
	return j


func jobOf(lv: int) -> Dictionary:
	return JOBS[jobIndex(lv)]


func jobOfClass(cls: String, lv: int) -> Dictionary:
	var j = 0
	for i in JOBS_BY[cls].size():
		if lv >= JOBS_BY[cls][i].lv:
			j = i
	return JOBS_BY[cls][j]


func skillUnlocked(s: Dictionary) -> bool:
	if s.get("boss"):
		return skillRank(s.id) > 0   # boss skills only come from their box
	for J in JOBS:
		if J.id == s.job:
			return CH().level >= J.lv
	return false


func classSkills() -> Array:
	return SKILLS.filter(func(s): return s.get("cls", "rock") == classId)


func buffOn(id: String) -> bool:
	return Buffs.get(id, 0.0) > 0


func buffRank(id: String) -> int:
	return skillRank(id) if buffOn(id) else 0


## a skill's per-rank value (desc, dur, dmgR are stored as arrays indexed by rank)
static func sv(s: Dictionary, key: String, r: int):
	var a = s.get(key)
	if a is Array:
		return a[clampi(r, 0, a.size() - 1)]
	return a


func charmBonus(c: Dictionary) -> Dictionary:
	return CHARM_TIERS[c.charm] if c.charm >= 0 else {"atk": 0, "crit": 0, "exp": 0, "coin": 0}


# ---------------- stats: attributes + gear + charm + passives + buffs
func calcStats() -> Dictionary:
	var c = CH()
	var G: Dictionary = GEAR[classId]
	var ar: Dictionary = G.armor[c.armor]
	var wp: Dictionary = G.weapon[c.weapon]
	var ch = charmBonus(c)
	var R = skillRank
	var arch = classId == "archer"
	var mage = classId == "mage"
	var stf: Dictionary = G.staff[c.get("staff", 0)] if mage else {"atk": 0, "def": 0}
	var extra: int = R.call("avatarBody") * 5 + R.call("avatarSight") * 5 + R.call("avatarMind") * 5 + R.call("avatarBond") * 5 + R.call("avatarEngine") * 5
	var a = {"STR": c.attrs.STR + extra, "VIT": c.attrs.VIT + extra, "AGI": c.attrs.AGI + extra, "DEX": c.attrs.DEX + extra}
	var AB: Dictionary = c.get("abyss", {"pot": {}, "eng": {}})
	var ap = func(k): return AB.pot.get(k, 0)
	var ae = func(k): return AB.eng.get(k, 0)
	var bs = func(k): return c.get("bshop", {}).get(k, 0)
	# house: placed furniture and shelf curios (shared by every hero)
	var Hs: Dictionary = save.get("house", {"placed": {}, "shelfItems": []})
	var furn = func(k):
		var id = Hs.placed.get(k)
		if id:
			for it in FURNITURE[k].items:
				if it.id == id:
					return it.val
		return 0.0
	var cur = {}
	for id in Hs.get("shelfItems", []):
		for it in CURIOS:
			if it.id == id:
				for f in it.fx:
					cur[f] = cur.get(f, 0.0) + it.fx[f]
	var trophyExp: int = c.get("bossKills", {}).keys().filter(func(k): return int(c.bossKills[k]) > 0).size() * 10   # each hero earns their own trophies
	var boon = {"hp": 0.0, "atk": 0.0, "def": 0.0, "crit": 0.0}   # treasures from boss boxes
	var owned: Dictionary = save.get("boons", {})   # boss treasures are shared by every hero
	for id in owned:
		if BOONS.has(id):
			boon[BOONS[id].stat] += BOONS[id].val * owned[id]
	var hp: float = 90 + c.level * 10 + a.VIT * 14 + ar.hp + ap.call("hp") * 10 + bs.call("tonic") * 40 + boon.hp
	var atk: float = 10 + c.level * 2 + a.STR * 3 + wp.atk + stf.atk + ch.atk + ap.call("atk") * 2 + boon.atk
	var def: float = 2 + c.level * 0.5 + a.VIT * 0.9 + ar.def + wp.def + ap.call("def") * 2 + boon.def
	var crit: float = 5 + a.DEX * 0.7 + ch.crit + ap.call("crit") * 0.5 + boon.crit + ae.call("crate") * 0.5 + cur.get("crit", 0) + R.call("wisdom") + R.call("tactics") \
		+ ((8 + R.call("radiance")) if buffOn("radiance") else 0) + R.call("tranquilHeart") + R.call("eagleEye") + R.call("serenity") \
		+ ((8 + R.call("keenEye")) if buffOn("keenEye") else 0) + (12 if buffOn("deadeye") else 0) + ((5 + R.call("rage") * 0.5) if buffOn("rage") else 0) + (10 if buffOn("enrage") else 0)
	var critDmg: float = 1.5 + a.DEX * 0.012 + R.call("comboMastery") * 0.03 + R.call("eagleEye") * 0.04 + ae.call("cdmg") * 0.01 + bs.call("lens") * 0.04 + R.call("spellMastery") * 0.04
	var ff: int = R.call("fleetFoot")
	var spd: float = furn.call("rug") + (1 if buffOn("shocked") else 0) + (1 + minf(0.5, a.AGI * 0.008) + R.call("swiftEdge") * 0.02) * ((1 + ((0.1 + (ff - 1) * 0.015) if ff else 0.1)) if arch else 1.0) \
		+ ((0.1 + R.call("haste") * 0.01) if buffOn("haste") else 0) + ((0.15 + R.call("windWalk") * 0.01) if buffOn("windWalk") else 0)
	var aspd: float = ae.call("aspd") * 0.01 + cur.get("aspd", 0) + ((0.15 + R.call("timeWarp") * 0.01) if buffOn("timeWarp") else 0) + R.call("skyBond") * 0.03 + (1 if buffOn("shocked") else 0) \
		+ 1 + minf(0.45, a.AGI * 0.007) + R.call("swiftEdge") * 0.03 + R.call("bowMastery") * 0.02 + R.call("quickdraw") * 0.03 + ((0.08 + R.call("haste") * 0.01) if buffOn("haste") else 0)
	var atkMul: float = 1 + R.call("basics") * 0.03 + R.call("avatarBody") * 0.02 + R.call("bowMastery") * 0.03 + R.call("steadyAim") * 0.04 + R.call("avatarSight") * 0.02
	if buffOn("radiantQuiver"):
		atkMul += 0.2 + R.call("radiantQuiver") * 0.02
	atkMul += R.call("arcaneStudy") * 0.03 + R.call("darkAffinity") * 0.03 + R.call("wisdom") * 0.02 + R.call("avatarMind") * 0.02 + ((0.1 + R.call("radiance") * 0.01) if buffOn("radiance") else 0) \
		+ ((0.6 + R.call("ascendance") * 0.03) if buffOn("ascendance") else 0) + ((0.15 + R.call("warBanner") * 0.01) if buffOn("warBanner") else 0) + ((0.6 + R.call("ancientRoar") * 0.03) if buffOn("ancientRoar") else 0)
	if buffOn("transcendentAim"):
		atkMul += 0.55 + R.call("transcendentAim") * 0.03
	if buffOn("focus"):
		atkMul += 0.1 + R.call("focus") * 0.02
	if buffOn("rage"):
		atkMul += 0.12 + R.call("rage") * 0.02
	if buffOn("saintsAura"):
		atkMul += 0.2 + R.call("saintsAura") * 0.02
	if buffOn("transcendence"):
		atkMul += 0.6 + R.call("transcendence") * 0.03
	atk *= atkMul + cur.get("atkPct", 0)
	hp *= 1 + R.call("ironBody") * 0.04 + cur.get("hpPct", 0)
	def *= 1 + furn.call("table") + R.call("ironBody") * 0.04 + R.call("shieldMastery") * 0.03 + (0.3 if buffOn("transcendence") else 0.0)
	# Energy: Willpower raises recovery on a curve that flattens out (≈2.3× base at most), so skills
	# stay a burst resource at every level instead of becoming spammable.
	var W: float = c.attrs.WIL + extra
	var enMax = roundi(100 + minf(60, W * 0.6) + ap.call("en") * 4)
	var enRegen = 6 * (1 + 1.3 * (1 - exp(-W / 55)))
	var enHit: float = (3 + minf(2, W * 0.02)) * ((1.6 * (1 + R.call("quickdraw") * 0.05)) if arch else (0.5 if mage else 1.0))   # Focus builds from arrows; Mana mostly regenerates
	var enRegenF: float = (0.6 * (2 if buffOn("radiantQuiver") else 1)) if arch else ((1.25 * (1 + R.call("manaFlow") * 0.06) * (2 if buffOn("overflow") else 1)) if mage else 1.0)
	if arch:
		atk *= 0.82; hp *= 0.9
	if mage:
		atk *= 1.15; hp *= 0.85; def = def * 0.75 + stf.def
	if classId == "summoner":
		atk *= 0.95; hp *= 1.05; def *= 1 + ((0.2 + R.call("sanctuary") * 0.02) if buffOn("sanctuary") else 0.0)
	var arrowMul: float = (1 + ARROW_TIERS[c.get("arrows", 0)].dmg) if arch else 1.0
	return {"hp": roundi(hp * (1 - P.abyssDrain)), "hpFull": roundi(hp), "atk": roundi(atk), "def": roundi(def), "crit": minf(80, crit), "critDmg": critDmg, "spd": spd, "aspd": aspd,
		"exp": ch.exp + cur.get("exp", 0) + trophyExp + bs.call("notes") * 5, "coin": ch.coin + cur.get("coin", 0), "hpRegen": furn.call("chair"),
		"enMax": enMax, "enRegen": enRegen * enRegenF * (1 + furn.call("bed")) / 2.5, "enHit": enHit, "arrowMul": arrowMul,   # regen is 2.5× slower than it was, so the potions matter
		"hunt": ae.call("hunt") * 0.02 + bs.call("bane") * 0.05, "leech": ae.call("leech") * 0.003}


## has the hero you're playing beaten this boss? (every hero has to beat each boss once before its pedestal
## can call it back; the account-wide trophies only gate the world map and unlock heroes)
func heroBeat(kind: String) -> bool:
	return int(CH().get("bossKills", {}).get(kind, 0)) > 0


func setClass(id: String) -> void:
	classId = id
	refreshJobNames()
	JOBS = JOBS_BY[id]
	var c = CH()
	for s in SKILLS:
		if s.get("innate") and s.get("cls", "rock") == id and not c.skills.get(s.id):
			c.skills[s.id] = s.innate
	PS = calcStats()


func matsForLevel(lv: int, small := false) -> Dictionary:
	var band: Array = []
	for b in D.matBands:
		if lv < b[0]:
			band = b[1]
			break
	var k = 0.4 if small else 1.0
	return {band[0]: roundi((8 + lv * 0.35) * k), band[1]: roundi((5 + lv * 0.25) * k)}


func matName(k: String) -> String:
	var T: Dictionary = SLIME_TYPES[k]
	return T.matName if T.get("matName") else "%s Slime Residue" % T.name.split(" ")[0]


static func abyssCost(kind: String, n: int) -> int:
	return 3 + n * 2 if kind == "pot" else 5 + n * 3


static func bossCost(n: int) -> int:
	return 1 + n


# ================================================================ style ranks

func rankOf(pts: float) -> int:
	var r = 0
	for i in RANKS.size():
		if pts >= RANKS[i].min:
			r = i
	return r


func styleAdd(base: float, id: String) -> void:
	var rep: int = Style.last.count(id)
	var mult = 1.0 / (1 + rep * 0.55)
	Style.last.append(id)
	if Style.last.size() > 6:
		Style.last.pop_front()
	Style.pts = minf(RANK_CAP, Style.pts + base * mult * (1 + skillRank("comboMastery") * 0.06))
	var r = rankOf(Style.pts)
	if r > Style.rank:
		Style.popped = 1.0
		if r >= 4:
			Sfx.rankUp(r)
	Style.rank = r
	Style.peak = maxi(Style.peak, r)


func comboHit() -> void:
	Style.hits += 1
	Style.timer = 3.2
	Style.sinceHit = 0.0


func updateStyle(dt: float) -> void:
	Style.sinceHit += dt
	if Style.sinceHit > 1.1:
		Style.pts = maxf(0, Style.pts - dt * (22 + Style.pts * 0.16))
		Style.rank = rankOf(Style.pts)
	if Style.hits:
		Style.timer -= dt
		if Style.timer <= 0:
			endCombo(false)


func endCombo(broken: bool) -> void:
	var hits: int = Style.hits
	var peak: int = Style.peak
	Style.hits = 0
	Style.peak = Style.rank
	Style.timer = 0.0
	if hits < 5:
		return
	var k: float = RANK_MULT[peak] * (0.5 if broken else 1.0)
	var e = roundi((hits * 3 + CH().level * 2) * k)
	var coins = roundi((hits * 2 + 4) * k)
	gainExp(e)
	save.coins += coins
	saveDirty = true
	if not broken and peak > save.get("bestRank", -1):
		save.bestRank = peak
	if not broken and peak > CH().get("bestRank", -1):
		CH().bestRank = peak   # per hero, for the account record
	if not broken:
		for q in save.quests:
			if q.type == "combo" and not q.done and peak >= q.target:
				q.have = 1
				q.done = true
				toast("Quest complete: %s" % q.title)
	showComboResult(hits, peak, e, coins, broken)


func gainExp(n: float) -> void:
	var c = CH()
	c.exp += roundi(n * (1 + PS.get("exp", 0) / 100.0))
	while c.exp >= expNeed(c.level):
		var oldJob = jobIndex(c.level)
		c.exp -= expNeed(c.level)
		c.level += 1
		c.ap += 3
		c.sp += 3
		PS = calcStats()
		P.hp = PS.hp
		Sfx.levelUp()
		if c.level == ASCEND_LV + 1:
			later(1.4, func():
				banner("ASCENDENCY", "Past level %d your skill points can push your skills beyond their limits." % ASCEND_LV)
				Sfx.rankUp(9))
		banner("LEVEL UP!", "Level %d · 3 attribute points and 3 skill points" % c.level)
		if jobIndex(c.level) > oldJob:
			var J = jobOf(c.level)
			later(1.4, func():
				banner("JOB ADVANCEMENT", "%s is now a %s! New skills in the Skills tab." % [CLASSES[classId].name, J.name])
				Sfx.rankUp(8))
			fx.append({"type": "ring", "x": P.x, "y": P.y - 20, "t": 0.0, "life": 1.0, "r": 60, "col": J.color})
		for i in 30:
			part(P.x + rand(-10, 10), P.y - rand(0, 40), rand(-20, 20), rand(-90, -40), rand(0.6, 1.2), ["#ffe14d", "#ffffff", "#6fe0ff"][i % 3], 0, 2)
		if c.level % 5 == 0 or (c.level - 1) % 3 == 0:
			toast("Something new may be waiting in the Shop.")
	saveDirty = true


# ---------------- EXP scaling by level difference
func expScale(mobLv: int) -> float:
	var d: int = mobLv - CH().level
	if d <= -3: return 0.5
	if d == -2: return 0.75
	if d == -1: return 0.9
	if d == 0: return 1.0
	if d == 1: return 1.1
	if d == 2: return 1.25
	if d == 3: return 1.5
	if d == 4: return 1.75
	if d < 10: return 2 + (d - 5) / 5.0           # 5 → 200% … 10 → 300%
	if d < 20: return 3 + (d - 10) / 10.0 * 2     # 10 → 300% … 20 → 500%
	return 5.0


func mobExp(e) -> int:
	return maxi(1, roundi(e.exp * expScale(e.lv)))


# ================================================================ quests

func unlockedSlimes() -> Array:
	# quests nudge you onward: monsters from a little below to a little above your level
	var lv: int = CH().level
	var ok = func(k): return (SLIME_TYPES[k].w > 0 or SLIME_TYPES[k].get("critter", false)) and (not SLIME_TYPES[k].get("ai") or save.trophies.get("croc")) and (not SLIME_TYPES[k].get("habitat") or save.trophies.get("warlord"))
	var near = SLIME_KEYS.filter(func(k): return ok.call(k) and SLIME_TYPES[k].lv >= lv - 6 and SLIME_TYPES[k].lv <= lv + 5)
	if near.size() >= 2:
		return near
	var all = SLIME_KEYS.filter(ok)
	all.sort_custom(func(a, b): return absi(SLIME_TYPES[a].lv - lv) < absi(SLIME_TYPES[b].lv - lv))
	return all.slice(0, 3)


func genQuest() -> Dictionary:
	var pool = unlockedSlimes()
	var roll = randf()
	var lv: int = CH().level
	save.qid += 1
	var q = {"id": save.qid, "have": 0, "done": false}
	if roll < 0.65:
		var t: String = pool[rint(0, pool.size() - 1)]
		var T: Dictionary = SLIME_TYPES[t]
		var n: int = {"green": rint(6, 12), "blue": rint(5, 9), "red": rint(4, 7), "silver": rint(2, 4), "gold": rint(1, 2), "rat": rint(6, 10), "ferret": rint(4, 7), "boar": rint(8, 14), "tortoise": rint(6, 10)}.get(t, rint(6, 10))
		q.merge({"type": "kill", "target": t, "need": n, "title": "Defeat %d %s" % [n, (T.get("label", T.name + "s") if n > 1 else T.name)],
			"exp": roundi(n * T.exp * 1.6), "coins": roundi(n * (T.coins[0] + T.coins[1]) * 0.6 + 20)})
	elif roll < 0.88:
		var n = rint(12, 22)
		q.merge({"type": "kill", "target": "any", "need": n, "title": "Defeat %d monsters" % n, "exp": roundi(n * (10 + lv * 3)), "coins": n * 6 + 30})
	else:
		var r = 4 if lv < 5 else (5 if lv < 12 else (6 if lv < 25 else 7))
		q.merge({"type": "combo", "target": r, "need": 1, "title": "Finish a combo at %s rank or higher" % RANKS[r].r, "exp": 60 + lv * 25 * (r - 3), "coins": 80 + (r - 3) * 90})
	return q


func fillQuests() -> void:
	var guard = 0
	while save.quests.size() < 3 and guard < 50:
		guard += 1
		var q = genQuest()
		if guard < 40 and save.quests.any(func(o): return o.type == q.type and str(o.target) == str(q.target)):
			continue
		save.quests.append(q)
	saveDirty = true


## older saves: a finished first quest rolls straight on to the next
func mainQ() -> Dictionary:
	if not (save.get("main") is Dictionary):
		save.main = {"q": 0, "stage": 0, "claimed": false}
	var mq: Dictionary = save.main
	mq.q = mq.get("q", 0)
	if mq.claimed and mq.q + 1 < MAINQS.size():
		mq.q += 1
		mq.stage = 0
		mq.claimed = false
		if mq.q == 1 and save.trophies.get("warlord"):
			mq.stage = 3
	return mq


# ================================================================ cards, bestiary

func monsterName(type: String) -> String:
	if type == "croc":
		return BOSS_T.name
	if type == "warlord":
		return WARLORD_T.name
	if type == "dreamer":
		return "The Dreamer"
	return SLIME_TYPES[type].name if SLIME_TYPES.has(type) else type


func cardSet(type: String) -> Dictionary:
	if not save.cards.has(type):
		save.cards[type] = {}
	return save.cards[type]


## every card you own adds to EXP and coins from ALL monsters, for every hero
func cardValue(type: String) -> float:
	var c: Dictionary = save.cards.get(type, {})
	var b = 0.0
	for k in CARD_VAL:
		if c.get(k):
			b += CARD_VAL[k]
	return b


func accountCardBonus() -> float:
	var b = 0.0
	for t in save.cards:
		b += cardValue(t)
	return b


func cardBonus() -> float:
	return accountCardBonus()


func rollCards(e) -> void:
	var pre = "s" if e.shiny else "n"
	var c = cardSet(e.type)
	var spawn = func(gold: bool):
		var d = S.Drop.new()
		d.kind = "card"; d.type = e.type; d.key = pre + ("g" if gold else ""); d.gold = gold; d.shiny = e.shiny
		d.x = e.x; d.y = e.y - 10; d.vx = rand(-40, 40); d.vy = -240; d.val = 1
		d.surfY = e.surf.y; d.x0 = e.surf.x0 + 4; d.x1 = e.surf.x1 - 4
		drops.append(d)
	if randf() < GOLD_RATE and not c.get(pre + "g"):
		spawn.call(true)
	elif randf() < CARD_RATE and not c.get(pre):
		spawn.call(false)


func matRoll(type: String) -> int:
	var c = cardSet(type)
	var n = 1
	if (c.get("ng") or c.get("sg")) and randf() < 0.05:
		n = 10
	elif (c.get("n") or c.get("s")) and randf() < 0.1:
		n = 2
	return n


func recordKill(e) -> void:
	var B: Dictionary = save.bestiary
	if not B.has(e.type):
		B[e.type] = {"kills": 0, "shiny": 0}
	var r: Dictionary = B[e.type]
	if not r.kills:
		var nm: String = e.T.name
		later(0.4, func(): toast("New bestiary entry: %s!" % nm))
	r.kills += 1
	if e.shiny:
		r.shiny += 1
	saveDirty = true


# ================================================================ loot

func updateDrops(dt: float) -> void:
	var pb = pBox()
	var sea = M.get("sea")
	var seaTop: float = (sea.surface if sea.surface != null else -1e9) if sea != null else 1e9
	for i in range(drops.size() - 1, -1, -1):
		var d: S.Drop = drops[i]
		if d.t == 0.0 and d.y < d.surfY - 14:   # spawned in the air (a flying monster, a juggled one): it lands where it falls
			d.free = true
			d.x0 = 6.0; d.x1 = M.w - 6.0
			d.surfY = 1e9
		d.t += dt
		var py0: float = d.y
		if d.y > seaTop:   # things sink slowly through the water
			d.vy = minf(70, d.vy + GRAV * 0.3 * dt)
			d.vx *= exp(-dt * 2)
		else:
			d.vy = minf(MAXFALL, d.vy + GRAV * dt)
		d.x += d.vx * dt
		d.y += d.vy * dt
		d.x = clampf(d.x, d.x0, d.x1)
		if d.free and d.vy > 0:
			for q in surfaces:
				if not q.get("water", false) and d.x >= q.x0 and d.x <= q.x1 and py0 <= q.y and d.y >= q.y:
					d.free = false
					d.surfY = q.y; d.x0 = q.x0 + 3; d.x1 = q.x1 - 3
					break
			if d.free and d.y >= groundAt(d.x):
				d.free = false
				d.surfY = groundAt(d.x); d.x0 = 6.0; d.x1 = M.w - 6.0
		if d.y >= d.surfY:
			d.y = d.surfY
			if absf(d.vy) > 90:
				d.vy *= -0.45; d.vx *= 0.6
			else:
				d.vy = 0; d.vx *= exp(-dt * 10)
		if d.t > 0.35 and P.state != "dead" and d.x > pb.x0 - 4 and d.x < pb.x1 + 4 and d.y > pb.y0 and d.y < pb.y1 + 6:
			drops.remove_at(i)   # removed first, so a pickup can only ever happen once
			if d.kind == "coin":
				d.val = roundi(d.val * (1 + PS.get("coin", 0) / 100.0))
				save.coins += d.val
				Sfx.coin()
				pickupPop("coin", "Coins", d.val, "#ffe14d")
			elif d.kind == "abyss":
				save.abyssCoins = save.get("abyssCoins", 0) + d.val
				Sfx.tone(300, 0.2, "triangle", 0.08, 600)
				pickupPop("abyss", "Abyssal Coins", d.val, "#ff9ef0")
			elif d.kind == "box":
				collectBox(d.type)
			elif d.kind == "part":
				tankPickup(d)
			elif d.kind == "key":
				pickupKey()
			elif d.kind == "pendant":
				pickupPendant()
			elif d.kind == "card":
				cardSet(d.type)[d.key] = true
				saveDirty = true
				Sfx.rankUp(9 if d.gold else 6)
				Sfx.buy()
				var nm = monsterName(d.type)
				banner("GOLD MONSTER CARD!" if d.gold else "Monster Card!", "%s%s · +%d%% EXP & coins from it%s" % ["Shiny " if d.shiny else "", nm, 50 if d.gold else 10, " · chance of 10× materials" if d.gold else " · chance of double materials"])
				for k in 30:
					var cols: Array = ["#ffe14d", "#fff6b0", "#ffffff"] if d.gold else ["#ffffff", "#9fe6ff", "#ff9ecf"]
					part(P.x, P.y - 30, rand(-120, 120), rand(-200, -40), rand(0.6, 1.1), cols[k % 3], 200, 2)
			else:
				var n = matRoll(d.type)
				save.mats[d.type] = save.mats.get(d.type, 0) + n
				Sfx.goo()
				pickupPop("m_" + d.type, matName(d.type), n, "#ffffff")
			saveDirty = true
			continue
		if d.t > 60 and not (d.kind in ["box", "key", "pendant"]):
			drops.remove_at(i)


## pickup counters: one line per item that counts up while you keep collecting
func pickupPop(key: String, label: String, n: int, col) -> void:
	var p = null
	for q in POPS:
		if q.key == key:
			p = q
	if p == null:
		p = {"key": key, "label": label, "n": 0, "shown": 0.0, "t": 0.0, "col": css(col), "bump": 0.0}
		POPS.append(p)
		if POPS.size() > 5:
			POPS.pop_front()
	p.n += n
	p.t = 0.0
	p.bump = 1.0


func updatePops(dt: float) -> void:
	for i in range(POPS.size() - 1, -1, -1):
		var p = POPS[i]
		p.t += dt
		p.bump = maxf(0, p.bump - dt * 5)
		p.shown += (p.n - p.shown) * minf(1, dt * 14)
		if p.n - p.shown < 0.5:
			p.shown = float(p.n)
		if p.t > 1.6:
			POPS.remove_at(i)


# ================================================================ particles and floating text

func part(x: float, y: float, vx: float, vy: float, life: float, col, g := 0.0, sz := 1.0, floorY := INF) -> S.Part:
	var p = S.Part.new(x, y, vx, vy, life, css(col), g, sz, floorY)
	parts.append(p)
	return p


func sparks(x: float, y: float, col, n: int) -> void:
	for i in n:
		var a = randf() * TAU
		var s = rand(60, 180)
		part(x, y, cos(a) * s, sin(a) * s - 40, rand(0.15, 0.3), col, 300, 1)


func goo(x: float, y: float, color: int, n: int) -> void:
	var c = hexc(color)
	for i in n:
		part(x, y, rand(-90, 90), rand(-220, -60), rand(0.4, 0.8), c, 700, rint(1, 2), y + 20)


func dust(x: float, y: float, n: int) -> void:
	for i in n:
		part(x + rand(-6, 6), y - 1, rand(-40, 40), rand(-30, -8), rand(0.3, 0.55), "#efe6cf", 0, 2)


func updateParts(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: S.Part = parts[i]
		p.t += dt
		if p.t > p.life:
			parts.remove_at(i)
			continue
		p.vy += p.g * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.y > p.floorY:
			p.y = p.floorY; p.vy *= -0.3; p.vx *= 0.5
	for i in range(floaters.size() - 1, -1, -1):
		var f: S.Floater = floaters[i]
		f.t += dt
		f.y -= dt * (22 - f.t * 10)
		if f.t > f.life:
			floaters.remove_at(i)
	if parts.size() > 1500:
		parts = parts.slice(parts.size() - 1500)


func floatText(x: float, y: float, text: String, kind: String) -> void:
	# stack damage numbers like the classic MMOs
	var yy = y
	for f in floaters:
		if absf(f.x - x) < 14 and absf(f.y - yy) < 8 and f.t < 0.3:
			yy -= 9
	var f = S.Floater.new()
	f.x = x; f.y = yy; f.text = text; f.kind = kind; f.life = 1.1 if kind == "call" else 0.9
	floaters.append(f)
	if floaters.size() > 60:
		floaters.pop_front()


# ================================================================ messages

func toast(msg: String) -> void:
	toasts.append({"msg": msg, "t": 0.0})
	while toasts.size() > 4:
		toasts.pop_front()


## a key item picked up: the HUD shows it large and radiating for a moment
func keyItemGet(item: String, label: String, sub := "") -> void:
	keyGet = {"item": item, "name": label, "sub": sub, "t": 0.0}


func banner(big: String, sub := "") -> void:
	bannerMsg = {"big": big, "sub": sub, "t": 0.0}


func flashVig() -> void:
	vignette = 1.0


func flashEnergy() -> void:
	enShake = 0.4


func showComboResult(hits: int, peak: int, e: int, coins: int, broken: bool) -> void:
	comboMsg = {"big": "%d hit combo · %s" % [hits, RANKS[peak].r], "sub": "+%d EXP · +%d coins%s" % [e, coins, " · broken, rewards halved" if broken else ""], "t": 0.0}


# ================================================================ shared by the player and monsters

func isLow() -> bool:
	return P.state == "prone" or P.state == "slide" or (P.state == "attack" and P.move != null and P.move.get("prone", false))


## lying flat lets future high attacks pass overhead
func pBox() -> Dictionary:
	return hbox(P.x - 12, P.x + 12, P.y - 13, P.y) if isLow() else hbox(P.x - 7, P.x + 7, P.y - 40, P.y)


# ================================================================ forward declarations
# (defined for real further down the chain; GDScript needs to know they exist)

func spawnSlime(_initial := false) -> void: pass
func damageSlime(_e, _mv: Dictionary, _from = null) -> void: pass
func killSlime(_e) -> void: pass
func hurtPlayer(_src, _dmg: float) -> void: pass
func knockDown(_src) -> void: pass
func flinch() -> void: pass
func setAnim(_a: String) -> void: pass
func startMove(_id: String) -> void: pass
func frameOf(_anim: String, _t: float, _loop: bool) -> int: return 0
func spawnBoss() -> void: pass
func spawnWarlord() -> void: pass
func killBoss(_e) -> void: pass
func bossBox(_e) -> Dictionary: return {}
func updateBoss(_e, _dt: float) -> void: pass
func updateWarlord(_e, _dt: float) -> void: pass
func updateBossEye(_e, _dt: float) -> void: pass
func crimsonAI(_e, _T: Dictionary, _dt: float, _dx: float, _dy: float, _pb: Dictionary, _grounded: bool) -> bool: return false
func advanceMain(_mapId: String, _bossKind := "") -> void: pass
func resetObelisk() -> void: pass
func resetPets() -> void: pass
func startScene(_lines: Array, _onEnd = null) -> void: pass
func configureHome(_cls: String) -> void: pass
func buildQuickslots() -> void: pass
func aimTarget(_aim: String, _range: float): return null
func closeEnemy(_reach: float): return null
func airLift() -> bool: return true
func useSkill(_id: String) -> bool: return false
func echoHit(_e, _mv: Dictionary) -> void: pass
func skillHit(_mv: Dictionary, _f: int) -> void: pass
func castSpell(_mv: Dictionary, _f: int) -> void: pass
func fireArrows(_mv: Dictionary, _f: int) -> void: pass
func dragonCommand(_mv: Dictionary) -> void: pass
func archerInput(_has: Callable, _use: Callable, _dirIn: int, _up: bool, _down: bool, _wet: bool, _canAct: bool, _risingIntent: bool) -> void: pass
func mageInput(_has: Callable, _use: Callable, _dirIn: int, _up: bool, _down: bool, _wet: bool, _canAct: bool, _risingIntent: bool) -> void: pass
func summonerInput(_has: Callable, _use: Callable, _dirIn: int, _up: bool, _down: bool, _wet: bool, _canAct: bool, _risingIntent: bool) -> void: pass
func blink(_dirIn: int, _up: bool, _down: bool) -> void: pass
func arrowDive() -> void: pass
func perfectDodge() -> void: pass
func summonFromPedestal() -> void: pass
func activateObelisk(_o) -> void: pass
func travelHome() -> void: pass
func toggleMenu(_open = null) -> void: pass
func toCharSelect() -> void: pass
func updateTail(_dt: float, _anchor: Vector2) -> void: pass
func updateRocks(_dt: float) -> void: pass
func updateVials(_dt: float) -> void: pass
func openBox(_kind: String) -> void: pass
func openBoxes(_kind: String, _n := 1) -> void: pass
func collectBox(_kind: String, _n := 1) -> void: pass
func boxCount(_kind: String) -> int: return 0
func castBossSkill(_s: Dictionary) -> void: pass
func openDreamGate(_fanfare := false) -> void: pass
func initAbyssData() -> void: pass
func abyssAI(_e, _T: Dictionary, _dt: float, _dx: float, _dy: float, _pb: Dictionary) -> bool: return false
func spawnAbyssMob(_type: String, _T: Dictionary, _initial: bool, _shiny: bool) -> void: pass
func abyssElite(_e) -> void: pass
func seaCollide(_prevX: float, _prevY: float) -> void: pass
func abyssHold(_dt: float) -> bool: return false
func updateDreamer(_e, _dt: float) -> void: pass
func updatePart(_e, _dt: float) -> void: pass
func damagePart(_e, _mv: Dictionary) -> void: pass
func dreamerFalls(_e, _firstKill: bool) -> void: pass
func spawnDreamer() -> void: pass
func abyssOnLoad() -> void: pass
func abyssStep(_heavy: bool) -> void: pass
func waterBox(): return null
func groundAt(_x: float) -> float: return 0.0
func pickupKey() -> void: pass
func castDevour() -> void: pass
func dreamerHitOk(_e, _mv: Dictionary) -> bool: return true


# ---------------- the climb to the volcano (climb.gd fills these in)
func initClimbData() -> void: pass
func climbAI(_e, _T: Dictionary, _dt: float, _dx: float, _dy: float, _pb: Dictionary) -> bool: return false
func pickupPendant() -> void: pass
func spawnYeti(_fromPedestal := false) -> void: pass
func updateYeti(_e, _dt: float) -> void: pass
func yetiFalls(_e, _firstKill: bool) -> void: pass
func climbWind() -> float: return -1.0
func climbStep(_heavy: bool) -> void: pass
func climbMap() -> bool: return false
func yetiBox(_e) -> Dictionary: return {}


# ---------------- Glamrax's volcano (volcano.gd, glamrax.gd and finale.gd fill these in)
func initVolcanoData() -> void: pass
func statusExtra() -> Array: return []


# ---------------- Tank (tank.gd fills these in)
func initTankData() -> void: pass
func tankInput(_has: Callable, _use: Callable, _dirIn: int, _up: bool, _down: bool, _wet: bool, _canAct: bool, _rising: bool) -> void: pass
func tankDodge(_dirIn: int) -> void: pass
func tankMove(_dt: float, _dirIn: int, _up: bool, _down: bool) -> void: pass
func tankJumpMul() -> float: return 1.0
func tankWeakHit(_e) -> bool: return false
func tankPickup(_d) -> void: pass
func updateTank(_dt: float) -> void: pass


## Tank's exosuit stage (0 work clothes … 4 helmet, 5 the full mecha suit), which picks his sprite set
func exoStage(c: Dictionary) -> int:
	var a = int(c.get("armor", 0))
	return 5 if a >= 9 else mini(a, 4)


## the sprite set ("look") a hero is drawn with
func heroPose(): return null   # tank.gd
func slideSpeed() -> float: return 1.0
func slideLength() -> float: return 1.0
func animFallback(a: String) -> String: return a


func lookOf(cls: String) -> String:
	var c: Dictionary = save.get("chars", {}).get(cls, {})
	if cls == "tank":
		var g: String = c.get("look", {}).get("gender", "m")
		if classId == "tank" and inGame and buffOn("titanProtocol"):
			return "tank_%s_5" % g
		return "tank_%s_%d" % [g, exoStage(c)]
	return "%s_%s" % [cls, c.get("look", {}).get("gender", "m")]
