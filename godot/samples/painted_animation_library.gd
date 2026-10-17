extends RefCounted
const Ctx := preload("res://scripts/ctx.gd")
## Shared playback for normalized painted strips. The existing game owns all timing and hitboxes.
const BASE := "res://art/painted/"
var data: Dictionary
var textures := {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(BASE + "animations.json"))

func has_cycle(kind: String, anim: String) -> bool:
	return data.get(kind, {}).has(anim)

func count(kind: String, anim: String) -> int:
	return int(data[kind][anim].frames)

func frame_at(kind: String, anim: String, seconds: float, looping: bool = true) -> int:
	var cycle: Dictionary = data[kind][anim]
	var frame := maxi(0, floori(seconds * float(cycle.fps)))
	return frame % int(cycle.frames) if looping else mini(frame, int(cycle.frames) - 1)

func texture(kind: String, anim: String) -> Texture2D:
	var path: String = data[kind][anim].path
	if not textures.has(path):
		textures[path] = load(BASE + path)
	return textures[path]

func paint(x: Ctx, kind: String, anim: String, frame: int, at: Vector2, face: float = 1, alpha: float = 1, angle: float = 0) -> void:
	var cycle: Dictionary = data[kind][anim]
	var pixels: float = cycle.get("scale", 2)
	x.save()
	x.globalAlpha = alpha
	x.translate(at.x,at.y)
	if angle != 0:
		x.translate(0,-20)
		x.rotate(angle)
		x.translate(0,20)
	x.scale(face,1)
	x.drawFrame(texture(kind,anim),int(cycle.frames),clampi(frame,0,int(cycle.frames)-1),
		-float(cycle.foot[0])/pixels,-float(cycle.foot[1])/pixels,float(cycle.width)/pixels,float(cycle.height)/pixels)
	x.restore()


