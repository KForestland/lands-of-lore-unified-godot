extends "res://tests/helpers/g15_stored_spell_input.gd"
## Real E/click guard contract; explicit initial story/grant/NPC/grounded-stand
## component fixtures, not an earned campaign checkpoint or walk.
func _initialize():main.call_deferred()
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 if not require(scene.ready_for_review,"Actual L8 host ready"):return
 use_guard=false;await adopt()
 if not captured():await lclick()
 scene.act2_creatures.set_physics_process(false)
 var journey:Node=scene.get_node("L8Journey")
 if not await grant_scrolls([journey.State.BLADE]):return
 var fixture:Dictionary=journey.State.initial();fixture.gift="recovered";fixture.temple_visited=true
 scene.quest_state.l8_journey=fixture
 if not await stand_at(journey.TARGETS.village+Vector3(0,0,60)):return
 if not await look(journey.TARGETS.village):return
 await frames(15)
 var belt:Dictionary=scene.item_effects.belt_state()
 if not require(scene.item_effects.put_on_belt(journey.State.BLADE,0),"Carried genuine blade on a NONactive slot"):return
 belt.active=4 # Explicit selection fixture: the required item is in pack, not active.
 if not require(belt.slots[4]==-1 and not journey.state().admitted,"No active item and no admission"):return
 await tap(KEY_E);await frames(4)
 await picture("belt_guard_existing_dialogue")
 if not require(journey.opened=="village" and paused and not journey.state().admitted,"Plain real E opens the existing guard dialogue regardless of active slot"):return
 var choice:Button
 for child in journey.box.get_children():
  if child is Button and child.text.contains("Show Daniel") and not child.disabled:choice=child;break
 if not require(is_instance_valid(choice),"Original Show Daniel's blade choice remains visible and enabled"):return
 await button(MOUSE_BUTTON_LEFT,choice.get_global_rect().get_center());await frames(4)
 if not require(journey.state().admitted and journey.State.BLADE in scene.carried_collected,"Real click admits Luther without consuming the displayed blade"):return
 await tap(KEY_ESCAPE);await frames(4)
 if not await disk_cycle("belt_guard_native_choice"):return
 if not require(scene.get_node("L8Journey").state().admitted,"Same-build F5/F9 keeps admission"):return
 print("PASS real E with required blade carried but NONactive opens original guard choice; actual Show click admits; F5/F9; explicit story/grant/stand/NPC/selection component fixtures, not earned walk")
 quit()
