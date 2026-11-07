extends SceneTree
const Save=preload("res://scripts/lol2/act2_save.gd")
var failures:=0
func check(value:bool,label:String):
 if not value:failures+=1;printerr("FAIL initiation yield: ",label)
func _initialize():run.call_deferred()
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_initiation_fight_earned_save.json","lol2-restoration-darker-jungle")
 if not input.error.is_empty():printerr(input.error);quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 check(scene.apply_save(input.state).is_empty(),"actual mid-bout checkpoint")
 scene.player.set_physics_process(false);scene.set_physics_process(false);scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var tribe=scene.get_node("L8Tribe")
 var hp:int=scene.starting_magic.health();var inventory:Array=scene.carried_collected.duplicate()
 paused=true;var before:Dictionary=tribe.state().duplicate(true)
 for i in 5:await process_frame
 check(tribe.state()==before,"bout pauses")
 check(not tribe.yield_bout(),"paused yield refused")
 paused=false
 check(tribe.yield_bout(),"yield after actual sparring")
 check(tribe.State.member(tribe.state()) and tribe.state().player==0,"nonlethal concession completes initiation")
 check(scene.starting_magic.health()==hp and scene.act2_creatures.state.actors["23"].health==600,"both campaign health values preserved")
 check(scene.carried_collected==inventory,"no second offering or reward")
 var path:="res://tmp/l8_initiation_yield_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"yield save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"yield reload")
 check(not tribe.yield_bout(),"duplicate yield refused")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual mid-bout save -> pause refusal -> nonlethal yield -> membership/reload; no second leaf or HP loss")
 quit(0 if failures==0 else 1)
