extends "res://tests/l14_ledge_maze_earned_test.gd"
## BJ08 part C (hint book ch. 12 p.137-141): from part B's output in the three-door room -> the left door, the raised ledge
## maze and its idol, back -> the middle door, the tilting floor's four high buttons, the second idol, back -> the right door,
## the three fire paths, the lowered bridge, the third idol, back -> the exit behind the doors: the flute in the angled slot
## covers the oil, the blade bypass, the boulder hall off-centre -> the three pedestals raise the stairs -> the hopper gallery
## without stepping on the platform, five hoppers, their bodies on the platform, the ride down -> the faux Belial as the Beast
## -> the Chamber of Voices: the Dreamstone into the chalice, the CITY movie -> the native L16 arrival (STORY-066). Every stop
## is a quicksave + reload + re-save. Output: tmp/l14_chain_c_save.json and tmp/l14_chain_l16_arrival_save.json.
const OUT:="res://tmp/l14_chain_"
var stops:Array[String]=[]
var observed:Node
var stepped:bool=false
func combat_tick_budget()->int:return 18000
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
func ride_high(scene:Node)->bool:
 for i in 2400:
  scene.move_grounded(Vector3.ZERO,1.0/60);scene.curse.advance(1.0/60);await physics_frame
  if scene.player.is_on_floor() and scene.player.position.y>360:return true
 return check(false,"high-side ride at "+str(scene.player.position))
func watch_platform():
 if not is_instance_valid(observed):return
 var p:Vector3=observed.player.position
 if p.x>=-35 and p.x<=115 and p.z>=5814 and p.z<=6026 and p.y-32>=295:stepped=true
func key(code:Key)->void:
 var e:=InputEventKey.new();e.keycode=code;e.pressed=true
 Input.parse_input_event(e);Input.flush_buffered_events()
 await process_frame
 e=InputEventKey.new();e.keycode=code;e.pressed=false
 Input.parse_input_event(e);Input.flush_buffered_events()
 await process_frame
func await_level(area:String)->Node:
 for i in 3000:
  await process_frame
  var next:Variant=current_scene
  if next!=null and is_instance_valid(next) and str(next.get("area_id"))==area:
   for j in 1500:
    await process_frame
    if not is_instance_valid(next) or next.ready_for_review:break
   return next
 return null
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input=Save.read_save(OUT+"b_save.json","lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),"part B output: "+str(input.error)):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"part B state"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var trials=scene.get_node("L14Trials")
 # 1. The left door: the raised ledge maze, the first idol, and back.
 var maze:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_ledge_maze_walk.json"))
 if not await walk(scene,[[300,-2250],[340,-2185]],"the left door"):quit(1);return
 scene.camera.look_at(trials.DOORS["90"],Vector3.UP)
 if not check(trials.open_door("90").ok,"open the left door"):quit(1);return
 await physics_frame
 if not await walk(scene,[[400,-2090],[500,-1960]],"through the left door"):quit(1);return
 if not await walk(scene,maze.entry,"the maze entrance"):quit(1);return
 for hop in maze.ledges:
  if hop.has("jump"):
   if not await jump_gap(scene,hop):quit(1);return
  elif not await walk(scene,[hop.point],"the raised ledges"):quit(1);return
  if not check(scene.player.position.y>110 and scene.resets==0,"on the raised route"):quit(1);return
 if not await walk(scene,maze.exit,"the maze exit hall"):quit(1);return
 scene.camera.look_at(trials.PRIZE,Vector3.UP)
 if not check(trials.take().ok,"the first idol"):quit(1);return
 if not checkpoint(scene,"maze_idol"):quit(1);return
 var back_exit:Array=maze.exit.duplicate();back_exit.reverse()
 if not await walk(scene,back_exit,"back from the idol hall"):quit(1);return
 var back_ledges:Array=maze.ledges.duplicate(true);back_ledges.reverse()
 for hop in back_ledges:
  if hop.has("jump"):
   var back:Dictionary=hop.duplicate(true)
   back.jump.reverse();back.centres.reverse();back.from=hop.to;back.to=hop.from;back.landing_floor=float(hop.landing_floor)-float(hop.height)
   if not await jump_gap(scene,back):quit(1);return
  elif not await walk(scene,[hop.point],"the raised ledges back"):quit(1);return
 var back_entry:Array=maze.entry.duplicate();back_entry.reverse()
 if not await walk(scene,back_entry,"the maze entrance back"):quit(1);return
 if not await walk(scene,[[500,-1960],[430,-2080],[360,-2160],[36,-2230]],"back through the left door"):quit(1);return
 if not checkpoint(scene,"maze_return"):quit(1);return
 # 2. The middle door: the tilting floor, four high buttons, the far passage, the second idol, and back.
 var tilt=scene.get_node("L14Tilt")
 if not await walk(scene,[[32,-2170]],"the middle door"):quit(1);return
 scene.camera.look_at(trials.DOORS["89"],Vector3.UP)
 if not check(trials.open_door("89").ok,"open the middle door"):quit(1);return
 if not await walk(scene,[[32,-2000],[32,-1600],[32,-1450],[140,-1320],[300,-1230],[360,-1100]],"onto the right tilting floor"):quit(1);return
 if not await ride_high(scene):quit(1);return
 if not await walk(scene,[[360,-944]],"right near high button"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["145"],Vector3.UP)
 if not check(tilt.press("145").ok,"the first high button"):quit(1);return
 if not await walk(scene,[[360,356]],"right far high button"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["144"],Vector3.UP)
 if not check(tilt.press("144").ok,"the second high button"):quit(1);return
 if not await walk(scene,[[-330,327]],"across to the left floor"):quit(1);return
 if not await ride_high(scene):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["143"],Vector3.UP)
 if not check(tilt.press("143").ok,"the third high button"):quit(1);return
 if not await walk(scene,[[-330,-973]],"left near high button"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["142"],Vector3.UP)
 if not check(tilt.press("142").ok,"the fourth high button"):quit(1);return
 for i in 180:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not check(tilt.state().settled==2,"the floors level and the far passage opens"):quit(1);return
 if not await walk(scene,[[0,-973],[0,612],[0,900],[0,1100],[0,1250],[0,1400]],"the far passage"):quit(1);return
 var tilt_route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_tilt_walk.json"))
 if not await walk(scene,tilt_route.prize,"the middle statue"):quit(1);return
 scene.camera.look_at(trials.PRIZES["372"],Vector3.UP)
 if not check(trials.take(64,"372").ok,"the second idol"):quit(1);return
 if not checkpoint(scene,"tilt_idol"):quit(1);return
 var prize_back:Array=tilt_route.prize.duplicate();prize_back.reverse()
 if not await walk(scene,prize_back,"back from the middle idol"):quit(1);return
 if not await walk(scene,[[0,1250],[0,1100],[0,900],[0,612],[200,300],[200,-1000],[200,-1190],[140,-1320],[32,-1450],[32,-1600],[32,-2000],[32,-2170],[36,-2230]],"the leveled floors and the middle door back"):quit(1);return
 if not checkpoint(scene,"tilt_return"):quit(1);return
 # 3. The right door: three fire paths, three buttons, the bridge lowers, the gate, the third idol, and back.
 var fire=scene.get_node("L14FirePaths")
 var fire_route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_fire_paths_walk.json"))
 if not await walk(scene,[[-250,-2230],[-270,-2180]],"the right door"):quit(1);return
 scene.camera.look_at(trials.DOORS["88"],Vector3.UP)
 if not check(trials.open_door("88").ok,"open the right door"):quit(1);return
 if not await walk(scene,[[-350,-2050],[-600,-1790]],"through the right door"):quit(1);return
 for pair in [["3962","60"],["3921","61"],["3943","62"]]:
  if not await walk(scene,fire_route[pair[0]],"fire path "+pair[1]):quit(1);return
  scene.camera.look_at(fire.BUTTONS[pair[1]],Vector3.UP)
  if not check(fire.press(pair[1]).ok,"fire path button "+pair[1]):quit(1);return
 for i in 360:await physics_frame
 if not await walk(scene,fire_route["4010"],"the near bridge landing"):quit(1);return
 if not check(scene.request_jump(),"jump onto the bridge"):quit(1);return
 if not await walk(scene,[[-1697,-1970],[-1697,-2120],[-1697,-2220],[-1697,-2390]],"across the lowered bridge"):quit(1);return
 if not check(scene.request_jump(),"jump to the far landing"):quit(1);return
 if not await walk(scene,[[-1700,-2470]],"the far landing"):quit(1);return
 for i in 150:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not check(fire.state().gate==2,"the far gate opens"):quit(1);return
 if not await walk(scene,fire_route["4103"],"the third idol's hall"):quit(1);return
 scene.camera.look_at(trials.PRIZES["384"],Vector3.UP)
 if not check(trials.take(64,"384").ok,"the third idol"):quit(1);return
 if not checkpoint(scene,"fire_idol"):quit(1);return
 var hall_back:Array=fire_route["4103"].duplicate();hall_back.reverse()
 if not await walk(scene,hall_back,"back through the gate"):quit(1);return
 if not await walk(scene,[[-1700,-2470]],"far landing back"):quit(1);return
 if not check(scene.request_jump(),"return jump to the bridge"):quit(1);return
 if not await walk(scene,[[-1697,-2390],[-1697,-2220],[-1697,-2120],[-1697,-1940]],"the bridge back"):quit(1);return
 if not check(scene.request_jump(),"return jump to the near landing"):quit(1);return
 if not await walk(scene,[[-1697,-1875]],"near landing back"):quit(1);return
 for k in ["4010","3943","3921","3962"]:
  var r:Array=fire_route[k].duplicate();r.reverse()
  if not await walk(scene,r,"fire path back "+k):quit(1);return
 if not await walk(scene,[[-600,-1790],[-350,-2050],[-270,-2180],[-250,-2230],[36,-2230]],"the right door back"):quit(1);return
 for id in ["371","372","384"]:check(("act2:L14_HT:trial_idol"+id) in scene.carried_collected,"three idols carried")
 if not checkpoint(scene,"three_idols"):quit(1);return
 # 4. The exit behind the doors: the Temple flute in the angled slot covers the oil; the blade bypass; the boulder hall off-centre.
 if not await walk(scene,[[32,-2170],[32,-2000],[-110,-1900],[-110,-1750],[-115,-1660],[-110,-1570]],"the lower exit beside the slot"):quit(1);return
 var slot=scene.get_node("L14FluteSlot")
 var temple_flute:=""
 for id in scene.carried_collected:
  if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==96:temple_flute=id
 if not check(not temple_flute.is_empty(),"the Temple flute is carried"):quit(1);return
 scene.camera.look_at(slot.POINT,Vector3.UP)
 if not check(slot.interact("insert",temple_flute).ok,"the flute in the angled slot"):quit(1);return
 for i in 180:await physics_frame
 if not check(slot.state().covered==2,"both oil covers closed"):quit(1);return
 scene.camera.look_at(slot.POINT,Vector3.UP)
 if not check(slot.interact("retrieve").ok,"take the flute back"):quit(1);return
 if not checkpoint(scene,"flute_slot"):quit(1);return
 var trap=scene.get_node("L14TrapRoute")
 if not await walk(scene,[[-115,-1660],[-110,-1750],[32,-1800],[170,-1750],[170,-1650],[155,-1540],[145,-1470],[30,-1420],[30,-1360],[30,-1000],[30,-700],[30,-414]],"over the covered oil"):quit(1);return
 scene.camera.look_at(trap.DOORS["81"],Vector3.UP)
 if not check(trap.open_door("81").ok,"the bypass entrance"):quit(1);return
 if not await walk(scene,[[-160,-414],[-290,-280],[-290,400],[-240,576],[-110,580]],"the blade bypass"):quit(1);return
 scene.camera.look_at(trap.DOORS["80"],Vector3.UP)
 if not check(trap.open_door("80").ok,"the bypass exit"):quit(1);return
 if not await walk(scene,[[0,650]],"the lower hall again"):quit(1);return
 if not checkpoint(scene,"blade_bypass"):quit(1);return
 if not await walk(scene,[[-32,850],[-33,1000],[-33,1100],[-33,1250],[-30,1400]],"the boulder hall, off-centre"):quit(1);return
 check(not trap.state().triggered and scene.starting_magic.health()>0,"the boulder stays put on the side strip")
 if not checkpoint(scene,"boulder_side"):quit(1);return
 # 5. The three pedestals raise the stairs.
 var idol_route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_idol_room_walk.json"))
 if not await walk(scene,idol_route,"to the three pedestals"):quit(1);return
 var ped=scene.get_node("L14IdolPedestals")
 for step in [["87",[-100,3505],ped.IDOLS[2]],["85",[110,3510],ped.IDOLS[0]],["86",[19,3590],ped.IDOLS[1]]]:
  if not await walk(scene,[step[1]],"pedestal "+step[0]):quit(1);return
  scene.camera.look_at(ped.CASES[step[0]],Vector3.UP)
  if not check(ped.offer(step[0],step[2]).ok,"an idol on pedestal "+step[0]):quit(1);return
 for i in 360:await physics_frame
 if not check(ped.state().assembled==4,"the stairs assemble"):quit(1);return
 if not await walk(scene,[[32,3730],[32,3789],[32,3850],[32,3918],[32,3979],[32,4042],[32,4096],[32,4151],[32,4208],[32,4260]],"up the assembled stairs"):quit(1);return
 if not checkpoint(scene,"pedestals"):quit(1);return
 # 6. The hopper gallery: along the side ledge without stepping on the platform; five hoppers; bodies on the platform; the ride down.
 var hopper_route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_hopper_platform_walk.json"))
 if not await walk(scene,hopper_route,"the corridor to the wooden platform"):quit(1);return
 observed=scene;physics_frame.connect(watch_platform)
 if not await walk(scene,[[-47,5770]],"side-ledge approach"):quit(1);return
 if not check(scene.request_jump(),"jump onto the side ledge"):quit(1);return
 if not await walk(scene,[[-47,5890],[-47,5935]],"the side ledge"):quit(1);return
 if not check(scene.request_jump(),"jump off the ledge to the far landing"):quit(1);return
 if not await walk(scene,[[-30,6070],[40,6150],[40,6320],[40,6600],[40,6650]],"the hopper gallery"):quit(1);return
 check(not stepped,"never stood on the pressure platform")
 if not checkpoint(scene,"hopper_gallery"):quit(1);return
 var puzzle=scene.get_node("L14HopperPlatform");var pop=scene.act2_creatures
 var all_dead:=false
 for i in 3600:
  if not await fight_nearby(scene):quit(1);return
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  all_dead=true
  for id in puzzle.IDS:
   if pop.state.actors[id].health>0:all_dead=false
  if all_dead:break
 if not check(all_dead,"the five hoppers are dead"):quit(1);return
 for i in 180:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 for id in puzzle.IDS:
  scene.camera.look_at(pop.bodies[id].global_position+Vector3.UP*8,Vector3.UP)
  if not check(puzzle.take(id).ok,"pick up hopper body "+id):quit(1);return
 if not checkpoint(scene,"hopper_bodies"):quit(1);return
 if not await walk(scene,[[40,6320],[40,6150],[-30,6070]],"back along the gallery"):quit(1);return
 if not check(scene.request_jump(),"jump back onto the side ledge"):quit(1);return
 if not await walk(scene,[[-47,5935]],"side ledge beside the platform"):quit(1);return
 for id in puzzle.IDS:
  scene.camera.look_at(puzzle.POINT,Vector3.UP)
  if not check(puzzle.place(puzzle.item(id)).ok,"body "+id+" on the platform"):quit(1);return
 if not await walk(scene,[[5,5920]],"step onto the loaded platform"):quit(1);return
 for i in 360:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not check(puzzle.state().lowered==4 and scene.player.is_on_floor() and absf(scene.player.position.y+38)<2,"the platform rides down"):quit(1);return
 if not checkpoint(scene,"platform_down"):quit(1);return
 # 7. The faux Belial: E descends, E confronts, G to the Beast, melee.
 var belial=scene.get_node("L14Belial")
 if not await walk(scene,[[25,5920]],"the elevator trigger"):quit(1);return
 for i in 3:await process_frame
 if not check(belial.hint.text=="E — Descend to the Chamber of Voices","the descent prompt shows: '"+belial.hint.text+"'"):quit(1);return
 await key(KEY_E)
 if not check(belial.state().entered and scene.player.position.distance_to(belial.ARRIVAL)<2.0,"actual E descends to the chamber"):quit(1);return
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not await walk(scene,[[42,11110],[42,11200],[42,11220],[42,11290]],"the boss approach"):quit(1);return
 for i in 3:await process_frame
 check(belial.hint.text.begins_with("G — Change form"),"the Belial prompt shows: '"+belial.hint.text+"'")
 if not check(belial.talk(),"the confrontation"):quit(1);return
 if not check(belial.choose_form(),"Beast choice"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==1:break
 if not check(scene.player_form==1,"the Beast"):quit(1);return
 for i in 2400:
  if pop.state.actors["90"].health<=0:break
  if not check(scene.starting_magic.health()>0,"the Beast survives"):quit(1);return
  scene.camera.look_at(pop.bodies["90"].position+Vector3.UP*24,Vector3.UP)
  pop.strike();scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 if not check(pop.state.actors["90"].health==0,"the faux Belial falls"):quit(1);return
 if not checkpoint(scene,"belial"):quit(1);return
 # 8. The Chamber of Voices: E at the doors, the voices, the chalice takes the Dreamstone, the CITY movie, L16.
 var chv=scene.get_node("L14ChamberVoices")
 if not check(chv.carried_dreamstone()==chv.DREAMSTONE,"the Dreamstone is carried to the chamber"):quit(1);return
 if not await walk(scene,[[400,11000],[600,10850]],"the chamber doors"):quit(1);return
 scene.camera.look_at(chv.DOORS[0],Vector3.UP)
 for i in 3:await process_frame
 if not check(chv.door_in_reach() and chv.hint.text=="E — Enter the Chamber of Voices","the chamber door prompt: '"+chv.hint.text+"'"):quit(1);return
 await key(KEY_E)
 if not check(chv.inside and chv.phase=="voices" and paused,"E opens the Chamber of Voices"):quit(1);return
 check(scene._quicksave_unrecorded(OUT+"during_voices_save.json")=="Close the current overlay before saving.","F5 inside the chamber is refused with the overlay message")
 await key(KEY_SPACE)
 if not check(chv.phase=="idle","the voices end"):quit(1);return
 # E offers the Dreamstone (the chalice click needs a sized viewport; l14_chamber_voices_earned_test covers it rendered).
 await key(KEY_E)
 if not check(chv.state().offered and chv.phase=="city" and chv.carried_dreamstone().is_empty(),"E offers the Dreamstone to the chalice and CITY plays"):quit(1);return
 var before:int=scene.progression.level_changes.size()
 scene.progression.change_scene_enabled=true
 await key(KEY_SPACE)
 var next:Node=await await_level("L16_CA")
 if not check(next!=null,"the native L16 arrival after the CITY movie"):quit(1);return
 scene=next;prepare(scene)
 check(scene.start_selector==1 and scene.player.position.distance_to(Vector3(-3860,scene.player.position.y,-1341))<2.0,"L16 arrival 1 at native (-3860,1341): %s"%scene.player.position)
 check(not ("act2:L13_RC:dreamstone" in scene.carried_collected) and scene.quest_state.get("l14_chamber_voices",{}).get("offered",false),"the Dreamstone stays consumed in the city")
 if not checkpoint(scene,"l16_arrival"):quit(1);return
 scene.queue_free();await process_frame
 if failures==0:print("PASS L14 chain part C in one sitting: three trials and idols -> flute slot/blades/boulder -> pedestals -> hoppers and the platform -> faux Belial as the Beast -> Chamber of Voices chalice -> CITY -> native L16 arrival; %d stops saved and reloaded to the same state"%stops.size())
 quit(0 if failures==0 else 1)
