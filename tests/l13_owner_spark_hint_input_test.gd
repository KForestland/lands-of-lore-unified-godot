extends "res://tests/helpers/g15_spell_input.gd"
## Untouched local owner F10. Real mouse/E/1/Q/J/F5/F9; no supplied pose or pool.
const Save=preload("res://scripts/lol2/game_save.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const Combat=preload("res://scripts/lol2/player_combat.gd")
func owner_input_index()->int:return 0
const MESSAGE="The globe is dark. Cast Spark at it (1, then Q)."
func _initialize():main.call_deferred()
func main():
 var inputs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_hint_inputs_manifest.json"))
 var input:String="res://"+str(inputs.files[owner_input_index()].path)
 if not require(FileAccess.get_sha256(input)==str(inputs.files[owner_input_index()].sha256),"Untouched local owner full save"):return
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 if not require(Save.load_file(self,input).is_empty(),"Actual whole-game owner loader"):return
 await scene_changed
 for tick in 3000:
  await process_frame
  if is_instance_valid(current_scene) and bool(current_scene.get("ready_for_review")):break
 if not require(is_instance_valid(current_scene) and bool(current_scene.get("ready_for_review")),"Owner area ready before sending keys"):return
 use_guard=false;await adopt()
 if not captured():await lclick();await frames(3)
 var door:Node=scene.get_node("L13EggDoor")
 if not require(not door.state().opened,"Owner actually arrives before door106 is opened"):return
 if owner_input_index()==1:
  if not await look(Vector3(-3263,70,4909)):return
  var hit:Dictionary=Combat.aim_ray(scene,384,3)
  if not require(not hit.is_empty() and hit.collider==door.face_body,"Second owner stop really aims the closed106 leaf"):return
  await tap(KEY_E);await frames(3)
  if not require(scene.interface_hud.hint.text==MESSAGE and not door.state().opened,"Real E on closed door106 echoes the globe instruction"):return
 if not await look(door.receiver.global_position+Vector3.UP*12):return
 var mana:int=scene.starting_magic.magic_state().player.mana
 await tap(KEY_E);await frames(4)
 if not require(scene.interface_hud.hint.text==MESSAGE and not door.state().opened and scene.starting_magic.magic_state().player.mana==mana,"Real E on the dark globe explains1/Q without opening/casting/debit"):return
 await tap(KEY_F5)
 if not require(FileAccess.file_exists(Save.slot_path(1)),"Real F5 during the lesson writes its slot"):return
 var started:int=Time.get_ticks_msec()
 while Time.get_ticks_msec()-scene.interface_hud.lesson_started_msec<5900:
  await process_frame
  if not require(scene.interface_hud.hint.text==MESSAGE,"Lesson remains readable for six wall seconds"):return
 if not require(Journal.notes(scene).count("l13_action_egg_globe")==1,"Exact hint goes into the Journal once"):return
 await tap(KEY_E);await frames(3)
 if not require(Journal.notes(scene).count("l13_action_egg_globe")==1,"Repeated E does not duplicate the Journal"):return
 await tap(KEY_J);await frames(3)
 if not require(scene.interface_hud.sheet.visible and scene.interface_hud.sheet_body.text.count(MESSAGE)==1,"Real J displays the sentence once"):return
 await picture("owner_globe_lesson_journal")
 await tap(KEY_J);await frames(3)
 if not captured():await tap(KEY_TAB);await frames(3)
 await tap(KEY_1);await tap(KEY_Q);await frames(12)
 if not require(door.state().opened and door.face_body.collision_layer==0 and not door.blocker.is_region_blocked(1226),"Actual1 thenQ opens native door106 and its passage"):return
 if not require(scene.interface_hud.lesson_text!=MESSAGE,"Completed globe no longer repeats its requirement"):return
 await picture("owner_door106_open")
 if not await disk_cycle("l13_owner_hint"):return
 if not require(scene.get_node("L13EggDoor").state().opened and Journal.notes(scene).count("l13_action_egg_globe")==1 and hp()>0 and scene.resets==0,"Door and one Journal hint survive actualF5/F9, alive/zero recovery"):return
 print("PASS untouched owner input ",owner_input_index()," real mouse/E echo, readable6s, J once,1/Q opens106, F5/F9; ordinary1/60, no supplied body/resources/clock")
 quit()
