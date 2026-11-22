extends "res://tests/helpers/g15_world_spell_input.gd"
## Actual unlearned head67 F5, normal autosave, rendered input and wall clock.
## No position or resource writes; no accelerated clock or injected statuses.
func _initialize():main.call_deferred()
func main():
 const Save=preload("res://scripts/lol2/game_save.gd")
 const Journal=preload("res://scripts/lol2/my_journal.gd")
 if not require(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1" and "--no-autosave" not in OS.get_cmdline_user_args(),"Private normal-autosave proof"):return
 var input:="res://tests/fixtures/chain_spell_lessons/sixth_life_head67.json"
 if not require(FileAccess.get_sha256(input)=="1f6636eae4481520b47e466352efa16bb527934ee6c8f5a7797cf0aa7093a60f","Pinned actual stopped-player F5"):return
 if not require(Save.load_file(self,input).is_empty(),"Actual full-game loader"):return
 await scene_changed;use_guard=false;await adopt()
 var heads:Node=scene.get_node("L19GhostlyHeads")
 var hud:Node=scene.interface_hud
 var message:="Mists learned. Press 4, then Q at each ghostly head."
 var note:="spell_lesson_mists_heads"
 var session:Node=preload("res://scripts/lol2/game_session.gd").for_tree(self)
 var started:int=int(hud.get("lesson_started_msec")) if hud.get("lesson_started_msec")!=null else Time.get_ticks_msec()
 if not require(hud.hint.text==message,"Lesson is still readable after loading into the room"):return
 while Time.get_ticks_msec()-started<6000:
  await process_frame
  if not require(hud.hint.text==message,"Actual arrival autosave cannot replace the lesson within six wall seconds"):return
 if not require(session.autosave_writes>0 and heads.state().shot.is_empty(),"Actual automatic writer completed without an automatic cast"):return
 await picture("lesson_readable_six_seconds")
 for tick in 1800:
  await process_frame
  if hud.hint.text!=message:break
 if not require(hud.hint.text=="Autosaved.","Autosave status is played after the readable lesson"):return
 var mana:int=scene.starting_magic.magic_state().player.mana
 await tap(KEY_E)
 if not require(hud.hint.text==message and heads.state().shot.is_empty() and scene.starting_magic.magic_state().player.mana==mana,"Real E repeats only the needed lesson, without casting/debit"):return
 await tap(KEY_F5)
 if not require(hud.hint.text==message and Save.read_document(Save.slot_path(1)).error.is_empty(),"Actual Saved status also waits behind the lesson"):return
 await tap(KEY_J)
 if not require(hud.sheet.visible and hud.shown_page=="journal" and hud.sheet_body.text.count(message)==1 and Journal.notes(scene).count(note)==1,"Real Journal shows the exact sentence once"):return
 await picture("lesson_in_journal")
 await tap(KEY_J);await tap(KEY_E)
 if not require(Journal.notes(scene).count(note)==1,"Repeated E never duplicates the Journal entry"):return
 await tap(KEY_4);scene.starting_magic.set_process(false)
 mana=scene.starting_magic.magic_state().player.mana
 await tap(KEY_Q)
 if not require(heads.state().shot==[67] and scene.starting_magic.magic_state().player.mana==mana-1,"Actual Q alone still records the head for one mana"):return
 if not await disk_cycle("lesson_notice_journal"):return
 if not require(Journal.notes(scene).count(note)==1 and scene.get_node("L19GhostlyHeads").state().shot==[67],"Real F5/F9 retains the one Journal entry and cast"):return
 await tap(KEY_E)
 if not require(scene.interface_hud.hint.text!=message and scene.get_node("L19GhostlyHeads").state().shot==[67],"Real E does not repeat a lesson for the already used head"):return
 print("PASS actual head67 load/arrival autosave: lesson >=6 wall seconds, status queued, real E echo/no cast, real J exact sentence once, Qcost1/F5F9; ordinary clock, no position/resource writes")
 quit()
