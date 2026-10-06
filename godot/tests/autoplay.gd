extends Node
## Smoke test: starts the game, plays a short scripted run with fake key presses and menu clicks,
## and saves screenshots along the way. Uses a throwaway save file.
## Run:  godot --path godot res://tests/autoplay.tscn -- <output dir> [hero]
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://autoplay"
var hero := "rock"
var t := 0.0
var shots := 0
var steps: Array = []
var hunting := 0.0
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		hero = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autoplay_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://autoplay_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1} if hero == "summoner" else {}
	game.fillQuests()
	var at = [0.6]   # (lambdas capture locals by value, so the running time lives in an array)
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "shot", "title")
	add.call(0.2, "pick", hero)
	add.call(0.3, "shot", "title_" + hero)
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "shot", "intro1")
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(1.0, "shot", "intro2")
	add.call(0.1, "skip")
	add.call(1.5, "shot", "start")
	add.call(0.1, "hold", KEY_RIGHT)
	add.call(1.2, "release", KEY_RIGHT)
	add.call(0.1, "tap", KEY_SPACE)
	add.call(0.15, "shot", "jump")
	add.call(0.4, "tap", KEY_Z)
	add.call(0.1, "tap", KEY_Z)
	add.call(0.1, "shot", "attack")
	add.call(0.3, "warp", "meadow")
	add.call(1.5, "shot", "meadow")
	add.call(0.1, "hunt", 3.0)
	add.call(3.0, "shot", "fight")
	add.call(0.1, "exp", 4000)
	add.call(0.1, "tap", KEY_TAB)
	for tab in ["char", "inv", "shop", "skills", "quests", "map", "bestiary", "controls", "world"]:
		add.call(0.2, "tab", tab)
		add.call(0.35, "shot", "menu_" + tab)
	for st in ["abyss", "boss", "house"]:
		add.call(0.1, "tab", "shop")
		add.call(0.05, "shoptab", st)
		add.call(0.3, "shot", "shop_" + st)
	add.call(0.1, "tab", "skills")
	add.call(0.1, "scroll", 400)
	add.call(0.3, "shot", "skills_scrolled")
	add.call(0.1, "settings")
	add.call(0.3, "shot", "settings")
	add.call(0.1, "account")
	add.call(0.4, "shot", "account")
	add.call(0.1, "close")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "warp", "pond")
	add.call(1.5, "night")
	add.call(0.5, "shot", "night")
	add.call(0.1, "rain")
	add.call(3.0, "shot", "rain")
	add.call(0.1, "god")
	add.call(0.1, "warp", "lair")
	add.call(2.0, "shot", "lair")
	add.call(0.1, "hunt", 4.0)
	add.call(4.0, "shot", "croc")
	add.call(0.1, "warp", "crimson1")
	add.call(2.0, "shot", "crimson1")
	add.call(0.1, "hunt", 3.0)
	add.call(3.0, "shot", "crimson_fight")
	add.call(0.1, "warp", "crimson5")
	add.call(2.5, "shot", "warlord")
	add.call(0.1, "hunt", 4.0)
	add.call(4.0, "shot", "warlord_fight")
	add.call(0.1, "warp", "house")
	add.call(1.5, "shot", "house")
	add.call(0.1, "warp", "trophy")
	add.call(1.5, "shot", "trophy")
	add.call(0.1, "mainmenu")
	add.call(0.6, "shot", "back_to_select")
	add.call(0.2, "quit")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	t += delta
	if hunting > 0:
		hunting -= delta
		_hunt()
		if hunting <= 0:
			key(KEY_LEFT, false)
			key(KEY_RIGHT, false)
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
			"hold": key(s[2], true)
			"release": key(s[2], false)
			"skip":
				if game.intro != null:
					game.introSkip()
			"warp":
				game.fadeTo = {"map": s[2]}
				print("warp ", s[2], " menu=", game.menuOpen, " overlay=", game.overlay, " t=", t)
			"hunt": hunting = s[2]
			"exp":
				game.gainExp(s[2])
				game.save.coins += 50000
				for k in game.save.mats:
					game.save.mats[k] += 40
			"tab": game.openTab(s[2])
			"shoptab": game.shopTab = s[2]
			"scroll": game.scrollBy("panel", s[2])
			"settings": game.openSettings()
			"account":
				game.overlay = ""
				game.openAccount()
			"close": game.closeOverlay()
			"night": game.World.t = 0.95
			"rain":
				game.save.settings.weather = "rain"
				game.setWeather("rain", true)
			"god": game.save.settings.god = true
			"mainmenu":
				game.toggleMenu(false)
				game.toCharSelect()
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	print("shot %s map=%s state=%s anim=%s hp=%d lv=%d mobs=%d coins=%d" % [name, game.mapId, P.state, P.anim, P.hp, game.CH().level if game.inGame else 0, game.slimes.size(), game.save.coins])
	busy = false


## walk at the nearest monster and keep attacking
func _hunt() -> void:
	var P = game.P
	var best = null
	for e in game.slimes:
		if e.state != "dead" and absf(e.y - P.y) < 40 and (best == null or absf(e.x - P.x) < absf(best.x - P.x)):
			best = e
	key(KEY_LEFT, false)
	key(KEY_RIGHT, false)
	if best == null:
		return
	var dx = best.x - P.x
	if absf(dx) > (60 if game.classId != "rock" else 18):
		key(KEY_RIGHT if dx > 0 else KEY_LEFT, true)
	elif int(t * 10) % 3 == 0:
		key(KEY_Z, true)
		key(KEY_Z, false)
