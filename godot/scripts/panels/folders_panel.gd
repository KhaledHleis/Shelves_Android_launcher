class_name FoldersPanel
extends ListPanel
## The list of folders. Everything about one folder lives in its editor.

signal edit_requested(folder_id: String)

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
		["ui_accept", "Open"],
		["inspect", "Move up"],
		["all_apps", "Move down"],
		["ui_cancel", "Back"],
	]


func on_activate(id: String) -> void:
	if id == "__new__":
		ask_text("Name the folder", "", func(name: String) -> void:
			var new_id := Library.create_folder(name)
			edit_requested.emit(new_id)
		)
		return
	if not id.is_empty():
		edit_requested.emit(id)


## X / Y — reorder, which decides the order of the tabs on the home screen.
func on_alt(id: String) -> void:
	if not id.is_empty() and id != "__new__":
		Library.move_folder(id, -1)
		selected = maxi(selected - 1, 0)
		refresh()


func on_alt2(id: String) -> void:
	if not id.is_empty() and id != "__new__":
		Library.move_folder(id, 1)
		selected += 1
		refresh()
