extends SceneTree
## New process after museum_torches_live_test: the hash-pinned disk save restores 35 lit torches, a spent pilot and the
## one awarded magic level; a further Spark on the pilot awards nothing. SUPPLIED: camera vantage, spell world gate.
const Live = preload("res://tests/museum_torches_live_test.gd")
const Torches = preload("res://scripts/lol2/museum_torches.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run() -> void:
	var receipt = JSON.parse_string(FileAccess.get_file_as_string(Live.RECEIPT)) if FileAccess.file_exists(Live.RECEIPT) else null
	if not check(receipt is Dictionary and FileAccess.get_sha256(Live.SAVE) == str(receipt.sha256), "Run museum_torches_live_test first (receipt/save hash)"): return
	set_meta("lol2_cave_completion", {"collected": [], "equipped_item": "", "health": 30})
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum); current_scene = museum
	for i in 5: await process_frame
	museum.set_physics_process(false)
	if not check(museum.quickload(Live.SAVE).is_empty(), "Fresh-process torch load"): return
	var torches = museum.museum_torches
	if not check(torches.state.pilot_spent and int(torches.state.pilot_state) == 1 and torches.state.lit.size() == 35, "Restored torches: %s" % [torches.state]): return
	for key in torches.torches:
		if not check(torches.is_lit(key) and torches.torches[key].base.material_override == torches.materials["holder_lit"], "Torch %s not drawn lit after restart" % key): return
	museum.starting_magic.set_process(false)
	var spells := TestMagic.new(); museum.add_child(spells); spells.set_process(false); museum.starting_magic = spells
	if not check(int(spells.magic_state().player.level) == int(receipt.level), "Magic level after restart %d, saved %d" % [int(spells.magic_state().player.level), int(receipt.level)]): return
	# Spark straight at the pilot volume through the shared ray.
	var pilot: Vector3 = torches.bodies[Torches.PILOT].global_position
	var found := false
	for distance in [40.0, 60.0, 25.0, 80.0]:
		for step in 16:
			if found: break
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			museum.player.position = pilot + d * distance - Vector3(0, museum.camera.position.y, 0)
			museum.player.rotation = Vector3.ZERO; museum.camera.rotation = Vector3.ZERO
			museum.camera.look_at(pilot)
			await physics_frame
			var origin: Vector3 = museum.camera.global_position
			var q := PhysicsRayQueryParameters3D.create(origin, origin - museum.camera.global_basis.z * 384, 3, [museum.player.get_rid()])
			var hit: Dictionary = museum.get_world_3d().direct_space_state.intersect_ray(q)
			found = not hit.is_empty() and hit.collider == torches.bodies[Torches.PILOT]
		if found: break
	if not check(found, "No vantage to the pilot after restart"): return
	var saved: Dictionary = spells.magic_state().duplicate(true)
	saved.cooldown = 0.0; saved.player.mana = maxi(int(saved.player.mana), 5); spells.commit(saved); spells.select_spell("spark")
	if not check(spells.cast() and torches.awards == 0 and int(spells.magic_state().player.level) == int(receipt.level), "Spark after restart awarded again"): return
	print("PASS museum torches restart: new process restores 35 lit, pilot spent, magic level %d kept; Spark awards nothing" % int(receipt.level))
	quit()
