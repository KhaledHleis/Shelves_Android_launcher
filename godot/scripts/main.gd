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
## Slow mode: the shelf, and the case opened off it.
var shelf: ShelfView
var box_view: BoxView
var _shelf_z := 0.0
## Whichever of the two views the current folder is set to use.
var view: Node3D

var _all_apps: AllAppsPanel
var _folders: FoldersPanel
var _picker: FolderPickerPanel
var _settings: SettingsPanel
var _folder_edit: FolderEditPanel
var _inspect: InspectPanel
var _choice: ChoicePanel
## Panels open on top of each other (Settings → Folders → one folder), so
## they form a stack and only the top of it reads input.
var _stack: Array[ListPanel] = []

var _sky_material: ShaderMaterial
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _drag_accum := 0.0
var _drag_accum_y := 0.0
var _dragging := false
var _rotating := false
var _moved := 0.0
var _toast_tween: Tween

## Horizontal offsets of the 3D views: one moves the selection clear of the
## Inspect sheet, the other is the folder transition.
var _focus_shift := 0.0
var _slide := 0.0
var _fold_tween: Tween
var _fold_load_pending := false

const FOLD_OUT := 0.17
const FOLD_IN := 0.36
const FOLD_TRAVEL := 0.9


func _ready() -> void:
	var sky := env.environment.sky
	if sky != null and sky.sky_material is ShaderMaterial:
		_sky_material = sky.sky_material

	title.add_theme_font_size_override("font_size", Style.FONT_BODY)
	title.add_theme_color_override("font_color", Style.TEXT)
	title.add_theme_stylebox_override("normal", Style.pill(Color(0.06, 0.06, 0.09, 0.80)))
	toast.add_theme_font_size_override("font_size", Style.FONT_BODY)
	toast.modulate.a = 0.0

	if not AppBridge.has_plugin:
		_show_badge("MOCK DATA — plugin not loaded (tap for details)")
	elif AppBridge.plugin_returned_nothing():
		_show_badge("Plugin loaded but returned no apps (tap for details)")

	shelf = ShelfView.new()
	shelf.name = "ShelfView"
	shelf.visible = false
	world.add_child(shelf)
	box_view = BoxView.new()
	box_view.name = "BoxView"
	world.add_child(box_view)
	shelf.open_requested.connect(_open_box)
	box_view.closed.connect(_on_box_closed)

	view = carousel
	for v in _views():
		v.selection_changed.connect(_on_selection_changed)
	_build_panels()
	top_bar.folder_tapped.connect(func(step: int) -> void: switch_folder(step))
	bottom_bar.prompt_activated.connect(_on_prompt)
	Library.library_changed.connect(_on_library_changed)
	Library.folders_changed.connect(_on_library_changed)
	AppBridge.icon_ready.connect(_on_icon_ready)

	Settings.changed.connect(func(key: String) -> void:
		if key.begins_with("bg_"):
			_apply_background_style()
		elif key == "mode":
			_load_folder(true)
	)
	_apply_background_style()
	_on_library_changed()


func _build_panels() -> void:
	_all_apps = AllAppsPanel.new()
	_folders = FoldersPanel.new()
	_picker = FolderPickerPanel.new()
	_settings = SettingsPanel.new()
	_folder_edit = FolderEditPanel.new()
	_inspect = InspectPanel.new()
	_choice = ChoicePanel.new()
	for panel in [_all_apps, _folders, _picker, _settings, _folder_edit, _inspect, _choice]:
		$Overlay.add_child(panel)
		panel.closed.connect(_on_panel_closed.bind(panel))
		panel.choice_requested.connect(
			func(heading: String, options: Array, current: String, on_pick: Callable) -> void:
				_push(_choice)
				_choice.open_choice(heading, options, current, on_pick, panel == _inspect)
		)

	_all_apps.folder_requested.connect(func(package: String) -> void:
		_push(_picker)
		_picker.open_for(package)
	)
	_all_apps.inspect_requested.connect(func(package: String) -> void:
		_push(_inspect)
		_inspect.open_for(package)
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
	_inspect.folder_requested.connect(func(package: String) -> void:
		_push(_picker)
		_picker.open_for(package)
	)
	# A shape or a finish changing has to reach the models already on screen.
	_inspect.changed.connect(func(package: String) -> void:
		Covers.invalidate(package)
		for v in _views():
			for item in v.get_children():
				if item is MediaItem:
					(item as MediaItem).apply_customization()
		_on_selection_changed(view.index, view.items.size(),
			str(view.current().get("package", "")), Library.display_name(
				str(view.current().get("package", "")), str(view.current().get("name", ""))))
	)


## Opens a panel on top of whatever is already up.
func _push(panel: ListPanel) -> void:
	if not _stack.is_empty():
		_stack.back().active = false
	panel.active = true
	# Panels are siblings, so the one on top of the stack has to be the last
	# child too — otherwise it opens behind the opaque panel that opened it.
	$Overlay.move_child(panel, -1)
	_stack.append(panel)
	_set_view_input(false)


func _on_panel_closed(panel: ListPanel) -> void:
	_stack.erase(panel)
	_set_view_input(_stack.is_empty())
	if not _stack.is_empty():
		var top: ListPanel = _stack.back()
		top.active = true
		top.refresh()


## True while any panel is up — the home screen stops reading input then, so
## a press cannot move the shelf behind an open list.
func _set_view_input(enabled: bool) -> void:
	for v in _views():
		v.reads_input = enabled


func _views() -> Array[Node3D]:
	return [carousel, grid, shelf]


func panel_open() -> bool:
	return not _stack.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back gesture closes the top panel rather than the app.
		if not _stack.is_empty():
			_stack.back().close()
		elif box_view.is_open:
			box_view.close()
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
	if count <= 1 or view.locked or box_view.is_open:
		return
	folder_index = wrapi(folder_index + step, 0, count)
	Audio.play("folder")
	top_bar.set_folders(Library.folders(), folder_index)
	_play_folder_change(step)


## The old shelf eases out the way you pushed it, the new one eases in from
## the other side, and each piece pops in its own time — nearest first.
func _play_folder_change(step: int) -> void:
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.kill()
		# Pressed again mid-way: finish the swap now rather than drop it.
		if _fold_load_pending:
			_fold_load_pending = false
			_load_folder(false)
		for v in _views():
			for child in v.get_children():
				if child is MediaItem:
					(child as MediaItem).reset_pop()
	var dir := float(signi(step))
	_fold_load_pending = true
	for node in _visible_media(view):
		node.play_exit(FOLD_OUT, minf(absf(node.position.x) * 0.04, 0.05))
	_fold_tween = create_tween()
	_fold_tween.tween_method(func(v: float) -> void: _slide = v,
		_slide, -dir * FOLD_TRAVEL, FOLD_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fold_tween.tween_callback(func() -> void:
		_fold_load_pending = false
		_load_folder(false)
		_slide = dir * FOLD_TRAVEL
		# Anything that left but is not coming back on screen must not stay
		# shrunk for the next time it is used.
		for v in _views():
			for child in v.get_children():
				if child is MediaItem and (v != view or not (child as MediaItem).visible):
					(child as MediaItem).reset_pop()
		for node in _visible_media(view):
			node.play_enter(FOLD_IN, minf(node.position.length() * 0.09, 0.22))
	)
	_fold_tween.tween_method(func(v: float) -> void: _slide = v,
		dir * FOLD_TRAVEL, 0.0, FOLD_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _visible_media(v: Node3D) -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	for child in v.get_children():
		if child is MediaItem and (child as MediaItem).visible:
			out.append(child)
	return out


## How far left the views move so the selection sits in the middle of what
## the Inspect sheet leaves uncovered.
func _sheet_shift() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var vp := get_viewport().get_visible_rect().size
	var target := Vector2(vp.x * ListPanel.SHEET_LEFT * 0.5, vp.y * 0.5)
	return camera.project_position(target, camera.global_position.z).x


func _load_folder(keep_selection: bool) -> void:
	var folder := Library.folder_at(folder_index)
	if folder.is_empty():
		return
	var keep := ""
	if keep_selection and view != null:
		keep = str(view.current().get("package", ""))

	# Each folder remembers whether it is a carousel or a grid; Slow mode
	# puts every folder on the shelf.
	var wanted: Node3D = grid if str(folder.get("layout", "carousel")) == "grid" else carousel
	if str(Settings.get_value("mode")) == "slow":
		wanted = shelf
	if wanted != view:
		view.visible = false
		view.set_items([] as Array[Dictionary])
		view = wanted
		view.visible = true
	view.set_items(Library.apps_in_folder(str(folder["id"])), keep)
	# The grid prints every name on its own box, so the big centred title
	# underneath is just something for the bottom row to collide with.
	title.visible = view != grid
	bottom_bar.set_launch_text("Open" if view == shelf else "Launch")


# ---------------------------------------------------------------- selection

func _on_selection_changed(index: int, total: int, package: String, name: String) -> void:
	title.text = name
	# An empty folder has no name to show, and an empty pill is just a smudge.
	title.self_modulate.a = 0.0 if name.is_empty() else 1.0
	bottom_bar.indicator.set_position_in_folder(index, total)
	_tint_background(package)


func _on_icon_ready(package: String, _tex: Texture2D) -> void:
	if view != null and package == str(view.current().get("package", "")):
		_tint_background(package)


## Style and pattern are launcher-wide; the two colours are per app.
func _apply_background_style() -> void:
	if _sky_material == null:
		return
	_sky_material.set_shader_parameter("style", Settings.bg_style_index())
	_sky_material.set_shader_parameter("overlay", Settings.bg_overlay_index())
	_sky_material.set_shader_parameter("overlay_strength",
		float(Settings.get_value("bg_overlay_strength")))
	_sky_material.set_shader_parameter("speed", float(Settings.get_value("bg_speed")))
	_sky_material.set_shader_parameter("pattern_speed",
		float(Settings.get_value("bg_pattern_speed")))


func _tint_background(package: String) -> void:
	if _sky_material == null or package.is_empty():
		return
	var colors := Library.app_colors(package)
	# Kept well darker than the cover, so the selected model never sinks into
	# its own background.
	# Both ends are pulled down by the same amount, so the gradient reads as
	# two colours from the art rather than one colour fading into black.
	var vivid: Color = (colors[0] as Color).darkened(0.48)
	var deep: Color = (colors[1] as Color).darkened(0.52)
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


func _process(delta: float) -> void:
	var sheet_up := _stack.has(_inspect)
	var target := _sheet_shift() if sheet_up else 0.0
	_focus_shift = lerpf(_focus_shift, target, clampf(delta * 9.0, 0.0, 1.0))
	for v in _views():
		v.position.x = _focus_shift + _slide
	title.modulate.a = lerpf(title.modulate.a, 0.0 if sheet_up else 1.0,
		clampf(delta * 12.0, 0.0, 1.0))

	shelf.position.z = _shelf_z

	if box_view.is_open:
		if not panel_open():
			_box_input(delta)
		return
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
	if view == shelf:
		return ShelfView.PAGE_JUMP
	return GridView.PAGE_JUMP if view == grid else Carousel.PAGE_JUMP


# ---------------------------------------------------------------- slow mode

func _open_box(package: String, node: MediaItem) -> void:
	shelf.locked = true
	shelf.hidden_slot = shelf.index
	box_view.open(package, node)
	bottom_bar.set_launch_text("Play")
	# The shelf steps back out of the way while the case is open.
	create_tween().tween_property(self, "_shelf_z", -0.9, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title.self_modulate.a = 0.0


func _on_box_closed() -> void:
	shelf.hidden_slot = -1
	shelf.locked = false
	bottom_bar.set_launch_text("Open")
	title.self_modulate.a = 1.0


func _close_box() -> void:
	if box_view.busy:
		return
	box_view.close()
	create_tween().tween_property(self, "_shelf_z", 0.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _box_input(delta: float) -> void:
	if box_view.busy:
		return
	if InputMode.accept_just_pressed():
		if not InputMode.consume_wake():
			box_view.play()
	elif InputMode.back_just_pressed():
		_close_box()
	else:
		var rx := 0.0
		for device in Input.get_connected_joypads():
			var ax := Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
			if absf(ax) > absf(rx):
				rx = ax
		if absf(rx) > 0.22:
			box_view.rotate_media(rx * 2.6 * delta)


func _pointer_down(pos: Vector2) -> void:
	_press_pos = pos
	_press_time = Time.get_ticks_msec() / 1000.0
	_drag_accum = 0.0
	_drag_accum_y = 0.0
	_moved = 0.0
	_dragging = true
	_rotating = _centre_rect().has_point(pos)


func _pointer_drag(relative: Vector2) -> void:
	if box_view.is_open:
		_moved += relative.length()
		box_view.rotate_media(relative.x * 0.008)
		return
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
	if view == grid:
		# A grid has somewhere to go vertically, so a vertical swipe means
		# something there — in the carousel it would be a stray gesture.
		_drag_accum_y -= relative.y
		while absf(_drag_accum_y) >= SWIPE_STEP:
			grid.move_row(signi(int(_drag_accum_y)))
			_drag_accum_y -= signf(_drag_accum_y) * SWIPE_STEP


func _pointer_up(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var held := Time.get_ticks_msec() / 1000.0 - _press_time
	# A drag never launches — the v0.1 rule, kept.
	if _moved > TAP_SLOP or held > TAP_TIME:
		return
	if box_view.is_open:
		# Right half of the open case is the media: play it. Outside the case
		# closes it, the way B does. The insert side does nothing.
		var vp := get_viewport().get_visible_rect().size
		var case_rect := Rect2(vp.x * 0.17, vp.y * 0.12, vp.x * 0.66, vp.y * 0.76)
		if not case_rect.has_point(pos):
			_close_box()
		elif pos.x > vp.x * 0.5:
			box_view.play()
		return
	var centre := _centre_rect()
	if centre.has_point(pos):
		view.launch_selected()
		return
	if view == grid:
		# Step toward whatever was tapped, by whichever axis is further out.
		var offset := pos - centre.get_center()
		if absf(offset.y) / centre.size.y > absf(offset.x) / centre.size.x:
			grid.move_row(signi(int(offset.y)))
		else:
			grid.move(signi(int(offset.x)))
		return
	if pos.x < centre.position.x:
		view.move(-1)
	elif pos.x > centre.end.x:
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
			if box_view.is_open:
				box_view.play()
			else:
				view.launch_selected()
		"settings":
			_push(_settings)
			_settings.open()
		"all_apps":
			_push(_all_apps)
			_all_apps.open()
		"inspect":
			var cur: Dictionary = view.current()
			if not cur.is_empty():
				_push(_inspect)
				_inspect.open_for(str(cur["package"]), str(cur["name"]))
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
