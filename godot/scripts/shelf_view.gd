class_name ShelfView
extends Node3D
## Slow mode: the folder as a row of boxes standing on a shelf.
##
## Every box shows its spine — number, title, icon — except the selected one,
## which is pulled forward and turned to show its cover. A does not launch
## here: it asks for the box to be opened ([signal open_requested]).
##
## Same contract as [Carousel] and [GridView], so the home screen can swap
## between the three.

signal selection_changed(index: int, total: int, package: String, title: String)
signal launching(package: String)
signal open_requested(package: String, node: MediaItem)

const HALF := 13                       ## spines kept either side of the selection
const WINDOW := HALF * 2 + 1
const SCALE := 1.55
const GAP := 0.0015                    ## between spines: tight, so no sides show
const OPEN_GAP := 0.07                 ## between the selection and its neighbours
const PULL := 0.20                     ## how far the selection comes off the shelf
const SPINE_YAW := PI * 0.5            ## turns the -X face (the spine) to the camera

const SCROLL_SPEED := 10.0
const MAX_LAG := 3.0
const REPEAT_DELAY := 0.34
const REPEAT_RATE := 0.06
const PAGE_JUMP := 10
const STICK_DEADZONE := 0.22
const STICK_SPEED := 2.6

var items: Array[Dictionary] = []
var index: int = 0
var locked: bool = false
var reads_input: bool = true

var _nodes: Array[MediaItem] = []
var _lag: float = 0.0
var _repeat_dir: int = 0
var _repeat_timer: float = 0.0
var _board: MeshInstance3D
## The slot whose box is out of the shelf and open, so it is not drawn twice.
var hidden_slot: int = -1


func _ready() -> void:
	_build_board()
	for i in WINDOW:
		var item := MediaItem.new()
		item.name = "Box%d" % i
		item.force_kind = "shelfbox"
		add_child(item)
		_nodes.append(item)
	AppBridge.icon_ready.connect(_on_icon_ready)
	_layout()


## The plank the boxes stand on, and a lip along its front edge.
func _build_board() -> void:
	# Matte and dark: a lit plank across the whole screen was the brightest
	# thing in it.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.08)
	mat.roughness = 0.9
	mat.metallic_specular = 0.1
	var plank := BoxMesh.new()
	plank.size = Vector3(9.0, 0.045, 0.95)
	_board = MeshInstance3D.new()
	_board.name = "Board"
	_board.mesh = plank
	_board.material_override = mat
	_board.position = Vector3(0, -BoxMediaMesh.HEIGHT * SCALE * 0.5 - 0.024, -0.2)
	add_child(_board)

	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.13, 0.13, 0.16)
	lip_mat.roughness = 0.6
	lip_mat.metallic_specular = 0.2
	var lip := BoxMesh.new()
	lip.size = Vector3(9.0, 0.022, 0.02)
	var lip_node := MeshInstance3D.new()
	lip_node.mesh = lip
	lip_node.material_override = lip_mat
	lip_node.position = Vector3(0, 0.02, 0.47)
	_board.add_child(lip_node)


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


func center_node() -> MediaItem:
	for node in _nodes:
		if node.visible and node.item_index == index:
			return node
	return null


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


## Where a box sits, from how many places it is from the selection (which
## can be fractional while the shelf slides).
static func _x_for(offset: float) -> float:
	var spine := BoxMediaMesh.SHELF_DEPTH * SCALE + GAP
	var first := BoxMediaMesh.WIDTH * SCALE * 0.5 + OPEN_GAP + spine * 0.5
	var a := absf(offset)
	var x := lerpf(0.0, first, clampf(a, 0.0, 1.0)) + maxf(a - 1.0, 0.0) * spine
	return x * signf(offset)


func _layout() -> void:
	var total := items.size()
	_board.visible = total > 0
	if total == 0:
		for node in _nodes:
			node.visible = false
		return

	# Slot-keyed, as in the grid: a box keeps its app while it stays on the
	# shelf, so a step re-baked nothing.
	var wanted: Dictionary = {}
	for k in range(-HALF, HALF + 1):
		var slot := index + k
		if slot >= 0 and slot < total:
			wanted[slot] = true
	var spare: Array[MediaItem] = []
	var placed: Dictionary = {}
	for node in _nodes:
		if wanted.has(node.item_index) and not placed.has(node.item_index) \
				and node.spine_number == node.item_index + 1:
			placed[node.item_index] = node
		else:
			spare.append(node)
	for key in wanted:
		var slot: int = key
		if not placed.has(slot):
			var node: MediaItem = spare.pop_back()
			node.set_item(slot, items[slot]["package"], items[slot]["name"], slot + 1)
			placed[slot] = node
	for node in spare:
		node.visible = false
		node.item_index = -1

	for key in placed:
		var slot: int = key
		var node: MediaItem = placed[slot]
		var offset := float(slot - index) + _lag
		var t := clampf(absf(offset), 0.0, 1.0)
		var ease := t * t * (3.0 - 2.0 * t)
		node.visible = slot != hidden_slot
		node.scale = Vector3.ONE * SCALE
		# Turned spine-out, a box's spine sits half its width in front of its
		# centre, so shelved boxes are set back by that much to line their
		# spines up with the shelf edge.
		var back := -BoxMediaMesh.WIDTH * SCALE * 0.5
		node.position = Vector3(_x_for(offset), lerpf(0.03, 0.0, ease), lerpf(PULL, back, ease))
		# The spine always faces the camera on both sides; the selection
		# swings round from there to show its cover.
		node.rotation.y = lerpf(0.0, SPINE_YAW, ease)
		node.is_center = absf(offset) < 0.5


func _on_icon_ready(package: String, tex: Texture2D) -> void:
	for node in _nodes:
		if node.package == package:
			node.apply_icon(tex)


# ---------------------------------------------------------------- navigation

## The shelf has ends: running off one is a bump, not a wrap — a row of
## boxes that loops round is not a shelf.
func move(step: int) -> void:
	if items.is_empty() or step == 0:
		return
	var next := clampi(index + step, 0, items.size() - 1)
	if next == index:
		return
	_lag = clampf(_lag + float(next - index), -MAX_LAG, MAX_LAG)
	index = next
	Audio.play("move", 0.06)
	_layout()
	_emit_selection()


func jump_to(target: int) -> void:
	if items.is_empty():
		return
	var next := clampi(target, 0, items.size() - 1)
	if next == index:
		return
	_lag = clampf(float(next - index), -MAX_LAG, MAX_LAG)
	index = next
	Audio.play("move", 0.06)
	_layout()
	_emit_selection()


func _emit_selection() -> void:
	var cur := current()
	selection_changed.emit(index, items.size(), str(cur.get("package", "")),
		str(cur.get("name", "")))


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
	if node == null:
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


# ---------------------------------------------------------------- opening

## A in Slow mode opens the box rather than launching.
func launch_selected() -> void:
	if locked or items.is_empty():
		return
	var node := center_node()
	if node == null:
		return
	Audio.play("select")
	open_requested.emit(str(current().get("package", "")), node)
