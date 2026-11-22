extends "res://tests/generic_l10_ashes_ankh_test.gd"
const ANKH_INPUT:="res://tmp/generic_l10_inputs/generic_l10_ankh.json"
const ANKH_PIN:="eb599c4dc42e7befc1581d8167404908a761a15f96f4a5c6b3798d8f4612cb3a"
func emperor_original_route()->bool:
 var ankh:String="act2:L10_DC:priest_ankh"
 if not require(ankh in scene.carried_collected,"Actual earned ankh before Emperor slab"):return false
 var leave:Array=fixture("l10_priest_walk.json").priest.points.duplicate(true)
 leave.reverse();leave.append([2880,-3005]);leave.append_array(fixture("l10_ankh_walk.json").points)
 if not await walk(leave,"original Holy Switch66"):return false
 var entry:Node=scene.get_node("L10EmperorEntry")
 await act(entry.SLAB_AIM,"Use earned ankh on original slab66")
 if not require(entry.opened(),"ActualE ankh opens original outer slab"):return false
 if ankh not in scene.carried_collected:await act(entry.SLAB_AIM,"Retrieve original ankh for inner tomb")
 if not require(ankh in scene.carried_collected,"Ankh actually retrieved for inner tomb"):return false
 if not await walk([[3207,-2350],[3207,-2290],[3207,-2240],[3207,-2190],[3207,-2140],[3207,-2070],[3207,-2010]],"opened original Emperor stairs"):return false
 await ticks(60)
 if not require(pos().y< -50,"Actual lower stair landing rather than the stacked surface"):return false
 if not await checkpoint("original_emperor_entry"):return false
 var route:Dictionary=fixture("l10_emperor_supply_walk.json")
 var blue:Dictionary=fixture("l10_blue_walk.json")
 if not await walk([[3207,-2070],[3207,-2140],[3207,-2190],[3207,-2240],[3207,-2290],[3207,-2350],[3207,-2390]],"leave Emperor stairs for original supply"):return false
 if not await walk(route.surface_to_breach.points,"return to original opened breach"):return false
 if not await walk([[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]],"original breached tomb descent"):return false
 await ticks(120)
 if not require(absf(pos().y+58)<3,"Actual original north-catacomb landing"):return false
 if not await walk(blue.blue.points,"original loose globe43"):return false
 if not await take_item("act2:L10_DC:item43","original empty43"):return false
 if not await walk(blue.stairs.points,"reverse northern charger stairs"):return false
 if not await walk(blue.fence74.points,"original fence74 high approach"):return false
 if not await fence_real_input(74):return false
 if not await walk(blue.fence174.points,"original fence174 high approach"):return false
 if not await fence_real_input(174):return false
 if not await walk(route.yellow.points,"original gold altar for globe43"):return false
 if not await charge_one("L10:yellow"):return false
 if not require("act2:L10_DC:item43:charged:yellow" in scene.carried_collected,"ActualE charges original43 gold"):return false
 if not await walk(route.yellow_return.points,"return east entrance network"):return false
 if not await walk(blue.exit_stairs.points,"original surface entrance stairs"):return false
 if not await checkpoint("original_emperor_three_globes"):return false
 if not await walk(fixture("l10_emperor_walk.json").approach.points,"original Emperor entrance revisit"):return false
 if not await walk([[3207,-2350],[3207,-2290],[3207,-2240],[3207,-2190],[3207,-2140],[3207,-2070],[3207,-2010],[3207,-1950],[3207,-1900],[3207,-1800],[3207,-1740],[3207,-1650]],"original Emperor colour boxes"):return false
 var emperor:Node=scene.get_node("L10Emperor")
 for target in ["126","127","125"]:
  if not await walk([[emperor.AIMS[target].x,-1650]],"original matching box"+target):return false
  await act(emperor.AIMS[target],"Offer earned colour globe to Emperor box"+target)
  if not require(not emperor.State.Kit.slot(emperor.state(),target).occupied.is_empty(),"ActualE fills original box"+target):return false
  if not await checkpoint("original_emperor_box"+target):return false
 if not await walk([[3135,-1650],[3135,-1510],[3207,-1450],[3207,-1360]],"original inner HolyDoor143"):return false
 await act(emperor.AIMS["143"],"Use retained original ankh at143")
 if not require(emperor.State.opened(emperor.state()),"ActualE opens inner HolyDoor143"):return false
 if not await walk([[3207,-1300],[3207,-1270]],"original EMPT room trigger"):return false
 if not emperor.room_active:await act(emperor.AIMS.remains,"Enter original Emperor tomb room")
 if not require(emperor.room_active and paused,"ActualE enters original room and pauses world"):return false
 await frames(5)
 var coffin:Button=emperor.room_panel.get_node("CoffinHotspot")
 var at:Vector2=coffin.get_global_rect().get_center()
 await button(MOUSE_BUTTON_LEFT,at);await frames(5)
 if not require(emperor.State.REMAINS in scene.carried_collected and not paused and not emperor.room_active,"Actual original coffin hotspot click grants one remains and resumes world"):return false
 return await checkpoint("original_emperor_remains")
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(ANKH_INPUT)==ANKH_PIN,"Untouched actual ankh F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(ANKH_INPUT,Slots.slot_path(1))==OK,"Install actual untouched ankh F5 for F9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L10_DC" and hp()>0,"Living actualF9 original ankh state"):return
 if not await emperor_original_route():await picture("stop");quit(1);return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Living ordinary-input original Emperor route without recovery"):return
 print("PASS B actualEankh slab66 and retrieval, original lower stairs, source43/gold supply, actualEboxes126/127/125 and inner143, original coffin GUI click/remains/F5; continuation only, no supplied pose/health/clock/action calls")
 quit()
