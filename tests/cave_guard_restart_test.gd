extends SceneTree
const Save=preload("res://scripts/lol2/walkthrough_save.gd")
var cave
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:
	push_error(message);quit(1)
func run() -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://tests/cave_guard_restart_receipt.json"))
	if not receipt is Dictionary or FileAccess.get_sha256(receipt.path)!=str(receipt.sha256):return fail("Missing/hash-mismatched fresh-process guard fixture")
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var error: String=cave._quickload(receipt.path)
	if not error.is_empty():return fail(error)
	var saved: Dictionary=Save.read_save(receipt.path,cave._checkpoint_count()).state
	if cave.guard_encounter.state.sequence.elapsed!=saved.guard_encounter.encounter.sequence.elapsed:return fail("Fresh process lost movie clock")
	if not cave.guard_encounter.input_locked() or cave.starting_magic.world_active():return fail("Fresh process lost encounter lock")
	var paused: Dictionary=cave.guard_encounter.checkpoint()
	for i in range(6):await physics_frame
	if cave.guard_encounter.checkpoint()!=paused:return fail("Fresh paused restore advanced")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in range(3600):
		await physics_frame
		if cave.guard_encounter.state.sequence.phase=="complete":break
	if cave.guard_encounter.state.sequence.phase!="complete" or cave.guard_encounter.input_locked():return fail("Fresh resumed guard sequence did not release")
	# Bounded input probe at the owner's reported lever position, not a full approach claim.
	cave.player.global_position=cave.native_translation+Vector3(-68.54,-257.988,-16734.385);cave.player.velocity=Vector3.ZERO
	for i in range(30):await physics_frame
	var lever: Node3D=cave.guard_encounter.movement.bodies["72"]
	cave.camera.look_at(lever.global_position)
	await physics_frame
	print("LEVER72 target=",cave.guard_encounter.target_lever()," position=",cave.player.global_position-cave.native_translation)
	if cave.guard_encounter.target_lever()!=72:return fail("Owner lever pose did not target movable72")
	var before: int=cave.guard_encounter.state.movable_states["72"]
	var event:=InputEventKey.new();event.keycode=KEY_E;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	var release:=InputEventKey.new();release.keycode=KEY_E;release.pressed=false;Input.parse_input_event(release)
	for i in range(3):await physics_frame
	if cave.guard_encounter.state.movable_states["72"]!=1-before:return fail("Actual E failed to toggle source lever72")
	print("PASS hash-linked fresh-process midmovie restore, paused lock, normal host clock through all clips/release, actual E lever72 from reported pose. Full campaign and other levers untested.")
	cave.guard_encounter.movie.voice.stop();cave.guard_encounter.delayed_voice.stop()
	await physics_frame;await physics_frame
	cave.queue_free();await process_frame;await process_frame;quit()
