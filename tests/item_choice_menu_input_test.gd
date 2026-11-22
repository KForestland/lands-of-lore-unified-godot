extends "res://tests/helpers/g15_stored_spell_input.gd"
const Choices=preload("res://scripts/lol2/item_choice_menu.gd")
func _initialize():main.call_deferred()
func scroll_value(menu:PopupMenu)->float:
 if menu.has_method("get_scroll"):return float(menu.call("get_scroll"))
 var todo:Array=[menu]
 while not todo.is_empty():
  var node:Node=todo.pop_back()
  if node is VScrollBar:return node.value
  todo.append_array(node.get_children(true))
 return -1
func menu_button(index:int,logical:Vector2):
 await button(index,root.get_screen_transform()*logical)
func main():
 var original_resize_hooks:int=root.size_changed.get_connections().size()
 scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
 use_guard=false;await adopt()
 var rooms:Node=scene.monastery
 rooms.set_process(false)
 var items:Array=["museum:item14:Healing_Scroll","museum:item15:Healing_Scroll"]
 var definitions:Array=[148]
 for id:String in Choices.Catalog.ids("jungle"):
  # This UI fixture does not kill/loot Kelsrick. His source-specific sword
  # requires that receipt; other admitted sources still provide25 types.
  if id=="jungle:kelsrick:Fine_Longsword":continue
  var definition:int=Choices.Catalog.definition(id)
  if definition<0 or definition in definitions:continue
  definitions.append(definition);items.append(id)
  if definitions.size()==25:break
 for id:String in items:
  if not require(Grants.grant(scene,id,{"cap":false}).ok,"Genuine item fixture for choice pack"):return
 var api=load("res://scripts/lol2/game_save.gd")
 var fixture_error:String=api.validate(api.make_document(scene,1))
 if not require(fixture_error.is_empty(),"Explicit Give-menu pack is valid BEFORE any UI input: "+fixture_error):return
 # UI-only room fixture; no story, conversation or item offer is claimed.
 rooms.state().room="MOFF";rooms.restore();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var held:OptionButton=rooms.held
 for view in [Vector2i(1280,720),Vector2i(960,540)]:
  root.size=view;await frames(15)
  if not require(held.item_count==26,"25 distinct item types plus empty hand, duplicate healing grouped"):return
  var healing:=-1
  for index in range(1,held.item_count):
   var text:String=held.get_item_text(index)
   if not require(held.get_item_icon(index)!=null and not text.contains("harvest") and not text.contains(":"),"Every actual choice has original icon and catalog name"):return
   if text=="Healing Scroll x2":healing=index
  if not require(healing>=0,"Equal Healing Scroll source instances stack with count"):return
  var before:Array=scene.carried_collected.duplicate()
  await menu_button(MOUSE_BUTTON_LEFT,held.get_global_rect().get_center());await frames(4)
  var popup:PopupMenu=held.get_popup()
  var bounds:=Rect2(Vector2(popup.position),Vector2(popup.size))
  print("CHOICE_BOUNDS visible=",popup.visible," held=",held.get_global_rect()," requested=",view," root=",root.size," logical=",root.get_visible_rect()," item_view=",held.get_viewport_rect()," maximum=",popup.max_size," popup=",bounds)
  var pixels:Rect2=root.get_screen_transform()*bounds
  if not require(popup.visible and root.get_visible_rect().encloses(bounds) and Rect2(Vector2.ZERO,Vector2(view)).grow(1).encloses(pixels),"Actual dropdown fits both logical and physical window: "+str(bounds)+" pixels="+str(pixels)):return
  await picture("give_choices_open_"+str(view.x))
  var prior:float=scroll_value(popup)
  for tick in 8:await menu_button(MOUSE_BUTTON_WHEEL_DOWN,bounds.get_center())
  if not require(scroll_value(popup)>prior,"Actual mouse wheel scrolls overflowing item list"):return
  print("CHOICE_KEYS window=",popup.get_window_id()," focus=",popup.get_focused_item()," scroll=",scroll_value(popup))
  for step in popup.item_count+1:
   if popup.get_focused_item()==popup.item_count-1:break
   await tap(KEY_DOWN)
  if not require(popup.get_focused_item()==popup.item_count-1,"Actual down-arrow reaches last item and scrolls it into view"):return
  await tap(KEY_UP);await tap(KEY_DOWN);await tap(KEY_ENTER);await frames(3)
  if not require(not popup.visible and held.selected==held.item_count-1 and scene.carried_collected==before,"Actual arrows/Enter choose an original owned id without giving or consuming it"):return
  await picture("give_choices_"+str(view.x))
 scene.queue_free();current_scene=null;await frames(4)
 root.size=Vector2i(1280,720);await frames(4)
 if not require(root.size_changed.get_connections().size()==original_resize_hooks,"Freed choice menus disconnect Window resize callbacks without stale captures"):return
 print("PASS real production Give-item dropdown, 25 types/26 sources, Healing Scroll x2/catalog harvest names/native icons, real wheel/arrow selection and window bounds1280+960; explicit UI room/grant fixtures")
 quit()
