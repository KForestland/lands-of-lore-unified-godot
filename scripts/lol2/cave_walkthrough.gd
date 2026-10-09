extends "res://scripts/lol2/special_placed_prop_review.gd"

const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const WalkthroughSave = preload("res://scripts/lol2/walkthrough_save.gd")
const Collectible = preload("res://scripts/lol2/cave_collectible.gd")
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var player_form := 0
var player_magic_checkpoint := preload("res://scripts/lol2/player_magic_state.gd").initial()
const Curse = preload("res://scripts/lol2/player_curse.gd")
var curse := Curse.new()
var collectible := Collectible.new()
var aloe: Node3D
var stalagmites: Node3D
var equipped_item := ""
var equipped_armor := ""
var source_combat_enabled := true
var full_route_enabled := true
const RoachPopulation=preload("res://scripts/lol2/cave_roach_population_state.gd")
var roach_population: Dictionary=RoachPopulation.initial()
var roach_population_regions: Array=JSON.parse_string(FileAccess.get_file_as_string(RoachPopulation.SOURCE)).regions
var roach: Node3D
var roach_population_live: Node3D
## Cave guards on the generic scripted creature owner (docs/cave-guard-population.md).
const GUARD_CONFIG:={"root":"res://assets/lol2/generated/cave_guard_sprites/","source":"res://scripts/lol2/cave_guard_population_source.json","target_prefix":"caveguard","fighting_owner":"quest_state","render":"cave_indexed","nav":"res://assets/lol2/generated/creature_nav/L1_DC.json",
	"audio_contract":"res://scripts/lol2/cave_guard_audio_source.json","audio_manifest":"res://assets/lol2/generated/cave_guard_audio/audio.json",
	"names":{"0":"Guard captain","1":"Guard","2":"Guard"},
	"look":{"0":{"canvas":[400,248],"scale":0.25,"floor_row":236,"radius":15,"height":46},"1":{"canvas":[400,248],"scale":0.25,"floor_row":236,"radius":15,"height":46},"2":{"canvas":[400,248],"scale":0.25,"floor_row":236,"radius":15,"height":46}}}
var guard_population: Node3D
var wild_roach_population: Node3D
var lurking_roach_population: Node3D
var scenic_guard: Node3D
var eyes: Node3D
var captain: Node3D
var guard_controls: Node3D
## Fighting progression subset; becomes Jungle quests on arrival (player_fighting_transport.gd).
var quest_state: Dictionary={}
var inventory: CanvasLayer
var interaction_requested := false
var interaction_available := false
var interaction_prompt: Label
var glow_records: Array[int] = []
var save_notice := ""
var save_notice_until := 0
var development_mode := "--developer-tools" in OS.get_cmdline_user_args() or (not OS.has_feature("original_game_required") and "--demo-interface" not in OS.get_cmdline_user_args())
var walkthrough_ready := false
var hud: Label
var dynamic_order: Array = []
var audit_frame := 0
var audit_pose := 0
var audit_start: Transform3D
var walk_check_frame := 0
var walk_check_start := Vector3.ZERO
var light_view: SubViewport
var light_camera: Camera3D
var light_pairs: Array = []
var lighting_enabled := true
var lighting_frame := 0
var light_materials: Array[ShaderMaterial] = []
var glows_enabled := true
var glow_frame := 0
var glow_record := 1108
var dummy_root: Node3D
var dummy_frame := 0
var lava = preload("res://scripts/lol2/cave_lava.gd").new()
var river_water = preload("res://scripts/lol2/river_region_query.gd").new()
var drowning = preload("res://scripts/lol2/river_drowning_state.gd").new()
var drowning_notice: Label
var drowning_menu: Control
var drowning_menu_status: Label
var drowning_reload: Button
var drowning_sink_elapsed := 0.0
var drowning_camera_origin := Vector3.ZERO
# Authored first-person death presentation; original timing/depth not measured.
const DROWNING_SINK_SECONDS := 2.0
const DROWNING_SINK_DEPTH := 18.0
var bridge_warning: Node
var river_chains: Node3D
var river_deck: Node3D
var indexed_chain: Node
var video_overlay: CanvasLayer
var chamber_arrival_state := "not_started"
var indexed_doors: Array[Node3D] = []
var indexed_door_surfaces: Array[Node3D] = []

var item_effect_checkpoint := preload("res://scripts/lol2/player_item_state.gd").initial()
var item_effects: Node
var starting_magic: Node
func attach_starting_magic() -> void:
	starting_magic=preload("res://scripts/lol2/player_starting_magic.gd").new()
	starting_magic.name="StartingMagic"
	add_child(starting_magic)
	item_effects = preload("res://scripts/lol2/player_item_controller.gd").new()
	item_effects.name = "ItemEffects"
	add_child(item_effects)

func _ready() -> void:
	if OS.has_feature("original_game_required") and not get_tree().get_meta("original_game_verified", false):
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred("res://scenes/lol2/original_game_gate.tscn")
		return
	await super._ready()
	add_child(curse)
	attach_starting_magic.call_deferred()
	curse.cave_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/cave_curse/regions.json")).regions
	FormBody.apply(player, camera, player_form, false)
	for view in raw_views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.cull_mask = 0 # Only indexed viewports draw the world.
	get_window().title = "Lands of Lore II — Cavern walkthrough proof of concept"
	var ui := CanvasLayer.new()
	ui.layer = 21
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(14, 12)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hud)
	interaction_prompt = Label.new()
	interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	interaction_prompt.offset_left = -125
	interaction_prompt.offset_right = 125
	interaction_prompt.offset_top = 30
	interaction_prompt.offset_bottom = 60
	interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 2)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(interaction_prompt)
	drowning_notice = Label.new()
	drowning_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	drowning_notice.position = Vector2(-220,-90)
	drowning_notice.size = Vector2(440,70)
	drowning_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drowning_notice.add_theme_font_size_override("font_size",22)
	drowning_notice.add_theme_color_override("font_color",Color(1.0,0.75,0.5))
	drowning_notice.add_theme_color_override("font_shadow_color",Color.BLACK)
	drowning_notice.add_theme_constant_override("shadow_offset_x",2)
	drowning_notice.add_theme_constant_override("shadow_offset_y",2)
	drowning_notice.hide()
	ui.add_child(drowning_notice)
	_build_drowning_menu(ui)
	for prop in props_root.get_children():
		if prop.get_meta("original_record", -1) == Collectible.RECORD:
			collectible.mesh = prop
	assert(collectible.mesh != null, "Collectible record missing from recovered cave")
	aloe = preload("res://scripts/lol2/cave_aloe.gd").new()
	add_child(aloe)
	aloe.setup(self)
	stalagmites = preload("res://scripts/lol2/cave_stalagmite.gd").new()
	add_child(stalagmites)
	stalagmites.setup(self)
	if source_combat_enabled:
		roach = preload("res://scripts/lol2/cave_roach.gd").new()
		add_child(roach)
		roach.setup(self)
		roach_population_live=preload("res://scripts/lol2/cave_roach_population.gd").new()
		add_child(roach_population_live)
		roach_population_live.setup(self)
		if FileAccess.file_exists(str(GUARD_CONFIG.root)+"sprites.json"):
			guard_population=preload("res://scripts/lol2/cave_scenic_guard_population.gd").new()
			guard_population.name="GuardPopulation"
			guard_population.configure(GUARD_CONFIG)
			add_child(guard_population)
			var guard_error: String=guard_population.setup(self)
			if not guard_error.is_empty(): push_error(guard_error)
		wild_roach_population=preload("res://scripts/lol2/cave_wild_roach.gd").new()
		wild_roach_population.name="WildRoachPopulation"
		add_child(wild_roach_population)
		var wild_error: String=wild_roach_population.setup(self)
		if not wild_error.is_empty(): push_error(wild_error)
	scenic_guard=preload("res://scripts/lol2/cave_scenic_guard.gd").new()
	scenic_guard.name="ScenicGuard55"
	add_child(scenic_guard)
	var scenic_error: String=scenic_guard.setup(self,scenic_guard.scene_effect,scenic_guard.scene_active)
	if not scenic_error.is_empty():push_error(scenic_error)
	if preload("res://scripts/lol2/cave_lurking_roach.gd").assets_ready():
		lurking_roach_population=preload("res://scripts/lol2/cave_lurking_roach.gd").new()
		lurking_roach_population.name="LurkingRoachPopulation"
		add_child(lurking_roach_population)
		var lurking_error: String=lurking_roach_population.setup(self)
		if not lurking_error.is_empty(): push_error(lurking_error)
	eyes=preload("res://scripts/lol2/cave_eyes.gd").new()
	eyes.name="CaveEyes24"
	add_child(eyes)
	var eyes_error: String=eyes.setup(self)
	if not eyes_error.is_empty():push_error(eyes_error)
	# Captain56 and the guard controls drive the guard population; review scenes without source
	# combat have none, so both stay null there (every other use already checks for null).
	if guard_population!=null:
		captain=preload("res://scripts/lol2/cave_captain.gd").new();captain.name="CaveCaptain56";add_child(captain)
		var captain_error: String=captain.setup(self)
		if not captain_error.is_empty():push_error(captain_error)
		guard_controls=preload("res://scripts/lol2/cave_guard_controls.gd").new()
		guard_controls.name="CaveGuardControls"
		add_child(guard_controls)
		var guard_controls_error: String=guard_controls.setup(self)
		if not guard_controls_error.is_empty():push_error(guard_controls_error)
	if full_route_enabled:
		_build_indexed_doors()
		player.collision_layer = 2
		indexed_chain = load("res://scripts/lol2/indexed_chain_event.gd").new()
		add_child(indexed_chain)
		indexed_chain.setup(self)
	_build_lighting()
	lighting_enabled = not ("--walkthrough-capture" in OS.get_cmdline_user_args() or "--reference-lighting" in OS.get_cmdline_user_args())
	_set_lighting(lighting_enabled)
	if "--walkthrough-capture" in OS.get_cmdline_user_args():
		audit_start = camera.global_transform
		hud.visible = false
	else:
		var initial_checkpoint: int = fixtures[0].checkpoints.size()+1 if full_route_enabled else 13
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--checkpoint="): initial_checkpoint = int(argument.trim_prefix("--checkpoint=")) - 1
		_jump_checkpoint(initial_checkpoint)
		set_physics_process(true)
		set_process_unhandled_input(true)
	if full_route_enabled:
		await get_tree().physics_frame
		river_deck = preload("res://scripts/lol2/recovered_river_deck.gd").new()
		add_child(river_deck)
		river_deck.setup(self)
		river_chains = preload("res://scripts/lol2/river_chain_interaction.gd").new()
		add_child(river_chains)
		river_chains.setup(self)
		bridge_warning = preload("res://scripts/lol2/bridge_warning.gd").new()
		add_child(bridge_warning)
		bridge_warning.setup(self)
		if "--chain-approach" in OS.get_cmdline_user_args():
			var chain_initial: int = fixtures[0].checkpoints.size()
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--checkpoint="): chain_initial = int(argument.trim_prefix("--checkpoint=")) - 1
			_jump_checkpoint(chain_initial)
	_resize_index_view()
	if not "--glow-capture" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--glow-record="):
				_position_glow_review()
				player.global_position.y += 16.0
	if "--glow-capture" in OS.get_cmdline_user_args():
		_position_glow_review()
		set_physics_process(false)
		set_process_unhandled_input(false)
		hud.visible = false
	if "--dummy-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_process_unhandled_input(false)
		hud.visible = false
	if "--lighting-capture" in OS.get_cmdline_user_args():
		set_physics_process(false)
		set_process_unhandled_input(false)
		hud.visible = false
	if "--controls-check" in OS.get_cmdline_user_args():
		call_deferred("_run_controls_check")
	if "--interaction-review" in OS.get_cmdline_user_args():
		_position_glow_review()
		player.global_position.y += 16
		camera.look_at(collectible.target_position())

	flight_label.visible = development_mode
	walkthrough_ready = true

func _resize_index_view() -> void:
	super._resize_index_view()
	if light_view != null: light_view.size = index_view.size
	for view in layer_views: view.size = index_view.size
	for view in composites:
		view.size = index_view.size
		view.get_child(0).size = Vector2(index_view.size)

func _build_drowning_menu(ui: CanvasLayer) -> void:
	drowning_menu = Control.new()
	drowning_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(drowning_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.06, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drowning_menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drowning_menu.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 340
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := Label.new()
	title.text = "You drowned"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	drowning_reload = Button.new()
	drowning_reload.text = "Return to checkpoint"
	drowning_reload.pressed.connect(_reload_drowning_checkpoint)
	box.add_child(drowning_reload)
	var load_button := Button.new()
	load_button.text = "Load quicksave"
	load_button.pressed.connect(func():
		var error := _quickload()
		if not error.is_empty():
			drowning_menu_status.text = "Could not load quicksave. Return to checkpoint or try again."
		else:
			_clear_drowning()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(load_button)
	drowning_menu_status = Label.new()
	drowning_menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(drowning_menu_status)
	drowning_menu.hide()

func _clear_drowning() -> void:
	if bridge_warning != null: bridge_warning.dismiss()
	if drowning.dead: camera.position = drowning_camera_origin
	drowning.reset()
	drowning_sink_elapsed = 0.0
	if drowning_notice != null: drowning_notice.hide()
	if drowning_menu != null:
		drowning_menu.hide()
		drowning_menu_status.text = ""

func _reload_drowning_checkpoint() -> void:
	_reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _advance_drowning_death(delta: float) -> void:
	if drowning_menu.visible: return
	drowning_sink_elapsed = minf(DROWNING_SINK_SECONDS, drowning_sink_elapsed + delta)
	camera.position = drowning_camera_origin + Vector3.DOWN * DROWNING_SINK_DEPTH * (drowning_sink_elapsed / DROWNING_SINK_SECONDS)
	if drowning_sink_elapsed >= DROWNING_SINK_SECONDS:
		drowning_notice.hide()
		drowning_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		drowning_reload.grab_focus()

func _reset() -> void:
	jump_requested = false
	_clear_drowning()
	if roach != null: roach.recover()
	if roach_population_live!=null: roach_population_live.recover()
	if guard_population!=null: guard_population.recover()
	if wild_roach_population!=null: wild_roach_population.recover()
	if lurking_roach_population!=null: lurking_roach_population.recover()
	if indexed_chain != null and checkpoint == fixtures[0].checkpoints.size()+1:
		_position_source_entrance()
		return
	if indexed_chain != null and checkpoint == fixtures[0].checkpoints.size():
		if not _position_chain_approach():
			push_warning("Chain approach is occupied; player position retained")
		return
	super._reset()
	# Inspection look_at can leave local yaw/roll. Walking owns yaw on
	# the player, and only pitch on the child camera.
	camera.rotation = Vector3(-0.15, 0.0, 0.0)

func _jump_checkpoint(index: int) -> void:
	if indexed_chain != null:
		index = posmod(index, _checkpoint_count())
		if index == fixtures[0].checkpoints.size()+1:
			checkpoint = index
			_position_source_entrance()
			return
		if index == fixtures[0].checkpoints.size():
			if _position_chain_approach():
				checkpoint = index
				flight_label.text = "Walk mode · Chain approach · region 800"
			else:
				push_warning("Chain approach is occupied; checkpoint retained")
			return
	flying = false
	super._jump_checkpoint(index)

func _checkpoint_count() -> int:
	return fixtures[0].checkpoints.size() + (2 if indexed_chain != null else 0)

func _position_source_entrance() -> void:
	var arrival: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/cave_start/start.json"))
	start = point(arrival.position)+native_translation
	player.global_position = start+Vector3.UP*34.0
	player.rotation = Vector3(0,wrapf(-float(arrival.heading)*TAU/65536.0,-PI,PI),0)
	camera.rotation = Vector3.ZERO
	target = start-player.basis.z*64.0
	player.velocity = Vector3.ZERO
	flying = false
	flight_label.text = "Walk mode · Cave entrance"

func _unhandled_input(event: InputEvent) -> void:
	if guard_controls!=null and guard_controls.input_locked(): return
	if roach != null and roach.model.player_health <= 0:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R: _reset()
			elif event.keycode == KEY_F9: _quickload()
		return
	if roach != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if roach_population_live==null or not roach_population_live.strike(): roach.strike()
		get_viewport().set_input_as_handled()
		return
	if drowning.dead:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R and drowning_menu.visible:
				_reload_drowning_checkpoint()
			elif event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if not development_mode and event is InputEventKey and event.keycode in [KEY_F,KEY_N,KEY_P,KEY_R,KEY_V,KEY_K,KEY_B,KEY_C,KEY_G,KEY_L,KEY_T]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			if not is_instance_valid(inventory) and not is_instance_valid(video_overlay):
				inventory = preload("res://scripts/lol2/museum_inventory.gd").new()
				inventory.item_ids = carried_items()
				inventory.use_item = item_effects.use
				inventory.equipped_item = equipped_item
				inventory.change_equipment = set_equipped_item
				inventory.equipped_armor = equipped_armor
				inventory.change_armor = set_equipped_armor
				add_child(inventory)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_V and indexed_chain != null:
			_open_video_review()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_E:
			if captain!=null and captain.loot!=null and captain.loot.collect():
				get_viewport().set_input_as_handled();return
			interaction_requested = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F5:
			_quicksave()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9:
			_quickload()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_set_lighting(not lighting_enabled)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		glows_enabled = not glows_enabled
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		dummy_root.visible = not dummy_root.visible
		return
	# Comparison-wall toggle is a diagnostic feature, not part of this view.
	if event is InputEventKey and event.keycode == KEY_T: return
	super._unhandled_input(event)

func _open_video_review() -> void:
	if is_instance_valid(video_overlay): return
	interaction_requested = false
	interaction_available = false
	interaction_prompt.hide()
	video_overlay = load("res://scripts/lol2/cave_video_overlay.gd").new()
	add_child(video_overlay)

func play_chamber_arrival() -> bool:
	# Automatic chamber arrival: Kenneth, then the original cave discussion.
	if not walkthrough_ready or chamber_arrival_state != "not_started" or is_instance_valid(video_overlay):
		return false
	if not preload("res://scripts/lol2/cave_video_overlay.gd").story_assets_ready():
		return false
	if not preload("res://scripts/lol2/museum_walkthrough.gd").assets_ready():
		return false
	chamber_arrival_state = "playing"
	interaction_requested = false
	interaction_available = false
	interaction_prompt.hide()
	video_overlay = load("res://scripts/lol2/cave_video_overlay.gd").new()
	video_overlay.story_mode = true
	video_overlay.ended.connect(func(reason: String):
		chamber_arrival_state = "complete" if reason in ["finished", "skipped"] else "not_started"
		if chamber_arrival_state == "complete": _enter_museum.call_deferred())
	add_child(video_overlay)
	return true

func _enter_museum() -> void:
	if not is_inside_tree() or chamber_arrival_state != "complete": return
	var completion := _completion_state()
	var transfer_error: String = preload("res://scripts/lol2/museum_walkthrough.gd").validate_cave_transfer(completion)
	if not transfer_error.is_empty():
		# Stay in the cave with state intact; the chamber arrival can be retried.
		chamber_arrival_state = "not_started"
		_save_feedback("Cannot leave the cave: " + transfer_error)
		return
	get_tree().set_meta("lol2_cave_completion", completion)
	var error := get_tree().change_scene_to_file("res://scenes/lol2/museum_walkthrough.tscn")
	if error != OK:
		get_tree().remove_meta("lol2_cave_completion")
		chamber_arrival_state = "not_started"
		push_error("Museum scene could not load; chamber sequence can be retried.")

func carried_items() -> Array:
	var items: Array = collectible.saved_ids()+aloe.collected+stalagmites.collected
	if captain!=null:items+=preload("res://scripts/lol2/cave_captain_items.gd").from_checkpoint(captain.state)
	return items.filter(func(id): return id not in item_effect_checkpoint.spent)

func _completion_state() -> Dictionary:
	return {"collected": carried_items(), "item_effects":item_effect_checkpoint.duplicate(true),
		"equipped_item": equipped_item, "equipped_armor": equipped_armor, "health": roach.model.player_health if roach != null else 30,
		"curse": curse.snapshot(), "magic":player_magic_checkpoint.duplicate(true), "player_form": player_form, "chamber_complete": true,
		"fighting":preload("res://scripts/lol2/player_fighting_transport.gd").pack(quest_state)}

func _process(_delta: float) -> void:
	if not walkthrough_ready: return
	hud.modulate.a = 0.0 if drowning.dead else 1.0
	for instance in placed_instances: instance.visible = props_root.visible
	light_camera.global_transform = camera.global_transform
	for material in light_materials: material.set_shader_parameter("glow_enabled", glows_enabled and props_root.visible)
	for pair in light_pairs: pair[1].visible = pair[0].is_visible_in_tree()
	index_camera.global_transform = camera.global_transform
	for cam in layer_cameras: cam.global_transform = camera.global_transform
	for pair in occluder_pairs:
		pair[1].visible = pair[0].is_visible_in_tree()
	var order: Array = range(placed_props.size())
	var direction := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z)
	order.sort_custom(func(a, b):
		var da := direction.dot(point(placed_props[a].position_native))
		var db := direction.dot(point(placed_props[b].position_native))
		return da < db if not is_equal_approx(da, db) else a < b)
	dynamic_order = order
	for i in range(order.size()):
		composites[i].get_child(0).material.set_shader_parameter("source_indices", layer_views[order[i]].get_texture())
	if development_mode:
		hud.text = "Draracle Caverns · Walkthrough proof of concept\nWASD + mouse · Space jump · Shift sprint · Esc release mouse · Click resume\nF fly · Space/Ctrl fly up/down · N/P checkpoints · R reset · F5 save · F9 load\nK dummy creatures · B props · C roof · G glow · L lighting: %s · %s · checkpoint %d\nOriginal assets; lighting and some materials remain provisional." % ["Enhanced" if lighting_enabled else "Reference", "Flying" if flying else "Walking", checkpoint + 1]
	else:
		hud.text = "Draracle’s Caverns\nWASD + mouse · Space jump · E interact · I inventory\nLeft click strike · 1 Spark · 2 Healing · Q cast · F5 save · F9 load"
	hud.text += "\n" + curse.message()
	if captain!=null and captain.loot!=null and captain.loot.aimed(): hud.text += "\nE — Take Short Sword"
	if Time.get_ticks_msec() < save_notice_until:
		hud.text += "\n" + save_notice
	if collectible.collected:
		hud.text += "\nCavern samples: 1"
	if aloe != null: hud.text += "\nCave Aloe: %d · I: inventory" % carried_items().filter(func(id): return preload("res://scripts/lol2/cave_aloe.gd").valid_item(id)).size()
	if equipped_item != "": hud.text += (" · Weapon: " if player_form==0 else " · Stored: ") + preload("res://scripts/lol2/player_equipment.gd").label(equipped_item)
	if roach != null:
		hud.text += "\nHealth: %d/%d · Left click: strike" % [roach.model.player_health,roach.Model.PLAYER_HEALTH]
		if roach.model.player_health<=0: hud.text += "\nYou fell · R: checkpoint · F9: load save"
	interaction_prompt.visible = not drowning.dead and hud.visible and interaction_available and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	interaction_prompt.text = "E · Strike chain" if (indexed_chain != null and indexed_chain.can_strike()) or (river_chains != null and river_chains.target_chain() >= 0) else "E · Collect cavern sample"
	if aloe != null and aloe.target() >= 0: interaction_prompt.text = "E · Pick Cave Aloe"
	if stalagmites != null and stalagmites.target() >= 0: interaction_prompt.text = "E · Take Stalagmite"
	if indexed_chain != null:
		if development_mode:
			hud.text += "\nV: video review"
			if checkpoint == fixtures[0].checkpoints.size(): hud.text += " · Chain approach"
		if development_mode or indexed_chain.can_strike() or (river_chains != null and river_chains.near_bridge()):
			hud.text += "\n" + (river_chains.status_text() if river_chains != null and river_chains.near_bridge() else indexed_chain.status_text())
	if "--dummy-capture" in OS.get_cmdline_user_args():
		_capture_dummies()
	if "--glow-capture" in OS.get_cmdline_user_args():
		_capture_glow()
	if "--lighting-capture" in OS.get_cmdline_user_args():
		_capture_lighting()
	if "--walkthrough-walk-check" in OS.get_cmdline_user_args():
		_walk_check()
	if "--walkthrough-capture" in OS.get_cmdline_user_args():
		audit_frame += 1
		if audit_frame % 12 == 0:
			await RenderingServer.frame_post_draw
			var directory := _capture_path("walkthrough/pose%d") % audit_pose
			DirAccess.make_dir_recursive_absolute(directory)
			index_view.get_texture().get_image().save_png(directory + "/background.png")
			var records: Array = []
			for i in range(order.size()):
				layer_views[order[i]].get_texture().get_image().save_png(directory + "/source%d.png" % i)
				composites[i].get_texture().get_image().save_png(directory + "/composite%d.png" % i)
				records.append(placed_props[order[i]].record)
			get_viewport().get_texture().get_image().save_png(directory + "/resolved.png")
			var file := FileAccess.open(directory + "/view.json", FileAccess.WRITE)
			file.store_string(JSON.stringify({"order": records, "camera": str(camera.global_transform), "props_visible": props_root.visible, "roof_visible": roof.visible, "cameras_synchronized": layer_cameras.all(func(cam): return cam.global_transform.is_equal_approx(camera.global_transform))}, "  "))
			audit_pose += 1
			if audit_pose == 4:
				get_tree().quit()
			else:
				if audit_pose == 1: get_window().size = Vector2i(800, 450)
				props_root.visible = audit_pose != 2
				roof.visible = audit_pose != 3
				camera.global_transform = audit_start
				camera.global_position += Vector3(audit_pose * 0.7, 0, audit_pose * 0.4)
				camera.rotate_y([0.0, 0.4, 1.2, 3.14][audit_pose])

func _physics_process(delta: float) -> void:
	if guard_controls!=null and guard_controls.input_locked():player.velocity=Vector3.ZERO;return
	if captain!=null and captain.intro_active():player.velocity=Vector3.ZERO;return
	if roach != null and roach.model.player_health<=0:
		player.velocity = Vector3.ZERO
		return
	if drowning.dead:
		_advance_drowning_death(delta)
		return
	super._physics_process(delta)
	if walkthrough_ready:
		if roach != null and not flying and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(video_overlay) and lava.contact(player.global_position-native_translation,player.is_on_floor()) >= 0:
			roach.model.player_health = 0
			player.velocity = Vector3.ZERO
			jump_requested = false
			_save_feedback("The lava killed you. R returns to the checkpoint; F9 loads your save.")
			return
		if indexed_chain != null:
			indexed_chain.tick(delta)
		if river_deck != null:
			drowning.advance(delta,not flying and river_water.submerged(player.global_position-native_translation),Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			drowning_notice.text = drowning.message()
			drowning_notice.visible = drowning.active or drowning.dead
			if drowning.dead:
				drowning_camera_origin = camera.position
				drowning_sink_elapsed = 0.0
				if bridge_warning != null: bridge_warning.dismiss()
				player.velocity = Vector3.ZERO
				interaction_requested = false
				interaction_available = false
				return
		if bridge_warning != null: bridge_warning.tick(delta)
		_update_interaction()
		if roach != null: roach.tick(delta)
		if roach_population_live!=null: roach_population_live.advance(delta)
		if curse.active(): RoachPopulation.contact_at(roach_population,roach_population_regions,player.global_position-native_translation,player.is_on_floor())
		_check_chamber_arrival()

func _update_interaction() -> void:
	if stalagmites != null and stalagmites.target() >= 0:
		interaction_available = true
		if interaction_requested and stalagmites.harvest(): _save_feedback("Stalagmite added to inventory.")
		interaction_requested = false
		return
	if aloe != null and aloe.target() >= 0:
		interaction_available = true
		if interaction_requested and aloe.harvest(): _save_feedback("Cave Aloe added to inventory.")
		interaction_requested = false
		return
	if river_chains != null and river_chains.target_chain() >= 0:
		interaction_available = true
		if interaction_requested: river_chains.strike()
		interaction_requested = false
		return
	if indexed_chain != null and indexed_chain.can_strike() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		interaction_available = true
		if interaction_requested:
			indexed_chain.strike()
		interaction_requested = false
		return
	interaction_available = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and collectible.can_collect(camera, player)
	if interaction_requested and interaction_available:
		collectible.restore([Collectible.ID])
		_sync_collected_visuals()
		interaction_available = false
		_save_feedback("Collected cavern sample.")
	interaction_requested = false

func _sync_collected_visuals() -> void:
	var active := Vector4.ONE
	for i in range(glow_records.size()):
		if glow_records[i] == Collectible.RECORD and collectible.collected:
			active[i] = 0.0
	for material in light_materials:
		material.set_shader_parameter("glow_active", active)

func _save_state() -> Dictionary:
	var position := player.position
	var rotation := camera.rotation
	var result := {
		"format": WalkthroughSave.FORMAT, "version": WalkthroughSave.VERSION,
		"map": WalkthroughSave.MAP_ID, "checkpoint": checkpoint,
		"collected": collectible.saved_ids(),
		"player": {"position": [position.x, position.y, position.z],
			"yaw": wrapf(player.rotation.y, -PI, PI),
			"camera_rotation": [rotation.x, rotation.y, rotation.z], "flying": flying},
		"display": {"lighting": lighting_enabled, "glow": glows_enabled,
			"props": props_root.visible, "roof": roof.visible, "creatures": dummy_root.visible}}
	if river_deck != null:
		result.bridge = preload("res://scripts/lol2/cave_bridge_save.gd").capture(river_deck, river_chains, bridge_warning)
	if indexed_chain != null: result.chain_doors = indexed_chain.saved_state()
	if aloe != null: result.aloe = aloe.collected.duplicate()
	if stalagmites != null: result.stalagmites = stalagmites.collected.duplicate()
	result.equipped_item = equipped_item
	result.equipped_armor = equipped_armor
	if roach != null: result.roach = roach.snapshot()
	result.roach_population=roach_population.duplicate(true)
	result.roach_population_schema=1
	if guard_population!=null: result.guards=guard_population.checkpoint()
	if wild_roach_population!=null: result.wild_roach=wild_roach_population.checkpoint()
	if scenic_guard!=null:result.scenic_guard=scenic_guard.checkpoint()
	if lurking_roach_population!=null: result.lurking_roach=lurking_roach_population.checkpoint()
	if eyes!=null:result.eyes=eyes.checkpoint()
	if captain!=null:result.captain=captain.checkpoint()
	if guard_controls!=null:result.guard_controls=guard_controls.checkpoint()
	result.player_form = player_form
	result.curse = curse.snapshot()
	result.magic = player_magic_checkpoint.duplicate(true)
	result.item_effects = item_effect_checkpoint.duplicate(true)
	var fighting:=preload("res://scripts/lol2/player_fighting_transport.gd").pack(quest_state)
	if not fighting.is_empty(): result.fighting=fighting
	return result

func apply_player_form(form: int) -> bool:
	if not FormBody.apply(player, camera, form): return false
	player_form = form
	return true

func set_equipped_item(item_id: String) -> bool:
	if item_id != "" and (not item_id in carried_items() or (Catalog.slot(item_id) != "weapon" or not Catalog.admitted(item_id,"cave"))): return false
	equipped_item = item_id
	return true

func set_equipped_armor(item_id: String) -> bool:
	if item_id != "" and (Catalog.slot(item_id) != "armor" or not Catalog.admitted(item_id,"cave") or not item_id in carried_items()): return false
	equipped_armor = item_id
	return true

func _save_feedback(message: String) -> void:
	save_notice = message
	save_notice_until = Time.get_ticks_msec() + 5000
	print(message)

func _quicksave(path: String = WalkthroughSave.DEFAULT_PATH) -> String:
	if not walkthrough_ready:
		return "The cavern is still loading."
	if is_instance_valid(video_overlay) or drowning.dead or (roach != null and roach.model.player_health<=0):
		var message := "Finish the scene or recover before saving."
		_save_feedback(message)
		return message
	var error := WalkthroughSave.write_save(path, _save_state(), _checkpoint_count())
	_save_feedback("Quicksaved." if error.is_empty() else "Save failed: " + error)
	return error

func _quickload(path: String = WalkthroughSave.DEFAULT_PATH) -> String:
	if not walkthrough_ready:
		return "The cavern is still loading."
	if is_instance_valid(video_overlay): return "Finish the scene before loading."
	var result := WalkthroughSave.read_save(path, _checkpoint_count())
	if not result.error.is_empty():
		_save_feedback("Load failed: " + result.error)
		return result.error
	# Validation completes before any live state changes. Reset the checkpoint
	# anchors first so R and N/P continue from the restored checkpoint.
	var state: Dictionary = result.state
	if state.has("roach") and roach == null: return "This save needs cave combat enabled."
	if (state.has("bridge") and river_deck == null) or (state.has("chain_doors") and indexed_chain == null):
		var message := "This save needs the cave bridge route enabled."
		_save_feedback(message)
		return message
	_clear_drowning()
	_jump_checkpoint(int(state.checkpoint))
	player.position = point(state.player.position)
	item_effect_checkpoint = preload("res://scripts/lol2/player_item_state.gd").canonical(state.get("item_effects",preload("res://scripts/lol2/player_item_state.gd").initial()))
	player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(state.get("magic",preload("res://scripts/lol2/player_magic_state.gd").initial())).checkpoint
	player_form = int(state.get("player_form", 0))
	curse.restore(state.get("curse",Curse.initial()))
	quest_state=preload("res://scripts/lol2/player_fighting_transport.gd").restore(state.get("fighting",{})).checkpoint
	FormBody.apply(player, camera, player_form, false)
	player.rotation = Vector3(0, float(state.player.yaw), 0)
	camera.rotation = point(state.player.camera_rotation)
	jump_requested = false
	player.velocity = Vector3.ZERO
	flying = state.player.flying
	flight_label.text = "Fly mode" if flying else "Walk mode"
	_set_lighting(state.display.lighting)
	glows_enabled = state.display.glow
	props_root.visible = state.display.props
	roof.visible = state.display.roof
	dummy_root.visible = state.display.creatures
	collectible.restore(state.collected)
	aloe.restore(state.get("aloe", []))
	stalagmites.restore(state.get("stalagmites", []))
	equipped_item = state.get("equipped_item", "")
	equipped_armor = state.get("equipped_armor", "")
	roach_population=RoachPopulation.canonical(state.get("roach_population",RoachPopulation.initial()))
	if roach_population_live!=null: roach_population_live.restore()
	if guard_population!=null:
		var Guards=preload("res://scripts/lol2/scripted_creature_state.gd")
		guard_population.restore(state.get("guards",Guards.initial(guard_population.src)))
	if wild_roach_population!=null:
		var WildState=preload("res://scripts/lol2/scripted_creature_state.gd")
		wild_roach_population.restore(state.get("wild_roach",WildState.initial(wild_roach_population.src)))
	if scenic_guard!=null:scenic_guard.restore(state.get("scenic_guard",scenic_guard.State.initial()))
	if lurking_roach_population!=null:
		lurking_roach_population.restore(state.get("lurking_roach",preload("res://scripts/lol2/cave_lurking_roach_state.gd").initial()))
	if eyes!=null:eyes.restore(state.get("eyes",eyes.State.initial(eyes.src)))
	if captain!=null:captain.restore(state.get("captain",captain.initial()))
	if guard_controls!=null:guard_controls.restore(state.get("guard_controls",guard_controls.State.initial()),not state.has("guard_controls"))
	if roach != null:
		if state.has("roach"): roach.restore(state.roach)
		else:
			roach.model = roach.Model.new()
			roach.body.position = roach.spawn
			roach.restore(roach.snapshot())
	if state.has("bridge"):
		preload("res://scripts/lol2/cave_bridge_save.gd").restore(state.bridge, river_deck, river_chains, bridge_warning)
	if state.has("chain_doors"): indexed_chain.restore_save(state.chain_doors)
	_sync_collected_visuals()
	interaction_requested = false
	interaction_available = false
	_save_feedback("Quicksave loaded.")
	return ""

func _walk_check() -> void:
	walk_check_frame += 1
	if walk_check_frame in [30, 90]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.keycode = KEY_W
		event.pressed = walk_check_frame == 30
		if event.pressed:
			walk_check_start = player.global_position
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.parse_input_event(event)
	if walk_check_frame == 110:
		var displacement := Vector2(player.global_position.x - walk_check_start.x, player.global_position.z - walk_check_start.z).length()
		print("Walkthrough input check: moved %.2f units; resets %d; grounded %s" % [displacement, resets, player.is_on_floor()])
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(_capture_path(""))
		get_viewport().get_texture().get_image().save_png(_capture_path("walkthrough_ready.png"))
		get_tree().quit(0 if displacement > 1.0 and resets == 0 and player.is_on_floor() else 1)

func _run_controls_check() -> void:
	set_physics_process(false)
	# Real desktop mouse events must not rotate the camera mid-test.
	set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.collision_mask = 0
	var failures := 0
	var cases := 0
	for checkpoint_id in [13, 0]:
		_jump_checkpoint(checkpoint_id)
		for turn in [0.0, 100.0, -200.0]:
			var mouse := InputEventMouseMotion.new()
			mouse.relative = Vector2(turn, 15)
			_unhandled_input(mouse)
			var forward := -camera.global_basis.z
			forward.y = 0
			forward = forward.normalized()
			var right := camera.global_basis.x
			right.y = 0
			right = right.normalized()
			for pair in [[KEY_W, forward], [KEY_S, -forward], [KEY_A, -right], [KEY_D, right]]:
				player.global_position = Vector3(0, 10000, 0)
				player.velocity = Vector3.ZERO
				var event := InputEventKey.new()
				event.keycode = pair[0]
				event.physical_keycode = pair[0]
				event.pressed = true
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				await get_tree().physics_frame
				var before := player.global_position
				_physics_process(1.0 / 60.0)
				var release: InputEventKey = event.duplicate()
				release.pressed = false
				Input.parse_input_event(release)
				Input.flush_buffered_events()
				var moved := player.global_position - before
				moved.y = 0
				var alignment := moved.normalized().dot(pair[1])
				cases += 1
				if alignment < 0.999:
					failures += 1
					print("Direction mismatch key %s: camera alignment %.4f" % [pair[0], alignment])
	# R/reset must also remove an inherited inspection yaw/roll.
	camera.rotation = Vector3(0.2, 1.1, 0.3)
	_reset()
	if absf(camera.rotation.y) > 0.0001 or absf(camera.rotation.z) > 0.0001: failures += 1
	print("WASD camera-relative checks: %d cases, %d failures" % [cases, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _set_lighting(enabled: bool) -> void:
	lighting_enabled = enabled
	resolve_surface.material.set_shader_parameter("enhanced_lighting", enabled)
	light_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func _build_lighting() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json")).props
	var positions := PackedVector3Array()
	var glow_material_ids: Dictionary = {}
	for i in range(catalog.size()):
		var prop: Dictionary = catalog[i]
		if int(prop.descriptor) == 469:
			glow_records.append(int(prop.record))
			positions.append(point(prop.position_native) + native_translation + Vector3(0, float(prop.top) * 0.65, 0))
			var instance: MeshInstance3D = props_root.get_child(i)
			glow_material_ids[instance.material_override.get_instance_id()] = true
	assert(positions.size() == 4)
	var originals: Array = []
	for pair in occluder_pairs: originals.append(pair[0])
	originals.append_array(placed_instances)
	var materials: Dictionary = {}
	for original in originals:
		var source: Material = original.material_override if original.material_override != null else original.mesh.surface_get_material(0)
		var key := source.get_instance_id()
		if not materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("mask_capture", false)
			material.set_shader_parameter("lighting_capture", true)
			material.set_shader_parameter("glow_positions", positions)
			material.set_shader_parameter("glowing_prop", glow_material_ids.has(key))
			light_materials.append(material)
			materials[key] = material
		var mesh := MeshInstance3D.new()
		mesh.mesh = original.mesh
		mesh.material_override = materials[key]
		mesh.layers = 64
		add_child(mesh)
		mesh.global_transform = original.global_transform
		light_pairs.append([original, mesh])
	light_view = SubViewport.new()
	light_view.size = index_view.size
	light_view.world_3d = get_world_3d()
	add_child(light_view)
	light_camera = Camera3D.new()
	light_camera.cull_mask = 64
	light_camera.fov = camera.fov
	light_camera.near = camera.near
	light_camera.far = camera.far
	light_camera.environment = Environment.new()
	light_camera.environment.background_mode = Environment.BG_COLOR
	light_camera.environment.background_color = Color(0.24, 0.275, 0.325)
	light_view.add_child(light_camera)
	light_camera.current = true
	resolve_surface.material.set_shader_parameter("light_field", light_view.get_texture())

func _capture_lighting() -> void:
	lighting_frame += 1
	if lighting_frame in [18, 30, 42]:
		await RenderingServer.frame_post_draw
		var directory := _capture_path("lighting_%d") % (checkpoint + 1)
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "enhanced" if lighting_frame == 18 else "reference" if lighting_frame == 30 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		index_view.get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		composites.back().get_texture().get_image().save_png(directory + "/final_indices_" + name + ".png")
		if lighting_frame == 18:
			light_view.get_texture().get_image().save_png(directory + "/light.png")
			_set_lighting(false)
		elif lighting_frame == 30: _set_lighting(true)
		else: get_tree().quit()

func _position_glow_review() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--glow-record="): glow_record = int(argument.trim_prefix("--glow-record="))
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json")).props
	for prop in catalog:
		if int(prop.record) == glow_record and int(prop.descriptor) == 469:
			var center := point(prop.position_native) + native_translation + Vector3(0, float(prop.top) / 2, 0)
			var location := Vector3.ZERO
			for face in data.faces:
				if int(face.region) == int(prop.region):
					for vertex in face.points: location += point(vertex) * 64.0
					location /= face.points.size()
					break
			location += native_translation
			if Vector2(location.x - center.x, location.z - center.z).length() < 20.0:
				var farthest := location
				for face in data.faces:
					if int(face.region) == int(prop.region):
						for vertex in face.points:
							var candidate := point(vertex) * 64.0 + native_translation
							if candidate.distance_squared_to(center) > farthest.distance_squared_to(center): farthest = candidate
				location = location.lerp(farthest, 0.65)
			location.y = center.y + 12
			player.global_position = location - Vector3(0, 24, 0)
			player.look_at(Vector3(center.x, player.global_position.y, center.z))
			camera.look_at(center)
			return
	push_error("Glow review record must be111,543,1108 or1137")
	get_tree().quit(1)

func _capture_glow() -> void:
	glow_frame += 1
	if glow_frame in [18, 30, 42]:
		await RenderingServer.frame_post_draw
		var directory := _capture_path("glow_%d") % glow_record
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "glow" if glow_frame == 18 else "plain" if glow_frame == 30 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		composites.back().get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		light_view.get_texture().get_image().save_png(directory + "/light_" + name + ".png")
		if glow_frame == 18: glows_enabled = false
		elif glow_frame == 30: glows_enabled = true
		else: get_tree().quit()

func _configure_review() -> void:
	super._configure_review()
	dummy_root = Node3D.new()
	stage.add_child(dummy_root)
	var root := "res://assets/lol2/generated/dummy_creatures/"
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(root + "creatures.json"))
	var frames: Dictionary = {}
	var materials: Dictionary = {}
	for frame in catalog.frames:
		var descriptor := int(frame.descriptor)
		frames[descriptor] = frame
		var material := _indexed_material(root + "creature_%d.png" % descriptor)
		material.set_shader_parameter("sprite", true)
		materials[descriptor] = material
	for placement in catalog.placements:
		var center := Vector3.ZERO
		var found := false
		for face in data.faces:
			if int(face.region) == int(placement.region):
				for vertex in face.points: center += point(vertex) * 64.0
				center /= face.points.size()
				if placement.has("vertex"):
					center = center.lerp(point(face.points[int(placement.vertex)]) * 64.0, float(placement.fraction))
				found = true
				break
		assert(found)
		var descriptor := int(placement.descriptor)
		var frame: Dictionary = frames[descriptor]
		var quad := QuadMesh.new()
		quad.size = Vector2(frame.preview_width, frame.preview_height)
		quad.center_offset.y = float(frame.preview_height) * 0.5
		quad.material = materials[descriptor]
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.position = center + native_translation
		instance.set_meta("dummy_id", str(placement.id))
		instance.layers = 2
		dummy_root.add_child(instance)
	print("Dummy creature preview:2 guards and2 roach-like sprites; provisional scale/positions")

func _capture_dummies() -> void:
	if dummy_frame == 0 and not player.is_on_floor(): return
	dummy_frame += 1
	if dummy_frame in [60, 72, 84]:
		await RenderingServer.frame_post_draw
		set_physics_process(false)
		var directory := _capture_path("dummies_%d") % (checkpoint + 1)
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "shown" if dummy_frame == 60 else "hidden" if dummy_frame == 72 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		index_view.get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		if dummy_frame == 60: dummy_root.visible = false
		elif dummy_frame == 72: dummy_root.visible = true
		else: get_tree().quit()

func _position_chain_approach() -> bool:
	# Source region800 is the validated approach; walkthrough uses native units.
	var floor_center := Vector3.ZERO
	var found := false
	for face in data.faces:
		if int(face.region) == 800:
			for vertex in face.points:
				floor_center += point(vertex) * 64.0 / face.points.size()
			found = true
			break
	if not found:
		return false
	var candidate := floor_center + native_translation + Vector3.UP * 32.1
	var shape_node: CollisionShape3D = player.get_child(0)
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = shape_node.shape
	probe.transform = Transform3D(Basis.IDENTITY, candidate + shape_node.position)
	probe.collision_mask = player.collision_mask
	probe.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(probe).is_empty():
		return false
	player.global_position = candidate
	player.velocity = Vector3.ZERO
	flying = false
	var chain_center := Vector3(1217, -165, -11501) + native_translation
	player.look_at(Vector3(chain_center.x, candidate.y, chain_center.z), Vector3.UP)
	camera.look_at(chain_center, Vector3.UP)
	return true

func _build_indexed_doors() -> void:
	assert(indexed_doors.is_empty())
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/motion.json"))
	var placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/placement.json"))
	for source in placement.placements:
		var door = load("res://scripts/lol2/recovered_door.gd").new()
		add_child(door)
		for record in motion.doors:
			if int(record.index) == int(source.index):
				door.configure(record, 1.0)
		var p: Array = source.native_xyz
		door.position = Vector3(p[0], p[2], -p[1]) + native_translation
		door.scale.z = -1.0
		for face in range(4):
			var surface: MeshInstance3D = door.get_child(face)
			var id: int = door._frames[0][face].material
			surface.material_override = _indexed_material("res://assets/lol2/doors/indices_%d.png" % id)
			surface.layers = 2
			indexed_door_surfaces.append(surface)
		_copy_occluders(door)
		var body = load("res://scripts/lol2/recovered_door_collision.gd").new()
		door.add_child(body)
		body.bind(door)
		indexed_doors.append(door)
		door.opening_changed.connect(func(_percent: int) -> void: _sync_indexed_door_layers())

func _sync_indexed_door_layers() -> void:
	# Sample changes replace meshes; all indexed/occlusion/light copies must follow.
	for pair in occluder_pairs + light_pairs:
		if pair[0] in indexed_door_surfaces:
			pair[1].mesh = pair[0].mesh
			pair[1].global_transform = pair[0].global_transform

func _check_chamber_arrival() -> void:
	# Authored arrival volume on recovered center approach region1214.
	# Original native trigger boundary is not claimed by this placement.
	if indexed_chain == null or flying or chamber_arrival_state != "not_started": return
	if roach != null and roach.model.player_health<=0: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var position_native := player.global_position - native_translation
	if position_native.x < -79.0 or position_native.x > -47.0: return
	if position_native.z > -18601.0 or position_native.z < -18637.0: return
	# Native floor -295; walking capsule center is floor +32.
	if absf(position_native.y - (-263.0)) > 8.0: return
	play_chamber_arrival()
