extends "res://tests/generic_l10_sitting_test.gd"
## Next earned leg, resumed by realF9 from the untouched first-Ruins F5 output.
## Native mirrors/alcoves are game travel; the test supplies no body/health/clock.
const INPUT:="res://tmp/generic_l10_inputs/generic_l9_first_pit_arrival.json"
const PIN:="eebc3076f0fab9c0ccd02876cca47ed026d3349b7f38016060d4f7b9f7641242"
func transport(controller:Node,points:Array,label:String)->bool:
 var before:int=controller.transports.size()
 points=points.duplicate(true)
 if controller==scene.get_node("L9Tower"):
  # Open both leaves and take the visible middle, outside their swing arcs.
  points=points.slice(0,points.size()-2)+[[-2855,-1136.5],[-2880,-1136.5],[-2925,-1136.5]]
 for goal in points:
  if not await preload("res://tests/helpers/l9_tower_door_input.gd").sitting(self):return false
  if not await walk([goal],label,{"final_reach":2.0,"until":func():return controller.transports.size()>before}):return false
  if controller.transports.size()>before:break
 if not require(controller.transports.size()>before,"Actual native "+label+" transport"):return false
 receipts.append({"event":label,"native_transports":controller.transports.slice(before),"health":hp(),"resets":scene.resets})
 return true
func spark_field(tower:Node,id:String)->bool:
 await tap(KEY_1)
 for attempt in 12:
  if not require(hp()>0,"Living while aiming at field"+id):return false
  await act(tower.aims[id],"Spark tower orb"+id,KEY_Q)
  if id in tower.state().orbs:
   if not require(tower.selector_views.has(id) and tower.selector_views[id].selector==1,"Visible original red selector after actualQ"+id):return false
   receipts.append({"event":"realSpark","id":id,"health":hp(),"resets":scene.resets})
   return true
  await ticks(60)
 stop("Tower orb"+id,"Actual Q did not release its field; "+prompts());return false
func tower_and_bracers()->bool:
 var opening:Dictionary=fixture("l9_opening_walk.json")
 if not require(scene.act2_creatures.state.actors["79"].health>0,"Saar79 starts alive in this genuine first-visit state"):return false
 if not await walk(opening.points,"first Ruins approach to bridge orb"):return false
 var bridge:Node=scene.get_node("L9MagicBridge")
 if not require(not bridge.raised(),"First-visit bridge really starts unraised"):return false
 await tap(KEY_1)
 for attempt in 12:
  await act(bridge.AIM,"Spark the native bridge orb",KEY_Q)
  if bridge.raised():break
  await ticks(60)
 if not require(bridge.raised(),"RealQ raises the original bridge"):return false
 if not await checkpoint("bridge_raised"):return false
 if not await walk([[-1235,-1803],[-1320,-1803],[-1425,-1803],[-1525,-1803],[-1630,-1803],[-1710,-1803]],"original raised bridge crossing"):return false
 var tower:Node=scene.get_node("L9Tower")
 var route:Dictionary=fixture("l9_tower_walk.json")
 if not await transport(tower,route.entry.points,"first Tower arrival alcove"):return false
 if not await checkpoint("tower_arrival"):return false
 if not await walk(route.ground.points,"ground tower orb"):return false
 if not await spark_field(tower,"1090"):return false
 if not await walk(route.white.points,"white charger floor"):return false
 var charger:Node=scene.get_node("Act2Chargers")
 await look(charger.globes["L9:white"].global_position)
 if not require(charger.reachable("L9:white"),"Physically reached the original white charger"):return false
 if not await checkpoint("white_charger_approach"):return false
 var blank:String="act2:L9_DR:tower_blank"
 if not await take_item(blank,"existing book-led Tower globe adapter"):return false
 if not await charge_one("L9:white"):return false
 if not await checkpoint("first_white_globe"):return false
 var upper:Array=fixture("l9_tower_upper_walk.json")
 for leg in upper:
  if not await walk(leg.route.points,"upper tower "+str(leg.target)):return false
  if str(leg.target)=="79":
   if not await fight("larger Saar79"):return false
   if not require(scene.act2_creatures.state.actors["79"].health==0,"Real sword/Spark combat defeats larger Saar79"):return false
  elif not await spark_field(tower,str(leg.target)):return false
 if not await checkpoint("saar_defeated"):return false
 var niche:Dictionary=fixture("l9_bracers_walk.json")
 if not await walk(niche.points,"dead bracers niche"):return false
 var shield:Node=scene.get_node("L9DeadBracers")
 await tap(KEY_1)
 for attempt in 12:
  await act(shield.aim,"Spark the niche shield",KEY_Q)
  if shield.released():break
  await ticks(60)
 if not require(shield.released() and shield.barrier.collision_layer==0,"Actual Q drops the source312 shield after Saar"):return false
 if not await take_item("act2:L9_DR:item55","Bracers of the Dead"):return false
 return await checkpoint("earned_bracers")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Untouched first-Ruins earned checkpoint pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Slots.slot_path(1))==OK,"Install actual F5 output in slot1"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old and area=="L9_DR" and hp()>0 and not scene.starting_magic.interface_request,"RealF9 restores earned arrival, ordinary world input"):return
 receipts.append({"continuation_sha256":PIN,"health":hp(),"position":str(pos())})
 if not await tower_and_bracers():await picture("stop");quit(1);return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Living on-foot earned Tower sitting, no recovery/stall"):return
 await picture("earned_bracers")
 var f:=FileAccess.open("user://tests/generic_l10_sitting/tower_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CHECKPOINT CONTINUATION ONLY; fresh whole pilot outstanding","receipts":receipts,"resets":scene.resets,"stops":stops},"  "));f.close()
 print("PASS B earned Tower continuation ONLY: actual bridge/Tower alcove, realW and Q fields, Saar79 combat, Q shield312, E bracers and F5; pinned game-written arrival, no supplied pose/health/clock/action handlers")
 quit()
