extends "res://tests/helpers/real_input_player.gd"
## Grok r19o3 owner-save walk 2026-11-16 (lead): after the Lizard crawl and the flute, a player under the sunken ritual floor
## did not find the way back up (three jumps at (2299, -3226) fell back; the screen said only "G — Return to Human").
## The way exists: only the Lizard fits the seam, from well back (too close, the jump hits the lip). The screen now names it (row 0287 note).
## Input: the earned chain A output (statue in the lower hall), loaded as chain B loads it. Then only real keys and mouse;
## ordinary 1/60. Proves: Human under the seam is told to take the Lizard; the Human jump cannot get up; real G; the Lizard
## is told to back well away from the ledge; from Grok's stand, real S back then a real running jump lands on the ritual
## floor within three tries (measured: 3/3 after backing 60 units, 0/3 after 40).
const Save=preload("res://scripts/lol2/act2_save.gd")
const INPUT := "res://tmp/l14_chain_a_save.json"
func _initialize(): main.call_deferred()
func stop_with(text: String) -> bool:
	print("FAIL l14_seam_return: ", text); quit(1); return false
func jump_from(takeoff: Vector2) -> float:
	if not await walk([[takeoff.x, takeoff.y]], "takeoff", {"no_fight": true}): return -INF
	key_event(KEY_W, false)
	var target := Vector3(2300.0, pos().y, -3300.0)
	for i in 120:
		if absf(yaw_error(target)) < 0.03: break
		turn_step(target, false); await physics_frame
	var start := pos().y
	key_event(KEY_W, true); await ticks(2); await tap(KEY_SPACE)
	for i in 180: await physics_frame
	key_event(KEY_W, false); await frames(4)
	return pos().y - start
func main():
	use_guard = false
	avoid_fights = true
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0 or Engine.physics_ticks_per_second != 60: return await stop_with("rendered ordinary clock needed")
	if not FileAccess.file_exists(INPUT): return await stop_with("earned chain A output (run l14_temple_chain_a_test)")
	var input = Save.read_save(INPUT, "lol2-restoration-map-L14_HT")
	if not input.error.is_empty(): return await stop_with(input.error)
	var map = load("res://scenes/lol2/maps/L14_HT.tscn").instantiate(); map.adapter_exit_seeds = false; root.add_child(map); current_scene = map
	for i in 1500:
		await process_frame
		if map.ready_for_review: break
	if not map.apply_save(input.state).is_empty(): return await stop_with("apply the earned input")
	await adopt()
	if not captured(): await lclick(); await frames(4)
	var passage: Node = scene.get_node("L14LowerPassage")
	var route: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_bedroom_approach.json")).lower
	# 1. Real W along the lower corridor to under the seam, as the Human.
	if not await walk(route.slice(0, route.size() - 1), "lower corridor", {"no_fight": true}): return await stop_with("walk the lower corridor, at %s" % pos())
	await frames(4)
	if scene.player_form != 0 or passage.hint.text != passage.UP_HUMAN: return await stop_with("under the seam the Human is told to take the Lizard (got '%s')" % passage.hint.text)
	# 2. The Human jump from Grok's spot does not get up (the ceiling).
	var human_rise: float = await jump_from(Vector2(2299.2, -3226.3))
	if human_rise > 20.0: return await stop_with("the Human was not expected to fit the seam (rose %.1f)" % human_rise)
	# 3. Real G: the Lizard, and the line names the way up.
	await tap(KEY_G)
	for i in 600:
		await physics_frame
		if scene.player_form == 2: break
	await frames(4)
	if scene.player_form != 2: return await stop_with("real G gives the Lizard")
	if passage.hint.text != passage.UP_LIZARD: return await stop_with("the Lizard is told to back well away from the ledge (got '%s')" % passage.hint.text)
	# 4. From Grok's stand: real S well away from the ledge, then a real running jump; at most three tries.
	var rise := -INF
	for attempt in 3:
		if not await walk([[2299.2, -3226.3]], "Grok's stand", {"no_fight": true}): return await stop_with("walk back to Grok's stand, at %s" % pos())
		key_event(KEY_W, false)
		var target := Vector3(pos().x, pos().y, -3400.0)
		for i in 120:
			if absf(yaw_error(target)) < 0.03: break
			turn_step(target, false); await physics_frame
		key_event(KEY_S, true); await ticks(60); key_event(KEY_S, false); await ticks(2)
		var start := pos().y
		key_event(KEY_W, true); await ticks(2); await tap(KEY_SPACE)
		for i in 180: await physics_frame
		key_event(KEY_W, false); await frames(4)
		rise = pos().y - start
		print("SEAM try %d: rose %.1f, at %s" % [attempt + 1, rise, pos()])
		if rise >= 30.0: break
	if rise < 30.0: return await stop_with("backed well away, the Lizard's running jump reaches the ritual floor within three tries (rose %.1f, at %s)" % [rise, pos()])
	if not await walk([[2300.0, -3400.0]], "ritual floor", {"no_fight": true}): return await stop_with("walk on the ritual floor, at %s" % pos())
	if pos().y < -10.0: return await stop_with("on the ritual floor (at %s)" % pos())
	print("PASS l14_seam_return: under the seam the screen names the Lizard and backing away from the lip; real G and a real jump from well back reach the ritual floor")
	quit(0)
