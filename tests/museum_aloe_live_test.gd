extends SceneTree
## Supplied poses/forms only; does not establish an earned route.
const S=preload("res://scripts/lol2/museum_aloe_state.gd")
const Body=preload("res://scripts/lol2/player_form_body.gd")
var scene
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: printerr("FAIL: "+message);quit(1)
	return ok
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	for i in 5: await physics_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	for node in [scene.long_arm,scene.tiny_enclosure,scene.curse]:node.set_physics_process(false)
	scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.aloe_pickups
	if not check(is_instance_valid(owner) and owner.pickups.size()==2,"Two Aloe actors"):return
	var poses=[Vector3(-1439,-179.087661743164,-1106),Vector3(-1595,-169.9,-1102)]
	for i in 2:
		var form:int=0 if i==0 else 2
		Body.apply(scene.player,scene.camera,form,false);scene.player_form=form
		scene.player.global_position=poses[i]+Vector3.UP*Body.FOOT_OFFSET;scene.camera.look_at(owner.pickups[i].global_position)
		await physics_frame
		if not check(owner.offered()==i,"Reachable Aloe at supplied pose %s"%i):return
		if i==0:
			var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
			box.size=Vector3(2,100,100);shape.shape=box;wall.add_child(shape);scene.add_child(wall)
			wall.global_position=(scene.camera.global_position+owner.pickups[i].global_position)*0.5
			await physics_frame;await physics_frame
			if not check(owner.offered()==-1 and not owner.use(),"Opaque wall blocks Aloe"):return
			wall.queue_free();await physics_frame;await physics_frame
			var original:Array=scene.carried_collected.duplicate()
			# Capacity fault injection; restored before all save assertions.
			while scene.carried_collected.size()<64:scene.carried_collected.append("capacity-probe")
			if not check(owner.use() and not owner.state.taken[0] and owner.pickups[0].visible,"Full pack preserves pickup"):return
			scene.carried_collected=original
		var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
		scene._unhandled_input(key)
		if not check(owner.state.taken[i] and scene.carried_collected.count(S.IDS[i])==1 and not owner.pickups[i].visible,"Production E collects Aloe once"):return
		DirAccess.make_dir_recursive_absolute("user://tests")
		var path:="user://tests/museum_aloe_live.json"
		if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Host save/load"):return
		if not check(owner.state.taken[i] and not owner.pickups[i].visible,"No respawn after load"):return
	if not check(not owner.use(),"Repeat pickup refuses"):return
	print("PASS supplied-pose live Aloe: production E, wall blocking, capacity refusal and host persistence")
	quit()
