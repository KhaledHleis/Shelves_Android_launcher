@tool
extends EditorExportPlugin
## Everything the Android export needs that the editor UI cannot express.
##
## Set REGISTER_AS_HOME to false to export a normal app instead of a home
## screen — handy while testing, since a broken launcher is awkward to escape.

const REGISTER_AS_HOME := true
const PLUGIN_NAME := "LauncherPlugin"
const BIN_DIR := "res://addons/shelves/bin/"


func _get_name() -> String:
	return "ShelvesExport"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var variant := "debug" if debug else "release"
	var path := "%s%s/%s-%s.aar" % [BIN_DIR, variant, PLUGIN_NAME, variant]
	if not FileAccess.file_exists(path):
		push_error("Shelves: %s is missing — run gradlew assemble in android-plugin/." % path)
		return PackedStringArray()
	return PackedStringArray([path])


## Goes inside <manifest>: the Android 11+ package visibility entry, the
## permissions the status bar needs, and the shortcut permission.
func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
	return """
	<queries>
		<intent>
			<action android:name="android.intent.action.MAIN" />
			<category android:name="android.intent.category.LAUNCHER" />
		</intent>
	</queries>
	<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
	<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
	<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
		tools:ignore="QueryAllPackagesPermission" />
"""


## Goes inside the main <activity>: makes the app selectable as the home screen.
func _get_android_manifest_activity_element_contents(platform: EditorExportPlatform,
		debug: bool) -> String:
	if not REGISTER_AS_HOME:
		return ""
	return """
		<intent-filter>
			<action android:name="android.intent.action.MAIN" />
			<category android:name="android.intent.category.HOME" />
			<category android:name="android.intent.category.DEFAULT" />
		</intent-filter>
"""
