extends "res://tests/helpers/dark_halls_rix_input.gd"
## Original dead/staff-taken owner packet, no supplied position or capability.
func run():
 if not await owner_rix("dead"):return
 var state:Dictionary=scene.rix.state().duplicate(true)
 var soul:int=scene.quest_state.monastery.globals.GV_LUTHERS_SOUL
 var staff:String=scene.rix.rix.corpse.id
 if not check(state=={"dead":true,"staff":true} and scene.creatures.state.actors["57"].health==0 and scene.carried_collected.count(staff)==1,"Owner's exact dead/staff state, no resurrection"):return
 await look(scene.creatures.bodies["57"].global_position+Vector3(0,20,0));await key(KEY_E);await ticks(3)
 if not check(scene.rix.state()==state and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==soul and scene.carried_collected.count(staff)==1,"E on already-taken corpse creates no rescue, gift or reward"):return
 scene.set_physics_process(true);await ticks(60);scene.set_physics_process(false)
 await key(KEY_F5);await ticks(3)
 var doc:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(doc.error.is_empty() and doc.state.area_save.quests.dark_halls_rix==state,"F5 preserves exact legacy two-field shape"):return
 if not await reload():return
 if not check(scene.rix.state()==state and scene.creatures.state.actors["57"].health==0 and scene.carried_collected.count(staff)==1 and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==soul,"F9 preserves dead Rix/staff/soul, no native rescue inserted"):return
 print("PASS original owner dead/staff packet through actualF9/E/F5/F9, no resurrection, new reward or capability; held rootphysics/AI/route/slot disclosed, no pose or health edit")
 quit()
