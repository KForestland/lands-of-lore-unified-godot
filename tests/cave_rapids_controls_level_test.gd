extends SceneTree
var cave
var controls
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:push_error(message);quit(1)
func ray_top(id: String, excluding: bool=false) -> Dictionary:
	var mesh: MeshInstance3D=controls.surfaces[id][0].mesh
	var points: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var center:=Vector3.ZERO
	for p in points:center+=mesh.to_global(p)/points.size()
	var exclude: Array[RID]=[cave.player.get_rid()]
	if excluding:exclude.append(controls.bodies[id].get_rid())
	return cave.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*2,center-Vector3.UP*2,1,exclude))
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready:return fail("Cave not ready")
	cave.set_physics_process(false);cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	controls=cave.rapids_controls
	if controls==null:return fail("Main Cave controls missing")
	await physics_frame;await physics_frame
	for row in controls.State.source().controls:
		var id:=str(int(row.motion.owner));var mask: int=1<<int(row.arrival.selector)
		if controls.surfaces[id].size()!=6:return fail("Control face count wrong "+id)
		for face in controls.surfaces[id]:
			if not int(face.source.child_mask)&mask:return fail("Wrong entry selector "+id)
			var points: PackedVector3Array=face.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var order: Array=[0,1,2,0,2,3]
			for i in 6:
				var source: Array=face.source.points[order[i]]
				var expected: Vector3=cave.native_translation+Vector3(source[0],source[1],source[2])
				if face.mesh.to_global(points[i]).distance_to(expected)>0.003:return fail("Original geometry mismatch "+id)
		var hit:=ray_top(id)
		if hit.is_empty() or hit.collider!=controls.bodies[id]:return fail("Control top collision missing "+id)
		if not ray_top(id,true).is_empty():return fail("Duplicate original control collision "+id)
	var initial: Dictionary=controls.checkpoint()
	if not cave._quicksave("user://controls_initial.json").is_empty():return fail("Main initial control save failed")
	controls.advance(1.0,false)
	if controls.checkpoint()!=initial:return fail("Inactive control advanced")
	cave.player.global_position=cave.native_translation+Vector3(450,-300,-17300);cave.player.look_at(cave.native_translation+Vector3(315,-300,-17571));cave.camera.look_at(cave.native_translation+Vector3(315,-280,-17571))
	await capture("controls_initial")
	if not cave.rapids_trigger.receive_hit(1,1,1):return fail("Admitted trigger refused")
	controls.advance(1.0/120.0,true)
	for i in 150:controls.advance(1.0/60.0,true)
	var partial: Dictionary=controls.checkpoint()
	if not is_equal_approx(partial.tick_fraction,0.5):return fail("Control fractional tick lost")
	if not cave._quicksave("user://controls_mid.json").is_empty():return fail("Main moving control save failed")
	for i in 560:controls.advance(1.0/60.0,true)
	await physics_frame;await physics_frame
	for row in controls.State.source().controls:
		var id:=str(int(row.motion.owner))
		if not controls.state.controls[id].complete:return fail("Control did not finish "+id)
		var t: Array=row.motion.target
		if controls.bodies[id].position.distance_to(cave.native_translation+Vector3(t[0],t[1],t[2]))>0.003:return fail("Body endpoint wrong "+id)
		for face in controls.surfaces[id]:
			var copy: MeshInstance3D=cave.occluder_by_source[face.mesh]
			if copy.mesh!=face.mesh.mesh or copy.global_transform!=face.mesh.global_transform:return fail("Control mask stale "+id)
	await capture("controls_finished")
	if not cave._quickload("user://controls_mid.json").is_empty():return fail("Main control continuation load failed")
	if controls.checkpoint()!=partial:return fail("Control continuation changed")
	var bad: Dictionary=partial.duplicate(true);bad.state.controls["103"].complete=true;bad.state.controls["103"].position[0]+=1
	if controls.restore(bad).is_empty() or controls.checkpoint()!=partial:return fail("Invalid load changed controls")
	var bad_save: Dictionary=cave._save_state();bad_save.rapids_controls=bad
	var file:=FileAccess.open("user://controls_invalid.json",FileAccess.WRITE);file.store_string(JSON.stringify(bad_save));file.close()
	if cave._quickload("user://controls_invalid.json").is_empty() or controls.checkpoint()!=partial:return fail("Main invalid save changed controls")
	if not cave._quickload("user://controls_initial.json").is_empty():return fail("Main initial rewind failed")
	await physics_frame;await physics_frame
	for id in controls.bodies:
		if ray_top(id).is_empty():return fail("Rewind lost collision")
	print("PASS actual Cave five-control geometry: original entry selectors/vertices, indexed faces/sprites, collision without duplicate tops, full accepted movement, depth-copy mesh updates and JSON rewind. Normal Cave owner; hit admission and native collision parity remain separate.")
	quit()
func capture(label: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/"+label+".png")
