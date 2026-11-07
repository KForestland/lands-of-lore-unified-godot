extends SceneTree
## L8 night shading (lead 2026-10-31, L8_TREE_TOPS_FINDING option A + D, B behind a flag): every static mesh of darker_jungle.tscn
## carries its faces' native sector light in CUSTOM0 and draws through the l8_night shader (sector from CUSTOM0), every prop batch
## carries the rows' sector light as per-instance custom data (shader reads INSTANCE_CUSTOM), every static assembly takes the sector
## of the region its placement stands in (uniform), the mouse pitch is clamped to the panorama's 37.6 degrees, set_night toggles
## option B / off, and the scene meta lol2_l8_night starts the level full-bright (the r12r draw) for comparisons.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func open() -> Node:
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(scene)
	return scene
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = open()
	for i in 600:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review, "L8 ready")
	check(absf(scene.pitch_limit - 0.656) < 0.001 and scene.vertex_light_enabled and scene.night_enabled and not scene.night_fog_only, "option A on, B off, pitch limit 0.656 rad (37.6 deg from the panorama) (%s %s %s)" % [scene.pitch_limit, scene.night_enabled, scene.night_fog_only])
	# Static meshes: CUSTOM0 in the mesh format, a night material reading it.
	var statics := 0; var bad := 0
	for mesh in scene.static_meshes:
		statics += 1
		var custom0: bool = (mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0) != 0
		var m = mesh.material_override
		if not (custom0 and m is ShaderMaterial and int(m.get_shader_parameter("sector_source")) == 0 and bool(m.get_shader_parameter("night_enabled"))): bad += 1
	check(statics > 0 and bad == 0, "%d static meshes carry CUSTOM0 and the night material (bad %d)" % [statics, bad])
	# Prop batches: per-instance sector light (the headless dummy renderer keeps no MultiMesh buffer, so the values are checked by
	# the captures; here the batches must use custom data and draw through the night shader as fixed-Y billboards).
	var placement: Array = scene.prop_placements.get(0, [])
	check(placement.size() == 3 and placement[0].use_custom_data, "prop batches carry per-instance custom data (record 0's batch)")
	var batches := 0; var lit := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("DarkerProps"):
			batches += 1
			var m = child.multimesh.mesh.material
			if m is ShaderMaterial and int(m.get_shader_parameter("sector_source")) == 1 and bool(m.get_shader_parameter("billboard")): lit += 1
	check(batches > 0 and lit == batches, "all %d prop batches draw through the night shader as fixed-Y billboards (%d)" % [batches, lit])
	# Faces: a floor keeps its own sector light; an assembly face (kind movable, no bound light) takes its region's: assembly 114
	# stands in region 3206 (the geometry), assembly 136 in region 682.
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/darker_jungle/area.json"))
	var region_light := {}
	var face114: Dictionary = {}; var face136: Dictionary = {}; var floor_face: Dictionary = {}
	for face in pack.faces:
		if face.kind == "floor" and face.get("region") is float and face.get("sector_light") is Array:
			region_light[int(face.region)] = Color(float(face.sector_light[0]), float(face.sector_light[1]), float(face.sector_light[2]), float(face.sector_light[3]))
			if floor_face.is_empty(): floor_face = face
		if face.kind == "movable" and face.get("placement_kind") == "static_assembly":
			if int(face.get("source_index", -1)) == 114 and face114.is_empty(): face114 = face
			if int(face.get("source_index", -1)) == 136 and face136.is_empty(): face136 = face
	check(not floor_face.is_empty() and scene.static_face_light(floor_face) == region_light[int(floor_face.region)], "a floor face keeps its own sector light")
	# The pack gives assembly faces no region: the host lights them by the region under the face centre (3206 / 682 in the geometry).
	check(not face114.is_empty() and scene.static_face_light(face114) == region_light.get(3206) and not face136.is_empty() and scene.static_face_light(face136) == region_light.get(682), "assembly faces 114 / 136 take the light of regions 3206 / 682 under them (%s / %s)" % [scene.static_face_light(face114) if not face114.is_empty() else null, region_light.get(3206)])
	check(scene.night_region_faces >= 948, "every assembly face (948) and floorless floor was lit by its region (%d)" % scene.night_region_faces)
	# The level's shade rows: row 63 brightest, row 52 (the common ambient) 0.44, row 16 (the darkest sectors) 0.07 of the palette.
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/darker_jungle_sky/shade_rows.json"))
	check(rows.rows.size() == 64 and float(rows.rows[63][1]) > 0.85 and absf(float(rows.rows[52][1]) - 0.44) < 0.05 and float(rows.rows[16][1]) < 0.1 and float(rows.rows[0][1]) < 0.01, "shade_rows.json: 64 rows, row 63 ~0.9, row 52 ~0.44, row 16 < 0.1, row 0 black (%s %s %s)" % [rows.rows[63], rows.rows[52], rows.rows[16]])
	var with_rows := 0
	for m in scene.night_materials: if bool(m.get_shader_parameter("has_rows")) and m.get_shader_parameter("shade_rows") != null: with_rows += 1
	check(with_rows == scene.night_materials.size(), "every night material samples the shade-row lookup (%d/%d)" % [with_rows, scene.night_materials.size()])
	# Option B behind the flag, and off.
	scene.set_night(true, true)
	var fog := 0
	for m in scene.night_materials: if bool(m.get_shader_parameter("fog_only")) and bool(m.get_shader_parameter("night_enabled")): fog += 1
	check(fog == scene.night_materials.size() and scene.night_fog_only, "set_night(true, true) = option B on every night material (%d/%d)" % [fog, scene.night_materials.size()])
	scene.set_night(false, false)
	var off := 0
	for m in scene.night_materials: if not bool(m.get_shader_parameter("night_enabled")): off += 1
	check(off == scene.night_materials.size(), "set_night(false) turns every night material off")
	scene.queue_free(); await process_frame
	set_meta("lol2_l8_night", {"enabled": false})
	var plain = open()
	for i in 600:
		await process_frame
		if plain.ready_for_review: break
	check(plain.ready_for_review and not plain.night_enabled and not has_meta("lol2_l8_night") and not bool(plain.night_materials[0].get_shader_parameter("night_enabled")), "meta lol2_l8_night {enabled: false} starts the level full-bright (the r12r draw)")
	plain.queue_free(); await process_frame
	print("L8 night: %d failures" % failures)
	if failures == 0: print("PASS l8 night: native sector light on every static mesh (CUSTOM0), prop batch (INSTANCE_CUSTOM) and assembly (region sector), fade to black by the original row formula; option B flag; pitch clamped to the panorama's 37.6 degrees")
	quit(0 if failures == 0 else 1)
