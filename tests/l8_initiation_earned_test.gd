extends "res://tests/l9_chapel_earned_test.gd"
const Tribe=preload("res://scripts/lol2/l8_tribe_state.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_nine_silverleaf_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual nine-leaf village input"):quit(1);return
 prepare(scene)
 var tribe=scene.get_node("L8Tribe")
 var before:Array=scene.carried_collected.duplicate()
 var original_health:int=scene.starting_magic.health()
 var leaf:String=before.filter(func(id):return preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==117)[0]
 check(not tribe.offer("wrong").ok and scene.carried_collected==before,"wrong initiation offering refused")
 var result:Dictionary=scene.get_node("L8Journey").interact("initiation",leaf)
 if not check(result.ok,str(result)):quit(1);return
 check(leaf not in scene.carried_collected and scene.carried_collected.size()==before.size()-1,"Kit accepts exactly one earned leaf")
 check(not scene.starting_magic.world_active() and scene.actor_input_locked(),"original speech holds world/input")
 for i in 30:await physics_frame
 check(tribe.loaded==0 and tribe.voice.playing,"original shaman329 plays")
 var error:String=scene._quicksave_unrecorded("res://tmp/l8_initiation_intro_earned_save.json")
 if not check(error.is_empty(),"mid-intro save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l8_initiation_intro_earned_save.json").is_empty(),"mid-intro reload")
 paused=true
 var held:float=tribe.state().elapsed
 for i in 5:await process_frame
 check(tribe.state().elapsed==held,"intro pauses")
 paused=false
 for i in 1200:
  await physics_frame
  if tribe.state().phase=="fight":break
 if not check(tribe.state().phase=="fight","four original clips finish into arena"):quit(1);return
 check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(2679,-4187))<2,"earned original SHAMAN place call")
 check(scene.act2_creatures.state.actors["23"].present,"original arena candidate Daniel23 present")
 check(not tribe.offer(leaf).ok,"duplicate offering refused")
 var pop=scene.act2_creatures
 for i in 360:
  await physics_frame
  scene.camera.look_at(pop.bodies["23"].global_position+Vector3.UP*45,Vector3.UP)
  if pop.aimed()=="23":break
  var direction:Vector3=pop.bodies["23"].position-scene.player.position;direction.y=0
  scene.move_grounded(direction.normalized(),scene.player.get_physics_process_delta_time())
 check(pop.aimed()=="23","physical sparring reach")
 check(not pop.receive_damage("23",10000,false,20),"spell cannot turn initiation lethal")
 var checkpoint:=false
 for i in 6000:
  await physics_frame
  if tribe.state().phase=="complete":break
  scene.camera.look_at(pop.bodies["23"].global_position+Vector3.UP*45,Vector3.UP)
  pop.strike();scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if not checkpoint and tribe.state().daniel<400:
   checkpoint=true
   error=scene._quicksave_unrecorded("res://tmp/l8_initiation_fight_earned_save.json")
   if not check(error.is_empty(),"mid-bout save: "+error):quit(1);return
   check(scene._quickload_unrecorded("res://tmp/l8_initiation_fight_earned_save.json").is_empty(),"mid-bout reload")
 if not check(Tribe.member(tribe.state()),"nonlethal bout completes membership"):quit(1);return
 check(checkpoint,"actual sustained sparring before finish")
 check(scene.starting_magic.health()==original_health and pop.state.actors["23"].health==600,"campaign HP unchanged; neither participant killed")
 check(scene.carried_collected.size()==before.size()-1,"one leaf only; no invented reward")
 var path:="res://tmp/l8_initiation_earned_save.json"
 error=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"membership save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"membership reload")
 check(Tribe.member(tribe.state()) and not tribe.offer(leaf).ok,"saved membership does not repeat offering")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall recovery or arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual nine leaves -> Kit offering -> original SHAMAN329..332 with mid-save -> source arena placement -> sustained nonlethal Daniel23 bout/reload -> tribe membership")
 quit(0 if failures==0 else 1)
