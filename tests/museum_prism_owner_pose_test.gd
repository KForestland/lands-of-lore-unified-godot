extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false
	scene.player.position=Vector3(2322.74267578125,-12.9582710266113,-3394.1005859375)
	scene.player.rotation.y=-0.099610298871994;scene.camera.rotation.x=-0.505040764808655;scene.camera.fov=75
	var owner=scene.prism
	scene.interface_hud.set_cursor(true)
	var point:Vector2=scene.camera.unproject_position(owner.display.global_position)
	scene.hand_item=scene.SWORD_ITEM_ID
	await click_at(point)
	if not check(not owner.taken,"Busy hand cursor pickup"):return
	scene.hand_item=""
	await click_at(point+Vector2(100,0))
	if not check(not owner.taken,"Off-sprite click picked Prism"):return
	scene.interface_hud.sheet.show()
	await click_at(point)
	if not check(not owner.taken,"Open interface sheet picked Prism"):return
	scene.interface_hud.sheet.hide()
	await click_at(point)
	if not check(owner.taken and scene.carried_collected.count(owner.ITEM)==1 and not owner.panorama.visible,"Exact owner-view cursor pickup and panorama change"):return
	await click_at(point)
	if not check(scene.carried_collected.count(owner.ITEM)==1,"Cursor duplicate Prism"):return
	if not check(scene.interface_hud.cursor_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pickup changed interface mode"):return
	print("PASS exact owner-pose cursor Prism pickup; busy/off-sprite/sheet refusal;panorama/no duplicate;interface preserved")
	await finish(scene);quit()
func click_at(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;Input.parse_input_event(event);await process_frame
