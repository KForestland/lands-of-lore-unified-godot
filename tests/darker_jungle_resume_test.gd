extends SceneTree
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Darker = preload("res://scripts/lol2/darker_jungle.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run():
	var path := "user://tests/darker_launcher_%d.json" % Time.get_ticks_usec()
	var cfg := path+".cfg"
	var saved := Save.read_save("user://tests/act1_darker_jungle_arrival.json",Darker.FORMAT)
	if not check(saved.error.is_empty() and Save.write_save(path,saved.state,Darker.FORMAT).is_empty(),"Verified arrival checkpoint unavailable"): return
	var config := ConfigFile.new()
	config.set_value("original_game","exe_path","/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE")
	if not check(config.save(cfg)==OK,"Launcher fixture config failed"): return
	var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	gate.settings_path = cfg
	gate.museum_save_path = path+".missing"
	gate.jungle_save_path = path+".missing"
	gate.hive_save_path = path+".missing"
	gate.darker_save_path = path
	root.add_child(gate)
	current_scene = gate
	await process_frame
	await process_frame
	if not check(current_scene==gate,"Darker save failed to prevent automatic cavern start"): return
	gate.path_field.text = ""
	gate._verify_and_start(false,false,false,true)
	if not check(not get_meta("original_game_verified") and not has_meta("lol2_darker_resume"),"Darker resume skipped original-game verification"): return
	gate.path_field.text = "/home/bob/lol2_out/museum_capture_20260913/game/LOLG.EXE"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{damaged")
	file.close()
	gate._verify_and_start(false,false,false,true)
	if not check(current_scene==gate and not has_meta("lol2_darker_resume"),"Damaged darker save left launcher"): return
	if not check(Save.write_save(path,saved.state,Darker.FORMAT).is_empty(),"Could not restore fixture save"): return
	var button: Button
	for child in gate.find_children("*","Button",true,false):
		if child.text=="Resume darker jungle": button=child
	if not check(is_instance_valid(button),"Darker resume button absent"): return
	button.pressed.emit()
	await process_frame
	await process_frame
	await physics_frame
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/lol2/darker_jungle.tscn","Darker launcher loaded wrong scene"): return
	if not check(not has_meta("lol2_darker_resume") and current_scene.quest_state.act_one_departure.phase=="arrived" and current_scene.quest_state.monastery.globals.GV_RUNES_TRANSLATED==1,"Darker launcher lost checkpoint"): return
	if not check(current_scene.player.position.distance_to(Vector3(-4577,32,1168))<.2 and current_scene.carried_collected==saved.state.inventory.collected,"Darker launcher lost pose/inventory"): return
	current_scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(cfg)
	print("PASS: verified launcher darker-jungle resume, corrupt save guard, original-game requirement and earned state")
	quit()
