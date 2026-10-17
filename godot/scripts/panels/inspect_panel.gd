class_name InspectPanel
extends ListPanel
## Everything about one app: what it is called, what it looks like, where it
## sits, and what pressing A actually does.

signal changed(package: String)
signal folder_requested(package: String)

const MODELS := ["box", "cartridge", "disc", "card"]
const FINISHES := ["opaque", "translucent", "clear", "metallic", "glitter"]

var package: String = ""

var _art_target: String = ""     ## "cover" or "label" while the art list is up
var _picking_art: bool = false


func _ready() -> void:
	super()
	set_title("Inspect")


func open_for(target: String, fallback_name: String = "") -> void:
	package = target
	_picking_art = false
	open()
	set_title(Library.display_name(target, fallback_name if not fallback_name.is_empty() else target))


func build_rows() -> Array[Dictionary]:
	if package.is_empty():
		return []
	if _picking_art:
		var art: Array[Dictionary] = [{"id": "__none__", "text": "None"}]
		for image in ArtLibrary.images():
			art.append({"id": image["path"], "text": image["name"]})
		if art.size() == 1:
			art.append({"id": "__where__",
				"text": "No images found — put PNG or JPG files in:", "suffix": ""})
			for folder in ArtLibrary.folders():
				art.append({"id": "__where__", "text": folder, "suffix": ""})
		return art

	var rec := Library.record(package)
	var launch: Dictionary = rec.get("launch", {})
	return [
		{"id": "name", "text": "Display name",
			"suffix": Library.display_name(package, "(app label)")},
		{"id": "model", "text": "Media", "suffix": str(rec.get("model", "box"))},
		{"id": "finish", "text": "Finish", "suffix": str(rec.get("finish", "opaque"))},
		{"id": "background", "text": "Background", "suffix": str(rec.get("background", "auto"))},
		{"id": "cover", "text": "Cover art",
			"suffix": _art_name(str(rec.get("cover", "")))},
		{"id": "label", "text": "Label art (disc, cartridge)",
			"suffix": _art_name(str(rec.get("label", "")))},
		{"id": "launch", "text": "Launch action",
			"suffix": "default" if launch.is_empty() else str(launch.get("data", "custom"))},
		{"id": "folders", "text": "Folders",
			"suffix": "%d" % (rec.get("folders", []) as Array).size()},
		{"id": "reset", "text": "Reset this app", "suffix": ""},
	]


func prompt_defs() -> Array:
	return [["ui_accept", "Change"], ["ui_cancel", "Back"]]


func on_activate(id: String) -> void:
	if _picking_art:
		if id == "__where__":
			return
		Library.set_app_value(package, _art_target, "" if id == "__none__" else id)
		_picking_art = false
		set_title(Library.display_name(package, package))
		_done()
		return

	var rec := Library.record(package)
	match id:
		"name":
			ask_text("Display name", Library.display_name(package, ""),
				func(text: String) -> void:
					Library.set_app_value(package, "display_name", text.strip_edges())
					set_title(Library.display_name(package, package))
					_done()
			)
			return
		"model":
			choose("Media", MODELS, str(rec.get("model", "box")),
				func(value: String) -> void:
					Library.set_app_value(package, "model", value)
					_done()
			)
			return
		"finish":
			choose("Finish", FINISHES, str(rec.get("finish", "opaque")),
				func(value: String) -> void:
					Library.set_app_value(package, "finish", value)
					_done()
			)
			return
		"background":
			choose("Background", Library.PALETTES.keys(),
				str(rec.get("background", "auto")),
				func(value: String) -> void:
					Library.set_app_value(package, "background", value)
					_done()
			)
			return
		"cover", "label":
			ArtLibrary.ensure_folder()
			_art_target = id
			_picking_art = true
			selected = 0
			set_title("Pick %s art" % id)
			refresh()
			return
		"launch":
			ask_text("Link or package/activity, blank for the app's own launcher",
				str((rec.get("launch", {}) as Dictionary).get("data", "")),
				func(text: String) -> void:
					Library.set_app_value(package, "launch", _parse_launch(text))
					_done()
			)
			return
		"folders":
			folder_requested.emit(package)
			return
		"reset":
			for key in ["display_name", "cover", "label"]:
				Library.set_app_value(package, key, "")
			Library.set_app_value(package, "model", "box")
			Library.set_app_value(package, "finish", "opaque")
			Library.set_app_value(package, "background", "auto")
			Library.set_app_value(package, "launch", {})
			set_title(Library.display_name(package, package))
	_done()


## A link is a link; anything with a slash is a component; otherwise it is a
## package to open. GameNative-style targets are the first kind.
func _parse_launch(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return {}
	if clean.contains("://"):
		return {"type": "uri", "data": clean}
	if clean.contains("/"):
		var parts := clean.split("/", false, 1)
		return {"type": "component", "package": parts[0], "component": parts[1], "data": clean}
	return {"type": "package", "package": clean, "data": clean}


func _art_name(path: String) -> String:
	return "none" if path.is_empty() else path.get_file()


func _done() -> void:
	changed.emit(package)
	refresh()
