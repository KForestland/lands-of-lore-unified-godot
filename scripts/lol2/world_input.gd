extends RefCounted
## Shared mouse admission for world input. Headless has no window to capture.
## Callers still own pause, flight, inventory, cursor, form and actor/modal locks.
static func available() -> bool:
	return captured() or DisplayServer.get_name() == "headless"

## Actual pointer/capture-controlled clock state; preserves existing non-input behavior.
static func captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
