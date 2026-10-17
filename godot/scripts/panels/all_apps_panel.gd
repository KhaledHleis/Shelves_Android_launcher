class_name AllAppsPanel
extends ListPanel
## Every launchable app, searchable and sortable. The place apps get filed
## into folders and hidden from the shelves.

signal folder_requested(package: String)

var sort: Library.Sort = Library.Sort.NAME
var show_hidden: bool = false


func _ready() -> void:
	super()
	set_title("All apps")
	enable_search(true)
	Library.library_changed.connect(func() -> void:
		if is_open:
			refresh()
	)


func open_hidden() -> void:
	show_hidden = true
	open()
	set_title("Hidden apps")


func open() -> void:
	super()
	set_title("Hidden apps" if show_hidden else "All apps")
	_update_title()


func build_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var apps := Library.hidden_apps() if show_hidden \
		else Library.search(search_text(), sort)
	for app in apps:
		var package: String = app["package"]
		var folders := (Library.record(package).get("folders", []) as Array).size()
		var suffix := ""
		if show_hidden:
			suffix = "hidden"
		elif folders > 0:
			suffix = "%d folder%s" % [folders, "" if folders == 1 else "s"]
		out.append({
			"id": package,
			"text": app["name"],
			"suffix": suffix,
			"icon": package,
		})
	return out


func prompt_defs() -> Array:
	if show_hidden:
		return [["ui_accept", "Unhide"], ["ui_cancel", "Back"]]
	return [
		["ui_accept", "Launch"],
		["inspect", "Folders"],
		["all_apps", "Hide"],
		["ui_cancel", "Back"],
	]


func on_activate(id: String) -> void:
	if id.is_empty():
		return
	if show_hidden:
		Library.set_hidden(id, false)
		refresh()
		return
	close()
	AppBridge.launch_app(id)


## X — file this app into folders.
func on_alt(id: String) -> void:
	if id.is_empty() or show_hidden:
		return
	folder_requested.emit(id)


## Y — hide it from every shelf.
func on_alt2(id: String) -> void:
	if id.is_empty() or show_hidden:
		return
	Library.set_hidden(id, true)
	Audio.play("back")
	refresh()


func _update_title() -> void:
	if not show_hidden:
		set_title("All apps  ·  %s" % ("A to Z" if sort == Library.Sort.NAME else "Recent"))
