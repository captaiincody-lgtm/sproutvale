extends "res://scripts/intro.gd"
## Sproutvale, part 9: the HUD, and the small immediate-mode toolkit it and the menus draw with.
## The prototype built these out of HTML and CSS. Here every box, label and button is drawn each
## frame in screen pixels (768×432), and anything clickable registers a "zone" for the mouse.

const UW := 768.0
const UH := 432.0
const INK := Color("#27335c")
const NAVY := Color("#0f163a")
const EDGE := Color("#0a0f28")
const GOLD := Color("#ffc83d")
const PANEL := Color("#f7fbff")
const PANEL2 := Color("#e8f3ff")
const MUTED := Color("#5b6690")
const LINE := Color("#d4ddf0")
const MINT := Color("#5fd39a")
const PINK := Color("#ff7eb6")
const DARK := Color("#1a1030")
const NONE := Color(0, 0, 0, 0)
const RANK_GRAD := ["#ff5d73", "#ffc83d", "#5fd39a", "#6fe0ff", "#b388ff", "#ff7eb6"]
const BOSS_INFO := {
	"croc": {"title": "⚠ Boss: Doc Croc", "stats": [["Level", "25"], ["HP", "16,000"], ["Attack", "62"], ["Defense", "18"]],
		"paras": ["**Attacks:** lunging bite on all fours · claw swipe when standing (lie prone with ↓ to duck under it) · stomp that brings rocks down on the red markers · mixes and throws poison vials that leave toxic puddles · enrages below 45% HP.",
			"**Reward:** 4,200 EXP · a shower of coins · a **Crocbox** (500–2,500 coins, 1–5 Boss Coins, maybe a rare treasure, and very rarely his Potion Throw skill)"],
		"rec": "Recommended: Lv 20+ with Swordsman skills. Walk right into the portal to enter."},
	"warlord": {"title": "⚠ Boss: Crimson Warlord", "stats": [["Level", "50"], ["HP", "60,000"], ["Attack", "150"], ["Defense", "40"]],
		"paras": ["**Attacks:** sword-and-shield cuts and a shield charge that knocks you flat · greatsword cleaves and leaping slams · throws his greatsword and walks over to fetch it · sends his own eyes after you (hit them and they fly home) · **Crimson Rain:** blood falls everywhere except beneath the two ledges, and it makes you bleed.",
			"**Reward:** 30,000 EXP · a hoard of coins · a trophy · a **Crimsonbox** (500–2,500 coins, 1–5 Boss Coins, maybe a rare treasure, and very rarely his Crimson Rain skill)"],
		"rec": "Recommended: Lv 45+. Walk right into the portal to enter."},
}

var UF: Font        # Fredoka medium: body text
var UB: Font        # Fredoka bold: labels, headings, buttons
var PX: Font        # Press Start 2P: the pixel font

var uci: CanvasItem                  # what the toolkit is drawing into right now
var uOff := Vector2.ZERO             # that canvas's top-left on screen (for zones)
var uClip := Rect2(0, 0, UW, UH)     # the part of the screen it can be seen through
var uZones: Array = []
var zonesBy := {}                    # layer name → [{r: Rect2 on screen, cb: Callable, tip: String}]
var scrollY := {}                    # scrolling layers: layer name → pixels scrolled
var contentH := {}                   # …and how tall their content was last frame
var mouse := Vector2(-999, -999)
var _sbCache := {}
var popAnim := 0.0


## JavaScript truthiness: null, false, 0, "" and empty collections are false
static func tb(v) -> bool:
	return not (not v)


func initHud() -> void:
	UF = Assets.ui_reg
	UB = Assets.ui_font
	PX = Assets.font


# ================================================================ toolkit

## Start drawing a layer. Its zones from last frame are replaced by the ones drawn now.
func uBegin(ci: CanvasItem, layer: String, off := Vector2.ZERO, clip := Rect2(0, 0, UW, UH)) -> void:
	uci = ci
	uOff = off
	uClip = clip
	if not zonesBy.has(layer):
		zonesBy[layer] = []
	uZones = zonesBy[layer]
	uZones.clear()
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func uRid() -> RID:
	return uci.get_canvas_item()


func sbox(fill: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var key = "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), bw, rad]
	if not _sbCache.has(key):
		if _sbCache.size() > 600:
			_sbCache.clear()
		var sb = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.draw_center = fill.a > 0
		sb.border_color = border
		sb.set_border_width_all(bw if border.a > 0 else 0)
		sb.set_corner_radius_all(rad)
		sb.corner_detail = 5
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 0.6
		_sbCache[key] = sb
	return _sbCache[key]


## a rounded box, like a CSS box with border, border-radius and a hard drop shadow
func uBox(r: Rect2, fill: Color, border := NONE, bw := 2, rad := 6, shadow := 0.0, shadowCol := DARK) -> void:
	if shadow != 0:
		sbox(shadowCol, NONE, 0, rad).draw(uRid(), Rect2(r.position + Vector2(0, shadow), r.size))
	sbox(fill, border, bw, rad).draw(uRid(), r)


## a soft glow around a box (box-shadow with a blur)
func uGlow(r: Rect2, col: Color, spread: float, rad := 8) -> void:
	for i in 4:
		var g = spread * (4 - i) / 4.0
		sbox(Color(col, col.a * 0.25), NONE, 0, rad + int(g)).draw(uRid(), r.grow(g))


## a rectangle filled with a vertical gradient through three colours (top, middle, bottom)
func uGrad(r: Rect2, top: Color, mid: Color, bot: Color, midAt := 0.55) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var y1 = r.position.y + r.size.y * midAt
	var a = r.position
	var b = r.end
	uci.draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), Vector2(b.x, y1), Vector2(a.x, y1)]), PackedColorArray([top, top, mid, mid]))
	uci.draw_polygon(PackedVector2Array([Vector2(a.x, y1), Vector2(b.x, y1), b, Vector2(a.x, b.y)]), PackedColorArray([mid, mid, bot, bot]))


func uW(s: String, size := 10, f: Font = null) -> float:
	return (f if f else UB).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## one line of text; `y` is the top of the line, `align` 0 left, 1 centre, 2 right. Returns its width.
func uText(s: String, x: float, y: float, size := 10, col := INK, f: Font = null, align := 0, shadow := NONE, sh := 1.0) -> float:
	f = f if f else UB
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var X = x - (w / 2.0 if align == 1 else (w if align == 2 else 0.0))
	var base = y + f.get_ascent(size)
	if shadow.a > 0:
		f.draw_string(uRid(), Vector2(X + sh, base + sh), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	f.draw_string(uRid(), Vector2(X, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w


## Word-wrapped text. **bold** switches to the bold face and back. Returns the height it takes.
## With draw = false it only measures.
func uPara(s: String, x: float, y: float, w: float, size := 9, col := INK, draw := true, bold := false, lh := 0.0, f0: Font = null, f1: Font = null) -> float:
	var reg = f0 if f0 else UF
	var bf = f1 if f1 else UB
	var lineH = lh if lh > 0 else roundf(size * 1.3)
	var space = reg.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var cy = 0.0
	var b = bold
	for para in s.split("\n"):
		var cx = 0.0
		for word in para.split(" "):
			var segs = word.split("**")
			var ww = 0.0
			var bb = b
			for i in segs.size():
				if i > 0:
					bb = not bb
				ww += (bf if bb else reg).get_string_size(segs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if cx > 0 and cx + ww > w:
				cx = 0.0
				cy += lineH
			for i in segs.size():
				if i > 0:
					b = not b
				var f = bf if b else reg
				if draw and segs[i] != "":
					f.draw_string(uRid(), Vector2(x + cx, y + cy + f.get_ascent(size)), segs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
				cx += f.get_string_size(segs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			cx += space
		cy += lineH
	return cy


func uHover(r: Rect2) -> bool:
	return Rect2(r.position + uOff, r.size).intersection(uClip).has_point(mouse)


## something the mouse can click (or hover for a tip), in the current canvas's coordinates
func zone(r: Rect2, cb: Callable, tip := "") -> void:
	var sr = Rect2(r.position + uOff, r.size).intersection(uClip)
	if sr.size.x <= 0 or sr.size.y <= 0:
		return
	uZones.append({"r": sr, "cb": cb, "tip": tip})


## A button. Options: on (gold), disabled, bg, fg, border, size, rad, tip, shadow, font.
func uButton(r: Rect2, label: String, cb: Callable, o := {}) -> void:
	var dis: bool = o.get("disabled", false)
	var bg: Color = GOLD if o.get("on", false) else o.get("bg", PANEL2)
	var bd: Color = o.get("border", INK)
	if not dis and uHover(r):
		bg = bg.lightened(0.15)
	var a = 0.45 if dis else 1.0
	uBox(r, Color(bg, bg.a * a), Color(bd, a), o.get("bw", 2), o.get("rad", 6), o.get("shadow", 2.0), Color(bd, a))
	var sz: int = o.get("size", 9)
	var f: Font = o.get("font", UB)
	uText(label, r.get_center().x, r.get_center().y - f.get_height(sz) / 2.0, sz, Color(o.get("fg", INK), a), f, 1)
	if not dis:
		zone(r, cb, o.get("tip", ""))
	elif o.has("tip"):
		zone(r, Callable(), o.tip)


## a small rounded label ("pill") sized to its text; returns its width
func uPill(s: String, x: float, y: float, bg := GOLD, fg := INK, size := 8, align := 0) -> float:
	var w = uW(s, size) + 10
	var X = x - (w / 2.0 if align == 1 else (w if align == 2 else 0.0))
	uBox(Rect2(X, y, w, size + 5), bg, NONE, 0, 7)
	uText(s, X + 5, y + 2, size, fg)
	return w


## draw the tooltip for whatever the mouse is over, looking through `layers` front to back
func drawTip(ci: CanvasItem, layers: Array) -> void:
	var tip = ""
	for L in layers:
		for z in zonesBy.get(L, []):
			if z.tip != "" and z.r.has_point(mouse):
				tip = z.tip
		if tip != "":
			break
	if tip == "":
		return
	uci = ci
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var w = minf(230.0, uW(tip, 9, UF) + 16)
	var h = uPara(tip, 0, 0, w - 14, 9, Color.WHITE, false) + 8
	var X = minf(UW - w - 6, mouse.x + 12)
	var Y = minf(UH - h - 6, mouse.y + 14)
	uBox(Rect2(X, Y, w, h), Color(20 / 255.0, 26 / 255.0, 58 / 255.0, 0.96), GOLD, 2, 6, 2.0, EDGE)
	uPara(tip, X + 7, Y + 4, w - 14, 9, Color.WHITE)


# ================================================================ HUD

func updateHud(rdt: float) -> void:
	for t in toasts:
		t.t += rdt
	toasts = toasts.filter(func(t): return t.t < 3.4)
	bannerMsg.t += rdt
	comboMsg.t += rdt
	vignette = maxf(0, vignette - rdt / 0.45)
	enShake = maxf(0, enShake - rdt)
	if Style.popped > 0:
		popAnim = 0.3
		Style.popped = 0.0
	popAnim = maxf(0, popAnim - rdt)


func renderHud(ci: CanvasItem) -> void:
	uBegin(ci, "hud")
	var indoor = tb(M.get("indoor", false))
	_bottomBar()
	if not indoor:
		_slots()
		_pots()
		_elemChips()
	_statusChips(indoor)
	_bossUI()
	_topRight(indoor)
	if not indoor:
		_styleRank()
	_hint()
	_toasts()
	_flashText(bannerMsg, 2.6, UH * 0.24, true)
	_flashText(comboMsg, 2.4, UH * 0.64, false)
	if scene != null:
		_dialog()
	if loot != null:
		_lootPanel()
	if vignette > 0:
		_vignette(vignette)


func _meter(r: Rect2, frac: float, cols: Array, tag: String, txt: String) -> void:
	uBox(r, NAVY, EDGE, 2, 5)
	var inner = r.grow(-2)
	var fw = inner.size.x * clampf(frac, 0, 1)
	if fw > 0.5:
		uGrad(Rect2(inner.position, Vector2(fw, inner.size.y)), css(cols[0]), css(cols[1]), css(cols[2]))
	uText(tag, r.position.x + 5, r.get_center().y - 3, 6, Color(1, 1, 1, 0.85), PX)
	uText(txt, r.get_center().x, r.get_center().y - 6, 9, Color.WHITE, UB, 1, EDGE)


func _bottomBar() -> void:
	var c = CH()
	var bar = Rect2(0, UH - 30, UW, 30)
	uGrad(bar, css("#2d3b72"), css("#26326a"), css("#1d2750"), 0.5)
	uci.draw_rect(Rect2(0, UH - 30, UW, 3), NAVY)
	uci.draw_rect(Rect2(0, UH - 27, UW, 1), css("#4a5ca0"))
	var x = 8.0
	var lvW = 24 + uW(str(c.level), 8, PX)
	uBox(Rect2(x, UH - 25, lvW, 20), NAVY, GOLD, 2, 6)
	uText("LV", x + 6, UH - 20, 8, GOLD, UB)
	uText(str(c.level), x + 19, UH - 19, 8, Color.WHITE, PX)
	x += lvW + 8
	var coinsW = uW(fmt(save.coins), 11) + 26
	var menuW = 82.0
	var avail = UW - x - coinsW - menuW - 26
	var unit = avail / 2.7
	_meter(Rect2(x, UH - 23, unit, 16), P.hp / PS.hp, ["#ff8a9a", "#ff5d73", "#d23a55"], "HP", "%d / %d" % [ceili(P.hp), PS.hp])
	x += unit + 6
	var sx = sin(enShake * 40) * 3 if enShake > 0.1 else 0.0
	_meter(Rect2(x + sx, UH - 23, unit * 0.7, 16), P.en / PS.enMax, ["#fff0a8", "#ffc83d", "#d88a10"], CLASSES[classId].res, "%d / %d" % [floori(P.en), PS.enMax])
	x += unit * 0.7 + 6
	var maxed = c.level >= MAX_LV
	var ep = 1.0 if maxed else float(c.exp) / expNeed(c.level)
	_meter(Rect2(x, UH - 23, unit, 16), ep, ["#b9f6ff", "#6fe0ff", "#2fb3d6"], "EXP", "MAX" if maxed else "%.1f%%" % (ep * 100))
	x += unit + 10
	_coin(Vector2(x + 6, UH - 15), 5.5)
	uText(fmt(save.coins), x + 15, UH - 22, 11, Color.WHITE, UB)
	var mb = Rect2(UW - menuW - 8, UH - 24, menuW, 18)
	uButton(mb, "Menu · Tab", func(): toggleMenu(true), {"bg": GOLD, "border": EDGE, "size": 9})
	if c.ap > 0 or c.sp > 0:
		uci.draw_circle(Vector2(mb.end.x - 3, mb.position.y + 2), 4, PINK)


func _coin(p: Vector2, r: float, kind := "coin") -> void:
	var cols = {"coin": ["#6b4a10", "#f2b92c", "#fff3b0"], "boss": ["#4a0a18", "#d23a55", "#ffd0d6"], "abyss": ["#1a0828", "#ff3ad8", "#ffd0f4"]}[kind]
	uci.draw_circle(p, r, css(cols[0]))
	uci.draw_circle(p, r - 1.5, css(cols[1]))
	uci.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.32, css(cols[2]))


func _slots() -> void:
	var c = CH()
	var sz = 26.0
	var x0 = UW - 8 - (4 * sz + 3 * 3)
	var y0 = UH - 36 - (2 * sz + 3)
	for i in SLOT_KEYS.size():
		var k: String = SLOT_KEYS[i]
		var r = Rect2(x0 + (i % 4) * (sz + 3), y0 + floori(i / 4.0) * (sz + 3), sz, sz)
		var id = c.binds.get(k, "")
		var s = SKILL.get(id) if id != "" else null
		var on = s != null and buffOn(id)
		if on:
			uGlow(r, GOLD, 4, 6)
		uBox(r, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.82 if s else 0.37), GOLD if on else EDGE, 2, 6)
		if s:
			uText(s.icon, r.get_center().x, r.position.y + 5, 13, Color.WHITE, UB, 1)
			var cd = float(Cool.get(id, 0.0))
			if cd > 0 and s.get("cd", 0) > 0:
				var h = (r.size.y - 4) * clampf(cd / s.cd, 0, 1)
				uci.draw_rect(Rect2(r.position.x + 2, r.end.y - 2 - h, r.size.x - 4, h), Color(0, 0, 0, 0.6))
			if on:
				uText("%ds" % ceili(Buffs[id]), r.end.x - 2, r.end.y - 11, 8, GOLD, UB, 2, Color.BLACK)
		uText(k.to_upper(), r.position.x + 3, r.position.y + 3, 6, Color.WHITE if s else Color(1, 1, 1, 0.45), PX, 0, Color.BLACK)


func _pots() -> void:
	var St = potState()
	var w = 27.0
	var h = 32.0
	var x0 = UW - 8 - (4 * 26 + 9) - 8 - (2 * w + 4)
	var y0 = UH - 36 - h
	var i = 0
	for k in ["hp", "sp"]:
		var p: Dictionary = St[k]
		var r = Rect2(x0 + i * (w + 4), y0, w, h)
		var a = 1.0 if p.n > 0 else 0.5
		uBox(r, Color(20 / 255.0, 26 / 255.0, 58 / 255.0, 0.85 * a), Color(EDGE, a), 2, 7)
		var fill = 1.0 if p.n >= POT.max else p.t / POT.recharge
		var fh = (h - 4) * fill
		uci.draw_rect(Rect2(r.position.x + 2, r.end.y - 2 - fh, w - 4, fh), Color(css("#ff4a5a" if k == "hp" else "#3aa8ff"), 0.45 * a))
		uText("❤" if k == "hp" else "✦", r.get_center().x, r.get_center().y - 7, 11, Color(1, 1, 1, a), UB, 1)
		uText(str(p.n), r.end.x - 3, r.position.y + 2, 9, Color(1, 1, 1, a), UB, 2)
		uText("H" if k == "hp" else "J", r.position.x + 3, r.end.y - 10, 7, Color(css("#c8d0ff"), a), UB)
		i += 1


func _chip(x: float, y: float, s: String, on: bool, lock: bool, size := 10) -> float:
	var w = uW(s, size) + 10
	var r = Rect2(x, y - (2 if on else 0), w, size + 7)
	var a = 1.0 if on else (0.3 if lock else 0.65)
	uBox(r, Color(css("#6a4aa8") if on else Color(20 / 255.0, 26 / 255.0, 58 / 255.0, 0.8), a), Color(GOLD if on else EDGE, a), 2, 6)
	uText(s, x + 5, r.position.y + 3, size, Color(1, 1, 1, a))
	return w


func _elemChips() -> void:
	if classId != "mage" and classId != "summoner":
		return
	var x = 8.0
	var y = UH - 36 - 17
	if classId == "summoner":
		x += _chip(x, y, "🐉", true, false) + 3
		for i in SUMMONS.size():
			var q: Dictionary = SUMMONS[i]
			x += _chip(x, y, "%d%s" % [i + 1, q.icon], summonOn(q.id), CH().level < q.lv) + 3
	else:
		var E2 = ELEM()
		for i in ELEMENTS.size():
			var q: Dictionary = ELEMENTS[i]
			x += _chip(x, y, "%d%s" % [i + 1, q.icon], q.id == E2.id, CH().level < q.lv) + 3


func _statusChips(indoor: bool) -> void:
	var chips = []
	if buffOn("shocked"):
		chips.append("⚡ Shocked %ds" % ceili(Buffs.shocked))
	if P.poison != null and P.poison.t > 0:
		chips.append("☠ Poisoned %ds" % ceili(P.poison.t))
	if P.bleed != null and P.bleed.t > 0:
		chips.append("🩸 Bleeding %ds" % ceili(P.bleed.t))
	var x = 8.0
	var y = UH - 36 - 17 - (0 if indoor or (classId != "mage" and classId != "summoner") else 21)
	for s in chips:
		var w = uW(s, 9) + 12
		uBox(Rect2(x, y, w, 16), Color(20 / 255.0, 26 / 255.0, 58 / 255.0, 0.85), EDGE, 2, 6)
		uText(s, x + 6, y + 3, 9, Color.WHITE)
		x += w + 4


func _bossUI() -> void:
	var b = null
	for e in slimes:
		if e.boss and e.state != "dead":
			b = e
			break
	if b != null:
		var w = minf(UW * 0.56, 368.0)
		var r = Rect2(UW / 2 - w / 2, 8, w, 32)
		if b.enraged:
			uGlow(r, css("#ff3c50"), 9, 8)
		uBox(r, Color(20 / 255.0, 10 / 255.0, 20 / 255.0, 0.85), EDGE, 2, 7)
		var nx = r.position.x + 7 + uText(b.T.name, r.position.x + 7, r.position.y + 3, 10, Color.WHITE)
		uText("Lv %d · Boss" % b.lv, nx + 6, r.position.y + 5, 8, css("#ffb0bc"), UF)
		var bb = Rect2(r.position.x + 7, r.position.y + 17, w - 14, 10)
		uBox(bb, css("#3a0f1c"), NONE, 0, 4)
		var fw = bb.size.x * clampf(b.hp / b.maxHp, 0, 1)
		if fw > 0.5:
			uGrad(Rect2(bb.position, Vector2(fw, bb.size.y)), css("#ff8a9a"), css("#e02a4a"), css("#9a1030"), 0.6)
		uText("%s / %s" % [fmt(b.hp), fmt(b.maxHp)], bb.get_center().x, bb.position.y + 1, 7, Color.WHITE, UB, 1, Color.BLACK)
	var sign = M.get("bossSign")
	if sign != null and absf(P.x - sign) < 70 and absf(P.y - M.floorY) < 4:
		var I: Dictionary = BOSS_INFO.warlord if M.get("theme") == "crimson" else BOSS_INFO.croc
		var w = minf(UW * 0.7, 336.0)
		var x = UW / 2 - w / 2
		var tw = w - 22
		var h = 12 + 14 + 26
		for p in I.paras:
			h += uPara(p, 0, 0, tw, 8, Color.WHITE, false) + 3
		h += uPara(I.rec, 0, 0, tw, 8, Color.WHITE, false) + 4
		var r = Rect2(x, UH * 0.18, w, h)
		uBox(r, Color(40 / 255.0, 10 / 255.0, 16 / 255.0, 0.92), css("#a82a30"), 3, 10, 4.0, EDGE)
		var y = r.position.y + 9
		uText(I.title, x + 11, y, 9, css("#ffe08a"), UB)
		y += 15
		for i in I.stats.size():
			var col = i % 2
			var row = floori(i / 2.0)
			var sx = x + 11 + col * (tw / 2)
			uText(I.stats[i][0], sx, y + row * 11, 8, css("#ffb0bc"), UF)
			uText(I.stats[i][1], sx + 52, y + row * 11, 8, Color.WHITE, UB)
		y += 26
		for p in I.paras:
			y += uPara(p, x + 11, y, tw, 8, Color.WHITE) + 3
		uPara(I.rec, x + 11, y, tw, 8, css("#ffe08a"))


func _topRight(indoor: bool) -> void:
	var D = World
	var hh = floori(D.t * 24)
	var mm = floori((D.t * 24 - hh) * 6) * 10
	var clock = "%02d:%02d · %s" % [hh, mm, WEATHERS[D.weather]]
	var nm: String = M.get("name", "")
	var w = maxf(uW(nm, 11), uW(clock, 8, UF)) + 18
	var r = Rect2(UW - 8 - w, 8, w, 31)
	uBox(r, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.82), EDGE, 2, 6)
	uText(nm, r.end.x - 8, r.position.y + 4, 11, Color.WHITE, UB, 2)
	uText(clock, r.end.x - 8, r.position.y + 18, 8, Color(1, 1, 1, 0.8), UF, 2)
	if indoor:
		return
	var y = _minimap(Rect2(UW - 8 - 168, r.end.y + 5, 168, 0)) + 5
	# quest tracker
	var mq = mainQ()
	var MQ: Dictionary = MAINQS[mq.q]
	var entries = []
	if not mq.claimed:
		entries.append({"text": "★ " + ("Claim your reward (Quests tab)" if mq.stage >= MQ.steps.size() else MQ.steps[mq.stage]), "main": true})
	for q in save.quests:
		entries.append({"text": ("✔ " if q.done else "") + q.title, "done": q.done, "p": minf(1.0, float(q.have) / q.need)})
	for e in entries:
		var tw = minf(uW(e.text, 8), 200.0)
		var th = uPara(e.text, 0, 0, tw + 6, 8, INK, false, e.has("main"))
		var hh2 = th + 6 + (5 if e.has("p") else 0)
		var er = Rect2(UW - 8 - tw - 14, y, tw + 14, hh2)
		var bg = css("#fff2d6") if e.has("main") else (css("#e3fbec") if e.get("done", false) else Color(247 / 255.0, 251 / 255.0, 1, 0.92))
		var bd = css("#c89418") if e.has("main") else (css("#2a8a55") if e.get("done", false) else INK)
		uBox(er, bg, bd, 2, 6)
		uPara(e.text, er.position.x + 7, y + 3, tw + 6, 8, css("#6a4a08") if e.has("main") else INK, true, e.has("main"))
		if e.has("p"):
			var pr = Rect2(er.position.x + 7, er.end.y - 6, tw, 3)
			uBox(pr, css("#d6e6fb"), NONE, 0, 2)
			if e.p > 0:
				uBox(Rect2(pr.position, Vector2(tw * e.p, 3)), MINT, NONE, 0, 2)
		y += hh2 + 4


## the prototype's minimap, drawn at 168 px wide; returns the y of its bottom edge
func _minimap(r: Rect2) -> float:
	var s: float = r.size.x / M.w
	var h: float = maxf(24, roundf(M.h * s))
	var o = r.position
	var u = 1.4   # one pixel of the prototype's little minimap canvas
	uBox(Rect2(o - Vector2(2, 2), Vector2(r.size.x + 4, h + 4)), css("#121a3c"), EDGE, 2, 6)
	uci.draw_rect(Rect2(o, Vector2(r.size.x, h)), Color(18 / 255.0, 26 / 255.0, 60 / 255.0, 0.85))
	var view = Rect2(o + cam * s, Vector2(VW, VH) * s).intersection(Rect2(o, Vector2(r.size.x, h)))
	uci.draw_rect(view, Color(111 / 255.0, 224 / 255.0, 1, 0.12))
	if M.get("pond"):
		var pd = M.pond
		uci.draw_rect(Rect2(o + Vector2(pd.x0, pd.surface) * s, Vector2((pd.x1 - pd.x0) * s, maxf(u, (pd.bottom - pd.surface) * s))), css("#3f86d8"))
	for rp in M.get("ropes", []):
		uci.draw_rect(Rect2(o + Vector2(rp[0], rp[1]) * s, Vector2(u, maxf(u, (rp[2] - rp[1]) * s))), css("#c49468"))
	for q in surfaces:
		if q.get("water", false):
			continue
		uci.draw_rect(Rect2(o + Vector2(q.x0, q.y) * s, Vector2(maxf(u, (q.x1 - q.x0) * s), u)), css("#7fd35a") if q.get("floor", false) else css("#b4ef86"))
	for p in M.get("portals", []):
		var py = p.get("y", null)
		uci.draw_rect(Rect2(o + Vector2(p.x, py if py else M.floorY) * s - Vector2(u, 3 * u), Vector2(2 * u, 3 * u)), css("#9fe6ff"))
	for e in slimes:
		if e.state != "dead":
			var d = 2 * u if e.elite else u
			uci.draw_rect(Rect2(o + Vector2(e.x, e.y) * s - Vector2(0, u), Vector2(d, d)), css("#ff5d73"))
	if obelisk != null and not obelisk.get("used", false):
		uci.draw_rect(Rect2(o + Vector2(obelisk.x, obelisk.y) * s - Vector2(u, 4 * u), Vector2(2 * u, 4 * u)), css("#ff3ad8") if int(realTime / 0.25) % 2 else css("#b88aff"))
	var blink = int(realTime / 0.3) % 2 == 1
	uci.draw_rect(Rect2(o + Vector2(P.x, P.y) * s - Vector2(u, 3 * u), Vector2(3 * u, 3 * u)), css("#ffe14d") if blink else css("#fff6b0"))
	return o.y + h + 2


func _styleRank() -> void:
	if not (Style.hits > 0 or Style.pts > 4):
		return
	var R: Dictionary = RANKS[Style.rank]
	var nx = RANKS[Style.rank + 1] if Style.rank + 1 < RANKS.size() else null
	var y = UH * 0.42
	var right = UW - 10
	var size = int(round(24 * (1 + 0.6 * popAnim / 0.3)))
	var sw = uW(R.r, size, PX)
	var hot = Style.rank >= 7
	var hue = fmod(realTime * 0.6, 1.0) if hot else 0.0
	# the rank letters wear the prototype's rainbow gradient, one colour band per letter
	var x = right - sw
	var n = R.r.length()
	for i in n:
		var ch: String = R.r[i]
		var col = css(RANK_GRAD[int(float(i) / maxi(1, n) * 4)]) if n > 1 else css(RANK_GRAD[Style.rank % RANK_GRAD.size()])
		if hot:
			col.h = fmod(col.h + hue, 1.0)
		uText(ch, x + 3, y + 3, size, DARK, PX)
		x += uText(ch, x, y, size, col, PX)
	uText(R.t, right, y + size + 5, 7, Color.WHITE, PX, 2, DARK, 2)
	var frac = clampf((Style.pts - R.min) / (nx.min - R.min), 0, 1) if nx != null else 1.0
	var br = Rect2(right - 104, y + size + 17, 104, 5)
	uBox(br, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.7), NONE, 0, 2)
	if frac > 0:
		var fw = br.size.x * frac
		uci.draw_polygon(PackedVector2Array([br.position, br.position + Vector2(fw, 0), br.position + Vector2(fw, 5), br.position + Vector2(0, 5)]),
			PackedColorArray([css("#ff5d73"), css("#b388ff").lerp(css("#ff5d73"), 1 - frac), css("#b388ff").lerp(css("#ff5d73"), 1 - frac), css("#ff5d73")]))
	if Style.hits:
		uText("%d hits" % Style.hits, right, br.end.y + 5, 7, GOLD, PX, 2, DARK, 2)


func hintText() -> String:
	if inWater():
		return "Space or ↑ to swim up · jump near the bank to climb out"
	if P.state == "climb":
		return "↑ ↓ to climb · ↑ or Space + ← → to jump off"
	var pt = portalAt()
	if pt != null:
		return ("Press ↑ · " + pt.label) if pt.get("door", false) else ("Press ↑ to travel to " + pt.label)
	var r = ropeAt()
	if r != null and P.grounded and absf(P.y - r.y0) > 2:
		return "Press ↑ to climb"
	return ""


func _hint() -> void:
	var s = hintText()
	if s == "":
		return
	var w = uW(s, 9, UF) + 16
	var r = Rect2(UW / 2 - w / 2, UH - 36 - 17, w, 16)
	uBox(r, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.8), NONE, 0, 6)
	uText(s, UW / 2, r.position.y + 3, 9, Color.WHITE, UF, 1)


func _toasts() -> void:
	var y = 8.0
	for t in toasts:
		var k = clampf(t.t / 0.25, 0, 1)
		var a = k * clampf((3.4 - t.t) / 0.3, 0, 1)
		var tw = minf(uW(t.msg, 9, UF), UW * 0.44 - 18)
		var th = uPara(t.msg, 0, 0, tw + 6, 9, INK, false)
		var r = Rect2(8 - (1 - k) * 12, y, tw + 18, th + 7)
		uBox(r, Color(PANEL, 0.95 * a), Color(INK, a), 2, 6)
		uPara(t.msg, r.position.x + 9, y + 3, tw + 6, 9, Color(INK, a))
		y += r.size.y + 5


## the banner and the combo result: pop in, hold, fade (the prototype's "ban" keyframes)
func _flashText(m: Dictionary, life: float, y: float, centered: bool) -> void:
	var k: float = m.t / life
	if k >= 1 or m.big == "":
		return
	var a = clampf(k / 0.1, 0, 1) if k < 0.1 else (1.0 if k < 0.8 else 1 - (k - 0.8) / 0.2)
	var shadow = Color(DARK, a)
	if centered:
		var s = 1.25 - 0.25 * clampf(k / 0.1, 0, 1)
		var size = int(round(15 * s))
		uText(m.big, UW / 2, y, size, Color(1, 1, 1, a), PX, 1, shadow, 3)
		if m.sub != "":
			uText(m.sub, UW / 2, y + size + 8, 11, Color(1, 1, 1, a), UB, 1, shadow, 2)
	else:
		uText(m.big, UW - 10, y, 8, Color(1, 1, 1, a), PX, 2, shadow, 2)
		uText(m.sub, UW - 10, y + 13, 9, Color(GOLD, a), UB, 2, shadow, 2)


func _dialog() -> void:
	var Sc: Dictionary = scene
	var L: Dictionary = Sc.lines[Sc.i]
	var w = minf(UW * 0.8, 496.0)
	var h = 60.0
	var r = Rect2(UW / 2 - w / 2, UH - 42 - h, w, h)
	uGlow(r, Color(160 / 255.0, 20 / 255.0, 40 / 255.0, 0.5), 12, 10)
	uBox(r, Color(20 / 255.0, 6 / 255.0, 10 / 255.0, 0.92), css("#8a1a24"), 3, 10)
	uText(L.get("who", ""), r.position.x + 13, r.position.y + 9, 8, css("#ff8a9a"), PX)
	var txt: String = L.text.substr(0, floori(Sc.shown))
	uPara(txt, r.position.x + 13, r.position.y + 22, w - 26, 11, Color.WHITE, true, false, 15)
	uText("Z ▶", r.end.x - 10, r.end.y - 14 + sin(realTime * 6) * 1.5, 8, css("#ffb8c4"), UB, 2)


## a boss box popping open: the box shakes, the lid flies up, then each prize appears in turn
func _lootPanel() -> void:
	var L: Dictionary = loot
	var red: bool = L.kind == "warlord"
	var t: float = L.t
	var n: int = L.rows.size()
	var shown: int = L.get("shown", 0)
	uci.draw_rect(Rect2(0, 0, UW, UH), Color(0.04, 0.02, 0.08, minf(0.6, t * 2)))
	var w = 340.0
	var h = 140.0 + n * 22
	var r = Rect2(UW / 2 - w / 2, UH / 2 - h / 2, w, h)
	var edge = css("#ff5d73") if red else css("#e8b830")
	uGlow(r, Color(edge, 0.45), 14, 12)
	uBox(r, css("#1c0a10") if red else css("#10200e"), edge, 3, 12)
	uText(String(L.name).to_upper(), UW / 2, r.position.y + 12, 12, edge, PX, 1, Color.BLACK, 2)
	# the box itself
	var bx = UW / 2
	var by = r.position.y + 100
	var open = t > 0.8
	var jig = 0.0 if open else sin(t * 60) * (t / 0.8) * 3
	var body = css("#8a1a24") if red else css("#3f7a2c")
	var shine = css("#b8303c") if red else css("#5fa83e")
	var band = css("#2a1418") if red else css("#e8b830")
	if open:
		uGlow(Rect2(bx - 26, by - 46, 52, 30), Color(edge, 0.5 + 0.3 * sin(realTime * 6)), 10, 12)
		for i in 6:
			var a = realTime * 0.8 + i * TAU / 6
			uci.draw_line(Vector2(bx, by - 30), Vector2(bx + cos(a) * 44, by - 30 + sin(a) * 26), Color(edge, 0.25), 3)
	uBox(Rect2(bx - 28 + jig, by - 30, 56, 30), body, Color.BLACK, 2, 3)
	uci.draw_rect(Rect2(bx - 18 + jig, by - 30, 6, 30), band)
	uci.draw_rect(Rect2(bx + 12 + jig, by - 30, 6, 30), band)
	var lidY = by - 44 - (minf(1, (t - 0.8) * 6) * 16 if open else 0.0)
	uBox(Rect2(bx - 30 + jig, lidY, 60, 15), shine, Color.BLACK, 2, 4)
	uci.draw_rect(Rect2(bx - 18 + jig, lidY + 2, 6, 11), band)
	uci.draw_rect(Rect2(bx + 12 + jig, lidY + 2, 6, 11), band)
	if not open:
		uBox(Rect2(bx - 5 + jig, by - 34, 10, 9), css("#ffd84a"), Color.BLACK, 1, 2)
	# the prizes
	var yy = by + 10
	for i in shown:
		var row: Dictionary = L.rows[i]
		var k = clampf((t - 0.9 - i * 0.35) / 0.2, 0, 1)
		var col = Color.WHITE
		if row.rare == 1:
			col = GOLD
		elif row.rare == 2:
			col = css("#ff9ef0")
			uGlow(Rect2(r.position.x + 18, yy - 2, w - 36, 20), Color(col, 0.35 + 0.2 * sin(realTime * 6)), 6, 8)
		uText(row.icon, r.position.x + 30, yy + 1, 13, Color(1, 1, 1, k))
		uText(row.text, r.position.x + 52, yy + 3, 10, Color(col, k), UB)
		yy += 22
	if shown >= n and t > 1.2 + n * 0.35:
		uText("Z ▶", r.end.x - 12, r.end.y - 16 + sin(realTime * 6) * 1.5, 8, edge, UB, 2)


## the red flash at the screen edges when you take a big hit
func _vignette(a: float) -> void:
	var c0 = Color(1, 40 / 255.0, 70 / 255.0, 0.6 * a)
	var c1 = Color(1, 40 / 255.0, 70 / 255.0, 0)
	var d = 46.0
	var quads = [
		[Vector2(0, 0), Vector2(UW, 0), Vector2(UW - d, d), Vector2(d, d)],
		[Vector2(UW, 0), Vector2(UW, UH), Vector2(UW - d, UH - d), Vector2(UW - d, d)],
		[Vector2(UW, UH), Vector2(0, UH), Vector2(d, UH - d), Vector2(UW - d, UH - d)],
		[Vector2(0, UH), Vector2(0, 0), Vector2(d, d), Vector2(d, UH - d)],
	]
	for q in quads:
		uci.draw_polygon(PackedVector2Array(q), PackedColorArray([c0, c0, c1, c1]))
