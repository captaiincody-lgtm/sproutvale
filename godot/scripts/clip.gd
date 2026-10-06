extends Control
## A clipping window for a scrolling part of the menus: whatever `painter` draws is cut off at
## this control's rectangle, which `rect_fn` places each frame (an empty Rect2 hides it).

var painter: Callable
var rect_fn: Callable


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var r: Rect2 = rect_fn.call() if rect_fn.is_valid() else Rect2()
	visible = r.size.x > 0 and r.size.y > 0
	if visible:
		position = r.position
		size = r.size
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
