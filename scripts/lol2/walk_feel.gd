extends RefCounted
## Modern walk feel (owner 2026-10-24: "a walking system with bobing and smoones"). Enhanced adapter, off by default:
## the original's view does not bob (longplay slit-scans: the horizon stays flat while walking) and no start/stop
## easing is proven, so Classic keeps instant speed changes and a fixed eye. F4 switches it on/off; the choice is a
## per-player convenience kept in user://lol2_settings.cfg (missing or unreadable: off). See docs/DEVIATIONS.md.
## Bob moves only the rendered view (Camera3D.v_offset): the camera node, aim rays and the collision body stay put.
const SETTINGS := "user://lol2_settings.cfg"
const KEY := KEY_F4
const ACCELERATE_SECONDS := 0.12
const STOP_SECONDS := 0.06
## One walk/run pair for every area (Cave, Museum, Jungle, Hive, Dark Halls): the Cave's 80 walking, 144 with Shift.
## Port values, not traced native speeds (docs/DEVIATIONS.md).
const WALK_SPEED := 80.0
const RUN_SPEED := 144.0
const BOB_WALK := 0.9
const BOB_RUN := 1.5
const STEPS_WALK := 1.9
const STEPS_RUN := 2.6
static var _enabled := -1
var planar := Vector2.ZERO
var phase := 0.0

static func enabled() -> bool:
	if _enabled < 0:
		_enabled = 0
		var config := ConfigFile.new()
		if config.load(SETTINGS) == OK and config.get_value("walk", "modern_feel", false) == true: _enabled = 1
	return _enabled == 1

static func set_enabled(on: bool, save := true) -> void:
	_enabled = 1 if on else 0
	if not save: return
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("walk", "modern_feel", on)
	config.save(SETTINGS)

static func toggle() -> bool:
	set_enabled(not enabled())
	return enabled()

## Horizontal velocity for this tick: the wanted velocity at once when off; eased toward it when on (full speed in
## ACCELERATE_SECONDS from rest, a stop in STOP_SECONDS).
func velocity(wanted: Vector2, delta: float) -> Vector2:
	if not enabled() or delta <= 0.0:
		planar = wanted
		return wanted
	if wanted == Vector2.ZERO and planar == Vector2.ZERO: return planar
	var rate := maxf(maxf(wanted.length(), planar.length()), WALK_SPEED)
	var seconds := STOP_SECONDS if wanted.length() < planar.length() else ACCELERATE_SECONDS
	planar = planar.move_toward(wanted, rate / seconds * delta)
	return planar

## View bob after the body moved: a step cycle whose height and rate grow with ground speed; it settles back to level
## when the player stops or leaves the floor. Off: the offset is cleared.
func bob(camera: Camera3D, ground_speed: float, on_floor: bool, delta: float) -> void:
	if camera == null: return
	if not enabled():
		camera.v_offset = 0.0
		phase = 0.0
		return
	var run := clampf((ground_speed - WALK_SPEED) / WALK_SPEED, 0.0, 1.0)
	if on_floor and ground_speed > 4.0:
		phase = fmod(phase + delta * lerpf(STEPS_WALK, STEPS_RUN, run) * PI, TAU)
		var amplitude := lerpf(BOB_WALK, BOB_RUN, run) * minf(ground_speed / WALK_SPEED, 1.0)
		camera.v_offset = -absf(sin(phase)) * amplitude
	else:
		camera.v_offset = move_toward(camera.v_offset, 0.0, 12.0 * delta)
		if is_zero_approx(camera.v_offset): phase = 0.0
