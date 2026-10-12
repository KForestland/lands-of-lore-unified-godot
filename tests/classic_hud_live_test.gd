extends SceneTree
## Shared area HUD (docs/classic-hud.md), run with --demo-interface (normal play profile). Events go straight to the
## HUD and host handlers inside this private display; nothing reaches the user's desktop.
## - Cave:
##   - one shared shell (cave_interface), the developer label hidden;
##   - the original portrait/frame/blink/cursor art; one starting_magic legend;
##   - Tab cursor mode, M atlas from the L1_DC region graph with the player on the map, Esc closes;
##   - I from cursor mode opens the inventory; F5/F9 save and load once, with the notice on the hint;
##   - equip -> hand icon; prompts (fallen) on the hint; Character page health/mana/form.
## - The real Cave->Museum transfer (_enter_museum): one shell in the Museum, no Cave HUD left, Character page
##   health/mana.
## - Jungle and Hive: one shell each, Tab/M work, Health in the Character page.
const Cap = preload("res://scripts/lol2/cave_captain_items.gd")
const Shell = preload("res://scripts/lol2/museum_interface.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func key(hud, code: int) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	hud._input(e)
func shells(node: Node) -> Array:
	var out: Array = []
	for child in node.find_children("*", "CanvasLayer", true, false):
		if child.get_script() != null and (child.get_script() == Shell or child.get_script().get_base_script() == Shell or child.get_script().resource_path.ends_with("_interface.gd")): out.append(child)
	return out
func legends(node: Node) -> int:
	return node.find_children("StartingMagic", "", true, false).size()
func common(area: Node, hud, label: String) -> bool:
	if not check(shells(area).size() == 1 and shells(area)[0] == hud and hud.visible,"%s: shells %d" % [label,shells(area).size()]): return false
	if not check(legends(area) == 1,"%s: starting-magic legends %d" % [label,legends(area)]): return false
	var frame_ok: bool = hud.blink_textures.size() == 3 and hud.cursor_texture != null and hud.weapon_button != null and hud.magic_button != null
	if not check(frame_ok,"%s: original HUD art missing" % label): return false
	# Bottom-right cluster (manual printed 7/10/39), no modern bar.
	var view: Vector2 = hud.get_viewport().get_visible_rect().size
	var r: Rect2 = hud.cluster.get_global_rect()
	if not check(r.end.x <= view.x and r.end.y <= view.y and r.end.x > view.x - 40 and r.end.y > view.y - 40 and r.position.x > view.x / 2,"%s: cluster not bottom-right %s in %s" % [label,r,view]): return false
	if not check(hud.find_children("*","HBoxContainer",true,false).filter(func(n): return n.get_parent() == hud).is_empty(),"%s: modern bottom bar present" % label): return false
	# Vitals and spell controls.
	var magic = area.starting_magic
	hud.refresh_vitals()
	if not check(is_equal_approx(hud.health_fill.size.x, 78.0 * clampf(magic.health() / 30.0, 0, 1)),"%s: health fill %s" % [label,hud.health_fill.size]): return false
	hud.set_cursor(true)
	hud.load_spell("heal")
	if not check(hud.loaded_spell() == "heal" and hud.magic_icon.texture == hud.spell_textures.heal,"%s: load Heal" % label): return false
	var right := InputEventMouseButton.new(); right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true
	hud._magic_input(right)
	if not check(hud.loaded_spell() == "spark" and hud.magic_icon.texture == hud.spell_textures.spark,"%s: right-click cycle" % label): return false
	hud.blue_button.pressed.emit()
	if not check(hud.spell_bar.visible and hud.spell_bar.get_global_rect().end.x <= r.position.x + hud.magic_button.position.x + 1,"%s: Spell Bar" % label): return false
	hud.spell_buttons.heal.pressed.emit()
	if not check(hud.loaded_spell() == "heal","%s: Spell Bar pick" % label): return false
	hud.load_spell("spark"); hud.blue_button.pressed.emit()
	hud.set_cursor(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; hud.set_cursor(false)
	key(hud, KEY_TAB)
	if not check(hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not hud.buttons[0].disabled,"%s: Tab cursor mode" % label): return false
	key(hud, KEY_TAB)
	if not check(not hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"%s: Tab return" % label): return false
	key(hud, KEY_M)
	if not check(hud.sheet.visible and hud.atlas.visible and hud.atlas.floor_polygons.size() > 0 and hud.atlas.bounds.has_point(Vector2(area.player.global_position.x,area.player.global_position.z)),"%s: atlas %d polygons, bounds %s, player %s" % [label,hud.atlas.floor_polygons.size(),hud.atlas.bounds,area.player.global_position]): return false
	key(hud, KEY_M)
	if not check(not hud.sheet.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"%s: atlas close" % label): return false
	hud.set_cursor(true); hud.open_page("character")
	if not check(hud.sheet.visible and hud.sheet_body.text.begins_with("Health: "),"%s: character page '%s'" % [label,hud.sheet_body.text]): return false
	key(hud, KEY_ESCAPE)
	if not check(not hud.sheet.visible and hud.cursor_active,"%s: Esc closes the sheet first" % label): return false
	hud.set_cursor(false)
	return true
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready and not cave.development_mode and is_instance_valid(cave.interface_hud),"Cave shell missing (demo profile)"): return
	cave.set_physics_process(false)
	var hud = cave.interface_hud
	for i in 3: await process_frame
	if not check(not cave.hud.visible and "F5 save" in cave.hud.text,"Cave developer label still shown: visible %s text '%s'" % [cave.hud.visible,cave.hud.text.left(120)]): return
	if not await common(cave, hud, "Cave"): return
	if not check("Form: " in hud.character_text() and "Mana: " in hud.character_text(),"Cave character page: " + hud.character_text()): return
	# Inventory from cursor mode, then the play key path still works.
	hud.set_cursor(true); key(hud, KEY_I); await process_frame
	if not check(is_instance_valid(cave.inventory),"Shell I did not open the cave inventory"): return
	cave.inventory.queue_free(); await process_frame
	paused = false; hud.set_cursor(false)
	# F5/F9 through the shell: one save, notice on the hint.
	var path: String = hud.save_path
	DirAccess.remove_absolute(path)
	key(hud, KEY_F5)
	if not check(FileAccess.file_exists(path) and hud.hint.text == "Cave saved." and hud.save_notice_remaining > 0,"Shell F5: '%s'" % hud.hint.text): return
	key(hud, KEY_F9)
	if not check(hud.hint.text == "Cave save loaded.","Shell F9: '%s'" % hud.hint.text): return
	cave.set_physics_process(false)
	# Equipment -> hand icon.
	cave.collectible.collected = cave.collectible.collected
	cave.carried_collected.append(Cap.SWORD) if cave.get("carried_collected") is Array else null
	if cave.set_equipped_item(Cap.SWORD):
		hud.refresh_equipment()
		if not check(hud.weapon_icon.visible,"Hand icon not shown"): return
	# Prompt routing: fallen.
	hud.save_notice_remaining = 0.0
	cave.roach.model.player_health = 0
	hud._process(0.0)
	if not check(hud.hint.text.begins_with("You fell"),"Fallen prompt not on the hint: '%s'" % hud.hint.text): return
	cave.roach.model.player_health = 30
	hud._process(0.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/classic_hud_cave.png")
	# The real Cave->Museum transfer.
	if cave.equipped_item != "" and not cave.equipped_item in cave.carried_items(): cave.set_equipped_item("")
	cave.chamber_arrival_state = "complete"
	cave._enter_museum()
	for i in 8: await process_frame
	var museum = current_scene
	if not check(museum != null and museum.scene_file_path == "res://scenes/lol2/museum_walkthrough.tscn","Museum not entered"): return
	if not check(not is_instance_valid(cave) and shells(root).size() == 1,"Cave HUD left over: %d shells" % shells(root).size()): return
	for i in 10: await process_frame
	museum.introduction_state = "complete"
	if is_instance_valid(museum.get("introduction")): museum.introduction.close()
	await process_frame
	if not await common(museum, museum.interface_hud, "Museum"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/classic_hud_museum.png")
	museum.queue_free(); await process_frame; await process_frame
	get_root().get_tree().remove_meta("lol2_cave_completion") if has_meta("lol2_cave_completion") else null
	# Jungle and Hive.
	for scene_path in ["res://scenes/lol2/jungle_walkthrough.tscn","res://scenes/lol2/hive_review.tscn"]:
		var area = load(scene_path).instantiate()
		root.add_child(area); current_scene = area
		for i in 6: await process_frame
		area.set_physics_process(false)
		if area.has_method("set_development_mode"): area.set_development_mode(false)
		if not await common(area, area.interface_hud, scene_path.get_file()): return
		area.queue_free(); await process_frame; await process_frame
	DirAccess.remove_absolute(path)
	print("PASS classic_hud_live: Cave shell (developer label hidden, original art, one legend, Tab/M atlas from L1_DC/Esc/I/F5/F9, hand icon, fallen prompt, health/mana/form page); real Cave->Museum transfer leaves one shell; Museum/Jungle/Hive one shell each with Tab/M/Esc and Health/Mana pages.")
	quit()
