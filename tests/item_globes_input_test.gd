extends "res://tests/helpers/g15_stored_spell_input.gd"
const BASE:="act2:L10_DC:item44"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 var yellow:String=BASE+":charged:yellow"
 if not await grant_scrolls([yellow]):return
 await frames(12)
 var magic:Node=scene.starting_magic
 var book:Dictionary=magic.magic_state().get("spellbook",magic.SpellBook.initial()).duplicate(true)
 var mana:int=magic.magic_state().player.mana
 # Explicit failed-policy fixture: admission must precede the real F cast,
 # and its plain refusal must survive the belt's generic feedback fallback.
 var Guard=preload("res://scripts/lol2/quest_resource_protection.gd")
 var trusted:Dictionary=Guard.data()
 Guard.policy={}
 Guard.policy_loaded=true
 Guard.policy_warning=true
 var pack_before:Array=scene.carried_collected.duplicate()
 await tap(KEY_F);await frames(3)
 if not require(scene.carried_collected==pack_before and magic.magic_state().player.mana>=mana and scene.interface_hud.hint.text=="This item cannot be used right now.","Actual F denied admission keeps charge/mana and displays the policy refusal once"):return
 Guard.policy=trusted
 mana=magic.magic_state().player.mana
 await tap(KEY_F);await frames(3)
 if not require(BASE in scene.carried_collected and yellow not in scene.carried_collected and magic.magic_state().player.mana<=mana-3 and magic.magic_state().get("spellbook",magic.SpellBook.initial())==book,"Actual F yellow Spark3 casts once and leaves original empty source, no lesson"):return
 await picture("yellow_globe_used")
 var charger:Node=scene.get_node("Act2Chargers")
 if not await stand_at(Vector3(1153,-125,-3553)):return
 if not await look(charger.globes["L10:yellow"].global_position):return
 await frames(12);await tap(KEY_E);await frames(5)
 if not require(BASE not in scene.carried_collected and charger.globes["L10:yellow"].visible,"Same empty source recharges by real E"):return
 await tap(KEY_E);await frames(12)
 if not require(scene.carried_collected.count(yellow)==1,"Real E retrieves one rechargeable yellow"):return
 if not await disk_cycle("yellow_globe_recharged"):return
 if not require(scene.carried_collected.count(yellow)==1,"F5/F9 retains recharged source exactly"):return
 # White remains a socket key; no unhosted Prism effect or Trinity promotion.
 var white:="act2:L10_DC:item43:charged:white"
 if not await grant_scrolls([white]):return
 scene.item_effects.put_on_belt(white,int(scene.item_effects.belt_state().active));await frames(12)
 mana=scene.starting_magic.magic_state().player.mana
 await tap(KEY_F)
 if not require(white in scene.carried_collected and scene.starting_magic.magic_state().player.mana==mana and scene.interface_hud.hint.text=="The white globe holds a spell that does nothing here yet.","Actual white F honest refusal keeps charge and mana"):return
 # Move to a distinct production area; explicit component stand, not a chain.
 scene.queue_free();await frames(4)
 if not await boot_map("L19_BC"):return
 var heads:Node=scene.get_node("L19GhostlyHeads")
 var blue:="act2:L10_DC:item45:charged:blue"
 if not await grant_scrolls([blue]):return
 if not await stand_at(heads.AT_67+Vector3(0,32,0)):return
 await frames(12)
 scene.item_effects.put_on_belt(blue,int(scene.item_effects.belt_state().active))
 scene.starting_magic.set_process(false) # Freeze teaching/mana clock only for explicit unlearned-book proof.
 var unlearned:Dictionary=scene.starting_magic.magic_state().duplicate(true);unlearned.spellbook=scene.starting_magic.SpellBook.initial();scene.starting_magic.commit(unlearned)
 book=scene.starting_magic.magic_state().get("spellbook",scene.starting_magic.SpellBook.initial()).duplicate(true)
 await tap(KEY_F);await frames(3)
 if not require(heads.state().shot==[67] and "act2:L10_DC:item45" in scene.carried_collected and blue not in scene.carried_collected and scene.starting_magic.magic_state().get("spellbook",scene.starting_magic.SpellBook.initial())==book,"Actual blue F dispatch records real head67 and returns empty; no teaching added by globe"):return
 if not await disk_cycle("blue_globe_head"):return
 if not require(scene.get_node("L19GhostlyHeads").state().shot==[67] and "act2:L10_DC:item45" in scene.carried_collected,"F5/F9 keeps receiver and empty globe, no event replay"):return
 print("PASS owner-set yellow Spark3/blue Mists1 real F, original empty identity/recharge/E/F5F9, white honest refusal; grant/stand/NPC component aids")
 quit()
