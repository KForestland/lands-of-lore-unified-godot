extends SceneTree
const Save=preload("res://scripts/lol2/act2_save.gd")
var failures:=0
func check(ok: bool,why: String)->bool:
 if not ok:failures+=1;printerr("FAIL tomb earned: ",why)
 return ok
func _initialize():run.call_deferred()
func peaceful(pop: Node,id: String)->bool:
 if id.is_empty():return false
 if pop.peaceful_actor(id):return true
 var definition: int=int(pop.State.actor_row(pop.src,id).definition)
 return bool(pop.src.definitions[str(definition)].get("peaceful_adapter",false))
func combat_tick_budget()->int:return 6000
func combat_spark()->bool:return true
func heal_threshold()->int:return 18
func combat_candidate(_scene: Node,_id: String)->bool:return true
func fight_nearby(scene: Node)->bool:
 var pop=scene.act2_creatures
 for tick in combat_tick_budget():
  var target:=""
  var distance:=85.0
  for id in pop.bodies:
   if not pop.state.actors[id].present or pop.state.actors[id].health<=0 or peaceful(pop,id):continue
   var d: float=pop.bodies[id].global_position.distance_to(scene.player.global_position)
   if d<distance and combat_candidate(scene,id):distance=d;target=id
  if target.is_empty():return true
  if tick%300==0:print("FIGHT ",target," hp ",pop.state.actors[target].health," distance ",distance," active ",pop.world_active()," aimed ",pop.aimed()," player ",scene.player.position," body ",pop.bodies[target].global_position)
  if not check(scene.starting_magic.health()>0,"survived earned combat"):return false
  var point: Vector3=pop.bodies[target].global_position+Vector3.UP*24
  scene.camera.look_at(point,Vector3.UP)
  if scene.starting_magic.health()<heal_threshold():
   scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
  if not pop.aimed().is_empty() and not peaceful(pop,pop.aimed()):
   pop.strike()
   if combat_spark() and pop.state.actors[target].health>100 and scene.starting_magic.health()>=heal_threshold():
    scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  await physics_frame
 return check(false,"combat timeout")
func pickup_route(route: Dictionary)->Array:return route.pickup
func reached_waypoint(_scene: Node,_label: String,_index: int)->void:pass
func after_pickup(_scene: Node)->bool:return true
func walk(scene: Node,points: Array,label: String)->bool:
 for i in points.size():
  var goal:=Vector3(points[i][0],0,points[i][1])
  var reached:=false
  for tick in maxi(240,int(scene.player.position.distance_to(goal)*0.7)+180):
   await physics_frame
   if not await fight_nearby(scene):return false
   var delta: Vector3=goal-scene.player.position;delta.y=0
   if delta.length()<8:reached=true;break
   scene.move_grounded(delta.normalized(),scene.player.get_physics_process_delta_time())
  if not reached:
   for hit in scene.player.get_slide_collision_count():
    var collision=scene.player.get_slide_collision(hit)
    print("WALK HIT ",collision.get_collider().get_path()," normal ",collision.get_normal()," position ",collision.get_position())
  if not check(reached,"%s point%d at %s goal%s"%[label,i,scene.player.position,goal]):return false
  reached_waypoint(scene,label,i)
  if i%10==0:print("WALK ",label," ",i," at ",scene.player.position)
 return true
func run():
 # Input is an actual earned STORY-006 save, produced by l10_gate_earned_test.
 var input:=Save.read_save("res://tmp/l10_gate_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),"earned gate input: "+input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"load earned gate input"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 # Headless display cannot capture a mouse. Waive only that existing interface
 # admission gate; combat, mana, cooldown, health and quest state remain live.
 scene.starting_magic.interface_request=true
 scene.progression.change_scene_enabled=false
 await physics_frame
 for height in [32.0,-80.0]:
  var ray=PhysicsRayQueryParameters3D.create(Vector3(-100,height,-1550),Vector3(0,height,-1550),512)
  var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  check(hit.is_empty() if height>0 else not hit.is_empty(),"catacomb wall blocks below its ceiling only at height "+str(height))
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_tomb_walk.json"))
 if not await walk(scene,pickup_route(route),"pickup"):quit(1);return
 var id:="act2:L10_DC:item44"
 scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
 if not check(scene.act2_items.take(id),"source globe pickup"):quit(1);return
 if not await after_pickup(scene):
  scene.queue_free();await process_frame
  quit(0 if failures==0 else 1);return
 if not await walk(scene,route.charger,"charger"):quit(1);return
 var charger=scene.get_node("Act2Chargers")
 scene.camera.look_at(charger.globes["L10:yellow"].global_position,Vector3.UP)
 if not check(charger.interact("L10:yellow","insert",id).ok,"charge earned globe"):quit(1);return
 if not check(charger.interact("L10:yellow","retrieve").ok,"retrieve earned globe"):quit(1);return
 if not await walk(scene,route.door,"tomb"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_tomb_approach_save.json").is_empty(),"earned approach checkpoint")
 var tomb=scene.get_node("L10Tombs")
 scene.camera.look_at(tomb.aims["87"],Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not tomb.offer("87","wrong").ok and before==scene.carried_collected,"wrong offer without loss")
 var offered: Dictionary=tomb.offer("87",id+":charged:yellow")
 if not check(offered.ok,"matching globe opens template22 door88: "+str(offered)):quit(1);return
 check(tomb.bodies["87"].collision_layer==0 and tomb.bodies["91"].collision_layer!=0,"only matching door collider opens")
 check(not tomb.offer("87",id+":charged:yellow").ok,"duplicate use refused")
 var path:="res://tmp/l10_tomb_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"earned tomb save")
 check(scene._quickload_unrecorded(path).is_empty(),"earned tomb reload")
 tomb.restore()
 check(tomb.opened("87") and id+":charged:yellow" not in scene.carried_collected,"door and consumption persist")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned gate save -> catacomb globe -> gold charger -> tomb87/door88 -> actual save/reload; no seeding")
 quit(0 if failures==0 else 1)
