extends "res://tests/player_magic_handoff_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	for node in [scene.rune_population,scene.return_population,scene.ambush_population,scene.executioner_live,scene.curse,scene.hive_curse,scene.boulders]: node.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name()=="headless":
		scene.rune_population.free()
		scene.rune_population=preload("res://tests/hive_rune_population_headless.gd").new()
		scene.add_child(scene.rune_population)
		scene.rune_population.set_physics_process(false)
	var pop=scene.rune_population
	var guards=scene.get_node("Warriors")
	guards.health=30
	if not check(pop.targets().is_empty(),"Initial pool spawned copies"): return
	guards.enemies=[0,0]
	var ready: Dictionary=pop.observe_originals()
	pop.RuneState.advance(pop.state,4.5,ready)
	var path:="user://tests/hive_rune_population.json"
	if not check(scene.quicksave(path).is_empty(),"Partial retirement save failed"): return
	pop.RuneState.advance(pop.state,1.5,ready)
	if not check(scene.quickload(path).is_empty() and pop.state.slots["32"].counter==1 and pop.state.fraction==0.5,"Partial retirement reload failed"): return
	scene.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	pop.RuneState.advance(pop.state,1.5,ready)
	pop.arrive({})
	if not check(pop.targets().is_empty(),"Missing runes admitted copies"): return
	pop.arrive({"monastery":{"globals":{"GV_HAS_RUNES":1}}})
	if not check(pop.targets().size()==2 and pop.state.slots["32"].template==22 and pop.state.slots["34"].template==21,"Template order/finite slots failed"): return
	if not check(scene.starting_magic.aura.targets().has("hiverune32"),"Aura lacks rune copy"): return
	if not check(pop.receive_damage("32",10,false) and pop.state.actors["32"].health==390,"Copy spell hit failed"): return
	var before: Dictionary=scene.area_handoff()
	var save_error: String=scene.quicksave(path)
	if not check(save_error.is_empty(),"Copied actor save failed: "+save_error+" "+scene.Save.read_save(path+".tmp").error): return
	pop.receive_damage("32",400)
	if not check(scene.quickload(path).is_empty() and scene.area_handoff()==before,"Copy disk rollback failed"): return
	var saved: Dictionary=scene.Save.read_save(path).state
	var bad: Dictionary=saved.duplicate(true)
	bad.quests.hive_rune_population.slots["32"].phase=2
	if not check(not scene.apply_save(bad).is_empty() and scene.area_handoff()==before,"Malformed copy mutated scene"): return
	bad=saved.duplicate(true);bad.quests.erase("hive_rune_population")
	if not check(not scene.apply_save(bad).is_empty(),"Missing marked packet accepted"): return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	pop.arrive({"monastery":{"globals":{"GV_HAS_RUNES":1}}})
	if not check(pop.targets().size()==2 and pop.state.slots["32"].generation==1,"Arrival duplicated copies"): return
	pop.receive_damage("32",400)
	if not check(pop.RuneState.validate(pop.checkpoint()).is_empty(),"Lethal hit left invalid save state"): return
	pop.advance(2.0)
	ready=pop.observe_originals()
	pop.RuneState.advance(pop.state,5.0,ready);pop.present()
	if not check(pop.state.slots["32"].phase==2 and not pop.bodies["32"].visible,"Copy corpse did not retire"): return
	pop.arrive({"monastery":{"globals":{"GV_HAS_RUNES":1}}})
	if not check(pop.state.slots["32"].generation==2,"Retired copy slot was not reused"): return
	pop.receive_damage("32",400);pop.advance(2.0)
	pop.RuneState.advance(pop.state,5.0,pop.observe_originals())
	scene.monastery_checkpoint=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	scene.monastery_checkpoint.globals.GV_HAS_RUNES=1
	scene.player.position=Vector3(-1780,-203,-7625)
	pop._physics_process(0)
	if not check(pop.state.inside and pop.state.slots["32"].generation==3,"Region284 entry missed rune copy"): return
	var packet: Dictionary=pop.checkpoint()
	pop._physics_process(0)
	if not check(pop.checkpoint()==packet,"Remaining inside repeated trigger"): return
	var handoff: Dictionary=scene.area_handoff()
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(handoff).is_empty() and jungle.area_handoff().quests.hive_rune_population==packet,"Jungle lost finite pool"): return
	await RenderingServer.frame_post_draw
	jungle.queue_free()
	await process_frame
	var legacy: Dictionary=saved.duplicate(true)
	legacy.quests=handoff.quests.duplicate(true)
	legacy.quests.erase("hive_rune_population");legacy.quests.erase("hive_rune_population_schema")
	var legacy_error: String=scene.apply_save(legacy)
	if not check(legacy_error.is_empty() and pop.targets().is_empty(),"Legacy disk load failed: "+legacy_error): return
	print("PASS: live finite rune copies, combat/aura admission, corpse retirement, partial disk continuation, rollback and no duplicate reload")
	# Harness teardown: let the renderer release textures before quitting.
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	quit()
