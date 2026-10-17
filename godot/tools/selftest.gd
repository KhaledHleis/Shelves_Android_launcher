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

	carousel.launch_selected()
	_check(carousel.locked, "launching locks input until the animation ends")

	print("\n%s — %d failure(s)" % ["FAILED" if _failures else "PASSED", _failures])
	get_tree().quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
