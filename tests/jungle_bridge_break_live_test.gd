extends SceneTree
## Actual Jungle host, supplied west-bank position/beast form, grounded production movement/support calls (manual ticks; host input loop disabled).
## Run twice with --save-path=PATH and then --restart to prove a new process loads the produced save.
## This is focused bridge coverage, not an earned campaign or proof of the curse's form producer.
var scene
var failed := false
func check(ok: bool, message: String) -> bool:
	if not ok: failed=true;push_error(message);quit(1)
	return ok
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path := "user://tests/plank_bridge_test.json"
	var restart := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):path=arg.trim_prefix("--save-path=")
		if arg=="--restart":restart=true
	DirAccess.make_dir_recursive_absolute("user://tests")
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):break
	if not check(scene.get("ready_for_review") and is_instance_valid(scene.plank_bridge),"Bridge host not ready"):return
	var bridge=scene.plank_bridge
	if restart:
		var error: String=scene.quickload(path)
		if not check(error.is_empty(),"Restart save rejected: "+error):return
		await physics_frame;await physics_frame
		if not check(bridge.broken() and int(scene.static_assemblies.modes.get(210,-1))==1 and scene.static_assemblies.is_present(211),"Restart lost bridge presentation"):return
		if not check(bridge.creature_barrier.enabled and bridge.effect_log.is_empty(),"Restart lost creature refusal or replayed events"):return
		for mesh in bridge.debris.values():
			if not check(mesh.visible,"Restart lost linked debris"):return
		for audio in bridge.sounds.values():
			if not check(not audio.playing,"Restart replayed source sounds"):return
		var body: StaticBody3D=scene.static_assemblies.solid_bodies[210]
		if not check(body.collision_layer!=0,"Restart removed original whole-box collision"):return
		print("PASS jungle_bridge_break_live_test restart: fresh process preserves break/debris/creature refusal/collision without replaying sound")
		quit();return
	if not check(not bridge.broken() and not scene.static_assemblies.is_present(211),"Fresh bridge already broken or debris211 visible"):return
	for mesh in bridge.debris.values():
		if not check(not mesh.visible,"Fresh debris prop visible"):return
	var body: StaticBody3D=scene.static_assemblies.solid_bodies[210]
	var collision_id:=body.get_rid()
	var shape: Shape3D=body.get_child(0).shape
	scene.player_form=1
	preload("res://scripts/lol2/player_form_body.gd").apply(scene.player,scene.camera,1,false)
	scene.player.position=Vector3(760,32,1207);scene.player.velocity=Vector3.ZERO
	for i in 30:await physics_frame
	scene.set_physics_process(false)
	var lowest: float=scene.player.position.y
	for i in 1000:
		if scene.player.position.x>=1850:break
		scene.move_grounded(Vector3.RIGHT,1.0/60.0)
		bridge.advance()
		lowest=minf(lowest,scene.player.position.y)
		await physics_frame
	print("BRIDGE_DIAGNOSTIC ",scene.player.position," form=",scene.player_form," foot=",scene.player.is_on_floor()," state=",bridge.state()," effects=",bridge.effect_log)
	if not check(scene.player.position.x>=1850 and lowest>-20,"Beast failed grounded bridge traversal"):return
	if not check(bridge.broken() and int(scene.static_assemblies.modes.get(210,-1))==1,"Host support tick did not break deck"):return
	if not check(scene.static_assemblies.is_present(211) and bridge.creature_barrier.enabled,"Break did not link debris211 or block creatures"):return
	for mesh in bridge.debris.values():
		if not check(mesh.visible,"Break omitted debris prop"):return
	if not check(body.get_rid()==collision_id and body.get_child(0).shape==shape and body.collision_layer!=0,"Break changed native whole-box collision"):return
	var crashes: Array=bridge.effect_log.filter(func(e):return e.type=="sound" and e.request==452)
	if not check(crashes.size()==1,"Expected exactly one crash cue"):return
	var error: String=scene.quicksave(path)
	if not check(error.is_empty(),"Bridge save rejected: "+error):return
	print("PASS jungle_bridge_break_live_test crossing: supplied beast form/approach, grounded production movement/support calls break once; deck selector1, all debris, creature refusal, original collision, save")
	quit()
