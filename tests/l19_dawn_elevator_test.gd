extends SceneTree
## BK07. Stand at the Dawn lever, then at Golden Door 51, then on the cab.
## The door writes local 4. Stepping onto region 1943 rides the cab to -1000.
## The lever brings it back. A reload over a live local 4 writes the saved value.
## A fresh boot of that save claims the cab decks, and Luther stands on the lowered floor.
## Birth group 770 moves Luther through the opcode-18 consumer and requests movie 65.
const DOOR_STAND := Vector3(2550, -68, -830)
const DOOR_AIM := Vector3(2550, -100, -854)
const CAB_STAND := Vector3(2621, -68, -840)
const PLATFORM := 1943
const RING := 1935
const CAB: Array[int] = [1935, 1936, 1937, 1938, 1939, 1940, 1941, 1942, 1943]
const SAVE := "res://tmp/l19_dawn_elevator_save.json"
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func press_e() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_E
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_E
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func look(scene: Node, at: Vector3) -> void:
	scene.camera.global_position = scene.player.global_position + Vector3(0, 10, 0)
	scene.camera.look_at(at, Vector3.UP)

func stand(scene: Node, at: Vector3) -> void:
	scene.player.position = at
	scene.player.velocity = Vector3.ZERO
	for _i in 3:
		await physics_frame

func ride(scene: Node, platform_height: int, ring_height: int) -> bool:
	var arrived := false
	for _step in 160:
		scene.progression.advance_floors(8.0 / 60.0)
		await process_frame
		if int(scene.progression.regions[PLATFORM][1]) == platform_height and int(scene.progression.regions[RING][1]) == ring_height:
			arrived = true
			break
	return arrived

func run() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 120:
		await process_frame
		if scene.ready_for_review and scene.progression != null and scene.get_node_or_null("L19DawnElevator") != null:
			break
	if not check(scene.ready_for_review and scene.get_node_or_null("L19DawnElevator") != null, "L19 ready"):
		quit(1)
		return
	scene.progression.change_scene_enabled = false
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.starting_magic.interface_request = true
	var pr: Node = scene.progression
	check(int(pr.regions[PLATFORM][1]) == -100 and int(pr.regions[RING][1]) == -90, "the cab starts at -100 and -90")
	check(not pr.native.locals.has(4), "local 4 starts unread")
	check(int(pr.native.attributes["movable:51"].angle_word) == 16384, "door 51 angle word is 16384")
	await stand(scene, CAB_STAND)
	var entered: bool = false
	for raw in pr.route_log:
		var row: Dictionary = raw
		if str(row.object) == "region:1943" and int(row.event) == 2:
			entered = true
	if not check(entered and not pr.native.locals.has(4) and int(pr.regions[PLATFORM][1]) == -100, "stepping on the cab does nothing while local 4 is unread"):
		quit(1)
		return
	await stand(scene, DOOR_STAND)
	look(scene, DOOR_AIM)
	await press_e()
	var opened: bool = int(pr.native.locals.get(4, -1)) == 0 and int(pr.travel.get(51, 0)) == 16384 and int(pr.travel.get(52, 0)) == 16384
	if not check(opened, "door 51 writes local 4 as 0 and travels 51 and 52 to 16384"):
		quit(1)
		return
	check(int(pr.regions[PLATFORM][1]) == -100, "the recall leaves the cab at the top")
	var before_y: float = -68.0
	await stand(scene, CAB_STAND)
	check(int(pr.native.locals.get(4, -1)) == 1, "stepping onto the platform runs the down group")
	if not check(await ride(scene, -1000, -990), "the cab reaches -1000 and -990"):
		quit(1)
		return
	check(absf(scene.player.position.y - (before_y - 900.0)) < 2.0, "Luther rides the platform down (y %s)" % scene.player.position.y)
	pr.use(53)
	check(int(pr.travel.get(53, 0)) == 16384 and int(pr.travel.get(54, 0)) == 16384, "the bottom doors travel to 16384")
	check(int(pr.regions[PLATFORM][1]) == -1000, "the bottom doors leave the cab down")
	var lift: Node = scene.get_node("L19DawnElevator")
	check(int(lift.state().local4) == 1 and int(lift.state().floors["1943"]) == -1000, "the quest stores local 4 and the platform")
	if not check(scene._quicksave_unrecorded(SAVE).is_empty(), "elevator save"):
		quit(1)
		return
	scene.player.position = DOOR_STAND
	for raw in [1935, 1936, 1937, 1938, 1939, 1940, 1941, 1942]:
		pr.regions[int(raw)][1] = -90
	pr.regions[PLATFORM][1] = -100
	pr.native.locals.erase(4)
	if not check(scene._quickload_unrecorded(SAVE).is_empty(), "elevator reload"):
		quit(1)
		return
	lift = scene.get_node("L19DawnElevator")
	var kept: bool = int(pr.regions[PLATFORM][1]) == -1000 and int(pr.regions[RING][1]) == -990 and int(pr.native.locals.get(4, -1)) == 1
	check(kept, "the reload keeps the cab down and local 4")
	check(absf(scene.player.position.y - (before_y - 900.0)) < 2.0, "the reload keeps Luther on the cab")
	pr.native.set_local(4, 0)
	if not check(scene._quickload_unrecorded(SAVE).is_empty(), "reload over a live local 4"):
		quit(1)
		return
	var overwritten: bool = int(pr.native.locals.get(4, -1)) == 1 and int(pr.regions[PLATFORM][1]) == -1000 and int(pr.regions[RING][1]) == -990
	check(overwritten, "the reload writes local 4 from the save and keeps the cab down")
	check(absf(scene.player.position.y - (before_y - 900.0)) < 2.0, "the second reload keeps Luther on the cab")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.starting_magic.interface_request = true
	var aim: Array = pr.exit_objects["prop:98"][0].position
	look(scene, Vector3(float(aim[0]), float(aim[1]), float(aim[2])))
	await press_e()
	check(int(pr.native.locals.get(4, -1)) == 0, "the lever at the bottom writes local 4 as 0")
	if not check(await ride(scene, -100, -90), "the lever returns the cab to -100 and -90"):
		quit(1)
		return
	check(absf(scene.player.position.y - before_y) < 2.0, "Luther rides the platform back up (y %s)" % scene.player.position.y)
	scene.queue_free()
	await process_frame
	await fresh_boot()
	await birth()
	if failures == 0:
		print("PASS Dawn elevator rides to -1000, a fresh boot keeps the deck under Luther, and the lever brings it back")
	quit(0 if failures == 0 else 1)

func fresh_boot() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 120:
		await process_frame
		if scene.ready_for_review and scene.progression != null and scene.get_node_or_null("L19DawnElevator") != null:
			break
	if not check(scene.ready_for_review and scene.get_node_or_null("L19DawnElevator") != null, "fresh L19 ready"):
		return
	scene.progression.change_scene_enabled = false
	scene.progression.set_physics_process(false)
	scene.set_physics_process(false)
	var pr: Node = scene.progression
	var source: Dictionary = {}
	var bare := true
	for id in CAB:
		source[id] = int(pr.regions[id][1])
		if pr.floor_decks.has(id):
			bare = false
	if not check(bare and int(source[PLATFORM]) == -100 and int(source[RING]) == -90, "a fresh boot has no cab decks and the source floors"):
		return
	if not check(scene._quickload_unrecorded(SAVE).is_empty(), "fresh boot load"):
		return
	var claimed := true
	for id in CAB:
		var native_h: int = int(source[id])
		var height: int = int(pr.regions[id][1])
		if not pr.floor_decks.has(id) or height != native_h - 900:
			claimed = false
			continue
		var deck: Node3D = pr.floor_decks[id] as Node3D
		if int(deck.get_meta("native_floor")) != native_h:
			claimed = false
		if absf(deck.position.y - float(height - native_h)) > 0.01:
			claimed = false
	check(claimed, "the fresh load claims every cab region on the saved floor")
	check(int(pr.native.locals.get(4, -1)) == 1, "the fresh load writes local 4")
	check(absf(scene.player.position.y - (CAB_STAND.y - 900.0)) < 2.0, "the fresh load puts Luther on the saved cab")
	if not pr.floor_decks.has(PLATFORM):
		scene.queue_free()
		await process_frame
		return
	for _i in 2:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var origin := Vector3(CAB_STAND.x, -900.0, CAB_STAND.z)
	var exclude: Array[RID] = [scene.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, -200, 0), 1, exclude))
	var deck_body: Node = (pr.floor_decks[PLATFORM] as Node3D).get_node("Collision")
	var hit_y := -9999.0
	if not hit.is_empty():
		var at: Vector3 = hit.position
		hit_y = at.y
	check(not hit.is_empty() and hit.collider == deck_body and absf(hit_y - (-1000.0)) < 2.0, "the cab collision is the saved platform (y %s)" % hit_y)
	var top := Vector3(CAB_STAND.x, -40.0, CAB_STAND.z)
	var top_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -160, 0), 1, exclude))
	var top_y := -9999.0
	if not top_hit.is_empty():
		var top_at: Vector3 = top_hit.position
		top_y = top_at.y
	check(top_hit.is_empty() or top_y < -200.0, "the source cab floor is gone (y %s)" % top_y)
	scene.player.position = Vector3(CAB_STAND.x, CAB_STAND.y - 900.0, CAB_STAND.z)
	scene.player.velocity = Vector3.ZERO
	scene.starting_magic.interface_request = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(true)
	for _i in 45:
		await physics_frame
	var floor_y := float(pr.regions[PLATFORM][1])
	check(scene.player.is_on_floor() and absf(scene.player.position.y - (floor_y + 32.0)) < 6.0, "Luther stands on the lowered cab (y %s floor %s)" % [scene.player.position.y, floor_y])
	scene.queue_free()
	await process_frame

func birth() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 120:
		await process_frame
		if scene.ready_for_review and scene.progression != null:
			break
	if not check(scene.ready_for_review, "L20 ready"):
		return
	var dawn: Node = scene.get_node("L20MotherCurse")
	check(dawn.DOOR == -1 and not dawn.relocates_player(), "the mother door stays unbound")
	var commands: Array = scene.progression.native.groups["s1:770"]
	var pose: PackedByteArray = PackedByteArray()
	for raw in commands:
		var command: Dictionary = raw
		if int(command.opcode) == 18:
			pose = command.bytes
	var words: bool = pose.size() >= 14 and int(pose[1]) == 1 and pose.decode_u16(2) == 0 and pose.decode_s16(4) == -1382 and pose.decode_s16(6) == 3213 and pose.decode_u16(10) == 0x0085 and pose.decode_u16(12) == 0x4000
	check(words, "group 770 stores the opcode 18 birth pose")
	scene.player.set_physics_process(false)
	var spot: Vector3 = scene.player.position
	scene.player.rotation.y = 0.2
	scene.progression.native.set_field("prop:87", "byte_0x25", 13)
	var results: Array = scene.progression.fire("prop:87", 6, {"caller_byte": 20, "context": "prop:87"})
	var ran: bool = false
	for raw in results:
		var row: Dictionary = raw
		if int(row.group) == 770 and str(row.status) == "ran":
			ran = true
	var yaw: float = -TAU * float(0x4000) / 65536.0
	var posed: bool = absf(scene.player.position.x - (-1382.0)) < 0.1 and absf(scene.player.position.z - (-3213.0)) < 0.1 and absf(scene.player.position.y - spot.y) < 0.1
	posed = posed and absf(angle_difference(scene.player.rotation.y, yaw)) < 0.001
	check(ran and posed, "group 770 runs and the consumer keeps height at (-1382, %s, -3213), now %s" % [spot.y, scene.player.position])
	check(dawn.birth_plays == 1 and not dawn.birth_reel_started, "movie 65 bb_brth is requested and the reel is not staged")
	dawn.skip_birth()
	var creatures: Node = scene.act2_creatures
	creatures.State.spawn(creatures.state, "46")
	creatures.present()
	var hp: int = int(creatures.state.actors["46"].health)
	var killed: bool = creatures.receive_damage("46", hp, true)
	var fired: bool = false
	for raw2 in scene.progression.route_log:
		var logged: Dictionary = raw2
		if str(logged.get("object", "")) != "actor:46" or int(logged.get("event", -1)) != 6:
			continue
		for item in logged.get("results", []):
			var result: Dictionary = item
			if int(result.get("group", -1)) == 12398 and str(result.get("status", "")) == "ran":
				fired = true
	check(killed and int(creatures.state.actors["46"].health) == 0 and fired, "a killing blow on actor 46 runs group 12398")
	scene.queue_free()
	await process_frame
