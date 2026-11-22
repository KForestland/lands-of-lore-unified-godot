extends SceneTree
## Source event/transaction vectors, not player-input acceptance.
const Native = preload("res://scripts/lol2/native_script_host.gd")
const Prog = preload("res://scripts/lol2/act2_progression.gd")
func vm():
	var value = Native.new()
	assert(value.load_area("res://scripts/lol2/native_scripts/L13_RC.json").is_empty())
	return value
func ran(results: Array, group: int) -> bool:
	for result: Dictionary in results:
		if result.status == "ran" and int(result.group) == group: return true
	return false
func _initialize() -> void:
	var blocked = vm()
	blocked.set_adapter_enabled("opcode9_enqueue", false)
	var before: Dictionary = blocked.snapshot()
	var rejected: Array = blocked.fire_event("prop:250", 4, {"arg_c":0, "context":"prop:250"})
	assert(not ran(rejected, 4366) and blocked.snapshot() == before, "Disabled consumer rolls back the entire group")
	var native = vm()
	var used: Array = native.fire_event("prop:250", 4, {"arg_c":0, "context":"prop:250"})
	assert(ran(used, 4366) and not ran(used, 4456))
	assert(native.field("prop:250", Native.FIELD_BYTE25) == 1)
	assert(native.field("movable:84", Native.FIELD_TRAVEL) == 95)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(native.snapshot(), "", true, true))
	var loaded = vm()
	assert(loaded.restore(saved).is_empty())
	assert(loaded.snapshot() == native.snapshot(), "Native object/record state survives disk-shaped roundtrip")
	var busy: Dictionary = loaded.snapshot()
	var repeated: Array = loaded.fire_event("prop:250", 4, {"arg_c":0, "context":"prop:250"})
	assert(not ran(repeated, 4366) and not ran(repeated, 4456) and loaded.snapshot() == busy, "Busy predicates remain native, without invented phase transitions")
	# Explicit VM-only predicate vector, never supplied to a gameplay scene.
	loaded.set_field("prop:250", Native.FIELD_BYTE25, 2)
	assert(ran(loaded.fire_event("prop:250", 4, {"arg_c":0, "context":"prop:250"}), 4456))
	var pad = vm()
	var results: Array = pad.fire_event("control:53", 5, {"caller_byte":4, "caller_byte_2":0, "context":"control:53"})
	assert(ran(results, 8134))
	var poses := []
	for result: Dictionary in results:
		for effect: Dictionary in result.get("effects", []):
			if effect.get("type") == "player_pose": poses.append(effect)
	assert(poses.size() == 1)
	var pose: Dictionary = poses[0]
	assert(int(pose.x) == -3258 and int(pose.y) == -5589 and int(pose.flags) == 0x0485 and not pose.apply_height)
	assert(Prog.player_pose_position(pose, Vector3(0,-868,0)) == Vector3(-3258,-868,5589), "Decoder keeps native height; destination-floor reconciliation belongs only to the declared world adapter")
	print("PASS L13 source actions: native250 predicates/84 enqueue, atomic disabled rejection, disk-shaped state, busy/reverse phase vectors, control53 original pose/flags")
	quit()
