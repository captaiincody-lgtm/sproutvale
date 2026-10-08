extends Node
## Scripted run up the volcano: out of the bubble, the four climb maps and their monsters, King Yeti's
## intro, his attacks (sword throw and impale, the grab and stalactite, the free sword and boulders),
## his death and the cave-in, the pendant's portal to Glamrax's Gate, the collapsed throne room and the
## pedestal, the Yetibox and its skill, Teleport Home, and the menus. Saves screenshots.
## Run:  godot --path godot res://tests/climb.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://climb"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false
var keepAlive := true


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://climb_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://climb_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1, "warlord": 1, "dreamer": 1}
	game.save.keyItems = {"dreamKey": true}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "skip")
	add.call(1.0, "exp", 9000000)
	# out of the bubble
	add.call(0.1, "warp", "bubble")
	add.call(2.0, "togate", "climb1")
	add.call(0.3, "shot", "bubble_exit")
	add.call(0.1, "enter")
	# Map 1: cold rock
	add.call(2.2, "shot", "climb1")
	add.call(0.1, "near", "boulder")
	add.call(1.4, "shot", "boulder")
	add.call(1.4, "shot", "boulder2")
	add.call(0.1, "near", "lizard")
	add.call(1.0, "shot", "lizard")
	add.call(1.0, "shot", "lizard2")
	add.call(0.1, "walk", 1.2)
	add.call(1.4, "shot", "climb1_walk")
	add.call(0.1, "go", 1100)
	add.call(0.6, "shot", "climb1_mid")
	add.call(0.1, "togate", "climb2")
	add.call(0.3, "shot", "climb1_end")
	add.call(0.1, "enter")
	# Map 2: blizzard
	add.call(2.2, "shot", "climb2")
	add.call(0.1, "near", "golem")
	add.call(1.6, "shot", "golem")
	add.call(1.0, "shot", "golem2")
	add.call(0.1, "near", "warlock")
	add.call(1.4, "shot", "warlock")
	add.call(1.2, "shot", "warlock2")
	add.call(0.1, "togate", "climb3")
	add.call(0.4, "shot", "cave_mouth")
	add.call(0.1, "enter")
	# Map 3: the cave
	add.call(2.2, "shot", "climb3")
	add.call(0.1, "near", "yeti")
	add.call(1.4, "shot", "cyeti")
	add.call(1.4, "shot", "cyeti2")
	add.call(0.1, "near", "sword")
	add.call(1.0, "shot", "esword")
	add.call(0.8, "shot", "esword2")
	add.call(0.1, "elite")
	add.call(0.8, "shot", "elite")
	add.call(0.1, "go", 1660)
	add.call(0.5, "shot", "boss_sign")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "map")
	add.call(0.5, "shot", "world_map")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "togate", "climb4")
	add.call(0.1, "enter")
	# Map 4: King Yeti
	add.call(1.6, "shot", "throne")
	add.call(1.4, "shot", "rise")
	add.call(0.6, "shot", "dialog1")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.6, "shot", "sword_rises")
	add.call(0.6, "shot", "sword_flies")
	add.call(0.6, "shot", "dialog2")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.6, "shot", "roar")
	add.call(1.0, "act", ["swing", 140])
	add.call(0.5, "shot", "swing")
	add.call(0.8, "act", ["throw", 200])
	add.call(0.35, "shot", "throw")
	add.call(0.3, "shot", "impaled")
	add.call(0.9, "shot", "rip")
	add.call(1.6, "calm")
	add.call(0.1, "act", ["grab", 50])
	add.call(0.6, "shot", "grab")
	add.call(0.8, "shot", "slams")
	add.call(1.2, "shot", "fling")
	add.call(0.8, "shot", "stalactite")
	add.call(1.2, "shot", "fallen")
	add.call(1.4, "calm")
	add.call(0.1, "enrage")
	add.call(0.8, "shot", "enrage")
	add.call(1.0, "shot", "free_sword")
	add.call(0.1, "act", ["boulders", 200])
	add.call(0.8, "shot", "boulders")
	add.call(0.8, "shot", "boulders2")
	add.call(0.5, "act", ["punch", 50])
	add.call(0.4, "shot", "punch")
	add.call(0.6, "killboss")
	add.call(0.6, "shot", "kneel")
	add.call(1.0, "shot", "slam")
	add.call(0.8, "shot", "cave_in")
	add.call(1.9, "shot", "pendant")
	add.call(1.6, "shot", "portal")
	add.call(1.7, "shot", "leap")
	add.call(1.8, "shot", "peak")
	add.call(2.0, "shot", "peak2")
	add.call(0.1, "walk", 2.0)
	add.call(2.2, "shot", "peak_walk")
	add.call(0.1, "togate", "glamrax")
	add.call(0.3, "shot", "glamrax_gate")
	add.call(0.1, "enter")
	add.call(0.5, "shot", "glamrax_sealed")
	# back down: the collapsed throne room and the pedestal
	add.call(0.1, "togate", "climb4")
	add.call(0.1, "enter")
	add.call(2.2, "shot", "ruin")
	add.call(0.1, "summon")
	add.call(2.2, "shot", "resummon")
	add.call(0.1, "killboss")
	add.call(2.4, "shot", "refight_dies")
	add.call(0.1, "tobox")
	add.call(0.6, "shot", "yetibox")
	# the Yetibox, opened from the bag, and its skill
	add.call(0.1, "farm")
	add.call(2.6, "shot", "yetibox_skill")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.1, "warp", "climb1")
	add.call(2.0, "skill", "swordThrow")
	add.call(0.3, "shot", "blade_out")
	add.call(0.5, "shot", "blade_back")
	# Teleport Home from the menu
	add.call(0.4, "tap", KEY_ESCAPE)
	add.call(0.4, "shot", "menu_home")
	add.call(0.1, "home")
	add.call(2.2, "shot", "home")
	# menus
	add.call(0.1, "cards")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "bestiary")
	add.call(0.1, "scroll", 6000)
	add.call(0.4, "shot", "bestiary_climb")
	add.call(0.1, "scroll", 3000)
	add.call(0.4, "shot", "bestiary_yeti")
	add.call(0.1, "tab", "inv")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "inv_key")
	add.call(0.1, "tab", "char")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "char_treasures")
	add.call(0.1, "tab", "map")
	add.call(0.4, "shot", "world_map_all")
	add.call(0.1, "tab", "quests")
	add.call(0.3, "shot", "quests")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "warp", "trophy")
	add.call(1.6, "go", 200)
	add.call(0.4, "shot", "trophy_stand")
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
			"near":
				var e = _mob(s[2])
				print("near %s: %s" % [s[2], e != null])
				if e != null:
					e.x = clampf(game.P.x + 80, 40, game.M.w - 40)
					e.y = game.groundAt(e.x) - (30 if e.T.get("fly") else 0)
					e.vy = 0
					e.homeX = e.x
					e.homeY = e.y
					e.aggro = true
					game.P.face = 1
			"go":
				game.P.x = s[2]
				game.P.y = game.groundAt(s[2])
				game.P.vy = 0
			"walk":
				key(KEY_RIGHT, true)
				get_tree().create_timer(s[2]).timeout.connect(func(): key(KEY_RIGHT, false))
			"elite":
				var e = _mob("sword")
				if e != null:
					game.abyssElite(e)
					print("elite %s size %.0fx%.0f" % [e.type, e.w, e.h])
			"act":
				var b = _boss()
				if b != null:
					game.P.held = null
					game.P.iframes = 0
					game.P.x = b.x - s[2][1]
					game.P.y = game.groundAt(game.P.x)
					game.P.face = 1
					b.face = -1
					b.data.cd = 99.0
					if s[2][0] == "throw":
						b.data.throwCd = 0
					game._yAct(b, s[2][0])
					print("act ", s[2][0])
			"calm":
				var b = _boss()
				if b != null:
					b.data.act = ""
					b.data.cd = 99.0
					b.data.grabCd = 99.0
					b.data.throwCd = 99.0
					b.data.boulderCd = 99.0
			"enrage":
				var b = _boss()
				if b != null:
					b.hp = b.maxHp * 0.29
					b.data.cd = 0.5
			"killboss":
				var b = _boss()
				print("boss: ", b != null)
				if b != null:
					game.P.held = null
					game.P.x = clampf(b.x - 120, 40, game.M.w - 40) if b.x > 200 else b.x + 120
					game.P.y = game.groundAt(game.P.x)
					game.P.face = 1
					b.hp = 1
					game.damageSlime(b, {"dmg": 1.0, "id": "test%d" % shots})
					print("boss state after hit: ", b.state)
			"tobox":
				var found = false
				for d in game.drops:
					if d.kind == "box":
						game.P.x = d.x
						game.P.y = game.groundAt(d.x)
						found = true
				print("box on floor: ", found, " key items: ", game.save.get("keyItems", {}))
			"farm":
				var n = 0
				while game.skillRank("swordThrow") == 0 and n < 3000:
					n += 1
					game.collectBox("kingYeti")
					game.openBoxes("kingYeti", 1)
				game.collectBox("kingYeti", 3)
				print("boxes until Impaling Blade: %d, boons: %s, binds: %s" % [n, game.CH().get("boons"), game.CH().binds])
				game.loot.t = 0.0
				game.loot.shown = 0
			"summon":
				game.P.x = game.M.pedestal.x
				game.P.y = game.groundAt(game.P.x)
				key(KEY_UP, true)
				get_tree().create_timer(0.05).timeout.connect(func(): key(KEY_UP, false))
			"skill":
				var near = null
				for e in game.slimes:
					if e.state != "dead" and (near == null or absf(e.x - game.P.x) < absf(near.x - game.P.x)):
						near = e
				if near != null:
					game.P.x = near.x - 90
					game.P.y = game.groundAt(game.P.x)
					game.P.face = 1
				game.P.en = 100
				print("useSkill ", s[2], " -> ", game.useSkill(s[2]))
			"home":
				print("menu open: ", game.menuOpen if "menuOpen" in game else "?")
				game.toggleMenu(false)
				game.travelHome()
			"cards":
				for k in ["boulder", "lizard", "golem", "warlock", "yeti", "sword"]:
					game.save.bestiary[k] = {"kills": 3, "shiny": 1 if k in ["lizard", "sword"] else 0}
				game.save.cards.lizard = {"n": true, "sg": true}
				game.save.cards.golem = {"ng": true}
				game.save.cards.kingYeti = {"n": true, "ng": true}
			"tab": game.openTab(s[2])
			"scroll": game.scrollBy("panel", s[2])
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
				print("reloaded: keyItems=%s trophies=%s blade=%s" % [sv.get("keyItems"), sv.trophies, sv.chars.rock.skills.has("swordThrow")])
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
	print("shot %s map=%s state=%s pos=%.0f,%.0f vy=%.0f hp=%d/%d held=%s mobs=%d boss=%s ys=%s scene=%s loot=%s" % [name, game.mapId, P.state, P.x, P.y, P.vy, P.hp, game.PS.hp,
		P.held.kind if P.held != null else "-", game.slimes.size(), ("%s/%s %d" % [b.state, b.data.get("act", ""), b.hp]) if b != null else "-", game.YS.get("state", "-"), game.scene != null, game.loot != null])
	busy = false
