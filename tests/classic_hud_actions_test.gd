extends SceneTree
## HUD actions with real viewport clicks on the private display (docs/classic-hud.md):
## - Magic Button (Museum host): in cursor mode a real left click casts the loaded Heal. Health +6 and mana -2, then
##   the cooldown refuses a second click. Refused: while paused, while dead (health 0), while the inventory is open
##   (modal), and outside cursor mode (button disabled). Each refusal leaves health and mana unchanged.
## - Attack Button (Hive host, return warrior27): a real click returns to play and delivers one ordinary left click,
##   so the existing hive_warriors.strike dispatch lands a normal hit. Refused while paused.
## Supplied state, labelled: Museum introduction completed; Hive rescue-return fixture and vantage as
## net_exile_onhit_hive_test; health/mana values assigned. The click routes are real.
const Shell = preload("res://scripts/lol2/museum_interface.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func click(control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = button; e.pressed = pressed
		e.position = control.get_global_rect().get_center()
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await process_frame
func mana(magic) -> int: return int(magic.magic_state().player.mana)
func run() -> void:
	# ---- Magic Button heal (Museum) ----
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in 8: await process_frame
	if is_instance_valid(museum.get("introduction")): museum.introduction.close()
	await process_frame
	var hud = museum.interface_hud; var magic = museum.starting_magic
	magic.set_process(false)
	hud.load_spell("heal")
	magic.set_health(20)
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.player.mana = 10; saved.cooldown = 0.0; magic.commit(saved)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; hud.set_cursor(false); await process_frame
	await click(hud.magic_button)
	if not check(magic.health() == 20 and mana(magic) == 10,"Disabled Magic Button cast outside cursor mode"): return
	hud.set_cursor(true); await process_frame
	await click(hud.magic_button)
	if not check(magic.health() == 26 and mana(magic) == 8,"GUI Heal: health %d mana %d" % [magic.health(), mana(magic)]): return
	for i in 20: await process_frame
	if not check(hud.cursor_active and hud.hint.text == "Healing" and hud.hint.is_visible_in_tree(),"GUI cast feedback not visible in cursor mode: '%s'" % hud.hint.text): return
	await click(hud.magic_button)
	if not check(magic.health() == 26 and mana(magic) == 8,"Cooldown did not refuse the second click"): return
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	magic.set_health(20)
	paused = true
	await click(hud.magic_button)
	paused = false
	if not check(magic.health() == 20 and mana(magic) == 8,"Paused GUI cast"): return
	magic.set_health(0)
	await click(hud.magic_button)
	if not check(magic.health() == 0 and mana(magic) == 8,"Dead GUI cast"): return
	magic.set_health(20)
	if not check(museum.open_inventory() and paused,"Inventory modal"): return
	await click(hud.magic_button)
	if not check(magic.health() == 20 and mana(magic) == 8,"Cast through the inventory modal"): return
	museum.inventory.close(); await process_frame; await process_frame
	paused = false; hud.set_cursor(true); await process_frame
	await click(hud.magic_button)
	if not check(magic.health() == 26 and mana(magic) == 6,"Heal after the modal closed: %d %d" % [magic.health(), mana(magic)]): return
	# A save/area notice keeps priority over the cast feedback.
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; magic.commit(saved)
	magic.set_health(20)
	hud.hint.text = "Museum saved."; hud.save_notice_remaining = 3.0
	await click(hud.magic_button)
	if not check(magic.health() == 26 and hud.hint.text == "Museum saved.","Cast feedback overrode the save notice: '%s'" % hud.hint.text): return
	museum.queue_free(); await process_frame; await process_frame
	remove_meta("lol2_cave_completion")
	# ---- Attack Button hit (Hive) ----
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	await process_frame; await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false); scene.curse.set_physics_process(false); scene.hive_curse.set_physics_process(false)
	var guards = scene.get_node("Warriors"); guards.set_process(false)
	var pop = scene.return_population; pop.set_physics_process(false)
	scene.starting_magic.set_process(false); scene.item_effects.set_process(false)
	var fixture: Dictionary = scene.area_handoff()
	fixture.quests.shared_flag_38 = 1; fixture.quests.hive_room_entered = true
	fixture.quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	if not check(scene.apply_area_handoff(fixture).is_empty() and pop.targets().size() == 3,"Hive return fixture"): return
	scene.set_physics_process(false)
	var target: CharacterBody3D = pop.bodies["27"]
	var clear := false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for offset in [Vector3(0,32,65),Vector3(0,32,-65),Vector3(65,32,0),Vector3(-65,32,0)]:
		scene.player.position = pop.State.SPAWNS[27] + offset
		scene.camera.look_at(target.global_position)
		for i in range(2): await physics_frame
		var hit: Dictionary = guards.aimed_hit()
		if not hit.is_empty() and hit.collider == target: clear = true; break
	if not check(clear,"No warrior vantage"): return
	var ihud = scene.interface_hud
	var a: Dictionary = pop.state.actors["27"]
	var health: int = int(a.health)
	guards.cooldown = 0.0
	ihud.set_cursor(true); await process_frame
	paused = true
	await click(ihud.weapon_button)
	paused = false
	for i in 3: await process_frame
	if not check(int(a.health) == health and ihud.attack_requests == 0,"Paused attack landed"): return
	ihud.set_cursor(true); await process_frame
	guards.cooldown = 0.0
	await click(ihud.weapon_button)
	for i in 4: await process_frame
	if not check(ihud.attack_requests == 1 and int(a.health) < health and not ihud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"GUI attack: requests %d health %d -> %d" % [ihud.attack_requests, health, int(a.health)]): return
	scene.queue_free(); await process_frame
	print("PASS classic_hud_actions: real-click Magic Heal +6 health/-2 mana with visible 'Healing' feedback in cursor mode (save notice keeps priority), cooldown/paused/dead/modal/disabled refusals unchanged; real-click Attack Button -> one ordinary left click -> existing Hive strike dispatch hits warrior27; paused attack refused.")
	quit()
