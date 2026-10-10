extends SceneTree
const Fighting=preload("res://scripts/lol2/player_fighting_transport.gd")
const Reward=preload("res://scripts/lol2/cave_melee_reward.gd")
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
	var path := "user://tests/fighting_handoff.json"
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false)
	if not check(cave.walkthrough_ready and cave.quest_state.is_empty() and not cave._save_state().has("fighting"),"Fresh cave has fighting progression"): return
	# Real population melee damage earns the source scale1 kill reward.
	var expected:=Reward.apply({},10,99,1)
	if not check(cave.roach_population_live.receive_damage("25",99) and cave.quest_state==Fighting.pack(expected.quests),"Cave melee kill reward missing"): return
	var earned: Dictionary=cave.quest_state.duplicate(true)
	if not check(earned.player_reward_state.player.experience==10,"Unexpected cave kill XP"): return
	if not check(cave._quicksave(path).is_empty(),"Cave fighting save failed"): return
	cave.quest_state={}
	if not check(cave._quickload(path).is_empty() and cave.quest_state==earned,"Cave fighting rollback failed"): return
	cave.set_physics_process(false)
	var bad: Dictionary=cave._save_state()
	bad.fighting.player_reward_state.player.level=99
	if not check(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty(),"Invalid cave level accepted"): return
	bad=cave._save_state();bad.fighting.extra=1
	if not check(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty(),"Unknown fighting field accepted"): return
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	if not check(museum.fighting_checkpoint==earned,"Museum reset incoming fighting progression"): return
	if not check(museum.quicksave(path).is_empty(),"Museum fighting save failed"): return
	museum.fighting_checkpoint={}
	if not check(museum.quickload(path).is_empty() and museum.fighting_checkpoint==earned,"Museum fighting rollback failed"): return
	museum.set_physics_process(false)
	var inventory: Dictionary=museum.inventory_state()
	await finish(museum)
	remove_meta("lol2_cave_completion")
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	jungle.set_physics_process(false)
	var conflict: Dictionary=inventory.duplicate(true)
	jungle.quest_state.player_reward_state={"version":1,"player":earned.player_reward_state.player.duplicate()}
	jungle.quest_state.player_reward_state.player.experience=3
	var before_conflict: Dictionary=jungle.quest_state.duplicate(true)
	if not check(not jungle.apply_inventory_handoff(conflict).is_empty() and jungle.quest_state==before_conflict,"Conflicting fighting handoff mutated Jungle"): return
	jungle.quest_state.erase("player_reward_state")
	if not check(jungle.apply_inventory_handoff(inventory).is_empty(),"Jungle fighting admission failed"): return
	if not check(jungle.quest_state.player_reward_state==earned.player_reward_state and jungle.quest_state.cave_melee_seed==earned.cave_melee_seed and not jungle.inventory_state().has("fighting"),"Jungle did not migrate fighting to quests"): return
	if not check(jungle.quicksave(path).is_empty(),"Jungle fighting save failed"): return
	jungle.quest_state.player_reward_state.player.experience=0
	if not check(jungle.quickload(path).is_empty() and jungle.quest_state.player_reward_state==earned.player_reward_state,"Jungle fighting rollback failed"): return
	jungle.set_physics_process(false)
	var transfer: Dictionary=jungle.area_handoff()
	await finish(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty() and hive.player_reward_checkpoint==earned.player_reward_state,"Hive reset incoming fighting progression"): return
	hive.set_physics_process(false)
	var before: Dictionary=hive.area_handoff()
	var clash: Dictionary=before.duplicate(true)
	clash.inventory.fighting={"player_reward_state":{"version":1,"player":earned.player_reward_state.player.duplicate()}}
	clash.inventory.fighting.player_reward_state.player.experience=1
	if not check(not hive.apply_area_handoff(clash).is_empty() and hive.area_handoff()==before,"Conflicting fighting mutated Hive"): return
	if not check(hive.quicksave(path).is_empty(),"Hive fighting save failed"): return
	hive.player_reward_checkpoint={}
	if not check(hive.quickload(path).is_empty() and hive.player_reward_checkpoint==earned.player_reward_state,"Hive fighting rollback failed"): return
	if not check(hive.area_handoff().quests.player_reward_state==earned.player_reward_state,"Hive return dropped fighting progression"): return
	await finish(hive)
	DirAccess.remove_absolute(path)
	print("PASS: live cave melee kill XP10, cave/Museum/Jungle/Hive disk rollback, single quest owner, invalid/conflicting fighting rejection")
	quit()
