class_name SettingsPanel
extends ListPanel
## Launcher-wide settings. Every row is a value you cycle with A, so there is
## no second kind of control to learn.

signal open_folders
signal open_hidden

const PROMPT_STYLES := ["auto", "xbox", "playstation", "nintendo", "steamdeck"]
const VOLUMES := [-18.0, -12.0, -6.0, 0.0]


func _ready() -> void:
	super()
	set_title("Settings")


func build_rows() -> Array[Dictionary]:
	var hidden_count := Library.hidden_apps().size()
	return [
		{"id": "folders", "text": "Folders", "suffix": "%d" % Library.folder_count()},
		{"id": "hidden", "text": "Hidden apps", "suffix": "%d" % hidden_count},
		{"id": "prompt_style", "text": "Controller prompts",
			"suffix": str(Settings.get_value("prompt_style"))},
		{"id": "swap_ab", "text": "Swap A and B (Nintendo layout)",
			"checked": bool(Settings.get_value("swap_ab"))},
		{"id": "sounds_enabled", "text": "UI sounds",
			"checked": bool(Settings.get_value("sounds_enabled"))},
		{"id": "sound_volume_db", "text": "Sound volume",
			"suffix": "%d dB" % int(Settings.get_value("sound_volume_db"))},
		{"id": "carousel_autorotate", "text": "Idle animation",
			"checked": bool(Settings.get_value("carousel_autorotate"))},
		{"id": "clock_24h", "text": "24-hour clock",
			"checked": bool(Settings.get_value("clock_24h"))},
		{"id": "diagnostics", "text": "Plugin diagnostics",
			"suffix": "device apps" if AppBridge.has_plugin else "MOCK"},
	]


func prompt_defs() -> Array:
	return [["ui_accept", "Change"], ["ui_cancel", "Back"]]


func on_activate(id: String) -> void:
	match id:
		"folders":
			open_folders.emit()
		"hidden":
			open_hidden.emit()
		"prompt_style":
			var i := PROMPT_STYLES.find(str(Settings.get_value("prompt_style")))
			Settings.set_value("prompt_style", PROMPT_STYLES[(i + 1) % PROMPT_STYLES.size()])
		"sound_volume_db":
			var v := float(Settings.get_value("sound_volume_db"))
			var i := VOLUMES.find(v)
			Settings.set_value("sound_volume_db", VOLUMES[(i + 1) % VOLUMES.size()])
		"diagnostics":
			print(AppBridge.diagnostics())
		_:
			# Everything else is a plain toggle.
			Settings.set_value(id, not bool(Settings.get_value(id)))
	refresh()
