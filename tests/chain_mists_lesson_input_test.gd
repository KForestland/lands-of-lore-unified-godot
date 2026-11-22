extends "res://tests/helpers/g15_world_spell_input.gd"
## Live teaching component, not an earned route: supplied grounded approach
## stand, then actual W and 4/Q. Other heads use disclosed local stands.
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L19_BC"):return
 var input:="res://tests/fixtures/chain_spell_lessons/sixth_life_before_heads.json"
 if not require(FileAccess.get_sha256(input)=="ad5b66a596456d626d2213b96655596b41cb8239349f8915eb4f1ded3acf9ce5","Pinned untouched sixth-life modern save"):return
 if not require(preload("res://scripts/lol2/game_save.gd").load_file(self,input).is_empty(),"Actual whole-game loader accepts the genuine continuous life"):return
 await scene_changed;await adopt()
 var heads:Node=scene.get_node("L19GhostlyHeads")
 var magic:Node=scene.starting_magic
 var book:Dictionary=magic.magic_state().get("spellbook",{})
 if not require(not "mists1" in book.get("learned",[]),"Modern unlearned book before the room"):return
 if not await stand_at(heads.AT_67+Vector3(0,32,-90)):return
 await look_at_point(heads.AT_67+Vector3.UP*32)
 key_event(KEY_W,true)
 for tick in 120:
  await physics_frame
  if heads.near_head()==67:break
 key_event(KEY_W,false);await frames(3)
 if not require(heads.near_head()==67 and scene.player.is_on_floor() and scene.resets==0,"Actual W reaches the real head from its grounded approach"):return
 if not require("mists1" in magic.magic_state().spellbook.learned,"First approach teaches required Mists1 without an optional scroll"):return
 if not require(heads.state().shot.is_empty() and not heads.state().dragged,"Teaching neither casts nor advances the puzzle"):return
 await picture("chain_mists_lesson")
 await tap(KEY_4)
 var points:Array=[heads.AT_67,heads.AT_69,heads.AT_68,heads.AT_70]
 for i in points.size():
  if i>0 and not await stand_at(points[i]+Vector3.UP*32):return
  magic.set_process(true);await ticks(40);magic.set_process(false)
  var before:Array=heads.state().shot.duplicate()
  await tap(KEY_E)
  if not require(heads.state().shot==before,"E never replaces the actual cast"):return
  var mana:int=magic.magic_state().player.mana
  await tap(KEY_Q)
  if not require(heads.state().shot.size()==i+1 and int(heads.state().shot[i])==heads.HEADS[i] and magic.magic_state().player.mana==mana-1,"Actual Q records exactly one head at existing cost1"):return
 if not require(heads.state().dragged and not 66 in heads.state().shot,"Four real casts complete the existing four-head outcome; fifth skull excluded"):return
 if not await disk_cycle("chain_mists_lesson"):return
 heads=scene.get_node("L19GhostlyHeads");magic=scene.starting_magic
 if not require("mists1" in magic.magic_state().spellbook.learned and heads.state().shot.size()==4 and heads.state().dragged,"F5/F9 retains teaching and all four actual casts"):return
 print("PASS live unlearned modern book -> actual W approach -> Mists lesson -> actual4/Q four heads, E negative, cost1, F5/F9; local stands disclosed, no earned-route claim")
 quit()
func look_at_point(point:Vector3):
 var offset:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 mouse_rel(Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003))
 await frames(3)
