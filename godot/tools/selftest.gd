extends Node
## Headless smoke test for the navigation rules.
##   godot --headless --path . tools/selftest.tscn
## Exits non-zero on the first failure, so it can go in CI later.

var _failures := 0


func _ready() -> void:
	# Start from a clean store: this test files apps into folders and hides
	# them, and a previous run's leftovers changed the counts it asserts on.
	Library.reset()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var carousel: Carousel = main.get_node("World/Carousel")
	var total := carousel.items.size()
	_check(total > 0, "folder has apps (%d)" % total)
	_check(carousel.index == 0, "starts on the first item")

	carousel.move(1)
	carousel.move(1)
	_check(carousel.index == 2, "two moves right land on index 2, got %d" % carousel.index)

	carousel.move(-1)
	_check(carousel.index == 1, "move left goes back, got %d" % carousel.index)

	carousel.jump_to(0)
	carousel.move(-1)
	_check(carousel.index == total - 1, "moving left off the start wraps to the end, got %d"
		% carousel.index)

	carousel.move(1)
	_check(carousel.index == 0, "and wraps forward again, got %d" % carousel.index)

	carousel.jump_to(carousel.index + Carousel.PAGE_JUMP)
	_check(carousel.index == Carousel.PAGE_JUMP, "trigger jump moves %d, got %d"
		% [Carousel.PAGE_JUMP, carousel.index])

	var folders := Library.folder_count()
	_check(folders >= 2, "two default folders, got %d" % folders)
	main.switch_folder(1)
	_check(main.folder_index == 1, "R1 switches folder, got %d" % main.folder_index)
	main.switch_folder(1)
	_check(main.folder_index == 0, "folders wrap round, got %d" % main.folder_index)

	# live nodes stay bounded no matter how big the library is
	var media := 0
	for child in carousel.get_children():
		if child is MediaItem:
			media += 1
	_check(media == Carousel.WINDOW, "only %d models instanced, got %d"
		% [Carousel.WINDOW, media])

	# The wrap must look like any other one-step move: a selection that jumps
	# from the last item to the first used to slide the whole library past.
	# Measure every model, visible or not — when the bug was present they all
	# flew far enough out to be culled, which a visible-only check would miss.
	carousel.jump_to(0)
	carousel.move(-1)
	var travel := 0.0
	var on_screen := 0
	for child in carousel.get_children():
		if child is MediaItem:
			travel = maxf(travel, absf((child as MediaItem).position.x))
			if (child as MediaItem).visible:
				on_screen += 1
	var limit := Carousel.SPACING * (Carousel.HALF + 2)
	_check(travel < limit, "wrapping slides one slot, not the whole list (max %.2f, limit %.2f)"
		% [travel, limit])
	_check(on_screen >= 3, "the shelf is still populated after a wrap, got %d" % on_screen)

	# The switch animation used to tween the same scale property the view
	# writes every frame, so the two fought and the model changed size as the
	# tween ended. It must animate the pivot and leave the root alone.
	carousel.jump_to(0)
	await get_tree().process_frame
	var node: MediaItem = carousel.center_node()
	var pivot: Node3D = node.get_node("Pivot")
	node.scale = Vector3.ONE * 2.0            # sentinel the view would rewrite next frame
	node.play_switch()
	_check(is_equal_approx(node.scale.x, 2.0),
		"the switch animation leaves the view's scale alone (%.3f)" % node.scale.x)
	_check(pivot.scale.x < 1.0,
		"and squashes the pivot instead (%.3f)" % pivot.scale.x)
	await get_tree().process_frame
	_check(is_equal_approx(node.scale.x, Carousel.CENTER_SCALE),
		"the view is the only thing setting the model's size (%.3f, expected %.3f)"
			% [node.scale.x, Carousel.CENTER_SCALE])

	# Rotation is yaw only — a stick push must not tip the case.
	Settings.set_value("carousel_autorotate", false)
	await get_tree().process_frame
	carousel.center_node().add_rotation(0.6)
	await get_tree().process_frame
	pivot = carousel.center_node().get_node("Pivot")
	_check(is_zero_approx(pivot.rotation.x),
		"rotating leaves pitch alone (pitch %.3f)" % pivot.rotation.x)
	_check(absf(pivot.rotation.y) > 0.1, "and does turn the case (yaw %.3f)" % pivot.rotation.y)

	# Spinning past half a turn must keep going. 8.4 radians is a turn and a
	# third: clamped it would sit at exactly PI, wrapped it lands short of it.
	var item: MediaItem = carousel.center_node()
	item.reset_rotation()
	for i in 24:
		item.add_rotation(0.35)
	await get_tree().process_frame
	var yaw: float = pivot.rotation.y
	_check(absf(yaw) < PI - 0.01,
		"the model spins past half a turn instead of stopping at the clamp (yaw %.3f)" % yaw)
	_check(absf(yaw) > 0.01, "and keeps a rotation after wrapping (yaw %.3f)" % yaw)

	Settings.set_value("carousel_autorotate", true)

	# ---- v0.3: folders, filing, hiding
	var before := Library.folder_count()
	var fid := Library.create_folder("Emulators", "grid")
	_check(Library.folder_count() == before + 1, "a custom folder is created")
	_check(Library.folder_layout(fid) == "grid", "and keeps the layout it was made with")

	var package: String = Library.all_apps()[0]["package"]
	Library.set_in_folder(package, fid, true)
	var filed := Library.apps_in_folder(fid)
	_check(filed.size() == 1 and filed[0]["package"] == package,
		"filing an app puts it in that folder, got %d" % filed.size())
	_check(Library.apps_in_folder("all").size() == total,
		"and leaves All alone, got %d" % Library.apps_in_folder("all").size())

	# Hiding takes an app off every shelf but keeps the record.
	Library.set_hidden(package, true)
	_check(Library.apps_in_folder(fid).is_empty(), "hiding takes it out of its folder")
	_check(Library.apps_in_folder("all").size() == total - 1, "and out of All")
	_check(Library.hidden_apps().size() == 1, "and it is listed under hidden apps")
	_check(Library.search("", Library.Sort.NAME).size() == total - 1,
		"search skips hidden apps")
	Library.set_hidden(package, false)
	_check(Library.apps_in_folder(fid).size() == 1, "unhiding puts it back")

	_check(Library.search("bala").size() == 1,
		"search matches part of a name, got %d" % Library.search("bala").size())
	_check(not Library.delete_folder("all"), "built-in folders cannot be deleted")
	_check(Library.delete_folder(fid), "a custom folder can")
	_check(not Library.in_folder(package, fid),
		"and deleting it clears the membership it left behind")

	# The grid is the other view of the same folder.
	var grid_view: GridView = main.get_node("World/GridView")
	Library.set_folder_layout("all", "grid")
	main._load_folder(false)
	await get_tree().process_frame
	_check(main.view == grid_view, "a folder set to grid opens in the grid view")
	grid_view.move(-1)
	_check(grid_view.index == total - 1, "the grid wraps backwards too, got %d" % grid_view.index)
	grid_view.jump_to(0)
	grid_view.move_row(-1)
	_check(grid_view.index == 0, "and a row move off the top stays put")
	grid_view.move_row(1)
	_check(grid_view.index == GridView.COLS, "a row down moves a whole row, got %d" % grid_view.index)
	Library.set_folder_layout("all", "carousel")
	main._load_folder(false)
	await get_tree().process_frame
	_check(main.view == carousel, "and switches back to the carousel")

	# Panels stack: opening one from another must leave only the top reading
	# input, or a single press acts on both.
	var apps_panel: AllAppsPanel = main._all_apps
	var picker: FolderPickerPanel = main._picker
	main._push(apps_panel)
	apps_panel.open()
	_check(main.panel_open(), "opening a panel takes input off the home screen")
	_check(apps_panel.active, "the open panel is active")
	main._push(picker)
	picker.open_for(package)
	_check(picker.active and not apps_panel.active,
		"opening a second panel deactivates the one underneath")
	picker.close()
	await get_tree().process_frame
	_check(apps_panel.active and apps_panel.is_open,
		"closing it hands input back to the panel below")
	apps_panel.close()
	await get_tree().process_frame
	_check(not main.panel_open(), "and closing the last one returns to the shelf")

	# Hiding is reversible from the same screen.
	Library.set_hidden(package, true)
	apps_panel.show_hidden = true
	apps_panel.refresh()
	var listed := false
	for row in apps_panel.rows:
		if str(row.get("id", "")) == package:
			listed = true
	_check(listed, "a hidden app is listed under Show hidden")
	apps_panel.on_activate(package)
	_check(not Library.is_hidden(package), "and A there unhides it")
	apps_panel.show_hidden = false

	# A folder's contents are editable from the folder itself.
	var edit: FolderEditPanel = main._folder_edit
	var fid2 := Library.create_folder("Shooters")
	edit.open_for(fid2)
	edit.on_activate(package)
	_check(Library.in_folder(package, fid2), "the folder editor files an app into it")
	var layout_pick := {"cb": Callable()}
	edit.choice_requested.connect(
		func(_h: String, _o: Array, _c: String, on_pick: Callable) -> void:
			layout_pick["cb"] = on_pick
	)
	edit.on_activate("__layout__")
	(layout_pick["cb"] as Callable).call("grid")
	_check(Library.folder_layout(fid2) == "grid", "and its layout is picked from a list")
	edit.close()
	Library.delete_folder(fid2)

	# ---- v0.4: customisation
	var inspect: InspectPanel = main._inspect
	inspect.open_for(package, "Test")
	# Values are offered as a list now, so the panel asks its host to show one
	# and hands back a callback. Catch it and answer as the user would.
	var asked := {"heading": "", "options": [], "pick": Callable()}
	inspect.choice_requested.connect(
		func(heading: String, options: Array, _current: String, on_pick: Callable) -> void:
			asked["heading"] = heading
			asked["options"] = options
			asked["pick"] = on_pick
	)
	inspect.on_activate("model")
	_check(asked["heading"] == "Media" and (asked["options"] as Array).size() == 4,
		"Inspect offers the four media shapes as a list")
	(asked["pick"] as Callable).call("disc")
	_check(Library.record(package).get("model") == "disc",
		"and picking one sets it, got %s" % Library.record(package).get("model"))
	inspect.on_activate("finish")
	(asked["pick"] as Callable).call("metallic")
	_check(Library.record(package).get("finish") == "metallic",
		"the finish is picked the same way, got %s" % Library.record(package).get("finish"))
	inspect.on_activate("background")
	(asked["pick"] as Callable).call("ember")
	var tinted: Array = Library.app_colors(package)
	_check(tinted[0] == Library.PALETTES["ember"][0],
		"a background palette overrides the icon colours")
	for kind in BoxMediaMesh.KINDS:
		var mesh := BoxMediaMesh.mesh_for(kind)
		_check(mesh != null and mesh.get_surface_count() == 2,
			"%s is a two-surface mesh (art, body)" % kind)

	# A custom launch action is parsed by shape, not by asking the user.
	Library.set_app_value(package, "launch", inspect._parse_launch("gamenative://play/42"))
	_check(Library.launch_action(package).get("type") == "uri", "a link parses as a uri")
	Library.set_app_value(package, "launch", inspect._parse_launch("com.x/com.x.Main"))
	_check(Library.launch_action(package).get("type") == "component",
		"package/activity parses as a component")
	Library.set_app_value(package, "launch", inspect._parse_launch(""))
	_check(Library.launch_action(package).is_empty(), "and blank means the app's own launcher")
	inspect.on_activate("reset")
	_check(Library.record(package).get("model") == "box"
		and Library.record(package).get("background") == "auto",
		"reset puts the app back to the defaults")
	inspect.close()

	# The diagnostics text runs on the device, where a crash in it would be
	# invisible — exercise the path here.
	var diag := AppBridge.diagnostics()
	_check(diag.contains("serving:") and diag.length() > 40,
		"diagnostics text builds (%d chars)" % diag.length())

	carousel.launch_selected()
	_check(carousel.locked, "launching locks input until the animation ends")

	print("\n%s — %d failure(s)" % ["FAILED" if _failures else "PASSED", _failures])
	get_tree().quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
