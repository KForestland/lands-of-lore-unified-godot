extends SceneTree
## L19 -> L20 door (lead 2026-11-14 after Grok robot/L19_BC/20261114_e21599e-dawn: at (3303, -943, -874) in region 2369 the
## scene did not change; DEVIATIONS row). Region 2369's entry records pick the L20 arrival by [0x26E58] cell 52 (pred 204
## == 0 -> arrival 1, region 316; pred 205 == 1 -> arrival 2, region 1523). F2 checkpoints carry no exit seeds, so the cell
## stayed unknown. Adapter L19_to_L20_history: at the door an unknown cell comes from the player's own L20 history (1 once
## the curse was cast into the mother, l19_dawn_curse.glob_entered; else 0).
## Real input (W held) from region 2365 into 2369, three starts:
##  (a) F2 checkpoint act3-l19 (no seeds, no L20 history) -> L20 at arrival 1;
##  (b) the same with the curse already cast into the mother (quest glob_entered) -> L20 at arrival 2;
##  (c) a slot save written on L19 and loaded by F9 (no L20 history) -> L20 at arrival 1.
## Test aids: start poses in 2365 (the robot's way in) and, in (b), the quest flag written into the checkpoint.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const ARRIVAL_1 := Vector2(-2383, -4261)
const ARRIVAL_2 := Vector2(-2398, -3206)
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l19 l20 door: ", m)
	quit(1)
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
func open_l19(state: Dictionary) -> Node:
	var old := current_scene
	var rerr: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, "L19_BC", state, true)
	if not rerr.is_empty(): print("RESUME ERROR ", rerr)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 30: await physics_frame
	return current_scene
func walk_to_door(scene: Node) -> Node:
	var creatures = scene.get("act2_creatures")
	if creatures is Node: creatures.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.global_position = Vector3(3240, -975 + 32.5, -874); scene.player.velocity = Vector3.ZERO
	for t in 20: await physics_frame
	var old := current_scene
	key(KEY_W, true)
	for t in 600:
		if not is_instance_valid(old) or current_scene != old: break
		var p: Vector3 = old.player.global_position
		old.player.rotation.y = atan2(-(3330.0 - p.x), -(-874.0 - p.z))
		await physics_frame
	key(KEY_W, false)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 20: await physics_frame
	return current_scene
func check_arrival(scene: Node, want: Vector2, label: String) -> bool:
	if scene == null or str(scene.get("area_id")) != "L20_BB":
		fail("%s: the door did not lead to L20 (scene %s)" % [label, str(scene.name) if scene != null else "none"]); return false
	var p: Vector3 = scene.player.global_position
	var d := Vector2(p.x, p.z).distance_to(want)
	print("DOOR %s: L20 at %s (%.0f from the expected arrival)" % [label, str(p), d])
	if d > 120.0:
		fail("%s: L20 arrival at %s, want near %s" % [label, str(p), str(want)]); return false
	return true
func run() -> void:
	set_meta("original_game_verified", true)
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act3-l19": entry = c
	var base: Dictionary = Starts.read(entry).state
	# (a)
	var scene: Node = await open_l19(base.duplicate(true))
	if str(scene.get("area_id")) != "L19_BC": return fail("(a) checkpoint opened " + str(scene.name))
	if (scene.progression.native.get("locals_e58") as Dictionary).has(52): return fail("(a) the checkpoint already knows cell 52 (no red)")
	scene = await walk_to_door(scene)
	if not check_arrival(scene, ARRIVAL_1, "(a) F2 checkpoint"): return
	# (b)
	var with_curse: Dictionary = base.duplicate(true)
	var curse: Dictionary = (with_curse.quests.get("l19_dawn_curse", preload("res://scripts/lol2/l19_dawn_curse.gd").initial()) as Dictionary).duplicate(true)
	curse.clicks = 3; curse.curse_said = true; curse.ruby_offered = true; curse.glob_entered = true; curse.line = preload("res://scripts/lol2/l19_dawn_curse.gd").CURSE_LINE
	with_curse.quests["l19_dawn_curse"] = curse
	scene = await open_l19(with_curse)
	if str(scene.get("area_id")) != "L19_BC": return fail("(b) checkpoint opened " + str(scene.name))
	scene = await walk_to_door(scene)
	if not check_arrival(scene, ARRIVAL_2, "(b) curse cast into the mother"): return
	# (c)
	scene = await open_l19(base.duplicate(true))
	var save := "res://tmp/l19_l20_door_slot_save.json"
	var err: String = scene._quicksave_unrecorded(save)
	if not err.is_empty(): return fail("(c) save: " + err)
	err = scene._quickload_unrecorded(save)
	if not err.is_empty(): return fail("(c) load: " + err)
	for i in 60: await physics_frame
	scene = current_scene
	scene = await walk_to_door(scene)
	if not check_arrival(scene, ARRIVAL_1, "(c) save loaded on L19"): return
	print("PASS l19 l20 door: F2 start -> L20 arrival 1; after the curse into the mother -> arrival 2; a loaded L19 save -> arrival 1")
	quit(0)
