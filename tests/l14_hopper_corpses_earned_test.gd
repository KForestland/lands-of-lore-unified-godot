extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hopper_gallery_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="48b0e0312e923bb505ddef95d5ad1b54b29c391bfb3345c62de9137cc9ca8e6a","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var puzzle=scene.get_node("L14HopperPlatform");var pop=scene.act2_creatures
 check(not puzzle.take("91").ok,"living hopper cannot become corpse item")
 var all_dead:bool=false
 for i in 3600:
  if not await fight_nearby(scene):quit(1);return
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  all_dead=true
  for id in puzzle.IDS:
   if pop.state.actors[id].health>0:all_dead=false
  if all_dead:break
  if i%600==0:print("HOPPER FIGHT ",i," ",pop.state.actors["91"]," ",pop.state.actors["95"])
 if not check(all_dead and puzzle.state().activated,"five actual source hoppers defeated through production combat"):quit(1);return
 for i in 180:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 for id in puzzle.IDS:
  check(absf(pop.bodies[id].position.y-300)<2,"actual corpse settles on gallery floor")
  scene.camera.look_at(pop.bodies[id].global_position+Vector3.UP*8,Vector3.UP)
  check(not puzzle.take(id,scene.carried_collected.size()).ok,"full corpse pickup refused")
  paused=true;check(not puzzle.take(id).ok,"paused corpse pickup refused");paused=false
  if not check(puzzle.take(id).ok,"unique actual hopper corpse pickup "+id):quit(1);return
  check(not puzzle.take(id).ok,"corpse cannot duplicate")
 for id in puzzle.IDS:check(puzzle.item(id) in scene.carried_collected,"five distinct earned bodies carried")
 check(scene.player.position.y>330,"combat remained on raised gallery")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_hopper_corpses_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_hopper_corpses_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned gallery -> original five hoppers actual combat -> unique corpse pickups/save-reload")
 quit(0 if failures==0 else 1)
