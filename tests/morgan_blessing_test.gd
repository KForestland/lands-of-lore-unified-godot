extends SceneTree
const Blessing = preload("res://scripts/lol2/morgan_orb_blessing.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize(): run.call_deferred()
func run():
	var oracle = JSON.parse_string(FileAccess.get_file_as_string("res://docs/morgan-orb-blessing-checks.json"))
	for c in oracle.health_cases.cases:
		assert(Blessing.heal(int(c.current),int(c.maximum),int(c.flags229)) == int(c.after))
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	for room in [scene.monastery,scene.weapon_shop,scene.magic_shop,scene.departure]: room.set_process(false)
	var rooms = scene.monastery
	# Supplied original repeat-visit state; real orb earning is checked separately.
	scene.carried_collected = [Speech.ORB]
	scene.health = 5
	rooms.state().flags["258"] = 1
	rooms.state().flags["260"] = 1
	assert(rooms.enter_room("MENT") and rooms.enter_room("MGAR"))
	assert(rooms.state().side_actor_present)
	rooms.advance(1000)
	assert(rooms.offer_item(Speech.ORB))
	assert(Speech.ORB not in scene.carried_collected and scene.health == 5)
	assert(rooms.state().flags.get("259",0) == 0)
	assert(str(rooms.view.clip.name).ends_with("2325407E.VQA"))
	rooms.advance(Speech.duration("MGAR_ORB",0)+0.2)
	var path = "user://tests/morgan_blessing.json"
	assert(scene.quicksave(path).is_empty())
	rooms.advance(1000)
	assert(scene.health == 25 and scene.carried_collected.count(Speech.ORB) == 1 and rooms.state().flags["259"] == 1)
	assert(scene.quickload(path).is_empty())
	assert(scene.health == 5 and Speech.ORB not in scene.carried_collected)
	rooms.advance(1000)
	assert(scene.health == 25 and scene.carried_collected.count(Speech.ORB) == 1)
	assert(rooms.offer_item(Speech.ORB))
	assert(rooms.state().conversation.sequence == "MGAR_ORB_REFUSE")
	rooms.advance(1000)
	assert(scene.health == 25 and scene.carried_collected.count(Speech.ORB) == 1)
	rooms.leave_room()
	assert(rooms.enter_room("MGAR") and not rooms.state().side_actor_present)
	assert(not rooms.offer_item(Speech.ORB))
	rooms.leave_room()
	rooms.leave_room()
	assert(scene.Save.validate_inventory(scene.inventory_state()).is_empty())
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS:400 native health cases, owned-orb Morgan presence, delayed healing/orb return, partial save rollback, same-visit refusal and next-visit absence")
	quit()
