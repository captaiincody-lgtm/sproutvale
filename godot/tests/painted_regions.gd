extends Node
var failures := 0
var output := "user://painted-regions"

func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PAINTED_REGIONS_FAIL: " + message)

func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)

func capture(game, name: String) -> void:
	game.set_process(false)
	game.cam.x = 0
	game.cam.y = game.M.floorY - 174
	game.P.x = 45
	game.P.y = game.M.floorY
	var selected := {}
	for enemy in game.slimes:
		if not selected.has(enemy.type):
			selected[enemy.type] = enemy
	game.slimes.clear()
	var slot := 0
	for kind in selected:
		var enemy = selected[kind]
		enemy.x = 110 + slot*48
		enemy.y = game.M.floorY - (45 if enemy.T.get("fly",false) else 0)
		enemy.state = "idle"
		enemy.walk = 0
		enemy.vx = 0
		enemy.vy = 0
		enemy.sq = 0
		enemy.flash = 0
		enemy.spawnT = 0
		game.slimes.append(enemy)
		slot += 1
	for frame in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	require(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Could not capture " + name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	var game = load("res://samples/painted_crimson.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if not game.has_method("preview_map_id"):
		require(false,"Regional sample failed to load")
		get_tree().quit(1)
		return
	get_tree().current_scene = game
	baseline = game.normalize(baseline)
	require(game.region == 3 and game.mapId == "crimson1","Crimson scene did not load its actual map")
	game.set_process(false)
	var families := {}
	for enemy in game.slimes:
		families[enemy.type] = enemy
	require(families.has("feet") and families.feet.partner != null and families.feet.partner.partner == families.feet,"Traveler foot pair was not preserved")
	var target: int = game.M.target
	game.M.target = 0
	game.P.iframes = 100
	for kind in ["evileye","hand","feet","torso","hairball"]:
		require(families.has(kind),"Crimson encounter did not spawn " + kind)
		if not families.has(kind):
			continue
		var enemy = families[kind]
		var ground: Dictionary = game.surfaces.filter(func(s): return s.get("floor",false))[0]
		enemy.surf = ground
		enemy.x = 230
		enemy.y = ground.y - (30 if enemy.T.get("fly",false) else 0)
		enemy.vx = 0
		enemy.vy = 0
		enemy.walk = 0
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
		require(enemy.state == "wind",kind + " real AI did not wind up")
		require(game.painted_mob_pose(enemy).get("frame") == 0,kind + " lacks anticipation")
		var steps := 0
		while enemy.state == "wind" and steps < 40:
			game.updateSlimes(0.02)
			steps += 1
		require(game.painted_mob_pose(enemy).get("anim") == ("spin" if kind == "hairball" else "attack"),kind + " real AI action uses wrong art")
		if kind == "hairball":
			var first: int = game.painted_mob_pose(enemy).frame
			game.updateSlimes(0.07)
			require(game.painted_mob_pose(enemy).frame != first,"Hair Spike rolling animation is frozen")
		game.damageSlime(enemy,{"dmg":1.0,"kb":0,"up":0})
		require(game.painted_mob_pose(enemy).get("anim") == "hurt",kind + " damage lacks hurt pose")
		game.damageSlime(enemy,{"dmg":1000000.0,"kb":0,"up":0})
		require(game.painted_mob_pose(enemy).get("anim") == "dead",kind + " lethal damage lacks death pose")
		enemy.deadT = 0.44
		require(game.painted_mob_pose(enemy).get("frame") == 3,kind + " death lacks settled pose")
	game.M.target = target
	for turn in game.REGION_IDS.size():
		game.set_process(true)
		tap(KEY_F3)
		await get_tree().process_frame
		var id: String = game.mapId
		require(game.M.plats == baseline.maps[id].plats and game.M.ropes == baseline.maps[id].ropes,"Regional art changed collisions or ropes: " + id)
		require(game.M.floorY == baseline.maps[id].floorY and game.M.w == baseline.maps[id].w,"Regional art changed map bounds: " + id)
		if id != "meadow":
			require(game.environments.texture(id,"backdrop") != null and game.environments.texture(id,"tile") != null,"Missing regional art: " + id)
		await capture(game,id)
		tap(KEY_B)
		await get_tree().process_frame
		require(Assets._tex["maps/"+id+".png"] == game.original_region_art["maps/"+id+".png"],"Original comparison failed: " + id)
		tap(KEY_B)
		await get_tree().process_frame
	game.set_process(true)
	tap(KEY_V)
	await get_tree().create_timer(0.3).timeout
	var gallery = get_tree().current_scene
	if not gallery.has_method("rebuild_cells"):
		require(false,"Gallery failed to open")
		get_tree().quit(1)
		return
	for step in 4:
		tap(KEY_TAB)
		await get_tree().process_frame
	require(gallery.filter_mode == 4 and gallery.cells.size() == 36,"Crimson review filter lacks its 36 strips")
	gallery.paused = true
	for page in gallery.pages():
		gallery.page = page
		for frame in 4:
			gallery.step_frame = frame
			gallery.queue_redraw()
			await RenderingServer.frame_post_draw
			require(get_viewport().get_texture().get_image().save_png(output.path_join("crimson_"+str(page)+"_"+str(frame)+".png")) == OK,"Could not capture Crimson review")
	tap(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	var returned = get_tree().current_scene
	require(returned.has_method("preview_map_id") and returned.region == 3 and returned.encounter == 2 and returned.mapId == "crimson1","Gallery return lost region or encounter")
	get_tree().current_scene = self
	returned.queue_free()
	await get_tree().process_frame
	print("PAINTED_REGIONS_PASS: five dark AI families, paired Travelers, six real maps, original comparison, gallery filter/return" if failures == 0 else "PAINTED_REGIONS_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
