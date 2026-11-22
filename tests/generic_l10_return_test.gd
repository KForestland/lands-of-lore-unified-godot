extends "res://tests/generic_l10_sitting_test.gd"
## Debug the next earned leg from an untouched real-F5 checkpoint. This is a
## disclosed checkpoint continuation; the final whole sitting must start at F2.
const INPUT:="res://tmp/generic_l10_inputs/generic_l10_yellow44.json"
const PIN:="d6fbdb73645b2bc6cdc934474d912f6b569c7d0181d429f91eec3bbc7f738ad0"
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Untouched game-written yellow44 checkpoint pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Slots.slot_path(1))==OK,"Install the genuine checkpoint into player slot1"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9)
 await adopt()
 if not require(scene.get_instance_id()!=old and area=="L10_DC" and hp()>0 and "act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"RealF9 restores the actually earned charged-globe checkpoint"):return
 receipts.append({"continuation_sha256":PIN,"scope":"Untouched realF5 output; no fresh outbound-leg claim","position":str(pos()),"health":hp()})
 if not await return_to_ruins():return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Living continuation, no fall reset or stall"):return
 await picture("earned_first_ruins_continuation")
 var f:=FileAccess.open("user://tests/generic_l10_sitting/continuation_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CHECKPOINT CONTINUATION ONLY, full pilot outstanding","receipts":receipts,"resets":scene.resets,"stops":stops},"  "));f.close()
 print("PASS B earned checkpoint continuation ONLY: realF9 yellow44 -> realW reverse stairs/statue/mirror -> nativeL9 -> realF5. Pinned game-written checkpoint, no supplied pose/health/clock/action handlers; not a fresh full sitting")
 quit()
