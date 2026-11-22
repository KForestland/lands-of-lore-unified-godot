extends "res://tests/generic_l13_chain_input_test.gd"
## A legacy game-written Dawn save is a disclosed component setup. Movement
## and jump admission are real keys, ordinary1/60; no supplied jump/pose/health.
const DAWN := "res://tmp/g03_l13_inputs/dawn_legacy.json"
const DAWN_SHA := "d6fa35d0d0cb99fc87303a651b33c4011c062df49fb1aaa29c006e900abf8e3d"
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock pink ledge proof"): return
	if not require(FileAccess.get_sha256(DAWN) == DAWN_SHA, "Untouched legacy Dawn component checkpoint"): return
	var route: Dictionary = fixture("l13_pink_steps_walk.json")
	if OS.get_environment("LOL2_PINK_BASE") != "0": # real start by default (lead 2026-11-15 14:33Z); 0 = the old Dawn-direct component load
		if not await start_from_f2(): return
		var path := "res://tmp/g03_l13_inputs/pink_base_f5.json"
		if not require(FileAccess.get_sha256(path) == "2564c6e32af3fda29a688d19e4c2f38873759549ab92e6a8ce9a2c87402e6195", "Untouched actualF5 pink-base pin"): return
		if not require(DirAccess.copy_absolute(path, Slots.slot_path(1)) == OK, "Install actualF5 pink-base component slot"): return
		await tap(KEY_F9); await adopt()
	else:
		var saved := preload("res://scripts/lol2/act2_save.gd").read_save(DAWN, "lol2-restoration-map-L13_RC")
		if not require(saved.error.is_empty(), "Legacy Dawn save is valid"): return
		scene = load("res://scenes/lol2/maps/L13_RC.tscn").instantiate()
		scene.adapter_exit_seeds = false
		root.add_child(scene); current_scene = scene
		for tick in 3000:
			await process_frame
			if scene.ready_for_review: break
		if not require(scene.apply_save(saved.state).is_empty(), "Disclosed legacy component load, no edited fields"): return
		await adopt()
		if not captured(): await lclick(); await frames(4)
		if not await walk(route.points, "Dawn to original pink ledges"): await picture("pink_approach_stop"); quit(1); return
		if not await checkpoint("g03_pink_base_f5"): return
	for index in route.steps.size():
		var step: Dictionary = route.steps[index]
		var region: Array = scene.progression.regions[int(step.region)]
		var poly := PackedVector2Array()
		for vertex: Array in region[0]: poly.append(Vector2(vertex[0], vertex[1]))
		var edge := Vector2(step.point[0], step.point[1])
		# The fixture is 10% along the outer edge. Keep that lane, eight
		# units inward instead of the legacy test's eight units outside it.
		var inner := poly[1].lerp(poly[2], 0.1)
		var target := edge + (inner - edge).normalized() * 8.0
		if not require(Geometry2D.is_point_in_polygon(target, poly), "Pink landing lies inside source tread"): return
		var landed := false
		var peak := pos().y
		for attempt in 5:
			key_event(KEY_W, false); key_event(KEY_SHIFT, false)
			for tick in 120:
				if scene.player.is_on_floor(): break
				await physics_frame
			await look(Vector3(target.x, pos().y, target.y))
			if index >= 2:
				key_event(KEY_W, true); key_event(KEY_SHIFT, true)
				for tick in 6: await physics_frame
			print("PINK LAUNCH step=",index," attempt=",attempt," at=",pos()," grounded=",scene.player.is_on_floor())
			key_event(KEY_SPACE, true); await physics_frame; key_event(KEY_SPACE, false)
			for tick in 120:
				var delta := target - Vector2(pos().x, pos().z)
				turn_step(Vector3(target.x, scene.camera.global_position.y, target.y), false)
				var moving: bool = (index >= 2 or tick >= 12) and delta.length() > 1.5
				key_event(KEY_W, moving); key_event(KEY_SHIFT, moving)
				await physics_frame
				peak = maxf(peak, pos().y)
				if index == 2 and (tick < 16 or tick % 30 == 0):
					var contacts := []
					for hit in scene.player.get_slide_collision_count():
						var c = scene.player.get_slide_collision(hit)
						contacts.append({"normal":str(c.get_normal()),"point":str(c.get_position()),"body":str(c.get_collider().get_path())})
					print("PINK CONTACT tick=",tick," at=",pos()," velocity=",scene.player.velocity," grounded=",scene.player.is_on_floor()," contacts=",contacts)
				if scene.resets != 0 or hp() <= 0: break
				# A grounded landing above the requested tread also reaches it;
				# rounded capsule contact can already support the next corner.
				if scene.player.is_on_floor() and pos().y - 32.0 >= float(step.height) - 8.0 and delta.length() < 12.0:
					landed = true; break
			key_event(KEY_W, false); key_event(KEY_SHIFT, false)
			if landed or scene.resets != 0 or hp() <= 0: break
		print("PINK INPUT step=", index, " region=", step.region, " target=", target, " height=", step.height, " position=", pos(), " peak=", peak, " landed=", landed)
		if not landed:
			await picture("pink_stop_" + str(index))
			if not require(false, "Real Space/W landing on pink ledge " + str(index)): return
	await picture("pink_all_ledges")
	if not await walk(route.top, "Pink top to plate approach"): await picture("pink_top_stop"); quit(1); return
	if not require(scene.resets == 0 and hp() > 0, "Pink route stays living without recovery"): return
	print("PASS real Space/W/Shift on all21original50-high pink treads; interior source landings, ordinary1/60, disclosed legacy load only,0resets")
	quit()
