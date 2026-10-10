extends "res://scripts/tank_ui.gd"
## Sproutvale, part 10c: the Attribute Tree tab. A wheel of nodes around the Origin: five branches
## (Might, Precision, Agility, Spirit, Vitality) with mixed paths between them, seven rings deep.
## One point a level; click a lit node to put a point in it. The tree itself lives in attr_tree.gd.

const TREE_BG := Color("#121838")
const TREE_BG2 := Color("#1d2550")
var treeResetT := -9.0   # the Reset button asks twice


## the tree opens centred on the Origin
func openTab(id: String) -> void:
	super.openTab(id)
	if id == "tree":
		var S = minf(panelRect.size.x - 24, 740.0)
		scrollY.panel = maxf(0, 10 + 58 + 18 + S / 2.0 - panelRect.size.y / 2.0)


func _treeRes() -> String:
	return str(CLASSES[classId].get("resource", "Energy"))


func _pTree(x: float, y: float, w: float) -> float:
	var c = CH()
	if not (c.get("tree") is Dictionary):
		c.tree = {}
	var tree: Dictionary = c.tree
	var tp = int(c.get("tp", 0))
	var spent = TREE.spent(tree)
	var y0 = y
	# ---- the banner
	var br = Rect2(x, y, w, 50)
	uGrad(br, css("#2a3470"), TREE_BG2, TREE_BG, 0.5)
	uBox(br, Color(0, 0, 0, 0), GOLD, 3, 10)
	uText("ATTRIBUTE TREE", x + 12, y + 9, 14, Color.WHITE, PX, 0, Color(DARK, 0.7), 3)
	uText("One point every level · click a glowing node to grow it · rings open as you spend", x + 12, y + 31, 8, css("#c8d4ff"), UF)
	var pw = uPill("%d point%s to spend" % [tp, "" if tp == 1 else "s"], x + w - 10, y + 8, GOLD if tp > 0 else css("#5b6690"), INK if tp > 0 else Color.WHITE, 10, 2)
	if tp > 0:
		uGlow(Rect2(x + w - 10 - pw, y + 8, pw, 15), Color(GOLD, 0.35 + 0.2 * sin(realTime * 4)), 5, 7)
	var armed = realTime - treeResetT < 3.0
	var rl = "Click again to reset" if armed else "Reset tree"
	var rw = uW(rl, 8) + 16
	uButton(Rect2(x + w - 10 - rw, y + 27, rw, 17), rl, func(): _treeReset(), {"bg": PINK if armed else PANEL2, "size": 8, "disabled": spent == 0,
		"tip": "Take every point back out of the tree, for free, and spend them again however you like."})
	uText("%d spent" % spent, x + w - 18 - rw, y + 30, 8, css("#c8d4ff"), UF, 2)
	y += 58
	# ---- the branches and when each ring opens
	var lx = x + 2
	for B in TREE.SPOKES:
		uci.draw_circle(Vector2(lx + 4, y + 6), 4, css(B.col))
		lx += uText("%s (%s)" % [B.name, attrName(B.attr)], lx + 11, y + 1, 8, INK, UB) + 22
	var opens = []
	for r in range(2, TREE.RINGS + 1):
		opens.append("%d: %d" % [r, TREE.RING_NEED[r]])
	uText("Rings open at  " + " · ".join(opens) + " points", x + w, y + 1, 8, MUTED, UF, 2)
	y += 18
	# ---- the wheel
	var S = minf(w, 740.0)
	var ctr = Vector2(x + w / 2.0, y + S / 2.0)
	var R = S / 2.0 - 20
	var ringR = func(k): return 0.0 if k == 0 else R * (0.19 + 0.81 * (k - 1) / (TREE.RINGS - 1.0))
	var pos = func(n): return ctr + Vector2(cos(deg_to_rad(n.ang)), sin(deg_to_rad(n.ang))) * ringR.call(n.ring)
	uci.draw_circle(ctr, R + 16, css("#0a0f28"))
	uci.draw_circle(ctr, R + 13, TREE_BG)
	# rings: open ones faintly lit, closed ones dark with their price on them
	for k in range(TREE.RINGS, 0, -1):
		var open = spent >= TREE.RING_NEED[k]
		var rr = ringR.call(k)
		uci.draw_arc(ctr, rr, 0, TAU, 96, Color(1, 1, 1, 0.07 if open else 0.03), 18.0 if k > 1 else 2.0)
		if not open:
			var tag = "🔒 %d" % TREE.RING_NEED[k]
			var lp = ctr + Vector2(cos(deg_to_rad(-90 + 72 * 2 + 36 - 26)), sin(deg_to_rad(-90 + 72 * 2 + 36 - 26))) * rr   # between Agility and the Wanderer path
			uText(tag, lp.x, lp.y - 5, 7, Color(1, 1, 1, 0.45), UB, 1)
	# a few stars
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var a = rng.randf() * TAU
		var d = sqrt(rng.randf()) * (R + 8)
		var tw = 0.4 + 0.6 * absf(sin(realTime * (0.6 + rng.randf()) + i))
		uci.draw_circle(ctr + Vector2(cos(a), sin(a)) * d, 0.6 + rng.randf() * 0.8, Color(1, 1, 1, 0.12 + 0.25 * tw))
	# links
	for e in TREE.edges():
		var A = TREE.node(e[0])
		var B = TREE.node(e[1])
		var ra = 99 if A.kind == "origin" else TREE.rankOf(tree, A.id)
		var rb = TREE.rankOf(tree, B.id)
		var col = css(B.col if A.kind == "origin" else (A.col if A.ring > B.ring else B.col))
		var lit = ra > 0 and rb > 0
		var half = ra > 0 or rb > 0
		var lc = col if lit else (Color(col, 0.45) if half else Color(1, 1, 1, 0.12))
		var lw = 3.0 if lit else (2.0 if half else 1.5)
		if A.ring == B.ring and A.ring > 0:
			# a ring road: follow the circle
			var a0 = deg_to_rad(A.ang)
			var a1 = deg_to_rad(B.ang)
			var da = fposmod(a1 - a0 + PI, TAU) - PI
			uci.draw_arc(ctr, ringR.call(A.ring), a0, a0 + da, 16, lc, lw, true)
		else:
			uci.draw_line(pos.call(A), pos.call(B), lc, lw, true)
	# nodes
	for n in TREE.nodes():
		var p: Vector2 = pos.call(n)
		_treeNode(n, p, tree, tp)
	y += S + 8
	# ---- what the tree gives you
	var T = TREE.totals(tree)
	y += uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y + h3("What your tree gives you", X, Y)
		if T.is_empty():
			yy += muted("Nothing yet. Every level brings one attribute point; spend it on a glowing node next to the Origin.", X, yy, W) + 2
			return yy - Y
		var keys = []
		for k in ["STR", "DEX", "AGI", "WIL", "VIT"]:
			if T.has(k):
				keys.append(k)
		for k in T:
			if not keys.has(k):
				keys.append(k)
		var cw = (W - 12) / 2.0
		var col0 = yy
		var hs = [0.0, 0.0]
		for i in keys.size():
			var side = 0 if hs[0] <= hs[1] else 1
			var tx = X + side * (cw + 12)
			var tt = TREE.fxText(keys[i], T[keys[i]], _treeRes())
			if TREE.CAPS.has(keys[i]) and T[keys[i]] >= TREE.CAPS[keys[i]]:
				tt += " (the most it can go)"
			uci.draw_circle(Vector2(tx + 3, col0 + hs[side] + 6), 2.5, MINT)
			hs[side] += uPara(tt, tx + 10, col0 + hs[side], cw - 10, 8, INK) + 2
		yy = col0 + maxf(hs[0], hs[1])
		return yy - Y], [{"fill": css("#f3f6ff"), "border": INK}])
	return y - y0


func _treeNode(n: Dictionary, p: Vector2, tree: Dictionary, tp: int) -> void:
	var col = css(n.col)
	var rad = {"origin": 15.0, "minor": 11.0, "notable": 13.0, "key": 15.0, "endless": 13.0}[n.kind]
	if n.kind == "origin":
		uGlow(Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2), Color(GOLD, 0.4 + 0.2 * sin(realTime * 2)), 6, int(rad))
		uci.draw_circle(p, rad, css("#ffe08a"))
		uci.draw_arc(p, rad, 0, TAU, 32, INK, 2.0, true)
		uText(n.icon, p.x, p.y - 8, 12, Color.WHITE, UB, 1)
		zone(Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2), Callable(), "**The Origin**\nEvery path starts here. Each level gives one attribute point; put it into a node touching a node you already have.")
		return
	var r = TREE.rankOf(tree, n.id)
	var why = TREE.blocker(tree, tp, n.id)
	var can = why == ""
	var maxed = n.max > 0 and r >= n.max
	var reach = TREE.reachable(tree, n.id) and TREE.spent(tree) >= TREE.RING_NEED[n.ring]
	var hov = uHover(Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2))
	if can:
		uGlow(Rect2(p - Vector2(rad, rad), Vector2(rad, rad) * 2), Color(GOLD, 0.35 + 0.3 * sin(realTime * 4 + n.ang)), 5, int(rad))
	var fill = col if r > 0 else (Color(col, 0.28) if reach else TREE_BG2)
	if hov:
		fill = fill.lightened(0.2)
	var pts = PackedVector2Array()
	if n.kind == "key":   # keystones are diamonds
		for k in 4:
			pts.append(p + Vector2(cos(k * PI / 2), sin(k * PI / 2)) * (rad + 3))
	elif n.kind == "notable":   # notables are hexagons
		for k in 6:
			pts.append(p + Vector2(cos(k * PI / 3 + PI / 6), sin(k * PI / 3 + PI / 6)) * (rad + 1))
	var edge = GOLD if maxed else (Color.WHITE if r > 0 else (col if reach else Color(col, 0.4)))
	if pts.is_empty():
		uci.draw_circle(p, rad, fill)
		uci.draw_arc(p, rad, 0, TAU, 28, edge, 2.5 if r > 0 else 1.5, true)
		if n.kind == "endless":
			uci.draw_arc(p, rad + 3, 0, TAU, 28, Color(edge, 0.6), 1.0, true)
	else:
		uci.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		uci.draw_polyline(pts, edge, 2.5 if r > 0 else 1.5, true)
	var ia = 1.0 if (r > 0 or reach) else 0.45
	uText(n.icon, p.x, p.y - 7, 10 if n.kind == "minor" else 11, Color(1, 1, 1, ia), UB, 1)
	if r > 0 or reach:
		var lab = str(r) if n.max == 0 else "%d/%d" % [r, n.max]
		var lw = uW(lab, 7) + 6
		var lr = Rect2(p.x - lw / 2, p.y + rad - 4, lw, 10)
		uBox(lr, GOLD if maxed else (Color.WHITE if r > 0 else css("#3a4478")), INK, 1, 4)
		uText(lab, p.x, lr.position.y + 1, 7, INK if (maxed or r > 0) else Color.WHITE, UB, 1)
	var res = _treeRes()
	var tip = "**%s** · %s path · %s\n" % [n.name, n.branch, ("rank %d (no limit)" % r) if n.max == 0 else ("rank %d / %d" % [r, n.max])]
	if TREE.FLAGS.has(n.fx.keys()[0]):
		tip += TREE.describe(n, 1, res)
	else:
		if r > 0:
			tip += "Now: " + TREE.describe(n, r, res) + "\n"
		if not maxed:
			tip += (("At rank %d: " % (r + 1)) if r > 0 else "Each rank: ") + TREE.describe(n, 1 if r == 0 else r + 1, res)
	var stat0: String = n.fx.keys()[0]
	if TREE.CAPS.has(stat0):
		tip += "\n(tree total can reach %s%s)" % [TREE.num(TREE.CAPS[stat0]), "%"]
	if not can and not maxed:
		tip += "\n🔒 " + why
	elif can:
		tip += "\nClick to spend a point."
	zone(Rect2(p - Vector2(rad + 2, rad + 2), Vector2(rad + 2, rad + 2) * 2), func(): _treeBuy(n.id), tip)


func _treeBuy(id: String) -> void:
	var c = CH()
	var why = TREE.blocker(c.tree, int(c.get("tp", 0)), id)
	if why != "":
		Sfx.tone(160, 0.12, "square", 0.05, 120)
		if why != "Mastered":
			toast(why + ".")
		return
	c.tree[id] = TREE.rankOf(c.tree, id) + 1
	c.tp = int(c.tp) - 1
	var n = TREE.node(id)
	Sfx.rankUp(5 if n.kind == "minor" else 8)
	if n.max > 0 and c.tree[id] >= n.max and n.max > 1:
		toast("%s mastered." % n.name)
	_restat()
	P.shield = minf(P.shield, float(PS.get("eshield", 0)))
	_changed()


func _treeReset() -> void:
	if realTime - treeResetT >= 3.0:
		treeResetT = realTime
		Sfx.ui()
		return
	treeResetT = -9.0
	var c = CH()
	var n = TREE.spent(c.tree)
	c.tree = {}
	c.tp = int(c.get("tp", 0)) + n
	PS = calcStats()
	P.hp = minf(P.hp, PS.hp)
	P.shield = minf(P.shield, float(PS.get("eshield", 0)))
	Sfx.buy()
	toast("Tree reset: %d points back to spend." % n)
	_changed()
