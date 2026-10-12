extends SceneTree
## Cave -> Museum -> Jungle continuity, travel phase (docs/player-continuity.md). Run with --demo-interface; then
## player_continuity_restart_test runs in a NEW process on the receipts written here.
##
## EARNED in this process through ordinary game paths and real viewport clicks/keys:
## - fighting XP: real Attack Button clicks land melee hits on the cave roach (cave_melee_reward, the production owner);
## - magic XP: a real Spell Bar click loads Spark and a real Magic Button click hits the roach (award_hit);
## - consumed item: real inventory clicks select an Aloe and press "Use Aloe" (spent history; the heal runs out);
## - equipment: real inventory clicks equip the Stalagmite; the Attack ring shows it;
## - mana/selected spell: real Spell Bar click loads Heal and a real Magic Button click casts it;
## - Museum -> Jungle: the real E key at the Shining Path approach (production enter_mirror).
## SUPPLIED, labelled: two Aloe and one Stalagmite in the cave owners (their world pickups are not walked); the player
## placed beside the roach and aimed; health 14 before the Heal; the cave chamber movie skipped (chamber_arrival_state
## "complete", then the production _enter_museum transfer); the Museum introduction skipped; the player placed at the
## mirror approach.
## Every comparison uses player_continuity.gd with explicit allowed changes only (Heal in the Museum; mana
## regeneration as documented elapsed-time drift). Negative controls drop an item, XP and the fighting packet from
## live Jungle state and must fail. Receipts: user://tests/continuity/phase1.json + per-area saves and screenshots.
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const Aloe = preload("res://scripts/lol2/cave_aloe.gd")
const WEAPON := "cave:prop641:harvest1:Stalagmite"
const DIR := "user://tests/continuity/"
var failed := false
var simulated_seconds := 0.0
var last_frame_seconds := 0.0
func _process(delta: float) -> bool:
	last_frame_seconds = maxf(0.0, delta)
	simulated_seconds += last_frame_seconds
	return false
var receipt := {"labels": {}, "snapshots": {}, "comparisons": {}, "saves": {}, "negative_controls": {}}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func click_at(position: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = button; e.pressed = pressed
		e.position = position; e.global_position = position
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	for i in 2: await process_frame
func click(control: Control) -> void: await click_at(control.get_global_rect().get_center())
func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	for i in 2: await process_frame
func cursor(hud, on: bool) -> void:
	if hud.cursor_active != on: await key(KEY_TAB)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + name + ".png")
## Real clicks in the open inventory: the item row, then the named action button.
func inventory_action(area, id: String, action: String) -> bool:
	if not is_instance_valid(area.get("inventory")):
		for i in 3: await process_frame
		await cursor(area.interface_hud, true)
		if not area.interface_hud.sheet.visible or area.interface_hud.atlas.visible: await click(area.interface_hud.buttons[0])
		await click(area.interface_hud.inventory_button)
	if not is_instance_valid(area.get("inventory")): return false
	var inv = area.inventory
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i)) == id:
			var r: Rect2 = inv.item_list.get_item_rect(i)
			await click_at(inv.item_list.get_global_rect().position + r.get_center())
			var button: Button = inv.use_button if action == "use" else inv.equip_button
			if not button.visible or button.disabled: return false
			await click(button)
			return true
	return false
func wait_scene(destination: String) -> Node:
	for i in 900:
		await process_frame
		var scene := current_scene
		if scene != null and is_instance_valid(scene) and scene.scene_file_path == destination and (scene.get("walkthrough_ready") == null or scene.walkthrough_ready): break
	for i in 4: await process_frame
	return current_scene
func hud_agrees(area, tag: String) -> bool:
	var hud = area.interface_hud; var magic = area.starting_magic
	await cursor(hud, true)
	if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
	var text: String = hud.sheet_body.text
	var fighting: Dictionary = magic.fighting_state(); var spell: Dictionary = magic.magic_state().player
	for expected in ["Health: %d / 30" % magic.health(), "Mana: %d / %d" % [int(spell.mana), int(spell.maximum)], "Spell: Healing",
			"Weapon: Stalagmite", "Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)], "Magic: level %d (%d XP)" % [int(spell.level), int(spell.experience)]]:
		if not check(expected in text,"%s HUD lacks '%s': '%s'" % [tag, expected, text]): return false
	if not check(hud.weapon_icon.visible and not hud.hand_icon.visible and hud.magic_icon.texture == hud.spell_textures.heal,"%s Attack/Magic ring disagree with state" % tag): return false
	await shot(tag.to_lower() + "_character")
	hud.close_sheet()
	await cursor(hud, false)
	return true
func save_click(area, name: String) -> bool:
	var hud = area.interface_hud
	var path: String = DIR + name + ".json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	hud.save_path = path
	await cursor(hud, true)
	if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
	var snapshot := Continuity.from_host(area)
	await click(hud.save_button)
	if not check(FileAccess.file_exists(path) and not "failed" in hud.save_status.text,"%s save click '%s'" % [name, hud.save_status.text]): return false
	var bytes := FileAccess.get_file_as_bytes(path)
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	receipt.saves[name] = {"path": path, "sha256": ctx.finish().hex_encode(), "format": JSON.parse_string(bytes.get_string_from_utf8()).get("format"), "snapshot": snapshot}
	hud.close_sheet()
	await cursor(hud, false)
	return true
func compare(name: String, before: Dictionary, after: Dictionary, allowed: Dictionary) -> bool:
	var errors := Continuity.compare(before, after, allowed)
	receipt.comparisons[name] = {"allowed": allowed, "errors": errors}
	return check(errors.is_empty(),"%s continuity: %s" % [name, errors])
func mana_drift(before: Dictionary, departed: float, remainder: float) -> Dictionary:
	# Include both frame endpoints conservatively; never allow arbitrary refill to maximum.
	return Continuity.mana_allowance(int(before["magic.mana"]), int(before["magic.maximum"]), simulated_seconds - departed + 2.0 * last_frame_seconds, remainder)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	receipt.labels = {"earned": ["fighting XP by real Attack Button hits on a cave roach (population owner)", "magic XP by real Spark click on that roach", "Aloe consumed by real inventory clicks", "Stalagmite equipped by real inventory clicks", "Heal selected and cast by real Spell Bar/Magic Button clicks", "Museum->Jungle by real E key at the mirror approach"],
		"supplied": ["2 Aloe + 1 Stalagmite placed in cave owners", "player placed/aimed at the roach and at the mirror approach", "health 14 before the cave Heal", "cave chamber movie skipped; production _enter_museum transfer", "Museum introduction skipped"]}
	# ---------------- Cave ----------------
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	for i in 4: await process_frame
	if not check(is_instance_valid(cave.interface_hud) and cave.roach_population_live != null,"cave HUD/roach population missing"): return
	var hud = cave.interface_hud; var magic = cave.starting_magic
	var aloe1 := Aloe.item_id(Aloe.RECORDS[0], 1); var aloe2 := Aloe.item_id(Aloe.RECORDS[1], 1)
	cave.aloe.collected.append_array([aloe1, aloe2]); cave.stalagmites.collected.append(WEAPON)
	var initial := Continuity.from_host(cave)
	receipt.snapshots.cave_initial = initial
	# Inventory first (population melee needs a weapon): use one Aloe, equip the Stalagmite (real clicks).
	await cursor(hud, true)
	await click(hud.buttons[0])
	await click(hud.inventory_button)
	if not check(is_instance_valid(cave.inventory),"cave inventory did not open"): return
	if not check(await inventory_action(cave, aloe1, "use"),"Use Aloe click"): return
	if not check(await inventory_action(cave, WEAPON, "equip"),"Equip Stalagmite click"): return
	if is_instance_valid(cave.inventory): await key(KEY_ESCAPE)
	# The Aloe heal runs only during play (cursor mode pauses world timers).
	await cursor(hud, false)
	for i in 3600:
		await process_frame
		if int(cave.item_effect_checkpoint.get("aloe", {}).get("pending", 0)) == 0: break
	if not check(aloe1 in cave.item_effect_checkpoint.spent and int(cave.item_effect_checkpoint.aloe.pending) == 0 and cave.equipped_item == WEAPON,"Aloe/equip not applied: %s" % cave.item_effect_checkpoint): return
	for i in 2: await process_frame
	if not check(hud.weapon_icon.visible and not hud.hand_icon.visible,"cave Attack ring did not show the equipped Stalagmite"): return
	# Spark then melee on a live cave roach (population owner), aimed from beside it.
	var pop = cave.roach_population_live
	var targets: Dictionary = pop.targets()
	if not check(not targets.is_empty(),"no live cave roach"): return
	var actor_id := ""
	var body: CharacterBody3D = null
	var aimed := false
	var vantage := Vector3.ZERO
	var standing: Vector3 = cave.player.global_position
	for entry in targets.values():
		if aimed: break
		var candidate: CharacterBody3D = entry.body
		for offset in [Vector3(0,0,40), Vector3(40,0,0), Vector3(0,0,-40), Vector3(-40,0,0), Vector3(28,0,28), Vector3(-28,0,-28), Vector3(28,0,-28), Vector3(-28,0,28)]:
			cave.player.global_position = candidate.global_position + offset
			for i in 3: await physics_frame
			cave.camera.look_at(candidate.global_position + Vector3.UP * 6)
			# Same visibility rule as the population strike (mask 3, player excluded, within reach).
			var query := PhysicsRayQueryParameters3D.create(cave.camera.global_position, candidate.global_position + Vector3.UP * 6, 3, [cave.player.get_rid()])
			query.hit_from_inside = true
			var hit: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(query)
			if (hit.is_empty() or hit.collider == candidate) and cave.camera.global_position.distance_to(candidate.global_position + Vector3.UP * 6) <= 90:
				aimed = true; actor_id = entry.actor; body = candidate; vantage = offset; break
	if not check(aimed,"no clear vantage on cave roach %s" % actor_id): return
	await cursor(hud, true)
	await click(hud.blue_button)
	await click(hud.spell_buttons.spark)
	await click(hud.blue_button)
	var magic_xp0: int = int(magic.magic_state().player.experience)
	cave.camera.look_at(body.global_position + Vector3.UP * 6)
	await click(hud.magic_button)
	for i in 6: await physics_frame
	if not check(int(magic.magic_state().player.experience) > magic_xp0,"Spark click did not earn magic XP (%d)" % int(magic.magic_state().player.experience)): return
	var hits := 0
	for attempt in 16:
		if int(cave.roach_population.actors[actor_id].health) <= 0: break
		await cursor(hud, true)
		cave.camera.look_at(body.global_position + Vector3.UP * 6)
		var before_health: int = int(cave.roach_population.actors[actor_id].health)
		# The roach moves (it fled after the Spark): stand beside it again, as placed above.
		cave.player.global_position = body.global_position + vantage
		for i in 3: await physics_frame
		cave.camera.look_at(body.global_position + Vector3.UP * 6)
		await click(hud.weapon_button)
		for i in 40: await physics_frame
		if int(cave.roach_population.actors[actor_id].health) < before_health: hits += 1
	var fighting: Dictionary = magic.fighting_state()
	if not check(hits > 0 and int(fighting.experience) > 0,"Attack clicks earned no fighting XP (hits %d, xp %d)" % [hits, int(fighting.experience)]): return
	# Back to where the player stood (supplied, like the vantage); no fall recovery may have run.
	cave.player.global_position = standing; cave.player.velocity = Vector3.ZERO
	for i in 30: await physics_frame
	var resets_after_combat: int = int(cave.resets)
	receipt.labels.melee_hits = hits; receipt.labels.roach_actor = actor_id; receipt.labels.roach_defeated = int(cave.roach_population.actors[actor_id].health) <= 0
	# Heal: health 14 supplied, real Spell Bar + Magic clicks.
	magic.set_health(14)
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	await cursor(hud, true)
	if not hud.spell_bar.visible: await click(hud.blue_button)
	await click(hud.spell_buttons.heal)
	await click(hud.blue_button)
	var mana0: int = int(magic.magic_state().player.mana)
	await click(hud.magic_button)
	if not check(magic.health() == 20 and int(magic.magic_state().player.mana) == mana0 - 2,"cave Heal click: %d %d" % [magic.health(), int(magic.magic_state().player.mana)]): return
	await cursor(hud, false)
	if not await hud_agrees(cave, "Cave"): return
	if not await save_click(cave, "cave"): return
	if not check(int(cave.resets) == resets_after_combat,"cave fall recovery ran during the test (resets %d -> %d)" % [resets_after_combat, int(cave.resets)]): return
	var at_cave := Continuity.from_host(cave)
	var cave_departed := simulated_seconds
	var cave_remainder: float = float(cave.starting_magic.magic_state().get("regen_elapsed",0.0))
	receipt.snapshots.cave_departure = at_cave
	for field in ["fighting.experience", "magic.experience", "spent[%s]" % aloe1, "equipped_item", "magic.spell", "health", "magic.mana"]:
		if not check(at_cave.has(field) and at_cave[field] != initial.get(field),"cave state did not change %s (%s -> %s)" % [field, initial.get(field), at_cave.get(field)]): return
	if not check(at_cave.has("collected[%s]" % aloe2) and at_cave.has("collected[%s]" % WEAPON) and not at_cave.has("collected[%s]" % aloe1),"cave carried items after use: %s" % at_cave): return
	# ---------------- Cave -> Museum ----------------
	cave.chamber_arrival_state = "complete"
	cave._enter_museum()
	var museum = await wait_scene("res://scenes/lol2/museum_walkthrough.tscn")
	if not check(museum != null and museum.scene_file_path.ends_with("museum_walkthrough.tscn"),"Museum did not load"): return
	museum.introduction_state = "complete"
	if is_instance_valid(museum.get("introduction")): museum.introduction.close()
	for i in 4: await process_frame
	var at_museum := Continuity.from_host(museum)
	receipt.snapshots.museum_arrival = at_museum
	if not compare("cave_to_museum", at_cave, at_museum, {"magic.mana": mana_drift(at_cave, cave_departed, cave_remainder)}): return
	if not await hud_agrees(museum, "Museum"): return
	# Legitimate Museum change: one Heal by real click.
	magic = museum.starting_magic; hud = museum.interface_hud
	magic.set_health(20)
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	var before_heal := Continuity.from_host(museum)
	await cursor(hud, true)
	await click(hud.magic_button)
	await cursor(hud, false)
	var after_heal := Continuity.from_host(museum)
	if not compare("museum_heal", before_heal, after_heal, {"health": 26, "magic.mana": int(before_heal["magic.mana"]) - 2}): return
	if not await save_click(museum, "museum"): return
	# ---------------- Museum -> Jungle (real E at the mirror approach) ----------------
	var at_departure := Continuity.from_host(museum)
	var museum_departed := simulated_seconds
	var museum_remainder: float = float(museum.starting_magic.magic_state().get("regen_elapsed",0.0))
	receipt.snapshots.museum_departure = at_departure
	museum.player.global_position = Vector3(-4058, museum.player.global_position.y if museum.player.global_position.y >= -4 and museum.player.global_position.y <= 36 else 16, -1381)
	museum.player.rotation.y = 0.0; museum.camera.rotation = Vector3.ZERO
	for i in 3: await physics_frame
	if not check(museum.can_enter_mirror(),"not at the mirror approach %s" % museum.player.global_position): return
	await key(KEY_E)
	var jungle = await wait_scene("res://scenes/lol2/jungle_walkthrough.tscn")
	if not check(jungle != null and jungle.scene_file_path.ends_with("jungle_walkthrough.tscn"),"Jungle did not load"): return
	for i in 4: await process_frame
	var at_jungle := Continuity.from_host(jungle)
	receipt.snapshots.jungle_arrival = at_jungle
	if not compare("museum_to_jungle", at_departure, at_jungle, {"magic.mana": mana_drift(at_departure, museum_departed, museum_remainder)}): return
	var aggregate_start := at_cave.duplicate(true)
	aggregate_start["magic.mana"] = int(at_cave["magic.mana"]) - 2
	if not compare("cave_to_jungle_minus_museum_heal", at_cave, at_jungle, {"health": 26, "magic.mana": mana_drift(aggregate_start, cave_departed, cave_remainder)}): return
	if not await hud_agrees(jungle, "Jungle"): return
	# ---------------- Negative controls (must FAIL) ----------------
	var good := Continuity.from_host(jungle)
	jungle.carried_collected.erase(aloe2)
	var dropped_item := Continuity.compare(good, Continuity.from_host(jungle))
	jungle.carried_collected.append(aloe2)
	jungle.quest_state.player_reward_state.player.experience -= 1
	var dropped_xp := Continuity.compare(good, Continuity.from_host(jungle))
	jungle.quest_state.player_reward_state.player.experience += 1
	var packet: Dictionary = museum_packet_without_fighting(at_departure)
	var dropped_packet := Continuity.compare(at_departure, packet)
	var restored := Continuity.compare(good, Continuity.from_host(jungle))
	receipt.negative_controls = {"dropped_item": dropped_item, "dropped_xp": dropped_xp, "dropped_fighting_packet": dropped_packet, "restored": restored}
	if not check(("collected[%s]: missing after (was 1)" % aloe2) in dropped_item and dropped_item.size() == 1,"item-drop control did not fail as expected: %s" % [dropped_item]): return
	if not check(dropped_xp.size() == 1 and dropped_xp[0].begins_with("fighting.experience:"),"XP-drop control did not fail as expected: %s" % [dropped_xp]): return
	if not check(dropped_packet.size() == 7 and restored.is_empty(),"packet-drop control %s / restore %s" % [dropped_packet, restored]): return
	if not await save_click(jungle, "jungle"): return
	var file := FileAccess.open(DIR + "phase1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ", true))
	file.close()
	print("PASS player_continuity_chain: earned in Cave (melee hits %d, Spark/magic XP, Aloe used, Stalagmite equipped, Heal selected/cast) -> Museum (no diff except mana regen; one explicit Heal) -> Jungle by real E (no diff); HUD Character page/rings agree in all three; saves %s; negative controls fail: item %s, XP %s, fighting packet %d fields." % [hits, receipt.saves.keys(), dropped_item, dropped_xp, dropped_packet.size()])
	quit()

## A handoff snapshot whose fighting packet was lost (as a broken adapter would): every fighting field must be missing.
func museum_packet_without_fighting(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate()
	for key in snapshot:
		if str(key).begins_with("fighting."): result.erase(key)
	return result
