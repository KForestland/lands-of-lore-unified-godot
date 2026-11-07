extends SceneTree
## Actual Hive and Jungle hosts: the scenery owner is set up by hive_review / jungle_walkthrough, its batches are in
## the tree with the right instance totals (666 / 16), nothing of it is saved in the area handoff, and captures at fixed
## vantages (Hive bump/pole clusters and smoke pits; the Jungle village idol, tall tree, pot and sack, and the river fog)
## go to user://tests/ for the visual comparison.
const HIVE_VANTAGES := {"hive_bumps_west": [[-1124, -230, -6088], [-1124, -190, -5900]],
	"hive_smoke_pits": [[1526, 0, -3818], [1526, 20, -3620]], "hive_poles_mid": [[-14, -180, -5723], [-14, -150, -5540]],
	"hive_cat_statues": [[-1132, -215, -5829], [-1000, -190, -5700]]}
const JUNGLE_VANTAGES := {"jungle_village_idol": [[-2024, 40, -4881], [-1880, 60, -4700]],
	"jungle_pot_sack": [[-1620, 10, -4440], [-1500, 40, -4300]], "jungle_fog": [[3095, -150, -3159], [2950, -120, -2980]]}
var failed := false

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	if failed: return
	failed = true; push_error(message); quit(1)

func settle(scene: Node3D) -> bool:
	for i in 600:
		await process_frame
		if scene.ready_for_review: return true
	return false

func capture(scene: Node3D, vantages: Dictionary, prefix: String) -> void:
	scene.set_physics_process(false); scene.flying = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for key in vantages:
		var target: Array = vantages[key][0]; var eye: Array = vantages[key][1]
		scene.player.global_position = Vector3(eye[0], eye[1], eye[2]); scene.player.velocity = Vector3.ZERO
		scene.player.rotation = Vector3.ZERO; scene.camera.rotation = Vector3.ZERO
		scene.camera.look_at(Vector3(target[0], target[1], target[2]), Vector3.UP)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/%s_%s.png" % [prefix, key])

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/tests")
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	if not await settle(hive): return fail("Hive not ready")
	var scenery = hive.scenery
	if scenery == null or scenery.area != "L5_HC" or scenery.instance_count != 666 or scenery.batches.size() != 45: return fail("Hive scenery owner missing or incomplete")
	for node in scenery.batches:
		if not node.is_inside_tree() or node.multimesh.instance_count == 0: return fail("Hive batch %s not in the tree" % node.name)
	# Real renderer: the instance transforms read back at the native positions (the headless state test cannot check this).
	for record in [0, 259, 268, 1]:
		var placed: Array = scenery.placements[record]
		if placed[0].get_instance_transform(placed[1]).origin != placed[2]: return fail("Hive record %d transform differs from its placement" % record)
	if JSON.stringify(hive.area_handoff()).contains("scenery"): return fail("Hive scenery must not be saved")
	await capture(hive, HIVE_VANTAGES, "hive_jungle_scenery")
	hive.queue_free()
	for i in 5: await process_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	if not await settle(jungle): return fail("Jungle not ready")
	scenery = jungle.scenery
	if scenery == null or scenery.area != "L4_HJ" or scenery.instance_count != 16 or scenery.batches.size() != 13: return fail("Jungle scenery owner missing or incomplete")
	if scenery.position_of(510) != Vector3(-2024, 10, -4881): return fail("Jungle idol misplaced")
	if jungle.props == null or jungle.props.placements.has(510) or jungle.props.placements.has(1400): return fail("Jungle idol/pot must come from the scenery pack only")
	if JSON.stringify(jungle.area_handoff()).contains("scenery"): return fail("Jungle scenery must not be saved")
	await capture(jungle, JUNGLE_VANTAGES, "hive_jungle_scenery")
	print("PASS hive_jungle_scenery_live: Hive 666 instances in 45 batches and Jungle 16 in 13, first frame only, not saved; captures in user://tests/hive_jungle_scenery_*.png")
	quit()
