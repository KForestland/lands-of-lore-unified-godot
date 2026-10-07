extends "res://tests/player_magic_handoff_test.gd"
## Jungle world-item Aloe rows63-67 on the real Jungle host: source identity (same definition110/handler9 as
## cave Aloe), real E pickup, production inventory "Use Aloe", pending heal, form gate, full-health
## consumption, disk rollback, no respawn, history-backed consumption validation, derived consumed-item cap,
## and Jungle→Hive→darker-jungle transport with further uses. Supplied local approach, not an earned route.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const World=preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const ROWS:=[63,64,65,66,67]
var scene
var items

func face(row: int) -> bool:
	var p: Vector3=items.aim_point(row)
	for i in range(8):
		var angle:=TAU*float(i)/8.0
		scene.player.global_position=p+Vector3(sin(angle)*50,0,cos(angle)*50)
		scene.player.velocity=Vector3.ZERO
		await physics_frame
		scene.camera.look_at(p)
		await physics_frame
		if items.target()==row: return true
	return false

func freeze(host) -> void:
	host.set_physics_process(false)
	for name in ["exit_encounter","bacatta","kelsrick","dawn","actor62","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue"]:
		var node=host.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	host.item_effects.set_process(false)
	if host.get("starting_magic")!=null: host.starting_magic.set_process(false)

func ids_of(host) -> Array:
	return host.carried_inventory.collected if host.get("carried_inventory")!=null else host.carried_collected

## Production inventory UI: select the item, require "Use Aloe", press it.
func consume(host, id: String) -> bool:
	if not check(host.open_inventory(),"Inventory did not open"): return false
	await process_frame
	var index:=-1
	for i in host.inventory.item_list.item_count:
		if str(host.inventory.item_list.get_item_metadata(i))==id: index=i
	if not check(index>=0,"Inventory lacks "+id): return false
	host.inventory.select_item(index)
	if not check(host.inventory.use_button.visible and host.inventory.use_button.text=="Use Aloe","No Use Aloe button for "+id): return false
	host.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	return check(id in host.item_effects.state().spent and id not in ids_of(host),"Use did not consume "+id)

func run() -> void:
	var path:="user://tests/jungle_aloe_use.json"
	# Source identity: Jungle rows63-67 are the cave Aloe definition.
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_world_items/items.json"))
	for row in source.items:
		if int(row.row) in ROWS and not check(int(row.identity)==preload("res://scripts/lol2/player_item_effects.gd").ALOE_IDENTITY and int(row.definition)==110 and int(row.handler)==9 and Catalog.use_kind(World.id_of(int(row.row)))=="aloe","Row %d is not source Aloe"%int(row.row)):return
		if int(row.row) not in ROWS and not check(Catalog.use_kind(World.id_of(int(row.row)))=="","Row %d gained an unverified use"%int(row.row)):return
	var consumables:=Catalog.consumables()
	if not check(consumables.size()==17 and consumables.filter(func(id): return Catalog.use_kind(id)=="aloe").size()==14,"Consumable registry differs: %d"%consumables.size()):return
	# Real Jungle host and real E pickups.
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	freeze(scene)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	items=scene.world_items
	for row in ROWS:
		if not check(await face(row),"Row %d not reachable"%row):return
		var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
		items._unhandled_input(key)
		if not check(World.id_of(row) in scene.carried_collected,"Row %d not collected"%row):return
	# Use, form gate, pending heal, partial disk rollback.
	var first:=World.id_of(63)
	scene.starting_magic.set_health(10)
	scene.player_form=1
	if not check(not scene.item_effects.use(first) and first in scene.carried_collected,"Transformed player used Aloe"):return
	scene.player_form=0
	if not await consume(scene,first):return
	if not check(scene.item_effects.state().aloe.pending==5 and scene.starting_magic.health()==10,"Pending heal differs"):return
	scene.item_effects.advance(2.0/60.0)
	var partial: Dictionary=scene.item_effects.state().duplicate(true)
	var partial_health: int=scene.starting_magic.health()
	if not check(partial.aloe.pending==5 and partial_health>10,"Gradual heal did not start"):return
	if not check(scene.quicksave(path).is_empty(),"Jungle save rejected consumed Jungle Aloe"):return
	scene.item_effects.advance(1)
	if not check(scene.starting_magic.health()==16 and scene.item_effects.state().aloe.pending==0,"Heal completion differs: %d"%scene.starting_magic.health()):return
	if not check(scene.quickload(path).is_empty() and scene.item_effects.state()==partial and scene.starting_magic.health()==partial_health,"Disk rollback differs"):return
	# No respawn: history keeps the consumed row.
	items.restore()
	if not check(63 in scene.quest_state.jungle_world_items.collected and not items.sprites[63].visible and items.target()!=63,"Consumed row63 respawned"):return
	# Full-health use still consumes.
	scene.starting_magic.set_health(30);scene.item_effects.advance(1)
	if not await consume(scene,World.id_of(64)):return
	scene.item_effects.advance(1)
	if not check(scene.starting_magic.health()==30 and scene.item_effects.state().aloe.pending==0,"Full-health Aloe differs"):return
	# Validation: history-backed consumption, duplicates, derived cap.
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad: Dictionary=saved.duplicate(true);bad.quests.jungle_world_items.collected.erase(63.0);bad.quests.jungle_world_items.collected.erase(63)
	if not check(Save.validate(bad)=="Consumed Jungle item lacks pickup history.","Consumed row without history accepted"):return
	bad=saved.duplicate(true);bad.inventory.item_effects.spent.append(first)
	if not check(not Save.validate(bad).is_empty(),"Duplicate consumption accepted"):return
	bad=saved.duplicate(true);bad.inventory.item_effects.spent.append(World.id_of(52))
	if not check(not Save.validate(bad).is_empty(),"Unverified Ironwod sap consumption accepted"):return
	var State=preload("res://scripts/lol2/player_item_state.gd")
	var full: Dictionary=State.initial();full.spent=consumables.duplicate()
	if not check(State.validate(full,[]).is_empty(),"All registered consumables rejected"):return
	full.spent.append("hive:Wax_runes:0")
	if not check(not State.validate(full,[]).is_empty(),"Cap or registry exceeded"):return
	# Jungle→Hive: further use and disk round trip.
	var handoff: Dictionary=scene.area_handoff()
	await finish(scene)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	await process_frame
	hive.item_effects.set_process(false);hive.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff))).is_empty(),"Hive rejected Jungle Aloe handoff"):return
	hive.starting_magic.set_health(10)
	if not await consume(hive,World.id_of(65)):return
	if not check(hive.item_effects.state().aloe.pending==5 and hive.quicksave(path).is_empty() and hive.quickload(path).is_empty(),"Hive Jungle Aloe use/disk differs"):return
	var back: Dictionary=hive.area_handoff()
	await finish(hive)
	# Hive→darker jungle (Jungle host subclass, its own save format).
	var darker=load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(darker);current_scene=darker
	for i in range(5): await process_frame
	freeze(darker)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(darker.apply_area_handoff(JSON.parse_string(JSON.stringify(back))).is_empty(),"Darker jungle rejected handoff"):return
	if not check(World.id_of(66) in darker.carried_collected and World.id_of(65) in darker.item_effects.state().spent,"Darker transport lost Aloe state"):return
	if not await consume(darker,World.id_of(66)):return
	if not check(darker.quicksave(path).is_empty() and darker.quickload(path).is_empty() and World.id_of(67) in darker.carried_collected,"Darker jungle use/disk differs"):return
	await finish(darker)
	DirAccess.remove_absolute(path)
	print("PASS Jungle Aloe rows63-67: source identity110/9, E pickups, UI Use Aloe, form gate, pending+5 gradual heal, full-health consumption, disk rollback, no respawn, history-backed/duplicate/unverified/cap validation (17 registered consumables), Jungle→Hive→darker uses and saves. Supplied approach; not earned.")
	quit()
