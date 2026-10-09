extends RefCounted
## Shared Act 1 state. Source flag38 is written at conversation start.
const Numbers = preload("res://scripts/lol2/walkthrough_save.gd")
const DURATIONS := [242.0/15.0,358.0/15.0,208.0/15.0,75.0/15.0]
const NEST_LOOP_DURATION := 36.0/15.0
const NEST_RISE_DURATION := 28.0/15.0
const CHASM_DURATION := 73.0/15.0
static func initial() -> Dictionary:
	return {"jungle_dagger_collected":false,"weapon_shop":preload("res://scripts/lol2/weapon_shop_state.gd").initial(),"act_one_departure":preload("res://scripts/lol2/act_one_departure_state.gd").initial(),"hive_curse":preload("res://scripts/lol2/hive_curse_state.gd").initial(),"hive_elevator":preload("res://scripts/lol2/hive_elevator_state.gd").initial(),"hive_wax_collected":false,"monastery":preload("res://scripts/lol2/monastery_quest_state.gd").initial(),"magic_shop":preload("res://scripts/lol2/magic_shop_state.gd").initial(),"shared_flag_38":0,"jungle_village":preload("res://scripts/lol2/jungle_village_state.gd").initial(),"hive_room_entered":false,"hive_chasm":initial_chasm(),"hive_nest":initial_nest(),"conversation":{"started":false,"completed":false,"section_cursor":0,"elapsed":0.0}}
static func initial_nest(chasm_active: bool = false) -> Dictionary:
	return {"phase":3 if chasm_active else 0,"elapsed":0.0}
static func validate_nest(state: Variant) -> String:
	if not state is Dictionary: return "Invalid Hive nest state."
	var phase = state.get("phase")
	var elapsed = state.get("elapsed")
	if not Numbers._number(phase) or phase != floor(phase) or phase < 0 or phase > 3: return "Invalid Hive nest phase."
	if not Numbers._number(elapsed) or not is_finite(elapsed) or elapsed < 0: return "Invalid Hive nest timing."
	if phase == 3:
		if elapsed != 0: return "Activated executioner cannot retain nest timing."
	elif elapsed >= (NEST_RISE_DURATION if phase == 2 else NEST_LOOP_DURATION): return "Hive nest clip has already ended."
	return ""
static func initial_chasm() -> Dictionary:
	return {"activated":false,"elapsed":0.0}
static func validate_chasm(state: Variant) -> String:
	if not state is Dictionary or not state.get("activated") is bool: return "Invalid Hive chasm state."
	var elapsed = state.get("elapsed")
	if not Numbers._number(elapsed) or not is_finite(elapsed) or elapsed < 0 or elapsed > CHASM_DURATION: return "Invalid Hive chasm timing."
	if not state.activated and elapsed != 0: return "Inactive chasm cannot be moving."
	return ""
static func initial_encounter() -> Dictionary:
	return {"health":30,"enemies":[24,24],"windups":[0.0,0.0],"cooldown":0.0,"pillar_elapsed":0.0}
static func validate_encounter(state: Variant) -> String:
	if not state is Dictionary: return "Invalid Hive encounter."
	var health = state.get("health")
	if not Numbers._number(health) or health != floor(health) or health < 0 or health > 30: return "Invalid encounter health."
	var enemies = state.get("enemies")
	var windups = state.get("windups")
	if not enemies is Array or enemies.size() != 2 or not windups is Array or windups.size() != 2: return "Invalid guardians."
	for i in range(2):
		if not Numbers._number(enemies[i]) or enemies[i] != floor(enemies[i]) or enemies[i] < 0 or enemies[i] > 24: return "Invalid guardian health."
		if not Numbers._number(windups[i]) or not is_finite(windups[i]) or windups[i] < 0 or windups[i] >= 1.5: return "Invalid guardian timing."
		if enemies[i] == 0 and windups[i] != 0: return "Defeated guardian cannot attack."
	for key in ["cooldown","pillar_elapsed"]:
		var value = state.get(key)
		if not Numbers._number(value) or not is_finite(value) or value < 0 or value > (0.45 if key == "cooldown" else 1.0): return "Invalid encounter timing."
	if state.pillar_elapsed > 0 and enemies[0] > 0 and enemies[1] > 0: return "Pillar requires a defeated guardian."
	return ""
static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid Act 1 quest state."
	if state.has("jungle_dagger_collected") and not state.jungle_dagger_collected is bool: return "Invalid Jungle dagger pickup history."
	if state.has("museum_control181"):
		var control_error := preload("res://scripts/lol2/museum_broken_thohan.gd").validate_checkpoint(state.museum_control181)
		if not control_error.is_empty(): return control_error
	var active_rooms := 0
	for room_key in ["monastery","magic_shop","weapon_shop"]:
		if state.get(room_key) is Dictionary and state[room_key].get("room","") != "": active_rooms += 1
	if active_rooms > 1: return "Multiple Act 1 rooms cannot be open together."
	if state.has("act_one_departure"):
		var departure_error := preload("res://scripts/lol2/act_one_departure_state.gd").validate(state.act_one_departure)
		if not departure_error.is_empty(): return departure_error
	if state.has("hive_rune_entry"):
		var rune_error := preload("res://scripts/lol2/hive_rune_entry_state.gd").validate(state.hive_rune_entry)
		if not rune_error.is_empty(): return rune_error
	if state.has("hive_curse"):
		var curse_error := preload("res://scripts/lol2/hive_curse_state.gd").validate(state.hive_curse)
		if not curse_error.is_empty(): return curse_error
	if state.has("hive_elevator"):
		var lift_error := preload("res://scripts/lol2/hive_elevator_state.gd").validate(state.hive_elevator)
		if not lift_error.is_empty(): return lift_error
	if state.has("hive_wax_collected") and not state.hive_wax_collected is bool: return "Invalid Hive wax pickup state."
	if state.has("monastery"):
		var monastery_error := preload("res://scripts/lol2/monastery_quest_state.gd").validate(state.monastery)
		if not monastery_error.is_empty(): return monastery_error
	if state.has("weapon_shop"):
		var weapon_shop_error := preload("res://scripts/lol2/weapon_shop_state.gd").validate(state.weapon_shop)
		if not weapon_shop_error.is_empty(): return weapon_shop_error
	if state.has("magic_shop"):
		var shop_error := preload("res://scripts/lol2/magic_shop_state.gd").validate(state.magic_shop)
		if not shop_error.is_empty(): return shop_error
	if state.has("jungle_village"):
		var gate_error := preload("res://scripts/lol2/jungle_village_state.gd").validate(state.jungle_village)
		if not gate_error.is_empty(): return gate_error
	if state.has("player_magic_reward_state"):
		var magic := preload("res://scripts/lol2/hive_magic_reward.gd").restore(state.player_magic_reward_state)
		if magic.has("error"): return magic.error
	if state.has("player_reward_state"):
		var reward := preload("res://scripts/lol2/hive_reward_application.gd").restore(state.player_reward_state)
		if reward.has("error"): return reward.error
	if state.has("jungle_exit_woman"):
		var exit_woman_error:=preload("res://scripts/lol2/jungle_exit_woman_packet.gd").validate(state.jungle_exit_woman)
		if not exit_woman_error.is_empty(): return exit_woman_error
	if state.has("jungle_bacatta"):
		var bacatta_error:=preload("res://scripts/lol2/jungle_bacatta_packet.gd").validate(state.jungle_bacatta)
		if not bacatta_error.is_empty(): return bacatta_error
	if state.has("jungle_world_items"):
		var items_error:=preload("res://scripts/lol2/jungle_world_items.gd").validate(state.jungle_world_items)
		if not items_error.is_empty(): return items_error
	if state.has("jungle_bacatta65"):
		var bacatta65_error:=preload("res://scripts/lol2/jungle_bacatta65_packet.gd").validate(state.jungle_bacatta65)
		if not bacatta65_error.is_empty(): return bacatta65_error
	if state.has("jungle_inner_gate"):
		var inner_error:=preload("res://scripts/lol2/jungle_inner_gate.gd").validate(state.jungle_inner_gate)
		if not inner_error.is_empty(): return inner_error
	if state.has("jungle_drunk"):
		var drunk_error:=preload("res://scripts/lol2/jungle_drunk_packet.gd").validate(state.jungle_drunk)
		if not drunk_error.is_empty(): return drunk_error
	if state.has("jungle_kityara"):
		var kityara_error:=preload("res://scripts/lol2/jungle_kityara_packet.gd").validate(state.jungle_kityara)
		if not kityara_error.is_empty(): return kityara_error
	if state.has("jungle_chief_hut"):
		var puzzle_error:=preload("res://scripts/lol2/jungle_chief_hut_state.gd").validate(state.jungle_chief_hut)
		if not puzzle_error.is_empty(): return puzzle_error
	if state.has("jungle_village_alarm"):
		var alarm_error:=preload("res://scripts/lol2/jungle_village_alarm_packet.gd").validate(state.jungle_village_alarm)
		if not alarm_error.is_empty(): return alarm_error
	if state.has("jungle_bacatta57"):
		var bacatta57_error:=preload("res://scripts/lol2/jungle_bacatta57_packet.gd").validate(state.jungle_bacatta57)
		if not bacatta57_error.is_empty(): return bacatta57_error
	if state.has("jungle_actor62"):
		var actor62_error:=preload("res://scripts/lol2/jungle_actor62_packet.gd").validate(state.jungle_actor62)
		if not actor62_error.is_empty(): return actor62_error
	if state.has("hive_dawn20"):
		var hive_dawn_error:=preload("res://scripts/lol2/hive_dawn20_packet.gd").validate(state.hive_dawn20)
		if not hive_dawn_error.is_empty(): return hive_dawn_error
	if state.has("jungle_dawn"):
		var dawn_error:=preload("res://scripts/lol2/jungle_dawn_packet.gd").validate(state.jungle_dawn)
		if not dawn_error.is_empty(): return dawn_error
	if state.has("jungle_kelsrick"):
		var kelsrick_error:=preload("res://scripts/lol2/jungle_kelsrick_packet.gd").validate(state.jungle_kelsrick)
		if not kelsrick_error.is_empty(): return kelsrick_error
	if state.has("jungle_exit_encounter"):
		var exit_error:=preload("res://scripts/lol2/jungle_exit_packet.gd").validate(state.jungle_exit_encounter)
		if not exit_error.is_empty(): return exit_error
	if state.has("jungle_villagers"):
		var Villagers=preload("res://scripts/lol2/scripted_creature_state.gd")
		var villager_error:=Villagers.validate(state.jungle_villagers,Villagers.source("res://scripts/lol2/jungle_villager_population_source.json"))
		if not villager_error.is_empty(): return villager_error
	if state.has("jungle_dino_population"):
		var dino_error := preload("res://scripts/lol2/jungle_dino_population_state.gd").validate(state.jungle_dino_population)
		if not dino_error.is_empty(): return dino_error
	if state.has("cave_melee_seed"):
		if not state.has("player_reward_state") or not preload("res://scripts/lol2/save_value_rules.gd").integer(state.cave_melee_seed,0x7fffffff): return "Invalid cave melee reward RNG."
	if state.has("player_weapon_modifiers"):
		var modifiers := preload("res://scripts/lol2/hive_weapon_request.gd").restore_modifiers(state.player_weapon_modifiers)
		if modifiers.has("error"): return modifiers.error
	if state.has("hive_boulder_surfaces"):
		var boulder_error := preload("res://scripts/lol2/hive_boulder_sequence.gd").validate(state.hive_boulder_surfaces)
		if not boulder_error.is_empty(): return boulder_error
	if state.has("hive_boulder_actor_schema"):
		if not preload("res://scripts/lol2/save_value_rules.gd").integer(state.hive_boulder_actor_schema,1) or state.hive_boulder_actor_schema!=1 or not state.has("hive_boulder_actors"): return "Missing boulder actor save packet."
	if state.has("hive_boulder_actors"):
		var actor_error := preload("res://scripts/lol2/hive_boulder_actor_state.gd").validate(state.hive_boulder_actors)
		if not actor_error.is_empty(): return actor_error
		if not state.has("hive_boulder_surfaces"): return "Boulders require saved surfaces."
		var phase: int=int(state.hive_boulder_surfaces.phase)
		if state.hive_boulder_actors.legacy_retired:
			if phase<2: return "Legacy boulders retired before activation."
		else:
			for actor in state.hive_boulder_actors.actors.values():
				if actor.active!=(phase>=2) or actor.stopping!=(phase>=3): return "Boulder actors disagree with saved surfaces."
	if state.has("hive_rune_population_schema"):
		if not preload("res://scripts/lol2/save_value_rules.gd").integer(state.hive_rune_population_schema,1) or state.hive_rune_population_schema!=1 or not state.has("hive_rune_population"): return "Missing rune population save packet."
	if state.has("hive_rune_population"):
		var rune_error:=preload("res://scripts/lol2/hive_rune_population_state.gd").validate(state.hive_rune_population)
		if not rune_error.is_empty(): return rune_error
	if state.has("hive_boulder_contact_schema"):
		if not preload("res://scripts/lol2/save_value_rules.gd").integer(state.hive_boulder_contact_schema,1) or state.hive_boulder_contact_schema!=1 or not state.has("hive_boulder_contact"): return "Missing boulder contact save packet."
	if state.has("hive_boulder_contact"):
		var contact_error:=preload("res://scripts/lol2/hive_boulder_contact_state.gd").validate(state.hive_boulder_contact)
		if not contact_error.is_empty(): return contact_error
		if not state.has("hive_boulder_actors"): return "Boulder contact requires saved actors."
	if state.has("hive_boulder_audio_schema"):
		if not preload("res://scripts/lol2/save_value_rules.gd").integer(state.hive_boulder_audio_schema,1) or state.hive_boulder_audio_schema!=1 or not state.has("hive_boulder_audio"): return "Missing boulder audio save packet."
	if state.has("hive_boulder_audio"):
		var audio_error:=preload("res://scripts/lol2/hive_boulder_audio_state.gd").validate(state.hive_boulder_audio)
		if not audio_error.is_empty(): return audio_error
		if not state.has("hive_boulder_surfaces") or not state.has("hive_boulder_actors"): return "Boulder audio requires saved owners."
		audio_error=preload("res://scripts/lol2/hive_boulder_audio_state.gd").validate_context(state.hive_boulder_audio,state.hive_boulder_surfaces,state.hive_boulder_actors)
		if not audio_error.is_empty(): return audio_error
	if state.has("hive_ambush"):
		var ambush_error := preload("res://scripts/lol2/hive_ambush_state.gd").validate(state.hive_ambush)
		if not ambush_error.is_empty(): return ambush_error
	if state.has("hive_return_population"):
		var population_error := preload("res://scripts/lol2/hive_return_population_state.gd").validate(state.hive_return_population)
		if not population_error.is_empty(): return population_error
	if state.has("hive_executioner_live"):
		var live_error := preload("res://scripts/lol2/hive_executioner_live.gd").validate(state.hive_executioner_live)
		if not live_error.is_empty(): return live_error
	if state.has("hive_executioner"):
		var owner = preload("res://scripts/lol2/hive_executioner_runtime.gd").new()
		var error: String = owner.restore(state.hive_executioner)
		if not error.is_empty(): return error
	if state.has("hive_actor_registry"):
		if not state.has("hive_executioner"): return "Actor registry requires executioner state."
		var registry := preload("res://scripts/lol2/hive_actor_registry.gd").restore(state.hive_actor_registry)
		if registry.has("error"): return registry.error
		var flags: Variant = state.hive_executioner.actor.get("flags17")
		if not preload("res://scripts/lol2/hive_clock_runtime.gd")._integer(flags,255): return "Missing executioner registry flags."
		if ((int(flags)&32)!=0)!=(36 in registry.checkpoint.active): return "Executioner registry membership disagrees with actor flags."
	if state.has("hive_executioner_commands"):
		if not state.has("hive_executioner"): return "Executioner commands require actor state."
		var commands := preload("res://scripts/lol2/hive_executioner_command_queue.gd").restore(state.hive_executioner_commands)
		if commands.has("error"): return commands.error
	if state.has("hive_outcome_world"):
		if not state.has("hive_executioner"): return "Outcome world requires its executioner checkpoint."
		var world := preload("res://scripts/lol2/hive_outcome_world.gd").restore_checkpoint(state.hive_outcome_world)
		if world.has("error"): return world.error
		var actor: Dictionary = state.hive_executioner.actor
		var actor_error: String = preload("res://scripts/lol2/hive_outcome_preparation.gd").validate_actor(actor)
		if not actor_error.is_empty(): return actor_error
		if int(actor.a0)!=255:
			var group: Variant = world.checkpoint.group
			if group==null or int(group.index)!=int(actor.a0): return "Saved outcome group disagrees with actor."
			var member: int = group.members.find(int(actor.id))
			if member<0 or int(group.flags[member])!=int(actor.b4): return "Saved outcome member disagrees with actor."
	if state.has("hive_runtime_schedule"):
		var schedule := preload("res://scripts/lol2/hive_ai_schedule.gd").restore(state.hive_runtime_schedule)
		if schedule.has("error"): return schedule.error
	if state.has("hive_runtime_timing"):
		var timing := preload("res://scripts/lol2/hive_timing_state.gd").restore(state.hive_runtime_timing)
		if timing.has("error"): return timing.error
	if state.has("hive_executioner_markers"):
		var markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
		var loaded: Dictionary = markers.load_hive_bank()
		if loaded.has("error"): return loaded.error
		var restored: Dictionary = markers.restore(loaded.bank,state.hive_executioner_markers)
		if restored.has("error"): return restored.error
	if state.has("hive_executioner") and state.has("hive_executioner_markers") and state.hive_executioner.actor.has("word7c"):
		if state.hive_executioner.actor.word7c!=state.hive_executioner_markers.counter: return "Executioner marker and command counters disagree."
	if state.has("hive_nest"):
		var error := validate_nest(state.hive_nest)
		if not error.is_empty(): return error
	if state.has("hive_chasm"):
		var error := validate_chasm(state.hive_chasm)
		if not error.is_empty(): return error
	if state.has("hive_encounter"):
		var error := validate_encounter(state.hive_encounter)
		if not error.is_empty(): return error
	if state.has("hive_return_population"):
		var population = preload("res://scripts/lol2/hive_return_population_state.gd")
		for group in population.GROUPS:
			var admitted: bool = (state.get("shared_flag_38",0) if group==366 else state.get("monastery",{}).get("globals",{}).get("GV_MET_BACATTA",0))==1
			for id in population.GROUPS[group]:
				if state.hive_return_population.actors[str(id)].active and not admitted: return "Return warrior lacks its quest history."
	if state.has("hive_rune_population"):
		for id in state.hive_rune_population.slots:
			if state.hive_rune_population.slots[id].phase==0: continue
			var health: int=1
			if int(id) in [32,34]:
				health=int(state.get("hive_encounter",initial_encounter()).enemies[0 if id=="32" else 1])
			elif id=="36": health=int(state.get("hive_executioner_live",{}).get("health",1))
			else:
				var packet: String="hive_ambush" if int(id) in [33,35] else "hive_return_population"
				health=int(state.get(packet,{}).get("actors",{}).get(id,{}).get("health",1))
			if health!=0: return "Reusable slot still has a living original actor."
	var flag = state.get("shared_flag_38")
	if not Numbers._number(flag) or (flag != 0 and flag != 1): return "Invalid shared quest flag."
	var conversation = state.get("conversation")
	if not conversation is Dictionary: return "Invalid conversation state."
	if not conversation.get("started") is bool or not conversation.get("completed") is bool: return "Invalid conversation status."
	if state.has("hive_encounter") and state.hive_encounter.health == 0 and conversation.started and not conversation.completed: return "Defeated player cannot be speaking."
	var entered = state.get("hive_room_entered", conversation.started)
	if not entered is bool: return "Invalid Hive room state."
	if conversation.started and not entered: return "Conversation requires Hive room admission."
	var cursor = conversation.get("section_cursor")
	var elapsed = conversation.get("elapsed")
	if not Numbers._number(cursor) or cursor != floor(cursor) or cursor < 0 or cursor > 3: return "Invalid conversation section."
	if not Numbers._number(elapsed) or not is_finite(elapsed) or elapsed < 0 or elapsed > DURATIONS[int(cursor)]: return "Invalid conversation time."
	if flag != int(conversation.started): return "Conversation and quest flag disagree."
	if not conversation.started:
		if conversation.completed or cursor != 0 or elapsed != 0: return "Invalid unstarted conversation."
	elif conversation.completed:
		if cursor != 3 or elapsed != DURATIONS[3]: return "Invalid completed conversation."
	elif elapsed >= DURATIONS[int(cursor)]: return "Conversation section has already ended."
	return ""
