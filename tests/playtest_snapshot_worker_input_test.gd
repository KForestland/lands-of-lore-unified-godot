extends "res://tests/playtest_bundle_test.gd"
## Diagnostic performance and failure contract; fresh rendered maps, no earned
## route claim. Invalid document/focus notifications are explicit fixtures.
class BadHost extends Node3D:
 var adapter_exit_seeds:=false
 var starting_magic:Node
 var snapshots:=0
 func area_snapshot()->Dictionary:snapshots+=1;return {}
 func can_save()->String:return ""
var recorder:Node
var metrics:Dictionary={}
func samples(path:String,label:String)->bool:
 recorder.set_recording(false);recorder.set_recording(true)
 cave=load(path).instantiate();root.add_child(cave);current_scene=cave
 var deadline:=Time.get_ticks_msec()+100000
 while recorder.start_ring.count<3 and Time.get_ticks_msec()<deadline:await process_frame
 if recorder.start_ring.count<3:fail("No three genuine timestamped snapshots on "+label+": "+recorder.snapshot_note);return false
 metrics[label]=recorder.start_ring.costs()
 metrics[label]["area_intervals"]=recorder.snapshot_intervals.duplicate()
 if metrics[label].capture_main_max_us>5000 and label=="L10" and not recorder.snapshot_intervals.has("L10_DC"):fail("Repeated over-budget captures did not select the disclosed slow interval");return false
 if recorder.snapshot_intervals.has("L10_DC") and label=="L10":
  var rows:Array=recorder.start_ring.rows
  if float(rows[-1].t)-float(rows[-2].t)<60.0:fail("Slow-area capture did not actually wait60seconds");return false
 print("SNAPSHOT_WORKER_COST ",label," ",JSON.stringify(metrics[label]))
 var Save=load("res://scripts/lol2/game_save.gd")
 for row in recorder.start_ring.rows:
  if not Save.validate(JSON.parse_string(row.json)).is_empty():fail("Worker admitted an invalid document");return false
  if row.captured_json_sha256!=str(row.json).sha256_text():fail("Captured-string SHA is not exact");return false
 cave.queue_free();await process_frame;await process_frame
 return true
func run()->void:
 if DisplayServer.get_name()=="headless" or Engine.time_scale!=1 or Engine.physics_ticks_per_second!=60:return fail("Rendered ordinary1/60 required")
 recorder=root.get_node("PlaytestFeedback").recorder
 if not await samples("res://scenes/lol2/cave_walkthrough.tscn","Cave"):return
 if not await samples("res://scenes/lol2/maps/L10_DC.tscn","L10"):return
 key(KEY_W,true);await process_frame
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 Input.parse_input_event(down);Input.flush_buffered_events();await process_frame
 if recorder.held_keys.is_empty() or recorder.held_buttons.is_empty():return fail("Real held inputs missing before focus loss")
 recorder.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 if not recorder.held_keys.is_empty() or not recorder.held_buttons.is_empty():return fail("Focus loss kept stale held inputs")
 if not recorder.events.any(func(e):return e.get("source")=="focus_loss" and e.kind=="key" and e.key=="W" and not e.pressed):return fail("Cross-focus replay lacks the engine release boundary")
 key(KEY_W,false);down=down.duplicate();down.pressed=false;Input.parse_input_event(down)
 recorder.set_recording(false);recorder.set_recording(true)
 var bad:=BadHost.new();bad.scene_file_path="res://scenes/lol2/cave_walkthrough.tscn";root.add_child(bad);current_scene=bad
 var deadline:=Time.get_ticks_msec()+10000
 while recorder.snapshot_warning.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if recorder.snapshot_warning.is_empty() or bad.snapshots!=1:return fail("Actual failed validation did not back off after one detached document")
 if recorder.next_snapshot_t-recorder.now()<14:return fail("Full-document failure retries before INTERVAL")
 var warning:String=recorder.snapshot_warning
 deadline=Time.get_ticks_msec()+1500
 while Time.get_ticks_msec()<deadline:await process_frame
 if bad.snapshots!=1 or recorder.snapshot_warning!=warning:return fail("Invalid state rebuilt/relogged at1Hz")
 var out:=FileAccess.open("res://tmp/r132_snapshot_worker_costs.json",FileAccess.WRITE);out.store_string(JSON.stringify(metrics,"\t")+"\n");out.close()
 print("PASS worker snapshots: pure detached encoding, base15s captures on Cave and measured60s fallback on L10 when needed, exact captured SHA, real held inputs + focus-release boundary, failed validation backs off without1Hz rebuild")
 quit()
