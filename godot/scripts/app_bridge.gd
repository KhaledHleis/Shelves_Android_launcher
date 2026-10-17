extends Node
## Only place in the project that talks to the Android plugin.
##
## On desktop (or whenever the plugin is missing) it serves mock apps and
## generated icons, so the whole UI can be built and tested on a PC.

signal apps_changed                       ## a package was installed or removed
signal icon_ready(package: String, texture: Texture2D)
signal battery_changed(level: int, charging: bool)
signal network_changed(state: Dictionary)

const PLUGIN_NAME := "LauncherPlugin"
const ICONS_PER_FRAME := 2
const POLL_INTERVAL := 10.0

var has_plugin: bool = false

var _plugin: Object = null
var _icon_cache: Dictionary = {}          ## package -> Texture2D
var _icon_queue: Array[String] = []
var _icon_queued: Dictionary = {}         ## package -> true
var _mock_apps: Array[Dictionary] = []
var _poll_accum: float = 0.0
var _battery: Dictionary = {"level": 100, "charging": false}
var _network: Dictionary = {"connected": false, "type": "none", "level": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		has_plugin = true
		if _plugin.has_signal("apps_changed"):
			_plugin.connect("apps_changed", _on_plugin_apps_changed)
	else:
		_build_mock_apps()
		push_warning("LauncherPlugin not found — running with mock apps.")
	_refresh_battery(true)
	_refresh_network(true)


func _process(delta: float) -> void:
	_pump_icon_queue()
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		_refresh_battery(false)
		_refresh_network(false)


# ---------------------------------------------------------------- apps

## Returns [{package, name, launchable}] sorted A→Z.
func get_installed_apps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_plugin:
		var raw: String = str(_plugin.getInstalledApps())
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Array:
			for entry in parsed:
				if entry is Dictionary and entry.has("package"):
					out.append({
						"package": str(entry.get("package", "")),
						"name": str(entry.get("name", entry.get("package", ""))),
					})
		else:
			push_error("getInstalledApps() returned unparsable data")
	else:
		out = _mock_apps.duplicate(true)
	out.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return out


func launch_app(package: String) -> bool:
	if has_plugin:
		return bool(_plugin.launchApp(package))
	print("[mock] launch ", package)
	return true


# ---------------------------------------------------------------- icons

## Cached texture, or null. When null, the icon is queued and [signal icon_ready]
## fires once it is decoded.
func get_icon(package: String) -> Texture2D:
	if _icon_cache.has(package):
		return _icon_cache[package]
	if not _icon_queued.has(package):
		_icon_queued[package] = true
		_icon_queue.append(package)
	return null


func _pump_icon_queue() -> void:
	var budget := ICONS_PER_FRAME
	while budget > 0 and not _icon_queue.is_empty():
		budget -= 1
		var package: String = _icon_queue.pop_front()
		_icon_queued.erase(package)
		var tex := _decode_icon(package)
		if tex != null:
			_icon_cache[package] = tex
			icon_ready.emit(package, tex)


func _decode_icon(package: String) -> Texture2D:
	if not has_plugin:
		return _mock_icon(package)
	var b64: String = str(_plugin.getAppIcon(package))
	if b64.is_empty():
		return _mock_icon(package)
	var bytes := Marshalls.base64_to_raw(b64)
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return _mock_icon(package)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- status

func get_battery_state() -> Dictionary:
	return _battery.duplicate()


func get_network_state() -> Dictionary:
	return _network.duplicate()


func _refresh_battery(force: bool) -> void:
	var next := _battery
	if has_plugin:
		var parsed: Variant = JSON.parse_string(str(_plugin.getBatteryState()))
		if parsed is Dictionary:
			next = {
				"level": int(parsed.get("level", 100)),
				"charging": bool(parsed.get("charging", false)),
			}
	else:
		var t := Time.get_ticks_msec() / 1000.0
		next = {"level": 40 + int(abs(sin(t * 0.05)) * 60.0), "charging": false}
	if force or next != _battery:
		_battery = next
		battery_changed.emit(int(_battery["level"]), bool(_battery["charging"]))


func _refresh_network(force: bool) -> void:
	var next := _network
	if has_plugin:
		var parsed: Variant = JSON.parse_string(str(_plugin.getNetworkState()))
		if parsed is Dictionary:
			next = {
				"connected": bool(parsed.get("connected", false)),
				"type": str(parsed.get("type", "none")),
				"level": int(parsed.get("level", 0)),
			}
	else:
		next = {"connected": true, "type": "wifi", "level": 3}
	if force or next != _network:
		_network = next
		network_changed.emit(_network.duplicate())


func _on_plugin_apps_changed(_package: String) -> void:
	_icon_cache.clear()
	apps_changed.emit()


# ---------------------------------------------------------------- mock

func _build_mock_apps() -> void:
	var names := [
		"GameNative", "RetroArch", "Dolphin", "Duckstation", "AetherSX2",
		"PPSSPP", "Citra", "Yuzu", "Flycast", "MelonDS",
		"Minecraft", "Stardew Valley", "Dead Cells", "Terraria", "Vampire Survivors",
		"Brawl Stars", "Genshin Impact", "Among Us", "Balatro", "Hades",
		"YouTube", "Spotify", "Netflix", "Chrome", "Files",
		"Settings", "Moonlight", "Steam Link", "Discord", "Twitch",
		"Camera", "Gallery", "Clock", "Calculator", "Maps", "Telegram",
	]
	for i in names.size():
		_mock_apps.append({
			"package": "com.mock.%s" % names[i].to_lower().replace(" ", ""),
			"name": names[i],
		})


func _mock_icon(package: String) -> Texture2D:
	var h := float(hash(package) % 360) / 360.0
	var a := Color.from_hsv(h, 0.65, 0.95)
	var b := Color.from_hsv(fposmod(h + 0.12, 1.0), 0.75, 0.55)
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var t := float(x + y) / float(size * 2)
			img.set_pixel(x, y, a.lerp(b, t))
	# a simple glyph block so icons are visually distinct
	var seed_val := hash(package)
	for cy in 4:
		for cx in 4:
			if (seed_val >> (cy * 4 + cx)) & 1:
				var px := 16 + cx * 24
				var py := 16 + cy * 24
				for y in range(py, py + 20):
					for x in range(px, px + 20):
						img.set_pixel(x, y, Color(1, 1, 1, 0.85))
	return ImageTexture.create_from_image(img)
