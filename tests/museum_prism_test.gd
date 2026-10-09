extends "res://tests/player_magic_handoff_test.gd"
const Prism=preload("res://scripts/lol2/museum_prism.gd")
var scene
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func press_e() -> void:
	var e:=InputEventKey.new();e.keycode=KEY_E;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_E;e.pressed=false;Input.parse_input_event(e);await process_frame
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	await process_frame;scene.introduction_state="complete"
	if is_instance_valid(scene.introduction):scene.introduction.close();await process_frame
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;scene.flying=false
	var prism=scene.prism
	if not check(is_instance_valid(prism) and prism.display.visible and not prism.taken,"Initial Prism"):return
	var found:=false
	for angle in range(0,360,15):
		var point: Vector3=prism.display.global_position
		scene.player.global_position=point+Vector3(sin(deg_to_rad(angle))*55,4,cos(deg_to_rad(angle))*55)
		scene.camera.look_at(point);await physics_frame
		if prism.reachable():found=true;break
	if not check(found,"Reachable Prism vantage"):return
	scene.hand_item="busy"
	await press_e()
	if not check(not prism.taken,"Busy hand admitted"):return
	scene.hand_item="";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await press_e()
	if not check(not prism.taken,"Inactive cursor admitted"):return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests")
	root.get_texture().get_image().save_png("user://tests/prism_visible.png")
	await press_e()
	if not check(prism.taken and not prism.display.visible and scene.carried_collected.count(Prism.ITEM)==1,"Actual E pickup"):return
	await press_e()
	if not check(scene.carried_collected.count(Prism.ITEM)==1,"Duplicate pickup"):return
	scene.open_inventory();await process_frame
	var inventory=scene.inventory;var index:=-1
	for i in inventory.item_list.item_count:
		if str(inventory.item_list.get_item_metadata(i))==Prism.ITEM:index=i
	if not check(index>=0,"Prism inventory entry"):return
	inventory.select_item(index);inventory.toggle_equipment();await process_frame
	if not check(scene.equipped_item==Prism.ITEM,"Prism equipment"):return
	inventory.queue_free();await process_frame
	var path:="user://tests/prism_museum.json"
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Prism disk roundtrip"):return
	if not check(prism.taken and not prism.display.visible and scene.equipped_item==Prism.ITEM,"Prism receipt/equipment restore"):return
	if not check(not Prism.validate(false,scene.carried_collected).is_empty() and not Prism.validate(true,[]).is_empty(),"Forged Prism receipt accepted"):return
	var transport: Dictionary=scene.inventory_state()
	scene.queue_free();await process_frame;await process_frame
	set_meta("lol2_jungle_handoff",transport)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(jungle);current_scene=jungle;await process_frame;freeze(jungle)
	if not check(jungle.equipped_item==Prism.ITEM and jungle.quicksave("user://tests/prism_jungle.json").is_empty(),"Prism Jungle transport/save"):return
	var handoff: Dictionary=jungle.area_handoff();jungle.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive;await process_frame;freeze(hive)
	if not check(hive.apply_area_handoff(handoff).is_empty() and hive.carried_inventory.equipped_item==Prism.ITEM and hive.quicksave("user://tests/prism_hive.json").is_empty(),"Prism Hive transport/save"):return
	print("PASS museum_prism: original display, empty-hand actual E, pause/busy refusal, one-time grant, real inventory Equip, disk receipt validation, Jungle/Hive transport. Vantage supplied; shared modern melee, no native blindness/material transition claim.")
	quit()
