extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_river_niche_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="8ce68e0b9955215e583b7863e7395edd46a57d0905ea992dd902b9136e8fc308","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var armor=scene.get_node("L12NicheArmor")
 if not await walk(scene,[[20,-14165]],"niche original prop136"):quit(1);return
 scene.camera.look_at(armor.POINT,Vector3.UP)
 check(not armor.take().ok,"armor unavailable before actual Spark")
 check(not armor.spark(2),"non-Spark level refused")
 paused=true;check(not armor.spark(1),"paused Spark receiver refuses");paused=false
 for i in 180:
  await physics_frame
  if scene.starting_magic.magic_state().cooldown<=0:break
 scene.starting_magic.select_spell("spark")
 var mana:int=scene.starting_magic.magic_state().player.mana
 if not check(scene.starting_magic.cast(),"actual Spark on original prop136"):quit(1);return
 await physics_frame
 if not check(armor.state().revealed and armor.sprite.visible,"Spark reveals original dormant item5"):quit(1);return
 check(scene.starting_magic.magic_state().player.mana==mana-1,"single actual mana debit")
 check(not armor.spark(1),"repeat Spark cannot duplicate reveal")
 var before:Array=scene.carried_collected.duplicate()
 check(not armor.take(scene.carried_collected.size()).ok and scene.carried_collected==before and not armor.state().taken,"full inventory refusal without loss")
 check(scene._quicksave_unrecorded("res://tmp/l12_armor_revealed_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_armor_revealed_save.json").is_empty(),"revealed armor save/reload")
 scene.camera.look_at(armor.POINT,Vector3.UP)
 if not check(armor.take().ok,"actual armor pickup and equip"):quit(1);return
 check(scene.carried_collected.count(armor.ITEM)==1 and scene.equipped_armor==armor.ITEM,"original armor equipped once")
 check(preload("res://scripts/lol2/item_catalog.gd").defense(armor.ITEM)==40,"original definition54 defense40")
 check(not armor.take().ok,"duplicate pickup refused")
 var error:String=scene._quicksave_unrecorded("res://tmp/l12_niche_armor_earned_save.json")
 if not check(error.is_empty(),"equipped armor save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l12_niche_armor_earned_save.json")
 check(error.is_empty(),"equipped armor reload: "+error)
 check(armor.state().taken and not armor.sprite.visible and scene.equipped_armor==armor.ITEM and scene.carried_collected.count(armor.ITEM)==1,"armor persists equipped once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned raft niche ->actual Spark prop136 ->original armor5 equipped/save-reload")
 quit(0 if failures==0 else 1)
