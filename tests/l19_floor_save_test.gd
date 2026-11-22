extends SceneTree
## Component, not earned: native group calls and held host physics are disclosed.
const Save=preload("res://scripts/lol2/act2_save.gd")
var scene: Node
var failures:=0
func check(ok:bool,message:String)->bool:
	if not ok: failures+=1;push_error(message)
	return ok
func _initialize()->void:run.call_deferred()
func make_scene()->void:
	scene=load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in 1200:
		await process_frame
		if scene.ready_for_review and scene.progression!=null:break
	scene.set_physics_process(false)
	for i in 3:await process_frame
func floors(height:int)->bool:
	return int(scene.progression.regions[40][1])==height and int(scene.progression.regions[61][1])==height
func same_packet(actual:Dictionary,expected:Dictionary)->bool:
	# JSON reads integral values as floats; compare their validated numeric values.
	if float(actual.clock)!=float(expected.clock) or actual.motions.size()!=expected.motions.size():return false
	for key in expected.motions:
		if not actual.motions.has(key):return false
		for field in ["height","remaining","fraction","speed"]:
			if int(actual.motions[key][field])!=int(expected.motions[key][field]):return false
	return true
func run()->void:
	await make_scene()
	var before="user://tests/c10_before.json";var after="user://tests/c10_after.json"
	check(floors(-40),"Native bars floors are -40")
	check(scene.progression.struck_refs.is_empty(),"Staged L19 has no kind-9 struck refs; floor repair makes no struck-reset claim")
	check(Save.save_host(scene,before).is_empty(),"Write pre-click checkpoint")
	var origin:Vector3=scene.player.position
	scene.progression.fire("movable:77",6,{"caller_byte":15})
	for i in 600:scene.progression.advance_floors(1.0/60.0)
	check(floors(-20),"Native group raises both floors")
	check(Save.save_host(scene,after).is_empty(),"Write raised checkpoint")
	var raised:Dictionary=Save.read_save(after,scene.area_save_format).state
	check(raised.floor_motion.motions.has("40") and raised.floor_motion.motions.has("61"),"Both raised decks are persisted")
	# Component placement on the affected region makes carry-on-restore observable.
	var stand:=Vector3(-301.5,12.0,-1876.5)
	scene.player.position=stand
	check(scene.progression.region_at(scene.player.position)==40,"Carry fixture stands on affected region40")
	scene.progression._carry_floor(40,-20,-40)
	check(scene.player.position==stand+Vector3.DOWN*20.0,"Positive control: ordinary floor delta carries fixture by20")
	scene.player.position=stand
	var lower:Dictionary=Save.read_save(before,scene.area_save_format).state.floor_motion
	scene.progression.restore_floor_checkpoint(lower)
	check(floors(-40) and scene.player.position==stand,"World restore lowers floor20 without carrying fixture before pose load: %s"%scene.player.position)
	var low_stand:=stand+Vector3.DOWN*20.0
	scene.player.position=low_stand
	scene.progression.restore_floor_checkpoint(raised.floor_motion)
	check(floors(-20) and scene.player.position==low_stand,"World restore raises floor20 without carrying fixture before pose load: %s"%scene.player.position)
	check(Save.load_host(scene,before).is_empty() and floors(-40),"Pre-click save actually resets both floors")
	check(scene.progression.floor_motion.is_empty(),"No future floor movement leaks across reload")
	check(scene.player.position==origin,"Normal load restores the saved arrival pose")
	scene.progression.fire("movable:77",6,{"caller_byte":15})
	for i in 600:scene.progression.advance_floors(1.0/60.0)
	check(floors(-20),"Reloaded native strike can run again")
	check(Save.load_host(scene,after).is_empty() and floors(-20),"Raised checkpoint retains raised floor state")
	var bad=raised.duplicate(true);bad.floor_motion.motions["65535"]=bad.floor_motion.motions["40"]
	check(not scene.apply_save(bad).is_empty() and floors(-20),"Invalid region refuses before world changes")
	var old=Save.read_save(before,scene.area_save_format).state;old.erase("floor_motion")
	check(scene.apply_save(old).is_empty() and floors(-40),"Older pre-click packet restores native baseline")
	scene.queue_free();await process_frame;await process_frame
	await make_scene()
	check(scene.apply_save(raised).is_empty() and floors(-20),"Fresh scene recreates raised decks")
	check(absf(scene.progression.floor_decks[40].position.y-20.0)<0.01,"Fresh deck collision/mesh transform is restored")
	check(Save.load_host(scene,before).is_empty() and floors(-40),"Repeated reverse load resets fresh decks")
	var pending=raised.duplicate(true)
	pending.floor_motion.clock=0.375
	pending.floor_motion.motions["40"]={"height":-39,"remaining":19,"fraction":32768,"speed":2}
	check(scene.apply_save(pending).is_empty(),"Pending floor packet loads")
	var exact:Dictionary=scene.progression.floor_checkpoint()
	check(same_packet(exact,pending.floor_motion),"Pending height/remaining/fraction/rate/clock survive exactly")
	check(Save.save_host(scene,"user://tests/c10_pending.json").is_empty(),"Pending checkpoint writes through normal save")
	check(same_packet(Save.read_save("user://tests/c10_pending.json",scene.area_save_format).state.floor_motion,pending.floor_motion),"Disk packet preserves pending accumulators")
	scene.queue_free();await process_frame
	if failures==0:print("PASS L19 floor save: before/after, fresh scene, repeated load, old/invalid packets and positive-controlled carry-free world restoration")
	quit(0 if failures==0 else 1)
