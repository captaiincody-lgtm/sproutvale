extends "res://scripts/abyss_draw.gd"
## Sproutvale, part 8: the story intro played when a hero starts a new adventure.
## Each scene is painted on a 384×216 canvas (through `ctx`, scaled 2× to the screen) and
## a text box with Skip / Next buttons sits along the bottom, as in the prototype.

const SW2 := 384.0
const SH2 := 216.0

var intro = null          # {cls, scenes: [{text, title, kind}], i, shown, t, done: Callable, fallen, run}
var introBtns := {}       # "skip" / "next": Rect2 in screen pixels, for mouse hit-tests


func _ipoly(x: Ctx, pts: Array, fill) -> void:
	x.beginPath()
	x.moveTo(pts[0][0], pts[0][1])
	for i in range(1, pts.size()):
		x.lineTo(pts[i][0], pts[i][1])
	x.closePath()
	x.fillStyle = fill
	x.fill()


static func _irnd(i: float) -> float:
	var s = sin(i * 127.1) * 43758.5453
	return s - floor(s)


# ------------------------------------------------------------------ scenes

## Scene 1: the captive in a crystal, Glamrax looming behind
func drawCaptiveScene(x: Ctx, t: float, kin: String) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#07030f"); g.addColorStop(1, "#2a0c3c"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 60:
		x.fillStyle = rgba(220, 180, 255, 0.3 + 0.7 * absf(sin(t * 1.5 + i))); x.fillRect(roundf(_irnd(i) * SW2), roundf(_irnd(i + 99) * SH2 * 0.7), 1, 1)
	# swirling mist rings
	for i in 5:
		x.strokeStyle = rgba(160, 60, 200, 0.12 + i * 0.03); x.lineWidth = 6 - i; x.beginPath(); x.ellipse(192, 120, 150 - i * 18, 40 - i * 4, sin(t * 0.3 + i) * 0.08, t * 0.4 + i, t * 0.4 + i + 4.2); x.stroke()
	# ---- Glamrax ----
	var bob = sin(t * 1.2) * 2
	var cx = 192.0
	var top = 2 + bob
	_ipoly(x, [[cx - 120, 205], [cx - 70, 70 + top], [cx - 30, 60 + top], [cx, 190]], "#1a0a24")   # cape wings
	_ipoly(x, [[cx + 120, 205], [cx + 70, 70 + top], [cx + 30, 60 + top], [cx, 190]], "#1a0a24")
	_ipoly(x, [[cx - 110, 205], [cx - 66, 78 + top], [cx - 34, 70 + top], [cx - 4, 195]], "#3a0f4a")
	_ipoly(x, [[cx + 110, 205], [cx + 66, 78 + top], [cx + 34, 70 + top], [cx + 4, 195]], "#3a0f4a")
	_ipoly(x, [[cx - 46, 216], [cx - 32, 62 + top], [cx + 32, 62 + top], [cx + 46, 216]], "#24102e")   # robe
	for i in 6:
		_ipoly(x, [[cx - 46 + i * 15, 216], [cx - 38 + i * 15, 206], [cx - 31 + i * 15, 216]], "#07030f")   # tattered hem
	_ipoly(x, [[cx - 6, 216], [cx - 3, 90 + top], [cx + 3, 90 + top], [cx + 6, 216]], "#7a2a8a")   # robe trim
	# hat with a crooked tip and brim
	_ipoly(x, [[cx - 40, 46 + top], [cx + 40, 46 + top], [cx + 30, 40 + top], [cx - 30, 40 + top]], "#2a0f3a")
	_ipoly(x, [[cx - 20, 42 + top], [cx + 20, 42 + top], [cx + 8, 0 + top], [cx + 28, -10 + top]], "#3a1450")
	_ipoly(x, [[cx - 20, 42 + top], [cx + 20, 42 + top], [cx + 17, 37 + top], [cx - 17, 37 + top]], "#9a3ad8")
	# shadowed face, glowing eyes, long grey beard
	x.fillStyle = "#0e0616"; x.beginPath(); x.ellipse(cx, 56 + top, 15, 13, 0, 0, TAU); x.fill()
	var glow = 0.7 + 0.3 * sin(t * 4)
	for ex in [-6, 6]:
		x.fillStyle = rgba(255, 58, 216, glow); x.fillRect(cx + ex - 3, 52 + top, 6, 2); x.fillStyle = rgba(255, 140, 240, glow * 0.35); x.fillRect(cx + ex - 5, 50 + top, 10, 6)
	_ipoly(x, [[cx - 12, 62 + top], [cx + 12, 62 + top], [cx + 6, 100 + top], [cx, 112 + top], [cx - 6, 100 + top]], "#b8b0c0")
	_ipoly(x, [[cx - 8, 64 + top], [cx + 2, 64 + top], [cx - 1, 104 + top]], "#d8d0e0")
	# raised hands crackling with magic, and a staff
	for s in [-1, 1]:
		x.fillStyle = "#3a1450"; x.beginPath(); x.ellipse(cx + s * 60, 104 + top, 12, 8, s * 0.4, 0, TAU); x.fill(); x.fillStyle = "#8a7a96"; x.beginPath(); x.arc(cx + s * 68, 98 + top, 5, 0, TAU); x.fill()
	x.strokeStyle = "#3a2a1a"; x.lineWidth = 4; x.beginPath(); x.moveTo(cx + 92, 210); x.lineTo(cx + 74, 60 + top); x.stroke()
	x.fillStyle = rgba(255, 58, 216, glow); x.beginPath(); x.arc(cx + 73, 54 + top, 7, 0, TAU); x.fill(); x.fillStyle = "#fff"; x.fillRect(cx + 70, 51 + top, 2, 2)
	# magic tethers from his hands to the crystal
	for s in [-1, 1]:
		x.strokeStyle = rgba(255, 100, 230, 0.5 + 0.4 * sin(t * 9 + s)); x.lineWidth = 1; x.beginPath()
		var px0 = cx + s * 68
		var py0 = 98 + top
		x.moveTo(px0, py0)
		for k in range(1, 7):
			var qx = px0 + (cx + s * 20 - px0) * k / 6.0 + (_irnd(k + floor(t * 12)) - 0.5) * 8
			var qy = py0 + (130 - py0) * k / 6.0 + (_irnd(k * 3 + floor(t * 12)) - 0.5) * 8
			x.lineTo(qx, qy)
		x.stroke()
	# ---- the crystal prison ----
	var cy = 126 + sin(t * 1.6) * 3
	var w = 26.0
	var h = 40.0
	x.fillStyle = rgba(160, 230, 255, 0.16); x.beginPath(); x.ellipse(cx, cy, 44, 58, 0, 0, TAU); x.fill()
	# the child inside (drawn first, seen through the crystal)
	if kin != "none":
		drawCaptive(x, cx, cy + 8, kin, t)
	_ipoly(x, [[cx, cy - h - 16], [cx + w, cy - h + 10], [cx + w, cy + h - 10], [cx, cy + h + 16], [cx - w, cy + h - 10], [cx - w, cy - h + 10]], rgba(150, 220, 255, 0.32))
	_ipoly(x, [[cx, cy - h - 16], [cx + w, cy - h + 10], [cx + 6, cy - h + 18], [cx - 6, cy - h + 4]], rgba(230, 250, 255, 0.35))
	_ipoly(x, [[cx - w, cy - h + 10], [cx - 10, cy - h + 22], [cx - 12, cy + h - 4], [cx - w, cy + h - 10]], rgba(255, 255, 255, 0.12))
	x.strokeStyle = rgba(220, 250, 255, 0.9); x.lineWidth = 1.2; x.beginPath(); x.moveTo(cx, cy - h - 16); x.lineTo(cx + w, cy - h + 10); x.lineTo(cx + w, cy + h - 10); x.lineTo(cx, cy + h + 16); x.lineTo(cx - w, cy + h - 10); x.lineTo(cx - w, cy - h + 10); x.closePath(); x.stroke()
	x.strokeStyle = rgba(200, 160, 255, 0.6); x.beginPath(); x.moveTo(cx - w, cy - h + 10); x.lineTo(cx + 6, cy - h + 18); x.lineTo(cx + w, cy - h + 10); x.moveTo(cx + 6, cy - h + 18); x.lineTo(cx + 2, cy + h + 4); x.stroke()
	for i in 6:
		var a = t * 2 + i
		x.fillStyle = "#e8fbff"; x.fillRect(roundf(cx + cos(a) * 40), roundf(cy + sin(a * 1.3) * 60), 1, 1)


func drawCaptive(x: Ctx, cx: float, cy: float, kin: String, t: float) -> void:
	var sway = sin(t * 1.6) * 0.5
	# body: a small tunic or dress, arms pressed to the crystal
	if kin == "sister":
		_ipoly(x, [[cx - 9, cy + 22], [cx - 5, cy - 4], [cx + 5, cy - 4], [cx + 9, cy + 22]], "#4f9a5a"); x.fillStyle = "#3f7a48"; x.fillRect(cx - 9, cy + 20, 18, 2)
	else:
		_ipoly(x, [[cx - 7, cy + 18], [cx - 6, cy - 4], [cx + 6, cy - 4], [cx + 7, cy + 18]], "#d8c89a"); x.fillStyle = "#6e5444"; x.fillRect(cx - 7, cy + 8, 14, 2); x.fillStyle = "#3b3634"; x.fillRect(cx - 6, cy + 18, 12, 6)
	x.fillStyle = "#ffdcc2"; x.fillRect(cx - 5, cy + 22 + 2, 3, 8); x.fillRect(cx + 2, cy + 24, 3, 8)
	x.strokeStyle = "#ffdcc2"; x.lineWidth = 3; x.beginPath(); x.moveTo(cx - 6, cy); x.lineTo(cx - 14, cy - 10 + sway); x.moveTo(cx + 6, cy); x.lineTo(cx + 14, cy - 10 - sway); x.stroke()
	# head, face, hair
	x.fillStyle = "#ffdcc2"; x.beginPath(); x.arc(cx, cy - 12, 9, 0, TAU); x.fill()
	if kin == "sister":
		x.fillStyle = "#e8c060"; x.beginPath(); x.arc(cx, cy - 15, 9.5, PI, 0); x.fill(); x.fillRect(cx - 9.5, cy - 15, 3, 8); x.fillRect(cx + 6.5, cy - 15, 3, 8)
		for s in [-1, 1]:
			x.beginPath(); x.ellipse(cx + s * 13, cy - 8 + sin(t * 2 + s) * 0.6, 3.5, 7, s * 0.3, 0, TAU); x.fill(); x.fillStyle = "#c0392b"; x.fillRect(cx + s * 11 - 1, cy - 16, 3, 2); x.fillStyle = "#e8c060"
	else:
		x.fillStyle = "#6e3c20"; x.beginPath(); x.arc(cx, cy - 15, 9.5, PI, 0); x.fill()
		for i in 6:
			_ipoly(x, [[cx - 9 + i * 3.4, cy - 17], [cx - 7 + i * 3.4 + (2 if i % 2 else -2), cy - 26], [cx - 5 + i * 3.4, cy - 17]], "#6e3c20")
	# closed, frightened eyes and a small open mouth
	x.fillStyle = "#2a1a1a"; x.fillRect(cx - 5, cy - 11, 3, 1); x.fillRect(cx + 2, cy - 11, 3, 1); x.fillRect(cx - 1, cy - 6, 2, 2)
	x.fillStyle = rgba(140, 210, 255, 0.9); x.fillRect(cx + 4, cy - 9 + fmod(t * 6, 5.0), 1, 2)


## the hero lying down / a run frame, given as {tex, n, f}: frame f of an n-frame strip
func _iheroImg(x: Ctx, img, dx: float, dy: float, dw: float, dh: float) -> void:
	if img == null or img.tex == null:
		return
	x.drawFrame(img.tex, img.n, img.f, dx, dy, dw, dh)


## Remy's opening: beaten in the rain, Glamrax walking away
func drawDefeatScene(x: Ctx, t: float, fallen) -> void:
	var tm = fmod(t, 3.4)
	var flash = tm < 0.12 or (tm > 0.22 and tm < 0.3)
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#6a6a90" if flash else "#14161f"); g.addColorStop(1, "#4a4a6a" if flash else "#262a38"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 9:
		x.fillStyle = rgba(140, 140, 180, 0.7) if flash else rgba(40, 44, 60, 0.85); x.beginPath(); x.ellipse(_irnd(i + 3) * SW2, 20 + _irnd(i + 9) * 40, 50 + _irnd(i) * 40, 16, 0, 0, TAU); x.fill()
	if flash:
		x.strokeStyle = "#ffffff"; x.lineWidth = 1.5; x.beginPath()
		var bx = 300.0
		var by = 0.0
		x.moveTo(bx, by)
		for s in 8:
			bx += (_irnd(s + floor(t)) - 0.5) * 24; by += 14; x.lineTo(bx, by)
		x.stroke()
	# muddy ground with puddles
	x.fillStyle = "#1e2018"; x.fillRect(0, 160, SW2, 56); x.fillStyle = "#2a3020"; x.fillRect(0, 160, SW2, 3)
	for pw in [[90, 40], [210, 30], [300, 50]]:
		x.fillStyle = "#7a80a0" if flash else "#2e3448"; x.beginPath(); x.ellipse(pw[0], 172, pw[1], 3, 0, 0, TAU); x.fill()
	# Remy lies in the mud, the staff snapped beside them
	if fallen:
		_iheroImg(x, fallen, 70, 160 - SH * 0.95 + 9, SW * 0.95, SH * 0.95)
	x.strokeStyle = "#5a3a20"; x.lineWidth = 2; x.beginPath(); x.moveTo(140, 168); x.lineTo(152, 164); x.moveTo(156, 169); x.lineTo(168, 167); x.stroke()
	# Glamrax walks away into the storm
	var gx = 250 + t * 9
	var gy = 162.0
	var a = maxf(0, 1 - t / 9)
	x.globalAlpha = a
	_ipoly(x, [[gx - 14, gy], [gx - 8, gy - 52], [gx + 8, gy - 52], [gx + 16, gy]], "#120818"); _ipoly(x, [[gx - 24, gy], [gx - 10, gy - 48], [gx - 6, gy - 46], [gx - 10, gy]], "#0a0410")
	_ipoly(x, [[gx - 14, gy - 52], [gx + 14, gy - 52], [gx + 4, gy - 76], [gx + 16, gy - 82]], "#1a0a24")
	x.fillStyle = rgba(255, 58, 216, 0.9); x.fillRect(gx - 4, gy - 50, 3, 1.5); x.fillRect(gx + 2, gy - 50, 3, 1.5)
	x.strokeStyle = "#2a1a14"; x.lineWidth = 2; x.beginPath(); x.moveTo(gx + 18, gy); x.lineTo(gx + 14, gy - 60); x.stroke(); x.fillStyle = rgba(255, 58, 216, 0.6 + 0.4 * sin(t * 4)); x.beginPath(); x.arc(gx + 14, gy - 63, 3.5, 0, TAU); x.fill()
	x.globalAlpha = 1
	# rain
	x.strokeStyle = rgba(170, 190, 230, 0.55); x.lineWidth = 1; x.beginPath()
	for i in 160:
		var rx = fmod(_irnd(i) * (SW2 + 60) + t * 40, SW2 + 60) - 30
		var ry = fmod(_irnd(i + 200) * SH2 + t * 420 + i * 7, SH2)
		x.moveTo(rx, ry); x.lineTo(rx - 3, ry + 9)
	x.stroke()
	for i in 12:
		var sx0 = _irnd(i + 50) * SW2
		var k = fmod(t * 2 + _irnd(i), 1.0)
		x.strokeStyle = rgba(190, 210, 240, 0.6 * (1 - k)); x.beginPath(); x.ellipse(sx0, 166 + (i % 3) * 4, 2 + k * 5, 0.8 + k, 0, 0, TAU); x.stroke()


func _irange(x: Ctx, y0: float, amp: float, col, seed: int) -> void:
	x.fillStyle = col; x.beginPath(); x.moveTo(0, SH2)
	for X in range(0, int(SW2) + 1, 4):
		x.lineTo(X, y0 - absf(sin(X * 0.02 + seed)) * amp - _irnd(floor(X / 4.0) + seed) * 3)
	x.lineTo(SW2, SH2); x.closePath(); x.fill()


## Scene 2: the Abyss Volcano, far across the land
func drawVolcanoScene(x: Ctx, t: float, cls: String) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#0a0418"); g.addColorStop(0.55, "#3a0f4a"); g.addColorStop(0.8, "#8a2a6a"); g.addColorStop(1, "#2a0a24"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 90:
		x.fillStyle = rgba(255, 230, 255, 0.2 + 0.6 * absf(sin(t + i * 1.7))); x.fillRect(roundf(_irnd(i + 5) * SW2), roundf(_irnd(i + 55) * 90), 1, 1)
	x.fillStyle = "#e8d8ff"; x.beginPath(); x.arc(320, 34, 14, 0, TAU); x.fill(); x.fillStyle = "#0a0418"; x.beginPath(); x.arc(326, 30, 13, 0, TAU); x.fill()
	# distant ranges
	_irange(x, 168, 20, "#2a1038", 1)
	x.save(); x.translate(200, 176); x.scale(0.6, 0.6); x.translate(-200, -176)   # far, far away
	# the volcano: a vast purple cone, rim-lit, with glowing rivers of abyssal magma
	var vx = 200.0
	var peakY = 62.0
	x.fillStyle = "#3a1450"; x.beginPath(); x.moveTo(40, 178); x.quadraticCurveTo(140, 130, vx - 26, peakY); x.lineTo(vx + 26, peakY); x.quadraticCurveTo(260, 130, 360, 178); x.closePath(); x.fill()
	x.fillStyle = "#5a2070"; x.beginPath(); x.moveTo(vx + 26, peakY); x.quadraticCurveTo(260, 130, 360, 178); x.lineTo(300, 178); x.quadraticCurveTo(240, 128, vx + 18, peakY + 4); x.closePath(); x.fill()
	var pulse = 0.6 + 0.4 * sin(t * 2)
	for r in [[vx - 10, 130, 175], [vx + 4, 210, 178], [vx + 16, 262, 176], [vx - 18, 92, 178]]:
		var sx0: float = r[0]
		var ex0: float = r[1]
		var ey0: float = r[2]
		x.strokeStyle = rgba(255, 58, 216, 0.55 * pulse); x.lineWidth = 1.5; x.beginPath(); x.moveTo(sx0, peakY + 4); x.quadraticCurveTo((sx0 + ex0) / 2 + 6, 120, ex0, ey0); x.stroke()
	x.fillStyle = rgba(255, 90, 230, 0.8 * pulse); x.fillRect(vx - 24, peakY - 2, 48, 4)
	x.fillStyle = rgba(255, 120, 240, 0.25 * pulse); x.beginPath(); x.ellipse(vx, peakY, 60, 18, 0, 0, TAU); x.fill()
	# smoke plume drifting east
	for i in 14:
		var k = fmod(t * 0.06 + i / 14.0, 1.0)
		var px0 = vx + k * 120 + sin(i) * 6
		var py0 = peakY - k * 70
		var r = 8 + k * 26
		x.fillStyle = rgba(90 + i * 4, 40, 110 + i * 5, 0.45 * (1 - k)); x.beginPath(); x.arc(px0, py0, r, 0, TAU); x.fill()
	# the tiny crystal hanging over the crater
	var cyy = peakY - 26 + sin(t * 1.6) * 1.5
	x.fillStyle = rgba(190, 240, 255, 0.7 + 0.3 * sin(t * 4)); x.beginPath(); x.moveTo(vx, cyy - 6); x.lineTo(vx + 3, cyy); x.lineTo(vx, cyy + 6); x.lineTo(vx - 3, cyy); x.closePath(); x.fill()
	x.fillStyle = rgba(190, 240, 255, 0.25); x.beginPath(); x.arc(vx, cyy, 8, 0, TAU); x.fill()
	x.restore()
	var hz = x.createLinearGradient(0, 120, 0, 190); hz.addColorStop(0, rgba(120, 40, 120, 0)); hz.addColorStop(1, rgba(120, 40, 120, 0.45)); x.fillStyle = hz; x.fillRect(0, 120, SW2, 70)   # distance haze
	_irange(x, 184, 8, "#1e0c2a", 3)
	# foreground cliff with the hero watching
	_irange(x, 196, 6, "#140818", 7)
	x.fillStyle = "#0a040e"; x.beginPath(); x.moveTo(0, SH2); x.lineTo(0, 150); x.lineTo(60, 156); x.lineTo(96, 170); x.lineTo(110, SH2); x.closePath(); x.fill()
	var hero = heroSilhouette(cls)
	if hero:
		x.drawFrame(hero, hero_idle_frames(cls), 0, 30, 112, SW * 0.55, SH * 0.55)


func _ilook(cls: String) -> String:
	var c: Dictionary = save.get("chars", {}).get(cls, {})
	var g: String = c.get("look", {}).get("gender", "m")
	return "%s_%s" % [cls, g]


func hero_idle_frames(cls: String) -> int:
	return int(Assets.hero_anim(_ilook(cls), "idle").frames)


## the hero's idle strip as a flat dark shape (Assets caches it)
func heroSilhouette(cls: String) -> Texture2D:
	return Assets.silhouette(Assets.hero_strip(_ilook(cls), "idle", 1), Color("#0a040e"))


## Jojo's opening: the shattered capsule in Doc Croc's lab
func drawCapsuleScene(x: Ctx, t: float, hero) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#0a1410"); g.addColorStop(1, "#16241c"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	for i in 6:
		x.fillStyle = "#1e2e26"; x.fillRect(i * 70 - 10, 0, 6, 160)   # pipes on the cave wall
	x.fillStyle = "#2a3a30"; x.fillRect(20, 120, 90, 6); x.fillRect(270, 112, 100, 6)   # lab benches with vials
	for i in 6:
		var vx = 28 + i * 13
		var c = ["#6cff8a", "#ff6a8a", "#9fe6ff"][i % 3]
		x.fillStyle = "#dff0ff"; x.fillRect(vx, 106, 5, 14); x.fillStyle = c; x.fillRect(vx, 112 + (i % 2) * 2, 5, 8 - (i % 2) * 2)
	x.fillStyle = "#0e1612"; x.fillRect(0, 168, SW2, 48)
	# spilled fluid glowing on the floor
	x.fillStyle = rgba(110, 255, 170, 0.25 + 0.1 * sin(t * 2)); x.beginPath(); x.ellipse(192, 172, 120, 9, 0, 0, TAU); x.fill()
	# the capsule: a tall glass cylinder, front shattered, a green glow from inside
	var cx = 192.0
	x.fillStyle = "#3a4a44"; x.fillRect(cx - 34, 160, 68, 10); x.fillRect(cx - 34, 30, 68, 10)
	x.fillStyle = rgba(110, 255, 170, 0.12 + 0.05 * sin(t * 3)); x.fillRect(cx - 30, 40, 60, 120)
	x.strokeStyle = rgba(200, 255, 230, 0.6); x.lineWidth = 1; x.strokeRect(cx - 30.5, 40.5, 61, 119)
	_ipoly(x, [[cx - 30, 40], [cx - 6, 40], [cx - 14, 70], [cx - 26, 95], [cx - 30, 92]], rgba(200, 255, 230, 0.25))   # a jagged fragment still in the frame
	_ipoly(x, [[cx + 30, 40], [cx + 12, 40], [cx + 20, 64], [cx + 30, 80]], rgba(200, 255, 230, 0.25))
	for i in 16:
		var sx = cx - 70 + _irnd(i) * 140
		var sy = 164 + _irnd(i + 30) * 10
		_ipoly(x, [[sx, sy], [sx + 4, sy - 2], [sx + 2, sy + 2]], rgba(200, 255, 230, 0.7))   # shards on the floor
	for i in 4:
		var dy = fmod(t * 30 + i * 40, 120.0)
		x.fillStyle = rgba(160, 255, 200, 0.6); x.fillRect(cx - 20 + i * 12, 40 + dy, 1.5, 3)   # drips
	# Jojo, slumped against the base, slowly stirring
	if hero:
		_iheroImg(x, hero, cx - 46, 168 - SH * 0.95 + 8, SW * 0.95, SH * 0.95)
	if sin(t * 1.3) > 0.6:
		x.fillStyle = "#ffffff"; x.font = '10px "Press Start 2P", monospace'; x.fillText("?", cx + 6, 120 - sin(t * 2) * 3)


## the memory: Glamrax commanding Doc Croc, washed in a flickering red-violet
func drawMemoryScene(x: Ctx, t: float) -> void:
	drawCaptiveScene(x, t, "none")
	var croc = Assets.mob_strip("croc", "stand")
	if croc:
		x.save(); x.translate(300, 200); x.scale(-0.55, 0.55); x.drawFrame(croc, 2, absi(int(floor(t * 2))) % 2, -BOX, -BOY, BW, BH); x.restore()
	var f = 0.55 + 0.1 * sin(t * 13) + (0.2 if randf() < 0.05 else 0.0)
	x.fillStyle = rgba(120, 30, 90, f * 0.5); x.fillRect(0, 0, SW2, SH2)
	var v = x.createRadialGradient(192, 108, 40, 192, 108, 230); v.addColorStop(0, rgba(0, 0, 0, 0)); v.addColorStop(1, rgba(0, 0, 0, 0.85)); x.fillStyle = v; x.fillRect(0, 0, SW2, SH2)
	for i in 30:
		x.fillStyle = rgba(255, 255, 255, 0.08); x.fillRect(0, fmod(i * 13 + t * 90, SH2), SW2, 1)   # scanlines: it's a memory


## Jojo runs home through the dusk: four evenly spaced frames of the run strip
func heroRunFrames(cls: String) -> Dictionary:
	var look = _ilook(cls)
	var n = int(Assets.hero_anim(look, "run").frames)
	var fs = []
	for i in 4:
		fs.append(int(floor(i * n / 4.0)))
	return {"tex": Assets.hero_strip(look, "run", 1), "n": n, "fs": fs}


func drawRushHomeScene(x: Ctx, t: float, frames) -> void:
	var g = x.createLinearGradient(0, 0, 0, SH2); g.addColorStop(0, "#2a1a4a"); g.addColorStop(0.6, "#c8606a"); g.addColorStop(1, "#ffb878"); x.fillStyle = g; x.fillRect(0, 0, SW2, SH2)
	x.fillStyle = "#ffe0a0"; x.beginPath(); x.arc(70, 150, 16, 0, TAU); x.fill()   # the setting sun
	var off = fmod(t * 50, 160.0)
	x.fillStyle = "#4a3a5a"; x.beginPath(); x.moveTo(0, 170)
	for X in range(0, int(SW2) + 1, 8):
		x.lineTo(X, 150 - absf(sin((X + off * 0.3) * 0.02)) * 22)
	x.lineTo(SW2, 170); x.fill()   # distant hills drift past
	for i in 6:
		var tx = fposmod(i * 80 - t * 120, 480.0) - 40
		x.fillStyle = "#2a3a2a"; x.fillRect(tx, 132, 4, 40); x.beginPath(); x.arc(tx + 2, 128, 14, 0, TAU); x.fill()   # trees racing by
	x.fillStyle = "#3a5a2a"; x.fillRect(0, 170, SW2, 46); x.fillStyle = "#4a7a3a"; x.fillRect(0, 170, SW2, 3)
	# home comes into view on the right as the scene goes on
	var hx = 420 - minf(1, t / 5) * 120
	x.fillStyle = "#1a1a22"; x.fillRect(hx - 1, 112, 92, 59); x.fillStyle = "#eceef2"; x.fillRect(hx, 113, 90, 57); x.fillStyle = "#3a3a44"; x.fillRect(hx + 14, 88, 64, 25)
	x.fillStyle = rgba(255, 214, 120, 0.85); x.fillRect(hx + 8, 126, 30, 26); x.fillRect(hx + 22, 94, 34, 14); x.fillStyle = "#2a3040"; x.fillRect(hx + 50, 136, 12, 34); x.fillStyle = "#b88aff"; x.fillRect(hx, 112, 90, 1)
	# Jojo, sprinting
	if frames and frames.tex:
		var f: int = frames.fs[int(floor(t * 10)) % 4]
		x.drawFrame(frames.tex, frames.n, f, 120 - RX * 0.95, 172 - GROUND * 0.95, SW * 0.95, SH * 0.95)
	for i in 4:
		var k = fmod(t * 3 + i * 0.25, 1.0)
		x.fillStyle = rgba(200, 180, 140, 0.6 * (1 - k)); x.fillRect(110 - k * 30, 168 - k * 4, 3, 2)   # dust kicked up behind


# ------------------------------------------------------------------ the driver

func playIntro(cls: String, done: Callable) -> void:
	var story: Dictionary = STORY[cls]
	var fallen = null
	if story.kin == "defeat" or story.kin == "capsule":   # the hero lying down: the last frame of "down"
		var look = _ilook(cls)
		var n = int(Assets.hero_anim(look, "down").frames)
		fallen = {"tex": Assets.hero_strip(look, "down", 1), "n": n, "f": n - 1}
	var first = "defeat" if story.kin == "defeat" else ("capsule" if story.kin == "capsule" else "captive")
	var scenes = [{"text": story.line, "title": false, "kind": first}]
	if story.has("line2"):
		scenes.append({"text": story.line2, "title": false, "kind": "memory"})
	if story.has("line3"):
		scenes.append({"text": story.line3, "title": false, "kind": "rush"})
	scenes.append({"text": "The Abyss Volcano", "title": true, "kind": "volcano"})
	intro = {"cls": cls, "kin": story.kin, "scenes": scenes, "i": 0, "shown": 0, "t": 0.0, "done": done,
		"fallen": fallen, "run": heroRunFrames(cls) if story.has("line3") else null, "btn": "Next"}
	Sfx.music("hollow"); Sfx.tone(110, 2, "sine", 0.08, 70); Sfx.tone(165, 2, "triangle", 0.04, 140)


func introNext() -> void:
	if intro == null:
		return
	var S: Dictionary = intro.scenes[intro.i]
	if not S.title and intro.shown < S.text.length():
		intro.shown = S.text.length()
		return
	if intro.i < intro.scenes.size() - 1:
		intro.i += 1; intro.shown = 0; intro.t = 0.0
		if intro.scenes[intro.i].title:
			intro.btn = "Begin"; Sfx.tone(80, 1.6, "sawtooth", 0.08, 50)
		else:
			Sfx.tone(300, 0.6, "sine", 0.06, 120)
		return
	_introFinish()


func introSkip() -> void:
	_introFinish()


func _introFinish() -> void:
	if intro == null:
		return
	var done: Callable = intro.done
	intro = null
	introBtns = {}
	if done.is_valid():
		done.call()


func updateIntro(dt: float) -> void:
	if intro == null:
		return
	intro.t += dt
	var S: Dictionary = intro.scenes[intro.i]
	intro.shown = mini(S.text.length(), maxi(intro.shown, int(floor(intro.t * 34))))


func renderIntro(ci: CanvasItem) -> void:
	if intro == null:
		return
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ci.draw_rect(Rect2(0, 0, 768, 432), Color("#05020a"))
	var S: Dictionary = intro.scenes[intro.i]
	var t: float = intro.t
	var x = ctx
	x.begin(ci, Transform2D.IDENTITY.scaled(Vector2(2, 2)))
	match S.kind:
		"defeat": drawDefeatScene(x, t, intro.fallen)
		"capsule": drawCapsuleScene(x, t, intro.fallen)
		"captive": drawCaptiveScene(x, t, intro.kin)
		"memory": drawMemoryScene(x, t)
		"rush": drawRushHomeScene(x, t, intro.run)
		"volcano": drawVolcanoScene(x, t, intro.cls)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_drawIntroBox(ci, S)


## the text box (.itext): bottom 4%, 86% wide, a dark violet panel with the story line and two buttons
func _drawIntroBox(ci: CanvasItem, S: Dictionary) -> void:
	var rid = ci.get_canvas_item()
	var W = 768.0 * 0.86
	var padX = 14.0
	var padY = 10.0
	var tw = W - padX * 2
	var uf: Font = Assets.ui_font
	var pf: Font = Assets.font
	var textH = 0.0
	if S.title:
		textH = pf.get_height(10) + 8
	else:   # size the box for the whole line so it doesn't grow while typing
		textH = maxf(uf.get_multiline_string_size(S.text, HORIZONTAL_ALIGNMENT_LEFT, tw, 11).y, uf.get_height(11) * 3)
	var btnH = 22.0
	var H = padY * 2 + textH + 6 + btnH
	var box = Rect2((768.0 - W) / 2, 432.0 - 432.0 * 0.04 - H, W, H)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(10 / 255.0, 4 / 255.0, 20 / 255.0, 0.82)
	sb.border_color = Color("#7a3aa0")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(160 / 255.0, 60 / 255.0, 200 / 255.0, 0.35)
	sb.shadow_size = 10
	sb.draw(rid, box)
	var tx = box.position.x + padX
	var ty = box.position.y + padY
	if S.title:
		var tc = Color("#ffb8f0")
		var base_y = ty + 4 + pf.get_ascent(10)
		pf.draw_string(rid, Vector2(tx, base_y), S.text, HORIZONTAL_ALIGNMENT_CENTER, tw, 10, Color(1, 58 / 255.0, 216 / 255.0, 0.35))   # a soft halo pass
		pf.draw_string(rid, Vector2(tx, base_y), S.text, HORIZONTAL_ALIGNMENT_CENTER, tw, 10, tc)
	else:
		var shown: String = S.text.substr(0, intro.shown)
		uf.draw_multiline_string(rid, Vector2(tx, ty + uf.get_ascent(11)), shown, HORIZONTAL_ALIGNMENT_LEFT, tw, 11, -1, Color("#f4e8ff"))
	# buttons, right-aligned: Skip, then Next / Begin
	var by = box.end.y - padY - btnH
	var nextLabel: String = intro.btn
	var nw = uf.get_string_size(nextLabel, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 24
	var sw = uf.get_string_size("Skip", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 24
	var nextR = Rect2(box.end.x - padX - nw, by, nw, btnH)
	var skipR = Rect2(nextR.position.x - 8 - sw, by, sw, btnH)
	_introBtn(ci, skipR, "Skip", Color(0, 0, 0, 0), Color("#4a3060"), Color("#c8b0e0"))
	_introBtn(ci, nextR, nextLabel, Color("#ff9ef0"), Color("#1a0828"), Color("#1a0828"))
	introBtns = {"skip": skipR, "next": nextR}


func _introBtn(ci: CanvasItem, r: Rect2, label: String, bg: Color, border: Color, fg: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.draw(ci.get_canvas_item(), r)
	var uf: Font = Assets.ui_font
	var y = r.position.y + (r.size.y - uf.get_height(11)) / 2 + uf.get_ascent(11)
	uf.draw_string(ci.get_canvas_item(), Vector2(r.position.x, y), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, fg)
