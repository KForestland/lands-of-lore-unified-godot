extends "res://tests/helpers/g15_stored_spell_input.gd"
const FIRST:="museum:item16:Summon_Scroll"
const SECOND:="darkhalls:control976u2:SumScrl"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L16_CA"):return
 if not await grant_scrolls([FIRST,SECOND]):return
 var traps:Node=scene.get_node("L16NwTraps")
 var magic=scene.starting_magic;magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 if not await inventory_right_use(FIRST):return
 if not require(FIRST not in scene.carried_collected and magic.magic_state().spellbook.learned==["summon3"] and not traps.state().ice and magic.magic_state().player.mana==mana,"First Summon scroll learns without casting/debit"):return
 # First scroll learns away from the local safety lesson; then aim the actual target.
 if not await stand_at(Vector3(-8940,132,-3286)):return
 if not await look(traps.ICE_AT):quit(1);return
 if not await inventory_right_use(SECOND):return
 if not require(SECOND not in scene.carried_collected and traps.state().ice and magic.magic_state().player.mana==mana-3,"Later actual Summon scroll uses same white-ball receiver/cost3"):return
 if not await disk_cycle("g15_stored_summon"):return
 if not require(scene.get_node("L16NwTraps").state().ice and FIRST in scene.item_effects.state().spent and SECOND in scene.item_effects.state().spent,"Real F5/F9 keeps both source identities consumed"):return
 print("PASS stored Summon learned then charge3 same ice body via actual I/rightclick/F5F9; source-ID grants/stand/clock fixtures")
 quit()
