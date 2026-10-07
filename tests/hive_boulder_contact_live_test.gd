extends SceneTree
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if ok: return true
	push_error(message);quit(1);return false
func place(form: int=0) -> void:
	scene.player_form=form
	assert(preload("res://scripts/lol2/player_form_body.gd").apply(scene.player,scene.camera,form,false))
	scene.player.position=Vector3(-2230,-1355,-6720)
	scene.boulders.bodies["30"].position=scene.player.position+Vector3(25,-32,0)
	scene.boulders.bodies["31"].position=Vector3(-2270,-1207,-6889)
	scene.boulders.contact=scene.boulders.Contact.initial()
	scene.get_node("Warriors").health=30
func run() -> void:
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(scene);current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	for node in [scene,scene.curse,scene.hive_curse,scene.boulder_surfaces,scene.boulders,scene.boulder_audio]: node.set_physics_process(false)
	var b=scene.boulders
	for form in range(3):
		place(form)
		if not check(b.resolve_contact("30",true),"Player movement did not contact boulder"): return
		if not check(scene.get_node("Warriors").health==20 and b.contact.magnitude==[130,55,205][form],"Form contact damage/impulse differs"): return
		# Correction must remove free overlap; repeated evaluation is not another hit.
		if not check(not b.resolve_contact("30",true) and scene.get_node("Warriors").health==20,"Resolved overlap emitted a duplicate hit"): return
		place(form)
		var accepted: bool=b.resolve_contact("30",false)
		if not check(accepted==(form!=2),"Boulder mover ignored native small-candidate gate"): return
		if form!=2 and not check(scene.get_node("Warriors").health==20,"Moving boulder lost damage"): return
	place()
	b.state.actors["30"].stopping=true
	if not check(b.resolve_contact("30",true) and scene.get_node("Warriors").health==30 and b.contact.magnitude==130,"State5 damage rejection removed physical response"): return
	b.state.actors["30"].stopping=false
	place()
	scene.starting_magic.aura.start()
	var protected_health: int=scene.get_node("Warriors").health
	if not check(b.resolve_contact("30",true) and scene.get_node("Warriors").health==protected_health and b.contact.magnitude==130,"Aura protection lost health or physical response"): return
	scene.starting_magic.cancel_aura()
	place()
	b.player_attempted=false
	b._physics_process(0.01)
	if not check(scene.get_node("Warriors").health==30,"Static overlap invented a movement attempt"): return
	scene.move_grounded(Vector3.RIGHT,0.01)
	b._physics_process(0.01)
	if not check(scene.get_node("Warriors").health==20,"Actual player movement attempt lost contact"): return
	b._physics_process(0.01)
	if not check(scene.get_node("Warriors").health==20 and b.contact.magnitude<130,"Momentum did not move away/decay without duplicate damage"): return
	place()
	paused=true
	if not check(not b.resolve_contact("30",true) and scene.get_node("Warriors").health==30,"Paused contact damaged player"): return
	paused=false
	# Save valid original actor state alongside a partial player impulse.
	b.restore(b.State.initial())
	b.contact={"version":1,"angle":49152,"magnitude":72.5}
	var path:="user://tests/hive_boulder_contact.json"
	if not check(scene.quicksave(path).is_empty(),"Contact save rejected"): return
	var saved: Dictionary=b.contact_checkpoint()
	var position: Vector3=scene.player.position
	b._physics_process(0.01)
	var expected_momentum: Dictionary=b.contact_checkpoint()
	var expected_position: Vector3=scene.player.position
	if not check(expected_momentum.magnitude<saved.magnitude and expected_position!=position,"Saved momentum does not move player"): return
	b.contact.magnitude=0
	if not check(scene.quickload(path).is_empty() and b.contact_checkpoint()==saved,"Partial impulse lost on disk restore"): return
	for node in [scene,scene.curse,scene.hive_curse,scene.boulder_surfaces,scene.boulders,scene.boulder_audio]: node.set_physics_process(false)
	b._physics_process(0.01)
	if not check(b.contact_checkpoint()==expected_momentum and scene.player.position.distance_to(expected_position)<0.001,"Reloaded momentum diverged"): return
	saved=b.contact_checkpoint()
	var transported: Dictionary=scene.area_handoff()
	var bad: Dictionary=scene.area_handoff()
	bad.quests.hive_boulder_contact.magnitude=-1
	if not check(not scene.apply_area_handoff(bad).is_empty() and b.contact_checkpoint()==saved,"Malformed impulse mutated live state"): return
	bad=scene.area_handoff();bad.quests.erase("hive_boulder_contact")
	if not check(not scene.apply_area_handoff(bad).is_empty(),"New missing contact packet accepted"): return
	bad.quests.erase("hive_boulder_contact_schema")
	if not check(scene.apply_area_handoff(bad).is_empty() and b.contact_checkpoint()==b.Contact.initial(),"Legacy save failed to initialize zero momentum"): return
	place()
	scene.get_node("Warriors").health=3
	if not check(b.resolve_contact("30",true) and scene.get_node("Warriors").health==0 and not scene.is_physics_processing(),"Lethal contact failed to stop player"): return
	if not check(not b.resolve_contact("30",true),"Dead player admitted repeated contact"): return
	scene.reset_position()
	if not check(b.contact_checkpoint()==b.Contact.initial(),"Retry/void reset retained momentum"): return
	scene.queue_free();await process_frame
	await physics_frame
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	await physics_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(transported).is_empty(),"Jungle rejected contact state"): return
	if not check(jungle.quicksave("user://tests/boulder_contact_jungle.json").is_empty() and jungle.quickload("user://tests/boulder_contact_jungle.json").is_empty(),"Jungle contact disk roundtrip failed"): return
	if not check(jungle.area_handoff().quests.hive_boulder_contact.angle==saved.angle and absf(jungle.area_handoff().quests.hive_boulder_contact.magnitude-saved.magnitude)<0.000000001,"Jungle lost suspended Hive momentum"): return
	jungle.queue_free();await process_frame
	print("PASS: live boulder contact in both directions, three forms, separation, state5, pause, partial impulse saves, rollback, legacy and death")
	quit()
