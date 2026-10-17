class_name GridView
extends Node3D
## The other way to show a folder: rows of media rather than one at a time.
##
## Same contract as [Carousel] so the home screen can swap between them, and
## the same recycling idea — only the rows around the selection exist.

signal selection_changed(index: int, total: int, package: String, title: String)
signal launching(package: String)

const COLS := 4
const ROWS := 4                        ## rows of nodes kept alive (2 on screen)
const WINDOW := COLS * ROWS
const SPACING_X := 0.60
const SPACING_Y := 0.62                ## two rows fit between the bars at this pitch
const SELECTED_SCALE := 0.80
const ITEM_SCALE := 0.64
const ROW_OFFSET := 0.31               ## centres those two rows
const FADE_ROWS := 1.6

const SCROLL_SPEED := 9.0
const MAX_LAG := 1.4
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.085
const PAGE_JUMP := COLS * 2
const STICK_DEADZONE := 0.22
const STICK_SPEED := 2.6

var items: Array[Dictionary] = []
var index: int = 0
var locked: bool = false

var _nodes: Array[MediaItem] = []
var _lag: float = 0.0                  ## rows the view trails the selection
var _repeat: Vector2i = Vector2i.ZERO
var _repeat_timer: float = 0.0


func _ready() -> void:
	for i in WINDOW:
		var item := MediaItem.new()
		item.name = "Item%d" % i
		add_child(item)
		_nodes.append(item)
	AppBridge.icon_ready.connect(_on_icon_ready)
	_layout()


# ---------------------------------------------------------------- content

func set_items(list: Array[Dictionary], keep_package: String = "") -> void:
	items = list
	index = 0
	if not keep_package.is_empty():
		for i in items.size():
			if items[i]["package"] == keep_package:
				index = i
				break
	_lag = 0.0
	for node in _nodes:
		node.item_index = -1
	_layout()
	_emit_selection()


func current() -> Dictionary:
	if items.is_empty():
		return {}
	return items[clampi(index, 0, items.size() - 1)]


## The node holding the selection, or null while it is off screen.
func center_node() -> MediaItem:
	for node in _nodes:
		if node.item_index == index:
			return node
	return _nodes[0]


func row_count() -> int:
	return int(ceil(float(items.size()) / float(COLS)))


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_lag = lerpf(_lag, 0.0, clampf(delta * SCROLL_SPEED, 0.0, 1.0))
	if absf(_lag) < 0.001:
		_lag = 0.0
	_layout()
	if locked:
		return
	_handle_repeat(delta)
	_handle_stick(delta)


func _layout() -> void:
	var total := items.size()
	var rows := row_count()
	var selected_row := index / COLS
	# The window follows the selected row, one row above it so a move up has
	# something already instanced to show.
	var first_row := selected_row - 1

	for j in WINDOW:
		var node := _nodes[j]
		var row := first_row + (j / COLS)
		var col := j % COLS
		var slot := row * COLS + col
		if total == 0 or row < 0 or slot < 0 or slot >= total or rows == 0:
			node.visible = false
			continue
		node.visible = true
		node.set_item(slot, items[slot]["package"], items[slot]["name"])

		var is_selected := slot == index
		var y_row := float(row - selected_row) + _lag
		node.position = Vector3(
			(float(col) - float(COLS - 1) * 0.5) * SPACING_X,
			ROW_OFFSET - y_row * SPACING_Y,
			0.1 if is_selected else 0.0)
		node.scale = Vector3.ONE * (SELECTED_SCALE if is_selected else ITEM_SCALE)
		node.rotation.y = 0.0
		node.is_center = is_selected
		node.visible = absf(y_row) < FADE_ROWS


func _on_icon_ready(package: String, tex: Texture2D) -> void:
	for node in _nodes:
		if node.package == package:
			node.apply_icon(tex)


# ---------------------------------------------------------------- navigation

## Horizontal moves run through the whole folder and wrap at either end, so
## the grid loops the way the carousel does.
func move(step: int) -> void:
	if items.is_empty() or step == 0:
		return
	var next := wrapi(index + step, 0, items.size())
	if next == index:
		return
	var row_before := index / COLS
	index = next
	_lag = clampf(_lag + float(index / COLS - row_before), -MAX_LAG, MAX_LAG)
	Audio.play("move", 0.06)
	_layout()
	var node := center_node()
	if node != null:
		node.play_switch()
	_emit_selection()


## Vertical moves jump a whole row and stop at the ends rather than wrapping:
## rolling off the bottom onto the top of the list is disorienting in a grid.
func move_row(step: int) -> void:
	if items.is_empty() or step == 0:
		return
	var next := index + step * COLS
	if next < 0 or next >= items.size():
		next = clampi(next, 0, items.size() - 1)
		if next == index:
			return
	index = next
	_lag = clampf(_lag + float(step), -MAX_LAG, MAX_LAG)
	Audio.play("move", 0.06)
	_layout()
	var node := center_node()
	if node != null:
		node.play_switch()
	_emit_selection()


func jump_to(target: int) -> void:
	if items.is_empty():
		return
	var next := clampi(target, 0, items.size() - 1)
	if next == index:
		return
	index = next
	_lag = 0.0
	_layout()
	_emit_selection()


func _emit_selection() -> void:
	var cur := current()
	selection_changed.emit(index, items.size(), str(cur.get("package", "")),
		str(cur.get("name", "")))


func _handle_repeat(delta: float) -> void:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1

	if dir == Vector2i.ZERO:
		_repeat = Vector2i.ZERO
		_repeat_timer = 0.0
		return

	if dir != _repeat:
		_repeat = dir
		_repeat_timer = REPEAT_DELAY
		if InputMode.consume_wake():
			return
		_apply(dir)
		return

	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = REPEAT_RATE
		_apply(dir)


func _apply(dir: Vector2i) -> void:
	if dir.y != 0:
		move_row(dir.y)
	elif dir.x != 0:
		move(dir.x)


func _handle_stick(delta: float) -> void:
	var node := center_node()
	if node == null or not node.visible:
		return
	var rx := 0.0
	for device in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
		if absf(ax) > absf(rx):
			rx = ax
	if absf(rx) < STICK_DEADZONE:
		return
	node.add_rotation(rx * STICK_SPEED * delta)


func rotate_center(drag: Vector2) -> void:
	if locked:
		return
	var node := center_node()
	if node != null:
		node.add_rotation(drag.x * 0.008)


# ---------------------------------------------------------------- launching

func launch_selected() -> void:
	if locked or items.is_empty():
		return
	var package := str(current().get("package", ""))
	var node := center_node()
	if package.is_empty() or node == null:
		return
	locked = true
	Audio.play("insert")
	Audio.fade_out_music(0.5)
	launching.emit(package)
	var tween := node.play_insert()
	tween.finished.connect(func() -> void:
		AppBridge.launch_app(package)
		await get_tree().create_timer(0.8).timeout
		node.reset_after_insert()
		locked = false
		_layout()
	)
