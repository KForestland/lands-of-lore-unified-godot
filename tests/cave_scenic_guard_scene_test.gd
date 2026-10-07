extends SceneTree
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool:return true
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready and scene.scenic_guard!=null,"Scenic cave integration"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false)
	var magic:=TestMagic.new();scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
	var guard=scene.scenic_guard;var pop=scene.guard_population
	guard.set_physics_process(false);pop.set_physics_process(false);scene.wild_roach_population.set_physics_process(false);scene.roach_population_live.set_process(false)
	if not check(guard.mesh.visible and guard.prop_meshes["574"].visible and not guard.prop_meshes["223"].visible and not pop.state.actors["54"].present,"Source initial presence"):return
	# Partial idle clock goes through the actual whole-scene disk save path.
	guard.advance(0.5)
	var saved: Dictionary=guard.checkpoint();var texture: Texture2D=guard.library.last_texture
	var path:="user://tests/cave_scenic_integrated.json"
	if not check(scene._quicksave(path).is_empty(),"Scenic scene save"):return
	guard.advance(1.0)
	if not check(scene._quickload(path).is_empty() and guard.checkpoint()==saved and guard.library.last_texture==texture,"Partial idle disk rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	# Find a source-near standing viewpoint with verified floor and unobstructed eye ray.
	var viewed:=false
	for angle in range(0,360,15):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*100
		var down:=PhysicsRayQueryParameters3D.create(guard.global_position+offset+Vector3.UP*80,guard.global_position+offset-Vector3.UP*100,1)
		var floor_view: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_view.is_empty():continue
		var eye: Vector3=floor_view.position+Vector3.UP*35
		var look: Vector3=guard.global_position+Vector3(0,26,0)
		var sight:=PhysicsRayQueryParameters3D.create(eye,look,1)
		if not scene.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
		scene.player.global_position=floor_view.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		scene.camera.look_at(look);viewed=true;break
	if not check(viewed,"Original scenic guard visible viewpoint"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/standing.png")
	# Supplied source pose fixture tests actual scene persistence while the physical
	# hit/movie producer remains unbound; this does not acknowledge its commands.
	var collapse: Dictionary=guard.State.initial();collapse.selector=3;collapse.elapsed=5.0
	guard.restore(collapse)
	if not check(scene._quicksave(path).is_empty(),"Partial collapse scene save"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/collapse_partial.png")
	guard.advance(20.0)
	if not check(guard.state.selector==3 and guard.State.frame(guard.state,guard.source)==75,"Collapse endpoint holds without supplied source event"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/collapse_endpoint.png")
	if not check(scene._quickload(path).is_empty() and guard.checkpoint()==collapse,"Partial collapse scene rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false);guard.restore(guard.State.initial())
	# Source-position fixture, followed by physical floor movement across region969.
	var t: Vector3=scene.native_translation
	var region: Dictionary=pop.src.regions.filter(func(r):return int(r.region)==969)[0]
	var polygon:=PackedVector2Array();var centre:=Vector2.ZERO
	for v in region.polygon:polygon.append(Vector2(v[0],v[1]));centre+=Vector2(v[0],v[1])
	centre/=region.polygon.size()
	var floor_hit: Dictionary={};var start:=Vector3.ZERO
	for angle in range(0,360,15):
		var p:=centre+Vector2(cos(deg_to_rad(angle)),sin(deg_to_rad(angle)))*100
		if Geometry2D.is_point_in_polygon(p,polygon):continue
		start=Vector3(p.x,-220,p.y)+t
		var ray:=PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*160,1)
		floor_hit=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if not floor_hit.is_empty() and absf(floor_hit.position.y-t.y+265)<12:break
		floor_hit={}
	if not check(not floor_hit.is_empty(),"Region969 approach floor"):return
	var direction: Vector3=(Vector3(centre.x,0,centre.y)+Vector3(t.x,0,t.z)-Vector3(floor_hit.position.x,0,floor_hit.position.z)).normalized()
	scene.player.global_position=floor_hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	scene.flying=false;scene.camera.look_at(guard.global_position+Vector3(0,26,0))
	await physics_frame
	var walked:=0
	for i in range(150):
		scene.player.velocity=direction*48+Vector3.DOWN*10;scene.player.move_and_slide()
		pop.advance(1.0/60.0);guard.advance(1.0/60.0);walked+=1
		await physics_frame
		if 969 in pop.state.regions:break
	if not check(walked>1 and 969 in pop.state.regions and pop.state.actors["54"].present and not guard.state.present and not guard.mesh.visible,"Actual region969 alternate branch"):return
	if not check(guard.state.prop223_present and not guard.state.prop_present and guard.state.pending.is_empty() and guard.state.effects.flags17.size()==13,"Alternate source presence and13verified flag writes applied"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/alternate.png")
	if not check(scene._quicksave(path).is_empty(),"Alternate saved"):return
	var departed: Dictionary=guard.checkpoint();guard.restore(guard.State.initial())
	if not check(scene._quickload(path).is_empty() and guard.checkpoint()==departed and not guard.mesh.visible,"Alternate scene rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	# Exercise the shared local0 branch guard with a source-result fixture.
	pop.restore(pop.State.initial(pop.src));guard.restore(guard.State.initial());guard.state.local0=1
	scene.player.velocity=Vector3.DOWN*10;scene.player.move_and_slide();await physics_frame
	pop.advance(1.0/60.0)
	if not check(969 in pop.state.regions and not pop.state.actors["54"].present and guard.state.present and guard.state.pending.is_empty(),"local0 must gate shared guard54 alternate"):return
	var invalid: Dictionary=scene._save_state();invalid.scenic_guard.pending=[{"group":"560","cursor":99}]
	if not check(not scene.WalkthroughSave.validate(invalid,scene._checkpoint_count()).is_empty(),"Scenic malformed packet validation"):return
	var legacy: Dictionary=scene._save_state();legacy.erase("scenic_guard")
	if not check(scene.WalkthroughSave.validate(legacy,scene._checkpoint_count()).is_empty(),"Legacy scenic-optional save"):return
	print("PASS integrated scenic guard original visible pose; actual scene partial-save rollback; floor walk region969 alternate/removal; saved source flag writes; shared local0 gate; malformed and legacy save validation")
	scene.queue_free();await process_frame;await process_frame;quit()
