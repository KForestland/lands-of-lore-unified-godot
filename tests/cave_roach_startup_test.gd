extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Cave initialization failed"):return
	scene.set_physics_process(false)
	var roach=scene.roach
	if not check(not roach.startup_active and roach.animation.action_key==-1 and roach.animation.view_slot==0,"Fresh actor must use original front idle"):return
	# Preserve previously saved action9 adapters without replaying them on new actors.
	roach.startup_active=true;roach.startup_elapsed=0.0;roach._sync(0.0,false)
	if not check(roach.startup_active and roach.animation.action_key==9 and roach.animation.frame_count==8,"Original initial clip absent"):return
	roach._sync(0.375,false)
	if not check(roach.animation.frame_index==3,"Initial clip frame differs"):return
	var path:="user://tests/cave_roach_startup.json"
	if not check(scene._quicksave(path).is_empty(),"Startup save failed"):return
	var saved: Dictionary=roach.snapshot()
	roach._sync(1.0,false)
	if not check(not roach.startup_active and roach.animation.action_key==-1,"Startup did not finish into idle"):return
	if not check(scene._quickload(path).is_empty(),"Startup load failed"):return
	scene.set_physics_process(false)
	if not check(roach.snapshot()==saved and roach.animation.frame_index==3,"Partial startup disk rollback failed"):return
	var bad:=saved.duplicate(true);bad.erase("startup_elapsed")
	if not check(not roach.validate(bad),"Partial startup packet accepted"):return
	bad=saved.duplicate(true);bad.startup_elapsed=1.0
	if not check(not roach.validate(bad),"Terminal active startup accepted"):return
	var legacy:=saved.duplicate(true);legacy.erase("startup_active");legacy.erase("startup_elapsed")
	roach.restore(legacy)
	if not check(not roach.startup_active and roach.animation.action_key==-1,"Legacy save replayed startup"):return
	roach.restore(saved)
	roach.model.phase=roach.Model.Phase.PURSUING
	roach._sync(0.0,true)
	if not check(not roach.startup_active and roach.animation.action_key==-1,"Existing pursuit did not interrupt presentation"):return
	roach.restore(saved)
	roach.model.enemy_health=0;roach.model.phase=roach.Model.Phase.DEFEATED
	roach._sync(0.0,false)
	if not check(not roach.startup_active and roach.animation.action_key==14 and roach.validate(roach.snapshot()),"Death did not cancel startup"):return
	print("PASS: original8-frame Roach startup, shared canvas, partial disk rollback, legacy migration, malformed rejection, pursuit and death interruption")
	scene.queue_free();await process_frame;quit()
