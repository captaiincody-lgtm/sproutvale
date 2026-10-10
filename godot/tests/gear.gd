extends Node
## Gear looks: one hero in armor / weapon tiers 0 → max (idle and running, both genders), the shop's gear
## preview, the advancement titles, and the painted World Map with every region open.
## Run:  godot --path godot res://tests/gear.tscn -- <output dir> <hero>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://gear"
var hero := "rock"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		hero = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://gear_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://gear_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1, "warlord": 1, "dreamer": 1}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", hero)
	add.call(0.4, "tap", KEY_ENTER)
	add.call(0.6, "endintro")
	add.call(0.3, "warp", "meadow")
	add.call(2.0, "calm")
	add.call(0.1, "back")
	for g in ["m", "f"]:
		add.call(0.1, "gender", g)
		for tier in [[0, 0, 0], [1, 2, 2], [2, 4, 4], [3, 6, 6], [4, 8, 8], [5, 10, 10]]:
			add.call(0.15, "gear", tier)
			add.call(0.35, "shot", "%s_%s_a%d_w%d_idle" % [hero, g, tier[0], tier[1]])
			add.call(0.05, "hold", KEY_RIGHT)
			add.call(0.45, "shot", "%s_%s_a%d_w%d_run" % [hero, g, tier[0], tier[1]])
			add.call(0.05, "unhold", KEY_RIGHT)
			add.call(0.05, "back")
	add.call(0.1, "gear", [2, 4, 4])
	add.call(0.1, "titles")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "shop")
	add.call(0.2, "shopTab", "gear")
	add.call(0.5, "shot", "shop_gear")
	add.call(0.1, "tab", "map")
	add.call(0.6, "shot", "map_all")
	add.call(0.1, "trophies", {"croc": 1})
	add.call(0.5, "shot", "map_crimson")
	add.call(0.1, "trophies", {})
	add.call(0.5, "shot", "map_start")
	add.call(0.2, "quit")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	t += delta
	if game.P != null and game.P.state != "dead" and game.PS is Dictionary and game.PS.has("hp"):
		game.P.hp = maxf(game.P.hp, game.PS.hp)
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
			"hold":
				key(s[2], true)
			"unhold":
				key(s[2], false)
			"endintro":
				var n = 0
				while game.intro != null and n < 40:
					game.introNext()
					n += 1
			"warp":
				game.fadeTo = {"map": s[2]}
			"calm":   # no monsters in the way of the pictures
				game.slimes.clear()
				game.save.settings.god = true
			"back":
				game.P.x = 200
				game.P.vx = 0
				game.slimes.clear()
			"gender":
				game.CH().look.gender = s[2]
				game.refreshJobNames()
			"gear":
				var c = game.CH()
				c.armor = s[2][0]; c.weapon = s[2][1]; c.staff = s[2][2]
				game.PS = game.calcStats()
				print("look ", game.heroLook())
			"titles":
				for cls in game.JOBS_BY:
					print(cls, ": ", " > ".join(game.JOBS_BY[cls].map(func(J): return J.name)))
			"trophies":
				game.save.trophies = s[2]
			"tab": game.openTab(s[2])
			"shopTab": game.shopTab = s[2]
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	busy = false
