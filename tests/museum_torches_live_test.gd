extends SceneTree
## Actual Museum host (docs/museum-torches.md): Spark on the pilot flame before the plate does nothing; E on the wall
## plate (movable52) through the host's input handler, then Spark through the shared spell ray -> all 35 torches lit,
## exactly one magic level; a second Spark awards nothing. Disk save + receipt for museum_torches_restart_test.
## SUPPLIED: camera vantages (searched around the plate/pilot), world gate of the spell owner (headless mouse).
const Torches = preload("res://scripts/lol2/museum_torches.gd")
const SAVE := "user://tests/museum_torches_lit.json"
const RECEIPT := "user://tests/museum_torches_receipt.json"
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
var museum
var torches
var spells
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		quit(1)
	return ok
func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	museum._unhandled_input(event)
func pose(target: Vector3, ok: Callable) -> bool:
	for distance in [40.0, 60.0, 25.0, 80.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			for lift in [0.0, -10.0, 10.0]:
				var eye: Vector3 = target + d * distance + Vector3(0, lift, 0)
				museum.player.position = eye - Vector3(0, museum.camera.position.y, 0)
				museum.player.rotation = Vector3.ZERO
				museum.camera.rotation = Vector3.ZERO
				museum.camera.look_at(target)
				await physics_frame
				if ok.call(): return true
	return false
## The shared Spark ray (player_starting_magic.spark: mask 3, player excluded) reaches the pilot's volume first.
func ray_hits_pilot() -> bool:
	var origin: Vector3 = museum.camera.global_position
	var q := PhysicsRayQueryParameters3D.create(origin, origin - museum.camera.global_basis.z * 384, 3, [museum.player.get_rid()])
	var hit: Dictionary = museum.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == torches.bodies[Torches.PILOT]
func ready_spark() -> void:
	var saved: Dictionary = spells.magic_state().duplicate(true)
	saved.cooldown = 0.0
	saved.player.mana = maxi(int(saved.player.mana), 5)
	spells.commit(saved)
	spells.select_spell("spark")
func level() -> int: return int(spells.magic_state().player.level)
func run() -> void:
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in 5: await process_frame
	museum.set_physics_process(false)
	torches = museum.museum_torches
	if not check(torches != null and torches.torches.size() == 35 and torches.state == Torches.initial(), "Museum torches missing or not fresh"): return
	museum.starting_magic.set_process(false)
	spells = TestMagic.new(); museum.add_child(spells); spells.set_process(false); museum.starting_magic = spells
	var pilot: Vector3 = torches.bodies[Torches.PILOT].global_position
	# Native order: before the plate the pilot's predicate (owner state == 1) is false.
	if not check(await pose(pilot, ray_hits_pilot), "No vantage where the Spark ray reaches the pilot flame"): return
	ready_spark()
	var level0 := level()
	if not check(spells.cast() and torches.state.lit.is_empty() and not torches.state.pilot_spent and level() == level0, "Spark before the plate changed the torches"): return
	# E on the plate through the host's own E handler.
	var aim: Array = torches.source.switch.aim
	if not check(await pose(Vector3(aim[0], aim[1], aim[2]), torches.offered), "No vantage offers the wall plate"): return
	press_e()
	if not check(int(torches.state.pilot_state) == 1 and torches.state.lit.is_empty(), "E did not press the plate"): return
	# Spark through the shared ray: one magic level, every torch lit.
	if not check(await pose(pilot, ray_hits_pilot), "No vantage back to the pilot"): return
	ready_spark()
	if not check(spells.cast(), "Spark refused"): return
	if not check(torches.state.pilot_spent and torches.state.lit.size() == 35 and torches.awards == 1 and level() == level0 + 1, "Plate+Spark: lit %d awards %d level %d->%d" % [torches.state.lit.size(), torches.awards, level0, level()]): return
	ready_spark()
	if not check(spells.cast() and torches.awards == 1 and level() == level0 + 1, "Second Spark awarded again"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var error: String = museum.quicksave(SAVE)
	if not check(error.is_empty(), "Torch save: " + error): return
	var receipt := {"save": SAVE, "sha256": FileAccess.get_sha256(SAVE), "level": level(), "level_before": level0}
	var file := FileAccess.open(RECEIPT, FileAccess.WRITE); file.store_string(JSON.stringify(receipt)); file.close()
	print("PASS museum torches live: Spark before plate inert; E plate; Spark lights 35 and awards one magic level (%d->%d); second Spark nothing; disk save + receipt" % [level0, level()])
	quit()
