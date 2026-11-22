extends SceneTree
## Owner r17 16-25-58. Walk the corridor in front of the Draracle. The leaves stop the walk, and the use opens them.
const Door := preload("res://scripts/lol2/cave_draracle_door.gd")
const START_Y := 17690.0
const DOOR_Y := 17735.0
const THROUGH_Y := 17760.0
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL door: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func native_of(cave: Node, world: Vector3) -> Vector3:
	var shift: Vector3 = cave.get("native_translation")
	return Vector3(world.x - shift.x, world.y - shift.y, shift.z - world.z)

func place(cave: Node, player: CharacterBody3D, native_y: float) -> void:
	var shift: Vector3 = cave.get("native_translation")
	player.global_position = Vector3(-62.0 + shift.x, -295.0 + shift.y + 32.0, -native_y + shift.z)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var cam: Camera3D = cave.get("camera")
	if cam != null:
		cam.rotation = Vector3.ZERO

func hit_leaf(player: CharacterBody3D) -> bool:
	for i in player.get_slide_collision_count():
		var hit: KinematicCollision3D = player.get_slide_collision(i)
		var collider: Object = hit.get_collider()
		if collider is Node and (collider as Node).is_in_group("draracle_leaf"):
			return true
	return false

func leaf_ahead(player: CharacterBody3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0.0, 0.0, -40.0), 256)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.collider
	return collider is Node and (collider as Node).is_in_group("draracle_leaf")

func run() -> void:
	var cave: Node = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for _i in 1500:
		await process_frame
		if bool(cave.get("walkthrough_ready")):
			break
	if not check(bool(cave.get("walkthrough_ready")), "cave ready"):
		quit(1)
		return
	var door: Node = cave.get_node_or_null("CaveDraracleDoor")
	if not check(door != null, "door hosted"):
		quit(1)
		return
	var magic: Node = cave.get("starting_magic")
	if magic != null:
		magic.set("interface_request", true)
	cave.set_physics_process(false)
	var player: CharacterBody3D = cave.get("player") as CharacterBody3D
	player.set_physics_process(false)
	place(cave, player, START_Y)
	if not check(int(door.get("travel")) == 0, "door starts closed"):
		quit(1)
		return
	var reached := false
	var blocked := false
	var farthest := START_Y
	for _tick in 150:
		await physics_frame
		player.velocity = Vector3(0.0, -32.0, -60.0)
		player.move_and_slide()
		var here := native_of(cave, player.global_position)
		if here.z > farthest:
			farthest = here.z
		if here.z >= DOOR_Y:
			break
		if here.z > START_Y + 20.0:
			reached = true
		if reached and hit_leaf(player) and here.z < DOOR_Y:
			blocked = true
			break
	var stopped := native_of(cave, player.global_position)
	if not blocked:
		print("door trace closed player ", stopped, " farthest ", farthest, " travel ", door.get("travel"))
	if not check(blocked and stopped.z < DOOR_Y and stopped.z > START_Y + 20.0, "closed leaves stopped the walk"):
		quit(1)
		return
	place(cave, player, stopped.z)
	var saw := leaf_ahead(player)
	if not saw:
		print("door trace ray missed at ", stopped)
	if not check(saw, "a leaf is in front of the walk"):
		quit(1)
		return
	var opened := bool(door.call("try_use"))
	if not check(opened and int(door.get("travel")) == int(Door.source().full_travel), "use opened both leaves"):
		quit(1)
		return
	var crossed := false
	for _tick in 180:
		await physics_frame
		player.velocity = Vector3(0.0, -32.0, -60.0)
		player.move_and_slide()
		var here := native_of(cave, player.global_position)
		if here.z > THROUGH_Y and here.z < 18000.0:
			crossed = true
			break
	var passed := native_of(cave, player.global_position)
	if not crossed:
		print("door trace open player ", passed, " travel ", door.get("travel"))
	if not check(crossed and passed.z > THROUGH_Y and passed.z < 18000.0, "walk continued through the arch"):
		quit(1)
		return
	print("PASS door: walked the corridor at (-62,-17617), the leaves stopped the walk, and the use opened them")
	quit(0)
