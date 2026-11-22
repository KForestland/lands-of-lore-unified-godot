extends "res://tests/generic_l10_sitting_test.gd"
## Targeted actualF5 continuation from the reproduced E61 stop; no supplied pose.
const INPUT:="res://tmp/generic_l10_inputs/generic_l10_switch61_blocked.json"
const PIN:="392236a7f7d48d3a09993c87cd0f0ba353d3e9e07d2be83341459550d3bfdc6e"
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Untouched actualF5 at reproduced switch61 stop"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Slots.slot_path(1))==OK,"Install actual earned standing F5 for realF9"):return
 await tap(KEY_F9);await adopt()
 var barrel:Node=scene.get_node("L10Barrel")
 if not require(area=="L10_DC" and hp()>0 and scene.resets==0 and not barrel.state().switch and scene.get_node("L10Tombs").opened("109"),"ActualF9 restores living switch approach after earned white109"):return
 # The mounting wall remains physically solid. The former aim point is behind it.
 var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,Vector3(-1515,43,-2984),1,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 if not require(not hit.is_empty() and hit.collider==scene.get_node("HeightBoundaryCollision") and absf(hit.position.z+2987)<0.01,"Original mounting wall still occludes the former aim point"):return
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 var low:=Vector3(INF,INF,INF);var high:=-low;var samples:=0
 for face in pack.faces:
  if face.get("placement_kind")!="static_assembly" or face.get("source_index")!=61 or face.get("child")!=236:continue
  for point in face.points:
   var v:=Vector3(point[0],point[1],point[2]);low=low.min(v);high=high.max(v);samples+=1
 var handle_center:Vector3=(low+high)*0.5
 await look(barrel.SWITCH);await frames(4)
 var before:String=prompts()
 await act(barrel.SWITCH,"ActualE on original handle61 in front of its solid mounting wall")
 if not barrel.state().switch:await picture("switch61_regression_stop")
 if not require(before.contains("E — Flip switch") and barrel.state().switch and scene.progression.travel[74]>0,"Visible prompt and first realE flip61/open caretaker74"):return
 if not require(samples>0 and barrel.SWITCH.distance_to(handle_center)<0.001,"Aim uses the published native61/236 handle centre"):return
 if not await checkpoint("switch61_opened_regression"):return
 var old_host:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old_host and hp()>0 and scene.resets==0 and scene.get_node("L10Barrel").state().switch and scene.progression.travel[74]>0,"ActualF5/F9 retains switch61 and caretaker74 open"):return
 print("PASS switch61: solid mounting wall kept; native handle aimed, visible prompt/first actualE opens74, actualF5/F9 preserves it; untouched earned checkpoint continuation, no supplied pose/health/clock/action calls")
 quit()
