extends SceneTree
## T3 save carry (geometry_move.gd inside_original; lead questions 2026-11-13 after Grok's direct test).
## (a) The owner's own save 01-16-21 (taken on r19f before the move): the tracker named the tunnel region 2529, but his feet
##     were at 74, on top of the tunnel inside the wooden room's space. It must NOT be carried down (that put him between
##     the room floor and the lowered tunnel's ceiling - Grok's black void): he stays in the room (feet >= -2, tracked in
##     a region of the room side, not the tunnel).
## (b) The same save moved INTO the tunnel (2535 at (1214, -5082), feet on its original floor 0) is carried to the
##     lowered floor (feet about -85) and tracked in 2535.
const FIXTURE := "res://tests/fixtures/l14_owner_tunnel_save_011621.json"
const TUNNEL := [2520, 2521, 2522, 2523, 2524, 2525, 2526, 2527, 2528, 2529, 2530, 2531, 2532, 2533, 2534, 2535, 2536,
		2537, 2538, 2539, 2540, 2542, 2543, 2545]
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l14 tunnel save carry: ", m)
	quit(1)
func load_doc(doc: Dictionary) -> Node:
	var path := ProjectSettings.globalize_path("user://tests/l14_tunnel_save_carry.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(doc, "", false, true)); f.close()   # full precision: a clock saved at its exact maximum must round-trip
	var old := current_scene
	var err: String = load("res://scripts/lol2/game_save.gd").load_file(self, path)
	if not err.is_empty(): printerr("load: ", err); return null
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 30: await physics_frame
	return current_scene
func run() -> void:
	set_meta("original_game_verified", true)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var scene: Node = await load_doc(doc.duplicate(true))
	if scene == null: return fail("(a) owner save did not load")
	if not str(scene.geometry_file).ends_with("area_moved.json"): return fail("moved pack not loaded")
	var pa: Vector3 = scene.player.global_position
	var ta: int = int(scene.tracked_region)
	if pa.y - 32.0 < -2.0: return fail("(a) owner save carried down: feet %.1f at %s" % [pa.y - 32.0, str(pa)])
	if ta in TUNNEL: return fail("(a) owner save still tracked in tunnel region %d" % ta)
	# (b) the same save, standing inside the tunnel on its original floor
	var inside: Dictionary = doc.duplicate(true)
	inside.area_save.player.position = [1214.0, 32.0, -5082.0]
	inside.area_save.player.region = 2535
	inside.area_save.player.erase("geometry_move")
	scene = await load_doc(inside)
	if scene == null: return fail("(b) tunnel save did not load")
	var pb: Vector3 = scene.player.global_position
	if absf(pb.y - 32.0 - (-85.0)) > 6.0: return fail("(b) tunnel save not carried to the lowered floor: feet %.1f" % (pb.y - 32.0))
	if int(scene.tracked_region) != 2535: return fail("(b) tunnel save tracked in %d, not 2535" % int(scene.tracked_region))
	print("PASS l14 tunnel save carry: owner 01-16-21 stays in the room (feet %.1f, region %d); a save inside the tunnel is carried (feet %.1f, region 2535)" % [pa.y - 32.0, ta, pb.y - 32.0])
	quit(0)
