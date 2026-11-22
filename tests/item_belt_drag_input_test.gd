extends "res://tests/helpers/g15_stored_spell_input.gd"
func _initialize():main.call_deferred()
func drag(at:Vector2,to:Vector2):
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=at;down.global_position=at;Input.parse_input_event(down);Input.flush_buffered_events();await frames(2)
 var previous:=at
 for position in [at+Vector2(15,0),at.lerp(to,0.5),to]:
  var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;motion.relative=position-previous;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);Input.flush_buffered_events();previous=position;await frames(3)
  print("BELT_DRAG position=",position," dragging=",root.gui_is_dragging())
 down.pressed=false;down.position=to;down.global_position=to;Input.parse_input_event(down);Input.flush_buffered_events();await frames(4)
func main():
 if not await boot_map("L10_DC"):return
 const ALOE:="act2:L14_HT:item68"
 if not await grant_scrolls([ALOE]):return
 await tap(KEY_I);await frames(20)
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==ALOE:index=i;break
 if not require(index>=0,"Actual Aloe grid icon"):return
 var at:Vector2=list.get_global_transform_with_canvas()*list.get_item_rect(index).get_center()
 var card:Control=scene.inventory.belt_view.cards[4]
 print("BELT_DRAG source=",at," target=",card.get_global_rect())
 await drag(at,card.get_global_rect().get_center())
 await picture("belt_drag_attempt")
 if not require(scene.item_effects.belt_state().slots[4]==scene.item_effects.Catalog.definition(ALOE) and ALOE in scene.carried_collected,"Actual drag onto specified belt slot keeps the inventory item"):return
 await picture("belt_inventory_drag")
 await tap(KEY_ESCAPE);await frames(6)
 scene.interface_hud.hide();await frames(2)
 if not require(not scene.interface_hud.visible,"Belt canvas is hidden with original HUD"):return
 scene.interface_hud.show();await frames(2)
 if not await disk_cycle("belt_manual_drag"):return
 if not require(scene.item_effects.belt_state().slots[4]==scene.item_effects.Catalog.definition(ALOE),"F5/F9 keeps manual drag target slot"):return
 print("PASS actual inventory drag/drop specific slot, ownership unchanged, shared HUD hide/show, F5F9 manual references; grant fixture only")
 quit()
