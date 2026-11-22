extends "res://tests/l20_pillars_scotia_earned_test.gd"
## Walk the chasm deck, then ride the carrier across the gap. The five shots are
## the east-lip clicks. Trinity is the Prism 5 cast (Shift+Q). The south lip is a different
## nav component from the pillar room, so the ride starts by standing there.

func settle(scene: Node, count: int) -> void:
	var pillars = scene.get_node("L20PillarsScotia")
	for _i in count:
		pillars.advance(scene.player.get_physics_process_delta_time())
		scene.move_grounded(Vector3.ZERO, scene.player.get_physics_process_delta_time())
		await physics_frame

func walk_to(scene: Node, goal: Vector3, limit: int, tol: float) -> bool:
	var reached := false
	var prior: Vector3 = scene.player.position
	var stalled := 0
	for tick in limit:
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0
		if delta.length() < tol and scene.player.is_on_floor():
			reached = true
			break
		if scene.player.position.distance_to(prior) < 0.05:
			stalled += 1
		else:
			stalled = 0
		prior = scene.player.position
		if stalled == 40:
			for hit_i in scene.player.get_slide_collision_count():
				var hit = scene.player.get_slide_collision(hit_i)
				print("CROSS HIT ", hit.get_collider().get_path(), " normal ", hit.get_normal(), " at ", scene.player.position)
			stalled = 0
		var pillars = scene.get_node("L20PillarsScotia")
		pillars.advance(scene.player.get_physics_process_delta_time())
		scene.move_grounded(delta.normalized() if delta.length() > 0.1 else Vector3.ZERO, scene.player.get_physics_process_delta_time())
		await physics_frame
		if tick % 400 == 0:
			print("CROSS ", scene.player.position, " goal ", goal)
	return reached

func run():
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l20_dawn_curse_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned mother save"):
		quit(1)
		return
	var input = Save.read_save(path, "lol2-restoration-map-L20_BB")
	if not check(input.error.is_empty(), str(input.error)):
		quit(1)
		return
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned mother input"):
		await stop(scene, 1)
		return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Explicit teaching fixture (as the parent since cf4b375): old input predates the scroll/book contract.
	if not check(scene.starting_magic.learn_spell_group("prism"), "Legacy Prism teaching fixture"):
		await stop(scene, 1)
		return
	await key(KEY_5)
	var pillars = scene.get_node("L20PillarsScotia")
	scene.player_form = 0
	scene.equipped_item = "act2:L13_RC:dark_sword"
	for id in pillars.FIRE:
		aim_lip(scene, pillars, int(id))
		await physics_frame
		await click()
		if not check(int(id) in shot_ids(pillars), "pillar %d click from the east lip" % int(id)):
			await stop(scene, 1)
			return
	var on_lip: bool = scene.player.position.distance_to(pillars.LIP) < 1.0
	if not check(on_lip and shot_ids(pillars).size() == 5 and pillars.opens_path() and not pillars.moves_pillars() and pillars.deck_ready(), "five shots open the deck before Trinity"):
		await stop(scene, 1)
		return
	scene.player.position = pillars.DECK_FROM + Vector3(0, 40, 0)
	scene.player.velocity = Vector3.ZERO
	await settle(scene, 60)
	if not check(await walk_to(scene, pillars.DECK_TO, 6000, 10.0), "chasm deck to the pillar floor at %s" % str(scene.player.position)):
		await stop(scene, 1)
		return
	if not check(scene.player.position.x < -3330.0 and scene.player.position.y < -10.0 and scene.player.is_on_floor() and scene.resets == 0, "stood on the far floor %s" % str(scene.player.position)):
		await stop(scene, 1)
		return
	scene.player.position = pillars.SCOTIA_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	await process_frame
	await key(KEY_Q, true) # Trinity is Prism 5 through the shared caster since cf4b375 (no longer E).
	if not check(bool(pillars.state().trinity) and pillars.moves_pillars(), "Trinity starts the carrier"):
		await stop(scene, 1)
		return
	scene.player.position = pillars.GAP_FROM + Vector3(0, 40, 0)
	scene.player.velocity = Vector3.ZERO
	await settle(scene, 60)
	var boarded := false
	for wait_i in 8000:
		if pillars.carrier_docked_south():
			if await walk_to(scene, Vector3(pillars.CARRIER_X, 0, pillars.CARRIER_SOUTH_Z), 1200, 8.0):
				var on_slab: bool = scene.player.is_on_floor() and absf(scene.player.position.x - pillars.CARRIER_X) <= 12.0 and absf(scene.player.position.z - pillars.carrier_z()) <= 18.0
				if on_slab:
					boarded = true
					break
			scene.player.position = pillars.GAP_FROM + Vector3(0, 40, 0)
			scene.player.velocity = Vector3.ZERO
			await settle(scene, 20)
		pillars.advance(scene.player.get_physics_process_delta_time())
		scene.move_grounded(Vector3.ZERO, scene.player.get_physics_process_delta_time())
		await physics_frame
		if wait_i % 400 == 0:
			print("DOCK ", pillars.carrier_z(), " player ", scene.player.position, " leg ", pillars.leg, " gap ", pillars.gap_open)
	if not check(boarded, "boarded the carrier at the south lip %s" % str(scene.player.position)):
		await stop(scene, 1)
		return
	var rode := false
	for ride_i in 8000:
		var delta: float = scene.player.get_physics_process_delta_time()
		pillars.advance(delta)
		var step := Vector3.ZERO
		var north_pause: bool = pillars.leg == 2 and absf(pillars.carrier_z() - pillars.CARRIER_NORTH_Z) < 2.0
		if north_pause:
			# Step clear of the slab onto the north floor while it waits. The capsule radius is 8 and the slab ends at z=-3600.
			var shore := Vector3(pillars.CARRIER_X, 0.0, -3560.0)
			if scene.player.position.z > -3590.0 and scene.player.is_on_floor() and absf(scene.player.position.x - pillars.CARRIER_X) < 16.0:
				rode = true
				break
			var flat := Vector3(shore.x - scene.player.position.x, 0, shore.z - scene.player.position.z)
			step = flat.normalized() if flat.length() > 0.1 else Vector3.ZERO
		scene.move_grounded(step, delta)
		await physics_frame
		if ride_i % 400 == 0:
			print("RIDE ", scene.player.position, " carrier ", pillars.carrier_z(), " leg ", pillars.leg, " gap ", pillars.gap_open)
	if not check(rode and scene.resets == 0, "rode the carrier onto the north shore %s" % str(scene.player.position)):
		await stop(scene, 1)
		return
	var stayed := false
	for leave_i in 8000:
		pillars.advance(scene.player.get_physics_process_delta_time())
		scene.move_grounded(Vector3.ZERO, scene.player.get_physics_process_delta_time())
		await physics_frame
		if pillars.carrier_z() < -3700.0 and scene.player.position.z > -3590.0 and scene.player.is_on_floor():
			stayed = true
			break
		if leave_i % 400 == 0:
			print("LEAVE ", scene.player.position, " carrier ", pillars.carrier_z(), " resets ", scene.resets)
	if not check(stayed and scene.resets == 0, "stayed on the north shore after the carrier left %s carrier %s" % [str(scene.player.position), str(pillars.carrier_z())]):
		await stop(scene, 1)
		return
	var save := "res://tmp/l20_pillar_cross_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "cross save"):
		await stop(scene, 1)
		return
	if not check(scene._quickload_unrecorded(save).is_empty(), "cross reload"):
		await stop(scene, 1)
		return
	pillars = scene.get_node("L20PillarsScotia")
	await process_frame
	if not check(pillars.opens_path() and pillars.moves_pillars() and pillars.deck_ready() and scene.player.position.z > -3610.0, "save keeps the crossing %s" % str(scene.player.position)):
		await stop(scene, 1)
		return
	print("PASS earned chasm deck and the carrier to the armory shore")
	await stop(scene, 0)
