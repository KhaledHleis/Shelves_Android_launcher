extends Node
## Tracks whether the user is driving the launcher by touch or by pad, and
## owns the two rules carried over from v0.1:
##
## 1. The focus highlight shows only while a pad or keyboard is in use.
## 2. The first pad press after touch only wakes the cursor — it does not
##    also move the selection.

signal mode_changed(using_pad: bool)

const STICK_DEADZONE := 0.4

var using_pad: bool = false

var _wake_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A handheld always has its pad attached, so start with prompts showing.
	using_pad = not Input.get_connected_joypads().is_empty()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_pad(false)
	elif event is InputEventJoypadButton or event is InputEventKey:
		_set_pad(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			_set_pad(true)


func _set_pad(pad: bool) -> void:
	if using_pad == pad:
		return
	if pad:
		# This press only brings the cursor back; whatever it was bound to is
		# swallowed by the next consume_wake() call.
		_wake_pending = true
	using_pad = pad
	mode_changed.emit(using_pad)


## True when the current press should be swallowed because it only woke the
## cursor up. Call this once, at the top of a navigation handler.
func consume_wake() -> bool:
	if _wake_pending:
		_wake_pending = false
		return true
	return false


# ---------------------------------------------------------------- actions

## Action that means "select / launch". Nintendo layouts put that button on
## the right, so the meaning of the two face buttons swaps.
func accept_action() -> String:
	return "ui_cancel" if bool(Settings.get_value("swap_ab")) else "ui_accept"


func back_action() -> String:
	return "ui_accept" if bool(Settings.get_value("swap_ab")) else "ui_cancel"


func accept_just_pressed() -> bool:
	return Input.is_action_just_pressed(accept_action())


func back_just_pressed() -> bool:
	return Input.is_action_just_pressed(back_action())
