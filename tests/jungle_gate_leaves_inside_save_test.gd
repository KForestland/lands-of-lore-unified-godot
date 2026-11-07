extends SceneTree
## Gate-leaf source relink vs saved region history, process 1 of 2 (headless; supplied kill/alert as in
## jungle_gate_leaves_host_test, aim supplied). Codex decision on 66b274e: only an ENTRY into regions 588/3895/3896/3897
## relinks; the alarm never does; a save made while standing inside such a region must not count as an entry on load.
## - Luther stands in region588 (entry with intact leaves changes nothing), then Force gate breaks leaf78 there.
## - Staying inside for further physics ticks and the alarm closing the gate do not relink it.
## - Save while inside (inside=[588]); same-process reload keeps leaf78 broken after ticks.
## The kept save user://tests/gate_leaves_inside.json is reloaded by jungle_gate_leaves_inside_reload_test in a new process.
const Confidante=preload("res://scripts/lol2/jungle_confidante_state.gd")
const PATH:="user://tests/gate_leaves_inside.json"
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func centre(g, region: String) -> Vector2:
	var c:=Vector2.ZERO
	for p in g.src.relink[region].polygon: c+=Vector2(p[0],p[1])
	return c/float(g.src.relink[region].polygon.size())
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	var g=scene.gate_leaves
	var at:=centre(g,"588")
	scene.player.global_position=Vector3(at.x,preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET+2,at.y);scene.player.velocity=Vector3.ZERO
	for i in 10: await physics_frame
	if not check(g.inside==[588],"Not standing in region588: %s at %s"%[g.inside,scene.player.global_position]): return
	scene.raise_huline_alert()
	var cs: Dictionary=scene.confidante.state.duplicate(true);var csrc: Dictionary=scene.confidante.src
	var cctx:={"locals":{"6":0,"33":0},"shared":{"0":5,"25":0,"29":1,"47":1}}
	Confidante.sight(cs,csrc,1465,cctx);Confidante.hit(cs,csrc,123,cctx,8)
	if not check(scene.confidante.restore({"version":1,"state":cs,"inside":[]}).is_empty(),"Supplied kill rejected"): return
	if not check(g.force(78) and scene.village_gate.leaf_removed(78),"Force gate failed"): return
	scene.village_alarm.request_movable(78,0);scene.village_alarm.request_movable(79,0)
	for i in 60:
		scene.village_gate.advance(1.0/30.0);await physics_frame
	if not check(scene.village_gate.leaf_removed(78) and g.inside==[588],"Standing inside or the alarm relinked leaf78"): return
	if not check(scene.quicksave(PATH).is_empty(),"Save inside region588"): return
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not check(disk.quests.jungle_gate_leaves.inside==[588.0] or disk.quests.jungle_gate_leaves.inside==[588],"Saved inside history: %s"%[disk.quests.jungle_gate_leaves.inside]): return
	if not check(scene.quickload(PATH).is_empty(),"Reload"): return
	for i in 30: await physics_frame
	if not check(scene.village_gate.leaf_removed(78),"Same-process reload inside region588 relinked leaf78"): return
	print("PASS jungle_gate_leaves_inside_save_test: broken inside region588, no relink while inside or by the alarm, inside=[588] saved, reload keeps it broken; kept ",PATH)
	quit()
