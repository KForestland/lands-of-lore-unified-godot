extends SceneTree
const S = preload("res://scripts/lol2/museum_scroll_state.gd")
var scene
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("FAIL: "+message)
		quit(1)
	return ok
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene);current_scene=scene
	for i in 5: await physics_frame
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	for node in [scene.long_arm,scene.tiny_enclosure,scene.curse]: node.set_physics_process(false)
	scene.flying=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.scroll_pickups
	if not check(is_instance_valid(owner) and owner.pickups.size()==5,"Five original scroll actors"): return
	for i in 5:
		if not check(owner.pickups[i].texture.get_size()==Vector2(31,16) and owner.pickups[i].position.y==34,"Ground sprite bounds"): return
	# Supplied poses: owner/input/save test, not earned access.
	scene.player.global_position=Vector3(-1937,32.1,-1128)
	scene.camera.look_at(owner.pickups[0].global_position)
	await physics_frame
	if not check(owner.offered()>=0,"Reachable initial scroll active=%s mouse=%s flying=%s ready=%s health=%s cursor=%s reach=%s" % [scene.starting_magic.world_active(),Input.mouse_mode,scene.flying,scene.get("walkthrough_ready"),scene.starting_magic.health(),scene.interface_hud.cursor_active,scene.can_reach_item(owner.pickups[0].global_position)]): return
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(250,100,2);shape.shape=box;wall.add_child(shape);scene.add_child(wall);wall.global_position=Vector3(-1900,40,-1148)
	await physics_frame;await physics_frame
	if not check(owner.offered()==-1 and not owner.use(),"Opaque wall blocks pickup"): return
	wall.queue_free();await physics_frame;await physics_frame
	var count:=0
	for target in [0,1,2,3,4,0,1,2,3,4]:
		scene.player.global_position=Vector3(S.POSITIONS[target].x,32.1,-1128)
		scene.camera.look_at(owner.pickups[target].global_position)
		await physics_frame
		var offered: int=owner.offered()
		if offered<0: continue
		var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
		scene._unhandled_input(key)
		if not check(owner.state.taken[offered] and scene.carried_collected.count(S.IDS[offered])==1,"Production E grants offered copy"): return
		count+=1
		if count==2:
			DirAccess.make_dir_recursive_absolute("user://tests")
			var path: String="user://tests/museum_scroll_partial.json"
			if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Partial host save/load"): return
			if not check(owner.state.taken.count(true)==2,"Partial receipt preserved"): return
	if not check(count==5 and owner.state.taken.count(true)==5 and not owner.use(),"All copies once; repeat refuses"): return
	for id in S.IDS:
		if not check(scene.carried_collected.count(id)==1,"No duplicates"): return
	print("PASS live Museum scroll E collection, occlusion, partial host save/load, five unique copies")
	quit()
