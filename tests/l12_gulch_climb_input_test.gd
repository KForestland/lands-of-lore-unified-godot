extends "res://tests/helpers/real_input_player.gd"
## Way back with the Dreamstone (lead 2026-11-15, DEVIATIONS row 0671): at the ice opening over the river the screen names
## both ways on (the ice floe, or E to climb down to the icy gulch); real E climbs down; real W walks the gulch path to the
## original jungle exit 734. Input: the earned Citadel-exit save in the L12 tunnel (l12_exit_cave chain, pinned), loaded into
## the L12 scene as the earned tests do. Then only real keys and mouse; ordinary 1/60.
const Save=preload("res://scripts/lol2/act2_save.gd")
const INPUT := "res://tmp/l12_exit_cave_qualified_save.json"
const PIN := "2eeacb8ec431c556f5113f4053810e946121f631ef7fbe01a5d31cdeb82e477d"
func _initialize(): main.call_deferred()
func stop_with(text: String) -> bool:
	print("FAIL l12_gulch_climb: ", text); quit(1); return false
func main():
	use_guard = false
	avoid_fights = true
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0 or Engine.physics_ticks_per_second != 60: return await stop_with("rendered ordinary clock needed")
	if FileAccess.get_sha256(INPUT) != PIN: return await stop_with("pinned Citadel-exit input")
	var input = Save.read_save(INPUT, "lol2-restoration-map-L12_CM")
	if not input.error.is_empty(): return await stop_with(input.error)
	var map = load("res://scenes/lol2/maps/L12_CM.tscn").instantiate(); map.adapter_exit_seeds = false; root.add_child(map); current_scene = map
	for i in 1500:
		await process_frame
		if map.ready_for_review: break
	if not map.apply_save(input.state).is_empty(): return await stop_with("apply the earned input")
	await adopt()
	if not captured(): await lclick(); await frames(4)
	var citadel: Node = scene.get_node("L12Citadel")
	if not preload("res://scripts/lol2/l13_journal_hints.gd").carrying_dreamstone(scene): return await stop_with("the input carries the Dreamstone")
	# 1. Real W to the ice opening over the river.
	if not await walk([[2480.0, -15680.0]], "ice opening", {"no_fight": true}): return await stop_with("walk to the ice opening, at %s" % pos())
	for i in 10: await process_frame
	if citadel.hint.text != citadel.OPENING_LINE: return await stop_with("the opening names both ways on (got '%s')" % citadel.hint.text)
	# 2. Real E climbs down to the gulch.
	await tap(KEY_E)
	for i in 20: await physics_frame
	if pos().distance_to(citadel.GULCH_LANDING) > 40.0: return await stop_with("E climbs down to the icy gulch (at %s)" % pos())
	# 3. Real W along the gulch path to the original jungle exit; the real level change opens the Savage Jungle.
	var left := func() -> bool: return not is_instance_valid(scene) or scene != current_scene or not scene.progression.level_changes.is_empty()
	await walk([[-960.0, -5593.0], [-768.0, -5593.0], [-509.0, -5588.5], [-347.0, -5603.0], [-100.0, -5600.0]], "gulch path", {"no_fight": true, "until": left})
	key_event(KEY_W, false)
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != map and bool(current_scene.get("ready_for_review")): break
	if not is_instance_valid(current_scene) or current_scene == map: return await stop_with("the original gulch exit opens the Savage Jungle")
	await adopt()
	if area != "L8_SJ": return await stop_with("the gulch exit leads to the Savage Jungle (arrived in %s)" % area)
	print("PASS l12_gulch_climb: the opening names the floe and the climb, real E climbs down, real W reaches the jungle exit")
	quit(0)
