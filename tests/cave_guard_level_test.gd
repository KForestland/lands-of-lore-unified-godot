extends SceneTree
## Actual Cave collision/render fixture. local7 is supplied for this bounded test;
## prop518/floor completion ownership and campaign save hookup are not asserted.
const Controller=preload("res://scripts/lol2/cave_guard_encounter.gd")
var cave
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:
	push_error(message);quit(1)
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready:return fail("Cave did not become ready")
	cave.set_physics_process(false);cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var controller: Node3D=cave.guard_encounter
	if controller==null:return fail("Main Cave encounter owner missing")
	cave.player.global_position=cave.native_translation+Vector3(-9,-245,-16615);cave.player.velocity=Vector3.ZERO
	for i in range(90):
		await physics_frame
		cave.player.velocity=Vector3(0,-30,0);cave.player.move_and_slide()
	var before: Vector3=cave.player.global_position-cave.native_translation
	print("ACTUAL_CAVE grounded=",cave.player.is_on_floor()," native=",before)
	if not cave.player.is_on_floor():return fail("No actual Cave support beneath control104")
	controller.advance(1.0/60,true,0)
	print("ACTUAL_CAVE phase=",controller.state.sequence.phase," native=",cave.player.global_position-cave.native_translation," visible=",controller.guard_visible())
	if controller.state.sequence.phase!="playing":return fail("Actual Cave did not admit the guard movie")
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/cave_guard_level.png")
	for child in controller.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("cave_guard_rgb_view.gd"):
			child.view.get_texture().get_image().save_png("user://tests/cave_guard_rgb.png")
			# The movie must disappear behind a real foreground depth occluder.
			var blocker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(200,200,1);blocker.mesh=box;blocker.layers=4
			var mask:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){ALBEDO=vec3(64.0,64.0,0.0)/255.0;}";mask.shader=shader;blocker.material_override=mask;cave.add_child(blocker)
			blocker.global_transform=cave.camera.global_transform;blocker.global_position-=cave.camera.global_basis.z*20
			for i in range(4):await process_frame
			await RenderingServer.frame_post_draw
			var occluded: Image=child.view.get_texture().get_image()
			var pixel: Color=occluded.get_pixel(occluded.get_width()/2,occluded.get_height()/2)
			if absf(pixel.r-64.0/255)>0.002 or absf(pixel.g-64.0/255)>0.002 or pixel.b>0.002:return fail("RGB movie ignored foreground depth occluder")
			blocker.queue_free();await process_frame
	var packet: Dictionary=controller.checkpoint();controller.advance(1,false,0)
	if controller.checkpoint()!=packet:return fail("Paused actual-level encounter advanced")
	for i in range(2400):
		var previous: int=controller.state.sequence.selector
		controller.advance(1.0/60,true,0)
		if controller.state.sequence.selector!=previous:
			await physics_frame;await physics_frame
		if controller.state.sequence.phase=="complete":break
	if controller.input_locked() or controller.state.sequence.phase!="complete":return fail("Actual-level guard sequence failed to release")
	cave.player.global_position=cave.native_translation+Vector3(-68.54,-257.988,-16734.385)
	cave.camera.look_at(controller.movement.bodies["72"].global_position)
	await physics_frame
	var lever_point: Vector3=controller.movement.bodies["72"].global_position
	var ray:=PhysicsRayQueryParameters3D.create(cave.camera.global_position,lever_point,1,[cave.player.get_rid()])
	print("LEVER_DIAGNOSTIC active=",controller.active()," target=",controller.target_lever()," camera=",cave.camera.global_position-cave.native_translation," lever=",lever_point-cave.native_translation," hit=",cave.get_world_3d().direct_space_state.intersect_ray(ray))
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_guard_lever.png")
	if controller.target_lever()!=72:return fail("Visible source lever face was not targetable")
	var old_state: int=controller.state.movable_states["72"]
	cave.set_physics_process(true)
	var press:=InputEventKey.new();press.keycode=KEY_E;press.pressed=true;Input.parse_input_event(press)
	await process_frame
	var release:=InputEventKey.new();release.keycode=KEY_E;release.pressed=false;Input.parse_input_event(release)
	for i in range(3):await physics_frame
	cave.set_physics_process(false)
	if controller.state.movable_states["72"]!=1-old_state:return fail("Actual E did not toggle visible source lever72")
	for id in [64,65,66]:
		var body: Node3D=controller.movement.bodies[str(id)]
		cave.player.global_position=cave.native_translation+Vector3(350,-253,body.global_position.z-cave.native_translation.z);cave.player.velocity=Vector3.ZERO
		cave.camera.look_at(body.global_position)
		await physics_frame
		print("LEVER_INPUT id=",id," target=",controller.target_lever())
		if controller.target_lever()!=id:return fail("Could not target source lever%d"%id)
		var previous: int=controller.state.movable_states[str(id)]
		cave.set_physics_process(true)
		var down:=InputEventKey.new();down.keycode=KEY_E;down.pressed=true;Input.parse_input_event(down)
		await process_frame
		var up:=InputEventKey.new();up.keycode=KEY_E;up.pressed=false;Input.parse_input_event(up)
		for i in range(3):await physics_frame
		cave.set_physics_process(false)
		if controller.state.movable_states[str(id)]!=1-previous:return fail("Actual E failed for lever%d"%id)
	var mid_motion: Dictionary=controller.checkpoint()
	if not cave._quicksave("user://tests/cave_guard_levers.json").is_empty():return fail("Lever movement save failed")
	for i in range(180):controller.advance(1.0/60,true,cave.cave_local7)
	if not cave._quickload("user://tests/cave_guard_levers.json").is_empty():return fail("Lever movement restore failed")
	cave.set_physics_process(false)
	if controller.checkpoint()!=mid_motion:return fail("Lever checkpoint lost state or movement on restore")
	controller.movie.voice.stop();controller.delayed_voice.stop()
	await physics_frame;await physics_frame
	print("PASS actual Cave support, visibility/reposition, six clips and release, pause. Supplied local7; no campaign save or owner approach claim.")
	cave.queue_free();await process_frame;await process_frame;quit()
