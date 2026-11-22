extends SceneTree
## Owner r12e F10 2026-10-25 11:02 at (3153,-4415): "a big hole in the world". The river gorge (22 regions, floor -500)
## runs under the south bank; its walls rise to 400, so their backs stood above the bank as backdrop. The original
## reaches the gorge only through the waterfall openings (top -10), so the port draws its walls up to -10. Those walls
## also collide only up to that opening, so the undrawn part does not cut the bank. Every other wall is unchanged.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_sunken_clip: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	if not scene.clip_sunken_groups: return fail("Sunken clip is off in the Jungle")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var clips: Dictionary = scene._sunken_clips(data, int(data.interior_audit.get("span_start", data.faces.size() - int(data.interior_audit.span_count))))
	var clipped_walls := 0
	for index in clips:
		if data.faces[index].kind == "wall": clipped_walls += 1
	if clipped_walls != 18: return fail("Expected 18 clipped gorge walls, got %d" % clipped_walls)
	var reported := -1
	for index in clips:
		var face: Dictionary = data.faces[index]
		var region := int(face.region)
		# The gorge ceilings (744 at 400) stay out of the sky. The same quads are drawn at the opening as the black roof.
		if face.kind == "ceiling":
			if region < 3314 or region > 3335 or str(face.get("material", "")) != "744": return fail("Gorge ceiling %d is not the black lid" % index)
			if not scene._clipped(face, float(clips[index])).is_empty(): return fail("Gorge ceiling %d was sliced into the sky" % index)
			var roof: Dictionary = scene._ceiling_at(face, float(clips[index]))
			if not is_equal_approx(scene._highest(roof), -10.0) or not is_equal_approx(scene._lowest(roof), -10.0): return fail("Gorge ceiling %d roof %s" % [index, roof.points])
			continue
		if region < 3314 or region > 3335 or str(face.get("material", "")) != "744": return fail("Clipped a wall outside the gorge: %d" % index)
		if not is_equal_approx(float(clips[index]), -10.0): return fail("Gorge top %s, expected -10" % clips[index])
		if region == 3331 and is_equal_approx(float(face.points[0][2]), -4334.0): reported = index
	if reported < 0: return fail("Reported wall (region3331 at z -4334) not clipped")
	var drawn: Dictionary = scene._clipped(data.faces[reported], -10.0)
	if scene._highest(drawn) != -10.0 or scene._lowest(drawn) != scene._lowest(data.faces[reported]): return fail("Reported wall drawn %s" % [drawn.points])
	var lip := Vector3(drawn.points[2][0], drawn.points[2][1], drawn.points[2][2])
	var kept_lip := false
	for body in scene.find_children("*", "StaticBody3D", true, false):
		for shape_owner in body.get_children():
			if shape_owner is CollisionShape3D and shape_owner.shape is ConcavePolygonShape3D and lip in shape_owner.shape.get_faces(): kept_lip = true
	if not kept_lip: return fail("Gorge wall collision lost its opening lip %s" % lip)
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var bank := PhysicsRayQueryParameters3D.create(Vector3(3105.49, 20.0, -4355.0), Vector3(3105.49, 20.0, -4320.0), 1, [scene.player.get_rid()])
	var bank_hit: Dictionary = space.intersect_ray(bank)
	if not bank_hit.is_empty(): return fail("Hidden wall still crosses the bank at %s" % bank_hit.position)
	var pit := PhysicsRayQueryParameters3D.create(Vector3(3105.49, -80.0, -4355.0), Vector3(3105.49, -80.0, -4320.0), 1, [scene.player.get_rid()])
	var pit_hit: Dictionary = space.intersect_ray(pit)
	if pit_hit.is_empty(): return fail("Gorge wall no longer stops the pit")
	if not is_equal_approx(pit_hit.position.z, -4334.0): return fail("Pit ray hit %s, not the gorge wall" % pit_hit.position)
	print("PASS jungle_sunken_clip: 18 gorge walls drawn up to -10 (region3331 wall %d), collision stops at the opening" % reported)
	quit(0)
