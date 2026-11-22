extends "res://tests/helpers/g15_stored_spell_input.gd"
## Real inventory clicks, genuine cross-level ids, explicit health/mana/NPC fixtures.
const ALOE:="act2:L14_HT:item68"
const SPARE:="jungle:item63:Cave_aloe"
const LICHEN:="act2:L16_CA:lichen518"
const ROOT:="act2:L13_RC:item53"
const MIND:="jungle:item4:Mind_clustr"
func _initialize():main.call_deferred()
func use_food(id:String)->bool:
 if is_instance_valid(scene.inventory):await tap(KEY_ESCAPE)
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Actual I opens the inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Actual item is in the inventory grid"):return false
 var rect:Rect2=list.get_item_rect(index)
 await button(MOUSE_BUTTON_RIGHT,list.get_global_transform_with_canvas()*rect.get_center())
 await frames(2)
 if is_instance_valid(scene.inventory) and is_instance_valid(scene.inventory.item_menu):
  await button(MOUSE_BUTTON_LEFT,scene.inventory.item_menu.get_node("Choices/UseItem").get_global_rect().get_center())
 await frames(4)
 return true
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([ALOE,SPARE,LICHEN,ROOT,MIND]):return
 # The supplied Act1 item retains the genuine pickup row required by its save validator.
 scene.quest_state.jungle_world_items={"version":1,"collected":[4,63]}
 var magic:Node=scene.starting_magic;magic.set_process(false)
 if not await use_food(LICHEN):return
 if not require(LICHEN in scene.carried_collected and magic.health()==30,"Full-health lichen is kept"):return
 magic.set_health(3)
 if not await use_food(LICHEN):return
 if not require(magic.health()==23 and LICHEN not in scene.carried_collected and scene.item_effects.state().spent.count(LICHEN)==1,"Actual cross-level lichen heals20 and consumes once"):return
 await picture("lichen_used")
 magic.set_health(10)
 if not await use_food(ALOE):return
 if not require(ALOE in scene.carried_collected and scene.inventory.detail_text.text=="Keep this aloe for the Temple priest's ritual.","Even wounded, the exact last-needed Temple Aloe stays for its ritual"):return
 if not await use_food(SPARE):return
 for tick in 600:
  await physics_frame
  if scene.item_effects.state().aloe.pending==0:break
 if not require(magic.health()>=15 and magic.health()<=16 and SPARE not in scene.carried_collected and ALOE in scene.carried_collected,"Free Aloe heals by the same pending5/native closing tick; the exact Temple ingredient remains"):return
 if not await use_food(MIND):return
 if not require(MIND not in scene.carried_collected and scene.atlas_explored.areas.L10_DC.full,"Actual Act1 Mind Cluster reveals the current Act2 atlas"):return
 if not require(is_instance_valid(scene.inventory)==false,"Successful use closes the paused inventory"):return
 magic.set_health(2)
 var mana:Dictionary=magic.magic_state().duplicate(true);mana.player.mana=0;magic.commit(mana)
 if not await use_food(ROOT):return
 if not require(magic.health()==30 and magic.magic_state().player.mana==mini(20,int(mana.player.maximum)) and ROOT not in scene.carried_collected and scene.item_effects.is_asleep(),"Actual Mandrake heals40/cap, restores20mana/cap and starts five-second sleep"):return
 var at:Vector3=scene.player.global_position
 var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events()
 for tick in 12:await physics_frame
 event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
 if not require(scene.player.global_position.distance_to(at)<1.0 and scene.player.is_on_floor(),"Real W cannot walk while asleep; gravity/floor stay live"):return
 await tap(KEY_I)
 if not require(not is_instance_valid(scene.inventory),"Real I cannot open the inventory during sleep"):return
 await tap(KEY_Q)
 if not require(not magic.available() and magic.magic_state().player.mana==mini(20,int(mana.player.maximum)),"Sleep prevents an actual cast without spending mana"):return
 scene.item_effects.set_process(false) # Exact saved timer fixture, not a duration claim.
 var remaining:float=scene.item_effects.state().mandrake_sleep
 if not await disk_cycle("item_consumables"):
  print("FOOD_SAVE_FAILURE can=",scene.can_save()," hud=",scene.interface_hud.hint.text);return
 if not require(scene.item_effects.state().spent.has(ROOT) and float(scene.item_effects.state().mandrake_sleep)>0.0 and float(scene.item_effects.state().mandrake_sleep)<=remaining and scene.atlas_explored.areas.L10_DC.full,"F5/F9 keeps consumed sources, sleep and revealed atlas"):return
 var written:Dictionary=preload("res://scripts/lol2/game_save.gd").read_document(preload("res://scripts/lol2/game_save.gd").slot_path(1)).state
 if not require(absf(float(written.area_save.inventory.item_effects.mandrake_sleep)-remaining)<0.00001,"Actual on-disk slot retains exact frozen timer; loaded clock advances normally"):return
 scene.item_effects.set_process(true)
 for tick in 600:
  await physics_frame
  if not scene.item_effects.is_asleep():break
 if not require(not scene.item_effects.is_asleep() and scene.starting_magic.health()>0 and scene.resets==0,"Sleep expires on the ordinary gameplay clock; zero recovery"):return
 print("PASS game-wide consumables actual I/right L14Aloe/L16lichen/L13Mandrake/Act1Mind, full refusal, source receipts, live sleep/W/Q, F5/F9; disclosed grants/resources/timer fixtures")
 quit()
