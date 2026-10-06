extends Node
## Scripted check of the boss loot update: the Warlord's dying cutscene, the sealed Dreamer's Gate,
## Crocbox / Crimsonbox, the boss treasures and the two boss skills. Saves screenshots.
## Run:  godot --path godot res://tests/bossloot.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://bossloot"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bossloot_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://bossloot_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "skip")
	add.call(1.0, "exp", 400000)
	add.call(0.1, "warp", "crimson5")
	add.call(2.0, "shot", "keep")
	add.call(0.1, "killboss")
	add.call(0.4, "shot", "dying_stagger")
	add.call(1.0, "shot", "dying_knee")
	add.call(1.0, "shot", "dialog1")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(1.5, "shot", "dialog2")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.6, "shot", "falls")
	add.call(2.0, "shot", "gate_open")
	add.call(0.1, "tobox")
	add.call(0.5, "shot", "box_shaking")
	add.call(2.2, "shot", "box_open")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.2, "togate")
	add.call(0.5, "shot", "gate")
	add.call(0.1, "tap", KEY_UP)
	add.call(0.4, "shot", "gate_sealed")
	add.call(0.1, "farm")
	add.call(2.6, "shot", "box_skill")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.2, "summon")
	add.call(2.0, "shot", "resummon")
	add.call(0.1, "killboss")
	add.call(2.6, "shot", "refight_falls")
	add.call(0.1, "warp", "meadow")
	add.call(1.2, "shot", "meadow_box")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.6, "shot", "meadow")
	add.call(0.1, "skill", "potionThrow")
	add.call(0.35, "shot", "potion_flying")
	add.call(0.5, "shot", "potion_puddle")
	add.call(0.1, "skill", "crimsonRain")
	add.call(1.5, "shot", "crimson_rain")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "skills")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "skills_boss")
	add.call(0.1, "tab", "char")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "char_treasures")
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


func _process(delta: float) -> void:
	t += delta
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
				game.Warlord.introDone = true
				game.fadeTo = {"map": s[2]}
			"exp":
				game.gainExp(s[2])
				game.save.settings.god = true
			"killboss":
				var b = _boss()
				print("boss: ", b != null)
				if b != null:
					game.P.x = b.x - 70
					game.P.face = 1
					b.hp = 1
					game.damageSlime(b, {"dmg": 1.0})
			"tobox":
				var found = false
				for d in game.drops:
					if d.kind == "box":
						game.P.x = d.x
						found = true
				print("box on floor: ", found)
			"togate":
				var g = null
				for p in game.M.portals:
					if p.get("sealed"):
						g = p
				print("sealed gate: ", g != null)
				if g != null:
					game.P.x = g.x
			"farm":
				# open boxes until the skill drops, to see the rare reveal and check the odds
				var n = 0
				while game.skillRank("crimsonRain") == 0 and n < 2000:
					n += 1
					game.openBox("warlord")
				var m = 0
				while game.skillRank("potionThrow") == 0 and m < 2000:
					m += 1
					game.openBox("croc")
				print("boxes until Crimson Rain: %d, until Potion Throw: %d, boons: %s, binds: %s, coins: %d, bossCoins: %d" % [n, m, game.CH().get("boons"), game.CH().binds, game.save.coins, game.save.bossCoins])
				print("stats: ", game.PS.hp, " ", game.PS.atk, " ", game.PS.def, " ", game.PS.crit)
				game.loot.t = 0.0
				game.loot.shown = 0
			"summon":
				game.P.x = game.M.pedestal.x
				key(KEY_UP, true)
				get_tree().create_timer(0.05).timeout.connect(func(): key(KEY_UP, false))
			"skill":
				var near = null
				for e in game.slimes:
					if e.state != "dead" and (near == null or absf(e.x - game.P.x) < absf(near.x - game.P.x)):
						near = e
				if near != null:
					game.P.x = near.x - 90
					game.P.face = 1
				game.P.en = 100
				print("useSkill ", s[2], " -> ", game.useSkill(s[2]))
			"tab": game.openTab(s[2])
			"scroll": game.scrollBy("panel", s[2])
			"reload":
				game.persist()
				var sv = game.loadSave()
				print("reloaded boons: ", sv.chars.rock.get("boons"), " skills has potionThrow: ", sv.chars.rock.skills.has("potionThrow"))
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	print("shot %s map=%s state=%s hp=%d mobs=%d coins=%d scene=%s loot=%s" % [name, game.mapId, P.state, P.hp, game.slimes.size(), game.save.coins, game.scene != null, game.loot != null])
	busy = false
