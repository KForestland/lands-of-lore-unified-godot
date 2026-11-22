extends "res://tests/item_consumables_input_test.gd"
## Supplied genuine identities; real inventory mouse Use and belt F. No earned
## pickup/mix claim, no HP/mana edits, held population, ordinary clock1/60.
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 const IDS=["act2:L8_SJ:item26","act2:L8_SJ:shaman_amaranth"]
 if not await grant_scrolls(IDS):return
 var pack:Array=scene.carried_collected.duplicate();var hp_before:int=hp()
 scene.starting_magic.set_process(false) # Hold regeneration to compare exact mana.
 var mana:Dictionary=scene.starting_magic.magic_state().duplicate(true)
 var spent:Array=scene.item_effects.state().spent.duplicate()
 for id in IDS:
  if not await use_food(id):return
  if not require(is_instance_valid(scene.inventory) and scene.inventory.detail_text.text==scene.item_effects.SERUM_REFUSAL,"Actual inventory Use names the serum's mixing requirement: "+id):return
  if not require(scene.carried_collected==pack and hp()==hp_before and scene.starting_magic.magic_state()==mana and scene.item_effects.state().spent==spent,"Actual failed Use consumes no alias, HP, mana or receipt: "+id):return
 await tap(KEY_ESCAPE)
 scene.item_effects.put_on_belt(IDS[0],int(scene.item_effects.belt_state().active)) # Declared belt-selection fixture, not input.
 await tap(KEY_F)
 if not require(scene.interface_hud.hint.text==scene.item_effects.SERUM_REFUSAL and scene.carried_collected==pack and scene.item_effects.state().spent==spent,"Real F uses the active Serum definition and keeps all carried copies with the same plain line"):return
 await picture("amaranth_refused")
 if not await disk_cycle("amaranth_refusal"):return
 if not require(scene.carried_collected==pack and scene.item_effects.state().spent==spent and hp()==hp_before and scene.resets==0,"F5/F9 keeps all refused Serum copies without a spent receipt or fall reset"):return
 print("PASS actual inventory Use on both genuine Serums and beltF names Silverleaf/keeps items and pools; F5/F9; declared grant/belt/population/regen fixtures")
 quit()
