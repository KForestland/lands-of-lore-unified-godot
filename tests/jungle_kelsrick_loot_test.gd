extends "res://tests/jungle_kelsrick_live_test.gd"
const LootState=preload("res://scripts/lol2/jungle_kelsrick_state.gd")
const ITEM="jungle:kelsrick:Fine_Longsword"
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func aim_loot() -> bool:
	for i in 24:
		var p: Vector3=ctrl.loot_sprite.global_position
		var angle:=TAU*float(i%12)/12.0
		var distance:=60.0 if i<12 else 35.0
		scene.player.global_position=p+Vector3(sin(angle)*distance,24,cos(angle)*distance)
		scene.camera.look_at(p)
		await physics_frame
		if ctrl.loot_target(): return true
	return false
func dispatch_e() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_E;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.keycode=KEY_E;event.pressed=false
	Input.parse_input_event(event);await process_frame
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	ctrl=scene.kelsrick
	var legacy: Dictionary=ctrl.checkpoint()
	if not check(not legacy.state.has("loot_taken") and ctrl.restore(legacy).is_empty() and not ctrl.loot_sprite.visible,"Legacy/living packet"):return
	var bad: Dictionary=legacy.duplicate(true);bad.state.loot_taken=true
	if not check(not ctrl.restore(bad).is_empty() and ctrl.checkpoint()==legacy,"Living loot mutation admitted"):return
	if not check(ctrl.population.receive_damage("64",1000,true),"Production lethal damage"):return
	# Actual engine drives death mirroring and the retirement clock.
	ctrl.set_physics_process(true)
	for i in 8: await physics_frame
	ctrl.set_physics_process(false)
	if not check(ctrl.state.health==0 and ctrl.state.death>0 and not ctrl.loot_sprite.visible,"Live death/clock"):return
	var partial: float=ctrl.state.death
	var path:="user://tests/kelsrick_loot.json"
	if not check(scene.quicksave(path).is_empty(),"Partial save"):return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;ctrl.advance(8)
	if not check(ctrl.state.death==partial,"Inactive world advanced loot"):return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;paused=true;ctrl.advance(8);paused=false
	if not check(ctrl.state.death==partial,"Pause advanced loot"):return
	ctrl.advance(6)
	if not check(ctrl.loot_sprite.visible and not ctrl.population.meshes["64"].visible,"Retirement visibility"):return
	if not check(scene.quickload(path).is_empty() and ctrl.state.death==partial and not ctrl.loot_sprite.visible,"Partial disk restore"):return
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	ctrl.state.death=4.95 # Boundary fixture; real engine must cross and present.
	ctrl.set_physics_process(true)
	for i in 8:await physics_frame
	ctrl.set_physics_process(false)
	if not check(ctrl.loot_sprite.visible and not ctrl.population.meshes["64"].visible,"Live retirement visibility"):return
	if not check(await aim_loot(),"Loot aim"):return
	ctrl._present()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/kelsrick_loot_visible.png")
	await dispatch_e()
	if not check(ctrl.state.get("loot_taken",false) and scene.carried_collected.count(ITEM)==1 and not ctrl.loot_sprite.visible,"Dispatched E pickup"):return
	if not check(scene.set_equipped_item(ITEM),"Equip source sword"):return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Taken disk roundtrip"):return
	freeze(scene);await dispatch_e();ctrl.advance(6)
	if not check(scene.equipped_item==ITEM and scene.carried_collected.count(ITEM)==1 and not ctrl.loot_sprite.visible,"Taken reload duplicate"):return
	var transfer: Dictionary=scene.area_handoff()
	var before: Dictionary=transfer.duplicate(true)
	bad=transfer.duplicate(true);bad.inventory.collected.erase(ITEM);bad.inventory.equipped_item=""
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Mismatched handoff mutated host"):return
	bad=Save.read_save(path).state;bad.quests.jungle_kelsrick.state.erase("loot_taken")
	if not check(not Save.validate(bad).is_empty(),"Forged inventory admitted"):return
	bad=ctrl.checkpoint();bad.state.death=1
	if not check(not ctrl.validate(bad).is_empty(),"Premature taken receipt admitted"):return
	scene.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive;await process_frame
	freeze(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty() and hive.carried_inventory.collected.count(ITEM)==1 and hive.equipped_item==ITEM,"Hive transfer"):return
	if not check(hive.quicksave(path).is_empty() and hive.quickload(path).is_empty(),"Hive disk roundtrip"):return
	print("PASS Kelsrick source sword: real lethal damage, engine retirement, pause/partial disk, visible aimed dispatched E, equip/save/no duplicate, conserved Hive handoff; supplied death/camera/boundary fixtures")
	quit()
