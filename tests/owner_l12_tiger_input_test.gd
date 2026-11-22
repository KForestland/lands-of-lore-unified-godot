extends "res://tests/helpers/owner_gaps_input.gd"
func run():
 if not await boot_owner("L12_CM","l12_platform"):return
 # Local cave-switch fixture, not a claim to have walked from the report stand.
 scene.player.position=Vector3(3430,-218,-6500);scene.player.velocity=Vector3.ZERO
 scene.set_physics_process(true);await ticks(6);await look(Vector3(3430,-218,-6580));await hold_key(KEY_W,6)
 await key(KEY_E);await ticks(10);await frame("tiger_switch")
 if not check(scene.quest_state.get("l12_tiger_platform",{}).get("activated",false),"RealW/E at the tiger-cave switch starts platform rise"):return
 if not check(scene.progression.floor_motion.has(1899) and int(scene.progression.regions[1899][1])>-275,"Original report deck actually rises"):return
 await key(KEY_F5)
 var read:=Saves.read_document(Saves.slot_path(1))
 if not check(read.error.is_empty() and read.state.area_save.quests.get("l12_tiger_platform",{}).get("activated",false),"ActualF5 captures new switch receipt"):return
 if not await reload():return
 await ticks(360)
 if not check(int(scene.progression.regions[1899][1])==-150,"ActualF9 continues to raised platform target without re-firing switch"):return
 # Second local stand is disclosed: a real running jump from raised native
 # floe1897 to the tower, no pose changes between that stand and reward/save.
 scene.player.position=Vector3(3822.75,-118,-8729.5);scene.player.velocity=Vector3.ZERO
 scene.set_physics_process(true);await ticks(8)
 if not check(scene.player.is_on_floor(),"Local floe stand settles on its actual raised collision"):return
 await look(Vector3(3890,-108,-8900))
 set_key(KEY_SHIFT,true);set_key(KEY_W,true);await ticks(4);await key(KEY_SPACE)
 var airborne:=false
 for i in 110:
  await physics_frame
  if not scene.player.is_on_floor():airborne=true
  if Vector2(scene.player.position.x-3890,scene.player.position.z+8900).length()<16:break
 set_key(KEY_W,false);set_key(KEY_SHIFT,false);await ticks(40)
 print("TIGER JUMP at=",scene.player.position," region=",scene.progression.region_at(scene.player.position)," form=",scene.player_form," airborne=",airborne," resets=",scene.resets)
 if not check(airborne and scene.player.is_on_floor() and scene.progression.region_at(scene.player.position)==1899 and scene.resets==0,"RealW/Shift/Space crosses from floe onto actual tower with no recovery"):return
 var owner:Node=scene.get_node("L12TigerPlatform")
 await look(owner.sprite.global_position);await frame("tiger_platform_blizzard");await key(KEY_E)
 if not check(owner.state().taken and "act2:L12_CM:blizzard" in scene.carried_collected and not owner.sprite.visible,"RealE takes original definition18 Blizzard from raised platform"):return
 await key(KEY_E)
 if not check(scene.carried_collected.count("act2:L12_CM:blizzard")==1,"RepeatedE cannot copy Blizzard"):return
 await key(KEY_F5)
 if not await reload():return
 if not check(scene.quest_state.l12_tiger_platform.taken and scene.carried_collected.count("act2:L12_CM:blizzard")==1 and not scene.get_node("L12TigerPlatform").sprite.visible,"ActualF5/F9 keeps exact axe and empty tower"):return
 print("PASS owner tiger replacement realW/E, movingF5/F9, actual running jump/E Blizzard/repeat/F5/F9; two supplied local stands, held NPCs, not cave-to-lake earned walk")
 quit()
