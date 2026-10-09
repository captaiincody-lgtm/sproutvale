extends Node
## Scripted run as Tank: the unlock, his story intro, the box and the meteor, Glamrax's scene, his
## pistol and grenade combos, components, the exosuit pieces (glide, double dash, shoulder slam, weak
## points, flight), gun and grenade lines, grenade types, the drone, his skills, the Workshop and the house.
## Run:  godot --path godot res://tests/tank.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://tank"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tank_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://tank_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1, "warlord": 1, "dreamer": 1}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "tank")
	add.call(0.4, "shot", "select")
	add.call(0.1, "tap", KEY_ENTER)
	for i in 4:
		add.call(2.2, "shot", "intro_%d" % i)
		add.call(0.1, "next")
	add.call(2.0, "shot", "home_box")
	add.call(0.1, "go", 500)
	add.call(1.0, "shot", "meteor_fall")
	add.call(0.75, "shot", "meteor_hit")
	add.call(2.2, "shot", "scan")
	add.call(2.0, "shot", "scan2")
	add.call(2.2, "shot", "glamrax")
	add.call(0.1, "next")
	add.call(1.2, "shot", "volcano")
	add.call(0.1, "next")
	add.call(0.6, "shot", "revenge")
	add.call(0.1, "endintro")
	add.call(0.1, "exp", 60000000)
	add.call(0.1, "warp", "meadow")
	add.call(2.0, "near")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.1, "tap", KEY_Z)
	add.call(0.02, "shot", "pistol")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.1, "tap", KEY_Z)
	add.call(0.12, "shot", "burst")
	add.call(0.4, "near")
	add.call(0.1, "tap", KEY_X)
	add.call(0.25, "shot", "grenade_throw")
	add.call(0.45, "shot", "grenade_boom")
	add.call(1.0, "shot", "parts")
	add.call(0.1, "gear", [4, 5, 5, 3])
	add.call(0.3, "near")
	add.call(0.6, "shot", "weakpoints")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.08, "shot", "energy_twins")
	add.call(0.3, "tap", KEY_X)
	add.call(0.3, "shot", "missile")
	add.call(0.1, "nade", "cryo")
	add.call(0.5, "near")
	add.call(0.1, "tap", KEY_X)
	add.call(0.7, "shot", "cryo")
	add.call(0.1, "nade", "napalm")
	add.call(0.5, "near")
	add.call(0.1, "tap", KEY_X)
	add.call(0.8, "shot", "napalm")
	# lying down: shoot straight ahead, then throw a grenade
	add.call(0.6, "near")
	add.call(0.1, "hold", KEY_DOWN)
	add.call(0.35, "tap", KEY_Z)
	add.call(0.06, "shot", "prone_shot")
	add.call(1.6, "tap", KEY_X)
	add.call(0.12, "shot", "prone_nade")
	add.call(0.1, "unhold", KEY_DOWN)
	# a high lob, and a grenade thrown forward in the air
	add.call(1.6, "near")
	add.call(0.1, "hold", KEY_UP)
	add.call(0.05, "tap", KEY_X)
	add.call(0.3, "shot", "nade_up")
	add.call(0.1, "unhold", KEY_UP)
	add.call(1.6, "jump")
	add.call(0.2, "release")
	add.call(0.05, "tap", KEY_X)
	add.call(0.12, "shot", "air_nade")
	# empty the magazine
	for i in 18:
		add.call(0.09, "tap", KEY_Z)
	add.call(0.1, "shot", "reload")
	# two rocket bursts
	add.call(1.2, "near")
	add.call(0.1, "tap", KEY_C)
	add.call(0.08, "shot", "burst1")
	add.call(0.1, "tap", KEY_C)
	add.call(0.1, "shot", "slam")
	add.call(0.6, "gender", "f")
	add.call(0.4, "shot", "female")
	add.call(0.1, "gender", "m")
	add.call(0.6, "jump")
	add.call(0.6, "shot", "glide")
	add.call(0.6, "release")
	add.call(0.1, "gear", [9, 7, 6, 4])
	add.call(0.6, "jump")
	add.call(0.9, "shot", "mecha_fly")
	add.call(0.2, "release")
	add.call(1.2, "skills")
	for s in ["sentry", "strafe", "buildBot", "napalmDrones", "missileStrike", "orbitalLaser", "armageddon"]:
		add.call(0.6, "skill", s)
		add.call(0.5, "shot", "skill_" + s)
	add.call(0.6, "skill", "titanProtocol")
	add.call(0.6, "shot", "titan")
	add.call(0.6, "skill", "swarmProtocol")
	add.call(0.6, "shot", "swarm")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "shop")
	add.call(0.2, "shopTab", "gear")
	add.call(0.5, "shot", "shop_gear")
	add.call(0.1, "shopTab", "workshop")
	add.call(0.5, "shot", "workshop")
	add.call(0.1, "tab", "skills")
	add.call(0.5, "shot", "skills")
	add.call(0.1, "tab", "controls")
	add.call(0.5, "shot", "controls")
	add.call(0.1, "tab", "char")
	add.call(0.5, "shot", "char")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "house")
	add.call(0.1, "warp", "home")
	add.call(2.0, "go", 520)
	add.call(0.6, "shot", "house_out")
	add.call(0.1, "tap", KEY_UP)
	add.call(1.6, "shot", "house_in")
	add.call(0.1, "reload")
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
			"next":
				if game.intro != null:
					game.introNext()
					game.introNext()
			"endintro":
				var n = 0
				while game.intro != null and n < 30:
					game.introNext()
					n += 1
				print("intro closed: ", game.intro == null)
			"warp":
				game.fadeTo = {"map": s[2]}
			"exp":
				game.gainExp(s[2])
				game.save.settings.god = false
				print("level ", game.CH().level)
			"go":
				game.P.x = s[2]
				game.P.vx = 0
			"near":
				var near = null
				for e in game.slimes:
					if e.state != "dead" and (near == null or absf(e.x - game.P.x) < absf(near.x - game.P.x)):
						near = e
				if near != null:
					game.P.x = near.x - 70
					game.P.y = near.surf.y if near.surf != null else game.P.y
					game.P.vy = 0
					game.P.face = 1
					game.P.state = "move"
			"gear":
				var c = game.CH()
				c.armor = s[2][0]; c.weapon = s[2][1]; c.nade = s[2][2]; c.drone = s[2][3]
				c.nades = ["frag", "shrapnel", "cryo", "napalm", "energy", "emp", "cluster"]
				game.save.parts = {"scrap": 900, "wire": 400, "circuit": 120, "core": 9}
				game.PS = game.calcStats()
				print("gear ", s[2], " look ", game.heroLook(), " spd ", game.PS.spd)
			"nade":
				game.CH().nadeSel = s[2]
			"hold":
				key(s[2], true)
			"unhold":
				key(s[2], false)
			"gender":
				game.CH().look.gender = s[2]
				game.PS = game.calcStats()
			"jump":
				game.P.state = "move"
				key(KEY_SPACE, true)
			"release":
				key(KEY_SPACE, false)
			"skills":
				var c = game.CH()
				for sk in game.classSkills():
					c.skills[sk.id] = sk.max
				game.PS = game.calcStats()
				print("skills: ", game.classSkills().map(func(q): return q.id))
			"skill":
				var near = null
				for e in game.slimes:
					if e.state != "dead" and (near == null or absf(e.x - game.P.x) < absf(near.x - game.P.x)):
						near = e
				if near != null:
					game.P.x = near.x - 60
					game.P.face = 1
				game.P.state = "move"
				game.P.en = game.PS.enMax
				for k in game.Cool:
					game.Cool[k] = 0.0
				print("useSkill ", s[2], " -> ", game.useSkill(s[2]))
			"tab": game.openTab(s[2])
			"shopTab": game.shopTab = s[2]
			"house":
				game.save.coins = 99999
				game._buildHouse()
				print("house built: ", game.houseBuilt())
			"reload":
				game.persist()
				var sv = game.loadSave()
				print("reloaded: parts=%s house=%s armor=%s nades=%s meteor=%s" % [sv.parts, sv.tankHouse, sv.chars.tank.armor, sv.chars.tank.nades, sv.chars.tank.get("meteorDone")])
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	print("shot %s map=%s state=%s anim=%s move=%s pos=%.0f,%.0f vy=%.0f hp=%d/%d en=%d mobs=%d tshots=%d tfx=%d drops=%d parts=%s intro=%s" % [name, game.mapId, P.state, P.anim, P.moveId, P.x, P.y, P.vy, P.hp, game.PS.get("hp", 0), P.en,
		game.slimes.size(), game.tshots.size(), game.tfx.size(), game.drops.size(), game.save.get("parts"), game.intro != null])
	busy = false
