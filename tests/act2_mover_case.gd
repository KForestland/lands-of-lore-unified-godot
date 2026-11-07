extends SceneTree
const Binder = preload("res://scripts/lol2/act2_progression.gd")
var failures := 0
func area() -> String: return ""
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL mover: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var a := area()
	var scene = load(Binder.LEVEL_SCENES[int(a.get_slice("_",0).trim_prefix("L"))]).instantiate()
	root.add_child(scene)
	var p = scene.progression
	check(p != null, "binder attached " + a)
	if p == null: quit(1); return
	p.change_scene_enabled = false
	p.set_physics_process(false)
	scene.player.set_physics_process(false)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/native_scripts/" + a + ".json"))
	var applied := false
	var refusals: Array = []
	for group in source.groups:
		var targets: Array = []
		for command in group.commands:
			var raw: PackedByteArray = str(command.raw_hex).hex_decode()
			if int(command.opcode) == 1 and int(command.kind) == 0x20 and int(raw[4]) > 0 and p.hinges.has(int(command.target)):
				targets.append(int(command.target))
		if targets.is_empty(): continue
		var before: Dictionary = {}
		for id in targets: before[id] = p.hinges[id].transform
		var result: Dictionary = p.native.execute_group(int(group.stream), int(group.group))
		if str(result.status) != "ran":
			refusals.append({"group": group.group, "reasons": result.reasons})
			continue
		for i in 120: p.advance_movers(1.0 / 60.0)
		for id in targets:
			check(p.mover_bodies.has(id) and p.mover_bodies[id].get_child_count() > 0, "moving collision " + str(id))
			if not p.hinges[id].transform.is_equal_approx(before[id]): applied = true
		if applied: break
	check(applied, a + " has at least one source opcode1 group driving visible geometry/collision; refusals=" + str(refusals))
	print(a, " mover bodies=", p.mover_bodies.size(), " applied=", applied)
	if failures == 0: print("PASS ", a, " original opcode1 group drives mover geometry and collision (motion adapter)")
	quit(0 if failures == 0 else 1)
