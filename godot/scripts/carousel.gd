class_name Carousel
extends Node3D
## Fast-mode carousel: the selected item in the middle, its neighbours either
## side, everything else recycled off-screen.
##
## Only WINDOW items exist as nodes no matter how big the library is — the two
## at the edges are always outside the frustum, so recycling never pops.

signal selection_changed(index: int, total: int, package: String, title: String)
signal launching(package: String)

const WINDOW := 7                      ## nodes kept alive (must be odd)
const MIN_WRAP := 4                    ## fewest items that can wrap without a visible repeat
const HALF := 3
const SPACING := 0.80
const CENTER_SCALE := 1.45
const SIDE_SCALE := 0.80
const SIDE_TILT := deg_to_rad(20.0)
const SIDE_DEPTH := -0.30
const FADE_FROM := 1.55                ## three on screen: previous, current, next

const SCROLL_SPEED := 9.0
const MAX_LAG := 1.6                   ## slots the view may trail the selection
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.085
const PAGE_JUMP := 10
const STICK_DEADZONE := 0.22
const STICK_SPEED := 2.6               ## radians per second at full tilt

var items: Array[Dictionary] = []
var index: int = 0
var locked: bool = false
## Cleared while a panel is open, so the shelf behind it does not move too.
var reads_input: bool = true               ## true while an insert animation runs

var _nodes: Array[MediaItem] = []
## How far the view is behind the selection, in slots. Relative on purpose:
## chasing the absolute index would slide the whole library across the screen
## when the selection wraps from the last item to the first.
var _lag: float = 0.0
var _repeat_dir: int = 0
var _repeat_timer: float = 0.0


func _ready() -> void:
	for i in WINDOW:
		var item := MediaItem.new()
		item.name = "Item%d" % i
		add_child(item)
		_nodes.append(item)
	AppBridge.icon_ready.connect(_on_icon_ready)
	_refresh_window(true)


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
	_refresh_window(true)
	_emit_selection()


func current() -> Dictionary:
	if items.is_empty():
		return {}
	return items[clampi(index, 0, items.size() - 1)]


func center_node() -> MediaItem:
	return _nodes[HALF]


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_lag = lerpf(_lag, 0.0, clampf(delta * SCROLL_SPEED, 0.0, 1.0))
	if absf(_lag) < 0.001:
		_lag = 0.0
	_layout()
	if locked or not reads_input:
		return
	_handle_repeat(delta)
	_handle_stick(delta)


func _layout() -> void:
	var total := items.size()
	for j in WINDOW:
		var node := _nodes[j]
		if total == 0:
			node.visible = false
			continue
		var offset := float(j - HALF) + _lag
		var slot := index + (j - HALF)
		if total >= MIN_WRAP:
			slot = wrapi(slot, 0, total)
		elif slot < 0 or slot >= total:
			node.visible = false
			continue
		node.visible = true
		node.set_item(slot, items[slot]["package"], items[slot]["name"])

		var dist := absf(offset)
		var t := clampf(dist, 0.0, 1.0)
		node.position = Vector3(offset * SPACING, 0.0, lerpf(0.0, SIDE_DEPTH, t))
		var s := lerpf(CENTER_SCALE, SIDE_SCALE, t)
		s = lerpf(s, SIDE_SCALE * 0.9, clampf(dist - 1.0, 0.0, 1.0))
		node.scale = Vector3.ONE * s
		node.rotation.y = -signf(offset) * SIDE_TILT * t
		node.is_center = dist < 0.5
		node.visible = dist < FADE_FROM


func _refresh_window(force: bool) -> void:
	if force:
		for node in _nodes:
			node.item_index = -1
	_layout()


func _on_icon_ready(package: String, tex: Texture2D) -> void:
	for node in _nodes:
		if node.package == package:
			node.apply_icon(tex)


# ---------------------------------------------------------------- navigation

func move(step: int) -> void:
	if items.is_empty() or step == 0:
		return
	var total := items.size()
	var next := index + step
	if total >= MIN_WRAP:
		next = wrapi(next, 0, total)
	else:
		next = clampi(next, 0, total - 1)
	if next == index:
		return
	index = next
	# step, not (next - old index): wrapping jumps the index the length of the
	# library, but the strip still only slides one slot.
	_lag = clampf(_lag + float(step), -MAX_LAG, MAX_LAG)
	Audio.play("move", 0.06)
	_layout()
	center_node().play_switch()
	_emit_selection()


func jump_to(target: int) -> void:
	if items.is_empty():
		return
	var next := clampi(target, 0, items.size() - 1)
	if next == index:
		return
	index = next
	_lag = 0.0
	Audio.play("move", 0.06)
	_refresh_window(true)
	_emit_selection()


func _emit_selection() -> void:
	_prefetch()
	var cur := current()
	selection_changed.emit(index, items.size(), str(cur.get("package", "")),
		str(cur.get("name", "")))


## Bakes covers a few slots past the visible three, so holding a direction
## never outruns them.
func _prefetch() -> void:
	var total := items.size()
	if total == 0:
		return
	for k in range(-6, 7):
		var i := wrapi(index + k, 0, total)
		var pkg := str(items[i]["package"])
		Covers.request(pkg, str(Library.record(pkg).get("model", "box")), absi(k) <= 1)


func _handle_repeat(delta: float) -> void:
	var dir := 0
	if Input.is_action_pressed("ui_right"):
		dir += 1
	if Input.is_action_pressed("ui_left"):
		dir -= 1

	if dir == 0:
		_repeat_dir = 0
		_repeat_timer = 0.0
		return

	if dir != _repeat_dir:
		# fresh press: the first pad input after touch only wakes the cursor
		_repeat_dir = dir
		_repeat_timer = REPEAT_DELAY
		if InputMode.consume_wake():
			return
		move(dir)
		return

	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = REPEAT_RATE
		move(dir)


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


# ---------------------------------------------------------------- touch

## Drag on the centre model, in screen pixels.
func rotate_center(drag: Vector2) -> void:
	if locked:
		return
	center_node().add_rotation(drag.x * 0.008)


# ---------------------------------------------------------------- launching

func launch_selected() -> void:
	if locked or items.is_empty():
		return
	var cur := current()
	var package := str(cur.get("package", ""))
	if package.is_empty():
		return
	locked = true
	Audio.play("insert")
	Audio.fade_out_music(0.5)
	launching.emit(package)
	var node := center_node()
	var tween := node.play_insert()
	tween.finished.connect(func() -> void:
		AppBridge.launch_app(package)
		# give Android a moment to take over, then put the shelf back
		await get_tree().create_timer(0.8).timeout
		node.reset_after_insert()
		locked = false
		_layout()
	)
