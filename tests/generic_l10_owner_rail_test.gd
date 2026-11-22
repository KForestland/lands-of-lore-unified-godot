extends "res://tests/generic_l10_blue_priest_test.gd"
## Immutable genuine owner F10 and fresh-v4 F5 continuations. No pose/resource
## writes, clock changes, direct jump/movement/action calls or actor freezing.
const OWNER_INPUT:="res://tests/fixtures/l10_owner_rail_20261113.json"
const OWNER_PIN:="35ed65a44685acaf275f3f3b436cba067966000c1e87cf47bc53c8ea3ae4c2ed"
const BLUE_INPUT:="res://tests/fixtures/l10_fresh_two_blue_3033c3d.json"
const BLUE_PIN:="ecdc060e08d154ff595764d4244778d7801793b02d1147943252c9f9be85a519"
func load_checkpoint(path:String,pin:String)->bool:
 if not require(FileAccess.get_sha256(path)==pin,"Untouched game-written input "+path):return false
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(path,Slots.slot_path(1))==OK,"Install disclosed genuine input for actualF9"):return false
 await tap(KEY_F9);await adopt();await ticks(12)
 return require(area=="L10_DC" and hp()>0 and scene.resets==0 and scene.player.is_on_floor(),"ActualF9 living grounded owner/earned checkpoint")
func fence_real_input(id:int)->bool:
 var fences:Node=scene.get_node("L10Fences");var row:Dictionary=fences.rows[id]
 var before:int=fences.passes
 if id==74 and not await checkpoint("ordinary_jump_takeoff_74"):return false
 if not require(scene.player.is_on_floor() and (pos()-row.center).dot(row.normal)>20,"Grounded high-side takeoff "+str(id)):return false
 if not require(not Input.is_physical_key_pressed(KEY_CTRL) and not Input.is_physical_key_pressed(KEY_SHIFT),"No crouch or sprint modifier"):return false
 await look(scene.camera.global_position-row.normal*200)
 key_event(KEY_W,true)
 # The old sprint takeoff is80away; normal walking reaches the rail first.
 # This is physical W input, not a replacement pose or a longer jump.
 for approach_tick in 120:
  if (pos()-row.center).dot(row.normal)<=35:break
  await physics_frame
 if not require(scene.player.is_on_floor() and (pos()-row.center).dot(row.normal)>18,"Ordinary grounded approach before Space"):return false
 await tap(KEY_SPACE)
 var airborne:=false;var crossed:=false;var poses:Array=[]
 for tick in 300:
  await physics_frame
  airborne=airborne or not scene.player.is_on_floor()
  poses.append({"pos":str(pos()),"floor":scene.player.is_on_floor(),"side":(pos()-row.center).dot(row.normal),"high":row.high,"passing":row.passing,"height":scene.player.get_child(0).shape.height,"velocity":str(scene.player.velocity)})
  if hp()<=0 or scene.resets!=0:break
  if (pos()-row.center).dot(row.normal)<-65 and scene.player.is_on_floor():crossed=true;break
 key_event(KEY_W,false);await ticks(8)
 receipts.append({"rail":id,"input":"W + Space only","airborne":airborne,"crossed":crossed,"passes":fences.passes-before,"position":str(pos()),"resets":scene.resets})
 print("RAIL RESULT ",receipts[-1])
 var diagnostic:=FileAccess.open("user://tests/generic_l10_sitting/rail"+str(id)+"_trajectory.json",FileAccess.WRITE)
 diagnostic.store_string(JSON.stringify({"result":receipts[-1],"poses":poses},"  "));diagnostic.close()
 if not require(airborne and crossed and fences.passes>before,"Plain W+Space clears rail "+str(id)):return false
 return require(hp()>0 and scene.resets==0,"Rail landing alive without fall recovery")
func blue_to_priest()->bool:
 var route:Dictionary=fixture("l10_blue_walk.json")
 if not await walk(route.stairs.points,"ordinary-jump blue stairs"):return false
 if not await walk(route.fence74.points,"ordinary-jump rail74 approach"):return false
 if not await fence_real_input(74):return false
 if not await walk(route.fence174.points,"ordinary-jump rail174 approach"):return false
 if not await fence_real_input(174):return false
 if not await walk(route.exit_stairs.points,"unchanged original exit stairs"):return false
 var path:Dictionary=fixture("l10_priest_walk.json")
 if not await walk(path.door.points,"unchanged original priest approach"):return false
 var tombs:Node=scene.get_node("L10Tombs")
 await act(tombs.aims["154"],"Earned blue at154 after ordinary rail jumps")
 if not require(tombs.opened("154"),"Unchanged original priest door opens"):return false
 if not await walk(path.priest.points,"unchanged priest room entry"):return false
 var priest:Node=scene.get_node("L10Priest")
 await act(priest.AIM,"Earned bracers after ordinary rail jumps")
 if not require(priest.state().urn_given and "act2:L10_DC:priest_urn" in scene.carried_collected,"Unchanged priest urn reward"):return false
 return await checkpoint("ordinary_jumps_priest_urn")
func main():
 if not await start_from_f2():return
 if not await load_checkpoint(OWNER_INPUT,OWNER_PIN):return
 if not require(pos().distance_to(Vector3(1559.3707275390625,-88.006591796875,-2034.651611328125))<0.2,"Exact owner report rail174 save pose; not a replacement stand"):return
 if not await fence_real_input(174):await picture("owner_rail_stop");return
 await picture("owner_rail_green")
 if not await checkpoint("owner_rail174_plain_jump"):return
 if not await load_checkpoint(BLUE_INPUT,BLUE_PIN):return
 if not await blue_to_priest():await picture("rail_chain_stop");return
 var dir:="user://tests/generic_l10_sitting/";DirAccess.make_dir_recursive_absolute(dir)
 var file:=FileAccess.open(dir+"owner_rail_receipts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Genuine owner F10 and earned fresh-v4 F5 continuations; installed snapshots disclosed, never a fresh whole sitting","receipts":receipts,"resets":scene.resets,"stops":stops,"clock":[Engine.time_scale,Engine.physics_ticks_per_second]},"  "));file.close()
 print("PASS owner bundle rail174 and earned blue stairs -> rail74 -> rail174 -> original stairs/priest/urn/F5; W+Space only, no Ctrl/Shift, no test pose/health/movement/action writes,0resets/stalls")
 quit()
