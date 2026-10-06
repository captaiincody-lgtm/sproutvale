extends Node2D
## A canvas that redraws every frame by calling `painter(self)`. The renderer and HUD draw
## through these, the same way the prototype painted one big canvas each frame.

var painter: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
