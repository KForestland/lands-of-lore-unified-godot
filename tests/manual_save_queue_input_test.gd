extends "res://tests/generic_prop_input_test.gd"
## Ordinary clock, automatic entry writer; supplied grounded crypt stand,
## root/NPC holds inherited from the component helper. No earned-route claim.
const SaveAPI=preload("res://scripts/lol2/game_save.gd")
func press_f5():
 var event:=InputEventKey.new();event.keycode=KEY_F5;event.physical_keycode=KEY_F5;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events()
 event=InputEventKey.new();event.keycode=KEY_F5;event.physical_keycode=KEY_F5;event.pressed=false
 Input.parse_input_event(event);Input.flush_buffered_events()
func wait_saved(previous:String)->bool:
 var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
 for tick in 1800:
  await process_frame
  if not session.save_in_progress() and FileAccess.file_exists(SaveAPI.slot_path(1)) and FileAccess.get_sha256(SaveAPI.slot_path(1))!=previous:break
 var read:Dictionary=SaveAPI.read_document(SaveAPI.slot_path(1))
 return check(read.error.is_empty() and FileAccess.get_sha256(SaveAPI.slot_path(1))!=previous,"Actual F5 writes a fresh player slot after the automatic writer")
func run():
 if not check(Engine.time_scale==1.0 and DisplayServer.get_name()!="headless","Rendered ordinary clock"):return
 folder="user://tests/manual_save_queue";DirAccess.make_dir_recursive_absolute(folder)
 var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
 session.set_process(false) # Admit the automatic arrival only after the supplied packet is applied.
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 if not await pose(Vector3(1041.1764,32.0475,-1359.0178),Vector3(1029,40,-1296)):return
 session.set_process(true)
 for tick in 1800:
  await process_frame
  if session.save_in_progress():break
 if not check(session.save_in_progress(),"Actual automatic arrival is writing"):return
 # Press in this same frame, before the session can reap the writer.
 press_f5()
 if not check(scene.interface_hud.hint.text.begins_with("Saving"),"Busy F5 is queued without a false Saved or refusal"):return
 if not await wait_saved(""):return
 var first:String=FileAccess.get_sha256(SaveAPI.slot_path(1))
 if not check(scene.interface_hud.hint.text.begins_with("Saved"),"Saved appears only after the slot write"):return
 await aim(Vector3(1029,40,-1296))
 await key(KEY_E)
 for tick in 60:await physics_frame
 if not check(int(state(86)[Rules.POSITION])>0 and int(state(86)[Rules.PHASE]) in [1,2],"Actual E has moved crypt86 before the second F5"):return
 # The ordinary production writer, deliberately overlapped with the input in
 # the same frame; its detached capture and real file write are unmodified.
 if not check(session.start_autosave(scene,"timer").is_empty(),"Actual autosave writer starts after object use"):return
 press_f5();press_f5() # Coalesce, never allocate two manual writes.
 if not check(scene.interface_hud.hint.text.begins_with("Saving"),"Repeated F5 keeps one pending request"):return
 if not await wait_saved(first):return
 var saved:Dictionary=SaveAPI.read_document(SaveAPI.slot_path(1)).state
 if not check(int(saved.area_save.quests.generic_objects.areas.L10_DC.movables["86"][Rules.POSITION])>0,"Queued F5 contains the used object's state"):return
 if not check(scene.resets==0 and Engine.time_scale==1.0,"No recovery or clock acceleration"):return
 await shot("saved_after_use")
 if not check(session.start_autosave(scene,"timer").is_empty(),"Writer overlaps real F9"):return
 var old_id:int=scene.get_instance_id()
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_F9;event.physical_keycode=KEY_F9;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events()
 if not check(session.manual_load_pending() and current_scene.get_instance_id()==old_id and scene.interface_hud.hint.text=="Loading…","Busy F9 waits without claiming load completion"):return
 for tick in 1800:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and current_scene.get("ready_for_review")==true and session.pending_resume.is_empty():break
 scene=current_scene
 if not check(scene.get_instance_id()!=old_id and scene.starting_magic.health()>0 and int(state(86)[Rules.POSITION])>0,"Queued real F9 restores the written slot alive"):return
 # Separate concurrency/error vector: failed autosave must still release the
 # pending manual save. Only the worker error is supplied, not the slot bytes.
 for tick in 1800:
  await process_frame
  if not session.save_in_progress():break
 var observed_errors:Array=[]
 session.manual_save_finished.connect(func(_slot:int,_error:String):observed_errors.append(session.last_autosave_error),CONNECT_ONE_SHOT)
 session._save_thread=Thread.new()
 if not check(session._save_thread.start(func()->String:return "Injected autosave failure")==OK,"Error-vector worker starts"):return
 var previous:String=FileAccess.get_sha256(SaveAPI.slot_path(1))
 press_f5()
 if not await wait_saved(previous):return
 if not check(observed_errors==["Injected autosave failure"] and not session.manual_save_pending(),"Failed autosave releases and writes the pending manual request"):return
 # New slot: F9 in the same frame as queued F5 must see the pending snapshot,
 # even when no on-disk slot exists yet. This is not a player-progress aid.
 session.last_slot=2
 if not check(not FileAccess.file_exists(SaveAPI.slot_path(2)),"Fresh private slot2"):return
 if not check(session.start_autosave(scene,"timer").is_empty(),"Production writer overlaps immediate F5/F9"):return
 old_id=scene.get_instance_id();press_f5()
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_F9;event.physical_keycode=KEY_F9;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events()
 if not check(session.manual_save_pending() and session.manual_load_pending(),"Immediate F5/F9 holds one snapshot and one load"):return
 for tick in 1800:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and current_scene.get("ready_for_review")==true and session.pending_resume.is_empty():break
 scene=current_scene
 if not check(scene.get_instance_id()!=old_id and SaveAPI.read_document(SaveAPI.slot_path(2)).error.is_empty() and scene.starting_magic.health()>0,"Immediate queued F5/F9 writes then loads fresh slot2 alive"):return
 # Non-busy F9 detaches the outgoing HUD synchronously. Its status path
 # must use the session captured before that detach, never get_tree() after.
 session.set_process(false)
 for tick in 1800:
  session._finish_autosave()
  if not session.save_in_progress():break
  await process_frame
 old_id=scene.get_instance_id()
 await key(KEY_F9)
 for tick in 1800:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id and current_scene.get("ready_for_review")==true and session.pending_resume.is_empty():break
 scene=current_scene
 if not check(scene.get_instance_id()!=old_id and scene.starting_magic.health()>0,"Non-busy real F9 also replaces the host alive"):return
 session.set_process(true)
 print("PASS ordinary time_scale1 real F5 during entry/post-use autosave, queued F9 and immediate F5/F9 fresh slot, truthful Saved, one pending save, failed-worker release; crypt86 retained")
 quit()
