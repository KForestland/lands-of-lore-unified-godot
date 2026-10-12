extends "res://tests/hive_reaver_amber_live_test.gd"
## Supplied grounded pickup vantage; after E only production grounded movement and real engine clocks.
func walk_to(point: Vector3) -> bool:
	for tick in 900:
		await physics_frame
		var offset:=Vector2(point.x-hive.player.position.x,point.z-hive.player.position.z)
		if offset.length()<3:return true
		var delta: float=hive.player.get_physics_process_delta_time()
		var direction: Vector2=offset.normalized()*minf(1.0,offset.length()/(80.0*delta))
		hive.move_grounded(Vector3(direction.x,0,direction.y),delta)
	return check(false,"Grounded escape blocked at %s heading to %s"%[hive.player.position,point])
func run() -> void:
	hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive
	for i in 10:await process_frame
	hive.set_physics_process(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;owner=hive.reaver_amber
	if not check(await view("121",["365","366"]),"Grounded Reaver pickup vantage"):return
	await press_e()
	if not check(State.REAVER in hive.carried_inventory.collected,"Actual Reaver E"):return
	var before: float=owner.state.reaver.timer
	for i in 20:await physics_frame
	if not check(owner.state.reaver.timer<before-0.2,"Engine did not advance Reaver timer"):return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await physics_frame
	var paused: float=owner.state.reaver.timer
	for i in 15:await physics_frame
	if not check(owner.state.reaver.timer==paused,"Inactive cursor advanced collapse timer"):return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Convex source regions form this corridor. Walk center to shared portal to next center.
	if not await walk_to(center("365")):return
	for region in range(365,371):
		var shared: Array=[]
		for point in owner.source.regions[str(region)].polygon:
			if point in owner.source.regions[str(region+1)].polygon:shared.append(point)
		if not check(shared.size()==2,"Expected shared source portal"):return
		var portal:=Vector3((shared[0][0]+shared[1][0])/2.0,-235,(shared[0][1]+shared[1][1])/2.0)
		if not await walk_to(portal):return
		if not await walk_to(center(str(region+1))):return
	if not check(owner._player_in("371") and hive.player.is_on_floor(),"Escape did not reach safe grounded region371"):return
	var deadline:=Time.get_ticks_msec()+20000
	while State.height(owner.state,366,"ceiling")>=State.ORIGINAL.ceiling:
		await physics_frame
		if not check(Time.get_ticks_msec()<deadline,"Automatic collapse did not follow player"):return
	# Equip through the actual inventory; the original definition contributes negative50 defense.
	if not check(hive.open_inventory(),"Reaver inventory open"):return
	await process_frame
	var inventory=hive.inventory;var selected:=-1
	for i in inventory.item_list.item_count:
		if str(inventory.item_list.get_item_metadata(i))==State.REAVER:selected=i
	if not check(selected>=0,"Reaver inventory entry"):return
	inventory.select_item(selected)
	if not check("50" in inventory.detail_text.text,"Reaver defense penalty not explained"):return
	inventory.toggle_equipment();await process_frame
	if not check(hive.equipped_item==State.REAVER and preload("res://scripts/lol2/player_defense.gd").scalar(hive)==-50,"Equipped Reaver defense contribution"):return
	inventory.queue_free();await process_frame;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(hive.quicksave("user://tests/reaver_escaped.json").is_empty() and hive.quickload("user://tests/reaver_escaped.json").is_empty(),"Escaped checkpoint roundtrip"):return
	if not check(owner._player_in("371") and State.REAVER in hive.carried_inventory.collected and hive.equipped_item==State.REAVER,"Reload lost escape or Reaver"):return
	print("PASS hive_reaver_escape: supplied pickup vantage, actual E, live timer/pause, production grounded movement through six source portals without repositioning after pickup, ceiling follows, safe region371, disk reload.")
	quit()
