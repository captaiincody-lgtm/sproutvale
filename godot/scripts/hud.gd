extends RefCounted
## The HUD (bars, minimap, potions, style rank, messages), the Tab character panel and the title card.
## Drawn in screen pixels on the 768×432 canvas, styled after the prototype's HTML overlay.

const S := preload("res://scripts/state.gd")
const W := 768.0
const H := 432.0
const INK := Color("#27335c")
const NAVY := Color("#0f163a")
const EDGE := Color("#0a0f28")
const GOLD := Color("#ffc83d")
const PANEL := Color("#f7fbff")
const RANK_COLS := ["#ff5d73", "#ffc83d", "#5fd39a", "#6fe0ff", "#b388ff", "#ff7eb6"]

var G
var P: S.Player
var px: FontFile    # pixel font
var ui: FontFile    # rounded font


func _init(game) -> void:
	G = game
	P = game.P
	px = Assets.font
	ui = Assets.ui_font


func box(ci: CanvasItem, r: Rect2, fill: Color, border := EDGE, bw := 2.0) -> void:
	ci.draw_rect(r, fill)
	if bw > 0:
		ci.draw_rect(r.grow(-bw / 2), border, false, bw)


func label(ci: CanvasItem, f: FontFile, s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, shadow := Color(0, 0, 0, 0)) -> void:
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x = pos.x - (w / 2 if align == HORIZONTAL_ALIGNMENT_CENTER else (w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
	if shadow.a > 0:
		ci.draw_string(f, Vector2(roundf(x) + 2, roundf(pos.y) + 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	ci.draw_string(f, Vector2(roundf(x), roundf(pos.y)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func meter(ci: CanvasItem, r: Rect2, frac: float, cols: Array, tag: String, txt: String) -> void:
	box(ci, r, NAVY, EDGE, 2)
	var inner = r.grow(-2)
	var fw = inner.size.x * clampf(frac, 0, 1)
	if fw > 0:
		var a = inner.position
		ci.draw_polygon(PackedVector2Array([a, a + Vector2(fw, 0), a + Vector2(fw, inner.size.y), a + Vector2(0, inner.size.y)]),
			PackedColorArray([Color(cols[0]), Color(cols[0]), Color(cols[2]), Color(cols[2])]))
		ci.draw_rect(Rect2(a + Vector2(0, inner.size.y * 0.35), Vector2(fw, inner.size.y * 0.3)), Color(cols[1], 0.5))
	label(ci, px, tag, Vector2(r.position.x + 5, r.position.y + r.size.y / 2 + 3), 6, Color(1, 1, 1, 0.85))
	label(ci, ui, txt, Vector2(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2 + 4), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, EDGE)


static func fmt(n: float) -> String:
	var s = str(roundi(n))
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func draw(ci: CanvasItem) -> void:
	if G.mode == "title":
		_title(ci)
		return
	var c: Dictionary = G.CH()
	var PS: Dictionary = G.PS
	# --- bottom bar
	var bar = Rect2(0, H - 30, W, 30)
	ci.draw_polygon(PackedVector2Array([bar.position, bar.position + Vector2(W, 0), bar.end, bar.position + Vector2(0, 30)]),
		PackedColorArray([Color("#2d3b72"), Color("#2d3b72"), Color("#1d2750"), Color("#1d2750")]))
	ci.draw_rect(Rect2(0, H - 30, W, 3), Color("#0f163a"))
	ci.draw_rect(Rect2(0, H - 27, W, 1), Color("#4a5ca0"))
	var x = 8.0
	box(ci, Rect2(x, H - 25, 46, 20), NAVY, GOLD, 2)
	label(ci, ui, "LV", Vector2(x + 6, H - 10), 9, GOLD)
	label(ci, px, str(c.level), Vector2(x + 20, H - 10), 8, Color.WHITE)
	x += 54
	var coins_w = 90.0
	var menu_w = 82.0
	var avail = W - x - coins_w - menu_w - 24
	var unit = avail / 2.7
	meter(ci, Rect2(x, H - 23, unit, 16), P.hp / PS.hp, ["#ff8a9a", "#ff5d73", "#d23a55"], "HP", "%d / %d" % [ceili(P.hp), PS.hp])
	x += unit + 6
	meter(ci, Rect2(x, H - 23, unit * 0.7, 16), P.en / PS.enMax, ["#fff0a8", "#ffc83d", "#d88a10"], "EN", "%d / %d" % [floori(P.en), PS.enMax])
	x += unit * 0.7 + 6
	var need: int = G.exp_need(int(c.level))
	var ep: float = 1.0 if c.level >= G.MAX_LV else float(c.exp) / need
	meter(ci, Rect2(x, H - 23, unit, 16), ep, ["#b9f6ff", "#6fe0ff", "#2fb3d6"], "EXP", "MAX" if c.level >= G.MAX_LV else "%.1f%%" % (ep * 100))
	x += unit + 10
	ci.draw_circle(Vector2(x + 6, H - 15), 6, Color("#6b4a10"))
	ci.draw_circle(Vector2(x + 6, H - 15), 4.5, Color("#f2b92c"))
	ci.draw_circle(Vector2(x + 4.5, H - 16.5), 1.6, Color("#fff3b0"))
	label(ci, ui, fmt(G.save.coins), Vector2(x + 16, H - 10), 12, Color.WHITE)
	var mb = Rect2(W - menu_w - 8, H - 24, menu_w, 18)
	box(ci, mb, GOLD, EDGE, 2)
	label(ci, ui, "Menu · Tab" + (" (!)" if c.ap > 0 else ""), mb.get_center() + Vector2(0, 4), 10, INK, HORIZONTAL_ALIGNMENT_CENTER)
	# --- potions
	var pw = 26.0
	for i in 2:
		var k: String = ["hp", "sp"][i]
		var p: Dictionary = P.pots[k]
		var r = Rect2(W - 150 + i * (pw + 4), H - 66, pw, 32)
		var fill: float = 1.0 if p.n >= 3 else p.t / 25.0
		box(ci, r, Color(20 / 255.0, 26 / 255.0, 58 / 255.0, 0.85 if p.n else 0.45), EDGE, 2)
		ci.draw_rect(Rect2(r.position.x + 2, r.end.y - 2 - (r.size.y - 4) * fill, r.size.x - 4, (r.size.y - 4) * fill), Color("#ff4a5a" if k == "hp" else "#3aa8ff", 0.45))
		label(ci, ui, "♥" if k == "hp" else "✦", r.get_center() + Vector2(0, 5), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		label(ci, ui, str(p.n), Vector2(r.end.x - 3, r.position.y + 10), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		label(ci, ui, "H" if k == "hp" else "J", Vector2(r.position.x + 3, r.end.y - 3), 8, Color("#c8d0ff"))
	# --- top right: place, clock, minimap
	var D: Dictionary = G.world
	var hh = floori(D.t * 24)
	var mm = floori((D.t * 24 - hh) * 6) * 10
	var clock = "%02d:%02d · %s" % [hh, mm, G.WEATHERS[D.weather]]
	var name_w = maxf(ui.get_string_size(G.M.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, ui.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x) + 16
	var pr = Rect2(W - 8 - name_w, 8, name_w, 34)
	box(ci, pr, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.82), EDGE, 2)
	label(ci, ui, G.M.name, Vector2(pr.end.x - 8, pr.position.y + 16), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	label(ci, ui, clock, Vector2(pr.end.x - 8, pr.position.y + 28), 9, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	_minimap(ci, Rect2(W - 8 - 168, 48, 168, 0))
	# --- style rank
	var st: Dictionary = G.style
	if st.hits > 0 or st.pts > 4:
		var R: Dictionary = G.D.ranks[st.rank]
		var nx = G.D.ranks[st.rank + 1] if st.rank + 1 < G.D.ranks.size() else null
		var y = H * 0.42
		var scl = 1.0 + st.popped * 0.6
		var rc = Color(RANK_COLS[int(G.real_time * 6) % RANK_COLS.size()]) if st.rank >= 7 else Color(RANK_COLS[st.rank % RANK_COLS.size()])
		label(ci, px, R.r, Vector2(W - 12, y), roundi(24 * scl), rc, HORIZONTAL_ALIGNMENT_RIGHT, Color("#1a1030"))
		label(ci, px, R.t, Vector2(W - 12, y + 16), 8, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, Color("#1a1030"))
		var frac = clampf((st.pts - R.min) / (nx.min - R.min), 0, 1) if nx != null else 1.0
		ci.draw_rect(Rect2(W - 12 - 100, y + 24, 100, 4), Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.7))
		ci.draw_rect(Rect2(W - 12 - 100, y + 24, 100 * frac, 4), rc)
		if st.hits:
			label(ci, px, "%d hits" % st.hits, Vector2(W - 12, y + 42), 8, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, Color("#1a1030"))
	# --- hint
	var hint = _hint()
	if hint != "":
		var hw = ui.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 20
		var hr = Rect2(W / 2 - hw / 2, H - 56, hw, 18)
		box(ci, hr, Color(15 / 255.0, 22 / 255.0, 58 / 255.0, 0.8), EDGE, 0)
		label(ci, ui, hint, hr.get_center() + Vector2(0, 4), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# --- toasts
	var ty = 10.0
	for t in G.toasts:
		var a = clampf(t.t / 0.25, 0, 1) * clampf((3.4 - t.t) / 0.3, 0, 1)
		var tw = ui.get_string_size(t.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 20
		var tr = Rect2(10 - (1 - clampf(t.t / 0.25, 0, 1)) * 12, ty, tw, 20)
		box(ci, tr, Color(PANEL, 0.95 * a), Color(INK, a), 2)
		label(ci, ui, t.msg, Vector2(tr.position.x + 10, tr.position.y + 14), 11, Color(INK, a))
		ty += 24
	# --- banner and combo result
	_flash_text(ci, G.banner_msg, 2.6, Vector2(W / 2, H * 0.3), HORIZONTAL_ALIGNMENT_CENTER, 20)
	_flash_text(ci, G.combo_msg, 2.4, Vector2(W - 12, H * 0.66), HORIZONTAL_ALIGNMENT_RIGHT, 9)
	if G.panel_open:
		_panel(ci)


func _flash_text(ci: CanvasItem, m: Dictionary, life: float, pos: Vector2, align: int, size: int) -> void:
	var k: float = m.t / life
	if k >= 1 or m.big == "":
		return
	var a = clampf(k / 0.1, 0, 1) if k < 0.1 else (1.0 if k < 0.8 else 1 - (k - 0.8) / 0.2)
	var s = 1.25 - 0.25 * clampf(k / 0.1, 0, 1)
	label(ci, px, m.big, pos, roundi(size * s), Color(1, 1, 1, a), align, Color(26 / 255.0, 16 / 255.0, 48 / 255.0, a))
	label(ci, ui, m.sub, pos + Vector2(0, 22 if size > 12 else 16), 13 if size > 12 else 11, Color(GOLD if size <= 12 else Color.WHITE, a), align, Color(26 / 255.0, 16 / 255.0, 48 / 255.0, a))


func _hint() -> String:
	if G.in_water():
		return "Space or ↑ to swim up · jump near the bank to climb out"
	if P.state == "climb":
		return "↑ ↓ to climb · ↑ or Space + ← → to jump off"
	var pt = G.portal_at()
	if pt != null:
		return ("Press ↑ · " + pt.label) if pt.get("door", false) else ("Press ↑ to travel to " + pt.label)
	var r = G.rope_at()
	if r != null and P.grounded and absf(P.y - r.y0) > 2:
		return "Press ↑ to climb"
	return ""


func _minimap(ci: CanvasItem, r: Rect2) -> void:
	var M: Dictionary = G.M
	var s: float = r.size.x / M.w
	var h: float = maxf(24, roundf(M.h * s))
	var o = r.position
	box(ci, Rect2(o - Vector2(2, 2), Vector2(r.size.x + 4, h + 4)), Color("#121a3c"), EDGE, 2)
	ci.draw_rect(Rect2(o, Vector2(r.size.x, h)), Color(18 / 255.0, 26 / 255.0, 60 / 255.0, 0.85))
	ci.draw_rect(Rect2(o + G.cam * s, Vector2(G.VW, G.VH) * s), Color(111 / 255.0, 224 / 255.0, 1, 0.12))
	if M.has("pond"):
		ci.draw_rect(Rect2(o + Vector2(M.pond.x0, M.pond.surface) * s, Vector2(M.pond.x1 - M.pond.x0, M.pond.bottom - M.pond.surface) * s), Color("#3f86d8"))
	for rp in M.ropes:
		ci.draw_rect(Rect2(o + Vector2(rp[0], rp[1]) * s, Vector2(1, maxf(1, (rp[2] - rp[1]) * s))), Color("#c49468"))
	for q in G.surfaces:
		if q.water:
			continue
		ci.draw_rect(Rect2(o + Vector2(q.x0, q.y) * s, Vector2(maxf(1, (q.x1 - q.x0) * s), 1)), Color("#7fd35a") if q.floor else Color("#b4ef86"))
	for p in M.portals:
		ci.draw_rect(Rect2(o + Vector2(p.x, p.get("y", M.floorY)) * s - Vector2(1, 3), Vector2(2, 3)), Color("#9fe6ff"))
	for e in G.mobs:
		if e.state != "dead":
			ci.draw_rect(Rect2(o + Vector2(e.x, e.y) * s - Vector2(0, 1), Vector2(1, 1)), Color("#ff5d73"))
	var blink = int(G.real_time / 0.3) % 2 == 0
	ci.draw_rect(Rect2(o + Vector2(P.x, P.y) * s - Vector2(1, 3), Vector2(3, 3)), Color("#ffe14d") if blink else Color("#fff6b0"))


func _panel(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), Color(10 / 255.0, 15 / 255.0, 40 / 255.0, 0.55))
	var r = Rect2(36, 36, W - 72, H - 96)
	box(ci, r, PANEL, INK, 3)
	var c: Dictionary = G.CH()
	var PS: Dictionary = G.PS
	var x = r.position.x + 20
	var y = r.position.y + 30
	label(ci, px, "Rock", Vector2(x, y), 12, INK)
	label(ci, ui, "Lv %d · %s" % [c.level, G.job_name(int(c.level))], Vector2(x + 64, y), 14, Color("#3a8fd9"))
	y += 24
	label(ci, ui, "Attributes  ·  %d point%s to spend%s" % [c.ap, "" if c.ap == 1 else "s", " (press 1–5)" if c.ap > 0 else ""], Vector2(x, y), 12, INK)
	y += 6
	for i in G.ATTRS.size():
		var a: String = G.ATTRS[i]
		var rr = Rect2(x, y + 4 + i * 22, 300, 19)
		box(ci, rr, Color("#e8f3ff"), Color("#c4d4ee"), 1)
		label(ci, px, str(i + 1), Vector2(rr.position.x + 8, rr.position.y + 14), 8, Color("#3a8fd9") if c.ap > 0 else Color("#9aa8c8"))
		label(ci, ui, a, Vector2(rr.position.x + 26, rr.position.y + 14), 12, INK)
		label(ci, ui, G.ATTR_DESC[a], Vector2(rr.position.x + 66, rr.position.y + 14), 11, Color("#5b6690"))
		label(ci, ui, str(c.attrs[a]), Vector2(rr.end.x - 10, rr.position.y + 14), 12, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 4 + 5 * 22 + 18
	var stats = [["Max HP", fmt(PS.hp)], ["Attack", fmt(PS.atk)], ["Defense", fmt(PS.def)], ["Critical", "%.1f%%" % PS.crit], ["Crit damage", "%d%%" % roundi(PS.critDmg * 100)], ["Move speed", "%d%%" % roundi(PS.spd * 100)]]
	for i in stats.size():
		var sx = x + (i % 3) * 104
		var sy = y + (i / 3) * 18
		label(ci, ui, stats[i][0], Vector2(sx, sy), 11, Color("#5b6690"))
		label(ci, ui, stats[i][1], Vector2(sx + 98, sy), 11, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 44
	label(ci, ui, "Materials", Vector2(x, y), 12, INK)
	var mx = x
	var mats = []
	for k in G.save.mats:
		if G.save.mats[k] > 0:
			mats.append(k)
	if mats.is_empty():
		label(ci, ui, "Nothing yet. Defeat monsters to collect their drops.", Vector2(x, y + 18), 11, Color("#5b6690"))
	for k in mats:
		var t = Assets.tex("items/residue_%s.png" % k)
		if mx > x + 290:
			break
		ci.draw_texture_rect(t, Rect2(mx, y + 6, 18, 18), false)
		label(ci, ui, str(G.save.mats[k]), Vector2(mx + 20, y + 20), 11, INK)
		mx += 44
	# controls, right column
	var cx = r.position.x + 352
	var cy = r.position.y + 30
	label(ci, ui, "Controls", Vector2(cx, cy), 14, INK)
	var rows = [["← →", "Move (double-tap to run)"], ["Space", "Jump, again to double jump"], ["Z", "Attack, keep pressing to chain"], ["↑ + Z", "Rising slash (launcher)"],
		["X", "Heavy slash · in the air: Meteor Drop"], ["C", "Dodge roll"], ["Shift", "Block (tap just in time to parry)"], ["↓", "Slide out of a run, else lie prone"],
		["↑", "Climb ropes, use doors and portals"], ["H  /  J", "Health / energy potion"], ["Tab", "This panel"], ["Esc", "Title screen"], ["F11  ·  − +", "Fullscreen · volume"]]
	for i in rows.size():
		var ry = cy + 20 + i * 18
		box(ci, Rect2(cx, ry - 12, 74, 16), Color("#e8f3ff"), INK, 1)
		label(ci, ui, rows[i][0], Vector2(cx + 37, ry), 10, INK, HORIZONTAL_ALIGNMENT_CENTER)
		label(ci, ui, rows[i][1], Vector2(cx + 80, ry), 10, Color("#3d4a78"))
	label(ci, ui, "Kills %s · Played %s" % [fmt(c.kills), _time(c.get("playTime", 0.0))], Vector2(r.end.x - 16, r.end.y - 12), 10, Color("#8a94b8"), HORIZONTAL_ALIGNMENT_RIGHT)


static func _time(s: float) -> String:
	var h = floori(s / 3600)
	var m = floori(s / 60) % 60
	return ("%dh %02dm" % [h, m]) if h else ("%dm" % m)


func _title(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), Color(10 / 255.0, 15 / 255.0, 40 / 255.0, 0.45))
	var r = Rect2(W / 2 - 200, 92, 400, 220)
	box(ci, r, PANEL, INK, 3)
	label(ci, px, "Sproutvale", Vector2(W / 2, r.position.y + 50), 24, Color("#3a8fd9"), HORIZONTAL_ALIGNMENT_CENTER, Color("#1d2750"))
	label(ci, ui, "Rock · Lv %d %s" % [G.CH().level, G.job_name(int(G.CH().level))], Vector2(W / 2, r.position.y + 82), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var blink = 0.6 + 0.4 * sin(G.real_time * 4)
	var b = Rect2(W / 2 - 80, r.position.y + 100, 160, 34)
	box(ci, b, Color(GOLD, 1), EDGE, 2)
	label(ci, ui, "Play  ·  Enter", b.get_center() + Vector2(0, 6), 16, Color(INK, blink + 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	label(ci, ui, "← → move · Space jump · Z attack · X heavy · C dodge · Shift block", Vector2(W / 2, r.position.y + 162), 11, Color("#5b6690"), HORIZONTAL_ALIGNMENT_CENTER)
	label(ci, ui, "Tab opens your character and the full controls · Esc quits", Vector2(W / 2, r.position.y + 180), 11, Color("#5b6690"), HORIZONTAL_ALIGNMENT_CENTER)
	label(ci, ui, "Your progress saves automatically.", Vector2(W / 2, r.position.y + 202), 10, Color("#8a94b8"), HORIZONTAL_ALIGNMENT_CENTER)
