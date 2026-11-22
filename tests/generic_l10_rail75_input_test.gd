extends "res://tests/generic_l10_owner_rail_test.gd"
## Genuine fresh-v4 blue F5 -> source-floor stairs -> third lower rail75.
## Production W/Space only; no position/resource/clock or direct action writes.
func main():
 # New isolated profiles stage test settings but no player slots. Install the
 # disclosed genuine checkpoint first, so the gate does not auto-start Cave.
 if not require(FileAccess.get_sha256(BLUE_INPUT)==BLUE_PIN,"Untouched earned blue input before opening gate"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(BLUE_INPUT,Slots.slot_path(1))==OK,"Install disclosed game-written slot before actualF2"):return
 if not await start_from_f2():return
 if not await load_checkpoint(BLUE_INPUT,BLUE_PIN):return
 var route:Dictionary=fixture("l10_rail75_walk.json")
 if not await walk(route.blue_to_75.points,"source stairs to reachable rail75 high side"):await picture("rail75_approach_stop");quit(1);return
 if not await fence_real_input(75):await picture("rail75_plain_jump_stop");return
 await picture("rail75_plain_jump_green")
 var fences:Node=scene.get_node("L10Fences");var row:Dictionary=fences.rows[75]
 var before:int=fences.passes
 await look(scene.camera.global_position+row.normal*200)
 key_event(KEY_W,true);await tap(KEY_SPACE)
 for tick in 150:await physics_frame
 key_event(KEY_W,false);await ticks(8)
 if not require((pos()-row.center).dot(row.normal)<-8 and fences.passes==before,"Original low-to-high reverse crossing still refuses plain jump"):return
 if not require(hp()>0 and scene.resets==0,"Both rail75 attempts alive without fall recovery"):return
 if not await checkpoint("ordinary_rail75_then_reverse_refused"):return
 await tap(KEY_F9);await adopt();await ticks(12)
 if not require(hp()>0 and scene.resets==0 and not scene.get_node("L10Fences").rows[75].passing,"RealF9 clears transient rail75 passage"):return
 var dir:="user://tests/generic_l10_sitting/";DirAccess.make_dir_recursive_absolute(dir)
 var file:=FileAccess.open(dir+"rail75_receipts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Unchanged earned fresh-v4 F5 continuation, disclosed checkpoint installation; real W/Space, original one-way direction retained","receipts":receipts,"resets":scene.resets,"stops":stops,"clock":[Engine.time_scale,Engine.physics_ticks_per_second]},"  "));file.close()
 print("PASS reachable rail75 from earned blue checkpoint by real stairs/W; W+Space only crosses high-to-low, reverse plain jump refuses, realF5/F9 clears transient passage,0testteleports/resets/stalls")
 quit()
