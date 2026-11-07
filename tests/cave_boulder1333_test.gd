extends SceneTree
## Owner 2026-10-21 ("the beast moving the rock", north of the first curse; longplay 7:03-7:08). Production Cave:
## prop1333 blocks the neck to the north room; human contact does nothing; the real beast support109 branch arms it
## (prop state 1); walking into it slides it to the group9470 destination; quicksave/quickload keep the state.
const Form=preload("res://scripts/lol2/player_form_body.gd")
var scene: Node3D
var boulder: Node3D
var last_hit:=""
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> bool:
	push_error(message);print("FAIL cave_boulder1333: ",message);quit(1);return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture");root.get_texture().get_image().save_png("user://capture/boulder1333_"+name+".png")
func stand(point: Vector3,form: int) -> void:
	scene.player_form=form;Form.apply(scene.player,scene.camera,form,false)
	scene.player.global_position=point+scene.native_translation+Vector3.UP*(Form.FOOT_OFFSET+2)
	for i in range(20):
		scene.player.velocity=Vector3(0,-30,0);scene.player.move_and_slide();await physics_frame
		if scene.player.is_on_floor():break
## Neck axis: from the boulder's resting spot toward its group9470 destination (into the north room).
func axis() -> Vector3:
	var d: Vector3=boulder.finish-boulder.start;d.y=0;return d.normalized()
## Can a human body cross the boulder's resting spot along the neck axis (from 110 behind to 40 beyond; the moved
## boulder rests 180 further along that axis, inside the north room)?
## Straight along the axis through the boulder's centre; last_hit is the collider.
func passes() -> bool:
	for deg in [0]:
		var from: Transform3D=scene.player.global_transform
		var d: Vector3=axis().rotated(Vector3.UP,deg_to_rad(deg))
		from.origin=boulder.start+boulder.instance.get_parent().global_position-d*110.0+Vector3.UP*(Form.FOOT_OFFSET+1)
		var hit:=KinematicCollision3D.new()
		if not scene.player.test_move(from,d*150.0,hit):return true
		if deg==0:last_hit=hit.get_collider().name if hit.get_collider()!=null else "?"
	return false
## Distance a human body travels from the resting spot along the neck axis turned by deg (into the north room).
func reach(deg: float) -> float:
	var from: Transform3D=scene.player.global_transform
	from.origin=boulder.start+boulder.instance.get_parent().global_position+Vector3.UP*(Form.FOOT_OFFSET+1)
	var d: Vector3=axis().rotated(Vector3.UP,deg_to_rad(deg))*320.0
	var hit:=KinematicCollision3D.new()
	return hit.get_travel().length() if scene.player.test_move(from,d,hit) else 320.0
## Closest horizontal distance from the rock centre to the human body's edge, walking at the centre from 150 units out on
## the corridor side (against the neck axis, turned by deg).
func approach(deg: float) -> float:
	var centre: Vector3=boulder.start+boulder.instance.get_parent().global_position
	var d: Vector3=-axis().rotated(Vector3.UP,deg_to_rad(deg))
	var from: Transform3D=scene.player.global_transform
	from.origin=centre+d*150.0+Vector3.UP*(Form.FOOT_OFFSET+1)
	var hit:=KinematicCollision3D.new()
	var travel: float=hit.get_travel().length() if scene.player.test_move(from,-d*150.0,hit) else 150.0
	return 150.0-travel-Form.RADII[0]
## Owner 2026-10-26: from inside the neck, can this form cross a north exit (portal point, toward the north room)?
func crosses(portal: Vector2, other: Vector2, form: int) -> bool:
	var n := Vector3(other.x - portal.x, 0, other.y - portal.y).normalized()
	await stand(Vector3(portal.x, 0, portal.y) - n * 30.0, form)
	var hit := KinematicCollision3D.new()
	return not scene.player.test_move(scene.player.global_transform, n * 80.0, hit)
## Exits from the neck into the north room (source portals 866->768 and 870->774), each with a point beyond.
## The low lizard tunnel after region631: from region639 into region629 (20 units of headroom).
const TUNNEL := [Vector2(-349, -5916), Vector2(-300, -5925)]
const EXITS := [[Vector2(-1276, -6206), Vector2(-1290, -6260)], [Vector2(-1222, -6188), Vector2(-1205, -6240)]]
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready:break
	if not scene.walkthrough_ready:return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.curse.set_physics_process(false)
	boulder=scene.get("boulder1333")
	if boulder==null:return fail("Boulder1333 not hosted")
	boulder.set_physics_process(false)
	var controls=scene.get("guard_controls")
	if controls==null:return fail("Guard controls missing")
	controls.set_physics_process(false)
	Form.apply(scene.player,scene.camera,0,false)
	if int(boulder.state)!=0 or boulder.armed():return fail("Boulder not resting/unarmed at start")
	if passes():return fail("Human passes the resting boulder")
	if last_hit not in ["Solid1333","Neck1333"]:return fail("Neck probe hit %s, not the boulder or its neck" % last_hit)
	# Owner F10 r12l 2026-10-28 15:17:55 ("I can walk past the texture"): walking at the rock from the corridor side, the
	# human body stops at least 40 units from its centre (the drawn rock is 64 wide each side of its centre).
	for deg in range(-60,65,20):
		var closest: float = approach(deg)
		if closest < 40.0:return fail("Human walks %.1f units from the rock centre at %d degrees (into the drawn rock)" % [closest, deg])
	# Owner 2026-10-26 / walkthroughs: no form leaves the neck past the resting rock; the lizard's way is the low tunnel
	# at region631 (source regions 635-634-639-629-776, 20-40 units of headroom), which human and beast do not fit.
	for exit in EXITS:
		for form in 3:
			if await crosses(exit[0], exit[1], form):return fail("Form %d crosses the neck exit %s past the resting rock" % [form, exit[0]])
	for form in 3:
		var through: bool = await crosses(TUNNEL[0], TUNNEL[1], form)
		if through != (form == 2):return fail("Low tunnel at region629: form %d passes=%s" % [form, through])
	Form.apply(scene.player,scene.camera,0,false)
	# Human contact, unarmed: nothing (native predicate207 needs prop state 1).
	var behind: Vector3=boulder.start-axis()*(boulder.FACE_OFFSET+boulder.FACE_RADIUS+Form.RADII[0]+1.0)
	await stand(Vector3(behind.x,boulder.start.y,behind.z)-scene.native_translation+boulder.instance.get_parent().global_position,0)
	for i in 30:boulder.advance(1.0/60.0)
	if int(boulder.state)!=0:return fail("Unarmed contact moved the boulder")
	# Real beast support109 contact arms it (group10114 prop1333 state 1).
	await stand(Vector3(-760,0,-5948),1);controls.advance(1.0/60.0)
	await stand(Vector3(-969,1,-5948),1)
	scene.camera.look_at(Vector3(-1051,32,-5874)+scene.native_translation)
	controls.advance(1.0/60.0)
	if not boulder.armed():return fail("Beast support109 did not arm prop1333: %s" % [controls.state.prop1333])
	# Beast walks into the boulder along the neck axis (native bump -> event5 value1).
	behind=boulder.start-axis()*(boulder.FACE_OFFSET+boulder.FACE_RADIUS+Form.RADII[1]+12.0)
	await stand(Vector3(behind.x,boulder.start.y,behind.z)-scene.native_translation+boulder.instance.get_parent().global_position,1)
	scene.player.look_at(scene.player.global_position+axis(),Vector3.UP);scene.camera.rotation=Vector3.ZERO
	await capture("before")
	for i in 40:
		scene.player.velocity=axis()*120.0;scene.player.move_and_slide();await physics_frame
		boulder.advance(1.0/60.0)
		if int(boulder.state)!=0:break
	if int(boulder.state)!=1:return fail("Beast bump did not start the slide")
	var pre:="user://tests/cave_boulder1333_mid.json"
	if not scene._quicksave(pre).is_empty():return fail("Mid-slide save failed")
	var saved_clock:=float(boulder.clock)
	for i in 70:boulder.advance(1.0/60.0)
	if int(boulder.state)!=2 or not boulder.instance.position.is_equal_approx(boulder.finish):return fail("Slide did not finish at the group9470 destination")
	await capture("moved")
	if not passes():return fail("Moved boulder still blocks the neck: %s" % last_hit)
	for exit in EXITS:
		if not await crosses(exit[0], exit[1], 0):return fail("Human cannot leave the neck at %s after the rock moved" % [exit[0]])
	await stand(Vector3(behind.x,boulder.start.y,behind.z)-scene.native_translation+boulder.instance.get_parent().global_position,1)
	# The beast that moved it walks on into the north room (longplay 7:08-7:11).
	var best:=0.0
	for deg in range(-40,45,5):best=maxf(best,reach(deg))
	if best<200.0:return fail("North room not reachable by the beast past the moved boulder: %s" % best)
	if not scene._quickload(pre).is_empty():return fail("Mid-slide reload failed")
	if int(boulder.state)!=1 or not is_equal_approx(float(boulder.clock),saved_clock):return fail("Reload lost the slide: %s" % [boulder.checkpoint()])
	for i in 70:boulder.advance(1.0/60.0)
	if int(boulder.state)!=2:return fail("Reloaded slide did not finish")
	for bad in [{"state":3,"clock":0.0},{"state":2,"clock":0.5},{"state":1,"clock":1.0},{"state":0}]:
		if boulder.validate(bad).is_empty():return fail("Malformed boulder state accepted: %s" % [bad])
	print("PASS cave_boulder1333: solid in the neck, no form leaves the neck while it rests and only the lizard fits the region631 low tunnel, unarmed contact inert, real beast support109 arms, beast bump slides to the group9470 destination in %.1f s, neck opens and the north room is reachable by the beast past it, mid-slide quicksave/quickload, malformed rejected" % boulder.SLIDE_SECONDS)
	quit(0)
