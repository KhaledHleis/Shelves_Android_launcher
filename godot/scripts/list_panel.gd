class_name ListPanel
extends Control
## The shape every v0.3 screen shares: a title, an optional search box, a list
## you move through with the pad or your finger, and a prompt bar.
##
## Subclasses say what the rows are and what the buttons do; everything about
## navigation, scrolling and prompts lives here once.

signal closed

const ROW_HEIGHT := 76
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.07

var rows: Array[Dictionary] = []       ## {id, text, suffix, icon, checked}
var selected: int = 0
var is_open: bool = false
## Only the panel on top of the stack reads input: two open panels both
## answering the pad made every press do two things at once.
var active: bool = true

var _title: Label
var _search: LineEdit
var _list: GridContainer
var _scroll: ScrollContainer
var _prompts: HBoxContainer
var _empty: Label
var _row_nodes: Array[Control] = []
var _repeat: Vector2i = Vector2i.ZERO
var _repeat_timer: float = 0.0
var _dialog: Control
var _cols: int = 1


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Style.BG_DARK
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 56
	_title.offset_top = 36
	_title.offset_bottom = 36 + 56
	_title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	_title.add_theme_color_override("font_color", Style.TEXT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_search.offset_left = 56
	_search.offset_right = -56
	_search.offset_top = 104
	_search.offset_bottom = 104 + 56
	_search.add_theme_font_size_override("font_size", Style.FONT_BODY)
	_search.visible = false
	_search.text_changed.connect(func(_t: String) -> void: refresh())
	add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 56
	_scroll.offset_right = -56
	_scroll.offset_top = 176
	_scroll.offset_bottom = -Style.BAR_HEIGHT - 16
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	# A GridContainer with one column behaves like a list, so both shapes use
	# the same code path.
	_list = GridContainer.new()
	_list.columns = 1
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 16)
	_scroll.add_child(_list)

	_empty = Label.new()
	_empty.text = "Nothing here"
	_empty.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_empty.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_empty.grow_vertical = Control.GROW_DIRECTION_BOTH
	_empty.add_theme_font_size_override("font_size", Style.FONT_BODY)
	_empty.add_theme_color_override("font_color", Style.TEXT_DIM)
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)

	_prompts = HBoxContainer.new()
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompts.offset_left = 56
	_prompts.offset_top = -Style.BAR_HEIGHT
	_prompts.add_theme_constant_override("separation", 32)
	add_child(_prompts)

	AppBridge.icon_ready.connect(func(_p: String, _t: Texture2D) -> void: _update_icons())
	_build_prompts()


# ---------------------------------------------------------------- open/close

func open() -> void:
	is_open = true
	visible = true
	selected = 0
	if _search != null:
		_search.text = ""
	refresh()


func close() -> void:
	is_open = false
	visible = false
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
	closed.emit()


func set_title(text: String) -> void:
	_title.text = text


func enable_search(enabled: bool) -> void:
	_search.visible = enabled
	_scroll.offset_top = 176 if enabled else 112


## More than one column turns the rows into tiles — what All apps uses.
func set_columns(count: int) -> void:
	_cols = maxi(count, 1)
	_list.columns = _cols
	refresh()


func search_text() -> String:
	return _search.text if _search != null else ""


# ---------------------------------------------------------------- rows

## Rebuilds the list from build_rows(), keeping the selection where it can.
func refresh() -> void:
	var keep := ""
	if selected >= 0 and selected < rows.size():
		keep = str(rows[selected].get("id", ""))
	rows = build_rows()
	if not keep.is_empty():
		for i in rows.size():
			if str(rows[i].get("id", "")) == keep:
				selected = i
				break
	selected = clampi(selected, 0, maxi(rows.size() - 1, 0))

	for node in _row_nodes:
		node.queue_free()
	_row_nodes.clear()

	for i in rows.size():
		_row_nodes.append(_make_row(i, rows[i]))
	_empty.visible = rows.is_empty()
	_paint_selection()


func _make_row(i: int, row: Dictionary) -> Control:
	if _cols > 1:
		return _make_tile(i, row)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_HEIGHT
	# A GridContainer only stretches a child that asks to expand; without this
	# every row shrank to the width of its own text.
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		if tapped:
			selected = i
			_paint_selection()
			activate()
	)
	_list.add_child(panel)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var pad := Control.new()
	pad.custom_minimum_size.x = 12
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pad)

	var package := str(row.get("icon", ""))
	if not package.is_empty():
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = AppBridge.get_icon(package)
		icon.set_meta("package", package)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var label := Label.new()
	label.text = str(row.get("text", ""))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", Style.FONT_BODY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var suffix := Label.new()
	suffix.text = str(row.get("suffix", ""))
	suffix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	suffix.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	suffix.add_theme_color_override("font_color", Style.TEXT_DIM)
	suffix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(suffix)

	var tick := Label.new()
	tick.text = "✓" if bool(row.get("checked", false)) else ""
	tick.custom_minimum_size.x = 44
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tick.add_theme_font_size_override("font_size", Style.FONT_BODY)
	tick.add_theme_color_override("font_color", Style.ACCENT)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tick)

	return panel


func _make_tile(i: int, row: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		if tapped:
			selected = i
			_paint_selection()
			activate()
	)
	_list.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var package := str(row.get("icon", ""))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not package.is_empty():
		icon.texture = AppBridge.get_icon(package)
		icon.set_meta("package", package)
	column.add_child(icon)

	var label := Label.new()
	label.text = str(row.get("text", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	var suffix := str(row.get("suffix", ""))
	if bool(row.get("checked", false)):
		suffix = "✓ " + suffix
	if not suffix.is_empty():
		var note := Label.new()
		note.text = suffix
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", Style.FONT_SMALL)
		note.add_theme_color_override("font_color", Style.ACCENT)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(note)

	return panel


func _paint_selection() -> void:
	for i in _row_nodes.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Style.ACCENT, 0.22) if i == selected else Color(1, 1, 1, 0.04)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		if i == selected:
			style.border_width_left = 4
			style.border_color = Style.ACCENT
		_row_nodes[i].add_theme_stylebox_override("panel", style)
	if selected >= 0 and selected < _row_nodes.size():
		_scroll.ensure_control_visible(_row_nodes[selected])


func _update_icons() -> void:
	for node in _row_nodes:
		var icon := node.find_child("Icon", true, false)
		if icon is TextureRect and (icon as TextureRect).texture == null:
			(icon as TextureRect).texture = AppBridge.get_icon(str(icon.get_meta("package", "")))


func selected_row() -> Dictionary:
	if selected < 0 or selected >= rows.size():
		return {}
	return rows[selected]


# ---------------------------------------------------------------- input

func _process(delta: float) -> void:
	if not is_open or not active:
		return
	if _dialog != null:
		if InputMode.back_just_pressed():
			_close_dialog()
		return
	if _search != null and _search.has_focus():
		# Typing: only the back button gets through, so B leaves the field.
		if InputMode.back_just_pressed():
			_search.release_focus()
		return

	if InputMode.back_just_pressed():
		Audio.play("back")
		close()
		return
	if InputMode.accept_just_pressed() and not InputMode.consume_wake():
		activate()
		return
	if Input.is_action_just_pressed("inspect"):
		on_alt(str(selected_row().get("id", "")))
		return
	if Input.is_action_just_pressed("all_apps"):
		on_alt2(str(selected_row().get("id", "")))
		return
	if Input.is_action_just_pressed("launcher_settings"):
		on_alt3(str(selected_row().get("id", "")))
		return

	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if dir == Vector2i.ZERO:
		_repeat = Vector2i.ZERO
		return
	if dir != _repeat:
		_repeat = dir
		_repeat_timer = REPEAT_DELAY
		if InputMode.consume_wake():
			return
		_move(dir)
		return
	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = REPEAT_RATE
		_move(dir)


func _move(dir: Vector2i) -> void:
	if rows.is_empty():
		return
	var next := selected
	if _cols <= 1:
		if dir.y != 0:
			next = wrapi(selected + dir.y, 0, rows.size())
	elif dir.x != 0:
		next = wrapi(selected + dir.x, 0, rows.size())
	elif dir.y != 0:
		next = clampi(selected + dir.y * _cols, 0, rows.size() - 1)
	if next == selected:
		return
	selected = next
	Audio.play("move", 0.06)
	_paint_selection()


func activate() -> void:
	var row := selected_row()
	if row.is_empty():
		return
	Audio.play("select")
	on_activate(str(row.get("id", "")))


func focus_search() -> void:
	if _search.visible:
		_search.grab_focus()


# ---------------------------------------------------------------- dialog

## A one-field dialog for naming things, since folders need names and there is
## nowhere else to type one.
func ask_text(prompt: String, initial: String, on_ok: Callable) -> void:
	_close_dialog()
	_dialog = Control.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialog)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(shade)

	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(760, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Style.BG_MID
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	_dialog.add_child(box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	box.add_child(column)

	var label := Label.new()
	label.text = prompt
	label.add_theme_font_size_override("font_size", Style.FONT_BODY)
	column.add_child(label)

	var field := LineEdit.new()
	field.text = initial
	field.add_theme_font_size_override("font_size", Style.FONT_BODY)
	field.custom_minimum_size.y = 64
	column.add_child(field)

	var hint := Label.new()
	hint.text = "Enter to confirm, B to cancel"
	hint.add_theme_font_size_override("font_size", Style.FONT_SMALL)
	hint.add_theme_color_override("font_color", Style.TEXT_DIM)
	column.add_child(hint)

	field.text_submitted.connect(func(text: String) -> void:
		_close_dialog()
		on_ok.call(text)
		refresh()
	)
	field.grab_focus()
	field.select_all()


func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


# ---------------------------------------------------------------- prompts

func _build_prompts() -> void:
	for child in _prompts.get_children():
		child.queue_free()
	for def in prompt_defs():
		var prompt := ButtonPrompt.new()
		prompt.action = str(def[0])
		prompt.label_text = str(def[1])
		prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_prompts.add_child(prompt)
		var id := str(def[0])
		prompt.activated.connect(func() -> void: _on_prompt_tapped(id))


func _on_prompt_tapped(action: String) -> void:
	match action:
		"ui_accept":
			activate()
		"ui_cancel":
			close()
		"inspect":
			on_alt(str(selected_row().get("id", "")))
		"all_apps":
			on_alt2(str(selected_row().get("id", "")))
		"launcher_settings":
			on_alt3(str(selected_row().get("id", "")))


# ---------------------------------------------------------------- subclasses

## What the list shows: [{id, text, suffix, icon, checked}]
func build_rows() -> Array[Dictionary]:
	return []


## Which prompts the footer shows: [[action, label], ...]
func prompt_defs() -> Array:
	return [["ui_accept", "Select"], ["ui_cancel", "Back"]]


func on_activate(_id: String) -> void:
	pass


func on_alt(_id: String) -> void:
	pass


func on_alt2(_id: String) -> void:
	pass


func on_alt3(_id: String) -> void:
	pass
