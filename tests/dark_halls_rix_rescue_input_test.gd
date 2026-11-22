extends "res://tests/helpers/dark_halls_rix_input.gd"
## Genuine alive owner200HP; local Rix/scroll stands, held AI/route/slot are
## component aids. Real E pickup/study/left-click weakening/Prism5/F5F9. No health,
## book, soul or quest-state edits in this primary Prism route; no earned-walk claim.
const SCROLL:="darkhalls:control971u1:Prsmscrl"
func at_rix()->bool:
 var body:Node3D=scene.creatures.bodies["57"]
 await component_stand(body.global_position+Vector3(60,32,0))
 await look(body.global_position+Vector3(0,20,0));await ticks(2)
 var ray:Dictionary=preload("res://scripts/lol2/player_combat.gd").aim_ray(scene,110,259)
 print("RIX_VISIBLE ",ray.get("collider")," wanted=",body," at=",scene.player.position)
 return check(not ray.is_empty() and ray.collider==body,"Fixture aims at the real unobscured living Rix")
func acquire_spell()->bool:
 var row:Dictionary=scene.loot.source.controls.filter(func(c):return int(c.control)==971)[0]
 var point:=Vector3(row.position[0],row.position[1],row.position[2])
 await component_stand(point+Vector3(50,32,0));await look(point+Vector3(0,24,0));await key(KEY_E)
 if not check(SCROLL in scene.carried_collected and int(scene.loot.taken().get("971",0))==1,"ActualE collects native Prism scroll with its receipt"):return false
 if not await study(SCROLL):return false
 return check(SCROLL not in scene.carried_collected and "prism5" in scene.starting_magic.magic_state().spellbook.learned,"Actual stored scroll learns existing Prism5; no Rix lesson grants it")

func weaken()->bool:
 for i in 60:
  if int(scene.creatures.state.actors["57"].health)<=100:break
  var hp_before:int=scene.creatures.state.actors["57"].health
  await button(MOUSE_BUTTON_LEFT,Vector2(640,360));await ticks(35)
  print("RIX_MELEE ",i," hp=",scene.creatures.state.actors["57"].health," before=",hp_before," mouse=",Input.mouse_mode," cursor=",scene.interface_hud.cursor_active," paused=",paused," active=",scene.starting_magic.world_active()," cd=",scene.creatures.strike_remaining," eq=",scene.equipped_item)
  if scene.creatures.state.actors["57"].health==hp_before:break
 if not check(scene.creatures.state.actors["57"].health>0 and scene.creatures.state.actors["57"].health<=100,"Ordinary actualleftclick weakens living Rix to source half-health"):return false
 return true
func rescue_cast():
 await key(KEY_5);await charge(KEY_Q,false,true)
func cast_pack_ok(before:Array)->bool:return scene.carried_collected==before
func fault_checks()->bool:return true
func after_rescued_load()->bool:return true
func route_name()->String:return "learned Prism5"
func disk_phase()->bool:
 scene.set_physics_process(true);await ticks(90);scene.set_physics_process(false)
 var before_sha:String=FileAccess.get_sha256(Saves.slot_path(10))
 await key(KEY_F5);await ticks(4)
 print("R143_SAVE_STATUS ",scene.interface_hud.save_status.text," serial=",Session.for_tree(self).last_slot," validation=",Saves.validate(Saves.make_document(scene,10)))
 if not check(FileAccess.get_sha256(Saves.slot_path(10))!=before_sha,"F5 wrote fresh bytes: "+scene.interface_hud.save_status.text):return false
 var doc:Dictionary=Saves.read_document(Saves.slot_path(10))
 print("R143_PHASE disk=",doc.error," hp=",scene.creatures.state.actors["57"].health," saved=",doc.get("state",{}).get("area_save",{}).get("quests",{}).get("dark_halls_population",{}).get("actors",{}).get("57",{})," line=",scene.interface_hud.hint.text," can=",scene.can_save())
 if not check(doc.error.is_empty(),"Actual F5 remains valid in each Rix phase"):return false
 return await reload()
func at_spell_range()->bool:
 var body:Node3D=scene.creatures.bodies["57"]
 for offset in [Vector3(160,32,0),Vector3(-160,32,0),Vector3(0,32,160),Vector3(0,32,-160)]:
  await component_stand(body.global_position+offset);await look(body.global_position+Vector3.UP*20);await ticks(2)
  if scene.rix.aimed_spell():return check(not scene.rix.aimed_living(),"Spell first-hit is beyond E reach")
 return check(false,"No clear source stand beyond E reach")
func run():
 if not await owner_rix("alive"):return
 if not check(scene.creatures.state.actors["57"].health==200 and not scene.rix.state().dead,"Genuinely alive source200 Rix, no resurrection"):return
 if not await at_rix():return
 var book_before:Dictionary=scene.starting_magic.magic_state().get("spellbook",{}).duplicate(true)
 await key(KEY_E);await ticks(2)
 if not check(scene.starting_magic.magic_state().get("spellbook",{})==book_before and not scene.rix.state().get("rescued",false),"E guides only: no lesson acquisition or rescue bypass"):return
 if not check(preload("res://scripts/lol2/my_journal.gd").notes(scene).count("dark_halls_rix_rescue")==1 and scene.interface_hud.lesson_remaining>5.5,"Once-only Journal and at least six-second lesson HUD"):return
 await frame("rix_unlearned_lesson")
 if not check("Rix" in scene.interface_hud.hint.text and "Weaken" in scene.interface_hud.hint.text,"ActualE names how to weaken/free living Rix"):return
 if not await acquire_spell():return
 if not await at_rix():return
 var healthy_pack:Array=scene.carried_collected.duplicate();var healthy_mana:int=scene.starting_magic.magic_state().player.mana
 await rescue_cast();await ticks(2)
 print("R143_HEALTHY hp=",scene.creatures.state.actors["57"].health," pack=",scene.carried_collected==healthy_pack," mana=",scene.starting_magic.magic_state().player.mana," expected=",healthy_mana," hint=",scene.interface_hud.hint.text," notice=",scene.starting_magic.notice_text())
 if not check(scene.creatures.state.actors["57"].health==200 and not scene.rix.state().get("rescued",false) and scene.carried_collected==healthy_pack and scene.starting_magic.magic_state().player.mana==healthy_mana and scene.interface_hud.hint.text.contains("Weaken Rix to half health first.") and scene.starting_magic.notice_text()=="Weaken Rix to half health first.","Healthy Rix targeted refusal preserves health/mana/item and says why"):return
 if not await at_rix():return
 if not await weaken():return
 await key(KEY_E);await ticks(2)
 if not check(scene.rix.accepts_player_spell("mists1") and scene.rix.accepts_player_spell("prism5") and not scene.rix.accepts_player_spell("prism3") and not scene.rix.accepts_player_spell("mists3"),"Pure target query admits only approved existing Mists1/Prism5"):return
 if not await disk_phase():return
 if not check(scene.creatures.state.actors["57"].health>0 and scene.creatures.state.actors["57"].health<=100 and not scene.rix.state().get("rescued",false),"F5/F9 keeps weakened, not rescued, Rix"):return
 if not await at_spell_range():return
 if not await fault_checks():return
 var soul:int=scene.quest_state.monastery.globals.GV_LUTHERS_SOUL
 var pack:Array=scene.carried_collected.duplicate()
 await rescue_cast();await ticks(3)
 if not check(scene.rix.state().get("rescued",false) and not scene.rix.state().dead and not scene.rix.state().staff,"Actual rescue cast frees living Rix without a corpse/staff gift"):return
 if not check(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==mini(10,soul+2) and cast_pack_ok(pack),"Native completion adds soul2 once, only the declared stored source may be consumed"):return
 scene.set_physics_process(true);await ticks(90);scene.set_physics_process(false)
 await key(KEY_F5);await ticks(3)
 var doc:Dictionary=Saves.read_document(Saves.slot_path(10))
 if not check(doc.error.is_empty() and doc.state.area_save.quests.dark_halls_rix.get("rescued",false),"ActualF5 writes the rescue/native receipt"):return
 if not await reload():return
 if not check(scene.rix.state().get("rescued",false) and scene.creatures.state.actors["57"].health>0,"ActualF9 preserves living rescue"):return
 if not check(scene.creatures.peaceful_actor("57"),"Loaded rescued Rix is peaceful and cannot be damaged"):return
 if not await after_rescued_load():return
 if not check(preload("res://scripts/lol2/my_journal.gd").notes(scene).count("dark_halls_rix_rescue")==1,"F9 keeps one rescue note"):return
 if not await at_rix():return
 var before:Dictionary=scene.rix.state().duplicate(true);soul=scene.quest_state.monastery.globals.GV_LUTHERS_SOUL
 var mana:int=scene.starting_magic.magic_state().player.mana
 await rescue_cast();await ticks(2)
 if not check(scene.rix.state()==before and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==soul and scene.starting_magic.magic_state().player.mana==mana,"Repeat cast neither rewards nor spends mana"):return
 await key(KEY_E);await ticks(2)
 if not check(scene.rix.state().get("talked",false),"ActualE runs native talk14388 status receipt"):return
 var talked:Dictionary=scene.rix.state().duplicate(true)
 await key(KEY_E);await ticks(2)
 if not check(scene.rix.state()==talked,"Real repeated E is idempotent"):return
 var health:int=scene.creatures.state.actors["57"].health
 await button(MOUSE_BUTTON_LEFT,Vector2(640,360));await ticks(35)
 if scene.starting_magic.magic_state().player.mana>0:
  await key(KEY_1);await charge(KEY_Q);await ticks(3)
 if not check(not scene.creatures.receive_damage("57",999) and scene.creatures.environment_damage("57",999)==0,"Shared weapon/spell and environment entry points refuse rescued damage before rewards"):return
 if not check(scene.creatures.state.actors["57"].health==health and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==soul and not scene.rix.state().dead and not scene.rix.state().staff,"Real melee/Spark plus common damage checks cannot kill Rix, change Soul or give staff"):return
 if not await disk_phase():return
 if not check(scene.rix.state().get("talked",false) and scene.creatures.peaceful_actor("57") and scene.creatures.state.actors["57"].health==health,"Talked/peaceful phase survives actual F5/F9"):return
 await frame("rix_alive_freed_"+route_name().replace(" ","_"))
 print("PASS R143 actual owner200/healthy refusal/ordinary melee/weakened F5F9/first-hit beyond E reach/%s/native rescue+soul2/exclusive staff/peaceful damage guards/idempotent talk and F5F9; disclosed local stands, held clocks/AI and child-specific item/fault fixtures; not earned walk"%route_name())
 quit()
