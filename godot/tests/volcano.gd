extends Node
## Scripted run through Glamrax's volcano: the gate on the summit, the laboratory and its security
## (Sentinels, Security Golems, the rare Sentinel-Golem), burning and shocks, the Cell Block (Security
## Dogs, Ferro-Slimes). Saves screenshots.
## Run:  godot --path godot res://tests/volcano.tscn -- <output dir> [part]
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://volcano"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false
var keepAlive := true


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var part = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://volcano_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://volcano_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1, "warlord": 1, "dreamer": 1, "kingYeti": 1}
	game.save.keyItems = {"dreamKey": true, "yetiPendant": true}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "skip")
	add.call(1.0, "exp", 40000000)
	if part in ["all", "maps"]:
		# the summit's gate is open now
		add.call(0.1, "warp", "peak")
		add.call(2.0, "togate", "volcano1")
		add.call(0.3, "shot", "gate_open")
		add.call(0.1, "enter")
		add.call(2.4, "shot", "lab")
		add.call(0.1, "near", "sentinel")
		add.call(1.2, "shot", "sentinel")
		add.call(0.1, "mobact", ["sentinel", "laser"])
		add.call(0.5, "shot", "sentinel_aim")
		add.call(0.2, "shot", "sentinel_laser")
		add.call(0.3, "mobact", ["sentinel", "slam"])
		add.call(0.35, "shot", "sentinel_slam")
		add.call(0.6, "shot", "sentinel_slam2")
		add.call(0.6, "spawn", "secgolem")
		add.call(0.1, "near", "secgolem")
		add.call(1.0, "shot", "golem_rifles")
		add.call(0.1, "mobact", ["secgolem", "punch"])
		add.call(0.45, "shot", "golem_wind")
		add.call(0.3, "shot", "golem_punch")
		add.call(1.0, "spawn", "sentgolem")
		add.call(0.1, "near", "sentgolem")
		add.call(1.0, "shot", "sentgolem")
		add.call(0.1, "mobact", ["sentgolem", "dash"])
		add.call(0.5, "shot", "sentgolem_dash_wind")
		add.call(0.3, "shot", "sentgolem_dash")
		add.call(0.5, "shot", "sentgolem_launched")
		add.call(1.0, "mobact", ["sentgolem", "laser"])
		add.call(0.6, "shot", "sentgolem_aim")
		add.call(0.15, "shot", "sentgolem_laser")
		add.call(0.6, "clear")
		add.call(0.1, "go", 1100)
		add.call(0.6, "shot", "lab_mid")
		add.call(0.1, "go", 1700)
		add.call(0.6, "shot", "lab_far")
		# the cell block
		add.call(0.1, "warp", "volcano3")
		add.call(2.2, "shot", "cells")
		add.call(0.1, "near", "dog")
		add.call(1.0, "shot", "dog")
		add.call(0.1, "mobact", ["dog", "pounce"])
		add.call(0.6, "shot", "dog_pounce")
		add.call(0.4, "shot", "dog_pin")
		add.call(1.0, "shot", "dog_shocked")
		add.call(1.2, "clear")
		add.call(0.1, "spawn", "ferro")
		add.call(0.1, "near", "ferro")
		add.call(0.8, "shot", "ferro")
		add.call(0.1, "mobact", ["ferro", "spark"])
		add.call(0.55, "shot", "ferro_spark")
		add.call(1.4, "mobact", ["ferro", "heat"])
		add.call(1.0, "shot", "ferro_hot")
		add.call(0.1, "burn")
		add.call(0.6, "shot", "burning")
		add.call(0.1, "tap", KEY_C)
		add.call(0.3, "tap", KEY_C)
		add.call(0.3, "shot", "burn_dashed")
		add.call(0.1, "go", 1500)
		add.call(0.6, "shot", "cells_far")
		add.call(0.1, "warp", "volcano4")
		add.call(2.2, "shot", "sanctum")
	add.call(0.1, "links")
	add.call(0.1, "reload")
	add.call(0.2, "quit")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _boss():
	for e in game.slimes:
		if e.boss:
			return e
	return null


func _mob(type: String):
	for e in game.slimes:
		if e.type == type and e.state != "dead":
			return e
	return null


func _process(delta: float) -> void:
	t += delta
	if keepAlive and game.P != null and game.P.state != "dead" and game.PS is Dictionary and game.PS.has("hp"):
		game.P.hp = maxf(game.P.hp, game.PS.hp * 0.6)
	while not busy and steps.size() and steps[0][0] <= t:
		var s: Array = steps.pop_front()
		match s[1]:
			"shot":
				busy = true
				_shot(s[2])
				break
			"pick":
				game.selClass = s[2]
			"tap":
				key(s[2], true)
				var code = s[2]
				get_tree().create_timer(0.05).timeout.connect(func(): key(code, false))
			"skip":
				if game.intro != null:
					game.introSkip()
			"warp":
				game.fadeTo = {"map": s[2]}
			"exp":
				game.gainExp(s[2])
				game.save.settings.god = false
				print("level ", game.CH().level)
			"togate":
				var g = null
				for p in game.M.portals:
					if p.to == s[2]:
						g = p
				print("portal to %s: %s" % [s[2], g != null])
				if g != null:
					game.P.x = g.x
					game.P.y = g.get("y", game.groundAt(g.x))
					game.P.vy = 0
					game.P.iframes = 1.5
			"enter":
				var g = game.portalAt()
				print("enter portal: ", g.to if g != null else "none")
				if g != null:
					game.travel(g)
			"spawn":
				var tries = 0
				while _mob(s[2]) == null and tries < 400:
					tries += 1
					game.spawnAbyssMob(s[2], game.SLIME_TYPES[s[2]], true, false)
				print("spawn %s: %s" % [s[2], _mob(s[2]) != null])
			"clear":
				for e in game.slimes:
					if not e.boss:
						e.state = "dead"
				game.P.held = null
				game.P.state = "move"
				game.Burn.t = 0
			"near":
				var e = _mob(s[2])
				print("near %s: %s" % [s[2], e != null])
				for q in game.slimes:
					if q != e and not q.boss:
						q.state = "dead"
				if e != null:
					e.x = clampf(game.P.x + 90, 40, game.M.w - 40)
					e.y = game.groundAt(e.x) - (30 if e.T.get("fly") else 0)
					e.vy = 0
					e.homeX = e.x
					e.homeY = e.y
					e.aggro = true
					e.state = "chase"
					e.atkCd = 9
					e.data.cd2 = 9
					game.P.face = 1
			"mobact":
				var e = _mob(s[2][0])
				if e != null:
					game.P.held = null
					game.P.iframes = 0
					game.P.state = "move"
					e.x = clampf(game.P.x + {"dash": 160, "pounce": 90, "laser": 110}.get(s[2][1], 50), 40, game.M.w - 40)
					if not e.T.get("fly"):
						e.y = game.groundAt(e.x)
					e.face = -1
					e.move = s[2][1]
					e.atkCd = 9
					e.data.laserCd = 99
					e.data.dashCd = 99
					e.data.heatCd = 99
					e.data.aim = Vector2(game.P.x, game.P.y - 22)
					e.data.n = 0
					e.state = "act" if s[2][1] == "slam" else "wind"
					e.t = 0
					e.hitDone = false
					print("mobact ", s[2])
			"burn":
				game.ignite({"atk": 370, "lv": 104})
			"links":
				var bad = []
				for id in game.MAPS:
					for p in game.MAPS[id].get("portals", []):
						if not game.MAPS.has(p.to):
							bad.append("%s -> %s (missing)" % [id, p.to])
						elif not game.MAPS[p.to].get("portals", []).any(func(q): return q.to == id):
							bad.append("%s -> %s (one-way)" % [id, p.to])
				print("portal links: ", bad if bad.size() else "all two-way")
			"reload":
				game.persist()
				var sv = game.loadSave()
				print("reloaded: trophies=%s" % [sv.trophies])
			"go":
				game.P.x = s[2]
				game.P.y = game.groundAt(s[2])
				game.P.vy = 0
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	var b = _boss()
	print("shot %s map=%s state=%s pos=%.0f,%.0f hp=%d/%d held=%s mobs=%d boss=%s burn=%.1f" % [name, game.mapId, P.state, P.x, P.y, P.hp, game.PS.hp,
		P.held.kind if P.held != null else "-", game.slimes.size(), ("%s %d/%d" % [b.state, b.hp, b.maxHp]) if b != null else "-", game.Burn.t])
	busy = false
