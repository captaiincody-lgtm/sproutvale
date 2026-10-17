extends Node
var failures := 0
func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PAINTED_ANIMATION_FAIL: " + message)

func _ready() -> void:
	var out := "user://painted-animations"
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var library = preload("res://samples/painted_animation_library.gd").new()
	var count := 0
	for kind in ["hero","slime"]:
		for anim in library.data[kind]:
			var spec: Dictionary = library.data[kind][anim]
			var texture: Texture2D = library.texture(kind,anim)
			require(texture != null,kind + "/" + anim + " is missing")
			if texture == null:
				continue
			var image := texture.get_image()
			require(image.get_width() == int(spec.width)*4 and image.get_height() == int(spec.height),kind + "/" + anim + " has wrong strip dimensions")
			var seen := {}
			for frame in 4:
				var cell := image.get_region(Rect2i(frame*int(spec.width),0,int(spec.width),int(spec.height)))
				require(cell.get_used_rect().has_area(),kind + "/" + anim + " has an empty frame")
				seen[cell.get_data().hex_encode().sha256_text()] = true
			require(seen.size() >= 2,kind + "/" + anim + " contains no pose changes")
			count += 1
	require(count == 36,"Expected 32 Rock and four slime strips")
	var game = load("res://samples/painted_meadow.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.2).timeout
	if not game.has_method("painted_hero_pose"):
		require(false,"Sample did not load")
		get_tree().quit(1)
		return
	game.slimes.clear()
	game.M.target = 0
	var rock_anims: Array = game.ANIM_BY_ID.keys().slice(0,32)
	for anim in rock_anims:
		game.P.state = "move"
		game.setAnim(anim)
		game.P.animT = 0.12
		var pose: Dictionary = game.painted_hero_pose()
		require(not pose.is_empty(),"Missing runtime pose for " + anim)
		if not pose.is_empty():
			require(pose.anim == anim,"Incorrect strip selected for " + anim)
	for move in ["slash","rising","thrust","spin","heavy","air","aegis","whirl","air2","air3","stab"]:
		game.startMove(move)
		var hit := int(game.P.move.hits[0])
		var timing: Dictionary = game.ANIM_BY_ID[game.P.anim]
		game.P.moveT = (hit+0.1)/float(timing.fps)/game.PS.aspd
		require(game.painted_hero_pose().frame == 2,move + " painted strike is not aligned with its damage frame")
		require(game.painted_hero_pose().anim == game.P.move.anim,move + " selects another move's artwork")
		for extra_hit in game.P.move.hits:
			game.P.moveT = (int(extra_hit)+0.1)/float(timing.fps)/game.PS.aspd
			require(game.painted_hero_pose().frame == 2,move + " extra hit lacks its strike pose")
	game.queue_free()
	await get_tree().process_frame
	var gallery = load("res://samples/painted_animation_gallery.tscn").instantiate()
	add_child(gallery)
	await get_tree().create_timer(0.2).timeout
	gallery.paused = true
	for page in gallery.pages():
		gallery.page = page
		for frame in 4:
			gallery.step_frame = frame
			gallery.queue_redraw()
			await RenderingServer.frame_post_draw
			require(get_viewport().get_texture().get_image().save_png(out.path_join("gallery_" + str(page) + "_" + str(frame) + ".png")) == OK,"Could not capture gallery")
	print("PAINTED_ANIMATIONS_PASS: 36 strips, 144 nonempty frames, 32 Rock states, eleven move timelines, gallery pages" if failures == 0 else "PAINTED_ANIMATIONS_FAILED")
	get_tree().quit(0 if failures == 0 else 1)


