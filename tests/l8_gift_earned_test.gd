extends SceneTree
const Save = preload("res://scripts/lol2/act2_save.gd")
const State = preload("res://scripts/lol2/l8_journey_state.gd")
const INPUT := "~/AI_COMMS/act1_completion_20261017/r12w_qualification/campaign/userdata/act1_dark_halls_darker_arrival.json"
const HASH := "065d4b814569c069490c0b4625177862918b2798ea504acf6ae89172b83baa92"
var failures := 0
func check(ok: bool, message: String) -> bool:
	if not ok: failures+=1; printerr("FAIL L8 earned gift: ",message)
	return ok
func _initialize(): run.call_deferred()
func run():
	if not check(FileAccess.get_sha256(INPUT)==HASH,"pinned earned Act1 arrival"): quit(1); return
	var source := Save.read_save(INPUT,"lol2-restoration-darker-jungle")
	if not check(source.error.is_empty(),"earned save validates: " + source.error): quit(1); return
	set_meta("lol2_darker_resume",source.state)
	Engine.set_meta("lol2_enhanced",false)
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review,"production scene ready"): quit(1); return
	scene.player.set_physics_process(false)
	var journey = scene.get_node_or_null("L8Journey")
	if not check(journey!=null,"production encounter attached"): quit(1); return
	await approach_entry(scene,journey)
	if not check(journey.target()=="entry","walk from earned arrival reaches Daniel without teleport"): quit(1); return
	var before: Array = scene.carried_collected.duplicate()
	check(not journey.interact("offer_daniel","wrong").ok and scene.carried_collected==before,"wrong offer preserves earned inventory")
	var path := "res://tmp/l8_gift_earned_test_save.json"
	for action in ["offer_daniel","hopper_interruption","recover_blade"]:
		var result: Dictionary = journey.interact(action,State.BLADE)
		if not check(result.ok,"production action " + action): quit(1); return
		var error: String = scene._quicksave_unrecorded(path)
		if not check(error.is_empty(),"save boundary " + action + ": " + error): quit(1); return
		error = scene._quickload_unrecorded(path)
		if not check(error.is_empty(),"reload boundary " + action + ": " + error): quit(1); return
	var after: Array = scene.carried_collected.duplicate()
	after.sort()
	before.sort()
	check(after==before,"gift recovered once; unrelated earned inventory unchanged")
	check(scene.quest_state.l8_journey.gift=="recovered","production save retained recovery")
	check(not journey.interact("recover_blade").ok,"duplicate recovery refused")
	await continue_route(scene)
	DirAccess.remove_absolute(path)
	if is_instance_valid(scene): scene.queue_free()
	await process_frame
	if failures==0: print("PASS STORY-001: earned Act1 arrival, production L8 gift/recovery, actual save/reload; rendered presentation not qualified")
	quit(0 if failures==0 else 1)

func continue_route(_scene: Node) -> void:
	pass

func approach_entry(scene: Node, journey: Node) -> void:
	# Portal-centre path from native nav regions at selector1 to Daniel93.
	for point in [Vector2(-4434,1168),Vector2(-4402.6,1167.93),Vector2(-4356.5,1179),Vector2(-4000,1200)]:
		for tick in 360:
			await physics_frame
			if journey.target()=="entry": return
			var delta: Vector3 = Vector3(point.x,scene.player.position.y,point.y)-scene.player.position
			if delta.length()<12: break
			scene.player.velocity = delta.normalized()*120
			scene.player.velocity.y = -32
			scene.player.move_and_slide()
