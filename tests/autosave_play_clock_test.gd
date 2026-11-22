extends "res://tests/game_save_quit_load_test.gd"
## F18 live rendered scheduler. Explicit clock hook, pause/movie/conversation fault probes
## are declared test aids. Real Tab/Journal/W; no earned-route claim or player pose writes.
const Save=preload("res://scripts/lol2/game_save.gd")
const Session=preload("res://scripts/lol2/game_session.gd")
class TalkHold extends Node:
	func input_locked()->bool:return true
var session:Node
var player_files:Dictionary={}
func finish_write()->void:
	for i in 3000:
		await process_frame
		session.advance_play(0.0)
		if not session.save_in_progress():break
	assert(not session.save_in_progress() and session.last_autosave_error.is_empty(),session.last_autosave_error)
func unchanged_slots()->void:
	for path in player_files:
		assert(FileAccess.get_file_as_bytes(path)==player_files[path],"Autosave changed player slot/backup: "+path)
func locate_proof()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-proof="):proof=arg.substr(13)
	assert(not proof.is_empty())
func screenshot(label:String)->void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(proof+"/"+label+".png")==OK)
func run()->void:
	locate_proof()
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1" and "--no-autosave" not in OS.get_cmdline_user_args())
	assert(DisplayServer.get_name()!="headless")
	session=Session.for_tree(self);session.set_process(false)
	scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
	session.advance_play(0.0);await ticks(2);session.advance_play(0.0);await finish_write()
	assert(session.autosave_writes==1 and session.last_autosave_reason=="arrival")
	var first:=FileAccess.get_file_as_bytes(Save.slot_path(0))
	for id in range(1,11):assert(Save.save(scene,id).is_empty())
	assert(Save.save(scene,6).is_empty()) # Also protect an existing player backup.
	for id in range(1,11):
		player_files[Save.slot_path(id)]=FileAccess.get_file_as_bytes(Save.slot_path(id))
		if FileAccess.file_exists(Save.backup_path(id)):player_files[Save.backup_path(id)]=FileAccess.get_file_as_bytes(Save.backup_path(id))
	assert(session.last_slot==6)
	# This owner protocol already blocks save admission, but previously did not stop the clock.
	var hold:=TalkHold.new();scene.add_child(hold)
	assert(scene.starting_magic.world_active() and not scene.can_save().is_empty())
	var before:float=session.play_seconds
	session.advance_play(75.0)
	assert(session.play_seconds==before,"conversation hold must not count as play time")
	hold.free()
	for key in [KEY_TAB,KEY_J]:
		await tap(key)
		assert(scene.interface_hud.cursor_active)
		session.advance_play(601.0)
		assert(session.play_seconds==before and session.autosave_writes==1,"menu time must not count")
		await tap(KEY_ESCAPE)
		assert(not scene.interface_hud.cursor_active)
	paused=true;session.advance_play(601.0);assert(session.play_seconds==before);paused=false
	var movie:=CanvasLayer.new();scene.add_child(movie);scene.video_overlay=movie
	session.advance_play(601.0);assert(session.play_seconds==before);scene.video_overlay=null;movie.free()
	assert(FileAccess.get_file_as_bytes(Save.slot_path(0))==first)
	# Real movement changes the pose that the timer checkpoint must retain.
	var prior:Vector3=scene.player.position
	await aim(scene.player.global_position+Vector3(80,scene.camera.position.y,0))
	var w:=InputEventKey.new();w.keycode=KEY_W;w.physical_keycode=KEY_W;w.pressed=true
	Input.parse_input_event(w);Input.flush_buffered_events();await ticks(12)
	w=InputEventKey.new();w.keycode=KEY_W;w.physical_keycode=KEY_W;w.pressed=false
	Input.parse_input_event(w);Input.flush_buffered_events();await ticks(8)
	assert(scene.player.position.distance_to(prior)>5.0 and scene.resets==0 and scene.player.is_on_floor())
	session.advance_play(599.99)
	assert(not session.save_in_progress() and session.autosave_writes==1,"no early timer write")
	assert(is_equal_approx(session.play_seconds-before,599.99))
	session.advance_play(0.01)
	assert(session.save_in_progress(),"600 seconds of play schedules autosave")
	await finish_write()
	assert(session.autosave_writes==2 and session.last_autosave_reason=="timer")
	assert(FileAccess.get_file_as_bytes(Save.backup_path(0))==first)
	unchanged_slots();assert(session.last_slot==6)
	var saved:=Save.read_document(Save.slot_path(0));assert(saved.error.is_empty())
	var safe_bytes:=FileAccess.get_file_as_bytes(Save.slot_path(0))
	var p:Array=saved.state.area_save.player.position
	var at:=Vector3(p[0],p[1],p[2]);var health:int=saved.state.area_save.inventory.health
	assert(health>0 and at.distance_to(scene.player.position)<0.1)
	await screenshot("timer_pose")
	# Death cannot replace the safe checkpoint; normal loading must recover the captured pose alive.
	scene.starting_magic.set_health(0)
	before=session.play_seconds;session.advance_play(601.0)
	assert(session.play_seconds==before and not session.save_in_progress() and session.autosave_writes==2)
	assert(not Save.autosave(scene,"timer").is_empty())
	assert(FileAccess.get_file_as_bytes(Save.slot_path(0))==safe_bytes)
	assert(Save.load(self,0).is_empty());await scene_changed;scene=current_scene;await settled()
	assert(session.pending_resume.is_empty() and not session.changing_scene)
	assert(scene.starting_magic.health()==health and scene.player.position.distance_to(at)<0.1 and scene.resets==0)
	assert(session.last_slot==6);unchanged_slots()
	await screenshot("loaded_alive")
	var receipt:={"passed":true,"clock_hook":"production advance_play, not600s of wall time","timer_boundary_seconds":600,"excluded":["pause","Tab","Journal","movie","conversation"],"arrival":true,"timer":true,"dead_refused":true,"player_slots_preserved":10,"player_backup6_preserved":true,"last_slot":session.last_slot,"saved_position":p,"loaded_position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"saved_health":health,"loaded_health":scene.starting_magic.health(),"resets":scene.resets}
	var f:=FileAccess.open(proof+"/receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));f.close()
	print("PASS F18 arrival; play-only600s; real Tab/Journal and pause/movie/conversation holds; player slots1..10/backups unchanged; dead refused; autosave loads alive at captured pose; resets=0")
	scene.free();scene=null;current_scene=null
	await process_frame
	quit()
