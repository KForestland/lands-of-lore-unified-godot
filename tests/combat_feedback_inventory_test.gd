extends SceneTree
## Playtest fixes 2026-10-14 (Cave with the classic HUD, --demo-interface):
## - every captured world left click shows the swing icon and plays the Attack ring animation (classic_interface pack);
## - a melee owner reporting a landed hit (combat_feedback.landed) shows the ring splash; an unarmed human hand strike
##   lands on a cave roach (4 damage) and reports the hit;
## - Spark shows a projectile on the effects overlay layer (Cave main camera draws nothing) and the Magic ring animation;
## - refused casts say why (full health, not enough mana); a successful Healing shows the golden pulse and keeps the
##   exact "Healing" notice;
## - the classic inventory: 4-column grid, double-click equips, clicking the worn weapon slot unequips, a drop on the
##   weapon slot equips, a drop of a non-weapon on it is refused.
var failed := false
const Feedback := preload("res://scripts/lol2/combat_feedback.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func frames(n: int) -> void:
	for i in n: await process_frame
func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	event.position = Vector2(480, 270)
	Input.parse_input_event(event)
func run() -> void:
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	var area = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(area); current_scene = area
	for i in range(600):
		await process_frame
		if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
	await frames(6)
	var hud = area.interface_hud
	if not check(is_instance_valid(hud) and is_instance_valid(hud.attack_swing), "No classic HUD swing feedback"): return
	var swing = hud.attack_swing
	if not check(swing.attack_frames.size() == 6 and swing.magic_frames.size() == 6, "classic_interface ring frames not loaded"): return
	# Swing on a captured world click.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; hud.set_cursor(false)
	click(true); await frames(1); click(false)
	if not check(swing.icon.visible and swing.attack_anim.visible, "Swing icon/ring animation not shown"): return
	# No swing in interface cursor mode.
	await frames(30); hud.set_cursor(true)
	swing.icon.visible = false
	click(true); await frames(1); click(false)
	if not check(not swing.icon.visible, "Swing shown in cursor mode"): return
	hud.set_cursor(false); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Landed report -> ring splash.
	swing.swing(hud.hand_icon.texture)
	Feedback.landed(true)
	await frames(2)
	if not check(swing.ring_flash.modulate.a > 0.0, "Landed hit did not splash the Attack ring"): return
	# Unarmed human hand strike on a cave roach lands and reports.
	var live = area.get("roach_population_live")
	if live != null:
		area.equipped_item = ""; area.player_form = 0
		var State = preload("res://scripts/lol2/cave_roach_population_state.gd")
		area.roach_population = State.initial(); live.restore(); await frames(2)
		# Same unobstructed approach search as cave_roach_population_live_test (source actor40, not moved).
		var id := "40"
		var body: CharacterBody3D = live.bodies[id]
		var target: Vector3 = body.global_position + Vector3(0, 6, 0)
		var aimed := false
		area.set_physics_process(false)
		for offset in [Vector3(0,20,45), Vector3(0,20,-45), Vector3(45,20,0), Vector3(-45,20,0), Vector3(0,40,0.1)]:
			area.player.position = target + offset - area.camera.position
			area.camera.look_at(target)
			for i in 2: await physics_frame
			var query := PhysicsRayQueryParameters3D.create(area.camera.global_position, target, 3, [area.player.get_rid()])
			var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == body: aimed = true; break
		if not check(aimed, "No clear actor40 approach"): return
		area.roach.model.strike_remaining = 0.0
		var before := Feedback.landed_hits
		var health := int(area.roach_population.actors[id].health)
		var struck: bool = live.strike()
		if not check(struck and int(area.roach_population.actors[id].health) == health - 4 and Feedback.landed_hits == before + 1, "Unarmed hand strike: struck %s hp %d -> %d" % [struck, health, int(area.roach_population.actors[id].health)]): return
		area.roach_population = State.initial(); live.restore()
		area.set_physics_process(true)
	# Spark on the overlay layer, Magic ring animation.
	var magic = area.starting_magic
	magic.select_spell("spark")
	var saved: Dictionary = magic.magic_state().duplicate(true); saved.player.mana = 10; saved.cooldown = 0.0; magic.commit(saved)
	if not check(magic.cast(), "Spark refused"): return
	var projectiles: Array = area.find_children("SpellProjectile", "Node3D", false, false)
	if not check(projectiles.size() == 1 and area.has_node("SpellEffectsOverlay"), "Spark projectile/overlay missing"): return
	var mesh: MeshInstance3D = projectiles[0].find_children("*", "MeshInstance3D", true, false)[0]
	if not check(mesh.layers == Feedback.EFFECT_LAYER and swing.magic_anim.visible, "Spark not on the effects layer (%d) or no ring animation" % mesh.layers): return
	# Refusals say why; a successful heal keeps "Healing" and pulses.
	await frames(40)
	magic.select_spell("heal"); magic.set_health(30)
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; saved.player.mana = 10; magic.commit(saved)
	if not check(not magic.cast() and magic.notice_text() == "Already at full health", "Full-health refusal: '%s'" % magic.notice_text()): return
	magic.set_health(20)
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; saved.player.mana = 0; magic.commit(saved)
	if not check(not magic.cast() and magic.notice_text() == "Not enough mana", "Mana refusal: '%s'" % magic.notice_text()): return
	saved = magic.magic_state().duplicate(true); saved.cooldown = 0.0; saved.player.mana = 10; magic.commit(saved)
	if not check(magic.cast() and magic.notice_text() == "Healing" and magic.health() == 26 and swing.screen_flash.color.a > 0.0, "Healing: notice '%s' health %d flash %s" % [magic.notice_text(), magic.health(), swing.screen_flash.color.a]): return
	# Classic inventory interactions (fake equip callables; presentation and routing only).
	var inv = preload("res://scripts/lol2/museum_inventory.gd").new()
	inv.item_ids = ["museum:item11:Fine_Longsword", "museum:item10:Mail_Shirt", "hive:item0:Wax"]
	var log: Array = []
	inv.change_equipment = func(id): log.append(["weapon", id]); return true
	inv.change_armor = func(id): log.append(["armor", id]); return true
	area.add_child(inv); await frames(2)
	if not check(inv.item_list.max_columns == 4 and inv.item_list.item_count == 3 and inv.equipment_slots.size() == 6, "Inventory grid/slots"): return
	inv.activate_item(0)
	if not check(inv.equipped_item == "museum:item11:Fine_Longsword" and log.back() == ["weapon", "museum:item11:Fine_Longsword"], "Double-click did not equip: %s" % [log]): return
	if not check(inv.equipment_slots[2].get_node("Worn").texture != null, "Worn weapon not shown in the weapon slot"): return
	inv.unequip_slot("weapon")
	if not check(inv.equipped_item == "" and log.back() == ["weapon", ""], "Slot click did not unequip: %s" % [log]): return
	if not check(not inv._can_drop("weapon", {"inventory_item": "hive:item0:Wax", "index": 2}), "Wax accepted in the weapon slot"): return
	if not check(inv._can_drop("armor", {"inventory_item": "museum:item10:Mail_Shirt", "index": 1}), "Mail refused by the armor slot"): return
	inv._drop("weapon", {"inventory_item": "museum:item11:Fine_Longsword", "index": 0})
	if not check(inv.equipped_item == "museum:item11:Fine_Longsword", "Drop on weapon slot did not equip"): return
	inv.close(); await frames(2)
	print("PASS combat_feedback_inventory: swing + ring animation on captured clicks only, landed splash, unarmed hand strike lands (4) and reports, Spark projectile on overlay layer + magic ring, refusal notices, Healing notice/pulse, classic inventory grid/double-click/slot/drag routing")
	quit(0)
