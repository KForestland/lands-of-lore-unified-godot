extends "res://tests/helpers/owner_gaps_input.gd"
## Unchanged owner Hive recorder-start and Jungle post-offer report saves. Local approach-region and
## NPC stands/held host movement are disclosed; speech uses ordinary real time.
const Targets=preload("res://scripts/lol2/item_belt_targets.gd")
const WAX:="hive:Wax_runes:0"
func _initialize():main.call_deferred()
func settled():
 for i in 1800:
  await process_frame
  if scene.get("ready_for_review")==true and is_instance_valid(scene.get("starting_magic")):break
 scene.set_physics_process(false)
 scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;await ticks(3)
func owner(index:int)->bool:
 var m:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/wax_belt_inputs_manifest.json"));var row:Dictionary=m.files[index]
 if not check(FileAccess.get_sha256("res://"+row.path)==row.sha256,"Unchanged owner Wax pin"):return false
 if not is_instance_valid(scene):
  scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
 DirAccess.make_dir_recursive_absolute(Saves.ROOT)
 var file:=FileAccess.open(Saves.slot_path(10),FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes("res://"+row.path));file.close();Session.for_tree(self).last_slot=10
 return await reload()
func stand(point:Vector3):
 scene.player.position=point;scene.player.velocity=Vector3.ZERO # Local component approach stand, not earned travel.
 await ticks(3)
func region_point(region:int)->Vector3:
 for row in scene.dawn.src.regions:
  if int(row.region)!=region:continue
  var point:=Vector2.ZERO
  for v in row.polygon:point+=Vector2(v[0],v[1])
  point/=row.polygon.size();return Vector3(point.x,float(row.floor_min)+32,point.y)+scene.dawn.origin()
 return Vector3.ZERO
func run_case(held:String)->bool:
 if not await owner(1):return false
 if not check(scene.get("dawn")==null,"Recorder start is genuinely Hive, not a forged Jungle save"):return false
 # Local source exit approach, then actual W crosses the native route polygon.
 await stand(Vector3(848,24,-4447));await look(Vector3(864,24,-4590))
 var old_id:int=scene.get_instance_id();scene.set_physics_process(true);set_key(KEY_W,true)
 for i in 600:
  await physics_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id:break
 set_key(KEY_W,false)
 scene=current_scene;await settled()
 if not check(is_instance_valid(scene.get("dawn")),"Real Hive exit W carries the unchanged start into Jungle"):return false
 if not check(int(scene.dawn.state.locals["17"])==0 and WAX in scene.carried_collected,"Genuine earned pre-offer state; no added items/story"):return false
 await stand(region_point(2812));await ticks(4)
 if not check(scene.dawn.state.present and int(scene.dawn.state.locals["19"])==0,"Actual pre-greeting region spawns Dawn before any gift"):return false
 await stand(Vector3(-5761,-68,4004));await look(scene.dawn.population.bodies["63"].global_position+Vector3.UP*30)
 for i in 7200:
  await physics_frame
  if scene.dawn.can_use():break
 if not check(scene.dawn.can_use(),"Real region/speech clocks reach ordinary offer admission"):return false
 if held.is_empty():
  # Temporary form/body fixtures: restore Human before any save or gift.
  var form_pack:Array=scene.carried_collected.duplicate()
  for form in [1,2]:
   scene.player_form=form
   preload("res://scripts/lol2/player_form_body.gd").apply(scene.player,scene.camera,form,false)
   await look(scene.dawn.population.bodies["63"].global_position+Vector3.UP*30);await ticks(3)
   var other:Dictionary=Targets.find(scene)
   if not check(scene.dawn.belt_wax().is_empty() and (other.is_empty() or other.owner!=scene.dawn),"Actual nonhuman view has no smart Wax offer"):return false
   await key(KEY_E);await ticks(2)
   if not check(scene.carried_collected==form_pack and int(scene.dawn.state.locals["17"])==0,"Actual nonhuman empty-hand E gives nothing and keeps both copies"):return false
   print("R144_FORM ",form," hint=",scene.dawn.interaction_hint()," pack unchanged")
  scene.player_form=0
  preload("res://scripts/lol2/player_form_body.gd").apply(scene.player,scene.camera,0,false)
  await look(scene.dawn.population.bodies["63"].global_position+Vector3.UP*30);await ticks(3)
 if not check(held.is_empty() or held in scene.carried_collected,"Supplied hand fixture is owned"):return false
 scene.hand_item=held # Explicit empty/Wax/Flute initial hand selection fixture.
 var before:Dictionary=scene.dawn.checkpoint().duplicate(true);var pack:Array=scene.carried_collected.duplicate();var hand:String=scene.hand_item
 var whole_before:Dictionary=scene.area_snapshot().duplicate(true)
 var effects_before:Dictionary=scene.item_effects.state().duplicate(true)
 var log_before:Array=scene.dawn.effect_log.duplicate(true)
 var preview_builds:int=scene.dawn.wax_preview_runs
 var preview_start:int=Time.get_ticks_usec()
 for i in 100:
  Targets.find(scene);scene.dawn.interaction_hint()
 print("R144_PREVIEW100 us=",Time.get_ticks_usec()-preview_start," native_builds=",scene.dawn.wax_preview_runs-preview_builds," held=",held)
 if not check(scene.area_snapshot()==whole_before and scene.item_effects.state()==effects_before and scene.dawn.effect_log==log_before and scene.dawn.wax_preview_runs-preview_builds<=1,"N hint/find queries share one preview and mutate no whole-save/effects/native-log state"):return false
 if not check(scene.dawn.checkpoint()==before and scene.carried_collected==pack and scene.hand_item==hand,"Target discovery cannot give, consume or edit encounter"):return false
 await ticks(15)
 if not check(preload("res://scripts/lol2/item_belt_state.gd").resolve(scene.item_effects.belt_state(),int(scene.item_effects.belt_state().active),scene.carried_collected)==WAX,"Looking at Dawn rolls to carried Wax even with all slots occupied"):return false
 if not check(scene.item_effects.smart_item==WAX and scene.dawn.interaction_hint()=="E — give the Wax runes to Dawn","Belt and existing HUD agree on real E, with no obsolete hold-first instruction"):return false
 await frame("wax_belt_before_E_"+("empty" if held.is_empty() else "wax" if held==WAX else "flute"))
 var groups_before:int=scene.dawn.effect_log.filter(func(e):return e.get("type")=="group" and int(e.get("group",-1))==29704).size()
 var soul_before:int=scene.quest_state.monastery.globals.GV_LUTHERS_SOUL
 await key(KEY_E);await ticks(3)
 if not check(scene.dawn.effect_log.filter(func(e):return e.get("type")=="group" and int(e.get("group",-1))==29704).size()==groups_before+1 and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==mini(10,soul_before+2),"One viewport E enters native29704 and its Soul reward exactly once"):return false
 if not check(scene.interface_hud.hint.text=="You give the Wax runes to Dawn.","One plain success line survives; no second handler refusal"):return false
 if not check(scene.carried_collected.size()==pack.size()-1 and WAX not in scene.carried_collected and int(scene.dawn.state.locals["17"])==1,"Real E gives exactly one Wax through native29704"):return false
 if not check(scene.hand_item==(hand if hand in scene.carried_collected else ""),"Temporary hand selection restored without resurrecting consumed item"):return false
 scene.set_physics_process(true)
 for i in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 var save_before:String=FileAccess.get_sha256(Saves.slot_path(10))
 await key(KEY_F5);await ticks(4)
 if not check(FileAccess.get_sha256(Saves.slot_path(10))!=save_before,"F5 writes fresh bytes immediately after the give"):return false
 var written:=Saves.read_document(Saves.slot_path(10))
 if not check(written.error.is_empty() and int(written.state.area_save.quests.jungle_dawn.state.locals["17"])==1,"Actual F5 writes the offer state"):return false
 if not await reload():return false
 if not check(int(scene.dawn.state.locals["17"])==1 and WAX not in scene.carried_collected and "hive:Wax_runes:1" in scene.carried_collected and preload("res://scripts/lol2/item_catalog.gd").Monastery.FLUTE in scene.carried_collected,"F9 keeps one exact consumed Wax, the spare and the Flute"):return false
 if not await owner(0):return false
 await look(scene.dawn.population.bodies["63"].global_position+Vector3.UP*30)
 pack=scene.carried_collected.duplicate();var soul:int=scene.quest_state.monastery.globals.GV_LUTHERS_SOUL
 var preview:Array=scene.dawn.State.offer(scene.dawn.state.duplicate(true),scene.dawn.src.duplicate(true),scene.dawn.WAX_IDENTITY,scene.dawn.context().duplicate(true))
 if not check(not preview.any(func(e):return e.get("type")=="group" and int(e.get("group",-1))==29704),"Native29704 remains closed after the real gift, independently of the current speech guard"):return false
 if not check(Targets.find(scene).is_empty(),"Already-given report is not offered a second native Wax gift"):return false
 await key(KEY_E);await ticks(3)
 if not check(scene.carried_collected==pack and scene.quest_state.monastery.globals.GV_LUTHERS_SOUL==soul,"Extra Wax in owner report stays owned; no repeat gift/reward"):return false
 return true
func main():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 for held in ["",WAX,preload("res://scripts/lol2/item_catalog.gd").Monastery.FLUTE]:
  if not await run_case(held):return
 print("PASS R144 three unchanged-owner Hive/W-exit/Dawn cases: empty hand, Wax held, Flute held; one real E/native29704/consume/reward/success line, restored still-owned hand, fresh F5/F9/spare/Flute;100 cached pure whole-save previews each; disclosed stands/hand/held-root/slot fixtures, ordinary clocks, not earned route")
 quit()
