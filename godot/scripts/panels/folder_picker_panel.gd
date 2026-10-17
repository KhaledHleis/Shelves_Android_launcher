class_name FolderPickerPanel
extends ListPanel
## Which folders an app sits in. Any number, including none — an app in no
## folder still shows up under All.

var package: String = ""


func _ready() -> void:
	super()
	set_title("Folders")


func open_for(target: String) -> void:
	package = target
	open()
	set_title("Folders  ·  %s" % Library.display_name(target, target))


func build_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for folder in Library.custom_folders():
		out.append({
			"id": folder["id"],
			"text": folder["name"],
			"checked": Library.in_folder(package, folder["id"]),
		})
	out.append({"id": "__new__", "text": "+ New folder", "suffix": ""})
	return out


func prompt_defs() -> Array:
	return [["ui_accept", "Toggle"], ["ui_cancel", "Done"]]


func on_activate(id: String) -> void:
	if id == "__new__":
		ask_text("Name the folder", "", func(name: String) -> void:
			var folder_id := Library.create_folder(name)
			Library.set_in_folder(package, folder_id, true)
		)
		return
	if id.is_empty() or package.is_empty():
		return
	Library.toggle_in_folder(package, id)
	refresh()
