extends SceneTree
## Kelsrick's inner gate (movables 74/75) on the real Jungle host. Supplied approach and producers; not an earned route.
## - Shut at rest: the walk 3567 → 2750 → 2752 is blocked.
## - Kelsrick's real talk1-end group g30684, through his own effects path, plays control98 selector1: both leaves
##   open and the same walk reaches region2752.
## - Kelsrick's real g5084 (region2750) shuts them behind Luther. Re-entering region2752 opens them.
## - The alarm route (movable 74/75 → 0) shuts them. After Kelsrick's death, E-use on a leaf opens it.
## - Disk save/load mid-swing is exact. A legacy save (no gate packet, talk1-end receipt) resumes open. Malformed packets
##   are rejected atomically.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const State=preload("res://scripts/lol2/jungle_inner_gate_state.gd")
const KState=preload("res://scripts/lol2/jungle_kelsrick_state.gd")
const PATH:=[Vector2(-1804,-5508),Vector2(-1816,-5552),Vector2(-1826,-5563),Vector2(-1846,-5599),Vector2(-1875,-5656)]
var scene
var g
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

func open_jungle() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for name in ["exit_encounter","bacatta","exit_woman","kelsrick","dawn","actor62","bacatta65","bacatta57","village_alarm","inner_gate","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	g=scene.inner_gate
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_jungle() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3: await process_frame

func place(at: Vector2) -> void:
	var top: Vector3=Vector3(at.x,200,at.y)+g.origin()
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else 0.0
	scene.player.global_position=Vector3(at.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)+Vector3(g.origin().x,0,g.origin().z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame

func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		g.advance(1.0/30.0)
		if i%10==0: await process_frame

func in_2752() -> bool:
	var p: Vector3=scene.player.global_position-g.origin()
	var poly:=PackedVector2Array()
	for v in g.src.regions[0].polygon: poly.append(Vector2(v[0],v[1]))
	return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),poly)

## Walk the waypoints with the host's collision; true when Luther reaches region2752.
func walk_south() -> bool:
	await place(PATH[0])
	for w in range(1,PATH.size()):
		for i in 90:
			var p: Vector3=scene.player.global_position-g.origin()
			var to: Vector2=PATH[w]-Vector2(p.x,p.z)
			if to.length()<6: break
			scene.player.velocity=Vector3(to.normalized().x,0,to.normalized().y)*120.0
			scene.player.move_and_slide();await physics_frame
			g.advance(1.0/60.0)
		if in_2752(): return true
	return in_2752()

func kelsrick_group(group: int) -> void:
	var k=scene.kelsrick
	var row: Dictionary=k.src.groups.filter(func(x): return int(x.group)==group)[0]
	k._apply(KState.run(k.state,k.src,[row],k.context()))

func run() -> void:
	var path:="user://tests/jungle_inner_gate_live.json"
	await open_jungle()
	if not check(g!=null and g.pose=={"74":0,"75":0} and g.leaves.size()==2,"Inner gate not installed shut"): return
	# Shut at rest blocks the walk.
	if not check(not await walk_south(),"Walked through the shut inner gate"): return
	await place(PATH[0])
	scene.player.look_at(Vector3(PATH[2].x,scene.player.global_position.y,PATH[2].y));scene.camera.rotation=Vector3.ZERO
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/inner_gate_shut.png")
	# Kelsrick's talk1 end (g30684) through his effects path opens both leaves.
	kelsrick_group(30684)
	if not check(State.open(g.state,"74") and State.open(g.state,"75") and "051062000100" in scene.kelsrick.receipts,"Talk1 end did not open the gate"): return
	await step(0.6)
	if not check(g.pose["74"]>0 and g.pose["74"]<100,"Not mid-swing: %s"%[g.pose]): return
	var saved: Dictionary=g.checkpoint()
	if not check(scene.quicksave(path).is_empty(),"Mid-swing save failed"): return
	await step(1.0)
	if not check(scene.quickload(path).is_empty() and g.checkpoint().state==State.canonical(saved.state),"Mid-swing reload not exact"): return
	await step(1.0)
	if not check(g.pose=={"74":100,"75":100},"Gate not open: %s"%[g.pose]): return
	if not check(await walk_south(),"Open gate still blocks the walk"): return
	# Kelsrick g5084 shuts it behind Luther (south); re-entering 2752 opens it.
	kelsrick_group(5084)
	if not check(not State.open(g.state,"74") and not State.open(g.state,"75"),"g5084 did not shut the gate"): return
	await step(1.5)
	if not check(g.pose=={"74":0,"75":0},"Gate did not swing shut: %s"%[g.pose]): return
	await place(Vector2(-1783,-5639));await step(0.1)
	await place(PATH[4]);await step(0.1)
	if not check(State.open(g.state,"74") and State.open(g.state,"75"),"Region2752 did not open the gate"): return
	# The alarm route shuts it.
	scene.village_alarm._apply([{"type":"movable","movable":75,"target":0},{"type":"movable","movable":74,"target":0}])
	if not check(not State.open(g.state,"74") and not State.open(g.state,"75"),"Alarm did not shut the gate"): return
	await step(1.5)
	# Use: only after Kelsrick's death; leaf75 opens both.
	await place(PATH[0])
	var aim: Vector3=Vector3(-1860,40,-5545)+g.origin()
	scene.player.look_at(Vector3(aim.x,scene.player.global_position.y,aim.z));scene.camera.look_at(aim)
	await physics_frame
	if not check(g.aimed_leaf()==75,"Not aiming at leaf75: %d"%g.aimed_leaf()): return
	if not check(not g.use() and not State.open(g.state,"75"),"Use opened with Kelsrick alive"): return
	scene.quest_state.monastery.globals.GV_KELSRICK_DEAD=1
	if not check(g.use() and State.open(g.state,"74") and State.open(g.state,"75"),"Use after Kelsrick's death differs"): return
	# Legacy save: no gate packet, Kelsrick's talk1-end receipt → resumes open.
	scene.quest_state.erase("jungle_inner_gate")
	if not check(g.restore(scene._inner_gate_packet()).is_empty() and g.pose=={"74":100,"75":100},"Legacy migration differs"): return
	# Atomic rejection.
	var good: Dictionary=g.checkpoint()
	var bad: Dictionary=good.duplicate(true);bad.state.leaves["74"].target=50
	if not check(not g.restore(bad).is_empty() and g.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"jungle_inner_gate":bad}).is_empty(),"Malformed packet partially applied"): return
	await close_jungle()
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS jungle inner gate live: shut at rest blocks 3567->2752; Kelsrick g30684 (control98 sel1) opens, mid-swing disk save/load exact, walk passes; g5084 shuts behind, region2752 reopens; alarm shuts; use only after Kelsrick death; legacy receipt migration; atomic malformed packet. Supplied producers; not earned.")
	quit()
