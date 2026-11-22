extends "res://tests/generic_l10_barrel_sitting_test.gd"
## Robot60147ae autosave at its second Cemetery return, unchanged and pinned.
## Same barrel/oil and post-cast route, real input only; robot4/240clock disclosed.
const ROBOT_INPUT:="res://tests/fixtures/l10_robot_oil_entry_20261113.json"
const ROBOT_PIN:="6eccba51f5bbb179d8bc331cc659bfb905e30a57e647d3209efda1d1cbe24c1a"
func main():
 if not require(FileAccess.get_sha256(ROBOT_INPUT)==ROBOT_PIN,"Untouched robot map-entry autosave"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(ROBOT_INPUT,Slots.slot_path(1))==OK,"Install genuine robot slot before actualF2/F9"):return
 if not await start_from_f2():return
 await tap(KEY_F9);await adopt();await ticks(12)
 if not require(area=="L10_DC" and pos().distance_to(Vector3(-542,32,-856))<1 and scene.player.is_on_floor() and scene.resets==0,"ActualF9 robot second mirror return"):return
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not require(Engine.time_scale==4 and Engine.physics_ticks_per_second==240,"Same disclosed robot clock4/240"):return
 if not await barrel_and_oil():await picture("robot_barrel_stop");quit(1);return
 var oil:Node=scene.get_node("L10Oil")
 if not require(not oil.burned() and absf(pos().x+1435)<10 and absf(pos().z+3200)<15,"Same robot oil-casting stand, no retreat/replacement pose"):return
 await picture("robot_before_oil")
 # Save the actual reached stand before the same Ctrl+Q used by the robot.
 if not await checkpoint("robot_oil_stand_before_cast"):return
 await tap(KEY_1)
 for attempt in 12:
  if oil.burned():break
  await act(oil.AIM,"Robot CtrlQ at oil stand",KEY_Q,true)
  await ticks(40)
 if not require(oil.burned(),"Actual robot CtrlQ collapses the tomb floor"):return
 var route:Array=[[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]]
 if not await walk(route,"robot down through collapsed floor"):await picture("robot_oil_fall_stop");quit(1);return
 await ticks(120)
 if not require(scene.player.is_on_floor() and absf(pos().y+58)<3 and scene.resets==0 and hp()>0,"Robot route lands on native minus90 catacomb floor without recovery"):return
 await picture("robot_oil_landed")
 if not await checkpoint("robot_oil_landing"):return
 await tap(KEY_F9);await adopt();await ticks(12)
 if not require(hp()>0 and scene.resets==0 and absf(pos().y+58)<3,"ActualF9 keeps living native landing"):return
 print("PASS robot60147ae map-entry save -> same white109/switch/barrel/globes45+9/oil stand -> CtrlQ -> identical collapsed-floor route -> native minus90 landing/F5F9; real input, disclosed4/240,0testteleports/resets/stalls")
 quit()
