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
@onready var grid: GridView = $World/GridView
@onready var env: WorldEnvironment = $World/WorldEnvironment
@onready var top_bar: TopBar = $UI/TopBar
@onready var bottom_bar: BottomBar = $UI/BottomBar
@onready var title: Label = $UI/Title
@onready var toast: Label = $UI/Toast

var folder_index: int = 0
## Whichever of the two views the current folder is set to use.
var view: Node3D

var _all_apps: AllAppsPanel
var _folders: FoldersPanel
var _picker: FolderPickerPanel
var _settings: SettingsPanel
var _folder_edit: FolderEditPanel
## Panels open on top of each other (Settings → Folders → one folder), so
## they form a stack and only the top of it reads input.
var _stack: Array[ListPanel] = []

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

	if not AppBridge.has_plugin:
		_show_badge("MOCK DATA — plugin not loaded (tap for details)")
	elif AppBridge.plugin_returned_nothing():
		_show_badge("Plugin loaded but returned no apps (tap for details)")

	view = carousel
	for v in [carousel, grid]:
		v.selection_changed.connect(_on_selection_changed)
	_build_panels()
	top_bar.folder_tapped.connect(func(step: int) -> void: switch_folder(step))
	bottom_bar.prompt_activated.connect(_on_prompt)
	Library.library_changed.connect(_on_library_changed)
	Library.folders_changed.connect(_on_library_changed)
	AppBridge.icon_ready.connect(_on_icon_ready)

	_on_library_changed()


func _build_panels() -> void:
	_all_apps = AllAppsPanel.new()
	_folders = FoldersPanel.new()
	_picker = FolderPickerPanel.new()
	_settings = SettingsPanel.new()
	_folder_edit = FolderEditPanel.new()
	for panel in [_all_apps, _folders, _picker, _settings, _folder_edit]:
		$Overlay.add_child(panel)
		panel.closed.connect(_on_panel_closed.bind(panel))

	_all_apps.folder_requested.connect(func(package: String) -> void:
		_push(_picker)
		_picker.open_for(package)
	)
	_folders.edit_requested.connect(func(folder_id: String) -> void:
		_push(_folder_edit)
		_folder_edit.open_for(folder_id)
	)
	_settings.open_folders.connect(func() -> void:
		_push(_folders)
		_folders.open()
	)
	_settings.open_hidden.connect(func() -> void:
		_all_apps.show_hidden = true
		_push(_all_apps)
		_all_apps.open()
	)
	_all_apps.closed.connect(func() -> void: _all_apps.show_hidden = false)


## Opens a panel on top of whatever is already up.
func _push(panel: ListPanel) -> void:
	if not _stack.is_empty():
		_stack.back().active = false
	panel.active = true
	_stack.append(panel)


func _on_panel_closed(panel: ListPanel) -> void:
	_stack.erase(panel)
	if not _stack.is_empty():
		var top: ListPanel = _stack.back()
		top.active = true
		top.refresh()


## True while any panel is up — the home screen stops reading input then, so
## a press cannot move the shelf behind an open list.
func panel_open() -> bool:
	return not _stack.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back gesture closes the top panel rather than the app.
		if not _stack.is_empty():
			_stack.back().close()
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
	if count <= 1 or view.locked:
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
	if keep_selection and view != null:
		keep = str(view.current().get("package", ""))

	# Each folder remembers whether it is a carousel or a grid.
	var wanted: Node3D = grid if str(folder.get("layout", "carousel")) == "grid" else carousel
	if wanted != view:
		view.visible = false
		view.set_items([] as Array[Dictionary])
		view = wanted
		view.visible = true
	view.set_items(Library.apps_in_folder(str(folder["id"])), keep)
	# The grid prints every name on its own box, so the big centred title
	# underneath is just something for the bottom row to collide with.
	title.visible = view == carousel


# ---------------------------------------------------------------- selection

func _on_selection_changed(index: int, total: int, package: String, name: String) -> void:
	title.text = name
	bottom_bar.indicator.set_position_in_folder(index, total)
	_tint_background(package)


func _on_icon_ready(package: String, _tex: Texture2D) -> void:
	if view != null and package == str(view.current().get("package", "")):
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
	if panel_open():
		return
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
	if view.locked or panel_open():
		return
	if InputMode.accept_just_pressed():
		if not InputMode.consume_wake():
			view.launch_selected()
	elif Input.is_action_just_pressed("folder_prev"):
		if not InputMode.consume_wake():
			switch_folder(-1)
	elif Input.is_action_just_pressed("folder_next"):
		if not InputMode.consume_wake():
			switch_folder(1)
	elif Input.is_action_just_pressed("page_prev"):
		view.jump_to(view.index - _page_jump())
	elif Input.is_action_just_pressed("page_next"):
		view.jump_to(view.index + _page_jump())
	elif Input.is_action_just_pressed("inspect"):
		_on_prompt("inspect")
	elif Input.is_action_just_pressed("all_apps"):
		_on_prompt("all_apps")
	elif Input.is_action_just_pressed("launcher_settings"):
		_on_prompt("settings")


func _page_jump() -> int:
	return GridView.PAGE_JUMP if view == grid else Carousel.PAGE_JUMP


func _pointer_down(pos: Vector2) -> void:
	_press_pos = pos
	_press_time = Time.get_ticks_msec() / 1000.0
	_drag_accum = 0.0
	_moved = 0.0
	_dragging = true
	_rotating = _centre_rect().has_point(pos)


func _pointer_drag(relative: Vector2) -> void:
	if not _dragging or view.locked:
		return
	_moved += relative.length()
	if _rotating:
		view.rotate_center(relative)
		return
	_drag_accum -= relative.x
	while absf(_drag_accum) >= SWIPE_STEP:
		view.move(signi(int(_drag_accum)))
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
		view.launch_selected()
	elif pos.x < _centre_rect().position.x:
		view.move(-1)
	elif pos.x > _centre_rect().end.x:
		view.move(1)


func _centre_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * CENTRE_W
	var h := vp.y * CENTRE_H
	return Rect2(Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5), Vector2(w, h))


# ---------------------------------------------------------------- screens

func _on_prompt(id: String) -> void:
	match id:
		"launch":
			view.launch_selected()
		"settings":
			_push(_settings)
			_settings.open()
		"all_apps":
			_push(_all_apps)
			_all_apps.open()
		"inspect":
			show_toast("Inspect arrives in v0.4")
		_:
			pass


## A list of apps that do not exist is worse than an empty screen, because it
## looks like it works. Say it on screen, not only in the log.
func _show_badge(text: String) -> void:
	var badge := Label.new()
	badge.name = "MockBadge"
	badge.text = text
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.offset_top = Style.BAR_HEIGHT + 12
	badge.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	badge.add_theme_color_override("font_color", Style.WARN)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.gui_input.connect(func(event: InputEvent) -> void:
		var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		if tapped:
			print(AppBridge.diagnostics())
			show_toast(AppBridge.diagnostics())
	)
	$UI.add_child(badge)


func show_toast(text: String) -> void:
	Audio.play("back")
	toast.text = text
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
