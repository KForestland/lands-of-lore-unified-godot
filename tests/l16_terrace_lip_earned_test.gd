extends SceneTree
## The reported stall is the region 4959 quad. Stand on the floor-30 bank in front of it and walk
## onto region 4971. The drawn quad stays in the mesh; the body climbs the prism.
const START := Vector3(-4847.4, 62.0, 15667.3)
const GOAL := Vector3(-4753.0, 127.0, 15567.4)

var scene: Node

func check(ok: bool, m: String) -> void:
	if not ok:
		push_error(m)
		print("FAIL ", m)
		return

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not scene.ready_for_review:
		check(false, "L16 not ready")
		quit(1)
		return
	var lips: Node = scene.get_node("L16TerraceLips")
	check(lips.get_child_count() == 10, "ten prisms on the map")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var faces: Array = pack["faces"]
	var drawn := -1
	for i in faces.size():
		var face: Dictionary = faces[i]
		if str(face.get("kind", "")) == "floor" and int(face.get("region", -1)) == 4959:
			drawn = i
			break
	check(drawn >= 0 and not scene.excluded_faces.has(drawn), "region 4959 floor stays drawn")
	check(not scene.include_collision_face(faces[drawn]), "region 4959 floor leaves the collision mesh")
	var player: CharacterBody3D = scene.player
	player.position = START
	player.velocity = Vector3.ZERO
	for _settle in 30:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	var reached := false
	for tick in 600:
		var d := GOAL - player.position
		d.y = 0.0
		if d.length() < 8.0 and player.is_on_floor() and player.position.y > 110.0:
			reached = true
			break
		scene.move_grounded(d.normalized(), 1.0 / 60.0)
		await physics_frame
		if tick % 120 == 0:
			print("LIP ", player.position, " region ", scene.progression.region_at(player.position))
	var region := int(scene.progression.region_at(player.position))
	check(reached and region == 4971 and scene.resets == 0, "onto region 4971 at %s region %s resets %s" % [player.position, str(region), str(scene.resets)])
	if reached and region == 4971 and scene.resets == 0:
		print("PASS l16 terrace lip: walked the region 4959 link onto region 4971")
		quit(0)
	else:
		quit(1)
