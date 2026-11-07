extends "res://tests/cave_guard_live_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready)
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var pop=scene.guard_population;pop.set_physics_process(false)
	assert(pop.navigation!=null)
	pop.State.spawn(pop.state,"39");pop.State.wake(pop.state,"39")
	pop.State.advance_clocks(pop.state,pop.src,3.0)
	var body: CharacterBody3D=pop.bodies["39"]
	var from: Vector3=body.global_position-pop.origin()
	var selected:=false
	for region in pop.navigation.regions:
		if region[0].size()!=4: continue
		var center:=Vector2.ZERO
		for point in region[0]: center+=Vector2(point[0],point[1])/4.0
		var distance:=center.distance_to(Vector2(from.x,from.z))
		if distance<400 or distance>600: continue
		var goal:=Vector3(center.x,float(region[1])+32,center.y)
		if pop.navigation.next_point(from,goal)==null: continue
		scene.player.global_position=goal+pop.origin();selected=true;break
	assert(selected)
	var samples: Array=[]
	for frame in range(30):
		await physics_frame
		pop.advance(1.0/60.0)
		if pop.moving["39"]: samples.append(float(pop.clocks["39"]))
	print("NAV_CLOCK_SAMPLES=",JSON.stringify(samples))
	assert(samples.size()>5)
	print("NAV_CLOCK_MAX=",samples.max())
	assert(float(samples.max())>0.45)
	print("PASS: navigation pursuit preserves walking clock across 30 production steps")
	scene.queue_free();await process_frame
	quit()
