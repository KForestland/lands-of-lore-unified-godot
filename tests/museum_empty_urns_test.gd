extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.empty_urns
	if not check(owner.urns.size()==9 and owner.broken.count(true)==0,"Nine source ordinary urns initially intact"):return
	scene.sword_transfer.collect();scene.carried_collected.append(scene.SWORD_ITEM_ID);scene.equipped_item=scene.SWORD_ITEM_ID
	var inventory: Array=scene.carried_collected.duplicate()
	# Owner's exact reported camera pose: urn188 must be visible and reachable.
	scene.player.position=Vector3(-23.4777565,42.0465164,-172.23390198)
	scene.player.rotation.y=-1.95179533958435;scene.camera.rotation.x=-0.313013285398483
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/ordinary_urn_owner_pose.png")
	await click()
	if not check(owner.broken[1] and owner.broken.count(true)==1,"Actual owner-pose click breaks urn188 only"):return
	if not check(scene.carried_collected==inventory,"Empty urn invented a reward"):return
	var path:="user://tests/ordinary_urns.json"
	if not check(scene.quicksave(path).is_empty(),"Broken ordinary urn save"):return
	# Actual Spark on a second urn; supplied unobstructed vantage.
	if not check(await aim(owner.bodies[0].global_position,owner.bodies[0]),"Urn187 Spark vantage"):return
	scene.starting_magic.select_spell("spark")
	var mana: int=scene.player_magic_checkpoint.player.mana
	var e:=InputEventKey.new();e.keycode=KEY_Q;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_Q;e.pressed=false;Input.parse_input_event(e);await process_frame
	if not check(owner.broken[0] and scene.player_magic_checkpoint.player.mana<mana,"Actual Spark breaks empty urn"):return
	if not check(not owner.receive_hit(0,8) and scene.carried_collected==inventory,"Repeat hit duplicated reward or break"):return
	if not check(scene.quickload(path).is_empty() and owner.broken.count(true)==1 and owner.broken[1] and owner.urns[0].visible,"Disk rewind preserves independent urns"):return
	freeze(scene)
	var bad: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	bad.checkpoint.museum_empty_urns.broken[0]=1
	if not check(not scene.Save.validate(bad).is_empty(),"Numeric break flag admitted"):return
	bad.checkpoint.erase("museum_empty_urns")
	if not check(scene.Save.validate(bad).is_empty(),"Legacy save without ordinary urn field rejected"):return
	if not check(owner.restore_checkpoint(null).is_empty() and owner.broken.count(true)==0,"Legacy restore leaves urns intact"):return
	if not check(scene.ivory.state.stages==[0,0],"Ordinary urns changed ivory receipts"):return
	print("PASS nine source ordinary urns; exact owner-pose melee; actual Spark; no invented rewards; repeat rejection; independent disk rollback; legacy/invalid save checks")
	await finish(scene);quit()
