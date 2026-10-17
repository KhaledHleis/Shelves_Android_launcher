class_name TopBar
extends Control
## Clock on the left, folder tabs in the middle, status on the right.
##
## The contents are built in code so the layout stays in one readable place;
## colours and sizes come from Style.

signal folder_tapped(index: int)

const SIDE_MARGIN := 40

var _clock: Label
var _tabs_box: HBoxContainer
var _tab_labels: Array[Label] = []
var _battery: BatteryIcon
var _battery_label: Label
var _wifi: WifiIcon
var _clock_accum := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = Style.BAR_HEIGHT

	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.color = Style.PANEL
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	# ---- clock (left)
	_clock = Label.new()
	_clock.name = "Clock"
	_clock.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_clock.offset_left = SIDE_MARGIN
	_clock.offset_right = SIDE_MARGIN + 220
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", Style.FONT_BODY)
	_clock.add_theme_color_override("font_color", Style.TEXT)
	add_child(_clock)

	# ---- folder tabs (centre)
	var centre := HBoxContainer.new()
	centre.name = "Folders"
	centre.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centre.grow_vertical = Control.GROW_DIRECTION_BOTH
	centre.add_theme_constant_override("separation", 18)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var prev := ButtonPrompt.new()
	prev.action = "folder_prev"
	prev.label_text = "‹"
	prev.hide_text_on_pad = true
	prev.icon_size = 38
	centre.add_child(prev)
	prev.activated.connect(func() -> void: folder_tapped.emit(-1))

	_tabs_box = HBoxContainer.new()
	_tabs_box.name = "Tabs"
	_tabs_box.add_theme_constant_override("separation", 12)
	centre.add_child(_tabs_box)

	var next := ButtonPrompt.new()
	next.action = "folder_next"
	next.label_text = "›"
	next.hide_text_on_pad = true
	next.icon_size = 38
	centre.add_child(next)
	next.activated.connect(func() -> void: folder_tapped.emit(1))

	# ---- status (right)
	var status := HBoxContainer.new()
	status.name = "Status"
	status.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	status.offset_right = -SIDE_MARGIN
	status.alignment = BoxContainer.ALIGNMENT_END
	status.add_theme_constant_override("separation", 14)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)

	_wifi = WifiIcon.new()
	_wifi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_wifi)

	_battery_label = Label.new()
	_battery_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_battery_label.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	_battery_label.add_theme_color_override("font_color", Style.TEXT_DIM)
	status.add_child(_battery_label)

	_battery = BatteryIcon.new()
	_battery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_battery)

	_update_clock()
	AppBridge.battery_changed.connect(_on_battery)
	AppBridge.network_changed.connect(_on_network)
	_on_battery(int(AppBridge.get_battery_state()["level"]),
		bool(AppBridge.get_battery_state()["charging"]))
	_on_network(AppBridge.get_network_state())


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 1.0:
		_clock_accum = 0.0
		_update_clock()


func _update_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now["hour"]
	var suffix := ""
	if not bool(Settings.get_value("clock_24h")):
		suffix = " AM" if hour < 12 else " PM"
		hour = hour % 12
		if hour == 0:
			hour = 12
	_clock.text = "%02d:%02d%s" % [hour, now["minute"], suffix]


## Rebuilds the tab strip. Called whenever folders or the selection change.
func set_folders(folders: Array, selected: int) -> void:
	for child in _tabs_box.get_children():
		child.queue_free()
	_tab_labels.clear()
	for i in folders.size():
		var tab := Label.new()
		tab.text = str(folders[i].get("name", "?")).to_upper()
		tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.add_theme_font_size_override("font_size", Style.FONT_BODY)
		if i == selected:
			tab.add_theme_stylebox_override("normal", Style.pill(Style.SURFACE_HI))
			tab.add_theme_color_override("font_color", Style.BG_DARK)
		else:
			tab.add_theme_stylebox_override("normal", Style.pill(Color(1, 1, 1, 0.07)))
			tab.add_theme_color_override("font_color", Style.TEXT_DIM)
		_tabs_box.add_child(tab)
		_tab_labels.append(tab)


func _on_battery(level: int, charging: bool) -> void:
	_battery.level = level
	_battery.charging = charging
	_battery_label.text = "%d%%" % level


func _on_network(state: Dictionary) -> void:
	_wifi.connected = bool(state.get("connected", false)) and str(state.get("type", "")) == "wifi"
	_wifi.level = int(state.get("level", 0))
