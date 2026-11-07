extends "res://scripts/lol2/museum_review.gd"
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Overlay = preload("res://scripts/lol2/cave_video_overlay.gd")
const INTRO_CLIPS := [4, 5]
const Save = preload("res://scripts/lol2/museum_save.gd")
const CHECKPOINT_KEY := "lol2_museum_checkpoint"
## Cave chamber completion packet (tree meta lol2_cave_completion), checked by the cave before it
## leaves and again on Museum entry. Version1 requires every top-level player field; the live sender
## also requires the version marker. Unversioned legacy packets retain their optional-field behavior.
## Existing field validators still own item, magic, fighting and curse semantics.
const CAVE_TRANSFER_VERSION := 1
const CAVE_TRANSFER_FIELDS := ["collected","equipped_item","equipped_armor","item_effects","health","player_form","curse","magic","fighting","chamber_complete"]
static func validate_cave_transfer(state: Variant, require_current: bool = false) -> String:
	if not state is Dictionary: return "Invalid cave completion."
	if require_current and not state.has("cave_transfer_version"): return "Missing cave transfer version."
	if state.has("cave_transfer_version"):
		var version = state.cave_transfer_version
		if not (version is int or version is float) or not is_finite(float(version)) or version != CAVE_TRANSFER_VERSION: return "Unsupported cave transfer version."
		for field in CAVE_TRANSFER_FIELDS:
			if not state.has(field): return "Missing cave transfer field: " + field
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
const Draracle = preload("res://scripts/lol2/museum_draracle.gd")
var draracle_source: Dictionary = Draracle.source()
## Source local19 (region1220 pedestal videos played) and whether the player already stands in region1220.
var draracle_local19 := 0
var draracle_inside := false
const DraracleBars = preload("res://scripts/lol2/museum_draracle_bars.gd")
var draracle_bars: Node3D
const Curtain = preload("res://scripts/lol2/museum_curtain.gd")
var curtain: Node3D
const WheelDoor = preload("res://scripts/lol2/museum_wheel_door.gd")
var wheel_door: Node3D
const TinyEnclosure = preload("res://scripts/lol2/museum_tiny_enclosure.gd")
var tiny_enclosure: Node
const SWORD_ITEM_ID := "museum:item11:Fine_Longsword"
var carried_collected: Array = []
var quest_state: Dictionary = {}
## Explored atlas regions. Not quest progress. Saved beside the checkpoint.
var atlas_explored = null
var hand_item := ""
var broken_case: Node3D
var broken_thohan: Node3D
const MAIL_ITEM_ID := "museum:item10:Mail_Shirt"
const Stones = preload("res://scripts/lol2/museum_stones.gd")
var champion_stones: Node3D
var lightning_crystal: Node3D
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
var static_assemblies: Node3D
var ivory: Node3D
var empty_urns: Node3D
var worm: Node3D
var belial: Node3D
var dragon_heart: Node3D
var prism: Node3D
var blood_loot: Node3D
var skeleton_population: Node3D
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var player_form := 0
## Native bit0 region blockers (on; tests may switch them off before the scene enters the tree).
## Off by default (lead, r12r 2026-10-30): the native bit0 blockers ignore regions the original opens by script (the Museum escape run crosses region 1422), so outside the Jungle they wait until dynamic unblocking is hosted.
var region_blockers_enabled := true  ## native bit0 blockers ON (lead 2026-10-31 blockers-on; r12w: back ON with fable 312efd9 portal-corner chamfer); region 1422 is open in the pack (--open-regions 1422, DEVIATIONS)
var region_blockers_attached := 0
const Curse = preload("res://scripts/lol2/player_curse.gd")
var curse := Curse.new()
var inventory: CanvasLayer
var interface_hud: CanvasLayer
const MirrorRoute = preload("res://scripts/lol2/museum_mirror_route.gd")
## Starts true so a player placed inside the corridor mouth (a load) does not travel until they step in again.
var mirror_was_inside := true
var mirror_last_position := Vector3.INF
var mirror_transition_pending := false
var exhibit_retry: Dictionary = {}
var failure_overlay: CanvasLayer
var dragon_door: AnimatableBody3D
var gallery: Node3D
var key_locks: Node3D
var aloe_pickups: Node3D
var world_items: Node3D
var liquid_drowning: Node
var scroll_pickups: Node3D
var crystal_pickups: Node3D
var orb_switch: Node3D
var museum_torches: Node3D
var long_arm: Node3D
const LongArm = preload("res://scripts/lol2/museum_long_arm.gd")
const LongArmState = preload("res://scripts/lol2/museum_long_arm_state.gd")
const KeyLocks = preload("res://scripts/lol2/museum_key_locks.gd")
const KeyLockState = preload("res://scripts/lol2/museum_key_locks_state.gd")
const OrbSwitch = preload("res://scripts/lol2/museum_orb_switch.gd")
const Torches = preload("res://scripts/lol2/museum_torches.gd")
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
	if get_tree().has_meta("lol2_cave_completion"): preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "arrival Cave->Museum", transfer_error)
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
		draracle_local19 = Draracle.restore(checkpoint.get("museum_draracle"))
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
	if preload("res://scripts/lol2/museum_lightning_crystal.gd").assets_ready():
		lightning_crystal = preload("res://scripts/lol2/museum_lightning_crystal.gd").new()
		add_child(lightning_crystal)
		lightning_crystal.setup(self)
		lightning_crystal.restore_collected(carried_collected+item_effect_checkpoint.spent)
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
		prism=preload("res://scripts/lol2/museum_prism.gd").new();add_child(prism)
		prism.setup(self,checkpoint.get("museum_prism",false) if checkpoint is Dictionary else false)
	if preload("res://scripts/lol2/museum_control96.gd").assets_ready():
		control96=preload("res://scripts/lol2/museum_control96.gd").new()
		control96.name="MuseumControl96"
		add_child(control96)
		var control_error: String=control96.setup(self,checkpoint.get("museum_control96") if checkpoint is Dictionary else null)
		if not control_error.is_empty(): push_error(control_error)
	if preload("res://scripts/lol2/museum_rubble_blocks.gd").assets_ready():
		add_child(preload("res://scripts/lol2/museum_rubble_blocks.gd").new())
	if preload("res://scripts/lol2/static_assemblies.gd").assets_ready("L3_DH"):
		static_assemblies=preload("res://scripts/lol2/static_assemblies.gd").new();add_child(static_assemblies)
		var assemblies_error: String=static_assemblies.setup(self,"L3_DH",[],[77])
		if not assemblies_error.is_empty(): push_error(assemblies_error)
	# Native player-impassable regions (region bit0, tools/prepare_region_blockers.py), as in the Jungle (L3_DH: 493 regions).
	if region_blockers_enabled: region_blockers_attached=preload("res://scripts/lol2/region_blockers.gd").attach(self,player,"L3_DH")
	if preload("res://scripts/lol2/museum_ivory.gd").assets_ready():
		ivory = preload("res://scripts/lol2/museum_ivory.gd").new()
		add_child(ivory)
		var ivory_error: String = ivory.setup(self, checkpoint.get("museum_ivory") if checkpoint is Dictionary else null)
		if not ivory_error.is_empty(): push_error(ivory_error)
	if checkpoint is Dictionary: restore_escape_wall(checkpoint)
	belial = preload("res://scripts/lol2/museum_belial.gd").new()
	add_child(belial)
	var belial_error: String = belial.setup(self,checkpoint.get("museum_belial") if checkpoint is Dictionary else null)
	if not belial_error.is_empty(): push_error(belial_error)
	dragon_heart = preload("res://scripts/lol2/museum_dragon_heart.gd").new()
	add_child(dragon_heart)
	var heart_error: String = dragon_heart.setup(self,checkpoint.get("museum_dragon_heart") if checkpoint is Dictionary else null)
	if not heart_error.is_empty(): push_error(heart_error)
	worm = preload("res://scripts/lol2/museum_worm.gd").new()
	add_child(worm)
	var worm_error: String = worm.setup(self, checkpoint.get("museum_worm") if checkpoint is Dictionary else null)
	if not worm_error.is_empty(): push_error(worm_error)
	empty_urns = preload("res://scripts/lol2/museum_empty_urns.gd").new()
	add_child(empty_urns)
	var urn_error: String = empty_urns.setup(self, checkpoint.get("museum_empty_urns") if checkpoint is Dictionary else null)
	if not urn_error.is_empty(): push_error(urn_error)
	gallery = preload("res://scripts/lol2/museum_gallery.gd").new()
	add_child(gallery)
	if checkpoint is Dictionary: gallery.restore_checkpoint(checkpoint.get("gallery", {}))
	if KeyLocks.assets_ready():
		key_locks = KeyLocks.new()
		add_child(key_locks)
		var lock_error: String = key_locks.setup(self, checkpoint.get("museum_key_locks") if checkpoint is Dictionary else null)
		if not lock_error.is_empty(): push_error(lock_error)
	if preload("res://scripts/lol2/museum_crystal.gd").assets_ready():
		crystal_pickups=preload("res://scripts/lol2/museum_crystal.gd").new()
		add_child(crystal_pickups)
		var crystal_error:String=crystal_pickups.setup(self, checkpoint.get("museum_crystal") if checkpoint is Dictionary else null)
		if not crystal_error.is_empty():push_error(crystal_error)
	if preload("res://scripts/lol2/museum_aloe.gd").assets_ready():
		aloe_pickups=preload("res://scripts/lol2/museum_aloe.gd").new()
		add_child(aloe_pickups)
		var aloe_error: String=aloe_pickups.setup(self,checkpoint.get("museum_aloe") if checkpoint is Dictionary else null)
		if not aloe_error.is_empty(): push_error(aloe_error)
	# Original row 0 (Cocos Cap, area_world_items_state.gd), taken through the plain-item E chain like the aloe.
	if preload("res://scripts/lol2/area_world_items.gd").assets_ready("museum"):
		world_items=preload("res://scripts/lol2/area_world_items.gd").new()
		world_items.handles_input=false
		add_child(world_items)
		var world_items_error: String=world_items.setup(self,"museum")
		if world_items_error.is_empty(): world_items_error=world_items.restore_checkpoint(checkpoint.get("museum_world_items") if checkpoint is Dictionary else null)
		if not world_items_error.is_empty(): push_error(world_items_error)
	# Drowning in the Museum pool (liquid_drowning.gd, owner 2026-10-31: the Lizard drowns in water everywhere).
	if preload("res://scripts/lol2/liquid_drowning.gd").assets_ready("L3_DH"):
		liquid_drowning=preload("res://scripts/lol2/liquid_drowning.gd").new()
		add_child(liquid_drowning)
		var liquid_error: String=liquid_drowning.setup(self,"L3_DH")
		if not liquid_error.is_empty(): push_warning(liquid_error)
	if preload("res://scripts/lol2/museum_scrolls.gd").assets_ready():
		scroll_pickups=preload("res://scripts/lol2/museum_scrolls.gd").new()
		add_child(scroll_pickups)
		var scroll_error: String=scroll_pickups.setup(self,checkpoint.get("museum_scrolls") if checkpoint is Dictionary else null)
		if not scroll_error.is_empty(): push_error(scroll_error)
	if OrbSwitch.assets_ready():
		orb_switch = OrbSwitch.new()
		add_child(orb_switch)
		var orb_error: String = orb_switch.setup(self, checkpoint.get("museum_orb_switch") if checkpoint is Dictionary else null)
		if not orb_error.is_empty(): push_error(orb_error)
	if Torches.assets_ready():
		museum_torches = Torches.new()
		add_child(museum_torches)
		var torch_error: String = museum_torches.setup(self, checkpoint.get("museum_torches") if checkpoint is Dictionary else null)
		if not torch_error.is_empty(): push_error(torch_error)
	if LongArm.assets_ready():
		long_arm = LongArm.new()
		add_child(long_arm)
		var arm_error: String = long_arm.setup(self, checkpoint.get("museum_long_arm") if checkpoint is Dictionary else null)
		if not arm_error.is_empty(): push_error(arm_error)
	if DraracleBars.assets_ready():
		draracle_bars = DraracleBars.new()
		add_child(draracle_bars)
		var bars_error: String = draracle_bars.setup(self, checkpoint.get("museum_draracle_bars") if checkpoint is Dictionary else null)
		if not bars_error.is_empty(): push_error(bars_error)
	if TinyEnclosure.assets_ready():
		tiny_enclosure = TinyEnclosure.new()
		add_child(tiny_enclosure)
		var enclosure_error: String = tiny_enclosure.setup(self)
		if not enclosure_error.is_empty(): push_error(enclosure_error)
	if Curtain.assets_ready():
		curtain = Curtain.new()
		add_child(curtain)
		var curtain_error: String = curtain.setup(self, checkpoint.get("museum_curtain") if checkpoint is Dictionary else null)
		if not curtain_error.is_empty(): push_error(curtain_error)
	if WheelDoor.assets_ready():
		wheel_door = WheelDoor.new()
		add_child(wheel_door)
		var wheel_error: String = wheel_door.setup(self, checkpoint.get("museum_wheel_door") if checkpoint is Dictionary else null)
		if not wheel_error.is_empty(): push_error(wheel_error)
	dragon_door = preload("res://scripts/lol2/museum_dragon_door.gd").new()
	add_child(dragon_door)
	if checkpoint is Dictionary: dragon_door.restore_checkpoint(checkpoint.get("dragon_door", {}))
	get_window().title = "Lands of Lore II — Draracle’s museum"
	if get_tree().has_meta("lol2_museum_resume"):
		var resume = get_tree().get_meta("lol2_museum_resume")
		get_tree().remove_meta("lol2_museum_resume")
		if Save.validate(resume).is_empty(): apply_save(resume)
	# Source arrival: control returns at once; the Draracle clips belong to region1220 (start_introduction()).
	introduction_state = "complete"
	draracle_inside = Draracle.inside(draracle_source, player.position, player.position.y - FormBody.FOOT_OFFSET)
	if is_instance_valid(draracle_bars): draracle_bars.sync_inside(player.position, player.position.y - FormBody.FOOT_OFFSET, player.is_on_floor())

## Lock78's passage faces (regions1237/1477 closed floors and walls) are built by the key-lock owner.
## The Prism owner draws the seven panorama source walls (shown until the pickup clears them to transparent 871);
## the static pass keeps their collision. Same assets gate as the owner's construction in _ready.
var prism_wall_records = null
func render_owned_face(face: Dictionary) -> bool:
	if prism_wall_records == null:
		prism_wall_records = {}
		if preload("res://scripts/lol2/museum_skeleton_population.gd").assets_ready():
			prism_wall_records = preload("res://scripts/lol2/museum_prism.gd").panel_wall_records()
	return str(face.get("kind", "")) == "source_wall" and prism_wall_records.has(int(face.get("wall_record", -1)))

func excluded_faces() -> Dictionary:
	var result := {}
	if KeyLocks.assets_ready():
		for index in KeyLocks.passage_data().closed_face_indices: result[int(index)] = true
	# Prop153's floor trap regions are built by the Long arm owner.
	if LongArm.assets_ready():
		for index in LongArm.floor_data().closed_face_indices: result[int(index)] = true
	# Movable65 owns region1249's lowered floor (face 3307) and raises it to y=30.
	if OrbSwitch.assets_ready(): result[OrbSwitch.pit_face()] = true
	return result

## Region1220 entry (source g1486/g1522): the clip for local19, then op198 local19 and the op18 return pose.
## An interrupted clip leaves local19 unchanged; the next entry plays it again.
func start_introduction() -> bool:
	if introduction_state != "complete" or is_instance_valid(introduction): return false
	if not Draracle.inside(draracle_source, player.position, player.position.y - FormBody.FOOT_OFFSET): return false
	var step := Draracle.step(draracle_source, draracle_local19)
	if step.is_empty() or not Overlay.story_assets_ready([int(step.clip)]): return false
	introduction_state = "playing"
	introduction = Overlay.new()
	introduction.story_mode = true
	introduction.story_clips = [int(step.clip)]
	introduction.story_title = "Draracle’s museum"
	introduction.ended.connect(func(reason: String):
		if reason in ["finished", "skipped"]:
			draracle_local19 = int(step.next_local19)
			var pose: Dictionary = step.return_pose
			player.position = Vector3(float(pose.position[0]), start.y, float(pose.position[1]))
			player.rotation = Vector3(0, float(pose.yaw), 0)
			camera.rotation = Vector3.ZERO
			player.velocity = Vector3.ZERO
			draracle_inside = false
		introduction_state = "complete")
	add_child(introduction)
	return true

func check_draracle_entry() -> void:
	if get_tree().paused or flying or introduction_state != "complete" or not player.is_on_floor(): return
	var now := Draracle.inside(draracle_source, player.position, player.position.y - FormBody.FOOT_OFFSET)
	var entered := now and not draracle_inside
	draracle_inside = now
	if entered: start_introduction()

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
		"museum_draracle": {"local19": draracle_local19},
		"museum_draracle_bars": draracle_bars.checkpoint() if is_instance_valid(draracle_bars) else DraracleBars.initial(DraracleBars.source()),
		"museum_curtain": curtain.checkpoint() if is_instance_valid(curtain) else Curtain.initial(),
		"museum_wheel_door": wheel_door.checkpoint() if is_instance_valid(wheel_door) else WheelDoor.initial(),
		"sword": sword_transfer.checkpoint(),
		"gate": museum_gate.checkpoint(),
		"collected": carried_collected.duplicate(),
		"equipped_item": equipped_item,
		"equipped_armor": equipped_armor,
		"hourglass": hourglass.checkpoint() if is_instance_valid(hourglass) else {},
		"escape_wall": escape_wall.checkpoint() if is_instance_valid(escape_wall) else {},
		"gallery": gallery.checkpoint() if is_instance_valid(gallery) else {},
		"museum_key_locks": key_locks.checkpoint() if is_instance_valid(key_locks) else KeyLockState.initial(),
		"museum_orb_switch": orb_switch.checkpoint() if is_instance_valid(orb_switch) else OrbSwitch.initial(),
		"museum_torches": museum_torches.checkpoint() if is_instance_valid(museum_torches) else Torches.initial(),
		"museum_aloe":aloe_pickups.checkpoint() if is_instance_valid(aloe_pickups) else preload("res://scripts/lol2/museum_aloe_state.gd").initial(),
		"museum_world_items":world_items.checkpoint() if is_instance_valid(world_items) else preload("res://scripts/lol2/area_world_items_state.gd").initial(),
		"museum_scrolls":scroll_pickups.checkpoint() if is_instance_valid(scroll_pickups) else preload("res://scripts/lol2/museum_scroll_state.gd").initial(),
		"museum_crystal":crystal_pickups.checkpoint() if is_instance_valid(crystal_pickups) else preload("res://scripts/lol2/museum_crystal_state.gd").initial(),
		"museum_long_arm": long_arm.checkpoint() if is_instance_valid(long_arm) else LongArmState.initial(),
		"museum_belial": belial.checkpoint(),
		"museum_dragon_heart": dragon_heart.checkpoint(),
		"museum_worm": worm.checkpoint(),
		"museum_empty_urns": empty_urns.checkpoint(),
		"museum_ivory": ivory.checkpoint() if is_instance_valid(ivory) else preload("res://scripts/lol2/museum_ivory_state.gd").initial(),
		"museum_prism": prism.checkpoint() if is_instance_valid(prism) else false,
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
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Aimed E pickup of a Y-billboard sprite: the view centre lies on the sprite's drawn rectangle (the original picks
## any pixel of the item with the cursor), or the centre cone of can_reach_item meets the given anchor. Tall or
## raised sprites (Prism, Long arm altar) otherwise need the view tilted onto their centre, with no hint on the hilt.
func can_reach_sprite(sprite: Sprite3D, anchor: Vector3) -> bool:
	if can_reach_item(anchor): return true
	if get_tree().paused or not is_instance_valid(sprite) or not sprite.visible or sprite.texture == null: return false
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z
	var normal: Vector3 = origin - sprite.global_position; normal.y = 0
	if normal.length() < 0.01: return false
	normal = normal.normalized()
	var point = Plane(normal, normal.dot(sprite.global_position)).intersects_ray(origin, direction)
	if point == null or origin.distance_to(point) > 96: return false
	var offset: Vector3 = point - sprite.global_position
	var right := Vector3(normal.z, 0, -normal.x)
	# No crosshair is drawn, so allow 4 degrees around the drawn rectangle.
	var margin: float = origin.distance_to(point) * tan(deg_to_rad(4.0))
	var half_width: float = sprite.texture.get_width() * sprite.pixel_size / 2.0 + margin
	var half_height: float = sprite.texture.get_height() * sprite.pixel_size / 2.0 + margin
	if absf(offset.dot(right)) > half_width or absf(offset.y) > half_height: return false
	var query := PhysicsRayQueryParameters3D.create(origin, point, preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
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

## Original L3_DH prop226 kind9 record4620 (masks0x19FF/any, threshold1/mode4) and control97 kind9 records
## (masks0x0106/0x0004) accept melee hits from any weapon; neither checks for the Fine Longsword. Admission mirrors
## the ivory urns' human rule: any equipped carried weapon (playtest 2026-10-17, report11-22-24). Cursed forms
## keep their existing refusal here.
func melee_ready() -> bool:
	if not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(player_form): return false
	return equipped_item in carried_collected and Catalog.slot(equipped_item) == "weapon"

func hourglass_in_reach() -> bool:
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(hourglass) or hourglass.activated: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	# Any aimed point on the visible hourglass within item reach (same rule as the escape wall face).
	var forward := -camera.global_basis.z
	var distance: float = hourglass.face_hit_distance(camera.global_position, forward)
	if distance < 0 or distance > 96: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * maxf(0, distance - 3), preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Hourglass hint when melee is refused: equip a carried weapon, or say that one is needed.
func hourglass_weapon_hint() -> String:
	if not preload("res://scripts/lol2/player_form_rules.gd").can_use_weapon(player_form):
		return "You cannot wield a weapon in this form"
	for id in carried_collected:
		if Catalog.slot(id) == "weapon" and Catalog.admitted(id,"museum"):
			return "Open the inventory (I) and equip your %s to strike the hourglass" % Catalog.entry(id).get("label","weapon")
	return "You need a weapon to strike the hourglass"

func can_strike_hourglass() -> bool:
	return melee_ready() and hourglass_in_reach()

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
	if not melee_ready(): return false
	if get_tree().paused or flying or introduction_state != "complete" or mirror_transition_pending: return false
	if not is_instance_valid(escape_wall) or escape_wall.stage < 1 or escape_wall.stage >= 4: return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	# Aim at any point of the damaged face within item reach; the old centre-point cone (14 deg around a point
	# 18 above eye height) refused a player looking straight at the wall from closer than ~72 units.
	var forward := -camera.global_basis.z
	var distance: float = escape_wall.face_hit_distance(camera.global_position, forward)
	if distance < 0 or distance > 96: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * maxf(0, distance - 3), preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude = [player.get_rid(), escape_wall.barrier.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

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
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and is_instance_valid(prism) and prism.use_pointer(event.position):
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and click_dragon(_pointer_pixel() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else event.position):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if (is_instance_valid(crystal_pickups) and crystal_pickups.strike()) or (is_instance_valid(ivory) and ivory.strike()) or (is_instance_valid(empty_urns) and empty_urns.strike()) or strike_hourglass() or strike_escape_wall() or (is_instance_valid(museum_torches) and museum_torches.strike_pilot()) or strike_sword_skeleton():
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if open_inventory(): get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _use_world() or _use_world_with_hand_stowed() or (is_instance_valid(key_locks) and key_locks.use_from_pack()): get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

## Every E action in priority order; actions that need the held item run first, with the hand as it is.
func _use_world() -> bool:
	return (is_instance_valid(ivory) and ivory.use()) or (introduction_state == "complete" and broken_thohan.use()) or (is_instance_valid(key_locks) and key_locks.use()) or (is_instance_valid(orb_switch) and orb_switch.use()) or (is_instance_valid(museum_torches) and museum_torches.use()) or (is_instance_valid(crystal_pickups) and crystal_pickups.use()) or (is_instance_valid(aloe_pickups) and aloe_pickups.use()) or (is_instance_valid(scroll_pickups) and scroll_pickups.use()) or (is_instance_valid(world_items) and world_items.use()) or (is_instance_valid(long_arm) and long_arm.use()) or (is_instance_valid(belial) and belial.use()) or (is_instance_valid(dragon_heart) and dragon_heart.use()) or (is_instance_valid(prism) and prism.use()) or (is_instance_valid(blood_loot) and blood_loot.use()) or (is_instance_valid(skeleton_population) and skeleton_population.use_control()) or (is_instance_valid(draracle_bars) and draracle_bars.use_control()) or (is_instance_valid(wheel_door) and wheel_door.use()) or (is_instance_valid(curtain) and curtain.use()) or open_dragon_door() or use_gallery() or enter_dragon() or enter_mirror() or take_sword() or take_mail() or take_stone(0) or take_stone(1) or (is_instance_valid(lightning_crystal) and lightning_crystal.use())

## Plain item grants and route doors that require an empty hand. Actions with other empty-hand outcomes (sconce burns,
## skeleton controls) are deliberately excluded so a held item never triggers them. The curtain and wheel door
## were added after the owner's r5 report 2026-10-20 (Stalagmite in hand, curtain silently refused); a revealed ivory
## chip and taking the Sk key back out of a lock after the r10 report 2026-10-23 (the chip was seen but E did nothing;
## "can't take back the key" with SS1 in hand). A lock insert from the pack is key_locks.use_from_pack (r12h 2026-10-26).
func _take_plain_item() -> bool:
	return (is_instance_valid(dragon_heart) and dragon_heart.use()) or (is_instance_valid(ivory) and ivory.use()) or (is_instance_valid(key_locks) and key_locks.use_take()) or (is_instance_valid(aloe_pickups) and aloe_pickups.use()) or (is_instance_valid(scroll_pickups) and scroll_pickups.use()) or (is_instance_valid(world_items) and world_items.use()) or (is_instance_valid(long_arm) and long_arm.use()) or (is_instance_valid(prism) and prism.use()) or take_sword() or take_mail() or take_stone(0) or take_stone(1) or (is_instance_valid(lightning_crystal) and lightning_crystal.use()) or (is_instance_valid(wheel_door) and wheel_door.use()) or (is_instance_valid(curtain) and curtain.use())

## Modern adapter (owner r3 report 2026-10-20): the plain pickups (Prism group6590, Long arm, Fine Longsword...)
## require an empty hand, and a carried item left in the hand silently refused them. When no action uses the held
## item, E retries those pickups with that item put back into the pack; it stays carried, only the hand is cleared.
func _use_world_with_hand_stowed() -> bool:
	var held := hand_item
	if held == "" or not held in carried_collected: return false
	hand_item = ""
	if _take_plain_item():
		if hand_item == "" and pickup_notice_time <= 0: save_feedback(_stowed_label(held) + " put away.")
		return true
	hand_item = held
	return false

func _stowed_label(id: String) -> String:
	var text := Catalog.label(id)
	return text if text != "" else id.get_slice(":", id.get_slice_count(":") - 1).replace("_", " ")

func _physics_process(delta: float) -> void:
	# Move the plate before the player step so a standing capsule can be carried.
	if is_instance_valid(orb_switch):
		orb_switch.step_motion(delta)
	super._physics_process(delta)
	check_exhibit_escape()
	check_draracle_entry()
	check_mirror_entry()
	if is_instance_valid(draracle_bars) and not get_tree().paused and not flying:
		draracle_bars.step(delta, player.position, player.position.y - FormBody.FOOT_OFFSET, player.is_on_floor())
	if is_instance_valid(curtain) and not get_tree().paused: curtain.step(delta)
	if is_instance_valid(wheel_door) and not get_tree().paused: wheel_door.step(delta)
	if not is_instance_valid(interaction_label): return
	pickup_notice_time = maxf(0, pickup_notice_time - delta)
	if pickup_notice_time > 0: return
	_show_world_hint()
	var held := hand_item
	if interaction_label.visible or held == "" or not held in carried_collected: return
	hand_item = ""
	var text := _plain_item_hint()
	hand_item = held
	if text.is_empty(): return
	interaction_label.text = text + (" (puts away " + _stowed_label(held) + ")" if text.begins_with("E — ") else "")
	interaction_label.show()

func _plain_item_hint() -> String:
	for owner in [aloe_pickups, scroll_pickups, world_items, ivory, key_locks, long_arm, prism, lightning_crystal, wheel_door, curtain]:
		if is_instance_valid(owner):
			var text: String = owner.take_hint() if owner == key_locks else owner.interaction_hint()
			if not text.is_empty(): return text
	if can_take_sword(): return "E — Take Fine Longsword"
	if can_take_mail(): return "E — Take Mail Shirt"
	if can_take_stone(0) or can_take_stone(1): return "E — Take Champion Stone"
	return ""

func _show_world_hint() -> void:
	var aloe_hint: String=aloe_pickups.interaction_hint() if is_instance_valid(aloe_pickups) else ""
	if not aloe_hint.is_empty():
		interaction_label.text=aloe_hint
		interaction_label.show()
		return
	var scroll_hint: String=scroll_pickups.interaction_hint() if is_instance_valid(scroll_pickups) else ""
	if not scroll_hint.is_empty():
		interaction_label.text=scroll_hint
		interaction_label.show()
		return
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
	var orb_hint: String = orb_switch.interaction_hint() if is_instance_valid(orb_switch) else ""
	if not orb_hint.is_empty():
		interaction_label.text = orb_hint
		interaction_label.show()
		return
	var torch_hint: String = museum_torches.interaction_hint() if is_instance_valid(museum_torches) else ""
	if not torch_hint.is_empty():
		interaction_label.text = torch_hint
		interaction_label.show()
		return
	var admit_hint: String = key_locks.admission_hint() if is_instance_valid(key_locks) else ""
	if not admit_hint.is_empty():
		interaction_label.text = admit_hint
		interaction_label.show()
		return
	var arm_hint: String = long_arm.interaction_hint() if is_instance_valid(long_arm) else ""
	if not arm_hint.is_empty():
		interaction_label.text = arm_hint
		interaction_label.show()
		return
	var ivory_hint: String = ivory.interaction_hint() if is_instance_valid(ivory) else ""
	if not ivory_hint.is_empty():
		interaction_label.text=ivory_hint;interaction_label.show();return
	var belial_hint: String = belial.interaction_hint() if is_instance_valid(belial) else ""
	if not belial_hint.is_empty():
		interaction_label.text=belial_hint;interaction_label.show();return
	var heart_hint: String = dragon_heart.interaction_hint() if is_instance_valid(dragon_heart) else ""
	if not heart_hint.is_empty():
		interaction_label.text=heart_hint;interaction_label.show();return
	var prism_hint: String=prism.interaction_hint() if is_instance_valid(prism) else ""
	if not prism_hint.is_empty():
		interaction_label.text=prism_hint;interaction_label.show();return
	var blood_hint: String=blood_loot.interaction_hint() if is_instance_valid(blood_loot) else ""
	if not blood_hint.is_empty():
		interaction_label.text=blood_hint;interaction_label.show();return
	var crystal_hint: String = lightning_crystal.interaction_hint() if is_instance_valid(lightning_crystal) else ""
	if not crystal_hint.is_empty():
		interaction_label.text=crystal_hint;interaction_label.show();return
	for door in [wheel_door, curtain]:
		var door_hint: String = door.interaction_hint() if is_instance_valid(door) else ""
		if not door_hint.is_empty():
			interaction_label.text = door_hint
			interaction_label.show()
			return
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
	if hourglass_in_reach():
		interaction_label.text = hourglass_weapon_hint()
		interaction_label.show()
		return
	if dragon_picture_target(_pointer_pixel()):
		interaction_label.text = "Click the dragon — Travel with the dragon"
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

## Shared curse hook (player_curse.advance): Long arm chute keeps the tiny form (docs/museum-tiny-enclosure.md).
func form_change_blocked(target: int) -> bool:
	return is_instance_valid(tiny_enclosure) and tiny_enclosure.blocks(target)

func form_change_unchecked(target: int) -> bool:
	return is_instance_valid(tiny_enclosure) and tiny_enclosure.shrinks_in_place(target)

func save_feedback(message: String) -> void:
	pickup_notice_time = 4.0
	interaction_label.text = message
	interaction_label.show()

## Diagnostics record every outcome, including early refusals that show no message (docs/dev-diagnostics.md).
func quicksave(path: String = Save.DEFAULT_PATH) -> String: return preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "save", _quicksave_unrecorded(path))
func quickload(path: String = Save.DEFAULT_PATH) -> String: return preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "load", _quickload_unrecorded(path))
func _quicksave_unrecorded(path: String = Save.DEFAULT_PATH) -> String:
	if introduction_state != "complete" or get_tree().paused: return "Close the current overlay before saving."
	if flying:
		save_feedback("Return to walking mode before saving.")
		return "Return to walking mode before saving."
	var state := {"format": Save.FORMAT, "version": 1, "checkpoint": checkpoint_state(),
		"atlas_explored": preload("res://scripts/lol2/atlas_explored.gd").stored(self),
		"player": {"position": [player.position.x,player.position.y,player.position.z],
		"yaw": wrapf(player.rotation.y,-PI,PI), "pitch": camera.rotation.x}}
	var error := Save.write_save(path,state)
	save_feedback("Museum saved." if error.is_empty() else "Save failed: " + error)
	return error

func _quickload_unrecorded(path: String = Save.DEFAULT_PATH) -> String:
	if get_tree().paused: return "Close the current overlay before loading."
	var result := Save.read_save(path)
	if not result.error.is_empty():
		save_feedback("Load failed: " + result.error)
		return result.error
	apply_save(result.state)
	save_feedback("Museum save loaded.")
	return ""

func apply_save(state: Dictionary) -> void:
	atlas_explored = preload("res://scripts/lol2/atlas_explored.gd").taken(state, preload("res://scripts/lol2/atlas_explored.gd").area_of(self))
	var saved: Dictionary = state.checkpoint
	introduction_state = "complete"
	draracle_local19 = Draracle.restore(saved.get("museum_draracle"))
	if is_instance_valid(draracle_bars):
		var bars_error: String = draracle_bars.restore(saved.get("museum_draracle_bars"))
		if not bars_error.is_empty(): push_error(bars_error)
	if is_instance_valid(curtain):
		var curtain_error: String = curtain.restore(saved.get("museum_curtain"))
		if not curtain_error.is_empty(): push_error(curtain_error)
	if is_instance_valid(wheel_door):
		var wheel_error: String = wheel_door.restore(saved.get("museum_wheel_door"))
		if not wheel_error.is_empty(): push_error(wheel_error)
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
	if is_instance_valid(aloe_pickups):
		var aloe_load_error: String=aloe_pickups.restore_checkpoint(saved.get("museum_aloe"))
		if not aloe_load_error.is_empty(): push_error(aloe_load_error)
	if is_instance_valid(world_items):
		var world_items_load_error: String=world_items.restore_checkpoint(saved.get("museum_world_items"))
		if not world_items_load_error.is_empty(): push_error(world_items_load_error)
	if is_instance_valid(scroll_pickups):
		var scroll_load_error: String=scroll_pickups.restore_checkpoint(saved.get("museum_scrolls"))
		if not scroll_load_error.is_empty(): push_error(scroll_load_error)
	if is_instance_valid(crystal_pickups):
		var crystal_load_error:String=crystal_pickups.restore_checkpoint(saved.get("museum_crystal"))
		if not crystal_load_error.is_empty():push_error(crystal_load_error)
	if is_instance_valid(orb_switch):
		var orb_load_error: String = orb_switch.restore_checkpoint(saved.get("museum_orb_switch"))
		if not orb_load_error.is_empty(): push_error(orb_load_error)
	if is_instance_valid(museum_torches):
		var torch_load_error: String = museum_torches.restore_checkpoint(saved.get("museum_torches"))
		if not torch_load_error.is_empty(): push_error(torch_load_error)
	if is_instance_valid(long_arm):
		var arm_error: String = long_arm.restore_checkpoint(saved.get("museum_long_arm",LongArmState.initial()))
		if not arm_error.is_empty(): push_error(arm_error)
	if is_instance_valid(belial):
		var belial_error: String = belial.restore(saved.get("museum_belial"))
		if not belial_error.is_empty(): save_feedback(belial_error); return
	if is_instance_valid(dragon_heart):
		var heart_error: String = dragon_heart.restore(saved.get("museum_dragon_heart"))
		if not heart_error.is_empty(): push_error(heart_error)
	if is_instance_valid(worm):
		var worm_error: String = worm.restore_checkpoint(saved.get("museum_worm"))
		if not worm_error.is_empty(): push_error(worm_error)
	if is_instance_valid(empty_urns):
		var urn_error: String = empty_urns.restore_checkpoint(saved.get("museum_empty_urns"))
		if not urn_error.is_empty(): push_error(urn_error)
	if is_instance_valid(ivory):
		var ivory_error: String = ivory.restore_checkpoint(saved.get("museum_ivory"))
		if not ivory_error.is_empty(): push_error(ivory_error)
	champion_stones.restore_collected(carried_collected+item_effect_checkpoint.spent)
	if is_instance_valid(lightning_crystal): lightning_crystal.restore_collected(carried_collected+item_effect_checkpoint.spent)
	mail_shirt.visible = not MAIL_ITEM_ID in carried_collected
	player_magic_checkpoint = preload("res://scripts/lol2/player_magic_state.gd").restore(saved.get("magic",preload("res://scripts/lol2/player_magic_state.gd").initial())).checkpoint
	fighting_checkpoint = preload("res://scripts/lol2/player_fighting_transport.gd").restore(saved.get("fighting",{})).get("checkpoint",{})
	if is_instance_valid(skeleton_population): skeleton_population.restore(saved.get("skeletons",preload("res://scripts/lol2/museum_skeleton_population_state.gd").initial()))
	if is_instance_valid(blood_loot):blood_loot.restore(saved.get("museum_blood_loot"))
	if is_instance_valid(prism):prism.restore(saved.get("museum_prism",false))
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
	draracle_inside = Draracle.inside(draracle_source, player.position, player.position.y - FormBody.FOOT_OFFSET)
	if is_instance_valid(draracle_bars): draracle_bars.sync_inside(player.position, player.position.y - FormBody.FOOT_OFFSET, player.is_on_floor())
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

func can_enter_mirror(walk_in := false) -> bool:
	if mirror_transition_pending or get_tree().paused or flying or introduction_state != "complete": return false
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	if walk_in: return MirrorRoute.in_region(player.global_position)
	return MirrorRoute.in_approach(player.global_position, -camera.global_basis.z)

## Native region1419 entry event: stepping into the corridor mouth from outside travels (MirrorRoute). Only a
## crossing made by movement counts (under 32 units since the last physics frame): a load or a placement inside
## the strip waits for a fresh step in.
func check_mirror_entry() -> void:
	var inside := MirrorRoute.in_region(player.global_position)
	var stepped := player.global_position.distance_to(mirror_last_position) < 32.0
	if inside and not mirror_was_inside and stepped: enter_mirror(true)
	mirror_was_inside = inside
	mirror_last_position = player.global_position

func enter_mirror(walk_in := false) -> bool:
	if not can_enter_mirror(walk_in): return false
	if not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready():
		save_feedback("Jungle assets are missing from this build.")
		return true
	var handoff := inventory_state()
	var error := preload("res://scripts/lol2/jungle_save.gd").validate_inventory(handoff)
	# A current departure must carry the whole player state; the Jungle would otherwise start missing fields fresh.
	if error.is_empty(): error = preload("res://scripts/lol2/player_handoff_contract.gd").missing_error(handoff)
	if not error.is_empty():
		save_feedback(error)
		preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "transfer Museum->Jungle", error)
		return true
	mirror_transition_pending = true
	_finish_jungle_transition.call_deferred(handoff)
	return true

func _finish_jungle_transition(handoff: Dictionary) -> void:
	get_tree().set_meta("lol2_jungle_handoff",handoff)
	# Explicit travel starts at entry1; an old resume request must not override it.
	if get_tree().has_meta("lol2_jungle_resume"): get_tree().remove_meta("lol2_jungle_resume")
	var result := get_tree().change_scene_to_file(MirrorRoute.DESTINATION)
	preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "transfer Museum->Jungle", "" if result == OK else "Could not enter the jungle.")
	if result != OK:
		get_tree().remove_meta("lol2_jungle_handoff")
		mirror_transition_pending = false
		save_feedback("Could not enter the jungle.")

## Authored E interaction in source chamber region1422; original dialogue/door dispatch pending.
## Reuses verified jungle entry1 as restoration arrival; full native inheritance not proven.
func can_enter_dragon() -> bool:
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return false
	return dragon_lair_ready() and (-camera.global_basis.z).dot(Vector3.FORWARD) >= 0.7

## Player stands in source region1422 in front of the lair picture (source wall 34, region 1425) and may travel.
func dragon_lair_ready() -> bool:
	if mirror_transition_pending or get_tree().paused or flying or introduction_state != "complete": return false
	var p := player.global_position
	# Source region1422 slopes from floor0 to -20; capsule center reaches12.
	if p.y < 8 or p.y > 56: return false
	return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array([
		Vector2(3060,-1094),Vector2(3036,-1094),Vector2(2946,-1234),Vector2(3156,-1234)]))

## Owner F10 2026-11-03 17-16-20 + longplay 31:26-31:40: the lair is a point-and-click picture; clicking the dragon
## starts the flight. Picture = source wall 34 on face x 2946..3156, z -1247.5, y -20..120 (uv 0..1). The dragon outline
## is a modern hotspot traced on that texture (DEVIATIONS: adapter); the chest and the rest of the picture do nothing.
const DRAGON_PICTURE_HOTSPOT := [Vector2(0.0,0.70),Vector2(0.22,0.62),Vector2(0.34,0.46),Vector2(0.36,0.34),Vector2(0.60,0.34),Vector2(0.60,0.56),Vector2(0.68,0.62),Vector2(0.62,0.80),Vector2(0.40,0.82),Vector2(0.0,0.80)]
func dragon_picture_uv(pixel: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	var point = Plane(Vector3.BACK,-1247.5).intersects_ray(origin,direction)
	if point == null or origin.distance_to(point) > 220: return Vector2(-1,-1)
	return Vector2((point.x-2946.0)/210.0,(120.0-point.y)/140.0)

func dragon_picture_target(pixel: Vector2) -> bool:
	if not dragon_lair_ready(): return false
	var uv := dragon_picture_uv(pixel)
	return Geometry2D.is_point_in_polygon(uv,PackedVector2Array(DRAGON_PICTURE_HOTSPOT))

func click_dragon(pixel: Vector2) -> bool:
	if not dragon_picture_target(pixel): return false
	return _start_dragon_journey()

func _pointer_pixel() -> Vector2:
	return get_viewport().get_visible_rect().size*0.5 if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else get_viewport().get_mouse_position()

func enter_dragon() -> bool:
	if not can_enter_dragon(): return false
	return _start_dragon_journey()

func _start_dragon_journey() -> bool:
	if not Overlay.story_assets_ready(DRAGON_CLIPS) or not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready():
		save_feedback("Dragon journey assets are missing from this build.")
		preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "transfer Museum->Jungle", "Dragon journey assets are missing from this build.")
		return true
	var handoff := inventory_state()
	var error := preload("res://scripts/lol2/jungle_save.gd").validate_inventory(handoff)
	# A current departure must carry the whole player state; the Jungle would otherwise start missing fields fresh.
	if error.is_empty(): error = preload("res://scripts/lol2/player_handoff_contract.gd").missing_error(handoff)
	if not error.is_empty():
		save_feedback(error)
		preload("res://scripts/lol2/dev_diagnostics.gd").record(self, "transfer Museum->Jungle", error)
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
