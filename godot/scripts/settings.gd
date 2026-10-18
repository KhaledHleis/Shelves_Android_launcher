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
	"bg_style": "pools",         # see BG_STYLES
	"bg_overlay": "none",        # see BG_OVERLAYS
	"bg_overlay_strength": 0.30,
	"bg_speed": 0.05,            # gradient drift
	"bg_pattern_speed": 0.15,    # pattern drift
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


const BG_STYLES := ["pools", "blending", "sweep", "aurora", "waves", "radial", "linear", "corners"]
const BG_OVERLAYS := ["none", "dots", "mesh", "triangles", "chladni", "bubbles", "strips",
	"sparkles", "hexagons", "ripples"]
## Named speeds rather than a slider: four steps are enough and they read
## better in a list. 0 means the background holds still.
const SPEEDS := {"still": 0.0, "slow": 0.02, "normal": 0.05, "fast": 0.12}
const PATTERN_SPEEDS := {"still": 0.0, "slow": 0.06, "normal": 0.15, "fast": 0.4}


## Nearest name for a stored number, so the list can show what is set.
static func speed_name(table: Dictionary, value: float) -> String:
	var best := "normal"
	var best_gap := 1e9
	for key in table:
		var gap: float = absf(float(table[key]) - value)
		if gap < best_gap:
			best_gap = gap
			best = key
	return best


## The shader takes numbers; the settings file keeps names, so the file stays
## readable and reordering the lists cannot silently change someone's look.
func bg_style_index() -> int:
	return maxi(BG_STYLES.find(str(get_value("bg_style"))), 0)


func bg_overlay_index() -> int:
	return maxi(BG_OVERLAYS.find(str(get_value("bg_overlay"))), 0)


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
