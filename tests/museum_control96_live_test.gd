extends SceneTree
const Save=preload("res://scripts/lol2/museum_save.gd")
const State=preload("res://scripts/lol2/museum_control96_state.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete";root.add_child(museum);current_scene=museum
	for i in range(5): await process_frame
	museum.set_physics_process(false);museum.skeleton_population.set_physics_process(false)
	var control=museum.control96
	if not check(is_instance_valid(control),"Missing control96 live integration"): return
	control.set_physics_process(false)
	museum.set_development_mode(false)
	museum.interface_hud.set_cursor(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var point:=Vector3(426,39,-1337.5)
	var placed:=false
	for x in [480,380,500,350]:
		museum.player.global_position=Vector3(x,32,-1337.5);museum.camera.look_at(point)
		await physics_frame
		if control.eligible(): placed=true;break
	if not check(placed,"No actual camera admission at source geometry"):return
	museum.camera.rotation.y+=PI
	if not check(not control.eligible(),"Behind-camera control admitted"):return
	museum.camera.look_at(point)
	var blocker:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,200,200);shape.shape=box;blocker.add_child(shape)
	blocker.position=(museum.camera.global_position+point)*0.5;museum.add_child(blocker)
	await physics_frame
	if not check(not control.eligible(),"Occluded control admitted"):return
	blocker.queue_free();await physics_frame;await physics_frame
	museum.interface_hud.set_cursor(true)
	control._physics_process(0.4)
	if not check(not control.state.latched,"Cursor overlay admitted first visibility"):return
	museum.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	control._physics_process(0.4)
	if not check(control.state.latched and control.state.stage==0 and not museum.skeleton_population.state.actors["30"].present,"Visibility did not enter first clip"):return
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/museum_control96_live.png")
	var path:="user://tests/museum_control96.json"
	var save_error: String=museum.quicksave(path)
	if not check(save_error.is_empty(),"Midclip save failed: "+save_error+str(Save.read_save(path+".tmp"))):return
	var mid: Dictionary=control.checkpoint()
	museum.health=0;control._physics_process(1.0)
	if not check(control.checkpoint()==mid,"Death advanced animation"):return
	museum.health=30
	museum.interface_hud.set_cursor(true);control._physics_process(1.0)
	if not check(control.checkpoint()==mid,"Cursor overlay advanced animation"):return
	museum.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	control._physics_process(1.4)
	if not check(control.state.stage==1 and control.state.control179,"First endpoint missed control179"):return
	if not check(museum.quickload(path).is_empty() and control.checkpoint()==mid,"Midclip reload differs"):return
	control._physics_process(10)
	if not check(control.state.stage==2 and museum.skeleton_population.state.actors["30"].present and museum.skeleton_population.bodies["30"].visible,"Final endpoint missing live skeleton30"):return
	if not check(museum.quicksave(path).is_empty(),"Final save failed"):return
	var saved: Dictionary=Save.read_save(path).state
	var bad: Dictionary=saved.duplicate(true);bad.checkpoint.museum_control96.stage=0
	var before: Dictionary=control.checkpoint()
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if not check(not museum.quickload(path).is_empty() and control.checkpoint()==before,"Malformed load mutated live control"):return
	var legacy: Dictionary=saved.duplicate(true);legacy.checkpoint.erase("museum_control96");legacy.checkpoint.skeletons.actors["30"].present=false
	if not check(Save.validate(legacy).is_empty(),"Legacy save rejected"):return
	museum.apply_save(legacy)
	if not check(control.checkpoint()==State.initial() and not museum.skeleton_population.state.actors["30"].present,"Legacy restore did not reset control"):return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS museum_control96_live_test: actual frustum/occlusion, source68frame endpoints, actor30, disk, atomic, legacy")
	museum.queue_free();await process_frame;quit()
