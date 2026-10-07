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
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Scenic Spark scene"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false);scene.guard_population.set_physics_process(false);scene.wild_roach_population.set_physics_process(false);scene.roach_population_live.set_process(false)
	scene.starting_magic.set_process(false)
	var magic:=TestMagic.new();scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
	var guard=scene.scenic_guard;guard.set_physics_process(false)
	var helper: StaticBody3D=guard.effects.target
	var viewed:=false
	for angle in range(0,360,15):
		var p: Vector3=helper.global_position+Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*100
		var down:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*80,p-Vector3.UP*100,1)
		var floor_hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty():continue
		scene.player.global_position=floor_hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		scene.camera.look_at(helper.global_position+Vector3.UP*35);await physics_frame
		var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*600,3,[scene.player.get_rid()])
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider==helper:viewed=true;break
	if not check(viewed,"Production Spark line of sight to source prop574"):return
	scene.flying=false
	var old: Dictionary=magic.magic_state().duplicate(true)
	if not check(not guard.receive_damage("prop574",8,true,20) and not guard.state.effects.started,"Melee mask2 rejected"):return
	magic.select_spell("spark")
	if not check(magic.cast(1),"Actual basic Spark cast"):return
	if not check(guard.state.effects.started and guard.state.effects.durability==1 and guard.state.selector==3 and guard.state.pending.is_empty() and guard.state.local0==1,"Spark admitted complete ordered source group"):return
	if not check(guard.state.effects.selectors.size()==19 and guard.state.effects.movie_loaded and guard.state.effects.reward_issued,"Oil fire/movie/reward"):return
	var rewarded: Dictionary=magic.magic_state()
	if not check(rewarded.player.level==old.player.level+1 and rewarded.player.mana==old.player.mana+(rewarded.player.maximum-old.player.maximum)-1,"Source one-level magic reward and cast cost"):return
	for i in range(90):guard.advance(1.0/60.0)
	var path:="user://tests/cave_scenic_spark.json"
	if not check(scene._quicksave(path).is_empty(),"Partial explosion scene save"):return
	var partial: Dictionary=guard.checkpoint();var magic_partial: Dictionary=magic.magic_state().duplicate(true)
	if not check(guard.effects.overlay.visible and guard.effects.overlay.texture!=null,"Projected original movie visible"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/spark_explosion.png")
	paused=true;guard.advance(1.0);await process_frame;await process_frame
	for voice in guard.effects.voices.values():
		if voice.playing and not check(voice.stream_paused,"Scene pause freezes original sound voices"):return
	if not check(guard.checkpoint()==partial,"Whole scene pause"):return
	paused=false
	for i in range(850):guard.advance(1.0/60.0)
	if not check(guard.state.selector==4 and guard.state.actor_state==1 and guard.state.prop_state==1 and not guard.state.prop_present and guard.state.movables["21"] and guard.state.movables["22"] and guard.state.pending.is_empty(),"Movie endpoint→actor event3→corpse and helpers"):return
	if not check(guard.effects.helpers["21"].get_meta("source_present") and guard.effects.helpers["22"].get_meta("source_present"),"Nonvisual source helper activation"):return
	await capture("res://tmp/regressions/cave_scenic_guard_package/spark_terminal.png")
	if not check(scene._quickload(path).is_empty() and guard.checkpoint()==partial and magic.magic_state()==magic_partial,"Explosion/collapse/audio/reward disk rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	for i in range(850):guard.advance(1.0/60.0)
	if not check(guard.state.selector==4 and magic.magic_state()==magic_partial,"Restored completion does not repeat reward"):return
	var invalid: Dictionary=scene._save_state();invalid.scenic_guard.effects.movie_time=999.0
	if not check(not scene.WalkthroughSave.validate(invalid,scene._checkpoint_count()).is_empty(),"Invalid movie clock rejection"):return
	print("PASS actual basic Spark hit prop574→original explosion/sounds+19fires→source magic level→automatic movie/collapse endpoints/corpse/helper21+22; pause, partial scene rollback, no reward repeat, invalid clock")
	scene.queue_free();await process_frame;await process_frame;quit()
