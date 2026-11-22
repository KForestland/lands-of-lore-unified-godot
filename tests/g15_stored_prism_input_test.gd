extends "res://tests/helpers/g15_stored_spell_input.gd"
const FIRST:="act2:L9_DR:item12"
const SECOND:="act2:L9_DR:item20"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L20_BB"):return
 if not await grant_scrolls([FIRST,SECOND]):return
 var pillars:Node=scene.get_node("L20PillarsScotia")
 var magic=scene.starting_magic;magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_TAB) # Open from the real HUD cursor; shared interface admission owns this request.
 if not await inventory_right_use(FIRST):return
 if not require(FIRST not in scene.carried_collected and magic.magic_state().spellbook.learned==["prism5"] and not pillars.state().trinity and magic.magic_state().player.mana==mana,"First actual Prism scroll learns only Trinity without cast/debit"):return
 # Learn from the optional scroll away from the first-required-use lesson;
 # then return to live mouse admission before the supplied target stand.
 if scene.interface_hud.cursor_active:await tap(KEY_TAB)
 if not await stand_at(pillars.SCOTIA_AT+Vector3(0,32,0)):return
 await tap(KEY_TAB)
 if not await inventory_right_use(SECOND):return
 if not require(SECOND not in scene.carried_collected and pillars.state().trinity and magic.magic_state().player.mana==mana-5 and magic.magic_state().get("spell","spark")=="spark","Later Prism scroll uses shared charge5 receiver/cost, preserves selected school"):return
 if not await disk_cycle("g15_stored_prism"):return
 if not require(scene.get_node("L20PillarsScotia").state().trinity and SECOND in scene.item_effects.state().spent,"Actual F5/F9 keeps stored Trinity consumption"):return
 print("PASS stored Prism learn then same Trinity5 cost5 via actual paused inventory/rightclick, F5F9; grant/stand/clock fixtures")
 quit()
