extends Node
## Launcher-wide settings, saved as JSON in user://.
##
## v0.2 exposes only what the Fast-mode shell needs. The file is versioned so
## v0.3+ can add keys without breaking an existing install.

signal changed(key: String)

const PATH := "user://settings.json"
const VERSION := 1

## Values a new install starts with.
const DEFAULTS := {
	"version": VERSION,
	"mode": "fast",              # fast | slow (slow lands in v0.5)
	"prompt_style": "auto",      # auto | xbox | playstation | nintendo | steamdeck
	"swap_ab": false,            # Nintendo-style A/B meaning
	"sounds_enabled": true,
	"sound_volume_db": -6.0,
	"music_enabled": false,
	"music_volume_db": -14.0,
	"clock_24h": true,
	"carousel_autorotate": true, # idle sway on the selected model
}

var _data: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func get_value(key: String) -> Variant:
	return _data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if _data.get(key) == value:
		return
	_data[key] = value
	save_settings()
	changed.emit(key)


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("settings: cannot read %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for key in parsed:
			_data[key] = parsed[key]
	_data["version"] = VERSION


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("settings: cannot write %s" % PATH)
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()


## Maps the prompt_style setting onto the Controller Icons device enum.
## NONE means "auto detect", which is the addon's own behaviour.
func forced_icon_style() -> int:
	match str(get_value("prompt_style")):
		"xbox":
			return ControllerSettings.Devices.XBOXONE
		"playstation":
			return ControllerSettings.Devices.PS5
		"nintendo":
			return ControllerSettings.Devices.SWITCH
		"steamdeck":
			return ControllerSettings.Devices.STEAM_DECK
		_:
			return ControllerSettings.Devices.NONE
