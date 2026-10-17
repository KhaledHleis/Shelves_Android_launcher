class_name FoldersPanel
extends ListPanel
## Folder management: order, layout, renaming, deleting.

func _ready() -> void:
	super()
	set_title("Folders")


func build_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for folder in Library.folders():
		var id: String = folder["id"]
		var count := Library.apps_in_folder(id).size()
		var builtin := bool(folder.get("builtin", false))
		out.append({
			"id": id,
			"text": folder["name"],
			"suffix": "%s · %d app%s%s" % [
				str(folder.get("layout", "carousel")),
				count, "" if count == 1 else "s",
				"  (built in)" if builtin else "",
			],
		})
	out.append({"id": "__new__", "text": "+ New folder"})
	return out


func prompt_defs() -> Array:
	return [
		["ui_accept", "Layout"],
		["inspect", "Rename"],
		["all_apps", "Delete"],
		["ui_cancel", "Back"],
	]


## A — switch this folder between the carousel and the grid.
func on_activate(id: String) -> void:
	if id == "__new__":
		ask_text("Name the folder", "", func(name: String) -> void:
			Library.create_folder(name)
		)
		return
	if id.is_empty():
		return
	var next := "grid" if Library.folder_layout(id) == "carousel" else "carousel"
	Library.set_folder_layout(id, next)
	refresh()


## X — rename.
func on_alt(id: String) -> void:
	var folder := Library.folder_by_id(id)
	if folder.is_empty() or bool(folder.get("builtin", false)):
		return
	ask_text("Rename folder", str(folder["name"]), func(name: String) -> void:
		Library.rename_folder(id, name)
	)


## Y — delete. Built-in folders refuse.
func on_alt2(id: String) -> void:
	if Library.delete_folder(id):
		Audio.play("back")
		refresh()
