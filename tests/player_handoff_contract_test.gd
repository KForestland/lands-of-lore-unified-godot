extends SceneTree
## Museum departure contract (docs/player-continuity.md), rendered with --demo-interface. The Cave side is the lead's
## cave_transfer_version gate (cave_museum_transfer_test). Here a test subclass of the real Museum host drops ONE field
## from the packet its production inventory_state() builds (a simulated broken adapter). For each required player field
## the production Museum departure (real E key at the Shining Path approach) must refuse, stay in the Museum with its
## state unchanged, publish no handoff meta, and show the reason on its interaction label.
## With nothing dropped the same departure travels (positive control) and the Jungle equals the Museum.
## Supplied: a real Cave packet built by the production _completion_state() after fighting XP 10 via the production
## cave_melee_reward rule, health 17 and mana 13 with Heal; Museum introduction skipped; player placed at the mirror
## approach.
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const Contract = preload("res://scripts/lol2/player_handoff_contract.gd")
const MuseumScript = preload("res://scripts/lol2/museum_walkthrough.gd")
const FIELDS := ["fighting", "magic", "health", "player_form", "curse", "item_effects", "collected", "equipped_item", "equipped_armor"]
var failed := false
var reasons := {}
var simulated_seconds := 0.0
var last_frame_seconds := 0.0
func _process(delta: float) -> bool:
	last_frame_seconds = maxf(0.0, delta)
	simulated_seconds += last_frame_seconds
	return false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
## A subclass of the real Museum whose inventory_state() can drop one field; full_packet() is the unmodified packer.
func museum_host() -> Node3D:
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/lol2/museum_walkthrough.gd"\nvar drop := ""\nfunc full_packet() -> Dictionary: return super.inventory_state()\nfunc inventory_state() -> Dictionary:\n\tvar packet: Dictionary = super.inventory_state()\n\tif drop != "": packet.erase(drop)\n\treturn packet\n'
	if script.reload() != OK: return null
	return script.new()
func wait_path(destination: String) -> Node:
	for i in 900:
		await process_frame
		var scene := current_scene
		if scene != null and is_instance_valid(scene) and scene.get_script() != null and str(scene.get_script().resource_path) == destination and (scene.get("walkthrough_ready") == null or scene.walkthrough_ready): break
	for i in 4: await process_frame
	return current_scene
func press_e() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
func run() -> void:
	# ---- A current Cave packet from the production packer ----
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false)
	cave.quest_state = preload("res://scripts/lol2/cave_melee_reward.gd").apply({}, 10, 99, 1).quests
	cave.starting_magic.set_health(17)
	var magic: Dictionary = cave.starting_magic.magic_state().duplicate(true); magic.player.mana = 13; magic.spell = "heal"
	cave.starting_magic.commit(magic)
	var full: Dictionary = cave._completion_state()
	cave.queue_free(); for i in 3: await process_frame
	if not check(MuseumScript.validate_cave_transfer(full, true).is_empty(), "production cave packet refused: " + MuseumScript.validate_cave_transfer(full, true)): return
	if has_meta(MuseumScript.CHECKPOINT_KEY): remove_meta(MuseumScript.CHECKPOINT_KEY)
	set_meta("lol2_cave_completion", full)
	# ---- Museum departure (real E key at the Shining Path approach) with a broken packer ----
	var m := museum_host()
	if not check(m != null, "museum test subclass did not compile"): return
	m.introduction_state = "complete"
	root.add_child(m); current_scene = m
	for i in 8: await process_frame
	if is_instance_valid(m.get("introduction")): m.introduction.close()
	if not check(Contract.missing_error(m.full_packet()).is_empty(), "complete museum packet refused: " + Contract.missing_error(m.full_packet())): return
	var museum_before := Continuity.from_packet(m.full_packet(), {})
	if not check(int(museum_before.get("health", 0)) == 17 and int(museum_before.get("fighting.experience", 0)) == 10 and museum_before.get("magic.spell") == "heal", "cave packet did not arrive: %s" % [museum_before]): return
	for field in FIELDS:
		m.drop = field
		m.player.global_position = Vector3(-4058, 16, -1381); m.player.rotation.y = 0.0; m.camera.rotation = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; m.interface_hud.set_cursor(false)
		for i in 3: await physics_frame
		if not check(m.can_enter_mirror(), "not at the mirror approach"): return
		var exact_before := JSON.stringify(m.checkpoint_state())
		press_e()
		if not check(JSON.stringify(m.checkpoint_state()) == exact_before, "synchronous refused departure changed canonical checkpoint (%s)" % field): return
		for i in 4: await process_frame
		if not check(is_instance_valid(m) and current_scene == m and not has_meta("lol2_jungle_handoff") and not m.mirror_transition_pending, "museum left without %s" % field): return
		var notice: String = m.interaction_label.text if m.interaction_label.is_visible_in_tree() else ""
		# Either the contract (names the field) or an existing validator refused it; both leave the Museum intact.
		if not check(not notice.is_empty() and not notice.begins_with("E —"), "museum refusal for %s not shown: '%s'" % [field, notice]): return
		reasons["museum without " + field] = notice
	m.drop = ""
	var departure := Continuity.from_packet(m.full_packet(), {})
	var departed := simulated_seconds
	var remainder: float = float(m.player_magic_checkpoint.regen_elapsed)
	press_e()
	var jungle = await wait_path("res://scripts/lol2/jungle_walkthrough.gd")
	if not check(jungle != null and jungle != m and jungle.has_method("area_handoff"), "complete museum packet did not travel"): return
	var allowance := Continuity.mana_allowance(int(departure["magic.mana"]), int(departure["magic.maximum"]), simulated_seconds - departed + 2.0 * last_frame_seconds, remainder)
	var errors := Continuity.compare(departure, Continuity.from_host(jungle), {"magic.mana": allowance})
	var reset_control := departure.duplicate(true)
	reset_control["magic.mana"] = departure["magic.maximum"]
	if not check(not Continuity.compare(departure, reset_control, {"magic.mana": Continuity.mana_allowance(int(departure["magic.mana"]), int(departure["magic.maximum"]), 0.0, 0.0)}).is_empty(), "reset-to-full mana negative control was admitted"): return
	print("DEPARTURE MANA ", JSON.stringify(allowance))
	if not check(errors.is_empty(), "museum->jungle positive control: %s" % [errors]): return
	jungle.queue_free(); for i in 3: await process_frame
	if has_meta("lol2_cave_completion"): remove_meta("lol2_cave_completion")
	if has_meta(MuseumScript.CHECKPOINT_KEY): remove_meta(MuseumScript.CHECKPOINT_KEY)
	print("PASS player_handoff_contract: %d fields each refused at the real Museum departure (Museum unchanged, no handoff meta, reason shown); the complete packet travels Museum->Jungle with no difference beyond bounded regeneration. Reasons: %s" % [FIELDS.size(), JSON.stringify(reasons)])
	quit()
