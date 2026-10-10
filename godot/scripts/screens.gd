extends "res://scripts/lunar_ui.gd"
## Sproutvale, part 11: the screens around the game. Character select (with the gender toggle),
## starting a hero (and their story intro the first time), Settings, and the Accomplishments record.

const HERO_ORDER := ["rock", "archer", "mage", "summoner", "tank"]
const SHOWN := 4          # hero cards visible at once on the select screen

var selClass := "rock"
var carousel := 0         # index of the first card shown
var overlay := ""         # "", "settings" or "account"
var dragSlider := ""
var _sliders := {}        # setting key → Rect2 on screen, for dragging
var _lastCardClick := {"id": "", "t": -9.0}
var _introDone := false
var selGlamrax := false   # the Glamrax card is picked (once every hero is in his crystal)


func applyVolume() -> void:
	var S: Dictionary = save.settings
	Sfx.vol = float(S.get("vol", 0.5))
	Sfx.music_vol = float(S.get("music", 0.5))
	Sfx.sfx_vol = float(S.get("sfx", 0.8))


func heroLocked(id: String) -> bool:
	if heroCaptured(id):   # Glamrax's crystal holds them
		return true
	var u = CLASSES[id].get("unlock")
	return u != null and u != "" and not save.get("trophies", {}).get(u)


func jobFor(cls: String, lv: int) -> Dictionary:
	var j = 0
	for i in JOBS_BY[cls].size():
		if lv >= JOBS_BY[cls][i].lv:
			j = i
	return JOBS_BY[cls][j]


# ================================================================ character select

func pickedClass() -> String:
	return selClass if CLASSES.has(selClass) else "rock"


func heroCards() -> Array:
	return HERO_ORDER + ["glamrax"] if glamraxUnlocked() else HERO_ORDER


func pickHero(id: String) -> void:
	var now = realTime
	if id == "glamrax":
		if selGlamrax and _lastCardClick.id == id and now - _lastCardClick.t < 0.4:
			startGame()
			return
		_lastCardClick = {"id": id, "t": now}
		if not selGlamrax:
			selGlamrax = true
			Sfx.ui()
			Sfx.music("piano")
		return
	if heroCaptured(id):
		return
	selGlamrax = false
	if _lastCardClick.id == id and now - _lastCardClick.t < 0.4:
		selClass = id
		startGame()
		return
	_lastCardClick = {"id": id, "t": now}
	if selClass != id:
		selClass = id
		Sfx.ui()
		Sfx.music("sel_" + id)


func setGender(id: String, g: String) -> void:
	var ch: Dictionary = save.chars[id]
	selClass = id
	if ch.look.gender == g:
		return
	var old = DEFAULT_LOOK[id][ch.look.gender]
	var nw = DEFAULT_LOOK[id][g]
	if ch.look.get("style") == old.get("style"):
		ch.look.style = nw.get("style")
	ch.look.gender = g
	ensureLook(id, ch)
	refreshJobNames()
	saveDirty = true
	Sfx.ui()


func moveSelection(d: int) -> void:
	var avail = HERO_ORDER.filter(func(id): return not heroLocked(id))
	if avail.is_empty():
		return
	selGlamrax = false
	var i = avail.find(selClass)
	i = clampi(i + d, 0, avail.size() - 1)
	if avail[i] != selClass:
		selClass = avail[i]
		Sfx.ui()
		Sfx.music("sel_" + selClass)
	var idx = HERO_ORDER.find(selClass)
	carousel = clampi(carousel, idx - SHOWN + 1, idx)


func renderTitle(ci: CanvasItem) -> void:
	uBegin(ci, "title")
	uGrad(Rect2(0, 0, UW, UH), Color(13 / 255.0, 19 / 255.0, 48 / 255.0, 0.15), Color(13 / 255.0, 19 / 255.0, 48 / 255.0, 0.4), Color(13 / 255.0, 19 / 255.0, 48 / 255.0, 0.65), 0.5)
	refreshJobNames()
	uText("Sproutvale", UW / 2 + 3, 25, 24, DARK, PX, 1)
	uText("Sproutvale", UW / 2, 22, 24, Color.WHITE, PX, 1)
	uText("Choose your hero", UW / 2, 55, 10, GOLD, PX, 1, DARK, 2)
	# the cards: four heroes and the still-hidden fifth, in a sideways slider
	var cards = heroCards()
	if capturedAll():
		selGlamrax = true
	carousel = clampi(carousel, 0, cards.size() - SHOWN)
	var cw = 150.0
	var gap = 10.0
	var ch = 238.0
	var total = SHOWN * cw + (SHOWN - 1) * gap
	var x0 = UW / 2 - total / 2
	var y0 = 76.0
	for i in SHOWN:
		var id: String = cards[carousel + i]
		_heroCard(id, Rect2(x0 + i * (cw + gap), y0, cw, ch))
	var navY = y0 + ch / 2 - 20
	if carousel > 0:
		uButton(Rect2(x0 - 36, navY, 28, 40), "‹", func(): carousel -= 1; Sfx.ui(), {"bg": css("#3a4a8a"), "fg": Color.WHITE, "border": DARK, "size": 18, "shadow": 3.0, "rad": 8})
	if carousel + SHOWN < cards.size():
		uButton(Rect2(x0 + total + 8, navY, 28, 40), "›", func(): carousel += 1; Sfx.ui(), {"bg": css("#3a4a8a"), "fg": Color.WHITE, "border": DARK, "size": 18, "shadow": 3.0, "rad": 8})
	# Play, Accomplishments, Settings
	var by = y0 + ch + 14
	var b1 = "Play as %s" % ("Glamrax" if selGlamrax else CLASSES[selClass].name)
	if capturedAll() and save.get("showdownWon", false):
		b1 = "Break the crystal"   # the finale, waiting for you
	var w1 = uW(b1, 11) + 34
	var w2 = uW("🏆 Accomplishments", 10) + 28
	var w3 = uW("⚙ Settings", 10) + 28
	var bx = UW / 2 - (w1 + w2 + w3 + 16) / 2
	uButton(Rect2(bx, by, w1, 28), b1, func(): startGame(), {"bg": GOLD, "border": DARK, "size": 11, "shadow": 3.0, "rad": 8, "bw": 3})
	uButton(Rect2(bx + w1 + 8, by, w2, 28), "🏆 Accomplishments", func(): openAccount(), {"bg": css("#3a4a8a"), "fg": Color.WHITE, "border": DARK, "size": 10, "shadow": 3.0, "rad": 9, "bw": 3})
	uButton(Rect2(bx + w1 + w2 + 16, by, w3, 28), "⚙ Settings", func(): openSettings(), {"bg": css("#5a6478"), "fg": Color.WHITE, "border": DARK, "size": 10, "shadow": 3.0, "rad": 9, "bw": 3})
	uText("Each hero keeps their own level, gear and skills. Coins and materials are shared.", UW / 2, by + 38, 9, Color(1, 1, 1, 0.85), UF, 1, DARK)


func _heroCard(id: String, r: Rect2) -> void:
	if id == "glamrax":
		_glamraxCard(r)
		return
	if id != "???" and heroCaptured(id):
		_capturedCard(id, r)
		return
	if id == "???" or heroLocked(id):
		var won = tb(save.get("trophies", {}).get("dreamer"))
		var lines: Array
		if id == "???":
			lines = ["Coming soon" if won else "🔒 Locked", "A new hero is on the way…" if won else "Defeat The Dreamer to unlock",
				"Something woke when the Dreamer fell." if won else "Something dreams at the bottom of the Abyss."]
		elif id == "tank":
			lines = ["🔒 Locked", "Defeat The Dreamer to unlock", "Something dreams at the bottom of the Abyss."]
		else:
			lines = ["🔒 Locked", "Defeat Doc Croc to unlock", "Something stirs in a glass capsule, deep in the Crocodile Lair."]
		uBox(r, css("#221d38"), css("#4a4068"), 3, 12, 4.0, DARK)
		var q = Rect2(r.position.x + 9, r.position.y + 9, r.size.x - 18, 104)
		uBox(q, css("#2a2440"), DARK, 2, 8)
		uText("?", q.get_center().x, q.get_center().y - 22, 40, css("#6a6090"), PX, 1)
		var y = q.end.y + 6
		uText("???", r.get_center().x, y, 11, css("#d8d0f0"), UB, 1)
		y += 16
		uPill(lines[0], r.get_center().x, y, css("#c8c0e0"), DARK, 8, 1)
		y += 17
		y += uPara(lines[1], r.position.x + 9, y, r.size.x - 18, 8, css("#b8b0d8"))
		uPara(lines[2], r.position.x + 9, y + 2, r.size.x - 18, 8, css("#b8b0d8"))
		return
	var C: Dictionary = CLASSES[id]
	var chd: Dictionary = save.chars[id]
	var on = selClass == id and not selGlamrax
	var J = jobFor(id, chd.level)
	if on:
		uGlow(r, GOLD, 4, 12)
	uBox(r, css("#fff6d6") if on else Color(247 / 255.0, 251 / 255.0, 1, 0.94), GOLD if on else DARK, 3, 12, 4.0, DARK)
	var pic = Rect2(r.position.x + 9, r.position.y + 9 - (absf(sin(realTime * PI / 1.2)) * 2.5 if on else 0.0), r.size.x - 18, 104)
	var look = lookOf(id)
	var fps = float(Assets.hero_anim(look, "idle").fps)
	heroPic(pic, id, "idle", floori(realTime * fps) if on else 0)
	var y = r.position.y + 118
	uText(C.name, r.get_center().x, y, 12, INK, UB, 1)
	y += 17
	# gender toggle
	var gw = 52.0
	for gi in 2:
		var g = ["m", "f"][gi]
		var gr = Rect2(r.get_center().x - gw - 2 + gi * (gw + 4), y, gw, 15)
		var gon = chd.look.get("gender", "m") == g
		uButton(gr, "♂ Male" if g == "m" else "♀ Female", func(): setGender(id, g), {"bg": PINK if gon else Color.WHITE, "fg": Color.WHITE if gon else INK, "border": DARK, "size": 8, "shadow": 0.0, "rad": 7})
	y += 20
	jobPill(J, r.get_center().x - (uW(J.name, 8) + 12) / 2, y)
	y += 17
	uText("Lv %d · %s" % [chd.level, C.role], r.get_center().x, y, 8, MUTED, UF, 1)
	y += 13
	uPara(C.blurb, r.position.x + 9, y, r.size.x - 18, 8, css("#40497a"))
	# the card itself selects (and a quick second click starts); drawn last so the gender buttons win
	var z = {"r": Rect2(r.position + uOff, r.size), "cb": func(): pickHero(id), "tip": ""}
	uZones.insert(0, z)


## the hidden sixth card: Glamrax himself, once every hero is in his crystal
func _glamraxCard(r: Rect2) -> void:
	var on = selGlamrax
	if on:
		uGlow(r, css("#ff4ad8"), 4, 12)
	uBox(r, css("#1a0624"), css("#ff4ad8") if on else css("#7a2a9a"), 3, 12, 4.0, DARK)
	var pic = Rect2(r.position.x + 9, r.position.y + 9, r.size.x - 18, 104)
	uBox(pic, css("#2a0a30"), DARK, 2, 8)
	var bob = absf(sin(realTime * PI / 1.2)) * 2.5 if on else 0.0
	withCtx(Vector2(pic.get_center().x, pic.end.y - 8 - bob), 1.25, func(x): _drawGlamrax(x, 0, 0, 1, {"anim": "float", "form": "robe"}, realTime, false))
	var y = r.position.y + 118
	uText("Glamrax", r.get_center().x, y, 12, css("#ffb8f0"), UB, 1)
	y += 17
	uPill("Level 200", r.get_center().x, y, css("#ff4ad8"), DARK, 8, 1)
	y += 17
	uText("Wizard · Every spell", r.get_center().x, y, 8, css("#c8a8e0"), UF, 1)
	y += 13
	var line = "The heroes are coming for their loved ones. Let them come."
	if save.get("finaleDone", false):
		line = "Beaten for good. You can still hold the sanctum against them, for old times' sake."
	elif save.get("showdownWon", false):
		line = "The heroes are in his crystals. Their power is his. But one crystal is cracking..."
	uPara(line, r.position.x + 9, y, r.size.x - 18, 8, css("#e8d0f0"))
	uZones.insert(0, {"r": Rect2(r.position + uOff, r.size), "cb": func(): pickHero("glamrax"), "tip": ""})


## a hero Glamrax took: still there on the card, sealed in his purple crystal
func _capturedCard(id: String, r: Rect2) -> void:
	uBox(r, css("#1c1230"), css("#7a3ad0"), 3, 12, 4.0, DARK)
	var pic = Rect2(r.position.x + 9, r.position.y + 9, r.size.x - 18, 104)
	heroPic(pic, id, "idle", 0)
	var c = pic.get_center()
	var pulse = 0.5 + 0.5 * sin(realTime * 2.2 + HERO_ORDER.find(id))
	var pts = PackedVector2Array([c + Vector2(0, -56), c + Vector2(30, -26), c + Vector2(26, 40), c + Vector2(0, 54), c + Vector2(-26, 40), c + Vector2(-30, -26)])
	uci.draw_colored_polygon(pts, Color(0.62, 0.3, 1.0, 0.36 + pulse * 0.12))
	var edge = pts.duplicate()
	edge.append(pts[0])
	uci.draw_polyline(edge, Color(0.85, 0.65, 1.0, 0.9), 2.0, true)
	uci.draw_line(c + Vector2(-14, -40), c + Vector2(-20, 24), Color(1, 1, 1, 0.45), 2.0, true)
	uci.draw_line(c + Vector2(0, -56), c + Vector2(0, 54), Color(0.9, 0.75, 1, 0.3), 1.0, true)
	var y = r.position.y + 118
	uText(CLASSES[id].name, r.get_center().x, y, 12, css("#e8dcff"), UB, 1)
	y += 17
	uPill("💎 Captured", r.get_center().x, y, css("#b07aff"), DARK, 8, 1)
	y += 17
	uText("Lv %d" % int(save.captured[id].get("level", 1)), r.get_center().x, y, 8, css("#c8b8e8"), UF, 1)
	y += 14
	uPara("Glamrax sealed them in a crystal deep in the volcano. Their power is feeding his machine.", r.position.x + 9, y, r.size.x - 18, 8, css("#c8b8e8"))


func toCharSelect() -> void:
	if heroAfter != "":   # the end: back to the hero who broke out of the crystal
		selGlamrax = false
		selClass = heroAfter
		heroAfter = ""
		setClass(selClass)
	if heroLocked(selClass):   # the hero who just fell to Glamrax can't be picked any more
		var avail = HERO_ORDER.filter(func(h): return not heroLocked(h))
		selClass = avail[0] if avail.size() else "rock"
		setClass(selClass)
	Sfx.music("sel_" + selClass)
	inGame = false
	menuOpen = false
	overlay = ""
	for k in Buffs:
		Buffs[k] = 0.0
	for k in Cool:
		Cool[k] = 0.0
	var idx = HERO_ORDER.find(selClass)
	carousel = clampi(idx - SHOWN + 1, 0, idx)


func startGame() -> void:
	if inGame or intro != null:
		return
	if selGlamrax or capturedAll():
		startShowdown()
		return
	if heroLocked(selClass):
		selClass = "rock"
	if not STORY.has(selClass):
		save.chars[selClass].introSeen = true
	var first = not save.chars[selClass].get("introSeen", false)
	if first and not _introDone:   # first time with this hero: the story intro plays, then the game begins
		playIntro(selClass, func():
			save.chars[selClass].introSeen = true
			saveDirty = true
			_introDone = true
			startGame()
			_introDone = false)
		return
	var prevLast = save.get("lastClass", "")
	save.lastClass = selClass
	setClass(selClass)
	buildQuickslots()
	applyVolume()
	Sfx.ui()
	inGame = true
	PS = calcStats()
	P.hp = PS.hp
	P.en = PS.enMax
	P.iframes = 1.2
	P.state = "move"
	setAnim("idle")
	var pos = CH().get("pos")
	if pos is Dictionary and MAPS.has(pos.get("map", "")):
		loadMap(pos.map, pos.get("x"), pos.get("y"))
	else:
		var m = save.settings.get("map", "home")
		loadMap(m if prevLast == selClass and MAPS.has(m) else ("house" if selClass == "summoner" else "home"))
	banner("%s · %s" % [CLASSES[classId].name, jobOf(CH().level).name], "Press Tab for the menu and controls")
	P.shield = float(PS.get("eshield", 0))
	if CH().get("treeNote"):   # an older save: the attribute points came back as tree points
		CH().erase("treeNote")
		var n = int(CH().get("tp", 0))
		later(2.6, func():
			banner("THE ATTRIBUTE TREE", "Your attributes were reset and refunded: %d points to spend. Tab → Attributes." % n)
			Sfx.rankUp(8))
	persist()


# ================================================================ overlays: Settings and Accomplishments

func openSettings() -> void:
	overlay = "settings"
	Sfx.ui()


func openAccount() -> void:
	overlay = "account"
	scrollY.over = 0.0
	Sfx.ui()


func closeOverlay() -> void:
	overlay = ""
	dragSlider = ""
	Sfx.ui()
	persist()


func renderOver(ci: CanvasItem) -> void:
	uBegin(ci, "over")
	ci.draw_rect(Rect2(0, 0, UW, UH), Color(13 / 255.0, 19 / 255.0, 48 / 255.0, 0.78))
	var w = 400.0 if overlay == "settings" else UW - 40
	var h = _settingsH() if overlay == "settings" else UH - 30
	var box = Rect2(UW / 2 - w / 2, UH / 2 - h / 2, w, h)
	uBox(box, PANEL, DARK, 3, 14, 5.0, DARK)
	uText("Settings" if overlay == "settings" else "Accomplishments", box.position.x + 14, box.position.y + 12, 12, INK, PX)
	uButton(Rect2(box.end.x - 74, box.position.y + 8, 62, 21), "✕ Close", func(): closeOverlay(), {"bg": css("#d23a4a"), "fg": Color.WHITE, "border": css("#6a0f1c"), "size": 9, "shadow": 3.0, "bw": 3, "rad": 8})
	if overlay == "settings":
		overRect = Rect2()
		_settingsBody(box.position.x + 16, box.position.y + 38, w - 32)
	else:
		overRect = Rect2(box.position.x + 4, box.position.y + 36, w - 8, h - 40)
		_scrollbar("over", overRect)


func _settingsH() -> float:
	var S = save.settings
	return 38 + 5 * 30 + 24 + 30 + (34 if S.get("god") else 0) + 14


func _settingsBody(x: float, y: float, w: float) -> void:
	var S: Dictionary = save.settings
	for row in [["vol", "Master volume", 0.5, "Everything: music and sound effects"], ["music", "Music", 0.5, "The soundtrack"], ["sfx", "Sound effects", 0.8, "Hits, spells, footsteps and the rest"], ["shake", "Screen shake", 1.0, "How much the screen shakes on big hits and explosions (0% turns it off)"]]:
		var k: String = row[0]
		var v = float(S.get(k, row[2]))
		uText(row[1], x, y + 8, 10)
		var tr = Rect2(x + 120, y + 10, w - 120 - 52, 8)
		uBox(tr, css("#d6e6fb"), INK, 1, 4)
		if v > 0:
			uBox(Rect2(tr.position, Vector2(tr.size.x * v, 8)), css("#3a8fd9"), NONE, 0, 4)
		var hx = tr.position.x + tr.size.x * v
		uci.draw_circle(Vector2(hx, tr.get_center().y), 7, INK)
		uci.draw_circle(Vector2(hx, tr.get_center().y), 5.5, Color.WHITE)
		uText("%d%%" % roundi(v * 100), x + w, y + 8, 10, INK, UB, 2)
		var hit = Rect2(tr.position.x - 6, y, tr.size.x + 12, 28)
		_sliders[k] = Rect2(tr.position + uOff, tr.size)
		zone(hit, func(): dragSlider = k; setSlider(k, mouse.x), row[3])
		dashed(x, x + w, y + 29)
		y += 30
	_check(x, y, w, "Mute everything", tb(S.get("mute", false)), func(): _setMute(not S.get("mute", false)), "")
	y += 30
	uText("Testing", x, y + 6, 10, css("#a82a30"))
	y += 24
	_check(x, y, w, "God mode", tb(S.get("god", false)), func():
		S.god = not S.get("god", false)
		toast("God mode on" if S.god else "God mode off")
		saveDirty = true, "You can't be hurt, skills never run out, and you hit forty times harder. For trying content without grinding.")
	y += 30
	if S.get("god"):
		if inGame:
			var bx = x
			for b in [["Go to Doc Croc", "lair"], ["Go to the Warlord", "crimson5"], ["Go to The Dreamer", "abyss5"], ["+10 levels", "lv"]]:
				var bw = uW(b[0], 9) + 18
				uButton(Rect2(bx, y + 4, bw, 20), b[0], func(): _godGo(b[1]), {"bg": css("#ffe8a8")})
				bx += bw + 6
		else:
			uText("Start a hero to use the jump buttons.", x, y + 8, 9, MUTED, UF)


func _check(x: float, y: float, w: float, label: String, on: bool, cb: Callable, tip: String) -> void:
	uText(label, x, y + 8, 10)
	var r = Rect2(x + w - 18, y + 6, 16, 16)
	uBox(r, css("#3a8fd9") if on else Color.WHITE, INK, 2, 4)
	if on:
		uText("✔", r.get_center().x, r.position.y + 1, 10, Color.WHITE, UB, 1)
	zone(Rect2(x, y, w, 28), cb, tip)
	dashed(x, x + w, y + 29)


func setSlider(k: String, mx: float) -> void:
	var r: Rect2 = _sliders.get(k, Rect2())
	if r.size.x <= 0:
		return
	var S = save.settings
	S[k] = snappedf(clampf((mx - r.position.x) / r.size.x, 0, 1), 0.05)
	if k == "vol" and S.vol > 0:
		S.mute = false
	applyVolume()
	saveDirty = true


func _setMute(m: bool) -> void:
	var S = save.settings
	S.mute = m
	if m:
		S.preMute = [S.get("vol", 0.5), S.get("music", 0.5)]
		S.vol = 0.0
	else:
		var pm = S.get("preMute", [0.5])
		S.vol = pm[0] if pm[0] else 0.5
	applyVolume()
	saveDirty = true


func _godGo(where: String) -> void:
	if not inGame:
		return
	if where == "lv":
		for i in 10:
			gainExp(expNeed(CH().level) - CH().exp + 1)
		PS = calcStats()
		P.hp = PS.hp
		toast("Now Lv %d" % CH().level)
		return
	overlay = ""
	toggleMenu(false)
	fadeTo = {"map": where, "x": MAPS[where].start}
	Sfx.ui()


## the Accomplishments record, scrolling inside overRect
func renderOverPanel(ci: CanvasItem) -> void:
	scrollY.over = clampf(scrollY.get("over", 0.0), 0, maxf(0, contentH.get("over", 0.0) - overRect.size.y))
	uBegin(ci, "overpanel", overRect.position, overRect)
	uBgs(ci, "overpanel")
	var x = 12.0
	var y = 4.0 - scrollY.over
	var w = overRect.size.x - 24
	var y0 = y
	var H = HERO_ORDER
	var C: Dictionary = save.get("cards", {})
	var B: Dictionary = save.get("bestiary", {})
	var cardKeys = ["n", "ng", "s", "sg"]
	var cardsOwned = 0
	var cardsTotal = 0
	for k in BEST_ORDER:
		cardsTotal += 2 if bigEntry(k) else 4
		for q in cardKeys:
			if C.get(k, {}).get(q):
				cardsOwned += 1
	var totalKills = 0
	var totalLv = 0
	var totalTime = 0.0
	for h in H:
		totalKills += int(save.chars[h].get("kills", 0))
		totalLv += int(save.chars[h].level)
		totalTime += float(save.chars[h].get("playTime", 0.0))
	var discovered = BEST_ORDER.filter(func(k): return B.get(k, {}).get("kills", 0) > 0).size()
	var trophies = save.get("trophies", {}).size()
	var furn = save.house.get("owned", []).size() + save.house.get("curios", []).size()
	# heroes
	y += _ah2("Heroes", "", x, y)
	var cards = []
	for h in H:
		cards.append(_heroRecord(h))
	y += uCards(x, y, w, 2, cards) + 6
	# account record
	y += _ah2("Account record", "", x, y)
	var mq = mainQ()
	var stats = [["Heroes", str(H.size()), "Playable heroes on this account"], ["Combined levels", str(totalLv), "Every hero's level added together"],
		["Monsters defeated", fmt(totalKills), "Across all heroes"], ["Time played", fmtTime(totalTime), "Across all heroes"],
		["Coins", fmt(save.coins), CUR_TIPS.coin], ["Boss Coins", fmt(save.get("bossCoins", 0)), CUR_TIPS.boss], ["Abyssal Coins", fmt(save.get("abyssCoins", 0)), CUR_TIPS.abyss], ["Luna Coins", fmt(save.get("lunaCoins", 0)), CUR_TIPS.luna],
		["Bestiary", "%d/%d" % [discovered, BEST_ORDER.size()], "Monster types discovered (shared)"], ["Monster cards", "%d/%d" % [cardsOwned, cardsTotal], CUR_TIPS.cards],
		["Trophies", "%d/10" % trophies, "One per boss beaten, +10% EXP each for every hero"], ["Furniture & curios", str(furn), "Owned house items (shared)"],
		["Main quest", "%d: %s" % [mq.q + 1, "done" if mq.stage >= 3 else "step %d/3" % (mq.stage + 1)], MAINQS[mq.q].title]]
	var tw = (w - 5 * 6) / 6.0
	for i in stats.size():
		var r = Rect2(x + (i % 6) * (tw + 6), y + floori(i / 6.0) * 38, tw, 33)
		uBox(r, Color.WHITE, LINE, 2, 8)
		uText(stats[i][1], r.position.x + 7, r.position.y + 4, 11)
		uText(stats[i][0], r.position.x + 7, r.position.y + 19, 8, MUTED, UF)
		zone(r, Callable(), stats[i][2])
	y += ceili(stats.size() / 6.0) * 38 + 8
	# bosses
	y += _ah2("Bosses defeated", "", x, y)
	var cols = H.size() + 2
	var cw0 = 150.0
	var cw = (w - cw0) / (cols - 1)
	var rows = [null]
	for b in BOSS_LIST:
		if b != null:
			rows.append(b)
	var unknown = BOSS_LIST.filter(func(b): return b == null).size()
	if unknown:
		rows.append({"id": "", "name": "???", "where": "%d more bosses yet to be discovered" % unknown})
	var th = 20.0 + (rows.size() - 1) * 28
	uBox(Rect2(x, y, w, th), Color.WHITE, INK, 2, 9)
	for ri in rows.size():
		var ry = y + (0.0 if ri == 0 else 20 + (ri - 1) * 28)
		var rh = 20.0 if ri == 0 else 28.0
		if ri > 0:
			dashed(x + 4, x + w - 4, ry)
			var b = rows[ri]
			uText(b.name, x + 10, ry + 3, 9)
			uText(b.where, x + 10, ry + 15, 7, css("#7a809a"), UF)
		for ci2 in H.size() + 1:
			var cx = x + cw0 + ci2 * cw + cw / 2
			if ri == 0:
				uText(CLASSES[H[ci2]].name if ci2 < H.size() else "Trophy", cx, ry + 5, 9, INK, UB, 1)
				continue
			var b = rows[ri]
			if ci2 < H.size():
				var n = save.chars[H[ci2]].get("bossKills", {}).get(b.id, 0) if b.id != "" else 0
				uText(("✔ %d×" % n) if n else ("—" if b.id != "" else "·"), cx, ry + 8, 9, css("#2a8a55") if n else INK, UB if n else UF, 1)
			elif b.id != "" and save.get("trophies", {}).get(b.id):
				uText("🏆", cx, ry + 6, 11, Color.WHITE, UB, 1)
	y += th + 10
	# cards
	y += _ah2("Monster cards", "%d collected · shared by every hero" % cardsOwned, x, y)
	var aw = 132.0
	var per = maxi(1, floori((w + 6) / (aw + 6)))
	aw = (w - (per - 1) * 6) / per
	for i in BEST_ORDER.size():
		var k: String = BEST_ORDER[i]
		var r = Rect2(x + (i % per) * (aw + 6), y + floori(i / float(per)) * 70, aw, 64)
		uBox(r, Color.WHITE, LINE, 2, 8)
		var known = B.get(k, {}).get("kills", 0) > 0
		uText(bossTOf(k).name if known else "???", r.position.x + 6, r.position.y + 4, 8)
		var keys = cardKeys.slice(0, 2) if bigEntry(k) else cardKeys
		for j in keys.size():
			_cardSlot(k, keys[j], r.position.x + 6 + j * 28, r.position.y + 17, 0.55)
		if cardValue(k):
			uText("+%d%% EXP & coins" % roundi(cardValue(k) * 100), r.position.x + 6, r.end.y - 12, 7, css("#2a8a55"))
	y += ceili(BEST_ORDER.size() / float(per)) * 70
	contentH.over = y - y0 + 12


func _ah2(t: String, sub: String, x: float, y: float) -> float:
	var w = uText(t, x, y + 4, 11)
	if sub != "":
		uText(sub, x + w + 8, y + 6, 8, MUTED, UF)
	return 22.0


static func fmtTime(s: float) -> String:
	var h = floori(s / 3600)
	var m = floori(s / 60) % 60
	return "%dh %dm" % [h, m] if h else "%dm" % m


func _heroRecord(h: String) -> Callable:
	return func(X, Y, W):
		var c: Dictionary = save.chars[h]
		var J = jobFor(h, c.level)
		var G = GEAR[h]
		var CL: Dictionary = CLASSES[h]
		heroPic(Rect2(X, Y, 70, 66), h)
		var tx = X + 80
		var tw = W - 80
		var nw = uText(CL.name, tx, Y, 10)
		jobPill(J, tx + nw + 6, Y)
		var rank = RANKS[c.bestRank].r if c.get("bestRank", -1) >= 0 and c.bestRank < RANKS.size() else "—"
		var sp = 0
		for v in c.get("skills", {}).values():
			sp += int(v)
		var rows = [["Level", str(c.level)], ["Monsters defeated", fmt(c.get("kills", 0))], ["Time played", fmtTime(c.get("playTime", 0.0))], ["Best combo", rank],
			[CL.armorLabel, G.armor[c.armor].name], [CL.weaponLabel, G.weapon[c.weapon].name]]
		if G.get("staff"):
			rows.append(["Staff", G.staff[c.get("staff", 0)].name])
		if G.get("arrows"):
			rows.append(["Arrows", G.arrows[c.get("arrows", 0)].name])
		rows.append(["Charm", CHARM_TIERS[c.charm].name if c.charm >= 0 else "none"])
		rows.append(["Skill points spent", str(sp)])
		var yy = Y + 17
		for r in rows:
			uText(r[0], tx, yy, 8, MUTED, UF)
			uText(r[1], tx + tw, yy, 8, INK, UB, 2)
			yy += 11
		return maxf(yy - Y, 66)
