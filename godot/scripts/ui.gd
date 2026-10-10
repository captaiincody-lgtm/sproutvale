extends "res://scripts/hud.gd"
## Sproutvale, part 10: the Tab menu. Character, Inventory, Shop (gear, abyssal, boss and house),
## Skills, Quests, World Map, Bestiary, Controls and World, laid out like the prototype's HTML panels.
## Cards are drawn content first; their backgrounds go into two canvas items that sit behind it,
## so a card can be sized to whatever it ended up holding.

const TABS := [["char", "Character"], ["tree", "Attributes"], ["inv", "Inventory"], ["shop", "Shop"], ["skills", "Skills"], ["quests", "Quests"],
	["map", "World Map"], ["bestiary", "Bestiary"], ["controls", "Controls"], ["world", "World"]]
const PAD := 8.0
const CARD := {"fill": Color.WHITE, "border": INK}

var curTab := "char"
var shopTab := "gear"
var skillSel := ""     # which advancement (job id), "boss" or "asc" the Skills tab is showing
var panelRect := Rect2()
var overRect := Rect2()
var BEST_ANIM := {}
var BEST_VIEW := {}
var wmHover = null
var uctx := Ctx.new()
var _bgRids := {}
var uBg0: RID
var uBg1: RID


# ================================================================ opening and closing

func toggleMenu(open = null) -> void:
	menuOpen = (not menuOpen) if open == null else tb(open)
	for k in K:
		K[k] = false
	if menuOpen:
		Sfx.ui()
	else:
		persist()


func openSettings() -> void: pass   # screens.gd


func openTab(id: String) -> void:
	if curTab != id:
		scrollY.panel = 0.0
	curTab = id
	Sfx.ui()


func canBuy(t: Dictionary) -> bool:
	if CH().level < t.lv or save.coins < t.coins:
		return false
	if int(CH().get("armor", 0)) < t.get("needArmor", 0):
		return false
	for k in t.get("mats", {}):
		if save.mats.get(k, 0) < t.mats[k]:
			return false
	return hasParts(t.get("parts", {}))


func _changed() -> void:
	saveDirty = true


func _restat() -> void:
	var old = PS.hp
	PS = calcStats()
	P.hp += maxf(0, PS.hp - old)


# ================================================================ backgrounds and layout helpers

## two canvas items behind `ci`: level 0 for cards, level 1 for things inside cards
func uBgs(ci: CanvasItem, layer: String) -> void:
	if not _bgRids.has(layer):
		var a = RenderingServer.canvas_item_create()
		var b = RenderingServer.canvas_item_create()
		for r in [a, b]:
			RenderingServer.canvas_item_set_parent(r, ci.get_canvas_item())
			RenderingServer.canvas_item_set_draw_behind_parent(r, true)
		_bgRids[layer] = [a, b]
	uBg0 = _bgRids[layer][0]
	uBg1 = _bgRids[layer][1]
	RenderingServer.canvas_item_clear(uBg0)
	RenderingServer.canvas_item_clear(uBg1)


func bgBox(level: int, r: Rect2, fill: Color, border := NONE, bw := 2, rad := 8, shadow := 0.0, shadowCol := INK) -> void:
	var rid = uBg0 if level == 0 else uBg1
	if shadow != 0:
		sbox(shadowCol, NONE, 0, rad).draw(rid, Rect2(r.position + Vector2(0, shadow), r.size))
	sbox(fill, border, bw, rad).draw(rid, r)


func dashed(x0: float, x1: float, y: float, col := LINE) -> void:
	uci.draw_dashed_line(Vector2(x0, y), Vector2(x1, y), col, 1.0, 3.0)


## Cards in rows of `n` columns. Each card is a Callable(x, y, w) -> content height, drawn with
## PAD around it. `styles[i]` (optional) is {fill, border}. A card marked {"wide": true} takes a whole row.
func uCards(x: float, y: float, w: float, n: int, cards: Array, styles := [], gap := 8.0) -> float:
	var cy = y
	var i = 0
	while i < cards.size():
		var st0: Dictionary = styles[i] if i < styles.size() else CARD
		var cols = 1 if st0.get("wide", false) else n
		var cw = (w - gap * (cols - 1)) / cols
		var rowH = 0.0
		var placed = []
		for j in cols:
			if i + j >= cards.size():
				break
			var st: Dictionary = styles[i + j] if i + j < styles.size() else CARD
			if j > 0 and st.get("wide", false):
				break
			var cx = x + j * (cw + gap)
			var h = cards[i + j].call(cx + PAD, cy + PAD, cw - PAD * 2)
			rowH = maxf(rowH, h)
			placed.append([cx, st])
		for p in placed:
			bgBox(0, Rect2(p[0], cy, cw, rowH + PAD * 2), p[1].get("fill", Color.WHITE), p[1].get("border", INK), 2, 9, 2.0, p[1].get("border", INK))
		cy += rowH + PAD * 2 + gap
		i += placed.size()
	return cy - y - gap


## a card heading with optional things on the right; returns its height
func h2(s: String, x: float, y: float, w: float, col := INK) -> float:
	uPara(s, x, y, w, 11, col, true, true)
	return 17.0


func h3(s: String, x: float, y: float, col := INK) -> float:
	uText(s, x, y, 10, col)
	return 15.0


func muted(s: String, x: float, y: float, w: float, col := MUTED, size := 8) -> float:
	return uPara(s, x, y, w, size, col) + 2


## label · value with a dashed line under it, like the prototype's .row
func statRow(x: float, y: float, w: float, a: String, b: String, tip := "") -> float:
	uText(a, x, y + 2, 9, INK, UF)
	uText(b, x + w, y + 2, 9, INK, UB, 2)
	dashed(x, x + w, y + 15)
	if tip != "":
		zone(Rect2(x, y, w, 15), Callable(), tip)
	return 16.0


func jobPill(J: Dictionary, x: float, y: float, align := 0) -> float:
	var w = uW(J.name, 8) + 12
	var X = x - (w if align == 2 else 0.0)
	uBox(Rect2(X, y, w, 13), css(J.color), INK, 2, 7)
	uText(J.name, X + 6, y + 2, 8, DARK)
	return w


## a row of chips that wraps; each item is [width, Callable(x, y)]. Returns the height used.
func flow(x: float, y: float, w: float, items: Array, h := 16.0, gap := 5.0) -> float:
	var cx = 0.0
	var cy = 0.0
	for it in items:
		if cx > 0 and cx + it[0] > w:
			cx = 0.0
			cy += h + gap
		it[1].call(x + cx, y + cy)
		cx += it[0] + gap
	return cy + h


## the "currency" strip shown on the Inventory and Shop tabs
func currencyBag(x: float, y: float, w: float, extra := "", cards := -1) -> float:
	var items = [[uW("CURRENCY", 6, PX) + 4, func(X, Y): uText("CURRENCY", X, Y + 5, 6, css("#8a5a08"), PX)]]
	var cur = [["coin", fmt(save.coins), "Coins", CUR_TIPS.coin], ["boss", fmt(save.get("bossCoins", 0)), "Boss Coins", CUR_TIPS.boss],
		["abyss", fmt(save.get("abyssCoins", 0)), "Abyssal Coins", CUR_TIPS.abyss]]
	if cards >= 0:
		cur.append(["cards", fmt(cards), "Monster Cards", CUR_TIPS.get("cards", "")])
	for c in cur:
		var w0 = uW(c[1], 9) + uW(" " + c[2], 9, UF) + 30
		items.append([w0, func(X, Y):
			uBox(Rect2(X, Y, w0, 16), Color.WHITE, INK, 2, 8)
			if c[0] == "cards":   # a little card instead of a coin
				uBox(Rect2(X + 6, Y + 3, 8, 10), css("#9fe6ff"), INK, 1, 2)
				uci.draw_rect(Rect2(X + 8, Y + 5, 4, 3), css("#ffffff"))
			else:
				_coin(Vector2(X + 10, Y + 8), 4.5, c[0])
			var tw = uText(c[1], X + 18, Y + 3, 9, INK, UB)
			uText(" " + c[2], X + 18 + tw, Y + 3, 9, INK, UF)
			zone(Rect2(X, Y, w0, 16), Callable(), c[3])])
	if extra != "":
		items.append([uW(extra, 8, UF), func(X, Y): uText(extra, X, Y + 4, 8, MUTED, UF)])
	return flow(x, y, w, items) + 8


func heroPic(r: Rect2, cls: String, anim := "idle", f := 0, bg := true, look := "") -> void:
	if bg:
		uBox(r, css("#e8f6ff"), INK, 2, 7)
		uGrad(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.75 - 2)), css("#bfe6ff"), css("#d4eeff"), css("#e8f6ff"), 0.5)
		uci.draw_rect(Rect2(r.position.x + 2, r.position.y + r.size.y * 0.75, r.size.x - 4, r.size.y * 0.25 - 2), css("#8fd06a"))
	if look == "":
		look = lookOf(cls)
	var A = Assets.hero_anim(look, anim)
	var tex = Assets.hero_strip(look, anim, 1)
	if tex == null:
		return
	var n = int(A.frames)
	var fw = tex.get_width() / float(n)
	var k = fw / SW
	# the prototype crops the 84×76 frame to the hero (48×60 from 18,4) for its previews
	var src = Rect2(fposmod(f, n) * fw + 18 * k, 4 * k, 48 * k, 62 * k)
	var s = minf(r.size.x / 48.0, r.size.y / 62.0)
	var dw = 48 * s
	var dh = 62 * s
	uci.draw_texture_rect_region(tex, Rect2(r.get_center().x - dw / 2, r.end.y - dh - 1, dw, dh), src)


func matIcon(k: String, x: float, y: float, s := 12.0) -> void:
	var t = Assets.tex("items/residue_%s.png" % k)
	if t:
		uci.draw_texture_rect(t, Rect2(x, y, s, s), false)


func matDot(k: String, x: float, y: float) -> void:
	uci.draw_circle(Vector2(x + 4, y + 4), 4.5, INK)
	uci.draw_circle(Vector2(x + 4, y + 4), 3.6, hexc(int(SLIME_TYPES[k].color)))


## draw with the Canvas2D stand-in into the current UI canvas, at `pos` and `scale`
func withCtx(pos: Vector2, s: float, fn: Callable) -> void:
	uctx.begin(uci, Transform2D(0, Vector2(s, s), 0, pos))
	fn.call(uctx)
	uci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ================================================================ the sheet

func renderMenu(ci: CanvasItem) -> void:
	uBegin(ci, "menu")
	ci.draw_rect(Rect2(0, 0, UW, UH), Color(10 / 255.0, 15 / 255.0, 40 / 255.0, 0.55))
	var sheet = Rect2(20, 14, UW - 40, UH - 28)
	uBox(sheet, PANEL, INK, 3, 12, 5.0, INK)
	# tabs, then the system buttons on the right (they wrap to a second row if they don't fit)
	var c = CH()
	var x = sheet.position.x + 7
	var y = sheet.position.y + 7
	var tabH = 21.0
	var sys = [["⚙ Settings", func(): openSettings()],
		["Save", func(): persist(); toast("Game saved."); Sfx.buy()], ["Main Menu", func(): persist(); toggleMenu(false); toCharSelect()],
		["Quit", func(): persist(); get_tree().quit()], ["Close", func(): toggleMenu(false)]]
	var tabsW = 0.0
	var tabWs = []
	for T in TABS:
		var b = _tabBadge(T[0], c)
		var w = uW(T[1], 9) + 16 + (uW(b, 7) + 10 if b != "" else 0.0)
		tabWs.append(w)
		tabsW += w + 3
	var headH = tabH + 7
	var head = Rect2(sheet.position + Vector2(3, 3), Vector2(sheet.size.x - 6, headH))
	sbox(PANEL2, NONE, 0, 10).draw(uRid(), head)
	uci.draw_rect(Rect2(sheet.position.x + 1.5, head.end.y - 1, sheet.size.x - 3, 3), INK)
	for i in TABS.size():
		var id: String = TABS[i][0]
		var r = Rect2(x, y + (2 if id != curTab else 0), tabWs[i], tabH + (3 if id == curTab else 0) - (2 if id != curTab else 0))
		if id == curTab:
			sbox(PANEL, INK, 2, 8).draw(uRid(), Rect2(r.position, r.size + Vector2(0, 6)))
			uci.draw_rect(Rect2(r.position.x + 2, head.end.y - 1, r.size.x - 4, 4), PANEL)
		elif uHover(r):
			sbox(Color(1, 1, 1, 0.5), NONE, 0, 8).draw(uRid(), r)
		var tw = uText(TABS[i][1], r.position.x + 8, y + 5, 9, INK)
		var badge = _tabBadge(id, c)
		if badge != "":
			uPill(badge, r.position.x + 8 + tw + 5, y + 6, PINK, Color.WHITE, 7)
		zone(r, func(): openTab(id))
		x += tabWs[i] + 3
	# the system buttons sit in a strip along the bottom of the sheet
	var foot = sheet.end.y - 26
	uci.draw_rect(Rect2(sheet.position.x + 1.5, foot, sheet.size.x - 3, 2), LINE)
	# the big way home, always in the same corner so it's easy to find
	var atHome = mapId == "home"
	var homeL = "🏠 You're home" if atHome else "🏠 TELEPORT HOME"
	var hr = Rect2(sheet.position.x + 8, foot + 3, uW(homeL, 10) + 26, 21)
	if not atHome:
		uGlow(hr, Color(css("#3ad6a0"), 0.45 + 0.2 * sin(realTime * 4)), 8, 8)
	uButton(hr, homeL, func(): toggleMenu(false); travelHome(), {"bg": css("#5ff0b4"), "size": 10, "shadow": 2.0, "disabled": atHome})
	var sysW = 0.0
	for sb in sys:
		sysW += uW(sb[0], 8) + 14 + 4
	var sx = sheet.end.x - 8 - sysW + 4
	var help = "Tab or Esc closes · M opens the world map"
	if hr.end.x + 10 + uW(help, 8, UF) < sx - 6:
		uText(help, hr.end.x + 10, foot + 8, 8, MUTED, UF)
	for sb in sys:
		var w = uW(sb[0], 8) + 14
		uButton(Rect2(sx, foot + 5, w, 17), sb[0], sb[1], {"bg": GOLD if sb[0] == "Close" else Color.WHITE, "size": 8, "shadow": 1.5})
		sx += w + 4
	panelRect = Rect2(sheet.position.x + 3, head.end.y + 2, sheet.size.x - 6, foot - head.end.y - 3)
	_scrollbar("panel", panelRect)


func _tabBadge(id: String, c: Dictionary) -> String:
	if id == "tree" and int(c.get("tp", 0)) > 0:
		return str(c.tp)
	if id == "quests" and save.quests.any(func(q): return q.done):
		return "!"
	if id == "shop":
		var G = GEAR[classId]
		var nexts = [_tier(G.armor, c.armor + 1), _tier(G.weapon, c.weapon + 1), _tier(CHARM_TIERS, c.charm + 1)]
		if G.get("arrows"):
			nexts.append(_tier(G.arrows, c.get("arrows", 0) + 1))
		if nexts.any(func(t): return t != null and canBuy(t)):
			return "new"
	if id == "skills" and c.sp and (ascCap() > ascSpent() or classSkills().any(func(s): return skillUnlocked(s) and baseRank(s.id) < s.max)):
		return str(c.sp)
	return ""


static func _tier(arr: Array, i: int):
	return arr[i] if i >= 0 and i < arr.size() else null


func _scrollbar(layer: String, r: Rect2) -> void:
	var ch = contentH.get(layer, 0.0)
	if ch <= r.size.y:
		return
	var s = scrollY.get(layer, 0.0)
	var h = maxf(20, r.size.y * r.size.y / ch)
	var y = r.position.y + (r.size.y - h) * s / (ch - r.size.y)
	uBox(Rect2(r.end.x - 6, y + 2, 4, h - 4), Color(INK, 0.35), NONE, 0, 2)


func scrollBy(layer: String, dy: float) -> void:
	var r = panelRect if layer == "panel" else overRect
	scrollY[layer] = clampf(scrollY.get(layer, 0.0) + dy, 0, maxf(0, contentH.get(layer, 0.0) - r.size.y))


## the scrolling contents of the open tab, drawn into a clipping node at panelRect
func renderPanel(ci: CanvasItem) -> void:
	scrollY.panel = clampf(scrollY.get("panel", 0.0), 0, maxf(0, contentH.get("panel", 0.0) - panelRect.size.y))
	uBegin(ci, "panel", panelRect.position, panelRect)
	uBgs(ci, "panel")
	var x = 12.0
	var y = 10.0 - scrollY.panel
	var w = panelRect.size.x - 24
	var h = 0.0
	match curTab:
		"char": h = _pChar(x, y, w)
		"tree": h = _pTree(x, y, w)
		"inv": h = _pInv(x, y, w)
		"shop": h = _pShop(x, y, w)
		"skills": h = _pSkills(x, y, w)
		"quests": h = _pQuests(x, y, w)
		"map": h = _pMap(x, y, w)
		"bestiary": h = _pBestiary(x, y, w)
		"controls": h = _pControls(x, y, w)
		"world": h = _pWorld(x, y, w)
	contentH.panel = h + 20


# ================================================================ Character

const STAT_KEYS := ["Level", "Boss Coins", "EXP", "Max HP", "Attack", "Defense", "Critical rate", "Critical damage", "Move speed", "Attack speed", "Monsters defeated", "Best combo"]

func attrName(a: String) -> String:
	if a == "STR":
		return "ATK"   # Attack Power, for every hero (the save still calls it STR)
	if a == "DEX" and classId == "archer":
		return "LUK"
	return a


func attrDesc(a: String) -> String:
	if a == "STR":
		return "Attack power"
	if a == "WIL":
		return "%s recovery" % CLASSES[classId].resource
	return ATTRS[a]


func attrTip(a: String) -> String:
	var res = CLASSES[classId].resource.to_lower()
	var pn = "Attack Power"
	var why = {"rock": "the force behind every swing", "archer": "steady hands and a sure draw", "mage": "the sharpness of every spell", "summoner": "the bond that makes your companions fight harder", "tank": "the muscle behind every bolt you tighten"}.get(classId, "")
	return {"STR": "%s: %s. +3 attack per point — the simplest way to hit harder." % [pn, why],
		"WIL": "Willpower. Speeds up %s recovery and slightly raises its maximum. Each point helps a little less than the last, so skills never become free to spam." % res,
		"VIT": "Vitality. +14 max HP and +0.9 defense per point. Defense blocks a share of damage that shrinks against higher-level monsters (75% at most).",
		"AGI": "Agility. Faster movement and faster attacks (each capped around +45–50%).",
		"DEX": ("Luck" if classId == "archer" else "Dexterity") + ". +0.7% critical rate and a bit more critical damage per point."}.get(a, "")


func _pTree(_x: float, _y: float, _w: float) -> float: return 0.0   # tree_ui.gd


func _pChar(x: float, y: float, w: float) -> float:
	var c = CH()
	var s = PS
	var vals = [str(c.level), str(save.get("bossCoins", 0)), "%s / %s" % [fmt(c.exp), fmt(expNeed(c.level))],
		str(s.hp), str(s.atk), str(s.def), "%.1f%%" % s.crit, "%d%%" % roundi(s.critDmg * 100), "%d%%" % roundi(s.spd * 100),
		"%d%%" % roundi(s.aspd * 100), fmt(c.kills), RANKS[save.bestRank].r if save.get("bestRank", -1) >= 0 else "none yet"]
	var J = jobOf(c.level)
	var ji = jobIndex(c.level)
	var nextJ = JOBS[ji + 1] if ji + 1 < JOBS.size() else null
	var C: Dictionary = CLASSES[classId]
	var card1 = func(X, Y, W):
		var tw = uText(C.name, X, Y, 11)
		jobPill(J, X + tw + 8, Y)
		var yy = Y + 18
		yy += muted("%s · 1 attribute point (for the Attribute Tree) and 3 skill points per level%s" % [C.role, (" · becomes a **%s** at Lv %d" % [nextJ.name, nextJ.lv]) if nextJ else ""], X, yy, W) + 4
		for i in STAT_KEYS.size():
			yy += statRow(X, yy, W, STAT_KEYS[i], vals[i], STAT_TIPS.get(STAT_KEYS[i], ""))
		return yy - Y
	var card2 = func(X, Y, W):
		var tp = int(c.get("tp", 0))
		uText("Attributes", X, Y, 11)
		if tp > 0:
			uPill("%d to spend" % tp, X + W, Y + 1, GOLD, INK, 8, 2)
		var yy = Y + 20
		yy += muted("Grown in the **Attribute Tree**: one point every level.", X, yy, W) + 4
		var T = TREE.totals(c.get("tree", {}))
		for a in ATTRS:
			uText(attrName(a), X, yy + 3, 10)
			uText(attrDesc(a), X + 40, yy + 4, 8, MUTED, UF)
			var bonus = int(T.get(a, 0))
			uText(str(int(c.attrs[a]) + bonus), X + W - 4, yy + 3, 10, INK, UB, 2)
			if bonus:
				uText("+%d tree" % bonus, X + W - 34, yy + 4, 7, css("#2a8a55"), UB, 2)
			zone(Rect2(X, yy, W, 20), Callable(), attrTip(a))
			yy += 21
		uButton(Rect2(X, yy + 2, W, 20), "🌳 Open the Attribute Tree", func(): openTab("tree"), {"bg": GOLD if tp > 0 else MINT, "size": 9})
		yy += 24
		return yy - Y
	var y0 = y
	y += uCards(x, y, w, 2, [card1, card2])
	y += 12
	var owned: Dictionary = save.get("boons", {})
	y += uCards(x, y, w, 1, [func(X, Y, W):
		var tw = uText("Boss treasures", X, Y, 11, css("#8a5a08"))
		uPill("ACCOUNT-WIDE · every hero", X + tw + 8, Y + 1, css("#ffe08a"), css("#6a4400"), 7)
		var yy = Y + 18
		yy += muted("Rare finds in Crocboxes, Crimsonboxes, Dreamboxes and Yetiboxes (about 1 box in 7). Each one raises a stat for good, for every one of your heroes, and they stack." , X, yy, W) + 4
		var cw = (W - 10) / 2
		for i in BOON_ORDER.size():
			var id: String = BOON_ORDER[i]
			var it: Dictionary = BOONS[id]
			var n = int(owned.get(id, 0))
			var cx = X + (i % 2) * (cw + 10)
			var cy = yy + floori(i / 2.0) * 22
			var a = 1.0 if n else 0.45
			uText(it.icon, cx, cy + 2, 12, Color(1, 1, 1, a))
			var nw = uText(it.name, cx + 20, cy + 1, 9, Color(INK, a))
			uText(("  ×%d" % n) if n else "", cx + 20 + nw, cy + 2, 8, css("#2a8a55"), UB)
			var srcs = []
			for bk in [["croc", "Crocbox"], ["warlord", "Crimsonbox"], ["dreamer", "Dreambox"], ["kingYeti", "Yetibox"]] + MORE_BOSSES.keys().filter(func(k): return BOXES.has(k)).map(func(k): return [k, BOXES[k].name]):
				if BOXES[bk[0]].items.has(id):
					srcs.append(bk[1])
			var src = " & ".join(srcs)
			uText("%s · %s" % [it.desc, src], cx + 20, cy + 12, 7, Color(MUTED, a), UF)
		yy += ceili(BOON_ORDER.size() / 2.0) * 22
		return yy - Y], [{"fill": css("#fff6e3"), "border": css("#c89418")}])
	return y - y0


# ================================================================ Inventory

func _pInv(x: float, y: float, w: float) -> float:
	var B = save.get("bestiary", {})
	var cards = 0
	for k in save.get("cards", {}):
		for q in ["n", "ng", "s", "sg"]:
			if save.cards[k].get(q):
				cards += 1
	var y0 = y
	y += currencyBag(x, y, w, "", cards)
	# boxes, loot bags and treasures side by side
	y += uCards(x, y, w, 3, [_invBoxes(), _invBags(), _invRares()],
		[{"fill": css("#fff8e6"), "border": css("#e0b34a")}, {"fill": css("#fdf3e4"), "border": css("#a0703a")}, {"fill": css("#eef8ff"), "border": css("#3a8ac0")}])
	y += 10
	# materials, three to a row
	var mats = func(X, Y, W):
		var yy = Y + h3("Materials", X, Y)
		var cols = 3
		var gap = 14.0
		var cw = (W - gap * (cols - 1)) / cols
		var keys: Array = SLIME_KEYS.duplicate()
		keys.sort_custom(func(a, b): return SLIME_TYPES[a].lv < SLIME_TYPES[b].lv)
		for i in keys.size():
			var k: String = keys[i]
			var cx = X + (i % cols) * (cw + gap)
			var ry = yy + floori(i / float(cols)) * 19
			var n = int(save.mats.get(k, 0))
			var seen = B.get(k, {}).get("kills", 0)
			var a = 1.0 if n else 0.5
			matIcon(k, cx + 1, ry + 2, 12)
			uText(matName(k), cx + 18, ry + 2, 9, Color(INK, a))
			uText("×" + fmt(n), cx + cw - 2, ry + 2, 9, Color(INK, a), UB, 2)
			dashed(cx, cx + cw, ry + 17)
			zone(Rect2(cx, ry, cw, 17), Callable(), "%s\n%s" % [MAT_TIPS.get(k, ""), ("Dropped by %s (Lv %d)" % [SLIME_TYPES[k].name, SLIME_TYPES[k].lv]) if seen else "Dropped by ???"])
		yy += ceili(keys.size() / float(cols)) * 19 + 4
		yy += muted("Materials are shared by all heroes and spent in the Shop. Hover one to see who drops it.", X, yy, W)
		return yy - Y
	y += uCards(x, y, w, 1, [mats])
	var KI: Dictionary = save.get("keyItems", {})
	if tb(KI.get("dreamKey")) or tb(KI.get("yetiPendant")):
		y += 10
		var keyCards = []
		if tb(KI.get("dreamKey")):
			keyCards.append(_keyCard("items/dream_key.png", "The Dream Key", css("#6a2a9a"), "Dropped by The Dreamer. It hums when you hold it. It can break the crystal that Glamrax keeps people imprisoned in, high over the Abyss Volcano."))
		if tb(KI.get("yetiPendant")):
			keyCards.append(_keyCard("items/yeti_pendant.png", "Glowing Pendant", css("#1f6f9a"), "Taken from King Yeti. Its light tore open the portal out of the collapsing cave, and it keeps that way to Glamrax's Gate open."))
		var st = []
		for k in keyCards:
			st.append({"fill": css("#f6efff"), "border": css("#6a2a9a")})
		y += uCards(x, y, w, 2, keyCards, st)
	return y - y0


func _keyCard(tex: String, name: String, col: Color, text: String) -> Callable:
	return func(X, Y, W):
		var t = Assets.tex(tex)
		if t:
			uci.draw_texture_rect(t, Rect2(X, Y, 32, 32), false)
		uText(name, X + 40, Y + 2, 10, col)
		var h = uPara(text, X + 40, Y + 16, W - 40, 8, MUTED)
		return maxf(34, 16 + h)


## a row of small buttons, right to left from `bx`; each is [label, callable]
func _btnRow(btns: Array, X: float, Y: float) -> void:
	var bx = X
	for b in btns:
		var bw = uW(b[0], 8) + 12
		uButton(Rect2(bx, Y, bw, 17), b[0], b[1], {"bg": b[2] if b.size() > 2 else MINT, "shadow": 0.0, "size": 8})
		bx += bw + 4


func _invBoxes() -> Callable:
	return func(X, Y, W):
		var yy = Y + h3("Boss boxes", X, Y)
		var boxKinds = (["croc", "warlord", "dreamer", "kingYeti"] + MORE_BOSSES.keys().filter(func(k): return BOXES.has(k))).filter(func(k): return boxCount(k) > 0)
		if boxKinds.is_empty():
			return yy - Y + muted("A boss drops a box every time you beat it. Open them here.", X, yy, W)
		for k in boxKinds:
			var BX: Dictionary = BOXES[k]
			var n = boxCount(k)
			var col = css(MORE_BOSSES[k].ui) if MORE_BOSSES.has(k) else css("#1f6f9a") if k == "kingYeti" else css("#6a2a9a") if k == "dreamer" else (css("#9a1f35") if k == "warlord" else css("#2a7a3a"))
			uText("📦 %s ×%d" % [BX.name, n], X + 2, yy + 2, 10, col, UB)
			uText("from %s" % BX.boss, X + W, yy + 4, 7, MUTED, UF, 2)
			var btns = []
			for q in [["1", 1], ["5", 5], ["10", 10], ["All", n]]:
				var cnt: int = q[1]
				if cnt <= 0 or (cnt > n and q[0] != "All") or (q[0] == "All" and n <= 1):
					continue
				btns.append(["Open %s" % q[0], func(): toggleMenu(false); openBoxes(k, cnt)])
			_btnRow(btns, X + 2, yy + 17)
			dashed(X, X + W, yy + 39)
			yy += 43
		return yy - Y


func _invBags() -> Callable:
	return func(X, Y, W):
		var yy = Y + h3("Loot bags", X, Y)
		var kinds = SLIME_KEYS.filter(func(k): return bagCount(k) > 0)
		if kinds.is_empty():
			return yy - Y + muted("Every monster has a 1 in 100 chance to drop a loot bag: EXP, coins, its material, and sometimes its rare treasure.", X, yy, W)
		for k in kinds:
			var n = bagCount(k)
			withCtx(Vector2(X + 9, yy + 20), 1.3, func(cx): drawLootBag(cx, k, 0, 0, realTime))
			uText("%s Bag" % SLIME_TYPES[k].name, X + 22, yy + 2, 9, INK, UB)
			uText("×%d" % n, X + W, yy + 2, 9, INK, UB, 2)
			var btns = [["Open 1", func(): _openBags(k, 1)]]
			if n > 1:
				btns.append(["Open all", func(): _openBags(k, n)])
			_btnRow(btns, X + 22, yy + 15)
			dashed(X, X + W, yy + 36)
			yy += 40
		return yy - Y


func _openBags(k: String, n: int) -> void:
	var got = openBags(k, n)
	if got.exp == 0 and got.coins == 0:
		return
	Sfx.buy()
	var bits = ["+%s EXP" % fmt(got.exp), "+%s coins" % fmt(got.coins), "+%d %s" % [got.mats, matName(k).to_lower()]]
	toast("💰 %s: %s" % ["Loot bag" if n == 1 else "%d loot bags" % n, ", ".join(bits)])
	for key in got.rares:
		Sfx.rankUp(9 if key.ends_with("_shiny") else 7)
		banner("SHINY RARE TREASURE!" if key.ends_with("_shiny") else "RARE TREASURE!", "%s%s · sells for %s coins" % [rareName(key), (" ×%d" % got.rares[key]) if got.rares[key] > 1 else "", fmt(rareValue(key))])
	PS = calcStats()
	persist()
	_changed()


func _invRares() -> Callable:
	return func(X, Y, W):
		uText("Rare treasures", X, Y, 10)
		var R: Dictionary = save.get("rares", {})
		var keys = R.keys().filter(func(k): return int(R[k]) > 0)
		keys.sort_custom(func(a, b): return rareValue(a) > rareValue(b))
		var yy = Y + 15
		if keys.is_empty():
			return yy - Y + muted("Every monster has a rare treasure it drops once in a long while (or from its loot bag). They aren't for crafting: sell them for a fortune. Shiny ones are worth five times as much.", X, yy, W)
		var total = 0
		for k in keys:
			total += rareValue(k) * int(R[k])
		uButton(Rect2(X + W - 70, Y - 2, 70, 15), "Sell all", func(): _sellRares(keys, -1), {"bg": GOLD, "shadow": 0.0, "size": 7})
		for k in keys:
			var n = int(R[k])
			var shiny = k.ends_with("_shiny")
			withCtx(Vector2(X + 8, yy + 19), 1.3, func(cx): drawRare(cx, rareType(k), shiny, 0, 0, realTime))
			uText(rareName(k), X + 22, yy + 1, 9, css("#b0549a") if shiny else INK, UB)
			uText("×%d" % n, X + W, yy + 1, 9, INK, UB, 2)
			uText("%s each" % fmt(rareValue(k)), X + 22, yy + 13, 7, MUTED, UF)
			var btns = [["Sell 1", func(): _sellRares([k], 1)]]
			if n > 1:
				btns.append(["Sell all", func(): _sellRares([k], -1)])
			var bx = X + W
			for b in btns:
				bx -= uW(b[0], 8) + 12 + 4
			_btnRow(btns, bx + 4, yy + 12)
			zone(Rect2(X, yy, 22, 26), Callable(), "Dropped by %s. Not used for crafting: sell it for coins." % monsterName(rareType(k)))
			dashed(X, X + W, yy + 31)
			yy += 35
		yy += muted("Worth %s coins in all." % fmt(total), X, yy, W)
		return yy - Y


func _sellRares(keys: Array, n: int) -> void:
	var paid = 0
	for k in keys:
		paid += sellRares(k, int(save.rares.get(k, 0)) if n < 0 else n)
	if paid > 0:
		Sfx.coin()
		Sfx.buy()
		toast("Sold for %s coins." % fmt(paid))
		persist()
		_changed()


# ================================================================ Shop

func _pShop(x: float, y: float, w: float) -> float:
	var y0 = y
	var sx = x
	var tabs = [["gear", "Gear"], ["abyss", "Abyssal Shop"], ["boss", "Boss Shop"], ["house", "House"]]
	if classId == "tank":
		tabs.insert(1, ["workshop", "Workshop"])
	elif shopTab == "workshop":
		shopTab = "gear"
	for T in tabs:
		var id: String = T[0]
		var bw = uW(T[1], 9) + 18
		uButton(Rect2(sx, y, bw, 18), T[1], func(): shopTab = id; scrollY.panel = 0.0; Sfx.ui(), {"on": shopTab == id, "bg": css("#f1f3fa"), "shadow": 0.0})
		sx += bw + 4
	y += 24
	dashed(x, x + w, y - 2, LINE)
	y += 6
	y += currencyBag(x, y, w, "Materials are in the Inventory tab.")
	match shopTab:
		"abyss": y += abyssCard(x, y, w)
		"boss": y += bossCard(x, y, w)
		"house": y += houseCard(x, y, w)
		"workshop": y += workshopCard(x, y, w)
		_: y += gearCards(x, y, w)
	return y - y0


## every requirement as a chip showing have / need, red when short; returns the block's height
func costBlock(t: Dictionary, x: float, y: float, w: float) -> float:
	var chips = []
	if CH().level < t.lv:
		chips.append([false, "Requires **Lv %d**" % t.lv, ""])
	chips.append([save.coins >= t.coins, "**%s** coins (you have %s)" % [fmt(t.coins), fmt(save.coins)], "coin"])
	if int(CH().get("armor", 0)) < t.get("needArmor", 0):
		chips.append([false, "Needs the **%s**" % GEAR.tank.armor[t.needArmor].name, ""])
	for k in t.get("mats", {}):
		chips.append([save.mats.get(k, 0) >= t.mats[k], "**%d / %d** %s" % [save.mats.get(k, 0), t.mats[k], matName(k).to_lower()], k])
	for k in t.get("parts", {}):
		chips.append([partCount(k) >= t.parts[k], "**%d / %d** %s" % [partCount(k), t.parts[k], PART_INFO[k].name.to_lower()], "p_" + k])
	var items = [[uW("COST", 6, PX) + 2, func(X, Y): uText("COST", X, Y + 5, 6, css("#8a5a08"), PX)]]
	for ch in chips:
		var cw = uW(ch[1].replace("**", ""), 8) + (24 if ch[2] != "" else 12)
		items.append([cw, func(X, Y):
			bgBox(1, Rect2(X, Y, cw, 15), css("#e6f9ee") if ch[0] else css("#ffe8ec"), css("#2a8a55") if ch[0] else css("#d13c55"), 2, 7)
			var tx = X + 6
			if ch[2] == "coin":
				_coin(Vector2(X + 9, Y + 7.5), 4)
				tx += 10
			elif ch[2].begins_with("p_"):
				var pt = Assets.tex("tank/part_%s.png" % ch[2].substr(2))
				if pt:
					uci.draw_texture_rect(pt, Rect2(X + 4, Y + 3, 9, 9), false)
				tx += 10
			elif ch[2] != "":
				matDot(ch[2], X + 5, Y + 3.5)
				tx += 10
			uPara(ch[1], tx, Y + 2, 400, 8, css("#1d5e3a") if ch[0] else css("#9a1f35"), true, false, 0, UF, UB)])
	var h = flow(x + 7, y + 7, w - 14, items, 15, 4) + 14
	bgBox(1, Rect2(x, y, w, h), css("#fff8e6"), css("#e0b34a"), 2, 7)
	uci.draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), NONE)
	return h + 6


func buyBtn(t: Dictionary, kind: String, verb: String, x: float, y: float, w: float) -> float:
	var label = ("Unlocks at Lv %d" % t.lv) if CH().level < t.lv else "%s · %s coins" % [verb, fmt(t.coins)]
	uButton(Rect2(x, y, w, 19), label, func(): _buy(kind), {"disabled": not canBuy(t), "bg": MINT})
	return 21.0


func _gearCard(kind: String, tiers: Array, cur: int) -> Callable:
	return func(X, Y, W):
		var C: Dictionary = CLASSES[classId]
		var nx = _tier(tiers, cur + 1)
		var yy = Y + h2(C.armorLabel if kind == "armor" else ("Staff" if kind == "staff" else C.weaponLabel), X, Y, W)
		# the picture shows the next tier on the hero, so you can see what the upgrade looks like
		var c = CH()
		var pv = {"armor": int(c.armor), "weapon": int(c.weapon), "staff": int(c.get("staff", 0))}
		if nx:
			pv[kind] = cur + 1
		heroPic(Rect2(X, yy, 44, 54), classId, "idle", 0, true, gearLook(classId, pv.armor, pv.weapon, pv.staff))
		if nx:
			uText("Next", X + 22, yy + 46, 7, css("#2a8a55"), UB, 1)
		var tx = X + 52
		uPara("Now: **%s**" % tiers[cur].name, tx, yy + 4, W - 52, 9, INK)
		if nx:
			uPara("→ **%s**" % nx.name, tx, yy + 20, W - 52, 9, css("#2a8a55"))
		yy += 60
		if nx:
			uText(("+%d HP, +%d DEF" % [nx.hp, nx.def]) if kind == "armor" else ("+%d ATK, +%d DEF" % [nx.atk, nx.def]), X, yy, 9)
			yy += 15
			yy += costBlock(nx, X, yy, W)
			yy += buyBtn(nx, kind, "Upgrade", X, yy, W)
		else:
			yy += muted("Fully upgraded.", X, yy, W)
		return yy - Y


func gearCards(x: float, y: float, w: float) -> float:
	if classId == "tank":
		return tankGearCards(x, y, w)
	var c = CH()
	var G = GEAR[classId]
	var cards = [_gearCard("armor", G.armor, c.armor), _gearCard("weapon", G.weapon, c.weapon)]
	if G.get("staff"):
		cards.append(_gearCard("staff", G.staff, c.get("staff", 0)))
	cards.append(func(X, Y, W):
		var cur = _tier(CHARM_TIERS, c.charm)
		var nxc = _tier(CHARM_TIERS, c.charm + 1)
		var yy = Y + h2("Charm", X, Y, W)
		yy += muted("A trinket that hangs from %s. Bought at Lv 1, upgraded every 3 levels." % ("the bow" if classId == "archer" else ("the staff" if classId == "mage" else "the hilt")), X, yy, W) + 2
		uPara("**%s**%s" % [cur.name if cur else "No charm yet", (" → **%s**" % nxc.name) if nxc else ""], X, yy, W, 9)
		yy += 15
		if cur:
			yy += muted("Now: +%d ATK, +%s%% crit, +%s%% EXP, +%s%% coins" % [cur.atk, str(cur.crit), str(cur.exp), str(cur.coin)], X, yy, W)
		if nxc:
			yy += uPara("%s: +%d ATK, +%s%% crit, +%s%% EXP, +%s%% coins" % ["Next" if cur else "Gives", nxc.atk, str(nxc.crit), str(nxc.exp), str(nxc.coin)], X, yy, W, 9, INK, true, true) + 3
			yy += costBlock(nxc, X, yy, W)
			yy += buyBtn(nxc, "charm", "Upgrade" if cur else "Buy", X, yy, W)
		else:
			yy += muted("Fully upgraded.", X, yy, W)
		return yy - Y)
	if G.get("arrows"):
		cards.append(func(X, Y, W):
			var ca = c.get("arrows", 0)
			var cur2 = G.arrows[ca]
			var nx2 = _tier(G.arrows, ca + 1)
			var yy = Y + h2("Arrows", X, Y, W)
			yy += muted("Better arrowheads add damage to every arrow you fire.", X, yy, W) + 2
			_arrowChip(cur2, X, yy + 2)
			yy += uPara("**%s** · +%d%% arrow damage" % [cur2.name, roundi(cur2.dmg * 100)], X + 22, yy, W - 22, 9) + 3
			if nx2:
				_arrowChip(nx2, X, yy + 2)
				yy += uPara("Next: %s · +%d%% arrow damage" % [nx2.name, roundi(nx2.dmg * 100)], X + 22, yy, W - 22, 9, INK, true, true) + 3
				yy += costBlock(nx2, X, yy, W)
				yy += buyBtn(nx2, "arrows", "Upgrade", X, yy, W)
			else:
				yy += muted("Fully upgraded.", X, yy, W)
			return yy - Y)
	var h = uCards(x, y, w, 3, cards)
	h += 8 + uCards(x, y + h + 8, w, 1, [cosmeticsCard()])
	return h


func _arrowChip(t: Dictionary, x: float, y: float) -> void:
	for i in 2:
		var r = Rect2(x + i * 9, y, 8, 8)
		uci.draw_rect(r, hexc(int(t.head if i == 0 else t.fletch)))
		uci.draw_rect(r, INK, false, 1)


func _buy(kind: String) -> void:
	var c = CH()
	var G = GEAR[classId]
	var tiers: Array = G.armor if kind == "armor" else (G.weapon if kind == "weapon" else (G.get("staff", []) if kind == "staff" else (G.get("arrows", []) if kind == "arrows" else (G.get("nade", []) if kind == "nade" else CHARM_TIERS))))
	if kind == "nade" and not c.has("nade"):
		c.nade = 0
	if kind == "arrows" and not c.has("arrows"):
		c.arrows = 0
	if kind == "staff" and not c.has("staff"):
		c.staff = 0
	var t = _tier(tiers, c[kind] + 1)
	if t == null or not canBuy(t):
		return
	save.coins -= t.coins
	for k in t.get("mats", {}):
		save.mats[k] -= t.mats[k]
	spendParts(t.get("parts", {}))
	c[kind] += 1
	PS = calcStats()
	Sfx.buy()
	Sfx.levelUp()
	var big = {"armor": "Exosuit upgraded!" if classId == "tank" else "Armor upgraded!", "nade": "New grenades!", "staff": "New staff!", "arrows": "New arrows!", "charm": "Charm acquired!"}.get(kind,
		"New bow!" if classId == "archer" else ("New wand!" if classId == "mage" else "New weapon!"))
	banner(big, t.name)
	_changed()


func cosmeticsCard() -> Callable:
	return func(X, Y, W):
		var c = CH()
		var yy = Y + h2("Cosmetics", X, Y, W)
		heroPic(Rect2(X, yy, 64, 80), classId)
		uText(CLASSES[classId].name, X + 32, yy + 84, 8, INK, UB, 1)
		var tx = X + 76
		var tw = W - 76
		var ty = yy
		for cat in cosCats(classId):
			ty += h3(COS_LABEL[cat], tx, ty)
			var items = []
			for o in COSMETICS[cat]:
				var owned = c.cos[cat].has(o.id)
				var on = c.look.get(cat) == o.id
				var bw = maxf(66, uW(o.name, 8) + (26 if o.get("col") != null else 12))
				var price = COS_PRICE[cat]
				items.append([bw, func(bx, by):
					var r = Rect2(bx, by, bw, 26)
					uButton(r, "", func(): _cos(cat, o.id), {"on": on, "bg": PANEL2 if owned else css("#f1f3fa"), "disabled": not owned and save.coins < price, "shadow": 1.0})
					var lx = bx + 6
					if o.get("col") != null:
						uci.draw_circle(Vector2(bx + 11, by + 8), 5, INK)
						uci.draw_circle(Vector2(bx + 11, by + 8), 3.8, hexc(int(o.col)))
						lx += 12
					uText(o.name, lx, by + 2, 8)
					uText("Equipped" if on else ("Owned" if owned else "%s coins" % fmt(price)), bx + bw / 2, by + 14, 7, Color(INK, 0.8), UF, 1)])
			ty += flow(tx, ty, tw, items, 26, 4) + 6
		ty += muted("Your hero's starting look is free. Anything you buy stays unlocked for this hero. (Cosmetics show on the hero once the new character art is in; for now the hero keeps the starter look.)", tx, ty, tw)
		return maxf(ty, yy + 96) - Y


func _cos(cat: String, id: String) -> void:
	var c = CH()
	if not c.cos[cat].has(id):
		if save.coins < COS_PRICE[cat]:
			return
		save.coins -= COS_PRICE[cat]
		c.cos[cat].append(id)
		Sfx.buy()
		for o in COSMETICS[cat]:
			if o.id == id:
				toast("Bought %s!" % o.name)
	if c.look.get(cat) != id:
		c.look[cat] = id
		Sfx.ui()
	_changed()


## one shop line: icon, name n/max, description, and a buy button
func shopItem(X: float, yy: float, W: float, it: Dictionary, n: int, cost: int, coin: String, can: bool, cb: Callable, dark := false) -> float:
	var maxed = n >= it.max
	var txtCol = css("#efe0ff") if dark else INK
	var sub = css("#c8b0e0") if dark else MUTED
	dashed(X, X + W, yy, css("#4a3060") if dark else LINE)
	uText(it.icon, X + 2, yy + 6, 14, Color.WHITE)
	var bw = 62.0
	var tw = W - 30 - bw - 6
	var nw = uText(it.name, X + 28, yy + 5, 9, txtCol)
	uText((" ×%d" % n) if it.max >= UNLIMITED else (" %d/%d" % [n, it.max]), X + 28 + nw, yy + 6, 8, sub, UF)
	var dh = uPara(it.desc + ((" · now %d×" % n) if n else ""), X + 28, yy + 18, tw, 8, sub)
	var h = maxf(30, 20 + dh) + 4
	var br = Rect2(X + W - bw, yy + h / 2 - 9, bw, 18)
	uButton(br, "Maxed" if maxed else "%d    " % cost, cb, {"disabled": maxed or not can, "bg": css("#ff9ef0") if dark else MINT})
	if not maxed:
		_coin(Vector2(br.get_center().x + uW(str(cost), 9) / 2 + 2, br.get_center().y), 4.5, coin)
	return h


func bossCard(x: float, y: float, w: float) -> float:
	var c = CH()
	return uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y
		uText("Boss Shop", X, yy, 11)
		var pw = uW(fmt(save.get("bossCoins", 0)), 8) + 22
		uBox(Rect2(X + W - pw, yy, pw, 14), GOLD, NONE, 0, 7)
		_coin(Vector2(X + W - pw + 8, yy + 7), 4, "boss")
		uText(fmt(save.get("bossCoins", 0)), X + W - pw + 15, yy + 2, 8)
		yy += 18
		yy += muted("Paid in Boss Coins — one for every boss you defeat. Permanent for %s." % CLASSES[classId].name, X, yy, W) + 4
		for it in BOSS_SHOP:
			var n = int(c.bshop.get(it.id, 0))
			var cost = bossCost(n)
			yy += shopItem(X, yy, W, it, n, cost, "boss", save.get("bossCoins", 0) >= cost, func(): _bshop(it.id))
		return yy - Y], [{"fill": css("#fff0ea"), "border": css("#a82a30")}])


func _bshop(id: String) -> void:
	var c = CH()
	for it in BOSS_SHOP:
		if it.id != id:
			continue
		var n = int(c.bshop.get(id, 0))
		var cost = bossCost(n)
		if n < it.max and save.get("bossCoins", 0) >= cost:
			save.bossCoins -= cost
			c.bshop[id] = n + 1
			_restat()
			Sfx.buy()
			toast("%s — %s" % [it.name, it.desc])
			_changed()


func abyssCard(x: float, y: float, w: float) -> float:
	var c = CH()
	return uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y
		uText("Abyssal Shop", X, yy, 11, css("#efe0ff"))
		var pw = uW(fmt(save.get("abyssCoins", 0)), 8) + 22
		uBox(Rect2(X + W - pw, yy, pw, 14), css("#1a0828"), NONE, 0, 7)
		_coin(Vector2(X + W - pw + 8, yy + 7), 4, "abyss")
		uText(fmt(save.get("abyssCoins", 0)), X + W - pw + 15, yy + 2, 8, css("#ffd0f4"))
		yy += 18
		yy += muted("Abyssal Coins come from the tentacled swarms an Obelisk can summon. Everything here is permanent for %s." % CLASSES[classId].name, X, yy, W, css("#c8b0e0")) + 4
		var cw = (W - 12) / 2
		var hs = []
		for i in 2:
			var kind = ["pot", "eng"][i]
			var cx = X + i * (cw + 12)
			var cy = yy + h3(["Potions", "Weapon engravings"][i], cx, yy, css("#ff9ef0"))
			for it in ABYSS_SHOP[kind]:
				var n = int(c.abyss[kind].get(it.id, 0))
				var cost = abyssCost(kind, n)
				cy += shopItem(cx, cy, cw, it, n, cost, "abyss", save.get("abyssCoins", 0) >= cost, func(): _abyss(kind, it.id), true)
			hs.append(cy)
		return maxf(hs[0], hs[1]) - Y], [{"fill": css("#22142f"), "border": css("#1a0828")}])


func _abyss(kind: String, id: String) -> void:
	var c = CH()
	for it in ABYSS_SHOP[kind]:
		if it.id != id:
			continue
		var n = int(c.abyss[kind].get(id, 0))
		var cost = abyssCost(kind, n)
		if n < it.max and save.get("abyssCoins", 0) >= cost:
			save.abyssCoins -= cost
			c.abyss[kind][id] = n + 1
			_restat()
			Sfx.buy()
			toast("%s — %s" % [it.name, it.desc])
			_changed()


func houseCard(x: float, y: float, w: float) -> float:
	var Hs: Dictionary = save.house
	var y0 = y
	y += muted("Furniture goes in your house and helps every hero. Only the piece you place counts, and you can swap between pieces you own for free.", x, y, w) + 6
	var cards = []
	for k in FURN_ORDER:
		cards.append(_furnCard(k))
	cards.append(func(X, Y, W):
		var shelf = null
		for i in FURNITURE.shelf.items:
			if i.id == Hs.placed.get("shelf"):
				shelf = i
		var slots = int(shelf.val) if shelf else 0
		uText("Shelf curios", X, Y, 11)
		var yy = Y + 16
		yy += muted("%d/%d on display%s" % [Hs.shelfItems.size(), slots, "" if shelf else " — place a shelf first"], X, yy, W)
		for it in CURIOS:
			var on = Hs.shelfItems.has(it.id)
			var own = Hs.get("curios", []).has(it.id)
			yy += _fitem(X, yy, W, it.name, it.desc, it.flavor, on, func(px, py): withCtx(Vector2(px, py), 2.5, func(cx): drawCurio(cx, it.id, 10, 12)),
				func(bx, by):
					if not own:
						_priceBtn(Rect2(bx, by, 64, 18), it.price, func(): _cbuy(it.id))
					else:
						uButton(Rect2(bx, by, 64, 18), "Take down" if on else "Display", func(): _ctoggle(it.id), {"disabled": not on and Hs.shelfItems.size() >= slots, "size": 8}))
		return yy - Y)
	y += uCards(x, y, w, 2, cards)
	return y - y0


func _priceBtn(r: Rect2, price: int, cb: Callable) -> void:
	uButton(r, fmt(price) + "    ", cb, {"disabled": save.coins < price, "bg": MINT, "size": 8})
	_coin(Vector2(r.get_center().x + uW(fmt(price), 8) / 2 + 2, r.get_center().y), 4)


## a furniture or curio line: preview, name, bonus, flavour text, and a button
func _fitem(X: float, yy: float, W: float, name: String, bonus: String, flavor: String, placed: bool, pic: Callable, btn: Callable) -> float:
	var tw = W - 50 - 72
	var h = maxf(40, 16 + uPara(flavor, 0, 0, tw, 7, MUTED, false) + 12) + 6
	if placed:
		bgBox(1, Rect2(X - 4, yy, W + 8, h), css("#fff8e0"), NONE, 0, 4)
	dashed(X, X + W, yy)
	var pr = Rect2(X, yy + 4, 46, 32)
	uBox(pr, css("#f2e4c8"), INK, 2, 5)
	uci.draw_rect(Rect2(pr.position.x + 2, pr.position.y + 22, pr.size.x - 4, 8), css("#a8743e"))
	pic.call(pr.position.x + 2, pr.position.y + 1)
	uText(name, X + 52, yy + 4, 9)
	uText(bonus, X + 52, yy + 16, 8, css("#2a8a55"), UB)
	uPara(flavor, X + 52, yy + 27, tw, 7, MUTED)
	btn.call(X + W - 66, yy + h / 2 - 9)
	return h


func _furnCard(k: String) -> Callable:
	return func(X, Y, W):
		var F: Dictionary = FURNITURE[k]
		var Hs: Dictionary = save.house
		var tw = uText(F.label, X, Y, 11)
		uText(F.stat, X + tw + 6, Y + 2, 8, MUTED, UF)
		var yy = Y + 18
		for it in F.items:
			var placed = Hs.placed.get(k) == it.id
			var owned = Hs.owned.has(it.id)
			var bonus = ("%d curio slots" % it.val) if k == "shelf" else (("+%.1f%% max HP / sec" % (it.val * 100)) if k == "chair" else "+%d%% %s" % [roundi(it.val * 100), F.stat.to_lower()])
			yy += _fitem(X, yy, W, it.name, bonus, it.desc, placed,
				func(px, py): withCtx(Vector2(px, py), 0.8, func(cx): drawFurniture(cx, k, it.id, 26.5, 33 if k == "shelf" else 35, [])),
				func(bx, by):
					if placed:
						uPill("Placed", bx + 64, by + 2, GOLD, INK, 8, 2)
					elif owned:
						uButton(Rect2(bx, by, 64, 18), "Place", func(): _fplace(k, it.id), {"size": 8})
					else:
						_priceBtn(Rect2(bx, by, 64, 18), it.price, func(): _fbuy(k, it.id)))
		return yy - Y


func _fbuy(k: String, id: String) -> void:
	for it in FURNITURE[k].items:
		if it.id == id and save.coins >= it.price and not save.house.owned.has(id):
			save.coins -= it.price
			save.house.owned.append(id)
			save.house.placed[k] = id
			PS = calcStats()
			Sfx.buy()
			Sfx.levelUp()
			toast("%s placed in your house!" % it.name)
			_changed()


func _fplace(k: String, id: String) -> void:
	save.house.placed[k] = id
	if k == "shelf":
		for it in FURNITURE.shelf.items:
			if it.id == id:
				save.house.shelfItems = save.house.shelfItems.slice(0, int(it.val))
	PS = calcStats()
	Sfx.ui()
	_changed()


func _shelfCap() -> int:
	for it in FURNITURE.shelf.items:
		if it.id == save.house.placed.get("shelf"):
			return int(it.val)
	return 0


func _cbuy(id: String) -> void:
	var Hs = save.house
	if not Hs.has("curios"):
		Hs.curios = []
	for it in CURIOS:
		if it.id == id and save.coins >= it.price and not Hs.curios.has(id):
			save.coins -= it.price
			Hs.curios.append(id)
			if Hs.shelfItems.size() < _shelfCap():
				Hs.shelfItems.append(id)
			PS = calcStats()
			Sfx.buy()
			toast("%s bought!" % it.name)
			_changed()


func _ctoggle(id: String) -> void:
	var L: Array = save.house.shelfItems
	if L.has(id):
		L.erase(id)
	elif L.size() < _shelfCap():
		L.append(id)
	PS = calcStats()
	Sfx.ui()
	_changed()


# ================================================================ Skills

## The Skills tab: your class's advancements down the left, the chosen one's skills on the right.
## Each advancement is grander than the last — a heavier frame, a deeper colour, more stars — so the
## tab itself shows how far the hero has come.
func _pSkills(x: float, y: float, w: float) -> float:
	var c = CH()
	var cur = jobIndex(c.level)
	var y0 = y
	var pw = uW("%d skill points" % c.sp, 9) + 14
	uBox(Rect2(x, y, pw, 16), GOLD, INK, 2, 8)
	uText("%d skill points" % c.sp, x + 7, y + 3, 9)
	uText("3 per level. Actives and buffs go on hotkeys A S D F Q W E R.", x + pw + 8, y + 4, 8, MUTED, UF)
	y += 24
	# keep the selection sensible: default to the newest advancement you've reached
	if skillSel == "":
		skillSel = str(JOBS[cur].id)
	var colW = minf(142.0, w * 0.32)
	var paneX = x + colW + 10
	var paneW = w - colW - 10
	var ly = y
	for ji in JOBS.size():
		ly += _jobBtn(ji, cur, x, ly, colW)
	ly += 6
	ly += _navBtn("boss", "☠ Boss skills", css("#9a1f35"), css("#ffe0e6"), false, x, ly, colW)
	var ascOpen: bool = c.level > ASCEND_LV or ascSpent() > 0
	ly += _navBtn("asc", "✦ Ascendency", css("#4a1c7a"), css("#efe0ff"), not ascOpen, x, ly, colW)
	if not ascOpen:
		uText("Unlocks past Lv %d" % ASCEND_LV, x + 4, ly, 7, MUTED, UF)
		ly += 11
	var ph: float
	if skillSel == "boss":
		ph = uCards(paneX, y, paneW, 1, [func(X, Y, W):
			uText("Boss skills", X, Y, 11, css("#9a1f35"))
			var yy = Y + 18
			yy += muted("Very rare finds in boss boxes (about 1 box in 50). Any class can use them once found.", X, yy, W) + 4
			for s in BOSS_SKILLS:
				yy += _skillRow(s, X, yy, W, skillRank(s.id) == 0)
			return yy - Y], [{"fill": css("#fff0ea"), "border": css("#a82a30")}])
	elif skillSel == "asc":
		ph = _ascPane(paneX, y, paneW)
	else:
		var ji = 0
		for i in JOBS.size():
			if str(JOBS[i].id) == skillSel:
				ji = i
		ph = _jobPane(ji, ji > cur, paneX, y, paneW)
	return maxf(ly, y + ph) - y0


## one advancement in the left-hand list. The deeper the tier, the heavier and brighter the button.
func _jobBtn(ji: int, cur: int, x: float, y: float, w: float) -> float:
	var J: Dictionary = JOBS[ji]
	var locked = ji > cur
	var t: float = ji / maxf(1.0, JOBS.size() - 1.0)
	var on: bool = skillSel == str(J.id)
	var h = 26.0 + 10 * t
	var r = Rect2(x, y, w, h)
	var col = css(J.color)
	var bw = 2 + roundi(t * 2)
	if locked:
		uBox(r, css("#eceef6"), css("#c2c7d8"), 2, 7)
		uText("🔒", x + 7, y + h / 2 - 6, 9, Color(MUTED, 0.9))
		uText(J.name, x + 24, y + h / 2 - 7, 9, Color(MUTED, 0.9), UB)
		uText("Lv %d" % J.lv, x + 24, y + h / 2 + 4, 7, Color(MUTED, 0.8), UF)
		return h + 5
	if on:
		uGlow(r, Color(col, 0.55 + 0.3 * t), 5 + 5 * t, 8)
	uGrad(r, col.lerp(Color.WHITE, 0.55 - 0.3 * t), col.lerp(Color.WHITE, 0.3 - 0.2 * t), col.lerp(DARK, 0.1 + 0.3 * t), 0.5)
	uBox(r, Color(0, 0, 0, 0), GOLD if on else INK, bw, 7)
	# stars: one per tier reached, so the bottom of the list is studded with them
	var stars = ""
	for i in ji:
		stars += "✦"
	if stars != "":
		uText(stars, x + w - 5, y + 4, 6 + roundi(t * 2), Color(DARK if col.lerp(Color.WHITE, 0.3 - 0.2 * t).get_luminance() > 0.52 else GOLD, 0.85), UF, 2)
	var fg = DARK if col.lerp(Color.WHITE, 0.3 - 0.2 * t).get_luminance() > 0.52 else Color.WHITE
	uText(J.name, x + 8, y + h / 2 - 10 + 2 * t, 9 + roundi(t * 2), fg, UB, 0, Color(DARK, 0.0 if fg == DARK else 0.5))
	uText("Lv %d · hits %d" % [J.lv, J.get("targets", 1)], x + 8, y + h / 2 + 3 + 2 * t, 7, Color(fg, 0.8), UF)
	zone(r, func(): skillSel = str(J.id); scrollY.panel = 0.0; Sfx.ui(), "")
	return h + 5


func _navBtn(id: String, label: String, col: Color, bg: Color, locked: bool, x: float, y: float, w: float) -> float:
	var r = Rect2(x, y, w, 24)
	var on: bool = skillSel == id
	if locked:
		uBox(r, css("#eceef6"), css("#c2c7d8"), 2, 7)
		uText(label, x + 8, y + 7, 9, Color(MUTED, 0.9), UB)
		return 29.0
	if on:
		uGlow(r, Color(col, 0.5), 6, 8)
	uBox(r, bg, GOLD if on else col, 2 + (1 if on else 0), 7)
	uText(label, x + 8, y + 7, 9, col, UB)
	zone(r, func(): skillSel = id; scrollY.panel = 0.0; Sfx.ui(), "")
	return 29.0


## the right-hand pane for one advancement: a banner that grows more ornate the deeper the tier
func _jobPane(ji: int, locked: bool, x: float, y: float, w: float) -> float:
	var J: Dictionary = JOBS[ji]
	var t: float = ji / maxf(1.0, JOBS.size() - 1.0)
	var col = css(J.color)
	var y0 = y
	var bh = 34.0 + 12 * t
	var br = Rect2(x, y, w, bh)
	if t > 0.25:
		uGlow(br, Color(col, 0.35 + 0.35 * t), 6 + 8 * t, 10)
	uGrad(br, col.lerp(Color.WHITE, 0.5 - 0.35 * t), col.lerp(Color.WHITE, 0.25 - 0.2 * t), col.lerp(DARK, 0.15 + 0.35 * t), 0.5)
	uBox(br, Color(0, 0, 0, 0), GOLD if t > 0.5 else INK, 2 + roundi(t * 2), 10)
	# rays behind the title for the late advancements
	if t > 0.5:
		for i in 9:
			var ang = realTime * 0.25 + i * TAU / 9
			uci.draw_line(br.get_center(), br.get_center() + Vector2(cos(ang), sin(ang) * 0.4) * (w * 0.5), Color(Color.WHITE, 0.07 * t), 3)
	var fg = DARK if col.lerp(Color.WHITE, 0.25 - 0.2 * t).get_luminance() > 0.52 else Color.WHITE
	uText(J.name.to_upper(), x + 12, y + 8 + 3 * t, 11 + roundi(t * 3), fg, PX, 0, Color(DARK, 0.6 if t >= 0.6 else 0.0), 2)
	uText(("Unlocks at Lv %d" % J.lv) if locked else ("Plain attacks only" if ji == 0 else "Skills hit up to %d enemies" % J.get("targets", 1)),
		x + 12, y + bh - 14 + 2 * t, 8, Color(fg, 0.85), UF)
	if t > 0.25:
		var stars = ""
		for i in ji:
			stars += "✦"
		uText(stars, x + w - 10, y + 9, 8 + roundi(t * 3), Color(GOLD if fg == Color.WHITE else DARK, 0.9), UF, 2)
	y += bh + 8
	var rows = classSkills().filter(func(s): return s.get("job") == J.id)
	y += uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y
		for s in rows:
			yy += _skillRow(s, X, yy, W, locked)
		return yy - Y], [{"fill": Color.WHITE if not locked else css("#f4f5fa"), "border": col if t > 0.5 else INK}])
	return y - y0


## Ascendency: past level 200, skill points push the skills you already have beyond their limits
func _ascPane(x: float, y: float, w: float) -> float:
	var c = CH()
	var y0 = y
	var cap = ascCap()
	var spent = ascSpent()
	var br = Rect2(x, y, w, 46)
	uGlow(br, Color(css("#b388ff"), 0.5 + 0.2 * sin(realTime * 2)), 12, 10)
	uGrad(br, css("#3a1468"), css("#24103f"), css("#120620"), 0.5)
	uBox(br, Color(0, 0, 0, 0), GOLD, 3, 10)
	for i in 12:
		var ang = realTime * 0.3 + i * TAU / 12
		uci.draw_line(br.get_center(), br.get_center() + Vector2(cos(ang), sin(ang) * 0.4) * (w * 0.55), Color(css("#b388ff"), 0.1), 3)
	uText("ASCENDENCY", x + 12, y + 10, 14, Color.WHITE, PX, 0, Color(DARK, 0.7), 3)
	uText("Beyond the limits of the art", x + 12, y + 30, 8, css("#d8c0ff"), UF)
	uText("%d / %d ranks held" % [spent, cap], x + w - 10, y + 16, 9, GOLD, UB, 2)
	y += 54
	y += uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y
		yy += muted("Every level past %d lets you hold one more Ascendency rank. A rank costs one skill point and raises the rank of skills you already know — past their maximum. Passive skills keep growing with every rank; actives gain about 4%% damage each." % ASCEND_LV, X, yy, W) + 6
		for ji in JOBS.size():
			var J: Dictionary = JOBS[ji]
			if not classSkills().any(func(s): return s.get("job") == J.id):
				continue
			yy += _ascRow(str(J.id), "%s ascendency" % J.name, "+1 rank to every %s skill you know" % J.name, css(J.color), X, yy, W)
		yy += 4
		yy += _ascRow("all", "Transcendence", "+1 rank to every skill you know, of every advancement", css("#b388ff"), X, yy, W)
		return yy - Y], [{"fill": css("#f7f1ff"), "border": css("#6a2a9a")}])
	return y - y0


func _ascRow(id: String, name: String, desc: String, col: Color, X: float, yy: float, W: float) -> float:
	var c = CH()
	var r = int(c.get("asc", {}).get(id, 0))
	var cost = 2 if id == "all" else 1
	var room = ascSpent() + 1 <= ascCap()
	var can = c.sp >= cost and r < ASC_NODE_MAX and room
	dashed(X, X + W, yy, LINE)
	uci.draw_circle(Vector2(X + 11, yy + 14), 9, Color(col, 0.25))
	uci.draw_circle(Vector2(X + 11, yy + 14), 9 - 2, col)
	uText(str(r), X + 11, yy + 8, 10, Color.WHITE, UB, 1, Color(DARK, 0.8))
	uText(name, X + 28, yy + 4, 10, css("#3a1468"), UB)
	uPara(desc, X + 28, yy + 17, W - 28 - 60, 8, MUTED)
	uText("%d / %d" % [r, ASC_NODE_MAX], X + W - 52, yy + 4, 8, MUTED, UF)
	var label = "+1" if can else ("MAX" if r >= ASC_NODE_MAX else ("Lv up" if not room else "No SP"))
	uButton(Rect2(X + W - 48, yy + 14, 48, 18), label, func(): _ascBuy(id, cost), {"disabled": not can, "bg": MINT})
	return 38.0


func _ascBuy(id: String, cost: int) -> void:
	var c = CH()
	if not (c.get("asc") is Dictionary):
		c.asc = {}
	var r = int(c.asc.get(id, 0))
	if c.sp < cost or r >= ASC_NODE_MAX or ascSpent() + 1 > ascCap():
		return
	c.asc[id] = r + 1
	c.sp -= cost
	Sfx.rankUp(7)
	toast("Ascended: %s is now rank %d." % [id if id == "all" else jobById(id).name, r + 1])
	_restat()
	_changed()


func skillDesc(s: Dictionary, r: int) -> String:
	return str(sv(s, "desc", r))


func _skillRow(s: Dictionary, X: float, yy: float, W: float, locked: bool) -> float:
	var c = CH()
	var r = baseRank(s.id)
	var asc = ascBonus(s.id) if r > 0 else 0
	var a = 0.55 if locked else 1.0
	var bindable = (s.type == "active" or s.type == "buff") and not locked
	var bossSk: bool = s.get("boss", "") != ""
	dashed(X, X + W, yy, Color(LINE, a))
	uText(s.icon, X + 4, yy + 8, 16, Color(1, 1, 1, a))
	var tx = X + 34
	var tw = W - 34 - 54
	var nx = tx + uText(s.name, tx, yy + 5, 9, Color(INK, a)) + 5
	var tags = {"active": ["Active", "#ffe0e6", "#9a1f35"], "buff": ["Buff", "#fff1c8", "#7a5a08"], "utility": ["Movement", "#e2f7ff", "#1d4e7a"]}.get(s.type, ["Passive", "#dff3ff", "#1d4e7a"])
	nx += uPill(tags[0], nx, yy + 6, Color(css(tags[1]), a), Color(css(tags[2]), a), 7) + 4
	if s.get("cost") and s.type != "utility":
		nx += uPill("%d energy" % s.cost, nx, yy + 6, Color(css("#fff4c8"), a), Color(css("#8a5a08"), a), 7) + 4
	nx += uText("%d/%d" % [r, s.max], nx, yy + 6, 8, Color(MUTED, a), UF) + 4
	if asc > 0:
		uPill("✦ +%d" % asc, nx, yy + 6, Color(css("#efe0ff"), a), Color(css("#4a1c7a"), a), 7)
	var desc = skillDesc(s, maxi(1, r + asc)) + ((" · %ss cooldown" % str(s.cd)) if s.get("cd") else "")
	var dh = uPara(desc, tx, yy + 19, tw, 8, Color(css("#40497a"), a))
	var h = 21 + dh
	if bindable:
		var kx = tx
		for k in SLOT_KEYS:
			var on = c.binds.get(k) == s.id
			uButton(Rect2(kx, yy + h, 18, 14), k.to_upper(), func(): _bind(s.id, k), {"on": on, "disabled": r == 0, "size": 7, "shadow": 1.0, "rad": 4})
			kx += 21
		h += 17
	if bossSk:
		var src = "Found!" if r else "In " + BOXES[s.boss].name
		uPill(src, X + W, yy + 4 + (h - 22) / 2 + 3, MINT if r else css("#ffe0e6"), INK if r else css("#9a1f35"), 8, 2)
		return maxf(h, 34) + 6
	var can = not locked and c.sp > 0 and r < s.max and skillUnlocked(s)
	uButton(Rect2(X + W - 48, yy + 4 + (h - 22) / 2, 48, 18), "+1" if r else "Learn", func(): _learn(s.id), {"disabled": not can, "bg": MINT})
	return maxf(h, 34) + 6


func _learn(id: String) -> void:
	var c = CH()
	var s: Dictionary = SKILL[id]
	if not (c.sp > 0 and skillUnlocked(s) and baseRank(id) < s.max):
		return
	c.skills[id] = baseRank(id) + 1
	c.sp -= 1
	Sfx.buy()
	if baseRank(id) == 1 and (s.type == "active" or s.type == "buff"):
		var pool = ["a", "s", "d", "f", "q", "w", "e", "r"] if s.type == "active" else ["q", "w", "e", "r", "a", "s", "d", "f"]
		var key = ""
		for k in pool:
			if not c.binds.get(k):
				key = k
				break
		if key != "":
			c.binds[key] = id
		toast("%s learned%s." % [s.name, (" — bound to " + key.to_upper()) if key != "" else ""])
	_restat()
	_changed()


func _bind(id: String, k: String) -> void:
	var c = CH()
	if c.binds.get(k) == id:
		c.binds.erase(k)
	else:
		for kk in c.binds.keys():
			if c.binds[kk] == id:
				c.binds.erase(kk)
		c.binds[k] = id
	Sfx.ui()
	_changed()


# ================================================================ Quests

func _pQuests(x: float, y: float, w: float) -> float:
	var y0 = y
	var mq = mainQ()
	var Q: Dictionary = MAINQS[mq.q]
	var done = mq.stage >= Q.steps.size()
	y += uCards(x, y, w, 1, [func(X, Y, W):
		uText("★ Main Quest %d · %s" % [mq.q + 1, Q.title], X, Y, 11, css("#8a5a08"))
		if done and not mq.claimed:
			uButton(Rect2(X + W - 56, Y - 2, 56, 18), "Claim", func(): _mainClaim(), {"bg": MINT})
		elif mq.claimed:
			uPill("Complete", X + W, Y, GOLD, INK, 8, 2)
		var yy = Y + 18
		yy += muted(Q.blurb, X, yy, W) + 2
		for i in Q.steps.size():
			var col = css("#2a8a55") if mq.stage > i else (INK if mq.stage == i else css("#7a809a"))
			uText(("✔ " if mq.stage > i else ("➤ " if mq.stage == i else "· ")) + Q.steps[i], X, yy, 9, col, UB if mq.stage == i else UF)
			yy += 14
		yy += 3 + muted("Reward: %s EXP and %s coins" % [fmt(Q.exp), fmt(Q.coins)], X, yy + 3, W)
		return yy - Y], [{"fill": css("#fff6e3"), "border": css("#c89418")}])
	y += 12
	y += h3("Side quests", x, y) + 2
	var cards = []
	for q in save.quests:
		cards.append(func(X, Y, W):
			uText(q.title, X, Y, 10)
			var pr = Rect2(X, Y + 17, W - 70, 6)
			uBox(pr, css("#d6e6fb"), NONE, 0, 3)
			var p = minf(1.0, float(q.have) / q.need)
			if p > 0:
				uBox(Rect2(pr.position, Vector2(pr.size.x * p, 6)), MINT, NONE, 0, 3)
			uText("Reward: %s EXP and %s coins" % [fmt(q.exp), fmt(q.coins)], X, Y + 27, 8, MUTED, UF)
			if q.done:
				uButton(Rect2(X + W - 58, Y + 10, 58, 19), "Claim", func(): _claim(q.id), {"bg": MINT})
			else:
				uButton(Rect2(X + W - 58, Y + 10, 58, 19), "Swap", func(): _swap(q.id))
			return 38.0)
	y += uCards(x, y, w, 1, cards)
	return y - y0


func _mainClaim() -> void:
	var mq = mainQ()
	var Q = MAINQS[mq.q]
	if mq.stage >= Q.steps.size() and not mq.claimed:
		mq.claimed = true
		gainExp(Q.exp)
		save.coins += Q.coins
		toast("Main quest reward: +%s EXP, +%s coins" % [fmt(Q.exp), fmt(Q.coins)])
		Sfx.levelUp()
		mainQ()
		_changed()


func _claim(id) -> void:
	for i in save.quests.size():
		var q = save.quests[i]
		if q.id == id and q.done:
			save.quests.remove_at(i)
			save.coins += q.coins
			gainExp(q.exp)
			toast("+%s EXP, +%s coins" % [fmt(q.exp), fmt(q.coins)])
			Sfx.buy()
			fillQuests()
			_changed()
			return


func _swap(id) -> void:
	for i in save.quests.size():
		if save.quests[i].id == id:
			save.quests[i] = genQuest()
			Sfx.ui()
			_changed()
			return


# ================================================================ World Map

func crimsonOpen() -> bool:
	return tb(save.get("trophies", {}).get("croc"))


## is this area on the world map yet? (each region appears once the boss before it falls)
func wmOpen(id: String) -> bool:
	if id.begins_with("crimson"):
		return crimsonOpen()
	if id.begins_with("abyss"):
		return tb(save.get("trophies", {}).get("warlord"))
	if id == "bubble":
		return tb(save.get("trophies", {}).get("dreamer"))
	if id.begins_with("climb"):
		return tb(save.get("trophies", {}).get("dreamer"))
	if id == "peak":
		return tb(save.get("trophies", {}).get("kingYeti"))
	if id.begins_with("volcano"):   # inside Glamrax's volcano: past the Mk II, the cell block and the sanctum
		return tb(save.get("trophies", {}).get("mk2" if id in ["volcano3", "volcano4"] else "kingYeti"))
	return true


func portalWhere(m: Dictionary, p: Dictionary) -> String:
	var py = p.get("y", null)
	if py and py < m.floorY:
		return "top-middle platform" if p.x > m.w * 0.35 and p.x < m.w * 0.65 else "high platform"
	return "west edge" if p.x < m.w * 0.2 else ("east edge" if p.x > m.w * 0.8 else "middle")


func wmLinks() -> Array:
	var out = []
	if crimsonOpen() and not MAPS.lair.portals.any(func(p): return p.to == "crimson1"):
		MAPS.lair.portals.append({"x": MAPS.lair.w - 40, "to": "crimson1", "tx": 70, "label": "The Crimson Wastes"})
	if wmOpen("abyss1"):
		openDreamGate()
	if wmOpen("bubble"):
		openBubbleGate()
	if wmOpen("peak"):
		openPendantGate()
	for id in MAPS:
		for p in MAPS[id].get("portals", []):
			if not MAPS.has(p.to):
				continue
			if not wmOpen(id) or not wmOpen(p.to):
				continue
			var found = null
			for l in out:
				if l.a == p.to and l.b == id:
					found = l
			if found:
				found.lb = portalWhere(MAPS[id], p)
				continue
			out.append({"a": id, "b": p.to, "la": portalWhere(MAPS[id], p), "lb": ""})
	return out


func areaLevels(m: Dictionary) -> String:
	var lv = []
	if m.get("boss"):
		lv = [bossTOf(m.boss).lv]
	else:
		for k in m.get("spawn", {}):
			lv.append(SLIME_TYPES[k].lv)
	if lv.is_empty():
		return "—"
	var a = lv.min()
	var b = lv.max()
	return "Lv %d" % a if a == b else "Lv %d–%d" % [a, b]


func _pMap(x: float, y: float, w: float) -> float:
	var y0 = y
	uBox(Rect2(x, y, 64, 16), Color.WHITE, INK, 2, 8)
	uText("World Map", x + 6, y + 3, 9)
	uPara("Hover an area for its monsters and levels. Dotted paths are portals — the label shows where each one is. Press M any time to open this map.", x + 72, y + 1, w - 72, 8, MUTED)
	y += 26
	var s = w / 1000.0
	var top = WM_TOP if wmOpen("climb1") else 0.0   # the volcano climb sits above the Abyss
	var r = Rect2(x, y, w, (430 + top) * s)
	var o = r.position + Vector2(0, top * s)
	# which area is the mouse over?
	var mp = (mouse - uOff - o) / s
	wmHover = null
	if uHover(r):
		for id in WM_NODES:
			if not wmOpen(id):
				continue
			var n = WM_NODES[id]
			if Vector2(mp.x - n.x, mp.y - n.y).length() < 34:
				wmHover = id
	withCtx(o, s, func(cx): drawWorldMap(cx, realTime))
	uBox(r, NONE, INK, 3, 9)
	if wmHover != null:
		_wmTip(r, s, o)
	return r.end.y - y0


func drawWorldMap(x: Ctx, t: float) -> void:
	var top = WM_TOP if wmOpen("climb1") else 0.0
	# the painted land (tools/bake/worldmap.mjs): sea and home island, then each region as it opens
	_wmLayer(x, "base", top)
	if crimsonOpen():
		_wmLayer(x, "crimson", top)
	if wmOpen("abyss1"):
		_wmLayer(x, "abyss", top)
	if top > 0:
		_wmLayer(x, "north", top)
	# glints running over the sea
	x.fillStyle = "rgba(255,255,255,0.35)"
	for i in 60:
		var wx = fmod(i * 97 + t * 8, 1020.0) - 10
		var wy = (i * 53) % int(430 + top) - top
		x.fillRect(roundf(wx), wy, 6, 1)
	if wmOpen("abyss1"):
		# red runes glinting in the Abyss trench
		for i in 18:
			var rx = 90 + hsh(i + 11) * 620
			var ry = 26 + hsh(i + 12) * 36
			x.fillStyle = "rgba(255,50,80,%.2f)" % (0.35 + 0.35 * sin(t * 2 + i))
			x.fillRect(rx, ry, 2, 5); x.fillRect(rx - 2, ry + 2, 6, 1)
		if wmOpen("bubble"):
			x.fillStyle = "rgba(255,255,255,0.18)"; x.beginPath(); x.arc(WM_NODES.bubble.x, WM_NODES.bubble.y, 24, 0, TAU); x.fill()
			x.strokeStyle = "rgba(200,170,255,0.8)"; x.lineWidth = 2; x.beginPath(); x.arc(WM_NODES.bubble.x, WM_NODES.bubble.y, 24, 0, TAU); x.stroke()
	if top > 0:
		_wmVolcano(x, t)
	# portal paths: dotted lines with a label at each end saying where the portal is
	for l in wmLinks():
		var A = WM_NODES.get(l.a)
		var Bn = WM_NODES.get(l.b)
		if A == null or Bn == null:
			continue
		x.strokeStyle = "#7a4a1c"; x.lineWidth = 4; x.setLineDash([8, 7]); x.lineDashOffset = -t * 12
		x.beginPath(); x.moveTo(A.x, A.y); x.lineTo(Bn.x, Bn.y); x.stroke(); x.setLineDash([])
		_wmLabel(x, A, Bn, l.la)
		_wmLabel(x, Bn, A, l.lb)
	for id in WM_NODES:
		if not wmOpen(id):
			continue
		if not MAPS.has(id):
			continue
		var n = WM_NODES[id]
		var m: Dictionary = MAPS[id]
		var hov = wmHover == id
		x.fillStyle = "#1a1030"; x.beginPath(); x.arc(n.x, n.y, 17 if hov else 14, 0, TAU); x.fill()
		x.fillStyle = "#a82a30" if m.get("boss") else ("#ffc83d" if hov else ("#d8c8ff" if id.begins_with("abyss") else ("#d8f0ff" if id.begins_with("climb") or id == "peak" else ("#f0c8ff" if id.begins_with("volcano") else "#ffffff"))))
		x.beginPath(); x.arc(n.x, n.y, 14 if hov else 11, 0, TAU); x.fill()
		x.fillStyle = "#ffe08a" if m.get("boss") else "#27335c"
		x.font = '12px "Press Start 2P", monospace'; x.textAlign = "center"; x.textBaseline = "middle"
		x.fillText("☠" if m.get("boss") else "●", n.x, n.y + 1)
		x.font = "bold 13px Fredoka, sans-serif"
		var lw = x.measureText(m.name).width + 14
		x.fillStyle = "rgba(26,16,48,0.85)"; x.fillRect(n.x - lw / 2, n.y + 20, lw, 30)
		x.fillStyle = "#ffffff"; x.fillText(m.name, n.x, n.y + 29)
		x.fillStyle = "#ffe08a"; x.font = "11px Fredoka, sans-serif"; x.fillText(areaLevels(m), n.x, n.y + 42)
	var h = WM_NODES.get(mapId)
	if h:
		var bob = sin(t * 5) * 3
		x.fillStyle = "#ff3a4a"; x.beginPath(); x.moveTo(h.x, h.y - 16 + bob); x.lineTo(h.x - 8, h.y - 30 + bob); x.arc(h.x, h.y - 32 + bob, 8, PI * 0.8, PI * 2.2); x.closePath(); x.fill()
		x.fillStyle = "#fff"; x.beginPath(); x.arc(h.x, h.y - 32 + bob, 3, 0, TAU); x.fill()
		x.font = "bold 11px Fredoka, sans-serif"; x.fillStyle = "#ff3a4a"; x.fillText("You are here", h.x, h.y - 48 + bob)
	x.textBaseline = "alphabetic"
	x.fillStyle = "rgba(26,16,48,0.8)"; x.fillRect(12, 12 - top, 200, 26)
	x.fillStyle = "#ffe08a"; x.font = '10px "Press Start 2P", monospace'; x.textAlign = "left"; x.fillText("SPROUTVALE REGION", 22, 30 - top)
	x.fillStyle = "rgba(255,248,230,0.92)"; x.fillRect(12, 392, 360, 26)
	x.fillStyle = "#4a2e14"; x.font = "11px Fredoka, sans-serif"; x.fillText("●  Area     ☠  Boss     - - -  Portal (label = where the portal is)", 22, 409)


const WM_TOP := 210.0


var _wmTex := {}

## one painted World Map layer (1500 × 960, covering map units x 0…1000, y -210…430), smoothly filtered
func _wmLayer(x: Ctx, k: String, top: float) -> void:
	if not _wmTex.has(k):
		var tx = Assets.tex("worldmap/%s.webp" % k)
		var ct = null
		if tx:
			ct = CanvasTexture.new()
			ct.diffuse_texture = tx
			ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_wmTex[k] = ct
	var ct = _wmTex[k]
	if ct == null:
		return
	var k2 = 1.5   # pixels per map unit
	x.drawImageRegion(ct, 0, (WM_TOP - top) * k2, 1000 * k2, (430 + top) * k2, 0, -top, 1000, 430 + top)


## the volcano's live bits: the crater's pulse and its smoke
func _wmVolcano(x: Ctx, t: float) -> void:
	x.fillStyle = "rgba(255,90,230,%.2f)" % (0.25 + 0.25 * sin(t * 3))
	x.beginPath(); x.ellipse(820, -150, 34, 8, 0, 0, TAU); x.fill()
	for i in 3:
		var k = fmod(t * 0.25 + i / 3.0, 1.0)
		x.fillStyle = "rgba(110,60,130,%.2f)" % (0.5 * (1 - k))
		x.beginPath(); x.arc(820 + k * 30 + i * 6, -160 - k * 20, 8 + k * 10, 0, TAU); x.fill()


func _wmLabel(x: Ctx, from: Dictionary, to: Dictionary, text: String) -> void:
	if text == "":
		return
	var L = maxf(1.0, Vector2(to.x - from.x, to.y - from.y).length())
	var px2 = from.x + (to.x - from.x) * 0.42 + (-(to.y - from.y) / L) * 12
	var py2 = from.y + (to.y - from.y) * 0.42 + ((to.x - from.x) / L) * 12
	x.font = "11px Fredoka, sans-serif"
	var w = x.measureText(text).width + 10
	x.fillStyle = "rgba(255,248,230,0.95)"; x.fillRect(px2 - w / 2, py2 - 9, w, 16)
	x.strokeStyle = "#7a4a1c"; x.lineWidth = 1; x.strokeRect(px2 - w / 2 + 0.5, py2 - 8.5, w - 1, 15)
	x.fillStyle = "#4a2e14"; x.textAlign = "center"; x.textBaseline = "middle"; x.fillText(text, px2, py2)


func _wmTip(r: Rect2, s: float, o: Vector2) -> void:
	var m: Dictionary = MAPS[wmHover]
	var mons = []
	if m.get("boss"):
		mons = [[m.boss, bossTOf(m.boss)]]
	else:
		for k in m.get("spawn", {}):
			mons.append([k, SLIME_TYPES[k]])
		mons.sort_custom(func(a, b): return a[1].lv < b[1].lv)
	var links = []
	for l in wmLinks():
		if l.a == wmHover or l.b == wmHover:
			var other = l.b if l.a == wmHover else l.a
			var here = l.la if l.a == wmHover else l.lb
			links.append(("**%s** → " % here if here != "" else "→ ") + MAPS[other].name)
	var w = 190.0
	var h = 34 + mons.size() * 13 + 14 + links.size() * 12 + (14 if mapId == wmHover else 0) + 6
	var n = WM_NODES[wmHover]
	var X = minf(r.end.x - w - 4, o.x + n.x * s + 24)
	var Y = clampf(o.y + n.y * s - 30, r.position.y + 4, r.end.y - h - 4)
	uBox(Rect2(X, Y, w, h), Color(247 / 255.0, 251 / 255.0, 1, 0.97), INK, 2, 8, 3.0, INK)
	var yy = Y + 6
	var nw = uText(m.name, X + 8, yy, 10)
	if m.get("boss"):
		uPill("Boss", X + 14 + nw, yy + 1, css("#ffe0e6"), css("#9a1f35"), 7)
	yy += 14
	uText(areaLevels(m), X + 8, yy, 8, css("#8a5a08"))
	yy += 13
	for mm in mons:
		uci.draw_circle(Vector2(X + 12, yy + 5), 4, INK)
		uci.draw_circle(Vector2(X + 12, yy + 5), 3.2, hexc(int(mm[1].color)))
		uText(mm[1].name if save.get("bestiary", {}).has(mm[0]) else "???", X + 20, yy, 8, INK, UF)
		uText("Lv %d" % mm[1].lv, X + w - 8, yy, 8, INK, UB, 2)
		yy += 13
	uText("Portals", X + 8, yy + 1, 8, MUTED, UF)
	yy += 13
	for l in links:
		uPara(l, X + 8, yy, w - 16, 8, INK)
		yy += 12
	if mapId == wmHover:
		uText("You are here", X + 8, yy + 2, 8, css("#d13c55"))


# ================================================================ Bestiary

func bigEntry(k: String) -> bool:
	return k == "croc" or k == "warlord" or k == "dreamer" or k == "kingYeti" or MORE_BOSSES.has(k)


func bossTOf(k: String) -> Dictionary:
	if MORE_BOSSES.has(k):
		return MORE_BOSSES[k].T
	return BOSS_T if k == "croc" else (WARLORD_T if k == "warlord" else (DREAMER_T if k == "dreamer" else (YETI_T if k == "kingYeti" else SLIME_TYPES[k])))


## the frames an entry cycles through: [set, key, frame] for idle, or for its attack when clicked
func bestFrames(k: String, mode: String, shiny: bool) -> Array:
	var seq = []
	var add = func(setn, key, idxs):
		for i in idxs:
			seq.append([setn, key, i])
	if k == "croc":
		if mode == "attack":
			for e in [["biteWind", 0], ["biteWind", 0], ["biteWind", 0], ["bite", 0], ["bite", 0], ["rise", 0], ["rise", 1], ["swipeWind", 0], ["swipeWind", 0], ["swipe", 0], ["swipe", 0],
				["stompWind", 0], ["stompWind", 0], ["stomp", 0], ["vialHold", 0], ["vialMix", 0], ["vialMix", 0], ["vialThrow", 0], ["roar", 0], ["roar", 0], ["roar", 0]]:
				seq.append(["croc", e[0], e[1]])
		else:
			add.call("croc", "quad", [0, 1, 2, 3])
		return seq
	if k == "warlord":
		if mode == "attack":
			add.call("warlord_ss", "swing", range(7)); add.call("warlord_ss", "wind", [0]); add.call("warlord_ss", "bash", [0, 0])
			add.call("warlord_gs", "swing", range(10)); add.call("warlord_gs", "hop", [0]); add.call("warlord_gs", "slam", [0]); add.call("warlord_ss", "noEyes", [0, 1])
		else:
			add.call("warlord_ss", "idle", [0, 1])
		return seq
	if k == "dreamer" or k == "kingYeti" or MORE_BOSSES.has(k):   # a portrait rather than strips: one frame calm, eighteen glaring
		for i in (18 if mode == "attack" else 1):
			seq.append(["", "", 0])
		return seq
	var setn = k + ("_shiny" if shiny else "")
	if k in ABYSS_MOBS or k in CLIMB_MOBS:
		var ks: Dictionary = Assets.mob_set(setn).get("keys", {})
		if mode == "attack":
			for key in ABYSS_BEST_ATTACK.get(k, CLIMB_BEST_ATTACK.get(k, [])):
				add.call(setn, key, range(int(ks.get(key, 1))) if int(ks.get(key, 1)) > 1 else [0, 0, 0])
		else:
			var k0 = ks.keys()[0] if ks.size() else "idle"
			add.call(setn, k0, range(int(ks.get(k0, 1))))
		return seq
	var T: Dictionary = SLIME_TYPES[k]
	var keys: Dictionary = Assets.mob_set(setn).get("keys", {})
	var n = func(key): return range(int(keys.get(key, 1)))
	if Assets.mob_set(setn).get("dim") != null:
		if mode == "attack":
			add.call(setn, "wind", [0, 0]); add.call(setn, "swing", n.call("swing")); add.call(setn, "bash", [0]); add.call(setn, "slam", [0])
		else:
			add.call(setn, "idle", n.call("idle")); add.call(setn, "run", n.call("run"))
	elif T.get("ai"):
		if mode == "attack":
			add.call(setn, "wind", [0, 0, 0]); add.call(setn, "lunge", [0, 0, 0])
			if keys.has("spin"):
				add.call(setn, "spin", n.call("spin"))
		elif T.get("fly"):
			add.call(setn, "idle", [0, 1])
		else:
			add.call(setn, "run", n.call("run"))
	elif mode == "attack":
		if k == "boar":
			add.call(setn, "wind", [0, 0, 0, 0]); add.call(setn, "run", [0, 1, 2, 3, 0, 1, 2, 3]); add.call(setn, "lunge", [0, 0])
		elif k == "tortoise":
			add.call(setn, "wind", [0, 0]); add.call(setn, "shell", [0]); add.call(setn, "spin", [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]); add.call(setn, "shell", [0, 0])
		elif T.get("critter"):
			add.call(setn, "wind", [0, 0, 0]); add.call(setn, "lunge", [0, 0, 0]); add.call(setn, "idle", [0])
		else:
			add.call(setn, "wind", [0, 0, 0]); add.call(setn, "hopA", [0, 0]); add.call(setn, "land", [0]); add.call(setn, "idle", [0])
	else:
		if T.get("critter"):
			add.call(setn, "run", n.call("run"))
		else:
			add.call(setn, "idle", [0, 0, 1, 1])
	return seq


func _bestPic(k: String, r: Rect2, known: bool, shinyView: bool, shinyKnown: bool) -> void:
	var st = BEST_ANIM.get(k)
	if st == null:
		st = {"mode": "idle", "t": 0.0}
		BEST_ANIM[k] = st
	var big = bigEntry(k)
	var seq = bestFrames(k, st.mode, shinyView)
	var f = floori(st.t * (7 if big else 8))
	if st.mode == "attack" and f >= seq.size():
		st.mode = "idle"
		st.t = 0.0
		seq = bestFrames(k, "idle", shinyView)
		f = 0
	if k == "dreamer":
		_bestDreamer(r, known, st.mode == "attack")
		return
	if k == "kingYeti":
		_bestYeti(r, known, st.mode == "attack")
		return
	if MORE_BOSSES.has(k):
		_bestMore(k, r, known, st.mode == "attack")
		return
	var fr = seq[posmod(f, seq.size())]
	if k in CLIMB_MOBS:
		_bestClimb(k, r, fr, known and (not shinyView or shinyKnown))
		return
	if k in ABYSS_MOBS:
		_bestAbyss(k, r, fr, known and (not shinyView or shinyKnown))
		return
	var gy = 0.88 if big else 0.8
	uBox(r, css("#e8f7ff"), INK, 2, 7)
	uGrad(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * gy - 2)), css("#cfeeff"), css("#dcf2ff"), css("#e8f7ff"), 0.5)
	uGrad(Rect2(r.position.x + 2, r.position.y + r.size.y * gy, r.size.x - 4, r.size.y * (1 - gy) - 2), css("#8fd06a"), css("#7cc05c"), css("#6cb04e"), 0.5)
	var tex = Assets.mob_strip(fr[0], fr[1])
	if tex == null:
		return
	if not known or (shinyView and not shinyKnown):
		tex = Assets.silhouette(tex, DARK)
	var S = Assets.mob_set(fr[0])
	var nfr = int(S.keys.get(fr[1], 1))
	var fw = tex.get_width() / float(nfr)
	var fh = float(tex.get_height())
	var dim = S.get("dim") != null
	# world units in the frame, and how many canvas pixels per unit the prototype used
	var unitsW = 220.0 if k == "croc" else (84.0 if dim else 44.0)
	var per = 1.0 if (k == "croc" or (dim and k != "warlord")) else 2.0
	var canvasW = 220.0 if big else 110.0
	var s = r.size.x / canvasW * per
	var dw = unitsW * s
	var dh = dw * fh / fw
	var footY = BOY if k == "croc" else (GROUND if dim else 33.0)
	var oy = r.position.y + r.size.y * gy - footY * s
	var ox = r.get_center().x - dw / 2
	uci.draw_texture_rect_region(tex, Rect2(ox, oy, dw, dh), Rect2(fw * clampi(fr[2], 0, nfr - 1), 0, fw, fh))


## which strips the bestiary plays when you click an Abyss monster
const ABYSS_BEST_ATTACK := {"toad": ["hop", "slam", "tongue"], "seagull": ["dive", "drop"], "bass": ["bite", "charge"], "crab": ["pinch", "beam"],
	"shark": ["bite", "bite"], "squid": ["ink", "gaze"], "orca": ["chomp", "tail"], "octopus": ["flurry", "grab"]}


## an Abyss monster's picture: dark water behind it, the whole frame fitted in (fish float in the middle, walkers stand on the sand)
func _bestAbyss(k: String, r: Rect2, fr: Array, known: bool) -> void:
	uBox(r, css("#1a0e2a"), INK, 2, 7)
	var air = k in ["toad", "seagull"]
	uGrad(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), css("#5a1630") if air else css("#2a2a5a"), css("#2a0f3a") if air else css("#1a1840"), css("#0e0818"), 0.5)
	var floorY = r.position.y + r.size.y * 0.84
	if k in ["toad", "crab", "octopus"]:
		uci.draw_rect(Rect2(r.position.x + 2, floorY, r.size.x - 4, r.end.y - floorY - 2), css("#241630"))
	var tex = Assets.mob_strip(fr[0], fr[1])
	if tex == null:
		return
	if not known:
		tex = Assets.silhouette(tex, css("#05030a"))
	var S = Assets.mob_set(fr[0])
	var nfr = int(S.keys.get(fr[1], 1))
	var fw = tex.get_width() / float(nfr)
	var fh = float(tex.get_height())
	var sc = minf((r.size.x - 8) / fw, (r.size.y - 8) / fh) * (1.0 if fw > 120 else 0.85)
	var dw = fw * sc
	var dh = fh * sc
	var ox = r.get_center().x - dw / 2
	var oy = r.get_center().y - dh / 2
	if k in ["toad", "crab", "octopus"]:
		oy = floorY - float(S.dim.ay + 2) * 2 * sc
	uci.draw_texture_rect_region(tex, Rect2(ox, oy, dw, dh), Rect2(fw * clampi(fr[2], 0, nfr - 1), 0, fw, fh))


## which strips the bestiary plays when you click a climb monster
const CLIMB_BEST_ATTACK := {"boulder": ["float", "launch", "roll"], "lizard": ["whip", "leap"], "golem": ["wind", "smash"],
	"warlock": ["cast", "blink"], "yeti": ["swipe", "leap", "slam"], "sword": ["fly", "fly"],
	# inside the volcano
	"sentinel": ["idle", "charge", "slam", "slam"], "secgolem": ["fire", "fire", "wind", "punch"], "sentgolem": ["fire", "laser", "dash", "punch"],
	"dog": ["pounce", "pin", "pin"], "ferro": ["hop", "spark", "hot", "hot"]}


## a climb monster's picture: cold sky over grey rock (the cave ones in the dark), the whole frame fitted in
func _bestClimb(k: String, r: Rect2, fr: Array, known: bool) -> void:
	var cave = k in ["yeti", "sword"] or k in VOLCANO_MOBS   # (the volcano's monsters: dark too)
	var snow = k in ["golem", "warlock"]
	uBox(r, css("#1a2230"), INK, 2, 7)
	uGrad(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), css("#1e2a3a") if cave else (css("#c8d8ea") if snow else css("#9fb4c8")),
		css("#16202c") if cave else (css("#aabfd6") if snow else css("#8298ae")), css("#0c1018") if cave else css("#6a7c90"), 0.5)
	var floorY = r.position.y + r.size.y * 0.86
	if k != "sword":
		uci.draw_rect(Rect2(r.position.x + 2, floorY, r.size.x - 4, r.end.y - floorY - 2), css("#2a3038") if cave else (css("#e8f2fa") if snow else css("#5a5e66")))
	var tex = Assets.mob_strip(fr[0], fr[1])
	if tex == null:
		return
	if not known:
		tex = Assets.silhouette(tex, css("#05070c"))
	var S = Assets.mob_set(fr[0])
	var nfr = int(S.keys.get(fr[1], 1))
	var fw = tex.get_width() / float(nfr)
	var fh = float(tex.get_height())
	var sc = minf((r.size.x - 8) / fw, (r.size.y - 8) / fh)
	var dw = fw * sc
	var dh = fh * sc
	var ox = r.get_center().x - dw / 2
	var oy = r.get_center().y - dh / 2
	var D = S.get("dim")
	if k != "sword" and D != null and D.has("ay"):
		oy = floorY - float(D.ay) * 2 * sc * (fh / (float(D.get("h", fh / 2)) * 2))
	uci.draw_texture_rect_region(tex, Rect2(ox, oy, dw, dh), Rect2(fw * clampi(fr[2], 0, nfr - 1), 0, fw, fh))


## King Yeti's picture: his portrait in the cold cave (he roars when you click it)
func _bestYeti(r: Rect2, known: bool, roar: bool) -> void:
	uBox(r, css("#0e1620"), INK, 2, 7)
	uGrad(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), css("#24384c"), css("#162432"), css("#080c12"), 0.5)
	var tex = Assets.tex("boss/yeti_portrait.png")
	if tex == null:
		return
	if not known:
		tex = Assets.silhouette(tex, css("#05070c"))
	var fh = float(tex.get_height())
	var nf = maxi(1, roundi(tex.get_width() / (fh * 220.0 / 170.0)))
	var fw = tex.get_width() / float(nf)
	var sc = minf((r.size.x - 4) / fw, (r.size.y - 4) / fh)
	var dst = Rect2(r.get_center().x - fw * sc / 2, r.end.y - 2 - fh * sc, fw * sc, fh * sc)
	var fi = (nf - 1) if roar and known else 0
	if roar and known and nf == 1:
		dst = dst.grow(sin(realTime * 40) * 1.5)
	uci.draw_texture_rect_region(tex, dst, Rect2(fw * fi, 0, fw, fh))


## a boss drawn in code (the Mk II, Glamrax): its portrait, glaring when you click it; a shadow until you've beaten it
func _bestMore(k: String, r: Rect2, known: bool, angry: bool) -> void:
	uBox(r, css("#140a14"), INK, 2, 7)
	uGrad(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), css("#3a1a30"), css("#1c0c1c"), css("#08040a"), 0.5)
	var inner = r.grow(-3)
	withCtx(inner.position, 1.0, func(c): drawBossPortrait(c, k, 0, 0, inner.size.x, inner.size.y, angry and known))
	if not known:
		uBox(inner, Color(0.02, 0.01, 0.03, 0.93), NONE, 0, 5)


## The Dreamer's picture: its portrait over the abyss (it glares when you click it)
func _bestDreamer(r: Rect2, known: bool, glare: bool) -> void:
	uBox(r, css("#12081e"), INK, 2, 7)
	uGrad(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), css("#3a1240"), css("#1e0c30"), css("#08040e"), 0.5)
	var tex = Assets.tex("boss/dreamer_portrait.png")
	if tex == null:
		return
	if not known:
		tex = Assets.silhouette(tex, css("#05030a"))
	var fw = tex.get_width() / 2.0
	var fh = float(tex.get_height())
	var sc = minf((r.size.x - 4) / fw, (r.size.y - 4) / fh)
	var dst = Rect2(r.get_center().x - fw * sc / 2, r.end.y - 2 - fh * sc, fw * sc, fh * sc)
	uci.draw_texture_rect_region(tex, dst, Rect2(fw if glare and known else 0.0, 0, fw, fh))


func _cardSlot(k: String, key: String, x: float, y: float, s := 0.6) -> void:
	var owned = cardSet(k).get(key)
	withCtx(Vector2(x, y), s, func(cx): cardArt(cx, k, key.ends_with("g"), key.begins_with("s"), false, 0, 0))
	if not owned:
		uci.draw_rect(Rect2(x, y, 44 * s, 60 * s), Color(30 / 255.0, 24 / 255.0, 52 / 255.0, 0.92))
		uText("?", x + 22 * s, y + 30 * s - 5, 8, css("#6a6488"), PX, 1)
	var labels = {"n": "Card", "ng": "Gold card", "s": "Shiny card", "sg": "Shiny gold card"}
	zone(Rect2(x, y, 44 * s, 60 * s), Callable(), labels[key] + (" (owned)" if owned else " (not found yet)"))


func _pBestiary(x: float, y: float, w: float) -> float:
	var B = save.get("bestiary", {})
	var found = BEST_ORDER.filter(func(k): return B.get(k, {}).get("kills", 0) > 0).size()
	var y0 = y
	var bw = uW("%d / %d discovered" % [found, BEST_ORDER.size()], 9) + 14
	uBox(Rect2(x, y, bw, 16), Color.WHITE, INK, 2, 8)
	uText("%d / %d discovered" % [found, BEST_ORDER.size()], x + 7, y + 3, 9)
	y += uPara("Defeat a monster to unlock its entry. Click the picture to see it attack. Monster cards drop at 1% (gold cards 0.01%).", x + bw + 8, y + 1, w - bw - 8, 8, MUTED) + 8
	var cards = []
	var styles = []
	for k in BEST_ORDER:
		cards.append(_bestCard(k))
		var known = B.get(k, {}).get("kills", 0) > 0
		styles.append({"fill": Color.WHITE if known else css("#eef1f8"), "border": INK, "wide": bigEntry(k)})
	y += uCards(x, y, w, 2, cards, styles)
	return y - y0


func _bestCard(k: String) -> Callable:
	return func(X, Y, W):
		var B = save.get("bestiary", {})
		var T = bossTOf(k)
		var rec = B.get(k, {"kills": 0, "shiny": 0})
		var known = rec.get("kills", 0) > 0
		var big = bigEntry(k)
		var shinyView = BEST_VIEW.get(k) == "s"
		var shinyKnown = rec.get("shiny", 0) > 0
		var where = []
		if k == "croc":
			where = [MAPS.lair]
		elif k == "warlord":
			where = [MAPS.crimson5]
		elif k == "dreamer":
			where = [MAPS.abyss5]
		elif k == "kingYeti":
			where = [MAPS.climb4]
		elif MORE_BOSSES.has(k):
			where = [MAPS[MORE_BOSSES[k].map]]
		else:
			for id in MAPS:
				if MAPS[id].get("spawn", {}).has(k):
					where.append(MAPS[id])
		var pw = 180.0 if big else 92.0
		var pr = Rect2(X, Y, pw, pw * (170.0 / 220.0 if big else 84.0 / 110.0))
		_bestPic(k, pr, known, shinyView, shinyKnown)
		if known:
			zone(pr, func(): BEST_ANIM[k] = {"mode": "attack", "t": 0.0}; Sfx.ui(), "Click to see its attack")
		var ph = pr.size.y
		if not big and known:
			uButton(Rect2(X, pr.end.y + 3, pw / 2 - 2, 14), "Normal", func(): BEST_VIEW[k] = "n"; Sfx.ui(), {"on": not shinyView, "size": 7, "shadow": 1.0})
			uButton(Rect2(X + pw / 2 + 1, pr.end.y + 3, pw / 2 - 1, 14), "Shiny ✦", func(): BEST_VIEW[k] = "s"; Sfx.ui(), {"on": shinyView, "size": 7, "shadow": 1.0})
			ph += 18
		var tx = X + pw + 10
		var tw = W - pw - 10
		var title = "???"
		if known:
			title = (("Shiny " + T.name) if shinyKnown else "??? (shiny)") if shinyView else T.name
		var yy = Y
		var nw = uText(title, tx, yy, 10)
		if big:
			uPill("Boss", tx + nw + 6, yy + 1, css("#ffe0e6"), css("#9a1f35"), 7)
		yy += 15
		var hp = T.hp * 3 if shinyView else T.hp
		var atk = T.atk * 3 if shinyView else T.atk
		var df = roundi(T.def * 1.5) if shinyView else T.def
		if known and (not shinyView or shinyKnown):
			var st = [["Lv", str(T.lv)], ["HP", fmt(hp)], ["ATK", str(atk)], ["DEF", str(df)]]
			for i in 4:
				var sx = tx + (i % 2) * (tw / 2)
				var sy = yy + floori(i / 2.0) * 11
				uText(st[i][0], sx, sy, 8, MUTED, UF)
				uText(st[i][1], sx + 26, sy, 8, INK)
			yy += 25
			yy += uPara("A rare shimmering variant: three times as strong, five times the rewards. About 3% of spawns." if shinyView else BEST_TEXT.get(k, ""), tx, yy, tw, 8, INK) + 2
			var locs = []
			for m in where:
				locs.append("%s (%s)" % [m.name, areaLevels(m)])
			yy += uPara("**Location:** " + (", ".join(locs) if locs.size() else "—"), tx, yy, tw, 8, MUTED) + 2
			yy += uPara("**Drops:** %s · **Defeated:** %d%s" % ["coins, Boss Coin" if big else matName(k), rec.kills, "" if big else " · **Shiny:** %d" % rec.get("shiny", 0)], tx, yy, tw, 8, MUTED) + 2
		elif known:
			yy += muted("Defeat a shiny one to reveal this variant.", tx, yy, tw)
		else:
			var names = []
			for m in where:
				names.append(m.name)
			yy += muted("Defeat one to learn more. It lives in: %s." % ", ".join(names), tx, yy, tw)
		if known:
			var cb = cardValue(k)
			yy += uPara("Cards" + ((" · **+%d%%** EXP & coins" % roundi(cb * 100)) if cb else ""), tx, yy + 2, tw, 8, MUTED) + 4
			var keys = ["n", "ng"] if big else ["n", "ng", "s", "sg"]
			for i in keys.size():
				_cardSlot(k, keys[i], tx + i * 30, yy)
			yy += 38
		return maxf(yy - Y, ph)


func updateBestiary(dt: float) -> void:
	for k in BEST_ANIM:
		BEST_ANIM[k].t += dt


# ================================================================ Controls and World

const ROCK_CONTROLS := {
	"title": "Combos",
	"combos": [["Z Z Z Z", "Crossguard Rush", "Four-hit chain ending in a spin slash"], ["Z Z · pause · Z", "Pause Breaker", "Wait a beat after the rising slash, then a double whirlwind"],
		["Z (1–3×) then X", "Rising Aegis", "Shield uppercut that launches slimes high"], ["In the air: Z Z Z", "Sky Rend", "Air slash, rising cut, then a flipping finisher that spikes enemies down"],
		["In the air: X", "Meteor Drop", "Plunge sword-first; the higher you fall, the bigger the shockwave"], ["X", "Heavy slash", "Big overhead chop on the ground"]],
	"rows": [["← →", "Move · hold to break into a run, or double-tap to sprint right away"], ["Space", "Jump · press again in the air for a flash jump"],
		["↑ ↓", "Climb ropes · ↑ + ← or → (or Space + direction) jumps off · ↑ at a portal, obelisk or sign to use it"], ["↓ + Space", "Drop through a platform"],
		["Z", "Attack · keep tapping for the full chain · ↑ + Z for a rising slash (a rising cut in the air)"], ["X", "Heavy slash"],
		["C", "Dodge (works once in the air) · dodge through an attack for a perfect dodge"], ["↓", "Lie prone · ← → to crawl · Z for a low stab at their feet · while running, slide into prone"],
		["Shift", "Hold to block · tap right before a hit to parry"], ["A S D F Q W E R", "Skills and buffs you bind in the Skills tab (they cost energy — plain hits refill it)"],
		["Space ×3 + dir", "Air Leap (Swordsman): a third jump that launches you far in that direction, or high with ↑"], ["H / J", "Health potion / Energy potion (3 charges each, recharging)"],
		["Tab", "Open or close this menu"], ["M", "World map"], ["F11", "Fullscreen"]],
	"note": "Rising slash launches slimes into the air. Jump after them and use air slashes to juggle. Mixing different moves raises your style rank faster than repeating one.",
}
const ARCHER_CONTROLS := {
	"title": "Archer's moves",
	"combos": [["Z", "Shot", "Fires at the nearest enemy in front of you — fast, light damage"], ["↑ + Z", "Up shot / Bow Launcher", "Shoots upward — or, right next to an enemy, scoops it into the air. Follow-up shots chase that juggled target"],
		["Z up close", "Bow swing", "Too close to shoot? She swings the bow and shoves them away"], ["In the air: Z Z Z", "Spiral Shot", "Two air shots, then a backflip that fans arrows down at up to 3 enemies · ↑/↓ + Z aims up or down"],
		["X", "Charged Shot", "A drawn-out heavy arrow that knocks enemies back"], ["In the air: X", "Arrow Dive", "Hop and loose a downward volley (hits up to 2)"], ["↓ then Z", "Prone shot", "Lie flat and fire low along the ground"]],
	"rows": [["H / J", "Health potion / Focus potion (3 charges each, recharging)"], ["← →", "Move (10% faster than Rock) · double-tap to sprint"], ["Space", "Jump · she can jump three times"], ["↓", "Lie prone · while running, a long fast slide"],
		["C", "Dodge"], ["Shift", "Guard with the bow"], ["A S D F Q W E R", "Skills — they spend Focus, which landing arrows builds back"], ["Tab / M", "Menu / world map"], ["F11", "Fullscreen"]],
	"note": "",
}
const MAGE_CONTROLS := {
	"title": "Remy's spells",
	"combos": [["Z", "Wand bolt", "Quick, single-target spell of your current element. Aims at the nearest enemy in front of you"], ["↑ / ↓ + Z", "Aimed bolt", "Straight up or down — Remy can aim directly overhead"],
		["X", "Staff spell", "About a second to cast (you stand still), then an area spell hits up to 3 enemies: tornado, crashing wave, clashing earth pillars, eruption, light pillar or vortex"],
		["Z up close", "Staff thwack", "Knocks an enemy away to make space"], ["↑ + Z up close", "Staff launcher", "Pops it into the air — wand bolts chase it for a juggle"],
		["1 – 6 or V", "Switch element", "Air, Water, Earth, Fire, then Light (Lv 30) and Dark (Lv 75). V cycles"], ["C + direction", "Blink", "Teleport left, right, up or down (costs a little mana)"]],
	"rows": [["H / J", "Health potion / Mana potion (3 charges each, recharging)"], ["← →", "Move · double-tap to sprint"], ["Space", "Jump · double jump"], ["↓", "Lie prone · while running, slide"],
		["Shift", "Guard with the staff"], ["A S D F Q W E R", "Skills — they spend Mana"], ["Tab / M", "Menu / world map"], ["F11", "Fullscreen"]],
	"note": "",
}
const SUMMONER_CONTROLS := {
	"title": "Jojo's commands",
	"combos": [["Z", "Command: chomp", "Wave your ring hand and the dragon darts to the nearest enemy you point at, bites, and flies back"], ["↑ / ↓ + Z", "Aimed command", "Straight up or straight down"],
		["X", "Command: fire breath", "The dragon breathes a cone of fire ahead (later forms scorch everything it touches)"], ["Z up close", "Push", "A two-handed shove that buys space"],
		["↑ + Z up close", "Grab and throw", "Heave the enemy into the air — commands then chase it for a juggle"], ["1 – 4", "Toggle companions", "Blue Slime (Lv 10), Crocodile (Lv 30), Phoenix (Lv 100), Angel (Lv 150). They fight on their own"]],
	"rows": [["H / J", "Health potion / Spirit potion (3 charges each, recharging)"], ["← →", "Move · double-tap to sprint"], ["Space", "Jump · double jump"], ["↓", "Lie prone (commands still work)"],
		["C", "Dodge"], ["Shift", "Guard"], ["A S D F Q W E R", "Skills — they spend Spirit"], ["Tab / M", "Menu / world map"], ["F11", "Fullscreen"]],
	"note": "Your dragon grows with you: a baby until Lv 75, then a Drake about twice your height, and at Lv 200 a full dragon.",
}


const TANK_CONTROLS := {
	"title": "Tank's combos",
	"combos": [["Z Z Z Z", "Pistol chain", "Three shots, then a burst"], ["Z Z X", "Cooked grenade", "A short-fuse grenade with a bigger blast"],
		["Z Z Z X", "Grenade barrage", "Three grenades at once"], ["X", "Grenade", "Lobbed at the nearest enemy · ↑ + X lobs it high, onto platforms above"],
		["↑ + Z", "Shoot up", "Up close it's an uppercut that launches"], ["Z up close", "Pistol whip", "A shove that buys space"],
		["Z in the air", "Air shots", "Shot, shot, burst · ↑/↓ to aim (he aims at the nearest monster)"], ["X in the air", "Air grenade", "Thrown forward · ↑ + X up · ↓ + X straight down"], ["↓ + X", "Prone grenade", "Only Tank can throw lying down"],
		["1 – 7 / V", "Grenade type", "Frag, shrapnel, cryo, napalm, energy, EMP, cluster (built in the Workshop)"]],
	"rows": [["H / J", "Health potion / Electricity potion (3 charges each, recharging)"], ["← →", "Move · double-tap to sprint"], ["Space", "Jump · double jump · hold Space to glide (Rocket Boots) or fly (Mecha Suit)"],
		["↓", "Lie prone (Z shoots straight ahead, X throws)"], ["C", "Dodge · with Servo Legs, two rocket bursts in any direction (the second is a shoulder slam with the Chest Rig)"], ["Shift", "Guard"],
		["A S D F Q W E R", "Skills — they spend Electricity"], ["Tab / M", "Menu / world map"], ["F11", "Fullscreen"]],
	"note": "The pistol holds a magazine and reloads briefly when it runs dry; pistol upgrades add bullets and cut the reload. Grenades have a cooldown. With the helmet, a red marker shows a weak point about once a minute (bosses too): hitting it is a super crit.",
}


func _kbdRow(X: float, yy: float, W: float, key: String, text: String) -> float:
	var kw = 96.0
	var h = uPara(text, 0, 0, W - kw - 10, 9, INK, false)
	uBox(Rect2(X, yy + 1, kw, 15), PANEL2, INK, 2, 5)
	uText(key, X + kw / 2, yy + 4, 7, INK, UB, 1)
	uPara(text, X + kw + 10, yy + 2, W - kw - 10, 9, INK)
	dashed(X, X + W, yy + maxf(17, h + 3) + 1)
	return maxf(17, h + 3) + 3


func _pControls(x: float, y: float, w: float) -> float:
	var CT: Dictionary = {"archer": ARCHER_CONTROLS, "mage": MAGE_CONTROLS, "summoner": SUMMONER_CONTROLS, "tank": TANK_CONTROLS}.get(classId, ROCK_CONTROLS)
	return uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y + h3(CT.title, X, Y)
		for r in CT.combos:
			yy += _kbdRow(X, yy, W, r[0], "**%s** · %s" % [r[1], r[2]])
		yy += 6 + h3("Controls", X, yy + 6)
		for r in CT.rows:
			yy += _kbdRow(X, yy, W, r[0], r[1])
		if CT.note != "":
			yy += 4 + muted(CT.note, X, yy + 4, W)
		return yy - Y])


func _pWorld(x: float, y: float, w: float) -> float:
	var S: Dictionary = save.settings
	return uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y + h3("Weather", X, Y)
		var items = []
		for wid in ["auto"] + WEATHERS.keys():
			var label = "Auto" if wid == "auto" else WEATHERS[wid]
			var bw = uW(label, 9) + 18
			items.append([bw, func(bx, by): uButton(Rect2(bx, by, bw, 18), label, func():
				S.weather = wid
				if wid != "auto":
					setWeather(wid, false)
				_changed(), {"on": S.get("weather", "auto") == wid})])
		yy += flow(X, yy, W, items, 18, 6) + 10
		yy += h3("Time of day", X, yy)
		items = []
		for p in [[0.0, "Frozen"], [1.0, "Normal"], [8.0, "Fast"]]:
			var bw = uW(p[1], 9) + 18
			items.append([bw, func(bx, by): uButton(Rect2(bx, by, bw, 18), p[1], func(): S.timeSpeed = p[0]; _changed(), {"on": float(S.get("timeSpeed", 1.0)) == p[0]})])
		yy += flow(X, yy, W, items, 18, 6) + 6
		items = []
		for p in [[0.27, "Dawn"], [0.5, "Noon"], [0.74, "Dusk"], [0.95, "Night"]]:
			var bw = uW(p[1], 9) + 18
			items.append([bw, func(bx, by): uButton(Rect2(bx, by, bw, 18), p[1], func(): World.t = p[0])])
		yy += flow(X, yy, W, items, 18, 6) + 8
		yy += muted("Volume lives in ⚙ Settings (top bar of this menu).", X, yy, W)
		return yy - Y])
