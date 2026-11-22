extends "res://tests/helpers/g15_stored_spell_input.gd"
## Component fixtures: fresh L8, valid admitted-journey story, real-ID grants,
## held NPCs and a grounded village stand; cached invalid policy fault injection.
## Only actual key/mouse input invokes the mix. Not an earned campaign route.
const Guard=preload("res://scripts/lol2/quest_resource_protection.gd")
const Journey=preload("res://scripts/lol2/l8_journey_state.gd")
const Trade=preload("res://scripts/lol2/l8_shaman_trade.gd")
const LEAF="act2:L10_DC:silverleaf159"
const SPARE="act2:L10_DC:silverleaf160"
func mode()->String:return "inventory"
func _initialize():main.call_deferred()
func select_serum()->bool:
 var list:ItemList=scene.inventory.item_list
 for i in list.item_count:
  if str(list.get_item_metadata(i))==Trade.SERUM:
   await button(MOUSE_BUTTON_LEFT,list.get_global_transform_with_canvas()*list.get_item_rect(i).get_center())
   await frames(3)
   return require(scene.inventory.selected_index==i,"Actual click selects carried Serum")
 return require(false,"Granted actual Serum appears in pack")
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock"):return
 scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for i in 2400:
  await process_frame
  if scene.ready_for_review and is_instance_valid(scene.get("item_effects")):break
 use_guard=false;await adopt()
 if not captured():await lclick();await frames(3)
 scene.act2_creatures.set_physics_process(false);scene.progression.change_scene_enabled=false
 for id:String in [Trade.SERUM,LEAF,SPARE,Journey.BLADE]:
  if id not in scene.carried_collected:
   if not require(Grants.grant(scene,id,{"cap":false,"history":"act2_once" if id.begins_with("act2:") else "none","sync":true}).ok,"Genuine-ID component grant "+id):return
 var story:=Journey.initial();story.gift="recovered";story.temple_visited=true;story.admitted=true
 scene.quest_state.l8_journey=story
 scene.player.position=Vector3(676,33,-4451);scene.player.velocity=Vector3.ZERO
 await ticks(20)
 if not require(hp()>0 and scene.resets==0 and scene.player.is_on_floor(),"Supplied village stand settles without recovery"):return
 var owner:Node=scene.get_node("L8Larkhon")
 if not require(owner.can_mix(Trade.SERUM),"Real owner admits recipe before protection fault"):return
 var valid:Dictionary=Guard.data().duplicate(true)
 Guard.policy={};Guard.policy_loaded=true;Guard.policy_warning=true
 var before:Array=scene.carried_collected.duplicate()
 var before_mix:Dictionary=owner.state().duplicate(true)
 var before_history:Dictionary=scene.quest_state.get("act2_items",{}).duplicate(true)
 if mode()=="village":
  await look(scene.get_node("L8Journey").TARGETS.village)
  await tap(KEY_E);await frames(4)
  if not require(paused and scene.get_node("L8Journey").opened=="village","Actual E opens village"):return
  if not require(await click_button("Approach the shaman's treehouse"),"Actual click approaches shaman"):return
  if not require(await click_button("Mix the Amaranth Serum"),"Actual click requests station mix"):return
  await frames(3)
  if not require(scene.get_node("L8Journey").notice=="This item cannot be used right now." and scene.get_node("L8Journey").box.get_child(0).is_visible_in_tree() and scene.get_node("L8Journey").box.get_child(0).text=="This item cannot be used right now.","Station displays actual denied-admission sentence instead of missing-ingredients fiction"):return
 else:
  await tap(KEY_I);await frames(4)
  if not require(paused and is_instance_valid(scene.inventory),"Actual I opens pack"):return
  if not await select_serum():return
  if not require(await click_button("Mix with Silverleaf"),"Actual click requests inventory mix"):return
  await frames(3)
  if not require(is_instance_valid(scene.inventory) and scene.inventory.detail_text.is_visible_in_tree() and scene.inventory.detail_text.text=="This item cannot be used right now.","Inventory displays actual denied-admission sentence"):return
 if not require(scene.carried_collected==before and owner.state()==before_mix and scene.quest_state.get("act2_items",{})==before_history,"Denied mix preserves exact pack, owner state and item history"):return
 await picture("r131_mix_refused_"+mode())
 Guard.policy=valid
 if mode()=="village":
  if not require(await click_button("Mix the Amaranth Serum"),"Same station button retries after rule recovery"):return
 else:
  if not require(await click_button("Mix with Silverleaf"),"Same inventory button retries after rule recovery"):return
 await frames(4)
 if not require(owner.State.mixed(owner.state()) and owner.State.VAPORS in scene.carried_collected and Trade.SERUM not in scene.carried_collected and LEAF not in scene.carried_collected,"Positive retry consumes the recipe once and makes actual vapors"):return
 if paused:await tap(KEY_ESCAPE);await frames(4)
 if not captured():await lclick();await frames(3)
 if not await disk_cycle("r131_mix_"+mode()):return
 if not require(scene.get_node("L8Larkhon").State.mixed(scene.get_node("L8Larkhon").state()),"Actual F5/F9 retains positive mix"):return
 print("PASS R131 ",mode()," actual input denied-mix visible reason, exact pack/state/history conservation, positive retry and F5/F9 at1/60; component fixtures disclosed")
 quit()
