class_name GridView
extends Node3D
## The other way to show a folder: rows of media rather than one at a time.
##
## Same contract as [Carousel] so the home screen can swap between them, and
## the same recycling idea — only the rows around the selection exist.
##
## Square lattice with the selection in the middle of the screen: the grid
## moves, the cursor does not.

signal selection_changed(index: int, total: int, package: String, title: String)
signal launching(package: String)

const COLS := 5                        ## items per row in the lattice
const ROWS := 5                        ## rows of nodes kept alive (3 on screen)
const WINDOW := COLS * ROWS
const SPACING_X := 0.58
const SPACING_Y := 0.52                ## rows line up, so they need room
const SELECTED_SCALE := 0.84
const ITEM_SCALE := 0.56
const FADE_ROWS := 1.7
const FADE_COLS := 2.7

const SCROLL_SPEED := 9.0
const MAX_LAG_X := float(COLS)         ## a row wrap really does travel that far
const MAX_LAG_Y := 2.0
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.085
const PAGE_JUMP := COLS * 2
const STICK_DEADZONE := 0.22
const STICK_SPEED := 2.6

var items: Array[Dictionary] = []
var index: int = 0
var locked: bool = false

var _nodes: Array[MediaItem] = []
## How far the lattice still has to travel, in cells, on both axes: the
## selection is always drawn dead centre, so moving scrolls the grid rather
## than the cursor.
var _lag := Vector2.ZERO
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
	_lag = Vector2.ZERO
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
	_lag = _lag.lerp(Vector2.ZERO, clampf(delta * SCROLL_SPEED, 0.0, 1.0))
	if _lag.length() < 0.001:
		_lag = Vector2.ZERO
	_layout()
	if locked:
		return
	_handle_repeat(delta)
	_handle_stick(delta)


func _layout() -> void:
	var total := items.size()
	if total == 0:
		for node in _nodes:
			node.visible = false
		return

	var sel_row := index / COLS
	var sel_col := index % COLS
	var first_row := sel_row - (ROWS / 2)

	for j in WINDOW:
		var node := _nodes[j]
		var row := first_row + (j / COLS)
		var col := j % COLS
		var slot := row * COLS + col
		if row < 0 or slot < 0 or slot >= total:
			node.visible = false
			continue
		node.set_item(slot, items[slot]["package"], items[slot]["name"])

		# Measured from the selection, which is why it lands at the origin.
		var dx := float(col - sel_col) + _lag.x
		var dy := float(row - sel_row) + _lag.y
		var is_selected := slot == index
		node.position = Vector3(dx * SPACING_X, -dy * SPACING_Y, 0.12 if is_selected else 0.0)
		node.scale = Vector3.ONE * (SELECTED_SCALE if is_selected else ITEM_SCALE)
		node.rotation.y = 0.0
		node.is_center = is_selected
		node.visible = absf(dy) < FADE_ROWS and absf(dx) < FADE_COLS


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
	var before := index
	index = next
	_lag += Vector2(
		float(index % COLS - before % COLS),
		float(index / COLS - before / COLS))
	_clamp_lag()
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
	_lag += Vector2(0.0, float(step))
	_clamp_lag()
	Audio.play("move", 0.06)
	_layout()
	var node := center_node()
	if node != null:
		node.play_switch()
	_emit_selection()


## Per axis, not by length: clamping the vector as a whole turned the move
## from the end of a row to the start of the next — four columns across and
## one row down — into a short diagonal, which read as a cut.
func _clamp_lag() -> void:
	_lag = Vector2(
		clampf(_lag.x, -MAX_LAG_X, MAX_LAG_X),
		clampf(_lag.y, -MAX_LAG_Y, MAX_LAG_Y))


func jump_to(target: int) -> void:
	if items.is_empty():
		return
	var next := clampi(target, 0, items.size() - 1)
	if next == index:
		return
	index = next
	_lag = Vector2.ZERO
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
