extends "res://tests/generic_l10_blue_priest_test.gd"
## The input fixtures are unchanged actual F5s. Every new location must be
## reached on production W/mouse/jump, not inferred from the planning graph.
const Planner=preload("res://tests/helpers/l10_owner_route_planner.gd")
const INPUT_FIXTURES=["res://tmp/generic_l10_inputs/owner36_gold_save.json","res://tmp/generic_l10_inputs/owner36_party_save.json","res://tmp/generic_l10_inputs/owner36_blue_save.json","res://tmp/generic_l10_inputs/owner36_lid_save.json","res://tmp/generic_l10_inputs/owner36_maus_save.json"]
const GRAPH_INPUT:="res://tmp/generic_l10_inputs/l10_owner_tour_graph.json"
const GRAPH_PIN:="be81771344577a4f2b412ae7fc195b42fe7a18764384bdeb7a97fd1d3b85ce34"
var source:Dictionary
var graph_source:Dictionary
var group_name:=""
var results:Array=[]
var trace:RefCounted
var folder:=""
func load_input(input:Dictionary)->bool:
 if not require(FileAccess.get_sha256(input.path)==input.sha256,"Untouched earned input pin"):return false
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(input.path,Slots.slot_path(1))==OK,"Install unchanged actualF5 for realF9"):return false
 await tap(KEY_F9);await adopt();await ticks(4)
 await heal_to(30)
 return require(area=="L10_DC" and hp()>0 and scene.resets==0 and captured() and not scene.adapter_exit_seeds and not scene.development_mode,"ActualF9 living production foot context")
func receipt():
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"group":group_name,"scope":"Actual input qualification from disclosed unchanged earned F5; planning queries alone never qualify a point","clock":[Engine.time_scale,Engine.physics_ticks_per_second],"results":results,"stops":stops},"  "));file.close()
func walk_route(planner:RefCounted,to:Vector3,label:String)->bool:
 var planned:Dictionary=planner.route(pos(),to)
 var route:Array=planned.points
 if route.is_empty():
  say("OWNER planner did not qualify "+label+": "+str(planned.reason))
  route=planned.get("fallback",[])
  if route.is_empty():return false
 return await walk(route,label,{"reach":6.0,"final_reach":2.0})
func open_tomb(id:String)->bool:
 var tombs:Node=scene.get_node("L10Tombs")
 if tombs.opened(id):return true
 var aim:Vector3=tombs.aims[id]
 var planner:=Planner.new(scene,graph_source)
 if source.get("socket_stands",{}).has(id):
  var point:Array=source.socket_stands[id]
  if source.get("socket_routes",{}).has(id):
   if not await walk(source.socket_routes[id],"explicit exterior approach to socket"+id,{"final_reach":2.0}):return false
  elif not await walk_route(planner,Vector3(point[0],point[1],point[2]),"actual exterior approach to socket"+id):return false
  await act(aim,"ActualE prerequisite socket"+id)
  return tombs.opened(id)
 for radius in [80.0,112.0,144.0]:
  for direction in 16:
   var candidate:=Vector3(aim.x+sin(direction*TAU/16)*radius,32.0,aim.z+cos(direction*TAU/16)*radius)
   if not planner.free_at(candidate):continue
   var query:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*10,aim,1|2|tombs.AIM_LAYER,planner.excludes)
   var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty() or hit.collider!=tombs.receptacles[id]:continue
   var planned:Dictionary=planner.route(pos(),candidate)
   if planned.points.is_empty():continue
   if not await walk(planned.points,"actual approach to prerequisite socket"+id,{"final_reach":4.0}):return false
   await act(aim,"ActualE prerequisite socket"+id)
   if tombs.opened(id):return true
 return false
func one_goal(id:int)->bool:
 var row:Dictionary=source.rows[str(id)]
 var original:=Vector3(row.position[0],row.position[1],row.position[2])
 var goal:=Vector3(original.x,row.standing_h,original.z)
 var planner:=Planner.new(scene,graph_source)
 var access_ok:=true
 if row.has("access"):
  var access:Dictionary=row.access
  if access.has("route"):
   access_ok=await walk(access.route,"owner report"+str(id)+" explicit actual approach",{"final_reach":2.0})
  else:
   var via:Vector3=Vector3(access.first[0],access.first[1],access.first[2])
   access_ok=await walk_route(planner,via,"owner report"+str(id)+" clear approach")
  if access_ok:
   for door in access.get("movables",[]):
    var binding:Node=scene.progression
    if binding.native.field("movable:%d"%int(door),"state_0x55",0)!=0:continue
    var aim:Vector3=binding.hinges[int(door)].global_transform*binding.mover_bounds[int(door)].get_center()
    await act(aim,"ActualE prerequisite movable"+str(door))
    await ticks(60)
    if binding.native.field("movable:%d"%int(door),"state_0x55",0)!=1:access_ok=false;break
  if access_ok:access_ok=await walk(access.points,"owner report"+str(id)+" around source scenery",{"final_reach":2.0})
 for socket in row.get("tombs",[]):
  if access_ok and not await open_tomb(str(socket)):access_ok=false
 var target:=goal;var found:=false;var chosen:Array=[];var fallback:Array=[]
 for radius in [0.0,4.0,8.0,12.0]:
  for direction in (1 if radius==0 else 16):
   var candidate:Vector3=goal+Vector3(sin(direction*TAU/16),0,cos(direction*TAU/16))*radius
   if not planner.free_at(candidate):continue
   var planned:Dictionary=planner.route(pos(),candidate)
   if fallback.is_empty():fallback=planned.get("fallback",[])
   if not planned.points.is_empty():target=candidate;chosen=planned.points;found=true;break
  if found:break
 var walked:=false
 if found and access_ok:walked=await walk(chosen,"owner report"+str(id),{"reach":6.0,"final_reach":2.0})
 elif access_ok and not fallback.is_empty():walked=await walk(fallback,"owner report"+str(id)+" native fallback",{"reach":6.0,"final_reach":2.0})
 await ticks(6)
 var distance:float=Vector2(pos().x-original.x,pos().z-original.z).length()
 for settling in 180:
  if scene.player.is_on_floor():break
  await physics_frame
 var expected_h:float=float(original.y) if row.get("literal_contact",false) else goal.y
 var height_error:float=absf(pos().y-expected_h)
 var reached:bool=walked and distance<=16.0 and height_error<=4.0 and hp()>0 and scene.resets==0
 var jump_hit:=false
 if reached and row.literal_jump:
  key_event(KEY_SPACE,true);await physics_frame;key_event(KEY_SPACE,false)
  for tick in 90:
   await physics_frame
   if Vector2(pos().x-original.x,pos().z-original.z).length()<=16.0 and absf(pos().y-original.y)<=2.0:jump_hit=true
  reached=jump_hit
 var contacts:Array=[]
 for index in scene.player.get_slide_collision_count():
  var hit:KinematicCollision3D=scene.player.get_slide_collision(index)
  contacts.append({"path":str(hit.get_collider().get_path()),"position":str(hit.get_position()),"normal":str(hit.get_normal())})
 var record:Dictionary={"row":id,"report":row.report,"reachable_on_foot":reached,"target":row.position,"standing_h":row.standing_h,"actual":str(pos()),"distance_xz":distance,"standing_height_error":height_error,"health":hp(),"resets":scene.resets,"native_planner_free_goal":found,"literal_jump_reached":jump_hit,"contacts":contacts,"trace_sample":trace.samples,"reason":"Actual input reached the reported location (within16 horizontal/4 standing-height units)." if reached else "Not qualified: actual foot route failed or no supported collision-free goal was found; see contacts/stops."}
 if reached:
  if not await checkpoint("owner_position_"+str(id)):reached=false;record.reachable_on_foot=false;record.reason="Real input reached the location but its realF5 failed; see gate."
 results.append(record);receipt();say("OWNER RESULT "+JSON.stringify(record))
 return reached
func group_setup(group:Dictionary)->bool:
 var ok:=true
 if group.get("prelude","")=="before174":
  var route:Dictionary=fixture("l10_blue_walk.json")
  ok=await walk(route.stairs.points,"earned blue charger stairs")
  if ok:ok=await walk(route.fence74.points,"original fence74 high approach")
  if ok:ok=await fence_real_input(74)
  if ok:ok=await walk(route.fence174.points,"original path before fence174")
 for tomb in group.get("tombs",[]):
  if not await open_tomb(tomb):ok=false;break
 return ok
func main():
 group_name=OS.get_environment("LOL2_OWNER_TOUR_GROUP")
 source=fixture("l10_owner_tour_cases.json")
 if not require(FileAccess.get_sha256(GRAPH_INPUT)==GRAPH_PIN,"Pinned read-only graph input, no committed native map geometry"):return
 graph_source=JSON.parse_string(FileAccess.get_file_as_string(GRAPH_INPUT))
 if not require(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"Ordinary production1/60 clock"):return
 if not require(source.groups.has(group_name),"Select one explicit owner tour group"):return
 folder="user://tests/generic_l10_owner_tour/"+group_name;DirAccess.make_dir_recursive_absolute(folder)
 if not await start_from_f2():return
 var group:Dictionary=source.groups[group_name]
 if not await load_input(source.inputs[group.input]):return
 trace=load("res://tests/helpers/walked_ground_recorder.gd").new(self,folder+"/walked_poses.jsonl")
 var setup:bool=await group_setup(group)
 var failures:=0
 for id in group.rows:
  var ok:=false
  if setup:ok=await one_goal(int(id))
  else:
   results.append({"row":id,"report":source.rows[str(int(id))].report,"reachable_on_foot":false,"reason":"Prerequisite socket could not be opened on real input."});receipt()
  if not ok:
   failures+=1
   if int(id)==int(group.rows[-1]):break
   if not await load_input(source.inputs[group.input]):break
   setup=await group_setup(group)
 trace.finish();receipt()
 if failures>0:print("FAIL owner tour ",group_name,": ",failures," positions still unqualified");quit(1);return
 print("PASS owner tour ",group_name,": ",results.size()," actual foot positions; ordinary1/60, no supplied runtime pose/health/clock/action writes")
 quit()
