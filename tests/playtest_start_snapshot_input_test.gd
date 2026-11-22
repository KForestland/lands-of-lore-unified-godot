extends "res://tests/playtest_bundle_test.gd"
## Rendered real input at ordinary clock. Fresh Cave, no packet/pose/health,
## story or clock fixtures. Shift is held across the first actual snapshot.
func run()->void:
 if DisplayServer.get_name()=="headless" or Engine.time_scale!=1 or Engine.physics_ticks_per_second!=60:return fail("Rendered ordinary1/60 required")
 var feedback:Node=root.get_node("PlaytestFeedback")
 var recorder:Node=feedback.recorder
 if recorder.recording or recorder.is_processing() or not recorder.start_ring.rows.is_empty():return fail("Ordinary mode must not sample")
 var Save=load("res://scripts/lol2/game_save.gd")
 var slots:Dictionary={}
 for id in range(1,11):slots[id]=FileAccess.get_sha256(Save.slot_path(id)) if FileAccess.file_exists(Save.slot_path(id)) else ""
 feedback.output_root="user://tests/playtest_start_snapshot"
 recorder.set_recording(true)
 await process_frame
 key(KEY_SHIFT,true)
 await process_frame
 cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
 var deadline:=Time.get_ticks_msec()+60000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if cave.walkthrough_ready and cave.can_save().is_empty():break
 if not cave.walkthrough_ready or not cave.can_save().is_empty():return fail("Fresh Cave not saveable")
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 deadline=Time.get_ticks_msec()+30000
 while recorder.start_ring.rows.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if recorder.start_ring.rows.is_empty():return fail("No first eligible snapshot: "+recorder.snapshot_note)
 var first:Dictionary=recorder.start_ring.rows[0].duplicate(true)
 print("FIRST_SNAPSHOT_INPUT ",first.held," expected=",OS.get_keycode_string(KEY_SHIFT))
 if not OS.get_keycode_string(KEY_SHIFT) in first.held.keys:return fail("Held Shift missing at capture")
 var initial_t:float=first.t
 deadline=Time.get_ticks_msec()+25000
 while recorder.start_ring.rows.size()<2 and Time.get_ticks_msec()<deadline:await process_frame
 if recorder.start_ring.rows.size()<2:return fail("Actual15-second cadence did not sample twice")
 if float(recorder.start_ring.rows[1].t)-initial_t<15.0:return fail("Cadence uses accelerated frame delta instead of actual15seconds")
 # This second snapshot will be the preceding start after ring wrap. Shift
 # spans its boundary; the subsequent W press must survive as prefix input.
 first=recorder.start_ring.rows[1].duplicate(true)
 key(KEY_SHIFT,false)
 key(KEY_W,true)
 var w_t:float=recorder.now()
 for i in range(15):await physics_frame
 key(KEY_W,false)
 var look:=InputEventMouseMotion.new();look.relative=Vector2(15,0);Input.parse_input_event(look)
 deadline=Time.get_ticks_msec()+145000
 while recorder.start_ring.count<10 and Time.get_ticks_msec()<deadline:await process_frame
 if recorder.start_ring.count<10:return fail("Nine-entry ring never wrapped on actual15-second cadence")
 var finish:float=initial_t+138.0
 while recorder.now()<finish:await process_frame
 if recorder.start_ring.rows.size()!=9:return fail("Ring is not bounded at nine documents")
 if recorder.now()-w_t<=120.0:return fail("W did not become a genuine older-than120s prefix input")
 if JSON.stringify(JSON.parse_string(first.json),"",true,true)!=JSON.stringify(JSON.parse_string(recorder.start_ring.rows[0].json),"",true,true):return fail("Live walk altered old document")
 key(KEY_F10,true);await process_frame;key(KEY_F10,false);await process_frame
 if not feedback.active:return fail("Real F10 did not open feedback")
 feedback.note.text="start snapshot real-input test"
 key(KEY_ENTER,true,true);await process_frame;key(KEY_ENTER,false,true);await process_frame
 var path:String=feedback.last_saved
 var bundle:Variant=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("bundle.json")))
 if not bundle is Dictionary or not bundle.files.has("start_save.json") or not bundle.files.has("replay_inputs.json"):return fail("No start document/replay stream: "+str(bundle))
 if not str(bundle.get("data_handling","")).contains("local only") or not "start_save.json" in bundle.get("local_only_files",[]):return fail("Bundle lacks owner-derived local-only save label")
 if bundle.start_snapshot.captured_json_sha256!=str(first.json).sha256_text():return fail("Captured-string SHA differs from the exact frozen encoded document")
 if bundle.start_snapshot.written_file_sha256!=FileAccess.get_sha256(path.path_join("start_save.json")):return fail("Written-file SHA is not separately exact")
 for name in bundle.files:
  if FileAccess.get_sha256(path.path_join(name))!=bundle.files[name]:return fail("Manifest hash mismatch "+name)
 if bundle.start_snapshot.t!=first.t or bundle.start_snapshot.coverage!="full":return fail("Full window did not select the preceding ring snapshot")
 var replay:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("replay_inputs.json")))
 if replay.start_t!=first.t or not "Shift" in replay.initial_input_state.keys:return fail("Replay lacks start boundary/held key")
 var walk:=false;var turned:=false
 for event in replay.events:
  if float(event.t)<=float(replay.start_t):return fail("Pre-capture input repeated")
  if event.kind=="key" and event.key=="W" and event.pressed:walk=true
  if event.kind=="look":turned=true
 if not walk or not turned:return fail("Real W/mouse absent from replay stream")
 var ordinary:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("inputs.json")))
 for event in ordinary.events:
  if float(event.t)<float(replay.window_start_t):return fail("Ordinary120-second window changed")
  if event.kind=="key" and event.key=="W" and event.pressed:return fail("Prefix W was not older than the ordinary window")
 if float(replay.start_t)>float(replay.window_start_t):return fail("Future/end snapshot substituted for preceding start")
 for id in slots:
  var after:String=FileAccess.get_sha256(Save.slot_path(id)) if FileAccess.file_exists(Save.slot_path(id)) else ""
  if after!=slots[id]:return fail("Recorder wrote player slot "+str(id))
 var start:Dictionary=Save.read_document(path.path_join("start_save.json"))
 if not start.error.is_empty():return fail("Start document invalid: "+start.error)
 if JSON.stringify(start.state,"",true,true)!=JSON.stringify(JSON.parse_string(first.json),"",true,true):return fail("Written start is not captured document")
 var costs:Dictionary=bundle.snapshot_costs
 print("SNAPSHOT_COST ",JSON.stringify(costs)," start_t=",first.t," next_t=",recorder.now())
 var costfile:=FileAccess.open("res://tmp/playtest_start_snapshot_costs.json",FileAccess.WRITE);costfile.store_string(JSON.stringify(costs,"\t")+"\n");costfile.close()
 var old:Node=cave
 var error:String=Save.load_file(self,path.path_join("start_save.json"))
 if not error.is_empty():return fail("Start load refused: "+error)
 deadline=Time.get_ticks_msec()+60000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if current_scene!=old and is_instance_valid(current_scene) and current_scene.get("walkthrough_ready")==true:break
 if current_scene==old or not is_instance_valid(current_scene) or current_scene.get("walkthrough_ready")!=true:return fail("Start document did not load fresh Cave")
 cave=current_scene
 for i in range(10):await physics_frame
 var pos:Array=start.state.area_save.player.position
 if cave.player.position.distance_to(Vector3(pos[0],pos[1],pos[2]))>6:return fail("Start load lost captured stand")
 print("PASS playtest start snapshot: ordinary mode off, actual15seconds + wrapped9 snapshots, older-than120s real W prefix, real Shift/mouse/F10, immutable whole document + held replay inputs, exact SHA, no player slot writes, fresh real load at captured stand")
 quit()
