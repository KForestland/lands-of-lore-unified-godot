extends "res://tests/game_save_quit_load_test.gd"
## Local two-process Cave proof. Supplied captain-grant packet and two local standing
## starts are setup aids, declared source sites. Roach hit, chain break, F5 and Continue
## use real events with live physics; no health top-ups, resets or campaign claim.
const Save=preload("res://scripts/lol2/game_save.gd")
func settled() -> void:
	for i in 1800:
		await process_frame
		if scene.walkthrough_ready and scene.get("starting_magic")!=null:break
	capture();await ticks(12)
func cave_aim(point:Vector3) -> void:
	for i in 4:
		var d:Vector3=point-scene.camera.global_position
		var yaw:=atan2(-d.x,-d.z);var pitch:=atan2(d.y,Vector2(d.x,d.z).length())
		var motion:=InputEventMouseMotion.new()
		motion.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.002,-(pitch-scene.camera.rotation.x)/0.002)
		Input.parse_input_event(motion);Input.flush_buffered_events();await process_frame
func click() -> void:
	await process_frame
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=Vector2(640,360)
		Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-phase="):phase=int(arg.get_slice("=",1))
		if arg.begins_with("--save-proof="):proof=arg.substr(13)
	if phase==1:
		scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
		var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/L1_DC.json"))
		state.captain.source.granted=["5-Short swd","37-Brnt Chain"]
		state.equipped_item="cave:captain:Short_Sword"
		assert(scene.apply_slot_state(state).is_empty(),"supplied captain-grant starting packet")
		capture();await ticks(4)
		# One floor-ray standing start beside the real roach, no actor/AI edits.
		var target:Vector3=scene.roach.body.global_position+Vector3.UP*6
		var start:=Vector3.ZERO
		for angle in range(0,360,30):
			var from:Vector3=target+Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*42+Vector3.UP*45
			var ray:=PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*220,1|256,[scene.player.get_rid()])
			var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():continue
			start=hit.position+Vector3.UP*32;break
		assert(start!=Vector3.ZERO);scene.player.global_position=start;scene.player.velocity=Vector3.ZERO
		await ticks(3);await cave_aim(scene.roach.body.global_position+Vector3.UP*6)
		var health:int=scene.roach.model.enemy_health
		await click();await ticks(3)
		assert(scene.roach.model.enemy_health<health,"real click fights roach")
		# Second disclosed local start uses the existing collision-checked chain approach.
		var floor_center:=Vector3.ZERO;var found:=false
		for face in scene.data.faces:
			if int(face.region)!=800:continue
			for vertex in face.points:floor_center+=scene.point(vertex)*64.0/face.points.size()
			found=true;break
		assert(found)
		var candidate:Vector3=floor_center+scene.native_translation+Vector3.UP*32.1
		var shape_node:CollisionShape3D=scene.player.get_child(0)
		var probe:=PhysicsShapeQueryParameters3D.new();probe.shape=shape_node.shape
		probe.transform=Transform3D(Basis.IDENTITY,candidate+shape_node.position);probe.collision_mask=scene.player.collision_mask;probe.exclude=[scene.player.get_rid()]
		assert(scene.get_world_3d().direct_space_state.intersect_shape(probe).is_empty(),"clear supplied chain standing start")
		scene.player.global_position=candidate;scene.player.velocity=Vector3.ZERO
		await cave_aim(scene.indexed_chain.mesh.global_position);await ticks(12)
		assert(scene.indexed_chain.can_strike());await tap(KEY_E);await ticks(320)
		assert(scene.indexed_chain.state.started and scene.indexed_chain.state.door_dispatch_count==1)
		assert(scene.can_save().is_empty(),scene.can_save());await tap(KEY_F5);await ticks(3)
		var read:=Save.read_document(Save.slot_path(1));assert(read.error.is_empty() and read.state.area=="L1_DC")
		assert(scene.resets==0 and scene.starting_magic.health()>0)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(proof+"/cave_saved.png")
		print("PASS phase1 Cave: real roach click, chain E, F5; supplied grant/standing setup, no health top-up; resets=0")
		quit();return
	var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate();root.add_child(gate);current_scene=gate
	await process_frame;gate.path_field.text=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	var button:Button=gate.find_child("Continue",true,false);assert(button!=null and not button.disabled)
	button.grab_focus();await tap(KEY_ENTER)
	if current_scene==gate:await scene_changed
	scene=current_scene;await settled()
	var expected:Dictionary=Save.read_document(Save.slot_path(1)).state.area_save
	var p:Array=expected.player.position
	assert(scene.player.position.distance_to(Vector3(p[0],p[1],p[2]))<2,"Cave Continue pose")
	assert(scene.roach.model.enemy_health==int(expected.roach.enemy_health),"fought roach health restored")
	assert(scene.indexed_chain.state.started and scene.indexed_chain.rule.script_state==1)
	print("CAVE CHAIN expected=",expected.chain_doors," actual=",scene.indexed_chain.saved_state())
	assert(JSON.parse_string(JSON.stringify(scene.indexed_chain.saved_state().doors))==expected.chain_doors.doors,"saved door poses with live clock")
	assert(scene.equipped_item==expected.equipped_item and scene.carried_items().has("cave:captain:Short_Sword"))
	assert(scene.resets==0 and scene.starting_magic.health()>0)
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(proof+"/cave_resumed.png")
	print("PASS phase2 real Continue restores Cave pose, fought roach, broken chain/doors and pack; resets=0")
	quit()
