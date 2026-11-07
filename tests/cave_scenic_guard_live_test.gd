extends SceneTree
const Guard=preload("res://scripts/lol2/cave_scenic_guard.gd")
var running:=true
var acknowledge:=false
var receipts: Array=[]
func active() -> bool:return running
func effects(command: Dictionary) -> bool:
	if not acknowledge:return false
	receipts.append(command.archive_offset);return true
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Cave setup"):return
	var guard:=Guard.new();scene.add_child(guard);guard.set_physics_process(false)
	if not check(guard.setup(scene,effects,active).is_empty(),"Scenic guard source setup"):return
	if not check(guard.position==Vector3(-272,-270,-15254)+scene.native_translation and guard.mesh.visible,"Scenic original placement"):return
	if not check(guard.supply_event("supplied_hit") and guard.state.selector==0 and guard.state.pending[0].cursor==0,"Missing environment callback must retain source queue"):return
	acknowledge=true;guard.advance(1.0)
	if not check(guard.state.selector==3 and guard.State.frame(guard.state,guard.source)==6,"Original collapse frame"):return
	var saved:=guard.checkpoint();var texture: Texture2D=guard.library.last_texture
	var path:="user://tests/cave_scenic_guard.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(saved));file.close()
	running=false;guard.advance(10.0)
	if not check(guard.checkpoint()==saved,"Pause gate"):return
	running=true;guard.advance(20.0)
	if not check(guard.state.selector==3 and guard.State.frame(guard.state,guard.source)==75,"Endpoint must not invent completion event"):return
	guard.supply_event("prop_event0");guard.supply_event("actor_event3")
	if not check(guard.state.selector==4 and guard.state.movables["21"] and guard.state.movables["22"],"Supplied source completion consumers"):return
	var count:=receipts.size()
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var restored: String=guard.restore(packet)
	if not check(restored.is_empty() and guard.checkpoint()==saved and guard.library.last_texture==texture and receipts.size()==count,"Disk partial frame rollback must not reissue effects: %s state%s texture%s receipts%s" % [restored,str(guard.checkpoint()==saved),str(guard.library.last_texture==texture),str(receipts.size()==count)]):return
	var bad:=packet.duplicate(true);bad.selector=6
	if not check(not guard.restore(bad).is_empty() and guard.checkpoint()==saved,"Invalid restore atomicity"):return
	guard.restore(guard.State.initial());guard.supply_event("region969")
	if not check(not guard.mesh.visible,"Alternate branch removes scenic actor"):return
	print("PASS scenic source controller original107frames/placement; supplied environmental acknowledgements, pause, held endpoint, corpse, saved cursor/frame rollback, invalid restore, alternate removal")
	scene.queue_free();await process_frame;await process_frame;quit()
