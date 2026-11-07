extends SceneTree
## Gate-leaf source relink vs saved region history, process 2 of 2 (headless, NEW process after
## jungle_gate_leaves_inside_save_test, same user dir). Loads the kept save made while standing inside region588:
## - loading and further physics ticks inside the region do not count as an entry: leaf78 stays broken;
## - stepping out of the region and walking back in (grounded mover) is an entry: the source group relinks both leaves
##   and unlinks the fallen leaf.
const PATH:="user://tests/gate_leaves_inside.json"
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func walk(to: Vector2, frames: int) -> void:
	for i in frames:
		var off:=to-Vector2(scene.player.global_position.x,scene.player.global_position.z)
		if off.length()<4: return
		scene.move_grounded(Vector3(off.x,0,off.y).normalized(),1.0/60.0)
		await physics_frame
func run() -> void:
	if not check(FileAccess.file_exists(PATH),"No kept save (run jungle_gate_leaves_inside_save_test first)"): return
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.quickload(PATH).is_empty(),"Kept save rejected"): return
	scene.set_physics_process(false)
	var g=scene.gate_leaves
	for i in 60: await physics_frame
	if not check(g.inside==[588] and scene.village_gate.leaf_removed(78) and g.panels["81"].visible,"Restart inside region588 relinked leaf78 (inside %s)"%[g.inside]): return
	var poly: Array=g.src.relink["588"].polygon
	var c:=Vector2.ZERO
	for p in poly: c+=Vector2(p[0],p[1])
	c/=float(poly.size())
	# Leave westward until the region history is empty, then come back.
	var west:=Vector2(c.x-200,c.y)
	await walk(west,900)
	for i in 5: await physics_frame
	if not check(g.inside.is_empty(),"Did not leave region588: %s at %s"%[g.inside,scene.player.global_position]): return
	if not check(scene.village_gate.leaf_removed(78),"Leaving relinked leaf78"): return
	await walk(c,900)
	for i in 5: await physics_frame
	if not check(g.inside==[588] and not scene.village_gate.leaf_removed(78) and not g.panels["81"].visible,"Re-entry did not relink (inside %s)"%[g.inside]): return
	DirAccess.remove_absolute(PATH)
	print("PASS jungle_gate_leaves_inside_reload_test: new process loaded the inside-region588 save without relinking; leaving and re-entering relinked both leaves")
	quit()
