extends "res://tests/l9_chapel_earned_test.gd"
func walk(scene:Node,points:Array,label:String)->bool:
 for index in points.size():
  var goal:=Vector3(points[index][0],0,points[index][1])
  var reached:=false
  var prior:Vector3=scene.player.position
  var stalled:=0
  for tick in 1600:
   if not await fight_nearby(scene):return false
   var d:Vector3=goal-scene.player.position;d.y=0
   if d.length()<8 and scene.player.is_on_floor():reached=true;break
   if scene.player.position.distance_to(prior)<0.05:stalled+=1
   else:stalled=0
   prior=scene.player.position
   if stalled==20 and scene.player.is_on_floor():
    check(scene.request_jump(),"actual jump at original stair lip");print("STAIR jump ",index," ",scene.player.position);stalled=0
   scene.move_grounded(d.normalized(),1.0/60);await physics_frame
   if tick%300==0:print("ALTAR WALK ",label," point",index," ",scene.player.position)
  if not check(reached,label+" point"+str(index)+" at "+str(scene.player.position)):return false
 return true
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_belial_combat_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="aca45000e5b33d3ac4209a7d5a6b29672d0973b317585203ea693ce108d74689","qualified boss combat input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned boss death input"):quit(1);return
 prepare(scene)
 var altar=scene.get_node("L13Altar")
 var legs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_altar_walk.json"))
 if not await walk(scene,legs[0],"Dreamstone order guard"):quit(1);return
 scene.camera.look_at(altar.STONE,Vector3.UP)
 var before:Array=scene.carried_collected.duplicate()
 check(not altar.take_stone().ok and scene.carried_collected==before,"actual premature stone attempt refuses without mutation")
 if not await walk(scene,legs[1],"sword altar"):quit(1);return
 scene.camera.look_at(altar.ALTAR,Vector3.UP)
 var sword:String=scene.equipped_item
 var result:Dictionary=altar.enchant()
 if not check(result.ok,"actual equipped sword offered: "+str(result)):quit(1);return
 check(sword not in scene.carried_collected and scene.equipped_item==altar.State.DARK and altar.State.DARK in scene.carried_collected,"current Fine Longsword transforms and equips once")
 check(not altar.enchant().ok,"duplicate enchantment refused")
 if not await walk(scene,legs[2],"Dreamstone after sword"):quit(1);return
 scene.camera.look_at(altar.STONE,Vector3.UP)
 if not check(altar.take_stone().ok and altar.State.STONE in scene.carried_collected,"earned Dreamstone taken after sword"):quit(1);return
 check(not altar.take_stone().ok,"duplicate stone refused")
 var error:String=scene._quicksave_unrecorded("res://tmp/l13_altar_earned_save.json")
 if not check(error.is_empty(),"altar save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l13_altar_earned_save.json")
 check(error.is_empty(),"altar load: "+error)
 check(scene.equipped_item==altar.State.DARK and scene.carried_collected.count(altar.State.DARK)==1 and scene.carried_collected.count(altar.State.STONE)==1,"equipment and retained stone survive save/reload once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("ALTAR completed ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual boss-death route -> premature stone refusal -> equipped sword Kit conversion -> Dreamstone -> equipped save/reload")
 quit(0 if failures==0 else 1)
