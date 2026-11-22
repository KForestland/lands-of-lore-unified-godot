extends "res://tests/helpers/quest_temple_resource_input.gd"
## Untouched City-ground producer save. Natural timed form expiry, real keys,
## inventory/belt, casts, five spare uses, last-copy refusal, real walk/E/F5/F9.
func leaves()->Array:
 return scene.carried_collected.filter(func(id):return preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==117)
func main():
 if not await boot_legacy("res://tests/fixtures/quest_resource_inputs/city_natural_human.json","c3d38a254ea222bd73f2f288069622a18777debcc988544cda34bb94fccc4bd3","lol2-restoration-map-L16_CA","res://scenes/lol2/maps/L16_CA.tscn"):return
 for tick in 8400:
  if tick%1200==0:print("CITY_FORM ",tick," ",scene.curse.state," fps=",Engine.get_frames_per_second())
  if scene.player_form==0:break
  if not require(hp()>0 and scene.resets==0,"Survive the original timed Beast interval"):return
  await physics_frame
 if not require(scene.player_form==0 and leaves().size()==6,"Natural Human, genuine six carried Silverleaves"):return
 if not await disk_cycle("city_natural_human"):return
 if not require(scene._quicksave_unrecorded("res://tmp/quest_city_natural_human_earned_save.json").is_empty(),"Game-written natural Human output for repeatable source-pinned follow-up"):return
 if not await belt_item(str(leaves()[0])):return
 if not require(not paused and captured(),"Inventory really closed and world input restored"):return
 for copy in 6:
  if not await look(scene.camera.global_position+Vector3(0,200,-300)):return
  await ticks(35);await tap(KEY_1);await tap(KEY_Q,true);await frames(2)
  var before:int=leaves().size()
  if not require(int(scene.starting_magic.magic_state().player.mana)<int(scene.starting_magic.magic_state().player.maximum),"Real Spark spends mana before the leaf: notice="+scene.starting_magic.notice_text()+" hud="+hud()+" paused="+str(paused)+" captured="+str(captured())):return
  await tap(KEY_F);await frames(2)
  if copy<5:
   if not require(leaves().size()==before-1,"True spare Silverleaf remains usable"):return
  else:
   if not require(leaves().size()==1 and hud()=="Keep a Silverleaf for the glass pyramid in the City.","Last needed Silverleaf remains with its named reason: "+hud()):return
 if not await disk_cycle("city_last_leaf"):return
 if not require(leaves().size()==1,"F9 preserves the reserve"):return
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_ground_to_greenhouse.json"))
 if not await walk(route,"City streets to glass pyramid",{"no_fight":true}):quit(1);return
 var greenhouse:Node=scene.get_node("L16Greenhouse")
 if not await look(greenhouse.PLATE):return
 await tap(KEY_E);await frames(4)
 if not require(leaves().is_empty() and not greenhouse.state().silverleaf.is_empty(),"Real E accepts the last needed copy atomically for its goal"):return
 if not await disk_cycle("city_leaf_offered"):return
 if not require(not scene.get_node("L16Greenhouse").state().silverleaf.is_empty() and scene.resets==0,"Pyramid receipt persists with zero fall resets"):return
 print("PASS City six real leaves: five spare F uses; last-copy refusal; real street walk; last-copy E offering; F5/F9")
 quit()
