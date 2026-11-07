extends "res://tests/l10_barrel_earned_test.gd"
func load_oil()->Node:
 var input:=Save.read_save("res://tmp/l10_oil_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):return null
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual earned spilled-oil input"):return null
 prepare(scene)
 for i in 4:await physics_frame
 return scene
func floor_hit(scene: Node)->Dictionary:
 return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1435,60,-3350),Vector3(-1435,-160,-3350),1,[scene.player.get_rid()]))
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var scene=await load_oil()
 if scene==null:quit(1);return
 var oil=scene.get_node("L10Oil")
 var hit:=floor_hit(scene)
 check(not hit.is_empty() and absf(hit.position.y)<1,"intact source floor blocks catacomb below")
 if not await walk(scene,[[-1435,-3120],[-1428,-3005],[-1428,-2840]],"retreat outside blast"):quit(1);return
 scene.camera.look_at(oil.AIM,Vector3.UP)
 scene.starting_magic.select_spell("spark")
 for i in 180:await physics_frame
 var mana: int=scene.starting_magic.magic_state().player.mana
 check(scene.starting_magic.cast(1),"actual basic Spark at distant oil")
 check(not oil.burned(),"basic384 range cannot reach distant oil")
 check(scene.starting_magic.magic_state().player.mana==mana-1,"basic cast debits once")
 for i in 180:await physics_frame
 var health: int=scene.starting_magic.health();mana=scene.starting_magic.magic_state().player.mana
 if not check(scene.starting_magic.cast(3) and oil.burned(),"level3 Spark ray ignites earned oil from distance"):quit(1);return
 check(scene.starting_magic.magic_state().player.mana==mana-3,"level3 real mana debit once")
 check(scene.starting_magic.health()==health,"distant caster outside explosion")
 check(not oil.ignite(3),"duplicate explosion refused")
 var path:="res://tmp/l10_explosion_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual exploded tomb save/reload")
 for i in 10:await physics_frame
 hit=floor_hit(scene)
 print("COLLAPSE RAY ",hit)
 if not check(not hit.is_empty() and absf(hit.position.y+90)<1,"collapsed floor and clipped buried ceiling expose original lower floor"):quit(1);return
 if not await walk(scene,[[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]],"physical descent into collapsed tomb"):quit(1);return
 for i in 120:
  await physics_frame
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
 if not check(absf(scene.player.position.y+58)<3,"physical landing on native catacomb floor minus90"):quit(1);return
 path="res://tmp/l10_north_catacomb_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual catacomb landing save/reload")
 for id in ["act2:L10_DC:item45","act2:L10_DC:item9","act2:L10_DC:item8:charged:white","act2:L9_DR:item55"]:check(id in scene.carried_collected,"retains earned item "+id)
 scene.queue_free();await process_frame
 # Separate refusal/hazard branch starts from the same real input; never merges into the earned route.
 scene=await load_oil()
 if scene==null:quit(1);return
 oil=scene.get_node("L10Oil");scene.camera.look_at(oil.AIM,Vector3.UP);scene.starting_magic.select_spell("spark")
 for i in 180:await physics_frame
 health=scene.starting_magic.health()
 check(scene.starting_magic.cast(1) and oil.burned(),"short Spark ignites when actually in range")
 check(scene.starting_magic.health()==maxi(0,health-oil.BLAST_DAMAGE),"close caster caught in real blast")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned oil -> retreat -> range-limited basic refusal -> level3 real Spark/mana -> scoped source collapse -> actual catacomb landing save; isolated close-cast blast branch never merged")
 quit(0 if failures==0 else 1)
