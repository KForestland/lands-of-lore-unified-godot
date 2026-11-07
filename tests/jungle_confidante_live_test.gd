extends "res://tests/jungle_aloe_use_test.gd"
## Village Confidante on the real Jungle host (rendered). Supplied prerequisite: GV_LUTHER_KNOWS_ABOUT_DANIEL=1 (the
## weapon-shop intro earns it in a campaign) and a carried, equipped short sword; local approach positions supplied.
## Production producers only after that: the barrel prop1465 coming into the camera's view (sight edge), region3408 and
## region3397 entry edges, the clip clock, and a real Q (basic Spark) aimed at control123's body from region3409.
## - Meeting: sight links control123 idling; region3408 holds Luther; the conversation plays; a mid-conversation disk
##   save/load restores exactly; timer prop68/the segment end set Met_Confidant; Luther is released; region3397 sets
##   local20=2.
## - Kill (from the pre-meeting save, barrel still in view: a load is not a sight edge): a Spark (Q) from region3409
##   runs kill group 25802 once (Killed_Confidante=1, Soul-1, death segment,
##   prop492 state5), the death end unlinks it, a second Spark does nothing, and save/load keeps local39.
## - The village gate leaves are not opened by the Confidante owner (VILLAGE_ESCAPE_CONTRACT item 4).
var c
## The only walkable spot in reach and sight of control123 without entering region3408 (which starts the meeting and
## holds Luther) is region3409 (village_escape_route.json inside_to_confidante end, 163 units away): beyond melee
## reach (140), so the idle-window kill is a basic Spark (Q, range 384; population_actor ray -> receive_damage 8).
const APPROACH:=Vector2(-1269.5,-4390.5)
func tap(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
func place(at: Vector2) -> void:
	var top: Vector3=Vector3(at.x,300,at.y)+c.origin()
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*800,1,[scene.player.get_rid()]))
	var y: float=hit.position.y if not hit.is_empty() else 0.0
	scene.player.global_position=Vector3(at.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)+Vector3(c.origin().x,0,c.origin().z)
	scene.player.velocity=Vector3.ZERO
	await physics_frame
func centre(region_id: int) -> Vector2:
	var r: Dictionary=c.src.regions.filter(func(x): return int(x.id)==region_id)[0]
	var v:=Vector2.ZERO
	for p in r.polygon: v+=Vector2(p[0],p[1])
	return v/float(r.polygon.size())
func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		c.advance(1.0/30.0)
		if i%30==0: await process_frame
func look(at: Vector3) -> void:
	scene.camera.look_at(at+c.origin())
	await physics_frame
func soul() -> int: return preload("res://scripts/lol2/shared_global_defaults.gd").read(scene.quest_state.monastery.globals,"GV_LUTHERS_SOUL")

func run() -> void:
	var path:="user://tests/opus_confidante_live.json";var before_meeting:="user://tests/opus_confidante_before.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	set_meta("lol2_jungle_handoff",{"collected":["cave:captain:Short_Sword"],"equipped_item":"cave:captain:Short_Sword","equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	c=scene.confidante
	if not check(c!=null and is_instance_valid(c),"Confidante owner missing"): return
	c.set_physics_process(false)
	scene.quest_state.monastery.globals["GV_LUTHER_KNOWS_ABOUT_DANIEL"]=1 # supplied prerequisite (focused fixture)
	if not check(scene.equipped_item!="","Supplied sword not equipped"): return
	# Sight edge: stand back from the barrel, outside the source regions, and look at it.
	var barrel: Array=c.src.props["1465"].position
	await place(APPROACH)
	c._regions()
	if not check(c.inside.is_empty(),"Approach stands in a Confidante region: %s"%[c.inside]): return
	# Sight is an edge: first look away (the first look after the load records what is in view), then turn to the barrel.
	await look(Vector3(APPROACH.x,40,APPROACH.y-300))
	c._sight()
	await look(Vector3(barrel[0],barrel[1]+40,barrel[2]))
	c._sight()
	if not check(c.state.controls["123"].present and int(c.state.controls["123"].segment)==3 and c.meshes["123"].visible,"Barrel sight did not show control123"): return
	if not check(scene.quicksave(before_meeting).is_empty(),"Pre-meeting save rejected"): return
	# Meeting.
	await place(centre(3408));c._regions()
	if not check(c.speaking()=="123" and scene.actor_input_locked() and int(c.state.locals["20"])==1,"Region3408 did not start the meeting"): return
	await step(3)
	if not check(int(c.state.controls["123"].segment)==0,"Conversation segment did not start"): return
	await step(5)
	if not check(scene.quicksave(path).is_empty(),"Mid-conversation save rejected"): return
	var saved: Dictionary=c.checkpoint()
	await step(4)
	if not check(scene.quickload(path).is_empty() and c.checkpoint()==saved,"Mid-conversation rollback differs"): return
	await step(40)
	if not check(c.speaking()=="" and not scene.actor_input_locked() and int(c.state.locals["27"])==1 and not c.state.controls["123"].present,"Conversation end: speaking=%s"%c.speaking()): return
	await place(centre(3397));c._regions()
	if not check(int(c.state.locals["20"])==2,"Region3397 did not set local20"): return
	# Kill from the pre-meeting save: a real Q (basic Spark) aimed at the idling control from region3409.
	if not check(scene.quickload(before_meeting).is_empty() and int(c.state.controls["123"].segment)==3,"Pre-meeting reload"): return
	var at: Array=c.src.locations["123"].control.position
	await place(APPROACH)
	await look(Vector3(at[0],at[1]+float(c.src.locations["123"].control.dimensions[2])/2,at[2]))
	c.present()
	var soul0:=soul()
	await tap(KEY_Q)
	await process_frame
	if not check(c.killed() and soul()==soul0-1 and int(c.state.controls["123"].owner_state)==5 and int(c.state.props["492"].owner_state)==5,"Spark did not kill control123: local39=%d soul %d->%d"%[int(c.state.locals["39"]),soul0,soul()]): return
	await step(1)
	await tap(KEY_Q)
	await process_frame
	if not check(soul()==soul0-1,"Second Spark changed the Soul"): return
	await step(3)
	if not check(not c.state.controls["123"].present,"Death end did not unlink control123"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and c.killed(),"Saved Killed_Confidante lost"): return
	if not check(not c.src.records.any(func(r): return str(r.owner_kind)=="movable"),"Confidante owner must not host the gate leaves"): return
	await finish(scene)
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(before_meeting)
	print("PASS jungle_confidante_live_test: barrel sight → region3408 hold → conversation, rollback, Met_Confidant, release → region3397; Spark kill once from region3409 (Killed_Confidante, Soul-1), unlink, save/load. Supplied Daniel knowledge, sword and approach positions; not a campaign route.")
	quit()
