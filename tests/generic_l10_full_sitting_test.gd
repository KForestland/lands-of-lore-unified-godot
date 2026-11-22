extends "res://tests/generic_l10_emperor_sitting_test.gd"
## Fresh realF2 sitting. No installation of any external checkpoint in this main.
var ground_trace
func stop(step:String,detail:String):
 super.stop(step,detail)
 if ground_trace!=null:
  ground_trace.record_now();ground_trace.finish()
func first_yellow_real()->bool:
 var route:Dictionary=fixture("l10_tomb_walk.json")
 if not await walk(route.pickup,"entry to original empty44"):return false
 if not await take_item("act2:L10_DC:item44","original empty44"):return false
 if not await walk(route.charger,"original yellow charger"):return false
 if not await charge_one("L10:yellow"):return false
 return await checkpoint("fresh_yellow44")
func first_ruins_pit_real()->bool:
 var route:Dictionary=fixture("ruins_pit_earned_walk.json")
 if not await walk(route.cemetery.points,"ordinary original Cemetery exit"):return false
 if not await travelled("Original Cemetery exit into Jungle"):return false
 if not require(area=="L8_SJ","Actual native Jungle arrival"):return false
 if not await walk(route.jungle.points,"original Jungle pit approach"):return false
 var descent:Dictionary=fixture("l8_pit_descent_walk.json")
 if not await walk(descent.points+[descent.pit],"original pit descent to Ruins"):return false
 if not await travelled("Original Jungle pit enters Ruins"):return false
 if not require(area=="L9_DR" and "act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"Fresh earned first Ruins arrival retains actual yellow44"):return false
 return await checkpoint("fresh_first_ruins")
func main():
 ground_trace=load("res://tests/helpers/walked_ground_recorder.gd").new(self,"user://tests/generic_l10_sitting/walked_poses.jsonl")
 if not require(ground_trace.stream!=null,"Actual trajectory recording is mandatory before gameplay"):return
 if not await start_from_f2():ground_trace.finish();return
 if not await first_yellow_real():await picture("stop");quit(1);return
 if not await first_ruins_pit_real():await picture("stop");quit(1);return
 if not await tower_and_bracers():await picture("stop");quit(1);return
 if not await return_and_supply():await picture("stop");quit(1);return
 # Reload the actual F5 just written in this very sitting, without substituting
 # a fixture or recovering an earlier outcome. The route stays in one process.
 var prior_host:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=prior_host and area=="L10_DC" and hp()>0 and scene.resets==0,"Actual same-sitting F9 keeps Luther alive with both original empties"):return
 if not await two_whites_and_return():await picture("stop");quit(1);return
 if not await barrel_and_oil():await picture("stop");quit(1);return
 if not await oil_blue_priest():await picture("stop");quit(1);return
 if not await chapel_ashes_ankh():await picture("stop");quit(1);return
 if not await emperor_original_route():await picture("stop");quit(1);return
 if not require(is_equal_approx(Engine.time_scale,1.0) and Engine.physics_ticks_per_second==60 and hp()>0 and scene.resets==0 and stops.is_empty(),"Fresh whole pilot finishes living at ordinary clock without fall recovery/stall"):return
 if not await proof_picture("fresh_pilot_complete"):return
 if not require(ground_trace.samples>60,"Continuous actual trajectory exists for walked-ground replay"):return
 ground_trace.record_now();ground_trace.finish()
 var trace_path:="user://tests/generic_l10_sitting/walked_poses.jsonl"
 var f:=FileAccess.open("user://tests/generic_l10_sitting/full_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"FRESH SINGLE PROCESS REAL F2 SITTING; no external checkpoint installed","entry_sha256":"6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","receipts":receipts,"health":hp(),"resets":scene.resets,"stops":stops,"clock":[Engine.time_scale,Engine.physics_ticks_per_second],"actual_trace_sha256":FileAccess.get_sha256(trace_path),"actual_trace_samples":ground_trace.samples},"  "));f.close()
 print("PASS B FRESH F2 Cemetery/44yellow -> original Jungle pit/Ruins bridge/Tower realQ/Saar/shield/bracers -> gold91/crypt67/C/original56+8 -> actual same-sitting F5/F9 -> white climb/return -> white109/switch/barrel/original45+9/oil -> actualCtrlQ/blue/fences/priest -> original chapel/body/ashes/ankh -> source43gold/Emperor boxes/inner143/coffin click/remains; real input, no external checkpoint installation, test pose/health/clock/action handlers or fall recovery")
 quit()
