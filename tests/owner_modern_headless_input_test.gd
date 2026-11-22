extends SceneTree
## Tool qualification: supplied local poses and held physics, engine-dispatched
## E without capture. Not a walk; magic capture guards must remain unchanged.
var failures:=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String)->bool:
 if not ok:failures+=1;push_error(message);quit(1)
 return ok
func press():
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func run():
 if not check(DisplayServer.get_name()=="headless","Headless qualification required"):return
 for spec:Dictionary in [
  {"area":"L12_CM","point":Vector3(3430,-218,-6580),"stand":Vector3(3430,-218,-6500),"key":"l12_tiger_platform"},
  {"area":"L14_HT","point":Vector3(607,24,-4139),"stand":Vector3(650.7,40,-4142.6),"key":"l14_aloe_bed"}]:
  var scene=load("res://scenes/lol2/maps/"+spec.area+".tscn").instantiate();scene.adapter_exit_seeds=false
  scene.process_mode=Node.PROCESS_MODE_DISABLED # Hold startup until the existing deferred magic attachment completes.
  root.add_child(scene);current_scene=scene
  for i in 1800:
   await process_frame
   if scene.ready_for_review and is_instance_valid(scene.starting_magic):break
  scene.process_mode=Node.PROCESS_MODE_INHERIT
  scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
  scene.player.position=spec.stand;scene.player.velocity=Vector3.ZERO
  scene.camera.look_at(spec.point,Vector3.UP)
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;scene.interface_hud.set_cursor(true)
  await press()
  if not check(not scene.quest_state.has(spec.key),"Interface cursor blocks newE owner: "+spec.area):return
  scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;paused=true;await press();paused=false
  if not check(not scene.quest_state.has(spec.key),"Pause blocks newE owner: "+spec.area):return
  if not check(Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and not scene.starting_magic.world_active(),"No captured pointer and original magic clock guard closed"):return
  await press()
  if not check(scene.quest_state.has(spec.key),"Actual headless E reaches new owner without capture: "+spec.area):return
  if spec.area=="L12_CM":
   if not check(scene.quest_state[spec.key].activated and scene.progression.floor_motion.has(1899),"Headless E really starts modern switch"):return
   for i in 5:await physics_frame
   if not check(not scene.starting_magic.world_active() and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED,"Input waiver leaves original magic clock capture guard closed; native mover ticking is unchanged"):return
  else:
   if not check(not scene.quest_state[spec.key].item.is_empty() and scene.quest_state[spec.key].item in scene.carried_collected,"Headless E really grants Aloe"):return
  scene.free();current_scene=null
 print("PASS real headless E for both new owners, no capture; pause/cursor refuse; magic clock retains original capture gate; native mover cadence unchanged. Supplied poses/held host disclosed")
 quit()
