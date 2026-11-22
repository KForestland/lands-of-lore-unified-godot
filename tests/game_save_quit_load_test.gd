extends SceneTree
## Two-process F-07 integration. Supplied local standing checkpoint + explicit native
## handoff calls are test aids; only the door and save/Continue use real input.
## No unaided cross-map/campaign claim. Body physics stays live, no recovery or top-ups.
var scene: Node
var phase := 0
var proof := ""
const REF := "movable:115"
const FIXTURE := "res://tests/fixtures/saves_d5da60a/areas/L9_DR.json"
func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i in count: await physics_frame
func tap(code: Key) -> void:
	await process_frame
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func aim(point: Vector3) -> void:
	var d: Vector3=point-scene.camera.global_position
	var yaw:=atan2(-d.x,-d.z);var pitch:=atan2(d.y,Vector2(d.x,d.z).length())
	var event:=InputEventMouseMotion.new()
	event.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
	Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func capture() -> void:
	root.grab_focus();scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func settled() -> void:
	for i in 1800:
		await process_frame
		if scene.get("ready_for_review") and scene.get("starting_magic")!=null:break
	capture();await ticks(24)
func transfer(level: int, selector: int, path: String) -> void:
	# Explicit handoff aid: no claim that the route between local controls was walked.
	scene.progression._change_level({"level":level,"selector":selector,"scene":path})
	await scene_changed;scene=current_scene;await settled()
func bank_api():
	return ResourceLoader.load("res://scripts/lol2/game_save.gd") if ResourceLoader.exists("res://scripts/lol2/game_save.gd") else null
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-phase="):phase=int(arg.get_slice("=",1))
		if arg.begins_with("--save-proof="):proof=arg.substr(13)
	if phase==1:
		scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false
		root.add_child(scene);current_scene=scene;await settled()
		var state: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		state.player.position=[-1387,52,-8516] # One supplied local start, before real input begins.
		assert(scene.apply_save(state).is_empty())
		# Supplied unlocked door state: native E can toggle it; obtaining its key is outside this local proof.
		scene.progression.native.call("set_field",REF,"byte_0x25",1)
		capture();await ticks(24)
		assert(scene.player.is_on_floor() and scene.starting_magic.health()>0 and scene.resets==0)
		await aim(scene.progression.movable_position(115));await ticks(2)
		assert(scene.progression.aimed()==115,"real native door aimed")
		var closed_transform:Transform3D=scene.progression.hinges[115].global_transform
		var initial: int=scene.progression.native.field(REF,"travel_0x50",0)
		print("DOOR BEFORE attrs=",scene.progression.native.attributes[REF]," state=",scene.progression.native.state.get(REF)," aimed_exit=",scene.progression.aimed_exit()," mode=",Input.mouse_mode," active=",scene.starting_magic.world_active())
		await tap(KEY_E);await ticks(180)
		print("DOOR AFTER travel=",scene.progression.travel[115]," state=",scene.progression.native.state.get(REF)," log=",scene.progression.route_log.slice(-6))
		var travel: int=scene.progression.travel[115]
		assert(travel!=initial,"real E changes native travel")
		assert(scene.progression.hinges[115].global_basis.x.distance_to(closed_transform.basis.x)>0.5,"real E rotates the physical door")
		var packet: Dictionary={"travel":travel,"byte25":scene.progression.native.field(REF,"byte_0x25",0),"position":var_to_str(scene.progression.hinges[115].position),"transform":var_to_str(scene.progression.hinges[115].global_transform),"initial":initial}
		if bank_api()!=null:packet["vm"]=scene.progression.native.snapshot()
		var file:=FileAccess.open(proof+"/door.json",FileAccess.WRITE);file.store_string(JSON.stringify(packet));file.close()
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(proof+"/door_open.png")
		assert(scene.resets==0)
		await transfer(8,1,"res://scenes/lol2/darker_jungle.tscn")
		assert(scene.can_save().is_empty() if scene.has_method("can_save") else true)
		await tap(KEY_F5);await ticks(6)
		var api=bank_api()
		if api!=null:
			var saved: Dictionary=api.read_document(api.slot_path(1))
			assert(saved.error.is_empty() and saved.state.native_bank.has("L9_DR"),"F5 includes previous native level")
		else:assert(FileAccess.file_exists(scene.area_save_path))
		assert(scene.resets==0 and scene.starting_magic.health()>0)
		print("PASS phase1: real E moved native door; explicit handoff aid to L8; real F5; resets=0")
		quit();return
	var api=bank_api()
	if api!=null:
		var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate();root.add_child(gate);current_scene=gate
		await process_frame
		gate.path_field.text=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
		var button: Button=gate.find_child("Continue",true,false)
		assert(button!=null and not button.disabled)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(proof+"/continue_menu.png")
		print("CONTINUE RECT ",button.get_global_rect()," viewport ",root.get_visible_rect())
		assert(root.get_visible_rect().has_point(button.get_global_rect().get_center()),"Continue is visible inside the real window")
		button.grab_focus();await tap(KEY_ENTER)
		if current_scene==gate:await scene_changed
		scene=current_scene;await settled()
	else:
		# The unchanged d5 reader has no bank: this process proves the lost door state.
		var saved: Dictionary=load("res://scripts/lol2/jungle_save.gd").read_save("user://saves/darker_jungle_quicksave.json","lol2-restoration-darker-jungle")
		assert(saved.error.is_empty());set_meta("lol2_darker_resume",saved.state)
		scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
	await transfer(9,0,"res://scenes/lol2/dragon_level.tscn")
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(proof+"/door.json"))
	assert(scene.progression.travel[115]==int(expected.travel),"native door survived process restart")
	assert(scene.progression.native.field(REF,"byte_0x25",0)==int(expected.byte25),"native door selector restored")
	await ticks(120) # Existing mover easing, as on a level revisit, settles without changing its rule.
	var transform:Transform3D=str_to_var(expected.transform)
	var actual:Transform3D=scene.progression.hinges[115].global_transform
	var physical:Transform3D=PhysicsServer3D.body_get_state(scene.progression.mover_bodies[115].get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
	for pose in [actual,physical]:
		assert(pose.origin.distance_to(transform.origin)<0.01,"door origin restored")
		for axis in 3:assert(pose.basis[axis].distance_to(transform.basis[axis])<0.002,"full visual/physics door orientation restored")
	assert(scene.resets==0 and scene.starting_magic.health()>0)
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(proof+"/door_restored.png")
	print("PASS phase2: real Continue and native handoff restores L9 VM and physical door; resets=0")
	quit()
