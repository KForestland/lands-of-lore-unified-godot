extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for frame in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready and cave.lava.regions.size()==86)
	var region: Dictionary
	for candidate in cave.lava.regions:
		if candidate.id==1471: region=candidate
	var center := Vector2.ZERO
	for vertex in region.polygon: center += vertex/region.polygon.size()
	var contact := Vector3(center.x,region.floor+32,center.y)
	assert(cave.lava.contact(contact,true)==1471)
	assert(cave.lava.contact(contact,false)==-1)
	assert(cave.lava.contact(contact+Vector3.UP*20,true)==-1)
	assert(cave.lava.contact(Vector3(-589,-177,-9529),true)==-1,"Earlier water pool is not lava")
	assert(cave.lava.contact(Vector3(500,-398,-13200),true)==-1,"Nearby rock is not lava")
	for id in [807,808,816,818,821,1078,1082]:
		assert(not cave.lava.regions.any(func(entry): return entry.id==id),"Other unresolved materials are not lava")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in range(20): await physics_frame
	var path := "user://tests/lava_%d.json" % Time.get_ticks_usec()
	assert(cave._quicksave(path).is_empty())
	cave.flying = true
	cave.player.global_position = contact+cave.native_translation
	for frame in range(5): await physics_frame
	assert(cave.roach.model.player_health==30,"Diagnostic flight bypasses ground hazards")
	cave.flying = false
	cave.player.global_position = contact+cave.native_translation+Vector3.UP*2
	cave.player.velocity = Vector3.ZERO
	for frame in range(60):
		await physics_frame
		if cave.roach.model.player_health==0: break
	assert(cave.roach.model.player_health==0,"Physical landing on source lava must kill")
	assert(cave.save_notice.begins_with("The lava killed you."))
	assert(not cave._quicksave(path).is_empty(),"Death cannot overwrite the living save")
	var reset := InputEventKey.new()
	reset.keycode = KEY_R
	reset.pressed = true
	cave._unhandled_input(reset)
	await physics_frame
	assert(cave.roach.model.player_health==30)
	assert(cave._quickload(path).is_empty() and cave.roach.model.player_health==30)
	DirAccess.remove_absolute(path)
	cave.free()
	print("PASS 86 source lava floors: contact death, water/rock/other-placeholder exclusion, airborne/flight exclusion, death-save rejection, reset/load recovery")
	quit()
