extends "res://tests/player_continuity_restart_test.gd"
## Jungle -> Hive -> Jungle continuity, travel phase (matrix case 2; docs/player-continuity.md). Run with
## --demo-interface and LOL2_EARNED_SAVES=<R13 campaign saves dir>; player_continuity_hive_restart_test follows in a
## NEW process.
## START: the R13 earned Jungle save act1_broken_museum_jungle.json (earned by the lead's R13 chain driver, legs 01-02),
## loaded with a real HUD Load click.
## EARNED here with real clicks: one Heal in the Jungle and one in the Hive (Spell Bar + Magic Button).
## Travel is the production HiveRoute: the player is placed inside each verified trigger polygon (SUPPLIED position)
## and gravity/physics trigger the route, as hive_route_test does. No movie or fixture is involved. Hive health is
## lowered by 6 before its Heal (SUPPLIED) so the cast has room.
## Each crossing is compared with player_continuity.gd: only the explicit Heal deltas and time-bounded mana
## regeneration are allowed. Each area is saved with the HUD Save button. A negative control drops one carried item and
## one fighting XP from the live Hive state; both must fail.
const SAVE := "act1_broken_museum_jungle.json"
const JUNGLE := "res://scenes/lol2/jungle_walkthrough.tscn"
const HIVE := "res://scenes/lol2/hive_review.tscn"
func walk_route(area, destination: String) -> Node:
	var route = area.get_node("HiveRoute")
	for i in 3: await physics_frame
	var center := Vector2.ZERO
	for point in route.route.polygon: center += Vector2(point[0], point[1]) / route.route.polygon.size()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; area.interface_hud.set_cursor(false)
	area.player.position = Vector3(center.x, route.route.floor + 34, center.y)
	for i in 600:
		await physics_frame
		var scene := current_scene
		if is_instance_valid(scene) and scene.scene_file_path == destination and scene.has_node("HiveRoute"): break
	for i in 30: await physics_frame
	return current_scene
func heal_click(area) -> Dictionary:
	var hud = area.interface_hud; var magic = area.starting_magic
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	var before := Continuity.from_host(area)
	await cursor(hud, true)
	if not hud.spell_bar.visible: await click(hud.blue_button)
	await click(hud.spell_buttons.heal)
	await click(hud.blue_button)
	await click(hud.magic_button)
	await cursor(hud, false)
	return {"before": before, "after": Continuity.from_host(area), "cast": magic.health() > int(before.get("health", 0))}
func agrees(area, tag: String) -> bool:
	var hud = area.interface_hud; var magic = area.starting_magic
	await cursor(hud, true)
	if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
	var text: String = hud.sheet_body.text
	var fighting: Dictionary = magic.fighting_state(); var spell: Dictionary = magic.magic_state().player
	for expected in ["Health: %d / 30" % magic.health(), "Mana: %d / %d" % [int(spell.mana), int(spell.maximum)],
			"Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)], "Magic: level %d (%d XP)" % [int(spell.level), int(spell.experience)]]:
		if not check(expected in text,"%s HUD lacks '%s': '%s'" % [tag, expected, text]): return false
	await shot("hive_return_" + tag.to_lower())
	hud.close_sheet()
	await cursor(hud, false)
	return true
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var earned := OS.get_environment("LOL2_EARNED_SAVES")
	if not check(not earned.is_empty() and FileAccess.file_exists(earned.path_join(SAVE)),"LOL2_EARNED_SAVES with %s required" % SAVE): return
	var bytes := FileAccess.get_file_as_bytes(earned.path_join(SAVE))
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	var start_copy := DIR + "hive_start_" + SAVE
	var out := FileAccess.open(start_copy, FileAccess.WRITE); out.store_buffer(bytes); out.close()
	receipt.labels = {"start": {"save": SAVE, "sha256": ctx.finish().hex_encode(), "origin": "R13 chain driver legs 01-02 (earned saves, loaded not re-earned)"},
		"earned_here": ["Heal by real Spell Bar/Magic Button clicks in Jungle and in Hive", "save/load by real HUD buttons"],
		"supplied": ["player placed inside each verified HiveRoute trigger polygon; physics triggers the route", "Hive health lowered by 6 before its Heal so the cast has room"]}
	# ---- Jungle, from the earned save ----
	var jungle = await open_fresh(JUNGLE)
	if not await load_click(jungle, start_copy): return
	var loaded := Continuity.from_host(jungle)
	if not check(Continuity.compare(Continuity.from_save(JSON.parse_string(bytes.get_string_from_utf8())), loaded).is_empty(),"earned save did not load exactly"): return
	var heal := await heal_click(jungle)
	if not check(heal.cast,"Jungle Heal click did not cast"): return
	if not compare("jungle_heal", heal.before, heal.after, {"health": int(heal.before.health) + 6, "magic.mana": int(heal.before["magic.mana"]) - 2, "magic.spell": "heal"} if heal.before.get("magic.spell") != "heal" else {"health": int(heal.before.health) + 6, "magic.mana": int(heal.before["magic.mana"]) - 2}): return
	if not await agrees(jungle, "Jungle"): return
	var at_jungle := Continuity.from_host(jungle)
	var remainder: float = float(jungle.starting_magic.magic_state().get("regen_elapsed", 0.0))
	var departed := simulated_seconds
	receipt.snapshots.jungle_departure = at_jungle
	# ---- Jungle -> Hive (production route) ----
	var hive = await walk_route(jungle, HIVE)
	if not check(hive != null and hive.scene_file_path == HIVE,"Hive route did not load the Hive"): return
	var at_hive := Continuity.from_host(hive)
	receipt.snapshots.hive_arrival = at_hive
	if not compare("jungle_to_hive", at_jungle, at_hive, {"magic.mana": mana_drift(at_jungle, departed, remainder)}): return
	if not await agrees(hive, "Hive"): return
	# Negative controls on live Hive state (must fail), then restore.
	var item: String = str(hive.carried_inventory.collected[0])
	hive.carried_inventory.collected.erase(item)
	var dropped_item := Continuity.compare(at_hive, Continuity.from_host(hive))
	hive.carried_inventory.collected.insert(0, item)
	hive.player_reward_checkpoint.player.experience -= 1
	var dropped_xp := Continuity.compare(at_hive, Continuity.from_host(hive))
	hive.player_reward_checkpoint.player.experience += 1
	var restored := Continuity.compare(at_hive, Continuity.from_host(hive), {"magic.mana": mana_drift(at_hive, simulated_seconds, 0.0)})
	receipt.negative_controls = {"dropped_item": dropped_item, "dropped_xp": dropped_xp, "restored": restored}
	if not check(dropped_item.size() == 1 and dropped_item[0].begins_with("collected[%s]" % item),"Hive item-drop control: %s" % [dropped_item]): return
	if not check(dropped_xp.size() == 1 and dropped_xp[0].begins_with("fighting.experience:"),"Hive XP-drop control: %s" % [dropped_xp]): return
	if not check(restored.is_empty(),"Hive restore after controls: %s" % [restored]): return
	# Legitimate Hive change: one Heal.
	hive.starting_magic.set_health(maxi(1, hive.starting_magic.health() - 6))
	var hive_heal := await heal_click(hive)
	if not check(hive_heal.cast,"Hive Heal click did not cast"): return
	if not compare("hive_heal", hive_heal.before, hive_heal.after, {"health": int(hive_heal.before.health) + 6, "magic.mana": int(hive_heal.before["magic.mana"]) - 2}): return
	if not await save_click(hive, "hive_return_hive"): return
	var at_hive_departure := Continuity.from_host(hive)
	remainder = float(hive.starting_magic.magic_state().get("regen_elapsed", 0.0))
	departed = simulated_seconds
	receipt.snapshots.hive_departure = at_hive_departure
	# ---- Hive -> Jungle (production route) ----
	var back = await walk_route(hive, JUNGLE)
	if not check(back != null and back.scene_file_path == JUNGLE,"Hive route did not return to the Jungle"): return
	var at_return := Continuity.from_host(back)
	receipt.snapshots.jungle_return = at_return
	if not compare("hive_to_jungle", at_hive_departure, at_return, {"magic.mana": mana_drift(at_hive_departure, departed, remainder)}): return
	if not await agrees(back, "Jungle_return"): return
	if not await save_click(back, "hive_return_jungle"): return
	var file := FileAccess.open(DIR + "hive_return_phase1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ", true)); file.close()
	print("PASS player_continuity_hive_return: R13 earned Jungle save -> Heal click -> Jungle->Hive by HiveRoute (no diff beyond time-bounded regen) -> Hive Heal click -> Hive->Jungle (no diff); HUD agrees in each; Hive saves; negative controls fail: %s / %s." % [dropped_item, dropped_xp])
	quit()
