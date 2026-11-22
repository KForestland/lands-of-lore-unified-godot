extends "res://tests/generic_l10_input_test.gd"
## Local ownership/codec qualification, not an earned walk: three supplied poses and a genuine C15 packet.
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
const Slots=preload("res://scripts/lol2/game_save.gd")
const AreaSave=preload("res://scripts/lol2/act2_save.gd")
var receipts:Array=[]
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1)
 return ok
func pose(at:Vector3,aim:Vector3):
 scene.player.position=at;scene.player.velocity=Vector3.ZERO
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 var offset:Vector3=aim-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events()
 scene.set_physics_process(true)
 # A transform change does not invalidate CharacterBody3D's cached floor flag.
 # Let the body process at the new position before accepting a grounded fixture.
 for tick in 4:await physics_frame
 for tick in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 for tick in 3:await physics_frame
 return check(scene.player.is_on_floor(),"Local fixture settles on real floor")
func action(id:int)->bool:
 var point:Vector3=scene.progression.hinges[id].global_transform*scene.progression.mover_bounds[id].get_center()
 var offset:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events()
 for tick in 3:await physics_frame
 var target:Dictionary=scene.get_node("GenericObjects").aimed()
 if not check(target.get("kind")=="movable" and int(target.id)==id,"Real aim tracks current geometry of%d; got%s"%[id,target]):return false
 await key(KEY_E)
 return true
func state(id:int)->Dictionary:
 var result:Dictionary={};var ref:String="movable:%d"%id
 for field in Rules.FIELDS:result[field]=scene.progression.native.field(ref,field,0)
 return result
func motion_matches(id:int,expected:Dictionary)->bool:
 var actual:=state(id)
 for field in Rules.FIELDS:
  if int(actual[field])!=int(expected[field]):return false
 return true
func load_slot()->bool:
 var old:int=scene.get_instance_id()
 await key(KEY_F9)
 for tick in 1800:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old and current_scene.get("ready_for_review")==true:
   var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
   if session.pending_resume.is_empty() and not session.changing_scene:break
 if not check(is_instance_valid(current_scene) and current_scene.get_instance_id()!=old,"Real F9 replaces the host"):return false
 scene=current_scene;scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 return check(scene.resets==0,"Slot load did not trigger a fall recovery")
func slot_packet()->Dictionary:
 var read:=Slots.read_document(Slots.slot_path(1))
 if not check(read.error.is_empty(),"RealF5 slot envelope validates"):return {}
 return read.state.area_save
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered ownership/codec qualification"):return
 folder="user://tests/generic_l10_persistence";DirAccess.make_dir_recursive_absolute(folder)
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review:break
 var path:="res://assets/lol2/generated/playtest_starts/c15_l10_dc.json"
 if not check(FileAccess.get_sha256(path)=="6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","Canonical fixture pin"):return
 var incoming:=AreaSave.read_save(path,"lol2-restoration-map-L10_DC")
 if not check(incoming.error.is_empty() and scene.apply_save(incoming.state).is_empty(),"Genuine starting packet applies"):return
 scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 for row in [
  {"id":86,"at":Vector3(1120,32.05,-1296),"aim":Vector3(1029,40,-1296)},
  {"id":107,"at":Vector3(1283,32,-3290),"aim":Vector3(1283,39,-3368)},
  {"id":126,"at":Vector3(-492,32,-2467),"aim":Vector3(-492,40,-2531)}]:
  var id:int=row.id
  if not await pose(row.at,row.aim):return
  if not check(int(state(id)[Rules.PHASE])==0,"Native closed precondition %d"%id):return
  var target:Dictionary=scene.get_node("GenericObjects").aimed()
  if not check(target.get("kind")=="movable" and int(target.id)==id,"Input really aims identity %d; got%s"%[id,target]):return
  var closed:Transform3D=scene.progression.hinges[id].transform
  await key(KEY_F5)
  var saved:=slot_packet()
  if not check(not saved.is_empty() and int(saved.quests.generic_objects.areas.L10_DC.movables[str(id)][Rules.PHASE])==0,"RealF5 captures closed logical/physical owner %d"%id):return
  if not await action(id):return
  for tick in 60:await physics_frame
  var opened:Transform3D=scene.progression.hinges[id].transform
  if not check(int(state(id)[Rules.PHASE])==1 and not opened.is_equal_approx(closed),"RealE moves native geometry %d"%id):return
  await shot("open%d"%id)
  if not await load_slot():return
  if not check(int(state(id)[Rules.PHASE])==0 and scene.progression.hinges[id].transform.is_equal_approx(closed),"FreshF9 restores closed state and geometry %d"%id):return
  if not await action(id):return
  for tick in 60:await physics_frame
  var area_packet:Dictionary=AreaSave.snapshot_host(scene)
  await key(KEY_F5)
  if not await action(id):return
  for tick in 60:await physics_frame
  if not check(int(state(id)[Rules.PHASE])==5,"Reuse closes %d"%id):return
  if not await load_slot():return
  if not check(int(state(id)[Rules.PHASE])==1 and scene.progression.hinges[id].transform.is_equal_approx(opened),"FreshF9 restores opened state and geometry %d"%id):return
  if not await action(id):return
  for tick in 60:await physics_frame
  var log_count:int=scene.progression.route_log.size()
  if not check(scene.apply_save(area_packet).is_empty() and int(state(id)[Rules.PHASE])==1 and scene.progression.hinges[id].transform.is_equal_approx(opened),"Per-area packet restores the same opened presentation %d"%id):return
  if not check(scene.progression.route_log.size()==log_count,"Restore does not replay use/hooks %d"%id):return
  var bad:Dictionary=area_packet.duplicate(true);bad.quests.generic_objects.areas.L10_DC.movables[str(id)][Rules.POSITION]=-1
  var prior:Vector3=scene.player.position
  if not check(not scene.apply_save(bad).is_empty() and scene.player.position==prior and scene.progression.hinges[id].transform.is_equal_approx(opened),"Malformed object packet refuses before pose/geometry mutation %d"%id):return
  receipts.append({"id":id,"closed_slot":true,"opened_slot":true,"area_packet":true,"invalid_refused":true,"no_replay":true})
  if id==107:
   if not await action(id):return
   await key(KEY_F5)
   var mid:=slot_packet();var motion:Dictionary=mid.quests.generic_objects.areas.L10_DC.movables[str(id)]
   if not check(int(motion[Rules.PHASE])==3 and int(motion[Rules.POSITION])>0 and int(motion[Rules.POSITION])<45*Rules.FIXED,"RealF5 captures in-flight height motion"):return
   for tick in 60:await physics_frame
   if not check(scene.apply_save(mid).is_empty() and motion_matches(id,motion),"Per-area restore recreates exact in-flight clock/position/phase"):return
   var expected:Transform3D=Rules.transform_for(0,int(motion[Rules.POSITION]),scene.progression.hinge_origin[id])
   if not check(scene.progression.hinges[id].transform.is_equal_approx(expected),"In-flight body and mesh restore together"):return
   for tick in 60:await physics_frame
   if not check(int(state(id)[Rules.PHASE])==5,"Restored motion finishes naturally"):return
   if not await load_slot():return
   for tick in 60:await physics_frame
   if not check(int(state(id)[Rules.PHASE])==5,"Fresh slot restores mid-motion and finishes"):return
 # Explicit codec fixtures, distinct from the untouched historical C15 input.
 # The old packet shape must reset objects after they actually moved.
 var opened_packet:Dictionary=AreaSave.snapshot_host(scene)
 var pre_pilot:Dictionary=opened_packet.duplicate(true);pre_pilot.quests.erase("generic_objects")
 if not check(int(state(126)[Rules.PHASE])==1,"A moved turn126 makes old-key absence a non-vacuous restore test"):return
 if not check(scene.apply_save(pre_pilot).is_empty(),"Pre-pilot packet shape without generic key loads after objects moved"):return
 for id in [86,107,126]:
  var placement:PackedByteArray=scene.progression.native.placements["movable:%d"%id]
  if not check(motion_matches(id,Rules.initial(placement)),"Absent generic key restores source defaults%d"%id):return
 if not check(scene.apply_save(opened_packet).is_empty() and int(state(126)[Rules.PHASE])==1,"Restore the moved positive control before testing a census omission"):return
 var partial:Dictionary=opened_packet.duplicate(true)
 partial.quests.generic_objects.areas.L10_DC.movables.erase("126")
 partial.quests.generic_objects.areas.L10_DC.movables["999999"]={"future":"opaque"}
 partial.quests.generic_objects.areas["FUTURE_AREA"]={"future":"opaque"}
 if not check(scene.apply_save(partial).is_empty(),"Partial census and unknown ids/areas load into a live host"):return
 if not check(motion_matches(126,Rules.initial(scene.progression.native.placements["movable:126"])) and motion_matches(86,opened_packet.quests.generic_objects.areas.L10_DC.movables["86"]),"Omitted126 uses source defaults while known86 keeps its saved motion"):return
 receipts.append({"pre_pilot_key_absence":true,"partial_census_live_restore":true,"unknown_rows_ignored":true})
 if not check(scene.resets==0,"No load/carry fall reset"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify({"local_component":true,"setup":"Pinned C15 packet, three supplied poses, movement/NPC clocks held after physical settle","cases":receipts,"real_keys":["E","F5","F9"],"resets":scene.resets},"  "));file.close()
 print("PASS B local realE/F5/F9 ownership: slide86,height107,turn126; closed/open fresh slots, per-area exact motion restore, malformed atomic refusal, missing old key/source defaults and live partial-census restore; supplied poses, no earned-walk claim")
 quit()
