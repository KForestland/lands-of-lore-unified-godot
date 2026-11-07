extends SceneTree
## Actual Jungle host: a Fire crystal earned through the real magic-shop sprite click (MAGIC give_item("57a-Fire crstl",
## 4)); four inventory "Use crystal" presses spend its 4 charges (handler2 adapter: shared Spark ray, 8 damage), the
## first striking a source dino; the 5th use is refused (burnt, "57b-Fire brnt"); status line; disk save/load; Jungle ->
## Hive handoff keeps the charges; validation negatives. Supplied dino vantage.
var jungle
var failed := false
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	if failed: return
	failed = true; push_error(message); quit(1)
func finish_shop(shop) -> void:
	for i in 1500:
		if not shop.State.active(shop.state()): return
		shop.advance(0.1)
func use_crystal(id: String) -> bool:
	if not jungle.open_inventory(): return false
	await process_frame
	var inv = jungle.inventory
	var index := -1
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i)) == id: index = i
	if index < 0: return false
	inv.select_item(index)
	if not inv.use_button.visible or inv.use_button.text != "Use crystal": fail("Use button: %s %s" % [inv.use_button.visible, inv.use_button.text]); return false
	var before: int = jungle.item_effects.crystal_charges(id)
	inv.use_button.pressed.emit()
	await process_frame
	if is_instance_valid(jungle.inventory): jungle.inventory.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return jungle.item_effects.crystal_charges(id) == before - 1
func run() -> void:
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 10: await process_frame
	jungle.set_physics_process(false)
	for room in [jungle.monastery, jungle.weapon_shop, jungle.departure]:
		if is_instance_valid(room): room.set_process(false)
	var shop = jungle.magic_shop
	shop.set_process(false)
	# Earn: the real shop room and the first Fire crystal sprite (sprite 4).
	if not shop.enter_room(): return fail("Shop room did not open")
	finish_shop(shop)
	var p: Array = shop.Shop.SPRITES[4]
	var before: Array = jungle.carried_collected.duplicate()
	if not shop.click(Vector2i(p[0] + 1, p[1] + 1)): return fail("Fire crystal sprite click refused")
	finish_shop(shop)
	shop.leave_room()
	var added: Array = jungle.carried_collected.filter(func(x): return not x in before)
	if added.size() != 1 or preload("res://scripts/lol2/item_catalog.gd").use_kind(added[0]) != "fire_crystal": return fail("Shop grant: %s" % [added])
	var crystal: String = added[0]
	if jungle.item_effects.crystal_charges(crystal) != 4: return fail("Shop crystal charges %d" % jungle.item_effects.crystal_charges(crystal))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Supplied vantage on a living source dino; the first use strikes it.
	var dinos = jungle.dino_population
	var target_id := ""
	for id in dinos.bodies:
		if int(dinos.view().actors[id].health) > 8: target_id = id; break
	if target_id == "": return fail("No living dino")
	var body: Node3D = dinos.bodies[target_id]
	dinos.set_physics_process(false); dinos.set_process(false)
	var aim: Vector3 = body.global_position + Vector3(0, 20, 0)
	jungle.player.global_position = aim + Vector3(60, 10, 0) - Vector3(0, jungle.camera.position.y, 0)
	jungle.player.rotation = Vector3.ZERO; jungle.camera.rotation = Vector3.ZERO
	await physics_frame
	jungle.camera.look_at(aim); await physics_frame; await physics_frame
	var health_before: int = int(dinos.view().actors[target_id].health)
	if not await use_crystal(crystal): return fail("First use did not spend a charge")
	var health_after: int = int(dinos.view().actors[target_id].health)
	if health_after != health_before - 8: return fail("Fire did not strike the dino: %d -> %d" % [health_before, health_after])
	# Look away (no target): the charge is still spent, as handler2 spends before its target search.
	jungle.camera.rotation = Vector3(PI / 2 - 0.05, 0, 0); await physics_frame
	for k in 3:
		if not await use_crystal(crystal): return fail("Use %d did not spend a charge" % (k + 2))
	if not jungle.item_effects.crystal_burnt(crystal): return fail("Crystal not burnt after 4 uses")
	if jungle.item_effects.use(crystal): return fail("Burnt crystal fired")
	if not "Fire crystal · burnt out" in jungle.item_effects.status(): return fail("Status: " + jungle.item_effects.status())
	if not crystal in jungle.carried_collected: return fail("Burnt crystal left the inventory")
	jungle.camera.rotation = Vector3.ZERO  # the save format bounds the view pitch
	# Disk save/load keeps the burnt crystal.
	var path := "user://tests/fire_crystal_live.json"
	var save_error: String = jungle.quicksave(path)
	if not save_error.is_empty(): return fail("Save failed: " + save_error)
	jungle.item_effects.state().fire_crystals[crystal] = 3
	if not jungle.quickload(path).is_empty() or not jungle.item_effects.crystal_burnt(crystal): return fail("Reload lost burnt state")
	# Validation negatives.
	var Items = preload("res://scripts/lol2/player_item_state.gd")
	var bad: Dictionary = jungle.item_effects.state().duplicate(true); bad.fire_crystals[crystal] = 5
	if Items.validate(bad, jungle.carried_collected).is_empty(): return fail("5 charges accepted")
	bad = jungle.item_effects.state().duplicate(true); bad.fire_crystals["jungle:magic_shop:Mana_foil"] = 1
	if Items.validate(bad, jungle.carried_collected).is_empty(): return fail("Charges on a non-crystal accepted")
	# Jungle -> Hive handoff keeps the charges.
	var handoff: Dictionary = jungle.area_handoff()
	jungle.queue_free(); await process_frame; await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 3: await process_frame
	var error: String = hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff, "", true, true)))
	if not error.is_empty() or int(hive.item_effects.state().get("fire_crystals", {}).get(crystal, -1)) != 0: return fail("Hive handoff: %s %s" % [error, hive.item_effects.state()])
	print("PASS fire_crystal_live: shop-earned 57a-Fire crstl (4 charges), inventory Use crystal x4 (first strikes a dino for 8), burnt refused, status, save/load, negatives, Jungle->Hive handoff.")
	quit()
