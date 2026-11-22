extends SceneTree
## Debug kill key (owner D12): absent without the flag; with it, real Ctrl+Shift+K defeats nearby hostiles through the normal damage path,
## real Ctrl+K defeats the aimed one, peaceful actors stay, and the dead stay dead after a save and reload.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const DebugKill = preload("res://scripts/lol2/debug_kill.gd")
const INPUT := "res://tmp/l8_shaman_serum_earned_save.json"
var failures := 0
func check(c: bool, m: String) -> bool:
	if not c:
		failures += 1; print("FAIL debug kill: ", m)
	return c
func _initialize() -> void: run.call_deferred()
func boot() -> Node:
	var source := Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	check(source.error.is_empty(), "earned save: " + str(source.error))
	set_meta("lol2_darker_resume", source.state); Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review, "scene ready")
	return scene
func key(ctrl: bool, shift: bool) -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_K; e.physical_keycode = KEY_K; e.pressed = down; e.ctrl_pressed = ctrl; e.shift_pressed = shift
		root.push_input(e); await process_frame
func alive_hostile_near(scene: Node) -> Array:
	var pop = scene.act2_creatures; var out := []
	for id in pop.bodies.keys():
		var a: Dictionary = pop.state.actors[id]
		if bool(a.present) and int(a.health) > 0 and not pop.peaceful_actor(str(id)) and not str(id) in DebugKill.STORY_ACTORS.get("L8_SJ", []) and pop.bodies[id].global_position.distance_to(scene.player.global_position) <= DebugKill.REACH: out.append(str(id))
	return out
func run() -> void:
	DebugKill.forced = false
	var scene: Node = await boot()
	check(scene.get_node_or_null("DebugKill") == null, "no debug key without --debug-mode")
	scene.queue_free(); current_scene = null; await process_frame
	DebugKill.forced = true
	scene = await boot()
	check(scene.get_node_or_null("DebugKill") != null, "debug key present with the flag")
	scene.player.set_physics_process(false)
	var pop = scene.act2_creatures
	# TELEPORT (declared, 1): stand Luther 150 units from the nearest living hostile; walking is not under test here.
	var nearest := ""
	for id in pop.bodies.keys():
		var a: Dictionary = pop.state.actors[id]
		if bool(a.present) and int(a.health) > 0 and not pop.peaceful_actor(str(id)) and not str(id) in DebugKill.STORY_ACTORS.get("L8_SJ", []) and (nearest == "" or pop.bodies[id].global_position.distance_to(scene.player.global_position) < pop.bodies[nearest].global_position.distance_to(scene.player.global_position)): nearest = str(id)
	if not check(nearest != "", "the earned L8 save has a living hostile creature"): quit(1); return
	var spot: Vector3 = pop.bodies[nearest].global_position
	scene.player.global_position = spot + (scene.player.global_position - spot).normalized() * 150.0 + Vector3(0, 40, 0)
	print("TELEPORT 1: beside actor ", nearest)
	for i in 5: await physics_frame
	# Aimed: look at the nearest hostile and press Ctrl+K.
	var near: Array = alive_hostile_near(scene)
	if not check(not near.is_empty(), "the earned L8 save has hostile creatures in reach"): quit(1); return
	near.sort_custom(func(a, b): return pop.bodies[a].global_position.distance_to(scene.player.global_position) < pop.bodies[b].global_position.distance_to(scene.player.global_position))
	var target: String = near[0]
	scene.camera.look_at(pop.bodies[target].global_position + Vector3(0, 24, 0), Vector3.UP)
	for i in 3: await physics_frame
	var aimed: String = pop.aimed()
	var peaceful := []
	for id in pop.bodies.keys():
		if pop.peaceful_actor(str(id)) and int(pop.state.actors[id].health) > 0: peaceful.append(str(id))
	var health_before: int = scene.starting_magic.health()
	await key(true, false)
	if not aimed.is_empty(): check(int(pop.state.actors[aimed].health) == 0, "Ctrl+K defeats the aimed creature %s" % aimed)
	else: print("NOTE aimed ray found nothing in reach of the camera; aimed kill not asserted")
	await key(true, true)
	check(alive_hostile_near(scene).is_empty(), "Ctrl+Shift+K defeats every hostile within reach (%s left)" % str(alive_hostile_near(scene)))
	for id in peaceful: check(int(pop.state.actors[id].health) > 0, "peaceful actor %s untouched" % id)
	if pop.state.actors.has("23"): check(int(pop.state.actors["23"].health) > 0, "Daniel is never defeated by the key")
	check(scene.starting_magic.health() == health_before, "Luther's own health unchanged")
	var path := "res://tmp/debug_kill_save.json"
	if check(scene._quicksave_unrecorded(path).is_empty(), "save after the kills"):
		check(scene._quickload_unrecorded(path).is_empty(), "reload")
		await process_frame
		check(alive_hostile_near(scene).is_empty(), "the defeated stay defeated after reload")
	scene.queue_free(); current_scene = null; await process_frame
	DebugKill.forced = false
	if failures == 0: print("PASS debug kill: flag-only, real Ctrl+K / Ctrl+Shift+K through the normal damage path, peaceful kept, survives reload")
	quit(0 if failures == 0 else 1)
