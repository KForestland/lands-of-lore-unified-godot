extends "res://tests/cave_guard_live_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.guard_population!=null)
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var pop=scene.guard_population;pop.set_physics_process(false);scene.roach_population_live.set_process(false)
	assert(pop.creature_audio.players.size()==8)
	assert(await stand_in(scene,pop,1104))
	await step(pop,0.2)
	assert(pop.state.actors["52"].woken and pop.state.audio["52"].request==510 and pop.state.audio["52"].sample>0)
	for id in pop.state.actors:
		if not pop.state.actors[id].present: assert(pop.state.audio[id].request==0)
	var path:="user://tests/cave_guard_audio.json"
	assert(scene._quicksave(path).is_empty())
	var saved: Dictionary=pop.checkpoint()
	var disk: Dictionary=scene.WalkthroughSave.read_save(path,scene._checkpoint_count()).state
	await step(pop,0.2)
	assert(pop.checkpoint()!=saved)
	assert(scene._quickload(path).is_empty() and pop.checkpoint()==saved)
	scene.set_physics_process(false)
	spells.running=false;pop.advance(1.0)
	assert(pop.checkpoint()==saved)
	paused=true;await process_frame;await process_frame
	assert(pop.checkpoint()==saved)
	paused=false;spells.running=true
	var position: Vector3=scene.player.position
	var quests: Dictionary=scene.quest_state.duplicate(true)
	for change in [["request",65535],["sample",-1],["sample",0.5],["selector",999],["time",-1]]:
		var bad:=disk.duplicate(true);bad.guards.audio["52"][change[0]]=change[1]
		bad.player.position[0]+=100
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		assert(not scene._quickload(path).is_empty())
		assert(pop.checkpoint()==saved and scene.player.position==position and scene.quest_state==quests)
	var old:=disk.duplicate(true);old.guards.erase("audio")
	assert(scene.WalkthroughSave.write_save(path,old,scene._checkpoint_count()).is_empty())
	assert(scene._quickload(path).is_empty() and not pop.state.has("audio"))
	pop.creature_audio.sync(0.0)
	assert(pop.state.audio["52"].request==0)
	DirAccess.remove_absolute(path)
	scene.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: region1104 guard rise sound, eight voices/absent silence, partial cave disk rollback, pause, malformed audio atomic rejection and legacy restore")
	quit()
