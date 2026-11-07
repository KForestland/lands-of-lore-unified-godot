extends "res://tests/l9_chapel_earned_test.gd"
const Harvest=preload("res://scripts/lol2/l10_silverleaf_harvest.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_silverleaf_growth_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual grown Silverleaf input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_silverleaf_harvest_walk.json"))
 var leaves=scene.get_node("L10Silverleaf")
 check(not leaves.pick("wrong").ok and not leaves.pick("159").ok,"invalid and remote tree refusal")
 if not await walk(scene,route.leave,"leave Emperor"):quit(1);return
 for leg in route.trees:
  if not await walk(scene,leg.points,"Silverleaf tree"+leg.tree):quit(1);return
  scene.camera.look_at(leaves.aim(leg.tree),Vector3.UP)
  var before:Array=scene.carried_collected.duplicate()
  check(not Harvest.pick(leaves.harvest_state(),before,scene.quest_state.act2_items,leg.tree,before.size()).ok,"full inventory refuses without loss")
  check(scene.carried_collected==before,"capacity refusal preserves actual earned inventory")
  var result:Dictionary=leaves.pick(leg.tree)
  if not check(result.ok,str(result)):quit(1);return
  check(Harvest.item_id(leg.tree) in scene.carried_collected,"source tree leaf carried")
  before=scene.carried_collected.duplicate()
  check(not leaves.pick(leg.tree).ok and before==scene.carried_collected,"tree cannot grant twice")
  var path:String="res://tmp/l10_silverleaf_"+leg.tree+"_earned_save.json"
  var error:String=scene._quicksave_unrecorded(path)
  if not check(error.is_empty(),"harvest save: "+error):quit(1);return
  if not check(scene._quickload_unrecorded(path).is_empty(),"harvest reload"):quit(1);return
 check(leaves.harvest_state().picked.size()==9,"nine original trees harvested")
 if not await walk(scene,route.exit.points,"return with nine leaves"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native jungle return"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==8 and change.selector==2,"native Savage Jungle arrival2")
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene._quicksave_unrecorded("res://tmp/l8_nine_leaves_arrival_earned_save.json").is_empty(),"actual nine-leaf jungle handoff")
 if not await walk(scene,route.village.points,"Wild Village return"):quit(1);return
 check(scene.get_node("L8Journey").target()=="village","physical Wild Village arrival")
 check(scene.act2_creatures.state.actors["113"].health==500,"admitted village guard remains unharmed")
 check(scene.act2_creatures.peaceful_actor("113"),"admitted guard has no hostile combat owner")
 var count:int=scene.carried_collected.filter(func(id):return preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==117).size()
 check(count==9,"all nine earned Silverleaves carried to village")
 var path:="res://tmp/l8_nine_silverleaf_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"nine-leaf village save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"nine-leaf village reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall reset or arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual growth -> nine original tree harvests with capacity/duplicate guards and reloads -> native L8 return -> physical Wild Village with all nine leaves")
 quit(0 if failures==0 else 1)
