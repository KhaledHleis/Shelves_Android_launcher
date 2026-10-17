extends Node
## Writes the media shapes out as .glb files to model from.
##   godot --headless --path godot tools/export_templates.tscn
##
## Each one carries the contract the launcher expects: material "art" on the
## faces that show the cover or sticker, material "body" on everything else.

const OUT := "user://templates"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for kind in BoxMediaMesh.KINDS:
		_export(kind)
	print("templates written to ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _export(kind: String) -> void:
	var root := Node3D.new()
	root.name = "shelves_%s" % kind
	var item := MeshInstance3D.new()
	item.name = "media"
	item.mesh = BoxMediaMesh.mesh_for(kind)

	var art := StandardMaterial3D.new()
	art.resource_name = "art"
	art.albedo_color = Color(0.85, 0.85, 0.88)
	var body := StandardMaterial3D.new()
	body.resource_name = "body"
	body.albedo_color = Color(0.18, 0.18, 0.21)
	item.set_surface_override_material(0, art)
	if item.mesh.get_surface_count() > 1:
		item.set_surface_override_material(1, body)
	root.add_child(item)
	item.owner = root

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err != OK:
		push_error("cannot build %s: %d" % [kind, err])
		return
	err = doc.write_to_filesystem(state, "%s/shelves-%s.glb" % [OUT, kind])
	if err != OK:
		push_error("cannot write %s: %d" % [kind, err])
	else:
		print("  ", kind, " — ", item.mesh.get_surface_count(), " surfaces")
