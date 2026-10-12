extends SceneTree
## Area + actual Jungle host, Net of Exile on-hit (net_exile_hold.gd): a Net carried from the Hive (real area
## handoff, supplied pickup history) is equipped in the Jungle; unarmed strike refused; a DINO that reached its
## bite is netted by the real population strike(): normal weapon damage, bite cancelled, held 10s in place
## without biting, "netted" label and feedback; repeat hit refreshes; release, then it bites again. A provoked
## Huline villager (shared scripted_creature_population) is netted the same way. A miss holds nothing; the
## world pause freezes holds; quicksave/quickload releases them (no Net fields in the save). Supplied vantage.
const Net = preload("res://scripts/lol2/net_exile_hold.gd")
const Live = preload("res://scripts/lol2/creature_live_rules.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
var jungle
var failed := false
## Herd mates may bite during the DINO phase; keep the player standing so the world gate stays open.
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
func net_damage() -> int:
	return jungle.item_effects.melee_damage(Forms.melee_damage(jungle.player_form, true))
func run() -> void:
	# Hive: supplied Net with pickup history, equipped, carried by the real area handoff.
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 5: await process_frame
	hive.carried_inventory.collected.append(Net.ITEM)
	hive.net_exile.state.state = 1
	if not check(hive.set_equipped_item(Net.ITEM), "Hive equip"): return
	var handoff: Dictionary = hive.area_handoff()
	hive.queue_free(); await process_frame; await process_frame
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 5: await process_frame
	var error: String = jungle.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff, "", true, true)))
	if not check(error.is_empty() and Net.ITEM in jungle.carried_collected, "Jungle handoff: " + error): return
	jungle.set_physics_process(false)
	var dinos = jungle.dino_population
	var villagers = jungle.villager_population
	dinos.set_physics_process(false); villagers.set_physics_process(false)
	jungle.starting_magic.set_process(false); jungle.item_effects.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(dinos.net_holds.is_empty() and villagers.net_holds.is_empty(), "Holds crossed the area change"): return
	# DINO24 reaches its bite (approach as jungle_dino_live_test).
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
	# Unarmed (form 0, nothing equipped) is refused; nothing held.
	if not check(jungle.set_equipped_item("") and await aim(dinos, "24"), "No DINO vantage"): return
	dinos.strike_remaining = 0.0
	if not check(not dinos.strike() and dinos.net_holds.is_empty(), "Unarmed strike accepted"): return
	if not check(jungle.set_equipped_item(Net.ITEM) and jungle.equipped_item == Net.ITEM, "Jungle equip Net"): return
	# Miss: aim away.
	jungle.camera.rotation = Vector3(PI / 2 - 0.05, 0, 0); await physics_frame
	dinos.strike_remaining = 0.0
	var health: int = int(dinos.view().actors["24"].health)
	if not check(not dinos.strike() and dinos.net_holds.is_empty() and int(dinos.view().actors["24"].health) == health, "Miss held"): return
	# Net hit.
	if not check(await aim(dinos, "24"), "Lost DINO aim"): return
	dinos.strike_remaining = 0.0
	if not check(dinos.strike() and int(dinos.view().actors["24"].health) == health - net_damage(), "Net hit damage"): return
	var live: Dictionary = dinos.view().live["24"]
	if not check(Net.held(dinos.net_holds, "24") and live.mode == Live.IDLE and not live.hit, "DINO not held/bite not cancelled: %s %s" % [dinos.net_holds, live]): return
	dinos._process(0.0)
	if not check(dinos.label.text.ends_with("· netted"), "Label: " + dinos.label.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/net_exile_onhit_jungle.png")
	var position: Vector3 = body.global_position
	var bites := 0
	topup = true
	for i in 300:
		jungle.health = 30
		dinos.advance(1.0 / 60.0); await physics_frame
		if dinos.view().live["24"].mode != Live.IDLE: bites += 1
	if not check(bites == 0 and body.global_position.distance_to(position) < 0.01 and is_equal_approx(float(dinos.net_holds["24"]), Net.SECONDS - 5.0), "Held DINO acted: %d %s" % [bites, dinos.net_holds]): return
	dinos.strike_remaining = 0.0
	var reaimed: bool = await aim(dinos, "24")
	if not check(reaimed and dinos.strike() and is_equal_approx(float(dinos.net_holds["24"]), Net.SECONDS), "Repeat refresh: aim %s aimed '%s' holds %s" % [reaimed, dinos.aimed(), dinos.net_holds]): return
	await step(dinos, 9.9)
	if not check(Net.held(dinos.net_holds, "24") and dinos.view().live["24"].mode == Live.IDLE, "Refresh lost early"): return
	# World pause freezes the hold.
	var left: float = float(dinos.net_holds["24"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await step(dinos, 5.0)
	if not check(is_equal_approx(float(dinos.net_holds.get("24", -1.0)), left), "Paused hold aged"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await step(dinos, 0.2)
	if not check(dinos.net_holds.is_empty(), "DINO hold did not expire"): return
	waited = 0.0
	while dinos.view().live["24"].mode != Live.ATTACK and waited < 4.0:
		await step(dinos, 0.05); waited += 0.05
	if not check(dinos.view().live["24"].mode == Live.ATTACK, "Released DINO did not bite again"): return
	# Villager (shared scripted population): provoke with the Net -> woken and held, no strikes while held.
	topup = false
	jungle.health = 30
	dinos.restore()
	var v: CharacterBody3D = villagers.bodies["56"]
	jungle.player.global_position = v.global_position + Vector3(0, 32, 40)
	await physics_frame
	villagers.strike_remaining = 0.0
	if not check(await aim(villagers, "56") and villagers.strike() and villagers.state.actors["56"].woken and Net.held(villagers.net_holds, "56"), "Villager not netted: %s" % [villagers.net_holds]): return
	jungle.health = 30
	await step(villagers, 9.0)
	if not check(jungle.health == 30 and v.global_position.distance_to(jungle.player.global_position) > 30, "Held villager struck: %d" % jungle.health): return
	await step(villagers, 1.2)
	if not check(villagers.net_holds.is_empty(), "Villager hold did not expire"): return
	waited = 0.0
	while jungle.health == 30 and waited < 12.0:
		await step(villagers, 0.25); waited += 0.25
	if not check(jungle.health < 30, "Released villager did not fight back"): return
	# Save/load releases holds; no Net fields saved.
	jungle.health = 30
	villagers.strike_remaining = 0.0
	if not check(await aim(villagers, "56") and villagers.strike() and Net.held(villagers.net_holds, "56"), "Villager second hold"): return
	dinos.net_holds["24"] = 3.0
	var path := "user://tests/net_exile_onhit_jungle.json"
	if not check(jungle.quicksave(path).is_empty(), "Jungle save failed"): return
	if not check(not "net_hold" in FileAccess.get_file_as_string(path), "Save carries Net hold fields"): return
	if not check(jungle.quickload(path).is_empty() and villagers.net_holds.is_empty() and dinos.net_holds.is_empty(), "Load kept holds: %s %s" % [villagers.net_holds, dinos.net_holds]): return
	# A lethal spell must also clear an existing hold on each Jungle host.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jungle.health = 30
	for pair in [[dinos, "24"], [villagers, "56"]]:
		var population = pair[0]
		var actor_id: String = pair[1]
		if not check(population.net_hit(actor_id, Net.ITEM), "Pre-death hold " + actor_id): return
		if not check(population.receive_damage(actor_id, 100000, false) and not Net.held(population.net_holds, actor_id), "Dead target retained hold " + actor_id): return
	print("PASS net_exile_onhit_jungle: Hive->Jungle Net carried + equipped, holds not carried, unarmed refused, miss no hold, DINO Net hit damage + bite cancel + 10s hold (label), repeat refresh, pause freeze, expiry + bite resumes, villager provoke+hold then fights, save/load releases holds.")
	quit()
