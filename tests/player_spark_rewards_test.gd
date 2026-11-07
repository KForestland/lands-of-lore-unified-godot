extends "res://tests/player_magic_handoff_test.gd"
const Reward=preload("res://scripts/lol2/hive_live_spell_reward.gd")
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.return_population.set_physics_process(false)
	var guards=scene.get_node("Warriors")
	guards.set_process(false)
	var spells=scene.starting_magic
	spells.set_process(false)
	scene.item_effects.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.player.position=guards.POSITIONS[0]+Vector3(0,32,65)
	scene.camera.look_at(guards.POSITIONS[0]+Vector3(0,35,0))
	guards.bodies[1].position=guards.POSITIONS[0]+Vector3(45,0,0)
	guards.enemies=[1,24]
	for i in range(3): await physics_frame
	if not check(spells.cast(5),"Aura cast failed"): return
	var bolts: Array=spells.aura.state().bolts.duplicate(true)
	if not check(bolts.size()==2,"Two guardian bolts missing"): return
	var expected: Dictionary=spells.magic_state().duplicate(true)
	var fighting: Dictionary=scene.player_reward_checkpoint.duplicate(true)
	for bolt in bolts:
		var hp:=1 if str(bolt.target)=="guardian32" else 24
		var loss:=mini(hp,int(spells.aura.DAMAGE[int(bolt.effect)-20]))
		var result:=Reward.apply(expected,int(expected.get("spark_reward_seed",324508639)),loss,int(bolt.effect),8)
		if not check(not result.has("error"),"Reward prediction failed"): return
		expected=result.checkpoint
		expected.spark_reward_seed=result.seed
	spells.aura.advance(0.5)
	if not check(guards.enemies[0]==0 and guards.enemies[1]<24 and spells.magic_state().player==expected.player and spells.magic_state().spark_reward_seed==expected.spark_reward_seed and scene.player_reward_checkpoint==fighting,"Guardian effects/loss/XP/RNG mismatch"): return
	var path:="user://tests/spark_rewards.json"
	if not check(scene.quicksave(path).is_empty(),"Reward RNG save failed"): return
	spells.magic_state().spark_reward_seed=7
	if not check(scene.quickload(path).is_empty() and spells.magic_state().spark_reward_seed==expected.spark_reward_seed,"Reward RNG rollback failed"): return
	scene.set_physics_process(false)
	var before: Dictionary=scene.area_handoff()
	for seed in [-1,true,2147483648,NAN]:
		var bad: Dictionary=before.duplicate(true)
		bad.quests.player_magic_reward_state.spark_reward_seed=seed
		if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Invalid reward RNG mutated scene"): return
	spells.cancel_aura()
	guards.health=30
	scene.get_node("Nest").set_physics_process(false)
	scene.get_node("Nest").chasm_handoff()
	var live=scene.executioner_live
	live.set_physics_process(false)
	live.advance(0.01)
	live.state.health=1
	scene.player.position=live.SPAWN+Vector3(0,32,65)
	scene.camera.look_at(live.body.global_position)
	for i in range(3): await physics_frame
	spells.magic_state().cooldown=0
	expected=spells.magic_state().duplicate(true)
	expected.player.mana-=1
	var last:=Reward.apply(expected,int(live.state.get("reward_seed",324508639)),1,20)
	if not check(spells.cast() and live.state.health==0 and spells.magic_state().player==last.checkpoint.player,"Executioner overkill used requested damage"): return
	await finish(scene)
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave not ready"): return
	cave.set_physics_process(false)
	cave.starting_magic.set_process(false)
	cave.item_effects.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	spells=cave.starting_magic
	expected=spells.magic_state().duplicate(true)
	var roach_reward:=Reward.apply(expected,int(expected.get("spark_reward_seed",324508639)),8,23,2)
	if not check(cave.roach.receive_magic(8,23) and spells.magic_state().player==roach_reward.checkpoint.player,"Roach dropped rolled effect or used wrong scale"): return
	cave.roach.model.enemy_health=1
	expected=spells.magic_state().duplicate(true)
	roach_reward=Reward.apply(expected,int(expected.get("spark_reward_seed",324508639)),1,20,2)
	if not check(cave.roach.receive_magic(8,20) and cave.roach.model.enemy_health==0 and spells.magic_state().player==roach_reward.checkpoint.player,"Roach overkill XP failed"): return
	before=spells.magic_state().duplicate(true)
	if not check(not cave.roach.receive_magic(8,23) and spells.magic_state()==before,"Corpse granted XP"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty() and spells.magic_state()==before,"Cave reward RNG transport failed"): return
	await finish(cave)
	DirAccess.remove_absolute(path)
	print("PASS rolled guardian/roach effect rewards, source scales8/2, actual one-HP loss, magic-only XP, saved reward RNG, invalid atomicity and corpse refusal")
	quit()
