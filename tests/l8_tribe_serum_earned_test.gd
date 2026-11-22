extends "res://tests/l9_chapel_earned_test.gd"
## BJ12 (owner 2026-11-10: "the serum is not accessible"). The second half of the Wild Village chain with the real E key,
## the real Enter key and real mouse clicks on the panel: nine earned leaves at the village -> E -> "Present a Silverleaf"
## -> the shaman's speech (Enter skips each line) -> the bout with Daniel -> E returns to the village from anywhere in the
## arena (Daniel not in the crosshair) -> E -> the shaman's treehouse -> a leaf for the Amaranth Serum -> the panel stays
## at his table -> "Mix" gives the Larkhon Vapors -> the Journal says what to do with them.
## Headless cannot capture the mouse, so the sparring blows call the population's strike (the left-click handler's body).
const Tribe = preload("res://scripts/lol2/l8_tribe_state.gd")
const Trade = preload("res://scripts/lol2/l8_shaman_trade.gd")
const Guardian = preload("res://scripts/lol2/l8_larkhon_state.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
var journey: Node
func key(code: int) -> void:
	var d := InputEventKey.new(); d.keycode = code; d.physical_keycode = code; d.pressed = true; Input.parse_input_event(d); Input.flush_buffered_events()
	await process_frame
	var u := InputEventKey.new(); u.keycode = code; u.physical_keycode = code; u.pressed = false; Input.parse_input_event(u); Input.flush_buffered_events()
	await process_frame
func click(part: String) -> bool:
	for c in journey.box.get_children():
		if c is Button and not c.disabled and part in c.text:
			var at: Vector2 = (c as Button).get_global_rect().get_center()
			var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at; root.push_input(move)
			await process_frame
			for pressed in [true, false]:
				var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at; e.global_position = at
				root.push_input(e)
				await process_frame
			await process_frame
			return true
	return false
func texts() -> String:
	var out := ""
	for c in journey.box.get_children():
		if c is Label: out += c.text + " "
		elif c is Button: out += "[" + c.text + "] "
	return out
func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	# Headless starts with a 64x64 root window; the panel's buttons lie outside it and a real click cannot land.
	root.size = Vector2i(1280, 720)
	var input := Save.read_save("res://tmp/l8_nine_silverleaf_earned_save.json", "lol2-restoration-darker-jungle")
	if not check(input.error.is_empty(), input.error): quit(1); return
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false; root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.apply_save(input.state).is_empty(), "actual nine-leaf village input"): quit(1); return
	prepare(scene)
	journey = scene.get_node("L8Journey")
	var tribe = scene.get_node("L8Tribe")
	var hints: Node = scene.get_node("L8VillageHints")
	var leaves := func() -> int: return scene.carried_collected.filter(func(id): return Trade.Items.definition(id) == 117).size()
	var had: int = leaves.call()
	for i in 10: await process_frame
	hints.check()
	check("l8_leaves_for_the_tribe" in MyJournal.notes(scene), "the Journal says what the leaves are for (%s)" % str(MyJournal.notes(scene)))
	# 1. Present a leaf: the initiation.
	await key(KEY_E)
	if not check(journey.opened == "village" and "Present a Silverleaf" in texts(), "E at the village offers the initiation (%s)" % texts()): quit(1); return
	check(await click("Present a Silverleaf"), "a real click presents the leaf")
	if tribe.state().phase != "intro": print("DIAG paused ", paused, " world ", scene.starting_magic.world_active(), " target '", journey.target(), "' form ", scene.player_form, " flying ", scene.flying, " admitted ", scene.quest_state.get("l8_journey", {}), " grown ", scene.quest_state.get("l10_silverleaf", {}).get("grown"), " opened '", journey.opened, "' view '", journey.view, "' texts ", texts())
	if not check(tribe.state().phase == "intro" and leaves.call() == had - 1 and journey.opened == "", "the shaman's speech begins; one leaf given (%s)" % str(tribe.state())): quit(1); return
	for line in 8:
		if tribe.state().phase != "intro": break
		for i in 8: await physics_frame
		check("Enter" in tribe.hint.text, "the speech names its skip key ('%s')" % tribe.hint.text)
		await key(KEY_ENTER)
	if not check(tribe.state().phase == "fight", "Enter skips the lines into the arena (%s)" % str(tribe.state())): quit(1); return
	var pop = scene.act2_creatures
	for i in 6000:
		await physics_frame
		if tribe.state().phase == "complete": break
		scene.camera.look_at(pop.bodies["23"].global_position + Vector3.UP * 45, Vector3.UP)
		var direction: Vector3 = pop.bodies["23"].position - scene.player.position; direction.y = 0
		if pop.aimed() == "23": pop.strike(); scene.move_grounded(Vector3.ZERO, scene.player.get_physics_process_delta_time())
		else: scene.move_grounded(direction.normalized(), scene.player.get_physics_process_delta_time())
	if not check(Tribe.member(tribe.state()), "the bout ends without a death; Luther is of the tribe (%s)" % str(tribe.state())): quit(1); return
	# 2. E returns to the village wherever Luther looks (the prompt shows everywhere in the arena).
	scene.camera.look_at(scene.camera.global_position + (scene.camera.global_position - pop.bodies["23"].global_position).normalized() * 50.0 + Vector3.UP * 0.01, Vector3.UP)
	for i in 6: await process_frame
	check(tribe.hint.text == "E — Return to the village", "the arena shows its way out ('%s')" % tribe.hint.text)
	await key(KEY_E)
	if not check(tribe.state().phase == "departed" and Vector2(scene.player.position.x, scene.player.position.z).distance_to(Vector2(531, -4414)) < 2, "E returns to the village with Daniel behind Luther (%s at %s)" % [str(tribe.state().phase), str(scene.player.position.round())]): quit(1); return
	if not await walk(scene, [[600, -4400], [676, -4390]], "back to the clearing"): quit(1); return
	for i in 10: await process_frame
	# 3. The shaman: a leaf for the serum, then the mix at his table.
	await key(KEY_E)
	if not check(journey.opened == "village" and "trade his potion" in texts(), "the clearing says the shaman will trade (%s)" % texts()): quit(1); return
	check(await click("Approach the shaman"), "approach the shaman's treehouse")
	had = leaves.call()
	check(await click("Offer a Silverleaf"), "a real click offers the leaf (%s)" % texts())
	check(Trade.SERUM in scene.carried_collected and leaves.call() == had - 1, "the shaman gives the Amaranth Serum for one leaf")
	if not check(journey.opened == "village" and journey.view == "shaman" and paused and "Mix the Amaranth Serum" in texts(), "the panel stays at the shaman's table and offers the mix (%s)" % texts()): quit(1); return
	hints.check()
	check("larkhon_serum_needs_leaf" in MyJournal.notes(scene), "the Journal says the serum wants a leaf, here and not only beside the Larkhon")
	check(await click("Mix the Amaranth Serum"), "a real click mixes")
	check(Guardian.VAPORS in scene.carried_collected and Trade.SERUM not in scene.carried_collected and leaves.call() == had - 2, "serum + leaf -> Larkhon Vapors (%s)" % texts())
	check("Activate" in texts() and not ("Mix the Amaranth" in texts()), "the table says what comes next and the mix is gone (%s)" % texts())
	check(await click("Step back"), "step back to the clearing")
	check("Larkhon" in texts() and "east" in texts(), "the clearing points to the Larkhon in the east (%s)" % texts())
	await key(KEY_ESCAPE)
	check(journey.opened == "" and not paused, "Escape leaves the village")
	hints.check()
	check("larkhon_vapors_unactivated" in MyJournal.notes(scene), "the Journal keeps the vapors' use (%s)" % str(MyJournal.notes(scene)))
	var path := "res://tmp/l8_tribe_serum_earned_save.json"
	check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(), "F5/F9 with the vapors")
	check(Guardian.VAPORS in scene.carried_collected and Guardian.mixed(scene.quest_state[Guardian.KEY]), "the vapors survive the reload")
	check(scene.resets == 0, "no fall recovery")
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS L8 tribe + serum by real input: E -> present a leaf -> Enter through the speech -> bout -> E out of the arena -> shaman's treehouse: leaf for serum -> mix at his table -> Vapors, Journal notes, save/reload")
	quit(0 if failures == 0 else 1)
