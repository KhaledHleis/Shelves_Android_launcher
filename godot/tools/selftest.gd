extends Node
## Headless smoke test for the navigation rules.
##   godot --headless --path . tools/selftest.tscn
## Exits non-zero on the first failure, so it can go in CI later.

var _failures := 0


func _ready() -> void:
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
