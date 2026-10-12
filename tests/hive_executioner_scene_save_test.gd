extends SceneTree
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var choices = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_action_choice_native.json"))
	var selected: Dictionary = {}
	for row in choices:
		if not row.has("table") and int(row.expected.action)==2:
			selected = row;break
	assert(not selected.is_empty())
	var actor := {"flags17":32,"flags16":4,"word7c":99,"ac":1,"ad":0,"b4":0,"b5":8,"b7":1,"b9":0,"target":0,"a8":selected.goal,"a9":selected.goal,"aa":1,"ab":1,"b8":0x30,"ba":0,"bb":0}
	var initial := Owner.new()
	assert(initial.initialize_pose(actor,2,15,true,0).is_empty())
	assert(initial.bind_player_damage({"attacker_heading":32768,"player_heading":32768,"guard":1,"mode":1,"scalar":0,"current":100,"descriptors":[]}).is_empty())
	assert(initial.choose_pending_ai(selected.stats).state.ab==2)
	assert(initial.commit_ai_decision(1).state.aa==2)
	var legacy: Dictionary = scene.area_handoff()
	assert(not legacy.quests.has("hive_executioner"))
	var handoff := legacy.duplicate(true)
	handoff.quests.hive_nest = {"phase":3,"elapsed":0}
	handoff.quests.hive_executioner = initial.checkpoint()
	handoff.quests.hive_actor_registry={"version":1,"active":[36,3],"inactive":[8]}
	handoff.quests.hive_executioner_commands={"version":1,"commands":[13,7,13],"cursor":4}
	assert(scene.apply_area_handoff(handoff).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint().pose == 2)
	var reach_original: Dictionary = scene.area_handoff()
	var perception_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_composed_native.json"))
	var perception_row: Dictionary = perception_rows[769]
	assert(perception_row.captured_definition and perception_row.context.region_present)
	var perception_handoff := reach_original.duplicate(true)
	perception_handoff.quests.hive_executioner.actor.merge(perception_row.actor,true)
	perception_handoff.quests.hive_executioner.actor.target=0x22574
	perception_handoff.quests.hive_executioner.attack.flags=int(perception_row.actor.b7)
	assert(scene.apply_area_handoff(perception_handoff).is_empty())
	scene.set_physics_process(false)
	var perception_before: Dictionary = scene.area_handoff()
	assert(scene.executioner_update_player_perception({}).has("error"))
	assert(scene.area_handoff()==perception_before)
	var perception_result: Dictionary = scene.executioner_update_player_perception(perception_row.context)
	assert(not perception_result.has("error"),str(perception_result))
	for field in perception_row.expected: assert(perception_result.checkpoint.actor[field]==perception_row.expected[field])
	assert(perception_result.checkpoint.actor.byte9e==perception_row.expected.byte9c)
	assert(perception_result.checkpoint.attack.flags==perception_row.expected.b7)
	var perception_path := "user://tests/hive_perception_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(perception_path).is_empty())
	assert(scene.apply_area_handoff(reach_original).is_empty())
	assert(scene.quickload(perception_path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint()==perception_result.checkpoint)
	assert(scene.apply_area_handoff(reach_original).is_empty())
	scene.set_physics_process(false)
	DirAccess.remove_absolute(perception_path)
	assert(scene.executioner_apply_valid_target_reach(0,128,0,0).has("error"))
	var reach_handoff := reach_original.duplicate(true)
	reach_handoff.quests.hive_executioner.actor.target=0x22574
	reach_handoff.quests.hive_executioner.actor.byte9e=2
	assert(scene.apply_area_handoff(reach_handoff).is_empty())
	scene.set_physics_process(false)
	assert(not scene.executioner_apply_valid_target_reach(129*65536,128,null,null).has("error"))
	assert(scene.executioner_runtime.checkpoint().actor.b7==0)
	assert(scene.executioner_runtime.checkpoint().attack.flags==0)
	var reach_result: Dictionary = scene.executioner_apply_valid_target_reach(128*65536,128,0,95)
	assert(reach_result.calls==["obstruction","random"])
	assert(reach_result.checkpoint.actor.b4==2 and reach_result.checkpoint.actor.b7==1)
	assert(reach_result.checkpoint.attack.flags==1)
	var reach_path := "user://tests/hive_reach_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(reach_path).is_empty())
	assert(not scene.executioner_apply_valid_target_reach(0,128,1,null).has("error"))
	assert(scene.quickload(reach_path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint()==reach_result.checkpoint)
	var lost_target: Dictionary = scene.executioner_update_target_reach(16,null,null,null,null)
	assert(not lost_target.has("error") and not lost_target.valid)
	assert(lost_target.checkpoint.actor.target==0 and lost_target.checkpoint.actor.b7==0 and lost_target.checkpoint.attack.flags==0)
	assert(scene.quicksave(reach_path).is_empty())
	assert(scene.apply_area_handoff(reach_handoff).is_empty())
	assert(scene.quickload(reach_path).is_empty())
	assert(scene.executioner_runtime.checkpoint()==lost_target.checkpoint)
	assert(scene.apply_area_handoff(reach_original).is_empty())
	scene.set_physics_process(false)
	DirAccess.remove_absolute(reach_path)
	# Reference-time entry owns both frame progress and persisted clock phase.
	var clock_type = preload("res://scripts/lol2/hive_clock_runtime.gd")
	var timing_type = preload("res://scripts/lol2/hive_timing_state.gd")
	assert(scene.executioner_advance_reference_time(16667).has("error"))
	scene.runtime_timing_checkpoint = timing_type.checkpoint(clock_type.initial_state(),123456789,15).checkpoint
	var timed_initial: Dictionary = scene.area_handoff()
	var timed_path := "user://tests/hive_reference_time_%d.json" % Time.get_ticks_usec()
	assert(not scene.executioner_advance_reference_time(16667).has("error"))
	assert(scene.quicksave(timed_path).is_empty())
	var timed_expected: Dictionary = scene.executioner_advance_reference_time(33001)
	var timed_final: Dictionary = scene.area_handoff()
	assert(scene.quickload(timed_path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_advance_reference_time(33001) == timed_expected)
	assert(scene.area_handoff() == timed_final)
	var paused_actor: Dictionary = scene.executioner_runtime.checkpoint()
	var paused_clock: Dictionary = scene.runtime_timing_checkpoint.clock.duplicate(true)
	paused = true
	var paused_tick: Dictionary = scene.executioner_advance_reference_time(30000000)
	paused = false
	assert(not paused_tick.advanced)
	assert(scene.executioner_runtime.checkpoint() == paused_actor)
	assert(scene.runtime_timing_checkpoint.clock == paused_clock)
	var invalid_before: Dictionary = scene.area_handoff()
	assert(scene.executioner_advance_reference_time(-1).has("error"))
	assert(scene.area_handoff() == invalid_before)
	var timed_visual: RefCounted = scene.get_node("Nest").executioner_visual
	scene.get_node("Nest").executioner_visual = preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
	assert(scene.executioner_advance_reference_time(16667).get("error","") == "Executioner sprite is not bound.")
	assert(scene.area_handoff() == invalid_before)
	scene.get_node("Nest").executioner_visual = timed_visual
	assert(scene.apply_area_handoff(timed_initial).is_empty())
	scene.runtime_timing_checkpoint = {}
	scene.set_physics_process(false)
	DirAccess.remove_absolute(timed_path)
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	var pose_path := "user://tests/hive_source_pose_%d.json" % Time.get_ticks_usec()
	assert(scene.executioner_advance(6145).state.frame==7)
	var pose_saved: Dictionary = scene.executioner_runtime.checkpoint()
	assert(scene.quicksave(pose_path).is_empty())
	var pose_expected: Dictionary = scene.executioner_advance(8192)
	assert(scene.quickload(pose_path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint()==pose_saved)
	assert(scene.executioner_command_checkpoint=={"version":1,"commands":[13,7,13],"cursor":4})
	var pose_material: StandardMaterial3D = scene.get_node("Nest").actor.material_override
	assert(pose_material.uv1_offset.is_equal_approx(Vector3(1.0/6,1.0/3,0)))
	assert(scene.executioner_advance(8192)==pose_expected)
	assert(scene.executioner_runtime.animation_context().terminal)
	assert(not scene.executioner_decide({},helpers).has("error"))
	DirAccess.remove_absolute(pose_path)
	# Stop on the first source damage frame; save must preserve progress before the second.
	assert(not scene.executioner_advance_with_player_damage(6145).has("error"))
	var saved: Dictionary = scene.executioner_runtime.checkpoint()
	assert(saved.pose == 12 and saved.attack.frame == 7 and saved.player_damage.current==93)
	# Clock-driven damage must survive a disk save between the two damage frames.
	scene.runtime_timing_checkpoint = timing_type.checkpoint(clock_type.initial_state(),0,15).checkpoint
	var damage_path := "user://tests/hive_timed_damage_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(damage_path).is_empty())
	var damage_before: Dictionary = scene.area_handoff()
	var damage_visual: RefCounted = scene.get_node("Nest").executioner_visual
	scene.get_node("Nest").executioner_visual = preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
	assert(scene.executioner_advance_reference_time_with_player_damage(1000000).has("error"))
	assert(scene.area_handoff() == damage_before)
	scene.get_node("Nest").executioner_visual = damage_visual
	var damage_expected: Dictionary = scene.executioner_advance_reference_time_with_player_damage(1000000)
	assert(not damage_expected.has("error"))
	var damage_expected_second: Dictionary = scene.executioner_advance_reference_time_with_player_damage(1000000)
	assert(not damage_expected_second.has("error"))
	assert(scene.executioner_runtime.checkpoint().player_damage.current == 86)
	var damage_final: Dictionary = scene.area_handoff()
	assert(scene.quickload(damage_path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_advance_reference_time_with_player_damage(1000000) == damage_expected)
	assert(scene.executioner_advance_reference_time_with_player_damage(1000000) == damage_expected_second)
	assert(scene.area_handoff() == damage_final)
	assert(scene.quickload(damage_path).is_empty())
	scene.set_physics_process(false)
	scene.runtime_timing_checkpoint = {}
	DirAccess.remove_absolute(damage_path)
	var path := "user://tests/hive_executioner_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	var expected: Dictionary = scene.executioner_advance_with_player_damage(4096)
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint() == saved)
	assert(scene.executioner_advance_with_player_damage(4096) == expected)
	assert(scene.executioner_runtime.checkpoint().player_damage.current==86)
	var baseline: Dictionary = scene.area_handoff()
	var bad: Dictionary = scene.Save.read_save(path).state
	bad.quests.hive_executioner.actor.ad = 99
	bad.player.position[0] += 100
	var position: Vector3 = scene.player.position
	assert(not scene.apply_save(bad).is_empty())
	assert(scene.player.position == position and scene.area_handoff() == baseline)
	bad = scene.Save.read_save(path).state
	bad.quests.hive_executioner.actor.erase("bb")
	assert(not scene.apply_save(bad).is_empty() and scene.area_handoff()==baseline)
	bad = scene.Save.read_save(path).state
	bad.quests.hive_actor_registry.active=[3]
	assert(not scene.apply_save(bad).is_empty() and scene.area_handoff()==baseline)
	bad = scene.Save.read_save(path).state
	bad.quests.hive_executioner_commands.cursor=-1
	assert(not scene.apply_save(bad).is_empty() and scene.area_handoff()==baseline)
	# Combined checkpoints cross jungle storage without losing animation/actor state.
	var jungle: Dictionary = scene.Save.read_save(path).state
	jungle.format = JungleSave.FORMAT
	var jungle_path := path.replace("hive_executioner_","jungle_executioner_")
	assert(JungleSave.write_save(jungle_path,jungle).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty() and scene.executioner_runtime == null and scene.executioner_command_checkpoint.is_empty() and scene.actor_registry_checkpoint.is_empty())
	assert(scene.apply_area_handoff(JungleSave.read_save(jungle_path).state).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint() == saved)
	assert(scene.executioner_command_checkpoint=={"version":1,"commands":[13,7,13],"cursor":4})
	var material: StandardMaterial3D = scene.get_node("Nest").actor.material_override
	assert(material.uv1_offset.is_equal_approx(Vector3(1.0/6.0,1.0/3.0,0)))
	var copy: Dictionary = scene.area_handoff();copy.quests.hive_executioner.actor.ad = 123
	assert(scene.executioner_runtime.checkpoint() == saved)
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(jungle_path)
	var prepared: Dictionary = scene.area_handoff()
	var outcome_stats: Array = [];outcome_stats.resize(30);outcome_stats.fill(250)
	prepared.quests.hive_executioner.actor.merge({"id":36,"a0":4,"b0":300,"b4":16,"word84":77,"stats":outcome_stats,"flags14":0,"flags15":0,"ae":0,"b6":0,"health":300},true)
	assert(scene.apply_area_handoff(prepared).is_empty())
	scene.set_physics_process(false)
	var outcome_events: Array = []
	var outcome_helpers := {"random":func(_state,_maximum):return 50,
		"event":func(_state,event):outcome_events.append(event),"release":func(_state):pass,
		"effect":func(_state,_resource,_parameters):assert(false)}
	var outcome_context := {"flags":0,"action":5,"definition77":5,"effects_disabled":true,"effect21":0,"effect22":0,"effect_template":0}
	var outcome_world := {"sector":0,"neighbors":[],"sector_flags":[0],"group":{"version":1,"index":4,"members":[36,3],"flags":[16,0],"reserved":[7,8,9]},"peers":[]}
	var health_context := {"requested":0,"definition3c":0,"definition7f":100,"mode":0}
	var world_before_failure: Dictionary = scene.area_handoff()
	var world_visual: RefCounted = scene.get_node("Nest").executioner_visual
	scene.get_node("Nest").executioner_visual=preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
	assert(scene.executioner_set_health(health_context,outcome_world,outcome_context,outcome_helpers).get("error","")=="Executioner sprite is not bound.")
	assert(scene.area_handoff()==world_before_failure)
	scene.get_node("Nest").executioner_visual=world_visual
	outcome_events.clear() # External callback effects are not rolled back.
	var transitioned: Dictionary = scene.executioner_set_health(health_context,outcome_world,outcome_context,outcome_helpers)
	assert(not transitioned.has("error"),str(transitioned))
	assert(transitioned.checkpoint.pose==17 and transitioned.state.health==0 and outcome_events==[10])
	assert(scene.executioner_advance(6145).state.frame==7)
	var partial_outcome: Dictionary = scene.executioner_runtime.checkpoint()
	assert(scene.quicksave(path).is_empty())
	var expected_outcome: Dictionary = scene.executioner_advance(8192)
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_runtime.checkpoint()==partial_outcome)
	assert(scene.outcome_world_checkpoint=={"version":1,"sector_flags":[0],"group":{"version":1,"index":4,"members":[3],"flags":[16],"reserved":[7,8,9]}})
	var world_saved: Dictionary = scene.area_handoff()
	var corrupt: Dictionary = world_saved.duplicate(true)
	corrupt.quests.hive_outcome_world.sector_flags=[256]
	assert(not scene.apply_area_handoff(corrupt).is_empty() and scene.area_handoff()==world_saved)
	var world_carried: Dictionary = scene.Save.read_save(path).state
	world_carried.format=JungleSave.FORMAT
	assert(JungleSave.write_save(jungle_path,world_carried).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty() and scene.outcome_world_checkpoint.is_empty())
	assert(scene.apply_area_handoff(JungleSave.read_save(jungle_path).state).is_empty())
	scene.set_physics_process(false)
	assert(scene.area_handoff()==world_saved)
	var stale: Dictionary = outcome_world.duplicate(true);stale.sector_flags=[1]
	assert(scene.executioner_begin_outcome(stale,{},{}).has("error") and scene.area_handoff()==world_saved)
	assert(scene.executioner_advance(8192)==expected_outcome)
	DirAccess.remove_absolute(path)
	# Supplied outcome checkpoints retain progress through the same scene/jungle
	# transport. This exercises playback/persistence, not health-zero admission.
	for selector in [17,18,19,20]:
		var outcome: Dictionary = saved.duplicate(true)
		outcome.pose=selector;outcome.source_pose={"selector":selector,"frame":0,"timer":0}
		outcome.attack.frame=0;outcome.attack.timer=0
		outcome.actor.a8=15;outcome.actor.a9=15;outcome.actor.aa=15;outcome.actor.ab=16
		var transfer: Dictionary = scene.area_handoff()
		transfer.quests.hive_executioner=outcome
		transfer.quests.erase("hive_outcome_world")
		assert(scene.apply_area_handoff(transfer).is_empty())
		scene.set_physics_process(false)
		assert(not scene.executioner_advance(6145).has("error"))
		var outcome_saved: Dictionary = scene.executioner_runtime.checkpoint()
		assert(scene.quicksave(path).is_empty())
		var continued: Dictionary = scene.executioner_advance(8192)
		assert(scene.quickload(path).is_empty())
		scene.set_physics_process(false)
		assert(scene.executioner_runtime.checkpoint()==outcome_saved)
		assert(scene.executioner_advance(8192)==continued)
		var carried: Dictionary = scene.Save.read_save(path).state
		carried.format=JungleSave.FORMAT
		assert(JungleSave.write_save(jungle_path,carried).is_empty())
		assert(scene.apply_area_handoff(legacy).is_empty())
		assert(scene.apply_area_handoff(JungleSave.read_save(jungle_path).state).is_empty())
		scene.set_physics_process(false)
		assert(scene.executioner_runtime.checkpoint()==outcome_saved)
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(jungle_path)
	assert(scene.apply_area_handoff(handoff).is_empty())
	scene.set_physics_process(false)
	var pending_before: Dictionary = scene.area_handoff()
	assert(scene.executioner_consume_commands(256).has("error") and scene.area_handoff()==pending_before)
	assert(scene.executioner_consume_commands(1).executed.is_empty() and scene.area_handoff()==pending_before)
	var consumed: Dictionary = scene.executioner_consume_commands(0)
	assert(not consumed.has("error"),str(consumed))
	assert(consumed.executed==[13,7,13] and consumed.counter==0)
	assert(scene.executioner_command_checkpoint=={"version":1,"commands":[],"cursor":4})
	assert(scene.executioner_runtime.checkpoint().actor.flags16==0 and scene.executioner_runtime.checkpoint().actor.b5==12)
	var consumed_state: Dictionary = scene.area_handoff()
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==consumed_state)
	DirAccess.remove_absolute(path)
	var inactive: Dictionary = handoff.duplicate(true)
	inactive.quests.hive_executioner.actor.merge({"flags14":0,"flags15":4,"ae":0,"b6":0,"health":300,"state25":1},true)
	inactive.quests.hive_executioner.actor.flags16=0
	inactive.quests.hive_executioner.actor.flags17=0
	inactive.quests.hive_executioner_commands={"version":1,"commands":[],"cursor":0}
	inactive.quests.hive_actor_registry={"version":1,"active":[3],"inactive":[8,36,9]}
	var refresh_state: Dictionary = inactive.duplicate(true)
	refresh_state.quests.hive_executioner.actor.flags14=2
	assert(scene.apply_area_handoff(refresh_state).is_empty())
	var before_refresh: Dictionary = scene.area_handoff()
	assert(scene.executioner_refresh_material_region({"same_region":true}).has("error") and scene.area_handoff()==before_refresh)
	var refreshed: Dictionary = scene.executioner_refresh_material_region({"same_region":true,"actor_z":0,"floor_height":0})
	assert(not refreshed.has("error"))
	assert(scene.actor_registry_checkpoint=={"version":1,"active":[3,36],"inactive":[8,9]})
	assert(scene.executioner_runtime.checkpoint().actor.flags16==1 and scene.executioner_runtime.checkpoint().actor.flags17==32)
	var refreshed_handoff: Dictionary = scene.area_handoff()
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==refreshed_handoff)
	assert(not scene.executioner_refresh_material_region({"same_region":true,"actor_z":0,"floor_height":0}).has("error"))
	assert(scene.area_handoff()==refreshed_handoff)
	DirAccess.remove_absolute(path)
	assert(scene.apply_area_handoff(inactive).is_empty())
	scene.set_physics_process(false)
	var idle_state: Dictionary = scene.area_handoff()
	assert(not scene.executioner_enqueue_hit_record(0).event_matched and scene.area_handoff()==idle_state)
	var suppressed: Dictionary = inactive.duplicate(true)
	suppressed.quests.hive_executioner.actor.flags15=20
	assert(scene.apply_area_handoff(suppressed).is_empty())
	var suppressed_before: Dictionary = scene.area_handoff()
	assert(not scene.executioner_enqueue_hit_record(1).event_matched and scene.area_handoff()==suppressed_before)
	assert(scene.apply_area_handoff(inactive).is_empty())
	var registered: Dictionary = scene.executioner_enqueue_hit_record(1)
	assert(not registered.has("error") and registered.inserted==[13,7] and not registered.rejected)
	assert(scene.actor_registry_checkpoint=={"version":1,"active":[36,3],"inactive":[8,9]})
	assert(scene.executioner_runtime.checkpoint().actor.flags16==4 and scene.executioner_runtime.checkpoint().actor.flags17==32)
	var registered_state: Dictionary = scene.area_handoff()
	assert(scene.executioner_enqueue_hit_commands().inserted.is_empty() and scene.area_handoff()==registered_state)
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==registered_state)
	assert(scene.executioner_consume_commands(0).executed==[13,7])
	inactive.quests.hive_executioner.actor.flags16=128
	assert(scene.apply_area_handoff(inactive).is_empty())
	var rejected_before: Dictionary = scene.area_handoff()
	assert(scene.executioner_enqueue_hit_commands().rejected and scene.area_handoff()==rejected_before)
	DirAccess.remove_absolute(path)
	var hit_start: Dictionary = inactive.duplicate(true)
	hit_start.quests.hive_executioner.actor.flags16=0
	hit_start.quests.hive_executioner.actor.merge({"id":36,"a0":255,"b0":300,"word84":0,"stats":outcome_stats},true)
	assert(scene.apply_area_handoff(hit_start).is_empty())
	scene.set_physics_process(false)
	# Compose the source sword request and mitigation with scene health/event saves.
	# Hit admission and upstream context producers are supplied for this test.
	var sword_request := preload("res://scripts/lol2/hive_weapon_request.gd").fine_longsword({"counter43":0,"counter44":0,"flags45":0,"stats":[7,11,13,17],"signed_bonus":-8})
	assert(not sword_request.has("error"))
	var sword_input := {"amount":sword_request.amount,"signature":sword_request.signature,"damage_mask":sword_request.mask,"attacker_heading":0,"target_heading":32768,"mode":1,"scalar":15,"current":300}
	var sword_damage := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").resolve(sword_input)
	assert(not sword_damage.has("error") and sword_damage.loss==17 and sword_damage.remaining==283)
	sword_damage.merge({"mode":0,"definition3c":0,"definition7f":50})
	var before_presentation_failure: Dictionary = scene.area_handoff()
	var bound_visual: RefCounted = scene.get_node("Nest").executioner_visual
	scene.get_node("Nest").executioner_visual=preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
	var failed_visual: Dictionary = scene.executioner_apply_prepared_hit(sword_damage,null,null,{})
	assert(failed_visual.get("error","")=="Executioner sprite is not bound.")
	assert(scene.area_handoff()==before_presentation_failure)
	scene.get_node("Nest").executioner_visual=bound_visual
	var sword_applied: Dictionary = scene.executioner_apply_prepared_hit(sword_damage,null,null,{})
	assert(not sword_applied.has("error"),str(sword_applied))
	assert(sword_applied.checkpoint.actor.health==283 and scene.executioner_command_checkpoint.commands==[13,7])
	assert(scene.actor_registry_checkpoint.active==[36,3])
	var sword_saved: Dictionary = scene.area_handoff()
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==sword_saved)
	# A stale result must not apply a second time after the health changes.
	assert(scene.executioner_apply_prepared_hit(sword_damage,null,null,{}).has("error"))
	assert(scene.area_handoff()==sword_saved)
	DirAccess.remove_absolute(path)
	assert(scene.apply_area_handoff(hit_start).is_empty())
	scene.set_physics_process(false)
	var prepared_hit := {"loss":300,"remaining":0,"mode":0,"definition3c":0,"definition7f":50}
	var hit_world := {"sector":null,"neighbors":[],"sector_flags":[],"peers":[],"group":null}
	var hit_helpers: Dictionary = outcome_helpers.duplicate()
	hit_helpers.release=func(_state):return {"error":"release failed"}
	var hit_before: Dictionary = scene.area_handoff()
	assert(scene.executioner_apply_prepared_hit(prepared_hit,hit_world,outcome_context,hit_helpers).has("error"))
	assert(scene.area_handoff()==hit_before)
	var callback_checks := []
	hit_helpers.release=func(_state):
		callback_checks.append(not scene.executioner_runtime.restore(hit_before.quests.hive_executioner).is_empty())
		callback_checks.append(scene.executioner_apply_prepared_hit(prepared_hit,hit_world,outcome_context,{}).has("error"))
	bound_visual=scene.get_node("Nest").executioner_visual
	scene.get_node("Nest").executioner_visual=preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
	var failed_lethal_visual: Dictionary = scene.executioner_apply_prepared_hit(prepared_hit,hit_world,outcome_context,hit_helpers)
	assert(failed_lethal_visual.get("error","")=="Executioner sprite is not bound.")
	assert(scene.area_handoff()==hit_before and callback_checks==[true,true])
	assert(scene.quicksave(path).is_empty())
	scene.get_node("Nest").executioner_visual=bound_visual
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==hit_before)
	callback_checks.clear()
	var hit_result: Dictionary = scene.executioner_apply_prepared_hit(prepared_hit,hit_world,outcome_context,hit_helpers)
	assert(not hit_result.has("error"),str(hit_result))
	assert(callback_checks==[true,true])
	assert(hit_result.checkpoint.actor.health==0 and hit_result.checkpoint.pose==17)
	assert(scene.executioner_command_checkpoint.commands==[13,7] and scene.actor_registry_checkpoint.active==[36,3])
	assert(scene.executioner_advance(6145).state.frame==7)
	var hit_saved: Dictionary = scene.area_handoff()
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==hit_saved)
	DirAccess.remove_absolute(path)
	var modifiers_start: Dictionary = hit_start.duplicate(true)
	modifiers_start.quests.player_weapon_modifiers={"version":1,"counter43":1,"counter44":2,"flags45":0}
	var reward_seed := {"version":1,"player":{"experience":249,"level":1,"condition":0,"maximum":100,"health":80,"stat151":10,"stat155":12}}
	var reward_applied := preload("res://scripts/lol2/hive_reward_application.gd").award_checkpoint(reward_seed,1,[95,63,32])
	assert(not reward_applied.has("error") and reward_applied.checkpoint.player.level==2 and reward_applied.checkpoint.player.experience==0)
	modifiers_start.quests.player_reward_state=reward_applied.checkpoint
	assert(scene.apply_area_handoff(modifiers_start).is_empty())
	var request_context := {"stats":[7,11,13,17],"signed_bonus":-8}
	var first_request: Dictionary = scene.prepare_fine_longsword_request(request_context)
	assert(not first_request.has("error") and first_request.request.signature==68)
	assert(scene.weapon_modifier_checkpoint.counter44==1 and scene.weapon_modifier_checkpoint.counter43==1)
	var modifier_saved: Dictionary = scene.area_handoff()
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty() and scene.weapon_modifier_checkpoint.is_empty())
	assert(scene.prepare_fine_longsword_request(request_context).has("error"))
	assert(scene.quickload(path).is_empty() and scene.area_handoff()==modifier_saved)
	var jungle_scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle_scene)
	await process_frame
	jungle_scene.set_physics_process(false)
	assert(jungle_scene.apply_area_handoff(modifier_saved).is_empty())
	assert(jungle_scene.quicksave(jungle_path).is_empty())
	assert(jungle_scene.apply_area_handoff(legacy).is_empty())
	assert(jungle_scene.quickload(jungle_path).is_empty())
	assert(scene.apply_area_handoff(jungle_scene.area_handoff()).is_empty())
	assert(scene.weapon_modifier_checkpoint==modifier_saved.quests.player_weapon_modifiers)
	assert(scene.player_reward_checkpoint==reward_applied.checkpoint)
	assert(scene.player_reward_checkpoint.player.maximum==108 and scene.player_reward_checkpoint.player.health==88)
	jungle_scene.queue_free()
	await process_frame
	scene.set_physics_process(false)
	DirAccess.remove_absolute(jungle_path)
	var second_request: Dictionary = scene.prepare_fine_longsword_request(request_context)
	assert(second_request.request.signature==68 and scene.weapon_modifier_checkpoint.counter44==0)
	var third_request: Dictionary = scene.prepare_fine_longsword_request(request_context)
	assert(third_request.request.signature==36 and scene.weapon_modifier_checkpoint.counter43==0 and scene.weapon_modifier_checkpoint.flags45==32)
	assert(scene.prepare_fine_longsword_request(request_context).request.signature==4)
	var reward_before: Dictionary = scene.area_handoff()
	var invalid_reward: Dictionary = reward_before.duplicate(true)
	invalid_reward.quests.player_reward_state.player.level=31
	assert(not scene.apply_area_handoff(invalid_reward).is_empty() and scene.area_handoff()==reward_before)
	var modifiers_before: Dictionary = scene.area_handoff()
	var bad_modifiers: Dictionary = modifiers_before.duplicate(true)
	bad_modifiers.quests.player_weapon_modifiers.counter44=-1
	assert(not scene.apply_area_handoff(bad_modifiers).is_empty() and scene.area_handoff()==modifiers_before)
	assert(scene.prepare_fine_longsword_request({"stats":[],"signed_bonus":0}).has("error"))
	assert(scene.area_handoff()==modifiers_before)
	DirAccess.remove_absolute(path)
	scene.queue_free()
	await process_frame
	print("PASS: scene-owned source/attack/outcome frame rendering, precise save continuation and jungle transport")
	quit(0)
