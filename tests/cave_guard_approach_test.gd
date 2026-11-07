extends SceneTree
const Save=preload("res://scripts/lol2/walkthrough_save.gd")
var cave
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:
	push_error(message);quit(1)
func key(code: int) -> void:
	var down:=InputEventKey.new();down.keycode=code;down.pressed=true;Input.parse_input_event(down)
	await process_frame
	var up:=InputEventKey.new();up.keycode=code;up.pressed=false;Input.parse_input_event(up)
	await process_frame
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready or cave.guard_encounter==null:return fail("Main Cave guard owner unavailable")
	cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Owner report11:05:57 encounter position; normal W movement into the plate.
	cave.player.global_position=cave.native_translation+Vector3(244.648,-252.954,-16447.025);cave.player.velocity=Vector3.ZERO
	for i in range(12):await physics_frame
	var walk:=InputEventKey.new();walk.physical_keycode=KEY_W;walk.keycode=KEY_W;walk.pressed=true;Input.parse_input_event(walk)
	for waypoint in [Vector2(100,-16430),Vector2(0,-16615)]:
		var destination: Vector3=cave.native_translation+Vector3(waypoint.x,0,waypoint.y)
		cave.player.look_at(Vector3(destination.x,cave.player.global_position.y,destination.z));cave.camera.rotation=Vector3.ZERO
		for i in range(240):
			await physics_frame
			if waypoint==Vector2(100,-16430) and i in [60,61]:
				var jump:=InputEventKey.new();jump.keycode=KEY_SPACE;jump.physical_keycode=KEY_SPACE;jump.pressed=i==60;Input.parse_input_event(jump)
			if cave.guard_encounter.state.sequence.phase=="playing":break
			var position: Vector3=cave.player.global_position
			if Vector2(position.x-destination.x,position.z-destination.z).length()<12:break
		print("APPROACH_WAYPOINT ",waypoint," actual=",cave.player.global_position-cave.native_translation)
		if cave.guard_encounter.state.sequence.phase=="playing":break
	var stop:=InputEventKey.new();stop.physical_keycode=KEY_W;stop.keycode=KEY_W;stop.pressed=false;Input.parse_input_event(stop)
	await process_frame
	print("OWNER_APPROACH native=",cave.player.global_position-cave.native_translation," phase=",cave.guard_encounter.state.sequence.phase)
	for i in range(cave.player.get_slide_collision_count()):
		var hit: KinematicCollision3D=cave.player.get_slide_collision(i)
		print("APPROACH_COLLISION ",hit.get_collider()," point=",hit.get_position()-cave.native_translation," normal=",hit.get_normal())
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/cave_guard_approach.png")
	if cave.guard_encounter.state.sequence.phase!="playing":return fail("Normal host did not trigger grounded guard encounter")
	if not cave.guard_encounter.input_locked() or cave.starting_magic.world_active():return fail("Encounter failed to lock movement/spell consumers")
	var mana: int=cave.starting_magic.magic_state().player.mana
	await key(KEY_Q)
	if cave.starting_magic.magic_state().player.mana!=mana:return fail("Spell consumed mana during guard movie")
	await key(KEY_ESCAPE);await physics_frame
	var paused: Dictionary=cave.guard_encounter.checkpoint()
	for i in range(6):await physics_frame
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE or cave.guard_encounter.checkpoint()!=paused:return fail("Escape failed to pause guard movie")
	await key(KEY_F5)
	var read:=Save.read_save(Save.DEFAULT_PATH,cave._checkpoint_count())
	if not read.error.is_empty() or not read.state.has("guard_encounter"):return fail("F5 did not save guard packet: "+str(read.error))
	DirAccess.make_dir_recursive_absolute("user://tests")
	var fixture:=FileAccess.open("user://tests/cave_guard_midmovie.json",FileAccess.WRITE);fixture.store_string(JSON.stringify(read.state));fixture.close()
	var witness:=FileAccess.open("user://tests/cave_guard_restart_receipt.json",FileAccess.WRITE);witness.store_string(JSON.stringify({"path":"user://tests/cave_guard_midmovie.json","sha256":FileAccess.get_sha256("user://tests/cave_guard_midmovie.json")}));witness.close()
	var saved: Dictionary=read.state.guard_encounter
	var pos: Vector3=cave.player.global_position
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;Input.parse_input_event(click)
	await process_frame
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;Input.parse_input_event(release)
	for i in range(12):await physics_frame
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or cave.guard_encounter.state.sequence.elapsed<=saved.encounter.sequence.elapsed:return fail("Click failed to resume guard clock")
	await key(KEY_ESCAPE);await key(KEY_F9)
	if cave.guard_encounter.state.sequence.elapsed!=saved.encounter.sequence.elapsed or cave.player.global_position.distance_to(pos)>0.1:return fail("F9 did not restore saved guard clock/position")
	var bad: Dictionary=read.state.duplicate(true);bad.cave_local7=2
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file:=FileAccess.open("user://tests/cave_guard_invalid.json",FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	var before: Dictionary=cave.guard_encounter.checkpoint()
	if cave._quickload("user://tests/cave_guard_invalid.json").is_empty() or cave.guard_encounter.checkpoint()!=before:return fail("Invalid Cave local bank mutated live encounter")
	print("PASS main Cave automatic grounded entry, movement/spell lock, actual Escape/click pause/resume, F5/F9 midmovie clock/position continuity, atomic invalid local bank. No full approach/campaign claim.")
	cave.guard_encounter.movie.voice.stop();cave.guard_encounter.delayed_voice.stop()
	await physics_frame;await physics_frame
	cave.queue_free();await process_frame;await process_frame;quit()
