extends Node
## Quests: the main quest line through the real ending, the green tracker entries with their Complete
## buttons, and Auto-complete (unlocked by the painting in the House shop). Saves screenshots.
## Run:  godot --path godot res://tests/quests.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://quests"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false
var fails := 0


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://quests_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://quests_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "skip")
	add.call(1.0, "check_chain")
	add.call(0.2, "finish_quests")
	add.call(0.5, "shot", "tracker_green")
	add.call(0.1, "click_complete")
	add.call(0.5, "shot", "tracker_after_click")
	add.call(0.1, "menu", "quests")
	add.call(0.5, "shot", "quests_locked")
	add.call(0.1, "menu", "shop")
	add.call(0.1, "shoptab", "house")
	add.call(0.4, "scrollend")
	add.call(0.4, "shot", "house_shop")
	add.call(0.1, "buy")
	add.call(0.4, "shot", "house_shop_bought")
	add.call(0.1, "menu", "quests")
	add.call(0.5, "shot", "quests_unlocked")
	add.call(0.1, "close")
	add.call(0.1, "finish_quests", "warlord")
	add.call(0.5, "check_auto")
	add.call(0.2, "shot", "tracker_auto")
	add.call(0.1, "warp", "house")
	add.call(2.0, "shot", "house_painting")
	add.call(0.2, "story")
	add.call(0.5, "done")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


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
				game.fadeTo = {"map": s[2]}
			"check_chain":
				var titles = game.MAINQS.map(func(q): return q.title)
				print("main quests: ", titles)
				ok(titles.size() == 7 and titles[-1] == "Glamrax, For Good", "main quests run to the real ending")
			"finish_quests":
				game.fillQuests()
				game.save.quests[0].have = game.save.quests[0].need
				game.save.quests[0].done = true
				var boss = s[2] if s[2] != null else "croc"
				game.save.trophies[boss] = 1
				var mq = game.mainQ()
				ok(game.mainDone(), "beating %s finishes the main quest (stage %d)" % [boss, mq.stage])
			"click_complete":
				var zs: Array = game.zonesBy.get("hud", [])
				var coins0 = game.save.coins
				var n0 = game.save.main.q
				var clicked = 0
				for z in zs.duplicate():
					if z.r.size.y <= 15 and z.r.position.x > game.UW - 230:
						game._click(z.r.get_center())
						clicked += 1
						break
				ok(clicked == 1 and game.save.main.q == n0 + 1, "tracker Complete claims the main quest (now quest %d)" % (game.save.main.q + 1))
				game._process(0.016)
				await RenderingServer.frame_post_draw
				for z in game.zonesBy.get("hud", []).duplicate():
					if z.r.size.y <= 15 and z.r.position.x > game.UW - 230:
						game._click(z.r.get_center())
						break
				ok(game.save.quests.all(func(q): return not q.done) and game.save.coins > coins0, "tracker Complete claims the side quest")
			"menu":
				game.menuOpen = true
				game.curTab = s[2]
			"shoptab":
				game.shopTab = s[2]
			"scrollend":
				game.scrollY["panel"] = 99999.0
			"buy":
				game.save.coins += 100000
				game._paintBuy()
				ok(game.autoQuestOwned() and game.autoQuestOn(), "painting bought, auto-complete on")
			"close":
				game.menuOpen = false
			"check_auto":
				var q1 = game.save.main.q
				ok(game.save.quests.all(func(q): return not q.done), "auto-complete claimed the side quest")
				ok(q1 == 2, "auto-complete claimed the main quest (now quest %d)" % (q1 + 1))
			"story":
				# the story after the false ending, from the save flags
				var M = game.save.main
				M.q = 5; M.stage = 3; M.claimed = true
				game.save.settings.autoQuests = false
				game.save.captured = {"rock": {"level": 100}}
				var mq = game.mainQ()
				ok(mq.q == 6 and mq.stage == 0, "final quest starts after claiming Glamrax (q %d stage %d)" % [mq.q, mq.stage])
				game.save.captured = {"rock": {}, "archer": {}, "mage": {}, "summoner": {}, "tank": {}}
				ok(game.mainQ().stage == 1, "all five sealed: step 2")
				game.save.showdownWon = true
				ok(game.mainQ().stage == 2, "showdown won: step 3")
				game.save.finaleDone = true
				ok(game.mainDone(), "finale: final quest done")
				var c0 = game.save.coins
				game.claimMainQuest()
				ok(game.save.coins == c0 + 250000 and game.save.main.claimed, "final quest claimed")
			"done":
				print("quests test: %d failure(s)" % fails)
				get_tree().quit(1 if fails else 0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	busy = false
