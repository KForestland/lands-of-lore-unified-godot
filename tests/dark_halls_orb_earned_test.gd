extends SceneTree
## Hintbook: the dome spawns ghosts. Walk in, the orb rises, the pulls bring ten shades, and the pit floor comes up.
var scene: Node
var orb: Node
var player: CharacterBody3D

func _initialize() -> void:
	run.call_deferred()

func miss(label: String) -> void:
	print("FAIL orb: ", label)
	quit(1)

func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for _i in 1500:
		await process_frame
		if current_scene != null and bool(current_scene.get("ready_for_review")) and current_scene.get_node_or_null("DarkHallsOrb") != null:
			break
	scene = current_scene
	if scene == null or not bool(scene.get("ready_for_review")):
		return miss("Dark Halls not ready")
	orb = scene.get_node("DarkHallsOrb")
	player = scene.get("player") as CharacterBody3D
	if player == null:
		return miss("player missing")
	if bool(orb.get("entered")):
		return miss("the orb had already risen")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for node_name in ["DarkHallsCreatures", "DarkHallsRoute"]:
		var extra := scene.get_node_or_null(node_name)
		if extra != null:
			extra.set_physics_process(false)
			extra.set_process(false)
			for body in extra.find_children("", "CollisionObject3D", true, false):
				(body as CollisionObject3D).collision_layer = 0
				(body as CollisionObject3D).collision_mask = 0
	player.global_position = Vector3(-1350.0, 782.0, -180.0)
	player.velocity = Vector3.ZERO
	var spot := Vector3(-1480.0, 782.0, -180.0)
	for _tick in 80:
		var step := spot - player.global_position
		step.y = 0.0
		if step.length() < 2.0:
			break
		player.velocity = step.normalized() * 120.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	for _i in 5:
		await physics_frame
	if not bool(orb.get("entered")):
		return miss("the walk did not enter region 1596 at %s" % player.global_position)
	var risen: Vector3 = (orb.get("orb_node") as Node3D).position
	if absf(risen.y - 900.0) > 1.0:
		return miss("the orb stayed at %s" % risen)
	if int(orb.get("orb_state")) != 0:
		return miss("entry changed the orb state")
	var home := _actor_at("58")
	for _pull in 10:
		if not bool(orb.call("expire_timer", 1)):
			return miss("timer 1 stopped at state %s" % orb.get("orb_state"))
		if not bool(orb.call("raise_kind6", "orb", 3)):
			return miss("value 3 did not pull at state %s" % orb.get("orb_state"))
	var shade := _actor_at("67")
	if shade.distance_to(Vector3(-2158.0, 370.0, -213.0)) > 1.0:
		return miss("shade 67 was not pulled (%s)" % shade)
	if _actor_at("58").distance_to(home) > 1.0:
		return miss("shade 58 moved")
	if int(orb.get("orb_state")) != 20:
		return miss("ten pulls left state %s" % orb.get("orb_state"))
	if not bool(orb.call("raise_kind6", "orb", 3)) or int(orb.get("orb_state")) != 25:
		return miss("state 20 did not offer the pit")
	if not bool(orb.call("raise_kind6", "orb", 20)):
		return miss("group 2792 did not run")
	if bool(orb.call("raise_kind6", "orb", 20)):
		return miss("the pit rose twice")
	for _i in 250:
		if float(orb.get("pit_y")) >= 739.0:
			break
		await physics_frame
	if float(orb.get("pit_y")) < 739.0:
		return miss("the pit floor stayed at %s" % orb.get("pit_y"))
	var windows := scene.get_node_or_null("DarkHallsWindows")
	if windows != null and bool(windows.call("done")):
		return miss("the window counter ended the orb")
	print("PASS orb: walked into region 1596, the orb rose to 900, ten shades were pulled, and the pit floor rose")
	quit(0)

func _actor_at(id: String) -> Vector3:
	var pop := scene.get_node("DarkHallsCreatures")
	var bodies: Dictionary = pop.get("bodies")
	return (bodies[id] as Node3D).position
