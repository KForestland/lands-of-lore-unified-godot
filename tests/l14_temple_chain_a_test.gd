extends "res://tests/l12_logs_approach_earned_test.gd"
## BJ08 (lead 2026-11-08): the Huline Temple main chain walked like a player in sittings. Part A: the native L14 arrival
## (from the L8 temple door with the Dreamstone; the earned STORY-049 arrival save) -> the main doors -> the priest's body on
## the slab -> aloe and poison from the pews -> the ritual bowls, the floor sinks, Spark on the body -> the green shard in the
## wooden post -> the left wall hanging -> the spider corridor -> the Lizard crawl under the sunken floor -> the flute in the
## coffin -> the grinder and the statue (hint book ch. 12 p.131-136). Every stop is a quicksave + reload + re-save (same state
## up to float print noise), the position and inventory persist, no fall recovery, no seeds. The per-step earned tests remain
## the qualification of each mechanism; this walk proves the chain holds in one sitting. Output: tmp/l14_chain_a_save.json.
const OUT:="res://tmp/l14_chain_"
var stops:Array[String]=[]
## 5bcd609 (2026-11-14): a successful load releases the half-second cast lock by design (game_session finish_load), so
## the re-save holds cooldown 0. Compare with that one documented release applied; every other value must match.
func released(save:Variant)->Variant:
 if save is Dictionary and save.get("quests") is Dictionary and save.quests.get("player_magic_reward_state") is Dictionary:
  save.quests.player_magic_reward_state.cooldown=0.0
 return save
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for k in a:
   if not b.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return is_equal_approx(float(a),float(b))
 return a==b
func checkpoint(scene:Node,name:String)->bool:
 var path:=OUT+name+"_save.json"
 var pos:Vector3=scene.player.position
 var carried:Array=scene.carried_collected.duplicate()
 if not check(scene._quicksave_unrecorded(path).is_empty(),"quicksave at "+name):return false
 var first:=FileAccess.get_file_as_string(path)
 if not check(scene._quickload_unrecorded(path).is_empty(),"reload at "+name):return false
 var again:=OUT+name+"_again_save.json"
 if not check(scene._quicksave_unrecorded(again).is_empty(),"second quicksave at "+name):return false
 check(same(released(JSON.parse_string(first)),JSON.parse_string(FileAccess.get_file_as_string(again))),"save -> load -> save stable at "+name)
 var persisted:bool=check(scene.player.position.distance_to(pos)<0.1 and scene.carried_collected==carried,"position and inventory persist at "+name)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall recovery or seeds up to "+name)
 stops.append(name)
 print("STOP ",name," at ",scene.player.position," form ",scene.player_form)
 return persisted
## G at a low passage: the form change the Dreamstone allows (l14_lower_passage.gd), then the curse clock runs it.
func change_form(scene:Node,form:int,label:String)->bool:
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"form choice "+label):return false
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==form:break
 return check(scene.player_form==form,"form %d reached: %s"%[form,label])
func crawl(scene:Node,points:Array,label:String)->bool:
 for point in points:
  var reached:=false
  for i in 1600:
   scene.curse.advance(1.0/60)
   var d:Vector3=Vector3(point[0],scene.player.position.y,point[1])-scene.player.position
   if d.length()<3 and scene.player.is_on_floor():reached=true;break
   scene.move_grounded(d.normalized(),1.0/60);await physics_frame
  if not check(reached,label+" crawl to "+str(point)+" at "+str(scene.player.position)):return false
 return true
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_temple_arrival_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="761850f60b460772b31566ff0eb4201caba6e3d6d120ccc590bc64addb317c2f","qualified Temple arrival (STORY-049)"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple arrival"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 check(scene.carried_collected.count("act2:L13_RC:dreamstone")==1,"the Dreamstone arrives with the player")
 if not checkpoint(scene,"arrival"):quit(1);return
 # 1. The main doors open on the earned receipt; the upper ritual chamber.
 var doors=scene.get_node("L14TempleDoors")
 check(not doors.gate.visible and doors.gate.get_node("Collision").collision_layer==0,"the main doors stand open")
 var entry:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_entry_walk.json"))
 if not await walk(scene,entry,"original main doors"):quit(1);return
 if not check(scene.player.position.y>30,"upper ritual chamber floor"):quit(1);return
 if not checkpoint(scene,"inside"):quit(1);return
 # 2. The priest's body from the entrance to the stone rectangle.
 var body=scene.get_node("L14PriestBody")
 var approach:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_priest_approach.json"))
 if not await walk(scene,approach,"upper entrance priest"):quit(1);return
 scene.camera.look_at(body.START+Vector3.UP*7,Vector3.UP)
 if not check(body.interact("carry").ok,"carry the priest's body"):quit(1);return
 # The original's carry stays on the floor-0 way over the lower stair layer (entrance 955 954 786 785 848 846 860 858
 # 859 to 856 beside the rectangle; grok_research/L14_SLAB_TO_PEW_STEP_20261113.md, longplay g_00247/g_00251).
 var carry:Array=[[2416,-2948],[2413,-3018],[2409,-3048],[2292,-3134],[2226,-3256],[2199,-3316],[2179,-3400],[2206,-3401],[2242,-3401],[2325,-3364],[2370,-3328]]
 if not await walk(scene,carry,"carry to the slab on the floor-0 way"):quit(1);return
 scene.camera.look_at(body.SLAB,Vector3.UP)
 if not check(body.interact("place").ok,"the body on the stone rectangle"):quit(1);return
 if not checkpoint(scene,"priest_slab"):quit(1);return
 # 3. Aloe and poison from the pews to the north (floor-0 way 812 816 814 821 818 820 819 21 22 23 24 1056 1058).
 var pews:Array=[[2394,-3327],[2433,-3327],[2513,-3362],[2605,-3398],[2664,-3414],[2827,-3374],[2907,-3466],[2997,-3540],[3089,-3681],[3093,-3863],[3013,-3828],[3000,-3900],[3000,-4050],[3000,-4300],[2950,-4550]]
 if not await walk(scene,pews,"east then north pew room"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point("act2:L14_HT:item68"),Vector3.UP)
 if not check(scene.act2_items.take("act2:L14_HT:item68"),"take the aloe"):quit(1);return
 if not await walk(scene,[[3070,-4550]],"poison supply"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point("act2:L14_HT:item72"),Vector3.UP)
 if not check(scene.act2_items.take("act2:L14_HT:item72"),"take the poison"):quit(1);return
 var back:Array=pews.duplicate();back.reverse();back.append([2370,-3328])
 if not await walk(scene,back,"return supplies to the priest"):quit(1);return
 if not checkpoint(scene,"supplies"):quit(1);return
 # 4. Aloe west, poison east; the floor sinks; Spark on the body.
 var ritual=scene.get_node("L14PriestRitual")
 if not await walk(scene,[[2300,-3450],[2375,-3605]],"west ritual bowl"):quit(1);return
 scene.camera.look_at(ritual.BOWLS["370"],Vector3.UP)
 if not check(ritual.offer("370","act2:L14_HT:item68").ok,"aloe in the western bowl"):quit(1);return
 if not await walk(scene,[[2441,-3605]],"east ritual bowl"):quit(1);return
 scene.camera.look_at(ritual.BOWLS["369"],Vector3.UP)
 if not check(ritual.offer("369","act2:L14_HT:item72").ok,"poison in the eastern bowl"):quit(1);return
 for i in 240:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if ritual.state().lowered>=2:break
 if not check(ritual.state().lowered==2,"the floor around the rectangle sinks"):quit(1);return
 if not await walk(scene,[[2500,-3480],[2480,-3328]],"return to the priest slab"):quit(1);return
 scene.camera.look_at(ritual.SPARK,Vector3.UP)
 for i in 180:
  await physics_frame
  if scene.starting_magic.magic_state().cooldown<=0:break
 scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast(),"Spark at the body"):quit(1);return
 await physics_frame
 if not check(ritual.state().vanished,"the body disappears"):quit(1);return
 if not checkpoint(scene,"ritual"):quit(1);return
 # 5. The green shard in the wooden post, north past the pews.
 var shard=scene.get_node("L14PostShard")
 var north:Array=[[2394,-3327],[2433,-3327],[2513,-3362],[2605,-3398],[2664,-3414],[2827,-3374],[2907,-3466],[2997,-3540],[3089,-3681],[3093,-3863],[3013,-3828],[3000,-3900],[3000,-4050],[3000,-4300],[3043,-4550],[3043,-4750],[3043,-4950],[3043,-5150],[3043,-5400],[3043,-5600]]
 if not await walk(scene,north,"north of the pews to the post"):quit(1);return
 scene.camera.look_at(shard.POINT,Vector3.UP)
 if not check(shard.take().ok,"the shard from the post"):quit(1);return
 if not checkpoint(scene,"post_shard"):quit(1);return
 # 6. Back to the ritual room: the left wall hanging hides a passage.
 var south:Array=north.duplicate();south.reverse()
 if not await walk(scene,south,"back to the ritual room"):quit(1);return
 var hanging=scene.get_node("L14Hanging")
 if not await walk(scene,[[2400,-3450],[2400,-3550],[2350,-3610],[2315,-3660]],"left hanging approach"):quit(1);return
 scene.camera.look_at(hanging.POINT,Vector3.UP)
 if not check(hanging.interact().ok,"open the left hanging"):quit(1);return
 if not await walk(scene,[[2220,-3750],[2170,-3800]],"through the hanging"):quit(1);return
 if not checkpoint(scene,"hanging"):quit(1);return
 # 7. The spiders come (combat while walking the corridor).
 var corridor:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_hanging_spider.json"))
 if not await walk(scene,corridor,"spider corridor"):quit(1);return
 check(scene.act2_creatures.state.actors["68"].health==0,"the corridor spider is dead")
 if not checkpoint(scene,"spider"):quit(1);return
 # 8. Under the sunken ritual floor as the Lizard, the flute in the coffin as the Human.
 var flute_approach:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_flute_approach.json"))
 if not await walk(scene,flute_approach,"return to the lowered ritual floor"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 for i in 3:await process_frame
 check(passage.hint.text.begins_with("G — Change to Lizard"),"the low-passage prompt shows: '"+passage.hint.text+"'")
 if not await change_form(scene,2,"Lizard for the low passage"):quit(1);return
 if not await crawl(scene,[[2302,-3320],[2304,-3272],[2290,-3200],[2222,-3046]],"lower corridor"):quit(1);return
 if not check(scene.player.position.y< -40,"the lower floor under the ritual room"):quit(1);return
 if not await change_form(scene,0,"Human in the lower corridor"):quit(1);return
 var flute_walk:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_flute_walk.json"))
 if not await walk(scene,flute_walk,"the coffin flute"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point("act2:L14_HT:item77"),Vector3.UP)
 if not check(scene.act2_items.take("act2:L14_HT:item77"),"take the Temple flute"):quit(1);return
 if not checkpoint(scene,"flute"):quit(1);return
 # 9. The grinder: the body to the belt, the box of red goo into the second machine, the statue at its back.
 var machine=scene.get_node("L14Machines")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_machines_walk.json"))
 if not await walk(scene,route.table,"the examining table"):quit(1);return
 scene.camera.look_at(machine.BUTTON,Vector3.UP)
 if not check(machine.interact("start").ok,"press the pedestal button"):quit(1);return
 for i in 150:await physics_frame
 if not check(machine.state().phase=="ready","the grinder fills the trough"):quit(1);return
 if not await walk(scene,route.box,"the blood trough"):quit(1);return
 scene.camera.look_at(machine.BOX+Vector3.UP*12,Vector3.UP)
 if not check(machine.interact("carry").ok,"carry the trough"):quit(1);return
 if not checkpoint(scene,"trough"):quit(1);return
 if not await walk(scene,route.machine,"the second machine"):quit(1);return
 if not await walk(scene,[[3240,-3615]],"machine aperture"):quit(1);return
 scene.camera.look_at(machine.INSERT,Vector3.UP)
 if not check(machine.interact("rotate").ok,"turn the trough long edge first"):quit(1);return
 if not check(machine.interact("insert").ok,"the trough goes in"):quit(1);return
 if not await walk(scene,route.catch,"around to the machine output"):quit(1);return
 if not await change_form(scene,2,"Lizard at the low output"):quit(1);return
 for i in 1200:
  await physics_frame
  if machine.state().phase=="formed":break
 if not check(machine.state().phase=="formed","the statue appears at the back"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point(machine.STATUE),Vector3.UP)
 if not check(scene.act2_items.take(machine.STATUE),"catch the statue"):quit(1);return
 if not await change_form(scene,0,"Human after the catch"):quit(1);return
 check(scene.carried_collected.count(machine.STATUE)==1 and scene.carried_collected.count("act2:L14_HT:item77")==1 and scene.carried_collected.count("act2:L14_HT:post_shard")==1,"statue, flute and shard carried once")
 if not checkpoint(scene,"machine_statue"):quit(1);return
 check(scene._quicksave_unrecorded(OUT+"a_save.json").is_empty(),"part A output save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L14 chain part A in one sitting: arrival -> doors -> priest slab -> aloe/poison -> ritual floor + Spark -> post shard -> hanging -> spiders -> Lizard crawl -> flute -> grinder statue; %d stops saved and reloaded to the same state"%stops.size())
 quit(0 if failures==0 else 1)
