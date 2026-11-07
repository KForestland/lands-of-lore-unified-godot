extends SceneTree
## Owner R19 report 10:51:27 ("the crack in the wall ... should be a crack and not a square"). Production Cave:
## movable 55 (template 50, resource 284) fills the region-1108 doorway with the original crack-cut slab. Checks: the
## slab is drawn (layer 2, cutout indexed material, its texture keeps index-0 crack pixels); the player capsule moving
## from the report pose through the doorway is stopped by the native box (Solid55); a layer-1 aim/LOS ray through the
## doorway centre is not stopped by the slab (the scenic guard stays visible through the crack).
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); print("FAIL cave_crack_movable: ", message); quit(1)
	return ok
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in range(900):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready, "Cave not ready"): return
	var crack = cave.get("crack_movable")
	if not check(crack != null and is_instance_valid(crack.mesh) and is_instance_valid(crack.body), "Movable 55 not hosted"): return
	if not check(crack.mesh.layers == 2 and crack.mesh.mesh.get_faces().size() == 12, "Slab not drawn as two indexed faces"): return
	var material: ShaderMaterial = crack.mesh.material_override
	if not check(bool(material.get_shader_parameter("cutout")), "Slab material is not cutout"): return
	var indices: Image = (material.get_shader_parameter("indices") as Texture2D).get_image()
	var holes := 0
	for y in indices.get_height():
		for x in indices.get_width():
			if indices.get_pixel(x, y).r8 == 0: holes += 1
	if not check(holes > 10000, "Crack opening pixels missing (%d)" % holes): return
	# Report pose (map -162, -7652, body origin h22) walking into the doorway centre.
	cave.curse.set_physics_process(false)
	var centre: Vector3 = crack.body.global_position
	var from: Transform3D = cave.player.global_transform
	from.origin = cave.native_translation + Vector3(-162, 34, -7652)
	var toward := Vector3(centre.x - from.origin.x, 0, centre.z - from.origin.z)
	for i in 3: await physics_frame
	var hit := KinematicCollision3D.new()
	# Region 1332 behind the slab is native bit0: since 2026-10-30 the Cave attaches its region blockers, so the player meets the
	# blocker edge before the slab's own box; either closes the doorway.
	if not check(cave.player.test_move(from, toward * 1.4, hit) and (hit.get_collider() == crack.body or hit.get_collider().name == "RegionBlockers"), "Doorway not closed by the slab (%s)" % [hit.get_collider()]): return
	var eye := from.origin + Vector3(0, 10, 0)
	var ray := PhysicsRayQueryParameters3D.create(eye, centre + toward.normalized() * 30.0, 1, [cave.player.get_rid()])
	var los: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(ray)
	if not check(los.is_empty() or los.collider != crack.body, "Slab blocks layer-1 aim/LOS"): return
	# Owner review picture from the report pose (rotation from the 10:51:27 report), rendered runs only.
	if DisplayServer.get_name() != "headless":
		cave.player.global_position = from.origin
		cave.player.rotation = Vector3(0, 0.0158181674778461, 0)
		cave.camera.rotation = Vector3.ZERO
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://capture")
		root.get_texture().get_image().save_png("user://capture/crack_1051_27.png")
	print("PASS cave_crack_movable: movable 55 slab drawn (layer 2, cutout, %d crack pixels), native box closes the doorway from the 10:51:27 pose, layer-1 view through the crack open" % holes)
	quit(0)
