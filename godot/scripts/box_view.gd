class_name BoxView
extends Node3D
## Slow mode's second step: the selected case, opened flat.
##
## The lid swings open on the spine like a book. On the left, the inside of
## the lid holds the insert — a manual or art the user picked, or nothing.
## On the right, the tray holds the media itself, in whatever shape Inspect
## gave the app (a "box" app gets a disc, since a box is what it comes in).
##
## A plays the insert animation on the media and launches. B closes the lid
## and hands back to the shelf.

signal closed
signal launching(package: String)

const W := BoxMediaMesh.WIDTH
const H := BoxMediaMesh.HEIGHT
const LID := 0.012
const TRAY := 0.03
const OPEN_SCALE := 2.0
const OPEN_TIME := 0.55
const CLOSE_TIME := 0.38

var is_open: bool = false
var package: String = ""
var busy: bool = false

var _rig: Node3D            ## scaled and placed as one
var _hinge: Node3D          ## the lid turns around this, at the spine
var _cover_mat: StandardMaterial3D
var _insert_mat: StandardMaterial3D
var _plastic: StandardMaterial3D
var _tray_inner: StandardMaterial3D
var _media: MediaItem
var _insert_hint: Label3D
var _from: Transform3D
var _tween: Tween


func _ready() -> void:
	visible = false
	_plastic = StandardMaterial3D.new()
	_plastic.albedo_color = Color(0.09, 0.09, 0.12)
	_plastic.roughness = 0.4
	_tray_inner = StandardMaterial3D.new()
	_tray_inner.albedo_color = Color(0.14, 0.14, 0.18)
	_tray_inner.roughness = 0.65

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	# The tray: the half that stays put, with the media on it.
	var tray := MeshInstance3D.new()
	var tray_mesh := BoxMesh.new()
	tray_mesh.size = Vector3(W, H, TRAY)
	tray.mesh = tray_mesh
	tray.material_override = _plastic
	tray.position = Vector3(0, 0, -TRAY * 0.5)
	_rig.add_child(tray)
	var tray_face := MeshInstance3D.new()
	var face := QuadMesh.new()
	face.size = Vector2(W - 0.03, H - 0.03)
	tray_face.mesh = face
	tray_face.material_override = _tray_inner
	tray_face.position = Vector3(0, 0, 0.0008)
	_rig.add_child(tray_face)
	# the ring that holds a disc — reads as a case even with a cartridge in it
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.035
	hub_mesh.bottom_radius = 0.035
	hub_mesh.height = 0.01
	hub.mesh = hub_mesh
	hub.material_override = _plastic
	hub.rotation.x = PI * 0.5
	hub.position = Vector3(0, 0.02, 0.004)
	_rig.add_child(hub)

	# The lid, hinged on the left edge (the spine).
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-W * 0.5, 0, LID * 0.5 + 0.004)
	_rig.add_child(_hinge)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(W, H, LID)
	lid.mesh = lid_mesh
	lid.material_override = _plastic
	lid.position = Vector3(W * 0.5, 0, 0)
	_hinge.add_child(lid)

	_cover_mat = StandardMaterial3D.new()
	_cover_mat.roughness = 0.4
	_cover_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var cover := MeshInstance3D.new()
	var cover_quad := QuadMesh.new()
	cover_quad.size = Vector2(W - 0.008, H - 0.008)
	cover.mesh = cover_quad
	cover.material_override = _cover_mat
	cover.position = Vector3(W * 0.5, 0, LID * 0.5 + 0.0008)
	_hinge.add_child(cover)

	# The inside of the lid: faces the tray when shut, the camera when open.
	_insert_mat = StandardMaterial3D.new()
	_insert_mat.roughness = 0.6
	_insert_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var insert := MeshInstance3D.new()
	var insert_quad := QuadMesh.new()
	insert_quad.size = Vector2(W - 0.05, H - 0.05)
	insert.mesh = insert_quad
	insert.material_override = _insert_mat
	insert.position = Vector3(W * 0.5, 0, -LID * 0.5 - 0.0008)
	insert.rotation.y = PI
	_hinge.add_child(insert)

	_insert_hint = Label3D.new()
	_insert_hint.text = "No insert\nInspect → Box insert"
	_insert_hint.font_size = 36
	_insert_hint.pixel_size = 0.001
	_insert_hint.modulate = Color(1, 1, 1, 0.35)
	_insert_hint.outline_size = 0
	_insert_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_insert_hint.position = Vector3(W * 0.5, 0, -LID * 0.5 - 0.002)
	_insert_hint.rotation.y = PI
	_hinge.add_child(_insert_hint)

	_media = MediaItem.new()
	_media.name = "Media"
	_rig.add_child(_media)
	_media.set_shadow_visible(false)


## Opens the case for [param target], starting from where [param from] stands
## on the shelf, so the box seems to be the one that was picked up.
func open(target: String, from: MediaItem) -> void:
	package = target
	is_open = true
	busy = true
	visible = true
	_from = global_transform.affine_inverse() * from.global_transform

	var rec := Library.record(package)
	var art := ArtLibrary.texture(str(rec.get("cover", "")))
	_cover_mat.albedo_texture = art if art != null else Covers.cover_for(package, "box", true)
	var insert_art := ArtLibrary.texture(str(rec.get("insert", "")))
	var colors := Library.app_colors(package)
	if insert_art != null:
		_insert_mat.albedo_texture = insert_art
		_insert_mat.albedo_color = Color.WHITE
	else:
		_insert_mat.albedo_texture = null
		_insert_mat.albedo_color = (colors[1] as Color).darkened(0.55)
	_insert_hint.visible = insert_art == null
	_plastic.albedo_color = (colors[1] as Color).darkened(0.7)
	_tray_inner.albedo_color = (colors[1] as Color).darkened(0.5)

	# What lives inside: the app's own media, or a disc for a plain box.
	var kind := str(rec.get("model", "box"))
	_media.force_kind = "disc" if kind == "box" else kind
	_media.item_index = -1
	_media.set_item(0, package, Library.display_name(package, package))
	_media.reset_after_insert()
	# Fits the tray both ways: a disc is as wide as it is tall.
	var widths := {"disc": 0.56, "cartridge": 0.33, "card": 0.44}
	var fit := minf((H * 0.84) / BoxMediaMesh.height_for(_media.force_kind),
		(W * 0.88) / float(widths.get(_media.force_kind, W)))
	_media.scale = Vector3.ONE * minf(fit, 0.95)
	_media.position = Vector3(0, 0.0, 0.03)
	_media.is_center = true
	_media.reset_pop()

	# Start exactly where the shelf box is, shut.
	_rig.transform = _from
	_hinge.rotation.y = 0.0
	_media.visible = false

	_kill()
	_tween = create_tween().set_parallel(true)
	# Centre of the opened case: the tray is right of the hinge, the lid will
	# be left of it, so the pair is centred on the hinge.
	var open_at := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * OPEN_SCALE),
		Vector3(W * 0.5 * OPEN_SCALE, -0.02, 0.15))
	_tween.tween_property(_rig, "transform", open_at, OPEN_TIME * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _media.visible = true).set_delay(OPEN_TIME * 0.35)
	_tween.tween_property(_hinge, "rotation:y", -PI, OPEN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(OPEN_TIME * 0.3)
	_tween.chain().tween_callback(func() -> void: busy = false)
	Audio.play("select")


## Shuts the lid and puts the case back where it came from.
func close() -> void:
	if not is_open or busy:
		return
	busy = true
	Audio.play("back")
	_kill()
	_tween = create_tween()
	_tween.tween_property(_hinge, "rotation:y", 0.0, CLOSE_TIME * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _media.visible = false)
	_tween.tween_property(_rig, "transform", _from, CLOSE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		visible = false
		is_open = false
		busy = false
		closed.emit()
	)


## The media goes into the slot, then the app launches.
func play() -> void:
	if not is_open or busy:
		return
	busy = true
	Audio.play("insert")
	Audio.fade_out_music(0.5)
	launching.emit(package)
	var tween := _media.play_insert()
	tween.finished.connect(func() -> void:
		AppBridge.launch_app(package)
		await get_tree().create_timer(0.8).timeout
		_media.reset_after_insert()
		busy = false
	)


## Turns the media in the tray, with the stick or a drag.
func rotate_media(yaw: float) -> void:
	if is_open and not busy:
		_media.add_rotation(yaw)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
