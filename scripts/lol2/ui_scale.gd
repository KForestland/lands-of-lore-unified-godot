extends RefCounted
## Player UI size (owner request 2026-10-21: "the UI needs to be 150-200% larger"). Modern adapter: the HUD
## cluster, prompt line, Character/Atlas sheet and inventory scale by FACTORS[current]; F6 switches 150% / 200%. The
## choice is a per-player convenience kept in user://lol2_settings.cfg (missing or unreadable: 150%).
## Owner r12h F10 2026-10-26 ("UI still too small, 300-350%", played at 6144x3312): the step is relative to a 720-high
## window (larger windows multiply it by height/720), and F6 cycles 150% / 200% / 300% / 350%. The HUD cluster stays
## within 45% of the window height and 30% of its width.
const FACTORS := [1.5, 2.0, 3.0, 3.5]
const REFERENCE_HEIGHT := 720.0
const SETTINGS := "user://lol2_settings.cfg"
const KEY := KEY_F6
static var _index := -1

static func factor() -> float:
	if _index < 0:
		_index = 0
		var config := ConfigFile.new()
		if config.load(SETTINGS) == OK:
			var saved: Variant = config.get_value("ui", "scale_index", 0)
			if (saved is int or saved is float) and int(saved) >= 0 and int(saved) < FACTORS.size(): _index = int(saved)
	return FACTORS[_index]

static func toggle() -> float:
	factor()
	_index = (_index + 1) % FACTORS.size()
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("ui", "scale_index", _index)
	config.save(SETTINGS)
	return FACTORS[_index]

## Window size multiplier: 1 up to a 720-high window, then height / 720.
static func resolution(view: Vector2) -> float: return maxf(1.0, view.y / REFERENCE_HEIGHT)

## The chosen step times the window multiplier.
static func effective(view: Vector2) -> float: return factor() * resolution(view)

## Scale of a HUD cluster of `cluster` pixels in `view`: effective(), capped to 45% of the height and 30% of the width.
static func cluster_scale(view: Vector2, cluster: Vector2) -> float:
	if cluster.x <= 0 or cluster.y <= 0: return effective(view)
	return minf(effective(view), minf(view.y * 0.45 / cluster.y, view.x * 0.3 / cluster.x))

## Scale `control` about `pivot` (0..1 of its size) by the UI factor, shrunk so it stays inside `room`.
static func fit(control: Control, pivot: Vector2, room: Vector2) -> float:
	var size := control.size
	if size.x <= 0 or size.y <= 0: return 1.0
	var view := control.get_viewport().get_visible_rect().size if control.is_inside_tree() else Vector2(0, REFERENCE_HEIGHT)
	var s := minf(effective(view), minf(room.x / size.x, room.y / size.y))
	s = maxf(s, 0.5)
	control.pivot_offset = size * pivot
	control.scale = Vector2(s, s)
	return s
