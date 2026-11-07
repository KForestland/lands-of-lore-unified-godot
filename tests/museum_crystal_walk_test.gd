extends "res://tests/museum_ivory_live_test.gd"
const Crystal = preload("res://scripts/lol2/museum_crystal_state.gd")
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Exact owner report11:12:11 start; existing weapon receipt supplied, no puzzle state supplied.
	scene.player.position=Vector3(-1294.09,32.0,-588.74);scene.player.rotation.y=-0.0096;scene.camera.rotation.x=-0.082
	scene.sword_transfer.collect();scene.carried_collected.append(scene.SWORD_ITEM_ID);scene.equipped_item=scene.SWORD_ITEM_ID
	var owner=scene.crystal_pickups;owner.set_process(true);scene.set_physics_process(true)
	var start:Vector3=scene.player.position
	var trace:Array=[]
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	var near:=false
	for i in 180:
		await physics_frame
		scene.camera.look_at(owner.body.global_position)
		if i%10==0:trace.append({"frame":i,"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"floor":scene.player.is_on_floor()})
		if scene.camera.global_position.distance_to(owner.body.global_position)<80:near=true;break
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file:=FileAccess.open("user://tests/crystal_walk_trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace));file.close()
	if not check(near and start.distance_to(scene.player.position)>30,"No ordinary walk approach from owner pose"):return
	for i in 3:
		scene.camera.look_at(owner.body.global_position);await physics_frame
		await click()
		if not check(owner.state.hits==i+1,"Walked melee did not release crystal"):return
		scene.camera.look_at(owner.pickups[i].global_position);await physics_frame
		await press_e()
		if not check(owner.state.taken[i] and scene.carried_collected.count(Crystal.IDS[i])==1,"Walked E did not collect crystal"):return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/crystal_walk.png")
	if not check(scene.quicksave("user://tests/crystal_walk.json").is_empty(),"Walked crystal save"):return
	print("PASS owner-pose actual W/collision approach, three actual melee/E earned crystal pickups and save; supplied existing weapon receipt, no intermediate teleport")
	await finish(scene);quit()
