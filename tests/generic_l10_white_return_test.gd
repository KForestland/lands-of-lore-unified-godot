extends "res://tests/generic_l10_bracers_return_test.gd"
## Untouched realF5 continuation. All travel, charging and pickups use actual input.
const TWO_EMPTY_INPUT:="res://tmp/generic_l10_inputs/generic_l10_two_empty.json"
const TWO_EMPTY_PIN:="0bd320b98ae3ac837f0fecc304a6d39a66e716a95495165543ced0fa470c510a"
func two_whites_and_return()->bool:
 var route:Dictionary=fixture("l9_white_revisit_walk.json")
 if not await walk(route.statue.points,"Cemetery statue revisit"):return false
 var row:Array=scene.progression.exit_objects["control:150"][0].position
 await act(Vector3(row[0],row[1],row[2]),"Use winged statue for original mirror")
 if not await walk(route.mirror42.points,"original mirror42",{"final_reach":2.0}):return false
 if not await travelled("Actual mirror journey to Ruins"):return false
 if not require(area=="L9_DR","Mirror reaches the Ruins"):return false
 if not await transport(scene.get_node("L9Mirrors"),route.outside_mirror.points,"opened mirror alcove outward"):return false
 if not await transport(scene.get_node("L9Tower"),route.tower_entry.points,"Tower revisit alcove"):return false
 var tower_route:Dictionary=fixture("l9_tower_walk.json")
 if not await walk(tower_route.ground.points,"previously released ground field"):return false
 if not require("1090" in scene.get_node("L9Tower").state().orbs,"Earned Spark field remains released"):return false
 if not await walk(tower_route.white.points,"actual white-charger climb"):return false
 for id in ["act2:L10_DC:item56","act2:L10_DC:item8"]:
  if not require(id in scene.carried_collected,"The original empty is carried before charging: "+id):return false
  if not await charge_one("L9:white"):return false
  if not require(id+":charged:white" in scene.carried_collected,"The same earned globe is now white: "+id):return false
 if not await checkpoint("two_original_white_globes"):return false
 var back:Dictionary=fixture("l9_mirror_return_walk.json")
 var points:Array=tower_route.white.points.duplicate(true);points.reverse()
 var ground:Array=tower_route.ground.points.duplicate(true);ground.reverse()
 points.append_array(ground);points.append_array(back.tower_exit.points.slice(-3))
 if not await transport(scene.get_node("L9Tower"),points,"white-globe Tower descent"):return false
 if not await transport(scene.get_node("L9Mirrors"),back.mirror_entry.points,"opened mirror room return"):return false
 if not await walk(back.cemetery_mirror.points,"Cemetery return mirror",{"final_reach":2.0}):return false
 if not await travelled("White globes return to Cemetery"):return false
 if not require(area=="L10_DC" and "act2:L9_DR:item55" in scene.carried_collected,"Earned bracers and two whites return to Cemetery"):return false
 for id in ["act2:L10_DC:item56:charged:white","act2:L10_DC:item8:charged:white"]:
  if not require(id in scene.carried_collected,"Return retains "+id):return false
 return await checkpoint("two_whites_returned")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(TWO_EMPTY_INPUT)==TWO_EMPTY_PIN,"Untouched two-empty F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(TWO_EMPTY_INPUT,Slots.slot_path(1))==OK,"Install actual two-empty F5 for realF9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0,"Living actualF9 two-empty continuation"):return
 if not await two_whites_and_return():await picture("stop");quit(1);return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Ordinary charging/return with no fall recovery or death"):return
 var f:=FileAccess.open("user://tests/generic_l10_sitting/white_return_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CONTINUATION ONLY; fresh whole pilot outstanding","input_sha256":TWO_EMPTY_PIN,"receipts":receipts,"resets":scene.resets},"  "));f.close()
 print("PASS B ordinary real-input two-empty continuation: statue/mirrors, Tower climb, Echarge/retrieve original56+8 white, on-foot descent and Cemetery return/F5; no test pose/health/clock/action calls")
 quit()
