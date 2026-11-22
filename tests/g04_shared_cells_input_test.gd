extends "res://tests/g15_expel_input_test.gd"
## Actual Shift+Q writes cell52, real F5/F9; cross-area framework transfers are
## explicit aids, not an earned L20 -> L14 -> L20 route.
func transfer_for_census(level:int,selector:int,path:String)->bool:
 scene.progression._change_level({"level":level,"selector":selector,"scene":path})
 for i in 2400:
  await process_frame
  if is_instance_valid(current_scene) and current_scene.scene_file_path==path and current_scene.get("ready_for_review")==true:break
 await adopt()
 return require(scene.scene_file_path==path and hp()>0 and scene.resets==0,"Disclosed native transfer retains living player")
func disk_cycle(tag:String)->bool:
 if not await super.disk_cycle(tag):return false
 if not require(scene.progression.native.locals_e58.get(52,-1)==1,"Actual Expel writer survives own-area F5/F9"):return false
 if not await transfer_for_census(14,0,"res://scenes/lol2/maps/L14_HT.tscn"):return false
 if not require(scene.progression.native.locals_e58.get(52,-1)==1,"Game-wide cell52 follows player into another level, without L19 history bridge"):return false
 if not await super.disk_cycle(tag+"_other_level"):return false
 if not require(scene.progression.native.locals_e58.get(52,-1)==1,"Real F5/F9 on other level retains global cell52"):return false
 if not await transfer_for_census(20,0,"res://scenes/lol2/maps/L20_BB.tscn"):return false
 return require(scene.progression.native.locals_e58.get(52,-1)==1,"Return to writer level shares same global cell")
