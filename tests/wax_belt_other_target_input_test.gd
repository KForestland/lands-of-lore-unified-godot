extends "res://tests/item_belt_e_dawn_wax_input_test.gd"
## Unchanged owner Hive start, actual W exit; extra local item stands are explicit.
func _initialize():main.call_deferred()
func main():
 if not await owner(1):return
 await stand(Vector3(848,24,-4447));await look(Vector3(864,24,-4590))
 var old_id:int=scene.get_instance_id();scene.set_physics_process(true);set_key(KEY_W,true)
 for i in 600:
  await physics_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id:break
 set_key(KEY_W,false);scene=current_scene;await settled()
 if not check(is_instance_valid(scene.get("dawn")) and int(scene.dawn.state.locals["17"])==0 and WAX in scene.carried_collected,"Actual Jungle with native Wax gift still pending"):return
 var items:Node=scene.world_items
 for row in items.sprites:
  if not items.sprites[row].visible:continue
  var id:String=items.Catalog.id_of(row)
  if id in scene.carried_collected:continue
  var point:Vector3=items.sprites[row].global_position
  for offset in [Vector3(50,32,0),Vector3(-50,32,0),Vector3(0,32,50),Vector3(0,32,-50)]:
   await stand(point+offset);await look(items.aim_point(row));await ticks(2)
   if items.target()!=row:continue
   var target:Dictionary=Targets.find(scene)
   if not check(target.is_empty() or target.owner!=scene.dawn,"Aimed ordinary Jungle item is never shadowed by pending Dawn"):return
   var count:int=scene.carried_collected.size()
   await key(KEY_E);await ticks(3)
   if not check(id in scene.carried_collected and scene.carried_collected.size()==count+1 and WAX in scene.carried_collected and int(scene.dawn.state.locals["17"])==0,"Real E takes only the actual other Jungle item, not the Wax gift"):return
   if not check(Saves.validate(Saves.make_document(scene,10)).is_empty(),"Ordinary item action leaves a valid whole-game document"):return
   await frame("wax_other_jungle_target")
   print("PASS R144 real E ordinary Jungle pickup ",id," while two Wax copies await Dawn; actual W Hive exit, supplied local item stands/held-root/slot fixtures, no gift or item grant")
   quit();return
 check(false,"No uncollected, aimed source Jungle item stand found")
