extends "res://tests/player_magic_handoff_test.gd"
## Supplied story/location fixtures; production grant, equipment, disk and transport paths.
const CaptainState=preload("res://scripts/lol2/cave_captain_state.gd")
const Items=preload("res://scripts/lol2/cave_captain_items.gd")
const Defense=preload("res://scripts/lol2/player_defense.gd")
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func write_json(path: String,value: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run() -> void:
	var path:="user://tests/captain_equipment_transport.json"
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not check(cave.walkthrough_ready,"Cave ready"):return
	freeze(cave);cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Supplied story completion: native state functions establish surrendered state2.
	var captain=cave.captain;var packet: Dictionary=captain.initial();var source: Dictionary=packet.source
	CaptainState.plate_entered(source,captain.src,89,4);CaptainState.control_animation_finished(source,captain.src)
	CaptainState.record_event(source,captain.src,10,0,953);CaptainState.hit(source,captain.src,1,1,1);CaptainState.pose_finished(source,captain.src)
	packet.movie_done=true;packet.movie=0.0;packet.pose=35.0/8.0
	if not check(captain.restore(packet).is_empty() and source.granted.is_empty(),"Surrender fixture has no unearned grants"):return
	var body: CharacterBody3D=cave.guard_population.bodies["56"];var aimed:=false
	for angle in range(0,360,15):
		cave.player.global_position=body.global_position+Vector3(sin(deg_to_rad(angle))*70,32,cos(deg_to_rad(angle))*70)
		cave.camera.look_at(body.global_position+Vector3.UP*24);await physics_frame
		if captain.aimed():aimed=true;break
	if not check(aimed and captain.use() and captain.use(),"Production aimed captain use grants failed"):return
	if not check(Items.SWORD in cave.carried_items() and Items.ARMOR in cave.carried_items(),"Source grants absent from inventory"):return
	if not check(cave.set_equipped_item(Items.SWORD) and cave.set_equipped_armor(Items.ARMOR) and Defense.scalar(cave)==8,"Captain equipment/chain defense8 failed"):return
	# Integrated optional lurking packet: mutate existing population, never instantiate a duplicate.
	var lurking=cave.lurking_roach_population
	if not check(lurking!=null and lurking.receive_damage("36",8),"Integrated lurking population missing"):return
	if not check(cave._quicksave(path).is_empty(),"Cave captain/lurking disk save failed"):return
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	cave.set_equipped_item("");cave.set_equipped_armor("");lurking.receive_damage("36",8)
	if not check(cave._quickload(path).is_empty() and cave.equipped_item==Items.SWORD and cave.equipped_armor==Items.ARMOR and lurking.state.actors["36"].health==142,"Cave disk rollback lost equipment/lurking"):return
	freeze(cave)
	var before: Dictionary=cave._save_state();var bad:=saved.duplicate(true);bad.lurking_roach.actors["36"].health=151;write_json(path,bad)
	if not check(not cave._quickload(path).is_empty() and cave._save_state()==before,"Malformed lurking disk load was not atomic"):return
	bad=saved.duplicate(true);bad.equipped_armor="museum:item10:Mail_Shirt";write_json(path,bad)
	if not check(not cave._quickload(path).is_empty() and cave._save_state()==before,"Unowned armor disk load was not atomic"):return
	var legacy:=saved.duplicate(true);legacy.erase("lurking_roach");write_json(path,legacy)
	if not check(cave._quickload(path).is_empty() and lurking.state.actors["36"].health==150 and cave.equipped_armor==Items.ARMOR,"Legacy optional lurking packet failed"):return
	freeze(cave)
	var transfer: Dictionary=cave._completion_state()
	set_meta("lol2_cave_completion",transfer)
	await finish(cave)
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();root.add_child(museum);current_scene=museum
	await process_frame;freeze(museum)
	# Supplied completed arrival overlay, not a claim that chamber/movie was earned.
	museum.introduction_state="complete";museum.flying=false
	if is_instance_valid(museum.introduction):museum.introduction.close();await process_frame
	if not check(museum.equipped_item==Items.SWORD and museum.equipped_armor==Items.ARMOR and Defense.scalar(museum)==8,"Production Cave→Museum handoff lost captain gear: weapon=%s armor=%s defense=%s" % [museum.equipped_item,museum.equipped_armor,Defense.scalar(museum)]):return
	var museum_save_error: String=museum.quicksave(path)
	if not check(museum_save_error.is_empty(),"Museum captain save failed: "+museum_save_error):return
	museum.set_equipped_item("");museum.set_equipped_armor("")
	if not check(museum.quickload(path).is_empty() and museum.equipped_item==Items.SWORD and museum.equipped_armor==Items.ARMOR,"Museum disk rollback lost captain gear"):return
	transfer=museum.inventory_state();await finish(museum)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(jungle);current_scene=jungle
	await process_frame;freeze(jungle)
	if not check(jungle.apply_inventory_handoff(transfer).is_empty(),"Museum→Jungle gear handoff failed"):return
	# Supplied shop/exhibit ownership for composition, never transported backwards into Museum.
	jungle.carried_collected.append(Defense.BRACERS);jungle.carried_collected.append("museum:item10:Mail_Shirt")
	if not check(jungle.item_effects.equip_offhand(Defense.BRACERS) and Defense.scalar(jungle)==13,"BurntChain8+Bracers5 did not equal13"):return
	if not check(jungle.set_equipped_armor("museum:item10:Mail_Shirt") and Defense.scalar(jungle)==25,"Mail20+Bracers5 did not equal25"):return
	for form in [1,2]:
		jungle.player_form=form
		if not check(Defense.scalar(jungle)==0,"Transformed player retained equipment defense"):return
	jungle.player_form=0;jungle.set_equipped_armor(Items.ARMOR)
	if not check(jungle.quicksave(path).is_empty(),"Jungle captain save failed"):return
	jungle.set_equipped_item("");jungle.set_equipped_armor("");jungle.item_effects.equip_offhand("")
	if not check(jungle.quickload(path).is_empty() and jungle.equipped_item==Items.SWORD and Defense.scalar(jungle)==13,"Jungle captain/offhand rollback failed"):return
	transfer=jungle.area_handoff();await finish(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive
	await process_frame;freeze(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty() and hive.equipped_item==Items.SWORD and hive.equipped_armor==Items.ARMOR and Defense.scalar(hive)==13,"Hive captain transport failed"):return
	if not check(hive.quicksave(path).is_empty(),"Hive captain save failed"):return
	hive.set_equipped_item("");hive.set_equipped_armor("");hive.item_effects.equip_offhand("")
	if not check(hive.quickload(path).is_empty() and hive.equipped_item==Items.SWORD and Defense.scalar(hive)==13,"Hive captain disk rollback failed"):return
	await finish(hive);DirAccess.remove_absolute(path)
	print("PASS captain production aimed grants→equip→cave disk→Museum handoff/disk→Jungle/Hive handoff/disk; defense8+5=13/20+5=25 human-only; integrated lurking disk/legacy/atomicity. Supplied surrender/story/location and later shop ownership fixtures; no earned campaign claim.")
	quit()
