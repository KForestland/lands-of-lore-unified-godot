extends SceneTree
## Prop154 orb, prop297 crystal, empty lock plates, and movable65's region1249 raise.
## Owner poses from reports 11:10:41, 11:11:14 and 11:12:11. E goes through museum._unhandled_input.
## The plate does not open the lock78 passage. A carried key is not treated as held.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const Orb = preload("res://scripts/lol2/museum_orb_switch.gd")
const KEY := "museum:control87:Sk_key"
const STALAGMITE := "cave:prop641:harvest1:Stalagmite"
var museum
var locks
var orb
var failed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		quit(1)
	return ok

func press() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func pose(at: Vector3, yaw: float, pitch: float) -> void:
	museum.player.position = at
	museum.player.rotation = Vector3(0, yaw, 0)
	museum.camera.rotation = Vector3(pitch, 0, 0)
	await physics_frame

func shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var path := "user://tests/" + file_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", ProjectSettings.globalize_path(path))

func view(target: Vector3) -> bool:
	for distance in [45.0, 70.0, 30.0, 88.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			for lift in [0.0, -12.0, 12.0]:
				var eye: Vector3 = target + d * distance + Vector3(0, lift, 0)
				museum.player.position = eye - Vector3(0, museum.camera.position.y, 0)
				museum.camera.rotation = Vector3.ZERO
				museum.player.rotation = Vector3.ZERO
				museum.camera.look_at(target)
				await physics_frame
				if museum.can_reach_item(target): return true
	return false

func passage_blocked() -> bool:
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-2000, 40, -1085), Vector3(-1950, 40, -1085))
	q.exclude = [museum.player.get_rid()]
	return not museum.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func ray_down(from_y: float) -> Vector3:
	# The kinematic plate publishes its transform on the physics step after the write.
	await physics_frame
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-2095, from_y, -1085), Vector3(-2095, -80, -1085))
	q.exclude = [museum.player.get_rid()]
	var hit: Dictionary = museum.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(0, 9999, 0)

func aim_dot(target: Vector3) -> float:
	var offset: Vector3 = target - museum.camera.global_position
	if offset.length() < 0.01: return 0.0
	return (-museum.camera.global_basis.z).dot(offset.normalized())

func run() -> void:
	var museum_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_review/museum.json"))
	var face: Dictionary = museum_json.faces[3307]
	if not check(int(face.region) == 1249 and str(face.kind) == "floor" and str(face.material) == "231", "Face 3307 is not region1249"): return
	for point in face.points:
		if not check(is_equal_approx(float(point[1]), -50.0), "Face 3307 is not y=-50"): return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_orb_switch_source.json"))
	if not check(source.pit.points == face.points, "Pit source drifted from museum.json"): return
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	museum.orb_switch.set_process(false)
	current_scene = museum
	await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	museum.gallery.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	locks = museum.key_locks
	orb = museum.orb_switch
	if not check(is_instance_valid(orb) and orb.checkpoint() == Orb.initial() and not orb.raised, "Orb switch missing"): return
	if not check(locks.checkpoint() == State.initial(), "Key packet is not initial"): return
	var orb_mesh: MeshInstance3D = orb.orb
	var crystal_mesh: MeshInstance3D = orb.crystal
	if not check(orb_mesh.position == Vector3(-2048, 19, -1085) and crystal_mesh.position == Vector3(-1305, 10, -722), "Sprite positions"): return
	var orb_quad: QuadMesh = orb_mesh.mesh
	var crystal_quad: QuadMesh = crystal_mesh.mesh
	if not check(is_equal_approx(orb_quad.size.x, 34.0) and is_equal_approx(orb_quad.size.y, 66.0), "Orb bounds"): return
	if not check(is_equal_approx(crystal_quad.size.x, 86.0) and is_equal_approx(crystal_quad.size.y, 81.0), "Crystal bounds"): return
	var plates := 0
	for child in locks.get_children():
		if not str(child.name).begins_with("LockPlate_"): continue
		plates += 1
		if not check(child.get_child_count() == 0, "Lock plate has collision"): return
	if not check(plates == 17 and locks.key_markers[87].visible, "Plates or initial key"): return
	var lowered: Vector3 = await ray_down(10.0)
	if not check(is_equal_approx(lowered.y, -50.0) and await passage_blocked(), "Pit not lowered or passage open: %s" % lowered): return
	# Owner cameras. Dots are recorded; the 0.97 cone is not loosened.
	await pose(Vector3(-2073.23, 32.04, -1133.40), -2.7816, -0.065)
	await shot("pose_orb.png")
	print("ORB_POSE reach78=", museum.can_reach_item(locks.aim_point(78)), " plate=", museum.can_reach_item(orb.aim), " dot78=", snappedf(aim_dot(locks.aim_point(78)), 0.001), " dotplate=", snappedf(aim_dot(orb.aim), 0.001), " dotorbsprite=", snappedf(aim_dot(orb_mesh.global_position + Vector3(0, 33, 0)), 0.001))
	await pose(Vector3(-2271.10, 32.04, -1061.31), 3.14157, 0.097)
	await shot("pose_key.png")
	print("KEY_POSE reach87=", museum.can_reach_item(locks.aim_point(87)), " dot87=", snappedf(aim_dot(locks.aim_point(87)), 0.001))
	await pose(Vector3(-1294.09, 32.0, -588.74), -0.0096, -0.082)
	await shot("pose_crystal.png")
	print("CRYSTAL_POSE reach113=", museum.can_reach_item(locks.aim_point(113)), " reach297=", museum.can_reach_item(crystal_mesh.global_position), " dot113=", snappedf(aim_dot(locks.aim_point(113)), 0.001), " dot297=", snappedf(aim_dot(crystal_mesh.global_position + Vector3(0, 40, 0)), 0.001))
	if not check(not museum.can_reach_item(crystal_mesh.global_position), "Owner crystal pose can smash prop297"): return
	var carried_before: int = museum.carried_collected.size()
	await press()
	if not check(museum.carried_collected.size() == carried_before and not orb.raised, "Crystal pose E granted or raised"): return
	if not await view(crystal_mesh.global_position + Vector3(0, 40, 0)):
		if not check(false, "No crystal vantage"): return
	await shot("pose_crystal_near.png")
	# Take the niche key through the real host, then put it away. Empty-hand E must not insert.
	if not await view(locks.aim_point(87)):
		if not check(false, "No niche vantage"): return
	await press()
	print("NICHE_DIAG hand=",museum.hand_item," collected=",museum.carried_collected," reach=",museum.can_reach_item(locks.aim_point(87))," mouse=",Input.mouse_mode," flying=",museum.flying," processing=",museum.is_processing_unhandled_input()," active=",museum.starting_magic.world_active())
	if not check(museum.carried_collected.count(KEY) == 1 and museum.hand_item == KEY and not locks.key_markers[87].visible, "Take niche key"): return
	var plate87: Node = locks.get_node("LockPlate_87")
	if not check(plate87.visible, "Empty niche plate hidden"): return
	if not museum.hold_for_exhibit(KEY):
		if not check(false, "Put away failed"): return
	if not check(museum.hand_item == "" and museum.carried_collected.count(KEY) == 1, "Key left the hand"): return
	await pose(Vector3(-2271.10, 32.04, -1061.31), 3.14157, 0.097)
	var key_reached: bool = museum.can_reach_item(locks.aim_point(87))
	await press()
	if key_reached:
		if not check(State.is_loaded(locks.state, 87) and museum.hand_item == "", "Aimed owner niche did not insert"): return
		await press()
		if not check(museum.hand_item == KEY, "Take back from owner niche"): return
		museum.hold_for_exhibit(KEY)
	else:
		if not check(not State.is_loaded(locks.state, 87) and museum.hand_item == "" and locks.admission_hint() == "", "Owner niche pose consumed the key"): return
	# Inventory hold is the admission path. It must not insert by itself.
	if not museum.open_inventory():
		if not check(false, "Inventory did not open"): return
	await process_frame
	var selected := -1
	for i in museum.inventory.item_list.item_count:
		if str(museum.inventory.item_list.get_item_metadata(i)) == KEY: selected = i
	if not check(selected >= 0, "Sk key missing from inventory"): return
	museum.inventory.select_item(selected)
	if not check(museum.inventory.hold_button.text == "Hold Sk key" and museum.inventory.detail_text.text.contains("skeleton key"), "Hold label: " + museum.inventory.hold_button.text): return
	museum.inventory.hold_button.pressed.emit()
	await process_frame
	if not check(museum.hand_item == KEY and museum.carried_collected.count(KEY) == 1 and not paused, "Hold button did not take the key in hand"): return
	# Key in hand at lock78 opens the passage and does not raise the pit.
	if not await view(locks.aim_point(78)):
		if not check(false, "No lock78 vantage"): return
	var locks_before: Dictionary = locks.checkpoint()
	await press()
	if not check(State.is_loaded(locks.state, 78) and museum.hand_item == "" and not await passage_blocked() and not orb.raised, "Lock78 insert"): return
	await press()
	if not check(museum.hand_item == KEY and await passage_blocked() and locks.checkpoint().loaded.is_empty() and locks.checkpoint().size() == 3, "Lock78 take"): return
	if not check(locks_before.size() == 3 and locks_before.loaded.is_empty(), "Key packet changed before insert"): return
	# Empty hand, stalagmite equipped: the plate rises. The passage stays shut. One key remains.
	museum.equipped_item = STALAGMITE
	museum.hold_for_exhibit(KEY)
	if not check(museum.hand_item == "" and museum.equipped_item == STALAGMITE, "Hand was not empty"): return
	if not await view(orb.aim):
		if not check(false, "No plate vantage"): return
	if not check(orb.interaction_hint() == "E — Raise the floor plate", "Plate hint: " + orb.interaction_hint()): return
	await press()
	if not check(orb.floor_state.height == -50.0 and orb.raised, "Use must start motion, not teleport floor"): return
	if not check(orb.floor_sound_plays == 1 and orb.floor_audio.playing and is_equal_approx(orb.floor_audio.stream.get_length(), 47616.0 / 22050.0), "Raise did not play sound 701"): return
	orb._process(1.0)
	if not check(is_equal_approx((await ray_down(80.0)).y, -14.0), "Moving floor collision missed intermediate height"): return
	museum.equipped_item = "" # Supplied weapon-admission fixture was not earned/carried; do not persist it.
	var moving_path := "user://tests/orb_midmotion.json"
	var moving_error: String = museum.quicksave(moving_path)
	if not check(moving_error.is_empty(), "Mid-motion save failed: " + moving_error): return
	var receipt_file := FileAccess.open("user://tests/orb_floor_receipt.json", FileAccess.WRITE)
	receipt_file.store_string(JSON.stringify({"path":moving_path,"sha256":FileAccess.get_sha256(moving_path)}))
	receipt_file.close()
	orb._process(1.0)
	moving_error = museum.quickload(moving_path)
	if not check(moving_error.is_empty() and orb.floor_state.height == -14.0 and orb.floor_state.timer == 540.0, "Mid-motion rollback failed"): return
	paused = true
	orb._process(1.0)
	paused = false
	if not check(orb.floor_state.height == -14.0 and orb.floor_state.timer == 540.0, "Paused floor advanced"): return
	orb._process(2.0)
	var raised_hit: Vector3 = await ray_down(80.0)
	var hole: Vector3 = await ray_down(10.0)
	if not check(orb.raised and is_equal_approx(raised_hit.y, 30.0) and hole.y > 1000.0 and await passage_blocked(), "Plate raise failed %s hole %s" % [raised_hit, hole]): return
	# Stand on the raised plate, arm the timed descent, and let host physics carry the capsule. Rewound afterwards.
	var ride_player: Vector3 = museum.player.position
	var ride_velocity: Vector3 = museum.player.velocity
	var ride_rotation: Vector3 = museum.player.rotation
	var ride_camera: Vector3 = museum.camera.rotation
	var ride_floor: Dictionary = orb.checkpoint()
	museum.player.position = Vector3(-2095, 62.1, -1085)
	museum.player.velocity = Vector3.ZERO
	museum.set_physics_process(true)
	var stood: bool = false
	var settle: int = 0
	while settle < 30 and not stood:
		await physics_frame
		settle += 1
		stood = museum.player.is_on_floor() and absf(museum.player.position.y - 62.0) < 2.0
	museum.set_physics_process(false)
	if not check(stood, "Raised plate did not support the capsule at %s" % museum.player.position): return
	var support_y: float = museum.player.position.y
	orb._process(7.0)
	if not check(not orb.raised and is_equal_approx(orb.floor_state.height, 30.0), "Ride descent did not arm"): return
	museum.set_physics_process(true)
	var moved: int = 0
	while moved < 30:
		await physics_frame
		moved += 1
	museum.set_physics_process(false)
	var ride_floor_hit: Vector3 = await ray_down(80.0)
	var carried: bool = museum.player.is_on_floor() and museum.player.position.y < support_y - 8.0 and absf(museum.player.position.y - (ride_floor_hit.y + 32.0)) <= 1.5
	print("PLATE_RIDER y=", museum.player.position.y, " floor=", ride_floor_hit.y, " grounded=", museum.player.is_on_floor(), " from=", support_y)
	if not check(carried, "Moving plate did not carry the standing capsule"): return
	var ride_error: String = orb.restore_checkpoint(ride_floor)
	museum.player.position = ride_player
	museum.player.velocity = ride_velocity
	museum.player.rotation = ride_rotation
	museum.camera.rotation = ride_camera
	await physics_frame
	if not check(ride_error.is_empty() and int(orb.floor_state.height) == int(ride_floor.height) and is_equal_approx(float(orb.floor_state.timer), float(ride_floor.timer)) and orb.raised, "Ride rewind failed"): return
	if not check(museum.carried_collected.count(KEY) == 1 and locks.checkpoint().loaded.is_empty(), "Raise duplicated the key"): return
	await press()
	if not check(orb.raised and orb.floor_sound_plays == 1 and is_equal_approx((await ray_down(80.0)).y, 30.0), "Second E changed active cycle"): return
	await shot("pose_plate_raised.png")
	museum.equipped_item = ""
	var path := "user://tests/museum_orb_switch_%d.json" % OS.get_process_id()
	var error: String = museum.quicksave(path)
	if not check(error.is_empty(), "Save: " + error): return
	error = museum.quickload(path)
	if not check(error.is_empty() and orb.raised and museum.carried_collected.count(KEY) == 1, "Reload: " + error): return
	orb._process(7.0)
	if not check(not orb.raised and orb.floor_state.target == -50.0 and orb.floor_state.height == 30.0, "Timer did not request lowering"): return
	orb._process(1.0)
	if not check(is_equal_approx((await ray_down(80.0)).y, -6.0), "Descending floor collision wrong"): return
	orb._process(2.0)
	if not check(is_equal_approx((await ray_down(10.0)).y, -50.0), "Timed reset did not restore lower floor"): return
	error = museum.quickload(path)
	if not check(error.is_empty() and orb.raised, "Cycle rollback failed"): return
	var raw := FileAccess.get_file_as_string(path)
	var saved: Dictionary = JSON.parse_string(raw)
	saved.checkpoint.museum_orb_switch = {"version": 1, "raised": 1}
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(saved))
	out.close()
	error = museum.quickload(path)
	if not check(not error.is_empty() and orb.raised, "Bad flag accepted: " + error): return
	saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	saved.checkpoint.erase("museum_orb_switch")
	out = FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(saved))
	out.close()
	error = museum.quickload(path)
	if not check(error.is_empty() and not orb.raised and is_equal_approx((await ray_down(10.0)).y, -50.0) and museum.carried_collected.count(KEY) == 1, "Legacy load: " + error): return
	# Aimed along the orb with an empty hand must not open the passage.
	await pose(Vector3(-2000, 32, -1085), PI / 2.0, 0.0)
	await press()
	if not check(await passage_blocked() and museum.carried_collected.count(KEY) == 1, "Orb view opened the passage"): return
	print("PASS museum_orb_switch: orb154 and crystal297 shown, 17 empty lock plates, region1249 rises only for empty-hand E, lock78 passage unchanged, key conserved, legacy save lowers.")
	quit()
