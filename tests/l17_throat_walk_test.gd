extends "res://tests/l12_logs_approach_earned_test.gd"
## BK01 (2026-11-09): a player walks the Subterranean Caverns from arrival 1 (1434, -7075) to the exit pocket (-5569, 6351)
## along the nav route (tests/fixtures/l17_arrival_to_pocket.json). The walk stopped at the cave throat (-4616, -2094): region
## 1236's corridor (a second layout at the same height) lay over corridor 562 - its boundary wall (region-edge rule) and its
## sloped floor and ceiling (region-aware collision: only regions within 8 nav hops of the player's collide).
## The book (ch.14): "you may run for the exit"; the spiders respawn, so the walk does not stop to fight them.
func fight_nearby(scene:Node)->bool:
 scene.curse.advance(1.0/60)
 if scene.starting_magic.health()<12 and scene.starting_magic.magic_state().cooldown<=0:
  scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
 return check(scene.starting_magic.health()>0,"survived the run through the caverns")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 # The chain's earned state (gear, health, the curse admission) from l17_cavern_run_earned_test, set down at the native
 # arrival 1: that save stands at the exit region, the walk starts where a player enters the caverns.
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
 check(int(scene.edge_rule_counts.get("pass_walls",0))>0,"the region-edge rule found boundary walls with a corridor beyond them (%s)"%str(scene.edge_rule_counts))
 check(scene.region_collision_enabled and scene.region_collision_shapes.size()>100 and scene.active_collision_regions>0 and scene.active_collision_regions<scene.region_collision_shapes.size(),"region-aware collision: %d region shapes, %d active near the arrival"%[scene.region_collision_shapes.size(),scene.active_collision_regions])
 check(scene.player.position.distance_to(Vector3(1434,32,-7075))<4,"native arrival 1")
 var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l17_arrival_to_pocket.json"))
 if not await walk(scene,fixture.points,"caverns to the exit pocket"):quit(1);return
 check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(-5569,6351))<30 and scene.resets==0,"the pocket is reached on foot without fall recovery at %s"%scene.player.position)
 check(scene._quicksave_unrecorded("res://tmp/l17_pocket_walk_save.json").is_empty(),"pocket save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L17 arrival 1 -> cave throat (region 1236's wall no longer cuts corridor 562) -> exit pocket on foot")
 quit(0 if failures==0 else 1)
