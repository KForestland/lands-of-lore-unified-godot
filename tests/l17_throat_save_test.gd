extends "res://tests/l12_logs_approach_earned_test.gd"
## BK01 follow-up (Kimi K62, 2026-11-09): a save taken inside the cave throat, where region 1236's layout lies over corridor
## 562 at the same floor, reloads on the same layer. The region-aware collision tracks the body's region like the original
## mover; a fresh nearest-floor pick at that spot may land on 1236, so the act2 save records the tracked region
## (player.region) and apply_save keeps it while the body still lies inside that polygon. A save without the key stays valid.
func fight_nearby(scene:Node)->bool:
 scene.curse.advance(1.0/60)
 if scene.starting_magic.health()<12 and scene.starting_magic.magic_state().cooldown<=0:
  scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
 return check(scene.starting_magic.health()>0,"survived the run through the caverns")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input=Save.read_save("res://tmp/l17_cavern_run_earned_save.json","lol2-restoration-map-L17_HC")
 if not check(input.error.is_empty(),"earned cavern save: "+str(input.error)):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L17_HC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 scene.progression.change_scene_enabled=false
 if not check(scene.apply_save(input.state).is_empty(),"apply the earned cavern state"):quit(1);return
 scene.player.position=Vector3(1434,32,-7075);scene.player.velocity=Vector3.ZERO
 for i in 20:await physics_frame
 prepare(scene)
 for i in 5:await physics_frame
 check(scene.region_collision_enabled and scene.region_collision_shapes.size()>100,"region-aware collision hosted (%d region shapes)"%scene.region_collision_shapes.size())
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l17_arrival_to_pocket.json"))
 var to_throat:Array=fixture.points.slice(0,36)
 to_throat.append([-4585.0,-2089.0]) # inside both corridor 562 and layout 1236 (creature_nav polygons)
 if not await walk(scene,to_throat,"caverns to the cave throat"):quit(1);return
 var pos:Vector3=scene.player.position
 check(scene._inside_nav_region(562,pos) and scene._inside_nav_region(1236,pos),"the throat: the body stands inside corridor 562 and layout 1236 at the same time (%s)"%pos)
 check(scene.last_collision_region==562,"the tracked region is corridor 562 (got %d)"%scene.last_collision_region)
 print("THROAT body ",pos," tracked ",scene.last_collision_region," fresh nearest-floor pick ",scene.progression.region_at(pos))
 var path:="res://tmp/l17_throat_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"F5 in the throat")
 var saved=Save.read_save(path,"lol2-restoration-map-L17_HC")
 check(saved.error.is_empty() and int(saved.state.player.get("region",-1))==562,"the save records the tracked region 562 (%s)"%str(saved.state.get("player",{}).get("region")))
 var legacy:Dictionary=saved.state.duplicate(true);legacy.player.erase("region")
 check(scene.apply_save(legacy).is_empty(),"a save without the region key stays valid")
 print("THROAT reload without the key picks ",scene.last_collision_region)
 # The saved region decides the layer while the body lies inside its polygon (1236 is the other layout over this spot);
 # a saved region the body is not inside (567, the corridor behind) is ignored and the fresh pick applies.
 var other:Dictionary=saved.state.duplicate(true);other.player.region=1236
 check(scene.apply_save(other).is_empty() and scene.last_collision_region==1236,"a save on layout 1236 reloads on 1236's layer (got %d)"%scene.last_collision_region)
 check(scene.region_collision_shapes.has(1236) and not scene.region_collision_shapes[1236].disabled and scene.region_collision_shapes[562].disabled,"on 1236's layer corridor 562's shape is off and 1236's is on")
 var stale:Dictionary=saved.state.duplicate(true);stale.player.region=567
 check(scene.apply_save(stale).is_empty() and scene.last_collision_region==562,"a saved region the body is not inside falls back to the fresh pick (got %d)"%scene.last_collision_region)
 check(scene.apply_save(saved.state).is_empty(),"F9: reload the throat save")
 for i in 5:await physics_frame
 check(scene.last_collision_region==562,"after the reload the body is on corridor 562's layer (got %d)"%scene.last_collision_region)
 check(scene.region_collision_shapes.has(562) and not scene.region_collision_shapes[562].disabled,"corridor 562's shape collides after the reload")
 check(scene.player.position.distance_to(pos)<2 and scene.resets==0,"the body stands where it saved")
 if not await walk(scene,fixture.points.slice(36),"the throat to the exit pocket"):quit(1);return
 check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(-5569,6351))<30 and scene.resets==0,"the pocket is reached on foot after the reload without fall recovery at %s"%scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS L17 save in the cave throat: the reload keeps corridor 562's layer over layout 1236 and the walk reaches the exit pocket")
 quit(0 if failures==0 else 1)
