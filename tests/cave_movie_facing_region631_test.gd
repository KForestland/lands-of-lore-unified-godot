extends SceneTree
## Playtest 2026-10-17: reports10:43:24/10:51:27 (guard movies run the wrong way) and10:48:34 (no first transformation).
## A. Plate89 starts the captain intro (control120, heading0x3999): from the source reposition pose the frames mirror,
##    so the guard leaves toward the side where the live captain then spawns.
## B. Plate114 starts actor52's clip (camera-facing, unmirrored) then control119's (heading31493, mirrored).
## C. Region631 first contact requests the first random curse (beast/lizard) with source duration0: the form is held
##    (no timeout), survives disk reload without re-firing, transfers to the Museum and takes its control109 branch.
## D. A later source curse region from the held form: nonhuman draw refused but consumed; human draw is timed and
##    reverts to the held form (D4906 previous-form request, duration0).
## SUPPLIED: start positions (plates, owner pose), test clocks via owner advance(); everything else production.
const Form=preload("res://scripts/lol2/player_form_body.gd")
const Facing=preload("res://scripts/lol2/placed_movie_facing.gd")
const Curse=preload("res://scripts/lol2/player_curse.gd")
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_movie_facing_region631: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/cave_movie_facing_"+name+".png")
func stand(point: Vector3, form: int) -> void:
	scene.player_form=form; Form.apply(scene.player,scene.camera,form,false)
	scene.player.global_position=point+scene.native_translation+Vector3.UP*(Form.FOOT_OFFSET+2)
	for i in range(20):
		scene.player.velocity=Vector3(0,-30,0); scene.player.move_and_slide(); await physics_frame
		if scene.player.is_on_floor(): break
## Restoration RNG seed whose next _draw(0,2) returns value (player_curse._draw stream).
func seed_for(value: int) -> int:
	for s in range(1,1000):
		if ((1664525*s+1013904223) & 0xffffffff) % 3 == value: return s
	return 1
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false); scene.guard_population.set_physics_process(false)
	scene.wild_roach_population.set_physics_process(false); scene.roach_population_live.set_process(false)
	# A. Captain intro from its real plate.
	var captain=scene.captain; captain.set_physics_process(false)
	var plate: Dictionary=captain.media.plates[0]
	scene.player.global_position=Vector3(plate.position[0],plate.height+34,plate.position[2])+scene.native_translation
	for i in range(30):
		scene.player.velocity=Vector3(0,-30,0); scene.player.move_and_slide(); await physics_frame
		captain.advance(1.0/60.0)
		if captain.intro_active(): break
	if not captain.intro_active(): return fail("Plate89 did not start the intro")
	for i in range(60): captain.advance(1.0/60.0)
	captain.present()
	var view: Vector3=scene.player.global_position-scene.native_translation
	print("captain viewpoint ", view, " heading ", Facing.control_heading(str(captain.media.control_hex)))
	if not captain.picture.visible or not captain.picture.flip_h: return fail("Captain movie not mirrored from the source viewpoint")
	await capture("captain_intro")
	var heading: float=Facing.control_heading(str(captain.media.control_hex))
	var exit_dir: Vector3=Vector3(cos(heading),0,sin(heading))  # texture +x (where the guard leaves the frame)
	var exit_screen: float=scene.camera.global_basis.x.dot(exit_dir)
	var spawn: Vector3=Vector3(captain.src.captain.position[0],0,captain.src.captain.position[2])-Vector3(captain.media.position[0],0,captain.media.position[2])
	var spawn_screen: float=scene.camera.global_basis.x.dot(spawn)
	if signf(exit_screen)!=signf(spawn_screen): return fail("Guard exit side %.2f disagrees with captain spawn side %.1f" % [exit_screen,spawn_screen])
	for i in range(900):
		captain.advance(1.0/60.0)
		if not captain.intro_active(): break
	captain.present()
	if captain.picture.visible: return fail("Captain picture stayed after intro")
	# B. Support114: actor52 clip camera-facing, control119 clip heading-oriented.
	var controls=scene.guard_controls
	scene.starting_magic.set_health(30)
	await stand(Vector3(-152,-10,-7650),0); scene.camera.look_at(Vector3(-163,20,-7834)+scene.native_translation); controls.advance(1.0/60.0)
	if not controls.state.clips.actor52.playing: return fail("Plate114 did not start actor52's clip")
	controls.present()
	if controls.pictures.actor52.visible and controls.pictures.actor52.flip_h: return fail("Actor52 clip was mirrored")
	await capture("actor52")
	for i in range(400):
		controls.advance(1.0/60.0)
		if controls.state.clips.control119.playing: break
	for i in range(30): controls.advance(1.0/60.0)
	controls.present()
	if not controls.pictures.control119.visible or not controls.pictures.control119.flip_h: return fail("Control119 clip not mirrored from the owner view")
	await capture("control119")
	# The same clip seen from the front of its source plane reads unmirrored.
	var owner_pose: Vector3=scene.player.global_position
	var c119: Array=controls.src.placements.control119.position
	var centre: Vector3=Vector3(c119[0],c119[1],c119[2])+scene.native_translation
	var h: float=float(controls.src.placements.control119.heading)*TAU/65536.0
	var normal: Vector3=Vector3(-sin(h),0,cos(h))
	if (owner_pose-centre).dot(normal)>0: normal=-normal
	scene.player.global_position=centre+normal*120.0+Vector3.UP*40
	scene.camera.look_at(centre+Vector3.UP*40)
	controls.present()
	var front: bool=controls.pictures.control119.flip_h
	if not controls.pictures.control119.visible or front: return fail("Front-side view still mirrored")
	scene.player.global_position=owner_pose
	for i in range(900):
		controls.advance(1.0/60.0)
		if not controls.input_locked(): break
	# C. Region631 first curse: source duration0 = held form.
	scene.set_physics_process(true); scene.curse.set_physics_process(true); scene.guard_population.set_physics_process(true)
	scene.curse.restore(scene.curse.initial())
	await stand(Vector3(-700,0,-6200),0)  # outside region631
	for i in range(5): await physics_frame
	if scene.curse.state.phase!=0: return fail("Curse active before region631")
	scene.player.global_position=Vector3(-550.228,32.05,-6084.04)+scene.native_translation
	var t:=0
	while scene.curse.state.phase==0 and t<120: await physics_frame; t+=1
	if not 631 in scene.guard_population.state.regions or not scene.guard_population.state.actors["39"].present: return fail("Region631 contact/guard39 spawn missing")
	var target: int=int(scene.curse.state.target)
	# Owner 2026-10-21 adapter (DEVIATIONS): the native held form gets the cave curse regions' 60-90 s timer.
	if scene.curse.state.phase!=1 or target not in [1,2] or scene.curse.state.duration<60.0 or scene.curse.state.duration>90.0: return fail("Region631 did not request the timed curse: %s" % [scene.curse.state])
	t=0
	while scene.player_form==0 and t<600: await physics_frame; t+=1
	if scene.player_form!=target or scene.curse.state.phase!=2: return fail("Timed form %d did not arrive: form %d %s" % [target,scene.player_form,scene.curse.state])
	if not Curse.valid(scene.curse.snapshot(),scene.player_form): return fail("Timed curse state invalid")
	var path:="user://tests/cave_region631.json"
	if not scene._quicksave(path).is_empty(): return fail("Cursed save failed")
	scene.player_form=0; scene.curse.state.previous=1
	if not scene._quickload(path).is_empty(): return fail("Cursed load failed")
	if scene.player_form!=target or int(scene.curse.state.phase)!=2: return fail("Reload lost the timed form")
	scene.player.global_position=Vector3(-700,0,-6200)+scene.native_translation+Vector3.UP*40
	for i in range(30): await physics_frame
	scene.player.global_position=Vector3(-550.228,32.05,-6084.04)+scene.native_translation
	for i in range(30): await physics_frame
	if int(scene.curse.state.phase)!=2 or scene.player_form!=target: return fail("Reload re-fired region631: %s" % [scene.curse.state])
	# Cave -> Museum transfer admits the held form.
	var packet: Dictionary={"curse":scene.curse.snapshot(),"player_form":scene.player_form}
	if not preload("res://scripts/lol2/museum_walkthrough.gd").validate_cave_transfer(packet).is_empty(): return fail("Museum transfer refused the held form")
	# Resulting form takes the matching source control109 branch on its real plate.
	scene.set_physics_process(false); scene.curse.set_physics_process(false); scene.guard_population.set_physics_process(false)
	await stand(Vector3(-969,1,-5948),target); controls.advance(1.0/60.0)
	var expected: String="beast" if target==1 else "lizard"
	if controls.state.branch109!=expected: return fail("Form %d took branch %s" % [target,controls.state.branch109])
	# D. The timed form expires back to human (owner 2026-10-21 adapter; the native form was held).
	scene.curse.advance(float(scene.curse.state.remaining)+0.01)
	for i in range(3): scene.curse.advance(0.02)
	for i in range(240):
		await physics_frame
		if scene.player_form==0: break
	if scene.player_form!=0 or int(scene.curse.state.phase)!=0: return fail("Timed form did not return to human: form %d %s" % [scene.player_form,scene.curse.state])
	var outcomes:={"timed_back_to_human":true}
	print("PASS cave_movie_facing_region631: captain intro mirrored (exit side matches captain spawn), actor52 unmirrored, control119 mirrored (front view mirrored=%s); region631 -> timed form %d after %d frames (60-90 s), kept across reload, no re-fire, Museum transfer valid, control109 %s branch; then %s" % [front,target,t,expected,outcomes])
	scene.queue_free(); await process_frame; quit()
