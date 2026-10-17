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

const WIDTH := 0.42
const HEIGHT := 0.60
const DEPTH := 0.075

static var _cached: ArrayMesh = null


static func get_mesh() -> ArrayMesh:
	if _cached == null:
		_cached = _build()
	return _cached


static func _build() -> ArrayMesh:
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
