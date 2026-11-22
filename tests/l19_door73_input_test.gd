extends "res://tests/generic_l13_chain_input_test.gd"
## Exact game-written robot east checkpoint, actualF9 continuation. Every move,
## E, click, F5 and F9 is engine input; no supplied pose/health or native action.
const EAST := "res://tmp/l19_door73_inputs/east_f5.json"
const EAST_SHA := "1a3e0fb780b6ace7bd745f2f7194ae7a3bf5b6d243a48c9c3b6aa27d5ac81441"
func picture(tag:String):
 var folder:="user://tests/l19_door73/";DirAccess.make_dir_recursive_absolute(folder)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+tag+".png")
func restore_east()->bool:
 if not require(FileAccess.get_sha256(EAST)==EAST_SHA,"Untouched robot lip2 eastF5"):return false
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(EAST,Slots.slot_path(1))==OK,"Install untouched game-written eastF5 for realF9"):return false
 await tap(KEY_F9);await adopt()
 if not require(area=="L19_BC" and scene.resets==0 and hp()>0,"Living realF9 L19 east continuation"):return false
 for id in [103,100,133]:
  if not require(absf(float(scene.progression.regions[id][1])+45)<0.1,"Each channel floor fully raised before proof "+str(id)):return false
 return require(scene.progression.native.field("movable:73",scene.progression.NativeHost.FIELD_TRAVEL,0)==0,"Earlier F9 really restores closed door73 before EACH press")
func checkpoint(tag:String)->bool:
 await ticks(20)
 print("DOOR73 SAVE admission=",scene.can_save()," at=",pos()," hp=",hp())
 var ok:bool=await super.checkpoint(tag)
 print("DOOR73 F5 result=",ok," HUD=",hud()," status=",scene.interface_hud.save_status.text)
 return ok
func main():
 use_guard=false
 if not await start_from_f2():return
 var modes:Array=["E","click"] if OS.get_environment("LOL2_DOOR73_MODE").is_empty() else [OS.get_environment("LOL2_DOOR73_MODE")]
 for mode in modes:
  if not await restore_east():return
  if not await walk([[1587,-2196],[1587,-2296]],"Robot east to closed door73"):await picture("approach_stop");quit(1);return
  for id in [103,100,133]:
   if not require(absf(float(scene.progression.regions[id][1])+45)<0.1,"Each raised floor immediately before "+mode):return
  if not require(scene.progression.native.field("movable:73",scene.progression.NativeHost.FIELD_TRAVEL,0)==0,"Door closed immediately before "+mode):return
  var closed:Transform3D=scene.progression.hinges[73].transform
  await look(Vector3(1587,-5,-2319));await picture(mode+"_before")
  if mode=="E":await tap(KEY_E)
  else:await lclick()
  if mode=="click" and not require(not scene.interface_hud.attack_swing.icon.visible,"Eligible door use takes priority over attack"):return
  await ticks(180);await picture(mode+"_after")
  var native=scene.progression.native
  print("DOOR73 actual",mode," travel=",native.field("movable:73",native.FIELD_TRAVEL,0)," list25=",native.field("0x2b53c:25","byte_0x09",0)," transform=",scene.progression.hinges[73].transform)
  if not require(native.field("movable:73",native.FIELD_TRAVEL,0)==55,"Real"+mode+" runs source73opening callback5858"):return
  if not require(native.field("0x2b53c:25","byte_0x09",0)==1 and not scene.progression.hinges[73].transform.is_equal_approx(closed),"Group3264 mark retained and actual door geometry moves"):return
  if not await checkpoint("l19_door73_"+mode+"_open"):return
  await tap(KEY_F9);await adopt();await ticks(180)
  if not require(scene.progression.native.field("movable:73",scene.progression.NativeHost.FIELD_TRAVEL,0)==55 and hp()>0 and scene.resets==0,"RealF9 preserves open door and living continuation"):return
  # E proves the earned crossing (and fights its existing enemy on real input).
  # Click independently proves identical physical opening and disk restoration.
  if mode=="E":
   if not await walk([[1587,-2350]],"Walk through opened door73"):await picture("door_cross_stop");quit(1);return
   if not await walk([[1587,-2280]],"Open door73 remains crossable after realF9"):quit(1);return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Both genuine checkpoint repeats remain living without fall recovery"):return
 print("PASS door73 modes=",modes," after raised channel, physical opening/F5/F9 each; E earns crossing and return, ordinary1/60,0pose/health writes")
 quit()
