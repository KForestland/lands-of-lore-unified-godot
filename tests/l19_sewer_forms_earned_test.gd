extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func ids_of(node: Node) -> Array:
	var out: Array = []
	for id in node.state().switches:
		out.append(int(id))
	return out

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l19_belial_horn_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned horn save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned horn input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	var forms = scene.get_node("L19SewerForms")
	var horn = scene.get_node("L19BelialHorn")
	if not check(bool(horn.state().taken), "horn save still carries the horn"):
		await stop(scene, 1); return
	scene.player.position = forms.DOOR_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	var before: Vector3 = scene.player.position
	await process_frame
	await process_frame
	if not check(not forms.moves_door() and scene.player.position.distance_to(before) < 1.0 and forms.BARS == -1, "Human at the sewer door does not move it"):
		await stop(scene, 1); return
	scene.player.position = forms.AT_74
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 2
	await process_frame
	await process_frame
	if not check(bool(forms.state().lizard_at_wall) and ids_of(forms).is_empty() and forms.GUTTER == -1, "Lizard is checked and the gutter stays unbound"):
		await stop(scene, 1); return
	scene.player_form = 1
	scene.player.position = forms.AT_75
	await process_frame
	await process_frame
	if not check(ids_of(forms).is_empty(), "Beast form does not record a slot"):
		await stop(scene, 1); return
	scene.player_form = 0
	for point in [forms.AT_74, forms.AT_75, forms.AT_76]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await process_frame
	var got: Array = ids_of(forms)
	var slots: bool = got.size() == 3 and int(got[0]) == 74 and int(got[1]) == 75 and int(got[2]) == 76
	if not check(slots, "Human records switches 74, 75, and 76"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_sewer_forms_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "forms save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "forms reload"):
		await stop(scene, 1); return
	forms = scene.get_node("L19SewerForms")
	await process_frame
	if not check(ids_of(forms).size() == 3 and bool(forms.state().lizard_at_wall), "save keeps the form checks"):
		await stop(scene, 1); return
	print("PASS earned sewer form checks from the horn save")
	await stop(scene, 0)
