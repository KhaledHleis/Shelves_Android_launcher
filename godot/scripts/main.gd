extends Node
## The Fast-mode home screen: one folder at a time, shown as a 3D carousel,
## with the launcher chrome on top.

const SWIPE_STEP := 130.0       ## pixels of drag per selection step
const TAP_SLOP := 16.0
const TAP_TIME := 0.45
const CENTRE_W := 0.30          ## share of the screen treated as "the model"
const CENTRE_H := 0.58

@onready var world: Node3D = $World
@onready var carousel: Carousel = $World/Carousel
@onready var env: WorldEnvironment = $World/WorldEnvironment
@onready var top_bar: TopBar = $UI/TopBar
@onready var bottom_bar: BottomBar = $UI/BottomBar
@onready var title: Label = $UI/Title
@onready var toast: Label = $UI/Toast

var folder_index: int = 0

var _sky_material: ShaderMaterial
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _drag_accum := 0.0
var _dragging := false
var _rotating := false
var _moved := 0.0
var _toast_tween: Tween


func _ready() -> void:
	var sky := env.environment.sky
	if sky != null and sky.sky_material is ShaderMaterial:
		_sky_material = sky.sky_material

	title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	title.add_theme_color_override("font_color", Style.TEXT)
	toast.add_theme_font_size_override("font_size", Style.FONT_BODY)
	toast.modulate.a = 0.0

	carousel.selection_changed.connect(_on_selection_changed)
	top_bar.folder_tapped.connect(func(step: int) -> void: switch_folder(step))
	bottom_bar.prompt_activated.connect(_on_prompt)
	Library.library_changed.connect(_on_library_changed)
	AppBridge.icon_ready.connect(_on_icon_ready)

	_on_library_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		# Picks up anything installed or removed while we were in the background.
		Library.refresh()


# ---------------------------------------------------------------- folders

func _on_library_changed() -> void:
	var folders := Library.folders()
	folder_index = clampi(folder_index, 0, maxi(folders.size() - 1, 0))
	top_bar.set_folders(folders, folder_index)
	_load_folder(true)


func switch_folder(step: int) -> void:
	var count := Library.folder_count()
	if count <= 1 or carousel.locked:
		return
	folder_index = wrapi(folder_index + step, 0, count)
	Audio.play("folder")
	top_bar.set_folders(Library.folders(), folder_index)
	_load_folder(false)


func _load_folder(keep_selection: bool) -> void:
	var folder := Library.folder_at(folder_index)
	if folder.is_empty():
		return
	var keep := ""
	if keep_selection:
		keep = str(carousel.current().get("package", ""))
	carousel.set_items(Library.apps_in_folder(str(folder["id"])), keep)


# ---------------------------------------------------------------- selection

func _on_selection_changed(index: int, total: int, package: String, name: String) -> void:
	title.text = name
	bottom_bar.indicator.set_position_in_folder(index, total)
	_tint_background(package)


func _on_icon_ready(package: String, _tex: Texture2D) -> void:
	if package == str(carousel.current().get("package", "")):
		_tint_background(package)


func _tint_background(package: String) -> void:
	if _sky_material == null or package.is_empty():
		return
	var tex := AppBridge.get_icon(package)
	if tex == null:
		return
	var colors := IconColors.pair(tex, package)
	# Kept well darker than the cover, so the selected model never sinks into
	# its own background.
	var vivid: Color = (colors[0] as Color).darkened(0.62)
	var deep: Color = (colors[1] as Color).darkened(0.45)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(c: Color) -> void:
		_sky_material.set_shader_parameter("color_a", c),
		_sky_material.get_shader_parameter("color_a"), vivid, 0.5)
	tween.tween_method(func(c: Color) -> void:
		_sky_material.set_shader_parameter("color_b", c),
		_sky_material.get_shader_parameter("color_b"), deep, 0.5)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pointer_down(touch.position)
		else:
			_pointer_up(touch.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_pointer_drag((event as InputEventScreenDrag).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pointer_down(mb.position)
			else:
				_pointer_up(mb.position)
	elif event is InputEventMouseMotion:
		if _dragging:
			_pointer_drag((event as InputEventMouseMotion).relative)


func _process(_delta: float) -> void:
	if carousel.locked:
		return
	if InputMode.accept_just_pressed():
		if not InputMode.consume_wake():
			carousel.launch_selected()
	elif Input.is_action_just_pressed("folder_prev"):
		if not InputMode.consume_wake():
			switch_folder(-1)
	elif Input.is_action_just_pressed("folder_next"):
		if not InputMode.consume_wake():
			switch_folder(1)
	elif Input.is_action_just_pressed("page_prev"):
		carousel.jump_to(carousel.index - Carousel.PAGE_JUMP)
	elif Input.is_action_just_pressed("page_next"):
		carousel.jump_to(carousel.index + Carousel.PAGE_JUMP)
	elif Input.is_action_just_pressed("inspect"):
		_on_prompt("inspect")
	elif Input.is_action_just_pressed("all_apps"):
		_on_prompt("all_apps")
	elif Input.is_action_just_pressed("launcher_settings"):
		_on_prompt("settings")


func _pointer_down(pos: Vector2) -> void:
	_press_pos = pos
	_press_time = Time.get_ticks_msec() / 1000.0
	_drag_accum = 0.0
	_moved = 0.0
	_dragging = true
	_rotating = _centre_rect().has_point(pos)


func _pointer_drag(relative: Vector2) -> void:
	if not _dragging or carousel.locked:
		return
	_moved += relative.length()
	if _rotating:
		carousel.rotate_center(relative)
		return
	_drag_accum -= relative.x
	while absf(_drag_accum) >= SWIPE_STEP:
		carousel.move(signi(int(_drag_accum)))
		_drag_accum -= signf(_drag_accum) * SWIPE_STEP


func _pointer_up(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var held := Time.get_ticks_msec() / 1000.0 - _press_time
	# A drag never launches — the v0.1 rule, kept.
	if _moved > TAP_SLOP or held > TAP_TIME:
		return
	if _centre_rect().has_point(pos):
		carousel.launch_selected()
	elif pos.x < _centre_rect().position.x:
		carousel.move(-1)
	elif pos.x > _centre_rect().end.x:
		carousel.move(1)


func _centre_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * CENTRE_W
	var h := vp.y * CENTRE_H
	return Rect2(Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5), Vector2(w, h))


# ---------------------------------------------------------------- screens

func _on_prompt(id: String) -> void:
	match id:
		"launch":
			carousel.launch_selected()
		"settings":
			show_toast("Launcher settings arrive in v0.3")
		"all_apps":
			show_toast("All apps arrives in v0.3")
		"inspect":
			show_toast("Inspect arrives in v0.4")
		_:
			pass


func show_toast(text: String) -> void:
	Audio.play("back")
	toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
