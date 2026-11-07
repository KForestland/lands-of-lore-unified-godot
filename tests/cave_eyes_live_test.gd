extends SceneTree
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return not get_tree().paused
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	if not check(scene.walkthrough_ready,"Cave ready"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	var eyes=scene.eyes;eyes.set_physics_process(false)
	if not check(eyes!=null and eyes.mesh.visible and eyes.position==Vector3(-1993,44,-5677)+scene.native_translation,"Source eyes placed"):return
	scene.starting_magic.set_process(false)
	var magic:=TestMagic.new();scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
	scene.player.global_position=eyes.global_position+Vector3(0,0,40)
	scene.camera.look_at(eyes.global_position)
	await physics_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
		root.get_texture().get_image().save_png("user://tests/cave_eyes_render.png")
	if not check(eyes.target() and eyes.use() and not eyes.use(),"Production aimed use, one shot"):return
	eyes._physics_process(2.0)
	var expected: Dictionary=eyes.checkpoint()
	if not check(expected.phase=="moving" and expected.sound_sample>0,"Moving path and original audio clock"):return
	var path:="user://tests/cave_eyes_world.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	if not check(scene._quicksave(path).is_empty(),"Eyes scene disk save"):return
	paused=true;eyes._physics_process(20.0)
	if not check(eyes.checkpoint()==expected,"Eyes pause"):return
	paused=false;eyes._physics_process(100.0)
	if not check(eyes.state.phase=="removed" and not eyes.mesh.visible,"Path end timer removes eyes"):return
	if not check(scene._quickload(path).is_empty() and eyes.checkpoint()==expected,"Scene partial path/audio rollback"):return
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));packet.eyes.index=99
	var file:=FileAccess.open(path+".invalid",FileAccess.WRITE);file.store_string(JSON.stringify(packet));file.close()
	if not check(not scene._quickload(path+".invalid").is_empty() and eyes.checkpoint()==expected,"Malformed scene rejected atomically"):return
	packet.erase("eyes");file=FileAccess.open(path+".legacy",FileAccess.WRITE);file.store_string(JSON.stringify(packet));file.close()
	if not check(scene._quickload(path+".legacy").is_empty() and eyes.state.phase=="idle","Legacy initial eyes"):return
	print("PASS eyes24 real scene art/aimed use, original sound clock, path/removal, pause, full disk rollback, malformed atomicity and legacy")
	scene.queue_free();await process_frame;await process_frame;quit()
