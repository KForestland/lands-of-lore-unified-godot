extends SceneTree
## Owner r12e F10 2026-10-25 11:02 at (3153,-4415): "a big hole in the world". The river gorge (22 regions, floor -500)
## runs under the south bank; its walls rise to 400, so their backs stood above the bank as backdrop. The original
## reaches the gorge only through the waterfall openings (top -10), so the port draws its walls up to -10. Collision
## and every other wall are unchanged.
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
		# The gorge's native ceilings (744 at 400, appended 2026-10-30) are dropped whole: above the top, nothing is left.
		if face.kind == "ceiling":
			if region < 3314 or region > 3335 or not scene._clipped(face, float(clips[index])).is_empty(): return fail("Gorge ceiling %d not dropped" % index)
			continue
		if region < 3314 or region > 3335 or str(face.get("material", "")) != "744": return fail("Clipped a wall outside the gorge: %d" % index)
		if not is_equal_approx(float(clips[index]), -10.0): return fail("Gorge top %s, expected -10" % clips[index])
		if region == 3331 and is_equal_approx(float(face.points[0][2]), -4334.0): reported = index
	if reported < 0: return fail("Reported wall (region3331 at z -4334) not clipped")
	var drawn: Dictionary = scene._clipped(data.faces[reported], -10.0)
	if scene._highest(drawn) != -10.0 or scene._lowest(drawn) != scene._lowest(data.faces[reported]): return fail("Reported wall drawn %s" % [drawn.points])
	var top := Vector3(data.faces[reported].points[2][0], data.faces[reported].points[2][1], data.faces[reported].points[2][2])
	var kept := false
	for body in scene.find_children("*", "StaticBody3D", true, false):
		for shape_owner in body.get_children():
			if shape_owner is CollisionShape3D and shape_owner.shape is ConcavePolygonShape3D and top in shape_owner.shape.get_faces(): kept = true
	if not kept: return fail("Gorge wall collision lost its top %s" % top)
	print("PASS jungle_sunken_clip: 18 gorge walls drawn up to -10 (region3331 wall %d), collision unchanged" % reported)
	quit(0)
