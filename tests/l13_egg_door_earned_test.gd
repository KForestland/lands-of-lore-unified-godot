extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_citadel_arrival_regression_anchor.json"
 if not check(FileAccess.get_sha256(path)=="21db5d3f9596650ad96df594e103eca6eb79dea299d91e585e610b146622b948","qualified citadel input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual citadel arrival"):quit(1);return
 prepare(scene)
 var door=scene.get_node("L13EggDoor")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_egg_door_walk.json"))
 if not await walk(scene,route.points,"first egg globe"):quit(1);return
 var gate:=PhysicsRayQueryParameters3D.create(Vector3(-3260,32,4950),Vector3(-3260,32,4850),1<<9)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(gate).is_empty(),"original region1226 blocks closed passage")
 scene.camera.look_at(door.AIM,Vector3.UP)
 paused=true;check(not door.light(1),"paused globe refuses");paused=false
 check(not door.light(5),"non-Spark aura cannot directly open globe")
 for i in 180:
  await physics_frame
  if scene.starting_magic.magic_state().cooldown<=0:break
 scene.starting_magic.select_spell("spark")
 var mana:int=scene.starting_magic.magic_state().player.mana
 if not check(scene.starting_magic.cast(),"production Spark cast"):quit(1);return
 await physics_frame
 if not check(door.state().opened,"actual Spark ray opens original egg door"):quit(1);return
 check(scene.starting_magic.magic_state().player.mana==mana-1,"single mana debit")
 check(scene.get_world_3d().direct_space_state.intersect_ray(gate).is_empty(),"original passage collision clears")
 var saved:="res://tmp/l13_egg_globe_earned_save.json"
 check(scene._quicksave_unrecorded(saved).is_empty() and scene._quickload_unrecorded(saved).is_empty(),"globe receipt save/reload")
 if not await walk(scene,[[-3320,5500],[-3320,5200],[-3260,5000],[-3260,4800]],"open egg doorway"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_egg_door_earned_save.json").is_empty(),"physical egg-door crossing saved")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned native citadel arrival -> original globe420 real Spark/mana -> original door106/region1226 opening -> physical crossing/save-reload")
 quit(0 if failures==0 else 1)
