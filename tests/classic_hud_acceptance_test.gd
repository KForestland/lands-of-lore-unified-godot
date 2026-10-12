extends SceneTree
## One HUD, four areas, two window sizes (docs/classic-hud.md), run with --demo-interface on a private display.
## In Cave, Museum, Jungle and Hive at 960x540 and 1280x720, every action below is a REAL viewport click or key event
## through the engine input queue:
## - normal play: one shell, the Blue Button art is drawn (r4 fix), cluster/hint/coordinates do not overlap;
## - Tab enters cursor mode; Blue Button opens the Spell Bar; its Heal/Spark icons load that spell (ring icon follows);
## - Magic Button casts Heal (health +6, mana -2; the health/mana fills follow);
## - portrait opens the one Character page: health, mana, form, spell, weapon/armor, fighting and magic level/XP; the
##   page is on screen and clear of the cluster, hint and coordinates;
## - Save button writes the area's existing save format; health is then changed and the Load button restores it and
##   returns to play in every area; the notice stays on screen;
## - Open inventory is modal (paused): the Magic Button and portrait are refused; Escape closes it;
## - Attack Button returns to play and sends one ordinary attack click;
## - a cursed Beast form hides the weapon (hand shown) and refuses the cast; human form shows the equipped weapon icon.
## Supplied, labelled: Museum introduction complete; Hive rescue-return fixture (conversation completed, as
## classic_hud_actions_test); health/mana/cooldown values; one carried Stalagmite weapon; Beast form assigned directly.
## Screenshots: user://tests/hud_acceptance/<area>_<width>_{play,character}.png
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const WEAPON := "cave:prop641:harvest1:Stalagmite"
var failed := false
var summary: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = button; e.pressed = pressed
		e.position = control.get_global_rect().get_center(); e.global_position = e.position
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	for i in 2: await process_frame
func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	for i in 2: await process_frame
func mana(magic) -> int: return int(magic.magic_state().player.mana)
func overlay_rect() -> Rect2:
	var overlay = root.get_node_or_null("PlaytestLocation")
	if overlay == null or not overlay.label.visible: return Rect2()
	return overlay.label.get_global_rect()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hud_acceptance/%s.png" % name)
func supply_weapon(area) -> void:
	if area.has_method("_completion_state"):
		if WEAPON not in area.stalagmites.collected: area.stalagmites.collected.append(WEAPON)
	elif area.get("carried_inventory") is Dictionary:
		if WEAPON not in area.carried_inventory.collected: area.carried_inventory.collected.append(WEAPON)
	elif WEAPON not in area.carried_collected: area.carried_collected.append(WEAPON)
func enter_cursor(hud) -> void:
	if not hud.cursor_active: await key(KEY_TAB)

func area_acceptance(area, label: String, size: Vector2i) -> bool:
	var tag := "%s %dx%d" % [label, size.x, size.y]
	get_root().size = size
	for i in 6: await process_frame
	var hud = area.interface_hud; var magic = area.starting_magic
	var view: Rect2 = hud.get_viewport().get_visible_rect()
	# ---- normal play ----
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; hud.set_cursor(false)
	if hud.spell_bar.visible: hud.toggle_spell_bar()
	for i in 3: await process_frame
	var shells: Array = area.get_children().filter(func(n): return n is CanvasLayer and n.has_method("refresh_vitals"))
	if not check(shells.size() == 1 and not magic.panel.visible,"%s: shells %d, modern panel %s" % [tag, shells.size(), magic.panel.visible]): return false
	if not check(hud.blue_icon.is_visible_in_tree() and hud.blue_icon.texture != null and hud.blue_button.icon == null and view.encloses(hud.blue_icon.get_global_rect()),"%s: Blue Button art not drawn" % tag): return false
	var cluster: Rect2 = hud.cluster.get_global_rect(); var coords := overlay_rect()
	if not check(view.encloses(cluster) and not cluster.intersects(hud.hint.get_global_rect()) and (not coords.has_area() or not coords.intersects(cluster)),"%s: cluster placement/overlap" % tag): return false
	await shot("%s_%d_play" % [label.to_lower(), size.x])
	# ---- Tab, Spell Bar, spell selection ----
	await key(KEY_TAB)
	if not check(hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"%s: Tab did not enter cursor mode" % tag): return false
	await click(hud.blue_button)
	if not check(hud.spell_bar.visible and hud.blue_icon.texture != null,"%s: Blue Button did not open the Spell Bar" % tag): return false
	if not check(view.encloses(hud.spell_bar.get_global_rect()) and not hud.spell_bar.get_global_rect().intersects(hud.hint.get_global_rect()),"%s: Spell Bar off screen or over the hint %s" % [tag, hud.spell_bar.get_global_rect()]): return false
	await click(hud.spell_buttons.spark)
	if not check(hud.loaded_spell() == "spark" and hud.magic_icon.texture == hud.spell_textures.spark,"%s: Spark icon click" % tag): return false
	await click(hud.spell_buttons.heal)
	if not check(hud.loaded_spell() == "heal" and hud.magic_icon.texture == hud.spell_textures.heal,"%s: Heal icon click" % tag): return false
	await click(hud.blue_button)
	if not check(not hud.spell_bar.visible,"%s: Blue Button did not close the Spell Bar" % tag): return false
	# ---- Heal by Magic Button ----
	magic.set_health(15)
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.player.mana = 10; saved.cooldown = 0.0; magic.commit(saved)
	await click(hud.magic_button)
	var maximum: int = int(magic.magic_state().player.maximum)
	if not check(magic.health() == 21 and mana(magic) == 8,"%s: GUI Heal health %d mana %d" % [tag, magic.health(), mana(magic)]): return false
	var k: float = float(hud.hud_source.scale)
	if not check(is_equal_approx(hud.health_fill.size.x, 39.0 * k * 21.0 / 30.0) and is_equal_approx(hud.mana_fill.size.x, 25.0 * k * 8.0 / float(maximum)),"%s: fills %s %s" % [tag, hud.health_fill.size.x, hud.mana_fill.size.x]): return false
	# ---- Character page (portrait) ----
	await click(hud.buttons[0])
	var text: String = hud.sheet_body.text
	var fighting: Dictionary = magic.fighting_state(); var spell: Dictionary = magic.magic_state().player
	for expected in ["Health: 21 / 30", "Mana: 8 / %d" % maximum, "Spell: Healing", "Form: Human", "Weapon: ", "Armor: ",
			"Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)], "Magic: level %d (%d XP)" % [int(spell.level), int(spell.experience)]]:
		if not check(hud.sheet.visible and expected in text,"%s: Character page lacks '%s': '%s'" % [tag, expected, text]): return false
	var sheet: Rect2 = hud.sheet.get_global_rect()
	if not check(view.encloses(sheet) and not sheet.intersects(hud.cluster.get_global_rect()) and not sheet.intersects(hud.hint.get_global_rect()) and (not coords.has_area() or not sheet.intersects(coords)),"%s: Character page %s overlaps/off screen" % [tag, sheet]): return false
	if area.has_node("Warriors"):
		var hl: String = area.get_node("Warriors").label.text
		if not check(not "Left click" in hl and not hl.begins_with("Health"),"%s: Hive modern health label '%s'" % [tag, hl]): return false
	if label == "Cave":
		if not check(text.count("Form: ") == 1,"%s: form shown %d times" % [tag, text.count("Form: ")]): return false
	await shot("%s_%d_character" % [label.to_lower(), size.x])
	# Atlas page (compass) obeys the same on-screen rule, then back to the Character page.
	await click(hud.buttons[1])
	sheet = hud.sheet.get_global_rect()
	if not check(hud.atlas.visible and view.encloses(sheet) and not sheet.intersects(hud.cluster.get_global_rect()) and not sheet.intersects(hud.hint.get_global_rect()) and (not coords.has_area() or not sheet.intersects(coords)),"%s: Atlas page %s overlaps/off screen" % [tag, sheet]): return false
	await click(hud.buttons[0])
	# ---- Save / Load buttons ----
	var path := "user://tests/hud_acceptance/%s_%d_save.json" % [label.to_lower(), size.x]
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	hud.save_path = path
	var before := Continuity.from_host(area)
	await click(hud.save_button)
	if not check(FileAccess.file_exists(path) and not "failed" in hud.save_status.text,"%s: Save click '%s'" % [tag, hud.save_status.text]): return false
	var format = JSON.parse_string(FileAccess.get_file_as_string(path)).get("format")
	if not check(view.encloses(hud.hint.get_global_rect()) and hud.hint.text == hud.save_status.text,"%s: save notice hidden '%s'" % [tag, hud.hint.text]): return false
	magic.set_health(9)
	if not hud.cursor_active: await enter_cursor(hud)
	if not hud.sheet.visible: await click(hud.buttons[0])
	await click(hud.load_button)
	var after := Continuity.from_host(area)
	var diff := Continuity.compare(before, after)
	if not check(magic.health() == 21 and diff.is_empty() and not "failed" in hud.hint.text,"%s: Load click health %d diff %s '%s'" % [tag, magic.health(), diff, hud.hint.text]): return false
	if not check(not hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"%s: Load did not return to play" % tag): return false
	# ---- Inventory modal ----
	await enter_cursor(hud)
	if not hud.sheet.visible: await click(hud.buttons[0])
	await click(hud.inventory_button)
	if not check(is_instance_valid(area.get("inventory")) and paused,"%s: Open inventory click" % tag): return false
	var h: int = magic.health(); var m: int = mana(magic)
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	await click(hud.magic_button)
	await click(hud.buttons[0])
	if not check(magic.health() == h and mana(magic) == m and not hud.sheet.visible,"%s: cast or page through the inventory modal" % tag): return false
	await key(KEY_ESCAPE)
	for i in 2: await process_frame
	if not check(not is_instance_valid(area.get("inventory")) and not paused,"%s: Escape did not close the inventory" % tag): return false
	# ---- Equipment and form on the Attack ring ----
	supply_weapon(area)
	if not check(area.set_equipped_item(WEAPON),"%s: equip supplied weapon" % tag): return false
	for i in 2: await process_frame
	if not check(hud.weapon_icon.visible and not hud.hand_icon.visible,"%s: equipped weapon not on the Attack ring" % tag): return false
	var form: int = int(area.player_form)
	area.player_form = 1
	for i in 2: await process_frame
	await enter_cursor(hud)
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; saved.player.mana = 10; magic.commit(saved); magic.set_health(15)
	await click(hud.magic_button)
	if not check(not hud.weapon_icon.visible and hud.hand_icon.visible and magic.health() == 15 and mana(magic) == 10,"%s: Beast form weapon/cast restriction" % tag): return false
	if not hud.sheet.visible: await click(hud.buttons[0])
	if not check("stored while transformed" in hud.sheet_body.text,"%s: Beast form page '%s'" % [tag, hud.sheet_body.text]): return false
	area.player_form = form
	for i in 2: await process_frame
	area.set_equipped_item("")
	# ---- Attack Button ----
	await enter_cursor(hud)
	if hud.sheet.visible: hud.close_sheet()
	var requests: int = hud.attack_requests
	await click(hud.weapon_button)
	if not check(hud.attack_requests == requests + 1 and not hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"%s: Attack click" % tag): return false
	magic.select_spell("spark")
	summary.append("%s save format %s" % [tag, format])
	return true

func open(path: String):
	var area = load(path).instantiate()
	root.add_child(area); current_scene = area
	for i in range(600):
		await process_frame
		if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
	for i in 4: await process_frame
	area.set_physics_process(false)
	if area.has_method("set_development_mode") and path.find("cave") < 0: area.set_development_mode(false)
	if area.get("introduction_state") != null:
		area.introduction_state = "complete"
		if is_instance_valid(area.get("introduction")): area.introduction.close()
	if area.has_node("Warriors"):
		var fixture: Dictionary = area.area_handoff()
		fixture.quests.shared_flag_38 = 1; fixture.quests.hive_room_entered = true
		fixture.quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
		if not check(area.apply_area_handoff(fixture).is_empty(),"Hive return fixture"): return null
		area.set_physics_process(false)
		area.return_population.set_physics_process(false)
	await process_frame
	return area

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests/hud_acceptance")
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	for entry in [["Cave","res://scenes/lol2/cave_walkthrough.tscn"],["Museum","res://scenes/lol2/museum_walkthrough.tscn"],["Jungle","res://scenes/lol2/jungle_walkthrough.tscn"],["Hive","res://scenes/lol2/hive_review.tscn"]]:
		var area = await open(entry[1])
		if area == null or not check(is_instance_valid(area.get("interface_hud")),"%s: no classic shell" % entry[0]): return
		for size in [Vector2i(960,540), Vector2i(1280,720)]:
			if not await area_acceptance(area, entry[0], size): return
		area.queue_free(); await process_frame; await process_frame
	remove_meta("lol2_cave_completion")
	get_root().size = Vector2i(1280,720)
	print("PASS classic_hud_acceptance: Cave/Museum/Jungle/Hive at 960x540 and 1280x720 with real clicks/keys — Blue Button drawn, Spell Bar Heal/Spark selection, Magic Heal +6/-2 with fills, one Character page with health/mana/form/spell/equipment/fighting+magic level/XP on screen without overlap, Save/Load buttons round-trip (no semantic diff), inventory modal refuses cast/page and Escape closes it, equipped weapon and Beast restriction on the Attack ring, Attack click returns to play. " + "; ".join(summary))
	quit()
