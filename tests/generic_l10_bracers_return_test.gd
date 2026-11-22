extends "res://tests/generic_l9_tower_sitting_test.gd"
## Ordinary real-input return and native globe supply, resumed by actualF9.
const BRACERS_INPUT:="res://tmp/generic_l10_inputs/generic_l9_bracers.json"
const BRACERS_PIN:="5ce68d1ea57d57d803920eeaa7a6738a405445c69ae348b51a749dce3ebedd46"
func return_and_supply()->bool:
 var route:Dictionary=fixture("l9_mirror_return_walk.json")
 var tower:Node=scene.get_node("L9Tower")
 if not await transport(tower,route.tower_exit.points,"earned Tower descent and exit"):return false
 if not await checkpoint("outside_tower_return"):return false
 if not await walk(route.orb.points,"first mirror-door orb approach"):return false
 var mirrors:Node=scene.get_node("L9Mirrors")
 if not require(not mirrors.opened(),"Mirror doors start closed before this actual first return"):return false
 await tap(KEY_1)
 for attempt in 12:
  await act(mirrors.AIM,"Spark the native mirror-door orb",KEY_Q)
  if mirrors.opened():break
  await ticks(60)
 if not require(mirrors.opened(),"ActualQ opens original mirror doors65/66 from the outer Ruins"):return false
 await ticks(120)
 if not await checkpoint("mirror_room_opened_from_ruins"):return false
 if not await transport(mirrors,route.mirror_entry.points,"opened mirror-room alcove"):return false
 if not await walk(route.cemetery_mirror.points,"native Cemetery return mirror",{"final_reach":2.0}):return false
 if not await travelled("Native mirror return to Cemetery"):return false
 if not require(area=="L10_DC" and "act2:L9_DR:item55" in scene.carried_collected,"Actual Cemetery arrival retains earned bracers"):return false
 if not await checkpoint("cemetery_bracers_and_white"):return false
 var supply:Dictionary=fixture("l10_two_empty_walk.json")
 if not await walk(supply.door.points,"gold socket91"):return false
 var tombs:Node=scene.get_node("L10Tombs")
 if not require(not tombs.opened("91"),"Gold91 starts unopened in this earned chain"):return false
 await act(tombs.aims["91"],"Offer the earned yellow globe at91")
 if not require(tombs.opened("91") and "act2:L10_DC:item44:charged:yellow" not in scene.carried_collected,"RealE spends earned yellow44 exactly once at91"):return false
 if not await checkpoint("gold91_opened"):return false
 return await supply_original_globes()
func supply_original_globes()->bool:
 var supply:Dictionary=fixture("l10_two_empty_walk.json")
 if not await walk(supply.lid.points,"crypt top67 and original empty56"):return false
 var generic:Node=scene.get_node("GenericObjects")
 var point:Vector3=scene.progression.hinges[67].transform*scene.progression.mover_bounds[67].get_center()
 await look(point)
 var target:Dictionary=generic.aimed()
 if not require(target.get("kind")=="movable" and int(target.id)==67,"Actual crosshair reaches crypt top67"):return false
 await act(point,"Open original crypt top67")
 await ticks(60)
 if not require(scene.progression.native.field("movable:67","state_0x55",0) in [1,2] and pos().y>=31.8,"Opening67 preserves the floor contact"):return false
 key_event(KEY_C,true);await ticks(6)
 if not require(scene.crouched,"Actual held C clears the low crypt cover"):return false
 await ticks(60)
 if not require(scene.progression.native.field("movable:67","state_0x55",0)==1,"The cover completes after the actual body clears it"):return false
 if not await take_item("act2:L10_DC:item56","original empty56"):return false
 key_event(KEY_C,false);await ticks(6)
 if not await walk(supply.free.points,"original loose globe8"):return false
 if not await take_item("act2:L10_DC:item8","original empty8"):return false
 return await checkpoint("two_original_empty_globes")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(BRACERS_INPUT)==BRACERS_PIN,"Untouched earned Tower/bracers F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(BRACERS_INPUT,Slots.slot_path(1))==OK,"Install untouched actualF5 in slot1"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old and area=="L9_DR" and hp()>0 and not scene.starting_magic.interface_request,"RealF9 resumes the earned bracers state"):return
 receipts.append({"continuation_sha256":BRACERS_PIN,"health":hp(),"position":str(pos())})
 if not await return_and_supply():await picture("stop");quit(1);return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Living ordinary return/supply walk, no fall recovery"):return
 var f:=FileAccess.open("user://tests/generic_l10_sitting/bracers_return_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CONTINUATION ONLY; fresh whole pilot outstanding","receipts":receipts,"resets":scene.resets,"stops":stops},"  "));f.close()
 print("PASS B earned return continuation: actualW Tower descent/native alcove, Qmirror65/66, native Cemetery return, Egold91/Egeneric67/Eoriginal56+8 and F5; no supplied pose/health/clock/action handlers")
 quit()
