extends SceneTree
## Form fit on a sloped floor (lead 2026-11-14, r19j cut check): at the F2 Claw Mountains arrival Ctrl+Q (Curse 3, the
## lizard) said 'The spell has no effect here'. The body stands on the floor (feet 0.14 above it), but the floor slopes:
## the lizard is a flat-based cylinder (radius 8, height 8) whose rim reached into the rising ground. player_form_body.gd:
## for a body on the floor the lizard's fit check starts one radius above the feet; sides and top keep full clearance.
## Real input:
##  (a) F2 'act2-l12' (Claw Mountains arrival), key 3 then Ctrl+Q at once: Luther becomes the lizard;
##  (b) the same stand with a roof slab 6 above the feet (lower than the lizard; test aid: the body is held in place,
##      physics off, since a standing human cannot be under it): Ctrl+Q still refuses.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL form fit slope: ", m)
	quit(1)
func tap(code: Key, ctrl: bool = false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.ctrl_pressed = ctrl; e.pressed = down
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
func open_claw() -> Node:
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act2-l12": entry = c
	var old := current_scene
	var err: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, Starts.read(entry).state, true)
	if not err.is_empty(): fail("start " + err); return null
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 60: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return current_scene
func cast_lizard(scene: Node) -> int:
	await tap(KEY_3)
	for i in 5: await physics_frame
	await tap(KEY_Q, true)
	for i in 120:
		await physics_frame
		if int(scene.player_form) != 0: break
	return int(scene.player_form)
func run() -> void:
	set_meta("original_game_verified", true)
	# (a)
	var scene: Node = await open_claw()
	if scene == null: return
	var stand: Vector3 = scene.player.global_position
	var form: int = await cast_lizard(scene)
	print("FIT (a) F2 Claw Mountains at %s, on_floor %s: Ctrl+Q -> form %d (%s)" % [str(stand), str(scene.player.is_on_floor()), form, str(scene.starting_magic.get("notice"))])
	if form != 2: return fail("(a) Ctrl+Q at the F2 arrival did not make the lizard (form %d, '%s')" % [form, str(scene.starting_magic.get("notice"))])
	# (b)
	scene = await open_claw()
	if scene == null: return
	var feet: float = scene.player.global_position.y - 32.0
	# Test aid: the human (46 tall) cannot stand under a roof lower than the lizard, so the body is held where it stands
	# (physics off, still on the floor) while the slab is placed.
	var held: Vector3 = scene.player.global_position
	scene.player.set_physics_process(false); scene.set_physics_process(false)
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(80, 4, 80); shape.shape = box
	roof.add_child(shape); scene.add_child(roof)
	roof.global_position = Vector3(scene.player.global_position.x, feet + 6.0 + 2.0, scene.player.global_position.z)
	for i in 5: await physics_frame
	scene.player.global_position = held
	for i in 2: await physics_frame
	form = await cast_lizard(scene)
	print("FIT (b) roof 6 above the feet: Ctrl+Q -> form %d (%s)" % [form, str(scene.starting_magic.get("notice"))])
	if form != 0: return fail("(b) the lizard formed under a roof lower than its height (form %d)" % form)
	print("PASS form fit slope: F2 Claw Mountains Ctrl+Q makes the lizard at once; a roof lower than the lizard still refuses")
	quit(0)
