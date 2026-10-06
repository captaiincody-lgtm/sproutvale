extends Node2D
## A canvas that redraws every frame by calling `painter(self)`, the way the prototype repainted
## its one big canvas each frame. `active` (optional) decides whether it shows at all.

var painter: Callable
var active: Callable


func _process(_delta: float) -> void:
	visible = active.call() if active.is_valid() else true
	if visible:
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
