extends SceneTree
## Placed contract probes complement the separately registered input-only entry walks.
const Rules = preload("res://scripts/lol2/dark_halls_blast_rules.gd")
var scene: Node
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message)
	print("FAIL dark_halls_environment: ", message)
	quit(1)
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review") == true: break
	scene = current_scene
	if scene == null or not scene.ready_for_review: return fail("scene missing")
	scene.set_physics_process(false)
	scene.creatures.set_physics_process(false)
	scene.crates.set_physics_process(false)
	scene.atrium.set_physics_process(false)
	var pop: Node = scene.creatures
	var before: Dictionary = snapshot()
	var xp: Dictionary = scene.quest_state.duplicate(true)
	var origin: Vector3 = scene.crates.center_of(448)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Rules.SOURCE))
	# Native source flag gate, live position (not spawn), present/dead and radius gates.
	pop.bodies["25"].global_position = origin + Vector3(0, 0, 60)
	pop.bodies["26"].global_position = origin + Vector3(0, 0, 300)
	pop.bodies["27"].global_position = origin + Vector3(0, 0, -60)
	var row27: Dictionary = pop.State.actor_row(pop.src, "27")
	var flags := int(row27.flags)
	row27.flags = flags & ~0x4000
	var hp25 := int(pop.state.actors["25"].health)
	var hp26 := int(pop.state.actors["26"].health)
	var hp27 := int(pop.state.actors["27"].health)
	var loss := Rules.damage(origin, pop.bodies["25"].global_position, rules)
	if loss <= 0: return fail("probe source floor missing")
	scene.crates.open_crate(448)
	if not scene.crates.on_spark(448, 3): return fail("blast refused")
	if hp25 - int(pop.state.actors["25"].health) != loss: return fail("creature blast falloff")
	if hp26 != int(pop.state.actors["26"].health) or hp27 != int(pop.state.actors["27"].health): return fail("radius or flags gate")
	row27.flags = flags
	# A roaming shade beneath the closed roof survives; the same shade dies when opened.
	var lit: AABB = scene.atrium.light_volume
	pop.bodies["24"].global_position = Vector3(lit.get_center().x, 400, lit.get_center().z)
	pop.bodies["58"].global_position = pop.bodies["24"].global_position + Vector3(700, 0, 0)
	pop.bodies["28"].global_position = pop.bodies["24"].global_position
	var hp24 := int(pop.state.actors["24"].health)
	var hp58 := int(pop.state.actors["58"].health)
	var hp28 := int(pop.state.actors["28"].health)
	if not scene.atrium.apply_sunlight().is_empty() or int(pop.state.actors["24"].health) != hp24: return fail("closed roof killed shade")
	scene.atrium.open_roof()
	if int(pop.state.actors["24"].health) != 0 or pop.bodies["24"].collision_layer != 0: return fail("sunlight did not kill shade")
	if int(pop.state.actors["58"].health) != hp58 or int(pop.state.actors["28"].health) != hp28: return fail("sunlight escaped roof or killed Rat")
	# Later entrants also die, not just shades present at the pull.
	pop.bodies["58"].global_position = pop.bodies["24"].global_position
	if not "58" in scene.atrium.apply_sunlight(): return fail("later shade survived sunlight")
	var saved: Dictionary = snapshot()
	var error: String = scene.apply_save(before)
	if not error.is_empty(): return fail("earlier restore: " + error)
	if scene.atrium.is_open() or scene.crates.state_of(448) != 0 or not scene.crates.door_blocking(): return fail("earlier restore kept puzzle changes")
	if int(pop.state.actors["24"].health) != hp24: return fail("earlier restore kept sunlight death")
	error = scene.apply_save(saved)
	if not error.is_empty(): return fail("later restore: " + error)
	if not scene.atrium.is_open() or int(pop.state.actors["24"].health) != 0 or int(pop.state.actors["25"].health) != hp25-loss: return fail("later restore lost damage")
	# Environment does not award a weapon/spell hit. Compare earned checkpoints, excluding population/puzzle packets.
	var after: Dictionary = scene.quest_state.duplicate(true)
	for key in ["dark_halls_population", "dark_halls_crates", "dark_halls_atrium"]:
		xp.erase(key)
		after.erase(key)
	# Disk JSON canonicalizes integer/float and StringName keys, so compare both on the same wire representation.
	if JSON.parse_string(JSON.stringify(xp)) != JSON.parse_string(JSON.stringify(after)): return fail("environment changed unrelated quests or XP")
	print("PASS dark_halls_environment: blast falloff/flags/radius; closed/open roof, later entrants, rats/outside shade; earlier/later save restore and no XP")
	quit(0)

func snapshot() -> Dictionary:
	var path := "user://tests/bh09_snapshot.json"
	var error: String = scene.quicksave(path)
	if not error.is_empty():
		push_error(error)
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))
