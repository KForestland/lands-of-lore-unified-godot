extends SceneTree
const Save=preload("res://scripts/lol2/act2_save.gd")
const Source=preload("res://scripts/lol2/act2_items_catalog.gd")
var failures:=0
func check(ok: bool, why: String)->bool:
 if not ok:failures+=1;printerr("FAIL charger live: ",why)
 return ok
func _initialize():run.call_deferred()
func run():
 # Local production encounter test: source-placed standing start beside each globe.
 # Pickup and subsequent walking/charging are earned; this is NOT the campaign gate route.
 for spec in [["L10:yellow","act2:L10_DC:item44"],["L10:blue","act2:L10_DC:item43"],["L9:white","act2:L10_DC:item44"]]:
  set_meta("lol2_map_start_selector",1)
  var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
  scene.adapter_exit_seeds=false
  root.add_child(scene);current_scene=scene
  for i in 1500:
   await process_frame
   if scene.ready_for_review:break
  scene.player.set_physics_process(false)
  var charger=scene.get_node("Act2Chargers")
  var items=scene.act2_items
  var id:String=spec[1]
  var p:Vector3=items.sprites[id].global_position
  scene.player.position=p+Vector3(0,32,60)
  await physics_frame
  scene.camera.look_at(items.aim_point(id),Vector3.UP)
  if not check(items.take(id),"actual source globe pickup "+id):quit(1);return
  check(not items.take(id),"duplicate world pickup refused")
  var target:String=spec[0]
  if target=="L9:white":
   # Actual host transport preserves the locally earned empty globe into L9.
   var handoff:Dictionary=scene.area_handoff()
   scene.queue_free();await process_frame
   set_meta("lol2_act2_handoff",handoff)
   set_meta("lol2_map_start_selector",1)
   scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
   scene.adapter_exit_seeds=false
   root.add_child(scene);current_scene=scene
   for i in 1500:
    await process_frame
    if scene.ready_for_review:break
   scene.player.set_physics_process(false)
   charger=scene.get_node("Act2Chargers")
   scene.player.position=charger.globes[target].global_position+Vector3(0,32,65)
   await physics_frame
   check(id in scene.carried_collected,"earned empty globe survives actual L9 handoff")
  for tick in 240:
   await physics_frame
   scene.camera.look_at(charger.globes[target].global_position,Vector3.UP)
   if charger.reachable(target):break
   var delta:Vector3=charger.globes[target].global_position-scene.player.global_position
   delta.y=0
   scene.player.velocity=delta.normalized()*90
   scene.player.velocity.y=-32
   scene.player.move_and_slide()
  if not charger.reachable(target):
   var ray=PhysicsRayQueryParameters3D.create(scene.camera.global_position,charger.globes[target].global_position,1,[scene.player.get_rid()])
   print("ALTAR RAY ",scene.camera.global_position," -> ",charger.globes[target].global_position," hit ",scene.get_world_3d().direct_space_state.intersect_ray(ray))
  if not check(charger.reachable(target),"physical pickup-to-altar reach "+target+" at "+str(scene.player.position)):quit(1);return
  var before:Array=scene.carried_collected.duplicate()
  check(not charger.interact(target,"insert","wrong").ok and scene.carried_collected==before,"wrong offer preserves inventory")
  if not check(charger.interact(target,"insert",id).ok,"insert earned globe"):quit(1);return
  check(charger.globes[target].visible and id not in scene.carried_collected,"occupied globe is displayed and no longer carried")
  var path:="res://tmp/act2_charger_live_save.json"
  var error:String=scene._quicksave_unrecorded(path)
  if not check(error.is_empty(),"occupied actual save: "+error):quit(1);return
  error=scene._quickload_unrecorded(path)
  if not check(error.is_empty(),"occupied actual reload: "+error):quit(1);return
  charger.restore()
  check(charger.globes[target].visible,"occupied visual restored without reward replay")
  scene.camera.look_at(charger.globes[target].global_position,Vector3.UP)
  check(charger.interact(target,"retrieve").ok,"retrieve once after reload")
  var output:=id+":charged:"+target.get_slice(":",1)
  check(scene.carried_collected.count(output)==1 and not charger.globes[target].visible,"one output and empty altar")
  check(not charger.interact(target,"retrieve").ok,"second retrieve refused")
  check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"retrieved save/reload")
  check(scene.carried_collected.count(output)==1,"retrieved output persists")
  DirAccess.remove_absolute(path)
  scene.queue_free();await process_frame
 if failures==0:print("PASS production yellow/blue/white: local source pickup -> physical altar approach -> occupied real save/reload -> one retrieval. Not campaign gate or rendered qualification.")
 quit(0 if failures==0 else 1)
