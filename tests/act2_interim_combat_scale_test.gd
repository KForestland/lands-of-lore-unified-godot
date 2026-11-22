extends SceneTree
## Interim combat scale (DEVIATIONS 0558): on an Act 2 map a strike of 8 removes 32 creature health, a creature blow on Luther is
## a quarter, Daniel is excluded, and a non-Act-2 area is unscaled.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const INPUT := "res://tmp/l8_shaman_serum_earned_save.json"
var failures := 0
func check(c: bool, m: String) -> bool:
	if not c:
		failures += 1; print("FAIL interim scale: ", m)
	return c
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source := Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	check(source.error.is_empty(), "earned save")
	set_meta("lol2_darker_resume", source.state); Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var pop = scene.act2_creatures
	var target := ""
	for id in pop.bodies.keys():
		var a: Dictionary = pop.state.actors[id]
		if bool(a.present) and int(a.health) >= 100 and not pop.peaceful_actor(str(id)) and pop.interim_scaled(str(id)): target = str(id); break
	if not check(target != "", "an Act 2 roaming creature with health"): quit(1); return
	var before: int = int(pop.state.actors[target].health)
	check(pop.receive_damage(target, 8, true), "a strike of 8 lands")
	check(before - int(pop.state.actors[target].health) == 32, "8 removes 32 (%d -> %d)" % [before, int(pop.state.actors[target].health)])
	check(is_equal_approx(pop.damage_to_player_scale(target), 0.25), "creature blows on Luther are a quarter")
	check(not pop.interim_scaled("23") and is_equal_approx(pop.damage_to_player_scale("23"), 1.0), "Daniel keeps his own rules")
	var area: String = pop.area_id
	pop.area_id = "L16_CA"
	check(not pop.interim_scaled(target) and is_equal_approx(pop.damage_to_player_scale(target), 1.0), "Act 3 areas are unscaled")
	pop.area_id = area
	scene.queue_free(); current_scene = null; await process_frame
	if failures == 0: print("PASS interim combat scale: x4 to Act 2 creatures, a quarter to Luther, Daniel and Act 3 untouched")
	quit(0 if failures == 0 else 1)
