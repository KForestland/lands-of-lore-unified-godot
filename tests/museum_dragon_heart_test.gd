extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.dragon_heart
	var atlas: Image=owner.movie.get_image()
	for frame in 20:
		if not check(atlas.get_pixel((frame%5)*304,(frame/5)*168).a==0.0,"Decoded blue backdrop is opaque in frame %d" % frame):return
	owner.set_physics_process(true)
	if not check(owner.state.phase=="idle" and not owner.gem.visible,"Original heart initially intact, no reward"):return
	# Owner's reported view, with reproducible magic progression below the next threshold.
	scene.player.position=Vector3(-1216.57385253906,32.0381774902344,-2072.49731445312)
	scene.player.rotation.y=-0.32824119925499;scene.camera.rotation.x=0;scene.camera.fov=75
	scene.player_magic_checkpoint.player={"experience":0,"level":5,"maximum":71,"mana":71}
	scene.starting_magic.select_spell("spark")
	for i in 3:await physics_frame
	DirAccess.make_dir_recursive_absolute("user://tests")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/dragon_heart_idle.png")
	var before:="user://tests/dragon_heart_before.json"
	if not check(scene.quicksave(before).is_empty(),"Save untouched heart"):return
	var event:=InputEventKey.new();event.keycode=KEY_Q;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.keycode=KEY_Q;event.pressed=false;Input.parse_input_event(event);await process_frame
	if not check(owner.state.phase=="playing" and scene.player_magic_checkpoint.player.experience==50 and scene.player_magic_checkpoint.player.mana==70,"Actual owner-pose Spark and original50magic reward"):return
	if not check(not owner.receive_spark() and scene.player_magic_checkpoint.player.experience==50,"Repeated hit duplicated reward"):return
	var during:="user://tests/dragon_heart_during.json"
	if not check(scene.quicksave(during).is_empty(),"Save movie in progress"):return
	scene.open_inventory();await process_frame
	var paused:float=owner.state.elapsed
	for i in 10:await physics_frame
	if not check(owner.state.elapsed==paused,"Inventory pause advanced movie"):return
	scene.inventory.close();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in 100:await physics_frame
	if not check(owner.state.phase=="revealed" and owner.gem.visible and owner.display.visible,"Movie completion must reveal original item25"):return
	if not check(await aim(owner.gem.global_position),"Dragon Gem reachable vantage"):return
	# Supply a genuinely carried sword (with its matching receipt), as in the owner's report.
	scene.sword_transfer.collect()
	if not scene.SWORD_ITEM_ID in scene.carried_collected: scene.carried_collected.append(scene.SWORD_ITEM_ID)
	var inventory:Array=scene.carried_collected.duplicate()
	scene.hand_item=scene.SWORD_ITEM_ID
	scene.carried_collected.resize(scene.Catalog.MAX_CARRIED);await press_e()
	if not check(not owner.state.taken,"Full inventory consumed gem"):return
	scene.carried_collected=inventory;scene.hand_item=scene.SWORD_ITEM_ID
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/dragon_heart_revealed.png")
	await press_e();await press_e()
	if not check(scene.hand_item=="" and scene.SWORD_ITEM_ID in scene.carried_collected,"Held sword not stowed and preserved"):return
	if not check(owner.state.taken and scene.carried_collected.count(owner.State.ITEM)==1,"Exactly-once Dragon Gem pickup"):return
	var after:="user://tests/dragon_heart_after.json"
	if not check(scene.quicksave(after).is_empty(),"Save earned gem"):return
	if not check(scene.quickload(during).is_empty() and owner.state.phase=="playing" and not owner.State.ITEM in scene.carried_collected,"Disk rollback to movie"):return
	freeze(scene);owner.set_physics_process(true);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in 100:await physics_frame
	if not check(owner.gem.visible and scene.player_magic_checkpoint.player.experience==50,"Reload completion duplicates experience or loses item"):return
	if not check(scene.quickload(after).is_empty() and owner.state.taken and not owner.gem.visible,"Restore collected receipt"):return
	var bad:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(after))
	bad.checkpoint.museum_dragon_heart.phase="idle"
	if not check(not scene.Save.validate(bad).is_empty(),"Unearned receipt admitted"):return
	if not check(scene.quickload(before).is_empty() and owner.state.phase=="idle" and scene.player_magic_checkpoint.player.experience==0,"Pre-trigger rollback"):return
	bad=JSON.parse_string(FileAccess.get_file_as_string(before));bad.checkpoint.erase("museum_dragon_heart")
	if not check(scene.Save.validate(bad).is_empty(),"Legacy Museum checkpoint rejected"):return
	var receipt: Dictionary={}
	for label in ["before","during","after"]:
		var saved_path: String="user://tests/dragon_heart_"+label+".json"
		receipt[label]={"path":saved_path,"sha256":FileAccess.get_sha256(saved_path)}
	var output:=FileAccess.open("user://tests/dragon_heart_receipt.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(receipt));output.close()
	print("PASS original heart Spark/movie/gem;50magicXP; actual E/full/held-stow/no-duplicate; pause and disk rollback")
	await finish(scene);quit()
