extends Node
## Scripted run through the Lunar quest line: a Lunar monster and its Luna Coins, the Lunar Shop's meter,
## the voice in the dark (before and after beating the game), the house at night, the neighborhood, the
## rocket and the heroes, the flight, and the Moon. Saves screenshots.
## Run:  godot --path godot res://tests/lunar.tscn -- <output dir> [part]
## (needs a display or a virtual one such as xvfb-run). Parts: mobs, early, village, night (default: all)

var game
var out_dir := "user://lunar"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var part = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lunar_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://lunar_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.settings.help = true
	game.save.trophies = {"croc": 1, "warlord": 1, "dreamer": 1, "kingYeti": 1, "mk2": 1, "glamrax": 1}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "call", func(): game.selClass = "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "call", func(): if game.intro != null: game.introSkip())
	add.call(1.0, "call", func(): game.gainExp(3000000); print("level ", game.CH().level))
	if part in ["all", "mobs"]:
		add.call(0.1, "call", func(): game.fadeTo = {"map": "meadow"})
		add.call(1.5, "call", func():
			game.lunarRateOverride = 1.0
			for e in game.slimes:
				e.state = "dead"
			game.slimes.clear()
			game.spawnSlime(true)
			game.lunarRateOverride = 0.0
			var e = game.slimes[0]
			e.x = game.P.x + 70; e.y = game.M.floorY; e.surf = game.surfaces[0]
			print("lunar: ", game.isLunar(e), " hp ", e.maxHp, " atk ", e.atk, " exp ", e.exp, " coinMul ", e.coinMul))
		add.call(1.0, "shot", "lunar_mob")
		add.call(0.1, "call", func():
			var e = game.slimes[0]
			print("exp before ", game.CH().exp, " coins ", game.save.coins)
			e.hp = 1
			game.damageSlime(e, {"dmg": 50.0}))
		add.call(0.5, "shot", "lunar_dead")
		add.call(1.5, "shot", "luna_drops")
		add.call(0.1, "call", func():
			for d in game.drops:
				d.x = game.P.x; d.y = game.P.y - 4; d.t = 1.0)
		add.call(0.5, "call", func(): print("luna coins: ", game.lunaCoins(), " coins ", game.save.coins))
		add.call(0.3, "shot", "luna_picked")
		add.call(0.1, "call", func(): game.openTab("inv"); game.toggleMenu(true))
		add.call(0.4, "shot", "inv_currency")
		add.call(0.1, "call", func(): game.openTab("shop"); game.shopTab = "lunar")
		add.call(0.4, "shot", "lunar_shop")
		add.call(0.1, "call", func(): game.toggleMenu(false))
	if part in ["all", "early"]:
		# the meter fills before the game is beaten
		add.call(0.1, "call", func(): game.save.lunaCoins = 1200; game.openTab("shop"); game.shopTab = "lunar"; game.toggleMenu(true))
		add.call(0.3, "call", func(): game.donateLuna(10))
		add.call(0.3, "shot", "meter_10")
		add.call(0.1, "call", func(): game.donateLuna(5000))
		add.call(1.2, "shot", "dark1")
		add.call(2.0, "shot", "dark2")
		add.call(2.0, "shot", "dark3")
		add.call(0.1, "call", func(): game.introNext(); game.introNext())
		add.call(0.6, "shot", "not_yet")
		add.call(0.1, "call", func(): print("lunar: ", game.LU(), " luna ", game.lunaCoins()); game.openTab("shop"); game.shopTab = "lunar"; game.toggleMenu(true))
		add.call(0.4, "shot", "shop_full_early")
		add.call(0.1, "call", func(): game.toggleMenu(false))
	if part in ["all", "village"]:
		add.call(0.1, "call", func(): _finale(); game.fadeTo = {"map": "home"})
		for x in [300, 650, 1030, 1410, 1750, 2200]:
			add.call(1.4 if x == 300 else 0.2, "call", func(): _go(x))
			add.call(0.6, "shot", "village_%d" % x)
		add.call(0.1, "call", func(): _go(1410); _enter("summoner"))
		add.call(1.4, "shot", "visit_jojo")
		add.call(0.1, "call", func(): _go(186); _up())
		add.call(0.6, "shot", "talk_jojo")
		add.call(0.1, "call", func(): game.scene = null; _go(60); _up())
		add.call(1.4, "call", func(): print("back out at x=%.0f map=%s" % [game.P.x, game.mapId]))
		add.call(0.1, "shot", "out_of_jojos")
		add.call(0.1, "call", func(): _go(game.VILLAGE.mage + 96); _up())
		add.call(0.6, "shot", "talk_grandma")
		add.call(0.1, "call", func(): game.scene = null; _go(game.VILLAGE.archer - 30))
		add.call(0.3, "call", func(): print("archer door: ", game.villageDoor("archer"), " ropes ", game.M.ropes))
		add.call(0.1, "call", func(): game.P.x = game.villageDoor("archer").x; game.P.y = 182; game.P.vy = 0; game.P.grounded = false)
		add.call(0.4, "call", func(): _up())
		add.call(1.4, "shot", "treehouse")
		add.call(0.1, "call", func(): game.scene = null; game.travelHome())
		add.call(1.4, "call", func(): print("home start x=%.0f" % game.P.x))
		add.call(0.1, "call", func(): game.fadeTo = {"map": "house"})
		add.call(1.4, "shot", "own_house")
	if part in ["all", "night"]:
		add.call(0.1, "call", func(): _finale(); game.LU().meter = 990; game.LU().rite = false; game.save.lunaCoins = 50; game.fadeTo = {"map": "meadow"})
		add.call(1.4, "call", func(): game.donateLuna(100))
		add.call(1.0, "call", func(): game.introNext(); game.introNext())
		add.call(1.2, "shot", "night_house")
		add.call(0.1, "call", func(): game.scene = null; _go(40); _up())
		add.call(1.4, "shot", "night_village")
		add.call(0.1, "call", func(): _go(1700))
		add.call(0.5, "shot", "night_village2")
		add.call(0.1, "call", func(): _go(1960))
		add.call(0.6, "shot", "rocket_talk1")
		for i in 5:
			add.call(0.2, "call", func(): game.pressed["z"] = true)
			add.call(0.2, "call", func(): game.pressed["z"] = true)
			add.call(0.4, "shot", "rocket_talk%d" % (i + 2))
		add.call(0.1, "call", func(): game.scene = null; _go(game.ROCKET_X))
		add.call(0.6, "shot", "at_hatch")
		add.call(0.1, "call", func(): _up())
		for i in 3:
			add.call(1.0, "shot", "flight%d_a" % i)
			add.call(1.6, "shot", "flight%d_b" % i)
			add.call(0.1, "call", func(): game.introNext(); game.introNext())
		add.call(0.3, "shot", "moon_drop")
		add.call(1.2, "shot", "moon_landing")
		add.call(1.0, "shot", "moon_landed")
		add.call(0.1, "call", func(): game.pressed[" "] = true; print("moon y before jump %.0f" % game.P.y))
		add.call(0.6, "call", func(): print("moon y mid jump %.0f vy %.0f" % [game.P.y, game.P.vy]))
		add.call(0.1, "shot", "moon_jump")
		add.call(1.6, "call", func(): _go(332); _up())
		add.call(0.5, "shot", "moon_talk")
		add.call(0.1, "call", func(): game.scene = null; _go(800))
		add.call(0.6, "shot", "moon_mid")
		add.call(0.1, "call", func(): _go(1300))
		add.call(0.6, "shot", "moon_far")
		add.call(0.1, "call", func(): _go(game.MOON_ROCKET_X); _up())
		add.call(1.6, "shot", "fly_home")
		add.call(0.1, "call", func(): game.introNext(); game.introNext())
		add.call(1.4, "shot", "home_again")
		add.call(0.1, "call", func(): game.fadeTo = {"map": "meadow"})
		add.call(1.6, "shot", "meadow_night")
	add.call(0.1, "call", func():
		game.persist()
		var sv = game.loadSave()
		print("reloaded: lunar=%s luna=%s map=%s" % [sv.get("lunar"), sv.get("lunaCoins"), sv.settings.map]))
	add.call(0.2, "quit")


func _finale() -> void:
	game.save.finaleDone = true
	game.save.showdownWon = true
	game.save.captured = {}
	for c in ["rock", "archer", "mage", "summoner", "tank"]:
		game.save.chars[c].bossKills = {"glamrax": 1}
	game.save.chars.tank.meteorDone = true


func _go(x: float) -> void:
	game.P.x = x
	game.P.y = game.groundAt(x)
	game.P.vy = 0
	game.P.vx = 0
	game.P.state = "move"
	game.P.grounded = true
	game.P.surf = game.surfaces[0]


func _up() -> void:
	game.pressed["arrowup"] = true


func _enter(h: String) -> void:
	for p in game.M.portals:
		if p.get("who", "") == h:
			game.travel(p)


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	t += delta
	if game.P != null and game.PS is Dictionary and game.PS.has("hp"):
		game.P.hp = maxf(game.P.hp, game.PS.hp * 0.6)
	while not busy and steps.size() and steps[0][0] <= t:
		var s: Array = steps.pop_front()
		match s[1]:
			"shot":
				busy = true
				_shot(s[2])
				break
			"tap":
				key(s[2], true)
				var code = s[2]
				get_tree().create_timer(0.05).timeout.connect(func(): key(code, false))
			"call":
				s[2].call()
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	print("shot %s map=%s state=%s pos=%.0f,%.0f grounded=%s mobs=%d scene=%s intro=%s" % [name, game.mapId, P.state, P.x, P.y, P.grounded, game.slimes.size(), game.scene != null, game.intro != null])
	busy = false
