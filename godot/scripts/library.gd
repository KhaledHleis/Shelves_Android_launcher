extends Node
## The launcher's data layer: the app list, the folders, and whatever the user
## has set per app. Saved as one JSON file in user://.
##
## v0.2 ships two built-in dynamic folders, All and New. The record format
## already carries the fields custom folders (v0.3) and Inspect (v0.4) need,
## so adding them later does not migrate anything.

signal library_changed       ## app list or folder contents changed
signal folders_changed       ## a folder was added, removed, renamed or moved

const PATH := "user://library.json"
const VERSION := 2

enum Sort { NAME, RECENT }
const NEW_WINDOW_DAYS := 14

var _data: Dictionary = {"version": VERSION, "folders": [], "apps": {}}
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


func folder_by_id(id: String) -> Dictionary:
	for folder in _data["folders"]:
		if folder["id"] == id:
			return folder
	return {}


func folder_index(id: String) -> int:
	var list: Array = _data["folders"]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


## Manual folders only — the ones an app can actually be filed into.
func custom_folders() -> Array:
	var out := []
	for folder in _data["folders"]:
		if str(folder.get("rule", "manual")) == "manual":
			out.append(folder)
	return out


func create_folder(name: String, layout: String = "carousel") -> String:
	var clean := name.strip_edges()
	if clean.is_empty():
		clean = "Folder"
	var id := "f_%d" % (Time.get_ticks_usec() % 100000000)
	_data["folders"].append({
		"id": id, "name": clean, "rule": "manual", "layout": layout, "builtin": false,
	})
	save()
	_rebuild_folders(int(Time.get_unix_time_from_system()))
	folders_changed.emit()
	library_changed.emit()
	return id


func rename_folder(id: String, name: String) -> void:
	var folder := folder_by_id(id)
	var clean := name.strip_edges()
	if folder.is_empty() or clean.is_empty():
		return
	folder["name"] = clean
	save()
	folders_changed.emit()


## Built-in folders stay. A deleted folder's membership is dropped from every
## app, so no record points at an id that no longer exists.
func delete_folder(id: String) -> bool:
	var folder := folder_by_id(id)
	if folder.is_empty() or bool(folder.get("builtin", false)):
		return false
	(_data["folders"] as Array).erase(folder)
	for package in (_data["apps"] as Dictionary):
		var list: Array = _data["apps"][package].get("folders", [])
		list.erase(id)
	save()
	_rebuild_folders(int(Time.get_unix_time_from_system()))
	folders_changed.emit()
	library_changed.emit()
	return true


func move_folder(id: String, delta: int) -> void:
	var list: Array = _data["folders"]
	var from := folder_index(id)
	var to := from + delta
	if from < 0 or to < 0 or to >= list.size():
		return
	var folder: Variant = list[from]
	list.remove_at(from)
	list.insert(to, folder)
	save()
	folders_changed.emit()


func folder_layout(id: String) -> String:
	var folder := folder_by_id(id)
	return str(folder.get("layout", "carousel")) if not folder.is_empty() else "carousel"


func set_folder_layout(id: String, layout: String) -> void:
	var folder := folder_by_id(id)
	if folder.is_empty():
		return
	folder["layout"] = layout
	save()
	folders_changed.emit()


func apps_in_folder(folder_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_by_folder.get(folder_id, []))
	return out


func all_apps() -> Array[Dictionary]:
	return _apps


## Visible apps, filtered and sorted — what the All apps panel shows.
func search(query: String = "", sort: Sort = Sort.NAME,
		include_hidden: bool = false) -> Array[Dictionary]:
	var needle := query.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for app in _apps:
		var package: String = app["package"]
		if is_hidden(package) and not include_hidden:
			continue
		var label := display_name(package, app["name"])
		if not needle.is_empty() and not label.to_lower().contains(needle):
			continue
		out.append({"package": package, "name": label})
	if sort == Sort.RECENT:
		out.sort_custom(func(a, b): return _first_seen(a["package"]) > _first_seen(b["package"]))
	else:
		out.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return out


func hidden_apps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for app in _apps:
		if is_hidden(app["package"]):
			out.append({
				"package": app["package"],
				"name": display_name(app["package"], app["name"]),
			})
	return out


func in_folder(package: String, folder_id: String) -> bool:
	return folder_id in record(package).get("folders", [])


func set_in_folder(package: String, folder_id: String, member: bool) -> void:
	var list: Array = record(package)["folders"]
	if member and folder_id not in list:
		list.append(folder_id)
	elif not member:
		list.erase(folder_id)
	save()
	_rebuild_folders(int(Time.get_unix_time_from_system()))
	library_changed.emit()


func toggle_in_folder(package: String, folder_id: String) -> bool:
	var member := not in_folder(package, folder_id)
	set_in_folder(package, folder_id, member)
	return member


func _first_seen(package: String) -> int:
	return int(record(package).get("first_seen", 0))


## Sets one field of an app's record. Inspect writes everything through here
## so there is a single place that saves and tells the views to re-read.
func set_app_value(package: String, key: String, value: Variant) -> void:
	record(package)[key] = value
	save()
	if key == "display_name":
		_rebuild_folders(int(Time.get_unix_time_from_system()))
	library_changed.emit()


## Named palettes for the background, so it does not have to follow the icon.
const PALETTES := {
	"auto": [],
	"ember": [Color(0.98, 0.45, 0.22), Color(0.22, 0.06, 0.05)],
	"deep sea": [Color(0.25, 0.68, 0.92), Color(0.04, 0.10, 0.20)],
	"forest": [Color(0.45, 0.85, 0.45), Color(0.05, 0.16, 0.10)],
	"violet": [Color(0.70, 0.40, 0.95), Color(0.12, 0.05, 0.22)],
	"mono": [Color(0.75, 0.76, 0.80), Color(0.07, 0.07, 0.09)],
}


## The swatch grid, the same idea as Socket's colour picker.
## Swatches, built rather than listed: eight hues at three lightnesses plus a
## grey column. Names are ids only — the picker shows colour, not words.
const SWATCH_HUES := {
	"red": 0.00, "orange": 0.07, "yellow": 0.14, "green": 0.33,
	"teal": 0.47, "blue": 0.60, "violet": 0.74, "pink": 0.90,
}
const SWATCH_LEVELS := {"light": [0.45, 0.97], "mid": [0.80, 0.80], "deep": [0.90, 0.45]}
const SWATCH_GREYS := {
	"white": 0.97, "silver": 0.75, "grey": 0.52, "slate": 0.34,
	"charcoal": 0.20, "ink": 0.09,
}


static func swatches() -> Dictionary:
	var out := {}
	for level in SWATCH_LEVELS:
		var sv: Array = SWATCH_LEVELS[level]
		for hue in SWATCH_HUES:
			out["%s %s" % [level, hue]] = Color.from_hsv(SWATCH_HUES[hue], sv[0], sv[1])
	for name in SWATCH_GREYS:
		out[name] = Color.from_hsv(0.0, 0.0, SWATCH_GREYS[name])
	return out


static var SWATCHES: Dictionary = swatches()


## The two colours the background gradient uses for this app: taken from the
## icon unless a palette was picked in Inspect.
func app_colors(package: String) -> Array:
	var rec := record(package)
	var name := str(rec.get("background", "auto"))
	if name == "custom":
		# Two colours of the user's choosing, which is what the design doc
		# always called for alongside the icon colours.
		return [
			SWATCHES.get(str(rec.get("bg_a", "violet")), PALETTES["violet"][0]),
			SWATCHES.get(str(rec.get("bg_b", "ink")), PALETTES["violet"][1]),
		]
	if PALETTES.has(name) and not (PALETTES[name] as Array).is_empty():
		return (PALETTES[name] as Array).duplicate()
	var tex := AppBridge.get_icon(package)
	return IconColors.pair(tex, package) if tex != null else [Style.ACCENT, Style.BG_MID]


## What pressing A on this app should do: its own launcher by default, or
## whatever Inspect was given — a link for a game inside GameNative, say.
func launch_action(package: String) -> Dictionary:
	return record(package).get("launch", {})


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
	_rebuild_folders(int(Time.get_unix_time_from_system()))
	library_changed.emit()


# ---------------------------------------------------------------- refresh

## Throws away folders and per-app records and starts from the defaults.
## Used by tools/selftest.tscn so a run does not inherit the last one's
## folders — the tests were passing or failing depending on what was left in
## user://library.json.
func reset() -> void:
	_data = {"version": VERSION, "folders": _default_folders(), "apps": {}}
	_first_run = true
	refresh()
	folders_changed.emit()


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
					# Recently installed and not filed anywhere yet — filing an
					# app into a folder is what takes it out of New.
					keep = _first_seen(package) >= new_cutoff \
						and (record(package).get("folders", []) as Array).is_empty()
				_:
					# Was comparing the package against the folder list, so a
					# manual folder could never match anything.
					keep = id in record(package).get("folders", [])
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
		"folders": [],          # manual folder ids
		"model": "box",         # box | cartridge | disc | card
		"finish": "opaque",     # on the art: opaque | translucent | clear | metallic | glitter
		"shell": "matte",       # the plastic: matte | glossy | smoked | metal | rubber
		"cover": "",            # path to an image in the watched art folder
		"label": "",
		"insert": "",           # Slow mode: art inside the box lid
		"background": "auto",   # auto, a name from PALETTES, or custom
		"bg_a": "violet",       # swatch names, used when background is custom
		"bg_b": "ink",
		"launch": {},           # custom launch action, or empty for the default
	}


func _default_folders() -> Array:
	return [
		{"id": "all", "name": "All", "rule": "all", "layout": "carousel", "builtin": true},
		{"id": "new", "name": "New", "rule": "new", "layout": "carousel", "builtin": true},
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
	if not parsed is Dictionary:
		push_warning("library: %s is not valid JSON, starting fresh" % PATH)
		_data["folders"] = _default_folders()
		return

	_data["apps"] = parsed.get("apps", {})
	var folders: Array = parsed.get("folders", [])
	_data["folders"] = folders if not folders.is_empty() else _default_folders()
	# v1 files had no builtin flag: All and New must stay undeletable.
	for folder in _data["folders"]:
		if not folder.has("builtin"):
			folder["builtin"] = str(folder.get("rule", "manual")) in ["all", "new"]
		if not folder.has("layout"):
			folder["layout"] = "carousel"


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("library: cannot write %s" % PATH)
		return
	_data["version"] = VERSION
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
