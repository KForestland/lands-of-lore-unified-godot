extends "res://tests/helpers/owner_gaps_input.gd"
func run():
 if not await boot_owner("L8_SJ","l8_shaft"):return
 if not check(scene.quest_state.l8_shore.arrived and scene.quest_state.l9_escape.escaped and scene.quest_state.l9_statue_walk.fight_done,"Owner's genuine post-flood story receipts"):return
 await look(Vector3(1560,-180,-1210));scene.set_physics_process(true);await hold_key(KEY_A,8);scene.set_physics_process(false)
 var water:Dictionary=scene.liquid_drowning.column_at(Vector3(1560,-50,-1210))
 await frame("shaft_report")
 if not check(not water.is_empty() and float(water.surface)==0.0,"Post-Belial shaft visibly contains water to the rim"):return
 if not check(scene.resets==0 and scene.starting_magic.health()>0 and scene.player.is_on_floor(),"Actual small rim walk stays alive and grounded"):return
 await key(KEY_F5)
 if not await reload():return
 if not check(not scene.liquid_drowning.column_at(Vector3(1560,-50,-1210)).is_empty(),"ActualF5/F9 retains flooded shaft from existing story state"):return
 print("PASS owner's genuine post-Belial shaft save, realF9/approach/F5/F9, water at rim and existing liquid query; held NPCs, no campaign claim")
 quit()
