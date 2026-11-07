extends SceneTree
## Village-entry Bacatta (actor57) on the real Jungle host. Supplied approach and globals; not an earned route.
## - Native start (relationship absent = 1): entering region3501 opens the VILLAGE room as before and leaves Bacatta57
##   untouched. Both encounter hooks read absent globals with their native values.
## - After the CAN farewell (relationship 0, met 1): re-entry seals the threshold. The VILLAGE room still opens; on
##   leaving it, Luther stands at g7026's return point outside. The double door (movables 56/57) swings shut and a
##   non-hostile Bacatta57 stands outside.
## - The seal and doors block re-entry and the room does not reopen. Disk save/load mid-swing is exact; a fresh host
##   resumes it.
## - A strike makes her hostile (generic owner), persisting over save/load. Region3157 removes her. Malformed packets
##   are rejected atomically.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const State=preload("res://scripts/lol2/jungle_bacatta57_state.gd")
var scene
var b
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

func globals() -> Dictionary:
	if not scene.quest_state.has("monastery"): scene.quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	return scene.quest_state.monastery.globals

func open_jungle() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for name in ["exit_encounter","bacatta","exit_woman","kelsrick","dawn","actor62","bacatta65","villager_population","dino_population","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups"]:
		var node=scene.get(name)
		if node!=null and is_instance_valid(node): node.set_physics_process(false);node.set_process(false)
	b=scene.bacatta57
	if b!=null: b.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func close_jungle() -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	for i in 3: await process_frame

func centroid(region: int) -> Vector2:
	var row: Dictionary=b.src.regions.filter(func(r): return int(r.region)==region)[0]
	var c:=Vector2.ZERO
	for v in row.polygon: c+=Vector2(v[0],v[1])
	return c/row.polygon.size()

func place(at: Vector2) -> void:
	var o: Vector3=b.origin()
	var top:=Vector3(at.x,200,at.y)+o
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else o.y
	scene.player.global_position=Vector3(at.x+o.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y+o.z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame

## Real interleaving: one physics step, then process frames (the VILLAGE room enters from _process).
func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		b.advance(1.0/30.0)
		await process_frame

func room() -> String: return str(scene.monastery.state().get("room","")) if is_instance_valid(scene.monastery) else ""

## Walk the player toward the threshold centroid with the host's collision; true when he gets inside.
func walk_in(frames: int=90) -> bool:
	var goal: Vector2=centroid(3501)
	for i in frames:
		var p: Vector3=scene.player.global_position-b.origin()
		var dir:=(goal-Vector2(p.x,p.z)).normalized()
		scene.player.velocity=Vector3(dir.x,0,dir.y)*120.0
		scene.player.move_and_slide()
		await physics_frame
		b.advance(1.0/60.0)
		if b._inside_threshold(): return true
	return false

func run() -> void:
	var path:="user://tests/jungle_bacatta57_live.json"
	await open_jungle()
	if not check(b!=null and not b.sealed() and not b.state.actor.present,"Bacatta57 not installed on the Jungle host"): return
	if not check(is_instance_valid(scene.monastery) and scene.monastery.view.manifest.rooms.has("VILLAGE"),"VILLAGE room media missing"): return
	# Native globals: absent relationship/soul read 1/5 by both encounter hooks.
	globals().erase("GV_BACATTA_RELATIONSHIP");globals().erase("GV_LUTHERS_SOUL")
	if not check(scene._bacatta57_context().shared["13"]==1 and scene._bacatta65_context().shared["13"]==1 and scene._bacatta65_context().shared["0"]==5,"Absent globals are not read with native values"): return
	# First visit (native relationship 1): the room opens, Bacatta57 stays absent, the doors stay open.
	await place(centroid(3503));await step(0.1)
	# Control for the seal check below: the same walk enters the open threshold.
	if not check(await walk_in(),"Walk from 3503 could not enter the open threshold"): return
	await step(0.3)
	if not check(room()=="VILLAGE" and not b.sealed() and not b.state.actor.present and b.pose==0,"First visit differs: room=%s %s"%[room(),b.state]): return
	await step(0.5)
	if not check(b._inside_threshold() and b.barrier.collision_layer==0 and not b.sealed(),"Unsealed visit moved the player or sealed"): return
	await close_jungle()
	# After the CAN farewell (supplied: introduction seen flag41, farewell flag34, Left_Village 2, relationship 0, met 1):
	# re-entry seals the village.
	await open_jungle()
	globals().GV_BACATTA_RELATIONSHIP=0;globals().GV_MET_BACATTA=1
	scene.monastery.state().flags["41"]=1;scene.monastery.state().flags["34"]=1;scene.monastery.state().locals.Left_Village=2
	await place(centroid(3503));await step(0.1)
	await place(centroid(3501));await step(0.3)
	if not check(b.sealed() and int(b.state.doors.target)==100 and b.state.actor.present and not b.hostile(),"Re-entry did not run g10162: %s"%[b.state]): return
	if not check(b.effect_log.any(func(e): return e.type=="external" and e.raw=="0e10d80003000100"),"Alarm timer not reported"): return
	if not check(room()=="VILLAGE" and b._inside_threshold(),"The VILLAGE room must still open on the sealing entry"): return
	await step(0.5)
	if not check(b._inside_threshold() and b.pose==0,"Moved or swung while the room is up"): return
	scene.monastery.leave_room();await step(0.1)
	# Source return point; it lies 24 units from Bacatta57, so the player capsule may be separated from her body.
	var rp: Array=b.src.return_point
	var at: Vector3=scene.player.global_position-b.origin()
	if not check(not b._inside_threshold() and Vector2(at.x,at.z).distance_to(Vector2(rp[0],rp[2]))<16.0 and b.barrier.collision_layer==1,"Return point differs: %s"%[at]): return
	# Mid-swing disk save/load is exact.
	await step(0.5)
	if not check(b.pose>0 and b.pose<100,"Doors not mid-swing: %d"%b.pose): return
	var saved: Dictionary=b.checkpoint()
	var frozen: Dictionary=saved.duplicate(true)
	var frozen_pose: int=b.pose
	paused=true;b.advance(2.0);paused=false
	if not check(b.checkpoint()==frozen and b.pose==frozen_pose,"Paused door swing advanced"): return
	if not check(scene.quicksave(path).is_empty(),"Mid-swing save failed"): return
	await step(1.0)
	if not check(scene.quickload(path).is_empty() and b.checkpoint().branch==State.canonical(saved.branch) and b.pose==State.door_percent(b.state),"Mid-swing reload not exact"): return
	await step(1.6)
	if not check(b.pose==100 and b.population.state.actors["57"].present and b.targets().size()>0,"Doors not shut / Bacatta57 not present"): return
	# Seal: the shut doors and threshold block re-entry; the room does not reopen.
	if not check(not await walk_in() and room()=="" and not b._inside_threshold(),"Sealed threshold re-entered"): return
	# Outside the doorway: 110 units along the west edge's outward normal, looking at the edge midpoint.
	var door_view:=Vector2(-1676,-3913)
	await place(door_view+Vector2(-0.92,-0.39)*110.0)
	scene.player.look_at(Vector3(door_view.x,scene.player.global_position.y,door_view.y)+Vector3(b.origin().x,0,b.origin().z));scene.camera.rotation=Vector3.ZERO
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/bacatta57_doors.png")
	var body57: Vector3=b.population.bodies["57"].global_position
	scene.player.global_position=body57+Vector3(-150,50,90);scene.camera.look_at(body57+Vector3.UP*35)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/bacatta57_outside.png")
	if not check(scene.quicksave(path).is_empty(),"Sealed save failed"): return
	await close_jungle()
	# Return: a fresh host resumes the sealed village, the shut doors and the peaceful Bacatta57.
	await open_jungle()
	if not check(scene.quickload(path).is_empty() and b.sealed() and b.pose==100 and b.state.actor.present and not b.hostile() and b.population.state.actors["57"].present,"Fresh-host resume differs"): return
	await place(centroid(3503));await step(0.1)
	if not check(not await walk_in() and room()=="","Fresh host let Luther back in"): return
	# Strike: hostile through the generic owner, persisting over save/load.
	if not check(b.population.receive_damage("57",5,true),"Body rejected a strike"): return
	await step(0.2)
	if not check(b.hostile() and b.population.state.actors["57"].woken and b.targets().size()>0,"Strike did not make Bacatta57 hostile"): return
	await step(1.0)
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and b.hostile() and b.population.state.actors["57"].present,"Hostile save/load differs"): return
	# Independent hostile-body health, pause and corpse checks (supplied position).
	scene.health=30
	scene.player.global_position=b.population.bodies["57"].global_position+Vector3(36,32,0)
	await physics_frame
	for tick in range(120):
		await step(0.1)
		if scene.health<30: break
	if not check(scene.health<30,"Hostile Bacatta57 never damaged nearby player"): return
	var hit_health: int=scene.health
	var paused_packet: Dictionary=b.checkpoint().duplicate(true)
	paused=true;b.advance(2.0);paused=false
	if not check(b.checkpoint()==paused_packet and scene.health==hit_health,"Paused body advanced or dealt damage"): return
	if not check(b.population.receive_damage("57",1000,true),"Body rejected lethal damage"): return
	await step(0.2)
	if not check(b.population.state.actors["57"].health==0 and b.targets().is_empty(),"Corpse remained targetable"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and b.population.state.actors["57"].health==0 and b.targets().is_empty(),"Corpse resurrected on reload"): return
	# Region3157 (met) removes her; the removal persists.
	await place(centroid(3157));await step(0.1)
	if not check(not b.state.actor.present and not b.population.state.actors["57"].present and b.targets().is_empty(),"Region3157 removal differs"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and not b.state.actor.present and b.sealed(),"Post-removal save differs"): return
	# Atomic rejection of malformed packets.
	var good: Dictionary=b.checkpoint()
	var bad: Dictionary=good.duplicate(true);bad.body.actors["57"].present=true
	var bad2: Dictionary=good.duplicate(true);bad2.branch.sealed=false
	if not check(not b.restore(bad).is_empty() and not b.restore(bad2).is_empty() and b.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"jungle_bacatta57":bad}).is_empty(),"Malformed packet partially applied"): return
	await close_jungle()
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS jungle bacatta57 live: native relationship (absent=1) first visit inert with VILLAGE room; after farewell (rel0) re-entry seals 3501, room still opens, return point outside, doors 56/57 swing shut (mid-swing disk save/load exact), non-hostile Bacatta57, re-entry blocked, fresh-host resume, strike -> hostile persisting, region3157 removal persisting, atomic malformed packets. Supplied approach/globals; not earned.")
	quit()
