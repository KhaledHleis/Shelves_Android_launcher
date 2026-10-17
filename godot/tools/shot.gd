extends Node
# Dev helper: load the home screen, let it settle, save a PNG, quit.
# Run with:  godot --path . tools/shot.tscn   (add --rendering-method gl_compatibility on a PC without Vulkan)
# Extra args:  -- pad            show controller prompts
#              -- pad grid       switch the All folder to a grid first
#              -- pad apps       open the All apps panel
#              -- pad settings   open Settings
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("grid"):
		Library.set_folder_layout("all", "grid")
	else:
		Library.set_folder_layout("all", "carousel")
	if args.has("shapes"):
		var kinds := ["cartridge", "disc", "card", "box"]
		var finishes := ["opaque", "metallic", "glitter", "translucent"]
		for i in kinds.size():
			var app: Dictionary = Library.search()[i]
			Library.set_app_value(app["package"], "model", kinds[i])
			Library.set_app_value(app["package"], "finish", finishes[i])
	for a in args:
		if a.begins_with("style="):
			Settings.set_value("bg_style", a.substr(6))
		if a.begins_with("overlay="):
			Settings.set_value("bg_overlay", a.substr(8))
			Settings.set_value("bg_overlay_strength", 0.5)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)

	if args.has("pad"):
		InputMode.using_pad = true
		InputMode.mode_changed.emit(true)
	await get_tree().create_timer(1.5).timeout
	if args.has("choice"):
		var app3: Dictionary = Library.search()[0]
		main._push(main._inspect)
		main._inspect.open_for(app3["package"], app3["name"])
		await get_tree().create_timer(0.3).timeout
		main._inspect.on_activate("finish")
	if args.has("colour"):
		var app4: Dictionary = Library.search()[0]
		main._push(main._inspect)
		main._inspect.open_for(app4["package"], app4["name"])
		await get_tree().create_timer(0.3).timeout
		main._inspect.on_activate("bg_a")
	if args.has("inspect"):
		var app2: Dictionary = Library.search()[0]
		main._push(main._inspect)
		main._inspect.open_for(app2["package"], app2["name"])
	if args.has("apps"):
		main._push(main._all_apps)
		main._all_apps.open()
	if args.has("settings"):
		main._push(main._settings)
		main._settings.open()
	if args.has("folders"):
		main._push(main._folders)
		main._folders.open()
	if args.has("folderedit"):
		var fid := Library.create_folder("Emulators", "grid")
		for app in Library.search().slice(0, 3):
			Library.set_in_folder(app["package"], fid, true)
		main._push(main._folder_edit)
		main._folder_edit.open_for(fid)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://shot.png")
	print("shot saved")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
