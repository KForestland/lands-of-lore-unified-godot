extends SceneTree
## Local prompt acceptance from unchanged pinned checkpoints. Full scene physics;
## input events only after loading: no position/health writes or production action calls.
const Save=preload("res://scripts/lol2/act2_save.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const SCENES={"lol2-restoration-map-L10_DC":"res://scenes/lol2/maps/L10_DC.tscn","lol2-restoration-dragon-preview":"res://scenes/lol2/dragon_level.tscn"}
var scene:Node
var failed:=false
var proof:={"scope":"Local real-input prompt/interaction walk from pinned checkpoint, not upstream campaign acceptance","teleports":0,"resource_writes":0,"direct_action_calls":0,"clock_acceleration":4,"resets":0,"live_samples":0,"events":[]}
func scenario()->String:return "globe"
func _initialize():run.call_deferred()
func check(ok:bool,message:String)->bool:
 if not ok:
  failed=true;push_error(message);proof["failure"]=message
  if is_instance_valid(scene):proof["failure_position"]=str(scene.player.position)
  write_proof();quit(1)
 return ok
func output()->String:
 var path:=OS.get_environment("LOL2_PROMPT_PROOFS")
 return (path if not path.is_empty() else "user://tests/bj14_sol_proofs")+"/"+scenario()+"/"
func write_proof():
 DirAccess.make_dir_recursive_absolute(output())
 var f:=FileAccess.open(output()+"receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(proof,"  "));f.close()
func key(code:Key,down:bool):
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;e.ctrl_pressed=Input.is_physical_key_pressed(KEY_CTRL);e.shift_pressed=Input.is_physical_key_pressed(KEY_SHIFT)
 Input.parse_input_event(e);Input.flush_buffered_events()
func tap(code:Key):
 # Dispatch discrete events between physics ticks, as window input arrives.
 await process_frame
 var prior:int=scene.get_instance_id() if is_instance_valid(scene) else 0
 key(code,true);await process_frame;key(code,false)
 if code==KEY_F9:
  for i in 1800:
   await process_frame
   if is_instance_valid(current_scene) and current_scene.get_instance_id()!=prior and current_scene.get("ready_for_review")==true and current_scene.get("starting_magic")!=null:break
  scene=current_scene
 for i in 3:await physics_frame
func ticks(n:int):
 for i in n:await physics_frame
func click():
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=Vector2(640,360)
  Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func turn(point:Vector3,pitch:bool=true):
 var d:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-d.x,-d.z)
 var angle:=atan2(d.y,Vector2(d.x,d.z).length())
 var e:=InputEventMouseMotion.new();e.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(angle-scene.camera.rotation.x)/0.003 if pitch else 0.0)
 Input.parse_input_event(e);Input.flush_buffered_events()
func look(point:Vector3):
 key(KEY_W,false);key(KEY_SHIFT,false)
 for i in 4:turn(point);await process_frame
func live()->bool:
 proof.resets=maxi(int(proof.resets),int(scene.resets));proof.live_samples+=1
 return check(scene.resets==0 and scene.starting_magic.health()>0 and not scene.flying and scene.is_physics_processing(),"Live scene, no death/flight/fall recovery")
func load_input(name:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame
 preload("res://scripts/lol2/game_session.gd").for_tree(self).reset_legacy() # supplied old packet starts with a fresh native bank
 var rows:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bj14_sol_inputs.json"))
 var row:Dictionary=rows[name]
 var path:=OS.get_environment("LOL2_PROMPT_INPUTS").path_join(str(row.file))
 if not check(FileAccess.get_sha256(path)==row.sha256,"Pinned "+name+" checkpoint"):return false
 var saved:=Save.read_save(path,row.format)
 if not check(saved.error.is_empty(),saved.error):return false
 scene=load(SCENES[row.format]).instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1800:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.ready_for_review and scene.apply_save(saved.state).is_empty(),"Load pinned "+name):return false
 root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 await ticks(12)
 proof.events.append({"loaded":name,"sha256":row.sha256,"position":str(scene.player.position)})
 return check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Real window captures mouse") and live()
func route(file:String,key_name:String="")->Array:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+file))
 if key_name.is_empty():return data.points if data is Dictionary else data
 var found=data[key_name]
 return found.points if found is Dictionary else found
func heal():
 if scene.starting_magic.health()>=18:return
 key(KEY_W,false);key(KEY_SHIFT,false)
 await tap(KEY_2);await tap(KEY_Q);await ticks(45)
func nearby_enemy()->String:
 var pop=scene.act2_creatures
 var best:="";var distance:=80.0
 for id in pop.bodies:
  if scenario()=="shielded" and id=="79":continue
  if not pop.state.actors[id].present or pop.state.actors[id].health<=0 or pop.peaceful_actor(id):continue
  var d:float=scene.player.global_position.distance_to(pop.bodies[id].global_position)
  if d<distance:distance=d;best=id
 return best
func combat()->bool:
 for tick in 500:
  var id:=nearby_enemy()
  if id.is_empty():return true
  if not live():return false
  await heal()
  await look(scene.act2_creatures.bodies[id].global_position+Vector3.UP*24)
  await click();await ticks(12)
 return check(false,"Local real-input combat timeout")
func walk(points:Array,label:String,until:Callable=Callable())->bool:
 for index in points.size():
  var goal:=Vector3(points[index][0],0,points[index][1]);var reached:=false;var prior:Vector3=scene.player.position;var stuck:=0;var hops:=0
  var budget:=maxi(600,int(Vector2(prior.x-goal.x,prior.z-goal.z).length()*2)+600)
  for tick in budget:
   if current_scene!=scene:key(KEY_W,false);return true
   if until.is_valid() and until.call():key(KEY_W,false);return true
   if not live():return false
   if not nearby_enemy().is_empty() and not await combat():return false
   var d:Vector3=goal-scene.player.position;d.y=0
   if d.length()<7:reached=true;break
   turn(Vector3(goal.x,scene.camera.global_position.y,goal.z),false);key(KEY_W,true)
   await physics_frame
   stuck=stuck+1 if scene.player.position.distance_to(prior)<0.05 else 0;prior=scene.player.position
   if stuck==25 and hops<4:await tap(KEY_SPACE);hops+=1;stuck=0
   if stuck>150:break
  key(KEY_W,false)
  if not check(reached,label+" stalled at "+str(index)+" position "+str(scene.player.position)):return false
  if index%10==0:print("PROMPT WALK ",label," ",index," ",scene.player.position)
 return true
func shot(label:String,text:String):
 proof.events.append({"prompt":label,"text":text,"position":str(scene.player.position)})
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(output())
 root.get_texture().get_image().save_png(output()+label+".png")
func take(id:String)->bool:
 var owner=scene.act2_items
 var label:String=owner.pickup_label(id)
 await look(owner.aim_point(id));await ticks(4)
 if not check(owner.target()==id and owner.hint.text=="E — Take "+label,"Aimed named pickup prompt "+id):return false
 await shot("pickup_"+id.get_slice(":",2),owner.hint.text)
 await look(owner.aim_point(id)+Vector3.RIGHT*500);await ticks(4)
 if not check(owner.hint.text.is_empty(),"Looking away clears pickup prompt"):return false
 await look(owner.aim_point(id));await tap(KEY_I);await ticks(4)
 if not check(is_instance_valid(scene.inventory) and owner.hint.text.is_empty(),"Inventory hides world pickup prompt"):return false
 await tap(KEY_ESCAPE);await ticks(4)
 if not check(not is_instance_valid(scene.inventory) and owner.hint.text=="E — Take "+label,"Closing inventory restores aimed pickup prompt"):return false
 await tap(KEY_F5);await tap(KEY_E);await ticks(8)
 if not check(id in scene.carried_collected and not owner.sprites[id].visible,"Real E takes unique pickup"):return false
 await tap(KEY_F9);await ticks(8);owner=scene.act2_items
 if not check(id not in scene.carried_collected and owner.hint.text=="E — Take "+label,"F9 restores untaken pickup prompt"):return false
 await tap(KEY_E);await ticks(4);await tap(KEY_F5);await tap(KEY_F9);await ticks(6);owner=scene.act2_items
 return check(id in scene.carried_collected and not owner.available(id) and owner.hint.text.is_empty(),"Taken pickup stays hidden across real save/reload")
func globe()->bool:
 if not await load_input("gold"):return false
 if not await walk(route("l10_tomb_walk.json","pickup"),"gold44 approach"):return false
 if not await take("act2:L10_DC:item44"):return false
 return true
func two_empty()->bool:
 if not await load_input("globe"):return false
 if not await walk(route("l10_two_empty_walk.json","door"),"gold tomb91"):return false
 var tomb=scene.get_node("L10Tombs");await look(tomb.aims["91"]);await tap(KEY_E);await ticks(12)
 if not check(tomb.opened("91"),"Real E opens earned gold tomb"):return false
 if not await walk(route("l10_two_empty_walk.json","lid"),"globe56"):return false
 if not await take("act2:L10_DC:item56"):return false
 if not await walk(route("l10_two_empty_walk.json","free"),"globe8"):return false
 if not await take("act2:L10_DC:item8"):return false
 return true
func barrel_globes()->bool:
 if not await load_input("barrel"):return false
 if not await walk([[-1480,-3081]],"globe45"):return false
 if not await take("act2:L10_DC:item45"):return false
 if not await walk([[-1458,-3005]],"leave white tomb"):return false
 for part in ["caretaker","inside","globe9"]:
  if not await walk(route("l10_barrel_walk.json",part),"globe9 "+part):return false
 if not await take("act2:L10_DC:item9"):return false
 return true
func northern_globe()->bool:
 if not await load_input("last_globe"):return false
 if not await walk(route("l10_blue_walk.json","blue"),"globe43"):return false
 return await take("act2:L10_DC:item43")
func shielded()->bool:
 if not await load_input("shielded"):return false
 var legs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_tower_upper_walk.json"))
 var tower=scene.get_node("L9Tower")
 for leg in legs:
  if not await walk(leg.route.points,"upper tower "+leg.target):return false
  if leg.target!="79":
   await look(tower.aims[leg.target]);await tap(KEY_1)
   for i in 180:
    if leg.target in tower.state().orbs:break
    await tap(KEY_Q);await ticks(12)
   if not check(leg.target in tower.state().orbs,"Real Spark upper field"):return false
 if not await walk(route("l9_bracers_walk.json"),"living Saar niche"):return false
 var owner=scene.act2_items
 await look(owner.aim_point("act2:L9_DR:item55"));await ticks(4)
 if not check(scene.act2_creatures.state.actors["79"].health>0,"Saar still alive"):return false
 if not check(owner.hint.text=="The bracers are shielded.","Living Saar shield explanation"):return false
 await shot("shielded",owner.hint.text);await tap(KEY_E);await ticks(4)
 return check("act2:L9_DR:item55" not in scene.carried_collected,"Shielded E cannot take bracers")
func bracers()->bool:
 if not await load_input("bracers"):return false
 if not await walk(route("l9_bracers_walk.json"),"bracers niche"):return false
 var shield=scene.get_node("L9DeadBracers")
 await look(shield.aim);await tap(KEY_1)
 for i in 100:
  if shield.released():break
  await tap(KEY_Q);await ticks(12)
 if not check(shield.released(),"Real Spark removes bracer shield"):return false
 return await take("act2:L9_DR:item55")
func statue()->bool:
 if not await load_input("statue"):return false
 var binder=scene.progression;var row:Array=binder.exit_objects["control:150"][0].position;var aim:=Vector3(row[0],row[1],row[2])
 if not await walk(route("l9_white_revisit_walk.json","statue"),"winged statue",func():return scene.player.position.distance_to(aim)<115):return false
 await look(aim);await ticks(4)
 if not check(binder.aimed_exit()=="control:150" and binder.interaction_hint.text=="E — Touch the winged statue","Winged statue visible input prompt"):return false
 await shot("statue",binder.interaction_hint.text)
 if not check(int(binder.native.locals.get(11,0))==0,"No contact or idle activation on approach"):return false
 await tap(KEY_F5);await tap(KEY_E);await ticks(5)
 if not check(int(binder.native.locals.get(11,0))==1,"E runs the actual source statue group"):return false
 # Independently load the unchanged checkpoint before the contact acceptance.
 if not await load_input("statue"):return false
 binder=scene.progression
 if not await walk(route("l9_white_revisit_walk.json","statue"),"fresh statue contact approach",func():return scene.player.position.distance_to(aim)<115):return false
 await look(aim);await tap(KEY_F5);await tap(KEY_F9);await ticks(12);binder=scene.progression
 if not check(int(binder.native.locals.get(11,0))==0,"F5/F9 before contact and idle do not activate statue"):return false
 for i in 300:
  if current_scene!=scene:break
  turn(aim);key(KEY_W,true);await physics_frame
 key(KEY_W,false)
 if current_scene!=scene:
  # change_scene removes the old map before installing the new one.
  for i in 1800:
   await process_frame
   if is_instance_valid(current_scene) and bool(current_scene.get("ready_for_review")):break
  if not check(is_instance_valid(current_scene) and current_scene.scene_file_path.ends_with("dragon_level.tscn"),"Walking into statue directly enters Ruins"):return false
  proof.events.append({"transition":"L9_DR","position":str(current_scene.player.position),"resets":current_scene.resets})
  return check(current_scene.resets==0,"Native destination settles without fall recovery")
 return check(false,"Continuous W into the statue must enter Ruins without E or a retreat/re-entry")
func slab_path()->Array:
 var back:Array=route("l10_priest_walk.json","priest");back.reverse();back.append([2880,-3005]);back.append_array(route("l10_ankh_walk.json"))
 return back
func slab()->bool:
 if not await load_input("slab_empty"):return false
 if not await walk(slab_path(),"empty slab approach"):return false
 var entry=scene.get_node("L10EmperorEntry");await look(entry.SLAB_AIM);await ticks(4)
 if not check(entry.hint.text=="The slab has an ankh-shaped hollow.","Slab without ankh explains hollow"):return false
 await shot("slab_empty",entry.hint.text)
 await tap(KEY_E);await ticks(4)
 if not check(not entry.opened(),"Empty-handed E leaves puzzle closed"):return false
 if not await load_input("ashes"):return false
 var back:Array=route("l9_chapel_walk.json","statue");back.reverse()
 if not await walk(back,"ashes back to priest"):return false
 entry=scene.get_node("L10EmperorEntry")
 var priest=scene.get_node("L10Priest");await look(priest.AIM)
 # Baseline needs two presses (lead owns F3); tolerate a one-press result after integration.
 for i in 2:
  if entry.Ankh.ANKH in scene.carried_collected:break
  await tap(KEY_E);await ticks(8)
 entry=scene.get_node("L10EmperorEntry")
 if not check(entry.Ankh.ANKH in scene.carried_collected,"Actual E trades ashes and retrieves ankh"):return false
 await tap(KEY_F5)
 var save_path:String=preload("res://scripts/lol2/game_save.gd").slot_path(1)
 if not check(FileAccess.file_exists(save_path),"Real F5 writes the earned ankh checkpoint"):return false
 DirAccess.make_dir_recursive_absolute(output())
 var checkpoint:=FileAccess.open(output()+"earned_ankh.json",FileAccess.WRITE)
 checkpoint.store_string(JSON.stringify(preload("res://scripts/lol2/game_save.gd").read_document(save_path).state.area_save,"  ",true,true)+"\n");checkpoint.close()
 proof.events.append({"earned_segment":"actual E priest trade; normal F5 before slab approach","save_sha256":FileAccess.get_sha256(save_path)})
 if not await walk(slab_path(),"earned ankh slab approach"):return false
 await look(entry.SLAB_AIM);await ticks(4)
 if not check(entry.hint.text=="E — Use the ankh on the slab","Carried ankh slab prompt"):return false
 await shot("slab_ankh",entry.hint.text)
 await tap(KEY_E);await ticks(5)
 if not check(entry.opened() and entry.hint.text=="E — Retrieve the ankh","E opens slab and offers retrieval"):return false
 await tap(KEY_F5);await tap(KEY_F9);await ticks(6);entry=scene.get_node("L10EmperorEntry")
 if not check(entry.opened() and entry.hint.text=="E — Retrieve the ankh","Occupied slab reload prompt"):return false
 await tap(KEY_E);await ticks(5)
 if not check(entry.Ankh.ANKH in scene.carried_collected and entry.hint.text.is_empty(),"Real E retrieves ankh and clears completed hint"):return false
 await tap(KEY_F5);await tap(KEY_F9);await ticks(8);entry=scene.get_node("L10EmperorEntry")
 return check(entry.opened() and entry.hint.text.is_empty(),"Completed slab stays clear after F5/F9")
func fence_cross(id:int)->bool:
 var fences=scene.get_node("L10Fences");var row:Dictionary=fences.rows[id]
 await ticks(4)
 if not await journal("l10_fence_tuck","fence"+str(id)):return false
 fences=scene.get_node("L10Fences")
 var before:int=fences.passes
 await look(scene.player.position-row.normal*300+Vector3.UP*10)
 key(KEY_SHIFT,true);key(KEY_W,true);await ticks(6)
 await tap(KEY_SPACE);await ticks(2);key(KEY_CTRL,true)
 var crossed:=false
 for i in 300:
  turn(scene.player.position-row.normal*300+Vector3.UP*10,false);await physics_frame
  if not live():return false
  if (scene.player.position-row.center).dot(row.normal)<-80 and scene.player.is_on_floor():crossed=true;break
 key(KEY_CTRL,false);key(KEY_W,false);key(KEY_SHIFT,false)
 return check(crossed and fences.passes>before,"Real sprint/jump/airborne Ctrl clears fence "+str(id))
func fences()->bool:
 if not await load_input("fences"):return false
 if not await walk(route("l10_blue_walk.json","fence74"),"fence74 approach"):return false
 if not await fence_cross(74):return false
 if not await walk(route("l10_blue_walk.json","fence174"),"fence174 approach"):return false
 if not await fence_cross(174):return false
 if not check(preload("res://scripts/lol2/my_journal.gd").notes(scene).count("l10_fence_tuck")==1,"Both fence approaches discover once"):return false
 await tap(KEY_F1);await ticks(3)
 var help=scene.interface_hud.help
 for i in 8:
  if help.page_topic==5:break
  await tap(KEY_RIGHT)
 if not check(help.page.visible and "Ctrl" in help.page_body.text and "tuck" in help.page_body.text,"Rendered movement help lists Ctrl tuck and C crouch"):return false
 await shot("controls",help.page_body.text);await tap(KEY_ESCAPE)
 await tap(KEY_F5);await tap(KEY_F9);await ticks(10)
 return live()
func journal(id:String,label:String)->bool:
 var J=preload("res://scripts/lol2/my_journal.gd")
 await ticks(4)
 if not check(id in J.notes(scene),"First approach discovers "+id):return false
 await tap(KEY_J);await ticks(4)
 if not check(scene.interface_hud.sheet.visible and J.hints()[id] in scene.interface_hud.sheet_body.text,"J displays exact puzzle note "+id):return false
 await shot(label,scene.interface_hud.sheet_body.text);await tap(KEY_J);await ticks(3)
 await tap(KEY_F5);await tap(KEY_F9);await ticks(5)
 return check(J.notes(scene).count(id)==1,"F5/F9 keeps exactly one note "+id) and live()
func rail()->bool:
 if not await load_input("rail"):return false
 var rails=scene.get_node("L9NobleRails")
 if not await walk([[639,-5700],[639,-5655]],"noble rail approach"):return false
 if not await journal("l9_rotten_rail","rail_note"):return false
 rails=scene.get_node("L9NobleRails")
 await look(Vector3(639,160,-5596));await click();await ticks(12)
 if not check("480" in rails.state().broken,"Real left click still breaks rail"):return false
 if not await walk([[639,-5500]],"through broken rail"):return false
 return await journal("l9_rotten_rail","rail_after_crossing")
func flood()->bool:
 if not await load_input("flood"):return false
 if not await walk([[4111,-9890]],"active flood first approach"):return false
 return await journal("l9_flood_table","flood_note")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var ok:bool=await call(scenario())
 for code in [KEY_W,KEY_SHIFT,KEY_CTRL,KEY_SPACE]:key(code,false)
 proof["passed"]=ok and not failed
 if is_instance_valid(scene):proof["resets"]=scene.resets
 write_proof()
 if ok and not failed:print("PASS ",scenario()," actual prompt/input/save-reload local walk; no teleport/resource-write/direct-action-call")
 quit(0 if ok and not failed else 1)
