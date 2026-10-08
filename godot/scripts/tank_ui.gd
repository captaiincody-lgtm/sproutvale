extends "res://scripts/ui.gd"
## Sproutvale, part 10b: Tank's side of the Shop. His Gear tab (exosuit, pistol, grenades: each
## needs components as well as coins and materials) and his Workshop, where components build
## grenade types, the drone and, one day, a house.


func _partIcon(k: String, x: float, y: float, s := 12.0) -> void:
	var t = Assets.tex("tank/part_%s.png" % k)
	if t:
		uci.draw_texture_rect(t, Rect2(x, y, s, s), false)


## the components Tank is carrying, as a row of chips
func partsBag(x: float, y: float, w: float) -> float:
	var items = [[uW("COMPONENTS", 6, PX) + 4, func(X, Y): uText("COMPONENTS", X, Y + 5, 6, css("#0a5a7a"), PX)]]
	for k in PART_KEYS:
		var n = fmt(partCount(k))
		var w0 = uW(n, 9) + uW(" " + PART_INFO[k].name, 9, UF) + 30
		items.append([w0, func(X, Y):
			uBox(Rect2(X, Y, w0, 16), Color.WHITE, INK, 2, 8)
			_partIcon(k, X + 4, Y + 2, 12)
			var tw = uText(n, X + 18, Y + 3, 9, INK, UB)
			uText(" " + PART_INFO[k].name, X + 18 + tw, Y + 3, 9, INK, UF)
			zone(Rect2(X, Y, w0, 16), Callable(), PART_INFO[k].tip)])
	return flow(x, y, w, items) + 8


func _tankGear(kind: String, label: String, tiers: Array, cur: int) -> Callable:
	return func(X, Y, W):
		var nx = _tier(tiers, cur + 1)
		var yy = Y + h2(label, X, Y, W)
		if kind == "armor":
			heroPic(Rect2(X, yy, 44, 54), "tank")
		else:
			var ic = Assets.tex("tank/nade_%s.png" % nadeType()) if kind == "nade" else Assets.tex("tank/bullet.png")
			uBox(Rect2(X, yy, 44, 54), css("#e8f6ff"), INK, 2, 7)
			if ic:
				uci.draw_texture_rect(ic, Rect2(X + 8, yy + 13, 28, 28 if kind == "nade" else 14), false)
		var tx = X + 52
		uPara("Now: **%s**" % tiers[cur].name, tx, yy + 4, W - 52, 9, INK)
		var info: String = tiers[cur].get("ability", tiers[cur].get("desc", ""))
		uPara(info, tx, yy + 18, W - 52, 8, MUTED)
		yy += 60
		if nx:
			uPara("→ **%s**" % nx.name, X, yy, W, 9, css("#2a8a55"))
			yy += 14
			yy += muted(nx.get("ability", nx.get("desc", "")), X, yy, W, css("#1d5e3a"))
			var stat = ""
			match kind:
				"armor": stat = "+%d HP, +%d DEF" % [nx.hp, nx.def]
				"weapon": stat = "+%d ATK" % nx.atk
				"nade": stat = "Grenade damage ×%s" % String.num(nx.mul, 2)
			uText(stat, X, yy, 9)
			yy += 15
			yy += costBlock(nx, X, yy, W)
			yy += buyBtn(nx, kind, "Build" if kind == "armor" else "Upgrade", X, yy, W)
		else:
			yy += muted("Fully upgraded.", X, yy, W)
		return yy - Y


func tankGearCards(x: float, y: float, w: float) -> float:
	var c = CH()
	var G = GEAR.tank
	var y0 = y
	y += partsBag(x, y, w)
	y += uCards(x, y, w, 3, [_tankGear("armor", "Exosuit", G.armor, int(c.armor)), _tankGear("weapon", "Pistol", G.weapon, int(c.weapon)),
		_tankGear("nade", "Grenades", G.nade, int(c.get("nade", 0)))])
	y += 8
	y += uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y + h3("No charm for Tank", X, Y)
		yy += muted("Instead of a charm, Tank builds grenade types and a drone in the Workshop. Components drop only while you play Tank.", X, yy, W)
		uButton(Rect2(X, yy + 2, 120, 19), "Open the Workshop", func(): shopTab = "workshop"; scrollY.panel = 0.0; Sfx.ui(), {"bg": MINT})
		return yy + 24 - Y])
	return y - y0


func workshopCard(x: float, y: float, w: float) -> float:
	var c = CH()
	var y0 = y
	y += partsBag(x, y, w)
	y += muted("Components drop from monsters only while you play Tank. Build grenade types (pick one with 1–7 or V in a fight), your drone, and a house.", x, y, w) + 4
	var cards = []
	# grenade types
	cards.append(func(X, Y, W):
		var yy = Y + h2("Grenade types", X, Y, W)
		var own = nadesOwned()
		for i in NADES.size():
			var N: Dictionary = NADES[i]
			var have = own.has(N.id)
			var on = nadeType() == N.id
			if on:
				bgBox(1, Rect2(X - 4, yy, W + 8, 30), css("#fff8e0"), NONE, 0, 4)
			var ic = Assets.tex("tank/nade_%s.png" % N.id)
			if ic:
				uci.draw_texture_rect(ic, Rect2(X, yy + 4, 20, 20), false)
			uText("%d · %s" % [i + 1, N.name], X + 26, yy + 3, 9)
			uPara(N.desc, X + 26, yy + 15, W - 26 - 90, 7, MUTED)
			var br = Rect2(X + W - 86, yy + 5, 86, 18)
			if have:
				uButton(br, "Equipped" if on else "Equip", func(): CH().nadeSel = N.id; _changed(); Sfx.ui(), {"disabled": on, "size": 8})
			elif c.level < N.lv:
				uButton(br, "Lv %d" % N.lv, Callable(), {"disabled": true, "size": 8})
			else:
				var ok = hasParts(N.parts)
				uButton(br, "Build", func(): _buildNade(N), {"disabled": not ok, "bg": MINT, "size": 8})
				zone(br, Callable(), "Needs " + _partsText(N.parts))
			if not have:
				uText(_partsText(N.parts), X + 26, yy + 25, 7, css("#2a6a8a") if hasParts(N.parts) else css("#9a1f35"), UF)
				yy += 8
			dashed(X, X + W, yy + 30)
			yy += 33
		return yy - Y)
	# the drone
	cards.append(func(X, Y, W):
		var yy = Y + h2("Drone", X, Y, W)
		var tier = droneTier()
		var nx = _tier(DRONES, tier + 1)
		uBox(Rect2(X, yy, 54, 40), css("#e8f6ff"), INK, 2, 7)
		if tier > 0:
			var dt = Assets.tex("tank/drone_%d.png" % (tier - 1))
			if dt:
				uci.draw_texture_rect_region(dt, Rect2(X + 5, yy + 6, 44, 32), Rect2(0, 0, dt.get_width() / 4.0, dt.get_height()))
		else:
			uText("?", X + 27, yy + 10, 18, MUTED, UB, 1)
		var tx = X + 62
		uPara("Now: **%s**" % (DRONES[tier].name if tier > 0 else "No drone yet"), tx, yy + 2, W - 62, 9)
		uPara(DRONES[tier].desc if tier > 0 else "A third weapon: it fights on its own, and backs up your pistol and grenades.", tx, yy + 16, W - 62, 8, MUTED)
		yy += 48
		if nx:
			uPara("→ **%s**" % nx.name, X, yy, W, 9, css("#2a8a55"))
			yy += 14
			yy += muted(nx.desc, X, yy, W, css("#1d5e3a"))
			var t = {"lv": nx.lv, "coins": nx.coins, "mats": {}, "parts": nx.parts}
			yy += costBlock(t, X, yy, W)
			var label = ("Unlocks at Lv %d" % nx.lv) if c.level < nx.lv else "%s · %s coins" % ["Build" if tier == 0 else "Upgrade", fmt(nx.coins)]
			uButton(Rect2(X, yy, W, 19), label, func(): _buildDrone(), {"disabled": not canBuy(t), "bg": MINT})
			yy += 21
		else:
			yy += muted("Fully upgraded.", X, yy, W)
		return yy - Y)
	# the house
	cards.append(func(X, Y, W):
		var yy = Y + h2("A house", X, Y, W)
		var ht = Assets.tex("tank/house.png")
		if ht:
			uci.draw_texture_rect(ht, Rect2(X, yy, 80, 60), false, Color(1, 1, 1, 1.0 if houseBuilt() else 0.45))
		uPara("Built ✓" if houseBuilt() else "Where the box used to be.", X + 88, yy + 4, W - 88, 9, css("#2a8a55") if houseBuilt() else INK)
		uPara("A workshop of your own on the home field, with a Trophy Hall and room for furniture." if not houseBuilt() else "Go home and walk in through the door.", X + 88, yy + 18, W - 88, 8, MUTED)
		yy += 66
		if not houseBuilt():
			yy += costBlock(HOUSE_COST, X, yy, W)
			var label = ("Unlocks at Lv %d" % HOUSE_COST.lv) if c.level < HOUSE_COST.lv else "Build · %s coins" % fmt(HOUSE_COST.coins)
			uButton(Rect2(X, yy, W, 19), label, func(): _buildHouse(), {"disabled": not canBuy(HOUSE_COST), "bg": MINT})
			yy += 21
		return yy - Y)
	y += uCards(x, y, w, 3, cards)
	return y - y0


func _partsText(p: Dictionary) -> String:
	var a = []
	for k in PART_KEYS:
		if p.has(k):
			a.append("%d %s" % [p[k], PART_INFO[k].name.to_lower()])
	return ", ".join(a)


func _buildNade(N: Dictionary) -> void:
	if not hasParts(N.parts) or CH().level < N.lv:
		return
	spendParts(N.parts)
	nadesOwned().append(N.id)
	CH().nadeSel = N.id
	Sfx.buy()
	Sfx.levelUp()
	banner("%s grenades built!" % N.name, N.desc)
	_changed()


func _buildDrone() -> void:
	var c = CH()
	var nx = _tier(DRONES, droneTier() + 1)
	if nx == null:
		return
	var t = {"lv": nx.lv, "coins": nx.coins, "mats": {}, "parts": nx.parts}
	if not canBuy(t):
		return
	save.coins -= nx.coins
	spendParts(nx.parts)
	c.drone = droneTier() + 1
	Sfx.buy()
	Sfx.levelUp()
	banner("Drone built!" if c.drone == 1 else "Drone upgraded!", nx.name)
	_changed()


func _buildHouse() -> void:
	if houseBuilt() or not canBuy(HOUSE_COST):
		return
	save.coins -= HOUSE_COST.coins
	spendParts(HOUSE_COST.parts)
	save.tankHouse = true
	Sfx.buy()
	Sfx.levelUp()
	banner("House built!", "A workshop of your own, on the home field.")
	if mapId == "home":
		configureHome("tank")
	_changed()
