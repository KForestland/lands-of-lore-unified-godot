extends "res://tests/museum_prism_test.gd"
const Ivory=preload("res://scripts/lol2/museum_ivory_state.gd")
func aim(target: Vector3, body: Node = null) -> bool:
	for angle in range(0,360,15):
		scene.player.global_position=target+Vector3(sin(deg_to_rad(angle))*60,18,cos(deg_to_rad(angle))*60)
		scene.camera.look_at(target);await physics_frame
		if body==null and scene.can_reach_item(target): return true
		var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,target,3,[scene.player.get_rid()])
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider==body:return true
	return false
func click() -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;Input.parse_input_event(e);await process_frame
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	await process_frame;scene.introduction_state="complete"
	if is_instance_valid(scene.introduction):scene.introduction.close();await process_frame
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;scene.flying=false
	var owner=scene.ivory
	if not check(is_instance_valid(owner) and owner.state.stages==[0,0] and not owner.chips[0].visible,"Ivory initial state"):return
	# Supplied existing sword, with its matching receipt. Container positions are original; player vantages supplied.
	scene.sword_transfer.collect();scene.carried_collected.append(scene.SWORD_ITEM_ID);scene.equipped_item=scene.SWORD_ITEM_ID
	if not check(await aim(owner.urns[0].global_position,owner.bodies[0]),"Clear urn189 attack vantage"):return
	scene.interface_hud.set_cursor(true);await click()
	if not check(owner.state.stages==[0,0],"Cursor mode hit urn"):return
	scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await click()
	if not check(owner.state.stages==[1,0] and owner.chips[0].visible and not owner.urns[0].visible,"Actual melee did not reveal chip17"):return
	var broken_path:="user://tests/ivory_broken.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	if not check(scene.quicksave(broken_path).is_empty(),"Broken urn save"):return
	if not check(await aim(owner.chips[0].global_position),"Chip17 reach"):return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/ivory_revealed.png")
	scene.hand_item=scene.SWORD_ITEM_ID;await press_e()
	if not check(owner.state.stages[0]==1,"Busy hand pickup"):return
	scene.hand_item=""
	var original: Array=scene.carried_collected.duplicate()
	scene.carried_collected.resize(scene.Catalog.MAX_CARRIED);await press_e()
	if not check(owner.state.stages[0]==1 and owner.chips[0].visible,"Full inventory consumed pickup"):return
	scene.carried_collected=original;await press_e();await press_e()
	if not check(owner.state.stages==[2,0] and scene.carried_collected.count(Ivory.IDS[0])==1,"Chip17 duplicate or missing"):return
	if not check(scene.quickload(broken_path).is_empty() and owner.state.stages==[1,0] and not Ivory.IDS[0] in scene.carried_collected,"Broken uncollected disk rewind"):return
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(await aim(owner.chips[0].global_position),"Rewound chip17 reach"):return
	await press_e()
	if not check(await aim(owner.urns[1].global_position,owner.bodies[1]),"Clear urn195 Spark vantage"):return
	scene.starting_magic.select_spell("spark")
	var mana: int=scene.player_magic_checkpoint.player.mana
	var e:=InputEventKey.new();e.keycode=KEY_Q;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_Q;e.pressed=false;Input.parse_input_event(e);await process_frame
	if not check(owner.state.stages==[2,1] and scene.player_magic_checkpoint.player.mana<mana,"Actual Spark did not reveal chip18"):return
	if not check(await aim(owner.chips[1].global_position),"Chip18 reach"):return
	await press_e()
	if not check(owner.state.stages==[2,2] and scene.carried_collected.count(Ivory.IDS[1])==1,"Chip18 pickup"):return
	scene.open_inventory();await process_frame
	var seen: Array=[]
	for i in scene.inventory.item_list.item_count:
		var id=str(scene.inventory.item_list.get_item_metadata(i))
		if id in Ivory.IDS:seen.append(id)
	if not check(seen.size()==2,"Two separate visible inventory entries"):return
	scene.inventory.queue_free();await process_frame;scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var path:="user://tests/ivory_complete.json"
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Ivory completed save/load"):return
	freeze(scene)
	var valid: Dictionary=scene.Save.read_save(path).state
	var bad:=valid.duplicate(true);bad.checkpoint.museum_ivory.stages[0]=0
	var before: Dictionary=scene.checkpoint_state()
	var file:=FileAccess.open("user://tests/ivory_bad.json",FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if not check(not scene.quickload("user://tests/ivory_bad.json").is_empty() and scene.checkpoint_state()==before,"Forged receipt mutated current save"):return
	var transport: Dictionary=scene.inventory_state()
	scene.queue_free();await process_frame;await process_frame
	set_meta("lol2_jungle_handoff",transport)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(jungle);current_scene=jungle;await process_frame;freeze(jungle)
	if not check(Ivory.IDS.all(func(id):return id in jungle.carried_collected) and jungle.quicksave("user://tests/ivory_jungle.json").is_empty(),"Ivory Jungle transport/save"):return
	var handoff: Dictionary=jungle.area_handoff();jungle.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive;await process_frame;freeze(hive)
	if not check(hive.apply_area_handoff(handoff).is_empty() and Ivory.IDS.all(func(id):return id in hive.carried_inventory.collected) and hive.quicksave("user://tests/ivory_hive.json").is_empty(),"Ivory Hive transport/save"):return
	var returned: Dictionary=hive.area_handoff();hive.queue_free();await process_frame;await process_frame
	var back=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(back);current_scene=back;await process_frame;freeze(back)
	if not check(back.apply_area_handoff(returned).is_empty() and Ivory.IDS.all(func(id):return id in back.carried_collected),"Ivory Hive return"):return
	var departure: Dictionary=back.area_handoff();back.queue_free();await process_frame;await process_frame
	set_meta("lol2_darker_handoff",departure)
	var darker=load("res://scenes/lol2/darker_jungle.tscn").instantiate();root.add_child(darker);current_scene=darker;await process_frame;freeze(darker)
	if not check(Ivory.IDS.all(func(id):return id in darker.carried_collected) and darker.quicksave("user://tests/ivory_darker.json").is_empty(),"Ivory darker arrival transport/save"):return
	var receipt: Dictionary={}
	for name in ["broken","complete","jungle","hive","darker"]:
		var saved_path: String="user://tests/ivory_"+name+".json"
		receipt[name]={"path":saved_path,"sha256":FileAccess.get_sha256(saved_path)}
	var out:=FileAccess.open("user://tests/ivory_receipt.json",FileAccess.WRITE);out.store_string(JSON.stringify(receipt));out.close()
	print("PASS museum_ivory_live: actual melee/Q/E, independent chips, cursor/busy/capacity rejection, uncollected/completed disk rewind, forged receipt atomic rejection, inventory UI and Museum/Jungle/Hive/return/darker transport. Vantages/sword supplied; no ordinary route claim.")
	quit()
