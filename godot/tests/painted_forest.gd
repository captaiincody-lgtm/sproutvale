extends Node
var failures := 0
var output := "user://painted-forest"

func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PAINTED_FOREST_FAIL: " + message)

func tap(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://samples/painted_forest.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if not game.has_method("painted_mob_pose"):
		require(false,"Forest scene did not load")
		get_tree().quit(1)
		return
	get_tree().current_scene = game
	game.set_process(false)
	var encounter_target: int = game.M.target
	game.M.target = 0
	game.P.iframes = 100
	var families := {}
	for enemy in game.slimes:
		families[enemy.type] = enemy
	# Hold a readable lineup in the real world renderer before exercising the AI.
	game.slimes.clear()
	game.P.x = 60
	game.cam.x = 0
	game.cam.y = game.M.floorY - 174
	var slot := 0
	for kind in ["rat", "boar", "tortoise", "ferret"]:
		if not families.has(kind):
			continue
		var enemy = families[kind]
		enemy.x = 135 + slot*60
		enemy.y = game.M.floorY
		enemy.state = "idle"
		enemy.flash = 0
		enemy.sq = 0
		enemy.spawnT = 0
		game.slimes.append(enemy)
		slot += 1
	# The world is a SubViewport texture; let it update before the parent capture.
	for frame in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	require(get_viewport().get_texture().get_image().save_png(output.path_join("encounter.png")) == OK,"Could not capture playable encounter")
	for kind in ["rat", "boar", "tortoise", "ferret"]:
		require(families.has(kind),"Encounter did not spawn " + kind)
		if not families.has(kind):
			continue
		var enemy = families[kind]
		var ground: Dictionary = game.surfaces.filter(func(s): return s.get("floor", false))[0]
		enemy.surf = ground
		enemy.x = 230
		enemy.y = ground.y
		enemy.vx = 0
		enemy.vy = 0
		enemy.sq = 0
		enemy.flash = 0
		enemy.hp = 100000
		enemy.state = "chase"
		enemy.aggro = true
		enemy.atkCd = 0
		enemy.hopCd = 10
		enemy.spawnT = 0
		game.P.x = 258
		game.P.y = ground.y
		game.updateSlimes(0.02)
		require(enemy.state == "wind",kind + " did not enter real AI windup")
		require(game.painted_mob_pose(enemy).get("frame") == 0,kind + " windup lacks anticipation pose")
		var steps := 0
		while enemy.state == "wind" and steps < 40:
			game.updateSlimes(0.02)
			steps += 1
		var expected := "run" if kind == "boar" else ("spin" if kind == "tortoise" else "attack")
		require(game.painted_mob_pose(enemy).get("anim") == expected,kind + " AI attack selects incorrect artwork")
		if kind in ["boar", "tortoise"]:
			var first: int = game.painted_mob_pose(enemy).frame
			game.updateSlimes(0.07)
			require(game.painted_mob_pose(enemy).frame != first,kind + " attack animation is frozen")
		# A hit on the tortoise's closed shell avoids its random retreat-on-hit branch.
		if kind == "tortoise":
			enemy.state = "shell"
			enemy.t = 0.4
			require(game.painted_mob_pose(enemy).get("frame") == 3,"Tortoise does not hold fully closed shell")
		game.damageSlime(enemy,{"dmg":1.0,"kb":0,"up":0})
		require(game.painted_mob_pose(enemy).get("anim") == "hurt",kind + " damage lacks hurt art")
		require(game.painted_mob_pose(enemy).get("frame") == 0,kind + " hurt skips its first pose")
		game.damageSlime(enemy,{"dmg":1000000.0,"kb":0,"up":0})
		require(game.painted_mob_pose(enemy).get("anim") == "dead",kind + " lethal damage lacks death art")
		enemy.deadT = 0.44
		require(game.painted_mob_pose(enemy).get("frame") == 3,kind + " death lacks settled final pose")
	game.set_process(true)
	game.M.target = encounter_target
	var original: Texture2D = game.original_meadow
	tap(KEY_F2)
	await get_tree().process_frame
	require(game.encounter == 0 and game.slimes.any(func(e): return e.type == "green"),"F2 did not switch to slime encounter")
	tap(KEY_F2)
	await get_tree().process_frame
	require(game.encounter == 1 and game.slimes.any(func(e): return e.type == "rat"),"F2 did not restore forest encounter")
	tap(KEY_V)
	await get_tree().create_timer(0.3).timeout
	var gallery = get_tree().current_scene
	if not gallery.has_method("rebuild_cells"):
		require(false,"V did not enter animation gallery")
		get_tree().quit(1)
		return
	require(Assets._tex["maps/meadow.png"] == original,"Gallery entry did not restore original terrain cache")
	for step in 3:
		tap(KEY_TAB)
		await get_tree().process_frame
	require(gallery.filter_mode == 3,"Tab did not select forest gallery filter")
	require(gallery.cells.size() == 26,"Forest gallery does not contain all 26 action strips")
	gallery.paused = true
	for page in gallery.pages():
		gallery.page = page
		for frame in 4:
			gallery.step_frame = frame
			gallery.queue_redraw()
			await RenderingServer.frame_post_draw
			require(get_viewport().get_texture().get_image().save_png(output.path_join("forest_"+str(page)+"_"+str(frame)+".png")) == OK,"Could not save forest review")
	tap(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	var returned = get_tree().current_scene
	require(returned.has_method("preview_families") and returned.encounter == 1,"Gallery return lost forest encounter")
	require(returned.original_meadow == original,"Gallery return replaced original comparison texture")
	tap(KEY_B)
	await get_tree().process_frame
	require(not returned.painted and Assets._tex["maps/meadow.png"] == original,"B comparison failed after gallery return")
	get_tree().current_scene = self
	returned.queue_free()
	print("PAINTED_FOREST_PASS: four AI attack sequences, reactions/deaths, F2 switch, gallery filter and return, original comparison" if failures == 0 else "PAINTED_FOREST_FAILED")
	get_tree().quit(0 if failures == 0 else 1)

