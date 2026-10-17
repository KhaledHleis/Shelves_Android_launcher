extends Node
## The launcher's data layer: the app list, the folders, and whatever the user
## has set per app. Saved as one JSON file in user://.
##
## v0.2 ships two built-in dynamic folders, All and New. The record format
## already carries the fields custom folders (v0.3) and Inspect (v0.4) need,
## so adding them later does not migrate anything.

signal library_changed       ## app list or folder contents changed

const PATH := "user://library.json"
const VERSION := 1
const NEW_WINDOW_DAYS := 14

var _data: Dictionary = {
	"version": VERSION,
	"folders": [],
	"apps": {},
}
var _apps: Array[Dictionary] = []          ## live list from AppBridge, sorted A→Z
var _by_folder: Dictionary = {}            ## folder id -> Array[Dictionary]
var _first_run: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	AppBridge.apps_changed.connect(refresh)
	refresh()


# ---------------------------------------------------------------- queries

func folders() -> Array:
	return _data["folders"]


func folder_count() -> int:
	return (_data["folders"] as Array).size()


func folder_at(index: int) -> Dictionary:
	var list: Array = _data["folders"]
	if list.is_empty():
		return {}
	return list[clampi(index, 0, list.size() - 1)]


func apps_in_folder(folder_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_by_folder.get(folder_id, []))
	return out


func all_apps() -> Array[Dictionary]:
	return _apps


func record(package: String) -> Dictionary:
	var apps: Dictionary = _data["apps"]
	if not apps.has(package):
		apps[package] = _new_record()
	return apps[package]


func display_name(package: String, fallback: String = "") -> String:
	var rec := record(package)
	var custom := str(rec.get("display_name", ""))
	return custom if not custom.is_empty() else fallback


func is_hidden(package: String) -> bool:
	return bool(record(package).get("hidden", false))


func set_hidden(package: String, hidden: bool) -> void:
	record(package)["hidden"] = hidden
	save()
	refresh()


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	_apps = AppBridge.get_installed_apps()
	var now := int(Time.get_unix_time_from_system())
	var apps: Dictionary = _data["apps"]
	var seen := {}

	for app in _apps:
		var package: String = app["package"]
		seen[package] = true
		if not apps.has(package):
			var rec := _new_record()
			# On the very first run nothing is "new" — otherwise the New folder
			# would just be a copy of All.
			rec["first_seen"] = 0 if _first_run else now
			apps[package] = rec

	# Forget records for apps that are gone.
	for package in apps.keys():
		if not seen.has(package):
			apps.erase(package)

	_first_run = false
	_rebuild_folders(now)
	save()
	library_changed.emit()


func _rebuild_folders(now: int) -> void:
	_by_folder.clear()
	var new_cutoff := now - NEW_WINDOW_DAYS * 86400
	for folder in _data["folders"]:
		var id: String = folder["id"]
		var rule: String = str(folder.get("rule", "manual"))
		var bucket: Array[Dictionary] = []
		for app in _apps:
			var package: String = app["package"]
			if is_hidden(package):
				continue
			var keep := false
			match rule:
				"all":
					keep = true
				"new":
					keep = int(record(package).get("first_seen", 0)) >= new_cutoff
				_:
					keep = package in record(package).get("folders", [])
			if keep:
				bucket.append({
					"package": package,
					"name": display_name(package, app["name"]),
				})
		_by_folder[id] = bucket


# ---------------------------------------------------------------- storage

func _new_record() -> Dictionary:
	return {
		"display_name": "",
		"hidden": false,
		"first_seen": 0,
		"folders": [],          # custom folder ids — v0.3
		"model": "box",         # v0.4
		"launch": {},           # custom launch action — v0.4
	}


func _default_folders() -> Array:
	return [
		{"id": "all", "name": "All", "rule": "all", "layout": "carousel"},
		{"id": "new", "name": "New", "rule": "new", "layout": "carousel"},
	]


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		_first_run = true
		_data["folders"] = _default_folders()
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("library: cannot read %s" % PATH)
		_data["folders"] = _default_folders()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_data["apps"] = parsed.get("apps", {})
		var folders: Array = parsed.get("folders", [])
		_data["folders"] = folders if not folders.is_empty() else _default_folders()
	else:
		push_warning("library: %s is not valid JSON, starting fresh" % PATH)
		_data["folders"] = _default_folders()


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("library: cannot write %s" % PATH)
		return
	_data["version"] = VERSION
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
