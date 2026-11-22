extends "res://tests/l12_logs_approach_earned_test.gd"
## BJ09: the NE lift's own save -> walk the starry-tower stairs down to floor 0.
## The box, the disk, and the yellow figure have no placements, so this sitting stops here.
func run():
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_ne_tower_chain_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned NE tower chain save"):
		quit(1)
		return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)):
		quit(1)
		return
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not check(scene.apply_save(input.state).is_empty(), "earned NE tower chain input"):
		quit(1)
		return
	prepare(scene)
	var tower = scene.get_node("L16NeTower")
	if not check(bool(tower.state().at_doors), "lift already taken"):
		quit(1)
		return
	var stairs: Array = [[15933.0, 3742.5], [15925.0, 3645.5], [15843.0, 3652.5], [15754.5, 3683.5], [15661.0, 3752.0], [15604.5, 3818.0], [15568.0, 3902.0], [15547.5, 4000.5], [15549.5, 4097.0], [15558.0, 4138.0]]
	if not await walk(scene, stairs, "starry stairs to floor 0"):
		quit(1)
		return
	var pos: Vector3 = scene.player.position
	var region: int = int(scene.progression.region_at(pos))
	print("STARRY ", pos, " region ", region, " resets ", scene.resets)
	var on_floor: bool = pos.x > 15000.0 and pos.y > 20.0 and pos.y < 50.0 and scene.resets == 0
	if not check(on_floor, "still on the starry floor"):
		quit(1)
		return
	var save := "res://tmp/l16_starry_floor_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "starry floor save"):
		quit(1)
		return
	if not check(scene._quickload_unrecorded(save).is_empty(), "starry floor reload"):
		quit(1)
		return
	pos = scene.player.position
	var stayed: bool = pos.x > 15000.0 and scene.resets == 0 and bool(scene.get_node("L16NeTower").state().at_doors)
	if not check(stayed, "reload keeps the starry floor"):
		quit(1)
		return
	print("STARRY RELOAD ", pos, " region ", int(scene.progression.region_at(pos)))
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("PASS earned NE lift -> starry stairs -> floor 0 save/reload")
	quit(0 if failures == 0 else 1)
