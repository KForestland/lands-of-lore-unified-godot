extends SceneTree
const State = preload("res://scripts/lol2/hive_elevator_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error(message)
	quit(1)
	return false
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func aim(scene: Node3D, point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
func settle(scene: Node3D, frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	var state := State.initial()
	assert(State.play_flute(state))
	State.advance(state,2.0)
	assert(not state.played_flute) # A tune outside the armed room is insufficient.
	State.enter_trigger(state,282)
	assert(state.armed and state.flute_signal == 0)
	assert(State.play_flute(state))
	State.advance(state,0.5)
	assert(not state.played_flute)
	State.enter_trigger(state,283)
	State.advance(state,2.0)
	assert(not state.played_flute and not state.armed)
	State.enter_trigger(state,282)
	State.play_flute(state)
	assert(State.advance(state,1.0))
	assert(state.played_flute and state.flute_signal == 2 and not State.play_flute(state))
	assert(State.validate(JSON.parse_string(JSON.stringify(state))).is_empty())
	for bad in [-1,8,0.5,"0",null,true,NAN,INF]:
		var invalid := state.duplicate(true)
		invalid.target = bad
		assert(not State.validate(invalid).is_empty())
	var coarse := State.initial()
	coarse.height = -1003.0
	coarse.target = 4
	State.enter_trigger(coarse,282)
	State.play_flute(coarse)
	coarse.poll_elapsed = 0.5
	var fine := coarse.duplicate(true)
	State.advance(coarse,2.0)
	for tick in range(20): State.advance(fine,0.1)
	assert(is_equal_approx(coarse.height,fine.height) and is_equal_approx(coarse.height,-859.0))
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	var lift = scene.elevator
	# Local lift fixture. The route from the monastery is a separate acceptance gate.
	scene.player.position = Vector3(-2564.5,-203,-7614.5)
	await settle(scene,10)
	if not check(scene.player.is_on_floor(),"Lift did not ground player"): return
	aim(scene,lift.aim_point(125))
	if not check(lift.target_control()==125,"Source lift control is unreachable from platform"): return
	if "--capture-lift" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hive_lift.png")
	key(KEY_E)
	if not check(lift.checkpoint.target==1,"E did not request second source stop"): return
	await settle(scene,50)
	if not check(lift.checkpoint.height < -235 and lift.checkpoint.height > -427,"Lift failed to advance partially"): return
	var path := "user://tests/hive_lift_%d.json" % Time.get_ticks_usec()
	if not check(scene.quicksave(path).is_empty(),"Mid-lift save failed"): return
	var height: float = lift.checkpoint.height
	var player_y: float = scene.player.position.y
	await settle(scene,20)
	if not check(scene.quickload(path).is_empty(),"Mid-lift load failed"): return
	scene.set_physics_process(false)
	if not check(is_equal_approx(lift.checkpoint.height,height) and is_equal_approx(scene.player.position.y,player_y),"Lift/player rollback mismatch"): return
	await settle(scene,150)
	if not check(is_equal_approx(lift.checkpoint.height,-427.0),"Lift failed to reach stop1"): return
	if not check(absf(scene.player.position.y-32.0-lift.checkpoint.height)<0.2,"Player failed to ride lift: " + str(scene.player.position)): return
	# Continue down all eight source levels with no player repositioning.
	for stop in range(2,8):
		aim(scene,lift.aim_point(125))
		key(KEY_E)
		if not check(lift.checkpoint.target==stop,"Lift control failed at stop"+str(stop)): return
		await settle(scene,150)
		if not check(is_equal_approx(lift.checkpoint.height,State.STOPS[stop]) and absf(scene.player.position.y-32.0-State.STOPS[stop])<0.2,"Ride mismatch at stop"+str(stop)+": "+str(scene.player.position)): return
	if not check(scene.omitted_lift_walls == 16,"Unexpected platform wall filter count"): return
	# Check all eight sides at every stop, crossing only the platform perimeter.
	# These rays previously hit the static column exported around the floor.
	for stop_height in State.STOPS:
		for edge in range(scene.LIFT_PERIMETER.size()):
			var midpoint: Vector2 = (scene.LIFT_PERIMETER[edge]+scene.LIFT_PERIMETER[(edge+1)%8])*0.5
			var outward: Vector2 = (midpoint-Vector2(-2564.5,-7614.5)).normalized()
			var inside: Vector2 = midpoint-outward*12.0
			var outside: Vector2 = midpoint+outward*12.0
			var ray := PhysicsRayQueryParameters3D.create(Vector3(inside.x,stop_height+42,inside.y),Vector3(outside.x,stop_height+42,outside.y))
			ray.exclude = [scene.player.get_rid()]
			if not check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Platform enclosed at height %s edge %s" % [stop_height,edge]): return
	if "--capture-lift" in OS.get_cmdline_user_args():
		aim(scene,Vector3(-2371,-1500,-7536))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hive_lift_lower.png")
	# Upper call button invokes its source stop while a player is elsewhere.
	var saved: Dictionary = scene.area_handoff()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await process_frame
	if not check(jungle.apply_area_handoff(saved).is_empty(),"Jungle rejected lift handoff"): return
	if not check(jungle.area_handoff().quests.hive_elevator == saved.quests.hive_elevator,"Jungle lost lift state"): return
	jungle.free()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.quests.hive_elevator.height = -2000
	if not check(not scene.apply_area_handoff(invalid).is_empty(),"Malformed lift state accepted"): return
	if not check(lift.checkpoint == saved.quests.hive_elevator,"Failed load mutated lift"): return
	# Exercise actual source arm/exit polygons and inventory button.
	scene.player.position = Vector3(-1935,-203,-7620)
	await settle(scene,2)
	if not check(lift.checkpoint.armed,"Source region282 did not arm flute check"): return
	scene.carried_inventory.collected.append(Speech.FLUTE)
	if not check(scene.open_inventory(),"Flute inventory did not open"): return
	scene.inventory.select_item(0)
	if not check(scene.inventory.use_button.visible,"Flute use unavailable"): return
	scene.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	await settle(scene,80)
	if not check(lift.checkpoint.played_flute and lift.checkpoint.flute_signal==2 and lift.checkpoint.target==0,"Armed flute did not request source sequence"): return
	if not check(Speech.FLUTE in scene.carried_inventory.collected,"Flute incorrectly consumed"): return
	DirAccess.remove_absolute(path)
	scene.free()
	print("PASS: eight-stop lift ride, original control, mid-motion disk rollback, Jungle carry, malformed save, source flute trigger and inventory use")
	quit()
