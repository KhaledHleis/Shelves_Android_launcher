class_name MediaItem
extends Node3D
## One piece of 3D media — in v0.2 always the generic game case.
##
## The carousel owns where an item sits; the item owns how it looks and how it
## moves in place (idle sway, user rotation, the insert animation).

const SWAY_SPEED := 0.9
const SWAY_AMOUNT := 0.055
const ROTATE_RETURN_DELAY := 2.5
const ROTATE_RETURN_SPEED := 3.0

var package: String = ""
var title: String = ""
var item_index: int = -1
var is_center: bool = false

var _pivot: Node3D
var _box: MeshInstance3D
var _shadow: MeshInstance3D
var _cover_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D

var _user_yaw := 0.0                   ## yaw added by the right stick or a drag
var _kind: String = "box"
var _has_user_art := false
var _finish: String = "opaque"
var _shell: String = "matte"
var _idle_since := 0.0
var _phase := 0.0
var _locked := false                   ## true during the insert animation
var _pop: Tween                        ## the one scale tween on the pivot


func _init() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	_cover_mat = StandardMaterial3D.new()
	_cover_mat.roughness = 0.42
	_cover_mat.metallic = 0.05
	_body_mat = StandardMaterial3D.new()
	_body_mat.roughness = 0.6

	_box = MeshInstance3D.new()
	_box.name = "Box"
	_box.mesh = BoxMediaMesh.get_mesh()
	_box.set_surface_override_material(0, _cover_mat)
	_box.set_surface_override_material(1, _body_mat)
	_pivot.add_child(_box)

	# A soft contact shadow under the model. Without it the case floats: there
	# is nothing in the scene for it to stand on, so the shadow has to be
	# drawn rather than cast.
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_texture = _shadow_texture()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.55)
	shadow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	shadow_mat.no_depth_test = false
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(0.62, 0.30)
	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	_shadow.mesh = shadow_quad
	_shadow.material_override = shadow_mat
	_shadow.rotation_degrees = Vector3(-78, 0, 0)
	_pivot.add_child(_shadow)

	_phase = randf() * TAU
	Covers.cover_ready.connect(_on_cover_ready)


func _process(delta: float) -> void:
	if _locked:
		return
	_phase += delta * SWAY_SPEED
	_idle_since += delta

	var sway := Vector3.ZERO
	if is_center and bool(Settings.get_value("carousel_autorotate")):
		sway = Vector3(sin(_phase * 0.7) * SWAY_AMOUNT * 0.4, sin(_phase) * SWAY_AMOUNT, 0.0)

	if _idle_since > ROTATE_RETURN_DELAY and absf(_user_yaw) > 0.001:
		_user_yaw = lerpf(_user_yaw, 0.0, clampf(delta * ROTATE_RETURN_SPEED, 0, 1))

	# Yaw only. The small tilt on X belongs to the idle sway, not to the user:
	# letting a stick push pitch made the case tip away and never read flat.
	_pivot.rotation = Vector3(sway.x, sway.y + _user_yaw, 0.0)


# ---------------------------------------------------------------- content

func set_item(index: int, package_name: String, label: String) -> void:
	if item_index == index and package == package_name:
		return
	item_index = index
	package = package_name
	title = label
	_user_yaw = 0.0
	apply_customization()


## Reads this app's record: which shape, which finish, which art. Called when
## the item is reused and again whenever Inspect changes something.
func apply_customization() -> void:
	var rec := Library.record(package)
	_kind = str(rec.get("model", "box"))
	_finish = str(rec.get("finish", "opaque"))
	_shell = str(rec.get("shell", "matte"))
	_box.mesh = BoxMediaMesh.mesh_for(_kind)
	_apply_finish()
	_apply_shell()

	var half_height := BoxMediaMesh.height_for(_kind) * 0.5
	_shadow.position = Vector3(0, -half_height - 0.01, 0.04)

	# User art replaces the generated look entirely when it is set.
	var cover := ArtLibrary.texture(str(rec.get("cover", "")))
	var label_art := ArtLibrary.texture(str(rec.get("label", "")))
	var art: Texture2D = label_art if _kind in ["disc", "cartridge"] and label_art != null else cover
	_has_user_art = art != null
	if _has_user_art:
		_cover_mat.albedo_texture = art
	else:
		# Always something to show: the finished cover, or a draft of it
		# until the bake lands.
		_cover_mat.albedo_texture = Covers.cover_for(package, _kind, is_center)
	var white := Color.WHITE
	white.a = _cover_mat.albedo_color.a
	_cover_mat.albedo_color = white
	_apply_colors()


func _apply_finish() -> void:
	match _finish:
		"translucent":
			_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cover_mat.albedo_color.a = 0.55
			_cover_mat.roughness = 0.25
			_cover_mat.metallic = 0.0
		"clear":
			_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cover_mat.albedo_color.a = 0.28
			_cover_mat.roughness = 0.04
			_cover_mat.metallic = 0.0
		"metallic":
			_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_cover_mat.albedo_color.a = 1.0
			_cover_mat.metallic = 0.75
			_cover_mat.roughness = 0.30
		"glitter":
			_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_cover_mat.albedo_color.a = 1.0
			_cover_mat.metallic = 0.7
			_cover_mat.roughness = 0.12
			_cover_mat.rim_enabled = true
			_cover_mat.rim = 0.9
		_:
			_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_cover_mat.albedo_color.a = 1.0
			_cover_mat.metallic = 0.05
			_cover_mat.roughness = 0.42
			_cover_mat.rim_enabled = false


## The icon decoded: the shell colour comes from it. The cover follows
## through [signal Covers.cover_ready].
func apply_icon(_tex: Texture2D) -> void:
	_apply_colors()


func _on_cover_ready(pkg: String, kind: String, tex: Texture2D) -> void:
	if pkg == package and kind == _kind and not _has_user_art:
		_cover_mat.albedo_texture = tex


## The plastic the shape is made of, which is a different question from the
## finish on the art stuck to it.
func _apply_shell() -> void:
	match _shell:
		"glossy":
			_body_mat.roughness = 0.12
			_body_mat.metallic = 0.0
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		"smoked":
			_body_mat.roughness = 0.18
			_body_mat.metallic = 0.0
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_body_mat.albedo_color.a = 0.55
		"metal":
			_body_mat.roughness = 0.28
			_body_mat.metallic = 0.9
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		"rubber":
			_body_mat.roughness = 0.95
			_body_mat.metallic = 0.0
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_:
			_body_mat.roughness = 0.62
			_body_mat.metallic = 0.0
			_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_body_mat.albedo_color.a = 1.0


func _apply_colors() -> void:
	var colors := Library.app_colors(package)
	var deep: Color = colors[1]
	var shell_tint := deep.darkened(0.35)
	shell_tint.a = _body_mat.albedo_color.a
	_body_mat.albedo_color = shell_tint


static var _shadow_tex: Texture2D = null


## One soft ellipse, reused by every model.
static func _shadow_texture() -> Texture2D:
	if _shadow_tex != null:
		return _shadow_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(float(x) / size - 0.5, float(y) / size - 0.5).length() * 2.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


## Two dominant colours of the current item, for the background gradient.
func colors() -> Array:
	return Library.app_colors(package)


# ---------------------------------------------------------------- input

## Adds right-stick / drag rotation, in radians, around the upright axis only.
func add_rotation(yaw: float) -> void:
	if _locked:
		return
	# Wrap, never clamp: clamping stopped the case dead at half a turn, so it
	# could not be spun right round. Wrapping also means the spring back to
	# rest always takes the short way.
	_user_yaw = wrapf(_user_yaw + yaw, -PI, PI)
	_idle_since = 0.0


func reset_rotation() -> void:
	_user_yaw = 0.0
	_idle_since = 0.0


# ---------------------------------------------------------------- animation

## Plays when the selection lands on this item.
##
## Animates the pivot, never the root: the view writes the root scale every
## frame from the distance to the centre, so a tween on the same property left
## the model at whichever size happened to be written last.
func play_switch() -> void:
	if _locked:
		return
	_kill_pop()
	_pivot.scale = Vector3.ONE * 0.92
	_pop = create_tween()
	_pop.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_pivot, "scale", Vector3.ONE, 0.45)


## Leaving with the folder: shrinks away, accelerating. Folder changes are
## the only time a whole shelf goes at once, so the pieces go one by one.
func play_exit(duration: float, delay: float = 0.0) -> void:
	if _locked:
		return
	_kill_pop()
	_pop = create_tween()
	_pop.tween_interval(delay)
	_pop.tween_property(_pivot, "scale", Vector3.ONE * 0.001, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Arriving with a new folder: grows in from nothing and overshoots a little.
func play_enter(duration: float, delay: float = 0.0) -> void:
	if _locked:
		return
	_kill_pop()
	_pivot.scale = Vector3.ONE * 0.001
	_pop = create_tween()
	_pop.tween_interval(delay)
	_pop.tween_property(_pivot, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Full size at once, no animation — for a node coming back from an exit
## while it was out of sight.
func reset_pop() -> void:
	_kill_pop()
	if not _locked:
		_pivot.scale = Vector3.ONE


func _kill_pop() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_pop = null


## Cartridge-into-the-slot animation. Returns the tween so the caller can wait
## on it before launching.
func play_insert() -> Tween:
	_kill_pop()
	_pivot.scale = Vector3.ONE
	_locked = true
	var start := _pivot.position
	var tween := create_tween()
	tween.set_parallel(false)
	# settle upright
	tween.tween_property(_pivot, "rotation", Vector3.ZERO, 0.12)
	# small pull back, then push in
	tween.tween_property(_pivot, "position", start + Vector3(0, 0.04, 0.12), 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pivot, "scale", Vector3(1.06, 0.94, 1.0), 0.10)
	tween.parallel().tween_property(_pivot, "position", start + Vector3(0, -0.05, -0.9), 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_pivot, "scale", Vector3(0.9, 1.08, 1.0), 0.08)
	return tween


func reset_after_insert() -> void:
	_locked = false
	_pivot.position = Vector3.ZERO
	_pivot.scale = Vector3.ONE
	_pivot.rotation = Vector3.ZERO
	_user_yaw = 0.0
