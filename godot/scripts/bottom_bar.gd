class_name BottomBar
extends Control
## Prompts for the three screens that v0.3 / v0.4 bring in, the shelf
## indicator, and the launch prompt.

signal prompt_activated(id: String)

const SIDE_MARGIN := Style.GUTTER

var indicator: ShelfIndicator

var _launch_prompt: ButtonPrompt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = Style.BAR_HEIGHT

	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.color = Style.PANEL
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	# ---- left: screens
	var left := HBoxContainer.new()
	left.name = "Screens"
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = SIDE_MARGIN
	left.add_theme_constant_override("separation", 30)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)

	_add_prompt(left, "launcher_settings", "Settings", "settings")
	_add_prompt(left, "all_apps", "Apps", "all_apps")
	_add_prompt(left, "inspect", "Inspect", "inspect")

	# ---- centre: position in folder
	indicator = ShelfIndicator.new()
	indicator.name = "Indicator"
	indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	indicator.grow_horizontal = Control.GROW_DIRECTION_BOTH
	indicator.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(indicator)

	# ---- right: launch
	var right := HBoxContainer.new()
	right.name = "Launch"
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -SIDE_MARGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)

	_launch_prompt = _add_prompt(right, InputMode.accept_action(), "Launch", "launch")
	Settings.changed.connect(func(key: String) -> void:
		if key == "swap_ab":
			_launch_prompt.action = InputMode.accept_action()
	)


func _add_prompt(parent: Control, action: String, text: String, id: String) -> ButtonPrompt:
	var prompt := ButtonPrompt.new()
	prompt.action = action
	prompt.label_text = text
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(prompt)
	prompt.activated.connect(func() -> void: prompt_activated.emit(id))
	return prompt
