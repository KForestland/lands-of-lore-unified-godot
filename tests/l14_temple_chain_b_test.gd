extends "res://tests/l14_temple_chain_a_test.gd"
## BJ08 part B (hint book ch. 12 p.136-137): from part A's output (the statue from the grinder, in the lower hall) back up as the
## Lizard to the sunken ritual floor -> the red-pillow bedroom, the headboard, the Lizard hop behind the altar and the crack ->
## the two hall buttons in order -> the library and its exit button -> the statue into the empty niche, the second green shard
## from the pedestal -> back through the hanging to the two floating bowls, a shard in each -> the passage behind them -> the
## Dreamstone in the slot raises the spiral stair -> up and over the bridge to the room with three doors. Every stop is a
## quicksave + reload + re-save. Output: tmp/l14_chain_b_save.json.
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input=Save.read_save(OUT+"a_save.json","lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),"part A output: "+str(input.error)):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"part A state"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var statue:="act2:L14_HT:item65"
 check(scene.carried_collected.count(statue)==1 and scene.carried_collected.count("act2:L14_HT:post_shard")==1 and scene.carried_collected.count("act2:L13_RC:dreamstone")==1,"statue, shard and Dreamstone carried from part A")
 # 1. Back along the lower corridor; the Lizard jumps up to the sunken ritual floor; Human through the opened hanging to the bedroom.
 var bedroom_route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_bedroom_approach.json"))
 if not await walk(scene,bedroom_route.lower,"lower corridor return"):quit(1);return
 if not await change_form(scene,2,"Lizard for the seam up"):quit(1);return
 if not await walk(scene,[[2290,-3200]],"lower floor takeoff"):quit(1);return
 if not check(scene.request_jump(),"Lizard jump up to the sunken ritual floor"):quit(1);return
 if not await walk(scene,[[2300,-3300],[2300,-3400]],"ritual floor as the Lizard"):quit(1);return
 if not await change_form(scene,0,"Human on the ritual floor"):quit(1);return
 if not await walk(scene,[[2300,-3500],[2350,-3610],[2315,-3660],[2220,-3750],[2174,-3795]],"through the opened hanging"):quit(1);return
 if not await walk(scene,bedroom_route.upper,"the red pillow bedroom"):quit(1);return
 check(scene.player.position.y>145,"the bedroom floor")
 if not checkpoint(scene,"bedroom"):quit(1);return
 # 2. The headboard, the Lizard hop behind the altar, the crack, Human in the lower hall.
 var bedroom=scene.get_node("L14Bedroom")
 scene.camera.look_at(bedroom.POINT,Vector3.UP)
 if not check(bedroom.interact().ok,"push the headboard"):quit(1);return
 for i in 160:await physics_frame
 if not await walk(scene,[[2200,-5271],[2290,-5271],[2200,-5271]],"behind the headboard and back"):quit(1);return
 if not await change_form(scene,2,"Lizard for the crack"):quit(1);return
 if not check(scene.request_jump(),"Lizard hop behind the altar"):quit(1);return
 if not await walk(scene,[[2100,-5272]],"west crack lip"):quit(1);return
 if not await walk(scene,[[2200,-5272],[2350,-5290],[2420,-5270],[2440,-5270]],"the low crack"):quit(1);return
 if not check(scene.player.position.y<50,"the lower corridor beyond the crack"):quit(1);return
 if not await change_form(scene,0,"Human in the lower hall"):quit(1);return
 if not checkpoint(scene,"crack"):quit(1);return
 # 3. The two hall buttons in order; the lowered stairs; the Lizard for the low slope; the library barrier opens.
 var library=scene.get_node("L14Library")
 scene.camera.look_at(library.BUTTONS[146],Vector3.UP)
 if not check(library.interact(146).ok,"the first hall button"):quit(1);return
 for i in 160:await physics_frame
 var lib_route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_library_walk.json"))
 if not await walk(scene,lib_route.slice(0,16),"lowered stairs to the low slope"):quit(1);return
 if not await change_form(scene,2,"Lizard for the low slope"):quit(1);return
 if not await walk(scene,lib_route.slice(18,20),"the low sloped corridor"):quit(1);return
 if not await change_form(scene,0,"Human beyond the slope"):quit(1);return
 if not await walk(scene,lib_route.slice(20),"hall to the second button"):quit(1);return
 scene.camera.look_at(library.BUTTONS[147],Vector3.UP)
 if not check(library.interact(147).ok,"the second hall button"):quit(1);return
 for i in 160:await physics_frame
 if not await walk(scene,[[1940,-4360],[2035,-4360],[2130,-4360]],"into the library"):quit(1);return
 if not checkpoint(scene,"library"):quit(1);return
 # 4. The library exit button; the Lizard back through the steep corridor; the outer room.
 var exit_route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_library_exit_walk.json"))
 if not await walk(scene,exit_route,"to the library wall button"):quit(1);return
 scene.camera.look_at(library.BUTTONS[148],Vector3.UP)
 if not check(library.interact(148).ok,"the library exit button"):quit(1);return
 for i in 160:await physics_frame
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"Lizard for the steep return"):quit(1);return
 for i in 600:
  if scene.curse.state.remaining<0.15 and scene.player.is_on_floor():scene.request_jump()
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"Lizard at the exit"):quit(1);return
 if not await walk(scene,[[1735,-5041.5],[1845,-5088]],"the opened library exit"):quit(1);return
 if not check(scene.request_jump(),"jump from the lowered exit floor"):quit(1);return
 if not await walk(scene,[[1845,-5163],[1847,-5198]],"exit floor seam"):quit(1);return
 if not await change_form(scene,0,"Human in the outer room"):quit(1);return
 if not checkpoint(scene,"library_exit"):quit(1);return
 # 5. South to the room with the curved wall; the Lizard through the low corridor; the statue into the empty niche; the shard.
 var niche_route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_niche_approach.json"))
 if not await walk(scene,niche_route.slice(0,43),"statue niche approach"):quit(1);return
 if not await change_form(scene,2,"Lizard for the niche corridor"):quit(1);return
 if not await walk(scene,niche_route.slice(43,52),"low header and niche floor"):quit(1);return
 if not await change_form(scene,0,"Human in the statue room"):quit(1);return
 if not await walk(scene,niche_route.slice(52),"the empty niche"):quit(1);return
 var niche=scene.get_node("L14Niche")
 scene.camera.look_at(niche.POINT,Vector3.UP)
 if not check(niche.offer().ok,"the statue into the empty niche"):quit(1);return
 for i in 160:await physics_frame
 if not check(niche.state().raised==2,"the pedestal rises"):quit(1);return
 if not await walk(scene,[[2760,-3900],[2730,-3888]],"the raised pedestal"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point(niche.SHARD),Vector3.UP)
 if not check(scene.act2_items.take(niche.SHARD),"the second green shard"):quit(1);return
 check(scene.carried_collected.count(niche.SHARD)==1 and scene.carried_collected.count("act2:L14_HT:post_shard")==1,"both shards carried")
 if not checkpoint(scene,"niche"):quit(1);return
 # 6. Back as the Lizard, up the two steps, Human through the hanging to the floating bowls; a shard in each; the passage opens.
 var bowls_route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_shard_bowls_approach.json"))
 if not await change_form(scene,2,"Lizard back from the niche"):quit(1);return
 if not await walk(scene,bowls_route.low.slice(0,11),"niche low corridor return"):quit(1);return
 if not check(scene.request_jump(),"jump onto the first step"):quit(1);return
 if not await walk(scene,[[2912,-3685]],"first step"):quit(1);return
 if not check(scene.request_jump(),"jump onto the second step"):quit(1);return
 if not await walk(scene,bowls_route.low.slice(13),"upper corridor to the ritual room"):quit(1);return
 if not await change_form(scene,0,"Human in the ritual room"):quit(1);return
 if not await walk(scene,bowls_route.west,"the shard trays past the hanging"):quit(1);return
 var bowls=scene.get_node("L14ShardBowls")
 scene.camera.look_at(bowls.BOWLS["406"],Vector3.UP)
 if not check(bowls.offer("406",bowls.SHARDS[1]).ok,"a shard in the first bowl"):quit(1);return
 if not await walk(scene,[[1235,-3455],[1235,-3310]],"the other bowl"):quit(1);return
 scene.camera.look_at(bowls.BOWLS["405"],Vector3.UP)
 if not check(bowls.offer("405",bowls.SHARDS[0]).ok,"a shard in the second bowl"):quit(1);return
 for i in 160:await physics_frame
 if not check(bowls.state().opened==2,"the passage behind the bowls opens"):quit(1);return
 if not await walk(scene,[[1235,-3453],[1160,-3453],[1125,-3453],[1075,-3453],[1015,-3453],[940,-3453]],"behind the bowls"):quit(1);return
 if not checkpoint(scene,"bowls"):quit(1);return
 # 7. The Dreamstone in the slot raises the spiral; retrieve it; up the spiral and over the bridge to the three doors.
 var spiral=scene.get_node("L14Spiral")
 var spiral_route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_spiral_walk.json"))
 var stone:=""
 for id in scene.carried_collected:
  if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==136:stone=id;break
 if not check(not stone.is_empty(),"the Dreamstone is still carried"):quit(1);return
 if not await walk(scene,spiral_route.approach,"the Dreamstone slot"):quit(1);return
 scene.camera.look_at(spiral.POINT,Vector3.UP)
 if not check(spiral.interact("insert",stone).ok,"the Dreamstone in the slot"):quit(1);return
 for i in 60:await physics_frame
 scene.camera.look_at(spiral.POINT,Vector3.UP)
 if not check(spiral.interact("retrieve").ok,"take the Dreamstone back"):quit(1);return
 for i in 300:await physics_frame
 if not check(spiral.state().raised==4 and stone in scene.carried_collected,"the spiral stair is up and the stone is carried"):quit(1);return
 if not checkpoint(scene,"spiral_slot"):quit(1);return
 if not await walk(scene,spiral_route.entry,"the outer spiral room"):quit(1);return
 if not await walk(scene,spiral_route.spiral,"up the spiral"):quit(1);return
 if not check(scene.player.is_on_floor() and scene.player.position.y>225,"the spiral top"):quit(1);return
 if not await walk(scene,spiral_route.bridge,"over the bridge to the three doors"):quit(1);return
 check(scene.player.is_on_floor() and scene.player.position.y>215,"the three-door room floor")
 if not checkpoint(scene,"three_doors"):quit(1);return
 check(scene._quicksave_unrecorded(OUT+"b_save.json").is_empty(),"part B output save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L14 chain part B in one sitting: lower return -> bedroom -> headboard/crack -> library buttons/exit -> niche statue + second shard -> two bowls -> Dreamstone slot/spiral -> bridge to the three doors; %d stops saved and reloaded to the same state"%stops.size())
 quit(0 if failures==0 else 1)
