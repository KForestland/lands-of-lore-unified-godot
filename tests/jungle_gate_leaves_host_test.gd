extends SceneTree
## Village gate-leaf consumer on the real Jungle host (headless; supplied story state, aim supplied: Force-gate input and
## aiming are covered by the rendered jungle_gate_leaves_force_test). Owner-approved modern binding 2026-10-25.
## - Prerequisite refusal: without the alert, then without Killed_Confidante, force() only gives the contextual hint;
##   the leaf, the fallen leaf and the held item are unchanged.
## - With both (Confidante killed through its source kill group on the pure state; alert through raise_huline_alert):
##   a carried held item is put away (still carried, not consumed); leaf78 loses mesh and collision, fallen leaf81
##   shows; leaf79 stays.
## - The alarm's later closure (movables 78/79 → 0 and gate advance) does not relink leaf78.
## - Disk rollback (save before, load) relinks it; save after, restart (new scene, load) keeps it broken.
const Confidante=preload("res://scripts/lol2/jungle_confidante_state.gd")
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func boot():
	var host=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(host);current_scene=host
	for i in 1500:
		await process_frame
		if host.get("ready_for_review"): break
	host.set_physics_process(false)
	return host
func leaf_state(host) -> Array: return [host.village_gate.leaf_removed(78),host.village_gate.leaf_removed(79),host.gate_leaves.panels["81"].visible,host.gate_leaves.panels["80"].visible]
func run() -> void:
	var before:="user://tests/gate_leaves_before.json";var after:="user://tests/gate_leaves_after.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	set_meta("lol2_jungle_handoff",{"collected":["cave:captain:Short_Sword"],"equipped_item":"","equipped_armor":""})
	scene=await boot()
	var g=scene.gate_leaves
	if not check(g!=null and is_instance_valid(g) and is_instance_valid(scene.confidante) and is_instance_valid(scene.village_gate),"Gate leaves owner missing"): return
	scene.hand_item="cave:captain:Short_Sword"
	# No alert: closed gate hint, nothing changes.
	if not check(g.force(78) and leaf_state(scene)==[false,false,false,false] and scene.hand_item=="cave:captain:Short_Sword" and g.refusal_hint()=="The village gate is closed.","Refusal without alert"): return
	scene.raise_huline_alert()
	if not check(g.force(78) and leaf_state(scene)==[false,false,false,false] and scene.hand_item=="cave:captain:Short_Sword" and g.refusal_hint().begins_with("The gate is barred"),"Refusal without Killed_Confidante"): return
	# Killed_Confidante through the Confidante owner's own kill group (supplied: sight + a landed hit on the pure state).
	var cs: Dictionary=scene.confidante.state.duplicate(true);var csrc: Dictionary=scene.confidante.src
	var cctx:={"locals":{"6":0,"33":0},"shared":{"0":5,"25":0,"29":1,"47":1}}
	Confidante.sight(cs,csrc,1465,cctx);Confidante.hit(cs,csrc,123,cctx,8)
	if not check(scene.confidante.restore({"version":1,"state":cs,"inside":[]}).is_empty() and scene.confidante.killed(),"Supplied kill rejected"): return
	if not check(scene.quicksave(before).is_empty(),"Pre-force save"): return
	if not check(g.force(78),"Force gate refused with both prerequisites"): return
	if not check(leaf_state(scene)==[true,false,true,false] and scene.hand_item=="" and "cave:captain:Short_Sword" in scene.carried_collected,"Force result %s hand=%s"%[leaf_state(scene),scene.hand_item]): return
	var body=scene.village_gate.leaves.filter(func(b): return int(b.get_meta("source_movable"))==78)[0]
	if not check(body.collision_layer==0 and not body.visible,"Leaf78 keeps collision or mesh"): return
	# Alarm closure later: target 0 again and the gate swings; the broken leaf stays broken.
	scene.village_alarm.request_movable(78,0);scene.village_alarm.request_movable(79,0)
	for i in 120: scene.village_gate.advance(1.0/30.0)
	if not check(leaf_state(scene)==[true,false,true,false] and body.collision_layer==0,"Alarm closure resurrected leaf78"): return
	if not check(scene.quicksave(after).is_empty(),"Post-force save"): return
	if not check(scene.quickload(before).is_empty() and leaf_state(scene)==[false,false,false,false] and body.collision_layer==1,"Rollback did not relink leaf78"): return
	if not check(scene.quickload(after).is_empty() and leaf_state(scene)==[true,false,true,false],"Reload after force"): return
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(after))
	var bad: Dictionary=disk.duplicate(true);bad.quests.jungle_gate_leaves.state.controls["81"]=false
	if not check(not preload("res://scripts/lol2/jungle_save.gd").validate(bad).is_empty(),"Unpaired saved leaf accepted"): return
	# Restart: a fresh Jungle host loads the saved broken leaf.
	scene.queue_free();await process_frame;await process_frame
	scene=await boot()
	if not check(scene.quickload(after).is_empty() and leaf_state(scene)==[true,false,true,false],"Restart lost the broken leaf: %s"%[leaf_state(scene)]): return
	for i in 60: scene.village_gate.advance(1.0/30.0)
	if not check(leaf_state(scene)==[true,false,true,false],"Restarted alarm resurrected leaf78"): return
	DirAccess.remove_absolute(before);DirAccess.remove_absolute(after)
	print("PASS gate leaves host: refusals keep leaf and held item; Force gate stows (not consumes) the held item, removes leaf78 mesh/collision, shows fallen leaf81; alarm closure, rollback, reload and restart behave")
	quit(0)
