extends "res://tests/generic_l10_white_return_test.gd"
## Ordinary input continuation from the same game-written two-white return.
const WHITE_RETURN_INPUT:="res://tmp/generic_l10_inputs/generic_l10_white_return.json"
const WHITE_RETURN_PIN:="75b888add88dcbbf5333dc8a1269fc460d44f2ce0a1a8578b2c14e4a5a820786"
func barrel_and_oil()->bool:
 var route:Dictionary=fixture("l10_barrel_walk.json")
 var tombs:Node=scene.get_node("L10Tombs")
 var barrel:Node=scene.get_node("L10Barrel")
 if not require(not barrel.state().switch and not tombs.opened("109"),"Earned branch starts before the white switch tomb"):return false
 if not await walk(route.white.points,"white switch tomb"):return false
 await act(tombs.aims["109"],"Offer earned white at109")
 if not require(tombs.opened("109"),"RealE spends an earned white to open109/112"):return false
 if not await walk(route.switch.points,"original switch61"):return false
 await act(barrel.SWITCH,"Flip original caretaker switch61")
 if not require(barrel.state().switch,"RealE flips61 and opens caretaker74"):return false
 if not await checkpoint("white_switch_opened"):return false
 if not await walk([[-1480,-3081]],"side of original coffin237"):return false
 if not await take_item("act2:L10_DC:item45","original empty45 beside coffin"):return false
 if not await walk([[-1458,-3005]],"leave white coffin"):return false
 if not await walk(route.caretaker.points,"caretaker room"):return false
 if not await walk(route.inside.points,"sidle past original barrel"):return false
 if not await walk(route.globe9.points,"original caretaker globe9"):return false
 if not await take_item("act2:L10_DC:item9","original empty9"):return false
 if not await walk(route.behind.points,"get behind barrel477"):return false
 await act(barrel.TOP,"Tip barrel toward north tomb")
 if not require(barrel.state().phase==1,"RealE starts the barrel rolling"):return false
 if not await walk(route.oil.points,"follow rolling barrel"):return false
 for tick in 3000:
  if barrel.state().phase==2:break
  if not nearest_hostile(fight_radius).is_empty() and not await fight("barrel obstruction"):return false
  await guard();await physics_frame
 if not require(barrel.state().phase==2,"Barrel physically reaches its source endpoint and spills oil"):return false
 return await checkpoint("barrel_oil_spilled")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(WHITE_RETURN_INPUT)==WHITE_RETURN_PIN,"Untouched two-white return F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(WHITE_RETURN_INPUT,Slots.slot_path(1))==OK,"Install actual two-white return F5 for realF9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0,"Living actualF9 two-white return"):return
 if not await barrel_and_oil():await picture("stop");quit(1);return
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"Living ordinary barrel leg with no fall recovery"):return
 print("PASS B ordinary real-input white109/switch61/caretaker74, original45+9, Ebarrel477 and on-foot follow to spilled oil/F5; continuation only, no supplied pose/health/clock/action calls")
 quit()
