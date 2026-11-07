extends SceneTree
## Dark Halls original Rats/SHADEs (tools/prepare_dark_halls_population.py) on the generic scripted creature owner:
## 50 present actors; the nearest Rat hunts and bites the player; a production melee strike hurts it and pays
## fighting experience; a killed Rat stays dead across quicksave/quickload (state in quests.dark_halls_population).
const State = preload("res://scripts/lol2/scripted_creature_state.gd")
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_creatures: ", message); quit(1); return false
func step(pop, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		pop.advance(1.0 / 60.0); await physics_frame; t += 1.0 / 60.0
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pop = scene.get("creatures")
	if pop == null or pop.bodies.size() != 51: return fail("Expected 51 creatures")
	pop.set_physics_process(false); pop.set_process(false)
	var rats := 0
	for row in pop.src.actors: rats += 1 if int(row.definition) == 1 else 0
	if rats != 31: return fail("Expected 31 Rats, got %d" % rats)
	# Rat55 sits 227 units from the arrival: stand 90 units away and let it come.
	var rat: CharacterBody3D = pop.bodies["55"]
	scene.player.global_position = rat.global_position + Vector3(90, 34, 0)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(rat.global_position + Vector3(0, 6, 0))
	scene.health = 30
	var waited := 0.0
	while scene.health == 30 and waited < 15.0:
		await step(pop, 0.25); waited += 0.25
	if scene.health >= 30: return fail("Rat55 never bit the player")
	scene.health = 30
	# Production melee strike from where it bit the player (same side of the shelves).
	scene.camera.look_at(rat.global_position + Vector3(0, 6, 0))
	await physics_frame
	# Rats now have sprite-sized bodies (DEVIATIONS 2026-10-24): a second hunting Rat that reached the player in front
	# of Rat55 takes the strike; it must still be a biting Rat, not a miss.
	var target: String = pop.aimed()
	if target.is_empty() or int(State.actor_row(pop.src, target).definition) != 1 or pop.bodies[target].global_position.distance_to(scene.player.global_position) > rat.global_position.distance_to(scene.player.global_position) + 1.0:
		return fail("Melee aim found no Rat in front of the player (aimed '%s')" % target)
	var hp: int = pop.state.actors[target].health
	var before: String = JSON.stringify(scene.quest_state.get("player_reward_state", {}))
	if not pop.strike() or pop.state.actors[target].health >= hp: return fail("Melee strike on Rat%s failed" % target)
	if JSON.stringify(scene.quest_state.get("player_reward_state", {})) == before and scene.quest_state.get("dark_halls_population") == null: return fail("Strike left no fighting record")
	# Kill it; the death persists through the quests and a disk save.
	pop.receive_damage("55", 999, false)
	await step(pop, 3.0)
	if int(pop.state.actors["55"].health) != 0: return fail("Rat55 survived")
	var path := "user://tests/dark_halls_creatures.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	pop.state.actors["55"].health = 100
	var saved := preload("res://scripts/lol2/jungle_save.gd").read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty() or int(scene.creatures.state.actors["55"].health) != 0: return fail("Reload revived Rat55: %s" % error)
	print("PASS dark_halls_creatures: 51 original creatures (31 Rats, 19 Shades, Rix); Rat55 bites, melee strike hurts it, its death survives quicksave/quickload")
	quit(0)
