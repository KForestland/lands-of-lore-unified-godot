extends SceneTree
const Save=preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum);current_scene=museum
	for i in range(5): await process_frame
	museum.set_physics_process(false)
	var pop=museum.skeleton_population
	pop.set_physics_process(false)
	var sword=museum.sword_transfer
	sword.set_process(false)
	if not check(not pop.state.actors["21"].present and not sword.struck and not sword.replaced,"Fresh actor21/prop107 state differs"):return
	# Source group1998 needs prop107 state3: no hit while carrying the sword.
	sword.restart();sword.advance(1.0)
	if not check(not sword.receive_hit() and not sword.struck,"Hit accepted before prop107 state3"):return
	sword.advance(7.0)
	if not check(sword.phase=="complete","Sword sequence did not complete"):return
	museum.carried_collected.append(museum.SWORD_ITEM_ID);sword.collect();museum.equipped_item=museum.SWORD_ITEM_ID
	var point: Vector3=sword.hit_point()
	var placed:=false
	for angle in range(0,360,15):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*60
		museum.player.global_position=Vector3(point.x+offset.x,32,point.z+offset.z)
		museum.camera.look_at(point)
		await physics_frame
		if museum.can_strike_sword_skeleton(): placed=true;break
	if not check(placed,"Sword skeleton not reachable for a strike"):return
	museum.equipped_item=""
	if not check(not museum.can_strike_sword_skeleton(),"Unarmed human strike admitted"):return
	museum.equipped_item=museum.SWORD_ITEM_ID
	if not check(museum.strike_sword_skeleton() and sword.struck and not sword.replaced and not pop.state.actors["21"].present,"Strike did not enter state4"):return
	if not check(not museum.strike_sword_skeleton(),"Second strike accepted"):return
	# Saved inside the state4 window keeps the pending replacement.
	var path:="user://tests/museum_sword_skeleton.json"
	if not check(museum.quicksave(path).is_empty(),"State4 save failed"):return
	var mid: Dictionary=sword.checkpoint()
	sword.struck=false
	if not check(museum.quickload(path).is_empty() and sword.checkpoint()==mid and sword.actor.visible,"State4 lost on reload"):return
	sword.advance(1.0)
	var a: Dictionary=pop.state.actors["21"]
	if not check(sword.replaced and not sword.actor.visible and a.present and a.woken and float(a.rise)>=0.0,"Endpoint did not replace prop107 with live skeleton21"):return
	if not check(pop.bodies["21"].visible and pop.bodies["21"].collision_layer==2 and pop.targets().has(str(pop.config.get("target_prefix","creature"))+"21"),"Skeleton21 not targetable"):return
	if not check(not museum.strike_sword_skeleton(),"Replaced prop107 still struck"):return
	if not check(museum.quicksave(path).is_empty(),"State5 save failed"):return
	var done: Dictionary=sword.checkpoint()
	sword.replaced=false;sword.actor.visible=true;pop.state.actors["21"].present=false
	if not check(museum.quickload(path).is_empty() and sword.checkpoint()==done and not sword.actor.visible and pop.state.actors["21"].present,"State5 lost on reload"):return
	# Malformed and inconsistent packets are rejected before changing live state.
	var saved: Dictionary=Save.read_save(path).state
	for change in [["replaced","yes"],["struck",false],["elapsed",3.0]]:
		var bad: Dictionary=saved.duplicate(true);bad.checkpoint.sword[change[0]]=change[1]
		if not check(not Save.validate(bad).is_empty(),"Accepted bad sword "+str(change)):return
	var orphan: Dictionary=saved.duplicate(true);orphan.checkpoint.skeletons.actors["21"].present=false
	if not check(not Save.validate(orphan).is_empty(),"Accepted replacement without skeleton21"):return
	# Legacy saves without prop107 states load as state3 with skeleton21 absent.
	var legacy: Dictionary=saved.duplicate(true);legacy.checkpoint.sword.erase("struck");legacy.checkpoint.sword.erase("replaced")
	legacy.checkpoint.skeletons.actors["21"].present=false
	if not check(Save.validate(legacy).is_empty(),"Legacy sword state rejected"):return
	museum.apply_save(legacy)
	if not check(not sword.struck and not sword.replaced and sword.actor.visible and not pop.state.actors["21"].present,"Legacy restore differs"):return
	DirAccess.remove_absolute(path)
	print("PASS: prop107 state3 strike (armed, reach/aim/LOS) -> state4 -> selector2 endpoint replaces it with live skeleton21 (rise+fight); state4/5 disk rollback; malformed/inconsistent rejected; legacy saves")
	museum.queue_free()
	await process_frame
	quit()
