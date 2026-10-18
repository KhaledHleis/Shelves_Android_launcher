extends Node
## The printed cover for an app that has no picture of its own.
##
## A cover is one image — gradient, icon, title, the darker band at the foot —
## baked once into a texture and stuck on the art surface, the way a real
## cover or sticker is printed. Baking needs a rendered frame (the title is
## text), so it is asynchronous. That gap is what turned models into white
## rectangles while a grid scrolled: a model reassigned to a new app had no
## texture until its bake landed.
##
## So a request never returns nothing. [method cover_for] answers at once with
## the best thing available: the finished bake if there is one, otherwise a
## draft drawn on the CPU right there (gradient and icon, no title), and it
## queues the real bake, which arrives through [signal cover_ready].

signal cover_ready(package: String, kind: String, texture: Texture2D)

const SIZES := {
	"box": Vector2i(312, 400),
	"cartridge": Vector2i(336, 368),
	"disc": Vector2i(384, 384),
	"card": Vector2i(440, 300),
}
const DRAFT_SCALE := 4              ## the CPU draft is this many times smaller
const WORKERS := 3                  ## bakes in flight at once
const MAX_CACHE := 240

var _baked: Dictionary = {}         ## key -> Texture2D (with its icon)
var _drafts: Dictionary = {}        ## key -> Texture2D
var _queue: Array[String] = []      ## keys waiting, most urgent first
var _pending: Dictionary = {}       ## key -> true while queued or baking
var _free: Array[SubViewport] = []
var _can_bake := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The headless test runner has no renderer to read a bake back from.
	_can_bake = DisplayServer.get_name() != "headless"
	for i in WORKERS:
		var vp := SubViewport.new()
		vp.name = "Bake%d" % i
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.disable_3d = true
		add_child(vp)
		_free.append(vp)
	AppBridge.icon_ready.connect(_on_icon_ready)


static func key_for(package: String, kind: String) -> String:
	return "%s|%s" % [package, kind if SIZES.has(kind) else "box"]


## The cover to show now. Never null.
func cover_for(package: String, kind: String, urgent: bool = false) -> Texture2D:
	var key := key_for(package, kind)
	if _baked.has(key):
		return _baked[key]
	request(package, kind, urgent)
	if not _drafts.has(key):
		_drafts[key] = _draft(package, kind)
	return _drafts[key]


## True when [method cover_for] would return the finished bake.
func is_baked(package: String, kind: String) -> bool:
	return _baked.has(key_for(package, kind))


## Queues a bake without asking for anything to show — used to bake the
## neighbours of the selection before they scroll into view.
func request(package: String, kind: String, urgent: bool = false) -> void:
	var key := key_for(package, kind)
	if _baked.has(key) or package.is_empty():
		return
	if _pending.has(key):
		if urgent and _queue.has(key):
			_queue.erase(key)
			_queue.push_front(key)
		return
	_pending[key] = true
	if urgent:
		_queue.push_front(key)
	else:
		_queue.append(key)


## Throws a package's covers away — its name or colours changed.
func invalidate(package: String) -> void:
	for kind in SIZES:
		var key := key_for(package, kind)
		_baked.erase(key)
		_drafts.erase(key)


func _process(_delta: float) -> void:
	while not _free.is_empty() and not _queue.is_empty():
		var key: String = _queue.pop_front()
		_bake(key, _free.pop_back())


func _on_icon_ready(package: String, _tex: Texture2D) -> void:
	# Anything drawn before the icon existed is stale now.
	for kind in SIZES:
		var key := key_for(package, kind)
		if _drafts.has(key):
			_drafts.erase(key)
			var draft := _draft(package, kind)
			_drafts[key] = draft
			if not _baked.has(key):
				cover_ready.emit(package, kind, draft)
				request(package, kind, true)


# ---------------------------------------------------------------- drawing

func _colors(package: String) -> Array:
	return Library.app_colors(package)


## Gradient and icon only, on the CPU, small. Cheap enough to do inline.
func _draft(package: String, kind: String) -> Texture2D:
	var size: Vector2i = SIZES.get(kind, SIZES["box"]) / DRAFT_SCALE
	var colors := _colors(package)
	var img := _gradient_image(size, colors[0], colors[1])
	var icon := AppBridge.get_icon(package)
	if icon != null:
		var src := icon.get_image()
		if src != null and not src.is_empty():
			src = src.duplicate()
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			var side := int(minf(size.x, size.y) * _icon_share(kind))
			src.resize(side, side, Image.INTERPOLATE_BILINEAR)
			var at := _icon_rect(kind, Vector2(size)).position
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(at))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _gradient_image(size: Vector2i, vivid: Color, deep: Color) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var t := float(y) / float(maxi(size.y - 1, 1))
		var row := vivid.lerp(deep, pow(t, 0.8))
		for x in size.x:
			var c := row
			# a soft diagonal sheen, and a darker band under the title
			var sheen: float = clampf(1.0 - absf((float(x) / size.x) + t * 0.6 - 0.75) * 3.0, 0.0, 1.0)
			c = c.lerp(Color.WHITE, sheen * 0.10)
			if t > 0.70:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return img


static func _icon_share(kind: String) -> float:
	match kind:
		"disc": return 0.26
		"card": return 0.40
		_: return 0.44


## Where the icon goes, in a cover of this size. Explicit rects, no anchors:
## setting position on an anchored Control rewrites its offsets.
static func _icon_rect(kind: String, size: Vector2) -> Rect2:
	var side := minf(size.x, size.y) * _icon_share(kind)
	var centre := Vector2(size.x * 0.5, size.y * 0.36)
	if kind == "disc":
		centre.y = size.y * 0.24       # above the hole
	elif kind == "card":
		centre = Vector2(size.x * 0.28, size.y * 0.42)
	return Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side))


static func _title_rect(kind: String, size: Vector2) -> Rect2:
	match kind:
		"disc":
			return Rect2(size.x * 0.18, size.y * 0.64, size.x * 0.64, size.y * 0.16)
		"card":
			return Rect2(size.x * 0.50, size.y * 0.22, size.x * 0.44, size.y * 0.46)
		_:
			return Rect2(size.x * 0.08, size.y * 0.71, size.x * 0.84, size.y * 0.27)


func _bake(key: String, vp: SubViewport) -> void:
	var parts := key.split("|")
	var package := parts[0]
	var kind := parts[1]
	var size: Vector2i = SIZES[kind]

	if not _can_bake:
		_finish(key, vp, null)
		return

	vp.size = size
	for child in vp.get_children():
		child.free()
	var colors := _colors(package)

	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(
		_gradient_image(size / DRAFT_SCALE, colors[0], colors[1]))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.position = Vector2.ZERO
	bg.size = Vector2(size)
	vp.add_child(bg)

	var icon_tex := AppBridge.get_icon(package)
	if icon_tex != null:
		var rect := _icon_rect(kind, Vector2(size))
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.position = rect.position
		icon.size = rect.size
		vp.add_child(icon)

	var trect := _title_rect(kind, Vector2(size))
	var label := Label.new()
	label.text = Library.display_name(package, _app_name(package))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if kind == "card" \
		else HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30 if kind != "disc" else 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = trect.position
	label.size = trect.size
	vp.add_child(label)

	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var tex: Texture2D = null
	if image != null and not image.is_empty():
		image.generate_mipmaps()
		tex = ImageTexture.create_from_image(image)
	# Baked before the icon decoded: show it, never keep it, so the icon
	# arriving gets a real one.
	_finish(key, vp, tex, icon_tex != null)


func _finish(key: String, vp: SubViewport, tex: Texture2D, keep: bool = true) -> void:
	_pending.erase(key)
	_free.append(vp)
	if tex == null:
		return
	var parts := key.split("|")
	if not keep and AppBridge.get_icon(parts[0]) != null:
		# The icon landed while this was baking.
		request(parts[0], parts[1], true)
	if keep:
		if _baked.size() >= MAX_CACHE:
			_baked.erase(_baked.keys()[0])
		_baked[key] = tex
	cover_ready.emit(parts[0], parts[1], tex)


func _app_name(package: String) -> String:
	for app in Library.all_apps():
		if app["package"] == package:
			return str(app["name"])
	return package
