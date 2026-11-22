extends "res://tests/helpers/g15_stored_spell_input.gd"
const SPARK:="act2:L10_DC:item21"
const FIRST:="act2:L14_HT:item20"
const THIRD:="act2:L14_HT:item47"
const SECOND:="act2:L14_HT:item21"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L19_BC"):return
 if not await grant_scrolls([SPARK,FIRST,SECOND,THIRD]):return
 var magic=scene.starting_magic;magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 if not await inventory_right_use(SPARK):return
 if not require(SPARK not in scene.carried_collected and SPARK in scene.item_effects.state().spent and magic.magic_state().player.mana==mana-3 and magic.notice_text()=="Level 3 Spark","Real scroll right-click dispatches existing Spark3 and consumes exactly once"):return
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 if not await inventory_right_use(FIRST):return
 if not require(FIRST not in scene.carried_collected and FIRST in scene.item_effects.state().spent and magic.magic_state().player.mana==mana and magic.magic_state().spellbook.learned==["mists1","mists3"] and magic.magic_state().get("spell","spark")=="spark","First Mists scroll learns both charges without cast/debit or selection change"):return
 if not await inventory_right_use(SECOND):return
 if not require(SECOND in scene.carried_collected and SECOND not in scene.item_effects.state().spent and magic.magic_state().player.mana==mana,"No-target refusal preserves scroll and mana"):return
 if is_instance_valid(scene.inventory):await tap(KEY_ESCAPE)
 var heads:Node=scene.get_node("L19GhostlyHeads")
 if not await stand_at(heads.AT_67+Vector3(0,32,0)):return
 if not await inventory_right_use(SECOND):return
 if not require(SECOND not in scene.carried_collected and heads.state().shot==[67] and magic.magic_state().player.mana==mana-1 and magic.magic_state().get("spell","spark")=="spark","Later actual Mists scroll uses same head receiver/cost1 without selection change"):return
 if not await inventory_right_use(THIRD):return
 if not require(THIRD in scene.carried_collected and THIRD not in scene.item_effects.state().spent and magic.magic_state().player.mana==mana-1 and scene.interface_hud.hint.text=="Wait a moment before casting again","Stored cooldown refusal keeps item/mana and gives a plain line"):return
 if is_instance_valid(scene.inventory):await tap(KEY_ESCAPE)
 if not await disk_cycle("g15_stored_mists"):return
 if not require(scene.get_node("L19GhostlyHeads").state().shot==[67] and SECOND in scene.item_effects.state().spent and SECOND not in scene.carried_collected,"Real F5/F9 keeps effect/consumption/book without respawn"):return
 print("PASS stored Spark3 + Mists first-learning/later-Q1/same receiver/refusal/F5F9 via actual I/grid rightclick; valid-ID grant/stand/clock fixtures")
 quit()
