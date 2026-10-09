extends "res://scripts/lol2/jungle_review.gd"
## Isolated Hive review saves and validated cross-area quest/inventory transport.
const Save = preload("res://scripts/lol2/hive_save.gd")
const Executioner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
var executioner_runtime: RefCounted
var executioner_live: Node3D
var rune_population: Node3D
var return_population: Node3D
var ambush_population: Node3D
var boulder_surfaces: Node3D
var boulders: Node3D
var boulder_audio: Node3D
var outcome_world_checkpoint: Dictionary = {}
var departure_checkpoint: Dictionary = {}
var carried_quest_checkpoint: Dictionary = {}
var monastery_checkpoint: Dictionary = {}
var jungle_village_checkpoint: Dictionary = {}
var executioner_command_checkpoint: Dictionary = {}
var actor_registry_checkpoint: Dictionary = {}
var weapon_modifier_checkpoint: Dictionary = {}
var player_reward_checkpoint: Dictionary = {}
var player_magic_checkpoint: Dictionary = {}
var carried_inventory := {"collected":[],"equipped_item":"","equipped_armor":""}
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var player_form := 0
const Curse = preload("res://scripts/lol2/player_curse.gd")
var curse := Curse.new()
var hive_curse: Node
var elevator: Node3D
var wax: Node3D
var runes: Node3D
var rune_light: Node3D
var dawn20: Node3D
var inventory: CanvasLayer
var interface_hud: CanvasLayer
## Empty until the encounter supplies a complete initialized marker checkpoint.
var executioner_marker_checkpoint: Dictionary = {}
## Empty until live scheduling supplies the complete clock phase and actor state.
var runtime_timing_checkpoint: Dictionary = {}
## Stored only at action boundaries, after the caller has applied its effects.
var runtime_schedule_checkpoint: Dictionary = {}
var equipped_item: String:
	get: return carried_inventory.equipped_item
var equipped_armor: String:
	get: return carried_inventory.equipped_armor
var item_effects: Node
var starting_magic: Node
func attach_starting_magic() -> void:
	starting_magic=preload("res://scripts/lol2/player_starting_magic.gd").new()
	starting_magic.name="StartingMagic"
	add_child(starting_magic)
	item_effects=preload("res://scripts/lol2/player_item_controller.gd").new()
	add_child(item_effects)

func _ready() -> void:
	dynamic_floor_regions = [772,773,774]
	super._ready()
	add_child(curse)
	attach_starting_magic.call_deferred()
	hive_curse = preload("res://scripts/lol2/hive_curse.gd").new()
	add_child(hive_curse)
	FormBody.apply(player,camera,player_form,false)
	attach_hive_route.call_deferred()
	interface_hud = preload("res://scripts/lol2/hive_interface.gd").new()
	interface_hud.walkthrough = self
	interface_hud.geometry_path = geometry_file
	interface_hud.location_name = "Hive Caves"
	interface_hud.save_path = Save.DEFAULT_PATH
	interface_hud.save_location_name = "Hive"
	add_child(interface_hud)
	wax = preload("res://scripts/lol2/hive_wax.gd").new()
	wax.name = "Wax"
	add_child(wax)
	elevator = preload("res://scripts/lol2/hive_elevator.gd").new()
	elevator.name = "Elevator"
	add_child(elevator)
	runes = preload("res://scripts/lol2/hive_rune_entry.gd").new()
	runes.name = "RuneEntry"
	add_child(runes)
	rune_light = preload("res://scripts/lol2/hive_rune_light.gd").new()
	rune_light.name = "RuneLight"
	add_child(rune_light)
	return_population = preload("res://scripts/lol2/hive_return_population.gd").new()
	return_population.name = "ReturnPopulation"
	add_child(return_population)
	ambush_population = preload("res://scripts/lol2/hive_ambush.gd").new()
	ambush_population.name = "AmbushPopulation"
	add_child(ambush_population)
	executioner_live = preload("res://scripts/lol2/hive_executioner_live.gd").new()
	executioner_live.name = "ExecutionerLive"
	add_child(executioner_live)
	rune_population=preload("res://scripts/lol2/hive_rune_population.gd").new()
	rune_population.name="RunePopulation"
	add_child(rune_population)
	boulder_surfaces=preload("res://scripts/lol2/hive_boulder_surfaces.gd").new()
	boulder_surfaces.name="BoulderSurfaces"
	add_child(boulder_surfaces)
	boulders=preload("res://scripts/lol2/hive_boulders.gd").new()
	boulders.name="Boulders"
	add_child(boulders)
	boulder_audio=preload("res://scripts/lol2/hive_boulder_audio.gd").new()
	boulder_audio.name="BoulderAudio"
	add_child(boulder_audio)
	# Source Dawn20/prop71 (hostile-monastery rune translation), linked by the RUNES room entry.
	if preload("res://scripts/lol2/hive_dawn20.gd").assets_ready():
		dawn20=preload("res://scripts/lol2/hive_dawn20.gd").new()
		dawn20.name="HiveDawn20"
		add_child(dawn20)
		var dawn_error: String=dawn20.setup(self)
		if not dawn_error.is_empty(): push_error(dawn_error)
	get_window().title = "Lands of Lore II — Hive Caves"
	if get_tree().has_meta("lol2_hive_resume"):
		var error := apply_save(get_tree().get_meta("lol2_hive_resume"))
		if error.is_empty():
			get_tree().remove_meta("lol2_hive_resume")
			set_development_mode(false)
		else: push_error(error)
func attach_hive_route() -> void:
	var route = preload("res://scripts/lol2/hive_route.gd").new()
	route.name = "HiveRoute"
	route.area = "hive"
	add_child(route)

func actor_input_locked() -> bool:
	return is_instance_valid(dawn20) and dawn20.input_locked()

func request_jump() -> bool:
	if is_instance_valid(dawn20) and dawn20.movement_locked(): return false
	return super.request_jump()

func _unhandled_input(event: InputEvent) -> void:
	if actor_input_locked(): return
	if (is_instance_valid(runes) and runes.active()) or get_tree().paused or (is_instance_valid(interface_hud) and interface_hud.cursor_active): return
	if event is InputEventKey and event.pressed and not event.echo:
		var actor = get_node("ConversationReview")
		if actor.started and not actor.completed and event.keycode in [KEY_F,KEY_R,KEY_E,KEY_SPACE,KEY_G]: return
		if event.keycode == KEY_R and get_node("Warriors").health == 0:
			get_node("Warriors").health=30 # Retry preserves defeated and reused source slots.
			set_physics_process(true)
			reset_position()
			get_viewport().set_input_as_handled()
			return
		if get_node("Warriors").health == 0 and event.keycode == KEY_F: return
		if event.keycode == KEY_E and (wax.collect() or elevator.interact() or runes.interact() or (is_instance_valid(dawn20) and dawn20.use())):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_G and rune_light.cast():
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_I:
			if open_inventory(): get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)
func area_handoff() -> Dictionary:
	var quests: Dictionary = carried_quest_checkpoint.duplicate(true)
	quests.merge(get_node("ConversationReview").quest_checkpoint(),true)
	if not monastery_checkpoint.is_empty():
		quests.monastery = monastery_checkpoint.duplicate(true)
	if not jungle_village_checkpoint.is_empty():
		quests.jungle_village = jungle_village_checkpoint.duplicate(true)
	quests.hive_rune_population=rune_population.checkpoint()
	quests.hive_rune_population_schema=1
	quests.hive_return_population = return_population.checkpoint()
	quests.hive_ambush = ambush_population.checkpoint()
	quests.hive_boulder_surfaces = boulder_surfaces.checkpoint()
	quests.hive_boulder_actors = boulders.checkpoint()
	quests.hive_boulder_actor_schema = 1
	quests.hive_boulder_contact = boulders.contact_checkpoint()
	quests.hive_boulder_contact_schema = 1
	quests.hive_boulder_audio = boulder_audio.checkpoint()
	quests.hive_boulder_audio_schema = 1
	quests.hive_encounter = get_node("Warriors").checkpoint()
	quests.hive_chasm = get_node("Chasm").checkpoint()
	quests.hive_nest = get_node("Nest").checkpoint()
	quests.hive_executioner_live = executioner_live.checkpoint()
	if is_instance_valid(dawn20) and dawn20.set_up(): quests.hive_dawn20 = dawn20.checkpoint()
	if not executioner_marker_checkpoint.is_empty():
		quests.hive_executioner_markers = executioner_marker_checkpoint.duplicate(true)
	if not runtime_timing_checkpoint.is_empty():
		quests.hive_runtime_timing = runtime_timing_checkpoint.duplicate(true)
	if not runtime_schedule_checkpoint.is_empty():
		quests.hive_runtime_schedule = runtime_schedule_checkpoint.duplicate(true)
	if not player_magic_checkpoint.is_empty():
		quests.player_magic_reward_state = player_magic_checkpoint.duplicate(true)
	if not player_reward_checkpoint.is_empty():
		quests.player_reward_state=player_reward_checkpoint.duplicate(true)
	if not weapon_modifier_checkpoint.is_empty():
		quests.player_weapon_modifiers=weapon_modifier_checkpoint.duplicate(true)
	if not actor_registry_checkpoint.is_empty():
		quests.hive_actor_registry=actor_registry_checkpoint.duplicate(true)
	if not executioner_command_checkpoint.is_empty():
		quests.hive_executioner_commands=executioner_command_checkpoint.duplicate(true)
	if not outcome_world_checkpoint.is_empty():
		quests.hive_outcome_world=outcome_world_checkpoint.duplicate(true)
	if executioner_runtime != null:
		quests.hive_executioner = executioner_runtime.checkpoint()
	if not departure_checkpoint.is_empty(): quests.act_one_departure = departure_checkpoint.duplicate(true)
	hive_curse.checkpoint.enabled = curse.requests_enabled()
	quests.hive_curse = hive_curse.checkpoint.duplicate(true)
	quests.hive_elevator = elevator.checkpoint.duplicate(true)
	quests.hive_wax_collected = wax.collected
	quests.hive_rune_entry = runes.checkpoint.duplicate(true)
	var inventory_state := carried_inventory.duplicate(true)
	inventory_state.player_form = player_form
	inventory_state.curse = curse.snapshot()
	# Living cross-area health supersedes an older visit's encounter snapshot.
	# A death checkpoint retains zero in hive_encounter; it is not a travel state.
	if get_node("Warriors").health > 0: inventory_state.health = get_node("Warriors").health
	else: inventory_state.erase("health")
	return {"inventory":inventory_state,"quests":quests}
func apply_area_handoff(state: Variant, entering: bool = true) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := Save.Shared.validate_inventory(state.get("inventory"))
	if not error.is_empty(): return error
	error = Save.Shared.Quests.validate(state.get("quests"))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/jungle_kelsrick_state.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_item_state.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_magic_state.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_fighting_transport.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	var restored_executioner: RefCounted
	if state.quests.has("hive_executioner"):
		restored_executioner = Executioner.new()
		error = restored_executioner.restore(state.quests.hive_executioner)
		if not error.is_empty(): return error
	var restored_markers: Dictionary = {}
	var restored_timing: Dictionary = {}
	var restored_schedule: Dictionary = {}
	if state.quests.has("hive_runtime_schedule"):
		var schedule := preload("res://scripts/lol2/hive_ai_schedule.gd").restore(state.quests.hive_runtime_schedule)
		if schedule.has("error"): return schedule.error
		restored_schedule = schedule.checkpoint
	if state.quests.has("hive_runtime_timing"):
		var timing := preload("res://scripts/lol2/hive_timing_state.gd").restore(state.quests.hive_runtime_timing)
		if timing.has("error"): return timing.error
		restored_timing = timing.checkpoint
	if state.quests.has("hive_executioner_markers"):
		var markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
		var loaded: Dictionary = markers.load_hive_bank()
		if loaded.has("error"): return loaded.error
		var restored: Dictionary = markers.restore(loaded.bank,state.quests.hive_executioner_markers)
		if restored.has("error"): return restored.error
		restored_markers = restored.checkpoint
	var restored_registry: Dictionary = {}
	if state.quests.has("hive_actor_registry"):
		restored_registry=preload("res://scripts/lol2/hive_actor_registry.gd").restore(state.quests.hive_actor_registry).checkpoint
	player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(state.inventory.magic).checkpoint if state.inventory.has("magic") else {}
	if state.quests.has("player_magic_reward_state"):
		player_magic_checkpoint = preload("res://scripts/lol2/hive_magic_reward.gd").restore(state.quests.player_magic_reward_state).checkpoint
	player_reward_checkpoint={}
	if state.quests.has("player_reward_state"):
		player_reward_checkpoint=preload("res://scripts/lol2/hive_reward_application.gd").restore(state.quests.player_reward_state).checkpoint
	if state.inventory.has("fighting") and state.inventory.fighting.has("player_reward_state"):
		player_reward_checkpoint=preload("res://scripts/lol2/hive_reward_application.gd").restore(state.inventory.fighting.player_reward_state).checkpoint
	weapon_modifier_checkpoint={}
	if state.quests.has("player_weapon_modifiers"):
		weapon_modifier_checkpoint=preload("res://scripts/lol2/hive_weapon_request.gd").restore_modifiers(state.quests.player_weapon_modifiers).checkpoint
	actor_registry_checkpoint=restored_registry
	var restored_commands: Dictionary = {}
	if state.quests.has("hive_executioner_commands"):
		restored_commands=preload("res://scripts/lol2/hive_executioner_command_queue.gd").restore(state.quests.hive_executioner_commands).checkpoint
	executioner_command_checkpoint=restored_commands
	var restored_world: Dictionary = {}
	if state.quests.has("hive_outcome_world"):
		restored_world=preload("res://scripts/lol2/hive_outcome_world.gd").restore_checkpoint(state.quests.hive_outcome_world).checkpoint
	outcome_world_checkpoint=restored_world
	executioner_runtime = restored_executioner
	executioner_marker_checkpoint = restored_markers
	runtime_timing_checkpoint = restored_timing
	runtime_schedule_checkpoint = restored_schedule
	carried_quest_checkpoint = state.quests.duplicate(true)
	departure_checkpoint = state.quests.get("act_one_departure",{}).duplicate(true)
	monastery_checkpoint = state.quests.get("monastery",{}).duplicate(true)
	jungle_village_checkpoint = state.quests.get("jungle_village",{}).duplicate(true)
	carried_inventory = state.inventory.duplicate(true)
	if carried_inventory.has("item_effects"): carried_inventory.item_effects=preload("res://scripts/lol2/player_item_state.gd").canonical(carried_inventory.item_effects)
	carried_inventory.erase("magic")
	wax.restore(state.quests.get("hive_wax_collected",false) or wax.ITEM in carried_inventory.collected)
	hive_curse.restore(state.quests.get("hive_curse",hive_curse.State.initial()))
	elevator.restore(state.quests.get("hive_elevator",elevator.State.initial()))
	jump_requested = false
	player_form = int(carried_inventory.get("player_form",0))
	curse.restore(carried_inventory.get("curse",Curse.initial()))
	hive_curse.restore_admission()
	FormBody.apply(player,camera,player_form,false)
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	error = get_node("ConversationReview").restore_quest_checkpoint(state.quests)
	var encounter: Dictionary = state.quests.get("hive_encounter",Save.Shared.Quests.initial_encounter()).duplicate(true)
	if state.inventory.has("health"): encounter.health = state.inventory.health
	get_node("Warriors").restore(encounter)
	get_node("Chasm").restore(state.quests.get("hive_chasm",Save.Shared.Quests.initial_chasm()))
	var nest_state = state.quests.get("hive_nest",Save.Shared.Quests.initial_nest())
	# Source chasm activation supersedes any pending nest film, including legacy saves.
	if get_node("Chasm").activated: nest_state = Save.Shared.Quests.initial_nest(true)
	get_node("Nest").restore(nest_state)
	executioner_live.restore(state.quests.get("hive_executioner_live",executioner_live.initial()))
	if executioner_runtime != null and get_node("Nest").phase == 3:
		var presentation_error: String = get_node("Nest").present_executioner(executioner_runtime.checkpoint())
		if not presentation_error.is_empty(): return presentation_error
	var actor = get_node("ConversationReview")
	set_physics_process(get_node("Warriors").health > 0 and not (actor.started and not actor.completed))
	runes.restore(state.quests.get("hive_rune_entry",runes.State.initial()))
	if is_instance_valid(dawn20) and dawn20.set_up():
		var dawn_error: String=dawn20.restore(state.quests.get("hive_dawn20",dawn20.initial()))
		if not dawn_error.is_empty(): return dawn_error
	return_population.restore(state.quests.get("hive_return_population",return_population.State.initial()))
	ambush_population.restore(state.quests.get("hive_ambush",ambush_population.Ambush.initial()))
	rune_population.restore(state.quests.get("hive_rune_population",rune_population.RuneState.initial()))
	var boulder_error: String=boulder_surfaces.restore(state.quests.get("hive_boulder_surfaces",boulder_surfaces.State.initial()))
	if not boulder_error.is_empty(): return boulder_error
	var actor_error: String=boulders.restore(state.quests.get("hive_boulder_actors",boulders.State.initial(boulder_surfaces.state.phase>=2)))
	if not actor_error.is_empty(): return actor_error
	var contact_error: String=boulders.restore_contact(state.quests.get("hive_boulder_contact",boulders.Contact.initial()))
	if not contact_error.is_empty(): return contact_error
	var audio_error: String=boulder_audio.restore(state.quests.get("hive_boulder_audio",boulder_audio.State.legacy(boulder_surfaces.state,boulders.state)))
	if not audio_error.is_empty(): return audio_error
	if entering:
		return_population.arrive(state.quests)
		rune_population.arrive(state.quests)
	return error
func quicksave(path: String = Save.DEFAULT_PATH) -> String:
	if get_tree().paused: return "Close the current overlay before saving."
	if flying: return "Return to walking mode before saving."
	var state := area_handoff()
	state.merge({"format":Save.FORMAT,"version":1,"player":{
		"position":[player.position.x,player.position.y,player.position.z],
		"yaw":wrapf(player.rotation.y,-PI,PI),"pitch":camera.rotation.x}})
	return Save.write_save(path,state)
func quickload(path: String = Save.DEFAULT_PATH) -> String:
	if get_tree().paused: return "Close the current overlay before loading."
	var result := Save.read_save(path)
	return result.error if not result.error.is_empty() else apply_save(result.state)
func apply_save(state: Variant) -> String:
	var error := Save.validate(state)
	if not error.is_empty(): return error
	# Old review saves without quests start with the neutral state.
	var handoff := {"inventory":state.inventory,"quests":state.get("quests",Save.Shared.Quests.initial())}
	player.position = Vector3(state.player.position[0],state.player.position[1],state.player.position[2])
	player.rotation.y = state.player.yaw
	camera.rotation = Vector3(state.player.pitch,0,0)
	player.velocity = Vector3.ZERO
	flying = false
	error = apply_area_handoff(handoff,false)
	if error.is_empty() and is_instance_valid(interface_hud):
		interface_hud.set_cursor(false)
		if runes.active(): runes.refresh()
	return error

func open_inventory() -> bool:
	var actor = get_node("ConversationReview")
	if runes.active() or get_tree().paused or is_instance_valid(inventory) or (actor.started and not actor.completed): return false
	inventory = preload("res://scripts/lol2/museum_inventory.gd").new()
	inventory.use_item = use_inventory_item
	inventory.item_ids = carried_inventory.collected.duplicate()
	inventory.equipped_item = equipped_item
	inventory.equipped_armor = equipped_armor
	inventory.change_equipment = set_equipped_item
	inventory.change_armor = set_equipped_armor
	inventory.return_to_game = interface_hud.set_cursor.bind(false)
	add_child(inventory)
	return true

func set_equipped_item(item_id: String) -> bool:
	if item_id != "" and (not preload("res://scripts/lol2/player_equipment.gd").weapon(item_id) or item_id not in carried_inventory.collected): return false
	carried_inventory.equipped_item = item_id
	interface_hud.refresh_equipment()
	return true

func set_equipped_armor(item_id: String) -> bool:
	if item_id != "" and (not preload("res://scripts/lol2/player_equipment.gd").armor(item_id) or item_id not in carried_inventory.collected): return false
	carried_inventory.equipped_armor = item_id
	interface_hud.refresh_equipment()
	return true

static func assets_ready() -> bool:
	if not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready(): return false
	var root := "res://assets/lol2/generated/"
	for file in ["hive_review/hive.json","hive_props/props.json","hive_pillar/pillar.json","hive_pillar/pillar.png","hive_warriors/warrior.png","hive_routes/routes.json","hive_conversation/conversation.json","hive_chasm/chasm.json","hive_chasm/rubble.png","hive_nest/nest.json","hive_nest/nesting_atlas.png","hive_nest/nest_to_attack_atlas.png","hive_nest/executioner.png"]:
		if not FileAccess.file_exists(root+file): return false
	var geometry = JSON.parse_string(FileAccess.get_file_as_string(root+"hive_review/hive.json"))
	if not geometry is Dictionary or not geometry.get("faces") is Array or geometry.faces.is_empty() or not geometry.get("materials") is Dictionary: return false
	for texture in geometry.materials.values():
		if not texture is String or not FileAccess.file_exists(root+"hive_review/"+texture): return false
	for animation in geometry.get("animations",{}).values():
		for file in animation.frames:
			if not FileAccess.file_exists(root+"hive_review/"+file): return false
	var props = JSON.parse_string(FileAccess.get_file_as_string(root+"hive_props/props.json"))
	if not props is Dictionary or not props.get("images") is Dictionary: return false
	for image in props.images.values():
		if not image is Dictionary or not image.get("file") is String or not FileAccess.file_exists(root+"hive_props/"+image.file): return false
	for i in range(10):
		if not FileAccess.file_exists(root+"hive_conversation/page_%d.png" % i): return false
	for i in range(6):
		if not FileAccess.file_exists(root+"hive_conversation/section_%d.wav" % i): return false
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string(root+"hive_conversation/conversation.json"))
	if not dialogue is Dictionary or not dialogue.get("sections") is Array: return false
	for section in dialogue.sections:
		if not section is Dictionary or not section.get("audio") is String or not FileAccess.file_exists(root+"hive_conversation/"+section.audio): return false
	return true

func executioner_decide(context: Variant, helpers: Dictionary) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.decide_current(context,helpers)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	return result

func executioner_advance_reference_time(microseconds: Variant, running: bool = true, feedback: Callable = Callable()) -> Dictionary:
	return _executioner_reference_tick(microseconds,running,feedback,false)

func executioner_advance_reference_time_with_player_damage(microseconds: Variant, running: bool = true) -> Dictionary:
	return _executioner_reference_tick(microseconds,running,Callable(),true)

func _executioner_reference_tick(microseconds: Variant, running: bool, feedback: Callable, player_damage: bool) -> Dictionary:
	# Explicit scheduler entry: never invent a clock or reset a restored actor's A3.
	var timing_type = preload("res://scripts/lol2/hive_timing_state.gd")
	var checked: Dictionary = timing_type.restore(runtime_timing_checkpoint)
	if checked.has("error"): return checked
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	if executioner_runtime.checkpoint().is_empty(): return {"error":"Executioner state unavailable."}
	var tick: Dictionary = preload("res://scripts/lol2/hive_clock_runtime.gd").advance_reference_time(checked.checkpoint.clock,microseconds,checked.checkpoint.phase,running and not get_tree().paused)
	if tick.has("error"): return tick
	if tick.advanced:
		var result := executioner_advance_with_player_damage(tick.delta) if player_damage else executioner_advance(tick.delta,feedback)
		if result.has("error"): return result
		tick["executioner"] = result
	# Commit provider phase only after actor update and presentation both succeed.
	runtime_timing_checkpoint = timing_type.checkpoint(tick.state,tick.phase,checked.checkpoint.executioner_a3).checkpoint
	return tick

func executioner_advance(delta: Variant, feedback: Callable = Callable()) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.advance(delta,feedback)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	return result

func executioner_finish_outcome_preparation(context: Variant, helpers: Dictionary) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.finish_outcome_preparation(context,helpers)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	return result

func executioner_advance_with_player_damage(delta: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.advance_with_player_damage(delta)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	return result

func executioner_begin_outcome(world: Variant, context: Variant, helpers: Dictionary) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	if not world is Dictionary: return {"error":"Invalid outcome world context."}
	var world_type = preload("res://scripts/lol2/hive_outcome_world.gd")
	var checked: Dictionary = world_type.restore_checkpoint({"version":1,"sector_flags":world.get("sector_flags"),"group":world.get("group")})
	if checked.has("error"): return checked
	if not outcome_world_checkpoint.is_empty() and checked.checkpoint!=outcome_world_checkpoint:
		return {"error":"Outcome world context disagrees with saved state."}
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.begin_outcome(world,context,helpers)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	outcome_world_checkpoint=world_type.restore_checkpoint({"version":1,"sector_flags":result.world.sector_flags,"group":result.world.group}).checkpoint
	return result

func executioner_set_health(health_context: Variant, world: Variant, outcome_context: Variant, helpers: Dictionary) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var saved: Dictionary = executioner_runtime.checkpoint()
	if saved.is_empty(): return {"error":"Executioner state unavailable."}
	var admitted := preload("res://scripts/lol2/hive_actor_health.gd").run(saved.actor,health_context)
	if admitted.has("error"): return admitted
	if admitted.outcome:
		if not outcome_context is Dictionary: return {"error":"Missing outcome context."}
		var context: Dictionary = outcome_context.duplicate(true);context.flags=0
		return executioner_begin_outcome(world,context,helpers)
	var result: Dictionary = executioner_runtime.set_actor_health(health_context,world,outcome_context,helpers)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(saved)
	if not error.is_empty(): return {"error":error}
	return result

func executioner_consume_commands(blocked: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var saved: Dictionary = executioner_runtime.checkpoint()
	if saved.is_empty(): return {"error":"Executioner state unavailable."}
	if not executioner_marker_checkpoint.is_empty() and executioner_marker_checkpoint.counter!=saved.actor.get("word7c"):
		return {"error":"Executioner marker and command counters disagree."}
	var result: Dictionary = executioner_runtime.consume_commands(executioner_command_checkpoint,blocked)
	if result.has("error"): return result
	executioner_command_checkpoint=result.queue
	if not executioner_marker_checkpoint.is_empty(): executioner_marker_checkpoint.counter=result.counter
	return result

func executioner_enqueue_hit_commands() -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var result: Dictionary = executioner_runtime.enqueue_hit_commands(executioner_command_checkpoint,actor_registry_checkpoint)
	if result.has("error"): return result
	executioner_command_checkpoint=result.queue
	actor_registry_checkpoint=result.registry
	return result

func executioner_enqueue_hit_record(loss: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var result: Dictionary = executioner_runtime.enqueue_hit_record(loss,executioner_command_checkpoint,actor_registry_checkpoint)
	if result.has("error"): return result
	if result.event_matched:
		executioner_command_checkpoint=result.queue
		actor_registry_checkpoint=result.registry
	return result

func executioner_apply_prepared_hit(hit: Variant, world: Variant, outcome_context: Variant, helpers: Dictionary) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var world_type = preload("res://scripts/lol2/hive_outcome_world.gd")
	if world!=null:
		if not world is Dictionary: return {"error":"Invalid prepared hit world."}
		var checked: Dictionary = world_type.restore_checkpoint({"version":1,"sector_flags":world.get("sector_flags"),"group":world.get("group")})
		if checked.has("error"): return checked
		if not outcome_world_checkpoint.is_empty() and checked.checkpoint!=outcome_world_checkpoint: return {"error":"Prepared hit world disagrees with saved state."}
	# Keep the live owner's callback guard; retain a checkpoint for presentation failure.
	var before: Dictionary = executioner_runtime.checkpoint()
	var result: Dictionary = executioner_runtime.apply_prepared_hit(hit,executioner_command_checkpoint,actor_registry_checkpoint,world,outcome_context,helpers)
	if result.has("error"): return result
	var error: String = _present_executioner_or_restore(before)
	if not error.is_empty(): return {"error":error}
	executioner_command_checkpoint=result.queue;actor_registry_checkpoint=result.registry
	if result.health.has("world"):
		outcome_world_checkpoint=world_type.restore_checkpoint({"version":1,"sector_flags":result.health.world.sector_flags,"group":result.health.world.group}).checkpoint
	return result

func prepare_fine_longsword_request(context: Variant) -> Dictionary:
	# Explicit upstream admission: called only after reach/item callback succeeds.
	# Original counters are consumed before target hit admission, even if it rejects.
	var result := preload("res://scripts/lol2/hive_weapon_request.gd").consume_fine_longsword(context,weapon_modifier_checkpoint)
	if result.has("error"): return result
	weapon_modifier_checkpoint=result.checkpoint
	return result

func _present_executioner_or_restore(before: Dictionary) -> String:
	var error: String = get_node("Nest").present_executioner(executioner_runtime.checkpoint())
	if error.is_empty(): return ""
	var rollback_error: String = executioner_runtime.restore(before)
	return error if rollback_error.is_empty() else error+" Rollback failed: "+rollback_error

func executioner_update_player_perception(context: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	return executioner_runtime.update_player_perception(context)

func executioner_update_target_reach(target_flags: Variant, points: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	return executioner_runtime.update_target_reach(target_flags,points,reach,obstruction,draw)

func executioner_apply_valid_target_reach(distance: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	return executioner_runtime.apply_valid_target_reach(distance,reach,obstruction,draw)

func executioner_refresh_material_region(context: Variant) -> Dictionary:
	if executioner_runtime == null or get_node("Nest").phase != 3: return {"error":"Executioner is not active in this scene."}
	var result: Dictionary = executioner_runtime.refresh_material_region(actor_registry_checkpoint,context)
	if result.has("error"): return result
	actor_registry_checkpoint=result.registry
	return result

func use_inventory_item(id: String) -> bool:
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) != "": return item_effects.use(id)
	if id != preload("res://scripts/lol2/monastery_conversation.gd").FLUTE: return false
	if not elevator.play_flute(): return false
	interface_hud.hint.text = "You play the flute."
	interface_hud.save_notice_remaining = 3.0
	return true

# The exported height differences made a fixed column around the movable floor.
# Keep the outer cavern/landing walls; the lift itself is an exposed platform.
const LIFT_PERIMETER = [Vector2(-2600,-7698),Vector2(-2529,-7698),
	Vector2(-2484,-7653),Vector2(-2484,-7575),Vector2(-2529,-7531),
	Vector2(-2600,-7531),Vector2(-2646,-7579),Vector2(-2646,-7653)]
var omitted_lift_walls := 0
func include_static_face(face: Dictionary) -> bool:
	if preload("res://scripts/lol2/hive_boulder_surfaces.gd").replaces(face): return false
	if not super.include_static_face(face): return false
	if face.kind != "wall" or int(face.region) < 771 or int(face.region) > 781: return true
	for edge in range(LIFT_PERIMETER.size()):
		var a: Vector2 = LIFT_PERIMETER[edge]
		var b: Vector2 = LIFT_PERIMETER[(edge+1)%LIFT_PERIMETER.size()]
		var on_edge := true
		for point in face.points:
			var xz := Vector2(point[0],point[2])
			if xz != a and xz != b:
				on_edge = false
				break
		if on_edge:
			omitted_lift_walls += 1
			return false
	return true

func move_grounded(direction: Vector3, delta: float, sprint: bool = false) -> void:
	if is_instance_valid(dawn20) and dawn20.movement_locked(): direction=Vector3.ZERO;jump_requested=false
	# Explicit attempt marker survives a blocked slide; no contact-entry latch.
	if is_instance_valid(boulders) and delta>0 and not flying and get_node("Warriors").health>0:
		if direction.length_squared()>0.000001 or jump_requested or not player.is_on_floor(): boulders.player_attempted=true
	super.move_grounded(direction,delta,sprint)

func reset_position() -> void:
	super.reset_position()
	if is_instance_valid(boulders): boulders.restore_contact(boulders.Contact.initial())
