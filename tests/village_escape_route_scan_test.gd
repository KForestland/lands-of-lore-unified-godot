extends SceneTree
## Headless scan of tests/fixtures/village_escape_route.json on the live Jungle host with the production grounded mover
## (move_grounded, capsule, native blockers on). Each segment starts at its own first point (placed) and must reach every
## point; the village gate is supplied open and rooms/encounter owners are paused, so this proves walkability only,
## not the earned route (jungle_village_escape_route_test).
const VillageState=preload("res://scripts/lol2/jungle_village_state.gd")
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func place(at: Vector2) -> void:
	var top:=Vector3(at.x,300,at.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*800,1,[scene.player.get_rid()]))
	scene.player.global_position=Vector3(at.x,(hit.position.y if not hit.is_empty() else 0.0)+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)
	scene.player.velocity=Vector3.ZERO
	for i in 3: await physics_frame
func run() -> void:
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	for name in ["monastery","weapon_shop","magic_shop","village_alarm","bacatta57","kelsrick","villager_population","dino_population","exit_encounter","drunk","kityara","confidante","gate_leaves","village_dialogue","dawn","bacatta","bacatta65","actor62","chief_hut","exit_woman"]:
		var n=scene.get(name)
		if n!=null and is_instance_valid(n): n.set_physics_process(false);n.set_process(false)
	scene.village_gate.set_physics_process(false)
	scene.village_gate.state().local24=1;scene.village_gate.state().elapsed=VillageState.DURATION;scene.village_gate.restore()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/village_escape_route.json"))
	for key in ["shop_to_gate","gate_to_inside","inside_to_confidante","confidante_to_tavern","tavern_to_outside","outside_to_tavern","return_to_leaf"]:
		var pts: Array=fixture.routes[key].points
		await place(Vector2(pts[0][0],pts[0][1]))
		for i in range(1,pts.size()):
			var target:=Vector2(pts[i][0],pts[i][1]);var best:=INF;var since:=0
			for step in 3000:
				var off:=target-Vector2(scene.player.global_position.x,scene.player.global_position.z)
				if off.length()<4: break
				if off.length()<best-0.5: best=off.length();since=0
				else: since+=1
				if not check(since<240,"%s stalls before point %d %s at %s"%[key,i,target,scene.player.global_position]): return
				scene.move_grounded(Vector3(off.x,0,off.y).normalized(),1.0/60.0)
				await physics_frame
			if not check(Vector2(scene.player.global_position.x,scene.player.global_position.z).distance_to(target)<4,"%s did not reach point %d"%[key,i]): return
		print("segment ",key," walked: ",pts.size()," points")
	print("PASS village_escape_route_scan_test: all seven segments walked with the production grounded mover (gate supplied open)")
	quit(0)
