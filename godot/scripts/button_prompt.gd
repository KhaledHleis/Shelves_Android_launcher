class_name ButtonPrompt
extends PanelContainer
## A button prompt: the glyph of the controller actually in use, plus a label.
##
## The glyph comes from the Controller Icons addon, so it follows the detected
## controller type and the "Prompt style" override in Settings. In touch mode
## there is no button to show, so the prompt collapses to a tappable label.

signal activated

## Input action this prompt stands for, e.g. "ui_accept" or "all_apps".
@export var action: String = "ui_accept":
	set(value):
		action = value
		_rebuild()

## Text shown next to the glyph.
@export var label_text: String = "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value

@export var icon_size: int = Style.PROMPT_ICON

## For prompts whose label only exists to be tappable (the folder arrows):
## the glyph says it better once a pad is in use.
@export var hide_text_on_pad: bool = false

var _icon: TextureRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.pill(Color(1, 1, 1, 0.08)))

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_icon)

	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	box.add_child(_label)

	_rebuild()
	Settings.changed.connect(_on_settings_changed)
	InputMode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(InputMode.using_pad)


func _gui_input(event: InputEvent) -> void:
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if tapped:
		accept_event()
		activated.emit()


func _rebuild() -> void:
	if _icon == null:
		return
	var tex := ControllerIconTexture.new()
	tex.path = action
	tex.force_controller_icon_style = Settings.forced_icon_style()
	_icon.texture = tex


func _on_settings_changed(key: String) -> void:
	if key == "prompt_style" or key == "swap_ab":
		_rebuild()


func _on_mode_changed(using_pad: bool) -> void:
	# No glyph makes sense while the user is tapping the screen.
	_icon.visible = using_pad
	_label.visible = not (using_pad and hide_text_on_pad)
	_label.add_theme_color_override("font_color",
		Style.TEXT_DIM if using_pad else Style.TEXT)
