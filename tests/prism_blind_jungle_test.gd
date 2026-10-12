extends SceneTree
## Area + actual Jungle host, Prism blind (prism_blind.gd): the Prism taken in the Museum (supplied receipt;
## pickup in prism_effects_museum_test) is carried by the real Museum->Jungle inventory transport, equipped.
## Open Jungle regions (source flag clear) succeed above 249: a draw in 250..749 (which fails in the enclosed
## Museum) blinds a DINO that reached its bite: normal weapon damage, bite cancelled, 10s without moving or biting,
## "blinded" label and HUD line; a draw <= 249 does not blind; repeat refresh; pause freeze; expiry, then it bites
## again. A provoked Huline villager (shared scripted_creature_population) is blinded the same way. Standing in
## the source-enclosed region3501 the player counts as enclosed. Quicksave/quickload releases blinds (no fields),
## and the Jungle->Hive handoff carries none. Supplied vantage.
const Prism = preload("res://scripts/lol2/prism_blind.gd")
const Live = preload("res://scripts/lol2/creature_live_rules.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
var jungle
var failed := false
var topup := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; push_error(message); quit(1)
	return ok
func step(pop, seconds: float) -> void:
	for i in range(roundi(seconds * 60)):
		if topup: jungle.health = 30
		pop.advance(1.0 / 60.0)
		await physics_frame
func aim(pop, id: String) -> bool:
	jungle.camera.look_at(pop.bodies[id].global_position + Vector3(0, 24, 0))
	await physics_frame
	return pop.aimed() == id
## Advance pop's RNG until its next draw lies in lo..hi.
func prime(pop, lo: int, hi: int) -> int:
	for i in 2000:
		var probe := RandomNumberGenerator.new(); probe.state = pop.prism_rng.state
		var draw := probe.randi_range(1, Prism.DRAW_MAX)
		if draw >= lo and draw <= hi: return draw
		pop.prism_rng.randi_range(1, Prism.DRAW_MAX)
	return -1
func damage() -> int:
	return jungle.item_effects.melee_damage(Forms.melee_damage(jungle.player_form, true))
func run() -> void:
	# Museum: supplied taken receipt, equipped, carried by the real inventory transport.
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in 5: await process_frame
	museum.carried_collected.append(Prism.ITEM); museum.prism.restore(true)
	if not check(museum.set_equipped_item(Prism.ITEM) and not museum.prism.panorama.visible, "Museum equip"): return
	var transport: Dictionary = museum.inventory_state()
	museum.queue_free(); await process_frame; await process_frame
	set_meta("lol2_jungle_handoff", transport)
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 5: await process_frame
	if not check(jungle.equipped_item == Prism.ITEM, "Museum->Jungle transport"): return
	jungle.set_physics_process(false)
	var dinos = jungle.dino_population
	var villagers = jungle.villager_population
	dinos.set_physics_process(false); villagers.set_physics_process(false)
	jungle.starting_magic.set_process(false); jungle.item_effects.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(dinos.prism_blinds.is_empty() and villagers.prism_blinds.is_empty(), "Blinds at arrival"): return
	# Region flag: source-enclosed region3501 vs the open spawn.
	var r3501: Dictionary = Prism.table().areas.jungle.exceptions.filter(func(r): return int(r.region) == 3501)[0]
	var c := Vector2.ZERO
	for p in r3501.polygon: c += Vector2(p[0], p[1])
	c /= r3501.polygon.size()
	var start: Vector3 = jungle.player.global_position
	jungle.player.global_position = Vector3(c.x, float(r3501.floor_min) + preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET, c.y)
	if not check(Prism.area_of(jungle) == "jungle" and Prism.player_enclosed(jungle), "Region3501 not enclosed"): return
	jungle.player.global_position = start
	# DINO24 reaches its bite (approach as net_exile_onhit_jungle_test).
	dinos.state()
	var body: CharacterBody3D = dinos.bodies["24"]
	var spawn: Vector3 = body.global_position
	var chosen := false
	for angle in range(0, 360, 30):
		var offset := Vector3(sin(deg_to_rad(angle)), 0, cos(deg_to_rad(angle))) * 180
		var down := PhysicsRayQueryParameters3D.create(spawn + offset + Vector3.UP * 120, spawn + offset - Vector3.UP * 120, 1)
		var floor_hit: Dictionary = dinos.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty(): continue
		jungle.player.global_position = floor_hit.position + Vector3.UP * preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		await physics_frame
		var saved: Dictionary = jungle.quest_state.jungle_dino_population.duplicate(true)
		await step(dinos, 1.0)
		if jungle.quest_state.jungle_dino_population.live["24"].mode == Live.PURSUE and Vector2(body.global_position.x - spawn.x, body.global_position.z - spawn.z).length() > 20:
			chosen = true; break
		jungle.quest_state.jungle_dino_population = saved; dinos.restore(); await physics_frame
	if not check(chosen, "No reachable approach for DINO24"): return
	var waited := 0.0
	while dinos.view().live["24"].mode != Live.ATTACK and waited < 10.0:
		await step(dinos, 0.05); waited += 0.05
	if not check(dinos.view().live["24"].mode == Live.ATTACK, "DINO never reached bite range"): return
	jungle.health = 30
	if not check(not Prism.player_enclosed(jungle), "DINO approach region not open"): return
	# Draw <= 249 in the open: damage only.
	var health: int = int(dinos.view().actors["24"].health)
	prime(dinos, 1, Prism.OPEN_ABOVE)
	dinos.strike_remaining = 0.0
	if not check(await aim(dinos, "24") and dinos.strike() and int(dinos.view().actors["24"].health) == health - damage() and dinos.prism_blinds.is_empty(), "Low draw blinded or no damage"): return
	# Draw 250..749: fails enclosed, blinds in the open.
	var draw := prime(dinos, Prism.OPEN_ABOVE + 1, Prism.ENCLOSED_ABOVE)
	if not check(not Prism.success(draw, true) and Prism.success(draw, false), "Draw %d not region-dependent" % draw): return
	health = int(dinos.view().actors["24"].health)
	dinos.strike_remaining = 0.0
	if not check(await aim(dinos, "24") and dinos.strike() and int(dinos.view().actors["24"].health) == health - damage(), "Prism hit damage"): return
	var live: Dictionary = dinos.view().live["24"]
	if not check(Prism.blinded(dinos.prism_blinds, "24") and live.mode == Live.IDLE and not live.hit and is_equal_approx(float(dinos.prism_blinds["24"]), Prism.SECONDS), "DINO not blinded/bite not cancelled: %s %s" % [dinos.prism_blinds, live]): return
	if not check(jungle.interface_hud.hint.text == Prism.feedback("dinosaur"), "HUD: " + jungle.interface_hud.hint.text): return
	dinos._process(0.0)
	if not check(dinos.label.text.ends_with("· blinded"), "Label: " + dinos.label.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/prism_blind_jungle.png")
	var position: Vector3 = body.global_position
	var bites := 0
	topup = true
	for i in 300:
		jungle.health = 30
		dinos.advance(1.0 / 60.0); await physics_frame
		if dinos.view().live["24"].mode != Live.IDLE: bites += 1
	if not check(bites == 0 and body.global_position.distance_to(position) < 0.01 and is_equal_approx(float(dinos.prism_blinds["24"]), Prism.SECONDS - 5.0), "Blinded DINO acted: %d %s" % [bites, dinos.prism_blinds]): return
	prime(dinos, Prism.OPEN_ABOVE + 1, Prism.DRAW_MAX)
	dinos.strike_remaining = 0.0
	if not check(await aim(dinos, "24") and dinos.strike() and is_equal_approx(float(dinos.prism_blinds["24"]), Prism.SECONDS), "Repeat refresh: %s" % [dinos.prism_blinds]): return
	await step(dinos, 9.9)
	if not check(Prism.blinded(dinos.prism_blinds, "24") and dinos.view().live["24"].mode == Live.IDLE, "Refresh lost early"): return
	var left: float = float(dinos.prism_blinds["24"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await step(dinos, 5.0)
	if not check(is_equal_approx(float(dinos.prism_blinds.get("24", -1.0)), left), "Paused blind aged"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await step(dinos, 0.2)
	if not check(dinos.prism_blinds.is_empty(), "DINO blind did not expire"): return
	waited = 0.0
	while dinos.view().live["24"].mode != Live.ATTACK and waited < 4.0:
		await step(dinos, 0.05); waited += 0.05
	if not check(dinos.view().live["24"].mode == Live.ATTACK, "Released DINO did not bite again"): return
	# Villager (shared scripted population): provoked and blinded, no strikes while blind.
	topup = false
	jungle.health = 30
	dinos.restore()
	var v: CharacterBody3D = villagers.bodies["56"]
	jungle.player.global_position = v.global_position + Vector3(0, 32, 40)
	await physics_frame
	if not check(not Prism.player_enclosed(jungle), "Villager region not open"): return
	prime(villagers, Prism.OPEN_ABOVE + 1, Prism.DRAW_MAX)
	villagers.strike_remaining = 0.0
	if not check(await aim(villagers, "56") and villagers.strike() and villagers.state.actors["56"].woken and Prism.blinded(villagers.prism_blinds, "56"), "Villager not blinded: %s" % [villagers.prism_blinds]): return
	jungle.health = 30
	await step(villagers, 9.0)
	if not check(jungle.health == 30 and v.global_position.distance_to(jungle.player.global_position) > 30, "Blinded villager struck: %d" % jungle.health): return
	await step(villagers, 1.2)
	if not check(villagers.prism_blinds.is_empty(), "Villager blind did not expire"): return
	waited = 0.0
	while jungle.health == 30 and waited < 12.0:
		await step(villagers, 0.25); waited += 0.25
	if not check(jungle.health < 30, "Released villager did not fight back"): return
	# Save/load releases blinds; no blind fields saved.
	jungle.health = 30
	prime(villagers, Prism.OPEN_ABOVE + 1, Prism.DRAW_MAX)
	villagers.strike_remaining = 0.0
	if not check(await aim(villagers, "56") and villagers.strike() and Prism.blinded(villagers.prism_blinds, "56"), "Villager second blind"): return
	dinos.prism_blinds["24"] = 3.0
	var path := "user://tests/prism_blind_jungle.json"
	if not check(jungle.quicksave(path).is_empty() and not "prism_blind" in FileAccess.get_file_as_string(path), "Save carries blind fields"): return
	if not check(jungle.quickload(path).is_empty() and villagers.prism_blinds.is_empty() and dinos.prism_blinds.is_empty() and jungle.equipped_item == Prism.ITEM, "Load kept blinds: %s %s" % [villagers.prism_blinds, dinos.prism_blinds]): return
	# Lethal spell clears both existing effects on both Jungle population hosts.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jungle.health = 30
	for pair in [[dinos, "24"], [villagers, "56"]]:
		var population = pair[0]
		var actor_id: String = pair[1]
		prime(population, Prism.ENCLOSED_ABOVE + 1, Prism.DRAW_MAX)
		population.prism_hit(actor_id, Prism.ITEM)
		population.net_hit(actor_id, preload("res://scripts/lol2/net_exile_hold.gd").ITEM)
		if not check(population.prism_blinds.has(actor_id) and population.net_holds.has(actor_id), "Pre-death dual effects " + actor_id): return
		if not check(population.receive_damage(actor_id, 100000, false) and not population.prism_blinds.has(actor_id) and not population.net_holds.has(actor_id), "Death retained effects " + actor_id): return
	# Jungle->Hive handoff: the Prism stays equipped, no blind travels.
	villagers.prism_blinds["56"] = 4.0
	var handoff: Dictionary = jungle.area_handoff()
	if not check(not "prism_blind" in JSON.stringify(handoff), "Handoff carries blinds"): return
	jungle.queue_free(); await process_frame; await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 3: await process_frame
	if not check(hive.apply_area_handoff(handoff).is_empty() and hive.carried_inventory.equipped_item == Prism.ITEM and hive.return_population.prism_blinds.is_empty(), "Hive arrival"): return
	DirAccess.remove_absolute(path)
	print("PASS prism_blind_jungle: Museum->Jungle Prism transport + equipped; region3501 enclosed, approach open; DINO draw<=249 damage only, draw %d (fails enclosed) blinds: damage + bite cancel + 10s still (label/HUD), repeat refresh, pause freeze, expiry + bite resumes; villager provoke+blind then fights; save/load releases; Jungle->Hive carries the Prism, no blinds." % draw)
	quit()
