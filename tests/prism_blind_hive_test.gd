extends "res://tests/player_magic_handoff_test.gd"
## Actual Hive host, Prism blind (prism_blind.gd) against the source return warriors via the real
## hive_warriors.strike(). Hive regions are enclosed (source flag set at the vantage): a miss draws nothing; an
## equipped Prism hit with a draw <= 749 lands normal damage only; a draw > 749 cancels the started attack and
## blinds 10s (no movement, attack or player damage), HUD line and "blinded" label; a failed repeat keeps the time,
## a successful repeat refreshes; the world pause freezes it; on expiry the warrior attacks again; a Net hit and a
## Prism blind are separate states; a killing hit blinds nothing; quicksave/quickload releases the blind (no
## fields). Supplied Prism and vantage (pickup/transport in prism_effects_museum_test / prism_blind_jungle_test).
const Prism = preload("res://scripts/lol2/prism_blind.gd")
var scene
var pop
var guards
func step(seconds: float) -> void:
	for i in roundi(seconds * 60.0): pop.advance(1.0 / 60.0)
func strike() -> bool:
	guards.cooldown = 0.0
	return guards.strike()
func prime(want: bool) -> int:
	var enclosed := Prism.player_enclosed(scene)
	for i in 1000:
		var probe := RandomNumberGenerator.new(); probe.state = pop.prism_rng.state
		var draw := probe.randi_range(1, Prism.DRAW_MAX)
		if Prism.success(draw, enclosed) == want: return draw
		pop.prism_rng.randi_range(1, Prism.DRAW_MAX)
	return -1
func run() -> void:
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	await process_frame; await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	guards = scene.get_node("Warriors")
	guards.set_process(false)
	pop = scene.return_population
	pop.set_physics_process(false)
	scene.starting_magic.set_process(false)
	scene.item_effects.set_process(false)
	var fixture: Dictionary = scene.area_handoff()
	fixture.quests.shared_flag_38 = 1
	fixture.quests.hive_room_entered = true
	fixture.quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	if not check(scene.apply_area_handoff(fixture).is_empty() and pop.targets().size() == 3, "Rescue return did not activate warriors"): return
	scene.set_physics_process(false)
	scene.carried_inventory.collected.append(Prism.ITEM)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var target: CharacterBody3D = pop.bodies["27"]
	var clear := false
	for offset in [Vector3(0,32,65),Vector3(0,32,-65),Vector3(65,32,0),Vector3(-65,32,0)]:
		scene.player.position = pop.State.SPAWNS[27] + offset
		scene.camera.look_at(target.global_position)
		for i in range(2): await physics_frame
		var hit: Dictionary = guards.aimed_hit()
		if not hit.is_empty() and hit.collider == target: clear = true; break
	if not check(clear, "No clear warrior vantage"): return
	if not check(Prism.area_of(scene) == "hive" and Prism.player_enclosed(scene), "Hive vantage not enclosed"): return
	var a: Dictionary = pop.state.actors["27"]
	if not check(scene.set_equipped_item(Prism.ITEM) and scene.equipped_item == Prism.ITEM, "Equip Prism"): return
	# Miss: no draw.
	var aim: Vector3 = scene.camera.rotation
	scene.camera.rotation = Vector3(PI / 2 - 0.05, 0, 0); await physics_frame
	var rng_state: int = pop.prism_rng.state
	var health: int = int(a.health)
	if not check(not strike() and int(a.health) == health and pop.prism_blinds.is_empty() and pop.prism_rng.state == rng_state, "Miss drew or damaged"): return
	scene.camera.rotation = aim; await physics_frame
	var expected_damage: int = scene.item_effects.melee_damage(preload("res://scripts/lol2/player_form_rules.gd").melee_damage(scene.player_form, true))
	# Failed draw: damage only.
	prime(false)
	if not check(strike() and int(a.health) == health - expected_damage and pop.prism_blinds.is_empty(), "Failed draw blinded"): return
	health = int(a.health)
	# Let the warrior start an attack, then blind it.
	for i in 120:
		pop.advance(1.0 / 60.0)
		if a.has("attack_animation"): break
	if not check(a.has("attack_animation"), "Warrior never started an attack"): return
	guards.health = 30
	var draw := prime(true)
	if not check(draw > Prism.ENCLOSED_ABOVE and strike() and int(a.health) == health - expected_damage, "Prism hit damage"): return
	if not check(Prism.blinded(pop.prism_blinds, "27") and not a.has("attack_animation") and is_equal_approx(float(pop.prism_blinds["27"]), Prism.SECONDS), "Not blinded/cancelled: %s" % [pop.prism_blinds]): return
	if not check(scene.interface_hud.hint.text == "The Prism's light blinds the hive warrior." and pop.target_label("27").ends_with("· blinded"), "Feedback: '%s' '%s'" % [scene.interface_hud.hint.text, pop.target_label("27")]): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/prism_blind_hive.png")
	var position: Vector3 = target.global_position
	step(5.0)
	if not check(guards.health == 30 and not a.has("attack_animation") and target.global_position.distance_to(position) < 0.01, "Blinded warrior acted"): return
	prime(false)
	if not check(strike() and is_equal_approx(float(pop.prism_blinds["27"]), Prism.SECONDS - 5.0), "Failed repeat changed the blind: %s" % [pop.prism_blinds]): return
	prime(true)
	if not check(strike() and is_equal_approx(float(pop.prism_blinds["27"]), Prism.SECONDS), "Repeat success did not refresh"): return
	var left: float = float(pop.prism_blinds["27"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	step(20.0)
	if not check(is_equal_approx(float(pop.prism_blinds.get("27", -1.0)), left), "Paused blind aged"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	step(10.2)
	if not check(pop.prism_blinds.is_empty(), "Blind did not expire"): return
	var attacked := false
	for i in 240:
		pop.advance(1.0 / 60.0)
		if a.has("attack_animation"): attacked = true; break
	if not check(attacked, "Released warrior did not attack again"): return
	# Net and Prism stay separate: a Net hit holds without touching blinds or the Prism draw.
	scene.carried_inventory.collected.append("hive:prop214:Net_of_Exile"); scene.net_exile.state.state = 1
	if not check(scene.set_equipped_item("hive:prop214:Net_of_Exile"), "Equip Net"): return
	rng_state = pop.prism_rng.state
	if not check(strike() and pop.net_holds.has("27") and pop.prism_blinds.is_empty() and pop.prism_rng.state == rng_state, "Net hit touched Prism state"): return
	pop.net_holds.clear()
	if not check(scene.set_equipped_item(Prism.ITEM), "Re-equip Prism"): return
	# Save/load releases the blind.
	guards.health = 30
	prime(true)
	if not check(strike() and Prism.blinded(pop.prism_blinds, "27"), "Second blind"): return
	var path := "user://tests/prism_blind_hive.json"
	if not check(scene.quicksave(path).is_empty() and not "prism_blind" in FileAccess.get_file_as_string(path), "Save carries blind fields"): return
	if not check(scene.quickload(path).is_empty() and pop.prism_blinds.is_empty(), "Load kept the blind"): return
	scene.set_physics_process(false); pop.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	a = pop.state.actors["27"]
	prime(true)
	pop.prism_hit("27", Prism.ITEM)
	if not check(Prism.blinded(pop.prism_blinds, "27"), "Pre-death blind"): return
	a.health = 1
	prime(true)
	scene.camera.look_at(target.global_position); await physics_frame
	if not check(strike() and int(a.health) == 0 and pop.prism_blinds.is_empty(), "Killing hit: %d %s" % [a.health, pop.prism_blinds]): return
	DirAccess.remove_absolute(path)
	print("PASS prism_blind_hive: enclosed Hive vantage; miss no draw, draw<=749 damage only, draw>749 damage + attack cancel + 10s blind (HUD, label), blind no act/move, failed repeat keeps time, success refreshes, pause freeze, expiry + attack resumes, Net hold separate, save/load release, killing hit no blind.")
	quit()
