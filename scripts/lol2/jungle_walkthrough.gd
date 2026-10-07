extends "res://scripts/lol2/jungle_review.gd"
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## Playable jungle staging with the human-sized Hive route.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const SWORD_ITEM_ID := "museum:item11:Fine_Longsword"
const MAIL_ITEM_ID := "museum:item10:Mail_Shirt"
@export var huline_content := true
@export var area_name := "Huline Jungle"
@export var area_save_path := Save.DEFAULT_PATH
@export var area_save_format := Save.FORMAT
var departure: CanvasLayer
var exit_encounter: Node3D
var bacatta: Node3D
var exit_woman: Node3D
var kelsrick: Node3D
var dawn: Node3D
var actor62: Node3D
var bacatta65: Node3D
var bacatta57: Node3D
## Item held on the cursor for an E-use offer (Kelsrick kind4 mode1); not consumed unless a source effect does.
var hand_item := ""
var quest_state: Dictionary = Save.Quests.initial()
var monastery: CanvasLayer
var magic_shop: CanvasLayer
var source_pickups: Node3D
var world_items: Node3D
var weapon_shop: CanvasLayer
var village_gate: Node3D
var village_dialogue: MeshInstance3D
var followup_gate: Node3D
var followup_dialogue: MeshInstance3D
var carried_collected: Array = []
var equipped_item := ""
var health := 30
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var player_form := 0
const Curse = preload("res://scripts/lol2/player_curse.gd")
var curse := Curse.new()
var equipped_armor := ""
var inventory: CanvasLayer
var interface_hud: CanvasLayer

static func assets_ready() -> bool:
	var path := "res://assets/lol2/generated/"
	for asset in ["jungle_source_pickups/pickups.json", "jungle_source_pickups/th_dagger.png", "museum_interface/cursor.png", "museum_interface/portrait.png", "museum_interface/portrait_frame.png",
		"museum_interface/blink_1.png", "museum_interface/blink_2.png", "museum_interface/blink_3.png",
		"museum_sword_transfer/sword.png", "museum_mail/mail.png", "museum_stones/stone.png", "jungle_review/jungle.json"]:
		if not FileAccess.file_exists(path + asset): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path + "jungle_review/jungle.json"))
	if not data is Dictionary or not data.get("faces") is Array or data.faces.is_empty() or not data.get("materials") is Dictionary: return false
	for texture in data.materials.values():
		if not texture is String or not FileAccess.file_exists(path + "jungle_review/" + texture): return false
	for asset in ["jungle_followup/gates.json","jungle_followup_dialogue/conversation.json","jungle_followup_dialogue/section_0.wav","jungle_followup_dialogue/page_0.png","jungle_followup_dialogue/page_6.png"]:
		if not FileAccess.file_exists(path+asset): return false
	for asset in ["act_one_departure/departure.json","act_one_departure/playback.json","act_one_departure/voice.wav"]:
		if not FileAccess.file_exists(path+asset): return false
	var playback = JSON.parse_string(FileAccess.get_file_as_string(path+"act_one_departure/playback.json"))
	if not playback is Dictionary or not playback.get("atlases") is Array: return false
	for atlas in playback.atlases:
		if not atlas is String or not FileAccess.file_exists(atlas): return false
	return preload("res://scripts/lol2/jungle_village_gate.gd").assets_ready() and preload("res://scripts/lol2/jungle_village_dialogue.gd").assets_ready()

var item_effects: Node
var item_effect_checkpoint := preload("res://scripts/lol2/player_item_state.gd").initial()
var starting_magic: Node
var dino_population: Node3D
## Huline villagers on the generic scripted creature owner (docs/jungle-villagers.md).
const VILLAGER_CONFIG:={"root":"res://assets/lol2/generated/jungle_villager_sprites/","source":"res://scripts/lol2/jungle_villager_population_source.json","target_prefix":"junglehuline","fighting_owner":"quest_state","quest_key":"jungle_villagers","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"1":"Huline","2":"Huline","3":"Huline cub"},
	"look":{"1":{"canvas":[320,240],"scale":0.47,"floor_row":206,"radius":15,"height":46},"2":{"canvas":[320,240],"scale":0.47,"floor_row":206,"radius":15,"height":46},"3":{"canvas":[320,240],"scale":0.33,"floor_row":206,"radius":10,"height":30}}}
var villager_population: Node3D
func attach_starting_magic() -> void:
	starting_magic=preload("res://scripts/lol2/player_starting_magic.gd").new()
	starting_magic.name="StartingMagic"
	add_child(starting_magic)
	item_effects=preload("res://scripts/lol2/player_item_controller.gd").new()
	add_child(item_effects)

func _init() -> void:
	# Huline Jungle: unbound grey wall faces (no source wall record) are collision-only.
	draw_unbound_walls = false

func _ready() -> void:
	super._ready()
	add_child(curse)
	attach_starting_magic.call_deferred()
	FormBody.apply(player,camera,player_form,false)
	if huline_content:
		attach_hive_route.call_deferred()
		village_gate = preload("res://scripts/lol2/jungle_village_gate.gd").new()
		village_gate.name = "VillageGate"
		add_child(village_gate)
		village_dialogue = preload("res://scripts/lol2/jungle_village_dialogue.gd").new()
		village_dialogue.name = "GateVillager"
		add_child(village_dialogue)
		followup_gate = preload("res://scripts/lol2/jungle_followup_gate.gd").new()
		followup_gate.name = "FollowupGate"
		add_child(followup_gate)
		followup_dialogue = preload("res://scripts/lol2/jungle_followup_dialogue.gd").new()
		followup_dialogue.name = "FollowupVillager"
		add_child(followup_dialogue)
	set_development_mode(false)
	interface_hud = preload("res://scripts/lol2/museum_interface.gd").new()
	interface_hud.walkthrough = self
	interface_hud.geometry_path = geometry_file
	interface_hud.location_name = area_name
	interface_hud.save_path = area_save_path
	interface_hud.save_location_name = "Jungle" if huline_content else area_name
	add_child(interface_hud)
	if huline_content:
		monastery = preload("res://scripts/lol2/monastery_rooms.gd").new()
		monastery.name = "MonasteryRooms"
		add_child(monastery)
		magic_shop = preload("res://scripts/lol2/magic_shop_rooms.gd").new()
		magic_shop.name = "MagicShop"
		add_child(magic_shop)
		weapon_shop = preload("res://scripts/lol2/weapon_shop_rooms.gd").new()
		weapon_shop.name = "WeaponShop"
		add_child(weapon_shop)
		source_pickups = preload("res://scripts/lol2/jungle_source_pickups.gd").new()
		source_pickups.name = "SourcePickups"
		add_child(source_pickups)
		if preload("res://scripts/lol2/jungle_world_items.gd").assets_ready():
			world_items = preload("res://scripts/lol2/jungle_world_items.gd").new()
			world_items.name = "WorldItems"
			add_child(world_items)
		dino_population = preload("res://scripts/lol2/jungle_dino_population.gd").new()
		dino_population.name = "DinoPopulation"
		add_child(dino_population)
		var dino_error: String = dino_population.setup(self)
		if not dino_error.is_empty(): push_error(dino_error)
		if FileAccess.file_exists(str(VILLAGER_CONFIG.root)+"sprites.json"):
			villager_population = preload("res://scripts/lol2/scripted_creature_population.gd").new()
			villager_population.name = "VillagerPopulation"
			villager_population.configure(VILLAGER_CONFIG)
			add_child(villager_population)
			var villager_error: String = villager_population.setup(self)
			if not villager_error.is_empty(): push_error(villager_error)
		exit_encounter=preload("res://scripts/lol2/jungle_exit_encounter.gd").new()
		exit_encounter.name="JungleExitEncounter"
		add_child(exit_encounter)
		var exit_error: String=exit_encounter.setup(self,_exit_context)
		if not exit_error.is_empty(): push_error(exit_error)
		bacatta=preload("res://scripts/lol2/jungle_bacatta.gd").new()
		bacatta.name="JungleBacatta"
		add_child(bacatta)
		var bacatta_error: String=bacatta.setup(self,{"context":_bacatta_context})
		if not bacatta_error.is_empty(): push_error(bacatta_error)
		if preload("res://scripts/lol2/jungle_exit_woman.gd").assets_ready():
			exit_woman=preload("res://scripts/lol2/jungle_exit_woman.gd").new()
			exit_woman.name="JungleExitWoman"
			add_child(exit_woman)
			var exit_woman_error: String=exit_woman.setup(self,{},quest_state.get("jungle_exit_woman"))
			if not exit_woman_error.is_empty(): push_error(exit_woman_error)
		if FileAccess.file_exists(preload("res://scripts/lol2/jungle_kelsrick_state.gd").MEDIA):
			kelsrick=preload("res://scripts/lol2/jungle_kelsrick.gd").new()
			kelsrick.name="JungleKelsrick"
			add_child(kelsrick)
			var kelsrick_error: String=kelsrick.setup(self,{"context":_kelsrick_context,"shared":_kelsrick_shared,"held_item":func(): return hand_item if hand_item in carried_collected else ""},quest_state.get("jungle_kelsrick"))
			if not kelsrick_error.is_empty(): push_error(kelsrick_error)
		if FileAccess.file_exists(preload("res://scripts/lol2/jungle_dawn_state.gd").MEDIA) and FileAccess.file_exists(preload("res://scripts/lol2/jungle_dawn_packet.gd").POPULATION):
			dawn=preload("res://scripts/lol2/jungle_dawn.gd").new()
			dawn.name="JungleDawn"
			add_child(dawn)
			var dawn_error: String=dawn.setup(self,{"context":_dawn_context,"shared":_named_shared,"held_item":func(): return hand_item if hand_item in carried_collected else "","consume_held":_consume_hand_item},quest_state.get("jungle_dawn"))
			if not dawn_error.is_empty(): push_error(dawn_error)
		if FileAccess.file_exists(preload("res://scripts/lol2/jungle_actor62_state.gd").SOURCE) and FileAccess.file_exists("res://assets/lol2/generated/jungle_actor62/sprites/sprites.json"):
			actor62=preload("res://scripts/lol2/jungle_actor62.gd").new()
			actor62.name="JungleActor62"
			add_child(actor62)
			var actor62_error: String=actor62.setup(self,quest_state.get("jungle_actor62"))
			if not actor62_error.is_empty(): push_error(actor62_error)
		if preload("res://scripts/lol2/jungle_bacatta65.gd").assets_ready():
			bacatta65=preload("res://scripts/lol2/jungle_bacatta65.gd").new()
			bacatta65.name="JungleBacatta65"
			add_child(bacatta65)
			var bacatta65_error: String=bacatta65.setup(self,{"context":_bacatta65_context,"shared":_bacatta65_shared,"held_item":func(): return hand_item if hand_item in carried_collected else ""},quest_state.get("jungle_bacatta65"))
			if not bacatta65_error.is_empty(): push_error(bacatta65_error)
		if preload("res://scripts/lol2/jungle_bacatta57.gd").assets_ready():
			bacatta57=preload("res://scripts/lol2/jungle_bacatta57.gd").new()
			bacatta57.name="JungleBacatta57"
			add_child(bacatta57)
			var bacatta57_error: String=bacatta57.setup(self,{"context":_bacatta57_context},quest_state.get("jungle_bacatta57"))
			if not bacatta57_error.is_empty(): push_error(bacatta57_error)
	get_window().title = "Lands of Lore II — "+area_name
	if get_tree().has_meta("lol2_jungle_handoff"):
		var handoff = get_tree().get_meta("lol2_jungle_handoff")
		if apply_inventory_handoff(handoff).is_empty(): get_tree().remove_meta("lol2_jungle_handoff")
	if get_tree().has_meta("lol2_jungle_resume"):
		var resume = get_tree().get_meta("lol2_jungle_resume")
		if apply_save(resume).is_empty(): get_tree().remove_meta("lol2_jungle_resume")

	if huline_content:
		departure = preload("res://scripts/lol2/act_one_departure.gd").new()
		departure.name = "ActOneDeparture"
		add_child(departure)

func attach_hive_route() -> void:
	var route = preload("res://scripts/lol2/hive_route.gd").new()
	route.name = "HiveRoute"
	route.area = "jungle"
	add_child(route)

func _unhandled_input(event: InputEvent) -> void:
	if actor_input_locked(): return
	if is_instance_valid(exit_encounter) and exit_encounter.active(): return
	if is_instance_valid(departure) and departure.active(): return
	if is_instance_valid(monastery) and monastery.active(): return
	if is_instance_valid(weapon_shop) and weapon_shop.active(): return
	if is_instance_valid(magic_shop) and magic_shop.active(): return
	if is_instance_valid(interface_hud) and interface_hud.cursor_active: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		if open_inventory(): get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func open_inventory() -> bool:
	if actor_input_locked(): return false
	if is_instance_valid(exit_encounter) and exit_encounter.active(): return false
	if (is_instance_valid(departure) and departure.active()) or get_tree().paused or is_instance_valid(inventory) or (is_instance_valid(monastery) and monastery.active()) or (is_instance_valid(magic_shop) and magic_shop.active()) or (is_instance_valid(weapon_shop) and weapon_shop.active()): return false
	inventory = preload("res://scripts/lol2/museum_inventory.gd").new()
	inventory.use_item = use_inventory_item
	inventory.item_ids = carried_collected.duplicate()
	inventory.equipped_item = equipped_item
	inventory.equipped_armor = equipped_armor
	inventory.change_armor = set_equipped_armor
	inventory.change_equipment = set_equipped_item
	inventory.return_to_game = interface_hud.set_cursor.bind(false)
	inventory.hold_item = hold_in_hand
	inventory.held_item_id = hand_item
	inventory.hold_label = "Hold in hand"
	add_child(inventory)
	return true

## Toggle the item held for an E-use offer (transient cursor state, not saved).
func hold_in_hand(id: String) -> bool:
	if id not in carried_collected: return false
	hand_item = "" if hand_item == id else id
	return true

func set_equipped_item(item_id: String) -> bool:
	if item_id != "" and (not preload("res://scripts/lol2/player_equipment.gd").weapon(item_id) or not item_id in carried_collected): return false
	equipped_item = item_id
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	return true

func set_equipped_armor(item_id: String) -> bool:
	if item_id != "" and (not preload("res://scripts/lol2/player_equipment.gd").armor(item_id) or not item_id in carried_collected): return false
	equipped_armor = item_id
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	return true

func inventory_state() -> Dictionary:
	return {"item_effects":item_effect_checkpoint.duplicate(true),"collected":carried_collected.duplicate(), "equipped_item":equipped_item, "equipped_armor":equipped_armor,"health":health,"player_form":player_form,"curse":curse.snapshot()}

func apply_inventory_handoff(state: Variant) -> String:
	var error := Save.validate_inventory(state)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_fighting_transport.gd").transport_error(state,quest_state)
	if not error.is_empty(): return error
	if state.has("museum_control181"): quest_state["museum_control181"] = state.museum_control181.duplicate(true)
	if state.has("magic"):
		quest_state.player_magic_reward_state = preload("res://scripts/lol2/player_magic_state.gd").restore(state.magic).checkpoint
	if state.has("fighting"): preload("res://scripts/lol2/player_fighting_transport.gd").merge(quest_state,state.fighting)
	item_effect_checkpoint=preload("res://scripts/lol2/player_item_state.gd").canonical(state.get("item_effects",preload("res://scripts/lol2/player_item_state.gd").initial()))
	carried_collected = state.collected.duplicate()
	if is_instance_valid(source_pickups): source_pickups.restore()
	if is_instance_valid(world_items): world_items.restore()
	health = int(state.get("health",30))
	jump_requested = false
	player_form = int(state.get("player_form",0))
	curse.restore(state.get("curse",Curse.initial()))
	FormBody.apply(player,camera,player_form,false)
	equipped_item = state.equipped_item
	equipped_armor = state.equipped_armor
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()
	return ""

func quicksave(path: String = "") -> String:
	if path.is_empty(): path = area_save_path
	if get_tree().paused: return "Close the current overlay before saving."
	if flying: return "Return to walking mode before saving."
	_sync_exit_checkpoint()
	return Save.write_save(path,{"format":area_save_format,"version":1,"inventory":inventory_state(),"quests":quest_state.duplicate(true),
		"player":{"position":[player.position.x,player.position.y,player.position.z],
		"yaw":wrapf(player.rotation.y,-PI,PI),"pitch":camera.rotation.x}},area_save_format)

func quickload(path: String = "") -> String:
	if path.is_empty(): path = area_save_path
	if get_tree().paused: return "Close the current overlay before loading."
	var result := Save.read_save(path,area_save_format)
	if not result.error.is_empty(): return result.error
	return apply_save(result.state)

func apply_save(state: Variant) -> String:
	var error := Save.validate(state,area_save_format)
	if not error.is_empty(): return error
	# Fighting transport is checked against the incoming quests by Save.validate.
	var inventory: Dictionary = state.inventory.duplicate(true)
	inventory.erase("fighting")
	apply_inventory_handoff(inventory)
	quest_state = state.get("quests",Save.Quests.initial()).duplicate(true)
	preload("res://scripts/lol2/player_fighting_transport.gd").merge(quest_state,preload("res://scripts/lol2/player_fighting_transport.gd").pack(quest_state))
	if state.inventory.has("fighting"): preload("res://scripts/lol2/player_fighting_transport.gd").merge(quest_state,state.inventory.fighting)
	if quest_state.has("hive_ambush"): quest_state.hive_ambush = preload("res://scripts/lol2/hive_ambush_state.gd").canonical(quest_state.hive_ambush)
	if quest_state.has("hive_rune_population"): quest_state.hive_rune_population=preload("res://scripts/lol2/hive_rune_population_state.gd").canonical(quest_state.hive_rune_population)
	if quest_state.has("hive_return_population"): quest_state.hive_return_population = preload("res://scripts/lol2/hive_return_population_state.gd").canonical(quest_state.hive_return_population)
	if quest_state.has("hive_curse"): quest_state.hive_curse = preload("res://scripts/lol2/hive_curse_state.gd").canonical(quest_state.hive_curse)
	if quest_state.has("jungle_dino_population"): quest_state.jungle_dino_population = preload("res://scripts/lol2/jungle_dino_population_state.gd").canonical(quest_state.jungle_dino_population)
	if quest_state.has("player_magic_reward_state"): quest_state.player_magic_reward_state = preload("res://scripts/lol2/player_magic_state.gd").restore(quest_state.player_magic_reward_state).checkpoint
	if state.inventory.has("magic"): quest_state.player_magic_reward_state = preload("res://scripts/lol2/player_magic_state.gd").restore(state.inventory.magic).checkpoint
	set_development_mode(false)
	player.position = Vector3(state.player.position[0],state.player.position[1],state.player.position[2])
	player.rotation.y = state.player.yaw
	camera.rotation = Vector3(state.player.pitch,0,0)
	player.velocity = Vector3.ZERO
	if is_instance_valid(village_gate): village_gate.restore()
	if is_instance_valid(village_dialogue): village_dialogue.restore()
	if is_instance_valid(followup_gate): followup_gate.restore()
	if is_instance_valid(followup_dialogue): followup_dialogue.restore()
	# Active rooms restore their own mouse mode below. Do not briefly grab the
	# world mouse while loading a save whose room UI must remain visible.
	# MonasteryRooms.restore() is the authoritative cursor owner for this
	# scene, including when a save changes room state. Avoid a transient grab
	# before it sees the restored quest data (which also produces X11 NO GRAB).
	var room_owns_mouse: bool = is_instance_valid(monastery)
	interface_hud.set_cursor(false,not room_owns_mouse)
	if is_instance_valid(monastery): monastery.restore()
	if is_instance_valid(magic_shop): magic_shop.restore()
	if is_instance_valid(weapon_shop): weapon_shop.restore()
	if is_instance_valid(source_pickups): source_pickups.restore()
	if is_instance_valid(world_items): world_items.restore()
	if is_instance_valid(departure): departure.restore()
	if is_instance_valid(dino_population): dino_population.restore()
	if is_instance_valid(villager_population): villager_population.restore_from_quests()
	if is_instance_valid(exit_encounter): exit_encounter.restore(quest_state.get("jungle_exit_encounter",exit_encounter.initial()))
	if is_instance_valid(bacatta): bacatta.restore(quest_state.get("jungle_bacatta",bacatta.initial()))
	if is_instance_valid(exit_woman): exit_woman.restore(quest_state.get("jungle_exit_woman",exit_woman.initial()))
	if is_instance_valid(kelsrick): kelsrick.restore(quest_state.get("jungle_kelsrick",kelsrick.initial()))
	if is_instance_valid(dawn): dawn.restore(quest_state.get("jungle_dawn",dawn.initial()))
	if is_instance_valid(actor62): actor62.restore(quest_state.get("jungle_actor62",actor62.initial()))
	if is_instance_valid(bacatta65): bacatta65.restore(quest_state.get("jungle_bacatta65",bacatta65.initial()))
	if is_instance_valid(bacatta57): bacatta57.restore(quest_state.get("jungle_bacatta57",bacatta57.initial()))
	return ""

# Validated inventory and quest transport for the Hive route.
func area_handoff() -> Dictionary:
	_sync_exit_checkpoint()
	return {"inventory":inventory_state(),"quests":quest_state.duplicate(true)}

func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := Save.validate_inventory(state.get("inventory"))
	if not error.is_empty(): return error
	error = Save.Quests.validate(state.get("quests"))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_item_state.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_magic_state.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_fighting_transport.gd").transport_error(state.inventory,state.quests)
	if not error.is_empty(): return error
	var inventory: Dictionary = state.inventory.duplicate(true)
	inventory.erase("fighting")
	apply_inventory_handoff(inventory)
	quest_state = state.quests.duplicate(true)
	preload("res://scripts/lol2/player_fighting_transport.gd").merge(quest_state,preload("res://scripts/lol2/player_fighting_transport.gd").pack(quest_state))
	if state.inventory.has("fighting"): preload("res://scripts/lol2/player_fighting_transport.gd").merge(quest_state,state.inventory.fighting)
	if quest_state.has("hive_ambush"): quest_state.hive_ambush = preload("res://scripts/lol2/hive_ambush_state.gd").canonical(quest_state.hive_ambush)
	if quest_state.has("hive_rune_population"): quest_state.hive_rune_population=preload("res://scripts/lol2/hive_rune_population_state.gd").canonical(quest_state.hive_rune_population)
	if quest_state.has("hive_return_population"): quest_state.hive_return_population = preload("res://scripts/lol2/hive_return_population_state.gd").canonical(quest_state.hive_return_population)
	if quest_state.has("hive_curse"): quest_state.hive_curse = preload("res://scripts/lol2/hive_curse_state.gd").canonical(quest_state.hive_curse)
	if quest_state.has("jungle_dino_population"): quest_state.jungle_dino_population = preload("res://scripts/lol2/jungle_dino_population_state.gd").canonical(quest_state.jungle_dino_population)
	if quest_state.has("player_magic_reward_state"): quest_state.player_magic_reward_state = preload("res://scripts/lol2/player_magic_state.gd").restore(quest_state.player_magic_reward_state).checkpoint
	if state.inventory.has("magic"): quest_state.player_magic_reward_state = preload("res://scripts/lol2/player_magic_state.gd").restore(state.inventory.magic).checkpoint
	if is_instance_valid(village_gate): village_gate.restore()
	if is_instance_valid(village_dialogue): village_dialogue.restore()
	if is_instance_valid(followup_gate): followup_gate.restore()
	if is_instance_valid(followup_dialogue): followup_dialogue.restore()
	if is_instance_valid(monastery): monastery.restore()
	if is_instance_valid(magic_shop): magic_shop.restore()
	if is_instance_valid(weapon_shop): weapon_shop.restore()
	if is_instance_valid(source_pickups): source_pickups.restore()
	if is_instance_valid(world_items): world_items.restore()
	if is_instance_valid(departure): departure.restore()
	if is_instance_valid(dino_population): dino_population.restore()
	if is_instance_valid(villager_population): villager_population.restore_from_quests()
	if is_instance_valid(exit_encounter): exit_encounter.restore(quest_state.get("jungle_exit_encounter",exit_encounter.initial()))
	if is_instance_valid(bacatta): bacatta.restore(quest_state.get("jungle_bacatta",bacatta.initial()))
	if is_instance_valid(exit_woman): exit_woman.restore(quest_state.get("jungle_exit_woman",exit_woman.initial()))
	if is_instance_valid(kelsrick): kelsrick.restore(quest_state.get("jungle_kelsrick",kelsrick.initial()))
	if is_instance_valid(dawn): dawn.restore(quest_state.get("jungle_dawn",dawn.initial()))
	if is_instance_valid(actor62): actor62.restore(quest_state.get("jungle_actor62",actor62.initial()))
	if is_instance_valid(bacatta65): bacatta65.restore(quest_state.get("jungle_bacatta65",bacatta65.initial()))
	if is_instance_valid(bacatta57): bacatta57.restore(quest_state.get("jungle_bacatta57",bacatta57.initial()))
	return ""

func move_grounded(direction: Vector3, delta: float, sprint: bool = false) -> void:
	if (is_instance_valid(village_dialogue) and village_dialogue.active()) or (is_instance_valid(followup_dialogue) and followup_dialogue.active()) or (is_instance_valid(dawn) and dawn.movement_locked()) or (is_instance_valid(bacatta65) and bacatta65.movement_locked()):
		jump_requested = false
		super.move_grounded(Vector3.ZERO,delta)
		return
	super.move_grounded(direction,delta,sprint)

func save_feedback(message: String) -> void:
	if not is_instance_valid(interface_hud): return
	interface_hud.hint.text = message
	interface_hud.save_notice_remaining = 3.0

func use_inventory_item(id: String) -> bool:
	if preload("res://scripts/lol2/item_catalog.gd").use_kind(id) != "": return item_effects.use(id)
	if id != preload("res://scripts/lol2/monastery_conversation.gd").FLUTE or id not in carried_collected: return false
	var Lift = preload("res://scripts/lol2/hive_elevator_state.gd")
	if not quest_state.has("hive_elevator"): quest_state.hive_elevator = Lift.initial()
	if not Lift.play_flute(quest_state.hive_elevator): return false
	interface_hud.hint.text = "You play the flute."
	interface_hud.save_notice_remaining = 3.0
	return true

func _sync_exit_checkpoint() -> void:
	if is_instance_valid(bacatta): quest_state.jungle_bacatta=bacatta.checkpoint()
	if is_instance_valid(exit_woman): quest_state.jungle_exit_woman=exit_woman.checkpoint()
	if is_instance_valid(kelsrick): quest_state.jungle_kelsrick=kelsrick.checkpoint()
	if is_instance_valid(dawn): quest_state.jungle_dawn=dawn.checkpoint()
	if is_instance_valid(actor62): quest_state.jungle_actor62=actor62.checkpoint()
	if is_instance_valid(bacatta65): quest_state.jungle_bacatta65=bacatta65.checkpoint()
	if is_instance_valid(bacatta57): quest_state.jungle_bacatta57=bacatta57.checkpoint()
	if is_instance_valid(exit_encounter): quest_state.jungle_exit_encounter=exit_encounter.checkpoint()

func _exit_context() -> Dictionary:
	var globals: Dictionary=quest_state.get("monastery",{}).get("globals",{})
	# Daniel knowledge is also written by the weapon shop's original conversation.
	var shop_globals: Dictionary=quest_state.get("weapon_shop",{}).get("globals",{})
	var shared: Dictionary={}
	for id in exit_encounter.src.shared_names:
		var key: String=exit_encounter.src.shared_names[id]
		shared[id]=GlobalDefaults.read(globals,key) if GlobalDefaults.NONZERO.has(key) else maxi(int(globals.get(key,0)),int(shop_globals.get(key,0)))
	# These Jungle-only locals start at zero; the Bacatta component will own their transitions.
	return {"shared":shared,"locals":{"41":0,"49":0,"51":int(bacatta.state.locals["51"]) if is_instance_valid(bacatta) and not bacatta.state.is_empty() else 0}}

func _physics_process(delta: float) -> void:
	if actor_input_locked():
		jump_requested=false
		return
	if is_instance_valid(exit_encounter) and exit_encounter.active():
		player.velocity=Vector3.ZERO
		jump_requested=false
		return
	super._physics_process(delta)

func request_jump() -> bool:
	if actor_input_locked() or (is_instance_valid(dawn) and dawn.movement_locked()) or (is_instance_valid(bacatta65) and bacatta65.movement_locked()): return false
	if is_instance_valid(exit_encounter) and exit_encounter.active(): return false
	return super.request_jump()

func _bacatta_context() -> Dictionary:
	var ctx:=_exit_context()
	var globals: Dictionary=quest_state.get("monastery",{}).get("globals",{})
	for id in bacatta.src.shared_names:
		if not ctx.shared.has(id):
			ctx.shared[id]=int(globals.get(str(bacatta.src.shared_names[id]),GlobalDefaults.initial_value(str(bacatta.src.shared_names[id]))))
	return ctx

func actor_input_locked() -> bool:
	return (is_instance_valid(bacatta) and bacatta.input_locked()) or (is_instance_valid(exit_woman) and exit_woman.input_locked()) or (is_instance_valid(kelsrick) and kelsrick.input_locked()) or (is_instance_valid(dawn) and dawn.input_locked())

## Dawn reads the soul, runes, gift, relationship and monastery-attack globals by their source names.
func _dawn_context() -> Dictionary:
	var globals: Dictionary=quest_state.get("monastery",{}).get("globals",{})
	var shared: Dictionary={}
	for id in dawn.src.shared_names: shared[id]=int(globals.get(str(dawn.src.shared_names[id]),GlobalDefaults.initial_value(str(dawn.src.shared_names[id]))))
	return {"shared":shared,"locals":{}}

## Opcode206/199 on Dawn's named globals (0..255; Soul cap10 and Dawn relationship cap2 from the runtime index table).
func _named_shared(e: Dictionary) -> void:
	var name: String=str(dawn.src.shared_names.get(str(int(e.index)),"")) if is_instance_valid(dawn) else ""
	if name.is_empty(): return
	if not quest_state.has("monastery"): quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	var globals: Dictionary=quest_state.monastery.globals
	var cap: int={"GV_LUTHERS_SOUL":10,"GV_DAWN_RELATIONSHIP":2}.get(name,255)
	globals[name]=clampi(int(e.value) if str(e.op)=="set" else int(globals.get(name,GlobalDefaults.initial_value(name)))+int(e.value),0,cap)

## Player property 0x18: the offered (held) item leaves the inventory.
func _consume_hand_item() -> void:
	if hand_item in carried_collected: carried_collected.erase(hand_item)
	if equipped_item==hand_item: equipped_item=""
	hand_item=""
	if is_instance_valid(interface_hud): interface_hud.refresh_equipment()

## Kelsrick reads the soul/dead globals, the Huline alert and the village speech completion (control99 local15).
## Shared29 (GV_HULINE_ALERT) already has one owner: the village gate state, whose admission requires it zero.
func _kelsrick_context() -> Dictionary:
	var globals: Dictionary=quest_state.get("monastery",{}).get("globals",{})
	var shared:={"0":int(globals.get("GV_LUTHERS_SOUL",GlobalDefaults.initial_value("GV_LUTHERS_SOUL"))),"11":int(globals.get("GV_KELSRICK_DEAD",0)),"29":0}
	var local15:=0
	if is_instance_valid(village_gate): shared["29"]=int(village_gate.state().shared29)
	if is_instance_valid(village_dialogue): local15=int(village_dialogue.state().get("local15",0))
	return {"shared":shared,"locals":{"15":local15}}

## Opcode206/199 writes (0..255; Soul capped at 10 by the verified runtime index table).
func _kelsrick_shared(e: Dictionary) -> void:
	var index:=int(e.index)
	var current:int=int(_kelsrick_context().shared.get(str(index),0))
	var value:=clampi(int(e.value) if str(e.op)=="set" else current+int(e.value),0,10 if index==0 else 255)
	if index==29:
		if is_instance_valid(village_gate): village_gate.state().shared29=value
		return
	var name: String=str({0:"GV_LUTHERS_SOUL",11:"GV_KELSRICK_DEAD"}.get(index,""))
	if name=="": return
	if not quest_state.has("monastery"): quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	quest_state.monastery.globals[name]=value

## Bacatta65 reads the Huline alert (the village gate's shared29, sole owner) and the monastery globals by source name.
func _bacatta65_context() -> Dictionary:
	var globals: Dictionary=quest_state.get("monastery",{}).get("globals",{})
	var shared: Dictionary={}
	for id in bacatta65.src.shared_names: shared[id]=int(globals.get(str(bacatta65.src.shared_names[id]),GlobalDefaults.initial_value(str(bacatta65.src.shared_names[id]))))
	shared["29"]=int(village_gate.state().shared29) if is_instance_valid(village_gate) else 0
	return {"shared":shared}

## Bacatta57 (village entry) tests GV_BACATTA_RELATIONSHIP and GV_MET_BACATTA; it writes no globals.
func _bacatta57_context() -> Dictionary:
	var shared: Dictionary={}
	for id in bacatta57.src.shared_names: shared[id]=GlobalDefaults.read(quest_state.get("monastery",{}).get("globals",{}),str(bacatta57.src.shared_names[id]))
	return {"shared":shared}

## Opcode206/199 on the Bacatta65 globals (runtime caps: soul 10, Bacatta relationship 2).
func _bacatta65_shared(e: Dictionary) -> void:
	var index:=int(e.index)
	var current:int=int(_bacatta65_context().shared.get(str(index),0))
	var value:=clampi(int(e.value) if str(e.op)=="set" else current+int(e.value),0,int(bacatta65.src.shared_caps.get(str(index),255)))
	if index==29:
		if is_instance_valid(village_gate): village_gate.state().shared29=value
		return
	var name: String=str(bacatta65.src.shared_names.get(str(index),""))
	if name=="": return
	if not quest_state.has("monastery"): quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	quest_state.monastery.globals[name]=value

func _input(event: InputEvent) -> void:
	if not actor_input_locked(): return
	if event is InputEventKey and event.keycode in [KEY_F5,KEY_F9,KEY_ESCAPE]: return
	get_viewport().set_input_as_handled()
