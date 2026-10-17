extends Node
var game
var out_dir := "user://painted-sample-check"

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("PAINTED_SAMPLE_FAIL: " + message)
		get_tree().quit(1)
	return condition

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(out_dir.path_join(name + ".png"))
	check(result == OK, "Could not save screenshot " + name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://samples/painted_meadow.tscn").instantiate()
	add_child(game)
	await pause(0.6)
	if not check(game.inGame and game.mapId == "meadow", "Sample did not enter meadow"):
		return
	if not check(game.painted and game.P.hp > 0, "Painted hero did not initialize"):
		return
	await shot("01_painted_idle")
	var start_x: float = game.P.x
	key(KEY_RIGHT, true)
	await pause(0.7)
	if not check(game.P.x > start_x + 15, "Right input did not move hero"):
		return
	var start_y: float = game.P.y
	key(KEY_SPACE, true)
	await pause(0.18)
	key(KEY_SPACE, false)
	if not check(game.P.y < start_y - 5, "Jump input did not lift hero"):
		return
	await shot("02_jump")
	key(KEY_RIGHT, false)
	await pause(0.8)
	key(KEY_Z, true)
	await pause(0.08)
	if not check(game.P.state == "attack", "Attack input did not start an attack"):
		return
	await shot("03_attack")
	key(KEY_Z, false)
	await pause(0.6)
	key(KEY_C, true)
	await pause(0.05)
	if not check(game.P.state in ["dash", "slide"], "Dodge input did not start a dodge"):
		return
	await shot("04_dodge")
	key(KEY_C, false)
	await pause(0.7)
	key(KEY_SHIFT, true)
	await pause(0.1)
	if not check(game.P.state == "block", "Block input did not start blocking"):
		return
	await shot("05_block")
	key(KEY_SHIFT, false)
	key(KEY_R, true)
	key(KEY_R, false)
	await pause(0.4)
	if not check(absf(game.P.x - 90) < 2 and game.P.hp == game.PS.hp, "Reset did not restore hero"):
		return
	key(KEY_B, true)
	key(KEY_B, false)
	await pause(0.2)
	if not check(not game.painted, "Comparison toggle did not select original art"):
		return
	await shot("06_original_comparison")
	key(KEY_B, true)
	key(KEY_B, false)
	await pause(0.2)
	if not check(game.painted, "Comparison toggle did not restore painted art"):
		return
	await shot("07_painted_restored")
	print("PAINTED_SAMPLE_PASS: movement, jump, attack, dodge, block, reset and comparison toggle")
	get_tree().quit()


