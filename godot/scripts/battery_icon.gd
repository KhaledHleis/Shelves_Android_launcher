class_name BatteryIcon
extends Control
## Battery pill, drawn rather than imported so there is no art dependency.

var level: int = 100:
	set(value):
		level = clampi(value, 0, 100)
		queue_redraw()

var charging: bool = false:
	set(value):
		charging = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(52, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x - 6.0
	var h := size.y
	var body := Rect2(0, 0, w, h)
	var fill_color := Style.GOOD
	if charging:
		fill_color = Style.ACCENT
	elif level <= 15:
		fill_color = Style.BAD
	elif level <= 30:
		fill_color = Style.WARN

	draw_rect(body, Style.TEXT_DIM, false, 2.0)
	draw_rect(Rect2(w + 1.0, h * 0.3, 4.0, h * 0.4), Style.TEXT_DIM, true)
	var inner := Rect2(3, 3, maxf((w - 6.0) * level / 100.0, 2.0), h - 6.0)
	draw_rect(inner, fill_color, true)

	if charging:
		var cx := w * 0.5
		var pts := PackedVector2Array([
			Vector2(cx + 3, 4), Vector2(cx - 4, h * 0.55),
			Vector2(cx, h * 0.55), Vector2(cx - 3, h - 4),
			Vector2(cx + 4, h * 0.45), Vector2(cx, h * 0.45),
		])
		draw_colored_polygon(pts, Style.BG_DARK)
