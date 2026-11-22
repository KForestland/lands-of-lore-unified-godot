extends "res://tests/g04_floor_input_test.gd"
## Untouched game-written crevasse producer output from Opus's r19k sweep.
## Actual legacy apply is disclosed; subsequent Spark/F5/F9 use engine input.
const INPUT:="res://tests/fixtures/g04_inputs/l12_crevasse_cooldown.json"
const PIN:="ff5cc5ec1659c7fefdd9ab0efc4ddd9e1a050d7782e0fa21bd5b41dc0465245e"
const AreaSave=preload("res://scripts/lol2/act2_save.gd")
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered cooldown load/input proof"):return
 if not check(FileAccess.get_sha256(INPUT)==PIN,"Untouched actual producer pin"):return
 var read:=AreaSave.read_save(INPUT,"lol2-restoration-map-L12_CM")
 if not check(read.error.is_empty() and absf(float(read.state.quests.player_magic_reward_state.cooldown)-0.417216)<0.000001,"Real producer carries reported0.42s cooldown"):return
 scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 scene.starting_magic.set_process(false)
 if not check(scene.apply_save(read.state).is_empty(),"Actual legacy loader accepts producer packet"):return
 if not check(float(scene.starting_magic.magic_state().get("cooldown",0))==0,"Loading clears the invisible previous cast cooldown before first input"):return
 await look(scene.get_node("L12FrozenBow").POINT);await key(KEY_1)
 var mana:int=scene.starting_magic.magic_state().player.mana
 await key(KEY_Q)
 if not check(scene.starting_magic.magic_state().player.mana==mana-1 and scene.get_node("L12FrozenBow").state().remaining>0,"First real Q immediately hits original ice after load"):return
 if not check(float(scene.starting_magic.magic_state().cooldown)>0,"Positive control: new casts still own their live cooldown"):return
 scene.set_physics_process(true)
 for i in 60:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 await key(KEY_F5);await ticks(2)
 var saved:=Saves.read_document(Saves.slot_path(1))
 if not check(saved.error.is_empty() and float(saved.state.area_save.quests.player_magic_reward_state.cooldown)>0,"Actual F5 captures active cooldown"):return
 if not await reload():return
 scene.starting_magic.set_process(false)
 if not check(float(scene.starting_magic.magic_state().get("cooldown",0))==0,"Whole-game F9 also clears old cast cooldown"):return
 await key(KEY_1);mana=scene.starting_magic.magic_state().player.mana
 await key(KEY_Q)
 if not check(scene.starting_magic.magic_state().player.mana==mana-1 and scene.resets==0,"First real Q after F9 is admitted without waiting or recovery"):return
 print("PASS actual0.417216s producer legacy load +first realSpark; live cooldown positive control; realF5/F9 clears cooldown and immediate nextQ")
 quit()
