extends SceneTree
## Component contract only. Earned traversal and visual comparison are separate acceptance gates.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message)
	print("FAIL dark_halls_slides: ", message)
	quit(1)
## Refined source evidence: template22 modes1/2 have identical bounds and different cutout faces.
## Verify the original texture/alpha selection rather than requiring the superseded invented panel translation.
func visual(slides: Node3D, id: String, opened: bool) -> bool:
	var panel: Node3D = slides.panels[id]
	if panel.position != Vector3.ZERO: return false
	var expected: Image = slides.variant_textures["368" if opened else "367"].get_image()
	var count := 0
	for mesh: MeshInstance3D in panel.get_children():
		if int(mesh.get_meta("source_face")) not in [2, 3]: continue
		count += 1
		var material: StandardMaterial3D = mesh.material_override
		if material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return false
		if material.albedo_texture.get_image().get_data() != expected.get_data(): return false
	return count == 2

func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene: Node = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("scene not ready")
	var slides: Node3D = scene.slides
	if slides.panels.size() != 6: return fail("six panels missing")
	for id in slides.panels:
		if slides.is_open(id): return fail("initially open " + id)
		if not slides.use(id) or not slides.is_open(id): return fail("open " + id)
		if not visual(slides, id, true): return fail("native open cutout not selected " + id)
		if slides.sound_log[-1] != 631: return fail("opening sound " + id)
		if not slides.use(id) or slides.is_open(id): return fail("close " + id)
		if slides.sound_log[-1] != 630: return fail("closing sound " + id)
		if not visual(slides, id, false): return fail("panel not restored " + id)
	if slides.use("999"): return fail("unknown control accepted")
	if slides.validate({"1041": 1}).is_empty(): return fail("non-boolean save accepted")
	if slides.validate({"999": true}).is_empty(): return fail("unknown saved control accepted")
	slides.use("1041")
	var path := "user://tests/dark_halls_slides.json"
	if not scene.quicksave(path).is_empty(): return fail("save")
	slides.use("1041")
	var saved: Dictionary = preload("res://scripts/lol2/jungle_save.gd").read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail(str(saved.error))
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty() or not slides.is_open("1041") or not visual(slides, "1041", true): return fail("restore: " + error)
	print("PASS dark_halls_slides: six native open/close pairs, original cutout variants, sounds, strict saved keys, disk rollback; component proof only")
	quit(0)
