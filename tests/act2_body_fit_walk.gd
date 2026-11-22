extends SceneTree
## Real W/mouse/C/E/F5/F9 input from the native arrival; hash-pinned carried state, no pose writes.
const Save = preload("res://scripts/lol2/act2_save.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
var scene: Node3D
var failed := false
var samples := []
var sample_ticks := 0
var visited := {}
var fitted := false
var low_seen := false
var healing := 0
var attacks := 0
var held_w := false
var out := ""
var proof := {}
var recent := []
var used_doors := {}
var route_actions := {}
func scenario() -> String: return "blood"
func _initialize(): run.call_deferred()
func check(ok:bool,message:String)->bool:
	if not ok and not failed:
		failed=true;proof["failure"]=message
		if is_instance_valid(scene):
			proof["recent_steps"]=recent.duplicate(true)
			proof["failure_state"]={"health":scene.starting_magic.health(),"flying":scene.flying,"resets":scene.resets,"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"crouched":scene.crouched,"physical_C":Input.is_physical_key_pressed(KEY_C),"mouse":Input.mouse_mode,"height":scene.player.get_child(0).shape.height}
			if scene.liquid_drowning!=null:
				proof.failure_state["drowning"]={"dead":scene.liquid_drowning.drowning.dead,"elapsed":scene.liquid_drowning.drowning.elapsed,"region":scene.liquid_drowning.polygon_at(scene.player.position)}
		write_proof();push_error(message);quit(1)
	return ok
func write_proof():
	if out.is_empty():return
	DirAccess.make_dir_recursive_absolute(out)
	var f:=FileAccess.open(out+"receipt.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(proof,"  "));f.close()
func set_key(code:Key,down:bool):
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func press(code:Key):
	await process_frame
	var prior:int=scene.get_instance_id()
	set_key(code,true);await process_frame;set_key(code,false)
	if code==KEY_F9:
		for i in 1800:
			await process_frame
			if is_instance_valid(current_scene) and current_scene.get_instance_id()!=prior and current_scene.get("ready_for_review")==true and current_scene.get("starting_magic")!=null:break
		scene=current_scene;scene.progression.change_scene_enabled=false
	for i in 4:await physics_frame
func forward(down:bool):
	if held_w==down:return
	held_w=down;set_key(KEY_W,down)
func aim(at:Vector3):
	var delta:Vector3=at-scene.camera.global_position
	var yaw:=atan2(-delta.x,-delta.z)
	var pitch:=atan2(delta.y,Vector2(delta.x,delta.z).length())
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
	Input.parse_input_event(motion);Input.flush_buffered_events()
func click():
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=root.get_visible_rect().size*0.5
		Input.parse_input_event(e);Input.flush_buffered_events();await physics_frame
func shot(label:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+label+".png")
func sample():
	sample_ticks+=1
	var fit:Dictionary=scene.player.get_meta("lol2_world_fit",{})
	recent.append({"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"velocity":scene.player.velocity,"on_floor":scene.player.is_on_floor(),"fit":fit.duplicate()})
	if recent.size()>64:recent.pop_front()
	var region:int=scene._collision_region_at(scene.player.position)
	visited[region]=true
	if bool(fit.get("active",false)):
		fitted=true;low_seen=low_seen or float(fit.height)<=20.1
		if not check(float(fit.radius)>=8.0 and float(fit.height)>=8.0,"World body went below Lizard minimum8"):return
	var shape:Shape3D=scene.player.get_child(0).shape
	if not check(is_equal_approx(float(shape.radius),Body.RADII[scene.player_form]),"Creature/prop contact shape lost its ordinary form radius"):return
	if not check(is_equal_approx(float(shape.height),Body.HEIGHTS[scene.player_form]),"Ordinary form height restored outside world move"):return
	if not check(not scene.flying and scene.resets==0 and scene.starting_magic.health()>0,"No flight/death/recovery: flying=%s resets=%d health=%d position=%s"%[scene.flying,scene.resets,scene.starting_magic.health(),scene.player.position]):return
	if samples.is_empty() or samples.back().region!=region or sample_ticks%120==0:
		samples.append({"region":region,"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"fit":fit.duplicate(),"contact_radius":shape.radius})
func after_sample()->bool:return true
func proof_folder()->String:return scenario()
func route_path()->String:return "res://tests/fixtures/task3c_"+scenario()+"_route.json"
func crossing_complete(_pass_index:int)->bool:return true
func walk(points:Array,label:String)->bool:
	for index in points.size():
		for id in route_actions.get(str(index),[]) if label=="approach" else []:
			forward(false);aim(scene.progression.movable_position(int(id)))
			await press(KEY_E);used_doors[int(id)]=true
			print("INPUT E planned native mover ",id)
			for wait_tick in 120:await physics_frame
		var goal:=Vector2(float(points[index][0]),float(points[index][1]));var reached:=false
		var before:Vector3=scene.player.position;var stalled:=0
		for tick in 2400:
			if not check(scene.is_physics_processing(),"Production movement host is live"):return false
			if not check(scene.starting_magic.health()>0,"Player survived real walk"):return false
			if scene.starting_magic.health()<=24 and float(scene.starting_magic.magic_state().cooldown)<=0:
				await press(KEY_2);await press(KEY_Q);healing+=1
			var delta:=Vector3(goal.x-scene.player.position.x,0,goal.y-scene.player.position.z)
			if delta.length()<(float(points[index][2]) if points[index].size()>2 else 6.0) and scene.player.is_on_floor():reached=true;break
			var target:Node3D=null
			var door_id:=-1
			for i in scene.player.get_slide_collision_count():
				var body=scene.player.get_slide_collision(i).get_collider()
				if body is Node3D and body.has_meta("population_actor"):target=body
				for id in scene.progression.mover_bodies:
					if scene.progression.mover_bodies[id]==body and not used_doors.has(id):door_id=int(id)
			if door_id>=0:
				forward(false);aim(scene.progression.movable_position(door_id))
				await press(KEY_E);used_doors[door_id]=true
				print("INPUT E native mover ",door_id," at ",scene.player.position)
			elif target!=null and tick%18==0:
				forward(false);aim(target.global_position+Vector3.UP*12.0)
				await click();attacks+=1
			else:
				aim(scene.player.global_position+Vector3(delta.x,scene.camera.position.y,delta.z))
				forward(true)
			await physics_frame;sample()
			if not await after_sample():return false
			if failed:return false
			stalled=stalled+1 if scene.player.position.distance_to(before)<0.01 else 0
			before=scene.player.position
			if tick%360==0:print("INPUT WALK ",scenario()," ",label," ",index," ",before," fit ",scene.player.get_meta("lol2_world_fit",{}))
			if stalled>240:break
		forward(false)
		if not reached:
			await shot("failure")
			var region:int=scene._collision_region_at(scene.player.position)
			for collision_index in scene.player.get_slide_collision_count():
				var collision=scene.player.get_slide_collision(collision_index)
				print("STALL CONTACT ",collision.get_collider()," normal ",collision.get_normal()," point ",collision.get_position())
			print("STOP L19 ",scene.player.position.x,",",scene.player.position.z," ",region," actual real-input stall ",label," [sol]")
			return check(false,label+" point%d at %s"%[index,scene.player.position])
	return true
func configure_clock()->void:
	pass # Every passage acceptance now uses the engine's ordinary clock.
func run():
	configure_clock()
	if not check(is_equal_approx(Engine.time_scale,1.0) and Engine.physics_ticks_per_second==60,"Passage acceptance clock1/60"):return
	out="user://tests/task3c/"+proof_folder()+"/"
	DirAccess.make_dir_recursive_absolute(out)
	var path:=OS.get_environment("LOL2_BODY_FIT_ARRIVAL_SAVE" if scenario()=="blood" else "LOL2_BODY_FIT_SEWER_SAVE")
	var input:=Save.read_save(path,"lol2-restoration-map-L19_BC")
	proof={"scenario":scenario(),"input":path,"input_sha256":FileAccess.get_sha256(path),"teleports":0,"healing":"real2/Q only","scope":"Local passage traversal from unchanged archived checkpoint, not acceptance of its upstream chain. Blood uses physical rim/cap over614, not native floor band near-25."}
	proof["clock"]={"time_scale":Engine.time_scale,"physics_ticks_per_second":Engine.physics_ticks_per_second}
	proof["context_aid_source_sites"]=[{"setting":"lol2_map_start_selector","value":1 if scenario()=="blood" else 3},{"setting":"adapter_exit_seeds","value":false}]
	if not check(input.error.is_empty(),"Pinned input checkpoint: "+str(input.error)):return
	set_meta("lol2_map_start_selector",1 if scenario()=="blood" else 3)
	scene=load("res://scenes/lol2/maps/L19_BC.tscn").instantiate();scene.adapter_exit_seeds=false
	root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:break
	var native_arrival:Vector3=scene.player.position
	if not check(scene.apply_area_handoff(input.state).is_empty(),"Normal carried-state handoff, keeping native arrival pose"):return
	if not check(scene.player.position==native_arrival,"Handoff did not change native arrival coordinates"):return
	proof["native_arrival"]=[native_arrival.x,native_arrival.y,native_arrival.z]
	proof["scope"]="Real-input passage from native arrival1 (blood) or native arrival3 (rapids), with pinned incoming carried state. Archived player pose is not used. Blood uses physical rim/cap over614. No whole upstream-chain acceptance."
	scene.progression.change_scene_enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await click()
	if not check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Real click captured world input"):return
	if not check(scene.act2_creatures.is_physics_processing() and not scene.development_mode,"Production host and creatures live"):return
	for i in 20:await physics_frame
	if scenario()=="blood":
		set_key(KEY_C,true);for i in 6:await physics_frame
		print("PHYSICAL C ",Input.is_physical_key_pressed(KEY_C)," crouched ",scene.crouched," height ",scene.player.get_child(0).shape.height," mouse ",Input.mouse_mode," form ",scene.player_form," pose ",scene.player.position," host-live ",scene.is_physics_processing())
		await shot("physical_C")
		if not check(scene.crouched and scene.player.get_child(0).shape.height==32.0,"Inherited physical C crouches act2_map"):return
		set_key(KEY_C,false);for i in 6:await physics_frame
		if not check(not scene.crouched and scene.player.get_child(0).shape.height==46.0,"Release C restores Human in clear arrival"):return
		proof["physical_C"]=true
	var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(route_path()))
	route_actions=route.get("actions",{})
	if not await walk(route.approach,"approach"):return
	if scenario()=="blood":
		await press(KEY_E)
		if not check(scene.get_node("L19BelialHorn").state().taken,"Real E at rim takes Belial's Horn"):return
		if not await walk(route.corridor,"to pool approach"):return
	await press(KEY_F5)
	var save_path:String=preload("res://scripts/lol2/game_save.gd").slot_path(1)
	if not check(FileAccess.file_exists(save_path),"Real F5 wrote approach save"):return
	var bytes:=(JSON.stringify(preload("res://scripts/lol2/game_save.gd").read_document(save_path).state.area_save,"  ",true,true)+"\n").to_utf8_buffer()
	var archived:=FileAccess.open(out+"approach_save.json",FileAccess.WRITE);archived.store_buffer(bytes);archived.close()
	proof["approach_save_sha256"]=FileAccess.get_sha256(out+"approach_save.json")
	proof["slot_sha256"]=FileAccess.get_sha256(save_path)
	var approach:Vector3=scene.player.position
	for pass_index in 2:
		if pass_index==1:
			await press(KEY_F9)
			if not check(scene.player.position.distance_to(approach)<8.0,"Real F9 restored saved approach"):return
		visited.clear();fitted=false;low_seen=false;samples.clear();sample_ticks=0
		if not await walk(route.crossing,"crossing%d"%pass_index):return
		if not check(visited.has(613) and visited.has(18) if scenario()=="blood" else visited.has(760) and visited.has(759),"Both required linked regions physically visited"):return
		# The rapids acceptance is an earned physical crossing. Preserving ordinary
		# step/slide may remove its former unnecessary duck; do not require a resize.
		if scenario()=="blood" and not check(fitted,"Blood passage actually used the bounded adapter"):return
		print("PASSAGE BODY ",scenario()," pass",pass_index," fitted=",fitted," low_fit=",low_seen)
		if not check(not scene.body_fit.active,"Ordinary world body restored in clear exit"):return
		if not await crossing_complete(pass_index):return
		proof["pass%d"%pass_index]={"fitted":fitted,"low_fit":low_seen,"trace":samples.duplicate(true),"visited":visited.keys(),"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z]}
		await shot("pass%d"%pass_index)
	proof["passed"]=true;proof["real_heals"]=healing;proof["real_attacks"]=attacks;proof["native_door_uses"]=used_doors.keys()
	proof["source_commit"]=OS.get_environment("LOL2_SOURCE_COMMIT")
	write_proof();scene.queue_free();await process_frame;await process_frame
	print("PASS Task3c ",scenario(),": real-input passage and repeated F9 walk; min8, original contact radius, no teleport/flight/recovery")
	quit()
