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
var gQuiet := false


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
	add.call(1.0, "exp", int(OS.get_environment("VOLC_EXP")) if OS.get_environment("VOLC_EXP") != "" else 40000000)
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
	if part == "glamrax":
		add.call(0.1, "warp", "volcano4")
		add.call(1.5, "shot", "g_pan1")
		add.call(2.5, "shot", "g_pan2")
		add.call(0.1, "waitbeat", "stop")
		add.call(0.3, "shot", "g_stop")
		add.call(0.1, "waitbeat", "talk")
		add.call(0.6, "shot", "g_talk")
		for i in 4:
			add.call(0.3, "tap", KEY_Z)
		add.call(0.1, "waitbeat", "rise")
		add.call(1.2, "shot", "g_rise")
		add.call(0.1, "waitbeat", "kin")
		add.call(1.4, "shot", "g_kin")
		add.call(0.1, "waitbeat", "hero")
		add.call(0.6, "shot", "g_frown")
		add.call(1.0, "shot", "g_reply")
		for i in 4:
			add.call(0.3, "tap", KEY_Z)
		add.call(0.1, "waitbeat", "")
		add.call(0.6, "shot", "g_fight")
		add.call(0.1, "gquiet", true)
		for sp in ["chain", "fire", "meteor", "wave", "tornado", "firenado", "ice", "pillars", "sky"]:
			add.call(1.6, "gcast", sp)
			add.call(0.5, "shot", "s_%s_a" % sp)
			add.call(0.5, "shot", "s_%s_b" % sp)
		add.call(1.2, "gcast", "orb")
		add.call(0.4, "shot", "orb")
		add.call(0.1, "reflect", 0)
		add.call(0.3, "shot", "orb_back")
		add.call(0.6, "shot", "orb_swatted")
		add.call(0.1, "reflect", 9)
		add.call(0.6, "shot", "orb_through")
		add.call(0.6, "shot", "stunned")
		add.call(0.1, "god", true)
		add.call(3.0, "bosshp", 0.74)
		add.call(0.1, "gquiet", false)
		add.call(1.2, "shot", "summon")
		add.call(1.6, "shot", "demon")
		add.call(1.0, "shot", "demon2")
		add.call(0.1, "clear")
		add.call(0.1, "bosshp", 0.49)
		add.call(1.4, "shot", "shield")
		add.call(0.1, "bosshp", 0.24)
		add.call(0.8, "shot", "shed")
		add.call(1.6, "shot", "shed2")
		add.call(1.2, "shot", "brawl")
		add.call(0.6, "shot", "brawl2")
		add.call(0.1, "bosshp", 0.09)
		add.call(0.8, "shot", "horns")
		add.call(1.6, "shot", "horns2")
		add.call(0.5, "shot", "brawl3")
		add.call(0.5, "shot", "brawl4")
		add.call(0.1, "killboss")
		add.call(0.6, "shot", "fallen")
		add.call(2.4, "shot", "lying")
		add.call(1.6, "shot", "end1")
		add.call(0.1, "tap", KEY_ENTER)
		add.call(0.3, "tap", KEY_ENTER)
		add.call(1.0, "shot", "end2")
		add.call(3.0, "shot", "end2_fade")
		add.call(2.4, "shot", "laugh1")
		add.call(1.5, "shot", "laugh2")
		add.call(0.1, "waitintro")
		add.call(1.0, "shot", "select")
		add.call(0.1, "tap", KEY_RIGHT)
		add.call(0.5, "shot", "select2")
	if part == "slam":
		add.call(0.1, "warp", "volcano2")
		add.call(1.6, "go", 200)
		add.call(3.0, "bossact", ["slam", "crouch"])
		for i in 34:
			add.call(0.1, "shot", "slam%d" % i)
	if part in ["all", "mk2"]:
		add.call(0.1, "warp", "volcano2")
		add.call(1.6, "shot", "bay_hang")
		add.call(0.1, "go", 200)
		add.call(1.4, "shot", "mk2_drop")
		add.call(0.8, "shot", "mk2_landed")
		add.call(1.2, "shot", "mk2_rifle")
		add.call(0.1, "keep", false)
		add.call(0.1, "bossact", ["kick", ""])
		add.call(0.35, "shot", "kick_wind")
		add.call(0.22, "shot", "kick_hit")
		add.call(0.2, "shot", "kick_wall")
		add.call(0.3, "shot", "kick_catch")
		add.call(0.5, "shot", "kick_shoot")
		add.call(0.75, "shot", "kick_nade")
		add.call(0.6, "shot", "kick_lift")
		add.call(0.35, "shot", "kick_smash")
		add.call(0.1, "keep", true)
		add.call(1.6, "bossact", ["slam", "crouch"])
		add.call(0.6, "shot", "slam_rise")
		add.call(0.35, "shot", "slam_dive")
		add.call(0.3, "shot", "slam_launched")
		add.call(0.35, "shot", "slam_punch")
		add.call(1.8, "bossact", ["bash", ""])
		add.call(0.4, "shot", "bash_wind")
		add.call(0.3, "shot", "bash")
		add.call(1.2, "bossact", ["punch", ""])
		add.call(0.5, "shot", "punch")
		add.call(1.0, "bossact", ["fly", "up"])
		add.call(1.5, "shot", "fly")
		add.call(0.6, "nade")
		add.call(0.5, "shot", "nade")
		add.call(0.45, "shot", "nade_boom")
		add.call(1.6, "bosshp", 0.48)
		add.call(0.1, "bossact", ["transform", ""])
		add.call(0.8, "shot", "transform")
		add.call(1.0, "shot", "blades")
		add.call(0.2, "bossact", ["slash", ""])
		add.call(0.3, "shot", "slash1")
		add.call(0.42, "shot", "slash2")
		add.call(0.42, "shot", "slash3")
		add.call(1.0, "bosshp", 0.18)
		add.call(0.1, "bossact", ["deploy", ""])
		add.call(0.9, "shot", "deploy")
		add.call(2.0, "shot", "drone")
		add.call(1.0, "shot", "drone_aim")
		add.call(1.0, "killboss")
		add.call(0.8, "shot", "mk2_dying")
		add.call(1.4, "shot", "mk2_dead")
		add.call(1.4, "shot", "mk2_box")
		add.call(1.6, "shot", "bay_after")
		add.call(0.1, "togate", "volcano3")
		add.call(0.1, "enter")
		add.call(2.0, "shot", "through_gate")
		add.call(0.1, "warp", "volcano2")
		add.call(2.0, "go", 300)
		add.call(0.3, "shot", "pedestal")
		add.call(0.1, "summon")
		add.call(1.6, "shot", "resummoned")
		add.call(0.1, "killboss")
		add.call(0.1, "skill", "laserDrone")
		add.call(1.5, "shot", "hero_drone")
		add.call(0.1, "opencard", "mk2")
		add.call(0.1, "warp", "trophy")
		add.call(2.0, "go", 296)
		add.call(0.5, "shot", "trophy_mk2")
		add.call(0.1, "warp", "volcano1")
		add.call(2.0, "go", 2070)
		add.call(0.6, "shot", "boss_sign")
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
	if gQuiet:
		var gb = _boss()
		if gb != null and gb.get("bossKind") == "glamrax":
			gb.data.cd = 99.0
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
				if game.intro != null and not str(game.intro.get("scenes", [{}])[0].get("kind", "")).begins_with("g_"):
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
			"waitbeat", "waitintro":
				var orig: float = s[3] if s.size() > 3 else s[0]
				var waiting = game.GX.get("beat", "") != s[2] if s[1] == "waitbeat" else game.intro != null
				if waiting and t - orig < 60:
					if s[1] == "waitbeat" and game.scene != null:
						game.pressed["z"] = true   # keep a dialogue moving
					steps.push_front([t + 0.1, s[1], s[2], orig])
					break
				for q in steps:   # everything after waits as long as this did
					q[0] += t - orig
				print("%s %s after %.1fs" % [s[1], s[2], t - orig])
				if s[1] == "waitintro":
					print("captured: ", game.save.get("captured"), " sel ", game.selClass)
			"god":
				game.save.settings.god = s[2]
			"gquiet":
				gQuiet = s[2]
			"gcast":
				var e = _boss()
				if e != null:
					game.P.held = null
					game.P.iframes = 0
					game.P.state = "move"
					e.data.spell = ""
					game._gxCast(e, s[2])
					print("cast ", s[2], " spells ", game.gSpells.size())
			"reflect":
				for q in game.slimes:
					if q.get("bossPart") and q.data.get("kind") == "orb":
						q.data.n = s[2]
						game.damagePart(q, {})
						print("reflected, to=", q.data.to)
			"keep":
				keepAlive = s[2]
				print("hp before: %d / %d" % [game.P.hp, game.PS.hp])
			"bossact":
				var e = _boss()
				if e != null:
					game.P.held = null
					game.P.iframes = 0
					game.P.state = "move"
					game.P.spin = 0
					e.state = "fight"
					var D = e.data
					for k in ["actCd", "kickCd", "slamCd", "bashCd", "flyCd"]:
						D[k] = 99
					D.nadeT = 99
					e.x = clampf(game.P.x + {"kick": 60, "punch": 70, "slash": 80, "bash": 200, "fly": 120}.get(s[2][0], 120), 60, game.M.w - 60)
					if game.P.x > game.M.w - 150:
						e.x = game.P.x - 70
					e.face = int(signf(game.P.x - e.x))
					e.y = game.groundAt(e.x)
					e.vx = 0; e.vy = 0
					D.boots = 0.0
					game._mk2Act(e, s[2][0], s[2][1])
					print("bossact ", s[2], " at ", e.x, " p ", game.P.x)
			"bosshp":
				var e = _boss()
				if e != null:
					e.hp = e.maxHp * s[2]
			"nade":
				var e = _boss()
				if e != null:
					game._mk2Nade(e, game.P.x)
			"killboss":
				var e = _boss()
				if e != null and e.state != "dead":
					e.hp = 1
					game.damageSlime(e, {"dmg": 50.0})
			"summon":
				if game.M.get("pedestal"):
					game.summonFromPedestal()
				print("summon: ", _boss() != null)
			"skill":
				game.CH().skills[s[2]] = 1
				game.castBossSkill(game.SKILL[s[2]])
				for i in 3:
					game.spawnAbyssMob("sentinel", game.SLIME_TYPES.sentinel, true, false)
			"opencard":
				print("monsterName: ", game.monsterName(s[2]), " box ", game.BOXES[s[2]].name)
				game.collectBox(s[2], 3)
				print("boxes: ", game.save.boxes)
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
		P.held.kind if P.held != null else "-", game.slimes.size(), ("%s %d/%d %s/%s y=%.0f x=%.0f" % [b.state, b.hp, b.maxHp, b.data.get("act", ""), b.data.get("ph", ""), b.y, b.x]) if b != null else "-", game.Burn.t])
	busy = false
