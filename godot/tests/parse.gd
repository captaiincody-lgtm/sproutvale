extends Node
## loads a script by path (first user arg) so parse errors show up with autoloads present
func _ready() -> void:
	var p: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() else "res://scripts/game.gd"
	var s = load(p)
	print("LOADED " if s != null else "FAILED ", p)
	get_tree().quit()
