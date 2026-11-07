extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_bridge_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="5340ed14935bd51506533cfdcbeadafe58f9de3b59a739dcbf34cc6dea0b6875","qualified bridge input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned upper ring input"):quit(1);return
 prepare(scene)
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_belial_ring_walk.json"))
 if not await walk(scene,points,"upper ring to original control103"):quit(1);return
 var target:=Vector3(-5482,4,-155)
 var offset:Vector3=scene.player.position-target
 check(Vector2(offset.x,offset.z).length()<100 and scene.player.position.y>35 and scene.player.is_on_floor(),"physical upper approach to source103")
 check(scene._quicksave_unrecorded("res://tmp/l13_belial_ring_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_belial_ring_earned_save.json").is_empty(),"earned ring approach save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("RING approach ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bridge -> physical upper ring -> original103 approach/save-reload; encounter admission not exercised")
 quit(0 if failures==0 else 1)
