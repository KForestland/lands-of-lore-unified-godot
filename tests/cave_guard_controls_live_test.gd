extends SceneTree
const Controls=preload("res://scripts/lol2/cave_guard_controls.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Form=preload("res://scripts/lol2/player_form_body.gd")
var scene: Node3D
var controls: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func stand(point: Vector3,form: int) -> void:
	scene.player_form=form;Form.apply(scene.player,scene.camera,form,false)
	scene.player.global_position=point+scene.native_translation+Vector3.UP*(Form.FOOT_OFFSET+2)
	for i in range(20):
		scene.player.velocity=Vector3(0,-30,0);scene.player.move_and_slide();await physics_frame
		if scene.player.is_on_floor():break
func disk_roundtrip(path: String) -> bool:
	var packet: Dictionary={"controls":controls.checkpoint(),"guards":scene.guard_population.checkpoint()}
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(packet,"",true,true));file.close()
	var read: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(controls.State.validate(read.controls,controls.src,controls.media).is_empty() and Generic.validate(read.guards,scene.guard_population.src).is_empty(),"Partial packet disk validation"):return false
	controls.advance(0.5)
	if not check(scene.guard_population.restore(read.guards).is_empty() and controls.restore(read.controls).is_empty(),"Restore guard/control packet"):return false
	return check(controls.checkpoint()==packet.controls,"Exact guard controls partial rollback")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/cave_guard_controls_"+name+".png")
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Guard control cave ready"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false);scene.wild_roach_population.set_physics_process(false);scene.roach_population_live.set_process(false);scene.captain.set_physics_process(false)
	controls=scene.get("guard_controls")
	if controls==null:
		controls=Controls.new();scene.add_child(controls)
		if not check(controls.setup(scene).is_empty(),"Guard control setup"):return
	controls.set_physics_process(false);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var initial_population: Dictionary=scene.guard_population.checkpoint()
	await stand(Vector3(-969,1,-5948),0);controls.advance(1.0/60.0)
	if not check(controls.state.contact.owner==109 and controls.state.branch109=="none","Real human support109 excluded"):return
	await stand(Vector3(-760,0,-5948),1);controls.advance(1.0/60.0)
	await stand(Vector3(-969,1,-5948),1)
	scene.camera.look_at(Vector3(-1051,32,-5874)+scene.native_translation)
	controls.advance(1.0/60.0)
	if not check(controls.state.branch109=="beast" and controls.state.prop1333==1 and not scene.guard_population.state.actors["39"].present,"Actual beast support admits original1912/hides39"):return
	for i in range(30):controls.advance(1.0/60.0)
	if not check(await disk_roundtrip("user://tests/cave_guard109_beast.json"),"Beast partial save"):return
	await capture("beast")
	var inactive: Dictionary=controls.checkpoint();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;controls.advance(1);await physics_frame;await physics_frame;await process_frame
	if not check(controls.checkpoint()==inactive and (not controls.voices.prop533.playing or controls.voices.prop533.stream_paused),"Released input freezes movie and voice"):return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.walkthrough_ready=false;controls.advance(1)
	if not check(controls.checkpoint()==inactive,"Loading gate freezes owned clocks"):return
	scene.walkthrough_ready=true
	scene.chamber_arrival_state="playing";controls.advance(1)
	if not check(controls.checkpoint()==inactive,"Arrival gate freezes owned clocks"):return
	scene.chamber_arrival_state="not_started"
	var paused_packet: Dictionary=controls.checkpoint();paused=true;controls.advance(1);await physics_frame;await physics_frame;await process_frame;await process_frame
	if not check(controls.checkpoint()==paused_packet and (not controls.voices.prop533.playing or controls.voices.prop533.stream_paused),"Original prop movie voice/clock pause"):return
	paused=false
	for i in range(200):controls.advance(1.0/60.0)
	if not check(controls.state.actor39.present and controls.walking39() and not controls.state.clips.prop533.playing,"Beast completion sourcepath mode"):return
	var before: Vector3=scene.guard_population.bodies["39"].global_position
	for i in range(60):controls.advance(1.0/60.0);await physics_frame
	if not check(before.distance_to(scene.guard_population.bodies["39"].global_position)>15 and int(scene.guard_population.state.live["39"].mode)==0,"Original path39 moves without generic combat"):return
	if not check(await disk_roundtrip("user://tests/cave_guard109_path.json"),"Saved path progress"):return
	var path_packet: Dictionary={"guards":scene.guard_population.checkpoint(),"controls":controls.checkpoint()}
	for i in range(8000):
		controls.advance(1.0/60.0)
		if controls.state.actor39.removed:break
	if not controls.state.actor39.removed:print("ROUTE stopped index ",controls.state.actor39.path_index," position ",scene.guard_population.bodies["39"].global_position-scene.native_translation)
	if not check(controls.state.actor39.removed and not scene.guard_population.state.actors["39"].present and 14306 in controls.state.groups,"Complete original nine-point path reaches own region746 removal"):return
	if not check(await disk_roundtrip("user://tests/cave_guard109_removed.json"),"Removed guard retained-state rollback"):return
	scene.guard_population.restore(path_packet.guards);controls.restore(path_packet.controls)
	if not check(scene.guard_population.receive_damage("39",1,true,20),"Guard39 source hit"):return
	controls.advance(1.0/60.0)
	if not check(not controls.walking39() and controls.state.actor39.b5==12,"Hit returns39 to pending combat"):return
	# Independent lizard branch uses its original alternate movie, without the beast prop-state write.
	scene.guard_population.restore(initial_population);controls.restore(controls.State.initial())
	await stand(Vector3(-969,1,-5948),2);controls.advance(1.0/60.0)
	if not check(controls.state.branch109=="lizard" and controls.state.clips.prop533.resource==1913 and controls.state.prop1333==0,"Actual Lizard support alternate1913"):return
	for i in range(160):controls.advance(1.0/60.0)
	if not check(scene.guard_population.state.actors["39"].present and scene.guard_population.state.actors["39"].woken and not controls.walking39(),"Lizard completion wakes original39"):return
	# Original114 first owner movie must complete before119 starts.
	scene.guard_population.restore(initial_population);controls.restore(controls.State.initial());scene.starting_magic.set_health(30)
	await stand(Vector3(-152,-10,-7650),0);scene.camera.look_at(Vector3(-163,20,-7834)+scene.native_translation);controls.advance(1.0/60.0)
	if not check(controls.input_locked() and controls.state.clips.actor52.playing and not controls.state.clips.control119.playing,"Actual support114 starts actor52 selector10"):return
	for i in range(45):controls.advance(1.0/60.0)
	if not check(await disk_roundtrip("user://tests/cave_guard114_first.json"),"Actor52 partial disk rollback"):return
	await capture("actor52")
	for i in range(300):
		controls.advance(1.0/60.0)
		if controls.state.clips.control119.playing:break
	if not check(controls.state.clips.control119.playing and not controls.state.clips.actor52.playing and 14362 in controls.state.groups,"Original actor event0 starts control119"):return
	for i in range(45):controls.advance(1.0/60.0)
	if not check(await disk_roundtrip("user://tests/cave_guard114_second.json"),"Control119 partial disk rollback"):return
	await capture("control119")
	paused_packet=controls.checkpoint();paused=true;controls.advance(1);await physics_frame;await physics_frame;await process_frame;await process_frame
	if not check(controls.checkpoint()==paused_packet and (not controls.voices.control119.playing or controls.voices.control119.stream_paused),"Second original clip pauses"):return
	paused=false
	for i in range(800):controls.advance(1.0/60.0)
	if not check(not controls.input_locked() and not controls.state.control119_present and scene.guard_population.state.actors["52"].woken and 10332 in controls.state.groups,"Original119 completion wakes52/unlocks/removes"):return
	if not check(await disk_roundtrip("user://tests/cave_guard114_terminal.json"),"Terminal rollback"):return
	# Legacy source control writes disarm the handler without replaying either film.
	scene.guard_population.state.controls["109"]=1;scene.guard_population.state.controls["114"]=1;controls.restore(controls.State.initial(),true)
	if not check(controls.state.controls["109"]==1 and controls.state.controls["114"]==1 and not controls.input_locked(),"Legacy control owner disarms preserved"):return
	var malformed: Dictionary=controls.checkpoint();malformed.clips.control119.resource=1912
	var before_bad: Dictionary=controls.checkpoint()
	if not check(not controls.restore(malformed).is_empty() and controls.checkpoint()==before_bad,"Wrong owner movie rejects atomically"):return
	print("PASS real support109 human exclusion/beast originalmovie+full9markerpath/removal+hit/Lizard alternate;114 real support→actor52originalmovie→119originalmovie→wake/unlock; partial disk rollback both stages/path, originalvoice pause, legacy disarms and malformed packet")
	scene.queue_free();await process_frame;await process_frame;quit()
