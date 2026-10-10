extends RefCounted
## The Attribute Tree: where a hero's attribute points go (one per level). A wheel of five branches,
## one per attribute, with mixed paths between neighbouring branches, in seven rings around the Origin.
## Rings open as you spend points in the tree, so the strongest nodes arrive with the late game.
## Each hero has their own tree: c.tree = {node id: rank}, c.tp = unspent points.

## points that must already be spent in the tree before a ring opens (index = ring; 0 is the Origin)
const RING_NEED := [0, 0, 3, 8, 16, 28, 45, 65]
const RINGS := 7

## the five branches, clockwise from the top. Ring 1–7 of each: [name, icon, stat, per rank, max ranks (0 = no limit)]
const SPOKES := [
	{"name": "Might", "attr": "STR", "col": "#ff5d73", "nodes": [
		["Might", "💪", "STR", 3, 5], ["Power", "⚔️", "atkPct", 3, 5], ["Brute Force", "💪", "STR", 5, 5], ["Warpath", "⚔️", "atkPct", 4, 5],
		["Titan's Grip", "💪", "STR", 7, 5], ["Berserker", "😤", "berserk", 10, 3], ["Endless Might", "♾️", "STR", 3, 0]]},
	{"name": "Precision", "attr": "DEX", "col": "#ffad1f", "nodes": [
		["Precision", "🎯", "DEX", 3, 5], ["Keen Edge", "✨", "crit", 1.5, 5], ["Steady Hand", "🎯", "DEX", 5, 5], ["Vital Strike", "💥", "critDmg", 6, 5],
		["Hawkeye", "🎯", "DEX", 7, 5], ["Lucky Star", "⭐", "critEn", 2, 3], ["Endless Precision", "♾️", "DEX", 3, 0]]},
	{"name": "Agility", "attr": "AGI", "col": "#33c4ee", "nodes": [
		["Agility", "💨", "AGI", 3, 5], ["Quick Feet", "👟", "spd", 2, 5], ["Nimble", "💨", "AGI", 5, 5], ["Flurry", "⚡", "aspd", 2.5, 5],
		["Windrunner", "💨", "AGI", 7, 5], ["Afterimage", "🌀", "dodge", 3, 3], ["Endless Agility", "♾️", "AGI", 3, 0]]},
	{"name": "Spirit", "attr": "WIL", "col": "#a06cff", "nodes": [
		["Spirit", "🔮", "WIL", 3, 5], ["Deep Well", "🔋", "enMax", 8, 5], ["Focus", "🔮", "WIL", 5, 5], ["Flow", "🌊", "enRegen", 5, 5],
		["Clarity", "💠", "enCost", 3, 5], ["Abyssal Ward", "🌑", "abyssRes", 10, 3], ["Endless Spirit", "♾️", "WIL", 3, 0]]},
	{"name": "Vitality", "attr": "VIT", "col": "#3fc47c", "nodes": [
		["Vitality", "❤️", "VIT", 3, 5], ["Thick Skin", "🛡️", "defPct", 5, 5], ["Stout", "❤️", "VIT", 5, 5], ["Lifeblood", "💗", "hpPct", 4, 5],
		["Iron Body", "❤️", "VIT", 7, 5], ["Bulwark", "🏰", "dr", 3, 3], ["Endless Vitality", "♾️", "VIT", 3, 0]]},
]

## the paths between branch i and branch i+1. Ring 2: one node; ring 3 grows out of it. Rings 4 and 6
## sit on the ring roads (two and three nodes); rings 5 and 7 grow out of them (ring 7: keystones).
## An entry's stat can be a Dictionary for a node that raises several things at once.
const SECTORS := [
	{"name": "Slayer", "col": "#ff7f45", "r": [
		[["Hunter", "🏹", "hunt", 4, 5]],
		[["Opening Blow", "🗡️", "first", 10, 3]],
		[["Cruelty", "🩸", "execute", 6, 5], ["Armor Breaker", "🔨", "pierce", 6, 5]],
		[["Executioner", "☠️", "executioner", 1, 1], ["Giant Slayer", "👹", "hunt", 8, 3]],
		[["Bloodlust", "🩸", "leech", 0.1, 5], ["Savage", "💥", "critDmg", 8, 5], ["Relentless", "⚔️", "atkPct", 3, 5]],
		[["Vampire", "🧛", "vampire", 1, 1], ["Deathblow", "💀", "bossCrit", 25, 1], ["Warlord's Fury", "🔥", "atkPct", 12, 1]]]},
	{"name": "Duelist", "col": "#a8d82a", "r": [
		[["Light Step", "🍃", "dodge", 1.5, 5]],
		[["Riposte", "↩️", "dodgeEn", 10, 3]],
		[["Swift Strikes", "⚡", "aspd", 2, 5], ["Pinpoint", "✨", "crit", 1.5, 5]],
		[["Blur", "🌀", "dodge", 3, 2], ["Assassin", "🗡️", "first", 15, 3]],
		[["Showoff", "🎭", "styleGain", 10, 5], ["Sprinter", "👟", "spd", 3, 5], ["Precise", "💥", "critDmg", 5, 5]],
		[["Phantom", "👻", "phantom", 1, 1], ["Tempest", "🌪️", "aspd", 12, 1], ["Fortune's Favor", "🍀", "crit", 6, 1]]]},
	{"name": "Wanderer", "col": "#5f8cff", "r": [
		[["Scavenger", "🪙", "coin", 5, 5]],
		[["Scholar", "📖", "exp", 5, 3]],
		[["Second Breath", "🌬️", "killEn", 2, 5], ["Swift Mind", "🌊", "enRegen", 4, 5]],
		[["Treasure Sense", "💰", "coin", 10, 3], ["Quick Study", "📚", "exp", 6, 3]],
		[["Wind Walker", "👟", "spd", 2, 5], ["Mana Tide", "🔋", "enMax", 10, 5], ["Spellweaver", "💠", "enCost", 2, 5]],
		[["Overflow", "🌊", "enRegen", 25, 1], ["Midas", "👑", "coin", 20, 1], ["Prodigy", "🎓", "exp", 15, 1]]]},
	{"name": "Warden", "col": "#2fc4b2", "r": [
		[["Energy Shield", "🔰", "eshield", 4, 5]],
		[["Recharge", "🔄", "eshRate", 25, 3]],
		[["Abyss Resistance", "🌑", "abyssRes", 6, 5], ["Regeneration", "🌿", "regen", 0.1, 5]],
		[["Abyss Walker", "🐚", "abyssDur", 15, 2], ["Sanctuary", "🌿", "regen", 0.3, 2]],
		[["Warded", "🔰", "eshield", 3, 5], ["Steadfast", "🪨", "critRes", 15, 3], ["Mending", "💚", "killHeal", 1, 3]],
		[["Last Stand", "🕯️", "lastStand", 1, 1], ["Aegis", "🔰", "eshield", 15, 1], ["Child of the Deep", "🌑", "abyssRes", 25, 1]]]},
	{"name": "Juggernaut", "col": "#d8913a", "r": [
		[["Spiked Hide", "🦔", "thorns", 20, 5]],
		[["Hardened", "🛡️", "defPct", 6, 3]],
		[["Heavy Armor", "🪖", "dr", 1.5, 5], ["Colossus", "💗", "hpPct", 4, 5]],
		[["Iron Spikes", "🦔", "thorns", 40, 3], ["Unshakable", "🪨", "critRes", 15, 2]],
		[["Battle Hunger", "🍖", "killHeal", 1, 5], ["Brawn", "🏋️", {"STR": 3, "VIT": 3}, 1, 5], ["Juggernaut", "🦏", "hpPct", 3, 5]],
		[["Unstoppable", "🦏", "dr", 8, 1], ["Titan", "🗿", "hpPct", 15, 1], ["Retribution", "⚡", "thorns", 150, 1]]]},
]

## how far hybrid nodes sit from the middle of their sector (degrees), by ring
const SPREAD := {2: [0], 3: [0], 4: [-14, 14], 5: [-14, 14], 6: [-22, 0, 22], 7: [-22, 0, 22]}

## stats with a ceiling, and what that ceiling is
const CAPS := {"dodge": 30.0, "dr": 30.0, "abyssRes": 80.0, "enCost": 40.0, "critRes": 90.0, "abyssDur": 50.0}

## what each stat does, for one rank's value `v`. {res} becomes the hero's resource (Energy, Focus, Mana…)
const FX := {
	"STR": "+%s ATK attribute", "DEX": "+%s DEX attribute", "AGI": "+%s AGI attribute", "WIL": "+%s WIL attribute", "VIT": "+%s VIT attribute",
	"atkPct": "+%s%% attack", "hpPct": "+%s%% max HP", "defPct": "+%s%% defense", "crit": "+%s%% critical rate", "critDmg": "+%s%% critical damage",
	"spd": "+%s%% move speed", "aspd": "+%s%% attack speed", "enMax": "+%s max {res}", "enRegen": "+%s%% {res} recovery", "enCost": "Skills cost %s%% less {res}",
	"eshield": "Energy shield worth %s%% of your max HP. It soaks up hits first and refills after 5s without being hurt",
	"eshRate": "Your energy shield starts refilling sooner and refills %s%% faster",
	"abyssRes": "%s%% Abyss resistance: the Abyss builds up slower and eats less of your HP",
	"abyssDur": "The Abyss lets go of you %s%% sooner",
	"dodge": "%s%% chance to dodge a hit completely", "dr": "Take %s%% less damage from everything", "critRes": "Monsters land critical hits on you %s%% less often",
	"thorns": "When a monster hits you, it takes %s%% of your ATK back", "regen": "Regenerate %s%% of your max HP every second, even in a fight",
	"leech": "Every hit heals you for %s%% of your max HP", "hunt": "+%s%% damage to bosses and elite monsters",
	"execute": "+%s%% damage to monsters below 30%% HP", "first": "+%s%% damage to monsters that haven't been hurt yet",
	"pierce": "Your hits ignore %s%% of a monster's defense", "berserk": "Up to +%s%% damage the lower your HP (full bonus at 30%% HP)",
	"critEn": "Critical hits restore %s {res}", "dodgeEn": "A perfect dodge restores %s {res}", "killEn": "Defeating a monster restores %s {res}",
	"killHeal": "Defeating a monster heals %s%% of your max HP", "styleGain": "+%s%% style points (combo ranks climb faster)",
	"exp": "+%s%% EXP", "coin": "+%s%% coins", "bossCrit": "Critical hits on bosses deal +%s%% more",
	"executioner": "Ordinary monsters below 12% HP are finished off in one blow",
	"vampire": "Life steal heals three times as much on critical hits",
	"phantom": "After a perfect dodge, your next 3 hits are certain to be critical",
	"lastStand": "Once every 90 seconds, a blow that would knock you out leaves you on 30% HP, untouchable for 2 seconds",
}
## the keystones: one rank, no number to show
const FLAGS := ["executioner", "vampire", "phantom", "lastStand"]

## the stats the tree adds to calcStats' output (Glamrax, played in the showdown, leaves them out)
const PS_KEYS := ["dodge", "dr", "critRes", "thorns", "eshield", "eshRate", "abyssRes", "abyssDur", "execute", "first", "pierce", "berserk",
	"critEn", "dodgeEn", "killEn", "killHeal", "styleGain", "enCost", "bossCrit", "executioner", "vampire", "phantom", "lastStand"]

static var _nodes: Array = []
static var _byId: Dictionary = {}
static var _adj: Dictionary = {}
static var _edges: Array = []


static func _mk(id: String, ring: int, ang: float, e: Array, col: String, kind: String, branch: String) -> Dictionary:
	var fx = e[2] if e[2] is Dictionary else {e[2]: e[3]}
	return {"id": id, "ring": ring, "ang": ang, "name": e[0], "icon": e[1], "fx": fx, "max": int(e[4]), "col": col, "kind": kind, "branch": branch}


static func build() -> void:
	if not _nodes.is_empty():
		return
	var add = func(n):
		_nodes.append(n)
		_byId[n.id] = n
		_adj[n.id] = []
	add.call({"id": "origin", "ring": 0, "ang": 0.0, "name": "Origin", "icon": "🌟", "fx": {}, "max": 0, "col": "#ffe08a", "kind": "origin", "branch": ""})
	for i in SPOKES.size():
		var B: Dictionary = SPOKES[i]
		var a = -90.0 + 72.0 * i
		for r in RINGS:
			var e: Array = B.nodes[r]
			add.call(_mk("s%d_%d" % [i, r + 1], r + 1, a, e, B.col, "endless" if int(e[4]) == 0 else ("notable" if r + 1 == 6 else "minor"), B.name))
	for i in SECTORS.size():
		var Sx: Dictionary = SECTORS[i]
		var mid = -90.0 + 72.0 * i + 36.0
		for k in Sx.r.size():
			var ring = k + 2
			for j in Sx.r[k].size():
				var e: Array = Sx.r[k][j]
				var kind = "key" if ring == 7 else ("notable" if ring % 2 == 1 else "minor")
				add.call(_mk("h%d_%d_%d" % [i, ring, j], ring, mid + SPREAD[ring][j], e, Sx.col, kind, Sx.name))
	var link = func(a: String, b: String):
		if _byId.has(a) and _byId.has(b) and not _adj[a].has(b):
			_adj[a].append(b)
			_adj[b].append(a)
			_edges.append([a, b])
	# the five branches run straight out from the Origin
	for i in SPOKES.size():
		link.call("origin", "s%d_1" % i)
		for r in range(1, RINGS):
			link.call("s%d_%d" % [i, r], "s%d_%d" % [i, r + 1])
	# rings 2, 4 and 6 are roads all the way round; rings 3, 5 and 7 grow outward from them
	for ring in [2, 4, 6]:
		var on = _nodes.filter(func(n): return n.ring == ring)
		on.sort_custom(func(p, q): return fposmod(p.ang + 90, 360) < fposmod(q.ang + 90, 360))
		for k in on.size():
			link.call(on[k].id, on[(k + 1) % on.size()].id)
	for i in SECTORS.size():
		for ring in [3, 5, 7]:
			for j in SPREAD[ring].size():
				link.call("h%d_%d_%d" % [i, ring - 1, j], "h%d_%d_%d" % [i, ring, j])


static func nodes() -> Array:
	build()
	return _nodes


static func node(id: String) -> Dictionary:
	build()
	return _byId.get(id, {})


static func edges() -> Array:
	build()
	return _edges


static func neighbors(id: String) -> Array:
	build()
	return _adj.get(id, [])


static func rankOf(tree: Dictionary, id: String) -> int:
	return int(tree.get(id, 0))


static func spent(tree: Dictionary) -> int:
	var n = 0
	for k in tree:
		n += int(tree[k])
	return n


static func reachable(tree: Dictionary, id: String) -> bool:
	if rankOf(tree, id) > 0:
		return true
	for nb in neighbors(id):
		if nb == "origin" or rankOf(tree, nb) > 0:
			return true
	return false


## "" if a point can go into this node now, otherwise why not
static func blocker(tree: Dictionary, tp: int, id: String) -> String:
	var n = node(id)
	if n.is_empty() or n.kind == "origin":
		return "origin"
	var r = rankOf(tree, id)
	if n.max > 0 and r >= n.max:
		return "Mastered"
	var need: int = RING_NEED[n.ring]
	if spent(tree) < need:
		return "This ring opens after %d points in the tree" % need
	if not reachable(tree, id):
		return "Take a node next to it first"
	if tp < 1:
		return "No attribute points (you get one each level)"
	return ""


## everything the tree adds up to: stat → total (caps applied)
static func totals(tree: Dictionary) -> Dictionary:
	build()
	var t = {}
	for id in tree:
		var n = _byId.get(id)
		if n == null:
			continue
		var r = int(tree[id])
		for k in n.fx:
			t[k] = t.get(k, 0.0) + float(n.fx[k]) * r
	for k in CAPS:
		if t.has(k):
			t[k] = minf(t[k], CAPS[k])
	return t


static func num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.2f" % v).rstrip("0").rstrip(".")


static func fxText(stat: String, v: float, res: String) -> String:
	var s: String = FX.get(stat, stat)
	if not FLAGS.has(stat):
		s = s % num(v)
	return s.replace("{res}", res)


static func describe(n: Dictionary, ranks: int, res: String) -> String:
	var parts = []
	for k in n.fx:
		parts.append(fxText(k, float(n.fx[k]) * ranks, res))
	return " · ".join(parts)
