extends Node
var failures := 0
var output := "user://painted-pond-head"

func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PAINTED_POND_HEAD_FAIL: " + message)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code,true)
	key(code,false)

func capture(name: String) -> void:
	for frame in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	require(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Capture failed: " + name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://samples/painted_pond.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if not game.has_method("preview_map_id"):
		require(false,"Pond sample failed to load")
		get_tree().quit(1)
		return
	get_tree().current_scene = game
	require(game.mapId == "pond" and game.region == 4,"Pond scene opened wrong map")
	var baseline: Dictionary = game.normalize(Assets.data)
	require(game.M.pond == baseline.maps.pond.pond,"Pond water bounds changed")
	require(game.M.plats == baseline.maps.pond.plats and game.M.ropes == baseline.maps.pond.ropes,"Pond platform or rope geometry changed")
	require(game.Water.cols.size() > 20,"Live pond water did not initialize")
	game.slimes.clear()
	game.M.target = 0
	game.P.x = 800
	game.P.y = 440
	game.P.vx = 0
	game.P.vy = 0
	game.P.state = "move"
	game.P.grounded = false
	game.P.surf = null
	game.P.iframes = 10
	require(game.inWater(),"Hero is not recognized as submerged")
	key(KEY_RIGHT,true)
	await get_tree().create_timer(0.25).timeout
	key(KEY_RIGHT,false)
	require(game.P.x > 808,"Painted pond prevents swimming movement")
	var before_y: float = game.P.y
	key(KEY_SPACE,true)
	await get_tree().create_timer(0.09).timeout
	key(KEY_SPACE,false)
	require(game.P.y < before_y - 4,"Pond swim stroke did not lift hero")
	game.P.x = game.M.pond.x0 + 7
	game.P.y = game.M.pond.surface + 30
	game.P.vx = 0
	game.P.vy = 0
	key(KEY_LEFT,true)
	await get_tree().create_timer(0.25).timeout
	key(KEY_LEFT,false)
	require(game.P.x >= game.M.pond.x0 + 6.9,"Submerged hero passed through pond bank")
	game.set_process(false)
	game.bannerMsg.t = 99.0
	game.P.x = 800
	game.P.y = 435
	game.P.state = "move"
	game.P.iframes = 0
	game.cam.x = 605
	game.cam.y = 275
	game.splash(800,0.6)
	for frame in 8:
		game.updateWater(0.016)
	require(game.Water.cols.any(func(v): return absf(v) > 0.1),"Pond splash no longer animates water")
	await capture("pond-swim")
	# A solid legacy background fill used to hide all painted detail at this depth.
	var water_image := get_viewport().get_texture().get_image()
	var water_colors := {}
	for py in range(675,720,5):
		for px in range(680,920,20):
			water_colors[water_image.get_pixel(px,py).to_rgba32()] = true
	require(water_colors.size() > 12,"Painted water depth was obscured by a flat background fill")
	tap(KEY_B)
	await get_tree().process_frame
	require(not game.painted and Assets._tex["maps/pond.png"] == game.original_region_art["maps/pond.png"],"Pond original-art comparison failed")
	tap(KEY_B)
	await get_tree().process_frame
	game.set_process(true)
	tap(KEY_F3)
	await get_tree().process_frame
	require(game.mapId == "crimson2" and game.region == 5 and game.encounter == 2,"F3 did not enter Bone Hollow")
	game.set_process(false)
	require(game.M.plats == baseline.maps.crimson2.plats and game.M.ropes == baseline.maps.crimson2.ropes,"Bone Hollow geometry changed")
	var head = null
	for enemy in game.slimes:
		if enemy.type == "head":
			head = enemy
	require(head != null,"Crimson encounter did not spawn Floating Head")
	if head == null:
		get_tree().quit(1)
		return
	game.M.target = 0
	game.slimes.assign([head])
	head.x = 220
	head.y = game.M.floorY - 35
	head.state = "idle"
	head.t = 0
	head.flash = 0
	head.spawnT = 0
	head.vx = 0
	head.vy = 0
	head.hp = 10000
	head.maxHp = 10000
	head.showBar = 0
	head.aggro = false
	game.P.x = 90
	game.P.y = game.M.floorY
	game.P.iframes = 0
	game.cam.x = 0
	game.cam.y = game.M.floorY - 174
	await capture("bone-hollow")
	head.state = "chase"
	head.aggro = true
	head.atkCd = 0
	game.P.x = head.x + 35
	game.P.y = head.y + 20
	game.P.hp = 10000
	game.P.iframes = 0
	game.P.touchCd = 100
	game.updateSlimes(0.01)
	require(head.state == "wind" and game.painted_mob_pose(head).anim == "attack" and game.painted_mob_pose(head).frame == 0,"Floating Head lacks real AI bite anticipation")
	var steps := 0
	while head.state == "wind" and steps < 60:
		game.updateSlimes(0.01)
		steps += 1
	require(head.state == "lunge" and game.painted_mob_pose(head).frame == 2,"Floating Head lunge lacks open-jaw strike")
	require(game.P.hp == 10000,"Floating Head damaged hero during windup")
	game.P.x = head.x + 5
	game.P.y = head.y + 10
	game.updateSlimes(0.01)
	require(head.hitDone and game.P.hp < 10000,"Floating Head real bite failed to hit")
	steps = 0
	while head.state == "lunge" and steps < 80:
		game.updateSlimes(0.01)
		steps += 1
	require(head.state == "recover" and game.painted_mob_pose(head).frame == 3,"Floating Head lacks bite recovery")
	game.damageSlime(head,{"dmg":1.0,"kb":0,"up":0})
	require(game.painted_mob_pose(head).anim == "hurt","Floating Head lacks hurt reaction")
	game.damageSlime(head,{"dmg":1000000.0,"kb":0,"up":0})
	head.deadT = 0.44
	require(game.painted_mob_pose(head).anim == "dead" and game.painted_mob_pose(head).frame == 3,"Floating Head lacks final death pose")
	game.M.target = 8
	game.set_process(true)
	tap(KEY_R)
	await get_tree().process_frame
	tap(KEY_V)
	await get_tree().create_timer(0.3).timeout
	var gallery = get_tree().current_scene
	if not gallery.has_method("rebuild_cells"):
		require(false,"Gallery failed to load")
		get_tree().quit(1)
		return
	for step in 4:
		tap(KEY_TAB)
		await get_tree().process_frame
	require(gallery.cells.filter(func(c): return c[0] == "head").size() == 5,"Gallery lacks five Floating Head strips")
	gallery.paused = true
	gallery.page = gallery.pages()-1
	for frame in 4:
		gallery.step_frame = frame
		gallery.queue_redraw()
		await RenderingServer.frame_post_draw
		require(get_viewport().get_texture().get_image().save_png(output.path_join("head-review-"+str(frame)+".png")) == OK,"Head gallery capture failed")
	tap(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	var returned = get_tree().current_scene
	require(returned.has_method("preview_map_id") and returned.region == 5 and returned.encounter == 2,"Gallery lost Bone Hollow region or encounter")
	get_tree().current_scene = self
	returned.queue_free()
	await get_tree().process_frame
	print("PAINTED_POND_HEAD_PASS: original water geometry, swimming, bank walls, splash animation, Floating Head bite/damage/death, Bone Hollow gallery return" if failures == 0 else "PAINTED_POND_HEAD_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
