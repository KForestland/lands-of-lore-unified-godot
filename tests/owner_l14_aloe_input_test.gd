extends "res://tests/helpers/owner_gaps_input.gd"
func run():
 if not await boot_owner("L14_HT","l14_bed"):return
 var before:Array=scene.carried_collected.duplicate()
 if not check(scene.get_node("L14AloeBed").sprite.visible,"Harvestable Aloe is actually drawn on the bed"):return
 await look(Vector3(607,24,-4139));scene.set_physics_process(true);await hold_key(KEY_W,3);scene.set_physics_process(false)
 # Capacity fixture uses the shared API; all temporary ids are removed by
 # the same API before the actual pickup. Exclude every reserved quest identity
 # so cleanup cannot ask the production protection to discard a needed item.
 var Grants=preload("res://scripts/lol2/item_grants.gd")
 var Catalog=preload("res://scripts/lol2/item_catalog.gd")
 var Protection=preload("res://scripts/lol2/quest_resource_protection.gd")
 for id:String in Catalog.ids("jungle"):
  if scene.carried_collected.size()==64:break
  if Protection.data().obligations.any(func(row):return Protection.matches(row,id)):continue
  if Grants.known(scene,id) and id not in scene.carried_collected:
   if not check(Grants.grant(scene,id,{"cap":false}).ok,"Disclosed capacity fixture grant"):return
 if not check(scene.carried_collected.size()==64,"Full inventory fixture"):return
 await key(KEY_E)
 if not check(scene.quest_state.get("l14_aloe_bed",{}).get("item","").is_empty() and scene.carried_collected.size()==64,"ActualE full refusal leaves bed unpicked and pack untouched"):return
 if not check(Grants.commit(scene,before.duplicate(),{"sync":true}).ok,"Remove only temporary fixture items through shared API"):return
 var reused:String=preload("res://scripts/lol2/jungle_harvest_items.gd").next_free("aloe",before)
 if reused not in scene.item_effects.state().spent:scene.item_effects.state().spent.append(reused) # Disclosed consumed-pool fixture.
 await frame("aloe_available");await key(KEY_E);await frame("aloe_report")
 var state:Dictionary=scene.quest_state.get("l14_aloe_bed",{})
 if not check(not str(state.get("item","")).is_empty() and state.item in scene.carried_collected and scene.carried_collected.size()==before.size()+1,"ActualE harvests one Aloe at owner's bed"):return
 if not check(not scene.get_node("L14AloeBed").sprite.visible,"Harvest removes only the modern Aloe picture"):return
 var item:String=state.item
 if not check(item==reused and item not in scene.item_effects.state().spent,"Existing renewable Aloe pool receipt is released on actual harvest"):return
 await key(KEY_E)
 if not check(scene.carried_collected.count(item)==1,"RepeatedE cannot copy bed reward"):return
 await key(KEY_F5)
 if not await reload():return
 if not check(scene.quest_state.l14_aloe_bed.item==item and scene.carried_collected.count(item)==1,"ActualF5/F9 keeps bed receipt and exact item"):return
 print("PASS owner Temple bed actualE grants existing Aloe once, repeatE/F5/F9 keep exact item; unchanged owner input, held NPCs")
 quit()
