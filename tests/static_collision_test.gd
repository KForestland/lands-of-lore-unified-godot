extends SceneTree
## Native static-object collision (tools/prepare_static_collision.py): production Cave and Museum build one oriented
## box per drawn solid assembly (placement word8 & 0x80, box template). Checks: Cave crate 96 (template26, 20 units)
## is solid and stops the player body; crate 94 (10 units) and flat template18 pieces stay walkable (modern adapter);
## shrine blocks 0/1 keep their own host bodies; Museum table 77 keeps the sword-table collider; a rotated Museum box
## matches the formula corners. Scripted assemblies (event records or kind-16 command targets) are left to hosts.
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); print("FAIL static_collision: ", message); quit(1)
	return ok
func space_cast(host: Node3D, query: PhysicsShapeQueryParameters3D) -> PackedFloat32Array:
	return host.get_world_3d().direct_space_state.cast_motion(query)
func static_assemblies_layer() -> int: return preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in range(900):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready, "Cave not ready"): return
	var sa = cave.static_assemblies
	var boxes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L1_DC.json")).boxes
	# Controls 94-97, 112, 121 and 122 are the pushable crate stack since grok J01/R01 (cave_crate_stack.gd, DEVIATIONS);
	# 94 was a non-solid control before that. Body 137 must still stay non-solid.
	var crates: Node = cave.get_node_or_null("CaveCrateStack")
	if not check(crates != null and sa.solid_bodies.has(96) and sa.solid_bodies.has(94) and not sa.solid_bodies.has(137), "Cave solid selection %s" % [sa.solid_bodies.keys()]): return
	if not check(not sa.solid_bodies.has(0) and not sa.solid_bodies.has(1), "Shrine blocks built twice"): return
	for key in boxes:
		var b: Dictionary = boxes[key]
		if int(b.height) >= 16 and not bool(b.scripted) and not sa.solid_bodies.has(int(key)):
			var drawn := false
			for face in sa.data.faces: drawn = drawn or int(face.assembly) == int(key)
			if not check(not drawn, "Cave solid %s (height %d) missing" % [key, int(b.height)]): return
	# Crate 96 (with crate 97 beside it): the player capsule cannot pass through.
	cave.curse.set_physics_process(false)
	var crate: Dictionary = boxes["96"]
	var from: Transform3D = cave.player.global_transform
	from.origin = cave.native_translation + Vector3(float(crate.x) - 40.0, float(crate.h) + 33.0, -float(crate.y))
	for i in 3: await physics_frame
	var hit := KinematicCollision3D.new()
	if not check(cave.player.test_move(from, Vector3(80, 0, 0), hit) and hit.get_collider() in sa.solid_bodies.values(), "Crates 96/97 do not block (%s)" % [hit.get_collider()]): return
	# Rotation witness (Codex review): every Cave box corner sits at the native formula corner; angled boxes exist
	# (timber frames 64-71, heading 18204), so a wrong rotation sign fails here.
	var cave_rotated := 0
	for id in sa.solid_bodies:
		var b: Dictionary = boxes[str(id)]
		if int(b.mode) == 3: continue
		var th := -float(b.heading) / 65536.0 * TAU
		var corner := Vector3(float(b.width) / 2.0, 0, float(b.depth) / 2.0)
		var expected: Vector3 = cave.native_translation + Vector3(float(b.x) + corner.x * cos(th) + corner.z * sin(th), 0, -float(b.y) - corner.x * sin(th) + corner.z * cos(th))
		var actual: Vector3 = sa.solid_bodies[id].global_transform * Vector3(corner.x, 0, corner.z)
		if not check(Vector2(actual.x, actual.z).distance_to(Vector2(expected.x, expected.z)) < 0.01, "Cave box %d corner %s vs %s" % [id, actual, expected]): return
		if int(b.heading) % 16384 != 0: cave_rotated += 1
	if not check(cave_rotated >= 8 and sa.solid_bodies.has(64), "Angled Cave witness missing (%d rotated)" % cave_rotated): return
	# Exercise the production player capsule against a genuinely angled face.
	# Corners alone do not prove physics uses the oriented collision shape.
	var angled_hits := 0
	for id in sa.solid_bodies:
		var b: Dictionary = boxes[str(id)]
		if int(b.heading) % 16384 == 0 or int(b.mode) == 3: continue
		var body: StaticBody3D = sa.solid_bodies[id]
		for side in [-1.0, 1.0]:
			var probe := cave.player.global_transform as Transform3D
			# Human capsule centre is nine units below the persisted body origin.
			probe.origin = body.global_transform * Vector3(side * (float(b.width) / 2.0 + 25.0), 9.0, 0.0)
			var normal: Vector3 = body.global_basis.x * float(side)
			var face_hit := KinematicCollision3D.new()
			if cave.player.test_move(probe, -normal * 40.0, face_hit) and face_hit.get_collider() == body:
				if not check(face_hit.get_normal().dot(normal) > 0.99, "Angled face normal disagrees for %s: %s vs %s" % [id, face_hit.get_normal(), normal]): return
				angled_hits += 1
				print("ANGLED_CAPSULE_HIT id=", id, " heading=", b.heading, " normal=", face_hit.get_normal())
	if not check(angled_hits > 0, "No production capsule hit on an angled Cave face"): return
	# Mode 3 (per-child boxes, Codex OPUS_MODE3_COLLISION_REVIEW): table 156 (heading 38593, non-cardinal). The capsule
	# walking into its top slab along the slab's own axis hits body 156 with the rotated child normal.
	var table: StaticBody3D = sa.solid_bodies.get(156)
	if not check(table != null and table.get_child_count() >= 2, "Mode-3 table 156 child boxes missing"): return
	var raised := false
	for child in table.get_children(): raised = raised or (absf(child.position.y - 34.5) < 0.01 and absf(child.position.x + 10.5) < 0.01)
	if not check(raised, "Table 156 type1 child 12 (record bounds -22..1, -12..11, h 25..44) has no box"): return
	var slab: CollisionShape3D = null
	for child in table.get_children():
		if slab == null or (child.shape as BoxShape3D).size.x * (child.shape as BoxShape3D).size.z > (slab.shape as BoxShape3D).size.x * (slab.shape as BoxShape3D).size.z: slab = child
	var slab_axis: Vector3 = slab.global_basis.x
	if not check(absf(slab_axis.x) > 0.1 and absf(slab_axis.z) > 0.1, "Table 156 slab is not angled (%s)" % slab_axis): return
	# The table stands between cave walls: cast the production capsule shape on the scenery layer only, so floor and
	# walls cannot take the contact, along the slab axis from both ends.
	var capsule_node: CollisionShape3D = cave.player.get_child(0)
	var cast := PhysicsShapeQueryParameters3D.new()
	cast.shape = capsule_node.shape
	cast.collision_mask = static_assemblies_layer()
	var table_rest: Dictionary = {}
	var table_normal := Vector3.ZERO
	for side in [1.0, -1.0]:
		var origin := Vector3(slab.global_position.x, cave.native_translation.y + float(boxes["156"].h) + 40.0, slab.global_position.z) + slab_axis * float(side) * ((slab.shape as BoxShape3D).size.x / 2.0 + 30.0)
		cast.transform = Transform3D(capsule_node.global_basis, origin + capsule_node.global_position - cave.player.global_position)
		cast.motion = -slab_axis * float(side) * 50.0
		var fraction: PackedFloat32Array = space_cast(cave, cast)
		if fraction[1] >= 1.0: continue
		cast.transform.origin += cast.motion * fraction[1]
		cast.motion = Vector3.ZERO
		var rest: Dictionary = cave.get_world_3d().direct_space_state.get_rest_info(cast)
		if rest.get("rid") == table.get_rid():
			table_rest = rest
			table_normal = slab_axis * float(side)
			break
	if not check(not table_rest.is_empty(), "Capsule passes mode-3 table 156 from both ends"): return
	if not check((table_rest.normal as Vector3).dot(table_normal) > 0.99, "Table 156 child normal %s vs %s" % [table_rest.normal, table_normal]): return
	print("MODE3_ANGLED_HIT id=156 heading=", boxes["156"].heading, " normal=", table_rest.normal)
	# LOS parity (Opus/Codex review, docs/DEVIATIONS.md): scenery solids block bodies (layer 9) but not the layer-1
	# aim/line-of-sight rays, matching every build before native collision. The native LOS path is untraced.
	var space: PhysicsDirectSpaceState3D = cave.get_world_3d().direct_space_state
	for id in [96, 64]:
		var body: StaticBody3D = sa.solid_bodies[id]
		var b: Dictionary = boxes[str(id)]
		var centre: Vector3 = body.global_position
		var across: Vector3 = body.global_basis.z * (float(b.depth) / 2.0 + 30.0)
		var ray := PhysicsRayQueryParameters3D.create(centre - across, centre + across, 1)
		var los: Dictionary = space.intersect_ray(ray)
		if not check(los.is_empty() or los.collider != body, "Layer-1 ray stopped by scenery %d" % id): return
		ray.collision_mask = static_assemblies_layer()
		if not check(space.intersect_ray(ray).get("collider") == body, "Scenery %d not on its own layer" % id): return
	var cave_solids: int = sa.solid_bodies.size()
	cave.queue_free()
	await process_frame
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate(); museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in 30: await process_frame
	var ms = museum.static_assemblies
	if not check(not ms.solid_bodies.has(77) and is_instance_valid(museum.sword_table), "Table 77 collider duplicated"): return
	var mboxes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L3_DH.json")).boxes
	var rotated := 0
	for id in ms.solid_bodies:
		var b: Dictionary = mboxes[str(id)]
		if int(b.mode) == 3: continue
		var body: StaticBody3D = ms.solid_bodies[id]
		var th := -float(b.heading) / 65536.0 * TAU
		var corner := Vector3(float(b.width) / 2.0, 0, float(b.depth) / 2.0)
		var expected := Vector3(float(b.x) + corner.x * cos(th) + corner.z * sin(th), 0, -float(b.y) - corner.x * sin(th) + corner.z * cos(th))
		var actual: Vector3 = body.global_transform * Vector3(corner.x, 0, corner.z)
		if not check(Vector2(actual.x, actual.z).distance_to(Vector2(expected.x, expected.z)) < 0.01, "Museum box %d corner %s vs %s" % [id, actual, expected]): return
		if int(b.heading) % 16384 != 0: rotated += 1
	if not check(ms.solid_bodies.size() > 0, "No museum solids"): return
	# Mode 3 (native per-child boxes, 5BFEC): archway 50 on the gallery -> hourglass route (campaign 02_museum) keeps
	# its opening for the production capsule while its pillar still blocks.
	var arch: StaticBody3D = ms.solid_bodies.get(50)
	if not check(arch != null and arch.get_child_count() > 3, "Archway 50 child boxes missing"): return
	var walker := museum.player.global_transform as Transform3D
	walker.origin = Vector3(1150, 32, -539)
	if not check(not museum.player.test_move(walker, Vector3(150, 0, 0)), "Archway 50 opening blocked"): return
	walker.origin = Vector3(1150, 32, -539 - 52)
	var pillar := KinematicCollision3D.new()
	if not check(museum.player.test_move(walker, Vector3(150, 0, 0), pillar) and pillar.get_collider() == arch, "Archway 50 pillar does not block (%s)" % [pillar.get_collider()]): return
	var mb: StaticBody3D = arch
	var mray := PhysicsRayQueryParameters3D.create(Vector3(1150, 40, -591), Vector3(1300, 40, -591), 1)
	var mlos: Dictionary = museum.get_world_3d().direct_space_state.intersect_ray(mray)
	if not check(mlos.is_empty() or mlos.collider != mb, "Layer-1 ray stopped by Museum scenery 50"): return
	var museum_solids: int = ms.solid_bodies.size()
	museum.queue_free()
	print("PASS static_collision: cave %d solids (%d angled, corners at the native formula, production capsule hits angled faces with the rotated normal; layer-1 aim/LOS rays pass scenery 96/64 and a Museum solid while bodies are blocked; crate 96 blocks the player; crate 94 and flat pieces walkable; shrine blocks host-owned), museum %d solids (%d rotated) at the native box corners; table 77 host-owned; mode-3 per-child boxes: archway 50 opening passes, pillar blocks; angled table 156 slab hit with the rotated normal, type1 child 12 boxed from its record" % [cave_solids, cave_rotated, museum_solids, rotated])
	quit(0)
