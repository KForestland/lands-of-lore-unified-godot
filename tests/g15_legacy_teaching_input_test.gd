extends "res://tests/helpers/g15_spell_input.gd"
const Slots=preload("res://scripts/lol2/game_save.gd")
const Starts=preload("res://scripts/lol2/playtest_starts.gd")
const OLD_INPUT:="res://tmp/g15_inputs/r19i_claw_slot.json"
const OLD_PIN:="b3fe96a441904a72620ecd11f02f12654f777ddaded429f58bd3eca4a5738f6c"
const CONTROL:=["curse1","curse2","curse3","curse5","prism5","summon3"]
const ALL:=["curse1","curse2","curse3","curse5","mists1","mists3","prism5","summon3"]
func _initialize():main.call_deferred()
func start_map(id:String,expected_area:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await frames(3)
 current_scene=null
 preload("res://scripts/lol2/game_session.gd").for_tree(self).reset_legacy()
 var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate()
 gate.settings_path="user://tests/g15_teaching_gate.cfg"
 DirAccess.make_dir_recursive_absolute("user://tests")
 var cfg:=ConfigFile.new();if not require(cfg.save(gate.settings_path)==OK,"Reset private F2 gate config"):return false
 root.add_child(gate);current_scene=gate;await frames(3)
 gate.path_field.text=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
 if not require(FileAccess.file_exists(gate.path_field.text),"Original copy staged"):return false
 await tap(KEY_F2)
 for tick in 40:
  var focus:Control=root.gui_get_focus_owner()
  if focus!=null and str(focus.name)=="Start_"+id:break
  await tap(KEY_TAB if focus==null else KEY_DOWN)
 var focus:Control=root.gui_get_focus_owner()
 if not require(focus!=null and str(focus.name)=="Start_"+id,"Real keyboard selects "+id):return false
 await tap(KEY_ENTER)
 for tick in 3000:
  await process_frame
  if current_scene!=gate and is_instance_valid(current_scene) and current_scene.get("ready_for_review")==true:break
 use_guard=false;await adopt();await frames(3)
 if not captured():await lclick();await frames(3)
 return require(area==expected_area and hp()>0 and scene.resets==0,"Actual F2 resumes "+expected_area)
func control_loop(label:String)->bool:
 var magic=scene.starting_magic
 if not require(scene.player_form==0,"Control proof starts human: "+label):return false
 for tick in 600:
  if magic.available() and scene.player.is_on_floor():break
  await physics_frame
 print("CONTROL PRE ",label," active=",magic.world_active()," floor=",scene.player.is_on_floor()," curse=",scene.curse.state," pose=",pos())
 await tap(KEY_3);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 print("CONTROL RESULT ",label," form=",scene.player_form," notice=",magic.notice_text()," mana delta=",mana-int(magic.magic_state().player.mana)," spell=",magic.magic_state().spell)
 if not require(scene.player_form==2 and magic.magic_state().player.mana==mana-2,"Real CtrlQ makes lizard with no teaching aid: "+label):return false
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==0 and magic.magic_state().player.mana==mana-2 and scene.resets==0,"Real CtrlQ returns human without recovery: "+label):return false
 magic.set_process(true)
 return true
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 for row in [["act2-l12","L12_CM"],["act2-l13","L13_RC"],["act2-l14","L14_HT"],["act3-l16","L16_CA"],["act3-l17","L17_HC"],["act3-l19","L19_BC"],["act3-l20","L20_BB"]]:
  if not await start_map(row[0],row[1]):return
  var expected:Array=ALL if str(row[1]) in ["L16_CA","L17_HC","L19_BC","L20_BB"] else CONTROL
  var learned:Array=scene.starting_magic.magic_state().get("spellbook",{}).get("learned",[])
  for cast in expected:
   if not require(cast in learned,"F2 "+row[1]+" carries prior teaching: "+cast):return
  if row[1]=="L12_CM":
   # The historical F2 pose is on a sloping arrival floor. The existing morph
   # room query cannot seat a flat-bottom lizard cylinder there; walk normally
   # to the first flat native tread before the control proof, no pose fix.
   if not await walk([[-509,-5588.5],[-711,-5594],[-752,-5593]],"F2 Claw real W off arrival slope onto native flat1269"):quit(1);return
   if not await control_loop("F2 Claw"):return
   await picture("f2_claw_control")
  print("F2 TEACHING ",row[1]," ",learned)
 if not require(FileAccess.get_sha256(OLD_INPUT)==OLD_PIN,"Actual r19i Claw whole-slot pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(OLD_INPUT,Slots.slot_path(1))==OK,"Install unchanged r19i Claw slot for actual F9"):return
 await tap(KEY_F9);await adopt();await frames(3)
 if not require(area=="L12_CM" and hp()>0 and scene.resets==0,"Actual F9 old r19i Claw living"):return
 for cast in CONTROL:
  if not require(cast in scene.starting_magic.magic_state().get("spellbook",{}).get("learned",[]),"r19i old save migrates "+cast):return
 if not await control_loop("real r19i Claw save"):return
 await picture("r19i_claw_control")
 if not await disk_cycle("migrated_r19i"):return
 if not require("curse3" in scene.starting_magic.magic_state().spellbook.learned and FileAccess.get_sha256(OLD_INPUT)==OLD_PIN,"F5/F9 persists migration, original input bytes untouched"):return
 print("PASS real r19i Claw F9 migration + seven real F2 starts, actual CtrlQ both directions on F2/oldsave, F5F9; no teaching/pose/resource aids, only private config/checkpoint install and debit-clock fixtures")
 quit()
