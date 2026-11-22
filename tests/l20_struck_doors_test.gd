extends SceneTree
## BK08. A Human with a sword strikes the L20 chase doors.
## Pair 50+51 travels together. Leaves 53, 54, 55, and 99 each travel on their own hit.
const Progression = preload("res://scripts/lol2/act2_progression.gd")
const State = preload("res://scripts/lol2/scripted_creature_state.gd")
const SWORD := "act2:L13_RC:dark_sword"
const DOOR_EAST := Vector3(-4680.0, -18.0, -4851.0)
const DOOR_WEST := Vector3(-4780.0, -18.0, -4851.0)
const GRATE_SOUTH := Vector3(-3554.0, -18.0, -4700.0)
const GRATE_NORTH := Vector3(-3554.0, -18.0, -4780.0)
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func travel_for(scene: Node, id: int, byte: int) -> int:
	var attrs: Dictionary = scene.progression.native.attributes
	var angle: int = int(attrs["movable:%d" % id].angle_word)
	return (angle * byte / 100) & 65535

func place(scene: Node, id: int) -> bool:
	var hinge: Node3D = scene.progression.hinges[id]
	var bounds: AABB = scene.progression.mover_bounds[id]
	var center: Vector3 = hinge.to_global(bounds.get_center())
	for offset in [Vector3(90, 0, 0), Vector3(-90, 0, 0), Vector3(0, 0, 90), Vector3(0, 0, -90)]:
		scene.player.global_position = center + offset
		scene.player.velocity = Vector3.ZERO
		scene.camera.global_position = center + offset + Vector3(0, 8, 0)
		scene.camera.look_at(center, Vector3.UP)
		if scene.progression.aimed_struck() == "movable:%d" % id:
			return true
	return false

func press_strike() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func hammer(scene: Node, id: int, byte: int) -> bool:
	var before: int = int(scene.progression.travel.get(id, 0))
	for _i in 40:
		scene.progression.strike_ref("movable:%d" % id)
		if int(scene.progression.travel.get(id, 0)) != before:
			return int(scene.progression.travel[id]) == travel_for(scene, id, byte)
	return false

func cross(scene: Node, start: Vector3, goal: Vector3) -> bool:
	scene.player.position = start
	scene.player.velocity = Vector3.ZERO
	for _i in 30:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	var prior: Vector3 = scene.player.position
	var stalled := 0
	for _tick in 500:
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < 12.0 and scene.player.is_on_floor():
			return true
		if scene.player.position.distance_to(prior) < 0.05:
			stalled += 1
		else:
			stalled = 0
		if stalled > 30:
			return false
		prior = scene.player.position
		scene.progression.advance_movers(1.0 / 60.0)
		scene.move_grounded(delta.normalized(), 1.0 / 60.0)
		await physics_frame
	return false

func fell_guardian(scene: Node, id: String) -> bool:
	var pop: Node = scene.act2_creatures
	if pop == null or not pop.state.actors.has(id):
		return false
	if not bool(pop.state.actors[id].present):
		State.spawn(pop.state, id)
		pop.present()
	var body: Node3D = pop.bodies[id]
	var stand: Vector3 = body.global_position + Vector3(0.0, 32.0, 70.0)
	scene.player.position = stand
	scene.player.velocity = Vector3.ZERO
	scene.camera.global_position = stand + Vector3(0.0, 24.0, 0.0)
	scene.camera.look_at(body.global_position + Vector3(0.0, 30.0, 0.0), Vector3.UP)
	scene.player_form = 0
	scene.equipped_item = SWORD
	for _i in 400:
		pop.strike_remaining = 0.0
		if not pop.strike():
			continue
		if int(pop.state.actors[id].health) == 0:
			return true
	return int(pop.state.actors[id].health) == 0

func grate_crossed(scene: Node, id: String) -> bool:
	scene.player_form = 0
	scene.equipped_item = SWORD
	if not hammer(scene, 53, 98) or not hammer(scene, 54, 88):
		return false
	for _i in 8:
		scene.progression.advance_movers(0.5)
	if await cross(scene, GRATE_SOUTH, GRATE_NORTH):
		return false
	if not fell_guardian(scene, id):
		return false
	if int(scene.progression.travel.get(52, 0)) != travel_for(scene, 52, 100):
		return false
	for _i in 8:
		scene.progression.advance_movers(0.5)
	return await cross(scene, GRATE_SOUTH, GRATE_NORTH)

func boot(scene: Node) -> void:
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	scene.starting_magic.interface_request = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.progression.change_scene_enabled = false
	scene.player_form = 0
	scene.equipped_item = ""

func run() -> void:
	check(Progression.struck_skipped("control:89") and Progression.struck_skipped("control:91") and Progression.struck_skipped("control:101") and not Progression.struck_skipped("movable:50") and Progression.struck_skipped("movable:77", "L19_BC") and not Progression.struck_skipped("movable:77", "L9_DR") and not Progression.struck_skipped("movable:77"), "bespoke controls stay off the binder")
	check(Progression.validate_struck({"version": 1, "areas": {}}, {}).is_empty(), "an empty struck key is valid")
	check(not Progression.validate_struck({"version": 2, "areas": {}}, {}).is_empty(), "a bad struck key is refused")
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "L20 ready"):
		quit(1)
		return
	boot(scene)
	if not check(not await cross(scene, DOOR_EAST, DOOR_WEST), "the shut pair blocks the doorway"):
		quit(1)
		return
	if not check(not await cross(scene, GRATE_SOUTH, GRATE_NORTH), "the grate blocks before either guardian dies"):
		quit(1)
		return
	var refs: Dictionary = scene.progression.struck_refs
	if not check(refs.has("movable:50") and refs.has("movable:51") and not refs.has("movable:52") and refs.has("movable:53") and refs.has("movable:54") and refs.has("movable:55") and refs.has("movable:99"), "struck set is the six doors"):
		quit(1)
		return
	if not check(place(scene, 50), "the sword can see door 50"):
		quit(1)
		return
	var marks: int = scene.progression.route_log.size()
	await press_strike()
	if not check(scene.progression.route_log.size() == marks and int(scene.progression.travel.get(50, 0)) == 0, "an empty hand does not strike the door"):
		quit(1)
		return
	scene.equipped_item = SWORD
	await press_strike()
	var opened_early: bool = int(scene.progression.travel.get(50, 0)) != 0
	var saw := false
	if scene.progression.route_log.size() > marks:
		var row: Dictionary = scene.progression.route_log[scene.progression.route_log.size() - 1]
		saw = str(row.get("object", "")) == "movable:50" and int(row.get("event", -1)) == 9
	if not check(saw and not opened_early and int(scene.progression.struck_durability["movable:50"]) < 255, "the first sword hit fires kind 9 and leaves the door shut"):
		quit(1)
		return
	if not check(hammer(scene, 50, 100) and int(scene.progression.travel[51]) == travel_for(scene, 51, 100) and int(scene.progression.travel.get(53, 0)) == 0, "door 50 carries 51 open and leaves 53 shut"):
		quit(1)
		return
	var leaf50: AnimatableBody3D = scene.progression.mover_bodies[50]
	var leaf51: AnimatableBody3D = scene.progression.mover_bodies[51]
	if not check(leaf50.collision_layer == 0 and leaf51.collision_layer == 0, "the open bit drops both leaves"):
		quit(1)
		return
	var solid: AnimatableBody3D = scene.progression.mover_bodies[53]
	scene.progression.native.call("set_field", "movable:53", "bit_0x15_0x80", 1)
	scene.progression._on_field("movable:53", "bit_0x15_0x80", 1)
	if not check(solid.collision_layer != 0, "the open bit leaves other L20 movables solid"):
		quit(1)
		return
	var kept_area := str(scene.progression.area_id)
	var other_areas: Array[String] = ["L9_DR", "L14_HT", "L16_CA", "L19_BC"]
	for other_area in other_areas:
		leaf50.collision_layer = 1
		scene.progression.area_id = other_area
		scene.progression._on_field("movable:50", "bit_0x15_0x80", 1)
		if not check(leaf50.collision_layer == 1, "the open bit leaves %s solid" % other_area):
			scene.progression.area_id = kept_area
			quit(1)
			return
	scene.progression.area_id = kept_area
	scene.progression._on_field("movable:50", "bit_0x15_0x80", 1)
	scene.progression._on_field("movable:51", "bit_0x15_0x80", 1)
	if not check(leaf50.collision_layer == 0 and leaf51.collision_layer == 0, "L20 leaves 50 and 51 still drop"):
		quit(1)
		return
	if not check(await cross(scene, DOOR_EAST, DOOR_WEST), "the open pair can be crossed"):
		quit(1)
		return
	var kept50: int = int(scene.progression.travel[50])
	var kept51: int = int(scene.progression.travel[51])
	var worn: int = int(scene.progression.struck_durability["movable:50"])
	scene.equipped_item = ""
	var path := "user://tests/bk08_struck.json"
	if not check(scene.quicksave(path).is_empty(), "struck save"):
		quit(1)
		return
	scene.queue_free()
	await process_frame
	var again: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	again.adapter_exit_seeds = false
	root.add_child(again)
	for _i in 1500:
		await process_frame
		if again.ready_for_review: break
	boot(again)
	if not check(again.ready_for_review and again.quickload(path).is_empty(), "struck reload"):
		quit(1)
		return
	if not check(int(again.progression.travel.get(50, 0)) == kept50 and int(again.progression.travel.get(51, 0)) == kept51 and int(again.progression.struck_durability["movable:50"]) == worn and int(again.progression.travel.get(53, 0)) == 0, "the save keeps the open pair and the shut leaf"):
		quit(1)
		return
	again.equipped_item = SWORD
	if not check(hammer(again, 53, 98) and int(again.progression.travel.get(54, 0)) == 0, "door 53 travels on its own"):
		quit(1)
		return
	if not check(hammer(again, 54, 88), "door 54 travels on its own"):
		quit(1)
		return
	if not check(place(again, 55) and hammer(again, 55, 98) and int(again.progression.travel.get(99, 0)) == 0, "door 55 travels and leaves 99 shut"):
		quit(1)
		return
	if not check(hammer(again, 99, 88) and int(again.progression.travel[50]) == kept50, "door 99 travels and the first pair stays"):
		quit(1)
		return
	again.queue_free()
	await process_frame
	var scotia: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	scotia.adapter_exit_seeds = false
	root.add_child(scotia)
	for _i in 1500:
		await process_frame
		if scotia.ready_for_review: break
	boot(scotia)
	if not check(scotia.ready_for_review and await grate_crossed(scotia, "48"), "actor 48 lifts the grate and the gap can be crossed"):
		quit(1)
		return
	scotia.queue_free()
	await process_frame
	var third: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	third.adapter_exit_seeds = false
	root.add_child(third)
	for _i in 1500:
		await process_frame
		if third.ready_for_review: break
	boot(third)
	if not check(third.ready_for_review and await grate_crossed(third, "47"), "actor 47 lifts the grate and the gap can be crossed"):
		quit(1)
		return
	print("PASS L20 struck doors: pairs 50+51, 53+54, and 55+99 open from a sword")
	quit(0)
