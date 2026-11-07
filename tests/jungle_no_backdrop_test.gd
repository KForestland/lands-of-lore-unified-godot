extends SceneTree
## Owner r12h 2026-10-26 ("like the wall is a glass that can hide other texture behind it only showing skybox"): the
## Jungle draws no backdrop faces. Clear texels and wall backs are transparent (alpha scissor / one-sided walls), so the
## geometry behind them shows; the panorama is only the sky background. Edge fills and one-sided walls stay on.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_no_backdrop: ", message); quit(1)

func _backdrop_faces(node: Node) -> int:
	var found := 0
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(surface)
			if mat is ShaderMaterial and mat.shader != null and mat.shader.resource_path.ends_with("backdrop.gdshader"): found += 1
	for child in node.get_children(): found += _backdrop_faces(child)
	return found

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	if scene.backdrop_edges or scene.backdrop_material != null: return fail("Backdrop is still enabled in the Jungle")
	if scene.find_child("Backdrop", true, false) != null: return fail("Backdrop mesh is still built")
	var painted := _backdrop_faces(scene)
	if painted != 0: return fail("%d surfaces still use backdrop.gdshader" % painted)
	if not scene.one_sided_walls or not scene.fill_untextured_edges: return fail("One-sided walls or edge fills were switched off")
	# Interior spans are drawn two-sided (one-sided step faces left sky cracks along slope seams, owner 12-17/12-18); only the
	# flat-black imp-pit material stays one-sided among spans.
	if scene.ONE_SIDED_SPAN_MATERIALS != ["744"]: return fail("Unexpected one-sided span materials %s" % [scene.ONE_SIDED_SPAN_MATERIALS])
	var cutouts := 0
	for key in scene.materials:
		var mat = scene.materials[key]
		if mat is StandardMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: cutouts += 1
		elif mat is StandardMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return fail("Material %s blends instead of cutting out" % key)
	if cutouts == 0: return fail("No alpha-scissor cut-out materials found")
	print("PASS jungle_no_backdrop: no backdrop faces; %d cut-out materials alpha-scissor; boundary walls one-sided, spans two-sided, edge fills kept" % cutouts)
	quit(0)
