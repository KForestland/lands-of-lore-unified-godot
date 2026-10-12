extends SceneTree
## Render both camera sides using actual RGB/indexed material factories.
const RGB = preload("res://scripts/lol2/all_maps_review.gd")
const Indexed = preload("res://scripts/lol2/all_maps_indexed_review.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var index_image := Image.create(1, 1, false, Image.FORMAT_R8)
	index_image.fill(Color(10.0 / 255.0, 0, 0))
	index_image.save_png("/tmp/map_front_index.png")
	for indexed in [false, true]:
		var factory = Indexed.new() if indexed else RGB.new()
		factory.current_area = {"front_face_materials": ["structural"], "indexed_materials": {"structural": "/tmp/map_front_index.png", "assembly": "/tmp/map_front_index.png"}}
		if indexed:
			factory.primed_contract = {"indexed_materials": factory.current_area.indexed_materials}
		for one_sided in [false, true]:
			var id := "structural" if one_sided else "assembly"
			var material: Material = factory._make_indexed_material(id, false, 0, 0) if indexed else factory._new_base_material(id)
			var view := SubViewport.new()
			view.size = Vector2i(32, 32)
			view.own_world_3d = true
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			var instance := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(2, 2)
			mesh.material = material
			instance.mesh = mesh
			view.add_child(instance)
			var cam := Camera3D.new()
			cam.cull_mask = 1
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 2
			cam.environment = Environment.new()
			cam.environment.background_mode = Environment.BG_COLOR
			cam.environment.background_color = Color.BLACK
			view.add_child(cam)
			cam.current = true
			for front in [true, false]:
				cam.position = Vector3(0, 0, 2 if front else -2)
				cam.look_at(Vector3.ZERO)
				for frame in 4:
					await process_frame
				var pixel := view.get_texture().get_image().get_pixel(16, 16)
				var visible := pixel.r + pixel.g + pixel.b > 0.1
				var expected: bool = front or not one_sided
				print("front test indexed=%s structural=%s front=%s visible=%s expected=%s" % [indexed, one_sided, front, visible, expected])
				if visible != expected:
					failures += 1
			view.queue_free()
			await process_frame
		factory.free()
	print("Structural front render tests: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
