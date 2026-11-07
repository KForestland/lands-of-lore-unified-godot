extends SceneTree
## Report 09-19-01: the orc movie was a screen overlay the stone prop could not occlude. It is now an indexed billboard on the
## world layer: the producer quantises every frame to the Cave palette; the host draws a layer-2 quad with the indexed sprite shader.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var Orc = preload("res://scripts/lol2/cave_old_orc.gd")
	var src: Dictionary = Orc.load_source()
	check(src.index_frames.size() == src.frames.size() and src.frames.size() == 835, "835 index frames beside the 835 RGB frames (%d/%d)" % [src.index_frames.size(), src.frames.size()])
	check(FileAccess.get_sha256(str(src.index_palette)) == str(src.index_palette_sha256) and str(src.index_palette) == "res://assets/lol2/generated/wall_indices/palette.png", "index frames quantised to the Cave index palette")
	var rgb := Image.load_from_file(str(src.frames[0].file))
	var idx := Image.load_from_file(str(src.index_frames[0].file))
	check(idx.get_format() == Image.FORMAT_L8 and idx.get_size() == rgb.get_size(), "index frame 0 is an L8 image of the frame's size")
	var mismatches := 0
	for y in range(0, idx.get_height(), 7):
		for x in range(0, idx.get_width(), 7):
			var transparent := rgb.get_pixel(x, y).a == 0.0
			var zero := idx.get_pixel(x, y).r == 0.0
			if transparent != zero: mismatches += 1
	check(mismatches == 0, "index 0 exactly where the cut-out frame is transparent (%d mismatches)" % mismatches)
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in 20: await process_frame
	var orc = scene.get("old_orc")
	check(orc != null and orc.picture is MeshInstance3D and orc.picture.layers == 2, "the orc picture is a MeshInstance3D on the world layer")
	if orc != null and orc.picture is MeshInstance3D:
		var material: ShaderMaterial = orc.picture.material_override
		check(material != null and material.shader == load("res://scripts/lol2/indexed_surface_review.gdshader") and bool(material.get_shader_parameter("sprite")), "the quad uses the indexed sprite shader")
		check(orc.picture.position == orc.anchor() and not orc.picture.visible, "the quad stands at the orc's anchor and is hidden until the region entry")
		check(scene.find_child("OldOrcPicture", true, false) == orc.picture and orc.get_node_or_null("CanvasLayer") == null, "no screen overlay remains")
	scene.queue_free(); await process_frame
	print("Cave old orc billboard: %d failures" % failures)
	if failures == 0: print("PASS cave old orc billboard: 835 palette-indexed frames, world-layer quad with the indexed sprite shader at the anchor")
	quit(0 if failures == 0 else 1)
