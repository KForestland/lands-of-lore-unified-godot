extends "res://tests/l9_chapel_earned_test.gd"
func jump_into(scene:Node,prison:Node)->bool:
 scene.jump_requested=true
 for i in 150:
  var d:Vector3=prison.PLATE-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>5 else Vector3.ZERO,1.0/60.0,true);await physics_frame
  if prison.entered:break
 return check(prison.entered and paused,"actual Human jump into source prison plate")
func land(scene:Node):
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player.is_on_floor():break
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_ruloi_cleared_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="be33f4bd95dbf874bc1f31bc4da0d6f9408d66fa79f91556650bdd43781ceee0","qualified nineteen Ruloi input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Ruloi input"):quit(1);return
 prepare(scene)
 var spires=scene.get_node("L13Spires");var dawn=scene.get_node("L13DawnPrison");var prison=scene.get_node("L13Prison")
 check(not dawn.can_enter(),"unlit gate refuses Dawn entry")
 for leg in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_spires_prison_walk.json")):
  if not await walk(scene,leg.points,"Spire/prison "+leg.id):quit(1);return
  if str(leg.id).is_valid_int():
   var id:=int(leg.id)
   scene.camera.look_at(spires.aims[id],Vector3.UP);scene.starting_magic.select_spell("spark")
   for i in 1800:
    scene.starting_magic.cast();scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
    if str(id) in spires.state().lit:break
   if not check(str(id) in spires.state().lit,"actual Spark lights original Spire "+str(id)):quit(1);return
  elif leg.id=="dawn":
   if not await jump_into(scene,dawn):quit(1);return
   check(dawn.state().visited and not dawn.state().released,"original Dawn room visited without Dreamstone")
   check(dawn.use_switch(),"examine stone-shaped recess")
   check(not scene._quicksave_unrecorded("res://tmp/forbidden_dawn_save.json").is_empty(),"Dawn overlay save refused")
   dawn.leave();await land(scene)
  else:
   if not await jump_into(scene,prison):quit(1);return
   check(prison.use_switch() and prison.cue=="release","all nineteen earned deaths admit original release")
   for i in 6000:
    await process_frame
    if not prison.entered:break
   if not check(prison.state().released and not paused,"full original release movie completes"):quit(1);return
   await land(scene)
 check(scene._quicksave_unrecorded("res://tmp/l13_prisons_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_prisons_earned_save.json").is_empty(),"earned spires/prisons save reload")
 check(dawn.state().visited and prison.state().released and spires.dawn_ready(),"earned room/gate states persist")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS physical ground Spires/Spark -> Dawn jump/recess -> maidens jump/full original release -> earned save/reload")
 quit(0 if failures==0 else 1)
