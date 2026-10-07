extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for pair in [["res://scenes/lol2/jungle_walkthrough.tscn","dawn"],["res://scenes/lol2/hive_review.tscn","dawn20"]]:
		var scene=load(pair[0]).instantiate();root.add_child(scene);current_scene=scene
		await process_frame;await physics_frame
		scene.set_physics_process(false)
		var dawn=scene.get(pair[1]);dawn.set_physics_process(false)
		var point: Array=dawn.src.actor.position
		var context: Dictionary={"position":[roundi(float(point[0])*65536),roundi(-float(point[2])*65536)],"height":int(point[1])+40,"sprite_height":20,"owner_radius":16,"effect_radius":8,"heading":0,"initial_heading":0,"initial_speed":0,"speed":200,"flags":0}
		var before: Dictionary=dawn.checkpoint()
		var result: Dictionary=dawn.query_projectile_launch(context)
		if result.has("error") or result.regions.is_empty() or result.regions.all(func(r):return r<0):
			push_error("Real host launch could not resolve caster region: %s %s"%[pair,result]);quit(1);return
		if dawn.checkpoint()!=before:
			push_error("Launch query changed encounter checkpoint");quit(1);return
		print("HOST launch: %s region=%s accepted=%s world=%s"%[pair[1],result.regions,result.accepted,result.world_position])
		scene.queue_free();for i in 3:await process_frame
	print("PASS: both production Dawn hosts resolve launch regions and physics without altering saved encounter state; supplied source height/radius, no cast creation.")
	quit()
