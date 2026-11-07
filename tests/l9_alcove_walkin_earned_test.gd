extends "res://tests/l9_statue_earned_test.gd"
## STORY-024: region 3185 opens the STAT room on entry. This walk does not press E and does not call enter().
## The room pauses the physics server, so the alcove route ends when the room opens.
func walk(scene:Node,points:Array,label:String)->bool:
 if label!="original STAT alcove3185":return await super.walk(scene,points,label)
 var statue=scene.get_node("L9Statue")
 for index in points.size():
  var goal:=Vector3(points[index][0],0,points[index][1])
  var reached:=false
  var prior:Vector3=scene.player.position
  var stalled:=0
  for tick in 1600:
   if statue.room_active and paused:return true
   if not await fight_nearby(scene):return false
   var d:Vector3=goal-scene.player.position;d.y=0
   if d.length()<(2.0 if scene.player_form==2 else 7.0) and scene.player.is_on_floor():reached=true;break
   if scene.player.position.distance_to(prior)<0.05:stalled+=1
   else:stalled=0
   prior=scene.player.position
   if stalled==20 and scene.player.is_on_floor():
    check(scene.request_jump(),"actual jump at original stair lip");print("STAIR jump ",index," ",scene.player.position);stalled=0
   scene.move_grounded(d.normalized(),1.0/60);await physics_frame
   if statue.room_active and paused:return true
   if tick%300==0:print("RETURN WALK ",label," point",index," ",scene.player.position)
  if not check(reached,label+" point"+str(index)+" at "+str(scene.player.position)):return false
 return true
func run():
 root.size=Vector2i(1280,720);Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual earned statue input"):quit(1);return
 prepare(scene)
 var chapel: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_chapel_walk.json"))
 if not await walk(scene,upstairs_points(chapel),"Noble north upstairs"):quit(1);return
 if not await walk(scene,[[639,-5700],[639,-5655]],"original balcony481"):quit(1);return
 var rails=scene.get_node("L9NobleRails")
 if "480" not in rails.state().broken:
  scene.camera.look_at(Vector3(639,160,-5596),Vector3.UP)
  if not check(rails.strike(),"real north rail strike on earlier question branch"):quit(1);return
 if not await walk(scene,[[639,-5500]],"north rail exit"):quit(1);return
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_statue_walk.json"))
 if not await walk(scene,route.points,"original STAT alcove3185"):quit(1);return
 var statue=scene.get_node("L9Statue")
 var before: Array=scene.carried_collected.duplicate()
 for i in 8:await process_frame
 if not check(statue.entry_latched and statue.room_active and paused,"alcove walk opens the STAT room without E"):quit(1);return
 check(Statue.REMAINS in before,"earned remains still carried when the room opens")
 check(not statue.offer("act2:L9_DR:item55").ok and before==scene.carried_collected,"wrong bracers refused without loss")
 for i in 5:await process_frame
 var bowl: Button=statue.panel.get_node("LeftBowl")
 check(bowl.position==Vector2(145,185) and bowl.size==Vector2(130,144),"original bowl hotspot0 bounds")
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=bowl.get_global_rect().get_center();event.global_position=event.position
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 if not check(Statue.offered(statue.state()) and Statue.REMAINS not in scene.carried_collected and not paused,"actual bowl click commits Kit once"):quit(1);return
 var path:="res://tmp/l9_alcove_walkin_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual bowl occupied receipt save/reload")
 check(not statue.enter().ok and not statue.offer(Statue.REMAINS).ok,"no duplicate offering after reload")
 check("act2:L9_DR:item55" in scene.carried_collected,"bracers retained")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS STORY-024: earned remains walk opens the STAT room without E, bowl click, save/reload")
 quit(0 if failures==0 else 1)
