extends SceneTree
## Phase A L8_SJ (lane l8-map, 2026-10-30): the darker jungle at the Act 1 Jungle standard. Headless: pack contract (every
## rendered source wall, every native ceiling, every floor incl. the 44 floorless collision floors, 1765 props with their frame
## flags), the night panorama pack, the scene (batched flipped props, native solids and blockers always on, the sky pack), and
## a ray onto a floorless floor (region 41, floor 70) that the pack previously left as a hole.
const ROOT := "res://assets/lol2/generated/"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var area: Dictionary = load_json(ROOT + "darker_jungle/area.json")
	var kinds := {}
	var floorless := 0; var flipped := 0; var unresolved := 0
	for face in area.faces:
		kinds[face.kind] = int(kinds.get(face.kind, 0)) + 1
		if face.kind == "floor" and not face.has("material"): floorless += 1
		if str(face.get("material", "")) == "unresolved": unresolved += 1
	check(int(kinds.get("floor", 0)) == 3961 and floorless == 44, "pack floors: 3961 = every region, 44 floorless collision floors (%d, %d)" % [int(kinds.get("floor", 0)), floorless])
	check(int(kinds.get("ceiling", 0)) == 3017, "pack ceilings: 3017 = every region with a native ceiling selector (%d)" % int(kinds.get("ceiling", 0)))
	check(int(kinds.get("source_wall", 0)) == 5101 and unresolved == 0, "pack source walls: 5101 = every record the original renders, all textured (%d, unresolved %d)" % [int(kinds.get("source_wall", 0)), unresolved])
	check(int(kinds.get("movable", 0)) == 948 and int(kinds.get("emulated_boundary", 0)) == 20, "pack movables 948 (911 static assemblies + 37 movables) and 20 emulated boundaries")
	for prop in area.props:
		if int(prop.get("frame_flags", 0)) & 0x40: flipped += 1
	check(area.props.size() == 1765 and flipped == 385, "pack props: 1765 (1631 placements + 134 attached), 385 with the column flip (%d, %d)" % [area.props.size(), flipped])
	check(area.start[0] == -4577 and area.start[2] == 1168, "pack start is the native arrival selector 1")
	var sky: Dictionary = load_json(ROOT + "darker_jungle_sky/environment.json")
	check(sky.area == "L8_SJ" and int(sky.panorama.vertical_origin) == 42 and sky.panorama.pixels_sha256 == "95c77132614990e44633cd6f10a433ef7eaf90db959fe987a1f2057ad77d6f94" and FileAccess.file_exists(ROOT + "darker_jungle_sky/panorama.png"), "night sky pack: backgrnd.pcx, vertical origin 42")
	# Scene.
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(scene)
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review, "darker jungle ready")
	check(scene.prop_instances == 1765 and scene.prop_placements.size() == 1765 and scene.prop_batches > 0 and scene.prop_batches < 400, "props batched: 1765 instances in %d MultiMeshes" % scene.prop_batches)
	var flipped_batches := 0; var plain_batches := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("DarkerProps_"):
			# Since l8-night the batches draw through the night ShaderMaterial (l8_night.gd), which carries the flip as its uv_scale uniform.
			var material: Material = child.multimesh.mesh.material
			var flip_x: float = material.get_shader_parameter("uv_scale").x if material is ShaderMaterial else material.uv1_scale.x
			if flip_x == -1.0: flipped_batches += 1
			else: plain_batches += 1
	check(flipped_batches > 0 and plain_batches > 0, "prop materials: both flipped (0x40) and plain batches (%d, %d)" % [flipped_batches, plain_batches])
	check(scene.preview_assemblies != null and scene.preview_assemblies.solid_bodies.size() == 16 and scene.preview_blockers == 859, "native solids 16 (14 + tree 114 / bridge 116, grok Y02) and 859 blocker edges always on (%d)" % scene.preview_blockers)
	check(scene.get_node_or_null("JungleSkyEnvironment") != null and scene.sky_pack == scene.DARKER_SKY, "the night panorama environment is the scene's sky")
	check(scene.player.position == Vector3(-4577, 32, 1168), "start at the native arrival")
	# Region 41 (selector 255, floor 70, not bit0): a floorless floor the Act 1 rule keeps as collision.
	await physics_frame; await physics_frame
	var from := Vector3(-6419.5, 300.0, -2089.3)
	# Source walls are drawn only (S1 rule; kind "source_wall" since 2026-10-31): the shell's collision triangles are bounded by the
	# non-wall faces (two per quad); until then the darker jungle's 5101 walls collided.
	var shell_triangles := 0
	for child in scene.get_children():
		if child is StaticBody3D and child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D and child.get_child(0).shape is ConcavePolygonShape3D:
			shell_triangles = (child.get_child(0).shape as ConcavePolygonShape3D).get_faces().size() / 3
			break
	var non_wall_faces: int = area.faces.size() - int(kinds.get("source_wall", 0))
	check(shell_triangles > 0 and shell_triangles <= 2 * non_wall_faces, "scene: shell collision %d triangles <= 2 x %d non-wall faces (source walls drawn only)" % [shell_triangles, non_wall_faces])
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 600.0, 1, [scene.player.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y - 70.0) < 1.0, "floorless region 41 collides at its native floor 70 (%s)" % [hit.position.y if not hit.is_empty() else "no hit"])
	# Control: the arrival floor (region 2359, floor 0) under the start.
	var control := PhysicsRayQueryParameters3D.create(Vector3(-4577, 60, 1168), Vector3(-4577, -300, 1168), 1, [scene.player.get_rid()])  # below the 100 ceiling
	var control_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(control)
	check(not control_hit.is_empty() and absf(control_hit.position.y) < 1.0, "control: the arrival floor collides at 0 (%s)" % [control_hit.position.y if not control_hit.is_empty() else "no hit"])
	scene.queue_free()
	for i in 3: await process_frame
	print("L8 map: %d failures" % failures)
	if failures == 0: print("PASS l8 map: pack 3961 floors (44 floorless) / 3017 ceilings / 5101 source walls / 948 movables / 1765 props (385 flipped); night sky; batched flipped props, 14 solids + 859 blockers always on, floorless collision")
	quit(0 if failures == 0 else 1)
