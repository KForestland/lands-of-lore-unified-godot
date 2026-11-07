extends "res://tests/l10_tomb_earned_test.gd"
const Fences=preload("res://scripts/lol2/l10_fences.gd")
func combat_spark()->bool:return false
func heal_threshold()->int:return 25
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 check(Fences.admits(true,false,true,true,-1),"high-side running airborne crouch admitted")
 for args in [[false,false,true,true,-1],[true,true,true,true,-1],[true,false,false,true,-1],[true,false,true,false,-1],[true,false,true,true,1]]:
  check(not Fences.admits(args[0],args[1],args[2],args[3],args[4]),"wrong-side/grounded/walk/unducked/reverse denied")
 var input:=Save.read_save("res://tmp/l10_gold_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned gold load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 scene.set_equipped_armor("cave:captain:Burnt_Chain")
 var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_fence_low_walk.json"))
 if not await walk(scene,fixture.points,"fence174 low approach"):quit(1);return
 var fences=scene.get_node("L10Fences");var row: Dictionary=fences.rows[174]
 check(row.body.position.y-row.body.get_child(0).shape.size.y/2<=row.height-30,"guard reaches lower floor, including small-form height")
 var low: Vector3=row.center-row.normal*55
 if not await walk(scene,[[low.x,low.z]],"low fence takeoff"):quit(1);return
 var key:=InputEventKey.new();key.physical_keycode=KEY_CTRL;key.keycode=KEY_CTRL;key.pressed=true;key.ctrl_pressed=true;Input.parse_input_event(key);Input.flush_buffered_events()
 root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 check(Input.is_physical_key_pressed(KEY_CTRL),"production crouch input held")
 var airborne:=false
 check(scene.request_jump(),"earned low-side running jump requested")
 for tick in 120:
  await physics_frame
  scene.move_grounded(row.normal,scene.player.get_physics_process_delta_time(),true)
  airborne=airborne or not scene.player.is_on_floor()
 check(airborne,"actual production jump became airborne")
 key.pressed=false;key.ctrl_pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
 check((scene.player.position-row.center).dot(row.normal)<-8 and fences.passes==0,"low-side jumping/crouching cannot cross original fence")
 var path:="res://tmp/l10_fence_low_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"earned refusal save/reload")
 check(fences.rows[174].body.collision_layer!=0 and not fences.rows[174].passing,"load retains fence, clears transient passage")
 check("act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"earned gold retained")
 scene.queue_free();await process_frame
 if failures==0:print("PASS STORY-009 earned gold -> original low fence174 -> wrong-way running jump/crouch refused -> save/reload. High-side physical exit remains STORY-017.")
 quit(0 if failures==0 else 1)
