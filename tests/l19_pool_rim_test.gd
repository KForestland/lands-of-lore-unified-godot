extends "res://tests/l12_logs_approach_earned_test.gd"
## BK02 (2026-11-09): the blood pool in Belial's Chamber is a hole in the region graph (no native region covers it; the rim
## regions 613/18/28/612/610 have no neighbour on the pool side). The rim's source walls now block (the region-edge rule), so a
## player who walks at the pool stops at the rim instead of falling out of the world. (The a1468af version of this test passed by
## chance: its straight waypoints met region 696's west wall; the pool-side source walls were never on the movement body until
## jungle_review's region_edge_blocks hook. The L17 edge rule check of that build also walked through the native wall at z 210.)
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L19_BC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 for i in 5:await physics_frame
 check(int(scene.edge_rule_counts.get("block_source_walls",0))>0,"the region-edge rule found source walls with nothing beyond them (%s)"%str(scene.edge_rule_counts))
 # The native route (build_act3_routes L19_BC): region 25's south side has no neighbour (the wall at z 210 is the original's),
 # so the arrival leaves west through 26 and 7 into the corridor, then south to 698/696 at the blood pool.
 if not await walk(scene,[[56,296],[18,232],[18,168],[16,124],[16,-177],[16,-466],[14,-572],[12,-774],[12,-1018],[0,-1100],[-30,-1180]],"arrival to the bloody room"):quit(1);return
 var lowest:float=scene.player.position.y
 for tick in 900:
  var d:Vector3=Vector3(-200,0,-1450)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized(),1.0/60);scene.curse.advance(1.0/60);await physics_frame
  lowest=minf(lowest,scene.player.position.y)
  if d.length()<8:break
 print("POOL WALK ends at ",scene.player.position," lowest ",lowest," resets ",scene.resets)
 check(lowest>-60.0 and scene.resets==0,"the rim holds: no fall into the pool hole (lowest %.1f, resets %d; before the rule the walk fell to -1595)"%[lowest,scene.resets])
 check(scene.player.position.distance_to(Vector3(-200,scene.player.position.y,-1450))>40.0,"the pool centre is not reached on foot")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L19 bloody room: the pool rim's source walls block where no region lies beyond; no fall out of the world")
 quit(0 if failures==0 else 1)
