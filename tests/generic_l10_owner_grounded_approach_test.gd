extends "res://tests/generic_l10_sitting_test.gd"
const INPUT:="res://tests/fixtures/l10_owner_ok_here_20261113.json"
const PIN:="8b361074560c0693caa32dc8d474d687616585cfcfd5891b87ea16526ec5eb20"
const TRACE:="res://tests/fixtures/l10_owner_fall_trace_20261113.json"
const TRACE_PIN:="e7e856ca8c287cadf2dd44ecd278b3cbeda98b0c047e0ffd07deac1618825f2d"
const CODES={"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D,"Shift":KEY_SHIFT,"Ctrl":KEY_CTRL,"Space":KEY_SPACE}
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(INPUT)==PIN and FileAccess.get_sha256(TRACE)==TRACE_PIN,"Untouched owner ok-here save and pinned recorded input"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Slots.slot_path(1))==OK,"Disclosed genuine F10 installation for actualF9"):return
 await tap(KEY_F9);await adopt();await ticks(12)
 if not require(pos().distance_to(Vector3(-508.957366943359,32.0443725585938,-4013.2578125))<1 and scene.player.is_on_floor(),"Actual owner ok-here grounded start, not the already-invalid roof"):return
 var trace:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(TRACE));var event_index:=0;var actual:Array=[];var held:Dictionary={};var stood_on_roof:=false
 for frame in int(ceil((trace.end-trace.start)*60))+1:
  var now:float=float(trace.start)+float(frame)/60
  while event_index<trace.events.size() and float(trace.events[event_index].t)<=now:
   var event:Dictionary=trace.events[event_index]
   if event.kind=="look":mouse_rel(Vector2(event.relative[0],event.relative[1]))
   else:
    held[event.key]=event.pressed
    key_event(CODES[event.key],event.pressed,held.get("Ctrl",false),held.get("Shift",false))
   event_index+=1
  await physics_frame
  var at:=pos()
  stood_on_roof=stood_on_roof or (scene.player.is_on_floor() and at.x< -653 and at.x> -680 and at.z< -4189 and at.z> -4286 and at.y>75)
  actual.append({"t":now,"x":at.x,"z":at.z,"h":at.y,"on_floor":scene.player.is_on_floor(),"resets":scene.resets})
 for code in CODES.values():key_event(code,false)
 await ticks(12)
 var boundary:Node=scene.get_node("HeightBoundaryCollision")
 var aperture:=BoxShape3D.new();aperture.size=Vector3(6,8,6)
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=aperture;q.collision_mask=1;q.exclude=[scene.player.get_rid()]
 var bands:Array=[]
 for y in [40,60]:
  q.transform=Transform3D(Basis(),Vector3(-653.5,y,-4238));var hits:Array=scene.player.get_world_3d().direct_space_state.intersect_shape(q,32)
  var named_hit:=false
  for hit in hits:named_hit=named_hit or hit.collider==boundary
  bands.append(named_hit)
 var result:Dictionary={"scope":"Actual F9 from owner ok-here, then his recorded keyboard/look events; no pose/resource/movement/action writes or reseating","save_sha256":PIN,"input_sha256":TRACE_PIN,"actual_poses":actual,"stood_on_invalid_roof":stood_on_roof,"final":str(pos()),"health":hp(),"resets":scene.resets,"named_band_query_y40_y60":bands,"clock":[Engine.time_scale,Engine.physics_ticks_per_second]}
 var f:=FileAccess.open("user://tests/generic_l10_sitting/owner_grounded_approach.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 await picture("owner_grounded_approach_raw_view")
 # Keep the recorded final look, then show the safe outcome at eye level via
 # real mouse input. The owner looked down during a fall that is now blocked.
 await look(Vector3(-653.5,scene.camera.global_position.y,-4238))
 await picture("owner_grounded_approach")
 print("OWNER GROUNDED RESULT roof=",stood_on_roof," final=",pos()," HP=",hp()," resets=",scene.resets," aperture40/upper60=",bands)
 if not require(not stood_on_roof and pos().y> -100 and scene.player.is_on_floor() and scene.resets==0 and hp()>0,"Recorded grounded approach blocked safely before invalid roof/fall"):return
 if not require(bands==[false,true],"Native35..45 opening stays clear; named45..100 upper wall is solid"):return
 print("PASS genuine owner ok-here F9 + recorded real keys/look: valid ground, no roof/fall/reset; two named source bands solid, native10-high aperture clear")
 quit()
