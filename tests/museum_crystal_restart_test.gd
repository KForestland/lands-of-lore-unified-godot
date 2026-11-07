extends "res://tests/museum_prism_test.gd"
const Crystals = preload("res://scripts/lol2/museum_crystal_state.gd")
func run() -> void:
	var receipt=JSON.parse_string(FileAccess.get_file_as_string("user://tests/crystal_receipt.json"))
	if not check(receipt is Dictionary and receipt.size()==3,"Run crystal live test first"):return
	for label in ["before","earned","charged"]:
		var path:String="user://tests/crystal_"+str(label)+".json"
		if not check(receipt.has(path) and FileAccess.get_sha256(path)==receipt[path].sha256,"Crystal save changed"):return
		scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
		scene.introduction_state="complete";root.add_child(scene);current_scene=scene
		await process_frame;freeze(scene)
		if not check(scene.quickload(path).is_empty(),"Fresh process crystal load: "+label):return
		freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var owner=scene.crystal_pickups
		if not check(owner.state.hits==(0 if label=="before" else 3),"Restart hit state"):return
		for i in 3:
			if not check(owner.state.taken[i]==(label!="before") and scene.carried_collected.count(Crystals.IDS[i])==(0 if label=="before" else 1),"Restart pickup receipt"):return
			if label!="before" and not check(scene.item_effects.crystal_charges(Crystals.IDS[i])==(1 if label=="charged" and i==0 else 0),"Restart charges"):return
		if label!="charged":
			await physics_frame;await RenderingServer.frame_post_draw
			scene.queue_free();await process_frame;await physics_frame;await RenderingServer.frame_post_draw
	await physics_frame;await RenderingServer.frame_post_draw
	# Actual inventory Use action on the earned/recharged Museum item.
	if not check(scene.open_inventory(),"Open crystal inventory"):return
	await process_frame
	var inv=scene.inventory;var index:=-1
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i))==Crystals.IDS[0]:index=i
	if not check(index>=0,"Earned crystal absent in inventory"):return
	inv.select_item(index)
	if not check(inv.use_button.visible and inv.use_button.text=="Use crystal","Museum crystal use action"):return
	await process_frame;await process_frame
	var panel=inv.find_child("ClassicInventory",true,false)
	var rect:Rect2=panel.get_global_rect()
	var screen:Rect2=root.get_visible_rect()
	if not check(screen.encloses(rect),"Selected-crystal inventory extends outside viewport: "+str(rect)):return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/crystal_inventory.png")
	print("CRYSTAL_USE_START")
	inv.use_button.pressed.emit();await process_frame
	print("CRYSTAL_USE_END")
	if not check(scene.item_effects.crystal_burnt(Crystals.IDS[0]) and not scene.item_effects.use(Crystals.IDS[0]),"Recharged crystal did not fire once/burn out"):return
	print("CRYSTAL_CLOSE_START")
	if is_instance_valid(scene.inventory):scene.inventory.queue_free()
	await process_frame;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(scene.quicksave("user://tests/crystal_burnt_again.json").is_empty(),"Used crystal Museum save"):return
	for i in 4:await physics_frame
	await RenderingServer.frame_post_draw
	print("CRYSTAL_TRANSITION_START")
	var packet:Dictionary=scene.inventory_state()
	scene.queue_free();await process_frame;await process_frame
	set_meta("lol2_jungle_handoff",packet)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(jungle);current_scene=jungle
	await process_frame;freeze(jungle)
	for id in Crystals.IDS:
		if not check(jungle.carried_collected.count(id)==1 and jungle.item_effects.crystal_burnt(id),"Museum->Jungle crystal/charges"):return
	if not check(jungle.quicksave("user://tests/crystal_jungle.json").is_empty(),"Jungle crystal save"):return
	var onward:Dictionary=jungle.area_handoff();jungle.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate();root.add_child(hive);current_scene=hive
	await process_frame;freeze(hive)
	if not check(hive.apply_area_handoff(onward).is_empty(),"Hive crystal handoff"):return
	for id in Crystals.IDS:
		if not check(hive.carried_inventory.collected.count(id)==1 and hive.item_effects.crystal_burnt(id),"Jungle->Hive crystal/charges"):return
	if not check(hive.quicksave("user://tests/crystal_hive.json").is_empty(),"Hive crystal save"):return
	print("PASS hash-linked fresh-process crystal before/earned/charged; inventory fire/burnout; Museum->Jungle->Hive identities/charges/save. Vantages and transitions supplied.")
	quit()
