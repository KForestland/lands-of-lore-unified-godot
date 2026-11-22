extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L19_BC"):return
 var heads:Node=scene.get_node("L19GhostlyHeads")
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("mists"),"Disclosed Mists learning fixture"):return
 await tap(KEY_4);magic.set_process(false)
 var points:Array=[heads.AT_67,heads.AT_69,heads.AT_68,heads.AT_70]
 for i in points.size():
  if not await stand_at(points[i]+Vector3(0,32,0)):return
  var before:Array=heads.state().shot.duplicate()
  await tap(KEY_E)
  if not require(heads.state().shot==before,"Real E no longer records a Mist shot"):return
  var mana:int=magic.magic_state().player.mana
  await tap(KEY_Q,true)
  if not require(heads.state().shot==before and magic.magic_state().player.mana==mana,"Mists3 does not record a head or debit"):return
  await tap(KEY_Q)
  if not require(heads.state().shot.size()==i+1 and int(heads.state().shot[i])==heads.HEADS[i] and magic.magic_state().player.mana==mana-1,"Real Q1 records one head for one mana"):return
  magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
  await tap(KEY_Q)
  if not require(heads.state().shot.size()==i+1 and magic.magic_state().player.mana==mana,"Duplicate head refuses without debit"):return
 if not require(heads.state().dragged,"Four real Mists1 casts preserve the original circle/drag outcome"):return
 await frames(3);await picture("g15_mists1_four_heads")
 if not await stand_at(heads.AT_66+Vector3(0,32,0)):return
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q)
 if not require(heads.state().shot.size()==4 and magic.magic_state().player.mana==mana,"Fifth skull stays excluded"):return
 if not await disk_cycle("g15_mists1"):return
 if not require(scene.get_node("L19GhostlyHeads").state().dragged and scene.get_node("L19GhostlyHeads").state().shot.size()==4,"Real F5/F9 preserves all four shots"):return
 print("PASS G15 Mists1 real E negative/Q1 four heads/cost1/wrongcharge/duplicates/fifth/F5F9, explicit stand/teaching/clock fixtures; no earned walk claim")
 quit()
