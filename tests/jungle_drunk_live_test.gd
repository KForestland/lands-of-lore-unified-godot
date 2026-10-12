extends SceneTree
const Save=preload("res://scripts/lol2/jungle_save.gd")
var scene
var drunk
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> bool:
	if not value:push_error(message);quit(1)
	return value
func run() -> void:
	await open_host()
	# Supplied approach; later input must hit the real target.
	scene.player.set_physics_process(false)
	scene.player.global_position=drunk.anchor()+Vector3(41,32,56)
	var starter: Array=drunk.src.starters[0].position
	var sight_target: Vector3=Vector3(starter[0],starter[1]+40,starter[2])+drunk.origin()
	scene.player.look_at(Vector3(sight_target.x,scene.player.global_position.y,sight_target.z));scene.camera.look_at(sight_target)
	for i in 3:await physics_frame
	drunk.advance(0.05)
	if not check(drunk.mesh.visible and drunk.barrier.collision_layer==1,"Actual source sighting did not start encounter"):return
	scene.player.look_at(Vector3(drunk.anchor().x,scene.player.global_position.y,drunk.anchor().z));scene.camera.look_at(drunk.anchor()+Vector3.UP*35)
	for i in 3:await physics_frame
	var ray=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*140,1,[scene.player.get_rid()])
	if not check(drunk.aimed(),"Drunk targeting ray missed"):return
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp/drunk_captures")
	root.get_texture().get_image().save_png("res://tmp/drunk_captures/idle.png")
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	Input.parse_input_event(key);await process_frame;key=key.duplicate();key.pressed=false;Input.parse_input_event(key);await process_frame
	if not check(drunk.movement_locked() and int(scene.village_alarm.state.locals["7"])==1,"Real E did not start talk"):return
	drunk.advance(2.0)
	var path:="user://tests/drunk_live.json"
	if not check(scene.quicksave(path).is_empty(),"Mid-line save failed"):return
	var before: Dictionary=drunk.checkpoint()
	drunk.advance(3.0)
	var load_error: String=scene.quickload(path)
	if not check(load_error.is_empty() and drunk.checkpoint()==before,"Mid-line reload differs"):return
	paused=true;drunk.advance(4.0);paused=false
	if not check(drunk.checkpoint()==before,"Paused encounter advanced"):return
	drunk.advance(40.0)
	if not check(not drunk.movement_locked() and int(drunk.state.segment)==1,"Talk did not return to idle"):return
	scene.village_alarm.state.locals["7"]=2;drunk.advance(0.1)
	if not check(not drunk.mesh.visible and drunk.barrier.collision_layer==0,"Alarm retirement left blocker"):return
	await close_host()
	await open_host()
	if not check(scene.quickload(path).is_empty() and drunk.checkpoint()==before and drunk.movement_locked(),"Fresh-host mid-line restore differs"):return
	drunk.advance(40.0)
	if not check(not drunk.movement_locked(),"Fresh-host talk did not release movement"):return
	await close_host()
	# Independent hit branch through actual mouse input from the source approach.
	await open_host()
	drunk.dispatch("prop",484,5)
	scene.player.set_physics_process(false);scene.player.global_position=drunk.anchor()+Vector3(41,32,56)
	scene.player.look_at(Vector3(drunk.anchor().x,scene.player.global_position.y,drunk.anchor().z));scene.camera.look_at(drunk.anchor()+Vector3.UP*35)
	for i in 3:await physics_frame
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;Input.parse_input_event(click)
	await process_frame
	click=click.duplicate();click.pressed=false;Input.parse_input_event(click);await process_frame
	if not check(int(drunk.state.owner_state)==1 and int(drunk.state.segment)==2 and int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)==4,"Armed hit did not produce source reaction/soul loss"):return
	var malformed: Dictionary=drunk.checkpoint();var good: Dictionary=malformed.duplicate(true);malformed.state.segment=0.5
	if not check(not drunk.restore(malformed).is_empty() and drunk.checkpoint()==good,"Malformed restore changed live encounter"):return
	if not check(scene.quicksave(path).is_empty(),"Hit branch save failed"):return
	drunk.advance(8.0)
	if not check(int(drunk.state.segment)==-1 and scene.quickload(path).is_empty() and drunk.checkpoint()==good,"Hit reaction save/load differs"):return
	await close_host()
	print("PASS drunk live supplied approach: real E and armed hit, mid-line disk and fresh-host restore, pause, idle completion, soul loss, reaction reload, atomic malformed rejection and alarm retirement.")	
	quit()

func open_host() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5:await process_frame
	scene.set_physics_process(false)
	for node in scene.get_children():
		if node is Node3D and node!=scene.player:node.set_physics_process(false)
	drunk=scene.drunk
	assert(is_instance_valid(drunk))
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_host() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3:await process_frame
