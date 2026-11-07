extends SceneTree
## Huline village alarm on the real Jungle host. Supplied approach and alert; not an earned route.
## - No alert: crossing the gate passage (region3805) changes nothing.
## - Alert after a Kelsrick strike (supplied: shared29=1, local52=1, gate open): crossing the passage, then 5 s later:
##   - Kelsrick hostile and soul 5→3 through the Kelsrick owner;
##   - local32 latch;
##   - the village gate leaves swing shut;
##   - the Bacatta57 double door shuts;
##   - the bells ring;
##   - the gate archers shoot arrows that damage Luther.
## - Disk save/load is exact; a fresh host resumes the closed gate, the doors and the archers; the alarm never repeats.
## - Pause freezes the alarm. Malformed packets are rejected atomically.
## - A second session: Bacatta57's sealing village re-entry (relationship 0) arms the same alarm.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const State=preload("res://scripts/lol2/jungle_village_alarm_state.gd")
const VillageState=preload("res://scripts/lol2/jungle_village_state.gd")
const GlobalDefaults=preload("res://scripts/lol2/shared_global_defaults.gd")
var scene
var a
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

func globals() -> Dictionary:
	if not scene.quest_state.has("monastery"): scene.quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	return scene.quest_state.monastery.globals
func soul() -> int: return GlobalDefaults.read(globals(),"GV_LUTHERS_SOUL")

func open_jungle() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for name in ["exit_encounter","bacatta","exit_woman","kelsrick","dawn","actor62","bacatta65","bacatta57","village_alarm","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	a=scene.village_alarm
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_jungle() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3: await process_frame

## The village gate already open (its normal admission happened before the strike).
func open_gate() -> void:
	scene.village_gate.state().local24=1;scene.village_gate.state().elapsed=VillageState.DURATION;scene.village_gate.restore()

func place(at: Vector2) -> void:
	var o: Vector3=a.origin()
	var top:=Vector3(at.x,200,at.y)+o
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else o.y
	scene.player.global_position=Vector3(at.x+o.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y+o.z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame

func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		a.advance(1.0/30.0);scene.village_gate.advance(1.0/30.0)
		if is_instance_valid(scene.bacatta57): scene.bacatta57.advance(1.0/30.0)
		if i%10==0: await process_frame

const PASSAGE:=Vector2(-1412,-5249)
const OUTSIDE:=Vector2(-1300,-5240)

func run() -> void:
	var path:="user://tests/jungle_village_alarm_live.json"
	await open_jungle()
	if not check(a!=null and is_instance_valid(scene.kelsrick) and is_instance_valid(scene.village_gate),"Village alarm not installed on the Jungle host"): return
	if not await wall_probe(): return
	# No alert: crossing the passage arms timer1 but nothing follows.
	open_gate()
	await place(OUTSIDE);await step(0.1)
	await place(PASSAGE);await step(0.1)
	await place(OUTSIDE);await step(7.0)
	if not check(a.movable_target(78)==-1 and scene.village_gate.pose==100 and soul()==5 and a.fired_arrows==0,"Alarm ran without the alert"): return
	await close_jungle()
	# Alert after the Kelsrick strike (supplied), gate open.
	await open_jungle()
	open_gate()
	scene.village_gate.state().shared29=1;scene.kelsrick.state.locals["52"]=1
	scene.starting_magic.set_health(30)
	await place(OUTSIDE);await step(0.1)
	await place(PASSAGE);await step(0.1)
	if not check(a.running(216) and (int(a.state.timers["216"][1].flags)&1)==0,"Passage did not arm control216 timer1"): return
	await place(OUTSIDE)
	if not check(await step_until(func(): return a.movable_target(78)==0,8.0),"Alarm did not run: %s"%[a.state]): return
	if not check(scene.kelsrick.fighting() and soul()==3 and scene.kelsrick.local_value(32)==1 and int(scene.kelsrick.local_value(8))==30,"Kelsrick/soul/latch differ: soul %d"%soul()): return
	if not check(int(a.state.locals["7"])==2 and a.state.movables=={"56":100,"57":100,"74":0,"75":0,"78":0,"79":0},"Alarm targets %s"%[a.state.movables]): return
	if not check(int(scene.bacatta57.state.doors.target)==100 and not scene.bacatta57.sealed() and not scene.bacatta57.state.actor.present,"Bacatta57 doors not shut by the alarm"): return
	await step(2.0)
	if not check(scene.village_gate.pose==0 and scene.bacatta57.pose==100,"Gate %d / doors %d not shut"%[scene.village_gate.pose,scene.bacatta57.pose]): return
	# Archers and bells; arrows reach Luther outside the shut gate.
	if not check(await step_until(func(): return a.arrow_hits>0,15.0) and scene.starting_magic.health()<30,"No arrow struck Luther (fired %d)"%a.fired_arrows): return
	# Control216 timer0 (started by g27172) rings the bells after its 300-tick countdown.
	if not check(await step_until(func(): return a.bells.playing and a.effect_log.any(func(e): return e.type=="sound" and int(e.request)==403),8.0),"Bells not rung"): return
	await capture()
	# Save/load exact; the alarm never repeats.
	var saved: Dictionary=a.checkpoint()
	if not check(scene.quicksave(path).is_empty(),"Alarm save failed"): return
	await step(2.0)
	if not check(scene.quickload(path).is_empty() and a.checkpoint().state==State.canonical(saved.state) and soul()==3 and scene.kelsrick.fighting(),"Reload not exact / lost soul or hostility"): return
	await step(6.0)
	if not check(soul()==3 and a.effect_log.filter(func(e): return e.type=="group" and int(e.group)==27172).size()<=1,"Alarm repeated"): return
	# Pause freezes the alarm and the arrows.
	var frozen: Dictionary=a.checkpoint();var health: int=scene.starting_magic.health()
	paused=true;a.advance(2.0);paused=false
	if not check(a.checkpoint()==frozen and scene.starting_magic.health()==health,"Paused alarm advanced"): return
	if not check(scene.quicksave(path).is_empty(),"Second save failed"): return
	await close_jungle()
	# Fresh host: the shut gate/doors and the archers resume.
	await open_jungle()
	scene.starting_magic.set_health(30)
	if not check(scene.quickload(path).is_empty() and a.movable_target(78)==0 and a.running(77) and a.running(217),"Fresh-host resume differs"): return
	await place(OUTSIDE);await step(0.5)
	if not check(scene.village_gate.pose==0 and scene.bacatta57.pose==100 and scene.kelsrick.fighting() and soul()==3,"Resumed gate/doors/Kelsrick differ"): return
	if not check(await step_until(func(): return a.fired_arrows>0,10.0),"Resumed archers silent"): return
	# Atomic rejection.
	var good: Dictionary=a.checkpoint()
	var bad: Dictionary=good.duplicate(true);bad.state.movables["78"]=42
	if not check(not a.restore(bad).is_empty() and a.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"jungle_village_alarm":bad}).is_empty(),"Malformed packet partially applied"): return
	await close_jungle()
	# Session 2: Bacatta57's sealing re-entry (relationship 0, alert) arms the same alarm.
	await open_jungle()
	globals().GV_BACATTA_RELATIONSHIP=0;globals().GV_MET_BACATTA=1
	scene.monastery.state().flags["41"]=1;scene.monastery.state().flags["34"]=1;scene.monastery.state().locals.Left_Village=2
	scene.village_gate.state().shared29=1;scene.kelsrick.state.locals["52"]=1
	var b57=scene.bacatta57
	var threshold: Dictionary=b57.src.regions.filter(func(r): return int(r.region)==3501)[0]
	var c:=Vector2.ZERO
	for v in threshold.polygon: c+=Vector2(v[0],v[1])
	await place(c/threshold.polygon.size());b57.advance(1.0/30.0)
	if not check(b57.sealed() and (int(a.state.timers["216"][1].flags)&1)==0,"Bacatta57 g10162 did not arm the alarm"): return
	# The VILLAGE room still opens on that entry; the world (and the alarm clock) waits until Luther leaves it.
	for i in 3: await process_frame
	if scene.monastery.active(): scene.monastery.leave_room()
	if not check(await step_until(func(): return a.movable_target(78)==0,8.0) and soul()==3,"Bacatta57-armed alarm did not run"): return
	await close_jungle()
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS jungle village alarm live: no alert inert; alert -> passage arms 216/1 -> g27172 (Kelsrick hostile, soul 5->3, latch, gate 78/79 shut, Bacatta57 doors shut, bells, archers hit Luther); disk save/load exact, no repeat, pause frozen, fresh-host resume; atomic malformed packet; Bacatta57 g10162 arms the same alarm. Supplied alert/approach; not earned.")
	quit()

func step_until(predicate: Callable, limit: float) -> bool:
	for i in int(limit*30.0):
		a.advance(1.0/30.0);scene.village_gate.advance(1.0/30.0)
		if is_instance_valid(scene.bacatta57): scene.bacatta57.advance(1.0/30.0)
		if i%10==0: await process_frame
		if predicate.call(): return true
	return false

func capture() -> void:
	var tower: Vector3=a.launch_point(216)
	scene.player.look_at(Vector3(tower.x,scene.player.global_position.y,tower.z));scene.camera.rotation=Vector3(0.15,0,0)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/village_alarm.png")

func wall_probe() -> bool:
	scene.player.set_physics_process(false)
	var old: Vector3=scene.player.global_position
	scene.player.global_position=Vector3(0,5000,0)
	var chest: Vector3=a._aim()
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,200,200);collision.shape=shape
	wall.add_child(collision);scene.add_child(wall);wall.global_position=chest-Vector3(50,0,0)
	await physics_frame
	await physics_frame
	scene.starting_magic.set_health(30)
	var node:=MeshInstance3D.new();node.mesh=a.arrow_mesh;a.add_child(node);node.global_position=chest-Vector3(100,0,0)
	a.arrows.append({"node":node,"velocity":Vector3(900,0,0),"life":3.0,"control":216})
	a._fly(0.2)
	if not check(scene.starting_magic.health()==30 and a.arrows.is_empty(),"Arrow damaged player through intervening wall on a long step"): return false
	# A wall beyond the player must not suppress a legitimate hit.
	wall.global_position=chest+Vector3(50,0,0)
	await physics_frame
	await physics_frame
	var clear_node:=MeshInstance3D.new();clear_node.mesh=a.arrow_mesh;a.add_child(clear_node);clear_node.global_position=chest-Vector3(100,0,0)
	a.arrows.append({"node":clear_node,"velocity":Vector3(900,0,0),"life":3.0,"control":216})
	a._fly(0.2)
	if not check(scene.starting_magic.health()==27 and a.arrows.is_empty(),"Wall behind player incorrectly suppressed arrow hit"): return false
	scene.starting_magic.set_health(30)
	a.arrow_hits=0
	wall.queue_free();await physics_frame
	scene.player.global_position=old;scene.player.set_physics_process(true)
	return true
