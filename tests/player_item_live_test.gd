extends "res://tests/player_magic_handoff_test.gd"
const Items=preload("res://scripts/lol2/player_item_state.gd")
func run() -> void:
	var path := "user://tests/player_item_live.json"
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum)
	current_scene=museum
	await process_frame
	museum.set_physics_process(false)
	museum.item_effects.set_process(false)
	museum.sword_transfer.set_process(false)
	# Pick up both actual source objects; only the local approach is supplied.
	for i in range(2):
		var sprite: Sprite3D=museum.champion_stones.sprites[i]
		museum.player.position=sprite.position+Vector3(90 if i==0 else -23,-18,0)
		museum.camera.look_at(sprite.position+Vector3(0,3.5,0))
		await physics_frame
		await physics_frame
		if not museum.take_stone(i):
			var target: Vector3 = sprite.global_position+Vector3(0,3.5,0)
			var query = PhysicsRayQueryParameters3D.create(museum.camera.global_position,target)
			query.exclude = [museum.player.get_rid()]
			print("Stone pickup diagnostic: ", {"index":i,"camera":museum.camera.global_position,"target":target,"distance":museum.camera.global_position.distance_to(target),"aim":(-museum.camera.global_basis.z).dot((target-museum.camera.global_position).normalized()),"paused":paused,"visible":sprite.visible,"owned":museum.carried_collected,"ray":museum.get_world_3d().direct_space_state.intersect_ray(query)})
			check(false,"Cannot collect source stone")
			return
	if not check(museum.open_inventory(),"Cannot open stone inventory"): return
	museum.inventory.select_item(0)
	if not check(museum.inventory.use_button.visible,"Stone use button absent"): return
	museum.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	var id: String=museum.Stones.IDS[0]
	if not check(id not in museum.carried_collected and museum.item_effect_checkpoint.spent==[id],"Stone was not consumed"): return
	if not check(museum.item_effect_checkpoint.champion.active and museum.item_effects.melee_damage(8)==28,"Champion bonus absent"): return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	museum.item_effects.advance(10)
	var partial: Dictionary=museum.item_effect_checkpoint.duplicate(true)
	if not check(partial.champion.timer==3000*65536,"Modern60 tick timer did not advance"): return
	if not check(museum.open_inventory(),"Cannot reopen inventory"): return
	museum.item_effects.advance(20)
	if not check(museum.item_effect_checkpoint==partial,"Inventory did not suspend timer"): return
	museum.inventory.close()
	await process_frame
	await process_frame
	if not check(museum.quicksave(path).is_empty(),"Cannot save active stone"): return
	Items.advance(museum.item_effect_checkpoint,60)
	if not check(museum.quickload(path).is_empty() and museum.item_effect_checkpoint==partial,"Active stone rollback failed"): return
	museum.set_physics_process(false)
	if not check(not museum.champion_stones.sprites[0].visible and not museum.champion_stones.sprites[1].visible,"Consumed stone respawned after load"): return
	var invalid: Dictionary=museum.checkpoint_state()
	invalid.collected.append(id)
	if not check(not museum.Save.validate({"format":museum.Save.FORMAT,"version":1,"checkpoint":invalid,"player":{}}).is_empty(),"Consumed owned duplicate accepted"): return
	var inventory: Dictionary=museum.inventory_state()
	await finish(museum)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene=jungle
	await process_frame
	jungle.set_physics_process(false)
	jungle.item_effects.set_process(false)
	if not check(jungle.apply_inventory_handoff(inventory).is_empty() and jungle.item_effect_checkpoint==partial,"Museum/Jungle effect transport failed"): return
	if not check(jungle.quicksave(path).is_empty(),"Jungle stone save failed"): return
	Items.advance(jungle.item_effect_checkpoint,60)
	if not check(jungle.quickload(path).is_empty() and jungle.item_effect_checkpoint==partial,"Jungle stone rollback failed"): return
	var transfer: Dictionary=jungle.area_handoff()
	await finish(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	current_scene=hive
	await process_frame
	hive.set_physics_process(false)
	hive.item_effects.set_process(false)
	if not check(hive.apply_area_handoff(transfer).is_empty() and hive.item_effects.state()==partial,"Jungle/Hive effect transport failed"): return
	# Consume the second stone through the actual inventory signal. Extend, don't stack.
	if not check(hive.open_inventory(),"Hive stone inventory unavailable"): return
	hive.player_form=1
	if not check(not hive.item_effects.use(hive.Save.Shared.Museum.STONES[1]) and hive.item_effects.melee_damage(12)==32,"Curse lost an active bonus or admitted stone use"): return
	hive.player_form=2
	if not check(hive.item_effects.melee_damage(1)==21,"Lizard lost an already-active bonus"): return
	hive.player_form=0
	hive.inventory.select_item(0)
	hive.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	if not check(hive.item_effects.state().champion.timer==6600*65536 and hive.item_effects.melee_damage(8)==28,"Second stone did not extend without stacking"): return
	var live=hive.executioner_live
	live.set_physics_process(false)
	hive.get_node("Nest").chasm_handoff()
	hive.get_node("Nest").set_physics_process(false)
	var guards=hive.get_node("Warriors")
	guards.set_process(false)
	hive.carried_inventory.collected.append(hive.Save.Shared.Museum.SWORD)
	hive.carried_inventory.equipped_item=hive.Save.Shared.Museum.SWORD
	hive.player.position=live.SPAWN+Vector3(0,32,65)
	hive.camera.look_at(live.body.global_position)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in range(3): await physics_frame
	live.present()
	for i in range(2): await physics_frame
	if not check(guards.strike() and live.state.health==272,"Live melee did not use temporary attack bonus"): return
	if not check(hive.quicksave(path).is_empty(),"Hive effect save failed"): return
	Items.advance(hive.item_effects.state(),111)
	if not check(hive.item_effects.melee_damage(8)==8,"Expired stone kept bonus"): return
	guards.cooldown=0
	if not check(guards.strike() and live.state.health==264,"Expired stone did not restore baseline melee"): return
	if not check(hive.quickload(path).is_empty() and live.state.health==272 and hive.item_effects.melee_damage(8)==28,"Hive effect/combat rollback failed"): return
	await finish(hive)
	DirAccess.remove_absolute(path)
	print("PASS: source stone pickups, inventory consumption, no respawn, timer suspension/extension/expiry, three-area saves and live melee")
	quit()
