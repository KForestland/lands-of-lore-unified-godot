extends Node
## Enter (or keypad Enter) skips the spoken line now playing (owner request 2026-10-22; docs/DEVIATIONS.md).
## Any node with skip_line() -> bool can take it: the owner pushes only its own speech clock to the line's end, so the
## line's normal completion code still runs (flags, items, the next line, room exits). The first owner that accepts
## consumes the key. Overlays that swallow all keys pass Enter through, as they do F10.
const KEYS := [KEY_ENTER, KEY_KP_ENTER]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or not event.keycode in KEYS: return
	var feedback := get_node_or_null("/root/PlaytestFeedback")
	if feedback != null and feedback.active: return
	if skip(): get_viewport().set_input_as_handled()

## Skips the line of the first owner that is speaking; false when nobody is.
func skip() -> bool:
	return _skip_in(get_tree().root)

func _skip_in(node: Node) -> bool:
	if node != self and node.has_method("skip_line") and node.skip_line(): return true
	for child in node.get_children():
		if _skip_in(child): return true
	return false
