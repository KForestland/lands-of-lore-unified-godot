extends RefCounted
## Shared Act 1 state. Source flag38 is written at conversation start.
const Numbers = preload("res://scripts/lol2/walkthrough_save.gd")
const DURATIONS := [242.0/15.0,358.0/15.0,208.0/15.0,75.0/15.0]
const NEST_LOOP_DURATION := 36.0/15.0
const NEST_RISE_DURATION := 28.0/15.0
const CHASM_DURATION := 73.0/15.0
static func initial() -> Dictionary:
	return {"jungle_dagger_collected":false,"weapon_shop":preload("res://scripts/lol2/weapon_shop_state.gd").initial(),"act_one_departure":preload("res://scripts/lol2/act_one_departure_state.gd").initial(),"hive_curse":preload("res://scripts/lol2/hive_curse_state.gd").initial(),"hive_elevator":preload("res://scripts/lol2/hive_elevator_state.gd").initial(),"hive_wax_collected":false,"monastery":preload("res://scripts/lol2/monastery_quest_state.gd").initial(),"magic_shop":preload("res://scripts/lol2/magic_shop_state.gd").initial(),"thieves_den":preload("res://scripts/lol2/thieves_den_state.gd").initial(),"weapon_poison":preload("res://scripts/lol2/weapon_poison.gd").initial(),"shared_flag_38":0,"jungle_village":preload("res://scripts/lol2/jungle_village_state.gd").initial(),"hive_room_entered":false,"hive_chasm":initial_chasm(),"hive_nest":initial_nest(),"conversation":{"started":false,"completed":false,"section_cursor":0,"elapsed":0.0}}
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
	if state.has("l8_tree_bridge"):
		var bridge_error: String = preload("res://scripts/lol2/l8_tree_bridge.gd").validate(state.l8_tree_bridge, state)
		if not bridge_error.is_empty(): return bridge_error
	if state.has("l8_cache_ladder"):
		var ladder_error: String = preload("res://scripts/lol2/l8_cache_ladder.gd").validate(state.l8_cache_ladder, state)
		if not ladder_error.is_empty(): return ladder_error
	if state.has("l14_quill"):
		var quill_error: String = preload("res://scripts/lol2/l14_quill.gd").validate(state.l14_quill, state)
		if not quill_error.is_empty(): return quill_error
	if state.has("l14_spider_burrow"):
		var burrow_error: String = preload("res://scripts/lol2/l14_spider_burrow.gd").validate(state.l14_spider_burrow, state)
		if not burrow_error.is_empty(): return burrow_error
	if state.has("l8_tree"):
		var tree_error:=preload("res://scripts/lol2/l8_tree.gd").validate(state.l8_tree,state)
		if not tree_error.is_empty():return tree_error
	if state.has("l14_spider_passage"):
		var spider_error:=preload("res://scripts/lol2/l14_spider_passage.gd").validate(state.l14_spider_passage,state)
		if not spider_error.is_empty():return spider_error
	if state.has("l14_machines"):
		var machine_error:=preload("res://scripts/lol2/l14_machines.gd").validate(state.l14_machines,state)
		if not machine_error.is_empty():return machine_error
	if state.has("l14_belial"):
		var belial_error:=preload("res://scripts/lol2/l14_belial.gd").validate(state.l14_belial,state)
		if not belial_error.is_empty():return belial_error
	if state.has("l14_hopper_return"):
		var hopper_return_error:=preload("res://scripts/lol2/l14_hopper_platform.gd").validate_return(state.l14_hopper_return,state)
		if not hopper_return_error.is_empty():return hopper_return_error
	if state.has("l14_hopper_platform"):
		var hopper_error:=preload("res://scripts/lol2/l14_hopper_platform.gd").validate(state.l14_hopper_platform,state)
		if not hopper_error.is_empty():return hopper_error
	if state.has("l14_idol_pedestals"):
		var idol_error:=preload("res://scripts/lol2/l14_idol_pedestals.gd").validate(state.l14_idol_pedestals,state)
		if not idol_error.is_empty():return idol_error
	if state.has("l14_trap_route"):
		var trap_error:=preload("res://scripts/lol2/l14_trap_route.gd").validate(state.l14_trap_route,state)
		if not trap_error.is_empty():return trap_error
	if state.has("l16_sw_chips"):
		var sw_error: String = preload("res://scripts/lol2/l16_sw_chips.gd").validate(state.l16_sw_chips,state)
		if not sw_error.is_empty(): return sw_error
	if state.has("l19_beast_wall"):
		var beast_error: String = preload("res://scripts/lol2/l19_beast_wall.gd").validate(state.l19_beast_wall,state)
		if not beast_error.is_empty(): return beast_error
	if state.has("l17_beast_blade"):
		var blade_error: String = preload("res://scripts/lol2/l17_beast_blade.gd").validate(state.l17_beast_blade,state)
		if not blade_error.is_empty(): return blade_error
	if state.has("l19_belial_horn"):
		var horn_error: String = preload("res://scripts/lol2/l19_belial_horn.gd").validate(state.l19_belial_horn,state)
		if not horn_error.is_empty(): return horn_error
	if state.has("l19_sewer_forms"):
		var form_error: String = preload("res://scripts/lol2/l19_sewer_forms.gd").validate(state.l19_sewer_forms,state)
		if not form_error.is_empty(): return form_error
	if state.has("l19_drain_path"):
		var path_error: String = preload("res://scripts/lol2/l19_drain_path.gd").validate(state.l19_drain_path,state)
		if not path_error.is_empty(): return path_error
	if state.has("l19_ghostly_heads"):
		var head_error: String = preload("res://scripts/lol2/l19_ghostly_heads.gd").validate(state.l19_ghostly_heads,state)
		if not head_error.is_empty(): return head_error
	if state.has("l19_dawn_curse"):
		var dawn_error: String = preload("res://scripts/lol2/l19_dawn_curse.gd").validate(state.l19_dawn_curse,state)
		if not dawn_error.is_empty(): return dawn_error
	if state.has("l20_pillars"):
		var pillar_error: String = preload("res://scripts/lol2/l20_pillars_scotia.gd").validate(state.l20_pillars,state)
		if not pillar_error.is_empty(): return pillar_error
	if state.has("l20_armory"):
		var armory_error: String = preload("res://scripts/lol2/l20_armory.gd").validate(state.l20_armory,state)
		if not armory_error.is_empty(): return armory_error
	if state.has("l20_faux_draracle"):
		var drar_error: String = preload("res://scripts/lol2/l20_faux_draracle.gd").validate(state.l20_faux_draracle,state)
		if not drar_error.is_empty(): return drar_error
	if state.has("l20_finale"):
		var finale_error: String = preload("res://scripts/lol2/l20_finale.gd").validate(state.l20_finale,state)
		if not finale_error.is_empty(): return finale_error
	if state.has("l16_fountain_ball"):
		var ball_error:=preload("res://scripts/lol2/l16_fountain_ball.gd").validate(state.l16_fountain_ball,state)
		if not ball_error.is_empty(): return ball_error
	if state.has("l16_nw_traps"):
		var nw_error: String = preload("res://scripts/lol2/l16_nw_traps.gd").validate(state.l16_nw_traps,state)
		if not nw_error.is_empty(): return nw_error
	if state.has("l17_cavern_run"):
		var cavern_error: String = preload("res://scripts/lol2/l17_cavern_run.gd").validate(state.l17_cavern_run,state)
		if not cavern_error.is_empty(): return cavern_error
	if state.has("l16_greenhouse"):
		var gh_error:=preload("res://scripts/lol2/l16_greenhouse.gd").validate(state.l16_greenhouse,state)
		if not gh_error.is_empty(): return gh_error
	if state.has("l16_se_oil"):
		var oil_error: String = preload("res://scripts/lol2/l16_se_oil.gd").validate(state.l16_se_oil,state)
		if not oil_error.is_empty(): return oil_error
	if state.has("l16_dragon_room"):
		var dragon_error: String = preload("res://scripts/lol2/l16_dragon_room.gd").validate(state.l16_dragon_room,state)
		if not dragon_error.is_empty(): return dragon_error
	if state.has("l16_dry_fountain"):
		var fountain_error:=preload("res://scripts/lol2/l16_dry_fountain.gd").validate(state.l16_dry_fountain,state)
		if not fountain_error.is_empty(): return fountain_error
	if state.has("l16_ne_tower"):
		var ne_error: String = preload("res://scripts/lol2/l16_ne_tower.gd").validate(state.l16_ne_tower,state)
		if not ne_error.is_empty(): return ne_error
	if state.has("l16_centre_tower"):
		var centre_error: String = preload("res://scripts/lol2/l16_centre_tower.gd").validate(state.l16_centre_tower,state)
		if not centre_error.is_empty(): return centre_error
	if state.has("l14_chamber_voices"):
		var chv_error:=preload("res://scripts/lol2/l14_chamber_voices.gd").validate(state.l14_chamber_voices,state)
		if not chv_error.is_empty(): return chv_error
	if state.has("l14_flute_slot"):
		var flute_error:=preload("res://scripts/lol2/l14_flute_slot.gd").validate(state.l14_flute_slot,state)
		if not flute_error.is_empty():return flute_error
	if state.has("l14_fire_paths"):
		var fire_error:=preload("res://scripts/lol2/l14_fire_paths.gd").validate(state.l14_fire_paths,state)
		if not fire_error.is_empty():return fire_error
	if state.has("l14_tilt"):
		var tilt_error:=preload("res://scripts/lol2/l14_tilt.gd").validate(state.l14_tilt,state)
		if not tilt_error.is_empty():return tilt_error
	if state.has("l14_trials"):
		var trials_error:=preload("res://scripts/lol2/l14_trials.gd").validate(state.l14_trials,state)
		if not trials_error.is_empty():return trials_error
	if state.has("l14_spiral"):
		var spiral_error:=preload("res://scripts/lol2/l14_spiral.gd").validate(state.l14_spiral,state)
		if not spiral_error.is_empty():return spiral_error
	if state.has("l14_shard_bowls"):
		var bowls_error:=preload("res://scripts/lol2/l14_shard_bowls.gd").validate(state.l14_shard_bowls,state)
		if not bowls_error.is_empty():return bowls_error
	if state.has("l14_niche"):
		var niche_error:=preload("res://scripts/lol2/l14_niche.gd").validate(state.l14_niche,state)
		if not niche_error.is_empty():return niche_error
	if state.has("l14_library"):
		var library_error:=preload("res://scripts/lol2/l14_library.gd").validate(state.l14_library,state)
		if not library_error.is_empty():return library_error
	if state.has("l14_bedroom"):
		var bedroom_error:=preload("res://scripts/lol2/l14_bedroom.gd").validate(state.l14_bedroom,state)
		if not bedroom_error.is_empty():return bedroom_error
	if state.has("l14_hanging"):
		var hanging_error:=preload("res://scripts/lol2/l14_hanging.gd").validate(state.l14_hanging,state)
		if not hanging_error.is_empty():return hanging_error
	if state.has("l14_post_shard"):
		var shard_error:=preload("res://scripts/lol2/l14_post_shard.gd").validate(state.l14_post_shard,state)
		if not shard_error.is_empty():return shard_error
	if state.has("l14_priest_ritual"):
		var ritual_error:=preload("res://scripts/lol2/l14_priest_ritual.gd").validate(state.l14_priest_ritual,state)
		if not ritual_error.is_empty():return ritual_error
	if state.has("l14_priest_body"):
		var body_error:=preload("res://scripts/lol2/l14_priest_body.gd").validate(state.l14_priest_body,state)
		if not body_error.is_empty():return body_error
	if state.has("l8_temple_door"):
		var temple_error:=preload("res://scripts/lol2/l8_temple_door_state.gd").validate(state.l8_temple_door,state)
		if not temple_error.is_empty():return temple_error
	if state.has("l13_exit_lock"):
		var exit_error:=preload("res://scripts/lol2/l13_exit_lock_state.gd").validate(state.l13_exit_lock,state)
		if not exit_error.is_empty():return exit_error
	if state.has("l13_return_pad"):
		var return_error:=preload("res://scripts/lol2/l13_return_pad.gd").validate(state.l13_return_pad,state)
		if not return_error.is_empty():return return_error
	if state.has("l13_altar"):
		var altar_error:=preload("res://scripts/lol2/l13_altar_state.gd").validate(state.l13_altar,state)
		if not altar_error.is_empty():return altar_error
	if state.has("l13_belial"):
		var belial_error:=preload("res://scripts/lol2/l13_belial.gd").validate(state.l13_belial,state)
		if not belial_error.is_empty():return belial_error
	if state.has("l13_bridge"):
		var bridge_error:=preload("res://scripts/lol2/l13_bridge.gd").validate(state.l13_bridge)
		if not bridge_error.is_empty():return bridge_error
	if state.has("l13_dawn_release"):
		var release_error:=preload("res://scripts/lol2/l13_dawn_release.gd").validate(state.l13_dawn_release,state)
		if not release_error.is_empty():return release_error
	if state.has("l13_dawn_prison"):
		var dawn_error:=preload("res://scripts/lol2/l13_dawn_prison.gd").validate(state.l13_dawn_prison,state)
		if not dawn_error.is_empty():return dawn_error
	if state.has("l13_spires"):
		var spire_error:=preload("res://scripts/lol2/l13_spires.gd").validate(state.l13_spires)
		if not spire_error.is_empty():return spire_error
	if state.has("l13_prison"):
		var prison_error:=preload("res://scripts/lol2/l13_prison.gd").validate(state.l13_prison,state)
		if not prison_error.is_empty():return prison_error
	if state.has("l13_elevator"):
		var lift_error:=preload("res://scripts/lol2/l13_elevator.gd").validate_lift(state.l13_elevator)
		if not lift_error.is_empty():return lift_error
	if state.has("l13_eggs"):
		var eggs_error:=preload("res://scripts/lol2/l13_eggs.gd").validate(state.l13_eggs,state)
		if not eggs_error.is_empty():return eggs_error
	if state.has("l13_egg_door"):
		var door_error:=preload("res://scripts/lol2/l13_egg_door.gd").validate(state.l13_egg_door)
		if not door_error.is_empty():return door_error
	if state.has("l12_citadel"):
		var citadel_error:=preload("res://scripts/lol2/l12_citadel_state.gd").validate(state.l12_citadel,state)
		if not citadel_error.is_empty():return citadel_error
	if state.has("l12_frozen_bow"):
		var frozen_error:=preload("res://scripts/lol2/l12_frozen_bow.gd").validate(state.l12_frozen_bow,state)
		if not frozen_error.is_empty():return frozen_error
	if state.has("l12_crevasse"):
		var crevasse_error:=preload("res://scripts/lol2/l12_crevasse.gd").validate(state.l12_crevasse)
		if not crevasse_error.is_empty():return crevasse_error
	if state.has("l12_niche_armor"):
		var armor_error:=preload("res://scripts/lol2/l12_niche_armor.gd").validate(state.l12_niche_armor,state)
		if not armor_error.is_empty():return armor_error
	if state.has("l12_river_rafts"):
		var raft_error:=preload("res://scripts/lol2/l12_river_rafts.gd").validate(state.l12_river_rafts)
		if not raft_error.is_empty():return raft_error
	if state.has("l12_glacier"):
		var glacier_error:=preload("res://scripts/lol2/l12_glacier_state.gd").validate(state.l12_glacier)
		if not glacier_error.is_empty():return glacier_error
	if state.has("l8_larkhon"):
		var larkhon_error:=preload("res://scripts/lol2/l8_larkhon_state.gd").validate(state.l8_larkhon,state)
		if not larkhon_error.is_empty():return larkhon_error
	if state.has("l8_huline_speech"):
		var speech_error:=preload("res://scripts/lol2/l8_huline_speech_state.gd").validate(state.l8_huline_speech)
		if not speech_error.is_empty():return speech_error
	if state.has("l8_clubhouse"):
		var club_error:=preload("res://scripts/lol2/l8_clubhouse.gd").validate(state.l8_clubhouse,state)
		if not club_error.is_empty():return club_error
	if state.has("l8_shaman_trade"):
		var shaman_error:=preload("res://scripts/lol2/l8_shaman_trade.gd").validate(state.l8_shaman_trade,state)
		if not shaman_error.is_empty():return shaman_error
	if state.has("l8_tribe"):
		var tribe_error:=preload("res://scripts/lol2/l8_tribe_state.gd").validate(state.l8_tribe,state)
		if not tribe_error.is_empty():return tribe_error
	if state.has("l10_silverleaf_harvest"):
		var harvest_error:=preload("res://scripts/lol2/l10_silverleaf_harvest.gd").validate(state.l10_silverleaf_harvest,state)
		if not harvest_error.is_empty():return harvest_error
	if state.has("l10_silverleaf"):
		var silverleaf_error:=preload("res://scripts/lol2/l10_silverleaf.gd").validate(state.l10_silverleaf,state)
		if not silverleaf_error.is_empty():return silverleaf_error
	if state.has("l8_baccata"):
		var baccata_error:=preload("res://scripts/lol2/l8_baccata.gd").validate(state.l8_baccata)
		if not baccata_error.is_empty():return baccata_error
		if state.l8_baccata.phase>0 and not state.get("l8_shore",{}).get("arrived",false):return "Baccata rescue requires the earned shore return."
	if state.has("l8_dawn"):
		var dawn_error:=preload("res://scripts/lol2/l8_dawn_state.gd").validate(state.l8_dawn,state)
		if not dawn_error.is_empty():return dawn_error
	if state.has("l8_shore"):
		var shore_error:=preload("res://scripts/lol2/l8_shore.gd").validate(state.l8_shore)
		if not shore_error.is_empty():return shore_error
		if state.l8_shore.arrived and not state.get("l9_escape",{}).get("escaped",false):return "Shore arrival requires the earned raft escape."
	if state.has("l9_escape"):
		var escape_error:=preload("res://scripts/lol2/l9_escape_state.gd").validate(state.l9_escape)
		if not escape_error.is_empty():return escape_error
		if not state.get("l9_statue_walk",{}).get("fight_done",false):return "Ruins escape requires the earned statue fight."
	if state.has("l9_flood"):
		var flood_error:=preload("res://scripts/lol2/l9_flood_state.gd").validate(state.l9_flood)
		if not flood_error.is_empty():return flood_error
		if not state.get("l9_statue_walk",{}).get("fight_done",false):return "Ruins flood requires the earned statue fight."
	if state.has("l9_statue_walk"):
		var walk_error := preload("res://scripts/lol2/l9_statue_walk.gd").validate(state.l9_statue_walk)
		if not walk_error.is_empty():return walk_error
		if not preload("res://scripts/lol2/l9_statue_state.gd").offered(state.get("l9_statue",{})):return "Walking statue requires the remains offering."
	if state.has("act2_chargers"):
		var charger_error := preload("res://scripts/lol2/act2_charger_state.gd").transport_error(state)
		if not charger_error.is_empty(): return charger_error
	if state.has("l9_statue"):
		var statue_error := preload("res://scripts/lol2/l9_statue_state.gd").validate(state.l9_statue,state.get("act2_items",{}).get("carried",[]))
		if not statue_error.is_empty():return statue_error
		if preload("res://scripts/lol2/l9_statue_state.gd").offered(state.l9_statue) and not state.get("l10_emperor",{}).get("remains",false):return "Statue bowl requires the earned Emperor remains."
	if state.has("l9_pyre"):
		var pyre_error := preload("res://scripts/lol2/l9_pyre_state.gd").validate(state.l9_pyre)
		if not pyre_error.is_empty(): return pyre_error
	if state.has("l9_noble_rails"):
		var rail_error := preload("res://scripts/lol2/l9_noble_rails.gd").validate(state.l9_noble_rails)
		if not rail_error.is_empty(): return rail_error
	if state.has("l9_mirrors"):
		var mirrors_error := preload("res://scripts/lol2/l9_mirrors.gd").validate(state.l9_mirrors)
		if not mirrors_error.is_empty():return mirrors_error
	if state.has("l9_dead_bracers"):
		var shield_error := preload("res://scripts/lol2/l9_dead_bracers.gd").validate(state.l9_dead_bracers)
		if not shield_error.is_empty():return shield_error
	if state.has("l9_tower"):
		var tower_error := preload("res://scripts/lol2/l9_tower.gd").validate(state.l9_tower)
		if not tower_error.is_empty(): return tower_error
	if state.has("l9_magic_bridge"):
		var bridge_error := preload("res://scripts/lol2/l9_magic_bridge.gd").validate(state.l9_magic_bridge)
		if not bridge_error.is_empty(): return bridge_error
	if state.has("l10_emperor"):
		var emperor_error := preload("res://scripts/lol2/l10_emperor_state.gd").validate(state.l10_emperor,state.get("act2_items",{}).get("carried",[]))
		if not emperor_error.is_empty():return emperor_error
		if state.l10_emperor.remains!=("act2:L10_DC:emperor_remains" in state.get("act2_items",{}).get("collected",[])):return "Emperor remains and reward history disagree."
	if state.has("l10_ankh"):
		var ankh_error := preload("res://scripts/lol2/l10_ankh_state.gd").validate(state.l10_ankh)
		if not ankh_error.is_empty():return ankh_error
		if preload("res://scripts/lol2/l10_ankh_state.gd").committed(state.l10_ankh,"priest:ashes") and (not state.get("l10_priest",{}).get("urn_given",false) or "act2:L10_DC:priest_ankh" not in state.get("act2_items",{}).get("collected",[])):return "Ankh requires the priest errand and reward history."
	if state.has("l10_priest") or "act2:L10_DC:priest_urn" in state.get("act2_items",{}).get("collected",[]):
		var priest_error := preload("res://scripts/lol2/l10_priest.gd").validate(state.get("l10_priest",{}),state)
		if not priest_error.is_empty():return priest_error
	if state.has("l10_oil"):
		var oil_error := preload("res://scripts/lol2/l10_oil.gd").validate(state.l10_oil)
		if not oil_error.is_empty():return oil_error
		if state.l10_oil.burned and state.get("l10_barrel",{}).get("phase",0)!=2:return "Burned oil requires the earned barrel spill."
	if state.has("l10_barrel"):
		var barrel_error := preload("res://scripts/lol2/l10_barrel.gd").validate(state.l10_barrel)
		if not barrel_error.is_empty(): return barrel_error
	if state.has("l10_braziers"):
		var brazier_error := preload("res://scripts/lol2/l10_braziers.gd").validate(state.l10_braziers)
		if not brazier_error.is_empty(): return brazier_error
	if state.has("l10_tombs"):
		var tomb_error := preload("res://scripts/lol2/l10_tomb_state.gd").validate(state.l10_tombs,state)
		if not tomb_error.is_empty(): return tomb_error
	if state.has("l8_backroom"):
		var news_error := preload("res://scripts/lol2/l8_backroom.gd").validate(state.l8_backroom)
		if not news_error.is_empty(): return news_error
	if state.has("l8_herbalist"):
		var herb_error := preload("res://scripts/lol2/l8_herbalist.gd").validate(state.l8_herbalist)
		if not herb_error.is_empty(): return herb_error
	if state.has("l10_main_gate"):
		var gate_error := preload("res://scripts/lol2/l10_main_gate.gd").validate(state.l10_main_gate)
		if not gate_error.is_empty(): return gate_error
	if state.has("l8_journey"):
		var journey_error := preload("res://scripts/lol2/l8_journey_state.gd").validate(state.l8_journey)
		if not journey_error.is_empty(): return journey_error
	if state.has("jungle_dagger_collected") and not state.jungle_dagger_collected is bool: return "Invalid Jungle dagger pickup history."
	if state.has("museum_control181"):
		var control_error := preload("res://scripts/lol2/museum_broken_thohan.gd").validate_checkpoint(state.museum_control181)
		if not control_error.is_empty(): return control_error
	var active_rooms := 0
	for room_key in ["monastery","magic_shop","weapon_shop","thieves_den"]:
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
	if state.has("hive_world_items"):
		var hive_items_error := preload("res://scripts/lol2/hive_world_items_state.gd").validate(state.hive_world_items)
		if not hive_items_error.is_empty(): return hive_items_error
	for area in ["darkhalls", "darkerjungle"]:
		var area_key: String = preload("res://scripts/lol2/area_world_items_state.gd").key(area)
		if state.has(area_key):
			var area_items_error: String = preload("res://scripts/lol2/area_world_items_state.gd").validate(state[area_key], area)
			if not area_items_error.is_empty(): return area_items_error
	if state.has("monastery"):
		var monastery_error := preload("res://scripts/lol2/monastery_quest_state.gd").validate(state.monastery)
		if not monastery_error.is_empty(): return monastery_error
	if state.has("weapon_shop"):
		var weapon_shop_error := preload("res://scripts/lol2/weapon_shop_state.gd").validate(state.weapon_shop)
		if not weapon_shop_error.is_empty(): return weapon_shop_error
	if state.has("magic_shop"):
		var shop_error := preload("res://scripts/lol2/magic_shop_state.gd").validate(state.magic_shop)
		if not shop_error.is_empty(): return shop_error
	if state.has("thieves_den"):
		var den_error := preload("res://scripts/lol2/thieves_den_state.gd").validate(state.thieves_den)
		if not den_error.is_empty(): return den_error
	if state.has("weapon_poison"):
		var poison_error := preload("res://scripts/lol2/weapon_poison.gd").validate(state.weapon_poison)
		if not poison_error.is_empty(): return poison_error
	if state.has("jungle_bridge"):
		var bridge_error := preload("res://scripts/lol2/jungle_bridge_break_state.gd").validate(state.jungle_bridge,preload("res://scripts/lol2/jungle_bridge_break_state.gd").source())
		if not bridge_error.is_empty(): return bridge_error
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
	if state.has("jungle_confidante"):
		var confidante_error:=preload("res://scripts/lol2/jungle_confidante_packet.gd").validate(state.jungle_confidante)
		if not confidante_error.is_empty(): return confidante_error
	if state.has("jungle_gate_leaves"):
		var leaves_error:=preload("res://scripts/lol2/jungle_gate_leaves.gd").validate(state.jungle_gate_leaves)
		if not leaves_error.is_empty(): return leaves_error
	if state.has("jungle_beehives"):
		var hive_error:=preload("res://scripts/lol2/jungle_beehives_state.gd").validate(state.jungle_beehives)
		if not hive_error.is_empty(): return hive_error
	if state.has("jungle_harvest"):
		var harvest_error:=preload("res://scripts/lol2/jungle_harvest_state.gd").validate(state.jungle_harvest)
		if not harvest_error.is_empty(): return harvest_error
	if state.has("hive_reaver_amber"):
		var reaver_error:=preload("res://scripts/lol2/hive_reaver_amber_state.gd").validate(state.hive_reaver_amber)
		if not reaver_error.is_empty(): return reaver_error
	if state.has("hive_flute_floor"):
		var flute_floor_error:=preload("res://scripts/lol2/hive_flute_floor.gd").validate(state.hive_flute_floor)
		if not flute_floor_error.is_empty(): return flute_floor_error
	if state.has("hive_net_exile"):
		var net_error:=preload("res://scripts/lol2/hive_net_exile.gd").validate(state.hive_net_exile)
		if not net_error.is_empty(): return net_error
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
	if state.has("dark_halls_population"):
		var Population = preload("res://scripts/lol2/scripted_creature_state.gd")
		var population_error := Population.validate(state.dark_halls_population, Population.source("res://scripts/lol2/dark_halls_population_source.json"))
		if not population_error.is_empty(): return population_error
	if state.has("dark_halls_rix"):
		var rix_error := preload("res://scripts/lol2/dark_halls_rix.gd").validate(state.dark_halls_rix)
		if not rix_error.is_empty(): return rix_error
	if state.has("dark_halls_loot"):
		var loot_error := preload("res://scripts/lol2/dark_halls_loot.gd").validate(state.dark_halls_loot, JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lol2/dark_halls_loot.gd").SOURCE)))
		if not loot_error.is_empty(): return loot_error
	if state.has("jungle_oil_fire"):
		var oil_error := preload("res://scripts/lol2/jungle_oil_fire.gd").validate(state.jungle_oil_fire)
		if not oil_error.is_empty(): return oil_error
	if state.has("jungle_causeway"):
		var causeway_error := preload("res://scripts/lol2/jungle_causeway.gd").validate(state.jungle_causeway)
		if not causeway_error.is_empty(): return causeway_error
	if state.has("jungle_river_dam"):
		var dam_error := preload("res://scripts/lol2/jungle_river_dam.gd").validate(state.jungle_river_dam)
		if not dam_error.is_empty(): return dam_error
	if state.has("dark_halls_windows"):
		var windows_error := preload("res://scripts/lol2/dark_halls_windows.gd").validate(state.dark_halls_windows, JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lol2/dark_halls_windows.gd").SOURCE)))
		if not windows_error.is_empty(): return windows_error
	if state.has("dark_halls_doors"):
		var doors_error := preload("res://scripts/lol2/dark_halls_doors.gd").validate(state.dark_halls_doors, JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/lol2/dark_halls_doors.gd").SOURCE)))
		if not doors_error.is_empty(): return doors_error
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
