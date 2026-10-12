extends RefCounted
## Preview orchestration, not an emulation of the native request backend.
const FPS := 12.0
const SNAP_FRAMES := 27
const REQUEST_DELAY := 2.25
const OPEN_SECONDS := 2.0
var started := false
var elapsed := 0.0
var selector := 0
var frame := 0
var opening := 0
var request_completed := false
var door_dispatch_count := 0

func activate() -> bool:
	if started:
		return false
	started = true
	selector = 1
	return true

func advance(delta: float) -> void:
	if not started:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed < SNAP_FRAMES / FPS:
		frame = mini(int(elapsed * FPS), SNAP_FRAMES - 1)
	else:
		selector = 2
		frame = 0
	if not request_completed and elapsed >= REQUEST_DELAY:
		request_completed = true
		door_dispatch_count += 1
	if request_completed:
		opening = clampi(int((elapsed - REQUEST_DELAY) / OPEN_SECONDS * 100.0), 0, 100)

func reset() -> void:
	started = false
	elapsed = 0.0
	selector = 0
	frame = 0
	opening = 0
	request_completed = false
	door_dispatch_count = 0
