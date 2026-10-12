extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var nest = scene.get_node("Nest")
	assert(not nest.present_executioner({"pose":0}).is_empty())
	nest.show_actor()
	var base_size: Vector2 = nest.actor.mesh.size
	var base_center: Vector3 = nest.actor.mesh.center_offset
	for pose in [0,2,11,12,17,18,19,20]:
		var count: int = {0:16,2:16,11:18,12:17,17:19,18:9,19:1,20:1}[pose]
		for frame in range(count):
			var state := {"pose":pose,"attack":{"selector":pose,"frame":frame}}
			if pose not in [11,12]: state.source_pose = {"selector":pose,"frame":frame}
			var before := state.duplicate(true)
			assert(nest.present_executioner(state).is_empty() and state == before)
			var material: StandardMaterial3D = nest.actor.material_override
			var columns := mini(6,count)
			var rows := ceili(float(count)/columns)
			assert(material.uv1_scale.is_equal_approx(Vector3(1.0/columns,1.0/rows,1)))
			assert(material.uv1_offset.is_equal_approx(Vector3(float(frame%columns)/columns,float(frame/columns)/rows,0)))
			assert(nest.actor.mesh.size.is_equal_approx(base_size*Vector2(1,1.2 if pose in [19,20] else 1)))
			assert(is_equal_approx(nest.actor.mesh.center_offset.y-nest.actor.mesh.size.y*0.5,base_center.y-base_size.y*0.5))
	var material: StandardMaterial3D = nest.actor.material_override
	var before: Vector3 = material.uv1_offset
	assert(not nest.present_executioner({"pose":12,"attack":{"selector":12,"frame":17}}).is_empty())
	assert(material.uv1_offset == before)
	assert(nest.present_executioner({"pose":12,"attack":{"selector":12,"frame":7}}).is_empty())
	assert(nest.actor.mesh.size==base_size and nest.actor.mesh.center_offset==base_center)
	scene.camera.global_position = nest.actor.global_position+Vector3(0,25,130)
	scene.camera.look_at(nest.actor.global_position+Vector3(0,25,0))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	image.save_png("res://tmp/executioner_attack_frame.png")
	for sample in [{"pose":17,"frame":12},{"pose":19,"frame":0}]:
		assert(nest.present_executioner({"pose":sample.pose,"source_pose":{"selector":sample.pose,"frame":sample.frame}}).is_empty())
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/executioner_outcome_%d.png" % sample.pose)
	nest.restore({"phase":3,"elapsed":0})
	assert(material.uv1_scale.is_equal_approx(Vector3(1.0/6,1.0/3,1)) and material.uv1_offset == Vector3.ZERO)
	scene.queue_free()
	await process_frame
	print("PASS:97 executioner frames on Hive sprite, canvas aspect, UV selection, invalid frame rejection and rendered capture")
	quit(0)
