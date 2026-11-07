extends SceneTree
## Owner reports 11:05:57/11:06:35: after the control104 trap (group9994 closes
## gate movable73, sets lever72 state1), the only reachable source lever is 72.
## Actual W walking from the plate, actual E on the visible lever face, then
## actual walking through the reopened north corridor. One Space press leaves
## the lever ledge (5-unit lip; host has no automatic step, as at the doorway).
var cave
var walk_log: Array=[]
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:
	push_error(message);quit(1)
func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func walk_to(target: Vector2, frames: int, jump_at: int=-1) -> Vector3:
	var destination: Vector3=cave.native_translation+Vector3(target.x,0,target.y)
	key(KEY_W,true)
	for i in range(frames):
		if i==jump_at:key(KEY_SPACE,true)
		if i==jump_at+1:key(KEY_SPACE,false)
		cave.player.look_at(Vector3(destination.x,cave.player.global_position.y,destination.z));cave.camera.rotation=Vector3.ZERO
		await physics_frame
		var position: Vector3=cave.player.global_position
		if Vector2(position.x-destination.x,position.z-destination.z).length()<8:break
	key(KEY_W,false)
	for i in range(4):await physics_frame
	var reached: Vector3=cave.player.global_position-cave.native_translation
	walk_log.append([target,reached]);print("WALK ",target," -> ",reached)
	return reached
func press_e() -> void:
	cave.set_physics_process(true)
	key(KEY_E,true);await process_frame;key(KEY_E,false)
	for i in range(3):await physics_frame
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready or cave.guard_encounter==null:return fail("Main Cave guard owner unavailable")
	cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var controller: Node3D=cave.guard_encounter
	cave.player.global_position=cave.native_translation+Vector3(-9,-245,-16615);cave.player.velocity=Vector3.ZERO
	for i in range(30):await physics_frame
	if controller.state.sequence.phase!="playing":return fail("Plate did not start the source guard sequence")
	for i in range(4000):
		controller.advance(1.0/60,true,cave.cave_local7)
		if controller.state.sequence.phase=="complete":break
	if controller.state.sequence.phase!="complete" or controller.input_locked():return fail("Guard sequence did not release")
	for i in range(400):await physics_frame
	var gate: Node3D=controller.movement.bodies["73"];var lever: Node3D=controller.movement.bodies["72"]
	if controller.state.movable_states["72"]!=1 or absf(gate.global_position.y-cave.native_translation.y+275)>0.5:return fail("Trap did not close source gate73")
	# Negative control: closed gate73 stops the north corridor at x<153.
	await walk_to(Vector2(40,-16450),400)
	var blocked: Vector3=await walk_to(Vector2(245,-16447),400,60)
	if blocked.x>147:return fail("Closed gate73 did not block the corridor")
	await walk_to(Vector2(40,-16600),400)
	await walk_to(Vector2(-60,-16700),400)
	await walk_to(Vector2(-68.5,-16734.4),400)
	# Refusal: E while looking away from the lever changes nothing.
	cave.camera.look_at(cave.player.global_position+Vector3(50,cave.camera.position.y,0))
	await physics_frame
	var refused: Dictionary=controller.checkpoint()
	await press_e();cave.set_physics_process(false)
	if controller.checkpoint()!=refused:return fail("E without an aimed lever changed the encounter")
	cave.camera.rotation=Vector3.ZERO
	var visible: Vector3=lever.to_global(controller.movement.face_centers["72"][2])
	cave.camera.look_at(visible)
	await physics_frame
	if controller.target_lever()!=72:return fail("Visible lever72 face was not targetable from the walked owner position")
	await process_frame
	if cave.interaction_prompt.text!="E · Pull lever":return fail("Lever72 prompt reads '%s', not 'E · Pull lever'"%cave.interaction_prompt.text)
	await press_e()
	for i in range(600):await physics_frame
	if controller.state.movable_states["72"]!=0 or absf(gate.global_position.y-cave.native_translation.y+175)>0.5:return fail("Actual E did not reopen gate73")
	cave.camera.rotation=Vector3.ZERO
	await walk_to(Vector2(-56,-16696),400,20)
	await walk_to(Vector2(41,-16595),400)
	await walk_to(Vector2(40,-16450),400)
	var passed: Vector3=await walk_to(Vector2(245,-16447),400,60)
	if passed.x<200 or not cave.player.is_on_floor():return fail("Reopened gate73 corridor was not walkable")
	print("PASS trap closes gate73; actual walk to lever72, refusal, actual E reopens gate73, actual walk through corridor. Bounded fixture: plate start pose, sequence clock advanced; no campaign/owner claim.")
	controller.movie.voice.stop();controller.delayed_voice.stop()
	await physics_frame
	cave.queue_free();await process_frame;await process_frame;quit()
