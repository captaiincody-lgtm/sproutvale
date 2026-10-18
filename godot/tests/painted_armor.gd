extends Node
var failures := 0
var output := "user://painted-armor"

func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PAINTED_ARMOR_FAIL: " + message)

func tap(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)

func capture(game, name: String) -> void:
	game.shake = 0
	game.cam.x = 0
	game.cam.y = game.M.floorY - 174
	for frame in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	require(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Capture failed: " + name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://samples/painted_armor.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	if not game.has_method("painted_mob_pose"):
		require(false,"Armor sample failed to load")
		get_tree().quit(1)
		return
	get_tree().current_scene = game
	game.set_process(false)
	require(game.encounter == 3 and game.region == 3 and game.mapId == "crimson1","Armor scene opened wrong encounter or region")
	var families := {}
	for enemy in game.slimes:
		families[enemy.type] = enemy
	var target: int = game.M.target
	game.M.target = 0
	game.slimes.clear()
	game.P.x = 50
	game.P.y = game.M.floorY
	game.P.iframes = 0
	var ground: Dictionary = game.surfaces.filter(func(s): return s.get("floor",false))[0]
	for kind in ["cknight","ccrusader"]:
		require(families.has(kind),"Missing family: " + kind)
		if not families.has(kind):
			get_tree().quit(1)
			return
		var enemy = families[kind]
		enemy.surf = ground
		enemy.x = 170 if kind == "cknight" else 280
		enemy.y = ground.y
		enemy.face = 1
		enemy.state = "idle"
		enemy.walk = 0
		enemy.vx = 0
		enemy.vy = 0
		enemy.flash = 0
		enemy.sq = 0
		enemy.spawnT = 0
		game.slimes.append(enemy)
		require(int(Assets.data.mobs[kind].lv) > 40 and int(game.SLIME_TYPES[kind].lv) == int(game.SLIME_TYPES.green.lv),"Preview balance leaked to production data")
	await capture(game,"encounter")
	for kind in ["cknight","ccrusader"]:
		var enemy = families[kind]
		for distance in [28,110]:
			game.slimes.assign([enemy])
			enemy.x = 100
			enemy.y = ground.y
			enemy.surf = ground
			enemy.vx = 0
			enemy.vy = 0
			enemy.walk = 0
			enemy.state = "chase"
			enemy.aggro = true
			enemy.atkCd = 0
			enemy.hopCd = 10
			enemy.t = 0
			enemy.flash = 0
			enemy.hp = 10000
			enemy.maxHp = 10000
			game.P.x = enemy.x + distance
			game.P.y = ground.y
			game.P.hp = 10000
			game.P.iframes = 0
			game.P.touchCd = 100
			game.P.state = "idle"
			var move: String = ("swing" if distance == 28 else "bash") if kind == "cknight" else ("cleave" if distance == 28 else "leap")
			var anim: String = move if move in ["bash","leap"] else "attack"
			game.updateSlimes(0.01)
			require(enemy.state == "wind" and enemy.move == move,"Real AI failed to choose " + kind + "/" + move)
			require(game.painted_mob_pose(enemy).get("anim") == anim and game.painted_mob_pose(enemy).get("frame") == 0,"Wrong anticipation art for " + move)
			var steps := 0
			while enemy.state == "wind" and steps < 60:
				game.updateSlimes(0.01)
				steps += 1
			require(enemy.state == "act","Windup failed to reach act: " + move)
			require(game.P.hp == 10000,"Attack damaged player before active window: " + move)
			await capture(game,kind+"_"+move+"_start")
			if move in ["swing","cleave"]:
				game.updateSlimes(0.04)
				require(game.P.hp == 10000 and game.painted_mob_pose(enemy).frame == 1,"Sword struck before t=0.06: " + move)
				game.updateSlimes(0.04)
				require(game.P.hp < 10000 and game.painted_mob_pose(enemy).frame == 2,"Sword strike art and actual damage disagree: " + move)
				await capture(game,kind+"_"+move+"_hit")
				game.updateSlimes(0.24)
				require(game.painted_mob_pose(enemy).frame == 3,"Sword art stayed active after t=0.3: " + move)
			elif move == "bash":
				# Ground friction is applied after the AI sets the 320-unit dash.
				require(enemy.vx > 250 and game.painted_mob_pose(enemy).frame == 2,"Shield dash lacks active pose/velocity")
				game.P.x = enemy.x + 10
				game.updateSlimes(0.02)
				require(game.P.hp < 10000 and enemy.hitDone and enemy.state == "recover","Shield bash failed to hit and recover")
				require(game.painted_mob_pose(enemy).frame == 3,"Shield bash lacks recovery pose")
			else:
				require(enemy.vy < -300 and game.painted_mob_pose(enemy).frame == 1,"Leaping cleave failed to launch")
				steps = 0
				var saw_descent := false
				while enemy.state == "act" and steps < 120:
					game.P.x = enemy.x
					game.updateSlimes(0.01)
					if enemy.state == "act" and enemy.vy > 0:
						saw_descent = game.painted_mob_pose(enemy).frame == 2
					steps += 1
				require(saw_descent,"Leaping cleave lacks descending sword pose")
				require(enemy.state == "recover" and game.P.hp < 10000,"Leaping cleave failed to land, hit and recover")
				require(game.painted_mob_pose(enemy).frame == 3,"Leaping cleave lacks landing pose")
				enemy.x = 200
				game.P.x = 215
				await capture(game,kind+"_leap_land")
			steps = 0
			while enemy.state != "recover" and steps < 100:
				game.updateSlimes(0.01)
				steps += 1
			require(enemy.state == "recover" and game.painted_mob_pose(enemy).frame == 3,"Attack did not recover: " + move)
		game.damageSlime(enemy,{"dmg":1.0,"kb":0,"up":0})
		require(game.painted_mob_pose(enemy).anim == "hurt","Missing armor hurt reaction: " + kind)
		game.damageSlime(enemy,{"dmg":1000000.0,"kb":0,"up":0})
		enemy.deadT = 0.44
		require(game.painted_mob_pose(enemy).anim == "dead" and game.painted_mob_pose(enemy).frame == 3,"Missing armor final death pose: " + kind)
	game.M.target = target
	game.set_process(true)
	tap(KEY_R)
	await get_tree().process_frame
	tap(KEY_B)
	await get_tree().process_frame
	require(not game.painted and Assets._tex["maps/crimson1.png"] == game.original_region_art["maps/crimson1.png"],"Original-art toggle failed")
	tap(KEY_B)
	await get_tree().process_frame
	tap(KEY_F2)
	await get_tree().process_frame
	require(game.encounter == 0 and game.slimes.any(func(e): return e.type == "green"),"F2 did not wrap armor to slimes")
	for step in 3:
		tap(KEY_F2)
		await get_tree().process_frame
	require(game.encounter == 3 and game.slimes.any(func(e): return e.type == "cknight"),"F2 did not return to armor")
	tap(KEY_V)
	await get_tree().create_timer(0.3).timeout
	var gallery = get_tree().current_scene
	if not gallery.has_method("rebuild_cells"):
		require(false,"Gallery did not load")
		get_tree().quit(1)
		return
	for step in 5:
		tap(KEY_TAB)
		await get_tree().process_frame
	require(gallery.filter_mode == 5 and gallery.cells.size() == 14,"Armor gallery filter lacks 14 strips")
	gallery.paused = true
	for page in gallery.pages():
		gallery.page = page
		for frame in 4:
			gallery.step_frame = frame
			gallery.queue_redraw()
			await RenderingServer.frame_post_draw
			require(get_viewport().get_texture().get_image().save_png(output.path_join("armor_"+str(page)+"_"+str(frame)+".png")) == OK,"Gallery capture failed")
	tap(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	var returned = get_tree().current_scene
	require(returned.has_method("preview_map_id") and returned.region == 3 and returned.encounter == 3,"Gallery lost armor encounter or Crimson region")
	get_tree().current_scene = self
	returned.queue_free()
	await get_tree().process_frame
	print("PAINTED_ARMOR_PASS: sword damage windows, shield bash, leaping cleave landing, damage/death art, F2, comparison, gallery return" if failures == 0 else "PAINTED_ARMOR_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
