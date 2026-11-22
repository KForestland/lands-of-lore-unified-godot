extends SceneTree
## K85 sites1+3: actual receive_damage routes award the existing reward exactly
## once, preserve the shared RNG, reject corpses and restore rewards from disk.
const Reward=preload("res://scripts/lol2/cave_melee_reward.gd")
func _initialize():run.call_deferred()
func run():
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 600:
		await process_frame
		if scene.walkthrough_ready and scene.get("starting_magic")!=null:break
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;scene.set_physics_process(false)
	for row in [[scene.wild_roach_population,"0",1],[scene.roach_population_live,"25",3]]:
		var pop=row[0];var id:String=row[1]
		var scale:int=pop.State.actor_row(pop.src,id).reward_scale if int(row[2])==1 else pop.reward_scale
		for damage in [8,999]:
			var health:int=pop.state.actors[id].health
			var expected=Reward.apply(scene.quest_state,health,damage,scale)
			assert(not expected.has("error") and expected.award>0)
			assert(pop.receive_damage(id,damage,true),"site%d landed" % int(row[2]))
			assert(scene.quest_state.player_reward_state==expected.quests.player_reward_state and scene.quest_state.cave_melee_seed==expected.quests.cave_melee_seed,"site%d exact single reward + RNG" % int(row[2]))
		var before:Dictionary=scene.quest_state.duplicate(true)
		assert(not pop.receive_damage(id,8,true) and scene.quest_state==before,"corpse cannot award")
	var earned:Dictionary=scene.quest_state.duplicate(true)
	var path="user://tests/foundation_reward_owners.json"
	assert(scene.quicksave(path).is_empty())
	scene.quest_state.player_reward_state.player.experience=0
	assert(scene.quickload(path).is_empty())
	assert(scene.quest_state.player_reward_state==earned.player_reward_state and scene.quest_state.cave_melee_seed==earned.cave_melee_seed,"reward disk rollback")
	DirAccess.remove_absolute(path);scene.free();current_scene=null;await process_frame
	print("PASS foundation melee rewards: actual sites1+3 hit/kill/no-duplicate/RNG/save rollback; sites4+6 remain covered by existing affected cases")
	quit()
