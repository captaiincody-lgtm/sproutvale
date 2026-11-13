extends Node
## Lines monsters up next to the hero on a map and saves a screenshot, to compare art before and after.
## Run:  godot --path godot res://tests/mobshow.tscn -- <output dir> <map> <monster,monster,...> [name]
## Put "!" after a monster's name for its shiny recolour and "*" for its elite one (e.g. rat!,boar*).
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://mobshow"
var map_id := "meadow"
var types: Array = []
var shot_name := "lineup"
var t := 0.0
var placed := false
var done := false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		map_id = args[1]
	if args.size() > 2:
		types = args[2].split(",")
	if args.size() > 3:
		shot_name = args[3]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mobshow_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://mobshow_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.fillQuests()
	game.selClass = "rock"


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	t += delta
	if t > 0.5 and t - delta <= 0.5:
		key(KEY_ENTER, true)
		get_tree().create_timer(0.05).timeout.connect(func(): key(KEY_ENTER, false))
	if t > 1.5 and t - delta <= 1.5 and game.intro != null:
		game.introSkip()
	if t > 2.5 and t - delta <= 2.5:
		game.fadeTo = {"map": map_id}
	if t > 4.5:
		game.World.t = 0.3   # midday
		_place()
	if t > 5.2 and not done:
		done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
		print("saved ", shot_name, " on ", game.mapId, " with ", types)
		get_tree().quit()


## keep the monsters standing in a row on the hero's floor, facing the hero
func _place() -> void:
	var P = game.P
	var floor = null
	for q in game.surfaces:
		if q.x0 <= P.x and P.x <= q.x1 and q.y >= P.y - 2 and not q.water:
			if floor == null or q.y < floor.y:
				floor = q
	if floor == null:
		return
	if not placed:
		placed = true
		game.slimes.clear()
		for i in types.size():
			var name: String = types[i]
			var shiny = name.ends_with("!")
			var elite = name.ends_with("*")
			name = name.trim_suffix("!").trim_suffix("*")
			var T: Dictionary = game.SLIME_TYPES[name]
			var e = game.S.Mob.new()
			e.id = 9000 + i
			e.type = name; e.T = T; e.lv = T.lv
			e.hp = T.hp; e.maxHp = T.hp; e.atk = 0; e.def = T.def; e.exp = 0
			e.w = 18.0; e.h = 16.0
			e.shiny = shiny
			e.elite = elite
			game.slimes.append(e)
	game.slimes = game.slimes.filter(func(e): return e.id >= 9000)   # nothing else spawns into the shot
	var n = game.slimes.size()
	var spacing = 44.0
	var x0 = P.x + 30.0
	for i in n:
		var e = game.slimes[i]
		e.x = clampf(x0 + i * spacing, floor.x0 + 10, floor.x1 - 10)
		e.y = floor.y
		e.surf = floor
		e.vx = 0; e.vy = 0
		e.state = "idle"
		e.face = -1
		e.aggro = false
		e.hopCd = 99.0
		e.atkCd = 99.0
		e.spawnT = 0.0
