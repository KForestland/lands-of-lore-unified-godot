extends "res://tests/generic_l10_barrel_sitting_test.gd"
const OIL_INPUT:="res://tmp/generic_l10_inputs/generic_l10_oil.json"
const OIL_PIN:="6004740eef5c164472a3aed635cade1de31013264dd9adfac9d0c695398c6fae"
func fence_real_input(id:int)->bool:
 var fences:Node=scene.get_node("L10Fences")
 var row:Dictionary=fences.rows[id]
 var before:int=fences.passes
 if not require(scene.player.is_on_floor() and (pos()-row.center).dot(row.normal)>25,"Actual high-side grounded approach to fence"+str(id)):return false
 await look(scene.camera.global_position-row.normal*200)
 key_event(KEY_SHIFT,true);key_event(KEY_W,true)
 await ticks(2)
 await tap(KEY_SPACE);await ticks(2)
 if not require(not scene.player.is_on_floor(),"ActualSpace running jump is airborne at fence"+str(id)):return false
 key_event(KEY_CTRL,true,true)
 var crossed:=false
 for tick in 300:
  await physics_frame
  if hp()<=0 or scene.resets!=0:break
  if (pos()-row.center).dot(row.normal)<-80 and scene.player.is_on_floor():crossed=true;break
 key_event(KEY_CTRL,false);key_event(KEY_SHIFT,false);key_event(KEY_W,false)
 if not require(crossed and fences.passes>before,"RealW/Shift/Space/midairCtrl crosses original fence"+str(id)):return false
 receipts.append({"fence":id,"passes":fences.passes-before,"position":str(pos()),"health":hp(),"resets":scene.resets})
 return true
func oil_blue_priest()->bool:
 var oil:Node=scene.get_node("L10Oil")
 if not require(scene.get_node("L10Barrel").state().phase==2 and not oil.burned(),"Actual spilled oil before ignition"):return false
 if not await walk([[-1435,-3120],[-1428,-3005],[-1428,-2840]],"retreat outside oil blast"):return false
 await tap(KEY_1)
 for attempt in 12:
  await act(oil.AIM,"CtrlQ distant oil",KEY_Q,true)
  if oil.burned():break
  await ticks(60)
 if not require(oil.burned(),"ActualCtrlQ ignites original spilled oil and collapses the floor"):return false
 if not await checkpoint("oil_floor_breached"):return false
 if not await walk([[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]],"physical breached-tomb descent"):return false
 await ticks(120)
 if not require(absf(pos().y+58)<3 and scene.resets==0,"Actual landing on original catacomb floor minus90"):return false
 if not await checkpoint("native_catacomb_landing"):return false
 var route:Dictionary=fixture("l10_blue_walk.json")
 if not await walk(route.blue.points,"northern original blue charger"):return false
 for id in ["act2:L10_DC:item45","act2:L10_DC:item9"]:
  if not require(id in scene.carried_collected,"Original empty carried before blue charge: "+id):return false
  if not await charge_one("L10:blue"):return false
  if not require(id+":charged:blue" in scene.carried_collected,"ActualE produces original blue "+id):return false
 if not await checkpoint("two_original_blue_globes"):return false
 if not await walk(route.stairs.points,"original blue-charger stairs back"):return false
 if not await walk(route.fence74.points,"fence74 high side"):return false
 if not await fence_real_input(74):return false
 if not await walk(route.fence174.points,"fence174 high side"):return false
 if not await fence_real_input(174):return false
 if not await walk(route.exit_stairs.points,"original entry-stair ascent"):return false
 if not require(pos().y>25,"Actually return above ground"):return false
 if not await checkpoint("two_blues_above_ground"):return false
 var priest_route:Dictionary=fixture("l10_priest_walk.json")
 if not await walk(priest_route.door.points,"original blue154 priest tomb"):return false
 var tombs:Node=scene.get_node("L10Tombs")
 await act(tombs.aims["154"],"Offer earned blue at154")
 if not require(tombs.opened("154"),"ActualE blue154 opens original priest room155"):return false
 if not await walk(priest_route.priest.points,"enter priest room on foot"):return false
 var priest:Node=scene.get_node("L10Priest")
 await act(priest.AIM,"Show earned bracers to priest")
 if not require(priest.state().urn_given and "act2:L10_DC:priest_urn" in scene.carried_collected and "act2:L9_DR:item55" in scene.carried_collected,"ActualE priest grants original urn once while retaining bracers"):return false
 return await checkpoint("original_priest_urn")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(OIL_INPUT)==OIL_PIN,"Untouched spilled-oil F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(OIL_INPUT,Slots.slot_path(1))==OK,"Install untouched oil F5 for actualF9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0,"ActualF9 living spilled-oil state"):return
 if not await oil_blue_priest():await picture("stop");quit(1);return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Living ordinary real-input blue/priest route without recovery"):return
 print("PASS B actualCtrlQ oil, on-foot original descent, Echarge45+9blue, realW/Shift/Space/Ctrl fences74/174, actualEblue154, enter155, Epriest/bracers/urn/F5; continuation only, no supplied pose/health/clock/action calls")
 quit()
