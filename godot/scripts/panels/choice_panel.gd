class_name ChoicePanel
extends ListPanel
## A list of the values one setting can take, instead of pressing A over and
## over to cycle through them. Shows which one is current.

var _options: Array = []
var _on_pick: Callable


func open_choice(heading: String, options: Array, current: String, on_pick: Callable) -> void:
	_options = options
	_on_pick = on_pick
	open()
	set_title(heading)
	for i in options.size():
		if str(options[i].get("id", "")) == current:
			selected = i
	refresh()


func build_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option in _options:
		out.append({
			"id": str(option.get("id", "")),
			"text": str(option.get("text", option.get("id", ""))),
			"suffix": str(option.get("suffix", "")),
			"checked": bool(option.get("current", false)),
		})
	return out


func prompt_defs() -> Array:
	return [["ui_accept", "Choose"], ["ui_cancel", "Cancel"]]


func on_activate(id: String) -> void:
	close()
	if _on_pick.is_valid():
		_on_pick.call(id)
