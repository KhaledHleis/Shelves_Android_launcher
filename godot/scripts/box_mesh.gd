class_name BoxMediaMesh
extends RefCounted
## Builds the generic "game case" mesh used by every item in v0.2.
##
## Two surfaces, so the cover can be textured independently of the rest:
##   surface 0 — front face only (UV 0,0 top-left → 1,1 bottom-right)
##   surface 1 — back, spine, outer edge, top and bottom (per-face UV)
##
## v0.4 swaps in cartridge / disc / card meshes; v0.7 loads .glb files. Both
## plug in here, which is why the mesh is built rather than imported.

## A PS4 case: 171 x 135 x 14 mm in real life, so roughly 1 : 0.79 : 0.08.
const WIDTH := 0.42
const HEIGHT := 0.53
const DEPTH := 0.042

static var _cached: ArrayMesh = null


static func get_mesh() -> ArrayMesh:
	if _cached == null:
		_cached = _build()
	return _cached


static func _build() -> ArrayMesh:
	return _slab(WIDTH, HEIGHT, DEPTH, 0.016)


static func _build_flat() -> ArrayMesh:
	var w := WIDTH * 0.5
	var h := HEIGHT * 0.5
	var d := DEPTH * 0.5

	var mesh := ArrayMesh.new()

	# ---- surface 0: front face (+Z)
	var front := SurfaceTool.new()
	front.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(front,
		Vector3(-w, h, d), Vector3(w, h, d), Vector3(w, -h, d), Vector3(-w, -h, d),
		Vector3(0, 0, 1))
	front.generate_tangents()
	front.commit(mesh)

	# ---- surface 1: everything else
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	# back (-Z)
	_quad(body,
		Vector3(w, h, -d), Vector3(-w, h, -d), Vector3(-w, -h, -d), Vector3(w, -h, -d),
		Vector3(0, 0, -1))
	# spine (-X) — the face v0.5 prints the title on
	_quad(body,
		Vector3(-w, h, -d), Vector3(-w, h, d), Vector3(-w, -h, d), Vector3(-w, -h, -d),
		Vector3(-1, 0, 0))
	# opening edge (+X)
	_quad(body,
		Vector3(w, h, d), Vector3(w, h, -d), Vector3(w, -h, -d), Vector3(w, -h, d),
		Vector3(1, 0, 0))
	# top (+Y)
	_quad(body,
		Vector3(-w, h, -d), Vector3(w, h, -d), Vector3(w, h, d), Vector3(-w, h, d),
		Vector3(0, 1, 0))
	# bottom (-Y)
	_quad(body,
		Vector3(-w, -h, d), Vector3(w, -h, d), Vector3(w, -h, -d), Vector3(-w, -h, -d),
		Vector3(0, -1, 0))
	body.generate_tangents()
	body.commit(mesh)

	mesh.surface_set_name(0, "cover")
	mesh.surface_set_name(1, "body")
	return mesh


## Adds one quad, wound a→b→c→d, with UVs (0,0) (1,0) (1,1) (0,1).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var pts := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## The other media shapes. Same two-surface idea throughout: surface 0 is the
## face that carries the art, surface 1 is everything else.
static var _shapes: Dictionary = {}

const KINDS := ["box", "cartridge", "disc", "card"]


static func mesh_for(kind: String) -> ArrayMesh:
	if kind == "box" or not kind in KINDS:
		return get_mesh()
	if not _shapes.has(kind):
		match kind:
			"cartridge":
				_shapes[kind] = _cartridge()
			"disc":
				_shapes[kind] = _disc()
			"card":
				_shapes[kind] = _card()
	return _shapes[kind]


## Where the icon and title sit, per shape: half-depth and half-height.
static func depth_for(kind: String) -> float:
	match kind:
		"cartridge": return 0.055
		"disc": return 0.008
		"card": return 0.007
		_: return DEPTH * 0.5


static func height_for(kind: String) -> float:
	match kind:
		"cartridge": return 0.42
		"disc": return 0.56
		"card": return 0.30
		_: return HEIGHT


## A slab with a chamfered front edge: the bevel is what makes the shape read
## as an object rather than a painted rectangle, because it catches the light
## at a different angle from the face.
static func _slab(w: float, h: float, d: float, bevel: float = 0.018) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var hw := w * 0.5
	var hh := h * 0.5
	var hd := d * 0.5
	var iw := hw - bevel
	var ih := hh - bevel
	var fz := hd
	var bz := hd - bevel

	var front := SurfaceTool.new()
	front.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(front, Vector3(-iw, ih, fz), Vector3(iw, ih, fz), Vector3(iw, -ih, fz),
		Vector3(-iw, -ih, fz), Vector3(0, 0, 1))
	# the four chamfer faces, carrying the edge of the art with them
	_bevel_quad(front, Vector3(-iw, ih, fz), Vector3(iw, ih, fz),
		Vector3(hw, hh, bz), Vector3(-hw, hh, bz), Vector3(0, 0.7, 0.7),
		Vector2(0, 0), Vector2(1, 0))
	_bevel_quad(front, Vector3(iw, -ih, fz), Vector3(-iw, -ih, fz),
		Vector3(-hw, -hh, bz), Vector3(hw, -hh, bz), Vector3(0, -0.7, 0.7),
		Vector2(1, 1), Vector2(0, 1))
	_bevel_quad(front, Vector3(-iw, -ih, fz), Vector3(-iw, ih, fz),
		Vector3(-hw, hh, bz), Vector3(-hw, -hh, bz), Vector3(-0.7, 0, 0.7),
		Vector2(0, 1), Vector2(0, 0))
	_bevel_quad(front, Vector3(iw, ih, fz), Vector3(iw, -ih, fz),
		Vector3(hw, -hh, bz), Vector3(hw, hh, bz), Vector3(0.7, 0, 0.7),
		Vector2(1, 0), Vector2(1, 1))
	front.generate_tangents()
	front.commit(mesh)
	hd = bz

	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(body, Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd), Vector3(-hw, -hh, -hd),
		Vector3(hw, -hh, -hd), Vector3(0, 0, -1))
	_quad(body, Vector3(-hw, hh, -hd), Vector3(-hw, hh, hd), Vector3(-hw, -hh, hd),
		Vector3(-hw, -hh, -hd), Vector3(-1, 0, 0))
	_quad(body, Vector3(hw, hh, hd), Vector3(hw, hh, -hd), Vector3(hw, -hh, -hd),
		Vector3(hw, -hh, hd), Vector3(1, 0, 0))
	_quad(body, Vector3(-hw, hh, -hd), Vector3(hw, hh, -hd), Vector3(hw, hh, hd),
		Vector3(-hw, hh, hd), Vector3(0, 1, 0))
	_quad(body, Vector3(-hw, -hh, hd), Vector3(hw, -hh, hd), Vector3(hw, -hh, -hd),
		Vector3(-hw, -hh, -hd), Vector3(0, -1, 0))
	body.generate_tangents()
	body.commit(mesh)
	mesh.surface_set_name(0, "art")
	mesh.surface_set_name(1, "body")
	return mesh


## A Switch-style cartridge: a small plastic shell with a sticker on the
## front. The sticker is surface 0 — the art and its finish live there — and
## the shell is surface 1, which is where the plastic material applies. That
## split is the whole point of the shape.
static func _cartridge() -> ArrayMesh:
	var w := 0.33
	var h := 0.38
	var d := 0.036
	var hw := w * 0.5
	var hh := h * 0.5
	var hd := d * 0.5
	var mesh := ArrayMesh.new()

	# surface 0: the sticker, sitting just proud of the shell face
	var sticker := SurfaceTool.new()
	sticker.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sw := hw * 0.84
	var sh := hh * 0.80
	var sz := hd + 0.0012
	_quad(sticker, Vector3(-sw, sh + hh * 0.06, sz), Vector3(sw, sh + hh * 0.06, sz),
		Vector3(sw, -sh + hh * 0.06, sz), Vector3(-sw, -sh + hh * 0.06, sz), Vector3(0, 0, 1))
	sticker.generate_tangents()
	sticker.commit(mesh)

	# surface 1: the shell, with the corner notch a Switch card has and a
	# tapered foot where the contacts sit
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var notch := 0.055
	var foot := -hh + 0.055
	var front := [
		Vector3(-hw, hh, hd), Vector3(hw - notch, hh, hd), Vector3(hw, hh - notch, hd),
		Vector3(hw, foot, hd), Vector3(hw * 0.86, -hh, hd), Vector3(-hw * 0.86, -hh, hd),
		Vector3(-hw, foot, hd),
	]
	_fan(shell, front, Vector3(0, 0, 1), hw, hh, false)
	var back: Array[Vector3] = []
	for p in front:
		back.append(Vector3(p.x, p.y, -hd))
	_fan(shell, back, Vector3(0, 0, -1), hw, hh, true)
	for i in front.size():
		var a: Vector3 = front[i]
		var b: Vector3 = front[(i + 1) % front.size()]
		var edge := (b - a).normalized()
		var normal := Vector3(edge.y, -edge.x, 0).normalized()
		_quad(shell, Vector3(a.x, a.y, -hd), Vector3(b.x, b.y, -hd), b, a, normal)
	shell.generate_tangents()
	shell.commit(mesh)
	mesh.surface_set_name(0, "art")
	mesh.surface_set_name(1, "body")
	return mesh


## Triangle fan over a convex outline, UV mapped across its bounds.
static func _fan(st: SurfaceTool, pts: Array, normal: Vector3, hw: float, hh: float,
		flip: bool) -> void:
	var order := range(1, pts.size() - 1)
	for i in order:
		var tri := [pts[0], pts[i], pts[i + 1]]
		if flip:
			tri.reverse()
		for p in tri:
			st.set_normal(normal)
			st.set_uv(Vector2(p.x / (hw * 2.0) + 0.5, 0.5 - p.y / (hh * 2.0)))
			st.add_vertex(p)


static func _card() -> ArrayMesh:
	return _slab(0.44, 0.30, 0.014, 0.006)


## A flat annulus: label side, then the edge and the back.
static func _disc() -> ArrayMesh:
	const SEGMENTS := 48
	var outer := 0.28
	var inner := 0.045
	var hd := 0.008
	var mesh := ArrayMesh.new()

	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		_ring_quad(face, a0, a1, inner, outer, hd, Vector3(0, 0, 1), false)
	face.generate_tangents()
	face.commit(mesh)

	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		_ring_quad(body, a0, a1, inner, outer, -hd, Vector3(0, 0, -1), true)
		# outer rim
		var p0 := Vector3(cos(a0) * outer, sin(a0) * outer, hd)
		var p1 := Vector3(cos(a1) * outer, sin(a1) * outer, hd)
		_quad(body, Vector3(p0.x, p0.y, -hd), Vector3(p1.x, p1.y, -hd), p1, p0,
			Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0))
	body.generate_tangents()
	body.commit(mesh)
	mesh.surface_set_name(0, "art")
	mesh.surface_set_name(1, "body")
	return mesh


## One chamfer face. The two outer corners reuse the art UV of the inner edge
## they came from, so the texture does not shear across the bevel.
static func _bevel_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, uv_a: Vector2, uv_b: Vector2) -> void:
	var pts := [a, b, c, d]
	var uvs := [uv_a, uv_b, uv_b, uv_a]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal.normalized())
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


static func _ring_quad(st: SurfaceTool, a0: float, a1: float, inner: float, outer: float,
		z: float, normal: Vector3, flip: bool) -> void:
	var pts := [
		Vector3(cos(a0) * inner, sin(a0) * inner, z),
		Vector3(cos(a0) * outer, sin(a0) * outer, z),
		Vector3(cos(a1) * outer, sin(a1) * outer, z),
		Vector3(cos(a1) * inner, sin(a1) * inner, z),
	]
	if flip:
		pts.reverse()
	# UVs map the disc face onto the whole image, so round art lands right.
	var order := [0, 1, 2, 0, 2, 3]
	for i in order:
		var p: Vector3 = pts[i]
		st.set_normal(normal)
		st.set_uv(Vector2(p.x / outer * 0.5 + 0.5, 0.5 - p.y / outer * 0.5))
		st.add_vertex(p)
