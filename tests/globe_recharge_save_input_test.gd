extends "res://tests/helpers/g15_stored_spell_input.gd"
## Real charger/E/F/F5/F9 lifecycle. Supplied genuine empty item and grounded
## local stand; blue uses a disclosed dispatch receiver ONLY to isolate recycling.
## Real blue head67 effect remains qualified by item_globes_input_test.
class RepeatMistReceiver extends Node:
 var uses:=0
 func accepts_player_spell(id:String)->bool:return id=="mists1"
 func receive_player_spell(id:String)->bool:
  if id!="mists1":return false
  uses+=1;return true
func color()->String:return "yellow"
func base_item()->String:return "act2:L10_DC:item44" if color()=="yellow" else "act2:L10_DC:item43"
func _initialize():main.call_deferred()
func ensure_blue_receiver():
 if color()=="blue" and scene.get_node_or_null("RepeatMistLifecycleFixture")==null:
  var receiver:=RepeatMistReceiver.new();receiver.name="RepeatMistLifecycleFixture";scene.add_child(receiver)
func charge_and_take()->bool:
 var charger:Node=scene.get_node("Act2Chargers")
 var target:String="L10:"+color()
 if not await look(charger.globes[target].global_position):return false
 await frames(12)
 await tap(KEY_E);await frames(4)
 if failure:return false
 if not require(charger.globes[target].visible and base_item() not in scene.carried_collected,"Real E inserts the same empty globe"):return false
 # Negative control: the same full-packet validator used by the input guard
 # must reject a duplicate receipt. Mutate only a detached packet, never play.
 var Slots=load("res://scripts/lol2/game_save.gd")
 var invalid:Dictionary=Slots.make_document(scene,1).duplicate(true)
 var receipts:Array=invalid.area_save.quests.act2_chargers.slots[target].receipts
 receipts.append(receipts[0])
 if not require(Slots.validate(invalid).contains("Invalid charger receipt"),"Shared post-action validator rejects corrupted receipt control"):return false
 if not await saved_step("inserted"):return false
 charger=scene.get_node("Act2Chargers")
 if not await look(charger.globes[target].global_position):return false
 await tap(KEY_E);await frames(12)
 return require(not charger.globes[target].visible and scene.carried_collected.count(base_item()+":charged:"+color())==1,"Real E retrieves exactly one charge")
func cast_empty()->bool:
 ensure_blue_receiver()
 var charged:String=base_item()+":charged:"+color()
 var receiver:Node=scene.get_node_or_null("RepeatMistLifecycleFixture")
 var count:int=receiver.uses if is_instance_valid(receiver) else 0
 var book:Dictionary=scene.starting_magic.magic_state().get("spellbook",{}).duplicate(true)
 await frames(40) # Ordinary world clock, enough for the shared half-second cooldown.
 await tap(KEY_F);await frames(4)
 if not require(scene.carried_collected.count(base_item())==1 and charged not in scene.carried_collected,"Real F dispatch returns the same original empty source"):return false
 if not require(scene.starting_magic.magic_state().get("spellbook",{})==book,"Stored charge never teaches a school"):return false
 if color()=="blue" and not require(receiver.uses==count+1,"Actual shared Mists dispatch reaches the explicit lifecycle receiver once"):return false
 return true
func saved_step(label:String)->bool:
 if not await disk_cycle(color()+"_"+label):return false
 ensure_blue_receiver()
 scene.act2_creatures.set_physics_process(false)
 return require(hp()>0 and scene.resets==0,"Save/reload remains alive with zero recovery at "+label)
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([base_item()]):return
 var anchor:Vector3=scene.get_node("Act2Chargers").ANCHORS["L10:"+color()]
 if not await stand_at(anchor+Vector3(1,-4,79)):return
 ensure_blue_receiver()
 for round in 3:
  if not await charge_and_take():return
  if not await saved_step("round%d_charged"%round):return
  if not await cast_empty():return
  if not await saved_step("round%d_emptied"%round):return
  if not await charge_and_take():return
  if not await saved_step("round%d_recharged"%round):return
  if not await cast_empty():return
  if not await saved_step("round%d_cast_again"%round):return
 print("PASS ",color()," three real E-charge/F-cast/E-recharge/F5/F9/F-cast rounds; saves at every stage, six casts, one original empty source, no learning, alive0resets; explicit item/stand/NPC and blue-dispatch lifecycle fixture, not an earned quest walk")
 quit()
