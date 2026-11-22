extends "res://tests/helpers/g15_world_spell_input.gd"
## Untouched actual player-written stop checkpoint; no position/form/resource
## writes in this leaf. Transitive helpers are conservatively source-audited.
func _initialize():main.call_deferred()
func main():
 const Save=preload("res://scripts/lol2/game_save.gd")
 var input:="res://tests/fixtures/chain_spell_lessons/sixth_life_head67.json"
 if not require(FileAccess.get_sha256(input)=="1f6636eae4481520b47e466352efa16bb527934ee6c8f5a7797cf0aa7093a60f","Untouched real F5 at head67"):return
 var original:Dictionary=Save.read_document(input)
 if not require(original.error.is_empty(),"Actual stop file validates"):return
 var saved_magic:Dictionary=original.state.area_save.quests.player_magic_reward_state
 if not require(not "mists1" in saved_magic.spellbook.learned and saved_magic.spellbook.learned.size()==6,"Pinned modern book genuinely lacks Mists"):return
 if not require(Save.load_file(self,input).is_empty(),"Original full-game load at the player's actual position"):return
 await scene_changed;use_guard=false;await adopt()
 var magic:Node=scene.starting_magic
 var heads:Node=scene.get_node("L19GhostlyHeads")
 if not require(heads.near_head()==67 and "mists1" in magic.magic_state().spellbook.learned and heads.state().shot.is_empty(),"The already-stuck player learns on load, with no automatic shot"):return
 for id:String in saved_magic.spellbook.learned:
  if not require(id in magic.magic_state().spellbook.learned,"Prior learned cast retained: "+id):return
 if not require(magic.magic_state().get("spell")==saved_magic.get("spell") and hp()<=int(original.state.area_save.inventory.health) and scene.resets==0,"Teaching changes no selected school, heals nothing and causes no recovery"):return
 await picture("real_head67_lesson")
 await tap(KEY_4);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_E)
 if not require(heads.state().shot.is_empty(),"Real E never supplies a free shot"):return
 await tap(KEY_Q)
 if not require(heads.state().shot==[67] and magic.magic_state().player.mana==mana-1,"Actual Q records the previously stopped head at cost1"):return
 if not await disk_cycle("real_head67_lesson"):return
 if not require("mists1" in scene.starting_magic.magic_state().spellbook.learned and scene.get_node("L19GhostlyHeads").state().shot==[67] and scene.resets==0,"Real F5/F9 keeps the earned player's lesson and cast"):return
 print("PASS untouched modern head67 F5 -> actual loader/lesson/key4/Q cost1/F5F9, old six casts and school retained, no auto-shot/E bypass/recovery or position writes")
 quit()
