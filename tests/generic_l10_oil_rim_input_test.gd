extends "res://tests/generic_l10_robot_oil_fall_test.gd"
## Actual F5 reached from the pinned robot map-entry save in the red proof.
const STAND_INPUT:="res://tests/fixtures/l10_robot_oil_stand_20261113.json"
const STAND_PIN:="abb72467dfbd8000380c1e95e78954973eef1a3b38dfb4a2bdfeab645237854c"
func reload_stand()->bool:
 if not require(FileAccess.get_sha256(STAND_INPUT)==STAND_PIN,"Untouched game-written robot-route casting-stand F5"):return false
 if not require(DirAccess.copy_absolute(STAND_INPUT,Slots.slot_path(1))==OK,"Install disclosed reached stand for actualF9"):return false
 await tap(KEY_F9);await adopt();await ticks(12)
 return require(area=="L10_DC" and scene.player.is_on_floor() and not scene.get_node("L10Oil").burned() and pos().distance_to(Vector3(-1434.7224,32.047,-3192.03))<1,"ActualF9 original close casting stand")
func cast_oil()->bool:
 var oil:Node=scene.get_node("L10Oil")
 await tap(KEY_1)
 for attempt in 12:
  if oil.burned():break
  await act(oil.AIM,"CtrlQ into oil",KEY_Q,true);await ticks(40)
 return require(oil.burned(),"ActualCtrlQ ignites spilled oil")
func descend(tag:String)->bool:
 var route:Array=[[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]]
 if not await walk(route,tag):await picture(tag+"_stop");return false
 await ticks(120)
 return require(scene.resets==0 and hp()>0 and scene.player.is_on_floor() and absf(pos().y+58)<3,"Native catacomb floor minus90 reached alive: "+tag)
func main():
 if not require(FileAccess.get_sha256(STAND_INPUT)==STAND_PIN,"Untouched reached stand input"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(STAND_INPUT,Slots.slot_path(1))==OK,"Install genuine slot before actualF2"):return
 if not await start_from_f2():return
 if not await reload_stand():return
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not require(Engine.time_scale==4 and Engine.physics_ticks_per_second==240,"Robot clock4/240"):return
 var recorder=load("res://tests/helpers/walked_ground_recorder.gd").new(self,"user://tests/generic_l10_sitting/oil_robot_rim4x.jsonl")
 if not await cast_oil():return
 if not require(scene.player.is_on_floor() and absf(pos().y-32)<1 and scene.resets==0,"Close caster stays on original supported rim, no fall/recovery"):return
 await frames(30)
 if not require(not scene.get_node("L10Oil").flash.visible,"Opening proof is after the explosion flash"):return
 await look(Vector3(-1490,-70,-3250));await picture("oil_hole_from_robot_rim")
 var rim:Array=[[-1470,-3172],[-1430,-3172],[-1390,-3172],[-1390,-3192],[-1385,-3230],[-1385,-3270],[-1390,-3192],[-1420,-3192],[-1435,-3192]]
 if not await walk(rim,"actual north and east rim after close cast"):await picture("oil_rim_stop");return
 if not require(scene.resets==0 and scene.player.is_on_floor() and absf(pos().y-32)<2,"Rim walk stays on original upper floor"):return
 if not await descend("close_cast_rim_descent"):return
 if not await checkpoint("robot_close_cast_rim_landing"):return
 recorder.finish()
 if not await reload_stand():return
 Engine.time_scale=1;Engine.physics_ticks_per_second=60
 if not require(Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"V4 ordinary clock1/60"):return
 recorder=load("res://tests/helpers/walked_ground_recorder.gd").new(self,"user://tests/generic_l10_sitting/oil_v4_descent1x.jsonl")
 if not await walk([[-1435,-3120],[-1428,-3005],[-1428,-2840]],"v4 real retreat before distant ignition"):return
 var health_before:=hp()
 if not await cast_oil():return
 if not require(hp()==health_before,"Distant v4 caster remains outside unchanged blast"):return
 if not await descend("v4_distant_cast_descent"):return
 await picture("v4_oil_landing")
 if not await checkpoint("robot_input_v4_cast_landing"):return
 await tap(KEY_F9);await adopt();await ticks(12)
 if not require(hp()>0 and scene.resets==0 and absf(pos().y+58)<3,"RealF9 preserves native landing"):return
 recorder.finish()
 print("PASS same robot-route casting save: close CtrlQ/rim W/descent at disclosed4/240, v4 retreat/CtrlQ/descent at1/60, realF5/F9, native lower floors,0testteleports/resets/stalls")
 quit()
