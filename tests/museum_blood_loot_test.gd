extends "res://tests/player_magic_handoff_test.gd"
const Loot=preload("res://scripts/lol2/museum_blood_loot.gd")
const BombState=preload("res://scripts/lol2/dragon_blood_state.gd")
const ItemState=preload("res://scripts/lol2/player_item_state.gd")
const Population=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
var scene
var loot
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func press_e() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_E;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.keycode=KEY_E;event.pressed=false;Input.parse_input_event(event);await process_frame
func aim(index: int) -> bool:
	for angle in range(0,360,15):
		var p: Vector3=loot.sprites[index].global_position
		scene.player.global_position=p+Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
		scene.camera.look_at(p);await physics_frame
		if loot.aimed()==index:return true
	return false
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	await process_frame;scene.introduction_state="complete"
	if is_instance_valid(scene.introduction):scene.introduction.close();await process_frame
	freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	loot=scene.blood_loot
	var population=scene.skeleton_population
	if not check(loot.checkpoint()==null and not loot.sprites[0].visible,"Initial loot"):return
	for index in range(2,5):
		if not check(loot.sprites[index].visible and await aim(index),"Placed vial aim "+str(index)):return
		await press_e()
		if not check(scene.carried_collected.count(Loot.ITEMS[index])==1 and loot.state.taken[index],"Placed vial pickup"):return
	if not check(scene.quicksave("user://tests/museum_placed_blood.json").is_empty(),"Living-owner placed vials save"):return
	if not check(population.receive_damage("20",1000,true),"Production skeleton20 death"):return
	loot.set_physics_process(true);loot.set_process(true)
	for i in 8:await physics_frame
	freeze(loot)
	if not check(loot.state.elapsed>0 and not loot.sprites[0].visible,"Engine retirement clock"):return
	var path:="user://tests/museum_blood.json"
	if not check(scene.quicksave(path).is_empty(),"Partial loot disk"):return
	var before: Dictionary=loot.checkpoint()
	paused=true;loot.advance(10);paused=false
	if not check(loot.checkpoint()==before,"Paused loot clock"):return
	loot.advance(6)
	if not check(loot.sprites[0].visible and loot.sprites[1].visible and not population.meshes["20"].visible,"Two retired drops"):return
	var reload_error: String=scene.quickload(path)
	if not check(reload_error.is_empty() and is_equal_approx(float(loot.state.elapsed),float(before.elapsed)) and loot.state.taken==before.taken,"Partial loot reload: "+reload_error+" "+str(loot.checkpoint())+" vs "+str(before)):return
	freeze(scene);loot.advance(6)
	for index in 2:
		if not check(await aim(index),"Aim vial "+str(index)):return
		if index==0:
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/museum_blood_visible.png")
		await press_e()
		if not check(scene.carried_collected.count(Loot.ITEMS[index])==1 and loot.state.taken[index],"Individual vial pickup"):return
		if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Pickup disk roundtrip"):return
		freeze(scene)
	# Actual inventory Use places one bomb and consumes only that vial.
	scene.open_inventory();await process_frame
	var inventory=scene.inventory;var selected:=-1
	for i in inventory.item_list.item_count:
		if str(inventory.item_list.get_item_metadata(i))==Loot.ITEMS[0]:selected=i
	if not check(selected>=0,"Blood inventory entry"):return
	inventory.select_item(selected);inventory.use_selected_item();await process_frame;await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var effects: Dictionary=scene.item_effects.state()
	if not check(Loot.ITEMS[0] in effects.spent and Loot.ITEMS[0] not in scene.carried_collected and effects.dragon_blood.size()==1 and Loot.ITEMS[1] in scene.carried_collected,"Inventory use/placement"):return
	var bomb: Dictionary=effects.dragon_blood[0]
	var point:=Vector3(bomb.position[0],bomb.position[1],bomb.position[2])
	# A nearby live skeleton and player; positions supplied to isolate blast behavior.
	var sk: Dictionary=population.checkpoint();Population.spawn(sk,"23");sk.actors["23"].position=[point.x+24-population.origin().x,point.y-10-population.origin().y,point.z-population.origin().z]
	if not check(population.restore(sk).is_empty(),"Blast target fixture"):return
	scene.player.global_position=point+Vector3(0,32,25)
	var health_before: int=population.state.actors["23"].health
	scene.item_effects.advance(1)
	if not check(scene.quicksave(path).is_empty(),"Active bomb save"):return
	var remaining: float=scene.item_effects.state().dragon_blood[0].remaining
	paused=true;scene.item_effects.advance(9);paused=false
	if not check(scene.item_effects.state().dragon_blood[0].remaining==remaining,"Paused bomb advanced"):return
	if not check(scene.quickload(path).is_empty() and scene.item_effects.state().dragon_blood[0].remaining==remaining,"Active bomb reload"):return
	freeze(scene);scene.item_effects.state().dragon_blood[0].remaining=0.05
	scene.item_effects.set_process(true)
	for i in 12:await process_frame
	scene.item_effects.set_process(false)
	if not check(scene.item_effects.state().dragon_blood.is_empty() and population.state.actors["23"].health==health_before-20 and scene.health==10,"Engine explosion damage/retirement"):return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Exploded bomb reload"):return
	freeze(scene);scene.item_effects.advance(20)
	if not check(scene.health==10 and population.state.actors["23"].health==health_before-20 and not loot.sprites[0].visible and not loot.sprites[1].visible,"Bomb/drop repeated after load"):return
	var bad: Dictionary=scene.item_effects.state().duplicate(true);bad.dragon_blood=[{"id":Loot.ITEMS[1],"area":scene.scene_file_path,"position":[0,0,0],"remaining":1.0}]
	if not check(not ItemState.validate(bad,scene.carried_collected).is_empty(),"Unspent bomb admitted"):return
	bad=loot.checkpoint();bad.taken[0]=false
	if not check(not Loot.validate(bad,population.checkpoint(),scene.carried_collected,scene.item_effects.state().spent).is_empty(),"Consumed vial lost receipt"):return
	# Arm the remaining vial, leave the Museum, and retain its fuse through both area transports.
	scene.player.global_position=point+Vector3(0,32,25);scene.camera.look_at(point)
	scene.open_inventory();await process_frame
	inventory=scene.inventory
	for i in inventory.item_list.item_count:
		if str(inventory.item_list.get_item_metadata(i))==Loot.ITEMS[1]:inventory.select_item(i);break
	inventory.use_selected_item();await process_frame;await process_frame
	if not check(scene.item_effects.state().dragon_blood.size()==1 and Loot.ITEMS[1] in scene.item_effects.state().spent,"Second vial arm"):return
	if not check(scene.quicksave(path).is_empty(),"Second active Museum save"):return
	var held_fuse: float=scene.item_effects.state().dragon_blood[0].remaining
	var transport: Dictionary=scene.inventory_state()
	scene.queue_free();await process_frame;await process_frame
	set_meta("lol2_jungle_handoff",transport)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(jungle);current_scene=jungle;await process_frame
	freeze(jungle);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	jungle.item_effects.advance(10)
	if not check(jungle.item_effects.state().dragon_blood[0].remaining==held_fuse and jungle.item_effects.dragon_blood.sprites.is_empty(),"Off-area bomb advanced/rendered"):return
	var jungle_path:="user://tests/blood_jungle.json"
	if not check(jungle.quicksave(jungle_path).is_empty() and jungle.quickload(jungle_path).is_empty(),"Blood Jungle save"):return
	var handoff: Dictionary=jungle.area_handoff()
	jungle.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive;await process_frame;freeze(hive)
	if not check(hive.apply_area_handoff(handoff).is_empty() and hive.item_effects.state().dragon_blood[0].remaining==held_fuse,"Blood Hive handoff"):return
	if not check(hive.quicksave("user://tests/blood_hive.json").is_empty(),"Blood Hive save"):return
	hive.queue_free();await process_frame;await process_frame
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene;await process_frame
	scene.introduction_state="complete"
	if is_instance_valid(scene.introduction):scene.introduction.close();await process_frame
	if not check(scene.quickload(path).is_empty() and scene.item_effects.state().dragon_blood[0].remaining==held_fuse,"Return to active Museum fuse"):return
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	population=scene.skeleton_population
	bomb=scene.item_effects.state().dragon_blood[0];point=Vector3(bomb.position[0],bomb.position[1],bomb.position[2])
	sk=population.checkpoint();sk.actors["23"].position=[point.x+24-population.origin().x,point.y-10-population.origin().y,point.z-population.origin().z];population.restore(sk)
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,80,80);collision.shape=box;wall.add_child(collision);scene.add_child(wall);wall.global_position=point+Vector3(12,20,0)
	scene.player.global_position=point+Vector3(250,32,0);await physics_frame;await physics_frame
	health_before=population.state.actors["23"].health
	scene.item_effects.advance(10)
	if not check(scene.item_effects.state().dragon_blood.is_empty() and population.state.actors["23"].health==health_before and scene.health==10,"Wall/range blast protection"):return
	print("PASS Museum two Dragon Blood grants: actual death, engine retirement, two aimed E pickups/partial disk, inventory Use placed bomb, saved fuse/pause, live engine blast damages creature/player once and preserves consumed drop after reload; supplied combat/camera/boundary fixtures")
	quit()
