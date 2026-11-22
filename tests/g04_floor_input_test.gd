extends SceneTree
## Local source-control fixture with held host movement, real mouse/E/F5/F9.
## Supplied stand is disclosed; this is a save census, not an earned walk.
const Saves=preload("res://scripts/lol2/game_save.gd")
const Session=preload("res://scripts/lol2/game_session.gd")
var scene:Node
var failed:=false
func _initialize():run.call_deferred()
func check(ok:bool,message:String)->bool:
 if not ok:failed=true;push_error(message);quit(1)
 return ok
func ticks(n:int):
 for i in n:await physics_frame
func key(code:Key):
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
  Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func look(point:Vector3):
 var d:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-d.x,-d.z);var pitch:=atan2(d.y,Vector2(d.x,d.z).length())
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events();await process_frame
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 for i in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
func reload():
 var old:int=scene.get_instance_id();await key(KEY_F9)
 for i in 1800:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old and current_scene.get("ready_for_review")==true and Session.for_tree(self).pending_resume.is_empty():break
 scene=current_scene;await settled()
 return check(scene.get_instance_id()!=old,"ActualF9 recreated the area")
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered input census"):return
 scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 var id:=83;var point:Vector3=scene.progression.movable_position(id)
 scene.player.position=point+Vector3(0,32,80);scene.player.velocity=Vector3.ZERO
 scene.set_physics_process(true)
 for i in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 await look(point);await ticks(3)
 if not check(scene.progression.aimed()==id,"Actual mouse aim selects source movable83"):return
 var native_before:Dictionary=scene.progression.native.snapshot()
 await key(KEY_E);await ticks(240)
 print("G04 input log ",scene.progression.route_log.slice(-3)," floors ",scene.progression.floor_checkpoint())
 if not check(not scene.progression.floor_motion.is_empty(),"RealE started native opcode196 floor"):return
 var expected:Dictionary=scene.progression.floor_checkpoint()
 await key(KEY_F5);await ticks(2)
 var document:=Saves.read_document(Saves.slot_path(1))
 print("G04 F5 error=",document.error," admission=",scene.can_save()," floor=",scene.player.is_on_floor()," at=",scene.player.position," HUD=",scene.interface_hud.save_status.text)
 if not check(document.error.is_empty(),"ActualF5 writes a valid whole-game slot"):return
 # Use the written checkpoint, not a guess at how many frames elapsed before F5.
 var saved_bank:Dictionary=document.state.native_bank.L14_HT
 print("G04 saved native targets ",saved_bank.state)
 if not await reload():return
 expected=saved_bank.world.floors
 var actual:Dictionary=scene.progression.floor_checkpoint()
 print("G04 restored floors ",actual)
 if not check(not actual.motions.is_empty(),"RealF9 retains live native floor heights/clock, not just VM target"):return
 for region in expected.motions:
  if not check(actual.motions.has(region) and absf(float(actual.motions[region].height)-float(expected.motions[region].height))<=2 and int(actual.motions[region].height)+int(actual.motions[region].remaining)==int(expected.motions[region].height)+int(expected.motions[region].remaining),"Saved deck resumes from its physical height (at most two normal post-load units), with the exact saved target "+region):return
 if not check(scene.starting_magic.health()>0 and scene.resets==0,"Living census continuation, no fall recovery"):return
 print("PASS G04 actual E/F5/F9 L14 native floor physical checkpoint; held stand aid, no event re-fire")
 quit()
