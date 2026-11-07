extends "res://tests/l9_chapel_earned_test.gd"
const PyreState=preload("res://scripts/lol2/l9_pyre_state.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l9_chapel_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual chapel arrival"):quit(1);return
 prepare(scene)
 var pyre=scene.get_node("L9Pyre")
 check(not scene.act2_items.available(PyreState.FULL),"source full urn cannot be picked up before cremation")
 check(not pyre.ignite("1205"),"orb refuses before body is on altar")
 scene.camera.look_at(pyre.body_position()+Vector3.UP*10,Vector3.UP)
 if not check(pyre.grab().ok,"grab original body2406"):quit(1);return
 if not await walk(scene,[[10600,-12900],[10700,-12800]],"drag original body"):quit(1);return
 var dragging:="res://tmp/l9_body_drag_earned_save.json"
 check(scene._quicksave_unrecorded(dragging).is_empty() and scene._quickload_unrecorded(dragging).is_empty(),"actual dragged-body position save/reload")
 check(pyre.state().holding and pyre.body_position().distance_to(Vector3(10538,140,-12996))>100,"dragged body follows earned movement")
 if not await walk(scene,[[10800,-12750],[10845,-12595]],"bring body to pyre"):quit(1);return
 scene.camera.look_at(pyre.ALTAR+Vector3.UP*12,Vector3.UP)
 for i in 120:await physics_frame
 if not check(pyre.place().ok,"Kit places dragged body on original pyre301"):quit(1);return
 check(not pyre.place().ok,"duplicate body placement refused")
 for id in ["1205","1206"]:
  scene.camera.look_at(pyre.ORBS[id],Vector3.UP)
  for i in 180:
   await physics_frame
   scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
   if id in pyre.state().orbs:break
  if not check(id in pyre.state().orbs,"actual Spark at source orb"+id):quit(1);return
  check(not pyre.ignite(id),"duplicate orb cannot replay burn")
  if id=="1205":check(pyre.state().phase==1,"one orb leaves body unburned")
 check(pyre.state().phase==2,"both orbs start original burning sprite")
 var burning:="res://tmp/l9_pyre_burning_earned_save.json"
 check(scene._quicksave_unrecorded(burning).is_empty() and scene._quickload_unrecorded(burning).is_empty(),"burn clock and two actual hits save/reload")
 var clock_before: float=pyre.state().burn
 paused=true
 for i in 20:await process_frame
 check(pyre.state().burn==clock_before,"pause freezes cremation")
 paused=false
 for i in 600:
  await physics_frame
  if pyre.state().phase==3:break
 if not check(pyre.state().phase==3,"burn completes to original ashes child224"):quit(1);return
 scene.camera.look_at(pyre.ALTAR+Vector3.UP*12,Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not pyre.urn("insert","act2:L10_DC:item8:charged:white").ok and before==scene.carried_collected,"wrong item refused without loss")
 if not check(pyre.urn("insert",PyreState.URN).ok,"Kit transforms original empty urn to source Full urn168"):quit(1);return
 var occupied:="res://tmp/l9_ashes_occupied_earned_save.json"
 check(scene._quicksave_unrecorded(occupied).is_empty() and scene._quickload_unrecorded(occupied).is_empty(),"occupied full urn save/reload")
 before=scene.carried_collected.duplicate()
 var refusal:=PyreState.act(pyre.state(),before,"retrieve","",before.size())
 check(not refusal.ok and before==scene.carried_collected,"full capacity retrieval vector preserves live inventory and slot")
 scene.camera.look_at(pyre.ALTAR+Vector3.UP*12,Vector3.UP)
 if not check(pyre.urn("retrieve").ok,"retrieve filled urn once"):quit(1);return
 check(not pyre.urn("retrieve").ok,"duplicate retrieval refused")
 check(PyreState.FULL in scene.carried_collected and PyreState.URN not in scene.carried_collected,"single urn transformation, no duplicate")
 var path:="res://tmp/l9_ashes_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual ashes save/reload")
 check(not scene.act2_items.available(PyreState.FULL),"world full urn cannot duplicate Kit output")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned chapel urn -> original body drag/save -> Kit altar -> two actual Sparks -> source fire/ashes -> occupied Kit urn save/full refusal/retrieval -> actual ashes save/reload")
 quit(0 if failures==0 else 1)
