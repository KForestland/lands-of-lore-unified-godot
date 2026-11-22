extends "res://tests/helpers/act1_owner_object_input.gd"
## Original owner stands; actual E. Nearer receiver is an explicit test double.
class NearerReceiver extends Node3D:
 var host:Node3D
 var uses:=0
 func _unhandled_input(event:InputEvent):
  if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
   uses+=1;host.save_feedback("Nearer target used.");get_viewport().set_input_as_handled()
func run():
 var only:String=OS.get_environment("SOL_R141_E_ONLY")
 if only!="passthrough":
  if not await owner("L7_DH","dh_decor17"):return
  await look(Vector3(1962,429,-986));await key(KEY_E);await ticks(2)
  if not check(scene.interface_hud.hint.text=="This crate holds no crystals.","ActualE identifies a source decoration crate"):return
  var deco_nearer:=NearerReceiver.new();deco_nearer.host=scene;scene.add_child(deco_nearer)
  scene.move_child(deco_nearer,scene.crates.get_index()-1)
  deco_nearer.global_position=scene.camera.global_position-scene.camera.global_basis.z*5
  await key(KEY_E);await ticks(2)
  if not check(deco_nearer.uses==1 and scene.interface_hud.hint.text=="Nearer target used.","Decoration inspection also leaves actualE for a nearer target"):return
  scene.queue_free();await process_frame;await process_frame
 if not await owner("L7_DH","dh_door17"):return
 var c:Node=scene.crates
 await look(c.center_of(56)+Vector3.UP*(c.half_of(56).y-1))
 var nearer:=NearerReceiver.new();nearer.host=scene;scene.add_child(nearer)
 scene.move_child(nearer,c.get_index()-1)
 nearer.global_position=scene.camera.global_position-scene.camera.global_basis.z*5
 await key(KEY_E);await ticks(2)
 if not check(nearer.uses==1 and scene.interface_hud.hint.text=="Nearer target used." and c.state_of(56)==1,"Primed echo leaves actualE available to a nearer receiver"):return
 print("PASS R141 realE decoration reason and primed-crate passthrough to nearer receiver double; original owner stands, held actors/slot, no earned NPC/lever claim")
 quit()
