extends "res://tests/helpers/g15_stored_spell_input.gd"
## Real inventory use; explicit grant, health and magic-clock component fixtures.
const FIRST:="act2:L9_DR:item15"
const SECOND:="act2:L10_DC:item7"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 if not await grant_scrolls([FIRST,SECOND]):return
 var magic=scene.starting_magic;magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 var school:String=magic.magic_state().get("spell","spark")
 var book:Dictionary=magic.magic_state().get("spellbook",magic.SpellBook.initial()).duplicate(true)
 if not require(magic.health()==30,"Full-health refusal precondition"):return
 await tap(KEY_TAB)
 if not await inventory_right_use(FIRST):return
 if not require(FIRST in scene.carried_collected and FIRST not in scene.item_effects.state().spent and magic.health()==30 and magic.magic_state().player.mana==mana,"Actual full-health right use refuses without consume or debit"):return
 magic.set_health(24) # Disclosed health fixture through the single health owner.
 if not await inventory_right_use(SECOND):return
 if not require(magic.health()==30 and magic.magic_state().player.mana==mana-2 and SECOND not in scene.carried_collected and FIRST in scene.carried_collected,"Actual stored Heal uses existing basic Healing1 effect/cost and consumes one source scroll"):return
 if not require(magic.magic_state().get("spell","spark")==school and magic.magic_state().get("spellbook",magic.SpellBook.initial())==book,"No new learned level or panel selection change"):return
 await picture("stored_heal_used")
 if not await disk_cycle("stored_heal"):return
 if not require(scene.starting_magic.health()==30 and scene.item_effects.state().spent.count(SECOND)==1 and FIRST in scene.carried_collected and SECOND not in scene.carried_collected,"Actual F5/F9 keeps the one consumed scroll and healing"):return
 if not require(SECOND in scene.quest_state.act2_items.collected and not scene.act2_items.sprites[SECOND].visible,"F9 keeps original source pickup receipt; no respawn"):return
 print("PASS stored Heal148 actual inventory rightclick/full refusal/basic Healing1/cost2/one consume/no learning or selection/F5F9; grant-health-clock fixtures")
 quit()
