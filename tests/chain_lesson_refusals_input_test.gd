extends "res://tests/helpers/g15_world_spell_input.gd"
## Eight actual cast refusals at their lesson receivers. Supplied grounded
## stands, learned groups, a production curse-warning request and depleted-mana
## fixtures are declared aids; ordinary clock/real E+Q, no earned-route claim.
const Teaching=preload("res://scripts/lol2/player_spell_teaching.gd")
var rows:Array=[]
func _initialize():main.call_deferred()
func fresh(which:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame
 if which!="L9_DR":return await boot_map(which)
 # L9's production host is the dragon-level scene, not maps/L9_DR.tscn.
 scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 if not require(scene.ready_for_review,"Ruins production owners ready"):return false
 use_guard=false;await adopt()
 if not captured():await lclick();await frames(3)
 return require(hp()>0 and scene.resets==0 and captured(),"Living ordinary Ruins component")
func probe(id:String,owner_name:String,school:Key,charge:int,story:=false)->bool:
 var magic:Node=scene.starting_magic
 var lesson:Dictionary={}
 for row:Dictionary in Teaching.table().live_lessons:
  if row.area==scene.area_id and row.owner==owner_name and Teaching.required_cast(row,scene.player_form)==id:lesson=row;break
 if not require(not lesson.is_empty(),"Named production lesson for "+id):return false
 await tap(school)
 magic.set_process(false) # Hold only regeneration/teaching/notice clocks for exact fixture debit.
 if not story:
  var drained:Dictionary=magic.magic_state().duplicate(true);drained.player.mana=0;drained.cooldown=0;magic.commit(drained)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_E)
 if not require(scene.interface_hud.hint.text==str(lesson.message),"Real E displays active reminder at "+id):return false
 var serial:int=magic.refusal_serial
 await tap(KEY_Q,charge==3,charge==5)
 var expected:="The mother shoots a fireball back. She does not die." if story else "Not enough mana - it returns over time."
 for tick in 12:
  await process_frame
  if not require(expected in scene.interface_hud.hint.text and scene.interface_hud.hint.text!=str(lesson.message),"Real cast refusal remains visible after reminder: "+id+" got "+scene.interface_hud.hint.text):return false
 if not require(magic.refusal_serial>serial and magic.magic_state().player.mana==mana,"Refused actual cast has no debit: "+id):return false
 if story and not require(not scene.get_node(owner_name).state().glob_entered,"Story refusal never advances mother"):return false
 rows.append({"cast":id,"area":scene.area_id,"owner":owner_name,"cue":scene.interface_hud.hint.text,"mana":mana,"clock":[Engine.time_scale,Engine.physics_ticks_per_second]})
 await picture("lesson_refusal_"+id)
 return true
func main():
 if not await fresh("L9_DR"):return
 if not await stand_at(Vector3(4111,12,-10080)):return
 scene.starting_magic.learn_spell_group("dampen")
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0),"Disclosed real warning request for Dampen eligibility"):return
 if not await probe("curse1","L9StatueWalk",KEY_3,1):return
 if not await fresh("L9_DR"):return
 if not await stand_at(Vector3(4111,12,-10080)):return
 scene.starting_magic.learn_spell_group("control")
 await tap(KEY_3);await tap(KEY_Q,true);await ticks(40)
 if not require(scene.player_form==2,"Real Control3 provides the return-form case"):return
 if not await probe("curse2","L9StatueWalk",KEY_3,3):return
 if not await fresh("L12_CM"):return
 if not await stand_at(scene.get_node("L12Crevasse").SPARK+Vector3(160,0,0)):return
 scene.starting_magic.learn_spell_group("control")
 if not await probe("curse3","L12Crevasse",KEY_3,3):return
 if not await fresh("L19_BC"):return
 if not await stand_at(scene.get_node("L19GhostlyHeads").AT_67+Vector3.UP*32):return
 scene.starting_magic.learn_spell_group("mists")
 if not await probe("mists1","L19GhostlyHeads",KEY_4,1):return
 if not await fresh("L16_CA"):return
 if not await stand_at(Vector3(-4111,107,15386)):return
 if not await look(Vector3(-4111,145,15457)):quit(1);return
 scene.starting_magic.learn_spell_group("mists")
 if not await probe("mists3","L16FountainFreeze",KEY_4,3):return
 if not await fresh("L16_CA"):return
 if not await stand_at(Vector3(-8940,132,-3286)):return
 if not await look(scene.get_node("L16NwTraps").ICE_AT):quit(1);return
 scene.starting_magic.learn_spell_group("summon")
 if not await probe("summon3","L16NwTraps",KEY_6,3):return
 if not await fresh("L20_BB"):return
 if not await stand_at(scene.get_node("L20PillarsScotia").SCOTIA_AT+Vector3.UP*32):return
 scene.starting_magic.learn_spell_group("prism")
 if not await probe("prism5","L20PillarsScotia",KEY_5,5):return
 if not await fresh("L20_BB"):return
 if not await stand_at(scene.get_node("L20MotherCurse").MOTHER_AT+Vector3.UP*32):return
 scene.starting_magic.learn_spell_group("control")
 if not await probe("curse5","L20MotherCurse",KEY_3,5,true):return
 if not require(rows.size()==8 and scene.resets==0,"All eight actual refusal rows completed without recovery"):return
 var file:=FileAccess.open("user://tests/g15_casts/lesson_refusals.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
 print("PASS all eight real E reminders then actual Q/modified-Q refusals remain visible, mother keeps story line, no debit/outcome; declared learning/stand/depleted-mana/clock/warning fixtures")
 quit()
