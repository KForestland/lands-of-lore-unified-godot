extends "res://tests/generic_l10_robot_socket_test.gd"
func main():
 if not await boot(SOCKET_INPUT,SOCKET_PIN):return
 var path:="user://tests/generic_l10_robot_checks/recorder.jsonl"
 var record=load("res://tests/helpers/walked_ground_recorder.gd").new(self,path)
 var before:Vector3=pos()
 var health:int=hp()
 for tick in 10:record.record_now()
 if not check(pos()==before and hp()==health and scene.resets==0,"Synchronous recorder reads do not move or damage Luther"):return
 var bounds:Dictionary=record.body_bounds(scene.player)
 if not check(not bounds.is_empty() and bounds.feet<pos().y and bounds.top>pos().y,"Actual fitted contact-shape bounds recorded"):return
 await look(Vector3(pos().x,scene.camera.global_position.y,pos().z+100))
 key_event(KEY_W,true);await ticks(15);key_event(KEY_W,false);await ticks(4)
 record.finish()
 var lines:PackedStringArray=FileAccess.get_file_as_string(path).strip_edges().split("\n")
 if not check(lines.size()>20 and JSON.parse_string(lines[0]).format=="lol2-walked-ground-v1","Dense real physics-frame output exists"):return
 var first:Dictionary=JSON.parse_string(lines[1]);var last:Dictionary=JSON.parse_string(lines[-1])
 if not check(first.discontinuity=="new_area_host_or_loaded_host" and last.physics_frame>first.physics_frame and last.resets==0,"Physics clock and host boundaries retained without recovery"):return
 if not check(pos().distance_to(before)>2 and Vector3(last.position[0],last.position[1],last.position[2]).distance_to(pos())<2,"ActualW movement is reflected in actual pose series"):return
 print("PASS read-only walked-ground recorder: synchronous no mutation, actual body bounds, dense physics poses and actualW,0resets")
 quit()
