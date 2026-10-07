extends SceneTree
## Jungle world-item rows 0/50/52–57/63–67 on the real Jungle host (supplied local approach, not an earned route):
## real E pickups through the production camera, carried ids/labels/icons, one-shot history, area handoff/JSON
## round trip, no respawn after the item leaves the inventory, malformed history rejected.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Catalog=preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const Info=preload("res://scripts/lol2/shop_item_inventory.gd")
var scene
var items
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
## Stand in reach of a row on its open side and look at it.
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
func press_e() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	items._unhandled_input(key)
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	# Other encounters stay frozen: teleporting between rows must not start their region scenes (which would rightly block pickups).
	for name in ["exit_encounter","bacatta","kelsrick","dawn","actor62","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	items=scene.world_items
	if not check(items!=null and items.sprites.size()==13 and items.sprites.values().all(func(s):return s.visible),"World items not placed"):return
	for row in Catalog.rows():
		var id:=Catalog.id_of(row)
		if not check(not Info.info(id).is_empty() and FileAccess.file_exists(Info.info(id).icon) and preload("res://scripts/lol2/act_one_item_names.gd").source_name(id)==Catalog.ITEMS[id].name,"Registry differs for "+id):return
		if not check(await face(row),"Row %d not reachable/aimed"%row):return
		press_e()
		if not check(id in scene.carried_collected and not items.sprites[row].visible and row in scene.quest_state.jungle_world_items.collected,"Row %d not collected"%row):return
		# A collected row can no longer be targeted (a second E may legitimately take a neighbouring row instead).
		if not check(items.target()!=row and scene.carried_collected.count(id)==1,"Row %d still targetable"%row):return
	if not check(Save.validate_inventory(scene.inventory_state()).is_empty(),"Carried rows rejected by the inventory allowlist"):return
	# Area handoff → JSON → validators → apply: history and carried rows survive.
	var handoff: Dictionary=scene.area_handoff()
	var parsed=JSON.parse_string(JSON.stringify(handoff,"  ",true,true))
	if not check(Save.Quests.validate(parsed.quests).is_empty() and Save.validate_inventory(parsed.inventory).is_empty(),"Handoff rejected"):return
	if not check(scene.apply_area_handoff(parsed).is_empty() and items.sprites.values().all(func(s):return not s.visible),"Handoff restore differs"):return
	# Trading/using an item away does not respawn it.
	scene.carried_collected.erase(Catalog.id_of(54));items.restore()
	if not check(not items.sprites[54].visible,"Row54 respawned after leaving the inventory"):return
	# Older saves carrying a row without history migrate into history.
	scene.quest_state.jungle_world_items=items.initial();scene.carried_collected.append(Catalog.id_of(54));items.restore()
	if not check(54 in scene.quest_state.jungle_world_items.collected and not items.sprites[54].visible,"Carried-row migration differs"):return
	for bad in [{"version":1,"collected":[51]},{"version":1,"collected":[0,0]},{"version":2,"collected":[]},{"version":1,"collected":[1.5]}]:
		var q: Dictionary=scene.quest_state.duplicate(true);q.jungle_world_items=bad
		if not check(not Save.Quests.validate(q).is_empty(),"Accepted malformed history "+str(bad)):return
	print("PASS: Jungle world items rows 0/50/52-57/63-67 on the Jungle host: 13 original-icon billboards, real E pickup each through the production camera (reach/aim/occlusion), one-shot, registry label/icon/source name, inventory allowlist, area handoff JSON round trip, no respawn after leaving the inventory, carried-row migration, malformed history rejected")
	quit()
