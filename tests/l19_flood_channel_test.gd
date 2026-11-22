extends SceneTree
## BK15. Three shots on switches 74, 75, and 76 fire the flood. The Human then
## walks the raised channel from region 104 through the region 133 mouth.
const FormBody := preload("res://scripts/lol2/player_form_body.gd")
const BLUE := "act2:L12_CM:blue_bow"
const STAND := Vector3(500.0, -13.0, -2082.0)
const GOAL := Vector3(720.0, -13.0, -2082.0)
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func ray_up(scene: Node, at: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var exclude: Array[RID] = [scene.player.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 160.0, 1, exclude)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return INF
	return float(hit.position.y)

func run() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 180:
		await process_frame
		if scene.ready_for_review and scene.progression != null:
			break
	if not check(scene.ready_for_review and scene.get_node_or_null("L19SewerForms") != null, "L19 ready"):
		quit(1)
		return
	var forms: Node = scene.get_node("L19SewerForms")
	scene.player_form = 0
	FormBody.apply(scene.player, scene.camera, 0, false)
	var collider := scene.player.get_child(0) as CollisionShape3D
	var capsule := collider.shape as CapsuleShape3D
	check(capsule != null and is_equal_approx(capsule.height, 46.0) and is_equal_approx(capsule.radius, 15.0), "Human capsule is height 46 radius 15")
	check(int(scene.progression.regions[133][1]) == -95, "region 133 starts at -95")
	check(int(scene.progression.regions[100][1]) == -85, "region 100 starts at -85")
	check(int(scene.progression.regions[103][1]) == -55, "region 103 starts at -55")
	check(scene.liquid_drowning.region_at(Vector3(651.0, -13.0, -2081.0)).is_empty(), "the channel mouth is not a liquid region")
	scene.carried_collected.append(BLUE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.starting_magic.interface_request = true
	if not check(scene.set_equipped_item(BLUE), "the blue bow equips"):
		quit(1)
		return
	for id in [74, 75, 76]:
		if not check(forms.shoot_switch(int(id), 15), "switch %d fires caller 15" % int(id)):
			quit(1)
			return
	var flooded := false
	for _step in 80:
		scene.progression.advance_floors(1.0)
		if int(scene.progression.regions[133][1]) == -45 and int(scene.progression.regions[100][1]) == -45:
			flooded = true
			break
	if not check(flooded, "regions 100 and 133 rise to -45"):
		quit(1)
		return
	check(int(scene.progression.regions[103][1]) == -45, "region 103 rises to -45")
	var deck133: Node3D = scene.progression.get_node_or_null("FloorMotions/Floor133")
	var deck100: Node3D = scene.progression.get_node_or_null("FloorMotions/Floor100")
	check(deck133 != null and is_equal_approx(deck133.position.y, 50.0), "region 133 deck offset is 50")
	check(deck100 != null and is_equal_approx(deck100.position.y, 40.0), "region 100 deck offset is 40")
	check(scene.progression.get_node_or_null("FloorMotions/Floor40") == null, "region 40 stays in the static mesh")
	if is_instance_valid(scene.act2_creatures):
		scene.act2_creatures.queue_free()
		await process_frame
	print("TELEPORT channel")
	scene.player.position = STAND
	scene.player.velocity = Vector3.ZERO
	scene.set_physics_process(false)
	for _i in 20:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	var reached := false
	var stuck := 0
	var last_x: float = scene.player.position.x
	for _tick in 900:
		var toward: Vector3 = GOAL - scene.player.position
		toward.y = 0.0
		if toward.length() < 8.0 and scene.player.position.x > 700.0:
			reached = true
			break
		var step: Vector3 = toward.normalized() if toward.length() > 0.1 else Vector3.ZERO
		scene.move_grounded(step, 1.0 / 60.0)
		await physics_frame
		if scene.resets != 0:
			break
		if scene.player.position.x < last_x + 0.05:
			stuck += 1
		else:
			stuck = 0
			last_x = scene.player.position.x
		if stuck > 90:
			break
	print("CHANNEL at ", scene.player.position, " resets ", scene.resets, " on_floor ", scene.player.is_on_floor())
	var mouth := ray_up(scene, Vector3(700.0, -30.0, -2082.0))
	var stair := ray_up(scene, Vector3(640.0, -30.0, -2082.0))
	print("CEILING mouth ", mouth, " stair ", stair)
	check(reached and scene.resets == 0, "the Human walks through the raised channel (x %.1f y %.1f z %.1f)" % [scene.player.position.x, scene.player.position.y, scene.player.position.z])
	check(absf(scene.player.position.y - STAND.y) < 8.0, "the body stays on the deck (y %.1f)" % scene.player.position.y)
	check(absf(mouth - 45.0) < 4.0, "region 133 ceiling rides to about 45 (hit %.1f)" % mouth)
	check(absf(stair - 55.0) < 4.0, "region 100 ceiling stays at about 55 (hit %.1f)" % stair)
	if failures == 0:
		print("PASS L19 flood channel: three shots raise the deck and the Human walks through region 133")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
