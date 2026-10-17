extends Node
# Dev helper: load the home screen, let it settle, save a PNG, quit.
# Run with:  godot --path . tools/shot.tscn   (add --rendering-method gl_compatibility on a PC without Vulkan)
func _ready() -> void:
	add_child(load("res://scenes/main.tscn").instantiate())
	if OS.get_cmdline_user_args().has("pad"):
		InputMode.using_pad = true
		InputMode.mode_changed.emit(true)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("user://shot.png")
	print("shot saved: ", ProjectSettings.globalize_path("user://shot.png"))
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
