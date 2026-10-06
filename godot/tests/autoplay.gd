extends Node
## Smoke test: starts the game, plays a short scripted run with fake key presses and saves screenshots.
## Run:  godot --path godot res://tests/autoplay.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run; uses a throwaway save file)

var game
var out_dir := "user://autoplay"
var t := 0.0
var shots := 0
var script_steps := [
	[0.5, "shot", "title"], [0.8, "tap", KEY_ENTER], [2.0, "shot", "home"],
	[2.1, "hold", KEY_RIGHT], [3.4, "release", KEY_RIGHT], [3.5, "shot", "walked"],
	[3.6, "tap", KEY_SPACE], [3.75, "shot", "jump"], [4.4, "tap", KEY_Z], [4.5, "tap", KEY_Z], [4.62, "shot", "slash"],
	[5.0, "warp", "meadow"], [6.5, "shot", "meadow"], [6.6, "hunt", 0], [9.0, "shot", "fight"], [9.1, "hunt", 0], [11.0, "shot", "fight2"],
	[11.5, "tap", KEY_TAB], [11.8, "shot", "panel"], [12.0, "tap", KEY_TAB],
	[12.2, "warp", "pond"], [13.6, "shot", "pond"], [13.7, "night", 0], [14.5, "shot", "night"], [14.6, "rain", 0], [19.0, "shot", "rain"],
	[19.1, "warp", "hollow"], [20.6, "shot", "hollow"], [20.7, "warp", "house"], [22.0, "shot", "house"], [22.1, "warp", "ridge"], [23.6, "shot", "ridge"], [24.0, "quit", 0],
]
var hunting := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autoplay_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://autoplay_save.json")
	add_child(game)
	game.save.settings.weather = "sunny"


func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	t += delta
	if hunting > 0:
		hunting -= delta
		_hunt()
	while script_steps.size() and script_steps[0][0] <= t:
		var s: Array = script_steps.pop_front()
		match s[1]:
			"shot":
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.save_png("%s/%02d_%s.png" % [out_dir, shots, s[2]])
				shots += 1
				print("shot ", s[2], " state=", game.P.state, " anim=", game.P.anim, " hp=", game.P.hp, " lv=", game.CH().level, " mobs=", game.mobs.size(), " coins=", game.save.coins)
			"tap":
				key(s[2], true)
				await get_tree().process_frame
				await get_tree().process_frame
				key(s[2], false)
			"hold": key(s[2], true)
			"release": key(s[2], false)
			"warp": game.fade_to = {"map": s[2], "x": null, "y": null}
			"hunt": hunting = 2.3
			"night": game.world.t = 0.95
			"rain": game.save.settings.weather = "rain"
			"quit":
				print("errors? none fatal; quitting")
				get_tree().quit()


## walk at the nearest monster and keep swinging
func _hunt() -> void:
	var P = game.P
	var best = null
	for e in game.mobs:
		if e.state != "dead" and abs(e.y - P.y) < 30 and (best == null or abs(e.x - P.x) < abs(best.x - P.x)):
			best = e
	key(KEY_LEFT, false); key(KEY_RIGHT, false)
	if best == null:
		return
	if abs(best.x - P.x) > 30:
		key(KEY_RIGHT if best.x > P.x else KEY_LEFT, true)
	else:
		P.face = 1 if best.x > P.x else -1
		key(KEY_Z, true); key(KEY_Z, false)
