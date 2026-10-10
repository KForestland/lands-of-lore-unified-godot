extends SceneTree
## Earned local approach to the first L4WW meeting: from a certified departure-route waypoint before source
## region 1902, the player walks with real key input (physical W through the host's own _physics_process) and
## real mouse-look events (host _unhandled_input), along the certified route through regions 1902 and 4407,
## then turns off the route into source region 4387. Every producer is the live one (host physics, component
## physics, camera sighting, grounded region polygons, media clocks). The only placement is the start waypoint.
## Proves: the hold blocks the same key/mouse input, the conversation runs to actor0 and releases input, and
## the released player walks away under the same input.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const START:=128
const LAST_ROUTE:=162
## Inside the 4387 polygon, 40 units north of route waypoint 162.
const MEETING:=Vector2(5719.5,-3880.0)
var scene
var w
var failed:=false
var held_keys: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed=true;release_all();push_error(message);quit(1)
	return ok

func key(code: int, pressed: bool) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed
	Input.parse_input_event(e)
	if pressed and code not in held_keys: held_keys.append(code)
	if not pressed: held_keys.erase(code)
func release_all() -> void:
	for code in held_keys.duplicate(): key(code,false)

## Mouse-look toward a ground point, as a player turns: one motion event through the input pipeline.
func look_toward(target: Vector2) -> void:
	var p: Vector3=scene.player.global_position
	var offset:=target-Vector2(p.x,p.z)
	if offset.length()<0.5: return
	var want:=atan2(-offset.x,-offset.y)
	var turn:=wrapf(want-scene.player.rotation.y,-PI,PI)
	if absf(turn)<0.002: return
	var m:=InputEventMouseMotion.new();m.relative=Vector2(-turn/0.003,0)
	Input.parse_input_event(m)

## Walk to a point holding W and steering with the mouse; stops early on an actor hold.
func walk_to(target: Vector2, tolerance: float, limit: int=2400) -> bool:
	for i in limit:
		if scene.actor_input_locked(): key(KEY_W,false);return true
		var p: Vector3=scene.player.global_position
		if target.distance_to(Vector2(p.x,p.z))<tolerance: return true
		look_toward(target)
		if KEY_W not in held_keys: key(KEY_W,true)
		await physics_frame
		if scene.resets!=0 or scene.flying: return false
	return false

func run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=120
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame;await physics_frame
	root.grab_focus()
	for i in 3: await process_frame
	w=scene.exit_woman
	if not check(w!=null and w.state.prop.present and int(w.state.local1)==0 and not w.sighted,"Exit conversation not installed fresh"):return
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/act_one_departure_route.json"))
	if not check(int(route.regions[133])==1902 and int(route.regions[148])==4407,"Certified route indices moved"):return
	# Single placement: the certified waypoint before region 1902, on its ground.
	var start:=Vector2(route.points[START][0],route.points[START][1])
	var top:=Vector3(start.x,600,start.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*1400,1,[scene.player.get_rid()]))
	if not check(not hit.is_empty(),"Start waypoint has no ground"):return
	scene.player.global_position=hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	scene.player.velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in 10: await physics_frame
	if not check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and scene.player.is_on_floor(),"Start waypoint not grounded or mouse not captured"):return
	var visited: Array=[]
	var log_at: int=w.effect_log.size()
	for index in range(START+1,LAST_ROUTE+1):
		if not check(await walk_to(Vector2(route.points[index][0],route.points[index][1]),10.0),"Route walk blocked at waypoint %d %s"%[index,scene.player.global_position]):return
		for r in w.inside:
			if int(r) not in visited: visited.append(int(r))
		if not check(not scene.actor_input_locked(),"Hold engaged on the certified route itself (waypoint %d)"%index):return
	if not check(1902 in visited and 4407 in visited and int(w.state.local1)==0,"Route did not cross source regions 1902/4407 inertly: %s local1=%s"%[visited,w.state.local1]):return
	# Leave the route: turn north into source region 4387 under the same input.
	if not check(await walk_to(MEETING,6.0) and scene.actor_input_locked(),"Walking into region4387 did not engage the hold"):return
	key(KEY_W,false)
	var entry: Array=w.effect_log.slice(log_at).filter(func(e): return e.type in ["frames_start","clip_start","hold","reposition","focus"]).map(func(e): return [e.type,int(e.get("selector",-1))])
	if not check(w.sighted and 4387 in w.inside and int(w.state.local1)==3 and w.state.focus,"Earned entry state differs: sighted=%s inside=%s"%[w.sighted,w.inside]):return
	if not check(entry.slice(entry.rfind(["clip_start",0])+1)==[["focus",-1],["reposition",-1],["hold",-1],["frames_start",6]] and ["hold",-1] in entry and ["reposition",-1] in entry,"Earned entry effects differ: %s"%[entry]):return
	# Held: the same key and mouse input are refused by the host.
	var pinned: Vector3=scene.player.global_position;var yaw: float=scene.player.rotation.y
	key(KEY_W,true)
	var m:=InputEventMouseMotion.new();m.relative=Vector2(300,0);Input.parse_input_event(m)
	for i in 30: await physics_frame
	key(KEY_W,false)
	if not check(scene.player.global_position.distance_to(pinned)<0.5 and is_equal_approx(scene.player.rotation.y,yaw),"Held player moved/turned under input"):return
	# The conversation runs on its own clocks to actor0 and releases input.
	var started: Array=[]
	for i in 120*90:
		await physics_frame
		if not w.state.prop.present and not scene.actor_input_locked(): break
	for e in w.effect_log.slice(log_at):
		if e.type=="clip_start": started.append(int(e.selector))
	if not check(started.slice(started.find(6))==[6,15,8,7,14,13,9,0] and started.count(6)==1,"Earned first conversation order differs: %s"%[started]):return
	if not check(w.state.actors["0"].present and w.population.state.actors["0"].present and not w.state.focus and not scene.actor_input_locked(),"First meeting did not end with actor0 and released input"):return
	# Released: the same input moves the player again (back toward the route).
	var released: Vector3=scene.player.global_position
	if not check(await walk_to(Vector2(route.points[LAST_ROUTE][0],route.points[LAST_ROUTE][1]),10.0,240) or scene.player.global_position.distance_to(released)>20.0,"Released player could not walk"):return
	release_all()
	# Goal3 home return under live physics: actor0 walks to its home node and removes itself (kind6 value8).
	for i in 120*40:
		await physics_frame
		if not w.state.actors["0"].present: break
	if not check(not w.state.actors["0"].present and not w.population.state.actors["0"].present and w.effect_log.any(func(e): return e.type=="remove" and int(e.actor)==0),"Actor0 did not walk home and remove itself"):return
	if not check(scene.resets==0 and scene.player.is_on_floor(),"Earned approach lost ground"):return
	scene.queue_free()
	for i in 3: await process_frame
	if failed: return
	print("PASS jungle exit woman earned: certified waypoint%d start, real W key + mouse-look through host input, crossed source regions %s inertly (local1 0), walked off-route into region4387 → live sighting, hold, reposition, focus, first line once; held input refused; clocked [6,15,8,7,14,13,9,0] → actor0, input released and walkable; actor0 walked home and removed itself (kind6 value8). Local approach only (start placement), not a full campaign route."%[START,visited])
	quit()
