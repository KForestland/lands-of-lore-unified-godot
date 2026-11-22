extends RefCounted
const Body = preload("res://scripts/lol2/player_form_body.gd")
## Shared slot/autosave admission. Existing explicit legacy writers retain their old guards.
const TRANSFERS := ["lol2_act2_handoff","lol2_darker_handoff","lol2_jungle_handoff","lol2_cave_completion","lol2_hive_route_handoff","lol2_dark_halls_route_handoff","lol2_dark_halls_handoff","lol2_slot_resume","lol2_level_change","lol2_map_start_selector"]
static func _play_hold_reason(host: Node) -> String:
	if not host.is_inside_tree(): return "The area is still loading."
	var tree := host.get_tree()
	var ready: Variant = host.get("walkthrough_ready")
	if ready == null: ready = host.get("ready_for_review")
	if ready == false: return "The area is still loading."
	if tree.paused: return "Close the current overlay before saving."
	if host.get("flying") == true: return "Return to walking mode before saving."
	var magic: Variant = host.get("starting_magic")
	if not is_instance_valid(magic): return "The area is still loading."
	if magic.health() <= 0: return "Recover or load a save before saving."
	var drowning: Variant = host.get("drowning")
	if drowning != null and drowning.get("dead") == true: return "Recover before saving."
	for key in TRANSFERS:
		if tree.has_meta(key): return "Wait until the area change finishes."
	var progression: Variant = host.get("progression")
	if is_instance_valid(progression) and progression.get("transition_pending") == true: return "Wait until the area change finishes."
	if host.get("mirror_transition_pending") == true: return "Wait until the area change finishes."
	for child in host.get_children():
		if child.get("transitioning") == true or (child.has_method("input_locked") and child.input_locked()): return "Finish the current scene before saving."
	for member in ["video_overlay","introduction","failure_overlay"]:
		if is_instance_valid(host.get(member)): return "Finish the current scene before saving."
	if host.get("chamber_arrival_state") != null and host.chamber_arrival_state != "not_started": return "Finish the current scene before saving."
	if host.get("introduction_state") != null and host.introduction_state != "complete": return "Finish the current scene before saving."
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return "Finish the conversation before saving."
	for member in ["chief_hut","kityara","guard_encounter","guard_controls","captain"]:
		var owner: Variant = host.get(member)
		if not is_instance_valid(owner): continue
		for method in ["input_locked","movement_locked","intro_active"]:
			if owner.has_method(method) and owner.call(method): return "Finish the current scene before saving."
	for member in ["village_dialogue","followup_dialogue","exit_encounter","departure"]:
		var owner:Variant=host.get(member)
		if is_instance_valid(owner) and owner.has_method("active") and owner.active():return "Finish the conversation before saving."
	# Idle room pages remain saveable; their separate speech clocks must finish first.
	for member in ["magic_shop","weapon_shop","thieves_den"]:
		var owner:Variant=host.get(member)
		if is_instance_valid(owner) and owner.active() and owner.State.active(owner.state()):return "Finish the conversation before saving."
	var monastery:Variant=host.get("monastery")
	if is_instance_valid(monastery) and monastery.active():
		var speech:Script=preload("res://scripts/lol2/monastery_conversation.gd")
		if speech.active(monastery.state().get("conversation",speech.initial())):return "Finish the conversation before saving."
	var runes:Variant=host.get("runes")
	if is_instance_valid(runes) and runes.has_method("busy") and runes.busy():return "Finish the current scene before saving."
	return ""

## Use the same loading, scene and conversation holds for the play clock, without
## stopping time spent jumping or in water while a checkpoint waits for safety.
static func play_active(host: Node) -> bool:
	var magic: Variant = host.get("starting_magic")
	return _play_hold_reason(host).is_empty() and is_instance_valid(magic) and magic.world_active()

static func reason(host: Node) -> String:
	var hold := _play_hold_reason(host)
	if not hold.is_empty(): return hold
	# A controller can still own drowning for a frame after the body reaches a bank.
	# Check both ownership forms as well as the independent water geometry below.
	var liquid_owner: Variant = host.get("liquid_drowning")
	for state in [host.get("drowning"), liquid_owner.get("drowning") if is_instance_valid(liquid_owner) else null]:
		if state != null and (state.get("active") == true or state.get("dead") == true): return "Reach safety before saving."
	var player: Variant = host.get("player")
	if not is_instance_valid(player) or not player.is_on_floor(): return "Stand on solid ground before saving."
	var liquid: Variant = host.get("liquid_drowning")
	if is_instance_valid(liquid):
		var region: Dictionary = liquid.polygon_at(player.global_position)
		if not region.is_empty() and player.global_position.y - Body.FOOT_OFFSET < float(region.surface): return "Leave the liquid before saving."
	var river: Variant = host.get("river_water")
	if river != null:
		var point: Vector3 = player.global_position - host.native_translation
		if river.region_at(point) >= 0 and point.y - Body.FOOT_OFFSET < river.PLANE: return "Leave the water before saving."
	return ""
