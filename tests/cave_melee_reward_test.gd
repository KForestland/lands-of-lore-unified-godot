extends SceneTree
const Reward=preload("res://scripts/lol2/cave_melee_reward.gd")
const Quests=preload("res://scripts/lol2/act_one_quest_state.gd")
const Fighting=preload("res://scripts/lol2/player_fighting_transport.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var base:=Quests.initial()
	var hit:=Reward.apply(base,10,8,1)
	assert(hit.award==1 and not base.has("player_reward_state"))
	var kill:=Reward.apply(hit.quests,2,99,1)
	assert(kill.award==10 and kill.loss==2 and kill.quests.player_reward_state.player.experience==11)
	assert(Reward.apply(base,24,8,2).award==2 and Reward.apply(base,1,8,2).award==25)
	assert(Reward.apply(base,0,8,1).has("error") and Reward.apply(base,10,0,1).has("error"))
	for scale in [5,10,255]:
		var reward:=Reward.apply(base,255,8,scale)
		assert(not reward.has("error") and reward.loss==8 and reward.award=={5:10,10:25,255:637}[scale])
	assert(Reward.apply(base,255,8,0).has("error") and Reward.apply(base,255,8,256).has("error"))
	var near: Dictionary=hit.quests.duplicate(true);near.player_reward_state.player.experience=249
	var level:=Reward.apply(near,10,8,1)
	assert(level.quests.player_reward_state.player.level==2 and level.quests.cave_melee_seed!=near.cave_melee_seed)
	# JSON restores pass-through quest numbers as floats; reward-owned fields must replay exactly.
	var replay:=Reward.apply(JSON.parse_string(JSON.stringify(near)),10,8,1)
	assert(replay.award==level.award and replay.loss==level.loss and replay.quests.cave_melee_seed==level.quests.cave_melee_seed)
	assert(replay.quests.player_reward_state==level.quests.player_reward_state)
	assert(Quests.validate(level.quests).is_empty())
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready)
	scene.set_physics_process(false)
	var live=scene.roach_population_live
	# The cave owns only the fighting subset of quests.
	scene.quest_state=Fighting.pack(near)
	assert(live.receive_damage("25",8) and scene.roach_population.actors["25"].health==2)
	assert(scene.quest_state.player_reward_state==level.quests.player_reward_state)
	var path:="user://tests/cave_melee_reward.json"
	assert(scene._quicksave(path).is_empty())
	var saved: Dictionary=scene.quest_state.duplicate(true)
	assert(live.receive_damage("25",99))
	var dead: Dictionary=scene.quest_state.duplicate(true)
	assert(not live.receive_damage("25",99) and scene.quest_state==dead)
	assert(scene._quickload(path).is_empty() and scene.quest_state==saved and scene.roach_population.actors["25"].health==2)
	scene.set_physics_process(false)
	var roach=scene.roach
	var before: Dictionary=scene.quest_state.duplicate(true)
	assert(not roach.receive_strike(true,true,false,8) and scene.quest_state==before)
	roach.model.strike_remaining=0.0
	var expected:=Reward.apply(before,roach.model.enemy_health,8,2)
	assert(roach.receive_strike(true,true,true,8) and scene.quest_state==expected.quests)
	before=scene.quest_state.duplicate(true)
	assert(not roach.receive_strike(true,true,true,8) and scene.quest_state==before)
	# Invalid progression cannot consume a target or partially commit its reward.
	scene.quest_state.cave_melee_seed=-1
	var hp: int=scene.roach_population.actors["26"].health
	assert(not live.receive_damage("26",99) and scene.roach_population.actors["26"].health==hp)
	roach.model.strike_remaining=0.0
	var actor_before: Dictionary=roach.snapshot()
	assert(not roach.receive_strike(true,true,true,99) and roach.snapshot()==actor_before)
	assert(Fighting.restore(scene.quest_state).has("error"))
	assert(scene._quicksave("user://tests/cave_melee_invalid.json")=="Invalid cave melee reward RNG.")
	print("PASS: cave scales1/2, kill/overkill/no-duplicate, level/RNG JSON replay, actual disk rollback, entrance miss/cooldown and atomic invalid-state rejection")
	scene.queue_free();await process_frame;quit()
