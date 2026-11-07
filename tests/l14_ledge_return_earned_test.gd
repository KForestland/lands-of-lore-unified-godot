extends "res://tests/l14_ledge_maze_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_ledge_maze_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="7ea08c766ffdbf61addf0bfe4a6c0162f9bb7ac38dcc3d8bf93440a9fcd90ac4","qualified earned maze idol"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned maze idol input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_ledge_maze_walk.json"))
 route.exit.reverse()
 if not await walk(scene,route.exit,"return from original LifeIdol hall"):quit(1);return
 route.ledges.reverse()
 for hop in route.ledges:
  if hop.has("jump"):
   var back:Dictionary=hop.duplicate(true)
   back.jump.reverse();back.centres.reverse();back.from=hop.to;back.to=hop.from;back.landing_floor=float(hop.landing_floor)-float(hop.height)
   if not await jump_gap(scene,back):quit(1);return
  elif not await walk(scene,[hop.point],"reverse original raised maze ledges"):quit(1);return
  if not check(scene.player.position.y>110 and scene.resets==0,"raised return without pit shortcut"):quit(1);return
 route.entry.reverse()
 if not await walk(scene,route.entry,"maze entrance return"):quit(1);return
 if not await walk(scene,[[500,-1960],[430,-2080],[360,-2160],[36,-2230]],"return through original left door"):quit(1);return
 var trials=scene.get_node("L14Trials")
 check(trials.IDOL in scene.carried_collected and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"earned first idol brought back without seeds/recovery")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_ledge_return_earned_save.json")
 if not check(error.is_empty(),"first idol return save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_ledge_return_earned_save.json").is_empty(),"first idol return reload")
 print("FIRST IDOL RETURN ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned first trial idol -> reverse raised ledges/four physical sprint jumps -> original door -> three-door room/save-reload")
 quit(0 if failures==0 else 1)
