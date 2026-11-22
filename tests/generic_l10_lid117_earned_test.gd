extends "res://tests/generic_l10_sitting_test.gd"
## Earned-save continuation; actual F2/F9 then W/mouse/E. No supplied poses.
const INPUT:="res://tmp/generic_l10_inputs/generic_l10_lid117_yellow44.json"
const PIN:="a57ae908a289c44d2be4593327d19c8dbb7295ac4c63b99aa66bdb76768eba09"
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
var diagnostics:Array=[]
var ground_trace:RefCounted
func record(tag:String):
 var world:Node=scene.get_node("GenericObjects")
 var target:Vector3=scene.progression.hinges[117].transform*scene.progression.mover_bounds[117].get_center()
 var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,target,1|2,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 var row:Dictionary={"tag":tag,"position":str(pos()),"target":str(target),"aimed":world.aimed(),"phase":scene.progression.native.field("movable:117",Rules.PHASE,0),"resets":scene.resets,"health":hp(),"prompt":prompts(),"clock":[Engine.time_scale,Engine.physics_ticks_per_second]}
 if not hit.is_empty():row.hit={"path":str(hit.collider.get_path()),"position":str(hit.position),"normal":str(hit.normal),"face_index":hit.get("face_index",-1),"point":[hit.position.x,hit.position.y,hit.position.z]}
 diagnostics.append(row);print("LID117 ",JSON.stringify(row))
 var f:=FileAccess.open("user://tests/generic_l10_sitting/lid117_reach.json",FileAccess.WRITE);f.store_string(JSON.stringify(diagnostics,"  "));f.close()
 return row
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Untouched actual v4 yellow44 F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Slots.slot_path(1))==OK,"Install earned yellow44 checkpoint for actualF9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0 and scene.resets==0,"Living earned yellow44 arrival"):return
 var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/height_boundary/L10_DC.json"))
 if not require("source_wall|2010,-3046|2150,-3046|0|130" in packet.block_face_keys and scene.get_node("HeightBoundaryCollision").collision_layer&1,"Wall204 remains enabled in the actual collision body"):return
 if not require(scene.progression.native.field("movable:117",Rules.PHASE,0)==0,"Lid117 begins shut in earned checkpoint"):return
 ground_trace=load("res://tests/helpers/walked_ground_recorder.gd").new(self,"user://tests/generic_l10_sitting/lid117_walked_poses.jsonl")
 var route:Dictionary=fixture("l10_lid117_walk.json")
 var initial_route:Dictionary=fixture("l10_tomb_walk.json")
 var back:Array=initial_route.charger.duplicate(true);back.reverse()
 if not await walk(back,"leave actual yellow charger"):quit(1);return
 back=initial_route.pickup.duplicate(true);back.reverse()
 if not await walk(back,"earned return up Cemetery stairs"):quit(1);return
 if not await walk(route.socket99,"earned surface approach to socket99"):record("socket99 approach stalled");quit(1);return
 var tombs:Node=scene.get_node("L10Tombs")
 if not require(not tombs.opened("99") and "act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"Earned yellow44 and shut door100 before actualE99"):return
 await act(tombs.aims["99"],"Offer actual yellow44 at socket99 to open door100")
 if not require(tombs.opened("99") and tombs.bodies["99"].collision_layer==0,"RealE spends yellow44 and clears door100"):return
 if not await checkpoint("lid117_door100_opened"):return
 if not await walk(route.old_stand,"through earned door100 to former lid117 stand"):
  record("old stand approach stalled");await picture("lid117_route_stop");quit(1);return
 var target:Vector3=scene.progression.hinges[117].transform*scene.progression.mover_bounds[117].get_center()
 await look(target);await frames(4)
 var front:Dictionary=record("former table stand before E")
 if not require(front.get("hit",{}).get("path","").ends_with("HeightBoundaryCollision") and absf(front.hit.point[2]+3046)<0.02,"Former stand is occluded by retained wall204"):return
 await picture("lid117_front_blocked")
 await act(target,"Actual E from former lid117 stand");await ticks(60);record("former table stand after E")
 if int(scene.progression.native.field("movable:117",Rules.PHASE,0))!=1:
  if not await walk(route.east_stand,"walk around east side of chest117"):
   record("east approach stalled");await picture("lid117_route_stop");quit(1);return
  await look(target);await frames(4);record("east stand before E")
  var aimed:Dictionary=scene.get_node("GenericObjects").aimed()
  if not require(aimed.get("kind")=="movable" and int(aimed.get("id",-1))==117,"Real walk reaches a clear crosshair stand for lid117"):return
  await picture("lid117_east_before")
  await act(target,"Actual E from walked east stand");await ticks(60);record("east stand after E")
 await picture("lid117_result")
 if not require(int(scene.progression.native.field("movable:117",Rules.PHASE,0))==1,"Player-reachable realE opens lid117"):return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Lid117 route has no recovery/death/stall"):return
 if not await checkpoint("lid117_east_opened"):return
 ground_trace.finish()
 print("PASS lid117: untouched earned F5 -> actualF9 -> realW stand -> actualE lid open; ordinary1/60, zero teleports, no health/clock/action writes")
 quit()
