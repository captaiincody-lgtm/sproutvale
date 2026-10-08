extends "res://scripts/core.gd"
## Sproutvale, part 2: maps and travel, ropes, portals, the pond's water, weather and time of day,
## and the camera.


# ================================================================ maps

## each hero has their own home: Rock's cottage, the archer's treehouse, Remy's burrow, Jojo's place
func configureHome(cls: String) -> void:
	var V: Dictionary = HOME_VARIANTS.get(cls, HOME_VARIANTS.rock)
	MAPS.home.merge(V.home.duplicate(true), true)
	MAPS.house.merge(V.house.duplicate(true), true)
	MAPS.trophy.portals[0].tx = 330


## surfaces slimes (and drops) can stand on: the floor plus every platform
func surfacesOf(m: Dictionary) -> Array:
	var s = []
	if m.get("floor"):
		# the Abyss: the ground comes in pieces, stepping down into the deep
		var sea = m.get("sea")
		for f in m.floor:
			var wet: bool = sea != null and f[0] >= sea.x0 - 1 and (sea.surface == null or f[2] > sea.surface)
			s.append({"x0": float(f[0]), "x1": float(f[1]), "y": float(f[2]), "floor": true, "water": false, "sea": wet})
	elif m.get("pond"):
		var p: Dictionary = m.pond
		s.append({"x0": 20.0, "x1": float(p.x0), "y": float(m.floorY), "floor": true, "water": false})
		s.append({"x0": float(p.x1), "x1": m.w - 20.0, "y": float(m.floorY), "floor": true, "water": false})
		s.append({"x0": p.x0 + 2.0, "x1": p.x1 - 2.0, "y": float(p.bottom), "floor": true, "water": true})
	else:
		s.append({"x0": 20.0, "x1": m.w - 20.0, "y": float(m.floorY), "floor": true, "water": false})
	for pl in m.plats:
		s.append({"x0": float(pl[0]), "x1": float(pl[0] + pl[2]), "y": float(pl[1]), "floor": false, "water": false})
	return s


## the painted map for the current map (homes and houses differ per hero)
func mapArt() -> String:
	if mapId == "home" or mapId == "house":
		return "maps/%s_%s.png" % [mapId, M.get("variant", "rock")]
	return "maps/%s.png" % mapId


func loadMap(id: String, px0 = null, py0 = null) -> void:
	if id == "home" or id == "house":
		configureHome(classId)
	if id == "lair" and save.trophies.get("croc") and not MAPS.lair.portals.any(func(p): return p.to == "crimson1"):
		MAPS.lair.portals.append({"x": MAPS.lair.w - 40, "to": "crimson1", "tx": 70, "label": "The Crimson Wastes"})
	if id == "crimson5" and save.trophies.get("warlord"):
		openDreamGate()
	# a boss box left lying on the floor isn't lost: it opens as you leave
	var unopened = []
	for d in drops:
		if d.kind == "box":
			unopened.append(d.type)
	loot = null
	pVials.clear(); pPuddles.clear(); PRain.t = 0.0
	mapId = id
	M = MAPS[id]
	save.settings.map = id
	saveDirty = true
	surfaces = surfacesOf(M)
	tufts.clear()
	for s in surfaces:
		if s.water or M.get("indoor") or M.get("floor") or M.get("theme") == "bubble" or (M.get("tree") and not s.floor):
			continue
		var x: float = s.x0 + 3
		while x < s.x1 - 3:
			var fg = hsh(x * 5.3 + s.y) > 0.8
			tufts.append({"x": x, "y": s.y, "h": (4 + floorf(hsh(x * 3) * 4)) if fg else (2 + floorf(hsh(x * 3) * 3)), "p": hsh(x * 7) * 6, "fg": fg})
			x += 5 + floorf(hsh(x) * 5)
	slimes.clear(); drops.clear(); parts.clear(); floaters.clear(); footprints.clear()
	P.x = float(px0) if px0 != null else float(M.start)
	P.y = float(py0) if py0 else float(M.floorY)
	P.vx = 0; P.vy = 0
	P.state = "move"
	P.surf = null
	for s in surfaces:
		if absf(s.y - P.y) < 1 and P.x >= s.x0 and P.x <= s.x1:
			P.surf = s
			break
	P.grounded = P.surf != null
	P.rope = null
	thought = null
	for i in M.target:
		spawnSlime(true)
	cam.x = clampf(P.x - VW / 2.0, 0, M.w - VW)
	cam.y = clampf(P.y - VH * 0.66, 0, M.h - VH)
	initWater()
	bossRocks.clear()
	if classId == "summoner":
		resetPets()
	bossVials.clear(); puddles.clear()
	resetObelisk()
	if inGame:
		Sfx.music(M.get("music", id))
	advanceMain(id)
	arrows.clear()
	P.juggle = null
	P.frozen = false
	scene = null
	if M.get("boss"):
		P.face = 1   # arenas: you always walk in facing the boss
	var bk = M.boss if M.get("boss") in ["warlord", "dreamer"] else "croc"
	M.pedestal = {"x": roundi(M.w * (0.55 if bk == "croc" else 0.5)), "kind": bk} if M.get("boss") and save.trophies.get(bk) else null
	abyssOnLoad()
	if M.get("boss") and not M.pedestal:
		if M.boss == "warlord":
			spawnWarlord()
		elif M.boss == "dreamer":
			spawnDreamer()
		else:
			spawnBoss()
	if inGame and not M.get("boss"):
		banner(M.name, M.get("sub", "Tougher slimes live here" if M.get("lvBonus") else "Starter area"))
	for k in unopened:
		later(0.6, func(): openBox(k))


func travel(portal: Dictionary) -> void:
	if fadeTo != null:
		return
	if portal.get("sealed") or not MAPS.has(portal.to):
		toast("The portal hums, but something on the other side is still asleep. It won't let you through yet.")
		Sfx.tone(180, 0.3, "sine", 0.08, 120)
		return
	fadeTo = {"map": portal.to, "x": portal.tx, "y": portal.get("ty")}
	Sfx.tone(520, 0.25, "sine", 0.12, 980)


func travelHome() -> void:
	if fadeTo != null or mapId == "home":
		return
	fadeTo = {"map": "home", "x": null}
	Sfx.tone(520, 0.25, "sine", 0.12, 980)


func onSurface():
	for s in surfaces:
		if P.x >= s.x0 - 2 and P.x <= s.x1 + 2 and absf(P.y - s.y) < 1:
			return s
	return null


func ropeAt():
	for r in M.ropes:
		if absf(P.x - r[0]) < 11 and P.y > r[1] - 2 and P.y - 30 < r[2]:
			return {"x": float(r[0]), "y0": float(r[1]), "y1": float(r[2])}
	return null


func portalAt():
	for p in M.portals:
		if absf(P.x - p.x) < 16 and absf(P.y - p.get("y", M.floorY)) < 2:
			return p
	return null


func noteAt():
	for n in M.get("notes", []):
		if absf(P.x - n.x) < 16 and absf(P.y - n.y) < 2:
			return n
	return null


## the boss pedestal: a beaten boss can be called back for another fight
func pedestalAt():
	var pd = M.get("pedestal")
	if pd == null or slimes.any(func(e): return e.boss and e.state != "dead"):
		return null
	return pd if absf(P.x - pd.x) < 22 and absf(P.y - M.floorY) < 3 else null


func obeliskAt():
	return obelisk if obelisk != null and not obelisk.used and absf(P.x - obelisk.x) < 18 and absf(P.y - obelisk.y) < 2 else null


# ================================================================ the pond

## the water on this map: the pond, or the Abyss's sea ({x0, x1, surface}; surface -1e9 when the whole map is underwater)
func waterBox():
	if M.is_empty():
		return null
	if M.get("pond") != null:
		return M.pond
	var sea = M.get("sea")
	if sea == null:
		return null
	return {"x0": sea.x0, "x1": sea.x1, "surface": sea.surface if sea.surface != null else -1e9, "sea": true}


## the height of the ground at x (the Abyss maps step down; everywhere else it's the floor)
func groundAt(x: float) -> float:
	var fl = M.get("floor")
	if not fl:
		return float(M.floorY)
	var g = INF
	for f in fl:
		if x >= f[0] - 0.5 and x <= f[1] + 0.5:
			g = minf(g, f[2])
	if g == INF:
		return float(fl[0][2]) if x < fl[0][0] else float(fl[-1][2])
	return g


func inWater() -> bool:
	var W = waterBox()
	return W != null and P.x > W.x0 and P.x < W.x1 and P.y - 4 > W.surface


func initWater() -> void:
	Water.cols = []
	Water.vel = []
	var W = waterBox()
	if W == null or W.surface < -1e8:
		return
	Water.x0 = float(W.x0)
	var n = ceili((W.x1 - W.x0) / Water.step) + 1
	for i in n:
		Water.cols.append(0.0)
		Water.vel.append(0.0)


func splash(x: float, k: float) -> void:
	var W = waterBox()
	if W == null or W.surface < -1e8:
		return
	var i = roundi((x - Water.x0) / Water.step)
	for d in range(-3, 4):
		var j = i + d
		if j >= 0 and j < Water.vel.size():
			Water.vel[j] += (1.0 if d == 0 else 0.5) * k * 90
	var y: float = W.surface
	var dark: bool = W.get("sea", false)
	for n in int(10 + k * 10):
		part(x + rand(-6, 6), y - 1, rand(-70, 70) * (0.5 + k * 0.5), rand(-200, -60) * (0.6 + k * 0.4), rand(0.35, 0.7), ("#8a5aa8" if n % 3 else "#d8b8f0") if dark else ("#cfeaff" if n % 3 else "#ffffff"), 700, 1 if n % 4 else 2, y)
	Sfx.play("splash", 0.8 + k * 0.35)


func updateWater(dt: float) -> void:
	var W = waterBox()
	if W == null or Water.cols.is_empty():
		return
	var c: Array = Water.cols
	var v: Array = Water.vel
	var n = c.size()
	for i in n:
		v[i] += (-60 * c[i] - 2.4 * v[i]) * dt
	for pass_i in 2:
		for i in n:
			var l: float = c[i - 1] if i > 0 else c[i]
			var r: float = c[i + 1] if i < n - 1 else c[i]
			v[i] += (l + r - 2 * c[i]) * 40 * dt
	for i in n:
		c[i] += v[i] * dt
	# gentle ambient ripples from wind, and rain pocking the surface
	if randf() < dt * (1 + World.wind * 3):
		v[rint(0, n - 1)] += rand(-8, 8) * (0.4 + World.wind)
	if World.rain > 0.3:
		for k in ceili(World.rain * 2):
			if randf() < 0.5:
				v[rint(0, n - 1)] += rand(4, 10)
	# swimmers stir the water
	if inWater() and absf(P.vx) > 20 and absf(P.y - 30 - W.surface) < 20:
		var i = roundi((P.x - Water.x0) / Water.step)
		if i > 0 and i < n:
			v[i] += P.vx * 0.02


# ================================================================ weather and the time of day

func setWeather(w: String, announce: bool) -> void:
	if World.weather == w:
		return
	World.weather = w
	World.wTimer = rand(90, 170)
	if announce:
		toast({"sunny": "The clouds part. Sunshine!", "cloudy": "Clouds roll in.", "rain": "Rain starts to fall.", "thunderstorm": "Thunder rumbles. A storm is coming!", "snow": "Snowflakes drift down…"}[w])


func updateWorld(dt: float) -> void:
	var St: Dictionary = save.settings
	World.t = fmod(World.t + dt / 480.0 * St.timeSpeed, 1.0)
	if St.weather != "auto":
		setWeather(St.weather, false)
	else:
		World.wTimer -= dt
		if World.wTimer <= 0:
			var opts = WEATHERS.keys().filter(func(k): return k != World.weather)
			setWeather(opts[rint(0, opts.size() - 1)], true)
	var tg: Dictionary = W_PARAMS[World.weather]
	var k = 1.0 - exp(-dt * 0.4)
	World.cloud += (tg.cloud - World.cloud) * k
	var ready: bool = World.cloud > 0.82   # rain and storms wait for the clouds to gather
	for key in ["rain", "snow", "storm"]:
		World[key] += ((tg[key] if key == "snow" or ready else 0.0) - World[key]) * k
	World.wind += (tg.wind * (1 + sin(realTime * 1000 / 2300.0) * 0.35) - World.wind) * k
	if World.snow > 0.4:
		World.snowCover = minf(1, World.snowCover + dt * 0.012 * World.snow)
	else:
		World.snowCover = maxf(0, World.snowCover - dt * 0.01)
	World.flash = maxf(0, World.flash - dt * 3)
	if World.storm > 0.5:
		World.nextBolt -= dt
		if World.nextBolt <= 0:
			World.nextBolt = rand(4, 10)
			World.flash = 1.0
			World.bolt = {"x": rand(20, VW - 20), "t": 0.25}
			later(rand(0.3, 1.3), func(): Sfx.thunder())
	if World.bolt != null:
		World.bolt.t -= dt
		if World.bolt.t <= 0:
			World.bolt = null
	World.ambT -= dt
	if World.ambT <= 0:
		World.ambT = 0.3
		var outdoors: bool = inGame and not M.get("indoor") and not (M.get("theme") in ["crimson", "abyss", "bubble"])
		Sfx.ambience(minf(1.3, World.rain) if outdoors else 0.0, minf(1.5, World.wind) if outdoors else 0.0)


func dayInfo() -> Dictionary:
	var a = (float(World.t) - 0.25) * TAU
	var sunY = sin(a)
	return {"sunY": sunY, "day": clampf((sunY + 0.12) / 0.34, 0, 1), "dusk": exp(-pow(sunY / 0.2, 2)), "sunX": cos(a)}


func updateCamera(dt: float) -> void:
	var tx = clampf(P.x - VW / 2.0 + P.face * 36, 0, M.w - VW)
	var ty = clampf(P.y - VH * 0.64, 0, M.h - VH)
	cam.x = damp(cam.x, tx, 6, dt)
	cam.y = damp(cam.y, ty, 5, dt)
