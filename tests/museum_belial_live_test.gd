extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.belial;owner.set_physics_process(true)
	if not check(owner.state.phase=="idle" and owner.display.visible,"Belial initially visible"):return
	scene.player.position=Vector3(343,27,-3282);scene.camera.look_at(Vector3(347,29.5,-3423));scene.camera.fov=75
	DirAccess.make_dir_recursive_absolute("user://tests")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/belial_owner_pose.png")
	var before:="user://tests/belial_before.json"
	if not check(scene.quicksave(before).is_empty(),"Save idle Belial"):return
	if not check(await aim(Vector3(347,29.5,-3423)),"Reachable Belial interaction vantage"):return
	scene.hand_item=scene.SWORD_ITEM_ID;await press_e()
	if not check(owner.state.phase=="idle","Busy hand used Belial"):return
	scene.hand_item="";await press_e()
	if not check(owner.state.phase=="active" and owner.clocks[0]>=0,"Actual E starts original active sequence and cue"):return
	for i in 40:await physics_frame
	var during:="user://tests/belial_during.json"
	if not check(scene.quicksave(during).is_empty(),"Save active Belial"):return
	var saved_frame:int=owner.state.frame
	await press_e()
	if not check(owner.state.frame>=saved_frame,"Repeated E reset selector frame"):return
	scene.open_inventory();await process_frame
	var paused:Dictionary=owner.checkpoint()
	for i in 10:await physics_frame
	if not check(owner.checkpoint()==paused,"Paused Belial advanced"):return
	scene.inventory.close();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in 240:await physics_frame
	if not check(owner.state.phase=="gone" and not owner.display.visible and owner.clocks[1]>=0,"Native endpoint removes exhibit and triggers completion sound"):return
	if not check(owner.clocks[0]<owner.DURATIONS[0],"Prop removal incorrectly stopped control102 voice"):return
	var after:="user://tests/belial_after.json"
	if not check(scene.quicksave(after).is_empty(),"Save completed Belial"):return
	if not check(scene.quickload(during).is_empty() and owner.state.phase=="active" and owner.state.frame==saved_frame,"Reload active frame"):return
	freeze(scene);owner.set_physics_process(true)
	for i in 240:await physics_frame
	if not check(owner.state.phase=="gone","Reloaded Belial failed to finish"):return
	if not check(scene.quickload(after).is_empty() and not owner.display.visible,"Completed save restored exhibit"):return
	if not check(scene.quickload(before).is_empty() and owner.state.phase=="idle" and owner.display.visible,"Idle rollback failed"):return
	var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(before))
	packet.checkpoint.museum_belial.animation.frame=100
	if not check(not scene.Save.validate(packet).is_empty(),"Invalid Belial frame admitted"):return
	packet.checkpoint.erase("museum_belial")
	if not check(scene.Save.validate(packet).is_empty(),"Legacy Museum save rejected"):return
	var receipt: Dictionary={}
	for label in ["before","during","after"]:
		var path: String="user://tests/belial_"+label+".json"
		receipt[label]={"path":path,"sha256":FileAccess.get_sha256(path)}
	var file:=FileAccess.open("user://tests/belial_receipt.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt));file.close()
	print("PASS Belial visible/actual E/busy/repeat/pause/source endpoint/control sound ownership/disk rollback/legacy")
	await finish(scene);quit()
