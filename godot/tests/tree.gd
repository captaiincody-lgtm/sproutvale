extends Node
## Scripted check of the Attribute Tree: an older save's attribute points come back as tree points,
## the tree tab and the Character tab, buying and resetting nodes, and the tree's combat effects
## (energy shield, dodge, damage reduction, Abyss resistance, Last Stand, cheaper skills). Saves screenshots.
## Run:  godot --path godot res://tests/tree.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://tree"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false
var fails := 0
const SAVE := "user://tree_save.json"


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# an older save: Rock at level 40 with his attribute points spent the old way, 5 left over
	var old = {"coins": 5000, "chars": {"rock": {"level": 40, "exp": 0, "ap": 5, "sp": 0, "introSeen": true,
		"attrs": {"STR": 60, "WIL": 10, "VIT": 40, "AGI": 10, "DEX": 3}, "skills": {}}}, "settings": {"weather": "sunny"}}
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", SAVE)
	add_child(game)
	game.save = game.loadSave()
	var rock = game.save.chars.rock
	check(int(rock.tp) == 39, "old save refunds one tree point per level gained (tp=%s)" % rock.tp)
	check(not rock.has("ap"), "old attribute points are gone")
	check(rock.attrs.STR == 1 and rock.attrs.VIT == 1, "attributes start again from 1")
	check(rock.get("treeNote", false), "the hero will be told about the refund")
	check(int(game.save.chars.archer.get("tp", -1)) == 0 and not game.save.chars.archer.get("treeNote", false), "a hero never played gets nothing to refund")
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(3.4, "shot", "refund_banner")
	add.call(0.1, "balance")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "char")
	add.call(0.4, "shot", "char_tab")
	add.call(0.1, "tab", "tree")
	add.call(0.4, "shot", "tree_empty")
	add.call(0.1, "buy")
	add.call(0.4, "shot", "tree_spent")
	add.call(0.1, "hover")
	add.call(0.3, "shot", "tree_tooltip")
	add.call(0.1, "scroll", 300)
	add.call(0.3, "shot", "tree_middle")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "tree_totals")
	add.call(0.1, "tab", "char")
	add.call(0.3, "shot", "char_after")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.3, "combat")
	add.call(0.6, "shot", "shield_hud")
	add.call(0.1, "reset")
	add.call(0.2, "quit")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	busy = false


func _buyPath(ids: Array) -> void:
	for id in ids:
		game._treeBuy(id)


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
			"tab":
				game.openTab(s[2])
			"scroll":
				game.scrollBy("panel", s[2])
			"balance":
				# the old way at level 40 (117 points: 59 ATK, 39 VIT, 9 WIL, 9 AGI, 2 DEX + the 5 unspent) against the
				# new way (39 tree points spent on the same attributes, three of the old for one of the new)
				var c = game.CH()
				c.attrs = {"STR": 60, "WIL": 10, "VIT": 40, "AGI": 10, "DEX": 3}
				var o = game.calcStats()
				c.attrs = {"STR": 1, "WIL": 1, "VIT": 1, "AGI": 1, "DEX": 1}
				c.tree = {"s0_1": 5, "s4_1": 5, "s0_2": 5, "s4_2": 5, "s0_3": 5, "s4_3": 5, "s3_1": 3, "s2_1": 3, "s1_1": 1, "s0_4": 2}
				var n = game.calcStats()
				print("lv40 old way: hp %d atk %d def %d crit %.1f  ·  tree: hp %d atk %d def %d crit %.1f" % [o.hp, o.atk, o.def, o.crit, n.hp, n.atk, n.def, n.crit])
				# level 100: 297 old points against 99 tree points down the Might, Vitality and Precision branches
				c.level = 100
				c.attrs = {"STR": 150, "WIL": 1, "VIT": 100, "AGI": 20, "DEX": 30}
				c.tree = {}
				o = game.calcStats()
				c.attrs = {"STR": 1, "WIL": 1, "VIT": 1, "AGI": 1, "DEX": 1}
				c.tree = {"s0_1": 5, "s0_2": 5, "s0_3": 5, "s0_4": 5, "s0_5": 5, "s4_1": 5, "s4_2": 5, "s4_3": 5, "s4_4": 5, "s4_5": 5,
					"s1_1": 5, "s1_2": 5, "s1_3": 5, "s1_4": 5, "s2_1": 5, "h0_2_0": 5, "h4_2_0": 5, "h4_4_0": 5, "h0_4_0": 4}
				n = game.calcStats()
				print("lv100 old way: hp %d atk %d def %d crit %.1f  ·  tree (%d pts): hp %d atk %d def %d crit %.1f" % [o.hp, o.atk, o.def, o.crit, game.TREE.spent(c.tree), n.hp, n.atk, n.def, n.crit])
				c.level = 40
				c.tree = {}
				game.PS = game.calcStats()
			"buy":
				var c = game.CH()
				var tp0 = int(c.tp)
				game._treeBuy("s0_3")   # ring 3 is shut until 8 points are in
				check(not c.tree.has("s0_3"), "ring 3 stays shut with nothing spent")
				game._treeBuy("h0_2_0")   # not touching anything yet
				check(not c.tree.has("h0_2_0"), "a node needs a neighbour you already have")
				_buyPath(["s0_1", "s0_1", "s0_1", "s0_2", "h0_2_0", "s3_1", "s3_1", "s3_2", "h3_2_0", "h3_2_0", "h3_2_0"])
				check(c.tree.get("h3_2_0", 0) == 3 and int(c.tp) == tp0 - 11, "buying along the paths spends one point each")
				_buyPath(["s0_3", "h0_3_0", "s4_1", "s4_2", "h4_2_0"])
				check(c.tree.get("h0_3_0", 0) == 1, "ring 3 opens past 8 points")
				for i in 5:
					game._treeBuy("s4_1")
				check(c.tree.get("s4_1", 0) == 5, "a node stops at its maximum")
				print("tree after buying: ", c.tree, " tp ", c.tp, " PS eshield ", game.PS.get("eshield"), " thorns ", game.PS.get("thorns"))
			"hover":
				# the mouse over the Energy Shield node, to see its tooltip
				game.mouse = Vector2(470, 300)
			"combat":
				var c = game.CH()
				game.save.settings.god = false
				c.tree = {"h3_2_0": 5, "h3_6_0": 5, "h3_7_2": 1, "h3_4_0": 5, "h3_7_0": 1, "s4_6": 3, "s3_5": 5, "h3_5_0": 2}
				game.PS = game.calcStats()
				game.P.hp = game.PS.hp
				game.P.shield = float(game.PS.eshield)
				var sh0 = game.P.shield
				check(game.PS.eshield > 0 and is_equal_approx(game.PS.dr, 0.09), "shield %d, damage reduction %.2f" % [game.PS.eshield, game.PS.dr])
				var hp0 = game.P.hp
				game.P.iframes = 0
				game.hurtPlayer({"x": game.P.x + 10, "lv": 40, "noCrit": true}, 60.0)
				check(game.P.shield < sh0 and game.P.hp == hp0, "a small hit only dents the energy shield (%.0f → %.0f, hp %d)" % [sh0, game.P.shield, game.P.hp])
				game.P.abyssB = 0.0
				game.abyssBuild(50)
				check(absf(game.P.abyssB - 50 * (1 - game.PS.abyssRes)) < 0.01, "Abyss buildup is cut by resistance (%.1f)" % game.P.abyssB)
				game.P.abyssB = 0.0
				check(is_equal_approx(game.abyssDur(), 30.0 * 0.7), "Abyss Walker shortens the Abyss (%.1fs)" % game.abyssDur())
				check(game.skillCost({"cost": 20}) == 17, "Clarity makes a 20-cost skill cost %d" % game.skillCost({"cost": 20}))
				game.P.state = "move"
				game.P.hp = 5
				game.killPlayer()
				check(game.P.state != "dead" and game.P.hp > 5, "Last Stand saves you once (hp %d)" % game.P.hp)
				game.P.hp = 0
				game.killPlayer()
				check(game.P.state == "dead", "…but not twice in a row")
				game.P.state = "move"
				game.P.hp = game.PS.hp
				game.P.deadT = 0
				# dodge: with the most dodge the tree allows, roughly three hits in ten miss
				c.tree = {"s2_6": 3, "h1_2_0": 5, "h1_5_0": 2}
				game.PS = game.calcStats()
				var miss = 0
				for i in 2000:
					var n0 = game.P.hurtN
					game.P.iframes = 0
					game.P.state = "move"
					game.P.hp = game.PS.hp
					game.hurtPlayer({"x": game.P.x + 10, "lv": 1, "noCrit": true}, 1.0)
					if game.P.hurtN == n0:
						miss += 1
				check(miss > 380 and miss < 520, "dodge %.1f%%: %d of 2000 hits dodged" % [game.PS.dodge, miss])
				c.tree = {"h3_2_0": 5, "h3_6_0": 3}
				game.PS = game.calcStats()
				game.P.hp = game.PS.hp
				game.P.shield = game.PS.eshield * 0.6
				game.P.iframes = 0
				game.P.state = "move"
			"reset":
				var c = game.CH()
				var tp0 = int(c.tp)
				var sp = game.TREE.spent(c.tree)
				game._treeReset()
				game._treeReset()
				check(c.tree.is_empty() and int(c.tp) == tp0 + sp, "reset gives every point back (%d)" % c.tp)
			"quit":
				game.save.settings.god = false
				print("tree test done, %d failed" % fails)
				get_tree().quit(1 if fails else 0)
