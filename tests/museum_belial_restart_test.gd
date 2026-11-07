extends "res://tests/museum_prism_test.gd"
func run() -> void:
	var receipt=JSON.parse_string(FileAccess.get_file_as_string("user://tests/belial_receipt.json"))
	if not check(receipt is Dictionary and receipt.size()==3,"Run Belial live test before restart"):return
	for label in ["before","during","after"]:
		var row:Dictionary=receipt[label]
		if not check(FileAccess.get_sha256(row.path)==row.sha256,"Belial saved bytes changed"):return
		var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(row.path))
		scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
		scene.introduction_state="complete";root.add_child(scene);current_scene=scene
		await process_frame;freeze(scene)
		if not check(scene.quickload(row.path).is_empty(),"Fresh-process Belial load: "+label):return
		freeze(scene)
		var owner=scene.belial
		var actual:Dictionary=owner.checkpoint()
		var expected:Dictionary=disk.checkpoint.museum_belial
		if not check(actual.version==expected.version and actual.animation==expected.animation and actual.sounds==expected.sounds,"Belial animation/sound checkpoint changed on restart: "+label):return
		if not check(owner.display.visible==(label!="after"),"Belial visibility changed on restart"):return
		if label=="during":
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;scene.flying=false;owner.set_physics_process(true)
			for i in 240:await physics_frame
			if not check(owner.state.phase=="gone" and not owner.display.visible and owner.clocks[1]>=0,"Restarted Belial did not finish"):return
		scene.queue_free();await process_frame;await process_frame
	print("PASS hash-linked fresh-process Belial idle/active/completed loads and resumed animation/sound clocks")
	quit()
