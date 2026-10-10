extends Node
## Scripted check of the loot update: loot bags, rare treasures, EXP and Abyssal Coins from the
## Obelisk, the 3-column inventory, crafting materials and the stronger house. Saves screenshots.
## Run:  godot --path godot res://tests/loot.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://loot"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://loot_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://loot_save.json")
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
	add.call(1.0, "crafting")
	add.call(0.1, "warp", "meadow")
	add.call(1.5, "kills")
	add.call(0.1, "drops")
	add.call(1.2, "shot", "drops")
	add.call(0.1, "pickup")
	add.call(0.6, "shot", "picked_up")
	add.call(0.1, "shower")
	add.call(1.6, "shot", "coin_shower")
	add.call(0.1, "collect")
	add.call(0.4, "shot", "shower_picked")
	add.call(0.1, "fill")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "inv")
	add.call(0.4, "shot", "inventory")
	add.call(0.1, "scroll", 400)
	add.call(0.3, "shot", "inventory_scrolled")
	add.call(0.1, "scroll", -2000)
	add.call(0.1, "openbags")
	add.call(0.4, "shot", "bags_opened")
	add.call(0.1, "sell")
	add.call(0.4, "shot", "sold")
	add.call(0.1, "tab", "shop")
	add.call(0.4, "shot", "shop")
	add.call(0.1, "house")
	add.call(0.1, "scroll", 2000)
	add.call(0.4, "shot", "shop_house")
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
	while not busy and steps.size() and steps[0][0] <= t:
		var s: Array = steps.pop_front()
		match s[1]:
			"shot":
				busy = true
				_shot(s[2])
				break
			"warp":
				game.fadeTo = {"map": s[2]}
			"pick":
				game.selClass = s[2]
			"tap":
				key(s[2], true)
				var code = s[2]
				get_tree().create_timer(0.05).timeout.connect(func(): key(code, false))
			"skip":
				if game.intro != null:
					game.introSkip()
			"crafting":
				print("ladder: ", game._craftLadder())
				for tr in game.GEAR.rock.weapon:
					print("rock weapon %-26s lv %3d %s" % [tr.name, tr.lv, tr.mats])
				for tr in game.GEAR.rock.armor:
					print("rock armor  %-26s lv %3d %s" % [tr.name, tr.lv, tr.mats])
				for tr in game.GEAR.tank.weapon:
					print("tank gun    %-26s lv %3d %s" % [tr.name, tr.lv, tr.mats])
				for i in range(0, game.CHARM_TIERS.size(), 4):
					var tr = game.CHARM_TIERS[i]
					print("charm       %-26s lv %3d %s" % [tr.name, tr.lv, tr.mats])
				for k in game.FURN_ORDER:
					print("furniture ", k, " ", game.FURNITURE[k].items.map(func(it): return it.val))
				for it in game.CURIOS:
					print("curio ", it.name, " ", it.fx, " ", it.desc)
			"kills":
				# kill a lot of monsters to check the drop odds
				var bags = 0
				var rares = 0
				var abyssBefore = 0
				for i in 20000:
					game.spawnSlime(true)
					var e = game.slimes[-1]
					game.killSlime(e)
				for d in game.drops:
					if d.kind == "bag": bags += 1
					if d.kind == "rare": rares += 1
				print("20000 kills: bags %d, rares %d" % [bags, rares])
				game.drops = game.drops.filter(func(d): return d.kind == "coin" and false)
				game.slimes = []
			"drops":
				var e = S_mob()
				game.dropLoot(e)
				for k in 3:
					game._drop("bag", e, randf_range(-60, 60), -220, 1, ["green", "blue", "red"][k])
				var d = game._drop("rare", e, 40, -240, 1, "green")
				d = game._drop("rare", e, -40, -240, 1, "red")
				d.shiny = true
				for k in 4:
					game._drop("exp", e, randf_range(-80, 80), -200, 30)
				for k in 3:
					game._drop("abyss", e, randf_range(-80, 80), -200)
			"pickup":
				for d in game.drops:
					d.x = game.P.x
					d.y = game.P.y - 10
					d.t = 1.0
			"shower":
				game.drops = []
				game.obeliskCoins({"x": game.P.x + 40, "surf": game.surfaces[0]})
			"collect":
				var n = {}
				for d in game.drops:
					n[d.kind] = n.get(d.kind, 0) + 1
				print("shower drops: ", n)
				for d in game.drops:
					d.x = game.P.x
					d.y = game.P.y - 10
					d.vy = 0
					d.t = 1.0
			"fill":
				game.save.coins += 500000
				game.collectBox("croc", 3)
				game.collectBox("warlord", 12)
				for k in ["green", "blue", "boar", "evileye", "shark"]:
					game.save.bags[k] = randi_range(1, 6)
				for k in ["green", "boar_shiny", "evileye", "squid", "ferro", "rat"]:
					game.save.rares[k] = randi_range(1, 4)
				for k in game.SLIME_KEYS:
					game.save.mats[k] = randi_range(0, 400)
				game.save.cards["green"] = {"n": true}
				game.save.cards["blue"] = {"n": true, "s": true}
				game.save.keyItems = {"dreamKey": true, "yetiPendant": true}
			"openbags":
				var c0 = game.save.coins
				var e0 = game.CH().exp
				var l0 = game.CH().level
				game._openBags("evileye", game.bagCount("evileye"))
				print("bags: coins +%d, level %d→%d, exp %d→%d, rares %s" % [game.save.coins - c0, l0, game.CH().level, e0, game.CH().exp, game.save.rares])
			"sell":
				var c0 = game.save.coins
				game._sellRares(["ferro"], 1)
				print("sold one Living Mercury for ", game.save.coins - c0, " values: ", game.rareValue("green"), " ", game.rareValue("green_shiny"), " ", game.rareValue("ferro"))
			"house":
				game.shopTab = "house"
			"tab": game.openTab(s[2])
			"scroll": game.scrollBy("panel", s[2])
			"reload":
				game.persist()
				var sv = game.loadSave()
				print("reloaded bags ", sv.bags, " rares ", sv.rares)
			"quit":
				print("done; quitting")
				get_tree().quit()


func S_mob():
	var e = game.S.Mob.new()
	e.type = "green"; e.T = game.SLIME_TYPES.green; e.lv = 1
	e.x = game.P.x + 50; e.y = game.P.y
	e.surf = game.surfaces[0]
	return e


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	print("shot %s map=%s coins=%d drops=%d" % [name, game.mapId, game.save.coins, game.drops.size()])
	busy = false
