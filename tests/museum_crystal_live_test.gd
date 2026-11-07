extends "res://tests/museum_ivory_live_test.gd"
const Crystal = preload("res://scripts/lol2/museum_crystal_state.gd")
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.crystal_pickups
	if not check(is_instance_valid(owner) and owner.state.hits==0,"Crystal host missing"):return
	# Existing weapon with matching receipt; camera vantages supplied. Pickups are earned by actual hits.
	scene.sword_transfer.collect();scene.carried_collected.append(scene.SWORD_ITEM_ID);scene.equipped_item=scene.SWORD_ITEM_ID
	DirAccess.make_dir_recursive_absolute("user://tests")
	var before:="user://tests/crystal_before.json"
	if not check(scene.quicksave(before).is_empty(),"Before crystal save"):return
	if not check(await aim(owner.body.global_position,owner.body),"Crystal attack vantage"):return
	scene.starting_magic.select_spell("spark")
	var e:=InputEventKey.new();e.keycode=KEY_Q;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_Q;e.pressed=false;Input.parse_input_event(e);await process_frame
	if not check(owner.state.hits==0,"Spark incorrectly released crystal"):return
	for frame in 45:await process_frame # Let the rejected Spark visual finish before pickup capture.
	for i in 3:
		if not check(await aim(owner.body.global_position,owner.body),"Crystal melee vantage"):return
		await click()
		if not check(owner.state.hits==i+1 and owner.pickups[i].visible,"Melee did not reveal next original item"):return
		if not check(await aim_pickup(owner,owner.pickups[i].global_position),"Released crystal pickup vantage"):return
		scene.hand_item=scene.SWORD_ITEM_ID;await press_e()
		if not check(not owner.state.taken[i],"Busy hand took crystal"):return
		scene.hand_item=""
		if i==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://tests/crystal_released.png")
			var carried:Array=scene.carried_collected.duplicate()
			scene.carried_collected.resize(scene.Catalog.MAX_CARRIED);await press_e()
			if not check(not owner.state.taken[i] and owner.pickups[i].visible,"Full inventory consumed crystal"):return
			scene.carried_collected=carried
		await press_e()
		if not check(owner.state.taken[i] and scene.carried_collected.count(Crystal.IDS[i])==1 and scene.item_effects.crystal_burnt(Crystal.IDS[i]),"Burnt crystal receipt/charges"):return
	if not check(await aim(owner.body.global_position,owner.body),"Repeat strike vantage"):return
	await click()
	if not check(owner.state.hits==3,"Repeat hit duplicated crystal"):return
	var earned:="user://tests/crystal_earned.json"
	if not check(scene.quicksave(earned).is_empty(),"Earned crystal save"):return
	if not check(scene.quickload(before).is_empty() and owner.state.hits==0 and not Crystal.IDS[0] in scene.carried_collected,"Unreleased disk rollback"):return
	if not check(scene.quickload(earned).is_empty() and owner.state.hits==3 and owner.state.taken==[true,true,true],"Earned disk reload"):return
	freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var locks=scene.key_locks
	scene.hand_item=Crystal.IDS[0]
	if not check(await aim(locks.sconce_point(117)),"Unlit sconce vantage"):return
	await press_e()
	if not check(scene.item_effects.crystal_burnt(Crystal.IDS[0]),"Unlit sconce recharged"):return
	scene.hand_item=""
	if not check(await aim(locks.aim_point(87)),"Key pickup vantage"):return
	await press_e()
	if not check(await aim(locks.aim_point(113)),"Sconce lock vantage"):return
	await press_e()
	if not check(preload("res://scripts/lol2/museum_key_locks_state.gd").sconces_lit(locks.state),"Actual key did not light sconces"):return
	scene.hand_item=Crystal.IDS[0]
	if not check(await aim(locks.sconce_point(117)),"Lit sconce vantage"):return
	await press_e()
	if not check(scene.item_effects.crystal_charges(Crystal.IDS[0])==1 and scene.hand_item=="","Earned crystal did not recharge"):return
	var charged:="user://tests/crystal_charged.json"
	if not check(scene.quicksave(charged).is_empty(),"Museum charged crystal save"):return
	if not check(scene.quickload(charged).is_empty() and scene.item_effects.crystal_charges(Crystal.IDS[0])==1,"Museum charged reload"):return
	var receipt:={}
	for path in [before,earned,charged]:receipt[path]={"path":path,"sha256":FileAccess.get_sha256(path)}
	var file:=FileAccess.open("user://tests/crystal_receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt));file.close()
	print("PASS actual Spark refusal/three melee releases/earned burnt pickups/busy/no duplicates/disk rollback/actual key and sconce recharge/Museum charged save")
	quit()

func aim_pickup(owner: Node3D, target: Vector3) -> bool:
	for angle in range(0,360,15):
		scene.player.global_position=target+Vector3(sin(deg_to_rad(angle))*60,18,cos(deg_to_rad(angle))*60)
		scene.camera.look_at(target);await physics_frame
		if owner.can_reach_pickup(target):return true
	return false
