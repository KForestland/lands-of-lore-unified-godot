extends "res://tests/museum_prism_test.gd"
const Ivory=preload("res://scripts/lol2/museum_ivory_state.gd")
func run() -> void:
	var receipt = JSON.parse_string(FileAccess.get_file_as_string("user://tests/ivory_receipt.json"))
	if not check(receipt is Dictionary and receipt.size()==5,"Run ivory live test before restart"):return
	for entry in [["broken","museum_walkthrough"],["complete","museum_walkthrough"],["jungle","jungle_walkthrough"],["hive","hive_review"],["darker","darker_jungle"]]:
		var saved: Dictionary=receipt[entry[0]]
		if not check(FileAccess.get_sha256(saved.path)==saved.sha256,"Ivory disk receipt changed"):return
		scene=load("res://scenes/lol2/"+entry[1]+".tscn").instantiate();root.add_child(scene);current_scene=scene;await process_frame
		if entry[1]=="museum_walkthrough":
			scene.introduction_state="complete"
			if is_instance_valid(scene.introduction):scene.introduction.close();await process_frame
		freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if not check(scene.quickload(saved.path).is_empty(),"Ivory new-process reload: "+entry[0]):return
		freeze(scene)
		var ids: Array=scene.carried_inventory.collected if entry[0]=="hive" else scene.carried_collected
		if entry[0]=="broken":
			if not check(scene.ivory.state.stages==[1,0] and scene.ivory.chips[0].visible and not scene.ivory.urns[0].visible and not Ivory.IDS[0] in ids,"Uncollected item lost on restart"):return
		else:
			if not check(Ivory.IDS.all(func(id):return ids.count(id)==1),"New-process duplicate/missing chip: "+entry[0]):return
			if entry[0]=="complete" and not check(scene.ivory.state.stages==[2,2] and not scene.ivory.chips[0].visible and not scene.ivory.chips[1].visible,"Completed receipt presentation"):return
		scene.queue_free();await process_frame;await process_frame
	print("PASS museum_ivory_restart: hash-linked new-process loads for uncollected/completed Museum, Jungle, Hive and darker arrival; separate chips and world receipts preserved")
	quit()
