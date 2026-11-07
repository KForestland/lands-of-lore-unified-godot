extends Node
## Source-selected forms and duration range; modern clock/RNG/presentation adapter.
const Body = preload("res://scripts/lol2/player_form_body.gd")
# Native preparation150 and blend64 ticks, mapped to an authored60Hz clock.
const WARNING_SECONDS := 214.0/60.0
# Native 649D8 decodes a form argument byte to (low nibble*15 .. +high nibble*15) s: at most 450 (the Jungle river dam
# asks 120..180 s; Cave/Hive draws stay within 60..150).
const MAX_DURATION := 450.0
var state: Dictionary = initial()
var cave_regions: Array = []

func _ready() -> void:
	state.seed = randi()

static func initial() -> Dictionary:
	return {"phase":0,"previous":0,"target":0,"remaining":0.0,"duration":0.0,"seed":324508639,"cave_triggered":false}

static func valid(value: Variant, form: Variant) -> bool:
	if not value is Dictionary or not Body.valid(form): return false
	if value.has("admission_flags"):
		var flags = value.admission_flags
		if not (flags is int or flags is float) or not is_finite(float(flags)) or flags != floorf(float(flags)) or int(flags) not in [0,16,32,48]: return false
	for key in ["phase","previous","target","remaining","duration","seed"]:
		var n = value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)): return false
	for key in ["phase","previous","target","seed"]:
		if value[key] != floorf(float(value[key])): return false
	if value.phase < 0 or value.phase > 3 or not Body.valid(value.previous) or not Body.valid(value.target): return false
	if value.seed < 0 or value.seed > 4294967295 or not value.get("cave_triggered") is bool: return false
	if value.remaining < 0 or value.duration < 0 or value.duration > MAX_DURATION: return false
	match int(value.phase):
		0: return value.remaining == 0 and value.duration == 0
		1: return value.remaining <= WARNING_SECONDS and (value.duration >= 60 or value.duration == 0) and value.previous == form and value.target != form
		2: return value.remaining <= value.duration and value.duration >= 60 and value.target == form and value.previous != form
		3: return value.remaining == 0 and value.duration == 0 and value.target != form
	return false

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(value: Dictionary) -> void:
	state = value.duplicate(true)
	for key in ["phase","previous","target","seed"]: state[key] = int(state[key])
	if state.has("admission_flags"): state.admission_flags = int(state.admission_flags)

## Native player+228: commands24/25 set/clear both bits0x30. Scripted
## requests test bit0x10; neither command cancels a pending transformation.
## Omitted flags retain legacy admission until the area's legacy state is read.
func requests_enabled() -> bool:
	return (int(state.get("admission_flags",0x30)) & 0x10) != 0

func set_requests_enabled(enabled: bool) -> void:
	state.admission_flags = 0x30 if enabled else 0

func restore_legacy_dawn_admission(receipts: Array) -> void:
	if state.has("admission_flags"): return
	for command in receipts:
		if command == "020100002500": set_requests_enabled(false)
		elif command == "020100002400": set_requests_enabled(true)

func _draw(low: int, high: int) -> int:
	# Stable restoration-owned stream; source RNG algorithm is not claimed.
	state.seed = (1664525*int(state.seed)+1013904223) & 0xffffffff
	return low + int(state.seed) % (high-low+1)

static func choose_form(current: int, previous: int, draw: int) -> int:
	if draw != current: return draw
	var chosen := (draw+1)%3
	return (chosen+1)%3 if chosen == previous else chosen

func cancel_aura() -> void:
	var host = get_parent()
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): host.starting_magic.cancel_aura()

func request_cave_curse() -> bool:
	if not requests_enabled() or state.cave_triggered or state.phase != 0: return false
	var current: int = get_parent().player_form
	var chosen := choose_form(current,int(state.previous),_draw(0,2))
	var duration := _draw(60,90)
	# From a held nonhuman form (region631) the source group still sets local1, but D6B20 refuses nonhuman->nonhuman.
	if current != 0 and chosen != 0:
		state.cave_triggered = true
		return false
	cancel_aura()
	state.merge({"phase":1,"previous":current,"target":chosen,"remaining":WARNING_SECONDS,"duration":float(duration),"cave_triggered":true},true)
	return true

## Cave region631 group256 runs player op2 sub0x13 with argument0. Native D7FB7 draws the same random form as the
## later curse regions; the duration decoder 649D8 returns0 for argument0 and D6D2C then sets the form timer to
## 0x7FFFFFFF, which the tick never counts down (D26EF) and the expiry path (D45DE->D4906) never reaches. The form is
## held: duration0 in the warning phase arrives in phase0 with the new form and no timer. It ends only through a later
## admitted request for human (cave curse regions drawing human, Museum op2 sub0x3C regions). Admission bit0x10 is
## required; a nonhuman current form is refused (D6B20 rejects nonhuman->nonhuman).
func request_region631_curse() -> bool:
	if not requests_enabled() or state.phase != 0: return false
	var current: int = get_parent().player_form
	if current != 0: return false
	var chosen := choose_form(current,int(state.previous),_draw(0,2))
	cancel_aura()
	# Owner 2026-10-21 ("stuck as beast"; mostly human): the native held form (timer 0x7FFFFFFF, above) becomes the
	# cave curse regions' 60-90 s form timer, then human (docs/DEVIATIONS.md).
	state.merge({"phase":1,"previous":current,"target":chosen,"remaining":WARNING_SECONDS,"duration":float(_draw(60,90))},true)
	return true

# Native D6B20 rejects a nonhuman -> nonhuman request. Presentation and clock
# are shared modern adapters; collision checks also protect forced human return.
func request_timed_form(target: int, duration: float) -> bool:
	if not requests_enabled(): return false
	var current: int = get_parent().player_form
	if not Body.valid(target) or duration < 60 or duration > MAX_DURATION or not is_finite(duration): return false
	if target == current or state.phase == 1 or state.phase == 3: return false
	if current != 0 and target != 0: return false
	if target == 0: return request_human()
	cancel_aura()
	state.merge({"phase":1,"previous":current,"target":target,"remaining":WARNING_SECONDS,"duration":duration},true)
	return true

func request_human() -> bool:
	if not requests_enabled(): return false
	if get_parent().player_form == 0:
		state.merge({"phase":0,"target":0,"remaining":0.0,"duration":0.0},true)
		return true
	cancel_aura()
	state.merge({"phase":3,"target":0,"remaining":0.0,"duration":0.0},true)
	return true

func active() -> bool:
	var host = get_parent()
	if get_tree().paused or not host.is_physics_processing() or host.flying or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.get("walkthrough_ready") != null and not host.walkthrough_ready: return false
	if host.get("drowning") != null and host.drowning.dead: return false
	if host.get("roach") != null and host.roach.model.player_health <= 0: return false
	if host.get("video_overlay") != null and is_instance_valid(host.video_overlay): return false
	if host.get("introduction_state") != null and host.introduction_state != "complete": return false
	if host.has_node("Warriors") and not host.get_node("Warriors").active(): return false
	return true

func _physics_process(delta: float) -> void:
	if not active(): return
	if not state.cave_triggered and not cave_regions.is_empty() and get_parent().player.is_on_floor():
		var p: Vector3 = get_parent().player.global_position-get_parent().native_translation
		var foot := p.y-Body.FOOT_OFFSET
		for region in cave_regions:
			if foot < region.floor_min-1 or foot > region.floor_max+3: continue
			var polygon := PackedVector2Array()
			for vertex in region.polygon: polygon.append(Vector2(vertex[0],vertex[1]))
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):
				request_cave_curse()
				break
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0 or state.phase == 0: return
	state.remaining = maxf(0.0,float(state.remaining)-delta)
	if state.remaining > 0: return
	if state.phase == 2:
		state.target = state.previous
		state.phase = 3
		state.duration = 0.0
	if state.phase == 1 or state.phase == 3:
		var host = get_parent()
		# Area hook (Museum Long arm chute): the morph waits as if there were no room.
		if host.has_method("form_change_blocked") and host.form_change_blocked(int(state.target)): return
		# Shrinking to tiny form on the chute slope: the cylinder rim meets the slope, so skip the room query there.
		var check_space: bool = not (host.has_method("form_change_unchecked") and host.form_change_unchecked(int(state.target)))
		if not Body.apply(host.player,host.camera,int(state.target),check_space): return
		host.player_form = int(state.target)
		preload("res://scripts/lol2/player_form_rules.gd").on_morphed(host)
		if state.phase == 1 and float(state.duration) == 0.0:
			# Source duration0 (D6D2C 0x7FFFFFFF): the new form is held with no timer.
			state.phase = 0
			state.remaining = 0.0
		elif state.phase == 1:
			state.phase = 2
			state.remaining = state.duration
		else:
			state.phase = 0
			state.remaining = 0.0

func message() -> String:
	if state.phase == 1: return "The curse stirs…"
	if state.phase == 3: return "You need room to change back."
	return ["Human","Beast","Lizard"][get_parent().player_form]
