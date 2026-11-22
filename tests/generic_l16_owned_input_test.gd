extends "res://tests/generic_l16_rollout_test.gd"
## Local grounded component stands, held root/NPC clocks and original pinned
## checkpoints. Real left binds to the same E transactions, no story injection.
func pyramid_stand()->bool:
 var owner:Node=scene.get_node("L16Greenhouse")
 if not await pose(Vector3(2289,32.05,-490),owner.PLATE):return false
 await aim(owner.PLATE)
 return check(scene.get_node("GenericObjects").would_use(),"Actual aimed pyramid gets use priority")
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary City owned-use clock"):return
 folder="user://tests/generic_l16_owned";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L16_CA.tscn","res://tests/fixtures/g03_l16_ground_b387ca96.json","b387ca96a3d514bcfb6e16dc3d7fea37883f2724ec506baa5fec1d985aef844a","lol2-restoration-map-L16_CA"):return
 var chips:Node=scene.get_node("L16SwChips")
 # Stand on the pedestal floor (region 6875, h 0): (-10089, 13035) is inside a pit (region 6882, floor -50) whose walls hold
 # since r19o9 (11c3ff2f City walls), so the old stand fell in and aimed from below the rim.
 if not await pose(Vector3(-10089,32.05,12990),chips.PEDESTALS[0]):return
 await aim(chips.PEDESTALS[0]);await click()
 if not check(chips.state().placed.is_empty() and scene.interface_hud.hint.text=="The pedestal takes an ivory chip.","Actual left retains empty-hand pedestal refusal"):return
 var hourglass:Node=scene.get_node("L16Greenhouse")
 if not await pose(Vector3(2361,52.05,-991),hourglass.HOURGLASS):return
 await aim(hourglass.HOURGLASS);await click()
 if not check(float(hourglass.state().fireball)==0 and scene.interface_hud.hint.text=="The hourglass chimes and ticks for a while.","Actual left retains hourglass-before-leaf order"):return
 if not await pyramid_stand():return
 var owner:Node=scene.get_node("L16Greenhouse")
 var leaf:String=owner.carried_silverleaf()
 if not check(not leaf.is_empty(),"Original earned checkpoint carries its silverleaf"):return
 var before:int=scene.carried_collected.count(leaf)
 await click()
 if not check(owner.state().silverleaf==leaf and scene.carried_collected.count(leaf)==before-1 and not scene.interface_hud.attack_swing.icon.visible,"Actual left executes original silverleaf transaction once; use wins"):return
 await shot("silverleaf_placed")
 await key(KEY_F5)
 if not await load_slot():return
 if not check(scene.get_node("L16Greenhouse").state().silverleaf==leaf and scene.resets==0,"F9 preserves placed item and no recovery"):return
 print("PASS City original-owner left use: chip refusal/hourglass-before-leaf, earned silverleaf placement, F5/F9; supplied grounded stands")
 quit()
