extends SceneTree
## Original L3_DH op2 sub0x3C regions (tools/prepare_museum_human_return.py): with the Cave's held curse form a player
## entering the Museum becomes human at any of the seven regions, not only the Long arm ducts. Production Museum
## scene, Long arm owner and curse; SUPPLIED: held form/curse state (as transferred from the Cave) and positions.
const Form=preload("res://scripts/lol2/player_form_body.gd")
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL museum_human_return_regions: ", message); quit(1); return false
func place(point: Vector2, floor: float) -> void:
	scene.player.global_position=Vector3(point.x,floor+Form.FOOT_OFFSET+2,point.y)
	for i in range(20):
		scene.player.velocity=Vector3(0,-30,0); scene.player.move_and_slide(); await physics_frame
		if scene.player.is_on_floor(): break
func held(form: int) -> void:
	scene.player_form=form; Form.apply(scene.player,scene.camera,form,false)
	scene.curse.restore({"phase":0,"previous":0,"target":form,"remaining":0.0,"duration":0.0,"seed":324508639,"cave_triggered":false,"admission_flags":48})
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene); current_scene=scene
	for i in range(30): await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var arm=scene.long_arm
	if arm==null or arm.human_return_rows.size()!=7: return fail("Expected all seven source human-return regions, got %d" % (0 if arm==null else arm.human_return_rows.size()))
	var results:={}
	# A held lizard (Cave region631 result) away from every human-return region stays a lizard.
	held(2); await place(Vector2(-3796,-369),2); for i in range(120): await physics_frame
	if scene.player_form!=2: return fail("Held form changed outside human-return regions")
	for id in ["58","444","1474"]:
		var row: Dictionary=arm.human_return_rows[id]
		var c:=Vector2.ZERO
		for v in row.polygon: c+=Vector2(v[0],v[1])/row.polygon.size()
		var form:=2 if id!="444" else 1
		held(form); await place(c,float(row.floor[0]))
		var t:=0
		while scene.player_form!=0 and t<600: await physics_frame; t+=1
		if scene.player_form!=0 or int(scene.curse.state.phase)!=0: return fail("Region %s did not return form %d to human: form %d %s" % [id,form,scene.player_form,scene.curse.state])
		results[id]=t
	# Disabled admission (bit0x10 clear) keeps the form, as the native request requires admission.
	var row58: Dictionary=arm.human_return_rows["58"]
	var c58:=Vector2.ZERO
	for v in row58.polygon: c58+=Vector2(v[0],v[1])/row58.polygon.size()
	held(1); scene.curse.set_requests_enabled(false); await place(c58,float(row58.floor[0]))
	for i in range(240): await physics_frame
	if scene.player_form!=1: return fail("Human return ignored disabled admission")
	print("PASS museum_human_return_regions: 7 source regions hosted; held lizard unchanged elsewhere; regions58/444/1474 (main rooms) return to human (frames %s); disabled admission keeps the form" % [results])
	scene.queue_free(); await process_frame; quit()
