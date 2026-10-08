extends "res://scripts/abyss.gd"
## Sproutvale, part 7: drawing the world, in the same order as the prototype's render().
## Everything is in world units on a 384×216 view; the layers it draws into are scaled 2×.
## `x` is a Canvas2D stand-in (ctx.gd), so the drawing code reads like the original.

const RX := 40.0       # hero sprite: hips/feet anchor inside the 84×76 frame (world units)
const GROUND := 66.0
const SW := 84.0
const SH := 76.0
const SLW := 44.0      # a slime-sized monster frame
const SLH := 36.0
const BW := 220.0      # Doc Croc's frame, and where his feet are in it
const BH := 150.0
const BOX := 84.0
const BOY := 144.0
const HP := 0.5        # one screen pixel, in world units
const WIND_V := [-1.2, 0.0, 1.2, 2.4, 3.6]
const FONT := '8px "Press Start 2P", monospace'
const F6 := '6px "Press Start 2P", monospace'
const F5 := '5px "Press Start 2P", monospace'
const GRASS := {
	"meadow": ["#3f8f2e", "#5ab43c", "#7fd35a", "#b4ef86"], "ridge": ["#8a6a24", "#b88a30", "#dab050", "#f2d27a"],
	"hollow": ["#2b5e3a", "#3f7e4c", "#5ea36a", "#8fd08c"], "lair": ["#2b5e3a", "#3f7e4c", "#5ea36a", "#8fd08c"],
	"interior": ["#6e4428", "#8e5c36", "#b07a4a", "#d8a870"], "crimson": ["#4a0e14", "#6e1820", "#922830", "#c04048"],
}
const FLOAT_COL := {"poison": "#8fff6a", "dmg": "#ffb03a", "crit": "#ff5d73", "hurt": "#c79bff", "coin": "#ffe14d", "exp": "#8ff0a4", "goo": "#9fe6ff", "call": "#ffffff"}

var ctx := Ctx.new()
var _rdt := 0.016
var lastCamX := 0.0
var clouds := []
var wclouds := []
var rainDrops := []
var snowFlakes := []
var leaves := []
var LIFE := {"flies": [], "birds": [], "birdT": 4.0, "bugs": []}
var DRAGON := {"on": false, "next": 20.0, "t": 0.0, "dir": 1, "y": 40.0, "s": 1.0}


func initRender() -> void:
	for i in 9:
		clouds.append({"x": hsh(i + 90) * VW * 1.6, "y": 10 + hsh(i + 91) * 60, "w": 24 + hsh(i + 92) * 40, "k": hsh(i + 93)})
	for i in 22:
		wclouds.append({"x": hsh(i + 300) * (VW + 160) - 80, "y": 4 + hsh(i + 301) * 70, "r": 22 + hsh(i + 302) * 26, "k": hsh(i + 303), "flash": 0.0})
	for i in 220:
		rainDrops.append({"x": randf() * VW, "y": randf() * VH, "s": rand(0.8, 1.2)})
	for i in 160:
		snowFlakes.append({"x": randf() * VW, "y": randf() * VH, "s": rand(0.5, 1.2), "p": randf() * 6})
	var leafCols = ["#6cc25a", "#9be07c", "#ec8fb0"]
	for i in 22:
		leaves.append({"x": randf() * VW, "y": randf() * VH, "p": randf() * 6, "c": leafCols[rint(0, 2)]})
	var flyCols = ["#ffd23a", "#ffffff", "#9fc9ff", "#ff9ecf"]
	for i in 7:
		LIFE.flies.append({"x": rand(0, 1600), "y": 0.0, "p": randf() * 6, "c": flyCols[i % 4], "vx": rand(-12, 12)})
	for i in 26:
		LIFE.bugs.append({"x": randf(), "y": randf(), "p": randf() * 6})


static func mixc(a, b, t: float) -> Color:
	return css(a).lerp(css(b), clampf(t, 0, 1))


func textOutline(x: Ctx, s: String, X: float, Y: float, fill, out = "#1a1030") -> void:
	x.fillStyle = out
	for d in [[-1, 0], [1, 0], [0, -1], [0, 1], [1, 1]]:
		x.fillText(s, X + d[0], Y + d[1])
	x.fillStyle = fill
	x.fillText(s, X, Y)


func heroLook() -> String:
	var c: Dictionary = save.chars.get(classId, {})
	var g: String = c.get("look", {}).get("gender", "m")
	return "%s_%s" % [classId, g]


func tailOn() -> bool:
	return Assets.hero.looks.get(heroLook(), {}).has("tail")


# ================================================================ the world

func renderWorld(ci: CanvasItem, dt: float) -> void:
	_rdt = dt
	var x = ctx
	x.begin(ci)
	var D = dayInfo()
	var sx = roundf(cam.x + (rand(-shake, shake) if shake > 0.2 else 0.0))
	var sy = roundf(cam.y + (rand(-shake, shake) if shake > 0.2 else 0.0))
	var theme: String = M.get("theme", "meadow")
	var crimson = theme == "crimson"
	var noSky = crimson or theme == "abyss" or theme == "bubble"
	if theme == "abyss" or theme == "bubble":
		drawAbyssBack(x, sx, sy, dt)
	else:
		if crimson:
			drawCrimsonSky(x)
		else:
			drawSky(x, D)
			drawClouds(x, D, dt)
			drawDragon(x, D, dt)
			drawWeatherClouds(x, D, dt)
		# parallax
		var floorScr: float = M.floorY - sy
		var farY = roundf(floorScr * 0.35 + VH * 0.42 - 120)
		var midY = roundf(floorScr * 0.6 + VH * 0.4 - 90)
		var fo = -fmod(roundf(sx * 0.15), VW * 2.0)
		var mo = -fmod(roundf(sx * 0.4), VW * 2.0)
		var skyTheme = "hollow" if theme == "lair" else ("meadow" if theme == "interior" else theme)
		var far = Assets.tex("sky/%s_far.png" % skyTheme)
		var mid = Assets.tex("sky/%s_mid.png" % skyTheme)
		if far != null:
			x.globalAlpha = 0.9
			x.drawImage(far, fo, farY, far.get_width() / 2.0, far.get_height() / 2.0)
			x.drawImage(far, fo + VW * 2, farY, far.get_width() / 2.0, far.get_height() / 2.0)
			x.globalAlpha = 1
		if mid != null:
			x.drawImage(mid, mo, midY, mid.get_width() / 2.0, mid.get_height() / 2.0)
			x.drawImage(mid, mo + VW * 2, midY, mid.get_width() / 2.0, mid.get_height() / 2.0)
		if midY + 90 < VH:
			x.fillStyle = "#1e060c" if crimson else ("#2f4a3c" if theme in ["hollow", "lair"] else ("#b89448" if theme == "ridge" else "#6fb86a"))
			x.fillRect(0, midY + 90, VW, VH)
	# terrain
	var mt = Assets.tex(mapArt())
	if mt != null:
		drawTerrain(x, mt, sx, sy)
	# snow caps
	if World.snowCover > 0.05 and not (theme in ["abyss", "bubble"]):
		var h = ceilf(World.snowCover * 3)
		x.fillStyle = "#f4f8ff"
		for s in surfaces:
			if s.x1 < sx or s.x0 > sx + VW:
				continue
			x.fillRect(roundf(s.x0 - sx), roundf(s.y - sy - h + 1), roundf(s.x1 - s.x0), h)
	# footprints in snow slowly fill back in
	for i in range(footprints.size() - 1, -1, -1):
		var fp: Dictionary = footprints[i]
		fp.t += dt * (1.6 if World.snow > 0.3 else 1.0)
		if fp.t > 25 or World.snowCover < 0.3:
			footprints.remove_at(i)
			continue
		x.fillStyle = rgba(150, 170, 205, 0.7 * (1 - fp.t / 25))
		x.fillRect(fp.x - sx - 1, fp.y - sy - 1, 3, 1)
	# raindrops splashing on every surface in view
	if World.rain > 0.3 and not M.get("indoor") and not (theme in ["abyss", "bubble"]):
		x.fillStyle = rgba(200, 225, 255, 0.8)
		for i in int(World.rain * 4):
			var s: Dictionary = surfaces[rint(0, surfaces.size() - 1)]
			var X = rand(maxf(s.x0, sx), minf(s.x1, sx + VW))
			if X > s.x0 and s.y - sy > 0 and s.y - sy < VH:
				x.fillRect(roundf(X - sx) - 1, roundf(s.y - sy) - 2, 1, 1)
				x.fillRect(roundf(X - sx) + 1, roundf(s.y - sy) - 2, 1, 1)
	# grass tufts sway in the wind
	var tt = realTime
	var gr: Array = GRASS.get(theme, GRASS.meadow)
	for g in tufts:
		if g.fg:
			continue
		var X: float = g.x - sx
		var Y: float = g.y - sy
		if X < -2 or X > VW + 2 or Y < -4 or Y > VH + 4:
			continue
		var pushed = 2.0 * (sgn(g.x - P.x) if g.x != P.x else 1.0) if absf(g.x - P.x) < 7 and absf(g.y - P.y) < 2 else 0.0
		var lean = roundf(sin(tt * (1.6 + World.wind) + g.p) * (0.4 + World.wind) - World.wind * 0.8) + pushed
		x.fillStyle = "#eef4ff" if World.snowCover > 0.5 else gr[2]
		x.fillRect(X, Y - 1, 1, 1)
		x.fillRect(X + sgn(lean), Y - 2, 1, 1)
		if g.h > 2:
			x.fillRect(X + lean, Y - g.h, 1, 1)
	drawObelisk(x, sx, sy)
	if M.get("slots"):
		drawHouse(x, sx, sy)
	if M.get("notes") or thought != null:
		drawNotes(x, sx, sy)
	if M.get("trophy"):
		drawTrophyStand(x, sx, sy)
	# portals
	for p in M.portals:
		var X: float = p.x - sx
		var Y: float = p.get("y", M.floorY) - sy
		x.font = FONT
		x.textAlign = "center"
		x.textBaseline = "alphabetic"
		if p.get("door"):
			if absf(P.x - p.x) < 30 and absf(P.y - p.get("y", M.floorY)) < 20:
				textOutline(x, "↑ " + p.label, roundf(clampf(X, 70, VW - 70)), roundf(Y - 42), "#ffffff")
			continue
		var sealed: bool = p.get("sealed", false)
		for i in 18:
			var a = tt * (1.2 if sealed else 3.0) + i / 18.0 * TAU
			var r = 8 + sin(tt * 4 + i) * 1.5
			if sealed:
				x.fillStyle = "#b88aff" if i % 3 else "#f0e6ff"
			else:
				x.fillStyle = "#9fe6ff" if i % 3 else "#ffffff"
			x.fillRect(roundf(X + cos(a) * r * 0.6), roundf(Y - 16 + sin(a) * r), 2, 2)
		x.fillStyle = rgba(184, 138, 255, 0.35) if sealed else rgba(160, 230, 255, 0.35)
		x.fillRect(X - 4, Y - 26, 8, 20)
		if absf(P.x - p.x) < 40:
			var hw = x.measureText("↑ " + p.label).width / 2 + 4
			textOutline(x, "↑ " + p.label, roundf(clampf(X, hw, VW - hw)), roundf(Y - 34), "#ffffff")
	# drops
	var coin = Assets.tex("items/coin.png")
	for d in drops:
		var X = roundf(d.x - sx)
		var Y = roundf(d.y - sy)
		match d.kind:
			"coin":
				var f = int(fmod(tt * 8 + d.spin, 4))
				x.drawFrame(coin, 4, f, X - 4, Y - 9 + (roundf(sin(tt * 4 + d.spin)) if d.vy == 0 else 0.0), 9, 9)
			"card":
				# a small glowing card that bobs in place
				var bob = roundf(sin(tt * 3) * 2) if d.vy == 0 else 0.0
				var gl = 0.5 + 0.5 * sin(tt * 6)
				x.fillStyle = rgba(255, 220, 80, 0.35 * gl) if d.gold else rgba(160, 230, 255, 0.35 * gl)
				x.fillRect(X - 8, Y - 20 + bob, 16, 18)
				cardArt(x, d.type, d.gold, d.shiny, true, X - 6, Y - 18 + bob)
			"box":
				drawBossBox(x, d.type, X, Y + (roundf(sin(tt * 3) * 1.5) - 1 if d.vy == 0 else 0.0), tt)
			"key":
				drawKeyDrop(x, X, Y, tt)
			"abyss":
				var gl = 0.5 + 0.5 * sin(tt * 5 + d.x)
				x.fillStyle = rgba(255, 58, 216, 0.3 * gl)
				x.fillRect(X - 6, Y - 11, 12, 12)
				x.drawImage(Assets.tex("items/abyss_coin.png"), X - 4, Y - 9, 9, 9)
			_:
				x.drawImage(Assets.tex("items/residue_%s.png" % d.type), X - 4, Y - 9, 9, 9)
	# monsters
	x.font = FONT
	x.textAlign = "center"
	for e in slimes:
		drawMob(x, e, sx, sy)
	# the hero
	drawPlayer(x, sx, sy, dt)
	# pond water drawn over whatever is submerged
	if M.get("pond") and Water.cols.size():
		drawWater(x, M.pond, sx, sy, tt)
	if theme == "abyss" or theme == "bubble":
		drawAbyssFront(x, sx, sy, dt)
	# tall grass in front of everyone, for depth
	for g in tufts:
		if not g.fg:
			continue
		var X: float = g.x - sx
		var Y: float = g.y - sy
		if X < -2 or X > VW + 2 or Y < -8 or Y > VH + 8:
			continue
		var pushed = 2.0 * (sgn(g.x - P.x) if g.x != P.x else 1.0) if absf(g.x - P.x) < 8 and absf(g.y - P.y) < 3 else 0.0
		var lean: float = sin(tt * (1.6 + World.wind) + g.p) * (0.5 + World.wind) - World.wind + pushed
		x.fillStyle = "#e4ecf8" if World.snowCover > 0.5 else gr[1]
		var k = 0.0
		while k < g.h:
			x.fillRect(roundf((X + lean * k / g.h) * RES) / RES, Y - k - HP, HP, HP)
			k += HP
		x.fillStyle = "#ffffff" if World.snowCover > 0.5 else gr[3]
		x.fillRect(roundf(X + lean), Y - g.h, 1, 1)
	if not M.get("indoor") and not noSky:
		drawAmbientLife(x, sx, sy, D, dt)
	if M.get("trophy"):
		drawTrophies(x, sx, sy)
	drawFX(x, sx, sy)
	drawArrows(x, sx, sy)
	drawSpirit(x, sx, sy)
	drawElemSpirit(x, sx, sy)
	if bossRocks.size():
		drawRocks(x, sx, sy)
	if M.get("boss") == "warlord":
		drawCrimsonRain(x, sx, sy)
	if M.get("pedestal"):
		drawPedestal(x, sx, sy)
	if bossVials.size() or puddles.size():
		drawVials(x, sx, sy)
	if pVials.size() or pPuddles.size() or PRain.t > 0:
		drawBossSkills(x, sx, sy)
	# particles
	for p in parts:
		var k: float = 1 - p.t / p.life
		x.globalAlpha = minf(1, k * 1.5)
		x.fillStyle = p.col
		x.fillRect(roundf(p.x - sx), roundf(p.y - sy), p.sz, p.sz)
	x.globalAlpha = 1
	drawPops(x, sx, sy)
	# floating numbers
	x.font = FONT
	x.textAlign = "center"
	for f in floaters:
		var X = roundf(f.x - sx)
		var Y = roundf(f.y - sy)
		var k: float = f.t / f.life
		x.globalAlpha = 1 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
		var col: String = FLOAT_COL.get(f.kind, "#ffffff")
		if f.kind == "crit":
			x.font = '10px "Press Start 2P", monospace'
			textOutline(x, f.text, X, Y, col)
			x.font = FONT
		else:
			textOutline(x, f.text, X, Y, col)
	x.globalAlpha = 1
	# weather
	if not M.get("indoor") and not noSky:
		drawWeather(x, dt, sx - lastCamX)
	lastCamX = sx


## multiplied over the world: night turns everything moonlit blue, heavy cloud greys it
func renderTint(ci: CanvasItem) -> void:
	var x = ctx
	x.begin(ci)
	if not M.is_empty() and M.get("theme") in ["abyss", "bubble"]:
		abyssTint(x)
		return
	if M.is_empty() or M.get("indoor") or M.get("theme") == "crimson":
		return
	var D = dayInfo()
	var night: float = 1 - D.day
	if night <= 0.02 and World.cloud <= 0.4:
		return
	x.fillStyle = mixc("#ffffff", "#5a6cb8", night * 0.62)   # a clear, moonlit blue rather than a murky fog
	x.fillRect(0, 0, VW, VH)
	if World.cloud > 0.4:
		x.fillStyle = mixc("#ffffff", "#b4bccb", (World.cloud - 0.4) * 0.45 * (1 - night * 0.6))
		x.fillRect(0, 0, VW, VH)


func renderOverlay(ci: CanvasItem) -> void:
	var x = ctx
	x.begin(ci)
	if not M.is_empty():
		var D = dayInfo()
		var night: float = 1 - D.day
		var outdoors: bool = not M.get("indoor") and not (M.get("theme") in ["crimson", "abyss", "bubble"])
		if outdoors and night > 0.3:
			var lx = roundf(P.x - cam.x)
			var ly = roundf(P.y - cam.y - 20)
			var g = x.createRadialGradient(lx, ly, 4, lx, ly, 56)
			g.addColorStop(0, rgba(255, 220, 150, (night - 0.3) * 0.28))
			g.addColorStop(1, rgba(255, 220, 150, 0))
			x.fillStyle = g
			x.beginPath()
			x.arc(lx, ly, 56, 0, TAU)
			x.fill()
		if outdoors and D.dusk > 0.1:
			x.fillStyle = rgba(255, 140, 80, D.dusk * 0.12)
			x.fillRect(0, 0, VW, VH)
		if World.flash > 0:
			x.fillStyle = rgba(255, 255, 255, World.flash * 0.6)
			x.fillRect(0, 0, VW, VH)
		abyssOverlay(x)
	if fade > 0:
		x.fillStyle = rgba(10, 12, 30, fade)
		x.fillRect(0, 0, VW, VH)


# ================================================================ monsters

func _mobSet(e) -> String:
	if e.type == "abyss":
		return "abyss"
	return e.type + ("_elite" if e.elite else ("_shiny" if e.shiny else ""))


func _key(Sset: Dictionary, k: String) -> String:
	return k if Sset.get("keys", {}).has(k) else "idle"


func drawMob(x: Ctx, e, sx: float, sy: float) -> void:
	if e.bossPart:
		return   # the Dreamer's eyes, mouth and tentacles are drawn with the Dreamer
	var T: Dictionary = e.T
	if T.get("habitat"):
		drawAbyssMob(x, e, sx, sy)
		return
	var X = roundf(e.x - sx)
	var Y = roundf(e.y - sy) + (10.0 if T.get("fly") else 0.0)   # flyers' sprites centre on their body
	if X < -30 or X > VW + 30:
		return
	if e.boss:
		drawBoss(x, e, X, Y)
		return
	var setName = _mobSet(e)
	var Sset = Assets.mob_set(setName)
	var critter: bool = T.get("critter", false)
	if e.elite and e.state != "dead" and randf() < 0.5:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h), 0, -20, 0.6, "#2a0838" if randf() < 0.5 else "#9a3ad8", 0, 2)
	if e.shiny and e.state != "dead" and randf() < 0.25:
		part(e.x + rand(-e.w / 2, e.w / 2), e.y - rand(0, e.h + 6), 0, -14, 0.5, ["#ffffff", "#fff6b0", "#ff9ecf"][rint(0, 2)], 0, 1)
	var k = "idle"
	var f = 0
	var n = func(key: String) -> int: return maxi(1, Assets.mob_frames(setName, key))
	if e.state == "dead":
		k = "dead"
	elif e.flash > 0:
		k = "white"
	elif e.state == "hurt":
		k = "hurt"
	elif e.state == "wind":
		k = "wind"
	elif e.state == "shell":
		k = "shell"
	elif e.state == "spin":
		k = "spin"; f = int(e.t * 18) % 4
	elif e.state == "charge":
		k = "run"; f = int(e.t * 22) % 4
	elif T.get("ai") and e.state == "act":
		match e.move:
			"roller":
				k = "spin"; f = int(e.t * 18) % 4
			"swing", "cleave":
				if Sset.keys.has("swing"):
					k = "swing"
					f = mini(n.call("swing") - 1, int(e.t / (0.6 if e.move == "cleave" else 0.4) * n.call("swing")))
				else:
					k = "lunge"
			"bash":
				k = "bash" if Sset.keys.has("bash") else "lunge"
			"leap":
				k = ("hop" if e.vy < 0 else "slam") if Sset.keys.has("slam") else "lunge"
			_:
				k = "lunge"
	elif e.state == "grab":
		k = "lunge"
	elif T.get("ai") and (e.state == "chase" or e.state == "idle") and not T.get("fly") and absf(e.vx) > 5:
		k = "run"; f = int(e.t * 8) % 4
	elif e.y < e.surf.y - 1 and not (critter and e.state == "lunge"):
		k = "hopA" if e.aggro else "hop"
	elif e.sq > 0.2:
		k = "land"
	elif critter and e.state == "lunge":
		k = "lunge"
	elif critter and absf(e.vx) > 8:
		k = "run"; f = int(e.t * 14) % 4
	else:
		k = "angry" if e.aggro else "idle"; f = int(e.t * 2.5) % 2
	k = _key(Sset, k)
	var nf: int = n.call(k)
	x.save()
	x.translate(X, Y)
	if e.state == "dead":
		var kk = maxf(0, 1 - e.deadT / 0.45)
		x.globalAlpha = kk
		x.scale(1 + (1 - kk) * 0.6, maxf(0.001, kk))
	if e.state == "wind":
		x.translate(roundf(sin(e.t * 60)), 0)
	if e.spawnT > 0:
		var kk = maxf(0.001, 1 - e.spawnT / 0.5)
		x.scale(kk, kk)
	if e.face < 0:
		x.scale(-1, 1)
	if e.elite:
		x.scale(3, 3)
	var dim = Sset.get("dim")
	var tex = Assets.mob_strip(setName, k)
	if dim != null:
		x.drawFrame(tex, nf, f % nf, -dim.ax, -dim.ay, dim.w, dim.h)
	else:
		x.drawFrame(tex, nf, f % nf, -22, -33, SLW, SLH)
	x.restore()
	if e.state != "dead" and (e.showBar > 0 or e.aggro):
		var bw = 22.0
		var bx = X - bw / 2
		var by: float = Y - e.h - 12
		x.fillStyle = "#1a1030"; x.fillRect(bx - 1, by - 1, bw + 2, 4)
		x.fillStyle = "#5b2335"; x.fillRect(bx, by, bw, 2)
		x.fillStyle = "#ff5d73"; x.fillRect(bx, by, maxf(0, roundf(bw * e.hp / e.maxHp)), 2)
		var dl: int = e.lv - CH().level
		x.font = FONT
		textOutline(x, "Lv %d" % e.lv, X, by - 3, "#ff8a9a" if dl >= 3 else ("#b8c0d0" if dl <= -3 else "#ffffff"))
	if e.bang > 0 and e.state != "dead":
		textOutline(x, "!", X, Y - e.h - 16, "#ffd23a")
	if e.shiny and e.state != "dead":
		textOutline(x, "*", X + e.w / 2 + 4, Y - e.h - 8, "#fff6b0")
	if e.elite and e.state != "dead":
		x.font = FONT
		textOutline(x, "ELITE %s" % T.name, X, Y - e.h - 26, "#e8b8ff")


func drawBoss(x: Ctx, e, X: float, Y: float) -> void:
	if e.bossKind == "dreamer":
		return   # drawn behind the floor (drawDreamerHead) and in front of it (drawDreamerTents)
	if e.bossKind == "warlord":
		drawWarlord(x, e, X, Y)
		return
	var k = "quad"
	var f = 0
	var sp = 1.35 if e.enraged else 1.0
	var wf = int(e.walkT * 6) % 4
	x.save()
	x.translate(X, Y)
	if e.state == "dead":
		k = "dead"
	else:
		match e.act:
			"roar": k = "roar"
			"rise":
				k = "rise"; f = 0 if e.t < 0.28 else 1
			"drop":
				k = "rise"; f = 1 if e.t < 0.25 else 0
			"bite": k = "biteWind" if e.t < 0.55 / sp else "bite"
			"swipe": k = "swipeWind" if e.t < 0.5 / sp else "swipe"
			"stomp": k = "stompWind" if e.t < 0.7 / sp else "stomp"
			"vial":
				k = "vialHold" if e.t < 0.6 / sp else ("vialMix" if e.t < 1.45 / sp else "vialThrow")
				if e.t > 0.6 / sp and e.t < 1.45 / sp:
					x.translate(roundf(sin(e.t * 40) * 0.6), 0)
			_:
				if e.mode == "stand":
					k = "stand"; f = int(e.walkT * 3) % 2
				else:
					k = "quadA" if e.enraged else "quad"; f = wf
	if e.hurtFlash > 0 and e.state != "dead":
		k = "whiteStand" if e.mode == "stand" or e.act in ["rise", "swipe", "stomp", "drop", "vial"] else "white"
		f = 0
	if e.state == "dead":
		x.globalAlpha = maxf(0, 1 - e.deadT / 2.4)
	if (e.act == "bite" and e.t < 0.55) or (e.act == "swipe" and e.t < 0.5) or (e.act == "stomp" and e.t < 0.7):
		x.translate(roundf(sin(e.t * 50)), 0)   # wind-up tremble = telegraph
	if e.face < 0:
		x.scale(-1, 1)
	var nf = maxi(1, Assets.mob_frames("croc", k))
	x.drawFrame(Assets.mob_strip("croc", k), nf, f % nf, -BOX, -BOY, BW, BH)
	x.restore()
	if e.enraged and e.state != "dead" and randf() < 0.3:
		part(e.x + rand(-40, 40), e.y - rand(20, 90), 0, -30, 0.5, "#ff5d73", 0, 1)


func drawWarlord(x: Ctx, e, X: float, Y: float) -> void:
	var setName = "warlord_gs" if e.mode == "gs" else ("warlord_un" if e.mode == "un" else "warlord_ss")
	var k = "idle"
	var f = 0
	var eyeless: bool = e.eyesOut > 0
	if e.state == "dead":
		k = ("hurt" if e.t < 0.6 else "slam") if e.dying else "dead"
	else:
		match e.act:
			"swing", "cleave":
				var tot = (1.1 if e.act == "cleave" else 0.75) / WSPD
				var ns = Assets.mob_frames(setName, "swing")
				k = "swing"; f = mini(ns - 1, int(e.t / tot * ns))
			"bash": k = "wind" if e.t < 0.28 / WSPD else "bash"
			"leap", "introJump": k = "hop" if e.y < M.floorY - 2 else "slam"
			"laugh", "rain": k = "wind"
			"throw": k = "wind" if e.t < 0.45 / WSPD else "lunge"
			"pickup": k = "slam"
			_:
				if absf(e.vx) > 5:
					k = "run"; f = int(e.walkT * 6) % 4
				else:
					k = "noEyes" if eyeless else "idle"; f = int(e.t * 2) % 2
	if e.hurtFlash > 0 and e.state != "dead":
		k = "white"; f = 0
	x.save()
	x.translate(X, Y)
	if e.state == "dead" and not e.dying:
		x.globalAlpha = maxf(0, 1 - e.deadT / 2.4)
	if e.dying and e.t > 0.6:
		x.translate(roundf(sin(e.t * 23) * 0.6), 0)   # trembling on one knee
	if e.act in ["swing", "cleave", "bash", "throw"] and e.t < 0.4 / WSPD:
		x.translate(roundf(sin(e.t * 50)), 0)
	if e.face < 0:
		x.scale(-1, 1)
	x.scale(3, 3)
	var nf = maxi(1, Assets.mob_frames(setName, k))
	x.drawFrame(Assets.mob_strip(setName, k), nf, f % nf, -RX, -GROUND, SW, SH)
	x.restore()
	if e.act == "laugh" and randf() < 0.3:
		part(e.x + rand(-10, 10), e.y - rand(90, 120), rand(-20, 20), -20, 0.6, "#ffe03a", 0, 1)
	if e.enraged and e.state != "dead" and randf() < 0.4:
		part(e.x + rand(-20, 20), e.y - rand(10, 110), 0, -30, 0.5, "#ff2a3a", 0, 2)
	if thrownSword != null:
		# the greatsword, spinning through the air or stuck point-down in the ground
		var Sw: Dictionary = thrownSword
		var cx: float = (Sw.x if Sw.stuck else Sw.cx) - (e.x - X)
		var cy: float = (M.floorY - 14 if Sw.stuck else Sw.cy) - (e.y - Y)
		x.save()
		x.translate(cx, cy)
		x.rotate(0.15 if Sw.stuck else Sw.spin)
		x.fillStyle = "#14060a"; x.fillRect(-2.5, -26, 5, 40)
		x.fillStyle = "#c8ccd8"; x.fillRect(-1.5, -25, 3, 30)
		x.fillStyle = "#f4f6ff"; x.fillRect(-1.5, -25, 1, 30)
		x.fillStyle = "#2a1418"; x.fillRect(-7, 4, 14, 3); x.fillRect(-1.5, 6, 3, 8)
		x.restore()


# ================================================================ the hero and the pets

func drawPlayer(x: Ctx, sx: float, sy: float, dt: float) -> void:
	var X = roundf(P.x - sx)
	var Y = roundf(P.y - sy)
	var look = heroLook()
	var vIdx = 0
	for i in WIND_V.size():
		if absf(WIND_V[i] - P.windV) < absf(WIND_V[vIdx] - P.windV):
			vIdx = i
	var anim: String = P.anim if Assets.hero.looks.get(look, {}).get("anims", {}).has(P.anim) else "idle"
	var A = Assets.hero_anim(look, anim)
	var nf = maxi(1, int(A.frames))
	var f = clampi(playerFrame(), 0, nf - 1)
	var tex = Assets.hero_strip(look, anim, vIdx)
	var blink: bool = not (P.state in ["dash", "held"]) and P.iframes > 0 and P.iframes < 0.9 and int(gameTime * 18) % 2 == 0
	x.fillStyle = rgba(20, 30, 10, 0.25)
	if P.grounded:
		x.fillRect(X - 8, Y - 1, 16, 2)
	for l in speedLines:
		var a: float = 1 - l.t / l.life
		var lx = roundf(l.x - sx)
		var ly = roundf(l.y - sy)
		x.fillStyle = rgba(255, 255, 255, 0.8 * a)
		x.fillRect(lx - l.len if P.face > 0 else lx, ly, l.len, 1)
		x.fillStyle = rgba(200, 240, 255, 0.35 * a)
		x.fillRect(lx - l.len * 0.6 if P.face > 0 else lx, ly + 1, l.len * 0.6, 1)
	if P.state == "dash":
		for k in range(1, 4):
			x.save()
			x.globalAlpha = 0.25 / k
			x.translate(X - P.face * k * 9, Y)
			if P.face < 0:
				x.scale(-1, 1)
			x.drawFrame(tex, nf, f, -RX, -GROUND, SW, SH)
			x.restore()
	var backView: bool = P.anim == "climb"
	var tail = Assets.hero_tail(look, anim, vIdx, f) if tailOn() else null
	if tail != null:
		updateTail(dt, Vector2(P.x + P.face * (tail[0] - RX), P.y + (tail[1] - GROUND)))
	if tail != null and not backView and not blink:
		x.save(); x.translate(-sx, -sy); drawTail(x, look); x.restore()
	drawPets(x, sx, sy, "back")
	var eaten: bool = P.held != null and P.held.kind == "eaten"
	if not blink and not eaten:
		x.save()
		x.translate(X, Y)
		if P.spin != 0:
			x.translate(0, -20)
			x.rotate(P.spin)
			x.translate(0, 20)
		if P.face < 0:
			x.scale(-1, 1)
		x.drawFrame(tex, nf, f, -RX, -GROUND, SW, SH)
		x.restore()
	drawPets(x, sx, sy, "front")
	if tail != null and backView and not blink:
		x.save(); x.translate(-sx, -sy); drawTail(x, look); x.restore()
	# name tag, classic MMO style
	if eaten:
		return
	x.font = FONT
	x.textAlign = "center"
	x.fillStyle = rgba(20, 20, 40, 0.7)
	x.fillRect(X - 18, Y + 3, 36, 10)
	x.fillStyle = "#ffffff"
	x.fillText(CLASSES[classId].name, X, Y + 11)


func drawTail(x: Ctx, look: String) -> void:
	var pts: Array = Tail.pts
	if pts.size() < 2:
		return
	var H: Dictionary = Assets.hero.looks[look].tail
	var L = []
	var R = []
	for i in pts.size():
		var a: Dictionary = pts[maxi(0, i - 1)]
		var b: Dictionary = pts[mini(pts.size() - 1, i + 1)]
		var dx: float = b.x - a.x
		var dy: float = b.y - a.y
		var d = Vector2(dx, dy).length()
		if d == 0:
			d = 1
		var w = 1.6 if i == 0 else 2.6 * sin(minf(1, (i + 0.6) / pts.size()) * PI * 0.92) + 0.35   # swells, then tapers to a tip
		L.append([pts[i].x - dy / d * w, pts[i].y + dx / d * w])
		R.append([pts[i].x + dy / d * w, pts[i].y - dx / d * w])
	x.save()
	x.lineJoin = "round"
	x.beginPath()
	x.moveTo(L[0][0], L[0][1])
	for p in L.slice(1):
		x.lineTo(p[0], p[1])
	var tip: Dictionary = pts[-1]
	var pre: Dictionary = pts[-2]
	x.lineTo(tip.x + (tip.x - pre.x) * 0.3, tip.y + (tip.y - pre.y) * 0.3)
	var Rr = R.duplicate()
	Rr.reverse()
	for p in Rr:
		x.lineTo(p[0], p[1])
	x.closePath()
	x.strokeStyle = H.get("out", "#3c2814")
	x.lineWidth = 1.1
	x.stroke()
	x.fillStyle = H.hair
	x.fill()
	# a highlight strand down one side and a shadow down the other
	x.lineWidth = 0.5
	x.strokeStyle = H.light
	x.beginPath()
	for i in range(1, pts.size() - 1):
		var q: Array = L[i]
		var mx: float = (pts[i].x + q[0]) / 2
		var my: float = (pts[i].y + q[1]) / 2
		if i > 1: x.lineTo(mx, my)
		else: x.moveTo(mx, my)
	x.stroke()
	x.strokeStyle = H.shade
	x.beginPath()
	for i in range(1, pts.size() - 1):
		var q: Array = R[i]
		var mx: float = pts[i].x * 0.4 + q[0] * 0.6
		var my: float = pts[i].y * 0.4 + q[1] * 0.6
		if i > 1: x.lineTo(mx, my)
		else: x.moveTo(mx, my)
	x.stroke()
	x.restore()


## one pet sprite: frame `f` of `key` in the pet's sheet, anchored at (ax, ay), scaled by sc
func _put(x: Ctx, setName: String, key: String, f: int, X: float, Y: float, face: int, sc: float, ax: float, ay: float, sx: float, sy: float) -> void:
	var Sset = Assets.mob_set(setName)
	if Sset.is_empty():
		return
	var nf = maxi(1, Assets.mob_frames(setName, key))
	x.save()
	x.translate(roundf(X - sx), roundf(Y - sy))
	if face < 0:
		x.scale(-1, 1)
	x.scale(sc, sc)
	x.drawFrame(Assets.mob_strip(setName, key), nf, f % nf, -ax, -ay, Sset.w / 2.0, Sset.h / 2.0)
	x.restore()


func drawPets(x: Ctx, sx: float, sy: float, layer: String) -> void:
	if classId != "summoner" or not Pets.list.has("dragon"):
		return
	var L: Dictionary = Pets.list
	var Dg: Dictionary = L.dragon
	if layer == "back":
		if summonOn("slime"):
			var Sl: Dictionary = L.slime
			if Sl.state == "jump":
				_put(x, "blue", "hopA", 0, Sl.x, Sl.y, Sl.face, 0.8, 22, 33, sx, sy)
			else:
				_put(x, "blue", "idle", int(Sl.t * 2) % 2, Sl.x, Sl.y, Sl.face, 0.8, 22, 33, sx, sy)
		if summonOn("croc"):
			var C: Dictionary = L.croc
			if C.state == "bite":
				_put(x, "pet_croc", "bite", 0, C.x, C.y, C.face, 0.3, BOX, BOY, sx, sy)
			else:
				_put(x, "pet_croc", "walk", int(C.t * 6) % 4, C.x, C.y, C.face, 0.3, BOX, BOY, sx, sy)
		if dragonForm() != "baby":
			drawDragonPet(x, Dg, sx, sy)
	else:
		if dragonForm() == "baby":
			drawDragonPet(x, Dg, sx, sy)
		if summonOn("phoenix"):
			var Ph: Dictionary = L.phoenix
			if Ph.state == "dive":
				_put(x, "pet_phoenix", "dive", 0, Ph.x, Ph.y, Ph.face, 1, 18, 14, sx, sy)
			else:
				_put(x, "pet_phoenix", "fly", int(Ph.t * 10) % 4, Ph.x, Ph.y, Ph.face, 1, 18, 14, sx, sy)
			x.fillStyle = rgba(255, 160, 40, 0.18)
			x.beginPath(); x.arc(Ph.x - sx, Ph.y - sy, 12, 0, TAU); x.fill()
		if summonOn("angel"):
			var A: Dictionary = L.angel
			x.fillStyle = rgba(255, 250, 210, 0.2)
			x.beginPath(); x.arc(A.x - sx, A.y - sy, 14, 0, TAU); x.fill()
			if A.thr > 0:
				_put(x, "pet_angel", "throw", 0, A.x, A.y, A.face, 0.9, 18, 20, sx, sy)
			else:
				_put(x, "pet_angel", "fly", int(A.t * 3) % 2, A.x, A.y, A.face, 0.9, 18, 20, sx, sy)


func drawDragonPet(x: Ctx, Dg: Dictionary, sx: float, sy: float) -> void:
	var form = dragonForm()
	var setName = "pet_baby" if form == "baby" else "pet_adult"
	var k = "fly"
	var f = int(Dg.t * (12 if form == "baby" else 6)) % 4
	if Dg.state == "breath":
		k = "breath"; f = 0
	elif Dg.state == "chomp":
		k = "claw" if Dg.claw else "bite"; f = 0
	elif form == "drake" and Dg.state == "follow":
		k = "walk"; f = int(absf(Dg.x) * 0.15) % 4
	var sc = 0.55 if form == "baby" else (1.45 if form == "drake" else 2.9)
	_put(x, setName, k, f, Dg.x, Dg.y, Dg.face, sc, 30, 36 if form == "baby" else 54, sx, sy)


func drawWater(x: Ctx, W: Dictionary, sx: float, sy: float, tt: float) -> void:
	var c: Array = Water.cols
	var st: float = Water.step
	x.fillStyle = rgba(60, 130, 210, 0.42)
	x.beginPath()
	x.moveTo(W.x0 - sx, W.bottom - sy + 20)
	for i in c.size():
		x.lineTo(W.x0 + i * st - sx, W.surface + c[i] - sy)
	x.lineTo(W.x1 - sx, W.bottom - sy + 20)
	x.closePath()
	x.fill()
	x.fillStyle = rgba(30, 70, 140, 0.25)
	x.fillRect(W.x0 - sx, W.surface + 14 - sy, W.x1 - W.x0, W.bottom - W.surface)
	for i in c.size():
		var X = roundf(W.x0 + i * st - sx)
		var Y = roundf(W.surface + c[i] - sy)
		x.fillStyle = rgba(220, 245, 255, 0.9)
		x.fillRect(X, Y, st, 1)
		if (i + int(tt * 2)) % 9 == 0:
			x.fillStyle = rgba(255, 255, 255, 0.8)
			x.fillRect(X + 1, Y + 3, 2, 1)
	# lily pads riding the surface
	for lx in [0.18, 0.46, 0.63, 0.84]:
		var X: float = W.x0 + (W.x1 - W.x0) * lx
		var i = roundi((X - W.x0) / st)
		var Y = roundf(W.surface + (c[i] if i < c.size() else 0.0) - sy)
		x.fillStyle = "#1f5a2c"; x.fillRect(roundf(X - sx) - 5, Y - 1, 10, 2)
		x.fillStyle = "#4faa4a"; x.fillRect(roundf(X - sx) - 4, Y - 1, 8, 1)
		if lx == 0.46:
			x.fillStyle = "#ffc4dc"; x.fillRect(roundf(X - sx) - 1, Y - 3, 3, 2)


func drawPops(x: Ctx, sx: float, sy: float) -> void:
	x.textAlign = "center"
	var n = POPS.size()
	for i in n:
		var p: Dictionary = POPS[i]
		var a: float = maxf(0, 1 - (p.t - 1.25) / 0.35) if p.t > 1.25 else 1.0
		var X = roundf(P.x - sx)
		var Y = roundf(P.y - sy - 50 - (n - 1 - i) * 10 - (1 - a) * 4)
		x.globalAlpha = a
		x.font = '9px "Press Start 2P", monospace' if p.bump > 0.4 else FONT
		textOutline(x, "+%s %s" % [fmt(roundi(p.shown)), p.label], X, Y, p.col)
	x.globalAlpha = 1


# ================================================================ monster cards

## a monster card: 44×60, or 12×16 when small (drawn live rather than cached)
func cardArt(x: Ctx, type: String, gold: bool, shiny: bool, small: bool, X: float, Y: float, scale_ := 1.0) -> void:
	var w = 12.0 if small else 44.0
	var h = 16.0 if small else 60.0
	x.save()
	x.translate(X, Y)
	x.scale(scale_, scale_)
	x.fillStyle = "#1a1030"; x.fillRect(0, 0, w, h)
	x.fillStyle = "#e2a81e" if gold else ("#c89aff" if shiny else "#9fd4ff"); x.fillRect(1, 1, w - 2, h - 2)
	x.fillStyle = "#fff0a0" if gold else "#f4f8ff"
	var m = 2.0 if small else 3.0
	x.fillRect(m, m, w - m * 2, h - m * 2)
	if type == "croc":
		var t = Assets.mob_strip("croc", "quad")
		if t != null:
			x.drawImageRegion(t, 0, 60 * RES, 220 * RES, 90 * RES, 1 if small else 2, 4 if small else 12, w - (2 if small else 4), 8 if small else 18)
	elif type == "dreamer":
		var t = Assets.tex("boss/dreamer_portrait.png")
		if t != null:
			x.drawImageRegion(t, 30, 0, 160, 170, 1 if small else 2, 1 if small else 4, w - (2 if small else 4), h - (3 if small else 16))
	elif type in ABYSS_MOBS:
		# the Abyss sets: the whole first frame, fitted into the card keeping its shape
		var setName = type + "_shiny" if shiny else type
		var Sset = Assets.mob_set(setName)
		var keys = Sset.get("keys", {})
		if not keys.is_empty():
			var t = Assets.mob_strip(setName, keys.keys()[0])
			if t != null:
				var fw = float(Sset.w)
				var fh = float(Sset.h)
				var bw = w - (2 if small else 6)
				var bh = h - (4 if small else 16)
				var k = minf(bw / fw, bh / fh)
				x.drawImageRegion(t, 0, 0, fw, fh, (w - fw * k) / 2, (2 if small else 3) + (bh - fh * k) / 2, fw * k, fh * k)
	else:
		var setName = "warlord_ss" if type == "warlord" else (type + "_shiny" if shiny and type != "abyss" else type)
		var Sset = Assets.mob_set(setName)
		var t = Assets.mob_strip(setName, "idle")
		if t != null:
			if Sset.get("dim") != null:
				x.drawImageRegion(t, 26 * RES, 14 * RES, 28 * RES, 52 * RES, 3 if small else 8, 1 if small else 4, 6 if small else 28, 13 if small else 50)
			else:
				x.drawImageRegion(t, 10 * RES, 10 * RES, 24 * RES, 24 * RES, 1 if small else 2, 3 if small else 10, 10 if small else 40, 10 if small else 40)
	if not small:
		x.fillStyle = "#8a5a08" if gold else "#27335c"
		x.fillRect(4, h - 10, w - 8, 5)
		if gold or shiny:
			x.fillStyle = "#ffffff"
			x.fillRect(5, 5, 2, 2)
			x.fillRect(w - 8, 6, 1, 1)
	x.restore()


# ================================================================ sky

func drawSky(x: Ctx, D: Dictionary) -> void:
	var g = x.createLinearGradient(0, 0, 0, VH)
	var top = mixc(mixc("#0c1638", "#4aa8ff", D.day), "#6b7fe0", D.dusk * 0.6)
	var hor = mixc(mixc("#26407a", "#c8eeff", D.day), "#ffb88a", D.dusk * 0.8)
	g.addColorStop(0, top)
	g.addColorStop(1, hor)
	x.fillStyle = g
	x.fillRect(0, 0, VW, VH)
	if World.cloud > 0.3:
		x.fillStyle = rgba(110, 120, 140, (World.cloud - 0.3) * 0.45 * (0.3 + D.day * 0.7))
		x.fillRect(0, 0, VW, VH)
	if D.day < 0.7:
		drawNightSky(x, (1 - D.day / 0.7) * maxf(0, 1 - World.cloud * 1.2))
	# sun / moon
	var sx: float = VW / 2.0 + D.sunX * VW * 0.42
	var sy: float = VH * 0.75 - absf(D.sunY) * VH * 0.6
	if World.cloud < 0.9:
		if D.sunY > -0.05:
			x.fillStyle = "#ffb36a" if D.dusk > 0.5 else "#fff4c0"
			x.fillRect(roundf(sx) - 5, roundf(sy) - 5, 10, 10)
			x.fillStyle = rgba(255, 240, 180, 0.25)
			x.fillRect(roundf(sx) - 8, roundf(sy) - 8, 16, 16)
		else:
			var mx = VW - sx
			x.fillStyle = "#eef2ff"; x.fillRect(roundf(mx) - 4, roundf(sy) - 4, 8, 8)
			x.fillStyle = "#c9d2ee"; x.fillRect(roundf(mx) - 1, roundf(sy) - 2, 2, 2)


func drawNightSky(x: Ctx, a: float) -> void:
	if a <= 0.01:
		return
	var t = realTime
	x.globalAlpha = a * 0.9
	x.drawImage(Assets.tex("sky/galaxy.png"), 0, 0, VW, VH)
	x.globalAlpha = 1
	var cols = [Color(1, 1, 1), Color(200 / 255.0, 220 / 255.0, 1), Color(1, 230 / 255.0, 190 / 255.0), Color(1, 200 / 255.0, 230 / 255.0)]
	for i in 160:
		var sx = hsh(i * 1.7) * VW
		var sy = hsh(i * 2.3 + 50) * VH * 0.62
		var tw = 0.5 + 0.5 * sin(t * (0.6 + hsh(i) * 2) + i)
		var bright = i % 23 == 0
		var col: Color = cols[i % 4]
		var sz = 1.0 if i % 5 == 0 else 0.5
		x.fillStyle = Color(col, a * (0.9 if bright else 0.25 + tw * 0.55))
		x.fillRect(roundf(sx * 2) / 2, roundf(sy * 2) / 2, sz, sz)
		if bright:
			var g = a * (0.4 + tw * 0.6)
			x.fillStyle = Color(col, g * 0.7)
			x.fillRect(sx - 2, sy + 0.25, 5, 0.5)
			x.fillRect(sx + 0.25, sy - 2, 0.5, 5)
			x.fillStyle = Color(col, g * 0.25)
			x.fillRect(sx - 1, sy - 1, 3, 3)
	# a ringed planet and a small red one
	var px = VW * 0.78
	var py = 34.0
	x.fillStyle = rgba(255, 220, 170, 0.18 * a); x.beginPath(); x.arc(px, py, 11, 0, TAU); x.fill()
	x.fillStyle = Color("#e8c890", a); x.beginPath(); x.arc(px, py, 7, 0, TAU); x.fill()
	x.fillStyle = Color("#c8a070", a); x.fillRect(px - 7, py - 1, 14, 1.5); x.fillRect(px - 6, py + 2.5, 12, 1)
	x.fillStyle = Color("#fff0d0", a); x.beginPath(); x.arc(px - 2.5, py - 2.5, 2, 0, TAU); x.fill()
	x.strokeStyle = rgba(255, 236, 200, 0.85 * a); x.lineWidth = 1
	x.beginPath(); x.ellipse(px, py, 14, 3.5, -0.35, 0, TAU); x.stroke()
	x.fillStyle = Color("#e8c890", a); x.beginPath(); x.arc(px, py, 7, PI * 1.08, PI * 1.92); x.fill()   # the ring passes behind the top
	x.fillStyle = Color("#c85a4a", a); x.beginPath(); x.arc(VW * 0.18, 22, 3, 0, TAU); x.fill()
	x.fillStyle = Color("#ff8a70", a); x.fillRect(VW * 0.18 - 2, 20, 1.5, 1.5)


## the Crimson Wastes sky: a blood moon over drifting ash
func drawCrimsonSky(x: Ctx) -> void:
	var t = realTime
	var g = x.createLinearGradient(0, 0, 0, VH)
	g.addColorStop(0, "#12020a"); g.addColorStop(0.55, "#4a0812"); g.addColorStop(1, "#8a1a1a")
	x.fillStyle = g
	x.fillRect(0, 0, VW, VH)
	var mx = VW * 0.72
	var my = 46.0
	var gl = x.createRadialGradient(mx, my, 4, mx, my, 60)
	gl.addColorStop(0, rgba(255, 60, 50, 0.55)); gl.addColorStop(1, rgba(255, 40, 40, 0))
	x.fillStyle = gl
	x.beginPath(); x.arc(mx, my, 60, 0, TAU); x.fill()
	x.fillStyle = "#c0282a"; x.beginPath(); x.arc(mx, my, 18, 0, TAU); x.fill()
	x.fillStyle = "#8a1418"; x.beginPath(); x.arc(mx + 5, my + 4, 5, 0, TAU); x.fill()
	x.beginPath(); x.arc(mx - 7, my - 5, 3, 0, TAU); x.fill()
	x.fillStyle = rgba(30, 4, 10, 0.55)
	for i in 6:
		x.beginPath()
		x.ellipse(fmod(hsh(i + 40) * VW + t * (6 + i), VW + 120) - 60, 30 + hsh(i + 41) * 60, 60 + hsh(i) * 40, 10, 0, 0, TAU)
		x.fill()
	for i in 40:
		# falling ash and embers
		var ax = fmod(hsh(i + 90) * VW + t * 10 + sin(t + i) * 6 + VW, VW)
		var ay = fmod(hsh(i + 91) * VH + t * 14, VH)
		x.fillStyle = rgba(80, 40, 40, 0.6) if i % 3 else rgba(255, 120, 90, 0.6)
		x.fillRect(ax, ay, 1, 1)


func drawClouds(x: Ctx, D: Dictionary, dt: float) -> void:
	x.fillStyle = mixc(mixc("#39406a", "#ffffff", D.day), "#8a93a3", World.cloud * 0.6)
	for c in clouds:
		c.x -= dt * (3 + World.wind * 10) * (0.5 + c.k)
		if c.x < -c.w:
			c.x += VW + c.w * 2
		if c.k > 0.25 + World.cloud * 0.75:
			continue
		var i = 0.0
		while i < c.w:
			var h = 4 + roundf(sin(i / c.w * PI) * 6)
			x.fillRect(roundf(c.x + i), roundf(c.y - h), 5, h + 3)
			i += 4


## a dragon glides across the sky now and then
func drawDragon(x: Ctx, D: Dictionary, dt: float) -> void:
	var G = DRAGON
	if not G.on:
		G.next -= dt
		if G.next <= 0 and World.storm < 0.5:
			G.on = true; G.t = 0.0; G.dir = -1 if randf() < 0.5 else 1; G.y = 26 + randf() * 40; G.s = 0.7 + randf() * 0.5; G.next = rand(50, 110)
		return
	G.t += dt
	var k: float = G.t / 16.0
	if k > 1:
		G.on = false
		return
	var X: float = -50 + k * (VW + 100) if G.dir > 0 else VW + 50 - k * (VW + 100)
	var Y: float = G.y + sin(G.t * 1.3) * 6
	var s: float = G.s
	var flap = sin(G.t * 5)
	var body = mixc("#2a2240", "#4a5a8a", D.day)
	var wing = mixc("#1c1630", "#3a4878", D.day)
	x.save()
	x.translate(X, Y)
	x.scale(G.dir * s, s)
	# tail
	x.strokeStyle = body; x.lineWidth = 2.2
	x.beginPath(); x.moveTo(-6, 0); x.quadraticCurveTo(-16, 4 + flap * 2, -26, 1 - flap); x.stroke()
	x.fillStyle = body
	x.beginPath(); x.moveTo(-26, 1 - flap); x.lineTo(-30, -2 - flap); x.lineTo(-29, 3 - flap); x.closePath(); x.fill()
	# far wing, body, near wing
	var wingPath = func(lift: float, dx: float):
		x.beginPath(); x.moveTo(-2 + dx, -1); x.lineTo(4 + dx, -12 - lift * 10); x.lineTo(10 + dx, -14 - lift * 9)
		x.lineTo(8 + dx, -6 - lift * 3); x.lineTo(13 + dx, -9 - lift * 5); x.lineTo(7 + dx, 0); x.closePath(); x.fill()
	x.fillStyle = wing
	wingPath.call(flap * 0.6, 2)
	x.fillStyle = body
	x.beginPath(); x.ellipse(0, 0, 8, 3, 0, 0, TAU); x.fill()
	x.beginPath(); x.moveTo(6, -1); x.quadraticCurveTo(11, -5, 15, -5); x.lineTo(19, -4); x.lineTo(15, -2); x.quadraticCurveTo(11, -1, 7, 2); x.closePath(); x.fill()   # neck + head
	x.fillStyle = "#ffb84a"; x.fillRect(15.5, -4.5, 1, 1)   # a glinting eye
	x.fillStyle = wing
	wingPath.call(flap, -1)
	x.restore()


func drawWeatherClouds(x: Ctx, D: Dictionary, dt: float) -> void:
	var wet = clampf((World.cloud - 0.45) / 0.45, 0, 1)
	if wet <= 0.01:
		return
	var snowy: bool = World.snow > World.rain
	var kind = "snow" if snowy else "rain"
	var light: float = 0.45 + D.day * 0.55
	for c in wclouds:
		c.x -= dt * (4 + World.wind * 14) * (0.6 + c.k * 0.6)
		if c.x < -c.r * 3:
			c.x = VW + c.r
		var spr = Assets.tex("sky/clouds/cloud_%s_%d.png" % [kind, clampi(roundi(c.r), 22, 48)])
		if spr != null:
			x.globalAlpha = wet * (0.95 if snowy else 0.92) * (1.0 if c.k < wet * 1.1 else 0.4)
			x.drawImage(spr, c.x, c.y, spr.get_width() / 2.0, spr.get_height() / 2.0)
			x.globalAlpha = 1
		if c.flash > 0:
			# lightning lighting the cloud from inside
			c.flash -= dt
			var cx: float = c.x + c.r * 1.3
			var cy: float = c.y + c.r * 0.7
			var g = x.createRadialGradient(cx, cy, 2, cx, cy, c.r * 1.3)
			g.addColorStop(0, rgba(255, 240, 200, minf(1, c.flash * 6)))
			g.addColorStop(1, rgba(255, 240, 200, 0))
			x.fillStyle = g
			x.beginPath(); x.arc(cx, cy, c.r * 1.3, 0, TAU); x.fill()
	if not snowy:
		x.fillStyle = rgba(30, 34, 50, wet * 0.16 * light)   # the whole sky dims under rain clouds
		x.fillRect(0, 0, VW, VH)
	if World.storm > 0.5 and randf() < dt * 0.9:
		var c: Dictionary = wclouds[rint(0, wclouds.size() - 1)]
		if c.x > -20 and c.x < VW:
			c.flash = 0.25


func drawWeather(x: Ctx, dt: float, camDx: float) -> void:
	var w: float = World.wind
	x.fillStyle = rgba(200, 220, 255, 0.55)
	for i in int(rainDrops.size() * minf(1, World.rain / 1.2)):
		var r: Dictionary = rainDrops[i]
		r.y += dt * 260 * r.s
		r.x -= dt * (w * 90) + camDx * 0.9
		if r.y > VH:
			r.y -= VH + 10
			r.x = randf() * VW
		r.x = fposmod(r.x, VW)
		x.fillRect(roundf(r.x), roundf(r.y), 1, 4)
	x.fillStyle = "#ffffff"
	for i in int(snowFlakes.size() * minf(1, World.snow)):
		var s: Dictionary = snowFlakes[i]
		s.p += dt
		s.y += dt * 22 * s.s
		s.x += sin(s.p * 1.3) * dt * 8 - dt * w * 30 - camDx * 0.9
		if s.y > VH:
			s.y = -2.0
			s.x = randf() * VW
		s.x = fposmod(s.x, VW)
		var sz = 2.0 if s.s > 1 else 1.0
		x.fillRect(roundf(s.x), roundf(s.y), sz, sz)
	if World.snow < 0.5 and World.rain < 0.5:
		for i in int(leaves.size() * minf(1, 0.3 + w * 0.6)):
			var l: Dictionary = leaves[i]
			l.p += dt * 3
			l.x -= dt * (20 + w * 60) + camDx * 0.9
			l.y += sin(l.p) * dt * 14 + dt * 8
			if l.x < -4:
				l.x = VW + 4.0
				l.y = randf() * VH * 0.7
			if l.y > VH:
				l.y = 0.0
			l.x = fposmod(l.x + VW + 8, VW + 8)
			x.fillStyle = l.c
			x.fillRect(roundf(l.x), roundf(l.y), 2 if sin(l.p) > 0 else 1, 1)
	if World.bolt != null:
		var bx: float = World.bolt.x
		var y = 0.0
		x.fillStyle = rgba(255, 255, 255, 0.9)
		while y < VH * 0.8:
			bx += rand(-3, 3)
			x.fillRect(roundf(bx), y, 2, 4)
			y += 4


## butterflies, birds, fireflies
func drawAmbientLife(x: Ctx, sx: float, sy: float, D: Dictionary, dt: float) -> void:
	var dry: bool = World.rain < 0.3 and World.snow < 0.3
	if D.day > 0.5 and dry:
		# butterflies drift around the player's area
		for b in LIFE.flies:
			b.p += dt * 9
			b.vx = clampf(b.vx + rand(-40, 40) * dt, -18, 18)
			if not b.y or absf(b.x - P.x) > 260:
				b.x = P.x + rand(-180, 180)
				b.y = M.floorY - rand(12, 60)
			b.x += b.vx * dt - World.wind * 6 * dt
			b.y += sin(b.p * 0.3) * 8 * dt
			var X = roundf(b.x - sx)
			var Y = roundf(b.y - sy + sin(b.p) * 1.5)
			if X < 0 or X > VW:
				continue
			x.fillStyle = b.c
			if sin(b.p) > 0:
				x.fillRect(X - 1, Y, 1, 1); x.fillRect(X + 1, Y, 1, 1)
			else:
				x.fillRect(X - 1, Y - 1, 1, 2); x.fillRect(X + 1, Y - 1, 1, 2)
			x.fillStyle = "#241410"
			x.fillRect(X, Y, 1, 1)
	if D.day > 0.4 and World.storm < 0.5:
		# a small flock crosses the sky now and then
		LIFE.birdT -= dt
		if LIFE.birdT <= 0:
			LIFE.birdT = rand(9, 20)
			var y0 = rand(14, 60)
			for i in rint(3, 6):
				LIFE.birds.append({"x": VW + 10 + i * 9, "y": y0 + absf(i - 2) * 4, "p": randf() * 6})
		x.fillStyle = mixc("#2a3350", "#6a7a9a", 1 - D.day)
		for b in LIFE.birds:
			b.x -= dt * 26
			b.p += dt * 10
			var X = roundf(b.x)
			var Y = roundf(b.y)
			var up = 1 if sin(b.p) > 0 else 0
			x.fillRect(X - 2, Y - up, 2, 1); x.fillRect(X, Y, 1, 1); x.fillRect(X + 1, Y - up, 2, 1)
		LIFE.birds = LIFE.birds.filter(func(b): return b.x > -10)
	if D.day < 0.35 and World.rain < 0.3:
		# fireflies at night
		var a: float = (0.35 - D.day) / 0.35
		for f in LIFE.bugs:
			f.p += dt
			var X = roundf(fposmod(f.x * VW + sin(f.p * 0.7) * 12 + VW, VW))
			var Y = roundf(VH * 0.35 + f.y * VH * 0.5 + cos(f.p * 0.9) * 8)
			var g = 0.5 + 0.5 * sin(f.p * 3)
			x.fillStyle = rgba(220, 255, 120, a * g)
			x.fillRect(X, Y, 1, 1)
			if g > 0.8:
				x.fillStyle = rgba(220, 255, 120, a * 0.25)
				x.fillRect(X - 1, Y - 1, 3, 3)


# ================================================================ world objects

func drawObelisk(x: Ctx, sx: float, sy: float) -> void:
	var o = obelisk
	if o == null:
		return
	var X = roundf(o.x - sx)
	var Y = roundf(o.y - sy)
	var h: float = 46 * o.rise
	var a: float = maxf(0, 1 - o.fade) if o.used else 1.0
	var tt = realTime
	x.save()
	x.globalAlpha = a
	x.fillStyle = rgba(184, 138, 255, 0.18); x.beginPath(); x.ellipse(X, Y - h * 0.5, 18, h * 0.6 + 6, 0, 0, TAU); x.fill()
	# tapered stone body with a capstone
	for layer in [["#0e0814", 9.0, 6.5, 7.0], ["#2e2440", 8.0, 5.6, 6.0]]:
		x.fillStyle = layer[0]
		x.beginPath(); x.moveTo(X - layer[1], Y); x.lineTo(X - layer[2], Y - h); x.lineTo(X, Y - h - layer[3]); x.lineTo(X + layer[2], Y - h); x.lineTo(X + layer[1], Y); x.closePath(); x.fill()
	x.fillStyle = "#463a5e"
	x.beginPath(); x.moveTo(X - 8, Y); x.lineTo(X - 5.6, Y - h); x.lineTo(X, Y - h - 6); x.lineTo(X - 1, Y); x.closePath(); x.fill()
	# glowing runes that pulse in sequence
	for i in 5:
		var ry = Y - 8 - i * (h - 12) / 5
		var g = 0.4 + 0.6 * maxf(0, sin(tt * 3 - i * 0.8))
		x.fillStyle = rgba(255, 58, 216, g); x.fillRect(X - 2, ry - 2, 4, 1); x.fillRect(X - 0.5, ry - 4, 1, 4)
		x.fillStyle = rgba(159, 255, 232, g * 0.8); x.fillRect(X - 1, ry - 3, 2, 0.5)
	x.fillStyle = "#1a0828"; x.fillRect(X - 11, Y - 2, 22, 3)
	x.restore()
	if not o.used and absf(P.x - o.x) < 50 and absf(P.y - o.y) < 30:
		x.font = FONT
		x.textAlign = "center"
		textOutline(x, "↑ Touch the Obelisk", X, Y - h - 14, "#e8b8ff")


func drawNotes(x: Ctx, sx: float, sy: float) -> void:
	var n = noteAt() if M.get("notes") else null
	if n != null and thought == null:
		x.font = FONT
		x.textAlign = "center"
		textOutline(x, "↑ " + n.label, roundf(n.x - sx), roundf(n.y - sy - 58), "#ffffff")
	if thought == null:
		return
	thought.t += _rdt
	if thought.t > 4.5 or (n == null and thought.t > 1.5 and thought.t < 3.4):
		thought = null
		return
	# a soft thought bubble above the hero's head
	var a = minf(1, minf(thought.t * 4, (4.5 - thought.t) * 2))
	var X = roundf(clampf(P.x - sx, 90, VW - 90))
	var Y = roundf(P.y - sy - 70)
	x.save()
	x.globalAlpha = a
	x.font = '7px "Press Start 2P", monospace'
	x.textAlign = "center"
	var lines = []
	var ln = ""
	for wd in str(thought.text).split(" "):
		var t2: String = ln + " " + wd if ln else wd
		if x.measureText(t2).width > 150:
			lines.append(ln)
			ln = wd
		else:
			ln = t2
	lines.append(ln)
	var W = 0.0
	for l in lines:
		W = maxf(W, x.measureText(l).width)
	W += 14
	var H = lines.size() * 10 + 8.0
	x.fillStyle = rgba(255, 255, 255, 0.95)
	x.strokeStyle = "#27335c"
	x.lineWidth = 1
	x.beginPath(); x.roundRect(X - W / 2, Y - H, W, H, 6); x.fill(); x.stroke()
	for b in [[-4, 4, 2.5], [-8, 10, 1.6]]:
		x.beginPath(); x.arc(roundf(P.x - sx) + b[0], Y + b[1], b[2], 0, TAU); x.fill(); x.stroke()
	x.fillStyle = "#27335c"
	for i in lines.size():
		x.fillText(lines[i], X, Y - H + 13 + i * 10)
	x.restore()


func drawPedestal(x: Ctx, sx: float, sy: float) -> void:
	var pd: Dictionary = M.pedestal
	var X = roundf(pd.x - sx)
	var Y = roundf(M.floorY - sy)
	var t = realTime
	var busy = slimes.any(func(e): return e.boss and e.state != "dead")
	x.fillStyle = "#241410"; x.fillRect(X - 12, Y - 22, 24, 22)
	x.fillStyle = "#6a6474"; x.fillRect(X - 11, Y - 21, 22, 21)
	x.fillStyle = "#8a8494"; x.fillRect(X - 11, Y - 21, 22, 3)
	x.fillStyle = "#4a4454"; x.fillRect(X - 14, Y - 4, 28, 4)
	var col = {"warlord": Color8(255, 58, 74), "dreamer": Color8(194, 92, 255)}.get(pd.kind, Color8(143, 255, 106))
	if not busy:
		x.fillStyle = Color(col, 0.5 + 0.3 * sin(t * 3)); x.beginPath(); x.arc(X, Y - 30 + sin(t * 2) * 2, 5, 0, TAU); x.fill()
		x.fillStyle = Color(col, 0.18); x.beginPath(); x.arc(X, Y - 30, 12, 0, TAU); x.fill()
	if not busy and absf(P.x - pd.x) < 22:
		x.font = FONT
		x.textAlign = "center"
		textOutline(x, "↑ Summon %s again" % {"warlord": "the Crimson Warlord", "dreamer": "The Dreamer"}.get(pd.kind, "Doc Croc"), X, Y - 46, "#ffffff")


func drawVials(x: Ctx, sx: float, sy: float) -> void:
	for p in puddles:
		var a: float = (p.life - p.t) / 0.6 if p.t > p.life - 0.6 else 1.0
		var X: float = p.x - sx
		var Y: float = M.floorY - sy
		x.globalAlpha = a
		x.fillStyle = "#4fb83a"; x.beginPath(); x.ellipse(X, Y, p.w / 2, 3, 0, 0, TAU); x.fill()
		x.fillStyle = "#9fff7a"; x.beginPath(); x.ellipse(X - 4, Y - 0.5, p.w / 4, 1.2, 0, 0, TAU); x.fill()
		x.globalAlpha = 1
	for v in bossVials:
		x.save()
		x.translate(v.x - sx, v.y - sy)
		x.rotate(v.spin)
		x.fillStyle = "#28383f"; x.fillRect(-3, -6, 6, 12)
		x.fillStyle = "#dff0ff"; x.fillRect(-2, -5, 4, 4)
		x.fillStyle = "#7fe060"; x.fillRect(-2, -1, 4, 6)
		x.fillStyle = "#9a6a3c"; x.fillRect(-1.5, -8, 3, 2)
		x.restore()


## the hero's own Potion Throw and Crimson Rain
func drawBossSkills(x: Ctx, sx: float, sy: float) -> void:
	for p in pPuddles:
		var a: float = (p.life - p.t) / 0.6 if p.t > p.life - 0.6 else 1.0
		x.globalAlpha = a
		x.fillStyle = "#4fb83a"; x.beginPath(); x.ellipse(p.x - sx, p.y - sy, p.w / 2, 3, 0, 0, TAU); x.fill()
		x.fillStyle = "#9fff7a"; x.beginPath(); x.ellipse(p.x - sx - 4, p.y - sy - 0.5, p.w / 4, 1.2, 0, 0, TAU); x.fill()
		x.globalAlpha = 1
	for v in pVials:
		x.save()
		x.translate(v.x - sx, v.y - sy)
		x.rotate(v.spin)
		x.fillStyle = "#28383f"; x.fillRect(-3, -6, 6, 12)
		x.fillStyle = "#dff0ff"; x.fillRect(-2, -5, 4, 4)
		x.fillStyle = "#7fe060"; x.fillRect(-2, -1, 4, 6)
		x.fillStyle = "#9a6a3c"; x.fillRect(-1.5, -8, 3, 2)
		x.restore()
	if PRain.t > 0:
		var k = minf(1, PRain.t / 0.5)
		x.fillStyle = rgba(120, 0, 20, 0.16 * k)
		x.fillRect(0, 0, VW, VH)
		var t = realTime
		x.strokeStyle = rgba(200, 20, 40, 0.7 * k)
		x.lineWidth = 1
		x.beginPath()
		for i in 160:
			var X = fmod(hsh(i * 1.7) * (VW + 40) + t * 30, VW + 40) - 20
			var Y = fmod(hsh(i * 2.9) * (VH + 60) + t * 520, VH + 60) - 40
			x.moveTo(X, Y)
			x.lineTo(X - 1.5, Y + 7)
		x.stroke()


## a boss's loot box: Crocbox (swamp green, gold bands), Crimsonbox (blood red, black iron) or Dreambox (abyss purple, red runes)
func drawBossBox(x: Ctx, kind: String, X: float, Y: float, tt: float) -> void:
	if kind == "dreamer":
		var g2 = 0.5 + 0.5 * sin(tt * 3)
		x.fillStyle = rgba(190, 80, 255, 0.28 * g2); x.fillRect(X - 13, Y - 21, 26, 22)
		x.fillStyle = "#06020c"; x.fillRect(X - 10, Y - 16, 20, 16)
		x.fillStyle = "#2a1040"; x.fillRect(X - 9, Y - 15, 18, 14)
		x.fillStyle = "#4a2068"; x.fillRect(X - 9, Y - 15, 18, 3)
		x.fillStyle = "#06020c"; x.fillRect(X - 9, Y - 10, 18, 1)
		x.fillStyle = "#120618"; x.fillRect(X - 6, Y - 15, 2, 14); x.fillRect(X + 4, Y - 15, 2, 14)
		x.fillStyle = rgba(255, 60, 90, 0.6 + 0.4 * g2); x.fillRect(X - 1, Y - 8, 2, 5); x.fillRect(X - 3, Y - 6, 6, 1)   # a red rune
		x.fillStyle = "#d89aff"; x.fillRect(X - 2, Y - 12, 4, 3)
		if randf() < 0.15:
			part(X + cam.x + rand(-10, 10), Y + cam.y - rand(4, 20), 0, -20, 0.6, "#c25cff" if randf() < 0.6 else "#ff3a5a", 0, 1)
		return
	var red = kind == "warlord"
	var gl = 0.5 + 0.5 * sin(tt * 4)
	x.fillStyle = rgba(255, 70, 90, 0.25 * gl) if red else rgba(255, 220, 80, 0.25 * gl)
	x.fillRect(X - 13, Y - 21, 26, 22)
	x.fillStyle = "#14080a"; x.fillRect(X - 10, Y - 16, 20, 16)                 # outline
	x.fillStyle = "#8a1a24" if red else "#3f7a2c"; x.fillRect(X - 9, Y - 15, 18, 14)  # body
	x.fillStyle = "#b8303c" if red else "#5fa83e"; x.fillRect(X - 9, Y - 15, 18, 3)   # lid shine
	x.fillStyle = "#14080a"; x.fillRect(X - 9, Y - 10, 18, 1)                   # lid seam
	x.fillStyle = "#2a1418" if red else "#e8b830"
	x.fillRect(X - 6, Y - 15, 2, 14); x.fillRect(X + 4, Y - 15, 2, 14)           # bands
	x.fillStyle = "#ffd84a" if not red else "#ff9aa6"; x.fillRect(X - 2, Y - 11, 4, 4)  # clasp
	if randf() < 0.15:
		part(X + cam.x + rand(-10, 10), Y + cam.y - rand(4, 20), 0, -20, 0.6, "#ff5d73" if red else "#ffe14d", 0, 1)


func drawRocks(x: Ctx, sx: float, sy: float) -> void:
	for r in bossRocks:
		var X = roundf(r.x - sx)
		var G = roundf(M.floorY - sy)
		if r.phase == "warn":
			# red danger marker that pulses faster as impact nears
			var u = 1 - clampf(r.warn / 1.2, 0, 1)
			var blinkOn = sin(realTime * 1000 / (70 - u * 50)) > 0
			x.fillStyle = rgba(255, 40, 60, 0.12 + u * 0.25); x.fillRect(X - 16, 0, 32, G)
			x.fillStyle = rgba(255, 60, 80, 0.85) if blinkOn else rgba(255, 140, 150, 0.6)
			x.beginPath(); x.ellipse(X, G - 1, 16, 4, 0, 0, TAU); x.fill()
			x.strokeStyle = "#ffd0d6"; x.lineWidth = 1; x.strokeRect(X - 16.5, G - 5.5, 33, 5)
		else:
			var Y = roundf(r.y - sy)
			x.fillStyle = "#241410"; x.fillRect(X - 10, Y - 16, 20, 16)
			x.fillStyle = "#8f877e"; x.fillRect(X - 9, Y - 15, 18, 14)
			x.fillStyle = "#b8ada0"; x.fillRect(X - 9, Y - 15, 8, 4)
			x.fillStyle = "#5e5850"; x.fillRect(X + 2, Y - 6, 7, 5)


func drawCrimsonRain(x: Ctx, sx: float, sy: float) -> void:
	if Warlord.rainWarn > 0 or Warlord.rain > 0:
		x.fillStyle = rgba(120, 0, 20, 0.28 if Warlord.rain > 0 else 0.15 * (1.5 - Warlord.rainWarn))
		x.fillRect(0, 0, VW, VH)
	if Warlord.rain <= 0:
		return
	var t = realTime
	x.strokeStyle = rgba(200, 20, 40, 0.75)
	x.lineWidth = 1
	x.beginPath()
	for i in 220:
		var wx = fmod(hsh(i * 1.7) * (M.w + 40) + t * 30, M.w + 40) - 20
		var wy = fmod(hsh(i * 2.9) * 400 + t * 520, 400) - 60
		var X = wx - sx
		var Y = wy - sy
		if X < -5 or X > VW + 5:
			continue
		if M.plats.any(func(pl): return wx > pl[0] and wx < pl[0] + pl[2] and wy > pl[1]):
			continue   # no rain beneath the ledges
		x.moveTo(X, Y)
		x.lineTo(X - 1.5, Y + 7)
	x.stroke()
	x.fillStyle = rgba(255, 240, 200, 0.06)
	for pl in M.plats:
		x.fillRect(pl[0] - sx, pl[1] - sy, pl[2], M.floorY - pl[1])   # the dry shelter under each ledge


# ---------------- the house: furniture and curios, drawn live so purchases appear at once

func drawFurniture(x: Ctx, kind: String, id: String, X: float, Y: float, items := []) -> void:
	var R = func(c, a: float, b: float, w: float, h: float):
		x.fillStyle = c
		x.fillRect(X + a, Y + b, w, h)
	if kind == "bed":
		var wood: String = {"cot": "#c8a868", "oakbed": "#8e5c36", "canopy": "#b8862c", "cloud": "#e8eef8"}.get(id, "#8e5c36")
		var sheet: String = {"cot": "#e8dcb0", "oakbed": "#e8e4dc", "canopy": "#f4ecf8", "cloud": "#ffffff"}.get(id, "#ffffff")
		var quilt: String = {"cot": "#b8a070", "oakbed": "#c0504a", "canopy": "#7a3aa0", "cloud": "#9fd4ff"}.get(id, "#c0504a")
		if id == "canopy":
			R.call("#241410", -26, -46, 3, 46); R.call("#241410", 23, -46, 3, 46); R.call(wood, -25, -45, 1.5, 44); R.call(wood, 24, -45, 1.5, 44)
			R.call("#5a1a6a", -27, -48, 54, 6); R.call("#8a3aa0", -27, -42, 8, 18); R.call("#8a3aa0", 19, -42, 8, 18)
		if id == "cloud":
			x.fillStyle = rgba(255, 255, 255, 0.85)
			for i in 6:
				x.beginPath(); x.arc(X - 22 + i * 9, Y - 4, 5, 0, TAU); x.fill()
		R.call("#241410", -25, -12, 50, 10); R.call(wood, -24, -11, 48, 8)
		R.call("#241410", -25, -22, 4, 22); R.call(wood, -24, -21, 2.5, 20); R.call("#241410", 21, -16, 4, 16); R.call(wood, 22, -15, 2.5, 14)
		R.call(sheet, -20, -15, 42, 4); R.call(quilt, -6, -16, 28, 6); R.call(sheet, -20, -17, 11, 4); R.call("#ffffff", -19, -17, 5, 1)
		if id == "oakbed":
			for i in 4:
				R.call("#e8a838" if i % 2 else "#3f7ab5", -4 + i * 7, -15, 3, 3)
	elif kind == "table":
		var top: String = {"pine": "#d8b07a", "oaktable": "#8e5c36", "marble": "#eef0f4"}.get(id, "#d8b07a")
		var leg: String = {"pine": "#b08850", "oaktable": "#6e4428", "marble": "#c8ccd8"}.get(id, "#b08850")
		R.call("#241410", -18, -20, 36, 4); R.call(top, -17, -19, 34, 2.5)
		if id == "marble":
			R.call("#c8ccd8", -10, -18.5, 6, 0.5); R.call("#c8ccd8", 4, -18, 8, 0.5)
		for lx in [-15, 12]:
			R.call("#241410", lx, -16, 3, 16); R.call(leg, lx + 0.5, -16, 2, 16)
		R.call("#4a86c8", -3, -26, 5, 6); R.call("#ff7a9a", -2, -29, 3, 3); R.call("#6cc25a", -4, -28, 2, 2)   # a little vase of flowers
	elif kind == "chair":
		if id == "stool":
			R.call("#241410", -6, -11, 12, 3); R.call("#b08850", -5, -10, 10, 2); R.call("#8e5c36", -5, -8, 1.5, 8); R.call("#8e5c36", 3.5, -8, 1.5, 8)
		elif id == "armchair":
			R.call("#241410", -9, -20, 18, 20); R.call("#7a4a9a", -8, -19, 16, 12); R.call("#9a6ac0", -8, -11, 16, 5); R.call("#5a3070", -9, -12, 3, 8)
			R.call("#5a3070", 6, -12, 3, 8); R.call("#4a2e1a", -7, -6, 2, 6); R.call("#4a2e1a", 5, -6, 2, 6)
		else:
			R.call("#241410", -9, -32, 18, 32); R.call("#d8a830", -8, -31, 16, 30); R.call("#a82a30", -6, -27, 12, 16); R.call("#a82a30", -7, -10, 14, 4)
			R.call("#fff0a0", -2, -30, 4, 2); R.call("#6fd4ff", -1, -33, 2, 2)
	elif kind == "rug":
		var base: String = {"mat": "#c8a868", "pattern": "#a82a30", "dragon": "#2f6a4a"}.get(id, "#c8a868")
		var trim: String = {"mat": "#8e6a38", "pattern": "#ffd35a", "dragon": "#9fe6a0"}.get(id, "#8e6a38")
		R.call("#241410", -37, -1.5, 74, 3); R.call(base, -36, -1, 72, 2); R.call(trim, -36, -1, 72, 0.5)
		var i = -32
		while i < 33:
			R.call(trim, i, 0, 3 if id == "dragon" else 2, 0.5)
			i += 8 if id == "pattern" else 6
		for fx_ in [-38, 36]:
			for k in 3:
				R.call(trim, fx_, -1 + k, 2, 0.5)
	elif kind == "shelf":
		var wood: String = {"plank": "#a8743e", "bookcase": "#7a4a28", "cabinet": "#5a3a20"}.get(id, "#a8743e")
		var H = 4.0 if id == "plank" else 30.0
		var top = -H
		if id == "plank":
			R.call("#241410", -18, -3, 36, 4); R.call(wood, -17, -2.5, 34, 2.5); R.call("#5a3a20", -14, 1, 2, 4); R.call("#5a3a20", 12, 1, 2, 4)
		else:
			R.call("#241410", -18, top - 1, 36, H + 2); R.call(wood, -17, top, 34, H); R.call("#3a2414", -15, top + 2, 30, H - 4)
			R.call(wood, -17, top + H / 2 - 1, 34, 2)
			if id == "bookcase":
				for i in 9:
					R.call(["#c0504a", "#3f7ab5", "#e8a838", "#4a9a5a", "#7a3aa0"][i % 5], -14 + i * 3.2, top + H / 2 + 2, 2.6, 10 - (i % 3))
			if id == "cabinet":
				x.fillStyle = rgba(200, 230, 255, 0.25)
				x.fillRect(X - 15, Y + top + 2, 30, H - 4)
				R.call("#d8b07a", -1, top + 2, 1, H - 4)
		# curios sit on the shelf boards
		var spots: Array
		if id == "plank":
			spots = [[-9, -3], [9, -3]]
		elif id == "bookcase":
			spots = [[-9, top + H / 2 - 1], [0, top + H / 2 - 1], [9, top + H / 2 - 1]]
		else:
			spots = [[-9, top + H / 2 - 1], [8, top + H / 2 - 1], [-9, top + H - 2], [8, top + H - 2]]
		for i in items.size():
			if i < spots.size():
				drawCurio(x, items[i], X + spots[i][0], Y + spots[i][1])


func drawCurio(x: Ctx, id: String, X: float, Y: float) -> void:
	var R = func(c, a: float, b: float, w: float, h: float):
		x.fillStyle = c
		x.fillRect(X + a, Y + b, w, h)
	match id:
		"eye":
			R.call("#241410", -3.5, -9, 7, 9); R.call(rgba(190, 230, 255, 0.6), -3, -8.5, 6, 8); R.call("#ffffff", -2, -6, 4, 4)
			R.call("#3fae5a", -1, -5, 2, 2); R.call("#000000", -0.5, -4.5, 1, 1); R.call("#8e5c36", -3.5, -10, 7, 1.5)
		"mandrake":
			R.call("#a8543a", -3, -4, 6, 4); R.call("#4a9a3c", -3, -9, 2, 5); R.call("#6cc25a", 0, -10, 2, 6); R.call("#d8c8a8", -1, -5, 2, 1)
		"ship":
			R.call("#241410", -5, -6, 10, 6); R.call(rgba(200, 240, 255, 0.55), -4.5, -5.5, 9, 5); R.call("#8e5c36", -3, -2.5, 6, 1.5)
			R.call("#ffffff", -1, -5, 2, 2.5); R.call("#c8a868", 4.5, -4, 1.5, 2)
		"hourglass":
			R.call("#d8a830", -3, -10, 6, 1.5); R.call("#d8a830", -3, -1.5, 6, 1.5); R.call(rgba(220, 240, 255, 0.6), -2, -8.5, 4, 7)
			R.call("#e8c060", -1, -4, 2, 2.5); R.call("#e8c060", -0.5, -7, 1, 1)
		"skull":
			R.call("#9fe6ff", -3.5, -8, 7, 6); R.call("#d8f4ff", -3, -8, 3, 2); R.call("#3a6a8a", -2.5, -5.5, 2, 2); R.call("#3a6a8a", 0.5, -5.5, 2, 2); R.call("#9fe6ff", -2, -2, 4, 2)
		"lamp":
			R.call("#d8c8a8", -0.5, -5, 1.5, 5)
			x.fillStyle = rgba(160, 255, 220, 0.35); x.beginPath(); x.arc(X, Y - 7, 5, 0, TAU); x.fill()
			R.call("#4ad8a8", -3, -9, 6, 3); R.call("#bfffe8", -2, -9, 2, 1)


## one label at a time, for whichever spot you're standing closest to (on the ground floor)
func nearestSlot():
	if absf(P.y - M.floorY) > 4:
		return null
	var best = null
	var bd = 1e9
	for s in M.slots:
		var d = absf(P.x - s.x)
		if d < s.w / 2 + 4 and d < bd:
			bd = d
			best = s
	return best


func drawHouse(x: Ctx, sx: float, sy: float) -> void:
	var Hs: Dictionary = save.get("house", {"placed": {}, "shelfItems": []})
	var Y0: float = M.floorY
	if M.get("variant") == "summoner":
		# the TV is on: a little platformer plays on screen
		var t = realTime
		var X0 = 204 - sx
		var Y1 = 66 - sy
		x.save()
		x.beginPath(); x.rect(X0, Y1, 64, 38); x.clip()   # everything on screen stays inside the bezel
		x.fillStyle = "#4a8ad8"; x.fillRect(X0, Y1, 64, 38)
		x.fillStyle = "#6cc25a"; x.fillRect(X0, Y1 + 30, 64, 8)
		x.fillStyle = "#8e5c36"
		for i in 6:
			var bx = fposmod(i * 14 - t * 20, 70) - 3
			x.fillRect(X0 + bx, Y1 + 22 - (i % 2) * 6, 8, 3)
		var jy = absf(sin(t * 3)) * 10
		x.fillStyle = "#ff3a3a"; x.fillRect(X0 + 22, Y1 + 24 - jy, 4, 6)
		x.fillStyle = "#ffdcc2"; x.fillRect(X0 + 22, Y1 + 22 - jy, 4, 2)
		x.fillStyle = "#ffd35a"; x.fillRect(X0 + fposmod(40 - t * 20, 64), Y1 + 14, 2, 2)
		x.fillStyle = rgba(255, 255, 255, 0.08); x.fillRect(X0, Y1, 64, 12)
		x.fillStyle = rgba(0, 0, 0, 0.08)
		for k in range(0, 38, 2):
			x.fillRect(X0, Y1 + k, 64, 1)   # glass sheen and scanlines
		x.restore()
		x.fillStyle = rgba(110, 170, 255, 0.08 + 0.04 * sin(t * 7))
		x.fillRect(X0 - 10, Y0 - sy - 6, 84, 8)   # its glow on the floor
	var near = nearestSlot()
	for s in M.slots:
		var id: String = str(Hs.get("placed", {}).get(s.k, ""))
		var X: float = s.x - sx
		var Y: float = (Y0 - 58 if s.get("wall") else Y0) - sy
		if id != "" and id != "<null>":
			drawFurniture(x, s.k, id, X, Y, Hs.get("shelfItems", []) if s.k == "shelf" else [])
		else:
			# an empty spot: a faint dashed outline
			x.fillStyle = rgba(200, 168, 120, 0.7)
			var h = 2.0 if s.k == "rug" else (28.0 if s.get("wall") else 22.0)
			var top = Y - 28 if s.get("wall") else Y - h
			var i: float = -s.w / 2
			while i < s.w / 2:
				x.fillRect(X + i, top, 2, 0.6)
				x.fillRect(X + i, top + h - 0.6, 2, 0.6)
				i += 3
			var j = 0.0
			while j < h:
				x.fillRect(X - s.w / 2, top + j, 0.6, 2)
				x.fillRect(X + s.w / 2 - 0.6, top + j, 0.6, 2)
				j += 3
		if s == near:
			var it = null
			if id != "" and FURNITURE.has(s.k):
				for q in FURNITURE[s.k].items:
					if q.id == id:
						it = q
			x.font = F6
			x.textAlign = "center"
			textOutline(x, it.name if it != null else "%s · empty" % s.label, roundf(X), roundf((Y0 - 92 if s.get("wall") else Y0 - 40) - sy), "#fff6d6")
			if it == null:
				textOutline(x, "Shop › House", roundf(X), roundf((Y0 - 84 if s.get("wall") else Y0 - 32) - sy), "#c8a878")


## ten pedestals along the hall; trophies for bosses you've beaten
func drawTrophyStand(x: Ctx, sx: float, sy: float) -> void:
	var Y: float = M.floorY - sy
	var T: Dictionary = save.trophies
	x.fillStyle = "#5a3a20"; x.fillRect(80 - sx, Y - 6, 480, 6)
	x.fillStyle = "#8e5c36"; x.fillRect(80 - sx, Y - 6, 480, 1.5)
	for i in TROPHIES.size():
		var tr = TROPHIES[i]
		var X = 104 + i * 48 - sx
		var got: bool = tr != null and T.get(tr.id, false)
		x.fillStyle = "#241410"; x.fillRect(X - 8, Y - 22, 16, 16)
		x.fillStyle = "#e8dcc0"; x.fillRect(X - 7, Y - 21, 14, 14)
		x.fillStyle = "#c8b898"; x.fillRect(X - 7, Y - 21, 14, 2)
		if got and tr.id == "dreamer":
			# a golden octopus head with ruby eyes
			x.fillStyle = "#ffd35a"; x.fillRect(X - 5, Y - 34, 10, 8); x.fillRect(X - 6, Y - 31, 12, 4)
			x.fillStyle = "#c89418"
			for j in 5:
				x.fillRect(X - 5 + j * 2.4, Y - 27, 1.2, 4 + (j % 2) * 2)
			x.fillStyle = "#ff2a4a"; x.fillRect(X - 3, Y - 31, 2, 1.5); x.fillRect(X + 1, Y - 31, 2, 1.5)
		elif got and tr.id == "warlord":
			# a golden crested helm
			x.fillStyle = "#ffd35a"; x.fillRect(X - 5, Y - 33, 10, 11)
			x.fillStyle = "#c89418"; x.fillRect(X - 5, Y - 24, 10, 2)
			x.fillStyle = "#5a0c14"; x.fillRect(X - 3, Y - 30, 7, 2)
			x.fillStyle = "#ff3a3a"; x.fillRect(X - 2, Y - 30, 1, 1); x.fillRect(X + 2, Y - 30, 1, 1)
			x.fillStyle = "#a82a30"; x.fillRect(X - 6, Y - 37, 3, 5)
		elif got:
			# a golden croc head in spectacles
			x.fillStyle = "#ffd35a"; x.fillRect(X - 6, Y - 30, 12, 8); x.fillRect(X - 1, Y - 34, 10, 5)
			x.fillStyle = "#c89418"; x.fillRect(X - 6, Y - 24, 12, 2); x.fillRect(X + 2, Y - 31, 7, 1)
			x.strokeStyle = "#3a2a10"; x.lineWidth = 0.6; x.beginPath(); x.arc(X + 1, Y - 32, 1.8, 0, TAU); x.stroke()
			x.fillStyle = "#fff6c0"; x.fillRect(X - 4, Y - 29, 2, 2)
		else:
			x.fillStyle = rgba(40, 30, 60, 0.75); x.fillRect(X - 5, Y - 32, 10, 10)
			x.font = F6; x.textAlign = "center"; x.fillStyle = "#b8b0d0"; x.fillText("?", X, Y - 25)
		if absf(P.x - (X + sx)) < 14:
			x.font = F6
			x.textAlign = "center"
			textOutline(x, "%s · +10%% EXP" % tr.name if got else "??? · defeat a new boss", roundf(X), roundf(Y - 42), "#ffe08a" if got else "#c8c0e0")


## the card wall in the trophy hall
func drawTrophies(x: Ctx, sx: float, sy: float) -> void:
	var C: Dictionary = save.cards
	var slots = [["n", "Card"], ["ng", "Gold"], ["s", "Shiny"], ["sg", "Shiny gold"]]
	x.font = F5
	x.textAlign = "center"
	var total = 0
	var totalSlots = 0
	for col in BEST_ORDER.size():
		var k: String = BEST_ORDER[col]
		var X0 = 70 + col * 56 - sx
		var nm = ""
		if k == "croc":
			nm = "Croc"
		elif k == "warlord":
			nm = "Warlord"
		elif k == "dreamer":
			nm = "Dreamer"
		else:
			var parts_: PackedStringArray = SLIME_TYPES[k].name.split(" ")
			nm = parts_[-1]
			if not SLIME_TYPES[k].get("ai") and nm == "Slime":
				nm = parts_[0]
		x.font = F5
		textOutline(x, nm, X0 + 10, 30 - sy, "#ffe08a")
		var use: Array = slots.slice(0, 2) if k in ["croc", "warlord", "dreamer"] else slots
		totalSlots += use.size()
		for row in use.size():
			var key: String = use[row][0]
			var X = X0 + (row % 2) * 22 - 1
			var Y = 36 + floorf(row / 2.0) * 34 - sy
			var owned: bool = C.get(k, {}).get(key, false)
			if owned:
				total += 1
			x.fillStyle = "#5a3a20"; x.fillRect(X - 2, Y - 2, 22, 30)
			x.fillStyle = "#ffd35a"; x.fillRect(X - 1, Y - 1, 20, 28)   # gilded frame
			if owned:
				cardArt(x, k, key.ends_with("g"), key.begins_with("s"), false, X, Y, 18.0 / 44.0)
			else:
				x.fillStyle = "#2a2040"; x.fillRect(X, Y, 18, 26)
				x.fillStyle = "#6a6488"; x.fillText("?", X + 9, Y + 16)
	x.font = FONT
	textOutline(x, "Cards collected: %d / %d" % [total, totalSlots], roundf(M.w / 2.0 - sx), 112 - sy, "#ffffff")


# ================================================================ skill and spell effects

func drawFX(x: Ctx, sx: float, sy: float) -> void:
	for f in fx:
		if f.t < 0:
			continue
		var k: float = f.t / f.life
		var X: float = f.x - sx
		var Y: float = f.y - sy
		x.save()
		match f.type:
			"strike":
				x.globalAlpha = (1 - k) * 0.5
				x.fillStyle = "#ffffff"; x.fillRect(0, 0, VW, VH)
				x.globalAlpha = 1 - k
				x.strokeStyle = "#ffffff"; x.lineWidth = 3
				x.beginPath()
				var bx = X
				var by = Y - 220
				x.moveTo(bx, by)
				for s in 9:
					bx = X + ((hsh(s + f.x) - 0.5) * 30 if s < 8 else 0.0)
					by += 24.4
					x.lineTo(bx, by)
				x.stroke()
				x.strokeStyle = "#9fe6ff"; x.lineWidth = 1; x.stroke()
			"aoe":
				drawAoe(x, f, X, Y, k)
			"sonic":
				for i in 3:
					var r = 8 + (k + i * 0.18) * 70
					var a = maxf(0, 1 - k - i * 0.15)
					x.strokeStyle = rgba(230, 240, 255, a)
					x.lineWidth = 2 - i * 0.5
					x.beginPath()
					x.ellipse(X + f.dir * r * 0.6, Y, r * 0.35, 6 + r * 0.08, 0, -1.3 if f.dir > 0 else PI - 1.3, 1.3 if f.dir > 0 else PI + 1.3)
					x.stroke()
			"ray":
				x.globalAlpha = 1 - k
				x.strokeStyle = "#fff6c0"; x.lineWidth = 2.5
				x.beginPath(); x.moveTo(X, Y); x.lineTo(f.tx - sx, f.ty - sy); x.stroke()
				x.strokeStyle = "#ffffff"; x.lineWidth = 1; x.stroke()
			"puddle":
				x.globalAlpha = 1 - k
				x.strokeStyle = "#bfe0ff"; x.lineWidth = 1
				x.beginPath(); x.ellipse(X, Y, f.r * (0.4 + k), f.r * (0.4 + k) * 0.25, 0, 0, TAU); x.stroke()
				x.fillStyle = rgba(150, 190, 240, 0.35)
				x.beginPath(); x.ellipse(X, Y, f.r * 0.8, f.r * 0.2, 0, 0, TAU); x.fill()
			"ring":
				x.globalAlpha = 1 - k
				x.strokeStyle = f.col; x.lineWidth = 2
				x.beginPath(); x.ellipse(X, Y, f.r * (0.3 + k), f.r * (0.3 + k) * 0.6, 0, 0, TAU); x.stroke()
			"whirlRing":
				x.globalAlpha = 1 - k
				for b in 6:
					var a: float = f.a0 + b * PI / 3 + k * 5
					x.strokeStyle = "#ffc4e6" if b % 2 else "#ffffff"
					x.lineWidth = 2.5 - b * 0.2
					x.beginPath(); x.ellipse(X, Y, f.r * (0.4 + k * 0.6), f.r * 0.32 * (0.4 + k * 0.6), 0, a, a + 0.9); x.stroke()
			"wave":
				if f.get("big"):
					x.globalAlpha = minf(1, (1 - k) * 1.6)
					x.strokeStyle = f.col; x.lineWidth = 4
					x.beginPath(); x.ellipse(X, Y, 16, 30, 0, -1.3 if f.vx > 0 else PI - 1.3, 1.3 if f.vx > 0 else PI + 1.3); x.stroke()
					x.strokeStyle = "#ffffff"; x.lineWidth = 1.5; x.stroke()
					x.globalAlpha *= 0.4
					x.beginPath(); x.ellipse(X - sgn(f.vx) * 8, Y, 12, 24, 0, -1.2 if f.vx > 0 else PI - 1.2, 1.2 if f.vx > 0 else PI + 1.2); x.stroke()
				else:
					x.globalAlpha = 1 - k
					x.strokeStyle = f.col; x.lineWidth = 3
					x.beginPath(); x.arc(X, Y, 18, -1.2 if f.vx > 0 else PI - 0.8, 1.2 if f.vx > 0 else PI + 1.2); x.stroke()
					x.strokeStyle = "#ffffff"; x.lineWidth = 1; x.stroke()
			"bolt":
				x.globalAlpha = 1 - k
				x.strokeStyle = "#fff6b0"; x.lineWidth = 2
				x.beginPath()
				var bx = X
				x.moveTo(bx, Y - 150)
				var yy = Y - 150
				var s = 0
				while yy < Y:
					bx += (hsh(f.get("seed", 0.0) + s) - 0.5) * 12
					x.lineTo(bx, yy)
					yy += 12
					s += 1
				x.lineTo(X, Y)
				x.stroke()
				x.fillStyle = rgba(255, 240, 150, 0.5)
				x.fillRect(X - 10, Y - 6, 20, 6)
			"beam":
				var w = 14 * (1 - k * 0.6)
				var gr = x.createLinearGradient(X - w, 0, X + w, 0)
				gr.addColorStop(0, rgba(255, 240, 180, 0)); gr.addColorStop(0.5, rgba(255, 255, 240, 1 - k)); gr.addColorStop(1, rgba(255, 240, 180, 0))
				x.fillStyle = gr
				x.fillRect(X - w, 0, w * 2, Y)
				x.fillStyle = rgba(255, 230, 140, 0.6 * (1 - k))
				x.fillRect(X - 20, Y - 3, 40, 3)
			"slashmark":
				x.globalAlpha = 1 - k
				x.strokeStyle = "#ffffff"; x.lineWidth = 2
				var L = 10 + k * 6
				x.beginPath(); x.moveTo(X - cos(f.a) * L, Y - sin(f.a) * L); x.lineTo(X + cos(f.a) * L, Y + sin(f.a) * L); x.stroke()
			"blades":
				for i in 12:
					var a: float = f.t * 9 + i / 12.0 * TAU
					var r: float = f.r * minf(1, k * 2.2)
					x.globalAlpha = 1 - k
					x.strokeStyle = "#ffc4e6" if i % 2 else "#ffffff"
					x.lineWidth = 2
					var px2 = X + cos(a) * r
					var py2 = Y + sin(a) * r * 0.45
					x.beginPath(); x.moveTo(px2, py2); x.lineTo(px2 + cos(a + 1.6) * 9, py2 + sin(a + 1.6) * 4); x.stroke()
			"skysword":
				var drop = minf(1, k * 2.4)
				var topY = -60 + (Y + 10) * drop
				var w = 12.0
				var len = 120.0
				x.globalAlpha = 0.85 if k < 0.8 else (1 - k) * 4
				x.fillStyle = rgba(200, 180, 255, 0.9)
				x.beginPath(); x.moveTo(X - w, topY - len); x.lineTo(X + w, topY - len); x.lineTo(X + w * 0.6, topY - 12); x.lineTo(X, topY); x.lineTo(X - w * 0.6, topY - 12); x.closePath(); x.fill()
				x.fillStyle = "#fff8ff"; x.fillRect(X - 2, topY - len, 4, len - 10)
				x.fillStyle = "#ffd86a"; x.fillRect(X - w * 2.2, topY - len - 4, w * 4.4, 6); x.fillRect(X - 3, topY - len - 26, 6, 22)
				if drop >= 1:
					x.strokeStyle = rgba(210, 190, 255, 1 - k); x.lineWidth = 3
					x.beginPath(); x.ellipse(X, Y, maxf(0.1, f.w * (k - 0.4) * 1.2), maxf(0.1, 10 * (k - 0.4) * 2), 0, 0, TAU); x.stroke()
		x.restore()


func drawArrows(x: Ctx, sx: float, sy: float) -> void:
	var tier: Dictionary = ARROW_TIERS[clampi(CH().get("arrows", 0), 0, ARROW_TIERS.size() - 1)]
	for a in arrows:
		var ang = atan2(a.vy, a.vx)
		var L = 12.0 if a.mv.get("big") else 9.0
		var X: float = a.x - sx
		var Y: float = a.y - sy
		var c = cos(ang)
		var s = sin(ang)
		if a.kind == "spell":
			drawSpellBolt(x, a, X, Y, ang)
			continue
		if a.kind == "wind":
			x.strokeStyle = rgba(190, 255, 232, 0.95); x.lineWidth = 2
			x.beginPath(); x.arc(X, Y, 4, ang - 1.4, ang + 1.4); x.stroke()
			continue
		x.strokeStyle = "#fff6b0" if a.mv.get("big") else "#c8a878"
		x.lineWidth = 2 if a.mv.get("big") else 1
		x.beginPath(); x.moveTo(roundf(X - c * L), roundf(Y - s * L)); x.lineTo(roundf(X), roundf(Y)); x.stroke()
		x.fillStyle = hexc(tier.head); x.fillRect(roundf(X + c) - 1, roundf(Y + s) - 1, 2, 2)
		x.fillStyle = hexc(tier.fletch); x.fillRect(roundf(X - c * L) - 1, roundf(Y - s * L) - 1, 2, 2)


func drawSpellBolt(x: Ctx, a: Dictionary, X: float, Y: float, ang: float) -> void:
	var t = realTime
	x.save()
	x.translate(X, Y)
	x.rotate(ang)
	match a.elem:
		"air":
			x.strokeStyle = rgba(230, 250, 255, 0.95); x.lineWidth = 1.5
			x.beginPath(); x.arc(-2, 0, 5, -1.3, 1.3); x.stroke()
			x.strokeStyle = rgba(150, 220, 255, 0.6)
			x.beginPath(); x.arc(-5, 0, 4, -1.1, 1.1); x.stroke()
		"water":
			x.fillStyle = rgba(110, 180, 255, 0.9); x.beginPath(); x.ellipse(0, 0, 4.5, 3.2, 0, 0, TAU); x.fill()
			x.fillStyle = "#e0f4ff"; x.fillRect(0, -1.5, 1.5, 1.5)
		"earth":
			x.rotate(t * 10)
			x.fillStyle = "#241410"; x.fillRect(-3.5, -3.5, 7, 7)
			x.fillStyle = "#a07a4a"; x.fillRect(-3, -3, 6, 6)
			x.fillStyle = "#c89a5a"; x.fillRect(-3, -3, 3, 2)
		"fire":
			x.fillStyle = rgba(255, 120, 40, 0.9); x.beginPath(); x.arc(0, 0, 4, 0, TAU); x.fill()
			x.fillStyle = "#ffe08a"; x.beginPath(); x.arc(1, 0, 2.2, 0, TAU); x.fill()
		"dark":
			x.fillStyle = rgba(60, 20, 100, 0.9); x.beginPath(); x.arc(0, 0, 4, 0, TAU); x.fill()
			x.strokeStyle = "#c28aff"; x.lineWidth = 1; x.beginPath(); x.arc(0, 0, 4.5, t * 8, t * 8 + 3.5); x.stroke()
		_:
			x.fillStyle = "#fff6c0"; x.beginPath(); x.arc(0, 0, 3, 0, TAU); x.fill()
	x.restore()


func drawAoe(x: Ctx, f: Dictionary, X: float, Y: float, k: float) -> void:
	var el: String = f.elem
	var t: float = f.t
	var fade_ = (1 - k) / 0.25 if k > 0.75 else 1.0
	x.save()
	match el:
		"air":
			# funnel: stacked swirling rings that widen with height, leaning with its drift
			var grow = minf(1, k * 4)
			var shrink = (1 - k) / 0.25 if k > 0.75 else 1.0
			for i in 14:
				var yy = -i * 4.2 * grow
				var w = (3 + i * 1.7) * shrink
				var lean = sin(t * 6 + i * 0.5) * (2 + i * 0.35)
				x.strokeStyle = rgba(230 - i * 4, 245 - i * 2, 255, (0.85 - i * 0.03) * fade_)
				x.lineWidth = 2 if i < 4 else 1.5
				x.beginPath(); x.ellipse(X + lean, Y + yy, maxf(0.1, w), 1.6 + i * 0.12, 0, t * 9 + i, t * 9 + i + 4.2); x.stroke()
			x.fillStyle = rgba(200, 180, 140, 0.35 * fade_)
			x.beginPath(); x.ellipse(X, Y - 1, maxf(0.1, 12 * shrink), 2.5, 0, 0, TAU); x.fill()
		"water":
			# a curling wave travelling across, with a foam crest
			var p = minf(1, k * 1.3)
			var d: float = f.dir
			var cx = X - d * 45 + d * 90 * p
			var h = 34 * sin(p * PI) + 6
			x.globalAlpha = 0.9 * fade_
			var body = func(dx: float, col: String, hh: float):
				x.fillStyle = col
				x.beginPath()
				x.moveTo(cx - d * 46 + dx, Y)
				x.quadraticCurveTo(cx - d * 20 + dx, Y - hh * 0.5, cx - d * 6 + dx, Y - hh)
				x.quadraticCurveTo(cx + d * 6 + dx, Y - hh * 1.05, cx + d * 9 + dx, Y - hh * 0.75)
				x.quadraticCurveTo(cx + d * 2 + dx, Y - hh * 0.7, cx + d * 7 + dx, Y - hh * 0.45)
				x.quadraticCurveTo(cx + d * 14 + dx, Y - hh * 0.2, cx + d * 18 + dx, Y)
				x.closePath()
				x.fill()
			body.call(-d * 6, "#2a5aa8", h * 0.85)
			body.call(0.0, "#4a8ae0", h)
			x.fillStyle = "#2a5aa8"; x.beginPath(); x.ellipse(cx + d * 6, Y - h * 0.62, 5, h * 0.2 + 1, 0, 0, TAU); x.fill()   # the hollow under the curl
			x.strokeStyle = "#e8f6ff"; x.lineWidth = 2
			x.beginPath(); x.arc(cx + d * 4, Y - h * 0.72, 6, -2.6 if d > 0 else -0.5, 0.6 if d > 0 else 3.2); x.stroke()   # white curl of the lip
			x.fillStyle = rgba(160, 210, 255, 0.55); x.beginPath(); x.ellipse(cx - d * 30, Y - 3, 22, 4, 0, 0, TAU); x.fill()
			x.fillStyle = "#9fd0ff"; x.beginPath(); x.ellipse(cx - d * 14, Y - h * 0.45, 6, 2, 0, 0, TAU); x.fill()
			x.fillStyle = "#ffffff"
			for i in 6:
				x.fillRect(cx - d * (6 - i * 2.5), Y - h - 1 + sin(t * 20 + i) * 1.2, 2, 1.5)   # foam
			x.fillStyle = rgba(200, 235, 255, 0.6); x.fillRect(cx - d * 50, Y - 2, 60, 2)
		"earth":
			# two pillars burst up either side and slam together
			var rise = minf(1, k * 4)
			var close = clampf((k - 0.15) / 0.23, 0, 1)
			var off = 30 * (1 - close * close)
			var H = 38 * rise
			x.globalAlpha = fade_
			for s in [-1, 1]:
				var px0: float = X + s * (off + 7) - 7
				var rock = [[px0 - 1, Y], [px0 - 2, Y - H * 0.55], [px0 + 1, Y - H + 3], [px0 + 5, Y - H - 3], [px0 + 10, Y - H], [px0 + 15, Y - H * 0.7], [px0 + 16, Y]]   # a jagged spur of stone
				x.fillStyle = "#241410"
				x.beginPath()
				for i in rock.size():
					var a2: float = rock[i][0]
					var b2: float = rock[i][1]
					if i:
						x.lineTo(a2 - 0.8 * sgn(a2 - px0 - 7), b2 - 0.8)
					else:
						x.moveTo(a2 - 1, b2)
				x.closePath(); x.fill()
				x.fillStyle = "#7e7464"
				x.beginPath()
				for i in rock.size():
					if i: x.lineTo(rock[i][0], rock[i][1])
					else: x.moveTo(rock[i][0], rock[i][1])
				x.closePath(); x.fill()
				x.fillStyle = "#a89c88"
				x.beginPath()
				x.moveTo(px0 + (15 if s < 0 else 0), Y); x.lineTo(px0 + (15 if s < 0 else 1), Y - H * 0.6); x.lineTo(px0 + 5, Y - H - 2)
				x.lineTo(px0 + (11 if s < 0 else 4), Y - H * 0.5); x.lineTo(px0 + (11 if s < 0 else 4), Y)
				x.closePath(); x.fill()
				x.strokeStyle = "#4a4238"; x.lineWidth = 0.8
				x.beginPath(); x.moveTo(px0 + 7, Y - H + 4); x.lineTo(px0 + 9, Y - H * 0.6); x.lineTo(px0 + 6, Y - H * 0.35)
				x.moveTo(px0 + 3, Y - 6); x.lineTo(px0 + 8, Y - 12); x.stroke()   # cracks
				x.fillStyle = "#6cc25a"; x.fillRect(px0 + 2, Y - H * 0.5, 3, 1)
			if close >= 1 and k < 0.55:
				x.fillStyle = rgba(255, 240, 200, (0.55 - k) * 4)
				x.beginPath(); x.arc(X, Y - 20, 12, 0, TAU); x.fill()
		"fire":
			# a small volcano grows from the ground, then erupts
			var grow = minf(1, k * 3.5)
			var H = 18 * grow
			var erupt = k > 0.3
			x.globalAlpha = fade_
			x.fillStyle = "#241410"; x.beginPath(); x.moveTo(X - 18 * grow - 1, Y); x.lineTo(X - 4, Y - H - 1); x.lineTo(X + 4, Y - H - 1); x.lineTo(X + 18 * grow + 1, Y); x.closePath(); x.fill()
			x.fillStyle = "#5a3a2a"; x.beginPath(); x.moveTo(X - 18 * grow, Y); x.lineTo(X - 4, Y - H); x.lineTo(X + 4, Y - H); x.lineTo(X + 18 * grow, Y); x.closePath(); x.fill()
			x.fillStyle = "#7a5038"; x.beginPath(); x.moveTo(X - 18 * grow, Y); x.lineTo(X - 4, Y - H); x.lineTo(X - 1, Y - H); x.lineTo(X - 6 * grow, Y); x.closePath(); x.fill()
			var glow = 0.7 + 0.3 * sin(t * 30) if erupt else 0.4
			x.fillStyle = rgba(255, 140 + roundf(60 * glow), 40, glow); x.fillRect(X - 4, Y - H - 1, 8, 2)
			if erupt:
				for i in 3:
					x.strokeStyle = rgba(255, 120 + i * 40, 40, 0.8 * fade_); x.lineWidth = 1.5
					x.beginPath(); x.moveTo(X - 3 + i * 3, Y - H); x.lineTo(X - 6 + i * 6 + sin(t * 8 + i) * 4, Y - H + 6 + i * 2); x.stroke()
				var cg = x.createRadialGradient(X, Y - H, 1, X, Y - H, 26)
				cg.addColorStop(0, rgba(255, 200, 80, 0.55 * fade_)); cg.addColorStop(1, rgba(255, 120, 40, 0))
				x.fillStyle = cg
				x.beginPath(); x.arc(X, Y - H, 26, 0, TAU); x.fill()
		"light":
			# a pillar of light with a ring at its foot
			var w = 12 * (1 - k * 0.5)
			var gr = x.createLinearGradient(X - w, 0, X + w, 0)
			gr.addColorStop(0, rgba(255, 240, 180, 0)); gr.addColorStop(0.5, rgba(255, 255, 235, 0.95 * fade_)); gr.addColorStop(1, rgba(255, 240, 180, 0))
			x.fillStyle = gr
			x.fillRect(X - w, Y - 150, w * 2, 150)
			x.strokeStyle = rgba(255, 236, 160, fade_); x.lineWidth = 1.5
			x.beginPath(); x.ellipse(X, Y - 1, 8 + k * 26, 2 + k * 5, 0, 0, TAU); x.stroke()
			x.strokeStyle = rgba(255, 255, 255, fade_ * 0.8)
			x.beginPath(); x.ellipse(X, Y - 1, 4 + k * 14, 1 + k * 3, 0, 0, TAU); x.stroke()
		"dark":
			# a spiralling vortex with a hungry core
			var R0 = 30 * (1 - k * 0.4)
			for arm in 4:
				x.strokeStyle = rgba(194, 138, 255, 0.85 * fade_) if arm % 2 else rgba(90, 40, 150, 0.9 * fade_)
				x.lineWidth = 2
				x.beginPath()
				var s = 0.0
				while s <= 1.0001:
					var a = t * 7 + arm * PI / 2 + s * 4
					var r = R0 * (1 - s)
					var px0 = X + cos(a) * r
					var py0 = Y - 16 + sin(a) * r * 0.45
					if s > 0: x.lineTo(px0, py0)
					else: x.moveTo(px0, py0)
					s += 0.05
				x.stroke()
			var cg = x.createRadialGradient(X, Y - 16, 1, X, Y - 16, 12)
			cg.addColorStop(0, rgba(0, 0, 0, fade_)); cg.addColorStop(0.6, rgba(40, 10, 70, 0.9 * fade_)); cg.addColorStop(1, rgba(90, 40, 150, 0))
			x.fillStyle = cg
			x.beginPath(); x.arc(X, Y - 16, 12, 0, TAU); x.fill()
	x.restore()


func drawSpirit(x: Ctx, sx: float, sy: float) -> void:
	if not buffOn("airSpirit"):
		return
	var X = roundf(Spirit.x - sx)
	var Y = roundf(Spirit.y - sy)
	var t: float = Spirit.t
	x.fillStyle = rgba(160, 255, 224, 0.25); x.beginPath(); x.arc(X, Y, 9, 0, TAU); x.fill()
	for i in 6:
		var a = t * 6 + i / 6.0 * TAU
		var r = 5 + sin(t * 4 + i) * 1.5
		x.fillStyle = "#e8fff8" if i % 2 else "#7fffd0"
		x.fillRect(roundf(X + cos(a) * r), roundf(Y + sin(a) * r * 0.7), 2, 2)
	x.fillStyle = "#ffffff"; x.fillRect(X - 2, Y - 2, 4, 4)
	x.fillStyle = "#1a4a3a"
	x.fillRect(X - 1 + (1 if P.face > 0 else 0), Y - 1, 1, 1)
	x.fillRect(X + 1 + (1 if P.face > 0 else 0), Y - 1, 1, 1)


func drawElemSpirit(x: Ctx, sx: float, sy: float) -> void:
	if not buffOn("elemSpirit"):
		return
	var X = roundf(ESpirit.x - sx)
	var Y = roundf(ESpirit.y - sy)
	var E2: Dictionary = ELEMENTS[ESpirit.i % 4]
	var t: float = ESpirit.t
	x.fillStyle = Color(css(E2.glow), 0.33); x.beginPath(); x.arc(X, Y, 9, 0, TAU); x.fill()
	for i in 4:
		var a = t * 5 + i / 4.0 * TAU
		x.fillStyle = ELEMENTS[i].col
		x.fillRect(roundf(X + cos(a) * 6), roundf(Y + sin(a) * 4), 2, 2)
	x.fillStyle = "#ffffff"; x.fillRect(X - 2, Y - 2, 4, 4)
	x.fillStyle = E2.glow; x.fillRect(X - 1, Y - 1, 2, 2)
