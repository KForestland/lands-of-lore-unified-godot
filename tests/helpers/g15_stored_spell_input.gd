extends "res://tests/helpers/g15_world_spell_input.gd"
const Grants=preload("res://scripts/lol2/item_grants.gd")
func grant_scrolls(ids:Array)->bool:
 for id:String in ids:
  if not require(Grants.grant(scene,id,{"cap":false,"history":"act2_once" if id.begins_with("act2:") else "none","sync":true}).ok,"Disclosed actual-ID scroll grant fixture"):return false
 return true
func inventory_right_use(id:String)->bool:
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Actual I opens paused inventory"):return false
 var before:Dictionary=scene.starting_magic.magic_state().duplicate(true)
 await tap(KEY_Q,false,true)
 if not require(not scene.starting_magic.available() and scene.starting_magic.magic_state()==before,"Ordinary world keys/caster remain blocked while browsing inventory"):return false
 var school:String=preload("res://scripts/lol2/item_catalog.gd").stored_school(id)
 if not require(scene.inventory.detail_text.text.contains("Stored"),"Inventory explains the actual stored spell use"):return false
 await picture("g15_stored_inventory_"+school)
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Scroll is in actual inventory grid"):return false
 var rect:Rect2=list.get_item_rect(index)
 await button(MOUSE_BUTTON_RIGHT,list.get_global_transform_with_canvas()*rect.get_center())
 await frames(2)
 if is_instance_valid(scene.inventory) and is_instance_valid(scene.inventory.item_menu):
  await button(MOUSE_BUTTON_LEFT,scene.inventory.item_menu.get_node("Choices/UseItem").get_global_rect().get_center())
 await frames(6)
 return true

# Contract after completed item inputs: a living, otherwise saveable host must
# still produce a valid whole-game packet. No save, event replay or disk write.
func item_action_save_error()->String:
 if not is_instance_valid(scene) or not scene.has_method("can_save") or not scene.has_method("area_snapshot"):return ""
 var effects:Variant=scene.get("item_effects")
 if is_instance_valid(effects) and effects.has_method("carried") and null in effects.carried():return "Item collection contains null after an item action."
 if not scene.can_save().is_empty():return ""
 var Slots=load("res://scripts/lol2/game_save.gd")
 return Slots.validate(Slots.make_document(scene,1))
func assert_item_action_saveable(context:String)->bool:
 var error:=item_action_save_error()
 return require(error.is_empty(),"Completed item action keeps F5 valid ("+context+"): "+error)
func tap(code:int,ctrl:=false,shift:=false)->void:
 await super.tap(code,ctrl,shift)
 if code in [KEY_E,KEY_F]:assert_item_action_saveable("key "+str(code))
func button(index:int,at:=Vector2(640,360))->void:
 await super.button(index,at)
 if index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:assert_item_action_saveable("mouse "+str(index))

func disk_cycle(tag:String)->bool:
 if not await super.disk_cycle(tag):return false
 return assert_item_action_saveable("F9 "+tag)
