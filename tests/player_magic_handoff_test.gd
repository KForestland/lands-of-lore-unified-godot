extends SceneTree
const Magic=preload("res://scripts/lol2/player_magic_state.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func finish(node: Node) -> void:
	await RenderingServer.frame_post_draw
	node.queue_free()
	await process_frame
	await process_frame
	await physics_frame
func run() -> void:
	var path := "user://tests/magic_handoff.json"
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false)
	if not check(cave.walkthrough_ready and cave.player_magic_checkpoint.player.mana==20,"Missing original starting mana"): return
	await physics_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	cave.flying=false
	cave.roach.model.player_health=10
	cave.starting_magic.set_process(false)
	cave.starting_magic.select_spell("heal")
	if not check(cave.starting_magic.cast() and cave.roach.model.player_health==16 and cave.player_magic_checkpoint.player.mana==18,"Starting cave Healing failed"): return
	cave.starting_magic._process(0.5)
	cave.chamber_arrival_state="playing"
	if not check(not cave.starting_magic.cast(),"Cave story allowed world casting"): return
	cave.chamber_arrival_state="not_started"
	cave.starting_magic.select_spell("spark")
	var target: Vector3=cave.roach.body.global_position+Vector3(0,6,0)
	var found:=false
	for offset in [Vector3(0,32,50),Vector3(0,32,-50),Vector3(50,32,0),Vector3(-50,32,0)]:
		cave.player.global_position=cave.roach.body.global_position+offset
		cave.camera.look_at(target)
		await physics_frame
		if cave.roach.clear_ray(cave.camera.global_position,target): found=true;break
	if not check(found and cave.starting_magic.cast() and cave.roach.model.enemy_health==16,"Starting cave Spark failed to hit actor23"): return
	cave.starting_magic._process(0.5)
	cave.player_magic_checkpoint.player.mana=13
	var expected_magic: Dictionary=cave.player_magic_checkpoint.duplicate(true)
	if not check(cave._quicksave(path).is_empty(),"Cave magic save failed"): return
	cave.player_magic_checkpoint.player.mana=2
	if not check(cave._quickload(path).is_empty() and cave.player_magic_checkpoint==expected_magic,"Cave magic rollback failed"): return
	cave.set_physics_process(false)
	var bad: Dictionary=cave._save_state()
	bad.magic.player.mana=-1
	if not check(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty(),"Negative cave mana accepted"): return
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	if not check(museum.player_magic_checkpoint==expected_magic,"Museum reset incoming mana"): return
	if not check(museum.quicksave(path).is_empty(),"Museum mana save failed"): return
	museum.player_magic_checkpoint.player.mana=1
	if not check(museum.quickload(path).is_empty() and museum.player_magic_checkpoint==expected_magic,"Museum mana rollback failed"): return
	museum.set_physics_process(false)
	var inventory: Dictionary=museum.inventory_state()
	await finish(museum)
	remove_meta("lol2_cave_completion")
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	jungle.set_physics_process(false)
	if not check(jungle.apply_inventory_handoff(inventory).is_empty(),"Jungle magic admission failed"): return
	if not check(jungle.quest_state.player_magic_reward_state==expected_magic and not jungle.inventory_state().has("magic"),"Jungle did not migrate to single quest owner"): return
	if not check(jungle.quicksave(path).is_empty(),"Jungle magic save failed"): return
	jungle.quest_state.player_magic_reward_state.player.mana=1
	if not check(jungle.quickload(path).is_empty() and jungle.quest_state.player_magic_reward_state==expected_magic,"Jungle mana rollback failed"): return
	jungle.set_physics_process(false)
	var transfer: Dictionary=jungle.area_handoff()
	await finish(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty() and hive.player_magic_checkpoint==expected_magic,"Hive reset incoming mana"): return
	hive.set_physics_process(false)
	var before: Dictionary=hive.area_handoff()
	var conflict: Dictionary=before.duplicate(true)
	conflict.inventory.magic=Magic.initial()
	if not check(not hive.apply_area_handoff(conflict).is_empty() and hive.area_handoff()==before,"Conflicting mana mutated Hive"): return
	if not check(hive.quicksave(path).is_empty(),"Hive mana save failed"): return
	hive.player_magic_checkpoint.player.mana=0
	if not check(hive.quickload(path).is_empty() and hive.player_magic_checkpoint==expected_magic,"Hive magic rollback failed"): return
	await finish(hive)
	DirAccess.remove_absolute(path)
	print("PASS: starting20 mana, cave/Museum/Jungle/Hive disk rollback,13 mana transported, single quest owner, invalid/conflicting state rejection")
	quit()
