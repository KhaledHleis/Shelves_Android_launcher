class_name WifiIcon
extends Control
## Signal bars. level is 0-4; connected false draws them all dim with a slash.

var connected: bool = false:
	set(value):
		connected = value
		queue_redraw()

var level: int = 0:
	set(value):
		level = clampi(value, 0, 4)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(34, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var bar_w := 6.0
	var gap := 3.0
	for i in 4:
		var h: float = size.y * (0.3 + 0.2333 * float(i))
		var x := float(i) * (bar_w + gap)
		var lit := connected and i < level
		var color := Style.TEXT if lit else Color(Style.TEXT_DIM, 0.35)
		draw_rect(Rect2(x, size.y - h, bar_w, h), color, true)
	if not connected:
		draw_line(Vector2(2, size.y - 2), Vector2(size.x - 2, 2), Style.BAD, 2.5, true)
