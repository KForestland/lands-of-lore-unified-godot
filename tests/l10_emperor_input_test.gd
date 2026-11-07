extends "res://tests/l10_emperor_earned_test.gd"
func run():
 root.size=Vector2i(1280,720)
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_emperor_inner_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual inner checkpoint"):quit(1);return
 prepare(scene)
 if not await walk(scene,[[3207,-1300],[3207,-1270]],"actual room3789"):quit(1);return
 var emperor=scene.get_node("L10Emperor")
 if not check(emperor.interact("remains").ok,"original EMPT entry"):quit(1);return
 for i in 5:await process_frame
 var button: Button=emperor.room_panel.get_node("CoffinHotspot")
 check(button.position==Vector2(293,102) and button.size==Vector2(53,144),"original native hotspot2 rectangle")
 var before: Array=scene.carried_collected.duplicate()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center();event.global_position=event.position
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 check(Emperor.REMAINS in scene.carried_collected and not paused and not emperor.room_active,"actual mouse click grants once and resumes world")
 check(scene.carried_collected.size()==before.size()+1 and not emperor.collect_remains().ok,"no duplicate after closing")
 # This is an isolated real-input branch; it never replaces the main route save.
 check(scene._quicksave_unrecorded("res://tmp/l10_emperor_click_earned_save.json").is_empty(),"actual click branch saves")
 scene.queue_free();await process_frame
 if failures==0:print("PASS original EMPT hotspot2 actual mouse input -> unique earned remains -> world resumes -> isolated save")
 quit(0 if failures==0 else 1)
