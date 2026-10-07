extends "res://tests/cave_roach_live_behavior_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.roach_population_live!=null)
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var pop=scene.roach_population_live;pop.set_physics_process(false)
	assert(pop.audio.players.size()==23)
	pop.state.live["42"].merge({"mode":State.ATTACK,"elapsed":1.4,"hit":false},true)
	pop.audio.sync(0.0)
	assert(pop.state.audio["42"].request==802 and pop.state.audio["42"].sample>0)
	var path:="user://tests/cave_roach_audio.json"
	assert(scene._quicksave(path).is_empty())
	var saved: Dictionary=pop.state.duplicate(true)
	var disk: Dictionary=scene.WalkthroughSave.read_save(path,scene._checkpoint_count()).state
	pop.audio.sync(0.2)
	assert(pop.state.duplicate(true)!=saved)
	assert(scene._quickload(path).is_empty() and pop.state.duplicate(true)==saved)
	scene.set_physics_process(false)
	spells.running=false;pop.advance(1.0)
	assert(pop.state.duplicate(true)==saved)
	paused=true;await process_frame;await process_frame
	assert(pop.state.duplicate(true)==saved)
	paused=false;spells.running=true
	var position: Vector3=scene.player.position
	var quests: Dictionary=scene.quest_state.duplicate(true)
	for change in [["request",65535],["sample",-1],["sample",0.5],["selector",999],["time",-1]]:
		var bad:=disk.duplicate(true);bad.roach_population.audio["42"][change[0]]=change[1]
		bad.player.position[0]+=100
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		assert(not scene._quickload(path).is_empty())
		assert(pop.state.duplicate(true)==saved and scene.player.position==position and scene.quest_state==quests)
	var old:=disk.duplicate(true);old.roach_population.erase("audio")
	assert(scene.WalkthroughSave.write_save(path,old,scene._checkpoint_count()).is_empty())
	assert(scene._quickload(path).is_empty() and not pop.state.has("audio"))
	pop.audio.sync(0.0)
	assert(pop.state.audio["42"].request==0)
	assert(pop.receive_damage("42",99))
	assert(pop.state.audio["42"].request==827)
	pop.state.live["43"].mode=State.PURSUE
	pop.clocks["43"]=0.625
	pop.audio.sync(0.0)
	assert(scene._quicksave(path).is_empty())
	pop.clocks["43"]=5.0
	assert(scene._quickload(path).is_empty())
	assert(pop.clocks["43"]==0.625 and pop.animations["43"].frame_index==5)
	DirAccess.remove_absolute(path)
	scene.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: Roach bite/death source sounds, 23 independent voices, partial cave disk rollback, pause, malformed audio atomic rejection and legacy restore")
	quit()
