class_name FolderEditPanel
extends ListPanel
## One folder, top to bottom: what it is called, how it is shown, and which
## apps are in it. Tick an app to file it here.

var folder_id: String = ""


func _ready() -> void:
	super()
	enable_search(true)


func open_for(id: String) -> void:
	folder_id = id
	open()
	var folder := Library.folder_by_id(id)
	set_title(str(folder.get("name", "Folder")))


func build_rows() -> Array[Dictionary]:
	var folder := Library.folder_by_id(folder_id)
	if folder.is_empty():
		return []
	var builtin := bool(folder.get("builtin", false))
	var out: Array[Dictionary] = [
		{"id": "__layout__", "text": "Layout", "suffix": str(folder.get("layout", "carousel"))},
	]
	if not builtin:
		out.append({"id": "__rename__", "text": "Rename", "suffix": str(folder["name"])})
		out.append({"id": "__delete__", "text": "Delete folder", "suffix": ""})
		out.append({"id": "__head__", "text": "— apps in this folder —", "suffix": ""})
		for app in Library.search(search_text()):
			var package: String = app["package"]
			out.append({
				"id": package,
				"text": app["name"],
				"icon": package,
				"checked": Library.in_folder(package, folder_id),
			})
	else:
		# All and New decide their own contents from a rule.
		var count := Library.apps_in_folder(folder_id).size()
		out.append({"id": "__head__",
			"text": "This folder fills itself — %d app%s" % [count, "" if count == 1 else "s"],
			"suffix": "built in"})
	return out


func prompt_defs() -> Array:
	return [["ui_accept", "Toggle"], ["ui_cancel", "Back"]]


func on_activate(id: String) -> void:
	match id:
		"__head__":
			return
		"__layout__":
			choose("Layout", ["carousel", "grid"], Library.folder_layout(folder_id),
				func(value: String) -> void:
					Library.set_folder_layout(folder_id, value)
					refresh()
			)
			return
		"__rename__":
			var folder := Library.folder_by_id(folder_id)
			ask_text("Rename folder", str(folder.get("name", "")), func(name: String) -> void:
				Library.rename_folder(folder_id, name)
				set_title(name)
			)
			return
		"__delete__":
			if Library.delete_folder(folder_id):
				Audio.play("back")
				close()
			return
		_:
			if not id.is_empty():
				Library.toggle_in_folder(id, folder_id)
	refresh()
