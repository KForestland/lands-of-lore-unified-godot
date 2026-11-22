extends SceneTree
## G-05 class B narrow adapter (act2_map _height_boundary_walls, scripts/lol2/height_boundary/L14_HT.json): the east map
## edge of the L14 pocket 3859-3863 is solid at body height (owner F10 06-24-14 walked through 13912 into the void and
## fell), the r36 e3 corridor through region 3890 stays open, and with meta lol2_height_boundary_off the same ray passes
## (red/green in one test). Opens L14 from its F2 playtest start twice. Headless: physics rays only.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const FROM := Vector3(3590, -50, -3560)   # inside region 3859 (floor -80), at body height
const TO := Vector3(3680, -50, -3560)     # east of the map edge (no native region there)
const L9_FROM := Vector3(-3230, 40, -1260)  # inside L9 region 1205 (floor 0), body height
const L9_TO := Vector3(-3170, 40, -1215)    # past its edge 0 (wall 16343), over the pit
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	printerr("FAIL height boundary narrow: ", message)
	quit(1)
func open_l14(off: bool) -> Node:
	return await open_start("act2-l14", off)
func hit_between(scene: Node, from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [scene.player.get_rid()]
	return not (scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()
## sha256 over every trimesh face of the scene's own static bodies except the adapter's (terrain must be byte-identical).
func terrain_hash(scene: Node) -> String:
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256)
	for body in scene.get_children():
		if not body is StaticBody3D or body.name == "HeightBoundaryCollision": continue
		for shape_node in body.get_children():
			if shape_node is CollisionShape3D and (shape_node as CollisionShape3D).shape is ConcavePolygonShape3D:
				ctx.update(((shape_node as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().to_byte_array())
	return ctx.finish().hex_encode()
func open_start(start_id: String, off: bool) -> Node:
	if off: set_meta("lol2_height_boundary_off", true)
	elif has_meta("lol2_height_boundary_off"): remove_meta("lol2_height_boundary_off")
	if is_instance_valid(current_scene): current_scene.queue_free(); current_scene = null
	await process_frame
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == start_id: entry = c
	if entry.is_empty(): return null
	var read: Dictionary = Starts.read(entry)
	if not str(read.error).is_empty(): return null
	load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, read.state, true)
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 10: await physics_frame
	return current_scene
func edge_hit(scene: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(FROM, TO, 1)
	q.exclude = [scene.player.get_rid()]
	return not (scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func run() -> void:
	set_meta("original_game_verified", true)
	var before: Node = await open_l14(true)
	if before == null: return fail("L14 start did not open")
	if not before.height_boundary_keys.is_empty() or before.edge_rule_counts.has("height_boundary"): return fail("meta off still applied the packet")
	var l14_terrain_off := terrain_hash(before)
	if edge_hit(before): return fail("before: something already blocks the ray across 13912 (test no longer red)")
	if hit_between(before, Vector3(2470, -50, -3350), Vector3(2520, -50, -3350)): return fail("before: something already blocks the lower level at 8416")
	var after: Node = await open_l14(false)
	if after == null: return fail("L14 start did not open again")
	var counts: Dictionary = after.edge_rule_counts.get("height_boundary", {})
	if int(counts.get("block_face_keys", 0)) != 8 or int(counts.get("collision_polygons", 0)) != 5: return fail("packet counts %s" % str(counts))
	# The four sill openings into the trench 34/36/38/40 are solid for the player (T14 fix): a ray at sill height 65
	# across the 35 -> 36 opening is blocked.
	if not hit_between(after, Vector3(3285, 65, -3560), Vector3(3310, 65, -3560)): return fail("after: the sill opening 35 -> 36 is not solid")
	# The r36 e3 bands are not applied: region 3890 overlaps r36 at floor -80 there (a real corridor).
	if hit_between(after, Vector3(3310, -50, -3500), Vector3(3270, -50, -3500)): return fail("after: the r36 e3 corridor through region 3890 is blocked")
	if after.get_node_or_null("HeightBoundaryCollision") == null: return fail("L14 adapter body missing")
	# Door 92 east jamb (owner r19g 14-08-18): walls 9490 (792 e1) and 9692 (957 e1) collide; his y 20 path through them is blocked.
	if not hit_between(after, Vector3(2492.8, 40, -3062.4), Vector3(2499.1, 40, -3027.1)): return fail("after: wall 9490 at the door 92 jamb is open")
	if not hit_between(after, Vector3(2499.1, 40, -3027.1), Vector3(2495.7, 40, -2991.3)): return fail("after: wall 9692 at the door 92 jamb is open")
	if terrain_hash(after) != l14_terrain_off: return fail("L14 terrain trimesh changed with the adapter on")
	if not edge_hit(after): return fail("after: the ray crosses the map edge at 13912")
	# 8416 band (region 163 edge 1, lower level): solid below 0, open on upper region 821's floor above it.
	if not hit_between(after, Vector3(2470, -50, -3350), Vector3(2520, -50, -3350)): return fail("after: the lower level crosses 8416 into the void")
	if hit_between(after, Vector3(2470, 30, -3330), Vector3(2520, 30, -3330)): return fail("after: the 8416 band blocks the upper floor")
	# L12: 6181, 7371 in their own body; terrain unchanged.
	var l12_off: Node = await open_start("act2-l12", true)
	if l12_off == null: return fail("L12 start did not open")
	var l12_terrain_off := terrain_hash(l12_off)
	if hit_between(l12_off, Vector3(3335, -920, -14850), Vector3(3335, -920, -14780)): return fail("L12 before: something already blocks the ledge edge at 6947")
	var l12_on: Node = await open_start("act2-l12", false)
	if l12_on == null: return fail("L12 start did not open again")
	if l12_on.height_boundary_keys.size() != 3 or l12_on.get_node_or_null("HeightBoundaryCollision") == null: return fail("L12 adapter keys/body")
	if terrain_hash(l12_on) != l12_terrain_off: return fail("L12 terrain trimesh changed with the adapter on")
	# Ledge region 2419 edge 3 (wall 6947): the drop onto the Melt man ice (robot 7501c30-v1d fall).
	if not hit_between(l12_on, Vector3(3335, -920, -14850), Vector3(3335, -920, -14780)): return fail("L12 after: the ray crosses the ledge edge at 6947")
	# L9 (dragon_level.gd): wall 16343, region 1205 edge 0 into the pit (robot v1.4 fall).
	var l9_off: Node = await open_start("act2-l9", true)
	if l9_off == null: return fail("L9 start did not open")
	if hit_between(l9_off, L9_FROM, L9_TO): return fail("L9 before: something already blocks the ray across 16343")
	var l9_terrain_off := terrain_hash(l9_off)
	var l9_on: Node = await open_start("act2-l9", false)
	if l9_on == null: return fail("L9 start did not open again")
	if l9_on.height_boundary_keys.size() != 1: return fail("L9 packet keys %d" % l9_on.height_boundary_keys.size())
	if l9_on.get_node_or_null("HeightBoundaryCollision") == null: return fail("L9 adapter body missing")
	if not hit_between(l9_on, L9_FROM, L9_TO): return fail("L9 after: the ray crosses 16343")
	if terrain_hash(l9_on) != l9_terrain_off: return fail("L9 terrain trimesh changed with the adapter on")
	print("PASS height boundary narrow: L14 8 edge keys (r36 e3 corridor open, door 92 jamb solid), L12 3 (incl. 6947), L9 1, each in its own body; rays open/solid; terrain trimesh hashes unchanged on L14, L12, L9")
	quit(0)
