extends "res://tests/generic_l10_owner_positions_test.gd"
## Earned F5 continuations only. All new movement/strikes/pickups use input.
## The inherited read-only graph proposes routes; no proposed pose qualifies.
const SHELF_GOLD:="res://tmp/generic_l10_gold91.json"
const SHELF_GOLD_PIN:="459543b2b44d0baba280471b3622e8fa788596cd4acb0e37ad0d15ce372bda47"
var shelf_receipts:Array=[]
func front_life(id:int)->int:
 return scene.progression.native.field("control:%d"%id,scene.progression.NativeHost.FIELD_BYTE26,-1)
func break_front(id:int)->bool:
 var world:Node=scene.get_node("GenericObjects")
 var before_start:int=front_life(id)
 if not require(before_start>0,"Unbroken source front before actual sword input"+str(id)):return false
 if not await fight("clear the actual room before front"+str(id)):return false
 var losses:Array=[]
 for blow in 64:
  var before:int=front_life(id)
  if before==0:break
  await guard()
  for cooldown in 240:
   if scene.act2_creatures.strike_remaining<=0:break
   await physics_frame
  var point:Vector3=world.cover_bodies[id].global_position
  await look(point);await frames(3)
  var target:Dictionary=world.aimed()
  if target.get("kind")!="cover" or int(target.get("id",-1))!=id:
   stop("shelf front"+str(id),"Actual crosshair blocked at %s; expected cover%d, got%s"%[pos(),id,target]);return false
  await lclick();await ticks(2)
  var after:int=front_life(id)
  if after>=before:
   stop("shelf front"+str(id),"Actual sword input made no progress; hp=%d life%d->%d HUD=%s"%[hp(),before,after,hud()]);return false
  losses.append([before,after])
 if not require(front_life(id)==0 and world.cover_bodies[id].collision_layer==0,"Actual strikes release source front"+str(id)):return false
 shelf_receipts.append({"front":id,"real_input":"left","position":str(pos()),"losses":losses,"health":hp(),"resets":scene.resets})
 return true
func collect_shelves(ids:Array)->bool:
 for number in ids:
  var id:String="act2:L10_DC:item%d"%int(number)
  if not scene.act2_items.available(id):
   var query:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.act2_items.aim_point(id),1,[scene.player.get_rid()])
   var obstruction:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
   print("SHELF BEFORE AIM id=",id," player=",pos()," eye=",scene.camera.global_position," item=",scene.act2_items.aim_point(id)," ray=",obstruction)
  if not await take_item(id,"requested shelf"+str(number)):return false
  shelf_receipts.append({"item":id,"real_input":"E","position":str(pos()),"health":hp(),"resets":scene.resets})
 return true
func jump_collect(id_number:int)->bool:
 var id:String="act2:L10_DC:item%d"%id_number
 if not require(scene.player.is_on_floor() and not id in scene.carried_collected,"Grounded actual stand before high shelf jumpE"):return false
 var stand:Vector3=pos()
 key_event(KEY_SPACE,true);await physics_frame;key_event(KEY_SPACE,false)
 var taken:=false
 for tick in 160:
  await look(scene.act2_items.aim_point(id));await physics_frame
  if scene.act2_items.available(id):
   var at_press:Vector3=pos()
   await tap(KEY_E);await frames(4)
   if id in scene.carried_collected:
    shelf_receipts.append({"item":id,"real_input":"Space then E","grounded_start":str(stand),"position_at_E":str(at_press),"health":hp(),"resets":scene.resets})
    say("Actual jumpE takes high shelf"+str(id_number)+" from "+str(stand)+" at "+str(at_press))
    taken=true;break
  if tick>8 and scene.player.is_on_floor():break
 for settling in 180:
  await physics_frame
  if scene.player.is_on_floor():break
 return require(taken and scene.player.is_on_floor() and hp()>0 and scene.resets==0,"Actual jumpE takes high shelf"+str(id_number)+" and lands safely")
func gold_shelves()->bool:
 if not require(scene.get_node("L10Tombs").opened("91"),"Earned91alreadyopen"):return false
 if not await walk([[25,-2495],[-102,-2495],[-180,-2495],[-250,-2495],[-395,-2406],[-477,-2464]],"actual gold91 room and north shelves"):return false
 if not await break_front(262):return false
 if not await walk([[-477,-2406]],"actual approach to scroll21 after its front broke"):return false
 if not await collect_shelves([21]):return false
 if not await walk([[-395,-2406]],"actual central north shelf stand"):return false
 for id in [265,266,267]:
  if not await break_front(id):return false
 if not await collect_shelves([25,26,27]):return false
 if not await walk([[-363,-2406]],"actual low shelf fire crystals and dagger"):return false
 if not await collect_shelves([19,20]):return false
 if not await walk([[-331,-2387]],"actual closer low dagger shelf stand"):return false
 key_event(KEY_C,true);await ticks(6)
 if not require(scene.crouched,"Actual heldC lowers the eye below the source low-shelf ceiling"):return false
 if not await collect_shelves([41]):return false
 key_event(KEY_C,false);await ticks(6)
 if not await walk([[-395,-2495],[-394,-2574]],"actual south shelf amber stand"):return false
 if not await break_front(271):return false
 for id_number in [10,13]:
  if not await jump_collect(id_number):return false
 if not await walk([[-489,-2574]],"actual south shelf sap stand"):return false
 if not await break_front(268):return false
 if not await collect_shelves([15,16]):return false
 return await checkpoint("requested_gold91_shelves")
func supply_shelves()->bool:
 if not await open_tomb("87"):return false
 var planner:=Planner.new(scene,graph_source)
 if not await walk_route(planner,Vector3(1409,32,-3994),"actual open87 supply shelf stand"):return false
 if not await break_front(248):return false
 for id_number in [2,3,4,5,6]:
  if not await jump_collect(id_number):return false
 if not await walk([[1273,-4178]],"actual north supply shelf scroll stand"):return false
 if not await break_front(253):return false
 if not await walk([[1255,-4188]],"actual scroll7 front254 stand"):return false
 if not await break_front(254):return false
 if not await collect_shelves([7]):return false
 return await checkpoint("requested_supply87_shelves")
func finish_shelves(ok:bool):
 if trace!=null:trace.finish()
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Earned F5 continuation, actual input only, not a fresh whole sitting","group":group_name,"passed":ok,"rows":shelf_receipts,"health":hp(),"resets":scene.resets,"stops":stops,"clock":[Engine.time_scale,Engine.physics_ticks_per_second]},"  "));file.close()
 if ok:print("PASS requested L10 shelf items ",group_name,"; realW/left/E from earned input,0teleports/resets/stalls")
 quit(0 if ok else 1)
func main():
 group_name=OS.get_environment("LOL2_SHELF_GROUP")
 if not require(group_name in ["gold91","supply87"],"Select explicit shelf group"):return
 if not require(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"Ordinary clock"):return
 source=fixture("l10_owner_tour_cases.json")
 if not require(FileAccess.get_sha256(GRAPH_INPUT)==GRAPH_PIN,"Unchanged read-only planning input"):return
 graph_source=JSON.parse_string(FileAccess.get_file_as_string(GRAPH_INPUT))
 folder="user://tests/generic_l10_shelves/"+group_name;DirAccess.make_dir_recursive_absolute(folder)
 if not await start_from_f2():return
 var input:Dictionary={"path":SHELF_GOLD,"sha256":SHELF_GOLD_PIN} if group_name=="gold91" else source.inputs.party
 if not await load_input(input):return
 if not require(scene.height_boundary_keys.size()==3530 and scene.get_node("HeightBoundaryCollision").collision_layer==1,"All3530shared boundary faces enabled"):return
 trace=load("res://tests/helpers/walked_ground_recorder.gd").new(self,folder+"/walked_poses.jsonl")
 var ok:bool=await gold_shelves() if group_name=="gold91" else await supply_shelves()
 ok=ok and hp()>0 and scene.resets==0 and stops.is_empty()
 finish_shelves(ok)
