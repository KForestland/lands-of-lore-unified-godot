extends SceneTree
## Generic static-assembly renderer: per-map counts, no assembly drawn twice with a feature host, and the Cave crates and
## Museum iron arches visible (render sample difference with the renderer hidden).
const Assemblies := preload("res://scripts/lol2/static_assemblies.gd")
const OWNERS := "res://scripts/lol2/static_assembly_owners.json"
const EXPECT := {"L1_DC": {"drawn": 113, "faces": 614, "owned": 7}, "L3_DH": {"drawn": 92, "faces": 1043, "owned": 26}}
func _initialize() -> void:
	_run.call_deferred()
func fail(message: String) -> void:
	print("FAIL ", message)
	quit(1)
func _visible_change(scene, node: Node3D, pos: Vector3, look: Vector3) -> int:
	scene.player.position = pos
	var d: Vector3 = look - pos
	scene.player.rotation.y = atan2(-d.x, -d.z)
	scene.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	node.visible = false
	if scene.has_method("sync_render_source"):
		for child in node.get_children(): scene.sync_render_source(child)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	node.visible = true
	if scene.has_method("sync_render_source"):
		for child in node.get_children(): scene.sync_render_source(child)
	var changed := 0
	for y in range(0, shown.get_height(), 4):
		for x in range(0, shown.get_width(), 4):
			if not shown.get_pixel(x, y).is_equal_approx(hidden.get_pixel(x, y)): changed += 1
	return changed
func _run() -> void:
	var owners: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OWNERS)).areas
	for area in EXPECT:
		if not Assemblies.assets_ready(area): return fail("static assembly pack missing for " + area)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Assemblies.ROOT + area + "/assemblies.json"))
		var drawn: Dictionary = {}
		var initial := 0
		for face in data.faces:
			if owners[area].owners.has(str(int(face.assembly))): return fail("%s draws host-owned assembly %d" % [area, int(face.assembly)])
			if face.initial:
				initial += 1
				drawn[int(face.assembly)] = true
		if drawn.size() != EXPECT[area].drawn or initial != EXPECT[area].faces or owners[area].owners.size() != EXPECT[area].owned:
			return fail("%s counts drawn=%d faces=%d owned=%d" % [area, drawn.size(), initial, owners[area].owners.size()])
		for key in data.materials:
			if not FileAccess.file_exists(Assemblies.ROOT + area + "/" + key): return fail("%s material image missing %s" % [area, key])
	# Cave: crates (static 94-97, 112, 121, 122) at the owner's 11:01 / 11:15 spot.
	for id in [94, 95, 96, 97, 112, 121, 122]:
		if not (JSON.parse_string(FileAccess.get_file_as_string(Assemblies.ROOT + "L1_DC/assemblies.json")).drawn as Array).has(float(id)): return fail("cave crate %d not drawn" % id)
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 900:
		await process_frame
		if cave.walkthrough_ready: break
	var cave_node: Node3D = cave.get("static_assemblies")
	if cave_node == null: return fail("cave walkthrough did not add static assemblies")
	if cave_node.drawn_face_count() != EXPECT.L1_DC.faces: return fail("cave drew %d faces" % cave_node.drawn_face_count())
	cave.flying = true
	var t: Vector3 = cave.native_translation
	var crates: int = await _visible_change(cave, cave_node, Vector3(500, -185, -12180) + t, Vector3(540, -205, -12300) + t)
	print("STATIC_ASSEMBLIES cave crates changed_samples=%d" % crates)
	if crates < 200: return fail("cave crates not visible")
	cave.free()
	await process_frame
	# Museum: iron lattice arches 83-86 beside the Draracle-wing door (longplay 17:56).
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	await process_frame
	museum.flying = true
	museum.interface_hud.set_cursor(false)
	museum.camera.fov = 75
	var museum_node: Node3D = museum.get("static_assemblies")
	if museum_node == null: return fail("museum walkthrough did not add static assemblies")
	if museum_node.drawn_face_count() != EXPECT.L3_DH.faces: return fail("museum drew %d faces" % museum_node.drawn_face_count())
	var arches: int = await _visible_change(museum, museum_node, Vector3(-4060, 40, -760), Vector3(-4060, 60, -844))
	print("STATIC_ASSEMBLIES museum arches changed_samples=%d" % arches)
	if arches < 200: return fail("museum arches not visible")
	# Mode switch: a stateful assembly (lock78, template36) rebuilds from its other-mode faces.
	museum_node.set_mode(78, 1)
	await process_frame
	if not museum_node.stateful_meshes.has(78) or museum_node.stateful_meshes[78].is_empty(): return fail("set_mode did not rebuild lock78")
	museum.free()
	print("PASS static assemblies: Cave 113 / Museum 92 original assemblies drawn, host-owned ones skipped")
	quit()
