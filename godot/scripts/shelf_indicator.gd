class_name ShelfIndicator
extends Control
## Where you are in the current folder: a track with a knob, and the count.
## With a big library a dot per app is useless, so it is a scrollbar instead.

const TRACK_H := 6.0
const KNOB_MIN := 26.0

var index: int = 0
var total: int = 0

var _label: Label
var _track: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 52)

	_label = Label.new()
	_label.name = "Count"
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_bottom = 26
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	_label.add_theme_color_override("font_color", Style.TEXT_DIM)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_track = Control.new()
	_track.name = "Track"
	_track.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_track.offset_top = -TRACK_H - 10.0
	_track.offset_bottom = -10.0
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	add_child(_track)


func set_position_in_folder(current: int, count: int) -> void:
	index = current
	total = count
	_label.text = "%d / %d" % [current + 1, count] if count > 0 else "empty"
	_track.queue_redraw()


func _draw_track() -> void:
	var w := _track.size.x
	var h := TRACK_H
	_track.draw_rect(Rect2(0, 0, w, h), Color(Style.TEXT_DIM, 0.25), true)
	if total <= 0:
		return
	var knob_w: float = maxf(w / float(total), KNOB_MIN)
	var span: float = maxf(w - knob_w, 1.0)
	var t: float = float(index) / float(maxi(total - 1, 1))
	_track.draw_rect(Rect2(span * t, 0, knob_w, h), Style.ACCENT, true)
