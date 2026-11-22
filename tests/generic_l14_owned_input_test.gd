extends "res://tests/generic_l14_rollout_test.gd"
## Supplied grounded trial-door stand; unchanged game-written checkpoints.
## Real left/E retain the original spiral prerequisite and saved door receipt.
func approach()->bool:
 var trials:Node=scene.get_node("L14Trials")
 if not await pose(Vector3(340,222.05,-2185),trials.DOORS["90"]):return false
 await aim(trials.DOORS["90"])
 return check(trials.generic_target().get("id")=="90" and scene.get_node("GenericObjects").would_use(),"Grounded aimed trial90 has use priority")
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary Temple owned-use clock"):return
 folder="user://tests/generic_l14_owned";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L14_HT.tscn","res://assets/lol2/generated/playtest_starts/c15_l14_ht.json","761850f60b460772b31566ff0eb4201caba6e3d6d120ccc590bc64addb317c2f","lol2-restoration-map-L14_HT"):return
 if not await approach():return
 await click()
 if not check(scene.get_node("L14Trials").state().doors.is_empty() and scene.interface_hud.hint.text=="Raise the spiral first.","Actual left retains spiral refusal and no door effect"):return
 if not await boot("res://scenes/lol2/maps/L14_HT.tscn","res://tmp/l14_spiral_slot_qualified_save.json","d2c2c706435236d946a761a120cca8abc5ae6ad73f3d8ac650f2be46bd29c15e","lol2-restoration-map-L14_HT"):return
 if not await approach():return
 await click()
 if not check(scene.get_node("L14Trials").state().doors==["90"] and not scene.interface_hud.attack_swing.icon.visible,"Actual left uses original trial transaction after earned spiral; no attack"):return
 await shot("trial_open")
 await key(KEY_F5)
 if not await load_slot():return
 if not check(scene.get_node("L14Trials").state().doors==["90"] and scene.resets==0,"F9 keeps earned trial receipt without recovery"):return
 print("PASS Temple owned left use preserves refusal, original earned admission and F5/F9; supplied grounded stand")
 quit()
