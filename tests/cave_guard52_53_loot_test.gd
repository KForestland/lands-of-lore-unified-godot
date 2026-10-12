extends "res://tests/player_magic_handoff_test.gd"
## Guards52/53 sword+shield arrival grants (prop699/g7878, prop1067/g8908). Real control114 movie/wake for guard52,
## supplied region106 contact for guard53, production lethal damage, live (unfrozen) retirement,
## independent drops/partial disk/pause, individual dispatched E pickups, real inventory-UI shield equip with the
## defense scalar change, disk reload, rejections, cave -> Museum -> Jungle handoff. Supplied contact/camera scope.
const Generic = preload("res://scripts/lol2/scripted_creature_state.gd")
const Pair = preload("res://scripts/lol2/cave_guard_pair_loot.gd")
const Defense = preload("res://scripts/lol2/player_defense.gd")
const Form = preload("res://scripts/lol2/player_form_body.gd")
var cave
var g
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func live(node: Node) -> void:
	node.set_process(true); node.set_physics_process(true)
func press(code: int) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = code; event.pressed = false
	Input.parse_input_event(event); await process_frame
func aim(loot, key: String) -> bool:
	for angle in range(90,450,15):
		var p: Vector3 = loot.sprites[key].global_position
		cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
		cave.camera.look_at(p); await physics_frame
		if loot.aimed() == key: return true
	return false
func spawn_at(region_id: int) -> void:
	var region: Dictionary = {}
	for row in g.src.regions:
		if int(row.region) == region_id: region = row
	var centre := Vector2.ZERO
	for p in region.polygon: centre += Vector2(p[0],p[1])
	centre /= region.polygon.size()
	Generic.contact(g.state,g.src,Vector3(centre.x,region.floor_min,centre.y),float(region.floor_min),0)
	g.restore(g.checkpoint())
## Live retirement: only the owner's own _physics_process advances it (no manual advance call).
func retire_live(loot) -> void:
	live(loot)
	var until := Time.get_ticks_msec() + 20000
	while float(loot.state.elapsed) < Pair.DELAY and Time.get_ticks_msec() < until: await physics_frame
	await process_frame
	freeze(loot)
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave ready"): return
	freeze(cave); cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	g = cave.guard_population
	var l52 = cave.guard52_loot
	var l53 = cave.guard53_loot
	if not check(l52.checkpoint() == null and l53.checkpoint() == null and g.state.actors["52"].present and not g.state.actors["53"].present,"Initial guards/loot"): return
	# Guard52's control114 support movie -> control119 -> wake, through production guard_controls.
	var controls = cave.guard_controls
	cave.player_form = 0; Form.apply(cave.player,cave.camera,0,false)
	cave.player.global_position = Vector3(-152,-10,-7650) + cave.native_translation + Vector3.UP*(Form.FOOT_OFFSET+2)
	for i in 20:
		cave.player.velocity = Vector3(0,-30,0); cave.player.move_and_slide(); await physics_frame
		if cave.player.is_on_floor(): break
	cave.camera.look_at(Vector3(-163,20,-7834) + cave.native_translation); controls.advance(1.0/60.0)
	if not check(controls.state.clips.actor52.playing,"control114 did not start actor52's movie"): return
	for i in 1400:
		controls.advance(1.0/60.0)
		if not controls.input_locked() and g.state.actors["52"].woken: break
	if not check(not controls.input_locked() and g.state.actors["52"].woken and l52.checkpoint() == null,"control114 completion/wake (loot untouched)"): return
	# Kill both; guard53 via its source spawn region106.
	spawn_at(106)
	if not check(g.state.actors["53"].present,"Region106 spawns guard53"): return
	if not check(g.receive_damage("52",1000,true) and g.receive_damage("53",1000,true),"Production lethal damage"): return
	# Live hooks: guard52 retires through its own process; guard53 still pending (independent clocks).
	await retire_live(l52)
	if not check(l52.sprites.sword.visible and l52.sprites.shield.visible and float(l53.state.elapsed) == 0,"Live retirement / independence: 52 %s 53 %s" % [l52.state, l53.state]): return
	l53.advance(2)
	var path := "user://tests/guard52_53_loot.json"
	if not check(cave._quicksave(path).is_empty(),"Partial save (52 retired, 53 at 2s)"): return
	paused = true; l53.advance(10); paused = false
	if not check(float(l53.state.elapsed) == 2,"Pause advanced guard53"): return
	if not check(cave._quickload(path).is_empty() and float(l53.state.elapsed) == 2 and l52.sprites.shield.visible,"Partial reload"): return
	freeze(cave); l53.advance(3)
	if not check(l53.sprites.sword.visible and l53.sprites.shield.visible,"Guard53 retirement"): return
	# Individual pickups: guard52 shield first, reload, then the rest.
	if not check(await aim(l52,"shield"),"Aim guard52 shield"): return
	cave._process(0); for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/guard52_drops.png")
	await press(KEY_E)
	if not check(l52.state.taken.shield and not l52.state.taken.sword and cave.carried_items().count("cave:guard52:Guard_Shield") == 1 and l52.sprites.sword.visible,"Individual shield pickup"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"One-taken reload"): return
	freeze(cave)
	for pair in [[l52,"sword"],[l53,"shield"],[l53,"sword"]]:
		if not check(await aim(pair[0],pair[1]),"Aim %s %s" % [pair[0].actor, pair[1]]): return
		await press(KEY_E)
		if not check(pair[0].state.taken[pair[1]],"Pickup %s %s" % [pair[0].actor, pair[1]]): return
	for id in ["cave:guard52:Short_Sword","cave:guard52:Guard_Shield","cave:guard53:Short_Sword","cave:guard53:Guard_Shield"]:
		if not check(cave.carried_items().count(id) == 1,"Carried once: " + id): return
	# Real inventory UI: equip the guard52 shield (offhand) and a guard sword; defense scalar rises by the shield byte.
	var before: int = Defense.scalar(cave)
	await press(KEY_I)
	if not check(is_instance_valid(cave.inventory),"Inventory opened"): return
	var inv = cave.inventory
	var shield_index := -1
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i)) == "cave:guard52:Guard_Shield": shield_index = i
	if not check(shield_index >= 0 and inv.item_list.get_item_text(shield_index) == "Guard Shield" and inv.item_list.get_item_icon(shield_index) != null,"Shield listed with label/icon"): return
	inv.select_item(shield_index)
	if not check(not inv.equip_button.disabled and inv.detail_text.text.contains("Defense +5"),"Shield equip offered: " + inv.detail_text.text): return
	inv.equip_button.pressed.emit(); await process_frame
	if not check(cave.item_effects.state().get("offhand","") == "cave:guard52:Guard_Shield" and Defense.scalar(cave) == before + 5 and inv.detail_name.text.ends_with("· Equipped"),"Shield equip/defense %d -> %d" % [before, Defense.scalar(cave)]): return
	if not check(cave.set_equipped_item("cave:guard53:Short_Sword"),"Guard sword equips"): return
	if is_instance_valid(cave.inventory): cave.inventory.queue_free(); await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var save_error: String = cave._quicksave(path)
	if not check(save_error.is_empty(),"Equipped save: " + save_error): return
	save_error = cave._quickload(path)
	if not check(save_error.is_empty(),"Equipped reload: " + save_error): return
	freeze(cave); l52.advance(20); l53.advance(20)
	if not check(cave.item_effects.state().get("offhand","") == "cave:guard52:Guard_Shield" and cave.equipped_item == "cave:guard53:Short_Sword" and Defense.scalar(cave) == before + 5 and cave.carried_items().count("cave:guard52:Guard_Shield") == 1,"Reload equipment/defense/duplicates"): return
	# Cave save offhand rule: an owned, cave-admitted offhand item only.
	var Save = preload("res://scripts/lol2/walkthrough_save.gd")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var count := 1000000
	if not check(Save.validate(saved,count).is_empty(),"Saved shield state invalid: " + Save.validate(saved,count)): return
	var foreign: Dictionary = saved.duplicate(true); foreign.item_effects.offhand = "jungle:weapon_shop:Gargoyle_Bracers"
	if not check(not Save.validate(foreign,count).is_empty(),"Jungle Bracers offhand admitted in cave save"): return
	var unowned: Dictionary = saved.duplicate(true); unowned.guard52_loot.taken.shield = false
	if not check(not Save.validate(unowned,count).is_empty(),"Unowned shield offhand admitted in cave save"): return
	var weapon_offhand: Dictionary = saved.duplicate(true); weapon_offhand.item_effects.offhand = "cave:guard53:Short_Sword"
	if not check(not Save.validate(weapon_offhand,count).is_empty(),"Sword as offhand admitted"): return
	# Rejections.
	for id in ["52","53"]:
		var living: Dictionary = g.checkpoint(); living.actors[id].health = 1
		var absent: Dictionary = g.checkpoint(); absent.actors[id].present = false
		var loot = l52 if id == "52" else l53
		if not check(not Pair.validate(loot.checkpoint(),living,id).is_empty() and not Pair.validate(loot.checkpoint(),absent,id).is_empty(),"Living/absent guard%s admitted" % id): return
		var collapsed: Dictionary = loot.checkpoint(); collapsed.taken.erase("shield")
		if not check(not Pair.validate(collapsed,g.checkpoint(),id).is_empty(),"Collapsed guard%s receipt admitted" % id): return
	# Cave -> Museum -> Jungle with the shield equipped.
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum); current_scene = museum; await process_frame
	freeze(museum); museum.introduction_state = "complete"
	if is_instance_valid(museum.introduction): museum.introduction.close(); await process_frame
	await process_frame
	if not check(museum.carried_collected.count("cave:guard52:Guard_Shield") == 1 and museum.item_effects.state().get("offhand","") == "cave:guard52:Guard_Shield" and Defense.scalar(museum) >= 5 and museum.quicksave(path).is_empty(),"Museum shield transport/defense/save: %s" % [museum.item_effect_checkpoint]): return
	if not check(museum.quickload(path).is_empty() and museum.item_effects.state().get("offhand","") == "cave:guard52:Guard_Shield","Museum disk reload kept shield"): return
	var transport: Dictionary = museum.inventory_state()
	await finish(museum)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle; await process_frame
	for room in [jungle.monastery,jungle.magic_shop,jungle.weapon_shop,jungle.departure]: room.set_process(false)
	if not check(jungle.apply_inventory_handoff(transport).is_empty(),"Jungle handoff"): return
	if not check(jungle.item_effects.state().get("offhand","") == "cave:guard52:Guard_Shield" and Defense.scalar(jungle) >= 5 and jungle.carried_collected.count("cave:guard53:Short_Sword") == 1,"Jungle shield/defense: %s" % [jungle.item_effect_checkpoint]): return
	await finish(jungle)
	print("PASS guard52/53 sword+shield arrival grants: control114 movie/wake then death, live retirement, independent drops/partial disk/pause, four individual E pickups, inventory-UI shield equip defense +5, disk reload, rejections, cave->Museum->Jungle shield/offhand/defense; supplied contact/camera scope")
	quit()
