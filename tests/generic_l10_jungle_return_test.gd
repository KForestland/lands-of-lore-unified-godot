extends "res://tests/generic_l10_sitting_test.gd"
## Continue a genuine F5 output by actual F9. No supplied world pose/health/clock.
const YELLOW_INPUT:="res://tmp/generic_l10_inputs/generic_l10_yellow44.json"
const YELLOW_PIN:="d6fbdb73645b2bc6cdc934474d912f6b569c7d0181d429f91eec3bbc7f738ad0"
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(YELLOW_INPUT)==YELLOW_PIN,"Untouched realF5 yellow globe checkpoint pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(YELLOW_INPUT,Slots.slot_path(1))==OK,"Install untouched earned F5 output in slot1"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old and area=="L10_DC" and hp()>0 and not scene.starting_magic.interface_request,"ActualF9 resumes earned charged globe"):return
 receipts.append({"continuation_sha256":YELLOW_PIN,"health":hp(),"position":str(pos())})
 var route:Dictionary=fixture("ruins_pit_earned_walk.json")
 if not await walk(route.cemetery.points,"ordinary Cemetery exit to Jungle"):await picture("stop");quit(1);return
 if not await travelled("Source Cemetery exit to Jungle"):return
 if not require(area=="L8_SJ","Actual native Jungle arrival"):return
 if not await checkpoint("jungle_gold_return"):return
 if not await walk(route.jungle.points,"ordinary Jungle pit approach"):await picture("stop");quit(1);return
 var descent:Dictionary=fixture("l8_pit_descent_walk.json")
 if not await walk(descent.points+[descent.pit],"actual pit descent to Ruins"):await picture("stop");quit(1);return
 if not await travelled("Native Jungle pit into Ruins"):return
 if not require(area=="L9_DR" and "act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"First-visit native Ruins arrival retains charged globe"):return
 if not await checkpoint("first_ruins_via_pit"):return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Living on-foot ordinary Ruins return, zero recovery"):return
 var f:=FileAccess.open("user://tests/generic_l10_sitting/jungle_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CONTINUATION ONLY; full fresh pilot outstanding","receipts":receipts,"resets":scene.resets},"  "));f.close()
 print("PASS B continuation: realF9 earned yellow44 -> actualW Cemetery exit/Jungle/pit -> native Ruins first arrival -> realF5, no supplied pose/health/clock/action handlers")
 quit()
