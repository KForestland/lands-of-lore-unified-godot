extends "res://tests/game_save_quit_load_test.gd"
## Rendered live scene; production clock advanced by its explicit test hook.
## Health/flight/movie/liquid substitutions are isolated admission probes, not play evidence.
const Save=preload("res://scripts/lol2/game_save.gd")
class LiquidProbe extends Node3D:
	func polygon_at(_point:Vector3)->Dictionary:return {"surface":100000.0}
func run()->void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1" and "--no-autosave" not in OS.get_cmdline_user_args())
	var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
	assert(session.AUTOSAVE_SECONDS==600.0 and session.AUTOSAVE_RETRY_SECONDS==5.0)
	scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
	for i in 1800:
		await process_frame
		if session.autosave_writes>0:break
	assert(session.autosave_writes==1 and session.last_autosave_reason=="arrival","arrival after settled physics")
	assert(not paused and scene.player.is_on_floor() and scene.starting_magic.health()>0)
	session.set_process(false) # Own the clock explicitly for exact boundary/admission probes.
	var first:=FileAccess.get_file_as_bytes(Save.slot_path(0))
	var writes:int=session.autosave_writes
	session.advance_play(600.0-float(session._autosave_elapsed)-0.01)
	assert(session.autosave_writes==writes,"no early timer save")
	var elapsed:float=session.play_seconds
	paused=true;session.advance_play(999.0);assert(session.play_seconds==elapsed and session.autosave_writes==writes);paused=false
	scene.flying=true;session.advance_play(999.0);assert(session.autosave_writes==writes);scene.flying=false
	scene.starting_magic.set_health(0);session.advance_play(999.0);assert(session.autosave_writes==writes);scene.starting_magic.set_health(30)
	var movie:=CanvasLayer.new();scene.add_child(movie);scene.video_overlay=movie
	session.advance_play(999.0);assert(session.autosave_writes==writes);scene.video_overlay=null;movie.free()
	# Cross the ten-minute boundary while wading: admission refuses and starts the five-second retry.
	var real_liquid:Node=scene.liquid_drowning
	var liquid:=LiquidProbe.new();scene.add_child(liquid);scene.liquid_drowning=liquid
	session.advance_play(0.02);assert(session.autosave_writes==writes and session._retry_remaining==5.0)
	assert(FileAccess.get_file_as_bytes(Save.slot_path(0))==first,"blocked autosave never replaces good bytes")
	scene.liquid_drowning=real_liquid;liquid.free()
	session.advance_play(4.99);assert(session.autosave_writes==writes,"retry does not run early")
	session.advance_play(0.02)
	assert(session.save_in_progress() and session.autosave_writes==writes,"accepted job completes asynchronously")
	assert(not Save.save(scene,4).is_empty(),"manual save waits for the single writer")
	var live_id:=scene.get_instance_id()
	assert(current_scene.get_instance_id()==live_id,"background writer preserves the live host; queued real F9 covered by manual_save_queue_input_test")
	for i in 300:
		await process_frame
		session._finish_autosave()
		if not session.save_in_progress():break
	assert(session.autosave_writes==writes+1 and session.last_autosave_reason=="timer")
	assert(FileAccess.get_file_as_bytes(Save.backup_path(0))==first,"autosave preserves verified previous bytes")
	var saved:=Save.read_document(Save.slot_path(0));assert(saved.error.is_empty() and saved.state.area_save.inventory.health>0)
	print("AUTOSAVE first/timer bytes=",FileAccess.get_file_as_bytes(Save.slot_path(0)).size()," wall_us=",session.last_autosave_micros," capture_us=",session.last_autosave_capture_micros)
	# A real scene change schedules a second arrival after the handoff and physics settle.
	session.set_process(true)
	await transfer(9,0,"res://scenes/lol2/dragon_level.tscn")
	for i in 1800:
		await process_frame
		if session.autosave_writes>writes+1:break
	assert(session.autosave_writes==writes+2 and session.last_autosave_reason=="arrival")
	saved=Save.read_document(Save.slot_path(0));assert(saved.error.is_empty() and saved.state.area=="L9_DR")
	assert(saved.state.native_bank.has("L10_DC") and saved.state.native_bank.has("L9_DR"))
	print("AUTOSAVE arrival bank_bytes=",FileAccess.get_file_as_bytes(Save.slot_path(0)).size()," capture_us=",session.last_autosave_capture_micros," wall_us=",session.last_autosave_micros)
	assert(scene.resets==0 and not paused)
	print("PASS arrival and 600-second production clock; pause/dead/flight/movie/liquid admission; five-second retry; backup; handoff arrival; resets=0")
	quit()
