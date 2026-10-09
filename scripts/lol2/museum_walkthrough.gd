extends "res://scripts/lol2/museum_review.gd"
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Overlay = preload("res://scripts/lol2/cave_video_overlay.gd")
const INTRO_CLIPS := [4, 5]
const Save = preload("res://scripts/lol2/museum_save.gd")
const CHECKPOINT_KEY := "lol2_museum_checkpoint"
## Cave chamber completion packet (tree meta lol2_cave_completion), checked by the cave before it
## leaves and again on Museum entry. Optional fields keep legacy packets valid; every carried,
## equipped or consumed item must be cave-owned. Reuses the catalog and existing player validators.
static func validate_cave_transfer(state: Variant) -> String:
	if not state is Dictionary: return "Invalid cave completion."
	var ids = state.get("collected",[])
	var error := Catalog.validate_carried(ids,"cave")
	if error.is_empty(): error = Catalog.validate_slots(ids,"cave",state.get("equipped_item",""),state.get("equipped_armor",""))
	if error.is_empty() and state.has("item_effects"):
		error = preload("res://scripts/lol2/player_item_state.gd").validate(state.item_effects,ids)
		if error.is_empty() and not state.item_effects.spent.all(func(id): return Catalog.admitted(id,"cave")): error = "Inconsistent consumed item."
	if error.is_empty() and state.has("magic"): error = str(preload("res://scripts/lol2/player_magic_state.gd").restore(state.magic).get("error",""))
	if error.is_empty() and state.has("fighting"): error = str(preload("res://scripts/lol2/player_fighting_transport.gd").restore(state.fighting).get("error",""))
	if error.is_empty() and state.has("health") and (not Save.within(state.health,1,30) or state.health != int(state.health)): error = "Invalid player health."
	if error.is_empty() and state.has("player_form") and not preload("res://scripts/lol2/player_form_body.gd").valid(state.player_form): error = "Invalid player form."
	if error.is_empty() and state.has("curse") and not preload("res://scripts/lol2/player_curse.gd").valid(state.curse,state.get("player_form",0)): error = "Invalid curse state."
	if error.is_empty() and state.has("chamber_complete") and not (state.chamber_complete is bool and state.chamber_complete): error = "Invalid cave completion."
	return error
var introduction: CanvasLayer
var introduction_state := "not_started"
const SWORD_ITEM_ID := "museum:item11:Fine_Longsword"
var carried_collected: Array = []
var quest_state: Dictionary = {}
var hand_item := ""
var broken_case: Node3D
var broken_thohan: Node3D
const MAIL_ITEM_ID := "museum:item10:Mail_Shirt"
const Stones = preload("res://scripts/lol2/museum_stones.gd")
var champion_stones: Node3D
var mail_shirt: Sprite3D
var equipped_item := ""
var equipped_armor := ""
var interaction_label: Label
var pickup_notice_time := 0.0
var health := 30
var player_magic_checkpoint := preload("res://scripts/lol2/player_magic_state.gd").initial()
## Cave fighting progression carried unchanged to Jungle quests.
var fighting_checkpoint: Dictionary = {}
var control96: Node3D
var blood_loot: Node3D
var skeleton_population: Node3D
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var player_form := 0
const Curse = preload("res://scripts/lol2/player_curse.gd")
var curse := Curse.new()
var inventory: CanvasLayer
var interface_hud: CanvasLayer
const MirrorRoute = preload("res://scripts/lol2/museum_mirror_route.gd")
var mirror_transition_pending := false
var exhibit_retry: Dictionary = {}
var failure_overlay: CanvasLayer
var dragon_door: AnimatableBody3D
var gallery: Node3D
var key_locks: Node3D
var long_arm: Node3D
const LongArm = preload("res://scripts/lol2/museum_long_arm.gd")
const LongArmState = preload("res://scripts/lol2/museum_long_arm_state.gd")
const KeyLocks = preload("res://scripts/lol2/museum_key_locks.gd")
const KeyLockState = preload("res://scripts/lol2/museum_key_locks_state.gd")
var escape_regions: Array = []
var escape_wall: MeshInstance3D
var hourglass: MeshInstance3D
var dragon_flight: CanvasLayer
const DRAGON_CLIPS := [6,7,8]

static func assets_ready() -> bool:
	if not preload("res://scripts/lol2/museum_control96.gd").assets_ready(): return false
	if not FileAccess.file_exists("res://assets/lol2/generated/museum_broken_case/case.json"): return false
	for name in ["control.json","icon.png","sword_0.png"]:
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_broken_thohan/"+name): return false
	if not FileAccess.file_exists("res://assets/lol2/generated/museum_dragon_door/door.png"): return false
	if not FileAccess.file_exists("res://assets/lol2/generated/museum_gallery/painting.png"): return false
	if not FileAccess.file_exists("res://assets/lol2/generated/museum_escape_wall/escape_regions.json"): return false
	for i in range(1,5):
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_escape_wall/stage_%d.png" % i): return false
	if not preload("res://scripts/lol2/museum_hourglass.gd").assets_ready(): return false
	for name in ["stone.png", "items.json"]:
		if not FileAccess.file_exists(Stones.ROOT + name): return false
	for name in ["mail.png", "item.json"]:
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_mail/" + name): return false
	for name in ["portrait.png", "portrait_frame.png", "cursor.png", "blink_1.png", "blink_2.png", "blink_3.png"]:
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_interface/" + name): return false
	if not preload("res://scripts/lol2/museum_gate.gd").assets_ready(): return false
	if not preload("res://scripts/lol2/museum_sword_transfer.gd").assets_ready(): return false
	if not Overlay.story_assets_ready(INTRO_CLIPS): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_review/museum.json"))
	if not data is Dictionary or not data.get("faces") is Array or data.faces.is_empty(): return false
	if not data.get("materials") is Dictionary: return false
	for path in data.materials.values():
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_review/" + str(path)): return false
	for animation in data.get("animations", {}).values():
		for frame in animation.frames:
			if not FileAccess.file_exists("res://assets/lol2/generated/museum_review/" + frame): return false
	var props = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_props/props.json"))
	if not props is Dictionary or not props.get("images") is Dictionary: return false
	for entry in props.images.values():
		if not FileAccess.file_exists("res://assets/lol2/generated/museum_props/" + str(entry.file)): return false
		for frame in entry.get("frames", []):
			if not FileAccess.file_exists("res://assets/lol2/generated/museum_props/" + str(frame.file)): return false
	return true

var item_effects: Node
var item_effect_checkpoint := preload("res://scripts/lol2/player_item_state.gd").initial()
var starting_magic: Node
func attach_starting_magic() -> void:
	starting_magic=preload("res://scripts/lol2/player_starting_magic.gd").new()
	starting_magic.name="StartingMagic"
	add_child(starting_magic)
	item_effects=preload("res://scripts/lol2/player_item_controller.gd").new()
	add_child(item_effects)

func _ready() -> void:
	super._ready()
	add_child(curse)
	attach_starting_magic.call_deferred()
	set_development_mode(false)
	var state = get_tree().get_meta("lol2_cave_completion", {})
	var transfer_error := validate_cave_transfer(state)
	if not transfer_error.is_empty():
		# The cave refuses to leave with such a packet; never half-apply it here.
		push_warning("Rejected cave completion packet: " + transfer_error)
		state = {}
	carried_collected = state.get("collected", []).duplicate()
	set_equipped_item(state.get("equipped_item", ""))
	set_equipped_armor(state.get("equipped_armor", ""))
	item_effect_checkpoint=preload("res://scripts/lol2/player_item_state.gd").canonical(state.get("item_effects",preload("res://scripts/lol2/player_item_state.gd").initial()))
	player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(state.get("magic",preload("res://scripts/lol2/player_magic_state.gd").initial())).checkpoint
	fighting_checkpoint = preload("res://scripts/lol2/player_fighting_transport.gd").restore(state.get("fighting",{})).get("checkpoint",{})
	health = int(state.get("health",30))
	player_form = int(state.get("player_form",0))
	curse.restore(state.get("curse",Curse.initial()))
	var checkpoint = get_tree().get_meta(CHECKPOINT_KEY, {})
	if checkpoint is Dictionary and checkpoint.get("version", 0) == 1:
		if checkpoint.get("introduction_complete", false): introduction_state = "complete"
		item_effect_checkpoint=preload("res://scripts/lol2/player_item_state.gd").canonical(checkpoint.get("item_effects",item_effect_checkpoint))
		player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(checkpoint.get("magic",player_magic_checkpoint)).checkpoint
		fighting_checkpoint = preload("res://scripts/lol2/player_fighting_transport.gd").restore(checkpoint.get("fighting",fighting_checkpoint)).get("checkpoint",{})
		health = int(checkpoint.get("health",health))
		player_form = int(checkpoint.get("player_form",player_form))
		curse.restore(checkpoint.get("curse",Curse.initial()))
		sword_transfer.restore_checkpoint(checkpoint.get("sword", {}))
		museum_gate.restore_checkpoint(checkpoint.get("gate", {}))
		carried_collected = checkpoint.get("collected", carried_collected).duplicate()
		var saved_equipment = checkpoint.get("equipped_item", "")
		if (Catalog.slot(saved_equipment) == "weapon" and Catalog.admitted(saved_equipment,"museum")) and saved_equipment in carried_collected:
			equipped_item = saved_equipment
		if preload("res://scripts/lol2/player_equipment.gd").armor(checkpoint.get("equipped_armor", "")) and checkpoint.get("equipped_armor", "") in carried_collected:
			equipped_armor = checkpoint.equipped_armor
	if checkpoint is Dictionary:
		if checkpoint.has("museum_control181"): quest_state["museum_control181"] = checkpoint.museum_control181.duplicate(true)
		hand_item = checkpoint.get("hand_item","")
	FormBody.apply(player,camera,player_form,false)
	if SWORD_ITEM_ID in carried_collected: sword_transfer.collect()
	mail_shirt = preload("res://scripts/lol2/museum_mail.gd").new()
	add_child(mail_shirt)
	mail_shirt.visible = not MAIL_ITEM_ID in carried_collected
	champion_stones = Stones.new()
	add_child(champion_stones)
	champion_stones.restore_collected(carried_collected+item_effect_checkpoint.spent)
	var interaction_ui := CanvasLayer.new()
	add_child(interaction_ui)
	interaction_label = Label.new()
	interaction_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interaction_label.offset_top = -112
	interaction_label.offset_bottom = -84
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_label.add_theme_constant_override("shadow_offset_x", 2)
	interaction_label.add_theme_constant_override("shadow_offset_y", 2)
	interaction_label.hide()
	interaction_ui.add_child(interaction_label)
	interface_hud = preload("res://scripts/lol2/museum_interface.gd").new()
	interface_hud.walkthrough = self
	add_child(interface_hud)
	broken_case = preload("res://scripts/lol2/museum_broken_case.gd").new()
	broken_case.name = "BrokenCase"
	add_child(broken_case)
	broken_thohan = preload("res://scripts/lol2/museum_broken_thohan.gd").new()
	broken_thohan.name = "BrokenThohan"
	add_child(broken_thohan)
	broken_thohan.set_process_unhandled_input(false)
	_add_mirror_visual()
	hourglass = preload("res://scripts/lol2/museum_hourglass.gd").new()
	add_child(hourglass)
	hourglass.expired.connect(show_exhibit_failure.call_deferred)
	if checkpoint is Dictionary: hourglass.restore_checkpoint(checkpoint.get("hourglass", {}))
	escape_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_escape_wall/escape_regions.json")).regions
	escape_wall = preload("res://scripts/lol2/museum_escape_wall.gd").new()
	add_child(escape_wall)
	if preload("res://scripts/lol2/museum_skeleton_population.gd").assets_ready():
		skeleton_population = preload("res://scripts/lol2/museum_skeleton_population.gd").new()
		skeleton_population.name = "SkeletonPopulation"
		add_child(skeleton_population)
		var saved_creatures = checkpoint.get("skeletons") if checkpoint is Dictionary else null
		var creature_error: String = skeleton_population.setup(self, saved_creatures)
		if not creature_error.is_empty(): push_error(creature_error)
		sword_transfer.replaced_by_actor.connect(spawn_sword_skeleton)
		blood_loot=preload("res://scripts/lol2/museum_blood_loot.gd").new();add_child(blood_loot)
		blood_loot.setup(self,checkpoint.get("museum_blood_loot") if checkpoint is Dictionary else null)
	if preload("res://scripts/lol2/museum_control96.gd").assets_ready():
		control96=preload("res://scripts/lol2/museum_control96.gd").new()
		control96.name="MuseumControl96"
		add_child(control96)
		var control_error: String=control96.setup(self,checkpoint.get("museum_control96") if checkpoint is Dictionary else null)
		if not control_error.is_empty(): push_error(control_error)
	if checkpoint is Dictionary: restore_escape_wall(checkpoint)
	gallery = preload("res://scripts/lol2/museum_gallery.gd").new()
	add_child(gallery)
	if checkpoint is Dictionary: gallery.restore_checkpoint(checkpoint.get("gallery", {}))
	if KeyLocks.assets_ready():
		key_locks = KeyLocks.new()
		add_child(key_locks)
		var lock_error: String = key_locks.setup(self, checkpoint.get("museum_key_locks") if checkpoint is Dictionary else null)
		if not lock_error.is_empty(): push_error(lock_error)
	if LongArm.assets_ready():
		long_arm = LongArm.new()
		add_child(long_arm)
		var arm_error: String = long_arm.setup(self, checkpoint.get("museum_long_arm") if checkpoint is Dictionary else null)
		if not arm_error.is_empty(): push_error(arm_error)
	dragon_door = preload("res://scripts/lol2/museum_dragon_door.gd").new()
	add_child(dragon_door)
	if checkpoint is Dictionary: dragon_door.restore_checkpoint(checkpoint.get("dragon_door", {}))
	get_window().title = "Lands of Lore II — Draracle’s museum"
	if get_tree().has_meta("lol2_museum_resume"):
		var resume = get_tree().get_meta("lol2_museum_resume")
		get_tree().remove_meta("lol2_museum_resume")
		if Save.validate(resume).is_empty(): apply_save(resume)
	start_introduction()

## Lock78's passage faces (regions1237/1477 closed floors and walls) are built by the key-lock owner.
func excluded_faces() -> Dictionary:
	var result := {}
	if KeyLocks.assets_ready():
		for index in KeyLocks.passage_data().closed_face_indices: result[int(index)] = true
	# Prop153's floor trap regions are built by the Long arm owner.
	if LongArm.assets_ready():
		for index in LongArm.floor_data().closed_face_indices: result[int(index)] = true
	return result

func start_introduction() -> bool:
	if introduction_state != "not_started" or is_instance_valid(introduction): return false
	if not Overlay.story_assets_ready(INTRO_CLIPS): return false
	introduction_state = "playing"
	introduction = Overlay.new()
	introduction.story_mode = true
	introduction.story_clips = INTRO_CLIPS.duplicate()
	introduction.story_title = "Draracle’s museum"
	introduction.ended.connect(func(reason: String):
		introduction_state = "complete" if reason in ["finished", "skipped"] else "not_started")
	add_child(introduction)
	return true

func _exit_tree() -> void:
	if not ready_for_review or not is_instance_valid(sword_transfer) or not is_instance_valid(museum_gate): return
	get_tree().set_meta(CHECKPOINT_KEY, checkpoint_state())

func checkpoint_state() -> Dictionary:
	return {
		"version": 1,
		"museum_control96":control96.checkpoint() if is_instance_valid(control96) else preload("res://scripts/lol2/museum_control96_state.gd").initial(),
		"museum_control181":quest_state.get("museum_control181",{"owner_state":0,"sprite_mode":0}).duplicate(true),"hand_item":hand_item,
		"item_effects":item_effect_checkpoint.duplicate(true), "health": health, "magic":player_magic_checkpoint.duplicate(true), "fighting":fighting_checkpoint.duplicate(true), "player_form": player_form, "curse": curse.snapshot(),
		"introduction_complete": introduction_state == "complete",
		"sword": sword_transfer.checkpoint(),
		"gate": museum_gate.checkpoint(),
		"collected": carried_collected.duplicate(),
		"equipped_item": equipped_item,
		"equipped_armor": equipped_armor,
		"hourglass": hourglass.checkpoint() if is_instance_valid(hourglass) else {},
		"escape_wall": escape_wall.checkpoint() if is_instance_valid(escape_wall) else {},
		"gallery": gallery.checkpoint() if is_instance_valid(gallery) else {},
		"museum_key_locks": key_locks.checkpoint() if is_instance_valid(key_locks) else KeyLockState.initial(),
		"museum_long_arm": long_arm.checkpoint() if is_instance_valid(long_arm) else LongArmState.initial(),
		"museum_blood_loot": blood_loot.checkpoint() if is_instance_valid(blood_loot) else null,
		"skeletons": skeleton_population.checkpoint() if is_instance_valid(skeleton_population) else preload("res://scripts/lol2/museum_skeleton_population_state.gd").initial(),
		"dragon_door": dragon_door.checkpoint() if is_instance_valid(dragon_door) else {}
	}

func can_take_sword() -> bool:
	if get_tree().paused or not sword_transfer.available or sword_transfer.collected: return false
	if not sword_transfer.table_sword.visible: return false
	return can_reach_item(sword_transfer.table_sword.global_position)

func can_reach_item(target: Vector3) -> bool:
	if get_tree().paused: return false
	var offset := target - camera.global_position
	if offset.length() > 96 or offset.length() < 0.01: return false
	if (-camera.global_basis.z).dot(offset.normalized()) < 0.97: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func take_sword() -> bool:
	if not can_take_sword(): return false
	sword_transfer.collect()
	if not SWORD_ITEM_ID in carried_collected: carried_collected.append(SWORD_ITEM_ID)
	pickup_notice_time = 2.5
	interaction_label.text = "Fine Longsword added to inventory."
	interaction_label.show()
	return true

func open_inventory() -> bool:
	if get_tree().paused or is_instance_valid(inventory): return false
	inventory = preload("res://scripts/lol2/museum_inventory.gd").new()
	inventory.use_item = use_inventory_item
	inventory.hold_item = hold_for_exhibit
	inventory.held_item_id = hand_item
	inventory.item_ids = carried_collected.duplicate()
	inventory.equipped_item = equipped_item
	inventory.equipped_armor = equipped_armor
	inventory.change_armor = set_equipped_armor
	inventory.change_equipment = set_equipped_item
	inventory.return_to_game = interface_hud.set_cursor.bind(false)
	add_child(inventory)
	return true

# Authored mouse binding and sword requirement; exact native button/weapon unverified.
func can_strike_hourglass() -> bool:
	if not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(player_form): return false
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(hourglass) or hourglass.activated: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	return equipped_item == SWORD_ITEM_ID and SWORD_ITEM_ID in carried_collected and can_reach_item(hourglass.global_position + Vector3(0,31,0))

func strike_hourglass() -> bool:
	if not can_strike_hourglass(): return false
	exhibit_retry = capture_exhibit_retry()
	if not hourglass.receive_hit(): return false
	escape_wall.begin_decay()
	gallery.close_for_hourglass()
	return true

func capture_exhibit_retry() -> Dictionary:
	return {"format":Save.FORMAT,"version":1,"checkpoint":checkpoint_state(),
		"player":{"position":[player.position.x,player.position.y,player.position.z],"yaw":wrapf(player.rotation.y,-PI,PI),"pitch":camera.rotation.x}}

func prepare_legacy_exhibit_retry() -> void:
	exhibit_retry = capture_exhibit_retry()
	exhibit_retry.checkpoint.hourglass = {"activated":false,"elapsed":0}
	exhibit_retry.checkpoint.escape_wall = {"stage":0,"wait":-1}
	exhibit_retry.checkpoint.gallery = {"painting_moved":true,"lever_pulled":true,"gate_open":true,"progress":1}
	exhibit_retry.player = {"position":[1332,32,-590],"yaw":0,"pitch":0}

func show_exhibit_failure() -> void:
	if not hourglass.failed or is_instance_valid(failure_overlay) or mirror_transition_pending: return
	if exhibit_retry.is_empty(): prepare_legacy_exhibit_retry()
	failure_overlay = preload("res://scripts/lol2/museum_failure_overlay.gd").new()
	failure_overlay.walkthrough = self
	add_child(failure_overlay)

func check_exhibit_escape() -> bool:
	if get_tree().paused or flying or introduction_state != "complete": return false
	if not is_instance_valid(hourglass) or not hourglass.activated or hourglass.escaped: return false
	if not is_instance_valid(escape_wall) or escape_wall.stage != 4 or not player.is_on_floor(): return false
	var p := player.global_position
	# Whole capsule must clear the wall; constrain admission to this vertical passage.
	if p.x < 1441 or p.y < -68.1 or p.y > 58.1: return false
	for region in escape_regions:
		var polygon := PackedVector2Array()
		for point in region.polygon: polygon.append(Vector2(point[0],point[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):
			if hourglass.finish_escape():
				save_feedback("You escaped the time chamber.")
				return true
	return false

func restore_escape_wall(checkpoint: Dictionary) -> void:
	escape_wall.restore_checkpoint(checkpoint.get("escape_wall", {}))
	# Saves made before wall restoration must retain a usable escape sequence.
	if not checkpoint.has("escape_wall") and hourglass.activated: escape_wall.begin_decay()

func can_strike_escape_wall() -> bool:
	if not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(player_form): return false
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(escape_wall) or escape_wall.stage < 1 or escape_wall.stage >= 4: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	return equipped_item == SWORD_ITEM_ID and SWORD_ITEM_ID in carried_collected and can_reach_item(escape_wall.global_position + (camera.global_position - escape_wall.global_position).normalized() * 3.0)

func strike_escape_wall() -> bool:
	return escape_wall.receive_hit() if can_strike_escape_wall() else false

# Prop107 kind9 hit record (state3); melee admission mirrors creature strikes (adapter).
func can_strike_sword_skeleton() -> bool:
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(skeleton_population) or not sword_transfer.available: return false
	if sword_transfer.phase != "complete" or sword_transfer.struck or sword_transfer.replaced: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	if player_form == 0 and equipped_item == "": return false
	return can_reach_item(sword_transfer.hit_point())

func strike_sword_skeleton() -> bool:
	return sword_transfer.receive_hit() if can_strike_sword_skeleton() else false

## Source group2022: actor21 op9 property3 at prop107's place; no later wake command, so it rises and fights.
func spawn_sword_skeleton() -> void:
	if not is_instance_valid(skeleton_population): return
	const CreatureState = preload("res://scripts/lol2/scripted_creature_state.gd")
	CreatureState.spawn(skeleton_population.state, "21")
	CreatureState.wake(skeleton_population.state, "21")
	skeleton_population.present()

func gallery_target() -> String:
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return ""
	if not is_instance_valid(gallery) or (is_instance_valid(interface_hud) and interface_hud.cursor_active): return ""
	if not gallery.painting_moved and can_reach_item(gallery.painting.global_position): return "painting"
	if gallery.painting_moved and not gallery.lever_pulled and can_reach_item(gallery.lever.global_position): return "lever"
	return ""

func use_gallery() -> bool:
	match gallery_target():
		"painting": return gallery.move_painting()
		"lever": return gallery.pull_lever()
	return false

func can_open_dragon_door() -> bool:
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(dragon_door) or dragon_door.opened: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	var target := dragon_door.global_position + Vector3(0,35,0)
	return can_reach_item(target + (camera.global_position-target).normalized()*4)

func open_dragon_door() -> bool:
	return dragon_door.open() if can_open_dragon_door() else false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if strike_hourglass() or strike_escape_wall() or strike_sword_skeleton():
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if open_inventory(): get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if (introduction_state == "complete" and broken_thohan.use()) or (is_instance_valid(key_locks) and key_locks.use()) or (is_instance_valid(long_arm) and long_arm.use()) or (is_instance_valid(blood_loot) and blood_loot.use()) or (is_instance_valid(skeleton_population) and skeleton_population.use_control()) or open_dragon_door() or use_gallery() or enter_dragon() or enter_mirror() or take_sword() or take_mail() or take_stone(0) or take_stone(1): get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	check_exhibit_escape()
	if not is_instance_valid(interaction_label): return
	pickup_notice_time = maxf(0, pickup_notice_time - delta)
	if pickup_notice_time > 0: return
	var broken_hint: String = broken_thohan.interaction_hint() if introduction_state == "complete" else ""
	if not broken_hint.is_empty():
		interaction_label.text = broken_hint
		interaction_label.show()
		return
	var lock_hint: String = key_locks.interaction_hint() if is_instance_valid(key_locks) else ""
	if not lock_hint.is_empty():
		interaction_label.text = lock_hint
		interaction_label.show()
		return
	var arm_hint: String = long_arm.interaction_hint() if is_instance_valid(long_arm) else ""
	if not arm_hint.is_empty():
		interaction_label.text = arm_hint
		interaction_label.show()
		return
	var blood_hint: String=blood_loot.interaction_hint() if is_instance_valid(blood_loot) else ""
	if not blood_hint.is_empty():
		interaction_label.text=blood_hint;interaction_label.show();return
	var control_hint: String = skeleton_population.control_hint() if is_instance_valid(skeleton_population) else ""
	if not control_hint.is_empty():
		interaction_label.text = control_hint
		interaction_label.show()
		return
	if can_open_dragon_door():
		interaction_label.text = "E — Open wooden door"
		interaction_label.show()
		return
	var gallery_action := gallery_target()
	if not gallery_action.is_empty():
		interaction_label.text = "E — Move painting" if gallery_action == "painting" else "E — Pull lever"
		interaction_label.show()
		return
	if can_strike_escape_wall():
		interaction_label.text = "Left click — Break damaged wall"
		interaction_label.show()
		return
	if can_strike_hourglass():
		interaction_label.text = "Left click — Strike hourglass"
		interaction_label.show()
		return
	var sword_ready := can_take_sword()
	var mail_ready := can_take_mail()
	interaction_label.visible = can_enter_dragon() or can_enter_mirror() or sword_ready or mail_ready or can_take_stone(0) or can_take_stone(1)
	interaction_label.text = "E — Travel with the dragon" if can_enter_dragon() else "E — Enter Shining Path" if can_enter_mirror() else "E — Take Fine Longsword" if sword_ready else ("E — Take Mail Shirt" if mail_ready else "E — Take Champion Stone")

func set_equipped_item(item_id: String) -> bool:
	if item_id != "" and ((Catalog.slot(item_id) != "weapon" or not Catalog.admitted(item_id,"museum")) or not item_id in carried_collected): return false
	equipped_item = item_id
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	return true

func save_feedback(message: String) -> void:
	pickup_notice_time = 4.0
	interaction_label.text = message
	interaction_label.show()

func quicksave(path: String = Save.DEFAULT_PATH) -> String:
	if introduction_state != "complete" or get_tree().paused: return "Close the current overlay before saving."
	if flying:
		save_feedback("Return to walking mode before saving.")
		return "Return to walking mode before saving."
	var state := {"format": Save.FORMAT, "version": 1, "checkpoint": checkpoint_state(),
		"player": {"position": [player.position.x,player.position.y,player.position.z],
		"yaw": wrapf(player.rotation.y,-PI,PI), "pitch": camera.rotation.x}}
	var error := Save.write_save(path,state)
	save_feedback("Museum saved." if error.is_empty() else "Save failed: " + error)
	return error

func quickload(path: String = Save.DEFAULT_PATH) -> String:
	if get_tree().paused: return "Close the current overlay before loading."
	var result := Save.read_save(path)
	if not result.error.is_empty():
		save_feedback("Load failed: " + result.error)
		return result.error
	apply_save(result.state)
	save_feedback("Museum save loaded.")
	return ""

func apply_save(state: Dictionary) -> void:
	var saved: Dictionary = state.checkpoint
	introduction_state = "complete"
	hourglass.restore_checkpoint(saved.get("hourglass", {}))
	restore_escape_wall(saved)
	gallery.restore_checkpoint(saved.get("gallery", {}))
	dragon_door.restore_checkpoint(saved.get("dragon_door", {}))
	sword_transfer.restore_checkpoint(saved.sword)
	museum_gate.restore_checkpoint(saved.gate)
	item_effect_checkpoint=preload("res://scripts/lol2/player_item_state.gd").canonical(saved.get("item_effects",preload("res://scripts/lol2/player_item_state.gd").initial()))
	carried_collected = saved.collected.duplicate()
	quest_state = {}
	if saved.has("museum_control181"): quest_state["museum_control181"] = saved.museum_control181.duplicate(true)
	hand_item = saved.get("hand_item","")
	broken_thohan.restore()
	if is_instance_valid(key_locks):
		var lock_error: String = key_locks.restore_checkpoint(saved.get("museum_key_locks",KeyLockState.initial()))
		if not lock_error.is_empty(): push_error(lock_error)
	if is_instance_valid(long_arm):
		var arm_error: String = long_arm.restore_checkpoint(saved.get("museum_long_arm",LongArmState.initial()))
		if not arm_error.is_empty(): push_error(arm_error)
	champion_stones.restore_collected(carried_collected+item_effect_checkpoint.spent)
	mail_shirt.visible = not MAIL_ITEM_ID in carried_collected
	player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(saved.get("magic",preload("res://scripts/lol2/player_magic_state.gd").initial())).checkpoint
	fighting_checkpoint = preload("res://scripts/lol2/player_fighting_transport.gd").restore(saved.get("fighting",{})).get("checkpoint",{})
	if is_instance_valid(skeleton_population): skeleton_population.restore(saved.get("skeletons",preload("res://scripts/lol2/museum_skeleton_population_state.gd").initial()))
	if is_instance_valid(blood_loot):blood_loot.restore(saved.get("museum_blood_loot"))
	if is_instance_valid(control96): control96.restore_checkpoint(saved.get("museum_control96",preload("res://scripts/lol2/museum_control96_state.gd").initial()))
	health = int(saved.get("health",30))
	player_form = int(saved.get("player_form",0))
	curse.restore(saved.get("curse",Curse.initial()))
	FormBody.apply(player,camera,player_form,false)
	equipped_item = saved.equipped_item
	equipped_armor = saved.get("equipped_armor", "")
	set_development_mode(false)
	player.position = Vector3(state.player.position[0],state.player.position[1],state.player.position[2])
	player.rotation.y = state.player.yaw
	camera.rotation = Vector3(state.player.pitch,0,0)
	player.velocity = Vector3.ZERO
	interface_hud.set_cursor(false)
	interface_hud.refresh_equipment()
	exhibit_retry = {}
	if hourglass.activated and not hourglass.escaped: prepare_legacy_exhibit_retry()

func can_take_mail() -> bool:
	return is_instance_valid(mail_shirt) and mail_shirt.visible and not MAIL_ITEM_ID in carried_collected and can_reach_item(mail_shirt.global_position + Vector3(0,6,0))

func take_mail() -> bool:
	if not can_take_mail(): return false
	carried_collected.append(MAIL_ITEM_ID)
	mail_shirt.hide()
	save_feedback("Mail Shirt added to inventory.")
	return true

func can_take_stone(index: int) -> bool:
	if not is_instance_valid(champion_stones) or index < 0 or index >= champion_stones.sprites.size(): return false
	var sprite: Sprite3D = champion_stones.sprites[index]
	return sprite.visible and not Stones.IDS[index] in carried_collected and can_reach_item(sprite.global_position + Vector3(0,3.5,0))

func take_stone(index: int) -> bool:
	if not can_take_stone(index): return false
	carried_collected.append(Stones.IDS[index])
	champion_stones.sprites[index].hide()
	save_feedback("Champion Stone added to inventory.")
	return true

func set_equipped_armor(item_id: String) -> bool:
	if item_id != "" and ((Catalog.slot(item_id) != "armor" or not Catalog.admitted(item_id,"museum")) or not item_id in carried_collected): return false
	equipped_armor = item_id
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	return true

func can_enter_mirror() -> bool:
	if mirror_transition_pending or get_tree().paused or flying or introduction_state != "complete": return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	return MirrorRoute.in_approach(player.global_position, -camera.global_basis.z)

func enter_mirror() -> bool:
	if not can_enter_mirror(): return false
	if not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready():
		save_feedback("Jungle assets are missing from this build.")
		return true
	var handoff := inventory_state()
	var error := preload("res://scripts/lol2/jungle_save.gd").validate_inventory(handoff)
	if not error.is_empty():
		save_feedback(error)
		return true
	mirror_transition_pending = true
	_finish_jungle_transition.call_deferred(handoff)
	return true

func _finish_jungle_transition(handoff: Dictionary) -> void:
	get_tree().set_meta("lol2_jungle_handoff",handoff)
	# Explicit travel starts at entry1; an old resume request must not override it.
	if get_tree().has_meta("lol2_jungle_resume"): get_tree().remove_meta("lol2_jungle_resume")
	var result := get_tree().change_scene_to_file(MirrorRoute.DESTINATION)
	if result != OK:
		get_tree().remove_meta("lol2_jungle_handoff")
		mirror_transition_pending = false
		save_feedback("Could not enter the jungle.")

func _add_mirror_visual() -> void:
	# Authored readable replacement at source kind16 object82; native effect pending.
	var mirror := MeshInstance3D.new()
	mirror.name = "ShiningPathMirror"
	mirror.position = Vector3(-4058,20,-1584)
	var quad := QuadMesh.new()
	quad.size = Vector2(60,80)
	mirror.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/lol2/museum_mirror.gdshader")
	mirror.material_override = material
	add_child(mirror)

## Authored E interaction in source chamber region1422; original dialogue/door dispatch pending.
## Reuses verified jungle entry1 as restoration arrival; full native inheritance not proven.
func can_enter_dragon() -> bool:
	if mirror_transition_pending or get_tree().paused or flying or introduction_state != "complete": return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	var p := player.global_position
	# Source region1422 slopes from floor0 to -20; capsule center reaches12.
	if p.y < 8 or p.y > 56 or (-camera.global_basis.z).dot(Vector3.FORWARD) < 0.7: return false
	return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array([
		Vector2(3060,-1094),Vector2(3036,-1094),Vector2(2946,-1234),Vector2(3156,-1234)]))

func enter_dragon() -> bool:
	if not can_enter_dragon(): return false
	if not Overlay.story_assets_ready(DRAGON_CLIPS) or not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready():
		save_feedback("Dragon journey assets are missing from this build.")
		return true
	var handoff := inventory_state()
	var error := preload("res://scripts/lol2/jungle_save.gd").validate_inventory(handoff)
	if not error.is_empty():
		save_feedback(error)
		return true
	mirror_transition_pending = true
	dragon_flight = Overlay.new()
	dragon_flight.story_mode = true
	dragon_flight.story_clips = DRAGON_CLIPS.duplicate()
	dragon_flight.story_title = "Dragon journey"
	dragon_flight.ended.connect(func(reason: String):
		if reason in ["finished","skipped"]:
			_finish_jungle_transition.call_deferred(handoff)
		else:
			mirror_transition_pending = false)
	add_child(dragon_flight)
	return true


func inventory_state() -> Dictionary:
	return {"museum_control181":quest_state.get("museum_control181",{"owner_state":0,"sprite_mode":0}).duplicate(true),"collected":carried_collected.duplicate(),"equipped_item":equipped_item,"equipped_armor":equipped_armor,"item_effects":item_effect_checkpoint.duplicate(true),"health":health,"magic":player_magic_checkpoint.duplicate(true),"fighting":fighting_checkpoint.duplicate(true),"player_form":player_form,"curse":curse.snapshot()}

func hold_for_exhibit(id: String) -> bool:
	if id not in carried_collected: return false
	hand_item = "" if hand_item == id else id
	return true

func use_inventory_item(id: String) -> bool:
	var used: bool = item_effects.use(id)
	if used and id not in carried_collected and hand_item == id: hand_item = ""
	return used
