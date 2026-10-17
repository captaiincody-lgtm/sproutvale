extends Node2D
## An interactive playback board for reviewing the current painted animation batch.
const Cycles := preload("res://samples/painted_animation_library.gd")
const Ctx := preload("res://scripts/ctx.gd")
var cycles = Cycles.new()
var x = Ctx.new()
var elapsed := 0.0
var paused := false
var step_frame := 0
var cells: Array = []
var page := 0
const PAGE_SIZE := 12

func _ready() -> void:
	for kind in ["hero", "slime"]:
		for anim in cycles.data[kind]:
			cells.append([kind, anim])

func pages() -> int:
	return maxi(1, ceili(float(cells.size()) / PAGE_SIZE))

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				paused = not paused
				step_frame = int(elapsed * 6) % 4
			KEY_LEFT, KEY_RIGHT:
				paused = true
				step_frame = posmod(step_frame + (-1 if event.keycode == KEY_LEFT else 1),4)
			KEY_PAGEUP, KEY_PAGEDOWN:
				page = posmod(page + (-1 if event.keycode == KEY_PAGEUP else 1), pages())
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://samples/painted_meadow.tscn")

func _draw() -> void:
	x.begin(self)
	x.fillStyle = "#122729"
	x.fillRect(0,0,768,432)
	x.font = '18px "Fredoka"'
	x.fillStyle = "#f7e9bd"
	x.fillText("SPROUTVALE - Animation review   " + str(page+1) + "/" + str(pages()),16,25)
	for i in mini(PAGE_SIZE, cells.size() - page*PAGE_SIZE):
		var cell: Array = cells[page*PAGE_SIZE+i]
		var col := i % 4
		var row := i / 4
		var at := Vector2(col*192+7,row*120+38)
		x.fillStyle = "#203b3b" if i % 2 == 0 else "#1b3335"
		x.fillRect(at.x,at.y,178,112)
		x.fillStyle = "#eddcb1"
		x.font = '12px "Fredoka"'
		x.fillText(("ROCK" if cell[0] == "hero" else "SLIME") + " � " + cell[1],at.x+8,at.y+16)
		var frame: int = step_frame if paused else int(elapsed*6)%4
		x.fillStyle = "#547571"
		x.fillRect(at.x+8,at.y+98,162,1)
		x.save()
		x.translate(at.x+89,at.y+97)
		var preview_scale := 1.25
		x.scale(preview_scale,preview_scale)
		cycles.paint(x,cell[0],cell[1],frame,Vector2.ZERO)
		x.restore()
		x.font = '9px "Fredoka"'
		x.fillStyle = "#9db5ac"
		x.fillText(str(frame+1)+"/4",at.x+146,at.y+16)
	x.font = '12px "Fredoka"'
	x.fillStyle = "#d6ded0"
	x.fillText("Space: play/pause   Left/Right: frame   PgUp/PgDn: page   Esc: meadow",16,420)


