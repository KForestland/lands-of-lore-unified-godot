extends "res://tests/l12_logs_approach_earned_test.gd"
## BK03 (2026-11-09): the guck of Belial's Chamber is a liquid, not a wall. The liquid regions are staged from the guck floors
## (materials 265 / 211); the bit0 gutters beside the arrival corridor are no longer blocker walls; wading and drowning are the
## Classic liquid rule. The guck's mana/health drain waits for the native rate (lead decision 2026-11-09: no invented timers;
## Grok BK13).
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L19_BC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 for i in 5:await physics_frame
 if not check(scene.liquid_drowning!=null and scene.liquid_drowning.regions.size()>200,"L19 liquid regions staged (%d)"%(scene.liquid_drowning.regions.size() if scene.liquid_drowning!=null else 0)):quit(1);return
 # (a) The sewer cavity (region 309, floor -45, bank surface -25; its walkways 310/311 are 40 high: Lizard passages). A Human
 # set down in the cavity wades with the head above the guck; a Lizard would be under.
 scene.player.position=Vector3(2936,-45+32,-3140);scene.player.velocity=Vector3.ZERO
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 print("CAVITY at ",scene.player.position)
 if not check(absf(scene.player.position.y-(-45+32))<4 and scene.resets==0,"the Human stands on the guck bed at -45 (y %.1f)"%scene.player.position.y):quit(1);return
 check(not scene.liquid_drowning.submerged(scene.player.position,0) and scene.liquid_drowning.submerged(scene.player.position,2),"a Human wades with the head above the guck; a Lizard would be under")
 # The sewer's creatures are not the subject here: the population is removed before the wade so only the guck could cost health.
 if is_instance_valid(scene.act2_creatures):scene.act2_creatures.queue_free();await process_frame
 var health_before:int=int(scene.starting_magic.health())
 for i in 240:
  scene.move_grounded(Vector3.ZERO,1.0/60);scene.curse.advance(1.0/60);await physics_frame
 print("GUCK health ",health_before," -> ",scene.starting_magic.health()," submerged0 ",scene.liquid_drowning.submerged(scene.player.position,0))
 check(int(scene.starting_magic.health())>=health_before,"wading costs nothing until the native guck rate is decoded (lead BK13): %d -> %d"%[health_before,int(scene.starting_magic.health())])
 # (b) The gutters beside the arrival corridor (region 733, 23 units wide, floor -100, bit0) were blocker walls; the Lizard fits.
 scene.player.position=Vector3(20,22,80);scene.player.velocity=Vector3.ZERO
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 scene.curse.set_requests_enabled(true)
 if not check(scene.curse.request_timed_form(2,240.0),"Lizard form for the gutter"):quit(1);return
 for i in 1200:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 print("MORPH state ",scene.curse.state," on_floor ",scene.player.is_on_floor()," form ",scene.player_form," pos ",scene.player.position)
 if not check(scene.player_form==2,"the Lizard"):quit(1);return
 var lowest:float=scene.player.position.y
 for tick in 900:
  var d:Vector3=Vector3(132,0,-322)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized(),1.0/60);scene.curse.advance(1.0/60);await physics_frame
  lowest=minf(lowest,scene.player.position.y)
  if d.length()<4:break
 for i in 300:
  var d:Vector3=Vector3(132,0,-322)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>4 else Vector3.ZERO,1.0/60);scene.curse.advance(1.0/60);await physics_frame
  lowest=minf(lowest,scene.player.position.y)
 print("GUTTER Lizard at ",scene.player.position," lowest ",lowest," resets ",scene.resets," on_floor ",scene.player.is_on_floor())
 check(scene.player.position.x>110.0 and scene.player.position.y< -50.0 and scene.resets==0,"the gutter is no longer a wall: the Lizard drops into the guck channel (x %.0f y %.1f)"%[scene.player.position.x,scene.player.position.y])
 check(scene.liquid_drowning.submerged(scene.player.position,2),"the Lizard is under the guck in the channel")
 check(scene._quicksave_unrecorded("res://tmp/l19_guck_save.json").is_empty(),"a save in the guck")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L19 guck: liquid regions staged; a Human wades the sewer cavity; the gutter beside the arrival admits the Lizard, which goes under")
 quit(0 if failures==0 else 1)
