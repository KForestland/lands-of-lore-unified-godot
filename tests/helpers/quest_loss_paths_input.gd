extends "res://tests/helpers/quest_temple_resource_input.gd"
## Component controls from untouched earned Temple supplies. The drop/throw
## consumer changes no pose/items/story. Mauri cases add his actual room as an
## explicitly disclosed UI component with initial idle TINT/price state: they
## are not a claim that Mauri can be reached from the Temple by walking.
const STONE="act2:L13_RC:dreamstone"
const BOW="act2:L12_CM:blue_bow"
func path_case()->String:return "throw"
func menu_for(id:String)->bool:
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Real I inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var wanted:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:wanted=i;break
 if not require(wanted>=0,"Genuine protected item carried"):return false
 var at:=Vector2.ZERO
 for scroll in 60:
  at=list.get_global_transform_with_canvas()*(list.get_item_rect(wanted).get_center()-Vector2(0,list.get_v_scroll_bar().value))
  if list.get_global_rect().grow(-3).has_point(at):break
  await button(MOUSE_BUTTON_WHEEL_UP if at.y<list.get_global_rect().position.y else MOUSE_BUTTON_WHEEL_DOWN,list.get_global_rect().get_center())
 if not require(list.get_global_rect().grow(-3).has_point(at),"Real wheel reveals item"):return false
 await button(MOUSE_BUTTON_RIGHT,at);await frames(2)
 return require(is_instance_valid(scene.inventory.item_menu) and scene.inventory.item_menu.visible,"Actual right-click choices")
func mouse_drag(from:Vector2,to:Vector2)->void:
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true;down.position=from;down.global_position=from;Input.parse_input_event(down)
 await frames(2)
 var move:=InputEventMouseMotion.new();move.position=to;move.global_position=to;move.relative=to-from;move.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(move)
 await frames(3)
 var up:=down.duplicate();up.pressed=false;up.button_mask=0;up.position=to;up.global_position=to;Input.parse_input_event(up)
 await frames(3)
func main():
 if not await boot_legacy(INPUT,PIN,"lol2-restoration-map-L14_HT","res://scenes/lol2/maps/L14_HT.tscn"):return
 await ticks(12)
 var pack:Array=scene.item_effects.carried().duplicate()
 if not require(pack.count(STONE)==1 and pack.count(BOW)==1,"Untouched unique Dreamstone and Blue Bow"):return
 var mode:String=path_case()
 if mode in ["give","sell"]:
  if not await mauri(mode=="sell",pack):return
 else:
  if not await menu_for(STONE):return
  var choices:Node=scene.inventory.item_menu.get_node("Choices")
  for node in choices.get_children():
   if node is Button and not require(node.text not in ["Drop","Sell","Give","Throw"],"No invented destructive inventory action"):return
  if mode=="drop" and not require(scene.inventory.detail_text.text.contains("Keep the Dreamstone"),"Reserved identity is plainly labelled when browsing"):return
  if mode=="throw":
   if not require(choices.has_node("UseItem"),"Existing Use selects held Dreamstone"):return
   await button(MOUSE_BUTTON_LEFT,choices.get_node("UseItem").get_global_rect().get_center());await frames(4)
   if not require(not paused and scene.hand_item==STONE,"Real inventory Use holds the actual item"):return
   var before_children:int=scene.item_effects.thrown_items.get_child_count()
   var prior_notice:=hud()
   await button(MOUSE_BUTTON_RIGHT);await frames(4)
   if not require(hud()==prior_notice,"Unsupported right-click never claims it would spend a quest item: "+hud()):return
   if not require(scene.item_effects.thrown_items.get_child_count()==before_children and scene.item_effects.thrown_items.rows().is_empty(),"No projectile or floor copy before a refused take"):return
   if not await menu_for(STONE):return
   await button(MOUSE_BUTTON_LEFT,scene.inventory.item_menu.get_node("Choices/PutOnBelt").get_global_rect().get_center());await tap(KEY_ESCAPE);await frames(3)
   for slot in 5:
    var belt:Dictionary=scene.item_effects.belt_state()
    if scene.item_effects.BeltState.resolve(belt,int(belt.active),scene.item_effects.carried())==STONE:break
    await tap(KEY_BRACKETRIGHT)
   await tap(KEY_F);await frames(2)
   if not require(hud()=="That does not fit here","Real F with Dreamstone has no consumption route and keeps the ordinary mismatch line: "+hud()):return
  else:
   await button(MOUSE_BUTTON_LEFT,choices.get_node("PutOnBelt").get_global_rect().get_center());await frames(2)
   var list:ItemList=scene.inventory.item_list
   var index:int=list.get_selected_items()[0]
   var at:Vector2=list.get_global_transform_with_canvas()*(list.get_item_rect(index).get_center()-Vector2(0,list.get_v_scroll_bar().value))
   await mouse_drag(at,Vector2(1240,680))
   if not require(scene.item_effects.carried()==pack,"Real drag outside all equipment/belt targets cannot drop a quest item"):return
   await tap(KEY_ESCAPE);await frames(3)
  if not require(scene.item_effects.carried()==pack and scene.item_effects.thrown_items.rows().is_empty(),"Refusal leaves one owned copy and no world copy"):return
  await picture("r131_"+mode)
  if not await disk_cycle("protected_"+mode):return
  if not require(scene.item_effects.carried()==pack,"Protected items survive actual F5/F9"):return
 print("PASS R131 real-input ",mode,": named reservation/unsupported-action boundary; pack unchanged, no world copy, no barter reward; component provenance disclosed")
 quit()
func mauri(price:bool,pack:Array)->bool:
 var State=preload("res://scripts/lol2/thieves_den_state.gd")
 # Initial room component, not a post-action story edit or earned route.
 var initial:Dictionary=State.initial();initial.room="TINT";initial.flags["19"]=1 if price else 0
 scene.quest_state.thieves_den=initial
 if not is_instance_valid(scene.thieves_den):
  scene.thieves_den=preload("res://scripts/lol2/thieves_den_rooms.gd").new()
  scene.thieves_den.name="ThievesDen";scene.add_child(scene.thieves_den)
 var den:Node=scene.thieves_den
 den.restore();await frames(4)
 if not require(den.available and den.active() and not State.active(den.state()),"Actual idle Mauri room component"):return false
 var wanted:=-1
 for i in den.held.item_count:
  if str(den.held.get_item_metadata(i))==BOW:wanted=i;break
 if not require(wanted>=0,"Original carried Blue Bow offered by actual hand chooser"):return false
 await button(MOUSE_BUTTON_LEFT,root.get_screen_transform()*den.held.get_global_rect().get_center());await frames(3)
 var popup:PopupMenu=den.held.get_popup()
 print("R131_CHOICE visible=",popup.visible," selected=",den.held.selected," focus=",popup.get_focused_item()," wanted=",wanted," transform=",root.get_screen_transform())
 if not require(popup.visible,"Actual Mauri choice popup opened"):return false
 for i in den.held.item_count+1:
  if popup.get_focused_item()==wanted:break
  await tap(KEY_DOWN)
 await tap(KEY_ENTER);await frames(3)
 if not require(str(den.held.get_item_metadata(den.held.selected))==BOW,"Real chooser selects Blue Bow"):return false
 var before:Dictionary=den.state().duplicate(true)
 var player_at:Vector3=scene.player.position
 var at:Vector2=root.get_screen_transform()*den.input_layer.get_global_transform_with_canvas()*Vector2(400,169)
 await button(MOUSE_BUTTON_LEFT,at);await frames(4)
 print("R131_MAURI_OWNERSHIP before_bow=",pack.count(BOW)," after_bow=",scene.item_effects.carried().count(BOW)," original_room=",before.room," current_room=",den.state().room)
 if not require(scene.item_effects.carried()==pack and den.state()==before and scene.player.position==player_at,"Refused gift/price changes neither pack, flags, script, rewards nor room/position"):return false
 var notice:Variant=den.get("item_notice")
 if not require(is_instance_valid(notice) and notice.is_visible_in_tree() and notice.text.contains("Keep the Blue Bow"),"Mauri refusal is actually visible over his room"):return false
 await picture("r131_mauri_price" if price else "r131_mauri_gift")
 if not require(scene.can_save().is_empty(),"Idle refused barter remains saveable: "+scene.can_save()):return false
 var Slots=preload("res://scripts/lol2/game_save.gd")
 var old:String=FileAccess.get_sha256(Slots.slot_path(1)) if FileAccess.file_exists(Slots.slot_path(1)) else ""
 await tap(KEY_F5);await frames(3)
 return require(FileAccess.file_exists(Slots.slot_path(1)) and FileAccess.get_sha256(Slots.slot_path(1))!=old,"Actual F5 after refused gift/price writes a slot")
