extends "res://tests/player_magic_handoff_test.gd"
## Actual Hive host, Net of Exile on-hit (net_exile_hold.gd) against the source return warriors via the real
## hive_warriors.strike(): an unarmed hit and a miss hold nothing; an equipped Net hit lands normal weapon damage,
## cancels the warrior's started attack and holds it 10s (no movement, attack or player damage), HUD line and
## "netted" label; a repeat hit at 5s refreshes (still held at 14.9s total, never stacked); release at 10s after
## the refresh, then the warrior attacks again; the world pause freezes the hold; a killing hit holds nothing;
## quicksave/quickload releases the hold and the save has no Net hold fields. Supplied Net (pickup tested in
## hive_net_exile_live_test) and supplied vantage.
const Net = preload("res://scripts/lol2/net_exile_hold.gd")
var scene
var pop
var guards
func step(seconds: float) -> void:
	var n := roundi(seconds * 60.0)
	for i in n: pop.advance(1.0 / 60.0)
func strike() -> bool:
	guards.cooldown = 0.0
	return guards.strike()
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
	# Supplied Net with its pickup history.
	scene.carried_inventory.collected.append(Net.ITEM)
	scene.net_exile.state.state = 1
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
	var a: Dictionary = pop.state.actors["27"]
	# Unarmed hit: ordinary damage, no hold.
	if not check(scene.equipped_item == "" and strike() and int(a.health) < 400 and pop.net_holds.is_empty(), "Unarmed hit: %d %s" % [a.health, pop.net_holds]): return
	# Equip the Net; a miss (aim away) holds nothing.
	if not check(scene.set_equipped_item(Net.ITEM) and scene.equipped_item == Net.ITEM, "Equip Net"): return
	var aim: Vector3 = scene.camera.rotation
	scene.camera.rotation = Vector3(PI / 2 - 0.05, 0, 0); await physics_frame
	var health: int = int(a.health)
	if not check(not strike() and int(a.health) == health and pop.net_holds.is_empty(), "Miss held or damaged"): return
	scene.camera.rotation = aim; await physics_frame
	# Let the warrior start an attack, then net it.
	for i in 120:
		pop.advance(1.0 / 60.0)
		if a.has("attack_animation"): break
	if not check(a.has("attack_animation"), "Warrior never started an attack"): return
	guards.health = 30
	var expected: int = health - scene.item_effects.melee_damage(preload("res://scripts/lol2/player_form_rules.gd").melee_damage(scene.player_form, true))
	if not check(strike() and int(a.health) == expected, "Net hit damage %d != %d" % [a.health, expected]): return
	if not check(Net.held(pop.net_holds, "27") and not a.has("attack_animation") and is_equal_approx(float(pop.net_holds["27"]), Net.SECONDS), "Net hit did not hold/cancel: %s" % [pop.net_holds]): return
	if not check(scene.interface_hud.hint.text == "The Net of Exile entangles the hive warrior." and pop.target_label("27").ends_with("· netted"), "Feedback: '%s' '%s'" % [scene.interface_hud.hint.text, pop.target_label("27")]): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/net_exile_onhit_hive.png")
	# Held 5s: no attack, no damage, no movement.
	var position: Vector3 = target.global_position
	step(5.0)
	if not check(guards.health == 30 and not a.has("attack_animation") and target.global_position.distance_to(position) < 0.01, "Held warrior acted: %d %s" % [guards.health, a.has("attack_animation")]): return
	# Repeat hit refreshes to 10s (no stacking).
	if not check(strike() and is_equal_approx(float(pop.net_holds["27"]), Net.SECONDS), "Repeat hit did not refresh: %s" % [pop.net_holds]): return
	step(9.9)
	if not check(Net.held(pop.net_holds, "27") and guards.health == 30 and not a.has("attack_animation"), "Refresh lost before 10s"): return
	# World pause: the hold does not age.
	var left: float = float(pop.net_holds["27"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	step(20.0)
	if not check(is_equal_approx(float(pop.net_holds.get("27", -1.0)), left), "Paused hold aged"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	step(0.2)
	if not check(not Net.held(pop.net_holds, "27") and pop.net_holds.is_empty(), "Hold did not expire: %s" % [pop.net_holds]): return
	var attacked := false
	for i in 240:
		pop.advance(1.0 / 60.0)
		if a.has("attack_animation"): attacked = true; break
	if not check(attacked, "Released warrior did not attack again"): return
	# Save/load releases the hold; the save carries no Net hold fields.
	guards.health = 30
	if not check(strike() and Net.held(pop.net_holds, "27"), "Second hold"): return
	var path := "user://tests/net_exile_onhit_hive.json"
	if not check(scene.quicksave(path).is_empty(), "Save failed"): return
	if not check(not "net_hold" in FileAccess.get_file_as_string(path), "Save carries Net hold fields"): return
	if not check(scene.quickload(path).is_empty() and pop.net_holds.is_empty(), "Load kept the hold"): return
	scene.set_physics_process(false); pop.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Death must clear a pre-existing hold.
	a = pop.state.actors["27"]
	if not check(pop.net_hit("27", Net.ITEM), "Pre-death hold"): return
	a.health = 1
	guards.cooldown = 0.0
	scene.camera.look_at(target.global_position); await physics_frame
	if not check(strike() and int(a.health) == 0 and pop.net_holds.is_empty(), "Killing hit: %d %s" % [a.health, pop.net_holds]): return
	print("PASS net_exile_onhit_hive: unarmed/miss no hold, Net hit damage + cancel + 10s hold (HUD, label), held no act/move, repeat refresh, pause freeze, expiry + attack resumes, save/load release, killing hit no hold.")
	quit()
