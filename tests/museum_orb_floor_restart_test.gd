extends "res://tests/museum_prism_test.gd"
func run() -> void:
	var receipt=JSON.parse_string(FileAccess.get_file_as_string("user://tests/orb_floor_receipt.json"))
	if not check(receipt is Dictionary and FileAccess.get_sha256(receipt.path)==receipt.sha256,"Run orb live test before restart; saved bytes must match"):return
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene)
	if not check(scene.quickload(receipt.path).is_empty(),"Fresh process mid-motion load"):return
	freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.orb_switch
	if not check(owner.floor_state.height==-14.0 and owner.floor_state.timer==540.0 and owner.floor_state.local20,"Restart changed floor state"):return
	owner.set_process(true)
	for i in 720:await process_frame
	if not check(owner.floor_state.height==-50.0 and not owner.floor_state.local20,"Restarted floor failed to finish rise/timer/descent"):return
	print("PASS hash-linked fresh-process floor restart and real-frame rise/reset/descent")
	quit()
