extends "res://tests/generic_l10_robot_socket_test.gd"
var cases:Array=[]
func run_case(break247:bool)->bool:
 if not await boot("res://tmp/generic_l10_inputs/generic_robot_front247.json","694510565f4f29e8be5685f6c759d7a5997c68be66100ddff0d466177780d13d"):return false
 var world:Node=scene.get_node("GenericObjects")
 if not check(world.snapshot_area().breakables["247"].life==100 and world.snapshot_area().breakables["248"].life==100 and pos().y>30,"Both original fronts begin intact, player on yard floor"):return false
 if break247:
  for hit in 30:
   if world.snapshot_area().breakables["247"].life==0:break
   for tick in 120:
    await physics_frame
    if scene.act2_creatures.strike_remaining<=0.0:break
   await look(Vector3(1383,10,-3956));await lclick();await frames(6)
  if not check(world.snapshot_area().breakables["247"].life==0,"Actual left strikes break247 before comparison"):return false
 # OrdinaryW must meet the original vertical shelf wall, not pass beneath it.
 for tick in 180:
  var goal:=Vector3(1424.18,scene.camera.global_position.y,-3933.83)
  turn_step(goal,false);key_event(KEY_W,absf(yaw_error(goal))<0.6)
  await physics_frame
 key_event(KEY_W,false);await ticks(8)
 var wall_hit:=PhysicsRayQueryParameters3D.create(Vector3(1415,30,-3980),Vector3(1415,30,-3930),1)
 wall_hit.exclude=[scene.player.get_rid()]
 var wall:Dictionary=scene.player.get_world_3d().direct_space_state.intersect_ray(wall_hit)
 if not check(pos().y>30 and pos().z< -3960 and not wall.is_empty() and absf(wall.position.z+3957)<0.1,"Original0..60sourcewall stops actualW beneath upperfront248"):return false
 var walked:=await walk([[1405,-3968],[1271,-4060],[1127,-4097],[1051,-4097],[887,-4161]],"safe ordinary return after shelf contact",{"no_fight":true})
 var row:Dictionary={"break247":break247,"walked":walked,"position":str(pos()),"resets":scene.resets,"life247":world.snapshot_area().breakables["247"].life,"life248":world.snapshot_area().breakables["248"].life,"wall_hit":str(wall.get("position","none"))}
 cases.append(row)
 print("ENTRY CASE broken247=",break247," at ",pos()," life248=",row.life248," resets=",scene.resets)
 return walked
func main():
 if not check(DisplayServer.get_name()!="headless","Rendered entry comparison"):return
 await run_case(false)
 await run_case(true)
 var dir:="user://tests/generic_l10_robot_checks";DirAccess.make_dir_recursive_absolute(dir)
 var file:=FileAccess.open(dir+"/ledge_entry.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"component comparisons from untouched original robot before247 save; actualW and actualleft, no cover mutation aids","cases":cases},"  "));file.close()
 if not check(cases.size()==2 and cases[0].life247==100 and cases[1].life247==0 and cases[0].life248==100 and cases[1].life248==100,"Intact and actual-broken247 comparison with248 intact in both"):return
 if not check(pos().y>=30 and not broken and scene.resets==0,"Player stays above yard floor on actualW contact and return, before/after247break"):return
 print("PASS supply ledge: actualW meets original1323edge2 wall with247 intact and after realleft breaks247;248intact, actualW returns on nativefloor,0resets")
 quit()
