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
		# Loud, because the export still succeeds without it and the app then
		# silently runs on mock data.
		printerr("================================================================")
		printerr("  SHELVES: %s is MISSING." % path)
		printerr("  The APK will have NO launcher plugin: no app list, no launching.")
		printerr("  Build it with android-plugin/gradlew assemble, or download the")
		printerr("  AAR from a green CI run and drop it in that folder.")
		printerr("================================================================")
		return PackedStringArray()
	print("Shelves: bundling %s" % path)
	return PackedStringArray([path])


## Shown next to the option in the export dialog. An Android plugin can only
## be injected by the Gradle build, so exporting with it off produces an APK
## with no plugin and no warning from Godot itself.
func _get_export_option_warning(platform: EditorExportPlatform, option: String) -> String:
	if not _supports_platform(platform):
		return ""
	if option == "gradle_build/use_gradle_build":
		var missing := []
		for variant in ["debug", "release"]:
			var path := "%s%s/%s-%s.aar" % [BIN_DIR, variant, PLUGIN_NAME, variant]
			if not FileAccess.file_exists(path):
				missing.append(variant)
		if not missing.is_empty():
			return "Shelves: the %s plugin AAR is missing from %s. Build it in \
android-plugin/ (gradlew assemble) or the app will run on mock data." \
				% [", ".join(missing), BIN_DIR]
		return "Shelves: this must stay ON — the launcher plugin is only injected by the Gradle build."
	return ""


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
	<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
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
