extends "res://tests/helpers/g15_stored_spell_input.gd"
## HUD-only component; genuine item grant/manual belt setup aids, no earned claim.
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L10_DC"):return
 var ids:=["act2:L10_DC:item48:charged:yellow","act2:L10_DC:item45:charged:blue","act2:L14_HT:item68","act2:L10_DC:item43:charged:white","act2:L13_RC:item53"]
 if not await grant_scrolls(ids):return
 for index in 5:
  if not require(scene.item_effects.put_on_belt(ids[index],index),"Manual HUD fixture owns item"):return
 scene.item_effects.belt_state().active=0
 await frames(30)
 await picture("item_belt_hud_preview")
 print("PASS five-slot HUD preview, middle active large, real native icons, count; no smart behavior wired")
 quit()
