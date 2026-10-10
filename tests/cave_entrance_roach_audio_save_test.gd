extends "res://tests/cave_roach_live_behavior_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.roach!=null)
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var pop=scene.roach;pop.set_physics_process(false)
	assert(pop.audio.players.size()==1)
	pop.model.phase=pop.Model.Phase.WINDUP;pop.model.phase_remaining=0.1
	pop._sync(0.0,false)
	assert(pop.state.audio["23"].request==802 and pop.state.audio["23"].sample>0)
	var path:="user://tests/cave_entrance_roach_audio.json"
	assert(scene._quicksave(path).is_empty())
	var saved: Dictionary=pop.snapshot()
	var disk: Dictionary=scene.WalkthroughSave.read_save(path,scene._checkpoint_count()).state
	pop.audio.sync(0.2)
	assert(pop.snapshot()!=saved)
	assert(scene._quickload(path).is_empty() and pop.snapshot()==saved)
	scene.set_physics_process(false)
	spells.running=false;pop.tick(1.0)
	assert(pop.snapshot()==saved)
	paused=true;await process_frame;await process_frame
	assert(pop.snapshot()==saved)
	paused=false;spells.running=true
	var position: Vector3=scene.player.position
	var quests: Dictionary=scene.quest_state.duplicate(true)
	for change in [["request",65535],["sample",-1],["sample",0.5],["selector",999],["time",-1]]:
		var bad:=disk.duplicate(true);bad.roach.audio["23"][change[0]]=change[1]
		bad.player.position[0]+=100
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		assert(not scene._quickload(path).is_empty())
		assert(pop.snapshot()==saved and scene.player.position==position and scene.quest_state==quests)
	var old:=disk.duplicate(true);old.roach.erase("audio")
	assert(scene.WalkthroughSave.write_save(path,old,scene._checkpoint_count()).is_empty())
	assert(scene._quickload(path).is_empty() and not pop.state.has("audio"))
	pop.audio.sync(0.0)
	assert(pop.state.audio["23"].request==0)
	assert(pop.receive_strike(true,true,true,99))
	assert(pop.state.audio["23"].request==827)
	DirAccess.remove_absolute(path)
	scene.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: Roach bite/death source sounds, entrance voice, partial cave disk rollback, pause, malformed audio atomic rejection and legacy restore")
	quit()
