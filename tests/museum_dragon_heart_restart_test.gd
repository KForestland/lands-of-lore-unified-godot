extends "res://tests/museum_prism_test.gd"
const Heart=preload("res://scripts/lol2/museum_dragon_heart_state.gd")
func run() -> void:
	var receipt=JSON.parse_string(FileAccess.get_file_as_string("user://tests/dragon_heart_receipt.json"))
	if not check(receipt is Dictionary and receipt.size()==3,"Run dragon-heart live test before restart"):return
	for label in ["before","during","after"]:
		var row:Dictionary=receipt[label]
		if not check(FileAccess.get_sha256(row.path)==row.sha256,"Dragon-heart saved bytes changed"):return
		var disk:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(row.path))
		scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
		scene.introduction_state="complete";root.add_child(scene);current_scene=scene
		await process_frame;freeze(scene)
		if not check(scene.quickload(row.path).is_empty(),"Fresh-process heart load: "+label):return
		freeze(scene)
		if not check(scene.dragon_heart.checkpoint()==disk.checkpoint.museum_dragon_heart,"Movie phase/frame changed on restart: "+label):return
		if not check(scene.player_magic_checkpoint==Magic.restore(disk.checkpoint.magic).checkpoint,"Restart changed magic reward: "+label):return
		if not check(scene.carried_collected.count(Heart.ITEM)==(1 if label=="after" else 0),"Restart duplicated/lost Dragon Gem: "+label):return
		if label=="during":
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;scene.flying=false
			var owner=scene.dragon_heart
			owner.set_physics_process(true)
			for i in 100:await physics_frame
			if not check(owner.gem.visible and not owner.state.taken and owner.state.phase=="revealed","Restarted movie did not reveal gem"):return
			if not check(scene.player_magic_checkpoint.player.experience==50,"Restarted movie duplicated original50XP"):return
		scene.queue_free();await process_frame;await process_frame
	print("PASS hash-linked fresh-process dragon-heart before/during/after loads, resumed movie and preserved one-shot magic/gem")
	quit()
