extends SceneTree
## Ordinary native selector0 layers122+123: source pixels, real host copies, pickup rollback.
const Crystal = preload("res://scripts/lol2/cave_stalagmite.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
		print("FAIL cave_stalagmite_layers: ", message)
		quit(1)
	return ok
func run() -> void:
	var base := Image.load_from_file(Crystal.ROOT+"122.png")
	var shard := Image.load_from_file(Crystal.ROOT+"123.png")
	var merged := Crystal.ordinary_layers(base, shard)
	var changed := 0
	for y in base.get_height():
		for x in base.get_width():
			var wanted := shard.get_pixel(x,y) if shard.get_pixel(x,y).r>0 else base.get_pixel(x,y)
			if not check(merged.get_pixel(x,y).is_equal_approx(wanted), "source pixel mismatch"): return
			if not merged.get_pixel(x,y).is_equal_approx(base.get_pixel(x,y)): changed+=1
	if not check(changed>500, "ordinary shard is absent"): return
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene=cave
	for i in range(900):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave not ready"): return
	var mask_shaders := {}
	for pair in cave.occluder_pairs:
		var path: String = pair[1].material_override.shader.resource_path
		mask_shaders[path] = int(mask_shaders.get(path,0)) + 1
	print("CRYSTAL_DEPTH_MASK_SHADERS ", JSON.stringify(mask_shaders))
	var crystals=cave.stalagmites
	for mesh in crystals.plants.values():
		if not check(cave.occluder_by_source[mesh].layers == 4,"crystal mask moved off shared layer"):return
	var initial=crystals.textures[0].get_image()
	if not check(initial.get_data()==merged.get_data(),"host did not use composed original layers"): return
	for record in Crystal.RECORDS:
		var mesh=crystals.plants[record]
		if not check(mesh.material_override.get_shader_parameter("indices")==crystals.textures[0],"initial world texture"):return
		if not check(cave.occluder_by_source[mesh].material_override.get_shader_parameter("indices")==crystals.textures[0],"initial occluder texture"):return
	# Same production restore boundary used by disk saves, including old pre-fix collected IDs.
	crystals.restore([Crystal.item_id(641,1)])
	var spent=crystals.plants[641]
	if not check(spent.material_override.get_shader_parameter("indices").get_image().get_data()==base.get_data(),"collected crystal still has shard"):return
	if not check(cave.occluder_by_source[spent].material_override.get_shader_parameter("indices")==crystals.textures[3],"spent occluder stale"):return
	if not check(crystals.glow.meshes[641].material_override.get_shader_parameter("indices")==crystals.glow.textures[1],"spent glow stale"):return
	crystals.restore([])
	if not check(spent.material_override.get_shader_parameter("indices")==crystals.textures[0],"rollback did not restore shard"):return
	if not check(crystals.glow.meshes[641].material_override.get_shader_parameter("indices")==crystals.glow.textures[0],"glow rollback stale"):return
	if not check(cave.layer_views.size()==10 and cave.composites.size()==10,"missing blend stages"):return
	cave.free()
	print("PASS cave_stalagmite_layers: all source pixels, %d changed pixels, seven world/occlusion owners, legacy collection and rollback" % changed)
	quit(0)
