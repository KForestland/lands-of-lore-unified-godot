extends SceneTree
## Owner-approved modern "Force gate" action (2026-10-25) on the real Jungle host, rendered: real camera aim, real E key,
## and ordinary grounded walking through the broken leaf. Supplied story state: the alarm closes the gate through the
## alarm owner's target API, Killed_Confidante comes from the Confidante owner's own kill group on its pure state.
## - Alert only: aiming at closed leaf78 shows "The gate is barred ..."; E changes nothing; the held item stays in hand.
## - Alert and kill: the hint reads "E — Force gate (puts away ...)"; E puts the carried item away (still carried),
##   leaf78 loses mesh and collision, the fallen leaf81 shows, sound452 plays; leaf79 stays closed.
## - Luther walks with move_grounded through the leaf78 gap from inside to outside the village; leaf79 still blocks.
const Confidante=preload("res://scripts/lol2/jungle_confidante_state.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func place(at: Vector2) -> void:
	var top:=Vector3(at.x,200,at.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	scene.player.global_position=Vector3(at.x,(hit.position.y if not hit.is_empty() else 0.0)+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)
	scene.player.velocity=Vector3.ZERO
	await physics_frame
func press_e() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	Input.parse_input_event(key);await process_frame
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key);await process_frame
func walk(to: Vector2, frames: int) -> void:
	for i in frames:
		var off:=to-Vector2(scene.player.global_position.x,scene.player.global_position.z)
		if off.length()<4: return
		scene.move_grounded(Vector3(off.x,0,off.y).normalized(),1.0/60.0)
		await physics_frame
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var g=scene.gate_leaves;var a=scene.village_alarm
	if not check(is_instance_valid(g) and is_instance_valid(a),"Gate leaves owner missing"): return
	scene.raise_huline_alert()
	a.request_movable(78,0);a.request_movable(79,0)
	for i in 300: scene.village_gate.advance(1.0/30.0)
	if not check(int(scene.village_gate.pose)==0,"Gate not closed: pose %d"%scene.village_gate.pose): return
	var aim:=Vector3(-1378,40,-5300)
	await place(Vector2(-1440,-5300));scene.camera.look_at(aim);await physics_frame
	scene.hand_item=Save.Museum.SWORD
	if not check(g.target()==78 and g.interaction_hint().begins_with("The gate is barred"),"Refusal hint: target %d '%s'"%[g.target(),g.interaction_hint()]): return
	await press_e()
	if not check(not scene.village_gate.leaf_removed(78) and scene.hand_item==Save.Museum.SWORD,"Refused E changed the gate or the hand"): return
	var cs: Dictionary=scene.confidante.state.duplicate(true);var csrc: Dictionary=scene.confidante.src
	var cctx:={"locals":{"6":0,"33":0},"shared":{"0":5,"25":0,"29":1,"47":1}}
	Confidante.sight(cs,csrc,1465,cctx);Confidante.hit(cs,csrc,123,cctx,8)
	if not check(scene.confidante.restore({"version":1,"state":cs,"inside":[]}).is_empty() and scene.confidante.killed(),"Supplied kill rejected"): return
	if not check(g.interaction_hint().begins_with("E — Force gate (puts away"),"Hint: '%s'"%g.interaction_hint()): return
	await press_e()
	if not check(scene.village_gate.leaf_removed(78) and not scene.village_gate.leaf_removed(79) and g.panels["81"].visible and scene.hand_item=="" and Save.Museum.SWORD in scene.carried_collected and g.crash.playing,"Force gate result"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/gate_leaves_forced.png")
	await walk(Vector2(-1300,-5300),900)
	if not check(scene.player.global_position.x>-1330,"Grounded walk did not pass the leaf78 gap: %s"%scene.player.global_position): return
	await place(Vector2(-1440,-5200));await walk(Vector2(-1300,-5200),600)
	if not check(scene.player.global_position.x<-1360,"Walked through closed leaf79: %s"%scene.player.global_position): return
	print("PASS jungle_gate_leaves_force_test: refusal hint without kill, Force gate E with stowed held item, leaf78 removed (mesh/collision), fallen leaf81, sound452, grounded walk through the gap, leaf79 still blocks. Supplied alert/kill; owner-approved modern binding.")
	quit()
