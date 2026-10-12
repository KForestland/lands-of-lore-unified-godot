extends "res://tests/player_magic_handoff_test.gd"
const Stone = preload("res://scripts/lol2/hive_ancient_stone.gd")
func run() -> void:
	Engine.time_scale=4
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	scene.executioner_live.set_physics_process(false)
	var guards=scene.get_node("Warriors")
	guards.set_process(false)
	var spells=scene.starting_magic
	spells.set_process(false)
	scene.item_effects.set_process(false)
	var fixture: Dictionary=scene.area_handoff()
	fixture.quests.hive_rune_entry.merge({"room":"RUNES","marker642_enabled":true,"lights":true},true)
	if not check(scene.apply_area_handoff(fixture).is_empty(),"Rune fixture rejected"): return
	scene.runes.activate_hotspot(4)
	for i in range(900):
		await process_frame
		if scene.runes.checkpoint.flag7 and not scene.runes.busy(): break
	if not check(Stone.ITEM in scene.carried_inventory.collected,"Actual pickup failed"): return
	scene.runes.leave()
	if not check(scene.open_inventory(),"Inventory failed"): return
	for i in scene.inventory.item_list.item_count:
		if str(scene.inventory.item_list.get_item_metadata(i))==Stone.ITEM: scene.inventory.select_item(i)
	if not check(scene.inventory.use_button.visible,"Ancient use missing"): return
	scene.inventory.use_button.pressed.emit()
	await process_frame
	if not check(scene.item_effects.state().ancient_charges==1 and Stone.ITEM not in scene.carried_inventory.collected and Stone.ITEM in scene.item_effects.state().spent,"Use did not consume and credit"): return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false)
	scene.player.position=guards.POSITIONS[0]+Vector3(0,32,65)
	scene.camera.look_at(guards.POSITIONS[0]+Vector3(0,35,0))
	# A second nearby living target is an explicit combat fixture, not source placement.
	guards.bodies[1].position=guards.POSITIONS[0]+Vector3(45,0,0)
	guards.health=18
	spells.magic_state().player.mana=0
	for i in range(3): await physics_frame
	if not check(not spells.cast() and scene.item_effects.state().ancient_charges==1,"Charge paid for basic Spark"): return
	var phase: int=scene.curse.state.phase
	scene.curse.state.phase=1
	if not check(not spells.cast(5) and scene.item_effects.state().ancient_charges==1 and guards.health==18,"Busy cast changed resources"): return
	scene.curse.state.phase=phase
	var event:=InputEventKey.new()
	event.keycode=KEY_Q;event.shift_pressed=true;event.pressed=true
	spells._unhandled_input(event)
	if not check(spells.protected() and spells.magic_state().player.mana==0 and scene.item_effects.state().ancient_charges==0 and guards.health==1 and spells.aura.state().bolts.size()==2,"Free max cast/aura/multi-target failed"): return
	guards._process(1.5)
	if not check(guards.health==1,"Aura did not block guardian hit"): return
	spells.aura.advance(0.05)
	var before: Dictionary=scene.area_handoff()
	var path:="user://tests/spark_aura_live.json"
	if not check(scene.quicksave(path).is_empty(),"In-flight save failed"): return
	spells.aura.advance(0.5)
	if not check(guards.enemies[0]<24 and guards.enemies[1]<24,"Homing bolts did not hit both targets"): return
	if not check(scene.quickload(path).is_empty() and scene.area_handoff()==before,"In-flight JSON rollback failed"): return
	scene.set_physics_process(false)
	var active: Dictionary=spells.aura.state()
	if not check(scene.open_inventory(),"Pause inventory failed"): return
	spells._process(2)
	scene.item_effects.advance(2)
	if not check(spells.aura.state()==active and guards.health==1,"Inventory advanced aura"): return
	scene.inventory.close()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	spells.magic_state().cooldown=0
	spells.select_spell("heal")
	spells.magic_state().player.mana=20
	if not check(not spells.cast() and guards.health==1,"Healing ignored aura pause"): return
	spells.select_spell("spark")
	guards.health=3 # Direct health changes are distinct from pending-heal ticks.
	if not check(spells.cast(5) and guards.health==3 and spells.magic_state().player.mana==10 and spells.aura.state().timer==active.timer+(600<<16) and spells.aura.state().bolts.size()==active.bolts.size(),"Paid recast reset health/sweep or failed extension"): return
	guards.health=1
	spells.aura.advance(20)
	if not check(not spells.protected() and guards.health==1 and scene.item_effects.state().aloe.pending==18 and scene.item_effects.state().aloe.base==1,"Expiry failed gradual recovery setup"): return
	scene.item_effects.advance(0.1)
	if not check(guards.health>1 and guards.health<30,"Recovery was absent or instant full heal"): return
	# Restore active saved flights, then transport the same shared packet.
	if not check(scene.quickload(path).is_empty(),"Active restore failed"): return
	scene.set_physics_process(false)
	before=scene.area_handoff()
	for field in ["charges","history","bolt"]:
		var bad: Dictionary=before.duplicate(true)
		if field=="charges": bad.inventory.item_effects.ancient_charges=10
		elif field=="history": bad.quests.hive_rune_entry.flag7=false
		else: bad.quests.player_magic_reward_state.spark_aura.bolts[0].effect=24
		if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Malformed aura/charge/history mutated state: "+field): return
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	jungle.set_physics_process(false)
	jungle.starting_magic.set_process(false)
	jungle.item_effects.set_process(false)
	if not check(jungle.apply_area_handoff(before).is_empty() and jungle.starting_magic.aura.state()==spells.aura.state(),"Jungle lost active aura"): return
	jungle.starting_magic.aura.advance(0)
	if not check(jungle.starting_magic.protected() and jungle.starting_magic.aura.state().bolts.is_empty() and jungle.item_effects.state().ancient_charges==0,"Area flights persisted or protection lost"): return
	if not check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty(),"Jungle aura save failed"): return
	await finish(jungle)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.get_node("Nest").set_physics_process(false)
	scene.get_node("Nest").chasm_handoff()
	var live=scene.executioner_live
	live.advance(0.01)
	scene.player.position=live.SPAWN+Vector3(0,32,65)
	scene.camera.look_at(live.body.global_position)
	for i in range(3): await physics_frame
	var attack_health: int=guards.health
	live.advance(0.01)
	live.advance(8.0/15.0)
	if not check(live.state.hit_sent and guards.health==attack_health,"Aura failed actual Executioner impact"): return
	var aura_state: Dictionary=spells.aura.state()
	aura_state.bolts=[]
	aura_state.pulse=0.0
	spells.aura.commit(aura_state)
	var predicted: Dictionary=aura_state.duplicate(true)
	var effect: int=spells.aura.State.draw_effect(predicted)
	var damage: int=spells.aura.DAMAGE[effect-20]
	var reward: Dictionary=preload("res://scripts/lol2/hive_live_spell_reward.gd").apply(spells.magic_state(),int(live.state.get("reward_seed",324508639)),damage,effect)
	var fighting: Dictionary=scene.player_reward_checkpoint.duplicate(true)
	spells.aura.advance(1.5)
	if not check(live.state.health==300-damage and spells.magic_state().player==reward.checkpoint.player and scene.player_reward_checkpoint==fighting and spells.protected(),"Repeated aura pulse lost homing hit, magic XP or saved aura"): return
	# This combat fixture never walks through the source curse-enabling region.
	scene.curse.set_requests_enabled(true)
	if not check(scene.curse.request_timed_form(2,60),"Transformation request failed"): return
	if not check(not spells.protected() and scene.item_effects.state().aloe.pending==18,"Transformation cancellation lost recovery"): return
	await finish(scene)
	DirAccess.remove_absolute(path)
	print("PASS: actual Ancient pickup/use, free max-only cast, busy refusal, two homing targets, combat protection, in-flight rollback, pause, paid extension, gradual recovery, invalid atomicity and Jungle transport; supplied room/combat fixtures")
	quit()
