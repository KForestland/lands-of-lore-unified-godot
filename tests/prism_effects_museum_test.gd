extends SceneTree
## Actual Museum host, Prism effects (docs/prism-effects.md):
## - Panorama: the seven source panels (430..424) stand on their alcove edges while the Prism is on display and are
##   visible from inside the alcove (screenshot differs from after the pickup); the actual E pickup clears them, a
##   taken receipt keeps them cleared across quicksave/quickload, and an earlier untaken save brings them back.
## - Blind: Prism equipped through the real inventory; woken region35 skeletons fought with the production strike.
##   Museum regions are enclosed (source flag set): a draw <= 749 lands normal damage and no blind; a draw > 749
##   blinds 10s with the started attack cancelled, feedback line and "blinded" label; the blinded skeleton neither
##   moves nor hurts the player; a repeat success refreshes; the world pause freezes it; on expiry it fights again;
##   an unarmed strike is refused without a draw; a killing hit blinds nothing; quicksave/quickload releases blinds (no fields).
## Draws are the population's own RNG, advanced until the next draw has the wanted outcome. Supplied vantage.
const Prism = preload("res://scripts/lol2/prism_blind.gd")
const Owner = preload("res://scripts/lol2/museum_prism.gd")
const State = preload("res://scripts/lol2/museum_skeleton_population_state.gd")
const Live = preload("res://scripts/lol2/creature_live_rules.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running := true
	func world_active() -> bool: return running
var museum
var pop
var spells
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func step(seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		pop.advance(1.0 / 60.0)
		await physics_frame
func press_e() -> void:
	var e := InputEventKey.new(); e.keycode = KEY_E; e.pressed = true; Input.parse_input_event(e); await process_frame
	e = InputEventKey.new(); e.keycode = KEY_E; e.pressed = false; Input.parse_input_event(e); await process_frame
## Advance the population RNG until its next draw succeeds (or fails) in this region.
func prime(want: bool) -> int:
	var enclosed := Prism.player_enclosed(museum)
	for i in 1000:
		var probe := RandomNumberGenerator.new(); probe.state = pop.prism_rng.state
		var draw := probe.randi_range(1, Prism.DRAW_MAX)
		if Prism.success(draw, enclosed) == want: return draw
		pop.prism_rng.randi_range(1, Prism.DRAW_MAX)
	return -1
func shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png("user://tests/" + name)
	return image
func strike(id: String) -> bool:
	pop.strike_remaining = 0.0
	museum.camera.look_at(pop.bodies[id].global_position + Vector3(0, 24, 0))
	await physics_frame
	return pop.aimed() == id and pop.strike()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in range(5): await process_frame
	museum.set_physics_process(false)
	pop = museum.skeleton_population
	pop.set_physics_process(false)
	museum.starting_magic.set_process(false)
	spells = TestMagic.new(); museum.add_child(spells); spells.set_process(false); museum.starting_magic = spells
	museum.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var owner = museum.prism
	# Panorama present while the Prism is displayed.
	if not check(Owner.assets_ready() and is_instance_valid(owner.panorama) and owner.panorama.visible and owner.panorama.mesh.get_surface_count() == 7, "Panorama not built"): return
	var panels: Array = JSON.parse_string(FileAccess.get_file_as_string(Owner.PANORAMA)).panels
	var p0: Array = panels[0].points
	var panel_mid := (Vector3(p0[0][0], p0[0][1], p0[0][2]) + Vector3(p0[2][0], p0[2][1], p0[2][2])) / 2.0
	var found := false
	for angle in range(0, 360, 15):
		var point: Vector3 = owner.display.global_position
		museum.player.global_position = point + Vector3(sin(deg_to_rad(angle)) * 55, 4, cos(deg_to_rad(angle)) * 55)
		museum.camera.look_at(point); await physics_frame
		if owner.reachable(): found = true; break
	if not check(found, "Reachable Prism vantage"): return
	var vantage: Vector3 = museum.player.global_position
	var untaken_path := "user://tests/prism_effects_untaken.json"
	if not check(museum.quicksave(untaken_path).is_empty(), "Untaken save"): return
	# Inside view of panel 0 (from the alcove), then the pickup view.
	museum.camera.look_at(panel_mid); await physics_frame
	var before: Image = await shot("prism_panorama_before.png")
	museum.camera.look_at(owner.display.global_position); await physics_frame
	await shot("prism_panorama_display.png")
	await press_e()
	if not check(owner.taken and not owner.display.visible and not owner.panorama.visible and Owner.ITEM in museum.carried_collected, "Pickup did not clear panorama"): return
	museum.player.global_position = vantage
	museum.camera.look_at(panel_mid); await physics_frame
	var after: Image = await shot("prism_panorama_after.png")
	var changed := 0
	for y in range(200, 520, 8):
		for x in range(340, 940, 8):
			if before.get_pixel(x, y).to_rgba32() != after.get_pixel(x, y).to_rgba32(): changed += 1
	if not check(changed > 200, "Panorama not visible from the alcove: %d changed samples" % changed): return
	# Taken receipt: save/load keeps it cleared; the earlier untaken save brings it back, then retake.
	var taken_path := "user://tests/prism_effects_taken.json"
	if not check(museum.quicksave(taken_path).is_empty() and museum.quickload(taken_path).is_empty() and owner.taken and not owner.panorama.visible, "Taken receipt reload"): return
	if not check(museum.quickload(untaken_path).is_empty() and not owner.taken and owner.panorama.visible and not Owner.ITEM in museum.carried_collected, "Untaken load did not restore panorama"): return
	museum.player.global_position = vantage; museum.camera.look_at(owner.display.global_position); await physics_frame
	await press_e()
	if not check(owner.taken and not owner.panorama.visible, "Retake"): return
	# Equip through the real inventory.
	museum.open_inventory(); await process_frame
	var inventory = museum.inventory; var index := -1
	for i in inventory.item_list.item_count:
		if str(inventory.item_list.get_item_metadata(i)) == Owner.ITEM: index = i
	if not check(index >= 0, "Prism inventory entry"): return
	inventory.select_item(index); inventory.toggle_equipment(); await process_frame
	inventory.queue_free(); await process_frame
	if not check(museum.equipped_item == Prism.ITEM, "Prism equipment"): return
	# Wake region35 skeletons (as museum_skeleton_live_test) and let 24 start fighting.
	var r35: Dictionary = pop.src.regions.filter(func(x): return int(x.region) == 35)[0]
	var c := Vector2.ZERO
	for v in r35.polygon: c += Vector2(v[0], v[1])
	c /= r35.polygon.size()
	var down := PhysicsRayQueryParameters3D.create(Vector3(c.x, float(r35.floor_max) + 40, c.y), Vector3(c.x, float(r35.floor_min) - 40, c.y), 1)
	var hit: Dictionary = pop.get_world_3d().direct_space_state.intersect_ray(down)
	if not check(not hit.is_empty(), "Region35 floor"): return
	museum.player.global_position = hit.position + Vector3.UP * preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	museum.player.velocity = Vector3.DOWN * 10; museum.player.move_and_slide(); await physics_frame
	pop.advance(1.0 / 60.0)
	if not check(pop.state.actors["24"].woken, "Region35 wake"): return
	var waited := 0.0
	while museum.health == 30 and waited < 15.0:
		await step(0.25); waited += 0.25
	if not check(museum.health < 30, "Skeletons never fought"): return
	museum.health = 30
	if not check(Prism.player_enclosed(museum), "Museum region not enclosed"): return
	var body: CharacterBody3D = pop.bodies["24"]
	museum.player.global_position = body.global_position + Vector3(0, 32, 55)
	await physics_frame
	# Failed draw: ordinary damage, no blind.
	var draw := prime(false)
	var hp: int = int(pop.state.actors["24"].health)
	if not check(draw > 0 and draw <= Prism.ENCLOSED_ABOVE and await strike("24") and int(pop.state.actors["24"].health) < hp and pop.prism_blinds.is_empty(), "Failed draw %d blinded or missed" % draw): return
	# Successful draw.
	draw = prime(true)
	hp = int(pop.state.actors["24"].health)
	museum.save_feedback("")
	if not check(draw > Prism.ENCLOSED_ABOVE and await strike("24") and int(pop.state.actors["24"].health) < hp and Prism.blinded(pop.prism_blinds, "24"), "Successful draw %d did not blind: %s" % [draw, pop.prism_blinds]): return
	var live: Dictionary = pop.state.live["24"]
	if not check(live.mode == Live.IDLE and not live.hit and is_equal_approx(float(pop.prism_blinds["24"]), Prism.SECONDS), "Attack not cancelled: %s" % [live]): return
	if not check(museum.interaction_label.text == Prism.feedback(pop.name_of("24")), "Feedback: " + museum.interaction_label.text): return
	pop._process(0.0)
	if not check(pop.label.text.ends_with("· blinded"), "Label: " + pop.label.text): return
	await shot("prism_blind_museum.png")
	# Blinded: stands still and never hurts the player (other skeletons are kept dormant away from the player).
	for id in pop.bodies:
		if id != "24" and pop.state.actors[id].woken: pop.receive_damage(id, 999, false)
	var position: Vector3 = body.global_position
	museum.health = 30
	await step(5.0)
	if not check(museum.health == 30 and body.global_position.distance_to(position) < 0.01 and is_equal_approx(float(pop.prism_blinds["24"]), Prism.SECONDS - 5.0), "Blinded skeleton acted: hp %d moved %.2f %s" % [museum.health, body.global_position.distance_to(position), pop.prism_blinds]): return
	# Repeat success refreshes; a repeat failure leaves the time running.
	prime(false)
	if not check(await strike("24") and is_equal_approx(float(pop.prism_blinds["24"]), Prism.SECONDS - 5.0), "Failed repeat changed the blind"): return
	if not check(museum.interaction_label.text != Prism.feedback(pop.name_of("24")), "Failed repeat announced success"): return
	prime(true)
	if not check(await strike("24") and is_equal_approx(float(pop.prism_blinds["24"]), Prism.SECONDS), "Repeat success did not refresh"): return
	# World pause freezes.
	spells.running = false
	var left: float = float(pop.prism_blinds["24"])
	await step(3.0)
	if not check(is_equal_approx(float(pop.prism_blinds["24"]), left), "Paused blind aged"): return
	spells.running = true
	await step(10.2)
	if not check(pop.prism_blinds.is_empty(), "Blind did not expire"): return
	waited = 0.0
	while museum.health == 30 and waited < 15.0:
		await step(0.25); waited += 0.25
	if not check(museum.health < 30, "Released skeleton did not fight again"): return
	museum.health = 30
	# Unequipped: hit lands, nothing drawn.
	if not check(museum.set_equipped_item("") and museum.equipped_item == "", "Unequip"): return
	var state_before: int = pop.prism_rng.state
	museum.player.global_position = body.global_position + Vector3(0, 32, 55); await physics_frame
	var struck: bool = await strike("24")
	# Human form unarmed: the shared strike refuses the hit, so no draw either.
	if not check(not struck and pop.prism_blinds.is_empty() and pop.prism_rng.state == state_before, "Unequipped hit drew/landed: struck %s aimed '%s' hp %d blinds %s rng %s" % [struck, pop.aimed(), int(pop.state.actors["24"].health), pop.prism_blinds, pop.prism_rng.state == state_before]): return
	if not check(museum.set_equipped_item(Prism.ITEM), "Re-equip"): return
	# Save/load releases blinds.
	prime(true)
	museum.health = 30
	if not check(await strike("24") and Prism.blinded(pop.prism_blinds, "24"), "Second blind"): return
	var path := "user://tests/prism_effects_blind.json"
	if not check(museum.quicksave(path).is_empty() and not "prism_blind" in FileAccess.get_file_as_string(path), "Save carries blind fields"): return
	if not check(museum.quickload(path).is_empty() and pop.prism_blinds.is_empty() and museum.equipped_item == Prism.ITEM, "Load kept the blind"): return
	# Killing hit blinds nothing.
	prime(true)
	pop.prism_hit("24", Prism.ITEM)
	if not check(Prism.blinded(pop.prism_blinds, "24"), "Pre-death blind"): return
	pop.state.actors["24"].health = 1
	prime(true)
	museum.player.global_position = pop.bodies["24"].global_position + Vector3(0, 32, 55); await physics_frame
	if not check(await strike("24") and int(pop.state.actors["24"].health) == 0 and pop.prism_blinds.is_empty(), "Killing hit blinded"): return
	for p in [untaken_path, taken_path, path]: DirAccess.remove_absolute(p)
	print("PASS prism_effects_museum: 7 source panorama panels shown on the alcove edges while displayed (%d changed samples vs after), actual E pickup clears them, taken receipt reload keeps cleared, untaken save restores; real inventory equip; enclosed Museum: draw<=749 damage only, draw>749 blind 10s + attack cancel + label/feedback, no movement/damage while blind, failed repeat keeps time, success refreshes, pause freeze, expiry then fights, unarmed strike refused without a draw, save/load releases, killing hit no blind." % changed)
	quit()
